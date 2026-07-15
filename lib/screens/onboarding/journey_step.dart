import 'package:flutter/material.dart';
import '../../design_system/constants/colors.dart';
import '../../l10n/app_localizations.dart';
import '../../design_system/constants/typography.dart';
import '../../design_system/constants/decorations.dart';
import 'onboarding_scaffold.dart';
import 'step_reveal.dart';

/// Onboarding step: pick self-described skill level.
///
/// Figma node 1919:17117 — centered title/subtitle followed by a 2×2
/// grid of borderless label pills. Selection styling mirrors
/// [game_type_step]: transparent + 1px `borderStrong` at rest,
/// `bgSurface` + 2px `accentSecondary` when active. Icons are omitted
/// per spec (labels only).
class JourneyStep extends StatefulWidget {
  final ValueChanged<String> onContinue;
  final VoidCallback? onBack;

  const JourneyStep({super.key, required this.onContinue, this.onBack});

  @override
  State<JourneyStep> createState() => _JourneyStepState();
}

class _JourneyStepState extends State<JourneyStep>
    with AutomaticKeepAliveClientMixin {
  String? _selected;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);

    return OnboardingScaffold(
      currentStep: 4,
      onBack: widget.onBack,
      onContinue:
          _selected != null ? () => widget.onContinue(_selected!) : null,
      continueLabel: l10n.onboardingContinue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 96),
          StepReveal(
            children: [
              Text(
                l10n.onboardingJourneyTitle,
                textAlign: TextAlign.center,
                style: AppTypography.ibm(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: -1.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.onboardingJourneySubtitle,
                textAlign: TextAlign.center,
                style: AppTypography.ibm(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  height: 1.5,
                  letterSpacing: -0.45,
                ),
              ),
              const SizedBox(height: 48),
              Row(
                children: [
                  Expanded(
                    child: _JourneyPill(
                      label: l10n.onboardingJourneyBeginner,
                      isSelected: _selected == 'beginner',
                      onTap: () => setState(() => _selected = 'beginner'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _JourneyPill(
                      label: l10n.onboardingJourneyFun,
                      isSelected: _selected == 'fun',
                      onTap: () => setState(() => _selected = 'fun'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _JourneyPill(
                      label: l10n.onboardingJourneyRegular,
                      isSelected: _selected == 'regular',
                      onTap: () => setState(() => _selected = 'regular'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _JourneyPill(
                      label: l10n.onboardingJourneyPro,
                      isSelected: _selected == 'pro',
                      onTap: () => setState(() => _selected = 'pro'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Label-only pill. Same visual system as `_GameTypePill` in
/// `game_type_step.dart`; kept local to avoid a premature abstraction.
class _JourneyPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _JourneyPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.bgSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
          border: Border.all(
            color: isSelected
                ? AppColors.accentSecondary
                : AppColors.borderStrong,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.ibm(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            height: 1.6,
            letterSpacing: -0.45,
          ),
        ),
      ),
    );
  }
}
