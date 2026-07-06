import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/user_stats.dart';
import 'package:poker_logger/services/user_stats_service.dart';

/// B14 regression tests: position breakdown counters were documented in the
/// data model but never written. These pin the pure delta-path builder and
/// the model (de)serialization.
void main() {
  group('UserStatsService.positionUpdatePaths', () {
    test('typical dealt hand with VPIP produces dealt+vpip paths only', () {
      final paths = UserStatsService.positionUpdatePaths(
        position: 'BTN',
        handsDealtDelta: 1,
        vpipDelta: 1,
      );
      expect(paths, {
        'positionHandsPlayed.BTN': 1,
        'positionVpipCount.BTN': 1,
      });
    });

    test('full raise hand produces all four paths', () {
      final paths = UserStatsService.positionUpdatePaths(
        position: 'CO',
        handsDealtDelta: 1,
        vpipDelta: 1,
        pfrDelta: 1,
        threeBetDelta: 1,
      );
      expect(paths, {
        'positionHandsPlayed.CO': 1,
        'positionVpipCount.CO': 1,
        'positionPfrCount.CO': 1,
        'positionThreeBetCount.CO': 1,
      });
    });

    test('folded-preflop hand still counts as dealt at the position', () {
      final paths = UserStatsService.positionUpdatePaths(
        position: 'UTG',
        handsDealtDelta: 1,
      );
      expect(paths, {'positionHandsPlayed.UTG': 1});
    });

    test('all-zero deltas produce no writes', () {
      expect(
        UserStatsService.positionUpdatePaths(position: 'BB'),
        isEmpty,
      );
    });

    test('null, empty, and whitespace positions produce no writes', () {
      expect(
        UserStatsService.positionUpdatePaths(
            position: null, handsDealtDelta: 1),
        isEmpty,
      );
      expect(
        UserStatsService.positionUpdatePaths(position: '', handsDealtDelta: 1),
        isEmpty,
      );
      expect(
        UserStatsService.positionUpdatePaths(
            position: '   ', handsDealtDelta: 1),
        isEmpty,
      );
    });

    test('position containing a dot is rejected (would corrupt dot-paths)', () {
      expect(
        UserStatsService.positionUpdatePaths(
            position: 'BT.N', handsDealtDelta: 1),
        isEmpty,
      );
    });

    test('every standard position name maps to a clean path', () {
      for (final pos in ['UTG', 'UTG+1', 'EP', 'MP', 'HJ', 'CO', 'BTN', 'SB', 'BB']) {
        final paths = UserStatsService.positionUpdatePaths(
            position: pos, handsDealtDelta: 1);
        expect(paths.keys.single, 'positionHandsPlayed.$pos');
      }
    });
  });

  group('UserStats position map serialization', () {
    test('fromFirestore parses position maps, tolerating num values', () {
      final stats = UserStats.fromFirestore({
        'userId': 'u1',
        'positionHandsPlayed': {'BTN': 12, 'SB': 3.0},
        'positionVpipCount': {'BTN': 5},
      });
      expect(stats.positionHandsPlayed, {'BTN': 12, 'SB': 3});
      expect(stats.positionVpipCount, {'BTN': 5});
      expect(stats.positionPfrCount, isEmpty);
      expect(stats.positionThreeBetCount, isEmpty);
    });

    test('legacy documents without position maps default to empty', () {
      final stats = UserStats.fromFirestore({'userId': 'u1', 'totalHands': 40});
      expect(stats.positionHandsPlayed, isEmpty);
      expect(stats.positionVpipCount, isEmpty);
    });

    test('toFirestore round-trips the position maps', () {
      final stats = UserStats(
        userId: 'u1',
        positionHandsPlayed: {'CO': 7},
        positionPfrCount: {'CO': 2},
      );
      final data = stats.toFirestore();
      expect(data['positionHandsPlayed'], {'CO': 7});
      expect(data['positionPfrCount'], {'CO': 2});
      final back = UserStats.fromFirestore({...data, 'userId': 'u1'});
      expect(back.positionHandsPlayed, {'CO': 7});
      expect(back.positionPfrCount, {'CO': 2});
    });
  });
}
