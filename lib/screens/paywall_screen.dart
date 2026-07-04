import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/spacing.dart';
import '../services/subscription_service.dart';

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

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: Column(
        children: [
          _buildTopBar(l10n),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                top: AppSpacing.xl,
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
          ),
          _buildBottomButton(l10n, bottomPadding),
        ],
      ),
    );
  }

  Widget _buildTopBar(AppLocalizations l10n) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      color: const Color(0xFF161719),
      padding: EdgeInsets.only(top: topPadding, bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 44,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: EdgeInsets.only(left: AppSpacing.md),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 20,
                      ),
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
              ],
            ),
          ),
        ],
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
            color: Color(0xFFB9B9B9),
          ),
        ),
      ],
    );
  }

  Widget _buildBillingToggle(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F21),
        borderRadius: BorderRadius.circular(12),
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
                  color: !_isAnnual ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    l10n.paywallMonthly,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: !_isAnnual
                          ? const Color(0xFF0C0C0C)
                          : const Color(0xFFB9B9B9),
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
                  color: _isAnnual ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    l10n.paywallAnnualSave,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _isAnnual
                          ? const Color(0xFF0C0C0C)
                          : const Color(0xFFB9B9B9),
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
                    color: Color(0xFFB9B9B9),
                  ),
                )
              : Text(
                  l10n.paywallRestore,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 22 / 15,
                    color: Color(0xFFB9B9B9),
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFFB9B9B9),
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
                  color: Color(0xFFB9B9B9),
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0xFFB9B9B9),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '\u2022',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFFB9B9B9),
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
                  color: Color(0xFFB9B9B9),
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0xFFB9B9B9),
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
      color: const Color(0xFF0C0C0C),
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
              color: isLoading ? Colors.white.withValues(alpha: 0.6) : Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Center(
              child: _isPurchasing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0C0C0C),
                      ),
                    )
                  : Text(
                      l10n.paywallContinue,
                      style: const TextStyle(
                        fontFamily: 'IBM Plex Sans',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 20 / 15,
                        color: Color(0xFF0C0C0C),
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
          color: const Color(0xFF161719),
          borderRadius: BorderRadius.circular(16),
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
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 12,
                          color: Color(0xFF0C0C0C),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          trialBadgeText!,
                          style: const TextStyle(
                            fontFamily: 'IBM Plex Sans',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            height: 16 / 11,
                            color: Color(0xFF0C0C0C),
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
                color: Color(0xFFB9B9B9),
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
                color: Color(0xFFB9B9B9),
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
                color: Color(0xFFB9B9B9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
