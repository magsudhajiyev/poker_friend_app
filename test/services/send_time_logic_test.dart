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
}
