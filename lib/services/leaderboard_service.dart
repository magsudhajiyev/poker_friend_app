import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';
import 'daily_challenge_service.dart';
import 'daily_challenge_store.dart';
import 'daily_scoring.dart';
import 'logger_service.dart';

/// Which board a ranking query targets.
enum LeaderboardBoard { streakCurrent, streakBest, daily }

/// Streak numbers as stored on `leaderboard_streak/{uid}`.
class StreakRow {
  final int current;
  final int best;
  final int perfectDays;
  final int totalPlayed;
  final String lastDayKey;

  const StreakRow({
    required this.current,
    required this.best,
    required this.perfectDays,
    required this.totalPlayed,
    required this.lastDayKey,
  });

  factory StreakRow.fromMap(Map<String, dynamic> d) => StreakRow(
        current: (d['currentStreak'] as num?)?.toInt() ?? 0,
        best: (d['bestStreak'] as num?)?.toInt() ?? 0,
        perfectDays: (d['perfectDays'] as num?)?.toInt() ?? 0,
        totalPlayed: (d['totalPlayed'] as num?)?.toInt() ?? 0,
        lastDayKey: d['lastDayKey']?.toString() ?? '',
      );
}

/// Calendar "day before" of a yyyy-MM-dd key ('' when unparseable).
String previousDayKey(String key) {
  try {
    final p = key.split('-').map(int.parse).toList();
    return DailyChallengeStore.dayKey(DateTime(p[0], p[1], p[2] - 1));
  } catch (_) {
    return '';
  }
}

/// Merge the device's streaks into the server row so a new phone / reinstall
/// never lowers the cross-device truth. Pure. [server] null = first write.
StreakRow mergeStreakRow({
  required StreakRow? server,
  required DailyChallengeStreaks local,
  required String dayKey,
}) {
  int current = local.current;
  var last = dayKey;
  var best = local.best;
  var perfect = local.perfectDays;
  var total = local.totalPlayed;
  if (server != null) {
    if (server.lastDayKey == previousDayKey(dayKey)) {
      current = local.current > server.current + 1
          ? local.current
          : server.current + 1;
    } else if (server.lastDayKey == dayKey) {
      current = local.current > server.current ? local.current : server.current;
    }
    if (server.best > best) best = server.best;
    if (server.perfectDays > perfect) perfect = server.perfectDays;
    if (server.totalPlayed > total) total = server.totalPlayed;
    if (server.lastDayKey.compareTo(last) > 0) last = server.lastDayKey;
  }
  if (current > best) best = current;
  return StreakRow(
      current: current,
      best: best,
      perfectDays: perfect,
      totalPlayed: total,
      lastDayKey: last);
}

/// Whether a current-streak row is still alive on the board: last played no
/// earlier than (local yesterday - 1 day); the extra day absorbs timezones.
bool isStreakRowFresh(String lastDayKey, String todayKey) {
  final cutoff = previousDayKey(previousDayKey(todayKey));
  return lastDayKey.isNotEmpty && lastDayKey.compareTo(cutoff) >= 0;
}

/// One row on a leaderboard, already resolved for display.
class LeaderboardEntry {
  final int rank; // 1-based
  final String uid;
  final String username;
  final int value; // streak count, or scoreKey (accuracy ×10) for daily
  final bool isMe;

  /// Daily-only extras (null on streak boards).
  final double? score; // accuracy 0..100
  final bool perfect;
  final int? durationMs;

  const LeaderboardEntry({
    required this.rank,
    required this.uid,
    required this.username,
    required this.value,
    required this.isMe,
    this.score,
    this.perfect = false,
    this.durationMs,
  });
}

/// Global Daily Challenge leaderboard — best-effort client writes plus
/// read queries for the three boards (current streak, today, all-time best).
///
/// Participation is automatic (no opt-in/opt-out, decided 2026-10-15): every
/// completed challenge with a username writes a row. Writes are
/// fire-and-forget/no-throw — a leaderboard failure must NEVER break the
/// challenge, same contract as [FeedPublisher]/FCM/sound.
///
/// Trust model: the client-written `score` is advisory; a Cloud Function
/// re-validates it against `verdicts`. Rules only shape-check (own uid,
/// username present, verdicts shape). Score = day accuracy, see DailyScoring.
///
/// Data model (see docs/features/daily-challenge-leaderboard.md):
///   leaderboard_daily/{dayKey}/entries/{uid}
///   leaderboard_streak/{uid}
class LeaderboardService {
  LeaderboardService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _daily = 'leaderboard_daily';
  static const String _entries = 'entries';
  static const String _streak = 'leaderboard_streak';

  /// Accuracy (0..100) stored as an int ×10 so the daily board can orderBy
  /// it without float drift on ties. 87.4 → 874, 100 → 1000.
  static int scoreKey(double score) => DailyScoring.scoreKey(score);

  /// Write this run's rows. Best-effort: logs and swallows all errors.
  ///
  /// Skips entirely when the super-admin day-override is active
  /// ([DailyChallengeService.debugDayOffset] != 0) so test runs never touch
  /// real standings. Requires a non-empty [username] — the caller ensures one
  /// first (see the challenge screen's submit flow).
  static Future<void> submit({
    required DailyChallengeResult result,
    required DailyChallengeStreaks streaks,
    required String username,
  }) async {
    if (DailyChallengeService.debugDayOffset != 0) return;
    final uid = AuthService.currentUser?.uid;
    if (uid == null || username.trim().isEmpty) return;
    final name = username.trim();

    try {
      final dailyRef = _db
          .collection(_daily)
          .doc(result.dayKey)
          .collection(_entries)
          .doc(uid);
      await dailyRef.set({
        'uid': uid,
        'username': name,
        'verdicts': result.verdicts,
        if (result.weights.isNotEmpty) 'weights': result.weights,
        'score': result.score,
        'scoreKey': scoreKey(result.score),
        'perfect': result.perfect,
        'durationMs': result.durationMs,
        'challengeNumber':
            DailyChallengeService.challengeNumber(_dayFromKey(result.dayKey)),
        'submittedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      LoggerService.warning('Leaderboard: daily entry write failed: $e');
    }

    try {
      final ref = _db.collection(_streak).doc(uid);
      StreakRow? server;
      try {
        final snap = await ref.get();
        if (snap.exists) server = StreakRow.fromMap(snap.data()!);
      } catch (e) {
        LoggerService.warning('Leaderboard: streak read failed: $e');
      }
      final m = mergeStreakRow(
          server: server, local: streaks, dayKey: result.dayKey);
      await ref.set({
        'uid': uid,
        'username': name,
        'currentStreak': m.current,
        'bestStreak': m.best,
        'perfectDays': m.perfectDays,
        'totalPlayed': m.totalPlayed,
        'lastDayKey': m.lastDayKey,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      LoggerService.warning('Leaderboard: streak row write failed: $e');
    }
  }

  /// The signed-in user's ranked entry for [dayKey], or null when there is
  /// none, the user is signed out, or anything fails (offline must never
  /// block play). Used to detect a run already played on another device.
  static Future<Map<String, dynamic>?> fetchMyDailyEntry(String dayKey) async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return null;
    try {
      final snap = await _db
          .collection(_daily)
          .doc(dayKey)
          .collection(_entries)
          .doc(uid)
          .get();
      return snap.exists ? snap.data() : null;
    } catch (e) {
      LoggerService.warning('Leaderboard: fetchMyDailyEntry failed: $e');
      return null;
    }
  }

  /// Super-admin testing hook ("Reset today"): delete the user's daily entry
  /// so a replayed run can be re-submitted. Rules make entries create-only
  /// (no owner update/delete), so only the super admin succeeds here;
  /// everyone else gets a swallowed permission error. Best-effort.
  static Future<void> deleteDailyEntry(String dayKey) async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db
          .collection(_daily)
          .doc(dayKey)
          .collection(_entries)
          .doc(uid)
          .delete();
    } catch (e) {
      LoggerService.warning('Leaderboard: daily entry delete failed: $e');
    }
  }

  /// Top [limit] rows of a board. Returns an empty list on any error — the
  /// UI shows an empty state rather than crashing.
  static Future<List<LeaderboardEntry>> top(
    LeaderboardBoard board, {
    String? dayKey,
    int limit = 100,
  }) async {
    final me = AuthService.currentUser?.uid;
    try {
      final Query<Map<String, dynamic>> query;
      switch (board) {
        case LeaderboardBoard.streakCurrent:
          query = _db
              .collection(_streak)
              .where('currentStreak', isGreaterThanOrEqualTo: 1)
              .orderBy('currentStreak', descending: true)
              .limit(limit);
        case LeaderboardBoard.streakBest:
          query = _db
              .collection(_streak)
              .where('bestStreak', isGreaterThanOrEqualTo: 1)
              .orderBy('bestStreak', descending: true)
              .limit(limit);
        case LeaderboardBoard.daily:
          final key = dayKey ??
              DailyChallengeStore.dayKey(DailyChallengeService.today());
          query = _db
              .collection(_daily)
              .doc(key)
              .collection(_entries)
              .orderBy('scoreKey', descending: true)
              .orderBy('durationMs', descending: false)
              .limit(limit);
      }
      final snap = await query.get();
      var rank = 0;
      final today =
          DailyChallengeStore.dayKey(DailyChallengeService.today());
      // Current-streak board: hide dead streaks (client-side, top page only).
      final docs = board == LeaderboardBoard.streakCurrent
          ? snap.docs.where((d) =>
              isStreakRowFresh(d.data()['lastDayKey']?.toString() ?? '', today))
          : snap.docs;
      return [
        for (final doc in docs) _entryFromDoc(board, doc.data(), ++rank, me),
      ];
    } catch (e) {
      LoggerService.warning('Leaderboard: top($board) read failed: $e');
      return const [];
    }
  }

  /// The current user's 1-based rank on a board, or null when they have no
  /// row (never played / no username) or on error. Uses a count() aggregation
  /// of everyone strictly ahead, so it is correct even outside the top 100.
  static Future<int?> myRank(LeaderboardBoard board, {String? dayKey}) async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return null;
    try {
      switch (board) {
        case LeaderboardBoard.streakCurrent:
        case LeaderboardBoard.streakBest:
          final field = board == LeaderboardBoard.streakCurrent
              ? 'currentStreak'
              : 'bestStreak';
          final mine = await _db.collection(_streak).doc(uid).get();
          final myVal = (mine.data()?[field] as num?)?.toInt() ?? 0;
          if (myVal < 1) return null;
          if (board == LeaderboardBoard.streakCurrent &&
              !isStreakRowFresh(mine.data()?['lastDayKey']?.toString() ?? '',
                  DailyChallengeStore.dayKey(DailyChallengeService.today()))) {
            return null;
          }
          final ahead = await _db
              .collection(_streak)
              .where(field, isGreaterThan: myVal)
              .count()
              .get();
          return (ahead.count ?? 0) + 1;
        case LeaderboardBoard.daily:
          final key = dayKey ??
              DailyChallengeStore.dayKey(DailyChallengeService.today());
          final col =
              _db.collection(_daily).doc(key).collection(_entries);
          final mine = await col.doc(uid).get();
          if (!mine.exists) return null;
          final myScore = (mine.data()?['scoreKey'] as num?)?.toInt() ?? 0;
          final myMs =
              (mine.data()?['durationMs'] as num?)?.toInt() ?? 1 << 30;
          // Strictly better = higher scoreKey, OR same scoreKey & faster.
          final higher = await col
              .where('scoreKey', isGreaterThan: myScore)
              .count()
              .get();
          final sameFaster = await col
              .where('scoreKey', isEqualTo: myScore)
              .where('durationMs', isLessThan: myMs)
              .count()
              .get();
          return (higher.count ?? 0) + (sameFaster.count ?? 0) + 1;
      }
    } catch (e) {
      LoggerService.warning('Leaderboard: myRank($board) failed: $e');
      return null;
    }
  }

  static LeaderboardEntry _entryFromDoc(LeaderboardBoard board,
      Map<String, dynamic> d, int rank, String? me) {
    final uid = d['uid']?.toString() ?? '';
    final username = (d['username']?.toString().trim().isNotEmpty ?? false)
        ? d['username'].toString()
        : 'Player';
    final isMe = me != null && uid == me;
    switch (board) {
      case LeaderboardBoard.streakCurrent:
        return LeaderboardEntry(
          rank: rank,
          uid: uid,
          username: username,
          value: (d['currentStreak'] as num?)?.toInt() ?? 0,
          isMe: isMe,
        );
      case LeaderboardBoard.streakBest:
        return LeaderboardEntry(
          rank: rank,
          uid: uid,
          username: username,
          value: (d['bestStreak'] as num?)?.toInt() ?? 0,
          isMe: isMe,
        );
      case LeaderboardBoard.daily:
        return LeaderboardEntry(
          rank: rank,
          uid: uid,
          username: username,
          value: (d['scoreKey'] as num?)?.toInt() ?? 0,
          isMe: isMe,
          score: (d['score'] as num?)?.toDouble() ?? 0,
          perfect: d['perfect'] == true,
          durationMs: (d['durationMs'] as num?)?.toInt(),
        );
    }
  }

  static DateTime _dayFromKey(String key) {
    try {
      final p = key.split('-').map(int.parse).toList();
      return DateTime(p[0], p[1], p[2]);
    } catch (_) {
      return DailyChallengeService.today();
    }
  }
}
