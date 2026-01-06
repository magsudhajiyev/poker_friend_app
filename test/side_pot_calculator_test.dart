import 'package:flutter_test/flutter_test.dart';
import '../lib/models/poker_game_state.dart';

void main() {
  group('SidePotCalculator Tests', () {

    test('2-player all-in with different stacks', () {
      // P1: 1000, P2: 1200
      // Expected: Main pot = 2000, P2 keeps 200

      List<PlayerState> players = [
        PlayerState(playerId: 1, isActive: true, hasFolded: false, currentStack: 0, totalContribution: 1000),
        PlayerState(playerId: 2, isActive: true, hasFolded: false, currentStack: 0, totalContribution: 1200),
      ];

      final sidePots = SidePotCalculator.calculateSidePots(players);

      expect(sidePots.length, 2, reason: 'Should create 2 pots for different stack sizes');

      // Main pot: 1000 × 2 = 2000
      expect(sidePots[0].amount, 2000);
      expect(sidePots[0].eligiblePlayers, [1, 2]);
      expect(sidePots[0].maxContribution, 1000);

      // Side pot: (1200 - 1000) × 1 = 200
      expect(sidePots[1].amount, 200);
      expect(sidePots[1].eligiblePlayers, [2]);
      expect(sidePots[1].maxContribution, 1200);
    });

    test('3-player all-in with different stacks', () {
      // P1: 500, P2: 1000, P3: 1500
      // Expected: 3 pots

      List<PlayerState> players = [
        PlayerState(playerId: 1, isActive: true, hasFolded: false, currentStack: 0, totalContribution: 500),
        PlayerState(playerId: 2, isActive: true, hasFolded: false, currentStack: 0, totalContribution: 1000),
        PlayerState(playerId: 3, isActive: true, hasFolded: false, currentStack: 0, totalContribution: 1500),
      ];

      final sidePots = SidePotCalculator.calculateSidePots(players);

      expect(sidePots.length, 3, reason: 'Should create 3 pots for 3 different stack sizes');

      // Main pot: 500 × 3 = 1500
      expect(sidePots[0].amount, 1500);
      expect(sidePots[0].eligiblePlayers, [1, 2, 3]);

      // Side pot 1: (1000 - 500) × 2 = 1000
      expect(sidePots[1].amount, 1000);
      expect(sidePots[1].eligiblePlayers, [2, 3]);

      // Side pot 2: (1500 - 1000) × 1 = 500
      expect(sidePots[2].amount, 500);
      expect(sidePots[2].eligiblePlayers, [3]);
    });

    test('4-player all-in - USER SCENARIO (UTG: 1400, BTN: 1400, SB: 2500, BB: 3000)', () {
      // This is the exact scenario the user reported
      // UTG: 1400, BTN: 1400, SB: 2500, BB: 3000

      List<PlayerState> players = [
        PlayerState(playerId: 1, isActive: true, hasFolded: false, currentStack: 0, totalContribution: 1400), // UTG
        PlayerState(playerId: 2, isActive: true, hasFolded: false, currentStack: 0, totalContribution: 1400), // BTN
        PlayerState(playerId: 3, isActive: true, hasFolded: false, currentStack: 0, totalContribution: 2500), // SB
        PlayerState(playerId: 4, isActive: true, hasFolded: false, currentStack: 0, totalContribution: 3000), // BB
      ];

      final sidePots = SidePotCalculator.calculateSidePots(players);

      print('Side pots created: ${sidePots.length}');
      for (var pot in sidePots) {
        print('  ${pot.toString()}');
      }

      expect(sidePots.length, 3, reason: 'Should create 3 pots for 4 players with different contributions');

      // Main pot: 1400 × 4 = 5600 (all 4 players eligible)
      expect(sidePots[0].amount, 5600);
      expect(sidePots[0].eligiblePlayers, [1, 2, 3, 4]);
      expect(sidePots[0].maxContribution, 1400);

      // Side pot 1: (2500 - 1400) × 2 = 2200 (SB, BB eligible)
      expect(sidePots[1].amount, 2200);
      expect(sidePots[1].eligiblePlayers, [3, 4]);
      expect(sidePots[1].maxContribution, 2500);

      // Side pot 2: (3000 - 2500) × 1 = 500 (BB only eligible)
      expect(sidePots[2].amount, 500);
      expect(sidePots[2].eligiblePlayers, [4]);
      expect(sidePots[2].maxContribution, 3000);

      // Verify total pot
      final totalPot = sidePots.fold<double>(0, (sum, pot) => sum + pot.amount);
      expect(totalPot, 8300);
    });

    test('4-player all-in with betThisRound included', () {
      // Simulating a hand where players have both totalContribution and betThisRound
      // SB: 100 totalContribution (from blind) + 2400 betThisRound = 2500 total
      // BB: 400 totalContribution (from blind+ante) + 2600 betThisRound = 3000 total

      List<PlayerState> players = [
        PlayerState(playerId: 1, isActive: true, hasFolded: false, currentStack: 0, totalContribution: 0, betThisRound: 1400), // UTG
        PlayerState(playerId: 2, isActive: true, hasFolded: false, currentStack: 0, totalContribution: 0, betThisRound: 1400), // BTN
        PlayerState(playerId: 3, isActive: true, hasFolded: false, currentStack: 0, totalContribution: 100, betThisRound: 2400), // SB
        PlayerState(playerId: 4, isActive: true, hasFolded: false, currentStack: 0, totalContribution: 400, betThisRound: 2600), // BB
      ];

      final sidePots = SidePotCalculator.calculateSidePots(players);

      expect(sidePots.length, 3);
      expect(sidePots[0].amount, 5600); // 1400 × 4
      expect(sidePots[1].amount, 2200); // (2500 - 1400) × 2
      expect(sidePots[2].amount, 500);  // (3000 - 2500) × 1
    });

    test('All players have same stack size', () {
      // When all players have same contribution, only 1 pot should exist
      List<PlayerState> players = [
        PlayerState(playerId: 1, isActive: true, hasFolded: false, currentStack: 0, totalContribution: 1000),
        PlayerState(playerId: 2, isActive: true, hasFolded: false, currentStack: 0, totalContribution: 1000),
        PlayerState(playerId: 3, isActive: true, hasFolded: false, currentStack: 0, totalContribution: 1000),
      ];

      final sidePots = SidePotCalculator.calculateSidePots(players);

      expect(sidePots.length, 1, reason: 'Should create 1 pot when all contributions are equal');
      expect(sidePots[0].amount, 3000);
      expect(sidePots[0].eligiblePlayers, [1, 2, 3]);
    });

    test('One player covers all others', () {
      // P1: 100, P2: 100, P3: 100, P4: 5000
      List<PlayerState> players = [
        PlayerState(playerId: 1, isActive: true, hasFolded: false, currentStack: 0, totalContribution: 100),
        PlayerState(playerId: 2, isActive: true, hasFolded: false, currentStack: 0, totalContribution: 100),
        PlayerState(playerId: 3, isActive: true, hasFolded: false, currentStack: 0, totalContribution: 100),
        PlayerState(playerId: 4, isActive: true, hasFolded: false, currentStack: 0, totalContribution: 5000),
      ];

      final sidePots = SidePotCalculator.calculateSidePots(players);

      expect(sidePots.length, 2);

      // Main pot: 100 × 4 = 400
      expect(sidePots[0].amount, 400);
      expect(sidePots[0].eligiblePlayers, [1, 2, 3, 4]);

      // Side pot: (5000 - 100) × 1 = 4900
      expect(sidePots[1].amount, 4900);
      expect(sidePots[1].eligiblePlayers, [4]);
    });

    test('Folded players excluded from side pots', () {
      List<PlayerState> players = [
        PlayerState(playerId: 1, isActive: true, hasFolded: true, currentStack: 0, totalContribution: 500), // FOLDED
        PlayerState(playerId: 2, isActive: true, hasFolded: false, currentStack: 0, totalContribution: 1000),
        PlayerState(playerId: 3, isActive: true, hasFolded: false, currentStack: 0, totalContribution: 1500),
      ];

      final sidePots = SidePotCalculator.calculateSidePots(players);

      // Only P2 and P3 should be in pots, P1 folded
      expect(sidePots.length, 2);

      // Main pot: 1000 × 2 = 2000 (P2 and P3 only)
      expect(sidePots[0].amount, 2000);
      expect(sidePots[0].eligiblePlayers, [2, 3]);
      expect(sidePots[0].eligiblePlayers.contains(1), false, reason: 'Folded player should not be eligible');

      // Side pot: (1500 - 1000) × 1 = 500
      expect(sidePots[1].amount, 500);
      expect(sidePots[1].eligiblePlayers, [3]);
    });

    test('Inactive players excluded from side pots', () {
      List<PlayerState> players = [
        PlayerState(playerId: 1, isActive: false, hasFolded: false, currentStack: 0, totalContribution: 500), // INACTIVE
        PlayerState(playerId: 2, isActive: true, hasFolded: false, currentStack: 0, totalContribution: 1000),
        PlayerState(playerId: 3, isActive: true, hasFolded: false, currentStack: 0, totalContribution: 1500),
      ];

      final sidePots = SidePotCalculator.calculateSidePots(players);

      // Only P2 and P3 should be in pots
      expect(sidePots.length, 2);
      expect(sidePots[0].eligiblePlayers.contains(1), false, reason: 'Inactive player should not be eligible');
    });

    test('Single active player returns empty list', () {
      List<PlayerState> players = [
        PlayerState(playerId: 1, isActive: true, hasFolded: false, currentStack: 0, totalContribution: 1000),
        PlayerState(playerId: 2, isActive: true, hasFolded: true, currentStack: 0, totalContribution: 500),
      ];

      final sidePots = SidePotCalculator.calculateSidePots(players);

      expect(sidePots.length, 0, reason: 'Only 1 active player (P2 folded) - no pots needed');
    });

    test('Empty player list returns empty list', () {
      List<PlayerState> players = [];

      final sidePots = SidePotCalculator.calculateSidePots(players);

      expect(sidePots.length, 0);
    });

    test('Verify pot amounts sum to total contributions', () {
      List<PlayerState> players = [
        PlayerState(playerId: 1, isActive: true, hasFolded: false, currentStack: 0, totalContribution: 300),
        PlayerState(playerId: 2, isActive: true, hasFolded: false, currentStack: 0, totalContribution: 700),
        PlayerState(playerId: 3, isActive: true, hasFolded: false, currentStack: 0, totalContribution: 1200),
        PlayerState(playerId: 4, isActive: true, hasFolded: false, currentStack: 0, totalContribution: 2000),
      ];

      final sidePots = SidePotCalculator.calculateSidePots(players);

      final totalFromPots = sidePots.fold<double>(0, (sum, pot) => sum + pot.amount);
      final totalContributions = players
          .where((p) => !p.hasFolded && p.isActive)
          .fold<double>(0, (sum, p) => sum + p.totalContribution + p.betThisRound);

      expect(totalFromPots, totalContributions,
        reason: 'Sum of all pots should equal sum of all active player contributions');
    });
  });
}
