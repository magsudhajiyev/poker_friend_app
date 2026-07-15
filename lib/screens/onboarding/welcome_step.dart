import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import 'onboarding_scaffold.dart';
import 'step_reveal.dart';

class WelcomeStep extends StatelessWidget {
  final VoidCallback onContinue;

  const WelcomeStep({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return OnboardingScaffold(
      currentStep: 1,
      onBack: null,
      onContinue: onContinue,
      continueLabel: l10n.onboardingContinue,
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Figma anchors the block at ~50% minus 97px, i.e. slightly
          // above the vertical center. The 4:5 spacer ratio matches.
          const Spacer(flex: 4),
          StepReveal(
            stagger: const Duration(milliseconds: 120),
            children: [
              // Logo — Figma node 1919:15903, 84×84 rounded card, 19.09px
              // radius, 0.627px white border already baked into the SVG.
              Center(
                child: SvgPicture.asset(
                  'assets/icons/card icons/Group 8.svg',
                  width: 84,
                  height: 84,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                l10n.onboardingWelcomeTitle,
                textAlign: TextAlign.center,
                style: AppTypography.ibm(
                  fontSize: 44,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.14,
                  letterSpacing: -0.88,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.onboardingWelcomeSubtitle,
                textAlign: TextAlign.center,
                style: AppTypography.ibm(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  height: 1.6,
                  letterSpacing: -0.34,
                ),
              ),
            ],
          ),
          const Spacer(flex: 5),
        ],
      ),
    );
  }
}
