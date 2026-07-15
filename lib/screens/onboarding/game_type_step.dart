import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../design_system/constants/colors.dart';
import '../../l10n/app_localizations.dart';
import '../../design_system/constants/typography.dart';
import '../../design_system/constants/decorations.dart';
import 'onboarding_scaffold.dart';
import 'step_reveal.dart';

class GameTypeStep extends StatefulWidget {
  final ValueChanged<String> onContinue;
  final VoidCallback? onBack;

  const GameTypeStep({super.key, required this.onContinue, this.onBack});

  @override
  State<GameTypeStep> createState() => _GameTypeStepState();
}

class _GameTypeStepState extends State<GameTypeStep>
    with AutomaticKeepAliveClientMixin {
  String? _selected;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);

    return OnboardingScaffold(
      currentStep: 2,
      onBack: widget.onBack,
      onContinue:
          _selected != null ? () => widget.onContinue(_selected!) : null,
      continueLabel: l10n.onboardingContinue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Figma anchors the title at ~50%-153.5px on an 852-tall frame,
          // i.e. slightly above the vertical center. A larger top spacer
          // than bottom pushes the block down from just under the
          // progress bar into that upper-mid position.
          const SizedBox(height: 96),
          StepReveal(
            children: [
              Text(
                l10n.onboardingGameTypeTitle,
                textAlign: TextAlign.center,
                style: AppTypography.ibm(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: -1.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.onboardingGameTypeSubtitle,
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _GameTypePill(
                      label: l10n.onboardingGameTypeCash,
                      iconAsset: 'icons/figma_icons/cash.svg',
                      isSelected: _selected == 'cash',
                      onTap: () => setState(() => _selected = 'cash'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _GameTypePill(
                      label: l10n.onboardingGameTypeTournament,
                      iconAsset: 'assets/icons/Trophy.svg',
                      isSelected: _selected == 'tournament',
                      onTap: () =>
                          setState(() => _selected = 'tournament'),
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

/// Pill option — Figma node 1919:15983 (unselected) / 1919:15984 (selected).
///
/// Unselected: transparent fill, 1px `borderStrong`.
/// Selected:   `bgSurface` fill, 2px `accentSecondary`.
/// 18h / 12v padding, 6px gap, 24px icon, 15px Medium label.
class _GameTypePill extends StatelessWidget {
  final String label;
  final String iconAsset;
  final bool isSelected;
  final VoidCallback onTap;

  const _GameTypePill({
    required this.label,
    required this.iconAsset,
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              iconAsset,
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(
                AppColors.accentSecondary,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
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
          ],
        ),
      ),
    );
  }
}
