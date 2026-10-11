import 'package:flutter_test/flutter_test.dart';
import '../lib/models/poker_game_state.dart';

void main() {
  group('SidePotCalculator Tests', () {

    test('2-player all-in with different stacks', () {
      // P1: 1000, P2: 1200
      // Expected: Main pot = 2000, overage pot of 200 awaiting refund

      List<PlayerState> players = [
        PlayerState(playerId: 1, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 1000),
        PlayerState(playerId: 2, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 1200),
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
        PlayerState(playerId: 1, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 500),
        PlayerState(playerId: 2, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 1000),
        PlayerState(playerId: 3, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 1500),
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
      // UTG: 1400, BTN: 1400, SB: 2500, BB: 3000

      List<PlayerState> players = [
        PlayerState(playerId: 1, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 1400), // UTG
        PlayerState(playerId: 2, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 1400), // BTN
        PlayerState(playerId: 3, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 2500), // SB
        PlayerState(playerId: 4, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 3000), // BB
      ];

      final sidePots = SidePotCalculator.calculateSidePots(players);

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
        PlayerState(playerId: 1, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 0, betThisRound: 1400), // UTG
        PlayerState(playerId: 2, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 0, betThisRound: 1400), // BTN
        PlayerState(playerId: 3, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 100, betThisRound: 2400), // SB
        PlayerState(playerId: 4, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 400, betThisRound: 2600), // BB
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
        PlayerState(playerId: 1, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 1000),
        PlayerState(playerId: 2, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 1000),
        PlayerState(playerId: 3, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 1000),
      ];

      final sidePots = SidePotCalculator.calculateSidePots(players);

      expect(sidePots.length, 1, reason: 'Should create 1 pot when all contributions are equal');
      expect(sidePots[0].amount, 3000);
      expect(sidePots[0].eligiblePlayers, [1, 2, 3]);
    });

    test('One player covers all others', () {
      // P1: 100, P2: 100, P3: 100, P4: 5000
      List<PlayerState> players = [
        PlayerState(playerId: 1, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 100),
        PlayerState(playerId: 2, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 100),
        PlayerState(playerId: 3, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 100),
        PlayerState(playerId: 4, isActive: true, hasFolded: false, currentStack: 4900, totalContribution: 5000),
      ];

      final sidePots = SidePotCalculator.calculateSidePots(players);

      expect(sidePots.length, 2);

      // Main pot: 100 × 4 = 400
      expect(sidePots[0].amount, 400);
      expect(sidePots[0].eligiblePlayers, [1, 2, 3, 4]);

      // Overage pot awaiting refund: (5000 - 100) × 1 = 4900
      expect(sidePots[1].amount, 4900);
      expect(sidePots[1].eligiblePlayers, [4]);
    });

    test('In-progress blinds do NOT create phantom pot levels (open all-in)', () {
      // Blinds 1/2 posted, default-stack player open-shoves 200.
      // SB and BB have NOT acted yet — their partial blinds must not
      // create pot layers. There are no side pots at this moment.
      List<PlayerState> players = [
        PlayerState(playerId: 1, isActive: true, hasFolded: false, currentStack: 99, betThisRound: 1), // SB, pending
        PlayerState(playerId: 2, isActive: true, hasFolded: false, currentStack: 98, betThisRound: 2), // BB, pending
        PlayerState(playerId: 3, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, betThisRound: 200), // open shove
        PlayerState(playerId: 4, isActive: true, hasFolded: false, currentStack: 500), // not contributed
      ];

      final sidePots = SidePotCalculator.calculateSidePots(players);

      // One single pot of 203 — NOT Main 3 / Side 2 / ...
      expect(sidePots.length, 1);
      expect(sidePots[0].amount, 203);

      // Now the 20K stack raises to 550 on top
      players.add(PlayerState(playerId: 5, isActive: true, hasFolded: false, currentStack: 19450, betThisRound: 550));
      final sidePots2 = SidePotCalculator.calculateSidePots(players);

      // Layer locked at the 200 all-in + active money above it.
      // HL-7: pending live players (SB/BB yet to act) are eligible — they
      // will either match the level or fold out on the next recalc.
      expect(sidePots2.length, 2);
      expect(sidePots2[0].amount, 403); // 1 + 2 + 200 + 200
      expect(sidePots2[0].eligiblePlayers, [1, 2, 3, 5]);
      expect(sidePots2[1].amount, 350); // raiser's active money above 200
      expect(sidePots2[1].eligiblePlayers, [1, 2, 5]);

      final total = sidePots2.fold<double>(0, (sum, pot) => sum + pot.amount);
      expect(total, 753);
    });

    test('Folded players: chips stay in pots as dead money, but not eligible', () {
      List<PlayerState> players = [
        PlayerState(playerId: 1, isActive: true, hasFolded: true, currentStack: 0, totalContribution: 500), // FOLDED
        PlayerState(playerId: 2, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 1000),
        PlayerState(playerId: 3, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 1500),
      ];

      final sidePots = SidePotCalculator.calculateSidePots(players);

      expect(sidePots.length, 2);

      // Main pot: 1000 (P2) + 1000 (P3) + 500 dead money from P1 = 2500
      expect(sidePots[0].amount, 2500);
      expect(sidePots[0].eligiblePlayers, [2, 3]);
      expect(sidePots[0].eligiblePlayers.contains(1), false, reason: 'Folded player should not be eligible');

      // Side pot: (1500 - 1000) × 1 = 500
      expect(sidePots[1].amount, 500);
      expect(sidePots[1].eligiblePlayers, [3]);

      // Chip conservation: pots must sum to ALL contributions incl. folded
      final totalFromPots = sidePots.fold<double>(0, (sum, pot) => sum + pot.amount);
      expect(totalFromPots, 3000);
    });

    test('Dead money is distributed into pots by contribution level', () {
      // A all-in 100, B and C continue to 500, D folded after committing 300.
      // Real rule: 100 of D's chips belong to the main pot (A's level),
      // the remaining 200 to the side pot — NOT all of it to the main pot.
      List<PlayerState> players = [
        PlayerState(playerId: 1, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 100), // A all-in
        PlayerState(playerId: 2, isActive: true, hasFolded: false, currentStack: 100, totalContribution: 500), // B
        PlayerState(playerId: 3, isActive: true, hasFolded: false, currentStack: 100, totalContribution: 500), // C
        PlayerState(playerId: 4, isActive: true, hasFolded: true, currentStack: 0, totalContribution: 300), // D folded
      ];

      final sidePots = SidePotCalculator.calculateSidePots(players);

      expect(sidePots.length, 2);

      // Main pot: 100 × 3 live + min(300, 100) dead = 400
      expect(sidePots[0].amount, 400);
      expect(sidePots[0].eligiblePlayers, [1, 2, 3]);

      // Side pot: 400 (B) + 400 (C) + 200 dead from D = 1000
      expect(sidePots[1].amount, 1000);
      expect(sidePots[1].eligiblePlayers, [2, 3]);

      final totalFromPots = sidePots.fold<double>(0, (sum, pot) => sum + pot.amount);
      expect(totalFromPots, 1400, reason: 'All committed chips stay in the pots');
    });

    test('Folded contribution above the top live level goes into the top pot', () {
      List<PlayerState> players = [
        PlayerState(playerId: 1, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 100),
        PlayerState(playerId: 2, isActive: true, hasFolded: false, currentStack: 100, totalContribution: 500),
        PlayerState(playerId: 3, isActive: true, hasFolded: true, currentStack: 0, totalContribution: 600), // folded over top
      ];

      final sidePots = SidePotCalculator.calculateSidePots(players);

      expect(sidePots.length, 2);
      // Main pot: 100 × 2 live + 100 dead = 300
      expect(sidePots[0].amount, 300);
      // Side pot: 400 (P2) + 400 dead + 100 dead excess = 900
      expect(sidePots[1].amount, 900);

      final totalFromPots = sidePots.fold<double>(0, (sum, pot) => sum + pot.amount);
      expect(totalFromPots, 1200, reason: 'No chips may vanish');
    });

    test('Inactive players excluded from side pots', () {
      List<PlayerState> players = [
        PlayerState(playerId: 1, isActive: false, hasFolded: false, currentStack: 0, totalContribution: 500), // INACTIVE
        PlayerState(playerId: 2, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 1000),
        PlayerState(playerId: 3, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 1500),
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

    test('Bets matched by another player are NOT refunded (3-way short all-in)', () {
      // A bets 100, C calls all-in for 60, B calls 100.
      // The 40+40 above C's level is a legitimate side pot between A and B —
      // nothing may be refunded.
      final gameState = PokerGameState(
        numberOfPlayers: 3,
        smallBlind: 1,
        bigBlind: 2,
        isCashGame: true,
      );
      for (int i = 1; i <= 3; i++) {
        gameState.setPlayerActive(i, true);
      }
      gameState.players[0].betThisRound = 100; // A
      gameState.players[1].betThisRound = 100; // B
      gameState.players[2].betThisRound = 60; // C all-in
      gameState.players[2].isAllIn = true;
      gameState.currentPot = 260;
      gameState.currentBet = 100;

      final result = gameState.processUncalledBetReturns();

      expect(result, '', reason: 'Top bet was matched by B — no refund');
      expect(gameState.currentPot, 260);
      expect(gameState.players[0].betThisRound, 100);
      expect(gameState.players[1].betThisRound, 100);
    });

    test('Only the single highest bettor gets the uncalled overage back', () {
      // A bets 100, C calls all-in for 60, B folds.
      // A's 40 above C's level is uncalled and returns to A only.
      final gameState = PokerGameState(
        numberOfPlayers: 3,
        smallBlind: 1,
        bigBlind: 2,
        isCashGame: true,
      );
      for (int i = 1; i <= 3; i++) {
        gameState.setPlayerActive(i, true);
      }
      gameState.players[0].betThisRound = 100; // A
      gameState.players[0].currentStack = 400;
      gameState.players[1].hasFolded = true; // B folded
      gameState.players[2].betThisRound = 60; // C all-in
      gameState.players[2].isAllIn = true;
      gameState.currentPot = 160;
      gameState.currentBet = 100;

      final result = gameState.processUncalledBetReturns();

      expect(result.isNotEmpty, true);
      expect(gameState.players[0].betThisRound, 60);
      expect(gameState.players[0].currentStack, 440);
      expect(gameState.currentPot, 120);
      expect(gameState.currentBet, 60);
    });

    test('Heads-up all-in over-shove refunds the difference', () {
      final gameState = PokerGameState(
        numberOfPlayers: 2,
        smallBlind: 1,
        bigBlind: 2,
        isCashGame: true,
      );
      for (int i = 1; i <= 2; i++) {
        gameState.setPlayerActive(i, true);
      }
      gameState.players[0].betThisRound = 500; // A shoves
      gameState.players[0].currentStack = 0;
      gameState.players[0].isAllIn = true;
      gameState.players[1].betThisRound = 200; // B calls all-in for less
      gameState.players[1].isAllIn = true;
      gameState.currentPot = 700;
      gameState.currentBet = 500;

      final result = gameState.processUncalledBetReturns();

      expect(result.isNotEmpty, true);
      expect(gameState.players[0].betThisRound, 200);
      expect(gameState.players[0].currentStack, 300);
      expect(gameState.players[0].isAllIn, false,
          reason: 'Refund puts chips behind — no longer all-in');
      expect(gameState.currentPot, 400);
    });

    test('Verify pot amounts sum to total contributions', () {
      List<PlayerState> players = [
        PlayerState(playerId: 1, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 300),
        PlayerState(playerId: 2, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 700),
        PlayerState(playerId: 3, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 1200),
        PlayerState(playerId: 4, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 2000),
      ];

      final sidePots = SidePotCalculator.calculateSidePots(players);

      final totalFromPots = sidePots.fold<double>(0, (sum, pot) => sum + pot.amount);
      final totalContributions = players
          .where((p) => p.isActive)
          .fold<double>(0, (sum, p) => sum + p.totalContribution + p.betThisRound);

      expect(totalFromPots, totalContributions,
        reason: 'Sum of all pots should equal sum of all committed chips');
    });
    test('B11: heads-up overage pot has a single eligible player (display drops it)', () {
      // Heads-up all-in, unequal contributions BEFORE the uncalled bet is
      // returned. The raw calculator emits the overage as a trailing pot,
      // but it has only ONE eligible player — recalculateActiveSidePots
      // filters pots to eligiblePlayers.length >= 2, so no spurious side-pot
      // pill ever shows heads-up. A genuine side pot needs 3+ live players.
      List<PlayerState> players = [
        PlayerState(playerId: 1, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 1000),
        PlayerState(playerId: 2, isActive: true, hasFolded: false, isAllIn: true, currentStack: 0, totalContribution: 1200),
      ];

      final sidePots = SidePotCalculator.calculateSidePots(players);

      // Exactly one pot is contestable (2 eligible); the overage is single-eligible.
      final contestable = sidePots.where((p) => p.eligiblePlayers.length >= 2).toList();
      expect(contestable.length, 1, reason: 'Heads-up has exactly one contested pot');
      expect(contestable.first.amount, 2000);
      final overage = sidePots.where((p) => p.eligiblePlayers.length < 2).toList();
      for (final p in overage) {
        expect(p.eligiblePlayers.length, 1, reason: 'Overage is an uncalled bet, not a side pot');
      }
    });
  });
}
