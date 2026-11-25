import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/onboarding/onboarding_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/services/live_session_logic.dart';
import 'package:poker_logger/services/live_session_notification_service.dart';
import 'package:poker_logger/widgets/live_session_bar.dart';

void main() {
  final start = DateTime(2026, 11, 25, 18, 0);

  group('payload', () {
    test('round trip', () {
      final p = LiveSessionLogic.payload(LiveSessionAction.logHand, 'abc123');
      expect(p, 'live_session:log_hand:abc123');
      final r = LiveSessionLogic.parsePayload(p)!;
      expect(r.action, LiveSessionAction.logHand);
      expect(r.sessionId, 'abc123');
    });

    test('rejects foreign and malformed payloads', () {
      expect(LiveSessionLogic.parsePayload(null), isNull);
      expect(LiveSessionLogic.parsePayload('engagement:x:y'), isNull);
      expect(LiveSessionLogic.parsePayload('live_session:open:'), isNull);
      expect(LiveSessionLogic.parsePayload('live_session:nope:id'), isNull);
      expect(LiveSessionLogic.parsePayload('live_session:open'), isNull);
    });

    test('a tapped button overrides the body action', () {
      final body = LiveSessionLogic.payload(LiveSessionAction.open, 's1');
      expect(LiveSessionLogic.resolveTap(body, null)!.action,
          LiveSessionAction.open);
      expect(
          LiveSessionLogic.resolveTap(body, LiveSessionLogic.actionIdOpen)!
              .action,
          LiveSessionAction.open);
      final t =
          LiveSessionLogic.resolveTap(body, LiveSessionLogic.actionIdLogHand)!;
      expect(t.action, LiveSessionAction.logHand);
      expect(t.sessionId, 's1');
    });

    test('notification id is stable, positive, per session', () {
      final a = LiveSessionLogic.notificationId('session_1');
      expect(a, LiveSessionLogic.notificationId('session_1'));
      expect(a, isNot(LiveSessionLogic.notificationId('session_2')));
      expect(a, greaterThan(0));
      expect(a, lessThan(2147483647));
    });
  });

  group('24 h rule', () {
    test('threshold', () {
      expect(LiveSessionLogic.isOverdue(start, start.add(const Duration(hours: 24))),
          isFalse);
      expect(
          LiveSessionLogic.isOverdue(
              start, start.add(const Duration(hours: 24, minutes: 1))),
          isTrue);
    });

    test('end time validation', () {
      final now = start.add(const Duration(hours: 30));
      expect(
          LiveSessionLogic.validateEndTime(
              start, start.subtract(const Duration(minutes: 1)), now),
          EndTimeCheck.beforeStart);
      expect(
          LiveSessionLogic.validateEndTime(
              start, now.add(const Duration(minutes: 1)), now),
          EndTimeCheck.inFuture);
      expect(LiveSessionLogic.validateEndTime(start, start, now),
          EndTimeCheck.ok);
      expect(LiveSessionLogic.validateEndTime(start, now, now), EndTimeCheck.ok);
    });

    test('elapsed label', () {
      expect(LiveSessionLogic.elapsedLabel(start, start), '0m');
      expect(
          LiveSessionLogic.elapsedLabel(
              start, start.add(const Duration(minutes: 12))),
          '12m');
      expect(
          LiveSessionLogic.elapsedLabel(
              start, start.add(const Duration(hours: 2, minutes: 5))),
          '2h 05m');
      expect(
          LiveSessionLogic.elapsedLabel(
              start, start.subtract(const Duration(minutes: 5))),
          '0m');
    });
  });

  group('record', () {
    test('encode / decode', () {
      final r = LiveSessionRecord(
          sessionId: 's',
          name: 'Friday',
          gameType: 'tournament',
          startTime: start,
          kind: LiveSessionRecord.kindFull);
      final d = LiveSessionRecord.decode(r.encode())!;
      expect(d.sessionId, 's');
      expect(d.gameType, 'tournament');
      expect(d.kind, LiveSessionRecord.kindFull);
      expect(d.startTime, start);
    });

    test('corrupt data decodes to null', () {
      expect(LiveSessionRecord.decode(null), isNull);
      expect(LiveSessionRecord.decode('not json'), isNull);
      expect(LiveSessionRecord.decode('{"id":"","start":"x"}'), isNull);
      expect(LiveSessionRecord.decode('{"id":"a","start":"nope"}'), isNull);
    });
  });

  group('notification details', () {
    final d = LiveSessionNotificationService.androidDetails(
        startTime: start, logHandLabel: 'Log a hand', openLabel: 'Open session');

    test('ongoing, silent, system chronometer from the start time', () {
      expect(d.ongoing, isTrue);
      expect(d.autoCancel, isFalse);
      expect(d.onlyAlertOnce, isTrue);
      expect(d.showWhen, isTrue);
      expect(d.usesChronometer, isTrue);
      expect(d.when, start.millisecondsSinceEpoch);
      expect(d.playSound, isFalse);
      expect(d.enableVibration, isFalse);
      expect(d.importance.value, lessThan(3)); // low or below: no sound
    });

    test('two actions that open the app, no money text', () {
      expect(d.actions, hasLength(2));
      expect(d.actions!.map((a) => a.id),
          [LiveSessionLogic.actionIdLogHand, LiveSessionLogic.actionIdOpen]);
      expect(d.actions!.every((a) => a.showsUserInterface), isTrue);
      expect(d.actions!.every((a) => !a.cancelNotification), isTrue);
      final text = '${d.channelName}${d.channelDescription}'
          '${d.actions!.map((a) => a.title).join()}';
      expect(RegExp(r'[\$€£]').hasMatch(text), isFalse);
    });
  });

  group('service persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      LiveSessionNotificationService.running.value = null;
    });

    test('start persists, stop clears', () async {
      await LiveSessionNotificationService.start(
          sessionId: 's1', name: 'N', gameType: 'cash', startTime: start);
      final r = await LiveSessionNotificationService.current();
      expect(r!.sessionId, 's1');
      expect(LiveSessionNotificationService.running.value?.sessionId, 's1');
      await LiveSessionNotificationService.stop('s1');
      expect(await LiveSessionNotificationService.current(), isNull);
      expect(LiveSessionNotificationService.running.value, isNull);
    });

    test('stopping another session keeps the running one', () async {
      await LiveSessionNotificationService.start(
          sessionId: 's1', name: 'N', gameType: 'cash', startTime: start);
      await LiveSessionNotificationService.stop('other');
      expect((await LiveSessionNotificationService.current())?.sessionId, 's1');
    });

    test('restoreOnLaunch without a running session does nothing', () async {
      await LiveSessionNotificationService.restoreOnLaunch();
      expect(LiveSessionNotificationService.running.value, isNull);
    });

    test('restoreOnLaunch picks up a persisted session', () async {
      final r = LiveSessionRecord(
          sessionId: 'p', name: 'Persisted', gameType: 'cash', startTime: start);
      SharedPreferences.setMockInitialValues({'live_session_record': r.encode()});
      await LiveSessionNotificationService.restoreOnLaunch();
      expect(LiveSessionNotificationService.running.value?.sessionId, 'p');
    });

    test('restoreOnLaunch survives corrupt prefs', () async {
      SharedPreferences.setMockInitialValues({'live_session_record': '{{'});
      await LiveSessionNotificationService.restoreOnLaunch();
      expect(LiveSessionNotificationService.running.value, isNull);
    });
  });

  group('Home bar', () {
    Widget host() => MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: LiveSessionBar()),
        );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      LiveSessionNotificationService.running.value = null;
    });

    testWidgets('hidden when no session runs', (tester) async {
      await tester.pumpWidget(host());
      expect(find.text('Resume'), findsNothing);
    });

    testWidgets('takes no space during the in-app tour, even if it starts later',
        (tester) async {
      LiveSessionNotificationService.running.value = LiveSessionRecord(
          sessionId: 's',
          name: 'Friday game',
          gameType: 'cash',
          startTime: DateTime.now().subtract(const Duration(hours: 1)));
      await tester.pumpWidget(host());
      expect(find.text('Resume'), findsOneWidget);
      OnboardingState.isOnboardingActive = true;
      OnboardingState.notifier.value++;
      await tester.pump();
      expect(find.text('Resume'), findsNothing);
      expect(tester.getSize(find.byType(LiveSessionBar)).height, 0);
      OnboardingState.isOnboardingActive = false;
      LiveSessionNotificationService.running.value = null;
    });

    testWidgets('shows name, elapsed and Resume', (tester) async {
      LiveSessionNotificationService.running.value = LiveSessionRecord(
          sessionId: 's',
          name: 'Friday game',
          gameType: 'cash',
          startTime: DateTime.now().subtract(const Duration(hours: 1, minutes: 5)));
      await tester.pumpWidget(host());
      expect(find.text('Friday game · 1h 05m'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      LiveSessionNotificationService.running.value = null;
      await tester.pump();
      expect(find.text('Resume'), findsNothing);
    });
  });
}
