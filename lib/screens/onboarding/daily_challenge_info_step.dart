import 'dart:async';

import 'package:flutter/material.dart';

import '../../design_system/constants/colors.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../services/username_service.dart';
import '../../widgets/onboarding/sample_leaderboard_card.dart';
import '../../widgets/onboarding/streak_flame_strip.dart';
import 'onboarding_scaffold.dart';
import 'step_reveal.dart';

/// The LAST onboarding step, shown right after the example challenge: pitch
/// the daily ritual ("come back daily, build a streak, climb the board") with
/// the streak-flame and sample-leaderboard animations. The earlier 3 bullets
/// now live in the previous screen's "How it works" block, so only the
/// subtitle line remains here. Continuing finishes onboarding and hands off
/// to Home + the in-app tour.
class DailyChallengeInfoStep extends StatefulWidget {
  /// Finish onboarding → Home + tour.
  final VoidCallback onContinue;
  final VoidCallback? onBack;

  const DailyChallengeInfoStep(
      {super.key, required this.onContinue, this.onBack});

  @override
  State<DailyChallengeInfoStep> createState() => _DailyChallengeInfoStepState();
}

class _DailyChallengeInfoStepState extends State<DailyChallengeInfoStep> {
  String? _username; // best-effort; null → localized "You"

  // Staggered: streak fills first (~1 s), then the board appears and climbs.
  static const _streakDelay = Duration(milliseconds: 250);
  static const _boardDelay = Duration(milliseconds: 1000);

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    try {
      final name = (await UsernameService.getUsername()
              .timeout(const Duration(seconds: 2)))
          ?.trim();
      if (mounted && name != null && name.isNotEmpty) {
        setState(() => _username = name);
      }
    } catch (_) {
      // Best-effort: keep the localized "You".
    }
  }

  List<String> _weekdayLetters(BuildContext context) {
    final m = MaterialLocalizations.of(context);
    final first = m.firstDayOfWeekIndex; // 0 = Sunday
    return [for (var i = 0; i < 7; i++) m.narrowWeekdays[(first + i) % 7]];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final w = MediaQuery.sizeOf(context).width;
    return OnboardingScaffold(
      currentStep: 3,
      onBack: widget.onBack,
      onContinue: widget.onContinue,
      continueLabel: l10n.onboardingDcInfoContinue,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StepReveal(
            stagger: const Duration(milliseconds: 120),
            children: [
              Text(
                l10n.onboardingDcInfoTitle,
                textAlign: TextAlign.center,
                style: AppTypography.ibm(
                  fontSize: (w * 0.09).clamp(30.0, 36.0),
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.14,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                l10n.onboardingDcInfoSubtitle,
                textAlign: TextAlign.center,
                style: AppTypography.ibm(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          StreakFlameStrip(
            startDelay: _streakDelay,
            header: l10n.onbStreakHeader,
            caption: l10n.onbStreakCaption,
            weekdayLetters: _weekdayLetters(context),
            semanticsLabel: l10n.onbStreakSemantics,
          ),
          const SizedBox(height: AppSpacing.md),
          SampleLeaderboardCard(
            startDelay: _boardDelay,
            header: l10n.onbLeaderboardHeader,
            youLabel: _username ?? l10n.onbLeaderboardYou,
            playerLabel: (letter) => l10n.onbSamplePlayer(letter),
            semanticsLabel: l10n.onbLeaderboardSemantics,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
