import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/notification_copy.dart';
import 'package:poker_logger/services/streak_saver_service.dart';

/// Streak-saver pure logic: the next-day reminder time and the
/// `engagement:{type}:{eventId}` payload round-trip.
void main() {
  group('nextReminderTime', () {
    test('always tomorrow at the reminder hour, regardless of now', () {
      final morning = DateTime(2026, 10, 16, 9, 12);
      final night = DateTime(2026, 10, 16, 23, 59);
      for (final now in [morning, night]) {
        final t = StreakSaverService.nextReminderTime(now);
        expect(t.day, 17);
        expect(t.hour, StreakSaverService.defaultReminderHour);
        expect(t.minute, 0);
      }
    });

    test('rolls over month/year boundaries', () {
      final t = StreakSaverService.nextReminderTime(DateTime(2026, 12, 31, 20));
      expect(t.year, 2027);
      expect(t.month, 1);
      expect(t.day, 1);
    });

    test('custom hour is honored', () {
      final t = StreakSaverService.nextReminderTime(DateTime(2026, 10, 16),
          hour: 7);
      expect(t.hour, 7);
    });
  });

  group('reminderTimeForRun', () {
    test('normal run: day D+1 at the reminder hour', () {
      final t = StreakSaverService.reminderTimeForRun(
          DateTime(2026, 10, 16), DateTime(2026, 10, 16, 21));
      expect(t, DateTime(2026, 10, 17, 19));
    });

    test('midnight-crossing run still targets D+1, not D+2', () {
      // Started on the 16th, finished 00:10 on the 17th.
      final t = StreakSaverService.reminderTimeForRun(
          DateTime(2026, 10, 16), DateTime(2026, 10, 17, 0, 10));
      expect(t, DateTime(2026, 10, 17, 19));
    });

    test('past D+1 reminder falls back to nextReminderTime(now)', () {
      final now = DateTime(2026, 10, 17, 20);
      final t = StreakSaverService.reminderTimeForRun(DateTime(2026, 10, 16), now);
      expect(t, StreakSaverService.nextReminderTime(now));
      expect(t, DateTime(2026, 10, 18, 19));
    });

    test('calendar arithmetic across month/year end', () {
      final t = StreakSaverService.reminderTimeForRun(
          DateTime(2026, 12, 31), DateTime(2027, 1, 1, 0, 5));
      expect(t, DateTime(2027, 1, 1, 19));
    });
  });

  group('payload parsing', () {
    test('round-trips type + eventId', () {
      const payload = 'engagement:dc_streak_risk:abc123';
      final parsed = StreakSaverService.parsePayload(payload);
      expect(parsed, isNotNull);
      expect(parsed!.type, EngagementNotifType.dcStreakRisk);
      expect(parsed.eventId, 'abc123');
    });

    test('rejects foreign payloads and malformed shapes', () {
      for (final bad in [
        null,
        '',
        'promo_expiry_warning',
        'event_xyz',
        'engagement:', // no type/id
        'engagement:dc_streak_risk', // missing id
        'engagement:dc_streak_risk:', // empty id
        'engagement:not_a_type:abc', // unknown type
        'engagement:dc_streak_risk:a:b', // too many parts
      ]) {
        expect(StreakSaverService.parsePayload(bad), isNull,
            reason: 'should reject "$bad"');
      }
    });

    test('every engagement type parses through the payload format', () {
      for (final t in EngagementNotifType.values) {
        final parsed =
            StreakSaverService.parsePayload('engagement:${t.id}:ev1');
        expect(parsed?.type, t);
      }
    });
  });

  test('default reminder hour sits outside the default quiet window start',
      () {
    // 19:00 default fires before 22:00 quiet hours — the streak-saver is
    // quiet-hours-exempt by policy anyway, but the default should not rely
    // on the exemption.
    expect(StreakSaverService.defaultReminderHour, lessThan(22));
    expect(StreakSaverService.defaultReminderHour, greaterThanOrEqualTo(8));
  });
}
