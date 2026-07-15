import 'package:flutter/material.dart';
import '../../design_system/constants/colors.dart';
import '../../l10n/app_localizations.dart';
import '../../design_system/constants/typography.dart';
import '../../design_system/constants/decorations.dart';
import 'onboarding_scaffold.dart';
import 'step_reveal.dart';

/// Onboarding step: multi-select of primary use-cases.
///
/// Matches the visual system of the game-type and journey steps —
/// centered 28/w600 title, 15/w400 centered subtitle, and full-width
/// label pills (transparent + 1px `borderStrong` at rest, `bgSurface`
/// + 2px `accentSecondary` when selected). No checkbox indicator; the
/// border colour communicates selection, consistent with the rest of
/// the flow.
class PurposeStep extends StatefulWidget {
  final ValueChanged<List<String>> onContinue;
  final VoidCallback? onBack;

  const PurposeStep({super.key, required this.onContinue, this.onBack});

  @override
  State<PurposeStep> createState() => _PurposeStepState();
}

class _PurposeStepState extends State<PurposeStep>
    with AutomaticKeepAliveClientMixin {
  final Set<String> _selected = {};

  @override
  bool get wantKeepAlive => true;

  void _toggle(String key) {
    setState(() {
      if (_selected.contains(key)) {
        _selected.remove(key);
      } else {
        _selected.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);

    final options = [
      ('logging', l10n.onboardingPurposeLogging),
      ('bankroll', l10n.onboardingPurposeBankroll),
      ('opponents', l10n.onboardingPurposeOpponents),
      ('actions', l10n.onboardingPurposeActions),
      ('studying', l10n.onboardingPurposeStudying),
      ('sharing', l10n.onboardingPurposeSharing),
      ('ai', l10n.onboardingPurposeAi),
      ('export', l10n.onboardingPurposeExport),
      ('stacks', l10n.onboardingPurposeStacks),
    ];

    final continueLabel = _selected.isEmpty
        ? l10n.onboardingGetStarted
        : '${l10n.onboardingGetStarted} (${_selected.length})';

    return OnboardingScaffold(
      currentStep: 6,
      totalSteps: 6,
      onBack: widget.onBack,
      onContinue: _selected.isNotEmpty
          ? () => widget.onContinue(_selected.toList())
          : null,
      continueLabel: continueLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          StepReveal(
            // 9 items with a 60ms stagger + 380ms per item ≈ 920ms
            // total — reads as a satisfying cascade without dragging.
            stagger: const Duration(milliseconds: 60),
            itemDuration: const Duration(milliseconds: 380),
            children: [
              Text(
                l10n.onboardingPurposeTitle,
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
                l10n.onboardingPurposeSubtitle,
                textAlign: TextAlign.center,
                style: AppTypography.ibm(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  height: 1.5,
                  letterSpacing: -0.45,
                ),
              ),
              const SizedBox(height: 32),
              for (final option in options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PurposePill(
                    label: option.$2,
                    isSelected: _selected.contains(option.$1),
                    onTap: () => _toggle(option.$1),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Full-width label pill — same visual system as the `_GameTypePill` /
/// `_JourneyPill`, kept local (three near-identical variants across
/// the flow; will consolidate if a fourth caller appears).
class _PurposePill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PurposePill({
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
          color: isSelected
              ? AppColors.accentSecondary.withValues(alpha: 0.12)
              : Colors.transparent,
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
