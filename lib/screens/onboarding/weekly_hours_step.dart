import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/components/backgrounds/gradient_background.dart';
import '../../l10n/app_localizations.dart';
import '../../design_system/constants/typography.dart';

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
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        const GradientBackground(),
        Positioned.fill(
          child: Opacity(
            opacity: 0.4,
            child: Image.asset(
              'assets/main_background.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      if (widget.onBack != null)
                        _buildBackChevron(widget.onBack!),
                      const SizedBox(height: 16),
                      Text(
                        l10n.onboardingMonthlySessionsTitle,
                        style: AppTypography.ibm(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.onboardingMonthlySessionsSubtitle,
                        style: AppTypography.ibm(
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textDisabled,
                          height: 1.5,
                        ),
                      ),
                      const Spacer(),
                      // Wheel picker
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
                            decoration: BoxDecoration(
                              border: Border.symmetric(
                                horizontal: BorderSide(
                                  color:
                                      Colors.white.withValues(alpha: 0.15),
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
                            color: AppColors.textDisabled,
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  0,
                  24,
                  bottomPadding > 0 ? bottomPadding + 16 : 40,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () =>
                        widget.onContinue(_values[_selectedIndex]),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.bgPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(110),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      l10n.onboardingContinue,
                      style: AppTypography.ibm(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.bgPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackChevron(VoidCallback onTap) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}
