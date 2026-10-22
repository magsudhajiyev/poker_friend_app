import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../design_system/components/buttons/back_button_circle.dart';
import '../design_system/components/dialogs/app_dialog.dart';
import '../design_system/components/dialogs/dialog_action_bar.dart';
import '../design_system/components/success_check_overlay.dart';
import '../design_system/components/overlays/subscription_success_popup.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/spacing.dart';
import '../design_system/constants/typography.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../design_system/components/modals/confirm_dialog.dart';
import '../onboarding/onboarding_prefs.dart';
import '../services/subscription_service.dart';
import '../services/subscription_logic.dart' show TrialOffer, TrialUnit;
import '../services/auth_service.dart';
import '../services/logger_service.dart';
import '../utils/user_facing_error.dart';
import '../design_system/constants/decorations.dart';
import 'auth_screen_experimental.dart';
import '../services/analytics_service.dart';

/// Paywall screen showing subscription plan selection.
///
/// Displays three tiers (Pro, Elite, Club) as vertically stacked cards.
/// Tapping a card selects it (green border). The pinned "Continue" button
/// triggers RevenueCat's native purchase flow for the selected plan.
class PaywallScreen extends StatefulWidget {
  final String? featureName;
  final bool showSkip;
  final int? preselectedTier;

  /// Launch-promo variant: the user was just auto-granted 1 month of free Pro
  /// (RevenueCat promotional entitlement). Shows a celebratory dialog on open
  /// and presents Pro monthly with a "1 MONTH FREE" badge.
  final bool launchPromo;

  /// Debug-only: when true, tapping Continue simulates a successful purchase
  /// (via a debug tier override) instead of hitting RevenueCat, so the full
  /// post-purchase success flow can be exercised. No-op in release builds.
  final bool mockPurchase;

  /// Hard-paywall mode: NON-DISMISSIBLE. No skip, no back (system back blocked
  /// too), so the only way forward is to start a subscription. The escape
  /// hatches that must stay reachable — Restore purchases (footer), Sign out
  /// and Delete account — are shown instead. Used by the app-entry gate when
  /// the `hard_paywall` flag is on and the user has no access.
  final bool hardGate;

  const PaywallScreen({
    super.key,
    this.featureName,
    this.showSkip = false,
    this.preselectedTier,
    this.launchPromo = false,
    this.mockPurchase = false,
    this.hardGate = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    String? featureName,
    int? preselectedTier,
    bool launchPromo = false,
    bool mockPurchase = false,
  }) {
    AnalyticsService.capture('paywall_opened', {
      if (featureName != null) 'feature': featureName,
      if (preselectedTier != null) 'preselected_tier': preselectedTier,
      'launch_promo': launchPromo,
    });
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => PaywallScreen(
          featureName: featureName,
          preselectedTier: preselectedTier,
          launchPromo: launchPromo,
          mockPurchase: mockPurchase,
        ),
      ),
    );
  }

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  int _selectedPlanIndex = 0;
  bool _isAnnual = true;
  bool _isPurchasing = false;
  bool _isRestoring = false;
  Offering? _offering;

  final ScrollController _scrollController = ScrollController();
  // Keys on each plan card so we can scroll the preselected one into view.
  final List<GlobalKey> _planCardKeys = List.generate(3, (_) => GlobalKey());

  // Package ids per tier (index = plan card) and their offline fallback
  // prices — the real prices always come from the store via RevenueCat.
  static const _tierIds = [
    ['pro_monthly', 'pro_annual'],
    ['elite_monthly', 'elite_annual'],
    ['club_monthly', 'club_annual'],
  ];
  static const _fallbackPrices = [
    ['\$19.99', '\$159.99'],
    ['\$24.99', '\$189.99'],
    ['\$59.99', '\$449.99'],
  ];

  /// The package id the [tier] card buys in the current billing period.
  String _packageIdFor(int tier) => _tierIds[tier][_isAnnual ? 1 : 0];

  /// The free trial the user can start on [tier] in the current billing
  /// period, or null (no trial / already used one / not loaded yet).
  TrialOffer? _trialFor(int tier) =>
      SubscriptionService.trialFor(_packageIdFor(tier));

  /// "7 days" / "1 month" — the length always comes from the store.
  String _trialDuration(TrialOffer t, AppLocalizations l10n) =>
      t.unit == TrialUnit.day
          ? l10n.paywallTrialDays(t.count)
          : l10n.paywallTrialMonths(t.count);

  /// What the user pays after the trial, e.g. "$159.99/year".
  String _pricePerPeriod(int tier, AppLocalizations l10n) => _tierPrimaryPrice(
      _tierIds[tier][0],
      _tierIds[tier][1],
      l10n,
      _fallbackPrices[tier][0],
      _fallbackPrices[tier][1]);

  @override
  void initState() {
    super.initState();
    // Which free trials can this user still start? (Eligibility changes once
    // a trial was used, so re-check every time the paywall opens.)
    SubscriptionService.refreshTrialOffers().then((_) {
      if (mounted) setState(() {});
    });
    _offering = SubscriptionService.currentOffering;
    if (_offering == null) {
      _fetchOfferings();
    }
    // Preselect a tier (e.g. the user's current plan) and scroll it into
    // view after first layout, instead of defaulting to Pro at the top.
    final pre = widget.preselectedTier;
    if (pre != null && pre >= 0 && pre <= 2) {
      _selectedPlanIndex = pre;
      if (pre != 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollSelectedIntoView();
        });
      }
    }
    if (widget.launchPromo) {
      _selectedPlanIndex = 0;
      _isAnnual = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showPromoWelcomeDialog();
      });
    }
  }

  /// Launch-promo celebration: the free Pro month was already granted
  /// server-side; this dialog just announces it over the paywall.
  Future<void> _showPromoWelcomeDialog() {
    final l10n = AppLocalizations.of(context);
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AppDialog(
        showCloseButton: false,
        barrierDismissible: false,
        // Full width so the column centers within the dialog (AppDialog's
        // internal layout is start-aligned).
        body: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.card_giftcard,
                color: AppColors.accentPrimary,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.promoWelcomeTitle,
                style: AppTypography.ibm(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: l10n.promoWelcomeBodyPre),
                    TextSpan(
                      text: l10n.promoWelcomeBodyBold,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextSpan(text: l10n.promoWelcomeBodyPost),
                  ],
                ),
                style: AppTypography.ibm(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.44,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: DialogActionBar.single(
          cancelLabel: l10n.onboardingGotIt,
          // "Got it" ends the promo funnel: leave the paywall entirely and
          // land on Home, where the congratulations dialog shows once
          // (pending flag persisted FIRST so an app kill can't lose it).
          onCancel: () async {
            await OnboardingPrefs.setPromoCongratsPending();
            if (!mounted) return;
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/', (route) => false);
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollSelectedIntoView() {
    final ctx = _planCardKeys[_selectedPlanIndex].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.1, // near the top of the viewport
      );
    }
  }

  Future<void> _fetchOfferings() async {
    await SubscriptionService.fetchOfferings();
    if (mounted) {
      setState(() {
        _offering = SubscriptionService.currentOffering;
      });
    }
  }

  Future<void> _onContinue() async {
    final l10n = AppLocalizations.of(context);

    // Guests must create an account before purchasing so the receipt is
    // tied to a recoverable identity. Linking keeps the same uid, so their
    // data (and this paywall) carry straight over.
    if (AuthService.isAnonymous) {
      final linked = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => AuthScreenExperimental(linkMode: true),
        ),
      );
      if (linked != true || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.paywallAccountReady),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // Debug-only mock purchase: skip RevenueCat, set a debug tier override so
    // the effective tier flips, and run the same success flow.
    if (widget.mockPurchase && !kReleaseMode) {
      setState(() => _isPurchasing = true);
      try {
        final tier = ['pro', 'elite', 'club'][_selectedPlanIndex];
        await SubscriptionService.setDebugTierOverride(tier);
        if (!mounted) return;
        await _showPurchaseSuccess(_tierLabel(_selectedPlanIndex, l10n));
      } finally {
        if (mounted) setState(() => _isPurchasing = false);
      }
      return;
    }

    // Get the appropriate package via product ID lookup
    final ids = _tierIds[_selectedPlanIndex];
    final package =
        SubscriptionService.packageById(_isAnnual ? ids[1] : ids[0]);
    unawaited(LoggerService.debug(
        '📦 Paywall: offering=$_offering, isAnnual=$_isAnnual, package=${package?.identifier}'));
    if (package == null) {
      // Try fetching offerings one more time before giving up
      await SubscriptionService.fetchOfferings();
      if (!mounted) return;
      _offering = SubscriptionService.currentOffering;
      final retryPackage =
          SubscriptionService.packageById(_isAnnual ? ids[1] : ids[0]);
      unawaited(LoggerService.debug(
          '📦 Paywall retry: offering=$_offering, package=${retryPackage?.identifier}'));
      if (retryPackage != null) {
        if (!mounted) return; // disposed during the fetch — don't recurse
        setState(() {});
        // Re-run with the now-available package
        return _onContinue();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.paywallSubscriptionUnavailable),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isPurchasing = true);
    try {
      final success = await SubscriptionService.purchasePackage(package);
      if (!mounted) return;
      if (success) {
        await _showPurchaseSuccess(_tierLabel(_selectedPlanIndex, l10n));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.paywallPurchaseFailed),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  /// Localized tier name for the given plan index (0=Pro, 1=Elite, 2=Club).
  String _tierLabel(int index, AppLocalizations l10n) {
    switch (index) {
      case 2:
        return l10n.profileTierClub;
      case 1:
        return l10n.profileTierElite;
      default:
        return l10n.profileTierPro;
    }
  }

  /// Localized label for the user's current effective tier (used on restore,
  /// where the specific plan index isn't known).
  String _effectiveTierLabel(AppLocalizations l10n) {
    switch (SubscriptionService.effectiveTier) {
      case 'club':
        return l10n.profileTierClub;
      case 'elite':
        return l10n.profileTierElite;
      default:
        return l10n.profileTierPro;
    }
  }

  /// Plays the post-purchase success flow: a green checkmark animation, then a
  /// titled confirmation card, then pops the paywall (returning true). Must be
  /// awaited before the pop — the paywall's Overlay is gone once the route pops.
  Future<void> _showPurchaseSuccess(String tierLabel) async {
    await SuccessCheckOverlay.show(context);
    if (!mounted) return;
    await SubscriptionSuccessPopup.show(context, tierLabel: tierLabel);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _onRestore() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isRestoring = true);
    try {
      final success = await SubscriptionService.restorePurchases();
      if (!mounted) return;
      if (success) {
        await _showPurchaseSuccess(_effectiveTierLabel(l10n));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.paywallNoPreviousPurchases),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  // ── Hard-gate escape hatches ─────────────────────────────────────────────
  // The paywall is non-dismissible, so these keep the user able to leave:
  // sign out (switch accounts) and delete the account. Both let the auth
  // stream route back to the intro screen — no explicit navigation here.

  Future<void> _onHardGateSignOut() async {
    await AuthService.signOut();
    // AuthWrapper's auth stream rebuilds to the intro screen on sign-out.
  }

  void _onHardGateDelete() {
    final l10n = AppLocalizations.of(context);
    ConfirmDialog.show(
      context,
      title: l10n.profileDeleteAccount,
      message: l10n.profileDeleteAccountMessage,
      confirmLabel: l10n.commonDelete,
      onConfirm: _deleteAccount,
    );
  }

  Future<void> _deleteAccount() async {
    final uid = AuthService.userId;
    if (uid == null) return;
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('users').doc(uid).delete();
      await firestore.collection('user_stats').doc(uid).delete();
      for (final coll in ['session_results', 'poker_sessions', 'opponents']) {
        final snap =
            await firestore.collection(coll).where('userId', isEqualTo: uid).get();
        for (final doc in snap.docs) {
          await doc.reference.delete();
        }
      }
      final opponents = await firestore
          .collection('opponents')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in opponents.docs) {
        await firestore.collection('opponent_stats').doc(doc.id).delete();
      }
      await AuthService.deleteAccount();
      // Auth stream routes to the intro screen once the user is gone.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UserFacingError.message(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final topPadding = MediaQuery.of(context).padding.top;
    final topBarHeight = topPadding + 56;
    // Hard gate: block the Android system back button too, so the paywall is
    // truly non-dismissible (the skip/back affordances are already hidden).
    return PopScope(
      canPop: !widget.hardGate,
      child: Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Scroll region — pads top so content clears the blurred bar.
                SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.only(
                    top: topBarHeight + AppSpacing.xl,
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    bottom: AppSpacing.xl,
                  ),
                  child: Column(
                    children: [
                      _buildHeader(l10n),
                      const SizedBox(height: 24),
                      _buildBillingToggle(l10n),
                      const SizedBox(height: 24),
                      _buildPlanCards(l10n),
                      const SizedBox(height: 24),
                      _buildFooter(l10n),
                    ],
                  ),
                ),
                // Blurred translucent top bar overlays the scroll region.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildTopBar(l10n),
                ),
              ],
            ),
          ),
          _buildBottomButton(l10n, bottomPadding),
        ],
      ),
      ),
    );
  }

  Widget _buildTopBar(AppLocalizations l10n) {
    final topPadding = MediaQuery.of(context).padding.top;
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          color: AppColors.bgPrimary.withValues(alpha: 0.6),
          padding: EdgeInsets.only(top: topPadding, bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 44,
                child: Stack(
                  children: [
                    // Back button — hidden when the Skip button is shown
                    // (onboarding paywall) OR in the non-dismissible hard gate;
                    // kept for feature-gate paywalls so they stay dismissible.
                    if (!widget.showSkip && !widget.hardGate)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.md),
                          child: BackButtonCircle(
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),
                    Center(
                      child: Text(
                        l10n.paywallAvailablePlans,
                        style: AppTypography.ibm(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          height: 22 / 17,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // Skip affordance — only when the paywall is dismissible
                    // (post-tour onboarding). Pops with no purchase.
                    if (widget.showSkip)
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Padding(
                            padding: EdgeInsets.only(right: AppSpacing.md),
                            child: Text(
                              l10n.onboardingSkip,
                              style: AppTypography.ibm(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Column(
      children: [
        Text(
          l10n.paywallStepLabel,
          style: AppTypography.ibm(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 22 / 15,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.paywallChooseYourPlan,
          style: AppTypography.ibm(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            height: 36 / 28,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.paywallUpgradeOrCancel,
          style: AppTypography.ibm(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 22 / 15,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildBillingToggle(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        border: Border.all(
          color: _isAnnual
              ? AppColors.accentPrimary.withValues(alpha: 0.35)
              : Colors.transparent,
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isAnnual = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isAnnual ? AppColors.bgElevated : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        l10n.paywallMonthly,
                        style: AppTypography.ibm(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: !_isAnnual
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isAnnual = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isAnnual
                      ? AppColors.accentPrimary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
                  border: Border.all(
                    color: _isAnnual
                        ? AppColors.accentPrimary.withValues(alpha: 0.5)
                        : Colors.transparent,
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        l10n.paywallAnnualSave,
                        style: AppTypography.ibm(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _isAnnual
                              ? AppColors.accentPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Pull the localized price string from a RevenueCat package, or fall back.
  String _priceOf(String packageId, String fallback) {
    return SubscriptionService.packageById(packageId)
            ?.storeProduct
            .priceString ??
        fallback;
  }

  /// Primary price line for a tier (the big price shown on the card).
  String _tierPrimaryPrice(String monthlyId, String annualId,
      AppLocalizations l10n, String monthlyFallback, String annualFallback) {
    if (_isAnnual) {
      return l10n.paywallPriceYearly(_priceOf(annualId, annualFallback));
    }
    return l10n.paywallPriceMonthly(_priceOf(monthlyId, monthlyFallback));
  }

  /// Secondary price line (the smaller "or …" alternate period).
  String _tierSecondaryPrice(String monthlyId, String annualId,
      AppLocalizations l10n, String monthlyFallback, String annualFallback) {
    if (_isAnnual) {
      return l10n.paywallOrPriceMonthly(_priceOf(monthlyId, monthlyFallback));
    }
    return l10n.paywallOrPriceYearly(_priceOf(annualId, annualFallback));
  }

  /// Card badge, e.g. "7 days free" (null without an eligible trial).
  String? _trialBadge(int tier, AppLocalizations l10n) {
    final t = _trialFor(tier);
    return t == null ? null : l10n.paywallTrialBadge(_trialDuration(t, l10n));
  }

  /// Card line, e.g. "Free for 1 month, then $159.99/year".
  String? _trialLine(int tier, AppLocalizations l10n) {
    final t = _trialFor(tier);
    return t == null
        ? null
        : l10n.paywallTrialThen(
            _trialDuration(t, l10n), _pricePerPeriod(tier, l10n));
  }

  Widget _buildPlanCards(AppLocalizations l10n) {
    return Column(
      children: [
        KeyedSubtree(
          key: _planCardKeys[0],
          child: _PlanCard(
            tierLabel: l10n.paywallProTier,
            tagline: l10n.paywallProDescription,
            primaryPrice: _tierPrimaryPrice(
                'pro_monthly', 'pro_annual', l10n, '\$19.99', '\$159.99'),
            secondaryPrice: _tierSecondaryPrice(
                'pro_monthly', 'pro_annual', l10n, '\$19.99', '\$159.99'),
            features: [
              l10n.paywallProFeature1,
              l10n.paywallProFeature2,
              l10n.paywallProFeature3,
              l10n.paywallProFeature4,
              l10n.paywallProFeature5,
            ],
            // Store free trial wins; the launch-promo gift badge otherwise.
            showTrialBadge: _trialFor(0) != null || widget.launchPromo,
            trialBadgeText: _trialBadge(0, l10n) ??
                (widget.launchPromo ? l10n.promoFreeMonthBadge : null),
            trialLine: _trialLine(0, l10n),
            isSelected: _selectedPlanIndex == 0,
            onTap: () => setState(() => _selectedPlanIndex = 0),
          ),
        ),
        const SizedBox(height: 16),
        KeyedSubtree(
          key: _planCardKeys[1],
          child: _PlanCard(
            tierLabel: l10n.paywallEliteTier,
            tagline: l10n.paywallEliteDescription,
            primaryPrice: _tierPrimaryPrice(
                'elite_monthly', 'elite_annual', l10n, '\$24.99', '\$189.99'),
            secondaryPrice: _tierSecondaryPrice(
                'elite_monthly', 'elite_annual', l10n, '\$24.99', '\$189.99'),
            features: [
              l10n.paywallEliteFeature4,
              l10n.paywallEliteFeature5,
              l10n.paywallEliteFeature6,
              l10n.paywallEliteFeature7,
              l10n.paywallEliteFeature8,
            ],
            showTrialBadge: _trialFor(1) != null,
            trialBadgeText: _trialBadge(1, l10n),
            trialLine: _trialLine(1, l10n),
            isSelected: _selectedPlanIndex == 1,
            onTap: () => setState(() => _selectedPlanIndex = 1),
          ),
        ),
        const SizedBox(height: 16),
        KeyedSubtree(
          key: _planCardKeys[2],
          child: _PlanCard(
            tierLabel: l10n.paywallClubTier,
            tagline: l10n.paywallClubDescription,
            primaryPrice: _tierPrimaryPrice(
                'club_monthly', 'club_annual', l10n, '\$59.99', '\$449.99'),
            secondaryPrice: _tierSecondaryPrice(
                'club_monthly', 'club_annual', l10n, '\$59.99', '\$449.99'),
            features: [
              l10n.paywallClubFeature1,
              l10n.paywallClubManagement,
              l10n.paywallLiveDealerVoice,
              l10n.paywallMultiTableEvents,
            ],
            showTrialBadge: _trialFor(2) != null,
            trialBadgeText: _trialBadge(2, l10n),
            trialLine: _trialLine(2, l10n),
            isSelected: _selectedPlanIndex == 2,
            onTap: () => setState(() => _selectedPlanIndex = 2),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(AppLocalizations l10n) {
    final trial = _trialFor(_selectedPlanIndex);
    return Column(
      children: [
        // Store-required trial terms (Apple 3.1.2 / Play): length, price
        // after the trial, and how to avoid the charge.
        if (trial != null) ...[
          Text(
            l10n.paywallTrialDisclosure(_trialDuration(trial, l10n),
                _pricePerPeriod(_selectedPlanIndex, l10n)),
            textAlign: TextAlign.center,
            style: AppTypography.ibm(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 22 / 15,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          l10n.paywallDisclaimer,
          textAlign: TextAlign.center,
          style: AppTypography.ibm(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 22 / 15,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        // Restore purchases button
        GestureDetector(
          onTap: (_isPurchasing || _isRestoring) ? null : _onRestore,
          child: _isRestoring
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.contentInactive,
                  ),
                )
              : Text(
                  l10n.paywallRestore,
                  style: AppTypography.ibm(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 22 / 15,
                    color: AppColors.textSecondary,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.textSecondary,
                  ),
                ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () =>
                  launchUrl(Uri.parse('https://www.finaltable.io/terms')),
              child: Text(
                l10n.paywallTerms,
                style: AppTypography.ibm(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 22 / 15,
                  color: AppColors.textSecondary,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.textSecondary,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '\u2022',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            GestureDetector(
              onTap: () =>
                  launchUrl(Uri.parse('https://www.finaltable.io/privacy')),
              child: Text(
                l10n.paywallPrivacy,
                style: AppTypography.ibm(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 22 / 15,
                  color: AppColors.textSecondary,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        // Hard-gate escape hatches: the paywall is non-dismissible, so the
        // user must still be able to sign out (switch to a subscribed account)
        // and delete their account (store/compliance requirement). Restore is
        // the button above.
        if (widget.hardGate) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: (_isPurchasing || _isRestoring) ? null : _onHardGateSignOut,
                child: Text(
                  l10n.paywallSignOut,
                  style: AppTypography.ibm(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    height: 22 / 15,
                    color: AppColors.textSecondary,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.textSecondary,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('•',
                    style: TextStyle(
                        fontSize: 15, color: AppColors.textSecondary)),
              ),
              GestureDetector(
                onTap: (_isPurchasing || _isRestoring) ? null : _onHardGateDelete,
                child: Text(
                  l10n.paywallDeleteAccount,
                  style: AppTypography.ibm(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    height: 22 / 15,
                    color: AppColors.accentDanger,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.accentDanger,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBottomButton(AppLocalizations l10n, double bottomPadding) {
    final isLoading = _isPurchasing || _isRestoring;
    return Container(
      color: AppColors.bgPrimary,
      padding: EdgeInsets.only(
        top: 24,
        bottom: bottomPadding > 0 ? bottomPadding : 24,
      ),
      child: Center(
        child: GestureDetector(
          onTap: isLoading ? null : _onContinue,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 323,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isLoading
                  ? AppColors.accentPrimary.withValues(alpha: 0.6)
                  : AppColors.accentPrimary,
              borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
            ),
            child: Center(
              child: _isPurchasing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textInverse,
                      ),
                    )
                  : Text(
                      _trialFor(_selectedPlanIndex) != null
                          ? l10n.paywallStartTrial
                          : l10n.paywallContinue,
                      style: AppTypography.ibm(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 20 / 15,
                        color: AppColors.textInverse,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single subscription plan card.
class _PlanCard extends StatelessWidget {
  final String tierLabel;
  final String tagline;
  final String primaryPrice;
  final String secondaryPrice;
  final List<String> features;
  final bool showTrialBadge;
  final String? trialBadgeText;

  /// "Free for 7 days, then $19.99/month" — shown under the price when the
  /// user can start a free trial on this plan.
  final String? trialLine;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.tierLabel,
    required this.tagline,
    required this.primaryPrice,
    required this.secondaryPrice,
    required this.features,
    required this.showTrialBadge,
    this.trialBadgeText,
    this.trialLine,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
          border: Border.all(
            color: isSelected ? AppColors.accentSecondary : Colors.transparent,
            width: 2,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tier name + trial badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    tierLabel,
                    style: AppTypography.ibm(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      height: 36 / 28,
                      color: AppColors.accentSecondary,
                    ),
                  ),
                ),
                if (showTrialBadge && trialBadgeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(AppDecorations.radiusFull),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 12,
                          color: AppColors.bgPrimary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          trialBadgeText!,
                          style: AppTypography.ibm(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            height: 16 / 11,
                            color: AppColors.textInverse,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Tagline
            Text(
              tagline,
              style: AppTypography.ibm(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                height: 22 / 17,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Primary price
            Text(
              primaryPrice,
              style: AppTypography.ibm(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                height: 36 / 28,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),

            // Secondary price
            Text(
              secondaryPrice,
              style: AppTypography.ibm(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 20 / 13,
                color: AppColors.textSecondary,
              ),
            ),
            if (trialLine != null) ...[
              const SizedBox(height: 8),
              Text(
                trialLine!,
                style: AppTypography.ibm(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 20 / 15,
                  color: AppColors.accentSecondary,
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Divider
            Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 24),

            // Features
            ...features.map(_buildFeatureRow),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String feature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(
            Icons.check,
            size: 16,
            color: AppColors.accentSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              feature,
              style: AppTypography.ibm(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 22 / 15,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
