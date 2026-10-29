import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/daily_challenge_store.dart';
import 'package:poker_logger/services/leaderboard_service.dart';

DailyChallengeStreaks _local(int cur, int best,
        {int perfect = 0, int played = 0}) =>
    DailyChallengeStreaks(
        current: cur, best: best, perfectDays: perfect, totalPlayed: played);

StreakRow _srv(int cur, int best, String last,
        {int perfect = 0, int played = 0}) =>
    StreakRow(
        current: cur,
        best: best,
        perfectDays: perfect,
        totalPlayed: played,
        lastDayKey: last);

void main() {
  test('new device: server 40 yesterday, local 1 -> 41', () {
    final m = mergeStreakRow(
        server: _srv(40, 40, '2026-10-28'),
        local: _local(1, 1),
        dayKey: '2026-10-29');
    expect(m.current, 41);
    expect(m.best, 41);
    expect(m.lastDayKey, '2026-10-29');
  });

  test('same-day resubmit keeps server current', () {
    final m = mergeStreakRow(
        server: _srv(41, 41, '2026-10-29'),
        local: _local(1, 1),
        dayKey: '2026-10-29');
    expect(m.current, 41);
  });

  test('gap: local wins, best never decreases', () {
    final m = mergeStreakRow(
        server: _srv(40, 40, '2026-10-20'),
        local: _local(1, 1),
        dayKey: '2026-10-29');
    expect(m.current, 1);
    expect(m.best, 40);
  });

  test('no server row: local values', () {
    final m = mergeStreakRow(
        server: null,
        local: _local(3, 5, perfect: 2, played: 9),
        dayKey: '2026-10-29');
    expect((m.current, m.best, m.perfectDays, m.totalPlayed), (3, 5, 2, 9));
  });

  test('monotonic counters take the max; later lastDayKey wins', () {
    final m = mergeStreakRow(
        server: _srv(2, 2, '2026-10-30', perfect: 7, played: 20),
        local: _local(1, 1, perfect: 3, played: 4),
        dayKey: '2026-10-29');
    expect(m.perfectDays, 7);
    expect(m.totalPlayed, 20);
    expect(m.lastDayKey, '2026-10-30');
  });

  test('previousDayKey uses calendar math', () {
    expect(previousDayKey('2026-11-01'), '2026-10-31');
    expect(previousDayKey('2027-01-01'), '2026-12-31');
  });

  test('isStreakRowFresh allows two days of slack', () {
    expect(isStreakRowFresh('2026-10-27', '2026-10-29'), true);
    expect(isStreakRowFresh('2026-10-26', '2026-10-29'), false);
    expect(isStreakRowFresh('', '2026-10-29'), false);
  });
}
