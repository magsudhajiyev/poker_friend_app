import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/authored_tree.dart';
import '../models/drill_models.dart';
import 'auth_service.dart';
import 'daily_challenge_service.dart';
import 'daily_scoring.dart';
import 'range_read_logic.dart';

/// One completed day of the Daily Challenge, as persisted.
class DailyChallengeResult {
  final String dayKey; // 'yyyy-MM-dd' (local date)
  final int seed;
  /// One letter per decision (c / o / m), grouped by hand with '|' — see
  /// [DailyScoring]. Legacy RNG results have no '|' (one letter = one hand).
  final String verdicts;

  /// Pot (BB) at each decision, aligned with the verdict letters — the
  /// accuracy weights. Empty = every decision weighs 1 (RNG days).
  final List<double> weights;

  /// Compact per-spot summaries for the results view on later visits:
  /// hand class, position, hero action, recommended action, verdict letter.
  final List<DailySpotSummary> spots;

  /// Total time for the run, first spot shown → last decision, in ms. The
  /// leaderboard "today" board uses it as the score tiebreaker. 0 for old
  /// results saved before duration capture existed.
  final int durationMs;

  const DailyChallengeResult({
    required this.dayKey,
    required this.seed,
    required this.verdicts,
    required this.spots,
    this.weights = const [],
    this.durationMs = 0,
  });

  /// Day accuracy, 0..100.
  double get score => DailyChallengeService.scoreOf(verdicts, weights);

  /// Per-hand accuracies, 0..1.
  List<double> get handAccuracies =>
      DailyScoring.handAccuracies(verdicts, weights);
  bool get perfect => DailyChallengeService.isPerfect(verdicts);

  Map<String, dynamic> toJson() => {
        'seed': seed,
        'v': verdicts,
        if (weights.isNotEmpty) 'w': weights,
        'spots': spots.map((s) => s.toJson()).toList(),
        if (durationMs > 0) 'ms': durationMs,
      };

  factory DailyChallengeResult.fromJson(
          String dayKey, Map<String, dynamic> json) =>
      DailyChallengeResult(
        dayKey: dayKey,
        seed: (json['seed'] as num?)?.toInt() ?? 0,
        verdicts: json['v']?.toString() ?? '',
        weights: [
          for (final w in (json['w'] as List? ?? const []))
            if (w is num) w.toDouble(),
        ],
        durationMs: (json['ms'] as num?)?.toInt() ?? 0,
        spots: [
          for (final s in (json['spots'] as List? ?? const []))
            if (s is Map) DailySpotSummary.fromJson(s.cast<String, dynamic>()),
        ],
      );

  /// Assemble a result from a completed run. Shared by the normal daily play
  /// path and the (non-persisting) REPLAY path so they grade and summarize
  /// identically — building this is NOT the same as saving it (replay never
  /// calls [DailyChallengeStore.save]).
  ///
  /// [hands] is the per-hand list of decision records; [weights] the pot-BB
  /// weights aligned with the flattened decisions (empty on RNG days). The
  /// `*Labels`/`streets`/`boards`/`facing` lists are the authored per-decision
  /// detail, flattened and aligned (empty on RNG days). [trees] is the
  /// authored day's trees (null on RNG days) — used for real card faces and
  /// the 'LJ vs BTN' matchup label.
  ///
  /// [quizzes] (authored days, optional) holds each hand's Range Read answers.
  /// Each becomes ONE extra verdict letter placed right after the decision it
  /// followed, weighted with that decision's pot, plus its own summary row
  /// (`kind` 'rr'). [weights] and the per-decision detail lists stay indexed
  /// by DECISION; the merge happens here.
  static DailyChallengeResult build({
    required String dayKey,
    required int seed,
    required List<List<DrillDecisionRecord>> hands,
    required List<double> weights,
    required int durationMs,
    List<AuthoredTree>? trees,
    List<String> streets = const [],
    List<List<String>> boards = const [],
    List<String> facing = const [],
    List<String> heroLabels = const [],
    List<String> bestLabels = const [],
    List<List<RangeReadAnswer>> quizzes = const [],
  }) {
    String letter(DrillDecisionRecord r) =>
        DailyChallengeService.verdictLetter(r.result.grade);
    final letters = <String>[];
    final outWeights = <double>[];
    final spots = <DailySpotSummary>[];
    var flat = 0; // index into the flattened per-decision detail lists
    var wOffset = 0; // index into the flat decision weights
    for (var i = 0; i < hands.length; i++) {
      final qs = i < quizzes.length ? quizzes[i] : const <RangeReadAnswer>[];
      final hasTree = trees != null && i < trees.length;
      final heroCards = hasTree ? trees[i].heroCards.join(' ') : '';
      final pos = hasTree
          ? '${trees[i].heroPosition} vs ${trees[i].villainPosition}'
          : '';
      final handLetters = StringBuffer();
      for (var j = 0; j < hands[i].length; j++) {
        final r = hands[i][j];
        final f = flat++;
        final w = wOffset + j < weights.length ? weights[wOffset + j] : 1.0;
        final street = f < streets.length ? streets[f] : '';
        final board = f < boards.length ? boards[f] : const <String>[];
        handLetters.write(letter(r));
        if (weights.isNotEmpty) outWeights.add(w);
        spots.add(DailySpotSummary(
          handClass: hasTree ? heroCards : r.handClass,
          position: hasTree ? pos : r.position,
          heroAction: r.result.heroAction,
          recommendedAction: r.result.recommendedAction,
          verdict: letter(r),
          hand: i,
          board: board,
          facing: f < facing.length ? facing[f] : '',
          heroLabel: f < heroLabels.length ? heroLabels[f] : '',
          recommendedLabel: f < bestLabels.length ? bestLabels[f] : '',
          street: street,
        ));
        for (final q in qs.where((q) => q.afterDecision == j)) {
          handLetters.write(q.letter);
          if (weights.isNotEmpty) outWeights.add(w);
          spots.add(DailySpotSummary(
            handClass: heroCards,
            position: pos,
            heroAction: '',
            recommendedAction: '',
            verdict: q.letter,
            hand: i,
            board: board,
            street: street,
            rangeRead: q,
          ));
        }
      }
      wOffset += hands[i].length;
      letters.add(handLetters.toString());
    }
    return DailyChallengeResult(
      dayKey: dayKey,
      seed: seed,
      verdicts: DailyScoring.encode(letters),
      weights: outWeights,
      durationMs: durationMs,
      spots: spots,
    );
  }
}

class DailySpotSummary {
  final String handClass; // 'AKo'
  final String position; // 'BTN'
  final String heroAction; // 'fold' | 'check' | 'call' | 'raise'
  final String recommendedAction;
  final String verdict; // c / o / m

  /// 0-based hand this decision belongs to (several per authored hand).
  final int hand;

  /// Street label of the decision ('Preflop', 'Flop', ...); '' on RNG days
  /// (every spot is preflop there).
  final String street;

  /// Board cards when the decision was made (e.g. ['10♠','9♣','4♦']);
  /// empty preflop and on RNG days.
  final List<String> board;

  /// Authored decisions: what the hero faced ('BTN 3-bet to 7.3BB') and
  /// plain-word labels for the hero's and the coach's action ('call 7.3BB',
  /// 'bet 16.2BB'). Empty on RNG days (rows fall back to the raw actions).
  final String facing;
  final String heroLabel;
  final String recommendedLabel;

  /// Non-null on a Range Read row (kind 'rr'): the question + the player's
  /// answer. Such a row has no hero/recommended action. Old stored results
  /// have no kind and parse as ordinary decisions.
  final RangeReadAnswer? rangeRead;

  bool get isRangeRead => rangeRead != null;

  const DailySpotSummary({
    required this.handClass,
    required this.position,
    required this.heroAction,
    required this.recommendedAction,
    required this.verdict,
    this.hand = 0,
    this.street = '',
    this.board = const [],
    this.facing = '',
    this.heroLabel = '',
    this.recommendedLabel = '',
    this.rangeRead,
  });

  Map<String, dynamic> toJson() => {
        'hc': handClass,
        'pos': position,
        'act': heroAction,
        'rec': recommendedAction,
        'g': verdict,
        'h': hand,
        if (street.isNotEmpty) 'st': street,
        if (board.isNotEmpty) 'bd': board,
        if (facing.isNotEmpty) 'fc': facing,
        if (heroLabel.isNotEmpty) 'hl': heroLabel,
        if (recommendedLabel.isNotEmpty) 'rl': recommendedLabel,
        if (rangeRead != null) 'k': 'rr',
        if (rangeRead != null) 'rr': rangeRead!.toJson(),
      };

  factory DailySpotSummary.fromJson(Map<String, dynamic> json) =>
      DailySpotSummary(
        handClass: json['hc']?.toString() ?? '',
        position: json['pos']?.toString() ?? '',
        heroAction: json['act']?.toString() ?? '',
        recommendedAction: json['rec']?.toString() ?? '',
        verdict: json['g']?.toString() ?? 'm',
        hand: (json['h'] as num?)?.toInt() ?? 0,
        street: json['st']?.toString() ?? '',
        facing: json['fc']?.toString() ?? '',
        heroLabel: json['hl']?.toString() ?? '',
        recommendedLabel: json['rl']?.toString() ?? '',
        rangeRead: json['k'] == 'rr' && json['rr'] is Map
            ? RangeReadAnswer.fromJson(
                (json['rr'] as Map).cast<String, dynamic>())
            : null,
        board: [
          for (final c in (json['bd'] as List? ?? const [])) c.toString(),
        ],
      );
}

class DailyChallengeStreaks {
  final int current; // alive run ending today or yesterday
  final int best;
  final int perfectDays;
  final int totalPlayed;

  const DailyChallengeStreaks({
    required this.current,
    required this.best,
    required this.perfectDays,
    required this.totalPlayed,
  });
}

/// SharedPreferences persistence for Daily Challenge results + streaks.
/// Local-only by design for v1 (same pattern as DrillLineupStore) — a
/// Firestore mirror/leaderboard can layer on later without changing callers.
class DailyChallengeStore {
  DailyChallengeStore._();

  static const String _keyPrefix = 'daily_challenge_results';

  static String _storageKey() {
    String? uid;
    try {
      uid = AuthService.currentUser?.uid;
    } catch (_) {
      // No Firebase (unit tests) — fall back to the shared key.
    }
    return uid == null ? _keyPrefix : '${_keyPrefix}_$uid';
  }

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static Future<Map<String, DailyChallengeResult>> _loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey());
      if (raw == null) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final e in decoded.entries)
          if (e.value is Map)
            e.key.toString(): DailyChallengeResult.fromJson(
                e.key.toString(), (e.value as Map).cast<String, dynamic>()),
      };
    } catch (_) {
      return {}; // corrupt payload — the challenge must never crash the app
    }
  }

  static Future<DailyChallengeResult?> resultFor(DateTime day) async =>
      (await _loadAll())[dayKey(day)];

  /// All stored results keyed by `yyyy-MM-dd`. Read-only snapshot for the
  /// replay calendar (which days were played + their scores). Never throws.
  static Future<Map<String, DailyChallengeResult>> allResults() => _loadAll();

  static Future<void> save(DailyChallengeResult result) async {
    final all = await _loadAll();
    all[result.dayKey] = result;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey(),
      jsonEncode({for (final e in all.entries) e.key: e.value.toJson()}),
    );
  }

  /// Testing hook (debug/super-admin "Reset today"): forgets one day's
  /// result so the challenge becomes playable again. Streaks recompute
  /// from what's left.
  static Future<void> delete(DateTime day) async {
    final all = await _loadAll();
    if (all.remove(dayKey(day)) == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey(),
      jsonEncode({for (final e in all.entries) e.key: e.value.toJson()}),
    );
  }

  static Future<DailyChallengeStreaks> streaks(DateTime today) async =>
      computeStreaks(await _loadAll(), today);

  /// Calendar-day shift. Never subtract a 24h `Duration` from a local
  /// DateTime: on a DST day (23h/25h) that skips or repeats a calendar day.
  static DateTime _shiftDays(DateTime d, int n) =>
      DateTime(d.year, d.month, d.day + n);

  /// True when [next] is the calendar day right after [prev] (DST-safe,
  /// compares Y-M-D, not elapsed hours).
  static bool isNextDay(DateTime prev, DateTime next) =>
      dayKey(_shiftDays(prev, 1)) == dayKey(next);

  /// Pure streak math (unit-tested). The current streak stays ALIVE when
  /// yesterday was played but today isn't yet — missing a full day breaks it.
  static DailyChallengeStreaks computeStreaks(
      Map<String, DailyChallengeResult> results, DateTime today) {
    final day0 = DateTime(today.year, today.month, today.day);
    final played = results.keys.toSet();

    var current = 0;
    // Anchor on today if played, else on yesterday (today still pending).
    var cursor =
        played.contains(dayKey(day0)) ? day0 : _shiftDays(day0, -1);
    while (played.contains(dayKey(cursor))) {
      current++;
      cursor = _shiftDays(cursor, -1);
    }

    // Best run: walk the sorted day keys counting consecutive-date runs.
    var best = 0;
    var run = 0;
    DateTime? prev;
    for (final key in played.toList()..sort()) {
      final parts = key.split('-').map(int.parse).toList();
      final d = DateTime(parts[0], parts[1], parts[2]);
      run = (prev != null && isNextDay(prev, d)) ? run + 1 : 1;
      if (run > best) best = run;
      prev = d;
    }

    return DailyChallengeStreaks(
      current: current,
      best: best < current ? current : best,
      perfectDays: results.values.where((r) => r.perfect).length,
      totalPlayed: results.length,
    );
  }
}

/// Persisted results of REPLAYS (replaying a past day — unranked practice).
///
/// A SEPARATE store from [DailyChallengeStore] on purpose: streaks and the
/// leaderboard derive from the ranked store, so replay results must never land
/// there (back-dating would corrupt the streak). This store exists only so the
/// replay calendar can show a breakdown for a past day the user replayed, and
/// survive app restarts. It is never read by streak/leaderboard code.
///
/// Reuses [DailyChallengeResult] and the same per-user, dayKey-keyed JSON map
/// shape as [DailyChallengeStore].
class DailyReplayStore {
  DailyReplayStore._();

  static const String _keyPrefix = 'daily_replay_results';

  static String _storageKey() {
    String? uid;
    try {
      uid = AuthService.currentUser?.uid;
    } catch (_) {}
    return uid == null ? _keyPrefix : '${_keyPrefix}_$uid';
  }

  static Future<Map<String, DailyChallengeResult>> _loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey());
      if (raw == null) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final e in decoded.entries)
          if (e.value is Map)
            e.key.toString(): DailyChallengeResult.fromJson(
                e.key.toString(), (e.value as Map).cast<String, dynamic>()),
      };
    } catch (_) {
      return {};
    }
  }

  /// All saved replay results keyed by `yyyy-MM-dd`. Never throws.
  static Future<Map<String, DailyChallengeResult>> allResults() => _loadAll();

  /// Save (or overwrite — latest replay wins) a replay result for its day.
  /// Best-effort: a failure simply means the calendar won't remember it.
  static Future<void> save(DailyChallengeResult result) async {
    try {
      final all = await _loadAll();
      all[result.dayKey] = result;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey(),
        jsonEncode({for (final e in all.entries) e.key: e.value.toJson()}),
      );
    } catch (_) {}
  }
}
