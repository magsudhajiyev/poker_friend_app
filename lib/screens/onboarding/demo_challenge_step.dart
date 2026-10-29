import 'dart:async';

import 'package:flutter/material.dart';

import '../../design_system/components/headers/section_header.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../services/coach_persona.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/daily_challenge_store.dart';
import '../../services/logger_service.dart';
import '../../services/authored_tree_service.dart';
import '../training/authored_challenge_screen.dart';
import '../training/drill_table_screen.dart';
import '../../widgets/onboarding/challenge_facts_row.dart';
import '../../widgets/onboarding/coach_trio.dart';
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
  CoachPersona? _selected; // null until the saved persona has loaded
  bool _precached = false;
  static const _factsDelay = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    CoachPersonas.load().then((p) {
      if (mounted) setState(() => _selected ??= p);
    }).catchError((Object e) {
      LoggerService.log('DemoChallengeStep: persona load failed: $e',
          level: LogLevel.WARNING);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    CoachTrio.precache(context);
  }

  void _pick(CoachPersona p) {
    setState(() => _selected = p);
    CoachPersonas.save(p);
  }

  Future<void> _playDemo() async {
    if (_launching) return;
    setState(() => _launching = true);
    try {
      final config =
          DailyChallengeService.configFor(DailyChallengeService.today());
      final dayKey = DailyChallengeStore.dayKey(config.day);
      final persona = _selected ?? await CoachPersonas.load();
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
      scrollable: true,
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
      child: _body(context, l10n),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n) {
    final w = MediaQuery.sizeOf(context).width;
    final selected = _selected;
    const gap = SizedBox(height: AppSpacing.md);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepReveal(
          stagger: const Duration(milliseconds: 120),
          children: [
            Text(
              l10n.onboardingDemoTitle,
              textAlign: TextAlign.center,
              style: AppTypography.ibm(
                fontSize: (w * 0.09).clamp(34.0, 36.0),
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.14,
                letterSpacing: -0.7,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
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
        gap,
        SectionHeader(title: l10n.onbCoachesHeader),
        const SizedBox(height: AppSpacing.xs),
        CoachTrio(
          selected: selected ?? CoachPersonas.grinder,
          onPick: _pick,
          hint: l10n.onbCoachesHint,
          tagsById: {
            CoachPersonas.grinder.id: l10n.onbCoachTagDuke,
            CoachPersonas.professor.id: l10n.onbCoachTagVega,
            CoachPersonas.nova.id: l10n.onbCoachTagNova,
          },
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: AppDecorations.borderThin,
            ),
            borderRadius: BorderRadius.circular(AppDecorations.cardRadius),
          ),
          child: ChallengeFactsRow(
            header: l10n.onbFactsHeader,
            startDelay: _factsDelay,
            facts: [
              (Icons.groups_outlined, l10n.onbFactSpots),
              (Icons.record_voice_over_outlined, l10n.onbFactCoach),
              (Icons.looks_one_outlined, l10n.onbFactOnce),
            ],
            bodies: [
              l10n.onbFactSpotsBody,
              l10n.onbFactCoachBody,
              l10n.onbFactOnceBody,
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}
