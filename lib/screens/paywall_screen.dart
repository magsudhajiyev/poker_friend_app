import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/spacing.dart';

/// Paywall screen showing subscription plan selection.
///
/// Displays three tiers (Pro, Elite, Club) as vertically stacked cards.
/// Tapping a card selects it (green border). The pinned "Continue" button
/// triggers RevenueCat's native purchase flow for the selected plan.
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
  int _selectedPlanIndex = 0;

  void _onContinue() {
    final l10n = AppLocalizations.of(context);
    final tierLabels = [
      l10n.paywallProTier,
      l10n.paywallEliteTier,
      l10n.paywallClubTier,
    ];
    // TODO: wire to RevenueCat purchase flow
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.paywallComingSoon(tierLabels[_selectedPlanIndex])),
        duration: const Duration(seconds: 2),
      ),
    );
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
                  const SizedBox(height: 32),
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

  Widget _buildPlanCards(AppLocalizations l10n) {
    return Column(
      children: [
        _PlanCard(
          tierLabel: l10n.paywallProTier,
          tagline: l10n.paywallProDescription,
          monthlyPrice: l10n.paywallProMonthly,
          annualPrice: l10n.paywallProYearly,
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
          monthlyPrice: l10n.paywallEliteMonthly,
          annualPrice: l10n.paywallEliteYearly,
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
          monthlyPrice: l10n.paywallClubMonthly,
          annualPrice: l10n.paywallClubYearly,
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
        const SizedBox(height: 8),
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
    return Container(
      color: const Color(0xFF0C0C0C),
      padding: EdgeInsets.only(
        top: 24,
        bottom: bottomPadding > 0 ? bottomPadding : 24,
      ),
      child: Center(
        child: GestureDetector(
          onTap: _onContinue,
          child: Container(
            width: 323,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Center(
              child: Text(
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
  final String monthlyPrice;
  final String annualPrice;
  final List<String> features;
  final bool showTrialBadge;
  final String? trialBadgeText;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.tierLabel,
    required this.tagline,
    required this.monthlyPrice,
    required this.annualPrice,
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

            // Price
            Text(
              monthlyPrice,
              style: const TextStyle(
                fontFamily: 'IBM Plex Sans',
                fontSize: 28,
                fontWeight: FontWeight.w600,
                height: 36 / 28,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),

            // Annual price
            Text(
              annualPrice,
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
