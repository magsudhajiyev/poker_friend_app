import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../design_system/components/buttons/back_button_circle.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/spacing.dart';
import '../services/subscription_service.dart';
import '../services/auth_service.dart';
import '../design_system/constants/decorations.dart';
import 'auth_screen_experimental.dart';

/// Paywall screen showing subscription plan selection.
///
/// Displays three tiers (Pro, Elite, Club) as vertically stacked cards.
/// Tapping a card selects it (green border). The pinned "Continue" button
/// triggers RevenueCat's native purchase flow for the selected plan.
class PaywallScreen extends StatefulWidget {
  final String? featureName;
  final bool showSkip;
  final int? preselectedTier;

  const PaywallScreen({
    super.key,
    this.featureName,
    this.showSkip = false,
    this.preselectedTier,
  });

  static Future<bool?> show(
    BuildContext context, {
    String? featureName,
    int? preselectedTier,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => PaywallScreen(
          featureName: featureName,
          preselectedTier: preselectedTier,
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

  @override
  void initState() {
    super.initState();
    _offering = SubscriptionService.currentOffering;
    if (_offering == null) {
      _fetchOfferings();
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

    // Get the appropriate package via product ID lookup
    final tierIds = [
      ['pro_monthly', 'pro_annual'],
      ['elite_monthly', 'elite_annual'],
      ['club_monthly', 'club_annual'],
    ];
    final ids = tierIds[_selectedPlanIndex];
    final package = SubscriptionService.packageById(
        _isAnnual ? ids[1] : ids[0]);
    debugPrint('📦 Paywall: offering=$_offering, isAnnual=$_isAnnual, package=${package?.identifier}');
    if (package == null) {
      // Try fetching offerings one more time before giving up
      await SubscriptionService.fetchOfferings();
      _offering = SubscriptionService.currentOffering;
      final retryPackage = SubscriptionService.packageById(
          _isAnnual ? ids[1] : ids[0]);
      debugPrint('📦 Paywall retry: offering=$_offering, package=${retryPackage?.identifier}');
      if (retryPackage != null) {
        if (mounted) setState(() {});
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.paywallWelcomePro),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(true);
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

  Future<void> _onRestore() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isRestoring = true);
    try {
      final success = await SubscriptionService.restorePurchases();
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.paywallPurchasesRestored),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(true);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final topPadding = MediaQuery.of(context).padding.top;
    final topBarHeight = topPadding + 56;
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Scroll region — pads top so content clears the blurred bar.
                SingleChildScrollView(
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
                // (onboarding paywall), kept for feature-gate paywalls so they
                // stay dismissible.
                if (!widget.showSkip)
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
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Sans',
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
                          style: const TextStyle(
                            fontFamily: 'IBM Plex Sans',
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
          style: const TextStyle(
            fontFamily: 'IBM Plex Sans',
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 22 / 15,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.paywallChooseYourPlan,
          style: const TextStyle(
            fontFamily: 'IBM Plex Sans',
            fontSize: 28,
            fontWeight: FontWeight.w600,
            height: 36 / 28,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.paywallUpgradeOrCancel,
          style: const TextStyle(
            fontFamily: 'IBM Plex Sans',
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
                  child: Text(
                    l10n.paywallMonthly,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans',
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
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isAnnual = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isAnnual ? AppColors.bgElevated : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
                ),
                child: Center(
                  child: Text(
                    l10n.paywallAnnualSave,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _isAnnual
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
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
      return '${_priceOf(annualId, annualFallback)}/year';
    }
    return '${_priceOf(monthlyId, monthlyFallback)}/month';
  }

  /// Secondary price line (the smaller "or …" alternate period).
  String _tierSecondaryPrice(String monthlyId, String annualId,
      AppLocalizations l10n, String monthlyFallback, String annualFallback) {
    if (_isAnnual) {
      return 'or ${_priceOf(monthlyId, monthlyFallback)}/month';
    }
    return 'or ${_priceOf(annualId, annualFallback)}/year';
  }

  Widget _buildPlanCards(AppLocalizations l10n) {
    return Column(
      children: [
        _PlanCard(
          tierLabel: l10n.paywallProTier,
          tagline: l10n.paywallProDescription,
          primaryPrice: _tierPrimaryPrice(
              'pro_monthly', 'pro_annual', l10n, '\$19.99', '\$159.99'),
          secondaryPrice: _tierSecondaryPrice(
              'pro_monthly', 'pro_annual', l10n, '\$19.99', '\$159.99'),
          features: [
            l10n.paywallUnlimitedHandLogging,
            l10n.paywallFullSessionHistory,
            l10n.paywallAiHandAnalysis,
            l10n.paywallExportHandsCsv,
          ],
          showTrialBadge: true,
          trialBadgeText: l10n.paywallFreeTrialBadge,
          isSelected: _selectedPlanIndex == 0,
          onTap: () => setState(() => _selectedPlanIndex = 0),
        ),
        const SizedBox(height: 16),
        _PlanCard(
          tierLabel: l10n.paywallEliteTier,
          tagline: l10n.paywallEliteDescription,
          primaryPrice: _tierPrimaryPrice(
              'elite_monthly', 'elite_annual', l10n, '\$24.99', '\$189.99'),
          secondaryPrice: _tierSecondaryPrice(
              'elite_monthly', 'elite_annual', l10n, '\$24.99', '\$189.99'),
          features: [
            l10n.paywallEverythingInProElite,
            l10n.paywallEliteFeature1,
            l10n.paywallEliteFeature2,
            l10n.paywallEliteFeature3,
          ],
          showTrialBadge: false,
          isSelected: _selectedPlanIndex == 1,
          onTap: () => setState(() => _selectedPlanIndex = 1),
        ),
        const SizedBox(height: 16),
        _PlanCard(
          tierLabel: l10n.paywallClubTier,
          tagline: l10n.paywallClubDescription,
          primaryPrice: _tierPrimaryPrice(
              'club_monthly', 'club_annual', l10n, '\$59.99', '\$449.99'),
          secondaryPrice: _tierSecondaryPrice(
              'club_monthly', 'club_annual', l10n, '\$59.99', '\$449.99'),
          features: [
            l10n.paywallEverythingInPro,
            l10n.paywallClubManagement,
            l10n.paywallLiveDealerVoice,
            l10n.paywallMultiTableEvents,
          ],
          showTrialBadge: false,
          isSelected: _selectedPlanIndex == 2,
          onTap: () => setState(() => _selectedPlanIndex = 2),
        ),
      ],
    );
  }

  Widget _buildFooter(AppLocalizations l10n) {
    return Column(
      children: [
        Text(
          l10n.paywallDisclaimer,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'IBM Plex Sans',
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
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans',
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
              onTap: () => launchUrl(Uri.parse('https://www.finaltable.io/terms')),
              child: Text(
                l10n.paywallTerms,
                style: const TextStyle(
                  fontFamily: 'IBM Plex Sans',
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
              onTap: () => launchUrl(Uri.parse('https://www.finaltable.io/privacy')),
              child: Text(
                l10n.paywallPrivacy,
                style: const TextStyle(
                  fontFamily: 'IBM Plex Sans',
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
                      l10n.paywallContinue,
                      style: const TextStyle(
                        fontFamily: 'IBM Plex Sans',
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
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Sans',
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
                      borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
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
                          style: const TextStyle(
                            fontFamily: 'IBM Plex Sans',
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
              style: const TextStyle(
                fontFamily: 'IBM Plex Sans',
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
              style: const TextStyle(
                fontFamily: 'IBM Plex Sans',
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
              style: const TextStyle(
                fontFamily: 'IBM Plex Sans',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 20 / 13,
                color: AppColors.textSecondary,
              ),
            ),
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
              style: const TextStyle(
                fontFamily: 'IBM Plex Sans',
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
