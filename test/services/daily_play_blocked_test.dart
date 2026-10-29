import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/screens/training/daily_challenge_screen.dart';
import 'package:poker_logger/services/authored_tree_service.dart';

void main() {
  const offline = DayPlan(null, DaySource.fallbackAfterError);
  const online = DayPlan(null, DaySource.firestore);

  bool blocked(DayPlan? p, {bool local = false, bool remote = false}) =>
      dailyPlayBlocked(plan: p, hasLocalResult: local, hasRemote: remote);

  test('blocks when the schedule is unconfirmed and nothing was played', () {
    expect(blocked(offline), isTrue);
  });
  test('does not block ranked sources or a missing plan', () {
    expect(blocked(online), isFalse);
    expect(blocked(const DayPlan(null, DaySource.rng)), isFalse);
    expect(blocked(const DayPlan(null, DaySource.bundledConfirmedMissing)),
        isFalse);
    expect(blocked(null), isFalse);
  });
  test('a finished day still shows results offline', () {
    expect(blocked(offline, local: true), isFalse);
    expect(blocked(offline, remote: true), isFalse);
  });
}
