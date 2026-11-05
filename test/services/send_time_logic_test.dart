import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/send_time_logic.dart';

/// Pure send-time math: UTC→local hour conversion (any offset) and the
/// send-window match with an optional lead.
void main() {
  group('localHour', () {
    test('zero offset is identity', () {
      for (var h = 0; h < 24; h++) {
        expect(SendTimeLogic.localHour(h, 0), h);
      }
    });

    test('positive offset (east of UTC) wraps forward', () {
      // CET winter +60 min: 23:00 UTC → 00:00 local next day.
      expect(SendTimeLogic.localHour(23, 60), 0);
      expect(SendTimeLogic.localHour(18, 60), 19);
    });

    test('negative offset (west of UTC) wraps backward', () {
      // US Pacific −480 min (−8h): 02:00 UTC → 18:00 local prev day.
      expect(SendTimeLogic.localHour(2, -480), 18);
      expect(SendTimeLogic.localHour(0, -480), 16);
    });

    test('half-hour offsets round down into the hour', () {
      // India +330 min (+5:30): 13:00 UTC → 18:30 local → hour 18.
      expect(SendTimeLogic.localHour(13, 330), 18);
    });

    test('result is always 0–23 for extreme offsets', () {
      for (final off in [-720, -60, 0, 330, 840]) {
        for (var h = 0; h < 24; h++) {
          final r = SendTimeLogic.localHour(h, off);
          expect(r, inInclusiveRange(0, 23), reason: 'off=$off h=$h');
        }
      }
    });
  });

  group('isInSendWindow', () {
    test('fires when current local hour equals the active hour', () {
      // User active locally at 19:00, offset +60. activeHourUtc = 18
      // (because 18 UTC → 19 local). At utcNow 18 → local 19 → match.
      expect(
          SendTimeLogic.isInSendWindow(
              utcHourNow: 18, activeHourUtc: 18, tzOffsetMinutes: 60),
          isTrue);
    });

    test('does not fire an hour off', () {
      expect(
          SendTimeLogic.isInSendWindow(
              utcHourNow: 17, activeHourUtc: 18, tzOffsetMinutes: 60),
          isFalse);
    });

    test('lead shifts the window earlier and wraps midnight', () {
      // Active local 00:00 (offset 0, activeHourUtc 0), lead 1 → target 23:00.
      expect(
          SendTimeLogic.isInSendWindow(
              utcHourNow: 23,
              activeHourUtc: 0,
              tzOffsetMinutes: 0,
              leadHours: 1),
          isTrue);
      expect(
          SendTimeLogic.isInSendWindow(
              utcHourNow: 0,
              activeHourUtc: 0,
              tzOffsetMinutes: 0,
              leadHours: 1),
          isFalse);
    });

    test('works across a negative offset', () {
      // Pacific user (−480) active locally at 20:00 → activeHourUtc = 4
      // (04 UTC → 20 local). At utcNow 4 → local 20 → match.
      expect(
          SendTimeLogic.isInSendWindow(
              utcHourNow: 4, activeHourUtc: 4, tzOffsetMinutes: -480),
          isTrue);
    });
  });

  group('personalHour', () {
    test('converts the UTC active hour to local, minus the lead', () {
      // CET +60: active 18 UTC = 19 local; 1h lead = 18.
      expect(
          SendTimeLogic.personalHour(
              activeHourUtc: 18, tzOffsetMinutes: 60, leadHours: 1),
          18);
      expect(
          SendTimeLogic.personalHour(activeHourUtc: 18, tzOffsetMinutes: 60),
          19);
    });

    test('wraps across midnight in both directions', () {
      expect(
          SendTimeLogic.personalHour(
              activeHourUtc: 0, tzOffsetMinutes: 0, leadHours: 1),
          23);
      expect(
          SendTimeLogic.personalHour(activeHourUtc: 23, tzOffsetMinutes: 120),
          1);
      expect(
          SendTimeLogic.personalHour(activeHourUtc: 2, tzOffsetMinutes: -300),
          21);
    });

    test('missing or invalid hour falls back to 19:00, with or without a lead',
        () {
      for (final bad in [null, -1, 24, 99]) {
        expect(
            SendTimeLogic.personalHour(
                activeHourUtc: bad, tzOffsetMinutes: 600, leadHours: 1),
            19);
        expect(
            SendTimeLogic.personalHour(
                activeHourUtc: bad, tzOffsetMinutes: 600),
            19);
      }
    });

    test('matches the server window rule (isInSendWindow, lead 1)', () {
      for (var active = 0; active < 24; active++) {
        for (final tz in [-480, 0, 60, 330]) {
          final h = SendTimeLogic.personalHour(
              activeHourUtc: active, tzOffsetMinutes: tz, leadHours: 1);
          // The server fires when local-now == that hour; find the UTC hour.
          final utcNow = ((h * 60 - tz) ~/ 60 % 24 + 24) % 24;
          if (tz % 60 == 0) {
            expect(
                SendTimeLogic.isInSendWindow(
                    utcHourNow: utcNow,
                    activeHourUtc: active,
                    tzOffsetMinutes: tz,
                    leadHours: 1),
                isTrue,
                reason: 'active=$active tz=$tz');
          }
        }
      }
    });
  });

  group('clampStreakReminderHour', () {
    test('00:00-07:59 moves to 21:00; everything else is unchanged', () {
      for (var h = 0; h < 8; h++) {
        expect(SendTimeLogic.clampStreakReminderHour(h), 21, reason: '$h');
      }
      for (var h = 8; h < 24; h++) {
        expect(SendTimeLogic.clampStreakReminderHour(h), h, reason: '$h');
      }
    });

    test('lead-1 of a 02:00 active hour (01:00) is clamped, 23 stays', () {
      final early = SendTimeLogic.personalHour(
          activeHourUtc: 2, tzOffsetMinutes: 0, leadHours: 1);
      expect(SendTimeLogic.clampStreakReminderHour(early), 21);
      final late = SendTimeLogic.personalHour(
          activeHourUtc: 0, tzOffsetMinutes: 0, leadHours: 1);
      expect(late, 23);
      expect(SendTimeLogic.clampStreakReminderHour(late), 23);
    });

    test('the 19:00 fallback is untouched', () {
      expect(SendTimeLogic.clampStreakReminderHour(19), 19);
    });
  });
}
