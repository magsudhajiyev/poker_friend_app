import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/constants/colors.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../models/drill_models.dart';
import '../../services/analytics_service.dart';
import '../../services/authored_tree_service.dart';
import '../../services/coach_persona.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/daily_challenge_store.dart';
import '../../widgets/daily_result_breakdown.dart';
import 'authored_challenge_screen.dart';
import 'drill_table_screen.dart';

/// REPLAY of a past Daily Challenge day — unranked practice.
///
/// Plays the EXACT spots for [day] (the construction is a pure function of the
/// date, so an old day reproduces precisely), grades them with the same coach
/// grader, and shows the accuracy + per-hand breakdown — but writes NOTHING:
/// no store save, no streak change, no leaderboard submit. This is deliberate
/// (user decision 2026-10-22: replays are unranked, non-counting), and also
/// necessary because streaks are derived from saved results — persisting a
/// back-dated result would retroactively alter the player's streak.
///
/// Tier gating (who may open this, and how far back) lives in
/// `DailyReplayLimits` and is enforced by the caller (the replay calendar).
class DailyReplayScreen extends StatefulWidget {
  /// The past day to replay (date-only, local).
  final DateTime day;

  /// A known result for this day — the stored (ranked) result, or one from an
  /// earlier replay this session. When present, the screen opens straight on
  /// the street-by-street results view (not the intro), so re-opening a day
  /// already played shows the breakdown instead of restarting. The user can
  /// still tap Replay to run it again.
  final DailyChallengeResult? initialResult;

  const DailyReplayScreen({super.key, required this.day, this.initialResult});

  @override
  State<DailyReplayScreen> createState() => _DailyReplayScreenState();
}

class _DailyReplayScreenState extends State<DailyReplayScreen> {
  late final DailyChallengeConfig _config =
      DailyChallengeService.configFor(widget.day);
  CoachPersona _persona = CoachPersonas.grinder;

  /// The result currently shown (in-memory only, never saved). Seeded from
  /// [DailyReplayScreen.initialResult]; updated when the user replays.
  late DailyChallengeResult? _result = widget.initialResult;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.capture('daily_replay_opened', {
      'challenge_number': DailyChallengeService.challengeNumber(_config.day),
    });
    CoachPersonas.load().then((p) {
      if (!mounted) return;
      setState(() => _persona = p);
      // No prior result → jump straight into the run (skip the intro screen).
      // We wait for the persona so the coach voice/mascot are correct. When a
      // result exists we stay on the breakdown instead.
      if (_result == null && !_started) _play();
    });
  }

  /// The user backed out of the run without finishing it.
  /// - If a prior result exists (they opened the breakdown, tapped "Replay
  ///   again", then abandoned) → fall back to showing that result.
  /// - Otherwise (we auto-started into the run on open, no prior result) → pop
  ///   straight back to the calendar, NOT to the intro "middle screen".
  void _onAbandoned() {
    if (widget.initialResult != null) {
      setState(() {
        _started = false;
        _result = widget.initialResult;
      });
    } else {
      _close();
    }
  }

  /// Run the day's spots and grade them — WITHOUT persisting anything.
  Future<void> _play() async {
    if (_started) return; // re-entrancy guard (double-tap "Replay again")
    HapticFeedback.selectionClick();
    setState(() => _started = true);
    final dayKey = DailyChallengeStore.dayKey(_config.day);
    final trees = await AuthoredTreeService.loadDay(dayKey);
    if (!mounted) return;

    final List<List<DrillDecisionRecord>> hands;
    final List<double> weights;
    List<String> streets = const [];
    List<List<String>> boards = const [];
    List<String> facing = const [], heroLabels = const [], bestLabels = const [];

    if (trees != null) {
      final outcomes = await Navigator.push<List<AuthoredHandOutcome>>(
        context,
        MaterialPageRoute(
          builder: (_) => AuthoredDayRunner(trees: trees, persona: _persona),
        ),
      );
      if (!mounted) return;
      if (outcomes == null || outcomes.length < trees.length) {
        _onAbandoned();
        return;
      }
      hands = [for (final o in outcomes) o.records];
      weights = [for (final o in outcomes) ...o.potWeights];
      streets = [for (final o in outcomes) ...o.streets];
      boards = [for (final o in outcomes) ...o.boards];
      facing = [for (final o in outcomes) ...o.facing];
      heroLabels = [for (final o in outcomes) ...o.heroLabels];
      bestLabels = [for (final o in outcomes) ...o.bestLabels];
    } else {
      final records = await Navigator.push<List<DrillDecisionRecord>>(
        context,
        MaterialPageRoute(
          builder: (_) => DrillTableScreen(
            seats: DailyChallengeService.seatsFor(_config),
            stackBB: _config.stackBB,
            anteMode: _config.anteMode,
            challengeConfig: _config,
            challengeDecisions: DailyChallengeService.spotsPerDay,
          ),
        ),
      );
      if (!mounted) return;
      if (records == null ||
          records.length < DailyChallengeService.spotsPerDay) {
        _onAbandoned();
        return;
      }
      hands = [
        for (final r in records) [r]
      ];
      weights = const [];
    }
    if (hands.any((h) => h.isEmpty)) {
      setState(() => _started = false);
      return;
    }

    // Build the result. It is saved to the REPLAY store (so the calendar
    // remembers it across sessions) — NOT the ranked store, so streaks and the
    // leaderboard are never touched. Latest replay wins (overwrites).
    final result = DailyChallengeResult.build(
      dayKey: dayKey,
      seed: _config.seed,
      hands: hands,
      weights: weights,
      durationMs: 0,
      trees: trees,
      streets: streets,
      boards: boards,
      facing: facing,
      heroLabels: heroLabels,
      bestLabels: bestLabels,
    );
    await DailyReplayStore.save(result); // best-effort; never throws
    if (!mounted) return;
    setState(() => _result = result);
    AnalyticsService.capture('daily_replay_completed', {
      'challenge_number': DailyChallengeService.challengeNumber(_config.day),
      'score': result.score,
    });
  }

  /// Pop back to the calendar, handing it the latest in-memory result so a
  /// re-tap of this day shows the breakdown (instead of restarting).
  void _close() => Navigator.of(context).pop(_result);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final number = DailyChallengeService.challengeNumber(_config.day);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close(); // route the system back through _close
      },
      child: Scaffold(
        backgroundColor: AppColors.paper,
        appBar: AppBar(
          backgroundColor: AppColors.paper,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            color: AppColors.textPrimary,
            onPressed: _close,
          ),
          title: Text(
            l10n.replayTitle(number),
            style: AppTypography.ibm(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: SafeArea(
          child: _result != null
              ? _results(l10n, _result!)
              // No result yet. We auto-start into the run on open (and on
              // "Replay again"), so the intro "middle screen" would only flash
              // for a frame — show a spinner instead of that teaser.
              : const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  // ── Results (compact, unranked) ──────────────────────────────────────────

  Widget _results(AppLocalizations l10n, DailyChallengeResult result) {
    final pct = (result.score * 10).round() / 10;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Center(
          child: Column(
            children: [
              Text(
                '$pct%',
                style: AppTypography.mono(
                  color: AppColors.accentPrimary,
                  fontSize: 44,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                l10n.replayAccuracy,
                style: AppTypography.ibm(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        // Same collapsible, street-by-street breakdown as the main Daily
        // Challenge results (hero card faces, board, verdicts, coach line).
        DailyResultBreakdown(result: result),
        const SizedBox(height: AppSpacing.xl),
        _ctaButton(label: l10n.replayPlayAgain, onTap: () {
          setState(() {
            _result = null;
            _started = false;
          });
          _play();
        }),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: TextButton(
            onPressed: _close,
            child: Text(
              l10n.replayDone,
              style: AppTypography.ibm(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }


  Widget _ctaButton({required String label, VoidCallback? onTap}) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.accentPrimary
              : AppColors.accentPrimary.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(60),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.ibm(
              color: AppColors.paper,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
