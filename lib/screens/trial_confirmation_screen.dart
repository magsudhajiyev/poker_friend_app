import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';
import '../design_system/constants/spacing.dart';
import '../design_system/constants/typography.dart';
import '../design_system/components/backgrounds/gradient_background.dart';
import '../design_system/components/buttons/close_circle_button.dart';

/// Intermediate screen shown after the user taps a tier CTA on the paywall.
/// Explains the free-trial timeline (Today → reminder → billing) and lets the
/// user confirm or go back.
class TrialConfirmationScreen extends StatelessWidget {
  final String tierLabel;
  final Color accentColor;
  final String monthlyPrice;
  final String annualPrice;

  const TrialConfirmationScreen({
    super.key,
    required this.tierLabel,
    required this.accentColor,
    required this.monthlyPrice,
    required this.annualPrice,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = (screenWidth * 0.06).clamp(16.0, 28.0);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        children: [
          const GradientBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      AppSpacing.xl,
                      horizontalPadding,
                      AppSpacing.bottomPadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTierBadge(),
                        SizedBox(height: AppSpacing.xl),
                        _buildTitle(l10n),
                        SizedBox(height: AppSpacing.xxxl + 8),
                        _buildTimeline(l10n),
                        const Padding(padding: EdgeInsets.only(top: 48)),
                        _buildPriceSummary(l10n),
                        SizedBox(height: AppSpacing.md),
                        _buildCtaButton(context, l10n),
                        SizedBox(height: AppSpacing.xs),
                        _buildDisclaimer(l10n),
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

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          CloseCircleButton(onTap: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }

  Widget _buildTierBadge() {
    return Text(
      tierLabel,
      style: AppTypography.sectionHeader(color: accentColor).copyWith(
        fontSize: 14,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildTitle(AppLocalizations l10n) {
    return Text(
      l10n.trialConfirmTitle(tierLabel),
      style: AppTypography.pageTitleLarge(),
    );
  }

  Widget _buildTimeline(AppLocalizations l10n) {
    final steps = [
      _TimelineStep(
        icon: Icons.check_circle,
        title: l10n.trialConfirmTodayTitle,
        body: l10n.trialConfirmTodayBody(tierLabel),
        accentColor: accentColor,
      ),
      _TimelineStep(
        icon: Icons.notifications_outlined,
        title: l10n.trialConfirmReminderTitle,
        body: l10n.trialConfirmReminderBody,
        accentColor: accentColor,
      ),
      _TimelineStep(
        icon: Icons.star_outline,
        title: l10n.trialConfirmStartTitle,
        body: l10n.trialConfirmStartBody,
        accentColor: accentColor,
      ),
    ];

    return Column(
      children: List.generate(steps.length, (i) {
        final step = steps[i];
        final isLast = i == steps.length - 1;
        return _buildTimelineRow(step, isLast);
      }),
    );
  }

  Widget _buildTimelineRow(_TimelineStep step, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left rail: icon + connector line
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: step.accentColor.withValues(alpha: 0.15),
                    border: Border.all(
                      color: step.accentColor.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    step.icon,
                    color: step.accentColor,
                    size: 18,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            step.accentColor.withValues(alpha: 0.5),
                            step.accentColor.withValues(alpha: 0.1),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.md),
          // Right side: text content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text(
                    step.title,
                    style: AppTypography.bodyLarge(color: Colors.white)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: AppSpacing.xxxs),
                  Text(
                    step.body,
                    style: AppTypography.bodyMedium(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSummary(AppLocalizations l10n) {
    return Center(
      child: Column(
        children: [
          Text(
            l10n.trialConfirmPriceSummary,
            style: AppTypography.bodyMedium(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          SizedBox(height: AppSpacing.xxxs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                annualPrice,
                style: AppTypography.bodyLarge(color: Colors.white).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
              SizedBox(width: AppSpacing.xxs),
              Text(
                '($monthlyPrice)',
                style: AppTypography.bodyMedium(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCtaButton(BuildContext context, AppLocalizations l10n) {
    return GestureDetector(
      onTap: () {
        // TODO: wire to RevenueCat purchase flow
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.paywallComingSoon(tierLabel)),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: accentColor,
          borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xxxl,
          vertical: AppSpacing.sm,
        ),
        child: Center(
          child: Text(
            l10n.trialConfirmStartCta,
            style: AppTypography.buttonText(color: Colors.black),
          ),
        ),
      ),
    );
  }

  Widget _buildDisclaimer(AppLocalizations l10n) {
    return Center(
      child: Text(
        l10n.trialConfirmDisclaimer,
        style: AppTypography.bodySmall(
          color: Colors.white.withValues(alpha: 0.5),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _TimelineStep {
  final IconData icon;
  final String title;
  final String body;
  final Color accentColor;

  const _TimelineStep({
    required this.icon,
    required this.title,
    required this.body,
    required this.accentColor,
  });
}
