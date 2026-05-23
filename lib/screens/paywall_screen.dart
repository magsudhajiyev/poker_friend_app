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
/// Elite is pre-selected as the "best value" decoy target.
/// All three tiers are purchasable via RevenueCat.
class PaywallScreen extends StatefulWidget {
  final String? featureName;

  const PaywallScreen({super.key, this.featureName});

  static Future<bool?> show(BuildContext context, {String? featureName}) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => PaywallScreen(featureName: featureName),
      ),
    );
  }

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  // Visible tier indices (only tiers with at least one package available)
  // Each entry is an index into _tierDefs
  List<int> _visibleTierIndices = [0, 1, 2]; // default — refined after offerings load

  // Selected index within _visibleTierIndices (not tierDef index)
  int _selectedVisibleIndex = 0; // Will be updated to point at Elite when possible
  bool _isAnnual = false;
  bool _isPurchasing = false;
  bool _isRestoring = false;

  // Package identifier pairs per tier [monthlyId, annualId]
  static const _tierPackageIds = [
    [SubscriptionService.pkgProMonthly,   SubscriptionService.pkgProAnnual],
    [SubscriptionService.pkgEliteMonthly, SubscriptionService.pkgEliteAnnual],
    [SubscriptionService.pkgClubMonthly,  SubscriptionService.pkgClubAnnual],
  ];

  // Fallback prices shown when RevenueCat offerings haven't loaded yet.
  // Index 0=Pro, 1=Elite, 2=Club
  static const _fallbackMonthly = [r'$19.99', r'$24.99', r'$59.99'];
  static const _fallbackAnnual  = [r'$159.99', r'$189.99', r'$449.99'];

  @override
  void initState() {
    super.initState();
    _refreshPackages();
    if (SubscriptionService.defaultOffering == null) {
      _fetchOfferings();
    }
  }

  Future<void> _fetchOfferings() async {
    await SubscriptionService.fetchOfferings();
    if (mounted) setState(_refreshPackages);
  }

  /// Determine which tiers are visible based on available packages.
  /// A tier is shown if at least one of its monthly/annual packages is non-null.
  void _refreshPackages() {
    final visible = <int>[];
    for (int tier = 0; tier < _tierPackageIds.length; tier++) {
      final monthly = SubscriptionService.packageById(_tierPackageIds[tier][0]);
      final annual  = SubscriptionService.packageById(_tierPackageIds[tier][1]);
      if (monthly != null || annual != null) {
        visible.add(tier);
      }
    }
    // If nothing loaded yet, show all tiers (will use fallback prices)
    if (visible.isEmpty) visible.addAll([0, 1, 2]);

    _visibleTierIndices = visible;

    // Pre-select Elite (tier index 1) if available, else first visible
    final eliteVisible = visible.indexOf(1);
    _selectedVisibleIndex = eliteVisible >= 0 ? eliteVisible : 0;
  }

  /// The tier index (0=Pro,1=Elite,2=Club) for the currently selected card.
  int get _selectedTierIndex => _visibleTierIndices[_selectedVisibleIndex];

  Package? _packageForTier(int tierIndex, {required bool annual}) {
    final id = _tierPackageIds[tierIndex][annual ? 1 : 0];
    return SubscriptionService.packageById(id);
  }

  String _primaryPrice(int tierIndex) {
    final pkg = _packageForTier(tierIndex, annual: _isAnnual);
    if (pkg != null) return pkg.storeProduct.priceString;
    return _isAnnual ? _fallbackAnnual[tierIndex] : _fallbackMonthly[tierIndex];
  }

  String _secondaryPrice(int tierIndex) {
    if (_isAnnual) {
      final monthly = _packageForTier(tierIndex, annual: false);
      final price = monthly?.storeProduct.priceString ?? _fallbackMonthly[tierIndex];
      return 'or $price/month';
    } else {
      final annual = _packageForTier(tierIndex, annual: true);
      final price = annual?.storeProduct.priceString ?? _fallbackAnnual[tierIndex];
      return 'or $price/year';
    }
  }

  /// Resolve the best available package for the selected tier.
  /// Returns null only if no package is available even after a retry fetch.
  Future<Package?> _resolvePackage() async {
    Package? pkg = _packageForTier(_selectedTierIndex, annual: _isAnnual)
                ?? _packageForTier(_selectedTierIndex, annual: !_isAnnual);
    if (pkg != null) return pkg;

    // Try fetching one more time
    await SubscriptionService.fetchOfferings();
    if (mounted) setState(_refreshPackages);
    return _packageForTier(_selectedTierIndex, annual: _isAnnual)
        ?? _packageForTier(_selectedTierIndex, annual: !_isAnnual);
  }

  Future<void> _onContinue() async {
    final l10n = AppLocalizations.of(context);
    final Package? package = await _resolvePackage();

    if (package == null) {
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
        final welcomeMsg = _selectedTierIndex == 2
            ? l10n.paywallWelcomeClub
            : _selectedTierIndex == 1
                ? l10n.paywallWelcomeElite
                : l10n.paywallWelcomePro;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(welcomeMsg), duration: const Duration(seconds: 2)),
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
          SnackBar(content: Text(l10n.paywallPurchasesRestored), duration: const Duration(seconds: 2)),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.paywallNoPreviousPurchases), duration: const Duration(seconds: 2)),
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
    final screenWidth = MediaQuery.of(context).size.width;

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
          _buildBottomButton(l10n, bottomPadding, screenWidth),
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
                      child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
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
                      color: !_isAnnual ? const Color(0xFF0C0C0C) : const Color(0xFFB9B9B9),
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
                      color: _isAnnual ? const Color(0xFF0C0C0C) : const Color(0xFFB9B9B9),
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

  // Feature lists per tier index (0=Pro, 1=Elite, 2=Club)
  List<String> _featuresForTier(int tierIndex, AppLocalizations l10n) {
    switch (tierIndex) {
      case 0:
        return [
          l10n.paywallProFeature1,
          l10n.paywallProFeature2,
          l10n.paywallProFeature3,
          l10n.paywallProFeature4,
          l10n.paywallProFeature5,
        ];
      case 1:
        return [
          l10n.paywallEverythingInProElite,
          l10n.paywallEliteFeature4,
          l10n.paywallEliteFeature5,
          l10n.paywallEliteFeature6,
          l10n.paywallEliteFeature7,
          l10n.paywallEliteFeature8,
        ];
      case 2:
        return [
          l10n.paywallClubFeature1,
          l10n.paywallClubFeature2,
          l10n.paywallClubFeature3,
          l10n.paywallClubFeature4,
        ];
      default:
        return [];
    }
  }

  Widget _buildPlanCards(AppLocalizations l10n) {
    final tierLabels    = [l10n.paywallProTier,   l10n.paywallEliteTier,   l10n.paywallClubTier];
    final tierTaglines  = [l10n.paywallProDescription, l10n.paywallEliteDescription, l10n.paywallClubDescription];

    final cards = <Widget>[];
    for (int vi = 0; vi < _visibleTierIndices.length; vi++) {
      final ti = _visibleTierIndices[vi]; // actual tier index (0/1/2)
      if (cards.isNotEmpty) cards.add(const SizedBox(height: 16));
      cards.add(_PlanCard(
        tierLabel: tierLabels[ti],
        tagline: tierTaglines[ti],
        primaryPrice: _isAnnual
            ? '${_primaryPrice(ti)}/year'
            : '${_primaryPrice(ti)}/month',
        secondaryPrice: _secondaryPrice(ti),
        features: _featuresForTier(ti, l10n),
        showTrialBadge: ti == 0, // Trial badge only on Pro
        trialBadgeText: l10n.paywallFreeTrialBadge,
        isBestValue: ti == 1, // Best Value badge only on Elite
        isSelected: _selectedVisibleIndex == vi,
        onTap: () => setState(() => _selectedVisibleIndex = vi),
      ));
    }
    return Column(children: cards);
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
        GestureDetector(
          onTap: (_isPurchasing || _isRestoring) ? null : _onRestore,
          child: _isRestoring
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFB9B9B9)),
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
              child: Text('\u2022', style: TextStyle(fontSize: 15, color: Color(0xFFB9B9B9))),
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

  Widget _buildBottomButton(AppLocalizations l10n, double bottomPadding, double screenWidth) {
    final isLoading = _isPurchasing || _isRestoring;
    final String label;
    switch (_selectedTierIndex) {
      case 0: label = l10n.paywallStartWithPro; break;
      case 2: label = l10n.paywallGetClubAction; break;
      default: label = l10n.paywallGetEliteAction;
    }

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
            width: screenWidth * 0.85,
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0C0C0C)),
                    )
                  : Text(
                      label,
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
  final bool isBestValue;
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
    required this.isBestValue,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
            // Tier name + badges
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
                if (isBestValue)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.limeGreen,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      l10n.paywallBestValue,
                      style: const TextStyle(
                        fontFamily: 'IBM Plex Sans',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 14 / 10,
                        color: Color(0xFF0C0C0C),
                      ),
                    ),
                  ),
                if (showTrialBadge && trialBadgeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, size: 12, color: Color(0xFF0C0C0C)),
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
            if (secondaryPrice.isNotEmpty)
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
            Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
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
          const Icon(Icons.check, size: 16, color: AppColors.accentSecondary),
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
