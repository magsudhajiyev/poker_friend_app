import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/design_system/components/buttons/app_button.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/screens/hand_actions_screen.dart';
import 'package:poker_logger/services/live_session_logic.dart';
import 'package:poker_logger/services/live_session_notification_service.dart';
import 'package:poker_logger/services/running_session_lock.dart';
import 'package:poker_logger/services/screen_capture_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _hand(String sessionId, {bool withAction = false}) => {
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
      'actions': withAction
          ? [
              {
                'player': 2,
                'action': 'raise',
                'street': 'preflop',
                'amount': 6.0,
                'playerName': 'Villain',
                'playerPosition': 'BB',
                'timestamp': '2026-11-25T20:00:00.000',
                'buttonPosition': 1,
              },
              {
                'player': 1,
                'action': 'call',
                'street': 'preflop',
                'amount': 6.0,
                'playerName': 'Hero',
                'playerPosition': 'BTN',
                'isCurrentUser': true,
                'timestamp': '2026-11-25T20:00:01.000',
                'buttonPosition': 1,
              },
            ]
          : <Map<String, dynamic>>[],
      'potAmount': 4.0,
    };

LiveSessionRecord _rec(String id) => LiveSessionRecord(
    sessionId: id,
    name: 'n',
    gameType: 'cash',
    startTime: DateTime(2026, 11, 25, 20));

final _secure = <bool>[];

Future<void> _open(WidgetTester t, Map<String, dynamic> hand) async {
  t.view.physicalSize = const Size(1170, 2532);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: HandActionsScreen(hand: hand, ourSeat: 1),
  ));
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}

Finder get _aiLine => find.byKey(const ValueKey('ai-locked-line'));
Finder get _share => find.byIcon(Icons.ios_share);

bool _toolEnabled(WidgetTester t, Finder icon) {
  final op = t.widget<Opacity>(
      find.ancestor(of: icon, matching: find.byType(Opacity)).first);
  return op.opacity == 1;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _secure.clear();
    ScreenCaptureGuard.resetForTest();
    LiveSessionNotificationService.running.value = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ScreenCaptureGuard.channel, (c) async {
      _secure.add((c.arguments as Map)['secure'] as bool);
      return null;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ScreenCaptureGuard.channel, null);
    LiveSessionNotificationService.running.value = null;
    RunningSessionLock.debugForceIos = null;
  });

  testWidgets('running session: AI locked with a line, share/export disabled',
      (t) async {
    LiveSessionNotificationService.running.value = _rec('s1');
    await _open(t, _hand('s1'));
    expect(_aiLine, findsOneWidget);
    expect(find.text('Available when the session ends.'), findsWidgets);
    expect(_toolEnabled(t, _share), isFalse);
    expect(_toolEnabled(t, find.byIcon(Icons.download)), isFalse);
    expect(_secure, [true]);
  });

  testWidgets('capture block is cleared on leave', (t) async {
    LiveSessionNotificationService.running.value = _rec('s1');
    await _open(t, _hand('s1'));
    await t.pumpWidget(const SizedBox());
    await t.pump();
    expect(_secure, [true, false]);
  });

  testWidgets('session ends while open: everything unlocks by itself',
      (t) async {
    LiveSessionNotificationService.running.value = _rec('s1');
    await _open(t, _hand('s1'));
    LiveSessionNotificationService.running.value = null;
    await t.pump();
    expect(_aiLine, findsNothing);
    expect(_toolEnabled(t, _share), isTrue);
    expect(_secure, [true, false]);
  });

  testWidgets('ended session or hand group: nothing locked, no channel call',
      (t) async {
    LiveSessionNotificationService.running.value = _rec('other-session');
    await _open(t, _hand('group-1'));
    expect(_aiLine, findsNothing);
    expect(_toolEnabled(t, _share), isTrue);
    expect(_toolEnabled(t, find.byIcon(Icons.download)), isTrue);
    expect(_secure, isEmpty);
  });

  group('locked controls explain themselves', () {
    testWidgets('share, export and AI taps show an info snackbar', (t) async {
      LiveSessionNotificationService.running.value = _rec('s1');
      await _open(t, _hand('s1'));
      const share =
          'You can share and download this hand after the session ends.';
      await t.tap(find.byIcon(Icons.ios_share));
      await t.pump();
      expect(find.text(share), findsOneWidget);
      ScaffoldMessenger.of(t.element(find.byType(Scaffold).first))
          .clearSnackBars();
      await t.pump(const Duration(seconds: 1));

      await t.tap(find.byIcon(Icons.download));
      await t.pump();
      expect(find.text(share), findsOneWidget);
      ScaffoldMessenger.of(t.element(find.byType(Scaffold).first))
          .clearSnackBars();
      await t.pump(const Duration(seconds: 1));

      await t.ensureVisible(_aiLine);
      await t.tap(find.byType(AppButton));
      await t.pump();
      expect(find.text('AI analysis is available after the session ends.'),
          findsOneWidget);
    });

    testWidgets('an unlocked hand shows no snackbar for share', (t) async {
      await _open(t, _hand('group-1'));
      expect(find.text('Available when the session ends.'), findsNothing);
    });
  });

  group('iOS action blur', () {
    testWidgets('blurred only on iOS while the session runs', (t) async {
      RunningSessionLock.debugForceIos = true;
      LiveSessionNotificationService.running.value = _rec('s1');
      await _open(t, _hand('s1', withAction: true));
      expect(find.byKey(const ValueKey('actions-blur')), findsOneWidget);
      expect(find.text('Actions are visible after the session ends.'),
          findsOneWidget);
      LiveSessionNotificationService.running.value = null; // session ends
      await t.pump();
      expect(find.byKey(const ValueKey('actions-blur')), findsNothing);
    });

    testWidgets('Android: no blur while running', (t) async {
      RunningSessionLock.debugForceIos = false;
      LiveSessionNotificationService.running.value = _rec('s1');
      await _open(t, _hand('s1', withAction: true));
      expect(find.byKey(const ValueKey('actions-blur')), findsNothing);
    });

    testWidgets('iOS, hand group: no blur', (t) async {
      RunningSessionLock.debugForceIos = true;
      await _open(t, _hand('group-1', withAction: true));
      expect(find.byKey(const ValueKey('actions-blur')), findsNothing);
    });
  });
}
