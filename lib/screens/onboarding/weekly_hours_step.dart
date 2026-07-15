import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../design_system/constants/colors.dart';
import '../../l10n/app_localizations.dart';
import '../../design_system/constants/typography.dart';
import 'onboarding_scaffold.dart';
import 'step_reveal.dart';

class WeeklyHoursStep extends StatefulWidget {
  final ValueChanged<int> onContinue;
  final VoidCallback? onBack;

  const WeeklyHoursStep({super.key, required this.onContinue, this.onBack});

  @override
  State<WeeklyHoursStep> createState() => _WeeklyHoursStepState();
}

class _WeeklyHoursStepState extends State<WeeklyHoursStep>
    with AutomaticKeepAliveClientMixin {
  // Values: 1 through 50
  static final _values = List.generate(50, (i) => i + 1);
  int _selectedIndex = 7; // Default: 8 sessions

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);

    return OnboardingScaffold(
      currentStep: 5,
      onBack: widget.onBack,
      onContinue: () => widget.onContinue(_values[_selectedIndex]),
      continueLabel: l10n.onboardingContinue,
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 96),
          StepReveal(
            children: [
              Text(
                l10n.onboardingMonthlySessionsTitle,
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
                l10n.onboardingMonthlySessionsSubtitle,
                textAlign: TextAlign.center,
                style: AppTypography.ibm(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  height: 1.5,
                  letterSpacing: -0.45,
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            height: 200,
            child: CupertinoPicker(
              scrollController: FixedExtentScrollController(
                initialItem: _selectedIndex,
              ),
              itemExtent: 50,
              magnification: 1.2,
              squeeze: 0.9,
              useMagnifier: true,
              selectionOverlay: Container(
                decoration: const BoxDecoration(
                  border: Border.symmetric(
                    horizontal: BorderSide(
                      color: AppColors.borderStrong,
                      width: 1,
                    ),
                  ),
                ),
              ),
              onSelectedItemChanged: (index) {
                setState(() => _selectedIndex = index);
              },
              children: _values.map((value) {
                return Center(
                  child: Text(
                    '$value',
                    style: AppTypography.ibm(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              l10n.onboardingMonthlySessionsUnit,
              style: AppTypography.ibm(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
