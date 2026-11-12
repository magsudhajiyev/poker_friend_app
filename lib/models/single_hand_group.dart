import 'game_types.dart';

/// Session `sessionType` of a hand group (a lightweight `poker_sessions` doc
/// that only holds single hands). Absent on every normal session.
const String kHandGroupSessionType = 'hand_group';

/// True when a session map (Firestore or SQLite) is a hand group.
bool isHandGroupSession(Map<String, dynamic> session) =>
    session['sessionType'] == kHandGroupSessionType;

/// A hand group as the single-hand UI sees it.
class SingleHandGroup {
  final String sessionId;
  final String name;
  final GameType gameType;
  final double smallBlind;
  final double bigBlind;
  final int handCount;
  final DateTime lastHandAt;

  const SingleHandGroup({
    required this.sessionId,
    required this.name,
    required this.gameType,
    required this.smallBlind,
    required this.bigBlind,
    required this.handCount,
    required this.lastHandAt,
  });

  /// Reads a `poker_sessions` map: Timestamp, ISO string or DateTime times.
  /// Returns null when it is not a hand group or has no usable time.
  static SingleHandGroup? fromSession(String id, Map<String, dynamic> m) {
    if (!isHandGroupSession(m)) return null;
    final last = _time(m['endTime']) ?? _time(m['startTime']);
    if (last == null) return null;
    return SingleHandGroup(
      sessionId: id,
      name: m['sessionName']?.toString() ?? '',
      gameType:
          m['gameType'] == 'tournament' ? GameType.tournament : GameType.cash,
      smallBlind: (m['smallBlind'] as num?)?.toDouble() ?? 0,
      bigBlind: (m['bigBlind'] as num?)?.toDouble() ?? 0,
      handCount: (m['totalHands'] as num?)?.toInt() ?? 0,
      lastHandAt: last,
    );
  }

  SingleHandGroup copyWith({int? handCount, DateTime? lastHandAt}) =>
      SingleHandGroup(
        sessionId: sessionId,
        name: name,
        gameType: gameType,
        smallBlind: smallBlind,
        bigBlind: bigBlind,
        handCount: handCount ?? this.handCount,
        lastHandAt: lastHandAt ?? this.lastHandAt,
      );

  static DateTime? _time(Object? v) {
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    if (v != null && v.runtimeType.toString().contains('Timestamp')) {
      return (v as dynamic).toDate() as DateTime;
    }
    return null;
  }
}
