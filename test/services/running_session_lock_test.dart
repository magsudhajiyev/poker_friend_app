import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/live_session_logic.dart';
import 'package:poker_logger/services/live_session_notification_service.dart';
import 'package:poker_logger/services/running_session_lock.dart';
import 'package:poker_logger/services/screen_capture_guard.dart';

LiveSessionRecord _rec(String id, {String kind = 'tracked'}) =>
    LiveSessionRecord(
        sessionId: id,
        name: 'n',
        gameType: 'cash',
        startTime: DateTime(2026, 11, 25, 20),
        kind: kind);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => LiveSessionNotificationService.running.value = null);

  group('RunningSessionLock', () {
    test('locked for the running tracked and full session, free once ended',
        () {
      final hand = {'sessionId': 's1'};
      expect(RunningSessionLock.lockedHand(hand), isFalse);
      LiveSessionNotificationService.running.value = _rec('s1');
      expect(RunningSessionLock.lockedHand(hand), isTrue);
      LiveSessionNotificationService.running.value =
          _rec('s1', kind: 'full');
      expect(RunningSessionLock.lockedHand(hand), isTrue);
      LiveSessionNotificationService.running.value = null; // session ended
      expect(RunningSessionLock.lockedHand(hand), isFalse);
    });

    test('other sessions, hand groups and missing ids are never locked', () {
      LiveSessionNotificationService.running.value = _rec('s1');
      expect(RunningSessionLock.lockedHand({'sessionId': 'group-9'}), isFalse);
      expect(RunningSessionLock.lockedHand({}), isFalse);
      expect(RunningSessionLock.lockedHand({'sessionId': ''}), isFalse);
    });
  });

  group('ScreenCaptureGuard (MethodChannel)', () {
    final calls = <bool>[];
    setUp(() {
      calls.clear();
      ScreenCaptureGuard.resetForTest();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ScreenCaptureGuard.channel, (c) async {
        expect(c.method, 'setSecure');
        calls.add((c.arguments as Map)['secure'] as bool);
        return null;
      });
    });
    tearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ScreenCaptureGuard.channel, null));

    test('acquire sets the flag once, the last release clears it', () async {
      await ScreenCaptureGuard.acquire();
      await ScreenCaptureGuard.acquire();
      expect(calls, [true]);
      await ScreenCaptureGuard.release();
      expect(calls, [true]);
      await ScreenCaptureGuard.release();
      expect(calls, [true, false]);
      await ScreenCaptureGuard.release(); // extra release is harmless
      expect(calls, [true, false]);
    });

    test('CaptureHold owns exactly one count and always lets go', () async {
      final hold = CaptureHold();
      hold.update(false);
      expect(calls, isEmpty);
      hold.update(true);
      hold.update(true);
      await Future<void>.delayed(Duration.zero);
      expect(calls, [true]);
      hold.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(calls, [true, false]);
      expect(ScreenCaptureGuard.holders, 0);
    });

    test('a missing native side is not an error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ScreenCaptureGuard.channel, null);
      await ScreenCaptureGuard.acquire();
      await ScreenCaptureGuard.release();
    });
  });
}
