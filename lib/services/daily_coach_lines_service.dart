import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'coach_level_resolver.dart';
import 'daily_challenge_service.dart';

/// Reads the AI coach lines for the Daily Challenge.
///
/// Lines are generated OUT OF BAND (a maintainer runs the batch tool with
/// the Claude API and writes `daily_challenge_lines/{dayKey}`) — the app
/// only READS them here. On a miss the caller uses its built-in persona
/// template reason, so the feature never depends on generation.
///
/// Firestore: daily_challenge_lines/{dayKey}
///   lines[spotIndex][coachId][level] = [variant, variant, variant]
///
/// Each (spot, coach, level) carries several full-line variants; the app
/// picks one at random so the coach does not repeat itself. A legacy
/// single-string value (old docs) is still accepted.
class DailyCoachLinesService {
  DailyCoachLinesService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final Random _rng = Random();

  /// One day's lines are cached in memory after the first read so every
  /// spot of the run does not re-fetch the same doc.
  static String? _cachedDayKey;
  static Map<String, dynamic>? _cachedData;

  /// Read a random AI line variant for one spot, in the player's tier and
  /// coach. Returns null when not generated yet (caller uses its template).
  static Future<String?> lineFor({
    required int spotIndex,
    required String coachId,
    required CoachLevel level,
  }) async {
    try {
      final dayKey = _dayKey(
          DailyChallengeService.configFor(DailyChallengeService.today())
              .day);
      final data = await _dayData(dayKey);
      if (data == null) return null;

      final lines = data['lines'];
      if (lines is! List || spotIndex >= lines.length) return null;
      final spot = lines[spotIndex];
      if (spot is! Map) return null;
      final coach = spot[coachId];
      if (coach is! Map) return null;
      final value = coach[level.id];

      // New shape: a list of variants → pick one at random.
      if (value is List) {
        final variants = value
            .whereType<String>()
            .where((s) => s.trim().isNotEmpty)
            .toList();
        if (variants.isEmpty) return null;
        return variants[_rng.nextInt(variants.length)];
      }
      // Legacy shape: a single string.
      if (value is String && value.trim().isNotEmpty) return value;
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _dayData(String dayKey) async {
    if (_cachedDayKey == dayKey && _cachedData != null) return _cachedData;
    final doc =
        await _db.collection('daily_challenge_lines').doc(dayKey).get();
    _cachedDayKey = dayKey;
    _cachedData = doc.data();
    return _cachedData;
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
