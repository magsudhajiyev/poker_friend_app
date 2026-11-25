import 'dart:convert';

/// Pure logic for the "running session outside the app" feature (notification
/// payloads, the persisted running-session record, the 24 h safety rule).
/// No Flutter, no plugin, no static state — everything here is unit-tested.

/// What a tap on the ongoing notification asks for.
enum LiveSessionAction {
  open('open'),
  logHand('log_hand');

  final String wire;
  const LiveSessionAction(this.wire);

  static LiveSessionAction? fromWire(String s) {
    for (final a in values) {
      if (a.wire == s) return a;
    }
    return null;
  }
}

/// The one running session the app knows about. Persisted so it survives a
/// process death; the timer always derives from [startTime].
class LiveSessionRecord {
  final String sessionId;
  final String name;

  /// `'cash'` or `'tournament'`.
  final String gameType;
  final DateTime startTime;

  /// `'full'` (PokerSessionManager session) or `'tracked'` (tracked-session
  /// mode). Decides how the session can be reopened after a restart.
  final String kind;

  const LiveSessionRecord({
    required this.sessionId,
    required this.name,
    required this.gameType,
    required this.startTime,
    this.kind = kindTracked,
  });

  static const kindFull = 'full';
  static const kindTracked = 'tracked';

  Map<String, dynamic> toJson() => {
        'id': sessionId,
        'name': name,
        'gameType': gameType,
        'start': startTime.toIso8601String(),
        'kind': kind,
      };

  String encode() => jsonEncode(toJson());

  /// Null for anything that is not a complete record (corrupt prefs).
  static LiveSessionRecord? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      final id = m['id'];
      final start = DateTime.tryParse('${m['start']}');
      if (id is! String || id.isEmpty || start == null) return null;
      return LiveSessionRecord(
        sessionId: id,
        name: (m['name'] as String?) ?? '',
        gameType: m['gameType'] == 'tournament' ? 'tournament' : 'cash',
        startTime: start,
        kind: m['kind'] == kindFull ? kindFull : kindTracked,
      );
    } catch (_) {
      return null;
    }
  }
}

enum EndTimeCheck { ok, beforeStart, inFuture }

class LiveSessionLogic {
  LiveSessionLogic._();

  static const payloadPrefix = 'live_session:';
  static const overdueAfter = Duration(hours: 24);

  /// `live_session:{action}:{sessionId}`
  static String payload(LiveSessionAction action, String sessionId) =>
      '$payloadPrefix${action.wire}:$sessionId';

  /// Null when [payload] is not a live-session payload. The action id of a
  /// tapped button is already part of the payload (one payload per button).
  static ({LiveSessionAction action, String sessionId})? parsePayload(
      String? payload) {
    if (payload == null || !payload.startsWith(payloadPrefix)) return null;
    final rest = payload.substring(payloadPrefix.length);
    final i = rest.indexOf(':');
    if (i <= 0 || i == rest.length - 1) return null;
    final action = LiveSessionAction.fromWire(rest.substring(0, i));
    if (action == null) return null;
    return (action: action, sessionId: rest.substring(i + 1));
  }

  /// Android action-button ids (the response carries the id; the payload is
  /// the notification's own, i.e. the body-tap `open` payload).
  static const actionIdLogHand = 'live_log_hand';
  static const actionIdOpen = 'live_open';

  /// What a tap means: a tapped button overrides the body payload's action.
  static ({LiveSessionAction action, String sessionId})? resolveTap(
      String? payload, String? actionId) {
    final parsed = parsePayload(payload);
    if (parsed == null) return null;
    if (actionId == actionIdLogHand) {
      return (action: LiveSessionAction.logHand, sessionId: parsed.sessionId);
    }
    return parsed;
  }

  /// Stable positive notification id per session (FNV-1a), in a range the
  /// other local notifications do not use.
  static int notificationId(String sessionId) {
    var h = 0x811c9dc5;
    for (final c in sessionId.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
    }
    return 1400000000 + (h % 100000000);
  }

  /// D27 rule 1: running for more than 24 h.
  static bool isOverdue(DateTime start, DateTime now) =>
      now.difference(start) > overdueAfter;

  /// The real end time the user types in must sit between start and now.
  static EndTimeCheck validateEndTime(
      DateTime start, DateTime end, DateTime now) {
    if (end.isBefore(start)) return EndTimeCheck.beforeStart;
    if (end.isAfter(now)) return EndTimeCheck.inFuture;
    return EndTimeCheck.ok;
  }

  /// "12m", "2h 05m", "26h 10m". Never negative (clock changes).
  static String elapsedLabel(DateTime start, DateTime now) {
    final d = now.difference(start);
    final mins = d.isNegative ? 0 : d.inMinutes;
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }
}
