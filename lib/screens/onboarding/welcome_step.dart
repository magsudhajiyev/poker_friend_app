import 'package:flutter/material.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/components/backgrounds/gradient_background.dart';
import '../../l10n/app_localizations.dart';
import '../../design_system/constants/typography.dart';

class WelcomeStep extends StatelessWidget {
  final VoidCallback onContinue;

  const WelcomeStep({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        const GradientBackground(),
        // Background poker chip image
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
              const Spacer(flex: 3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.onboardingWelcomeTitle,
                      style: AppTypography.ibm(
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.1,
                        letterSpacing: -1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.onboardingWelcomeSubtitle,
                      style: AppTypography.ibm(
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textDisabled,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              // Continue button
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
                    onPressed: onContinue,
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
}
