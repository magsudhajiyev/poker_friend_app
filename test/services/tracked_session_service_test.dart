import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lib/models/game_types.dart';
import '../../lib/models/hand_state_machine.dart';
import '../../lib/models/single_hand_group.dart';
import '../../lib/models/single_hand_setup.dart';
import '../../lib/models/tracked_session.dart';
import '../../lib/services/live_session_logic.dart';
import '../../lib/services/session_start_gate.dart';
import '../../lib/services/single_hand_service.dart';
import '../../lib/services/tracked_session_service.dart';

final _t0 = DateTime(2026, 11, 25, 20, 0);

class _Tracked implements TrackedSessionBackend {
  final calls = <String>[];
  Map<String, dynamic>? doc;
  int hands = 0;
  TrackedSession? created;

  @override
  Future<void> create(TrackedSession s) async {
    created = s;
    calls.add('create:${s.id}');
  }

  @override
  Future<Map<String, dynamic>?> load(String id) async => doc;
  @override
  Future<int> handCount(String id) async => hands;
  @override
  Future<void> recordResult(String id,
          {double? currentStack,
          int? finishedPlace,
          int? fieldSize,
          double? prizeWon}) async =>
      calls.add('result:$currentStack:$finishedPlace:$fieldSize:$prizeWon');
  @override
  Future<void> end(String id, DateTime at) async =>
      calls.add('end:$id:${at.toIso8601String()}');
  @override
  Future<void> discard(String id) async => calls.add('discard:$id');
}

class _Hands implements SingleHandBackend {
  final calls = <String>[];
  int count;
  _Hands(this.count);
  @override
  Future<List<SingleHandGroup>> loadGroups() async => [];
  @override
  Future<int> handCount(String groupId) async => count;
  @override
  Future<void> createGroup(
          {required String groupId,
          required String name,
          required SingleHandSetup setup}) async =>
      calls.add('create');
  @override
  Future<(String?, String?)> writeHand(
      {required String groupId,
      required int handNumber,
      required HandRecord hand,
      required SingleHandSetup setup,
      required Map<int, String> playerNames,
      Map<int, String>? playerIds}) async {
    calls.add('write:$groupId:$handNumber');
    return ('c$handNumber', 'l$handNumber');
  }

  @override
  Future<void> touchGroup(String groupId, DateTime at) async =>
      calls.add('touch:$groupId');
}

void main() {
  late _Tracked b;
  late List<String> live;
  late List<String> money;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    b = _Tracked();
    live = [];
    money = [];
    TrackedSessionService.backend = b;
    TrackedSessionService.now = () => _t0;
    TrackedSessionService.newId = () => 'sess-1';
    TrackedSessionService.liveStart = (s) async => live.add('start:${s.id}');
    TrackedSessionService.liveStop = (id) async => live.add('stop:$id');
    TrackedSessionService.recordCashResult =
        (p, buyIn, m) async => money.add('cash:$p:$buyIn:$m');
    TrackedSessionService.currentRecord = () async => null;
    SessionStartGate.currentRecord = () async => null;
    SessionStartGate.localSessions = () async => [];
    SessionStartGate.localSession = (id) async => null;
    SingleHandService.now = () => _t0;
    SingleHandService.canAddHand = (n) => n < 10;
  });

  group('start', () {
    test('cash: the buy-in is the stack; saved at once; notification starts',
        () async {
      final s = await TrackedSessionService.start(
          name: ' Casino ', gameType: GameType.cash, buyIn: 200);
      expect(s.name, 'Casino');
      expect(s.startingStack, 200);
      expect(s.startTime, _t0);
      expect(b.calls, ['create:sess-1']);
      expect(live, ['start:sess-1']);
    });

    test('tournament: optional starting stack, 0 when none', () async {
      final a = await TrackedSessionService.start(
          name: 'T', gameType: GameType.tournament, buyIn: 50);
      expect(a.startingStack, 0);
      final c = await TrackedSessionService.start(
          name: 'T',
          gameType: GameType.tournament,
          buyIn: 50,
          startingStack: 20000);
      expect(c.startingStack, 20000);
    });

    test('buy-in is required', () {
      expect(
          () => TrackedSessionService.start(
              name: 'x', gameType: GameType.cash, buyIn: 0),
          throwsArgumentError);
    });
  });

  group('finish (money + time)', () {
    final cash = TrackedSession(
        id: 's',
        name: 'n',
        gameType: GameType.cash,
        buyIn: 100,
        startingStack: 100,
        startTime: _t0.subtract(const Duration(hours: 3)));

    test('cash keeps cash-out = buy-in + profit as the final stack', () async {
      await TrackedSessionService.finish(cash,
          totalBuyIn: 300,
          result: const TrackedSessionResult(profitLoss: -120));
      expect(b.calls.first, 'result:180.0:null:null:null');
      expect(b.calls.last, startsWith('end:s:'));
      expect(live, ['stop:s']);
    });

    test('tournament stores place, field and prize', () async {
      final t = TrackedSession(
          id: 't',
          name: 'n',
          gameType: GameType.tournament,
          buyIn: 50,
          startingStack: 0,
          startTime: _t0);
      await TrackedSessionService.finish(t,
          totalBuyIn: 50,
          result: const TrackedSessionResult(
              profitLoss: 150,
              finishedPlace: 3,
              fieldSize: 90,
              prizeWon: 200));
      expect(b.calls.first, 'result:null:3:90:200.0');
    });

    test('ended without a result still closes the session', () async {
      await TrackedSessionService.finish(cash, totalBuyIn: 100);
      expect(b.calls.length, 1);
      expect(b.calls.single, startsWith('end:'));
    });
  });

  group('end without the sheet (still-playing prompt / end it first)', () {
    test('cash is settled from the last stack', () async {
      b.doc = {
        'sessionType': 'tracked',
        'sessionName': 'n',
        'gameType': 'cash',
        'startTime': _t0.subtract(const Duration(minutes: 90)).toIso8601String(),
        'buyInAmount': 100.0,
        'totalBuyIn': 200.0,
        'startingStack': 100.0,
        'currentStack': 260.0,
      };
      expect(await TrackedSessionService.endWithoutSheet('s', _t0), isTrue);
      expect(money, ['cash:60.0:200.0:90']);
      expect(b.calls.first, 'result:260.0:null:null:null');
      expect(live, ['stop:s']);
    });

    test('tournament: no money row (the prize is unknown)', () async {
      b.doc = {
        'sessionType': 'tracked',
        'gameType': 'tournament',
        'startTime': _t0.toIso8601String(),
        'buyInAmount': 50.0,
      };
      expect(await TrackedSessionService.endWithoutSheet('s', _t0), isTrue);
      expect(money, isEmpty);
      expect(b.calls.single, startsWith('end:'));
    });

    test('a session that is gone is just cleared', () async {
      b.doc = null;
      expect(await TrackedSessionService.endWithoutSheet('s', _t0), isTrue);
      expect(b.calls, isEmpty);
      expect(live, ['stop:s']);
    });
  });

  group('discard (D24)', () {
    test('deletes through the backend and stops the notification', () async {
      await TrackedSessionService.discard('s');
      expect(b.calls, ['discard:s']);
      expect(live, ['stop:s']);
    });

    test('hand count for the warning comes from the backend', () async {
      b.hands = 7;
      expect(await TrackedSessionService.handCount('s'), 7);
    });
  });

  group('running target (+ routing, D23)', () {
    test('a running tracked session is the default target', () async {
      TrackedSessionService.currentRecord = () async => LiveSessionRecord(
          sessionId: 's',
          name: 'Casino',
          gameType: 'tournament',
          startTime: _t0);
      final t = await TrackedSessionService.runningTarget();
      expect(t?.id, 's');
      expect(t?.name, 'Casino');
      expect(t?.gameType, GameType.tournament);
    });

    test('a running FULL session is not a hand target', () async {
      TrackedSessionService.currentRecord = () async => LiveSessionRecord(
          sessionId: 's',
          name: 'Full',
          gameType: 'cash',
          startTime: _t0,
          kind: LiveSessionRecord.kindFull);
      expect(await TrackedSessionService.runningTarget(), isNull);
    });

    test('nothing running -> no target (hand groups as before)', () async {
      expect(await TrackedSessionService.runningTarget(), isNull);
    });
  });

  group('hand saved inside the session (D17, D19)', () {
    HandRecord hand() => HandRecord(
        handNumber: 1, buttonPosition: 1, playerCount: 6, startTime: _t0);

    test('numbered after the existing hands; session untouched; flagged',
        () async {
      final h = _Hands(2);
      SingleHandService.backend = h;
      final r = await SingleHandService.saveHandInSession(
          hand: hand(),
          setup: SingleHandSetup(),
          sessionId: 'sess',
          sessionName: 'Casino');
      expect(r.handNumber, 3);
      expect(r.inSession, isTrue);
      expect(r.newGroup, isFalse);
      expect(r.group.name, 'Casino');
      // No group create, and NO touch: the session's endTime stays null.
      expect(h.calls, ['write:sess:3']);
    });

    test('the session is never cached as the last hand group', () async {
      SingleHandService.backend = _Hands(0);
      await SingleHandService.saveHandInSession(
          hand: hand(),
          setup: SingleHandSetup(),
          sessionId: 'sess',
          sessionName: 'Casino');
      // The group suggestion falls back to the cache when nothing is stored.
      expect(await SingleHandService.suggestedGroup(SingleHandSetup()), isNull);
    });

    test('tier hand cap throws instead of opening another session', () async {
      SingleHandService.backend = _Hands(10);
      expect(
          () => SingleHandService.saveHandInSession(
              hand: hand(),
              setup: SingleHandSetup(),
              sessionId: 'sess',
              sessionName: 'Casino'),
          throwsA(isA<SingleHandGroupFullException>()));
    });
  });

  group('tracked session map helpers', () {
    test('isTrackedSession / skipsHandStats', () {
      expect(isTrackedSession({'sessionType': 'tracked'}), isTrue);
      expect(isTrackedSession({'sessionType': 'hand_group'}), isFalse);
      expect(isTrackedSession({}), isFalse);
      expect(skipsHandStats({'sessionType': 'tracked'}), isTrue);
      expect(skipsHandStats({'sessionType': 'hand_group'}), isTrue);
      expect(skipsHandStats({'sessionType': null}), isFalse);
    });

    test('fromSession reads a stored doc and rejects other types', () {
      final s = TrackedSession.fromSession('x', {
        'sessionType': 'tracked',
        'sessionName': 'Casino',
        'gameType': 'tournament',
        'startTime': _t0.toIso8601String(),
        'buyInAmount': 80,
        'startingStack': 15000,
      });
      expect(s?.name, 'Casino');
      expect(s?.gameType, GameType.tournament);
      expect(s?.buyIn, 80);
      expect(s?.startingStack, 15000);
      expect(
          TrackedSession.fromSession(
              'x', {'sessionType': 'hand_group', 'startTime': 'z'}),
          isNull);
    });
  });
}
