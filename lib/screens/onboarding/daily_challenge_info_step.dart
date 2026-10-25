import 'package:flutter/material.dart';

import '../../design_system/constants/colors.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import 'onboarding_scaffold.dart';
import 'step_reveal.dart';

/// The LAST onboarding step: after the demo spot, explain the ongoing Daily
/// Challenge ritual — 5 spots a day, tuned to the player's experience level,
/// with the coaches explaining the lines. Continuing finishes onboarding and
/// hands off to Home + the in-app tour.
class DailyChallengeInfoStep extends StatelessWidget {
  /// Finish onboarding → Home + tour.
  final VoidCallback onContinue;
  final VoidCallback? onBack;

  const DailyChallengeInfoStep(
      {super.key, required this.onContinue, this.onBack});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OnboardingScaffold(
      currentStep: 3,
      onBack: onBack,
      onContinue: onContinue,
      continueLabel: l10n.onboardingDcInfoContinue,
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(flex: 3),
          StepReveal(
            stagger: const Duration(milliseconds: 120),
            children: [
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppColors.accentPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(
                      color: AppColors.accentPrimary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Icon(
                    Icons.calendar_today_outlined,
                    size: 38,
                    color: AppColors.accentPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                l10n.onboardingDcInfoTitle,
                textAlign: TextAlign.center,
                style: AppTypography.ibm(
                  fontSize: 36,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.14,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.onboardingDcInfoSubtitle,
                textAlign: TextAlign.center,
                style: AppTypography.ibm(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 28),
              _bullet(Icons.grid_view_rounded, l10n.onboardingDcInfoBullet1),
              const SizedBox(height: 14),
              _bullet(Icons.insights_rounded, l10n.onboardingDcInfoBullet2),
              const SizedBox(height: 14),
              _bullet(Icons.record_voice_over_rounded,
                  l10n.onboardingDcInfoBullet3),
            ],
          ),
          const Spacer(flex: 4),
        ],
      ),
    );
  }

  Widget _bullet(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.accentPrimary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 19, color: AppColors.accentPrimary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              text,
              style: AppTypography.ibm(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Colors.white,
                height: 1.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
