import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/screens/hand_actions_screen.dart';
import 'package:poker_logger/services/hand_delete_service.dart';
import 'package:poker_logger/services/live_session_logic.dart';
import 'package:poker_logger/services/live_session_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Backend implements HandDeleteBackend {
  final calls = <String>[];
  @override
  Future<Map<String, dynamic>?> loadSession(String id) async => id == 'full'
      ? {'totalHands': 5}
      : {'sessionType': id == 'group' ? 'hand_group' : 'tracked'};
  @override
  Future<void> deleteHand({
    required String sessionId,
    required String? handId,
    required int? handNumber,
    required bool touchEndTime,
  }) async =>
      calls.add('$sessionId:$handId:$handNumber');
}

Map<String, dynamic> _hand(String sessionId) => {
      'id': 'h1',
      'sessionId': sessionId,
      'handNumber': 3,
      'completeness': 'full',
      'buttonPosition': 1,
      'playerCount': 2,
      'gameType': 'cash',
      'smallBlind': 1.0,
      'bigBlind': 2.0,
      'heroSeatNumber': 1,
      'heroPositionName': 'BTN',
      'ourHoleCards': {'card1': 'A♠', 'card2': 'K♠'},
      'playerNames': {'1': 'Hero', '2': 'Villain'},
      'actions': <Map<String, dynamic>>[],
      'potAmount': 4.0,
    };

Future<void> _open(WidgetTester t, String sessionId, List<bool?> popped) async {
  t.view.physicalSize = const Size(1170, 2532);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (c) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async => popped.add(await Navigator.push<bool>(
                c,
                MaterialPageRoute(
                    builder: (_) => HandActionsScreen(
                        hand: _hand(sessionId), ourSeat: 1)))),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await t.tap(find.text('open'));
  await t.pump();
  await t.pump(const Duration(seconds: 1));
}

void main() {
  late _Backend b;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    b = _Backend();
    HandDeleteService.backend = b;
    LiveSessionNotificationService.running.value = null;
  });

  testWidgets('delete is offered for hand-group and tracked-session hands',
      (t) async {
    await _open(t, 'group', []);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await _open(t, 'tracked', []);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('delete is NOT offered for a full-session hand', (t) async {
    await _open(t, 'full', []);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('confirm deletes and pops with true; cancel keeps the hand',
      (t) async {
    final popped = <bool?>[];
    await _open(t, 'group', popped);
    await t.tap(find.byIcon(Icons.delete_outline));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Delete this hand?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(b.calls, isEmpty);
    expect(popped, isEmpty);

    await t.tap(find.byIcon(Icons.delete_outline));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.text('Delete').last);
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    expect(b.calls, ['group:h1:3']);
    expect(popped, [true]);
  });

  testWidgets('delete still works while the session runs (share is locked)',
      (t) async {
    LiveSessionNotificationService.running.value = LiveSessionRecord(
        sessionId: 'tracked',
        name: 'n',
        gameType: 'cash',
        startTime: DateTime(2026, 11, 25, 20));
    await _open(t, 'tracked', []);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });
}
