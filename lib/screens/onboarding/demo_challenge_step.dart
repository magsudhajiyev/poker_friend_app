import 'package:flutter/material.dart';

import '../../design_system/constants/colors.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../services/coach_persona.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/daily_challenge_store.dart';
import '../../services/authored_tree_service.dart';
import '../training/authored_challenge_screen.dart';
import '../training/drill_table_screen.dart';
import 'onboarding_scaffold.dart';
import 'step_reveal.dart';

/// Onboarding "value-first" demo: ONE Daily Challenge spot, played before the
/// paywall so a first-time user makes a real poker decision and gets instant
/// coaching. It reuses today's spot #1 — the authored solver hand when the day
/// is scheduled, else the RNG preflop drill — and is purely a teaser: the
/// result is discarded (no store write, no streak, no leaderboard). "Play a
/// hand" launches it; "Skip for now" moves on. Either way the flow advances.
///
/// This step is only inserted into [OnboardingFlow] when the `daily_challenge`
/// feature flag is on, so an unscheduled/flag-off build simply omits it.
class DemoChallengeStep extends StatefulWidget {
  /// Advance to the next onboarding step. Called after the demo finishes OR
  /// when the user skips.
  final VoidCallback onContinue;
  final VoidCallback? onBack;

  const DemoChallengeStep({super.key, required this.onContinue, this.onBack});

  @override
  State<DemoChallengeStep> createState() => _DemoChallengeStepState();
}

class _DemoChallengeStepState extends State<DemoChallengeStep> {
  bool _launching = false;

  Future<void> _playDemo() async {
    if (_launching) return;
    setState(() => _launching = true);
    try {
      final config = DailyChallengeService.configFor(DailyChallengeService.today());
      final dayKey = DailyChallengeStore.dayKey(config.day);
      final persona = await CoachPersonas.load();
      // Scheduled day → the first authored solver hand; otherwise ONE RNG
      // preflop decision. We never persist the outcome — this is a taster.
      final trees = await AuthoredTreeService.loadDay(dayKey);
      if (!mounted) return;
      if (trees != null && trees.isNotEmpty) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AuthoredDayRunner(
              trees: [trees.first],
              persona: persona,
              dayKey: dayKey,
              // Demo has no results screen after it → the final button just
              // finishes and advances the onboarding flow.
              lastHandLabel: AppLocalizations.of(context).onboardingDemoDone,
            ),
          ),
        );
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DrillTableScreen(
              seats: DailyChallengeService.seatsFor(config),
              stackBB: config.stackBB,
              anteMode: config.anteMode,
              challengeConfig: config,
              challengeDecisions: 1,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _launching = false);
    }
    if (mounted) widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return OnboardingScaffold(
      currentStep: 2,
      onBack: widget.onBack,
      onContinue: _launching ? null : _playDemo,
      continueLabel: l10n.onboardingDemoPlay,
      scrollable: false,
      secondaryAction: GestureDetector(
        onTap: _launching ? null : widget.onContinue,
        child: Text(
          l10n.onboardingDemoSkip,
          style: AppTypography.ibm(
            fontSize: 15,
            color: AppColors.textSecondary,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.textSecondary,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(flex: 4),
          StepReveal(
            stagger: const Duration(milliseconds: 120),
            children: [
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppColors.accentPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(
                      color: AppColors.accentPrimary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Icon(
                    Icons.sports_esports_outlined,
                    size: 40,
                    color: AppColors.accentPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                l10n.onboardingDemoTitle,
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
                l10n.onboardingDemoSubtitle,
                textAlign: TextAlign.center,
                style: AppTypography.ibm(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  height: 1.3,
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
