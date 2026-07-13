import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import 'onboarding_scaffold.dart';

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
          // Figma places the logo at ~47% down the screen. Smaller top flex
          // pushes content up so the layout matches.
          const Spacer(flex: 4),
          // Logo — Figma node 1822:14020. The SVG already ships the
          // 56×56 bgPrimary rounded rectangle, the 1.27px white border,
          // and the "final table" wordmark, so we render it directly at
          // its intrinsic size without any wrapper.
          Center(
            child: SvgPicture.asset(
              'assets/icons/card icons/Group 8.svg',
              width: 56,
              height: 56,
            ),
          ),
          const SizedBox(height: 36),
          Text(
            l10n.onboardingWelcomeTitle,
            textAlign: TextAlign.center,
            style: AppTypography.ibm(
              fontSize: 44,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.1,
              letterSpacing: -2.2,
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
              height: 1.5,
              letterSpacing: -0.85,
            ),
          ),
          const Spacer(flex: 5),
        ],
      ),
    );
  }
}
