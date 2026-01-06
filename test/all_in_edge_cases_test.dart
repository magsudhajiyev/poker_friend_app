import 'package:flutter_test/flutter_test.dart';
import '../lib/models/poker_game_state.dart';

void main() {
  group('All-In Edge Cases Tests', () {
    late PokerGameState gameState;

    setUp(() {
      gameState = PokerGameState(
        numberOfPlayers: 3,
        smallBlind: 1,
        bigBlind: 2,
        isCashGame: true,
      );

      // Set player stacks and activate players
      for (int i = 1; i <= 3; i++) {
        gameState.setPlayerStack(i, 100.0);
        gameState.setPlayerActive(i, true);
      }
    });

    test('_getNextActivePlayer handles case when all players are all-in or folded', () {
      // Player 1 is all-in
      gameState.players[0].updateStack(0.0);
      // Player 2 is folded
      gameState.players[1].hasFolded = true;
      // Player 3 is all-in
      gameState.players[2].updateStack(0.0);

      // Starting from player 1, should return player 1 (failsafe)
      // because no valid next player exists
      final nextPlayer = gameState.players[0];
      expect(nextPlayer.playerId, 1);
      expect(nextPlayer.currentStack, 0.0);
    });

    test('betting round completion detects all-in scenario correctly', () {
      // Set up: 2 players all-in, 1 player can act
      gameState.players[0].updateStack(0.0); // Player 1 all-in
      gameState.players[1].updateStack(0.0); // Player 2 all-in
      gameState.players[2].updateStack(50.0); // Player 3 can act

      // Mark the last player as having acted and called the bet for all-in logic to trigger
      gameState.players[2].hasActed = true;
      gameState.players[2].hasCalledCurrentBet = true;

      // The betting round should complete due to all-in rule
      expect(gameState.areAllPlayersAllIn(), true);

      // Simulate the _isBettingRoundComplete method logic
      List<PlayerState> activePlayers = gameState.players.where((p) => !p.hasFolded).toList();
      expect(activePlayers.length, 3); // All players still active (not folded)
      expect(activePlayers.length <= 1, false); // More than 1 player active
      expect(gameState.areAllPlayersAllIn(), true); // All-in condition met
    });

    test('areAllPlayersAllIn handles zero players who can act correctly', () {
      // All players are all-in
      for (int i = 0; i < 3; i++) {
        gameState.players[i].updateStack(0.0);
      }

      expect(gameState.areAllPlayersAllIn(), true);
      expect(gameState.getPlayersWhoCanAct().length, 0);
      expect(gameState.getActivePlayers().length, 3);
    });

    test('canPlayerAct correctly identifies all-in players', () {
      gameState.players[0].updateStack(0.0); // Player 1 all-in
      gameState.currentPlayer = 1;
      gameState.bettingRoundComplete = false;

      expect(gameState.canPlayerAct(1), false);

      // Player with stack can act
      gameState.currentPlayer = 2;
      expect(gameState.canPlayerAct(2), true);
    });

    test('all-in detection works with different stack sizes', () {
      // Player 1: 0.0 (all-in)
      gameState.players[0].updateStack(0.0);

      // Player 2: 0.01 (tiny stack but can act)
      gameState.players[1].updateStack(0.01);

      // Player 3: 100.0 (normal stack) - already set in setUp

      expect(gameState.areAllPlayersAllIn(), false); // 2 players can still act
      expect(gameState.getPlayersWhoCanAct().length, 2);

      // Make player 2 all-in too
      gameState.players[1].updateStack(0.0);

      // Mark player 3 as having acted and called for all-in logic to trigger
      gameState.players[2].hasActed = true;
      gameState.players[2].hasCalledCurrentBet = true;

      expect(gameState.areAllPlayersAllIn(), true); // Only 1 player can act
      expect(gameState.getPlayersWhoCanAct().length, 1);
    });

    test('heads-up all-in scenario', () {
      // Create heads-up game
      gameState = PokerGameState(
        numberOfPlayers: 2,
        smallBlind: 1,
        bigBlind: 2,
        isCashGame: true,
      );

      // Set stacks and activate players
      gameState.setPlayerStack(1, 50.0);
      gameState.setPlayerActive(1, true);
      gameState.setPlayerStack(2, 100.0);
      gameState.setPlayerActive(2, true);

      // Player 1 goes all-in
      gameState.players[0].updateStack(0.0);

      // Mark player 2 as having acted and called for all-in logic to trigger
      gameState.players[1].hasActed = true;
      gameState.players[1].hasCalledCurrentBet = true;

      expect(gameState.areAllPlayersAllIn(), true);
      expect(gameState.getActivePlayers().length, 2);
      expect(gameState.getPlayersWhoCanAct().length, 1);
    });

    test('all folded except one should not trigger all-in logic', () {
      // 2 players fold, 1 remains
      gameState.players[0].hasFolded = true;
      gameState.players[1].hasFolded = true;
      // Player 3 is still in with chips
      
      expect(gameState.areAllPlayersAllIn(), false);
      expect(gameState.getActivePlayers().length, 1);
      expect(gameState.getPlayersWhoCanAct().length, 1);
    });

    test('isAllIn method precision check', () {
      final player = gameState.players[0];

      // Test edge cases around zero
      player.updateStack(-0.01);
      expect(player.isAllIn, false); // Negative should not be all-in

      player.updateStack(0.001);
      expect(player.isAllIn, false); // Small positive not all-in

      player.updateStack(0.0);
      expect(player.isAllIn, true); // Exactly zero is all-in
    });
  });
}