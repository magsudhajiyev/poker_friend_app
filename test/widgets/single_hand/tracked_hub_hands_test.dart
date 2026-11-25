import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/models/game_types.dart';
import 'package:poker_logger/screens/tracked_session_hub.dart';
import 'package:poker_logger/services/hand_delete_service.dart';
import 'package:poker_logger/services/tracked_session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _h(int n) => {
      'id': 'h$n',
      'handNumber': n,
      'heroPositionName': 'BTN',
      'ourHoleCards': {'card1': 'A♠', 'card2': 'K♥'},
    };

void main() {
  late List<Map<String, dynamic>> stored;
  late int loads;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    stored = [_h(1), _h(2), _h(3)];
    loads = 0;
    TrackedSessionService.handsLoader = (id) async {
      loads++;
      return [...stored];
    };
  });

  Future<void> pumpHub(WidgetTester t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final session = TrackedSession(
        id: 's1',
        name: 'Casino',
        gameType: GameType.cash,
        buyIn: 100,
        startingStack: 100,
        startTime: DateTime.now());
    await t.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TrackedSessionHub.screenFor(session),
    ));
    await t.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a deleted hand leaves the list and the count (deletions bump)',
      (t) async {
    await pumpHub(t);
    expect(find.text('Hands (3)'), findsOneWidget);
    stored.removeAt(1);
    HandDeleteService.deletions.value++;
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Hands (2)'), findsOneWidget);
    expect(find.byKey(const ValueKey('tracked-hand-2')), findsNothing);
    expect(find.byKey(const ValueKey('tracked-hand-3')), findsOneWidget);
  });

  testWidgets('the list reloads when the player comes back from hand details',
      (t) async {
    await pumpHub(t);
    final before = loads;
    await t.tap(find.byKey(const ValueKey('tracked-hand-1')));
    await t.pump(const Duration(milliseconds: 400));
    // Hand details are open; a hand is deleted there and the screen closes.
    stored.removeAt(0);
    Navigator.of(t.element(find.byType(Scaffold).last)).pop();
    await t.pumpAndSettle();
    expect(loads, greaterThan(before));
    expect(find.text('Hands (2)'), findsOneWidget);
    expect(find.byKey(const ValueKey('tracked-hand-1')), findsNothing);
  });

  testWidgets('the last hand deleted: the hub just shows no list',
      (t) async {
    await pumpHub(t);
    stored.clear();
    HandDeleteService.deletions.value++;
    await t.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Hands ('), findsNothing);
    expect(find.text('Log a Hand'), findsOneWidget); // session stays
  });

  test('a hand group that loses its last hand is left as it is', () {
    final src = File('lib/services/hand_delete_service.dart').readAsStringSync();
    final del = src.substring(src.indexOf('static Future<void> delete('));
    expect(del.contains('deleteSession'), isFalse);
    expect(del.contains('discard'), isFalse);
  });
}
