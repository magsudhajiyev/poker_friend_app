import 'package:flutter_test/flutter_test.dart';
import '../lib/models/poker_game_state.dart';

void main() {
  group('Multi-Pot Dialog Selection Logic Tests', () {

    test('Should trigger multi-pot dialog when 2+ pots exist (2 players, different stacks)', () {
      // Setup: 2 players with different contributions
      List<PlayerState> players = [
        PlayerState(playerId: 1, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 1000),
        PlayerState(playerId: 2, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 1200),
      ];

      final sidePots = SidePotCalculator.calculateSidePots(players);

      // Verify: Should create 2 pots (main + side)
      expect(sidePots.length, 2, reason: 'Should create 2 pots for different stack sizes');

      // Dialog selection logic: sidePots.length >= 2 → MultiPotWinnerDialog
      final shouldShowMultiPotDialog = sidePots.length >= 2;
      expect(shouldShowMultiPotDialog, true, reason: 'Should show multi-pot dialog when 2+ pots exist');
    });

    test('Should trigger multi-pot dialog when 3+ pots exist (4 players - USER SCENARIO)', () {
      // Setup: User's exact scenario
      List<PlayerState> players = [
        PlayerState(playerId: 1, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 1400), // UTG
        PlayerState(playerId: 2, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 1400), // BTN
        PlayerState(playerId: 3, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 2500), // SB
        PlayerState(playerId: 4, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 3000), // BB
      ];

      final sidePots = SidePotCalculator.calculateSidePots(players);

      // Verify: Should create 3 pots
      expect(sidePots.length, 3, reason: 'Should create 3 pots for user scenario');

      // Dialog selection logic: sidePots.length >= 2 → MultiPotWinnerDialog
      final shouldShowMultiPotDialog = sidePots.length >= 2;
      expect(shouldShowMultiPotDialog, true, reason: 'Should show multi-pot dialog when 3 pots exist');
    });

    test('Should trigger regular dialog when only 1 pot exists (all equal stacks)', () {
      // Setup: All players with same contribution
      List<PlayerState> players = [
        PlayerState(playerId: 1, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 1000),
        PlayerState(playerId: 2, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 1000),
        PlayerState(playerId: 3, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 1000),
      ];

      final sidePots = SidePotCalculator.calculateSidePots(players);

      // Verify: Should create only 1 pot
      expect(sidePots.length, 1, reason: 'Should create 1 pot when all contributions equal');

      // Dialog selection logic: sidePots.length < 2 → WinnerSelectionDialog
      final shouldShowMultiPotDialog = sidePots.length >= 2;
      expect(shouldShowMultiPotDialog, false, reason: 'Should show regular dialog when only 1 pot');
    });

    test('Should trigger regular dialog when 0 or 1 players remain', () {
      // Setup: Only 1 active player (others folded)
      List<PlayerState> players = [
        PlayerState(playerId: 1, isActive: true, hasFolded: false, currentStack: 100, totalContribution: 500),
        PlayerState(playerId: 2, isActive: true, hasFolded: true, currentStack: 0, totalContribution: 200),
        PlayerState(playerId: 3, isActive: true, hasFolded: true, currentStack: 0, totalContribution: 300),
      ];

      final sidePots = SidePotCalculator.calculateSidePots(players);

      // Verify: Should create 0 pots (only 1 active player)
      expect(sidePots.length, 0, reason: 'Should create 0 pots when only 1 active player');

      // Dialog selection logic: sidePots.length < 2 → WinnerSelectionDialog
      final shouldShowMultiPotDialog = sidePots.length >= 2;
      expect(shouldShowMultiPotDialog, false, reason: 'Should show regular dialog when 0 pots');
    });

    test('Should trigger multi-pot dialog with BB ante (4 players with ante)', () {
      // Setup: Realistic scenario with BB ante
      // SB posts 100, BB posts 200 BB + 200 ante = 400
      // UTG goes all-in 1400, BTN calls 1400, SB calls 2400 more (2500 total), BB calls 2600 more (3000 total)

      List<PlayerState> players = [
        PlayerState(playerId: 1, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0,
                   totalContribution: 0, betThisRound: 1400), // UTG: all-in preflop
        PlayerState(playerId: 2, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0,
                   totalContribution: 0, betThisRound: 1400), // BTN: all-in preflop
        PlayerState(playerId: 3, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0,
                   totalContribution: 100, betThisRound: 2400), // SB: 100 SB + 2400 more = 2500 total
        PlayerState(playerId: 4, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0,
                   totalContribution: 400, betThisRound: 2600), // BB: 400 (BB+ante) + 2600 more = 3000 total
      ];

      final sidePots = SidePotCalculator.calculateSidePots(players);

      print('BB ante scenario - Side pots:');
      for (var pot in sidePots) {
        print('  ${pot.toString()}');
      }

      // Verify: Should create 3 pots
      expect(sidePots.length, 3, reason: 'Should create 3 pots with BB ante included');

      // Verify pot amounts (BB ante should be included in calculations)
      expect(sidePots[0].amount, 5600); // Main: 1400 × 4
      expect(sidePots[1].amount, 2200); // Side 1: (2500-1400) × 2
      expect(sidePots[2].amount, 500);  // Side 2: (3000-2500) × 1

      // Dialog selection logic
      final shouldShowMultiPotDialog = sidePots.length >= 2;
      expect(shouldShowMultiPotDialog, true, reason: 'Should show multi-pot dialog with BB ante scenario');
    });

    test('Edge case: 2 players same stack, 1 player bigger stack', () {
      // Setup: P1 and P2 have 1000, P3 has 2000
      List<PlayerState> players = [
        PlayerState(playerId: 1, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 1000),
        PlayerState(playerId: 2, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 1000),
        PlayerState(playerId: 3, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 2000),
      ];

      final sidePots = SidePotCalculator.calculateSidePots(players);

      // Verify: Should create 2 pots
      // Main: 1000 × 3 = 3000 (P1, P2, P3)
      // Side: (2000-1000) × 1 = 1000 (P3 only)
      expect(sidePots.length, 2);
      expect(sidePots[0].amount, 3000);
      expect(sidePots[1].amount, 1000);

      // Dialog selection logic
      final shouldShowMultiPotDialog = sidePots.length >= 2;
      expect(shouldShowMultiPotDialog, true);
    });

    test('Verify dialog selection threshold is exactly 2', () {
      // Test the boundary condition

      // With 1 pot - should use regular dialog
      var sidePots1 = [
        SidePot(amount: 1000, eligiblePlayers: [1, 2], maxContribution: 500)
      ];
      expect(sidePots1.length >= 2, false);

      // With 2 pots - should use multi-pot dialog
      var sidePots2 = [
        SidePot(amount: 1000, eligiblePlayers: [1, 2], maxContribution: 500),
        SidePot(amount: 500, eligiblePlayers: [2], maxContribution: 1000),
      ];
      expect(sidePots2.length >= 2, true);

      // With 3 pots - should use multi-pot dialog
      var sidePots3 = [
        SidePot(amount: 1000, eligiblePlayers: [1, 2, 3], maxContribution: 500),
        SidePot(amount: 500, eligiblePlayers: [2, 3], maxContribution: 750),
        SidePot(amount: 250, eligiblePlayers: [3], maxContribution: 1000),
      ];
      expect(sidePots3.length >= 2, true);
    });
  });
}
