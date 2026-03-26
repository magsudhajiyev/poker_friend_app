import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/user_stats.dart';

void main() {
  group('UserStats Percentage Calculations', () {
    group('VPIP Percentage', () {
      test('calculates correctly with standard values', () {
        final stats = UserStats(
          userId: 'test',
          vpipCount: 10,
          totalHands: 50,
          walksCount: 0,
        );

        expect(stats.vpipPercentage, closeTo(20.0, 0.01));
      });

      test('excludes walks from denominator', () {
        final stats = UserStats(
          userId: 'test',
          vpipCount: 10,
          totalHands: 50,
          walksCount: 10, // 40 eligible hands
        );

        // 10 / 40 = 25%
        expect(stats.vpipPercentage, closeTo(25.0, 0.01));
      });

      test('returns 0 when no eligible hands', () {
        final stats = UserStats(
          userId: 'test',
          vpipCount: 0,
          totalHands: 10,
          walksCount: 10, // All walks = 0 eligible
        );

        expect(stats.vpipPercentage, equals(0.0));
      });

      test('clamps at 100% even if count exceeds hands', () {
        final stats = UserStats(
          userId: 'test',
          vpipCount: 50,
          totalHands: 40,
          walksCount: 0,
        );

        expect(stats.vpipPercentage, equals(100.0));
      });

      test('eligibleHands calculation is correct', () {
        final stats = UserStats(
          userId: 'test',
          totalHands: 100,
          walksCount: 25,
        );

        expect(stats.eligibleHands, equals(75));
      });
    });

    group('PFR Percentage', () {
      test('calculates correctly with standard values', () {
        final stats = UserStats(
          userId: 'test',
          pfrCount: 5,
          totalHands: 50,
          walksCount: 0,
        );

        expect(stats.pfrPercentage, closeTo(10.0, 0.01));
      });

      test('excludes walks from denominator', () {
        final stats = UserStats(
          userId: 'test',
          pfrCount: 5,
          totalHands: 50,
          walksCount: 25, // 25 eligible hands
        );

        // 5 / 25 = 20%
        expect(stats.pfrPercentage, closeTo(20.0, 0.01));
      });

      test('returns 0 when no eligible hands', () {
        final stats = UserStats(
          userId: 'test',
          pfrCount: 5,
          totalHands: 10,
          walksCount: 10,
        );

        expect(stats.pfrPercentage, equals(0.0));
      });
    });

    group('3-Bet Percentage', () {
      test('uses threeBetOpportunity as denominator', () {
        final stats = UserStats(
          userId: 'test',
          threeBetCount: 5,
          threeBetOpportunity: 20,
        );

        expect(stats.threeBetPercentage, closeTo(25.0, 0.01));
      });

      test('returns 0 when no opportunities', () {
        final stats = UserStats(
          userId: 'test',
          threeBetCount: 0,
          threeBetOpportunity: 0,
        );

        expect(stats.threeBetPercentage, equals(0.0));
      });

      test('calculates 100% when always 3-betting', () {
        final stats = UserStats(
          userId: 'test',
          threeBetCount: 10,
          threeBetOpportunity: 10,
        );

        expect(stats.threeBetPercentage, closeTo(100.0, 0.01));
      });
    });

    group('Fold to 3-Bet Percentage', () {
      test('uses facing3BetCount as denominator', () {
        final stats = UserStats(
          userId: 'test',
          fold3betCount: 3,
          facing3BetCount: 10,
        );

        expect(stats.fold3betPercentage, closeTo(30.0, 0.01));
      });

      test('returns 0 when never faced 3-bet', () {
        final stats = UserStats(
          userId: 'test',
          fold3betCount: 0,
          facing3BetCount: 0,
        );

        expect(stats.fold3betPercentage, equals(0.0));
      });

      test('returns 0 when never folds to 3-bet', () {
        final stats = UserStats(
          userId: 'test',
          fold3betCount: 0,
          facing3BetCount: 10,
        );

        expect(stats.fold3betPercentage, equals(0.0));
      });
    });

    group('C-Bet Percentage', () {
      test('uses cbetOpportunity as denominator', () {
        final stats = UserStats(
          userId: 'test',
          cbetCount: 15,
          cbetOpportunity: 20,
        );

        expect(stats.cbetPercentage, closeTo(75.0, 0.01));
      });

      test('returns 0 when no c-bet opportunities', () {
        final stats = UserStats(
          userId: 'test',
          cbetCount: 0,
          cbetOpportunity: 0,
        );

        expect(stats.cbetPercentage, equals(0.0));
      });
    });

    group('Steal Percentage', () {
      test('uses stealOpportunity as denominator', () {
        final stats = UserStats(
          userId: 'test',
          stealCount: 8,
          stealOpportunity: 20,
        );

        expect(stats.stealPercentage, closeTo(40.0, 0.01));
      });

      test('returns 0 when no steal opportunities', () {
        final stats = UserStats(
          userId: 'test',
          stealCount: 0,
          stealOpportunity: 0,
        );

        expect(stats.stealPercentage, equals(0.0));
      });
    });

    group('Check/Raise Percentage', () {
      test('uses checkRaiseFlopOpportunity as denominator', () {
        final stats = UserStats(
          userId: 'test',
          checkRaiseFlopCount: 4,
          checkRaiseFlopOpportunity: 20,
        );

        expect(stats.checkRaiseFlopPercentage, closeTo(20.0, 0.01));
      });

      test('returns 0 when no check-raise opportunities', () {
        final stats = UserStats(
          userId: 'test',
          checkRaiseFlopCount: 0,
          checkRaiseFlopOpportunity: 0,
        );

        expect(stats.checkRaiseFlopPercentage, equals(0.0));
      });
    });

    group('hasDataFor helper', () {
      test('vpip returns true when eligibleHands > 0', () {
        final stats = UserStats(userId: 'test', totalHands: 10, walksCount: 0);
        expect(stats.hasDataFor('vpip'), isTrue);
      });

      test('vpip returns false when all hands are walks', () {
        final stats = UserStats(userId: 'test', totalHands: 10, walksCount: 10);
        expect(stats.hasDataFor('vpip'), isFalse);
      });

      test('pfr returns true when eligibleHands > 0', () {
        final stats = UserStats(userId: 'test', totalHands: 10, walksCount: 0);
        expect(stats.hasDataFor('pfr'), isTrue);
      });

      test('threeBet returns true when opportunity > 0', () {
        final stats = UserStats(userId: 'test', threeBetOpportunity: 5);
        expect(stats.hasDataFor('threeBet'), isTrue);
      });

      test('threeBet returns false when opportunity = 0', () {
        final stats = UserStats(userId: 'test', threeBetOpportunity: 0);
        expect(stats.hasDataFor('threeBet'), isFalse);
      });

      test('fold3bet returns based on facing3BetCount', () {
        expect(
          UserStats(userId: 'test', facing3BetCount: 1).hasDataFor('fold3bet'),
          isTrue,
        );
        expect(
          UserStats(userId: 'test', facing3BetCount: 0).hasDataFor('fold3bet'),
          isFalse,
        );
      });

      test('cbet returns based on cbetOpportunity', () {
        expect(
          UserStats(userId: 'test', cbetOpportunity: 1).hasDataFor('cbet'),
          isTrue,
        );
        expect(
          UserStats(userId: 'test', cbetOpportunity: 0).hasDataFor('cbet'),
          isFalse,
        );
      });

      test('steal returns based on stealOpportunity', () {
        expect(
          UserStats(userId: 'test', stealOpportunity: 1).hasDataFor('steal'),
          isTrue,
        );
        expect(
          UserStats(userId: 'test', stealOpportunity: 0).hasDataFor('steal'),
          isFalse,
        );
      });

      test('checkRaise returns based on checkRaiseFlopOpportunity', () {
        expect(
          UserStats(userId: 'test', checkRaiseFlopOpportunity: 1).hasDataFor('checkRaise'),
          isTrue,
        );
        expect(
          UserStats(userId: 'test', checkRaiseFlopOpportunity: 0).hasDataFor('checkRaise'),
          isFalse,
        );
      });
    });

    group('toLegacyStatsMap', () {
      test('includes all required fields', () {
        final stats = UserStats(
          userId: 'test',
          totalHands: 100,
          walksCount: 0,
          vpipCount: 30,
          pfrCount: 20,
          threeBetCount: 5,
          threeBetOpportunity: 25,
          fold3betCount: 2,
          facing3BetCount: 10,
          cbetCount: 15,
          cbetOpportunity: 20,
          stealCount: 8,
          stealOpportunity: 16,
          checkRaiseFlopCount: 3,
          checkRaiseFlopOpportunity: 15,
        );

        final map = stats.toLegacyStatsMap();

        expect(map['totalHands'], equals(100));
        expect(map['vpip'], closeTo(30.0, 0.1));
        expect(map['pfr'], closeTo(20.0, 0.1));
        expect(map['threeBet'], closeTo(20.0, 0.1)); // 5/25 = 20%
        expect(map['fold3Bet'], closeTo(20.0, 0.1)); // 2/10 = 20%
        expect(map['cbet'], closeTo(75.0, 0.1)); // 15/20 = 75%
        expect(map['steal'], closeTo(50.0, 0.1)); // 8/16 = 50%
        expect(map['checkRaise'], closeTo(20.0, 0.1)); // 3/15 = 20%
        expect(map['threeBetOpportunity'], equals(25));
        expect(map['facing3BetCount'], equals(10));
        expect(map['cbetOpportunity'], equals(20));
        expect(map['stealOpportunity'], equals(16));
        expect(map['checkRaiseFlopOpportunity'], equals(15));
        expect(map['eligibleHands'], equals(100));
      });
    });

    group('Edge Cases', () {
      test('all percentages clamped between 0 and 100', () {
        // Test with potentially invalid data (count > opportunity)
        final stats = UserStats(
          userId: 'test',
          totalHands: 10,
          vpipCount: 20, // More than totalHands
          pfrCount: 15,
          threeBetCount: 10,
          threeBetOpportunity: 5, // Count > opportunity
          fold3betCount: 8,
          facing3BetCount: 3,
          cbetCount: 25,
          cbetOpportunity: 10,
          stealCount: 30,
          stealOpportunity: 15,
          checkRaiseFlopCount: 12,
          checkRaiseFlopOpportunity: 6,
        );

        expect(stats.vpipPercentage, lessThanOrEqualTo(100.0));
        expect(stats.vpipPercentage, greaterThanOrEqualTo(0.0));
        expect(stats.pfrPercentage, lessThanOrEqualTo(100.0));
        expect(stats.pfrPercentage, greaterThanOrEqualTo(0.0));
        expect(stats.threeBetPercentage, lessThanOrEqualTo(100.0));
        expect(stats.threeBetPercentage, greaterThanOrEqualTo(0.0));
        expect(stats.fold3betPercentage, lessThanOrEqualTo(100.0));
        expect(stats.fold3betPercentage, greaterThanOrEqualTo(0.0));
        expect(stats.cbetPercentage, lessThanOrEqualTo(100.0));
        expect(stats.cbetPercentage, greaterThanOrEqualTo(0.0));
        expect(stats.stealPercentage, lessThanOrEqualTo(100.0));
        expect(stats.stealPercentage, greaterThanOrEqualTo(0.0));
        expect(stats.checkRaiseFlopPercentage, lessThanOrEqualTo(100.0));
        expect(stats.checkRaiseFlopPercentage, greaterThanOrEqualTo(0.0));
      });

      test('zero hands results in 0% for all stats', () {
        final stats = UserStats(userId: 'test');

        expect(stats.vpipPercentage, equals(0.0));
        expect(stats.pfrPercentage, equals(0.0));
        expect(stats.threeBetPercentage, equals(0.0));
        expect(stats.fold3betPercentage, equals(0.0));
        expect(stats.cbetPercentage, equals(0.0));
        expect(stats.stealPercentage, equals(0.0));
        expect(stats.checkRaiseFlopPercentage, equals(0.0));
      });
    });
  });
}
