import 'package:flutter/material.dart';
import '../../design_system/constants/colors.dart';
import '../../l10n/app_localizations.dart';
import '../../design_system/constants/typography.dart';
import '../../design_system/constants/decorations.dart';
import 'onboarding_scaffold.dart';

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

    return OnboardingScaffold(
      currentStep: 6,
      totalSteps: 6,
      onBack: widget.onBack,
      onContinue: _selected.isNotEmpty
          ? () => widget.onContinue(_selected.toList())
          : null,
      continueLabel: l10n.onboardingGetStarted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          Text(
            l10n.onboardingPurposeTitle,
            textAlign: TextAlign.left,
            style: AppTypography.ibm(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.15,
              letterSpacing: -1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.onboardingPurposeSubtitle,
            textAlign: TextAlign.left,
            style: AppTypography.ibm(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.5,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 32),
          ...options.map((option) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CheckCard(
                  label: option.$2,
                  isSelected: _selected.contains(option.$1),
                  onTap: () => _toggle(option.$1),
                ),
              )),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _CheckCard extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CheckCard({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
          border: Border.all(
            color: isSelected
                ? AppColors.accentPrimary
                : AppColors.borderStrong,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.ibm(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            // Checkbox indicator
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? AppColors.accentPrimary
                      : AppColors.borderStrong,
                  width: 2,
                ),
                color: isSelected
                    ? AppColors.accentPrimary
                    : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: AppColors.textInverse,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
