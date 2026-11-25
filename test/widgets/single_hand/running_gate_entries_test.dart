import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/screens/logging_mode_selection_screen.dart';
import 'package:poker_logger/screens/tracked_session_setup_screen.dart';
import 'package:poker_logger/screens/unified_session_setup_screen.dart';
import 'package:poker_logger/services/feature_flag_service.dart';
import 'package:poker_logger/services/live_session_logic.dart';
import 'package:poker_logger/services/live_session_notification_service.dart';
import 'package:poker_logger/services/session_start_gate.dart';
import 'package:poker_logger/utils/running_session_label.dart';
import 'package:poker_logger/services/tracked_session_service.dart';
import 'package:poker_logger/widgets/live_session_bar.dart';
import 'package:poker_logger/widgets/running_session_end.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _t0 = DateTime(2026, 11, 25, 13, 28);

Map<String, dynamic> _row(String id,
        {String name = '', bool tracked = true, String game = 'cash',
        DateTime? start}) =>
    {
      'id': id,
      'sessionType': tracked ? 'tracked' : null,
      'gameType': game,
      'sessionName': name,
      'startTime': (start ?? _t0).toIso8601String(),
      'endTime': null,
      'isTutorial': false,
    };

LiveSessionRecord _rec(String id, {String name = 'Test', bool full = false}) =>
    LiveSessionRecord(
        sessionId: id,
        name: name,
        gameType: 'cash',
        startTime: _t0,
        kind: full ? LiveSessionRecord.kindFull : LiveSessionRecord.kindTracked);

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

class _Docs implements TrackedSessionBackend {
  final List<Map<String, dynamic>> Function() rows;
  _Docs(this.rows);
  @override
  Future<Map<String, dynamic>?> load(String id) async {
    for (final r in rows()) {
      if (r['id'] == id) return r;
    }
    return null;
  }

  @override
  Future<void> create(TrackedSession s) async {}
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

void main() {
  List<Map<String, dynamic>> rows = [];
  LiveSessionRecord? record;
  late List<LiveSessionRecord> rebuilt;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    rows = [];
    record = null;
    rebuilt = [];
    LiveSessionNotificationService.stoppedIds.clear();
    LiveSessionNotificationService.running.value = null;
    SessionStartGate.pendingFull = null;
    SessionStartGate.now = () => _t0.add(const Duration(hours: 2));
    SessionStartGate.currentRecord = () async => record;
    SessionStartGate.localSessions = () async => rows;
    SessionStartGate.localSession = (id) async {
      for (final r in rows) {
        if (r['id'] == id) return r;
      }
      return null;
    };
    SessionStartGate.rebuildRecord = (r) async {
      rebuilt.add(r);
      record = r;
      LiveSessionNotificationService.running.value = r;
    };
    SessionStartGate.dropRecord = (id) async {
      if (record?.sessionId == id) record = null;
    };
    TrackedSessionService.backend = _Docs(() => rows);
    await FeatureFlagService.applyRemote(
        {'tracked_session': 'on', 'single_hand': 'off', 'training_drills': 'off'});
  });

  group('the warning comes FIRST: the + cards never open a setup', () {
    Future<void> tapCard(WidgetTester t, String title) async {
      t.view.physicalSize = const Size(1170, 4000);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(_app(const LoggingModeSelectionScreen()));
      await t.pumpAndSettle();
      await t.tap(find.text(title));
      await t.pumpAndSettle();
    }

    for (final running in [
      ('tracked', _rec('t1'), _row('t1')),
      ('full', _rec('f1', full: true), _row('f1', tracked: false)),
    ]) {
      testWidgets('Full logging card is blocked while a ${running.$1} '
          'session runs', (t) async {
        record = running.$2;
        rows = [running.$3];
        await tapCard(t, 'Logging Mode');
        expect(find.text('A session is running'), findsOneWidget);
        expect(find.text('Test is still running. End it before you start a new session.'),
            findsOneWidget);
        expect(find.byType(UnifiedSessionSetupScreen), findsNothing);
        expect(find.text('Go to session'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Continue anyway'), findsNothing);
        await t.tap(find.text('Cancel'));
        await t.pumpAndSettle();
        expect(find.byType(UnifiedSessionSetupScreen), findsNothing);
      });

      testWidgets('Track a session card is blocked while a ${running.$1} '
          'session runs', (t) async {
        record = running.$2;
        rows = [running.$3];
        await tapCard(t, 'Track a session');
        expect(find.text('A session is running'), findsOneWidget);
        expect(find.byType(TrackedSessionSetupScreen), findsNothing);
      });
    }

    testWidgets('nothing running: the cards open their setup', (t) async {
      await tapCard(t, 'Track a session');
      expect(find.byType(TrackedSessionSetupScreen), findsOneWidget);
    });

    testWidgets('record LOST but data says running: still blocked',
        (t) async {
      rows = [_row('t1', name: 'Test', game: 'tournament')];
      await tapCard(t, 'Track a session');
      expect(find.text('A session is running'), findsOneWidget);
      expect(find.byType(TrackedSessionSetupScreen), findsNothing);
    });
  });

  testWidgets('three running sessions: ending one surfaces the next',
      (t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    rows = [
      _row('a', name: 'Cash A', start: _t0.add(const Duration(minutes: 66))),
      _row('b', name: 'Test', game: 'tournament',
          start: _t0.add(const Duration(minutes: 41))),
      _row('c', name: '', tracked: false, start: _t0),
    ];
    record = _rec('a', name: 'Cash A');
    LiveSessionNotificationService.running.value = record;
    await t.pumpWidget(_app(const Scaffold(body: LiveSessionBar())));
    await t.pump();
    expect(find.textContaining('Cash A'), findsOneWidget);

    Future<void> endIt(String id) async {
      rows.removeWhere((r) => r['id'] == id); // endTime written
      LiveSessionNotificationService.stoppedIds.add(id);
      record = null;
      LiveSessionNotificationService.running.value = null; // stop()
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      await t.pump();
    }

    await endIt('a');
    expect(find.textContaining('Test'), findsOneWidget); // next one (tournament)
    expect(rebuilt.last.sessionId, 'b');
    await endIt('b');
    // The legacy full session has no name: a sensible label, not blank.
    expect(find.textContaining('Cash Game · Nov 25'), findsOneWidget);
    expect(rebuilt.last.sessionId, 'c');
    await endIt('c');
    expect(find.textContaining('Cash Game'), findsNothing); // bar gone
    expect(LiveSessionNotificationService.running.value, isNull);
  });

  test('a stopped session is never rebuilt from data (end write racing)',
      () async {
    rows = [_row('a', name: 'A')]; // endTime not written yet
    LiveSessionNotificationService.stoppedIds.add('a');
    expect(await SessionStartGate.findRunning(), isNull);
  });

  testWidgets('an empty name reads like "Cash Game · Nov 25"', (t) async {
    late BuildContext ctx;
    await t.pumpWidget(_app(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));
    final l10n = AppLocalizations.of(ctx);
    expect(runningSessionLabel(l10n, _rec('x', name: '')), 'Cash Game · Nov 25');
    expect(runningSessionLabel(l10n, _rec('x', name: ' Home ')), 'Home');
  });

  group('an orphaned FULL session ends through the normal end sheet', () {
    testWidgets('cash: sheet default from the last stack; written; stopped',
        (t) async {
      rows = [
        {
          ..._row('f1', tracked: false),
          'totalBuyIn': 100.0,
          'stackHistory': [
            {'stackSize': 100.0},
            {'stackSize': 160.0}
          ],
        }
      ];
      Map<String, dynamic>? args;
      RunningSessionEnd.showSheet = (c,
          {required gameType,
          required profitLoss,
          required totalBuyIn,
          required durationMinutes,
          required endTime}) async {
        args = {'profit': profitLoss, 'buyIn': totalBuyIn, 'type': gameType};
        return {'profitLoss': 55.0};
      };
      final done = <String>[];
      RunningSessionEnd.finishFull = (r, buyIn, res, end) async =>
          done.add('${r.sessionId}:$buyIn:${res['profitLoss']}');
      late bool ok;
      await t.pumpWidget(_app(Builder(
        builder: (c) => TextButton(
          onPressed: () async => ok = await RunningSessionEnd.end(
              c, _rec('f1', full: true), _t0.add(const Duration(hours: 1))),
          child: const Text('go'),
        ),
      )));
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      expect(ok, isTrue);
      expect(args!['profit'], 60.0);
      expect(args!['buyIn'], 100.0);
      expect(done, ['f1:100.0:55.0']);
    });

    testWidgets('closing the sheet keeps it running', (t) async {
      rows = [
        {..._row('f1', tracked: false), 'totalBuyIn': 100.0}
      ];
      RunningSessionEnd.showSheet = (c,
              {required gameType,
              required profitLoss,
              required totalBuyIn,
              required durationMinutes,
              required endTime}) async =>
          null;
      final done = <String>[];
      RunningSessionEnd.finishFull =
          (r, b, res, end) async => done.add(r.sessionId);
      late bool ok;
      await t.pumpWidget(_app(Builder(
        builder: (c) => TextButton(
          onPressed: () async => ok = await RunningSessionEnd.end(
              c, _rec('f1', full: true), _t0.add(const Duration(hours: 1))),
          child: const Text('go'),
        ),
      )));
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      expect(ok, isFalse);
      expect(done, isEmpty);
    });
  });
}
