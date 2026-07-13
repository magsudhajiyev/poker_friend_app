import 'package:flutter/material.dart';
import '../../design_system/constants/colors.dart';
import '../../l10n/app_localizations.dart';
import '../../design_system/constants/typography.dart';
import '../../design_system/constants/decorations.dart';
import 'onboarding_scaffold.dart';

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

    final options = [
      ('beginner', l10n.onboardingJourneyBeginner),
      ('fun', l10n.onboardingJourneyFun),
      ('regular', l10n.onboardingJourneyRegular),
      ('pro', l10n.onboardingJourneyPro),
    ];

    return OnboardingScaffold(
      currentStep: 4,
      onBack: widget.onBack,
      onContinue:
          _selected != null ? () => widget.onContinue(_selected!) : null,
      continueLabel: l10n.onboardingContinue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          Text(
            l10n.onboardingJourneyTitle,
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
            l10n.onboardingJourneySubtitle,
            textAlign: TextAlign.left,
            style: AppTypography.ibm(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.5,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 40),
          ...options.map((option) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _OptionCard(
                  label: option.$2,
                  isSelected: _selected == option.$1,
                  onTap: () => setState(() => _selected = option.$1),
                ),
              )),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionCard({
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
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.accentPrimary
                      : AppColors.borderStrong,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accentPrimary,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
