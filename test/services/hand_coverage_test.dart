import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/hand_coverage.dart';

void main() {
  test('live session: est_dealt and coverage', () {
    final m = SessionCoverage.compute(
        handsLogged: 6,
        foldTicks: 9,
        flagsOpen: 2,
        sessionMinutes: 60,
        isLive: true);
    expect(m['hands_logged'], 6);
    expect(m['flags_open'], 2);
    expect(m['est_dealt'], 30);
    expect(m['coverage'], 0.5);
  });

  test('coverage is capped at 1.0', () {
    final m = SessionCoverage.compute(
        handsLogged: 50,
        foldTicks: 50,
        flagsOpen: 0,
        sessionMinutes: 60,
        isLive: true);
    expect(m['coverage'], 1.0);
  });

  test('non-live or zero minutes: no estimate keys', () {
    final a = SessionCoverage.compute(
        handsLogged: 3,
        foldTicks: 1,
        flagsOpen: 0,
        sessionMinutes: 60,
        isLive: false);
    expect(a.keys, unorderedEquals(['hands_logged', 'flags_open']));
    final b = SessionCoverage.compute(
        handsLogged: 3,
        foldTicks: 1,
        flagsOpen: 0,
        sessionMinutes: 0,
        isLive: true);
    expect(b.containsKey('coverage'), isFalse);
  });
}
