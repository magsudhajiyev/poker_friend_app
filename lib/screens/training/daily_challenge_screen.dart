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
import '../../l10n/app_localizations.dart';
import '../../models/drill_models.dart';
import '../../services/authored_tree_service.dart';
import '../../services/daily_scoring.dart';
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
import '../../services/auth_service.dart';
import '../../widgets/coach_mascot.dart';
import '../../widgets/hand_micro_animations.dart';
import '../username_setup_screen.dart';
import 'authored_challenge_screen.dart';
import 'drill_table_screen.dart';
import 'leaderboard_screen.dart';
import 'daily_challenge_calendar_screen.dart';

/// DAILY CHALLENGE host — the chess.com-style daily ritual around the drill
/// table: intro (theme + streak + play) → the seeded run on DrillTableScreen
/// in challenge mode (coach grades every decision live) → results (score,
/// per-spot verdicts, streaks, share). One attempt counts per calendar day;
/// abandoning mid-run records nothing.
///
/// UI chrome is localized (all 11 locales); coach voice/notification copy
/// stays English (persona-heavy poker slang).
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

  /// For an AUTHORED (solver game-tree) day: the headline + subtitle derived
  /// from the real GTO data, replacing the leftover RNG weekday theme
  /// ("Six-Max Thursday") which has nothing to do with the authored spots.
  /// Both null on an RNG day (the weekday theme is correct there).
  String? _authoredHeadline;
  String? _authoredSubtitle;

  String get _dayHeadline => _authoredHeadline ?? _config.theme;
  String get _daySubtitle => _authoredSubtitle ?? _config.formatLabel;

  /// Results: which authored hands are expanded (collapsed by default).
  final Set<int> _openHands = {};

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
    // Authored day? Name it from the real GTO data, not the RNG weekday theme.
    final dayKey = DailyChallengeStore.dayKey(_config.day);
    final trees = await AuthoredTreeService.loadDay(dayKey);
    String? headline, subtitle;
    if (trees != null && trees.isNotEmpty) {
      // Shared stake/format across the day's hands (e.g. 'MTT · 50BB').
      final format = trees.first.formatLabel.trim();
      headline = format.isEmpty ? 'Solver Spots' : _cleanFormat(format);
      subtitle = trees.length == 1
          ? 'Solver spot'
          : '${trees.length} solver spots';
    }
    if (!mounted) return;
    setState(() {
      _todayResult = result;
      _streaks = streaks;
      _authoredHeadline = headline;
      _authoredSubtitle = subtitle;
      _loaded = true;
    });
  }

  /// 'MTT · 50BB' → 'MTT 50BB' (drop the middle dot for a clean headline).
  static String _cleanFormat(String s) =>
      s.replaceAll(' · ', ' ').replaceAll('·', ' ').replaceAll('  ', ' ').trim();

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
    // Scheduled days serve REAL solver game trees — up to 5 hands, each
    // branching on the player's line (decision count varies per hand);
    // unscheduled days fall back to the RNG preflop drill.
    final dayKey = DailyChallengeStore.dayKey(_config.day);
    final trees = await AuthoredTreeService.loadDay(dayKey);
    if (!mounted) return;

    // Per-hand decision records + aligned pot weights (DailyScoring).
    final List<List<DrillDecisionRecord>> hands;
    final List<double> weights;
    // Street label per decision, aligned with the flattened hands (authored).
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
      stopwatch.stop();
      // Abandoned mid-day → nothing recorded, the day stays playable.
      if (outcomes == null || outcomes.length < trees.length) return;
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
      stopwatch.stop();
      if (records == null ||
          records.length < DailyChallengeService.spotsPerDay) {
        return;
      }
      // Every RNG spot is its own one-decision hand, weight 1.
      hands = [
        for (final r in records) [r]
      ];
      weights = const [];
    }
    if (hands.any((h) => h.isEmpty)) return;

    final result = DailyChallengeResult.build(
      dayKey: dayKey,
      seed: _config.seed,
      hands: hands,
      weights: weights,
      durationMs: stopwatch.elapsedMilliseconds,
      trees: trees,
      streets: streets,
      boards: boards,
      facing: facing,
      heroLabels: heroLabels,
      bestLabels: bestLabels,
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

  /// The leaderboard name to use when the user skips picking a username: their
  /// real display name, or a stable 'Player####' from the uid as a last resort.
  String _leaderboardFallbackName() {
    final user = AuthService.currentUser;
    final name = user?.displayName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    final uid = user?.uid ?? '';
    final suffix = uid.length >= 4 ? uid.substring(uid.length - 4) : uid;
    return 'Player$suffix';
  }

  /// Ensure the player has a username (prompting the setup screen once if
  /// not), then submit the run to the global leaderboard. Best-effort: a
  /// cancelled username prompt or any failure simply skips the write.
  Future<void> _submitToLeaderboard(
      DailyChallengeResult result, DailyChallengeStreaks streaks) async {
    try {
      var username = await UsernameService.getUsername();
      if ((username == null || username.trim().isEmpty) && mounted) {
        // No username set. If the user ALREADY chose to skip once
        // (hasCompletedUsernameSetup is true but there's no username), don't
        // nag them every day — just submit with their real name.
        if (await UsernameService.hasCompletedUsernameSetup()) {
          username = _leaderboardFallbackName();
        } else {
          // First time: prompt to pick one (required for the leaderboard).
          // Skip returns '' (submit with the real name); closing with X
          // returns null (don't submit this run).
          final picked = await Navigator.push<String>(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const UsernameSetupScreen(leaderboardContext: true),
            ),
          );
          if (picked == null) return; // cancelled — don't submit
          username = picked.trim().isNotEmpty
              ? picked
              : _leaderboardFallbackName(); // skipped → real name
        }
      }
      if (username == null || username.trim().isEmpty) return;
      await LeaderboardService.submit(
        result: result,
        streaks: streaks,
        username: username,
      );
      AnalyticsService.capture('daily_challenge_leaderboard_submitted', {
        'challenge_number': DailyChallengeService.challengeNumber(_config.day),
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
      weights: result.weights,
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
              title: AppLocalizations.of(context).dailyChallengeTitle,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: !_loaded
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.accentPrimary),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, AppSpacing.xs, AppSpacing.md, 120),
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
        Text(_dayHeadline,
            style: AppTypography.ibm(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: AppColors.textPrimary)),
        const SizedBox(height: AppSpacing.xxxs),
        Text(_daySubtitle,
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
                  AppLocalizations.of(context).dailyChallengeRuleGrades),
              _ruleRow(Icons.public,
                  AppLocalizations.of(context).dailyChallengeRuleSameSpots),
              _ruleRow(Icons.local_fire_department_outlined,
                  AppLocalizations.of(context).dailyChallengeRuleStreak),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(AppLocalizations.of(context).dailyChallengeYourCoach,
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
              borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
            ),
            child: Center(
              child: Text(AppLocalizations.of(context).dailyChallengePlayToday,
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
        const SizedBox(height: AppSpacing.xs),
        _pastChallengesButton(),
      ],
    );
  }

  /// Outlined secondary button that opens the past-challenges replay calendar.
  Widget _pastChallengesButton() => GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const DailyChallengeCalendarScreen()),
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
                const Icon(Icons.history_rounded,
                    size: 18, color: AppColors.accentPrimary),
                const SizedBox(width: AppSpacing.xxs),
                Text(AppLocalizations.of(context).replayPastChallenges,
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
                Text(AppLocalizations.of(context).dailyChallengeLeaderboard,
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
                          milliseconds: 120 * CoachPersonas.all.indexOf(p)),
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
                format: (v) =>
                    '${DailyScoring.formatPct((v * 10).round() / 10)}%',
                style: AppTypography.mono(
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    color: result.perfect
                        ? AppColors.accentPrimary
                        : AppColors.textPrimary),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text('accuracy',
                  style: AppTypography.ibm(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(width: AppSpacing.sm),
              // Flexible so the dots take only the width left of the score and
              // WRAP when a day has many decisions (authored multi-hand days),
              // instead of overflowing the card.
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 3,
                      runSpacing: 4,
                      children: [
                        // Dots grouped by hand (a wider gap between hands).
                        for (final v in result.verdicts.split(''))
                          if (v == DailyScoring.handSeparator)
                            const SizedBox(width: 3)
                          else
                            Container(
                              width: 10,
                              height: 10,
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
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      result.perfect
                          ? AppLocalizations.of(context).dailyChallengePerfectDay
                          : _dayHeadline,
                      textAlign: TextAlign.end,
                      style: AppTypography.ibm(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _card(child: _streakRow()),
        const SizedBox(height: AppSpacing.md),
        Text(AppLocalizations.of(context).dailyChallengeYourSpots,
            style: AppTypography.ibm(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: AppColors.accentTertiary)),
        const SizedBox(height: AppSpacing.xs),
        _card(child: _spotsList(result)),
        const SizedBox(height: AppSpacing.xl),
        GestureDetector(
          onTap: _share,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
            ),
            child: Center(
              child: Text(
                  AppLocalizations.of(context).dailyChallengeShareResult,
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
        const SizedBox(height: AppSpacing.xs),
        _pastChallengesButton(),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Text(AppLocalizations.of(context).dailyChallengeNextAtMidnight,
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
                        color: AppColors.accentDanger.withValues(alpha: 0.8))),
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

  /// Decisions list. Multi-decision (authored) days show one COLLAPSIBLE
  /// section per hand (header: hand, holding, verdict dots, accuracy; rows:
  /// the street of each decision). RNG days stay a flat list.
  Widget _spotsList(DailyChallengeResult result) {
    final spots = result.spots;
    final grouped =
        DailyScoring.handsOf(result.verdicts).any((h) => h.length > 1);
    if (!grouped) {
      return Column(
        children: [
          for (var i = 0; i < spots.length; i++) ...[
            if (i > 0)
              Divider(height: 16, color: Colors.white.withValues(alpha: 0.06)),
            _spotRow(i + 1, spots[i]),
          ],
        ],
      );
    }
    final accs = result.handAccuracies;
    final byHand = <int, List<DailySpotSummary>>{};
    for (final s in spots) {
      (byHand[s.hand] ??= []).add(s);
    }
    final handIdx = byHand.keys.toList()..sort();
    return Column(
      children: [
        for (var k = 0; k < handIdx.length; k++) ...[
          if (k > 0)
            Divider(height: 12, color: Colors.white.withValues(alpha: 0.10)),
          _handSection(handIdx[k], byHand[handIdx[k]]!,
              handIdx[k] < accs.length ? accs[handIdx[k]] : 0),
        ],
      ],
    );
  }

  Widget _handSection(int hand, List<DailySpotSummary> rows, double accuracy) {
    final open = _openHands.contains(hand);
    final first = rows.first;
    final pct = (accuracy * 1000).round() / 10;
    final color =
        pct >= 80 ? AppColors.accentPrimary : (pct >= 50 ? _gold : _red);
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(
                () => open ? _openHands.remove(hand) : _openHands.add(hand));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Row(
              children: [
                Text('HAND ${hand + 1}',
                    style: AppTypography.ibm(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: AppColors.accentTertiary)),
                const SizedBox(width: AppSpacing.xs),
                // The hero's real cards as mini card faces (rank + suit);
                // old results stored only the class ('99') → plain text.
                if (_cardList(first.handClass).isNotEmpty)
                  _miniCards(_cardList(first.handClass))
                else
                  Text(first.handClass,
                      style: AppTypography.mono(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                const SizedBox(width: AppSpacing.xxs),
                Text(first.position,
                    style: AppTypography.mono(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Wrap(
                    spacing: 3,
                    runSpacing: 3,
                    children: [
                      for (final r in rows)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: switch (r.verdict) {
                              'c' => AppColors.accentPrimary,
                              'o' => _gold,
                              _ => _red,
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                Text('${DailyScoring.formatPct(pct)}%',
                    style: AppTypography.mono(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color)),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more,
                      size: 20, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: open
              ? Padding(
                  padding: const EdgeInsets.only(
                      top: AppSpacing.xxs, bottom: AppSpacing.xxs),
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0)
                          Divider(
                              height: 14,
                              color: Colors.white.withValues(alpha: 0.06)),
                        _spotRow(i + 1, rows[i]),
                      ],
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  /// Authored row, line 2: what the hero faced → what they did, plus the
  /// coach's line when it differs ("BTN 3-bet to 7.3BB → you call 7.3BB").
  /// Results saved before these labels existed fall back to raw actions.
  Widget _authoredActionLine(DailySpotSummary spot) {
    final hero = spot.heroLabel.isNotEmpty ? spot.heroLabel : spot.heroAction;
    final best = spot.recommendedLabel.isNotEmpty
        ? spot.recommendedLabel
        : spot.recommendedAction;
    final dim = AppTypography.ibm(fontSize: 12, color: AppColors.textSecondary);
    return Text.rich(
      TextSpan(style: dim, children: [
        if (spot.facing.isNotEmpty) ...[
          TextSpan(
              text: spot.facing,
              style: dim.copyWith(color: AppColors.textPrimary)),
          const TextSpan(text: '  →  '),
        ],
        TextSpan(text: 'you $hero'),
        if (spot.verdict != 'c') TextSpan(text: ' · coach: $best'),
      ]),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// '9♠ 9♥' → ['9♠', '9♥']; '' when the text has no suit glyphs.
  static List<String> _cardList(String text) {
    final cards = text.split(' ').where((c) => c.isNotEmpty).toList();
    const suits = {'♠', '♥', '♦', '♣'};
    return cards.isNotEmpty &&
            cards.every((c) => c.length >= 2 && suits.contains(c[c.length - 1]))
        ? cards
        : const [];
  }

  /// Small card faces (white, rank over suit, ♥/♦ red) — same look as the
  /// table's cards, scaled for a list row.
  Widget _miniCards(List<String> cards) {
    final w = (MediaQuery.sizeOf(context).width * 0.052).clamp(18.0, 24.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final c in cards)
          Container(
            width: w,
            height: w * 1.3,
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: AppColors.bgInverse,
              borderRadius:
                  BorderRadius.circular(AppDecorations.legendDotRadius),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(c.substring(0, c.length - 1),
                      style: AppTypography.mono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                          color: _isRed(c) ? _red : Colors.black)),
                  Text(c.substring(c.length - 1),
                      style: TextStyle(
                          fontSize: 10,
                          height: 1.0,
                          color: _isRed(c) ? _red : Colors.black)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static bool _isRed(String card) => card.endsWith('♥') || card.endsWith('♦');

  Widget _spotRow(int n, DailySpotSummary spot) {
    final l10n = AppLocalizations.of(context);
    final (color, label) = switch (spot.verdict) {
      'c' => (AppColors.accentPrimary, l10n.dailyChallengeVerdictBest),
      'o' => (_gold, l10n.dailyChallengeVerdictGood),
      _ => (_red, l10n.dailyChallengeVerdictLeak),
    };
    final number = Text('$n',
        style: AppTypography.mono(fontSize: 12, color: AppColors.textDisabled));
    final action = Text(
      spot.verdict == 'c'
          ? 'you ${spot.heroAction}'
          : 'you ${spot.heroAction} · coach: ${spot.recommendedAction}',
      overflow: TextOverflow.ellipsis,
      style: AppTypography.ibm(fontSize: 12, color: AppColors.textSecondary),
    );
    final badge = Container(
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
    );
    final labelStyle = AppTypography.mono(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary);

    // RNG spot: one line — holding, action, verdict.
    if (spot.street.isEmpty) {
      return Row(
        children: [
          number,
          const SizedBox(width: AppSpacing.xs),
          SizedBox(
            width: 64,
            child:
                Text('${spot.handClass} ${spot.position}', style: labelStyle),
          ),
          Expanded(child: action),
          badge,
        ],
      );
    }

    // Authored decision: street + the board it was played on (card faces),
    // then the action line with the verdict.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        number,
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(spot.street, style: labelStyle),
                  if (spot.board.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(child: _miniCards(spot.board)),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xxxs),
              _authoredActionLine(spot),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xxs),
        badge,
      ],
    );
  }

  // ── Shared pieces ────────────────────────────────────────────────────

  Widget _streakRow() {
    final s = _streaks;
    if (s == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
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
        stat('🔥 ${s.current}', l10n.dailyChallengeStatStreak),
        stat('${s.best}', l10n.dailyChallengeStatBest),
        stat('${s.perfectDays}', l10n.dailyChallengeStatPerfect),
        stat('${s.totalPlayed}', l10n.dailyChallengeStatPlayed),
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
