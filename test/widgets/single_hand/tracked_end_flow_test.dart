import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/models/game_types.dart';
import 'package:poker_logger/models/single_hand_setup.dart';
import 'package:poker_logger/models/tracked_session.dart';
import 'package:poker_logger/screens/single_hand_setup_screen.dart';
import 'package:poker_logger/services/live_session_logic.dart';
import 'package:poker_logger/services/tracked_session_service.dart';
import 'package:poker_logger/widgets/running_session_end.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _start = DateTime(2026, 11, 24, 20, 0);
final _realEnd = DateTime(2026, 11, 24, 23, 30);

class _B implements TrackedSessionBackend {
  final calls = <String>[];
  DateTime? endedAt;
  Map<String, dynamic>? doc;
  @override
  Future<void> create(TrackedSession s) async {}
  @override
  Future<Map<String, dynamic>?> load(String id) async => doc;
  @override
  Future<int> handCount(String id) async => 0;
  @override
  Future<void> recordResult(String id,
          {double? currentStack,
          int? finishedPlace,
          int? fieldSize,
          double? prizeWon}) async =>
      calls.add('result:$currentStack:$finishedPlace:$fieldSize:$prizeWon');
  @override
  Future<void> end(String id, DateTime at) async {
    endedAt = at;
    calls.add('end');
  }

  @override
  Future<void> discard(String id) async {}
}

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

LiveSessionRecord _record() => LiveSessionRecord(
    sessionId: 's', name: 'Casino', gameType: 'cash', startTime: _start);

void main() {
  late _B b;
  late List<String> live;
  Map<String, dynamic>? sheetArgs;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    b = _B();
    live = [];
    sheetArgs = null;
    TrackedSessionService.backend = b;
    TrackedSessionService.now = () => DateTime(2026, 11, 25, 12);
    TrackedSessionService.liveStop = (id) async => live.add('stop:$id');
  });

  Future<bool> run(WidgetTester t, LiveSessionRecord r, DateTime end,
      Map<String, dynamic>? sheetResult) async {
    RunningSessionEnd.showSheet = (c,
        {required gameType,
        required profitLoss,
        required totalBuyIn,
        required durationMinutes,
        required endTime}) async {
      sheetArgs = {
        'type': gameType,
        'profit': profitLoss,
        'buyIn': totalBuyIn,
        'minutes': durationMinutes,
        'end': endTime,
      };
      return sheetResult;
    };
    late bool ok;
    await t.pumpWidget(_app(Builder(
      builder: (c) => TextButton(
        onPressed: () async => ok = await RunningSessionEnd.end(c, r, end),
        child: const Text('go'),
      ),
    )));
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    return ok;
  }

  group('1: ending a tracked session from a prompt uses the normal sheet', () {
    testWidgets('cash: sheet asks the cash-out, default from the last stack',
        (t) async {
      b.doc = {
        'sessionType': 'tracked',
        'gameType': 'cash',
        'startTime': _start.toIso8601String(),
        'buyInAmount': 100.0,
        'totalBuyIn': 200.0,
        'currentStack': 260.0,
      };
      final ok = await run(t, _record(), _realEnd,
          {'profitLoss': 55.0, 'finishedPlace': null});
      expect(ok, isTrue);
      expect(sheetArgs!['type'], GameType.cash);
      expect(sheetArgs!['profit'], 60.0);
      expect(sheetArgs!['buyIn'], 200.0);
      expect(b.calls.first, 'result:255.0:null:null:null'); // 200 + 55
      expect(live, ['stop:s']);
    });

    testWidgets('tournament: sheet asks prize and place; the row is written',
        (t) async {
      b.doc = {
        'sessionType': 'tracked',
        'gameType': 'tournament',
        'startTime': _start.toIso8601String(),
        'buyInAmount': 50.0,
      };
      final ok = await run(
          t,
          LiveSessionRecord(
              sessionId: 's',
              name: 'T',
              gameType: 'tournament',
              startTime: _start),
          _realEnd,
          {
            'profitLoss': 150.0,
            'finishedPlace': 3,
            'fieldSize': 90,
            'prizeWon': 200.0
          });
      expect(ok, isTrue);
      expect(sheetArgs!['type'], GameType.tournament);
      expect(sheetArgs!['profit'], isNull);
      expect(b.calls.first, 'result:null:3:90:200.0');
    });

    testWidgets('closing the sheet keeps the session running', (t) async {
      b.doc = {
        'sessionType': 'tracked',
        'gameType': 'cash',
        'startTime': _start.toIso8601String(),
        'buyInAmount': 100.0,
      };
      expect(await run(t, _record(), _realEnd, null), isFalse);
      expect(b.calls, isEmpty);
      expect(live, isEmpty);
    });
  });

  group('2: a real end time drives duration and play time', () {
    testWidgets('sheet duration and the stored end use THAT time, not now',
        (t) async {
      b.doc = {
        'sessionType': 'tracked',
        'gameType': 'cash',
        'startTime': _start.toIso8601String(),
        'buyInAmount': 100.0,
      };
      await run(t, _record(), _realEnd, {'profitLoss': 0.0});
      expect(sheetArgs!['minutes'], 210); // 20:00 -> 23:30
      expect(sheetArgs!['end'], _realEnd);
      expect(b.endedAt, _realEnd);
    });

    test('the end path forwards the time to every writer', () {
      String src(String p) => File(p).readAsStringSync();
      expect(src('lib/services/firebase_service.dart'),
          contains('(endTime ?? DateTime.now())'));
      expect(src('lib/services/firebase_service.dart'),
          contains('Timestamp.fromDate(endTime)'));
      expect(src('lib/services/session_result_service.dart'),
          contains('Timestamp.fromDate(endTime)'));
      expect(src('lib/widgets/session_end_bankroll_sheet.dart'),
          contains('endTime: endTime'));
      expect(src('lib/services/tracked_session_service.dart'),
          contains('endTime: real ? at : null'));
    });
  });

  group('3: a session-forced game type is not saved as last used', () {
    testWidgets('cash session leaves a tournament last-used setup alone',
        (t) async {
      t.view.physicalSize = const Size(1170, 2532);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await SingleHandSetup(
              gameType: GameType.tournament,
              smallBlind: 100,
              bigBlind: 200,
              stackBB: 30,
              heroPosition: 'BTN')
          .saveAsLastUsed();

      await t.pumpWidget(_app(Builder(
        builder: (c) => TextButton(
          onPressed: () async => SingleHandSetupScreen.show(c,
              session: const SingleHandSessionTarget(
                  'sess', 'Casino', GameType.cash)),
          child: const Text('open'),
        ),
      )));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.tap(find.text('Start hand'));
      await t.pumpAndSettle();

      final last = await SingleHandSetup.loadLastUsed();
      expect(last.gameType, GameType.tournament);
      expect(last.smallBlind, 100);
      expect(last.bigBlind, 200);
    });
  });
}
