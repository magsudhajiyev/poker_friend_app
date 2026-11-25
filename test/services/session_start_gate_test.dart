import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/models/game_types.dart';
import 'package:poker_logger/services/live_session_logic.dart';
import 'package:poker_logger/services/live_session_notification_service.dart';
import 'package:poker_logger/services/session_navigation.dart';
import 'package:poker_logger/services/session_start_gate.dart';
import 'package:poker_logger/services/tracked_session_service.dart';
import 'package:poker_logger/widgets/running_session_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _t0 = DateTime(2026, 11, 25, 20, 0);

class _B implements TrackedSessionBackend {
  final created = <String>[];
  @override
  Future<void> create(TrackedSession s) async => created.add(s.id);
  @override
  Future<Map<String, dynamic>?> load(String id) async => null;
  @override
  Future<int> handCount(String id) async => 0;
  @override
  Future<void> recordResult(String id,
      {double? currentStack,
      int? finishedPlace,
      int? fieldSize,
      double? prizeWon}) async {}
  @override
  Future<void> end(String id, DateTime at) async {}
  @override
  Future<void> discard(String id) async {}
}

Map<String, dynamic> _row(String id,
        {String type = 'tracked',
        String game = 'tournament',
        DateTime? start,
        String? end,
        bool tutorial = false,
        String? kind}) =>
    {
      'id': id,
      'sessionType': kind == 'full' ? null : type,
      'gameType': game,
      'sessionName': 'S-$id',
      'startTime': (start ?? _t0).toIso8601String(),
      'endTime': end,
      'isTutorial': tutorial,
    };

LiveSessionRecord _rec(String id,
        {String kind = LiveSessionRecord.kindTracked,
        String game = 'tournament'}) =>
    LiveSessionRecord(
        sessionId: id,
        name: 'S-$id',
        gameType: game,
        startTime: _t0,
        kind: kind);

void main() {
  late _B backend;
  late List<LiveSessionRecord> rebuilt;
  late List<String> dropped;
  LiveSessionRecord? record;
  List<Map<String, dynamic>> rows = [];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SessionNavigation.reset();
    SessionStartGate.pendingFull = null;
    backend = _B();
    rebuilt = [];
    dropped = [];
    record = null;
    rows = [];
    SessionStartGate.now = () => _t0.add(const Duration(hours: 1));
    SessionStartGate.currentRecord = () async => record;
    SessionStartGate.localSessions = () async => rows;
    SessionStartGate.localSession = (id) async {
      for (final r in rows) {
        if (r['id'] == id) return r;
      }
      return null;
    };
    SessionStartGate.rebuildRecord = (r) async => rebuilt.add(r);
    SessionStartGate.dropRecord = (id) async => dropped.add(id);
    TrackedSessionService.backend = backend;
    TrackedSessionService.newId = () => 'new';
    TrackedSessionService.liveStart = (s) async {};
    TrackedSessionService.liveStop = (id) async {};
  });

  Future<Object?> tryStart(GameType t) async {
    try {
      await TrackedSessionService.start(name: 'n', gameType: t, buyIn: 100);
      return null;
    } catch (e) {
      return e;
    }
  }

  group('service-level rule: nothing is created while a session runs', () {
    test('tournament running -> a CASH session is refused, nothing created',
        () async {
      record = _rec('t1', game: 'tournament');
      rows = [_row('t1')];
      expect(await tryStart(GameType.cash), isA<SessionAlreadyRunning>());
      expect(backend.created, isEmpty);
    });

    test('cash running -> a TOURNAMENT session is refused', () async {
      record = _rec('c1', game: 'cash');
      rows = [_row('c1', game: 'cash')];
      expect(await tryStart(GameType.tournament), isA<SessionAlreadyRunning>());
      expect(backend.created, isEmpty);
    });

    test('a running FULL session (either game) refuses a tracked start',
        () async {
      record = _rec('f1', kind: LiveSessionRecord.kindFull, game: 'tournament');
      rows = [_row('f1', kind: 'full')];
      expect(await tryStart(GameType.cash), isA<SessionAlreadyRunning>());
      expect(backend.created, isEmpty);
    });

    test('nothing running: the session is created', () async {
      expect(await tryStart(GameType.cash), isNull);
      expect(backend.created, ['new']);
    });
  });

  group('the data is the source of truth', () {
    test('record missing, data says a tracked tournament runs: blocked and '
        'the record is rebuilt', () async {
      rows = [_row('t1')];
      expect(await tryStart(GameType.cash), isA<SessionAlreadyRunning>());
      expect(backend.created, isEmpty);
      expect(rebuilt.single.sessionId, 't1');
      expect(rebuilt.single.kind, LiveSessionRecord.kindTracked);
      expect(rebuilt.single.gameType, 'tournament');
      expect(rebuilt.single.name, 'S-t1');
    });

    test('an orphaned FULL session from the last 24 h blocks too', () async {
      rows = [_row('f1', kind: 'full', game: 'tournament')];
      final r = await SessionStartGate.findRunning();
      expect(r?.kind, LiveSessionRecord.kindFull);
      expect(rebuilt.single.sessionId, 'f1');
    });

    test('an old abandoned full session never blocks', () async {
      rows = [
        _row('old',
            kind: 'full', start: _t0.subtract(const Duration(days: 40)))
      ];
      expect(await SessionStartGate.findRunning(), isNull);
      expect(rebuilt, isEmpty);
    });

    test('ended sessions, tutorials and hand groups are not running',
        () async {
      rows = [
        _row('e1', end: _t0.toIso8601String()),
        _row('tut', kind: 'full', tutorial: true),
        _row('hg', type: 'hand_group'),
      ];
      expect(await SessionStartGate.findRunning(), isNull);
    });

    test('a stale record (its session ended) is dropped and does not block',
        () async {
      record = _rec('t1');
      rows = [_row('t1', end: _t0.toIso8601String())];
      expect(await SessionStartGate.findRunning(), isNull);
      expect(dropped, ['t1']);
    });

    test('the newest running session wins when only the data knows', () async {
      rows = [
        _row('a', start: _t0),
        _row('b', start: _t0.add(const Duration(minutes: 30))),
      ];
      expect((await SessionStartGate.findRunning())?.sessionId, 'b');
    });
  });

  testWidgets('a full session whose hub is open but not created yet blocks',
      (t) async {
    SessionStartGate.pendingFull = (name: 'Home game', gameType: 'tournament');
    late NavigatorState nav;
    await t.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      nav = Navigator.of(c);
      return const SizedBox();
    })));
    final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());
    SessionNavigation.track(SessionNavigation.fullHubKey, route);
    nav.push(route);
    await t.pumpAndSettle();
    final r = await SessionStartGate.findRunning();
    expect(r?.sessionId, SessionStartGate.pendingFullId);
    expect(r?.name, 'Home game');
    expect(r?.gameType, 'tournament');
    expect(await tryStart(GameType.cash), isA<SessionAlreadyRunning>());
    // The full session's own table starting is not "another" session.
    await SessionStartGate.assertNoRunning(ignorePending: true);
  });

  group('LiveSessionNotificationService.start never replaces a running one',
      () {
    test('a different running record is kept', () async {
      LiveSessionNotificationService.isStale = (r) async => false;
      await LiveSessionNotificationService.start(
          sessionId: 'a',
          name: 'A',
          gameType: 'tournament',
          startTime: _t0);
      await LiveSessionNotificationService.start(
          sessionId: 'b', name: 'B', gameType: 'cash', startTime: _t0);
      final cur = await LiveSessionNotificationService.current();
      expect(cur?.sessionId, 'a');
      expect(LiveSessionNotificationService.running.value?.sessionId, 'a');
    });

    test('the same session may be re-started (restore)', () async {
      LiveSessionNotificationService.isStale = (r) async => false;
      await LiveSessionNotificationService.start(
          sessionId: 'a', name: 'A', gameType: 'cash', startTime: _t0);
      await LiveSessionNotificationService.start(
          sessionId: 'a', name: 'A2', gameType: 'cash', startTime: _t0);
      expect((await LiveSessionNotificationService.current())?.name, 'A2');
    });

    test('a stale record (its session ended) is replaced', () async {
      await LiveSessionNotificationService.stop('a');
      LiveSessionNotificationService.isStale = (r) async => false;
      await LiveSessionNotificationService.start(
          sessionId: 'a', name: 'A', gameType: 'cash', startTime: _t0);
      LiveSessionNotificationService.isStale = (r) async => true;
      await LiveSessionNotificationService.start(
          sessionId: 'b', name: 'B', gameType: 'cash', startTime: _t0);
      expect((await LiveSessionNotificationService.current())?.sessionId, 'b');
    });
  });

  group('every entry point goes through the same gate', () {
    Future<void> blocked(WidgetTester t,
        {required LiveSessionRecord running,
        required List<Map<String, dynamic>> data,
        LiveSessionRecord? stored}) async {
      record = stored;
      rows = data;
      RunningSessionGuard.current = SessionStartGate.findRunning;
      bool? ok;
      await t.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
              builder: (c) => TextButton(
                    onPressed: () async =>
                        ok = await RunningSessionGuard.ensureFree(c),
                    child: const Text('start'),
                  )),
        ),
      ));
      await t.tap(find.text('start'));
      await t.pumpAndSettle();
      expect(find.text('A session is running'), findsOneWidget);
      expect(
          find.text(
              '${running.name} is still running. End it before you start a new session.'),
          findsOneWidget);
      expect(find.text('Go to session'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(ok, isFalse);
    }

    testWidgets('UI gate: tracked tournament running (record present)',
        (t) async {
      await blocked(t,
          running: _rec('t1'), data: [_row('t1')], stored: _rec('t1'));
    });

    testWidgets('UI gate: record LOST, data says tournament runs',
        (t) async {
      await blocked(t, running: _rec('t1'), data: [_row('t1')]);
      expect(rebuilt.single.sessionId, 't1'); // Home bar can show it again
    });

    testWidgets('UI gate: cash running blocks a tournament start too',
        (t) async {
      await blocked(t,
          running: _rec('c1', game: 'cash'),
          data: [_row('c1', game: 'cash')],
          stored: _rec('c1', game: 'cash'));
    });

    testWidgets('UI gate: a full session running', (t) async {
      await blocked(t,
          running: _rec('f1', kind: LiveSessionRecord.kindFull),
          data: [_row('f1', kind: 'full')],
          stored: _rec('f1', kind: LiveSessionRecord.kindFull));
    });
  });

  test('every session creator is wired to the gate (source guard)', () {
    String src(String p) => File(p).readAsStringSync();
    // Service level: the tracked start itself refuses.
    expect(src('lib/services/tracked_session_service.dart'),
        contains('SessionStartGate.assertNoRunning()'));
    // Full-session start (Unified setup) and tracked setup ask first.
    expect(src('lib/screens/unified_session_setup_screen.dart'),
        contains('RunningSessionGuard.ensureFree(context)'));
    expect(src('lib/screens/tracked_session_setup_screen.dart'),
        contains('RunningSessionGuard.ensureFree(context)'));
    // The guard reads the reconciled data, not only the stored record.
    expect(src('lib/widgets/running_session_guard.dart'),
        contains('SessionStartGate.findRunning'));
    // Every createSession caller: the full-session creator, hand groups
    // (never "running") and the tracked backend.
    final creators = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is File &&
          f.path.endsWith('.dart') &&
          f.readAsStringSync().contains('FirebaseService.createSession(')) {
        creators.add(f.path);
      }
    }
    creators.sort();
    expect(creators, [
      'lib/models/hand_state_machine.dart', // full session (gated at setup)
      'lib/services/single_hand_service.dart', // hand groups, never running
      'lib/services/tracked_session_service.dart', // gated in start()
    ]);
  });
}
