import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../design_system/components/headers/top_nav_bar.dart';
import '../../design_system/components/success_check_overlay.dart';
import '../../design_system/components/tween_number.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../models/drill_models.dart';
import '../../services/analytics_service.dart';
import '../../services/challenge_sound_service.dart';
import '../../services/coach_persona.dart';
import '../../services/coach_voice_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/daily_challenge_store.dart';
import '../../services/feature_flag_service.dart';
import '../../services/leaderboard_service.dart';
import '../../services/notification_prefs_service.dart';
import '../../services/streak_saver_service.dart';
import '../../services/username_service.dart';
import '../../widgets/coach_mascot.dart';
import '../../widgets/hand_micro_animations.dart';
import '../username_setup_screen.dart';
import 'drill_table_screen.dart';
import 'leaderboard_screen.dart';

/// DAILY CHALLENGE host — the chess.com-style daily ritual around the drill
/// table: intro (theme + streak + play) → the seeded run on DrillTableScreen
/// in challenge mode (coach grades every decision live) → results (score,
/// per-spot verdicts, streaks, share). One attempt counts per calendar day;
/// abandoning mid-run records nothing.
///
/// Copy is English-only while the feature is admin-flagged (Leak Detector
/// precedent) — localize before GA.
class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  static const _gold = AppColors.accentTertiary;
  static const _red = AppColors.accentDanger;

  late final DailyChallengeConfig _config =
      DailyChallengeService.configFor(DailyChallengeService.today());
  DailyChallengeResult? _todayResult;
  DailyChallengeStreaks? _streaks;
  CoachPersona _persona = CoachPersonas.grinder;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
    CoachPersonas.load().then((p) {
      if (mounted) setState(() => _persona = p);
    });
    // Warm the greeting clips while the intro is on screen, so tapping a
    // coach speaks instantly instead of after a synthesis round-trip.
    for (final p in CoachPersonas.all) {
      CoachVoiceService.prefetch(p.greeting, coachId: p.id);
    }
    ChallengeSoundService.loadEnabled();
    AnalyticsService.capture('daily_challenge_opened', {
      'challenge_number': DailyChallengeService.challengeNumber(_config.day),
    });
  }

  Future<void> _load() async {
    final result = await DailyChallengeStore.resultFor(_config.day);
    final streaks = await DailyChallengeStore.streaks(_config.day);
    if (!mounted) return;
    setState(() {
      _todayResult = result;
      _streaks = streaks;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    CoachVoiceService.stop(); // cut a running greeting preview
    super.dispose();
  }

  Future<void> _play() async {
    HapticFeedback.selectionClick();
    CoachVoiceService.stop();
    // Time the whole run (first spot shown → last decision) for the
    // leaderboard "today" tiebreaker.
    final stopwatch = Stopwatch()..start();
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
    stopwatch.stop();
    if (records == null ||
        records.length < DailyChallengeService.spotsPerDay) {
      return; // abandoned — nothing recorded, the day stays playable
    }

    final verdicts = records
        .map((r) => DailyChallengeService.verdictLetter(r.result.grade))
        .join();
    final result = DailyChallengeResult(
      dayKey: DailyChallengeStore.dayKey(_config.day),
      seed: _config.seed,
      verdicts: verdicts,
      durationMs: stopwatch.elapsedMilliseconds,
      spots: [
        for (final r in records)
          DailySpotSummary(
            handClass: r.handClass,
            position: r.position,
            heroAction: r.result.heroAction,
            recommendedAction: r.result.recommendedAction,
            verdict: DailyChallengeService.verdictLetter(r.result.grade),
          ),
      ],
    );
    await DailyChallengeStore.save(result);
    final streaks = await DailyChallengeStore.streaks(_config.day);
    if (!mounted) return;
    setState(() {
      _todayResult = result;
      _streaks = streaks;
    });
    AnalyticsService.capture('daily_challenge_completed', {
      'challenge_number': DailyChallengeService.challengeNumber(_config.day),
      'score': result.score,
      'perfect': result.perfect,
      'streak': streaks.current,
    });
    if (result.perfect) {
      HapticFeedback.heavyImpact();
      SuccessCheckOverlay.show(context);
    }
    // Global leaderboard: automatic participation. Admin day-override runs
    // never post (the service also guards, but skip the username prompt too).
    if (DailyChallengeService.debugDayOffset == 0) {
      _submitToLeaderboard(result, streaks);
    }
    // Streak-saver: settle today's pending reminder (stamps the 2h reward if
    // it fired) and schedule tomorrow's, in the picked coach's voice. The
    // service self-guards on flag / prefs / day-override. Fire-and-forget.
    unawaited(StreakSaverService.onChallengeCompleted(
      currentStreak: streaks.current,
      coachId: _persona.id,
      challengeNumber: DailyChallengeService.challengeNumber(_config.day),
    ));
  }

  /// Ensure the player has a username (prompting the setup screen once if
  /// not), then submit the run to the global leaderboard. Best-effort: a
  /// cancelled username prompt or any failure simply skips the write.
  Future<void> _submitToLeaderboard(
      DailyChallengeResult result, DailyChallengeStreaks streaks) async {
    try {
      var username = await UsernameService.getUsername();
      if ((username == null || username.trim().isEmpty) && mounted) {
        username = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => const UsernameSetupScreen(isChanging: true),
          ),
        );
      }
      if (username == null || username.trim().isEmpty) return; // declined
      await LeaderboardService.submit(
        result: result,
        streaks: streaks,
        username: username,
      );
      AnalyticsService.capture('daily_challenge_leaderboard_submitted', {
        'challenge_number':
            DailyChallengeService.challengeNumber(_config.day),
        'score': result.score,
        'streak': streaks.current,
      });
      if (mounted) setState(() {}); // refresh any visible board
    } catch (_) {
      // Leaderboard must never break the challenge.
    }
  }

  void _share() {
    final result = _todayResult;
    if (result == null) return;
    HapticFeedback.selectionClick();
    Share.share(DailyChallengeService.shareText(
      day: _config.day,
      verdicts: result.verdicts,
      streak: _streaks?.current ?? 0,
    ));
    AnalyticsService.capture('daily_challenge_shared', {
      'score': result.score,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            TopNavBar(
              title: 'Daily Challenge',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: !_loaded
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accentPrimary),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                          AppSpacing.xs, AppSpacing.md, 120),
                      child: _todayResult == null
                          ? _intro()
                          : _results(_todayResult!),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Intro (not yet played today) ─────────────────────────────────────

  Widget _intro() {
    final streak = _streaks?.current ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DAILY #${DailyChallengeService.challengeNumber(_config.day)}',
          style: AppTypography.ibm(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: AppColors.accentTertiary),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(_config.theme,
            style: AppTypography.ibm(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: AppColors.textPrimary)),
        const SizedBox(height: AppSpacing.xxxs),
        Text(_config.formatLabel,
            style: AppTypography.mono(
                fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.lg),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ruleRow(Icons.style_outlined,
                  '${DailyChallengeService.spotsPerDay} decisions, dealt fresh every day'),
              _ruleRow(Icons.record_voice_over_outlined,
                  'The coach grades every move as you make it'),
              _ruleRow(Icons.public,
                  'Same spots for everyone — compare with friends'),
              _ruleRow(Icons.local_fire_department_outlined,
                  'Play daily to build your streak'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('YOUR COACH',
            style: AppTypography.ibm(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: AppColors.accentTertiary)),
        const SizedBox(height: AppSpacing.xs),
        _coachPicker(),
        const SizedBox(height: AppSpacing.md),
        if (streak > 0 || (_streaks?.totalPlayed ?? 0) > 0)
          _card(child: _streakRow()),
        const SizedBox(height: AppSpacing.xl),
        GestureDetector(
          onTap: _play,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(AppDecorations.buttonRadius),
            ),
            child: Center(
              child: Text("Play today's challenge",
                  style: AppTypography.ibm(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.43,
                      color: Colors.black)),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _leaderboardButton(),
      ],
    );
  }

  /// Outlined secondary button that opens the global leaderboard. Shown on
  /// both the intro and the results view.
  Widget _leaderboardButton() => GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => LeaderboardScreen(config: _config)),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.leaderboard_outlined,
                    size: 18, color: AppColors.accentPrimary),
                const SizedBox(width: AppSpacing.xxs),
                Text('Leaderboard',
                    style: AppTypography.ibm(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        color: Colors.white)),
              ],
            ),
          ),
        ),
      );

  /// Coach persona cards — the mascot pops out over the card's top edge
  /// (game-UI style); tap to pick and the coach introduces themself in
  /// their own voice so the choice is audible, not just visual.
  static const double _mascotPop = 24; // how far the head rises above
  static const double _mascotSize = 60;

  Widget _coachPicker() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final p in CoachPersonas.all) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => _pickCoach(p),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(top: _mascotPop),
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xxs,
                        _mascotSize - _mascotPop + 6,
                        AppSpacing.xxs,
                        AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: p.id == _persona.id
                          ? AppColors.accentPrimary.withValues(alpha: 0.12)
                          : AppColors.bgSurface,
                      borderRadius:
                          BorderRadius.circular(AppDecorations.radiusLg),
                      border: Border.all(
                        color: p.id == _persona.id
                            ? AppColors.accentPrimary
                            : Colors.black,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.ibm(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: p.id == _persona.id
                                    ? AppColors.accentPrimary
                                    : AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(p.tagline,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            style: AppTypography.ibm(
                                fontSize: 10,
                                height: 1.2,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  // The mascot bust: bottom sits inside the card, head
                  // breaks the card's top edge. Mascots pop in staggered on
                  // screen entry. On pick: ONE clean bounce (the mascot's
                  // own happy reaction) + a smooth size-up — no springy
                  // overshoot stacking a second bounce on top.
                  Positioned(
                    top: 0,
                    child: PopIn(
                      delay: Duration(
                          milliseconds:
                              120 * CoachPersonas.all.indexOf(p)),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        scale: p.id == _persona.id ? 1.15 : 1.0,
                        alignment: Alignment.bottomCenter,
                        child: CoachMascot(
                          personaId: p.id,
                          expression: p.id == _persona.id && _justPicked
                              ? CoachExpression.happy
                              : CoachExpression.idle,
                          size: _mascotSize,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (p != CoachPersonas.all.last)
            const SizedBox(width: AppSpacing.xxs),
        ],
      ],
    );
  }

  /// Set on the first pick this visit — gates the mascot greeting reaction
  /// so the pre-selected coach doesn't "talk" on screen load.
  bool _justPicked = false;

  void _pickCoach(CoachPersona p) {
    HapticFeedback.selectionClick();
    setState(() {
      _persona = p;
      _justPicked = true;
    });
    CoachPersonas.save(p);
    // Mirror to the user doc so server engagement pushes can be coach-voiced.
    unawaited(NotificationPrefsService.saveCoachId(p.id));
    // Audible preview — the coach introduces themself in their real voice.
    CoachVoiceService.speak(p.greeting, coachId: p.id);
    AnalyticsService.capture('daily_challenge_coach_picked', {'coach': p.id});
  }

  Widget _ruleRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.accentPrimary),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(text,
                  style: AppTypography.ibm(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.35)),
            ),
          ],
        ),
      );

  // ── Results (already played today) ───────────────────────────────────

  Widget _results(DailyChallengeResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DAILY #${DailyChallengeService.challengeNumber(_config.day)} · DONE',
          style: AppTypography.ibm(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: AppColors.accentTertiary),
        ),
        const SizedBox(height: AppSpacing.sm),
        _card(
          child: Row(
            children: [
              TweenNumber(
                value: result.score,
                animateOnMount: true,
                duration: const Duration(milliseconds: 700),
                format: (v) => v == v.roundToDouble()
                    ? v.round().toString()
                    : v.toStringAsFixed(1),
                style: AppTypography.mono(
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    color: result.perfect
                        ? AppColors.accentPrimary
                        : AppColors.textPrimary),
              ),
              Text('/${result.verdicts.length}',
                  style: AppTypography.mono(
                      fontSize: 20, color: AppColors.textSecondary)),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final v in result.verdicts.split('')) ...[
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: switch (v) {
                              'c' => AppColors.accentPrimary,
                              'o' => _gold,
                              _ => _red,
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    result.perfect
                        ? 'Perfect day! 🏆'
                        : _config.theme,
                    style: AppTypography.ibm(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _card(child: _streakRow()),
        const SizedBox(height: AppSpacing.md),
        Text('YOUR SPOTS',
            style: AppTypography.ibm(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: AppColors.accentTertiary)),
        const SizedBox(height: AppSpacing.xs),
        _card(
          child: Column(
            children: [
              for (var i = 0; i < result.spots.length; i++) ...[
                if (i > 0)
                  Divider(
                      height: 16,
                      color: Colors.white.withValues(alpha: 0.06)),
                _spotRow(i + 1, result.spots[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        GestureDetector(
          onTap: _share,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(AppDecorations.buttonRadius),
            ),
            child: Center(
              child: Text('Share result',
                  style: AppTypography.ibm(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.43,
                      color: Colors.black)),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _leaderboardButton(),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Text('Next challenge at midnight',
              style: AppTypography.ibm(
                  fontSize: 12, color: AppColors.textDisabled)),
        ),
        // Testing hook: lets the admin/dev replay today without waiting for
        // midnight. Never visible to regular users in release builds.
        if (kDebugMode || FeatureFlagService.isSuperAdmin) ...[
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: GestureDetector(
              onTap: _resetToday,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxs),
                child: Text('Reset today (testing)',
                    style: AppTypography.ibm(
                        fontSize: 12,
                        color: AppColors.accentDanger
                            .withValues(alpha: 0.8))),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Debug/super-admin only: forget today's result so the day is playable
  /// again (streaks recompute from what's left).
  Future<void> _resetToday() async {
    HapticFeedback.selectionClick();
    await DailyChallengeStore.delete(_config.day);
    await _load();
  }

  Widget _spotRow(int n, DailySpotSummary spot) {
    final (color, label) = switch (spot.verdict) {
      'c' => (AppColors.accentPrimary, 'BEST'),
      'o' => (_gold, 'GOOD'),
      _ => (_red, 'LEAK'),
    };
    return Row(
      children: [
        Text('$n',
            style: AppTypography.mono(
                fontSize: 12, color: AppColors.textDisabled)),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(
          width: 64,
          child: Text('${spot.handClass} ${spot.position}',
              style: AppTypography.mono(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ),
        Expanded(
          child: Text(
            spot.verdict == 'c'
                ? 'you ${spot.heroAction}'
                : 'you ${spot.heroAction} · coach: ${spot.recommendedAction}',
            overflow: TextOverflow.ellipsis,
            style: AppTypography.ibm(
                fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.xxs, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
          ),
          child: Text(label,
              style: AppTypography.ibm(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: color)),
        ),
      ],
    );
  }

  // ── Shared pieces ────────────────────────────────────────────────────

  Widget _streakRow() {
    final s = _streaks;
    if (s == null) return const SizedBox.shrink();
    Widget stat(String value, String label) => Column(
          children: [
            Text(value,
                style: AppTypography.mono(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(label,
                style: AppTypography.ibm(
                    fontSize: 10,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary)),
          ],
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        stat('🔥 ${s.current}', 'STREAK'),
        stat('${s.best}', 'BEST'),
        stat('${s.perfectDays}', 'PERFECT'),
        stat('${s.totalPlayed}', 'PLAYED'),
      ],
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
          border: Border.all(color: Colors.black),
        ),
        child: child,
      );
}
