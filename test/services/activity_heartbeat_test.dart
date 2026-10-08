import 'package:flutter_test/flutter_test.dart';

import '../../lib/services/activity_heartbeat_service.dart';

// Wire contract with the admin dashboard: users/{uid}.lastActiveAt is
// written on foreground AT MOST once per hour. The throttle decision is
// the pure part — pin it.
void main() {
  group('ActivityHeartbeatService.shouldWrite', () {
    final t0 = DateTime(2026, 9, 5, 12, 0);

    test('always writes when never written', () {
      expect(ActivityHeartbeatService.shouldWrite(null, t0), true);
    });

    test('suppressed inside the hour', () {
      expect(
          ActivityHeartbeatService.shouldWrite(
              t0, t0.add(const Duration(minutes: 59))),
          false);
    });

    test('writes at exactly one hour and beyond', () {
      expect(
          ActivityHeartbeatService.shouldWrite(
              t0, t0.add(const Duration(hours: 1))),
          true);
      expect(
          ActivityHeartbeatService.shouldWrite(
              t0, t0.add(const Duration(days: 3))),
          true);
    });
  });
}
