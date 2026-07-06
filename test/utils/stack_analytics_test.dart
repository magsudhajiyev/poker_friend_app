import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/utils/stack_analytics.dart';

/// F2: stack-vs-table-average ratio and BB-per-hour aggregation.
void main() {
  group('latestTableAverage', () {
    test('returns the most recent entry carrying tableAvg', () {
      final history = [
        {'stackSize': 100.0, 'tableAvg': 120.0},
        {'stackSize': 150.0}, // hand-completion entry, no tableAvg
        {'stackSize': 180.0, 'tableAvg': 140.0},
        {'stackSize': 200.0},
      ];
      expect(StackAnalytics.latestTableAverage(history), 140.0);
    });

    test('null when no entry has tableAvg, empty list, or non-positive', () {
      expect(StackAnalytics.latestTableAverage([]), isNull);
      expect(
          StackAnalytics.latestTableAverage([
            {'stackSize': 100.0}
          ]),
          isNull);
      expect(
          StackAnalytics.latestTableAverage([
            {'stackSize': 100.0, 'tableAvg': 0.0}
          ]),
          isNull);
    });

    test('int-typed tableAvg (Firestore round-trip) is accepted', () {
      expect(
          StackAnalytics.latestTableAverage([
            {'stackSize': 100.0, 'tableAvg': 120}
          ]),
          120.0);
    });
  });

  group('stackToAvgRatio', () {
    test('divides stack by average', () {
      expect(StackAnalytics.stackToAvgRatio(140.0, 100.0), 1.4);
    });

    test('null on missing or non-positive average / missing stack', () {
      expect(StackAnalytics.stackToAvgRatio(140.0, null), isNull);
      expect(StackAnalytics.stackToAvgRatio(140.0, 0.0), isNull);
      expect(StackAnalytics.stackToAvgRatio(null, 100.0), isNull);
      expect(StackAnalytics.stackToAvgRatio(-5.0, 100.0), isNull);
    });

    test('busted hero (stack 0) is a valid 0.0 ratio, not null', () {
      expect(StackAnalytics.stackToAvgRatio(0.0, 100.0), 0.0);
    });
  });

  group('formatRatio', () {
    test('one decimal under 10, none at 10 and above', () {
      expect(StackAnalytics.formatRatio(1.44), '1.4×');
      expect(StackAnalytics.formatRatio(0.5), '0.5×');
      expect(StackAnalytics.formatRatio(9.96), '10.0×'); // rounds within format
      expect(StackAnalytics.formatRatio(12.3), '12×');
    });
  });

  group('sessionMinutes', () {
    test('durationMinutes wins when present', () {
      expect(StackAnalytics.sessionMinutes({'durationMinutes': 90}), 90);
    });

    test('falls back to endTime - startTime ISO strings', () {
      expect(
          StackAnalytics.sessionMinutes({
            'startTime': '2026-07-01T10:00:00.000',
            'endTime': '2026-07-01T12:30:00.000',
          }),
          150);
    });

    test('null without usable fields or with non-positive duration', () {
      expect(StackAnalytics.sessionMinutes({}), isNull);
      expect(
          StackAnalytics.sessionMinutes({'startTime': '2026-07-01T10:00:00.000'}),
          isNull);
      expect(
          StackAnalytics.sessionMinutes({
            'startTime': '2026-07-01T12:00:00.000',
            'endTime': '2026-07-01T10:00:00.000', // ends before it starts
          }),
          isNull);
    });
  });

  group('sessionProfit', () {
    test('explicit profit field wins', () {
      expect(StackAnalytics.sessionProfit({'profit': -40.0}), -40.0);
    });

    test('finalStack/currentStack minus totalBuyIn', () {
      expect(
          StackAnalytics.sessionProfit(
              {'finalStack': 300.0, 'totalBuyIn': 200.0}),
          100.0);
      expect(
          StackAnalytics.sessionProfit(
              {'currentStack': 150.0, 'totalBuyIn': 200.0}),
          -50.0);
    });

    test('last stack-history entry as final fallback', () {
      expect(
          StackAnalytics.sessionProfit({
            'totalBuyIn': 100.0,
            'stackHistory': [
              {'stackSize': 100.0},
              {'stackSize': 260.0},
            ],
          }),
          160.0);
    });

    test('null without buy-in or without any end stack', () {
      expect(StackAnalytics.sessionProfit({'finalStack': 300.0}), isNull);
      expect(StackAnalytics.sessionProfit({'totalBuyIn': 100.0}), isNull);
    });
  });

  group('cashBBPerHour', () {
    Map<String, dynamic> cash({
      double bb = 2.0,
      int minutes = 120,
      double profit = 0,
    }) =>
        {
          'gameType': 'cash',
          'bigBlind': bb,
          'durationMinutes': minutes,
          'profit': profit,
        };

    test('aggregates profit-in-BB over total hours', () {
      // 120 BB won over 2h + 60 BB lost over 1h → 60 BB over 3h = 20 BB/h.
      final r = StackAnalytics.cashBBPerHour([
        cash(bb: 2.0, minutes: 120, profit: 240.0),
        cash(bb: 2.0, minutes: 60, profit: -120.0),
      ]);
      expect(r.rate, closeTo(20.0, 1e-9));
      expect(r.minutes, 180);
    });

    test('tournaments, blindless and durationless sessions are excluded', () {
      final r = StackAnalytics.cashBBPerHour([
        cash(minutes: 120, profit: 100.0),
        {'gameType': 'tournament', 'bigBlind': 400.0, 'durationMinutes': 300, 'profit': 5000.0},
        {'gameType': 'cash', 'durationMinutes': 300, 'profit': 999.0}, // no BB
        {'gameType': 'cash', 'bigBlind': 2.0, 'profit': 999.0}, // no duration
      ]);
      expect(r.minutes, 120);
      expect(r.rate, closeTo(25.0, 1e-9)); // 50 BB over 2h
    });

    test('rate withheld (null) below 60 tracked minutes', () {
      final r = StackAnalytics.cashBBPerHour([cash(minutes: 45, profit: 90.0)]);
      expect(r.rate, isNull);
      expect(r.minutes, 45);
    });

    test('normalizes across stakes: same BB result from different blinds', () {
      // 100 BB/h at $1/$2 and 100 BB/h at $2/$5 average to 100 BB/h.
      final r = StackAnalytics.cashBBPerHour([
        cash(bb: 2.0, minutes: 60, profit: 200.0),
        cash(bb: 5.0, minutes: 60, profit: 500.0),
      ]);
      expect(r.rate, closeTo(100.0, 1e-9));
    });

    test('empty input yields no rate and zero minutes', () {
      final r = StackAnalytics.cashBBPerHour([]);
      expect(r.rate, isNull);
      expect(r.minutes, 0);
    });
  });
}
