import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';
import '../design_system/constants/spacing.dart';
import '../design_system/constants/typography.dart';
import '../design_system/components/backgrounds/gradient_background.dart';
import '../services/subscription_service.dart';
import 'trial_confirmation_screen.dart';

/// Paywall screen for displaying subscription options.
///
/// V1 launch version: shows a two-tier layout (Pro + Club) with static
/// pricing. Both tiers currently map to the single `premium` entitlement
/// in RevenueCat — proper entitlement split will come with dashboard
/// configuration work. CTA taps show a "Coming soon" snackbar until
/// RevenueCat products are published.
class PaywallScreen extends StatefulWidget {
  /// Optional feature name that triggered the paywall.
  /// Shown in the subtitle (e.g. "AI Hand Analysis is a premium feature").
  final String? featureName;

  const PaywallScreen({super.key, this.featureName});

  /// Show the paywall as a full-screen route.
  ///
  /// Returns `true` if the user successfully upgraded (reserved for future
  /// use — currently always returns `null` until purchase flow is wired).
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
  bool _isRestoring = false;

  Future<void> _restorePurchases() async {
    setState(() => _isRestoring = true);
    final success = await SubscriptionService.restorePurchases();
    if (!mounted) return;
    setState(() => _isRestoring = false);

    if (success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).paywallPurchasesRestored),
          backgroundColor: AppColors.limeGreen.withOpacity(0.2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).paywallNoPreviousPurchases),
        ),
      );
    }
  }

  void _showComingSoon(String tierLabel) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).paywallComingSoon(tierLabel)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showTrialConfirmation({
    required String tierLabel,
    required Color accentColor,
    required String monthlyPrice,
    required String annualPrice,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TrialConfirmationScreen(
          tierLabel: tierLabel,
          accentColor: accentColor,
          monthlyPrice: monthlyPrice,
          annualPrice: annualPrice,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Scale horizontal padding based on screen width so small phones
    // don't feel cramped and larger phones don't look stretched.
    final horizontalPadding = (screenWidth * 0.06).clamp(16.0, 28.0);

    return Scaffold(
      backgroundColor: AppColors.backgroundPaper,
      body: Stack(
        children: [
          const GradientBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      top: AppSpacing.md,
                      bottom: AppSpacing.bottomPadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                          ),
                          child: _buildHeader(),
                        ),
                        SizedBox(height: AppSpacing.xxxl),
                        _buildTierCarousel(),
                        SizedBox(height: AppSpacing.xl),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                          ),
                          child: _buildLegalFooter(),
                        ),
                      ],
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

  Widget _buildTopBar() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _TopBarIconButton(
            icon: Icons.close,
            onTap: () => Navigator.of(context).pop(),
          ),
          TextButton(
            onPressed: _isRestoring ? null : _restorePurchases,
            child: _isRestoring
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                    ),
                  )
                : Text(
                    l10n.paywallRestore,
                    style: AppTypography.bodyMedium(
                      color: AppColors.textSecondary,
                    ).copyWith(fontWeight: FontWeight.w500),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context);
    final title = widget.featureName != null
        ? l10n.paywallUnlockFeature(widget.featureName!)
        : l10n.paywallGoPremium;
    final subtitle = widget.featureName != null
        ? l10n.paywallFeatureSubtitle
        : l10n.paywallGeneralSubtitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.paywallTitle,
          style: AppTypography.sectionHeader(),
        ),
        SizedBox(height: AppSpacing.xs),
        Text(
          title,
          style: AppTypography.pageTitleLarge(),
        ),
        SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: AppTypography.bodyMedium(
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildTierCarousel() {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = (screenWidth * 0.06).clamp(16.0, 28.0);
    final cardWidth = screenWidth * 0.78;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildProTierCard(),
            ),
            SizedBox(width: AppSpacing.md),
            SizedBox(
              width: cardWidth,
              child: _buildEliteTierCard(),
            ),
            SizedBox(width: AppSpacing.md),
            SizedBox(
              width: cardWidth,
              child: _buildClubTierCard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProTierCard() {
    final l10n = AppLocalizations.of(context);
    return _TierCard(
      tierLabel: l10n.paywallProTier,
      accentColor: AppColors.buttonPrimary, // mint
      trialBadge: l10n.paywallFreeTrialBadge,
      tagline: l10n.paywallProDescription,
      features: [
        l10n.paywallUnlimitedHandLogging,
        l10n.paywallFullSessionHistory,
        l10n.paywallAiHandAnalysis,
        l10n.paywallExportHandsCsv,
      ],
      monthlyPrice: l10n.paywallProMonthly,
      annualPrice: l10n.paywallProYearly,
      ctaLabel: l10n.paywallStartFreeTrial,
      ctaBackgroundColor: Colors.white,
      ctaTextColor: Colors.black,
      isHighlighted: true,
      onTap: () => _showTrialConfirmation(
        tierLabel: l10n.paywallProTier,
        accentColor: AppColors.buttonPrimary,
        monthlyPrice: l10n.paywallProMonthly,
        annualPrice: l10n.paywallProYearly,
      ),
    );
  }

  Widget _buildEliteTierCard() {
    final l10n = AppLocalizations.of(context);
    return _TierCard(
      tierLabel: l10n.paywallEliteTier,
      accentColor: const Color(0xFFFFD700), // gold
      trialBadge: null,
      tagline: l10n.paywallEliteDescription,
      features: [
        l10n.paywallEverythingInProElite,
        l10n.paywallEliteFeature1,
        l10n.paywallEliteFeature2,
        l10n.paywallEliteFeature3,
      ],
      monthlyPrice: l10n.paywallEliteMonthly,
      annualPrice: l10n.paywallEliteYearly,
      ctaLabel: l10n.paywallGetElite,
      ctaBackgroundColor: const Color(0xFFFFD700),
      ctaTextColor: Colors.black,
      isHighlighted: false,
      onTap: () => _showTrialConfirmation(
        tierLabel: l10n.paywallEliteTier,
        accentColor: const Color(0xFFFFD700),
        monthlyPrice: l10n.paywallEliteMonthly,
        annualPrice: l10n.paywallEliteYearly,
      ),
    );
  }

  Widget _buildClubTierCard() {
    final l10n = AppLocalizations.of(context);
    return _TierCard(
      tierLabel: l10n.paywallClubTier,
      accentColor: AppColors.limeGreen,
      trialBadge: null,
      tagline: l10n.paywallClubDescription,
      features: [
        l10n.paywallEverythingInPro,
        l10n.paywallClubManagement,
        l10n.paywallLiveDealerVoice,
        l10n.paywallMultiTableEvents,
      ],
      monthlyPrice: l10n.paywallClubMonthly,
      annualPrice: l10n.paywallClubYearly,
      ctaLabel: l10n.paywallGetClub,
      ctaBackgroundColor: AppColors.limeGreen,
      ctaTextColor: Colors.black,
      isHighlighted: false,
      onTap: () => _showTrialConfirmation(
        tierLabel: l10n.paywallClubTier,
        accentColor: AppColors.limeGreen,
        monthlyPrice: l10n.paywallClubMonthly,
        annualPrice: l10n.paywallClubYearly,
      ),
    );
  }

  Widget _buildLegalFooter() {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Text(
          l10n.paywallDisclaimer,
          style: AppTypography.bodySmall(
            color: Colors.white.withOpacity(0.5),
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _FooterLink(
              label: l10n.paywallTerms,
              onTap: () {
                // TODO: link to ToS page (Week 2 task)
              },
            ),
            Text(
              '  ·  ',
              style: AppTypography.bodySmall(
                color: Colors.white.withOpacity(0.3),
              ),
            ),
            _FooterLink(
              label: l10n.paywallPrivacy,
              onTap: () {
                // TODO: link to privacy policy page (Week 2 task)
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// Top bar icon button — small circular glass button matching the rest
/// of the app's close/back affordances.
class _TopBarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopBarIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.iconButtonBg,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.whiteBorder(),
            width: AppDecorations.borderThin,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

/// Footer text link (Terms / Privacy).
class _FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FooterLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: AppTypography.bodySmall(
          color: AppColors.textSecondary,
        ).copyWith(
          decoration: TextDecoration.underline,
          decorationColor: AppColors.textSecondary.withOpacity(0.5),
        ),
      ),
    );
  }
}

/// A single tier card (Pro or Club).
///
/// Uses the app's glassmorphism style (BackdropFilter blur + white border)
/// with optional highlight variant for the recommended tier.
class _TierCard extends StatelessWidget {
  final String tierLabel;
  final Color accentColor;
  final String? trialBadge;
  final String tagline;
  final List<String> features;
  final String monthlyPrice;
  final String annualPrice;
  final String ctaLabel;
  final Color ctaBackgroundColor;
  final Color ctaTextColor;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _TierCard({
    required this.tierLabel,
    required this.accentColor,
    required this.trialBadge,
    required this.tagline,
    required this.features,
    required this.monthlyPrice,
    required this.annualPrice,
    required this.ctaLabel,
    required this.ctaBackgroundColor,
    required this.ctaTextColor,
    required this.isHighlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isHighlighted
        ? accentColor.withOpacity(0.6)
        : AppColors.whiteBorder(opacity: 0.12);
    final borderWidth = isHighlighted ? 1.5 : 1.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDecorations.modeCardRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: AppDecorations.blurLight,
          sigmaY: AppDecorations.blurLight,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundSurface.withOpacity(0.82),
            borderRadius: BorderRadius.circular(AppDecorations.modeCardRadius),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: isHighlighted
                ? [
                    BoxShadow(
                      color: accentColor.withOpacity(0.15),
                      blurRadius: 24,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTierHeader(),
              SizedBox(height: AppSpacing.xs),
              Text(
                tagline,
                style: AppTypography.bodyMedium(
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              SizedBox(height: AppSpacing.lg),
              ...features.map(_buildFeatureRow),
              SizedBox(height: AppSpacing.lg),
              _buildPricing(),
              SizedBox(height: AppSpacing.md),
              _buildCta(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTierHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          tierLabel,
          style: AppTypography.sectionHeader(color: accentColor).copyWith(
            fontSize: 14,
            letterSpacing: 1.5,
          ),
        ),
        const Spacer(),
        if (trialBadge != null)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xxxs + 1,
            ),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
              border: Border.all(
                color: accentColor.withOpacity(0.4),
                width: AppDecorations.borderThin,
              ),
            ),
            child: Text(
              trialBadge!,
              style: AppTypography.bodySmall(color: accentColor).copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                letterSpacing: 0.3,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFeatureRow(String feature) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.xxs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 18,
            color: accentColor,
          ),
          SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              feature,
              style: AppTypography.bodyMedium(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricing() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          monthlyPrice,
          style: AppTypography.bodyLarge(color: Colors.white).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(width: AppSpacing.xs),
        Text(
          '·',
          style: AppTypography.bodyLarge(
            color: Colors.white.withOpacity(0.4),
          ),
        ),
        SizedBox(width: AppSpacing.xs),
        Text(
          annualPrice,
          style: AppTypography.bodyLarge(
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildCta() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: ctaBackgroundColor,
          borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xxxl,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                ctaLabel,
                style: AppTypography.buttonText(color: ctaTextColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.arrow_forward,
              color: ctaTextColor,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
