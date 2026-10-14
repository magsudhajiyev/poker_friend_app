import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'daily_challenge_service.dart';

/// One completed day of the Daily Challenge, as persisted.
class DailyChallengeResult {
  final String dayKey; // 'yyyy-MM-dd' (local date)
  final int seed;
  final String verdicts; // one letter per decision: c / o / m

  /// Compact per-spot summaries for the results view on later visits:
  /// hand class, position, hero action, recommended action, verdict letter.
  final List<DailySpotSummary> spots;

  const DailyChallengeResult({
    required this.dayKey,
    required this.seed,
    required this.verdicts,
    required this.spots,
  });

  double get score => DailyChallengeService.scoreOf(verdicts);
  bool get perfect => DailyChallengeService.isPerfect(verdicts);

  Map<String, dynamic> toJson() => {
        'seed': seed,
        'v': verdicts,
        'spots': spots.map((s) => s.toJson()).toList(),
      };

  factory DailyChallengeResult.fromJson(
          String dayKey, Map<String, dynamic> json) =>
      DailyChallengeResult(
        dayKey: dayKey,
        seed: (json['seed'] as num?)?.toInt() ?? 0,
        verdicts: json['v']?.toString() ?? '',
        spots: [
          for (final s in (json['spots'] as List? ?? const []))
            if (s is Map) DailySpotSummary.fromJson(s.cast<String, dynamic>()),
        ],
      );
}

class DailySpotSummary {
  final String handClass; // 'AKo'
  final String position; // 'BTN'
  final String heroAction; // 'fold' | 'check' | 'call' | 'raise'
  final String recommendedAction;
  final String verdict; // c / o / m

  const DailySpotSummary({
    required this.handClass,
    required this.position,
    required this.heroAction,
    required this.recommendedAction,
    required this.verdict,
  });

  Map<String, dynamic> toJson() => {
        'hc': handClass,
        'pos': position,
        'act': heroAction,
        'rec': recommendedAction,
        'g': verdict,
      };

  factory DailySpotSummary.fromJson(Map<String, dynamic> json) =>
      DailySpotSummary(
        handClass: json['hc']?.toString() ?? '',
        position: json['pos']?.toString() ?? '',
        heroAction: json['act']?.toString() ?? '',
        recommendedAction: json['rec']?.toString() ?? '',
        verdict: json['g']?.toString() ?? 'm',
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

  /// Pure streak math (unit-tested). The current streak stays ALIVE when
  /// yesterday was played but today isn't yet — missing a full day breaks it.
  static DailyChallengeStreaks computeStreaks(
      Map<String, DailyChallengeResult> results, DateTime today) {
    final day0 = DateTime(today.year, today.month, today.day);
    final played = results.keys.toSet();

    var current = 0;
    // Anchor on today if played, else on yesterday (today still pending).
    var cursor =
        played.contains(dayKey(day0)) ? day0 : day0.subtract(const Duration(days: 1));
    while (played.contains(dayKey(cursor))) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    // Best run: walk the sorted day keys counting consecutive-date runs.
    var best = 0;
    var run = 0;
    DateTime? prev;
    for (final key in played.toList()..sort()) {
      final parts = key.split('-').map(int.parse).toList();
      final d = DateTime(parts[0], parts[1], parts[2]);
      run = (prev != null && d.difference(prev).inDays == 1) ? run + 1 : 1;
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
