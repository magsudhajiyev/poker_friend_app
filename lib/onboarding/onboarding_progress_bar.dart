import 'package:flutter/material.dart';
import '../design_system/constants/typography.dart';
import '../l10n/app_localizations.dart';
import 'onboarding_state.dart';
import '../design_system/constants/colors.dart';

/// Morphing-pill onboarding progress indicator.
///
/// Renders one indicator per step in a horizontal row. Each step is either:
///   - a small green filled dot (completed step)
///   - a wide green pill (current step)
///   - a small muted-white outlined dot (upcoming step)
///
/// The active pill and adjacent dots animate their width, colour, and
/// opacity with an ease-out-back curve, so a step change reads as the pill
/// smoothly "sliding" between positions rather than snapping.
///
/// Only renders while [OnboardingState.isOnboardingActive]. Listens to
/// [OnboardingState.notifier] so it self-rebuilds on step/skip/cancel.
class OnboardingProgressBar extends StatelessWidget {
  const OnboardingProgressBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: OnboardingState.notifier,
      builder: (context, _, __) {
        if (!OnboardingState.isOnboardingActive) return const SizedBox.shrink();

        final step = OnboardingState.displayStep;
        final total = OnboardingState.displayTotalSteps;

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _StepIndicators(total: total, current: step),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).onboardingStepOf(step, total),
                style: AppTypography.bodySmall(
                  color: Colors.white.withOpacity(0.54),
                ).copyWith(fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StepIndicators extends StatelessWidget {
  final int total;
  final int current;

  const _StepIndicators({required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 8,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: List.generate(total, (i) {
          final index = i + 1;
          final isActive = index == current;
          final isDone = index < current;

          return Padding(
            padding: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              width: isActive ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.accentPrimary
                    : isDone
                        ? AppColors.accentPrimary.withOpacity(0.65)
                        : Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(4),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.accentPrimary.withOpacity(0.35),
                          blurRadius: 8,
                          spreadRadius: 0.5,
                        ),
                      ]
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }
}
