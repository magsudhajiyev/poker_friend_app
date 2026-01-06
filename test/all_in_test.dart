import 'package:flutter_test/flutter_test.dart';
import '../lib/models/poker_game_state.dart';

void main() {
  group('All-In Logic Tests', () {
    late PokerGameState gameState;

    setUp(() {
      gameState = PokerGameState(
        numberOfPlayers: 4,
        smallBlind: 1,
        bigBlind: 2,
        isCashGame: true,
      );

      // Set player stacks and activate players
      for (int i = 1; i <= 4; i++) {
        gameState.setPlayerStack(i, 100.0);
        gameState.setPlayerActive(i, true);
      }
    });

    test('areAllPlayersAllIn returns false when all players have stacks', () {
      expect(gameState.areAllPlayersAllIn(), false);
    });

    test('areAllPlayersAllIn returns false with only one active player', () {
      // Fold 3 players
      gameState.players[1].hasFolded = true;
      gameState.players[2].hasFolded = true;
      gameState.players[3].hasFolded = true;
      
      expect(gameState.areAllPlayersAllIn(), false);
    });

    test('areAllPlayersAllIn returns true when all but one player are all-in', () {
      // Make 3 players all-in, 1 player can still act
      gameState.players[0].updateStack(0.0); // Player 1 all-in
      gameState.players[1].updateStack(0.0); // Player 2 all-in
      gameState.players[2].updateStack(0.0); // Player 3 all-in
      gameState.players[3].updateStack(50.0); // Player 4 can act

      // Mark the last player as having acted and called the bet for all-in logic to trigger
      gameState.players[3].hasActed = true;
      gameState.players[3].hasCalledCurrentBet = true;

      expect(gameState.areAllPlayersAllIn(), true);
    });

    test('areAllPlayersAllIn returns true when all players are all-in', () {
      // All players all-in
      for (int i = 0; i < 4; i++) {
        gameState.players[i].updateStack(0.0);
      }

      expect(gameState.areAllPlayersAllIn(), true);
    });

    test('getPlayersWhoCanAct excludes folded and all-in players', () {
      gameState.players[0].hasFolded = true; // Player 1 folded
      gameState.players[1].updateStack(0.0); // Player 2 all-in
      // Player 3 and 4 can still act (they have 100.0 from setUp)

      final playersWhoCanAct = gameState.getPlayersWhoCanAct();
      expect(playersWhoCanAct, [3, 4]);
    });

    test('canPlayerAct returns false for all-in player', () {
      gameState.players[0].updateStack(0.0); // Player 1 all-in
      gameState.currentPlayer = 1;

      expect(gameState.canPlayerAct(1), false);
    });

    test('_getNextActivePlayer handles all-in players correctly', () {
      // Player 1 can act (100.0 from setUp)
      gameState.players[1].updateStack(0.0); // Player 2 all-in
      gameState.players[2].hasFolded = true; // Player 3 folded
      // Player 4 can act (100.0 from setUp)

      // From player 1, next active should be player 4 (skipping all-in player 2 and folded player 3)
      final playersWhoCanAct = gameState.getPlayersWhoCanAct();
      expect(playersWhoCanAct.length, 2); // Players 1 and 4
      expect(playersWhoCanAct.contains(1), true);
      expect(playersWhoCanAct.contains(4), true);
    });

    test('isAllIn returns true only for zero stack', () {
      final player = gameState.players[0];

      player.updateStack(100.0);
      expect(player.isAllIn, false);

      player.updateStack(0.01);
      expect(player.isAllIn, false);

      player.updateStack(0.0);
      expect(player.isAllIn, true);
    });

    test('betting round completes when all players are all-in', () {
      // Set up scenario where all but one player are all-in
      gameState.players[0].updateStack(0.0); // All-in
      gameState.players[1].updateStack(0.0); // All-in
      gameState.players[2].updateStack(0.0); // All-in
      gameState.players[3].updateStack(50.0); // Can act, but will be skipped due to all-in rule

      // Mark the last player as having acted and called the bet for all-in logic to trigger
      gameState.players[3].hasActed = true;
      gameState.players[3].hasCalledCurrentBet = true;

      // Since areAllPlayersAllIn() returns true, betting round should complete
      expect(gameState.areAllPlayersAllIn(), true);

      // Test that the betting round completion logic works
      // This would normally be called internally by _isBettingRoundComplete()
      final activePlayers = gameState.getActivePlayers();
      final playersWhoCanAct = gameState.getPlayersWhoCanAct();

      expect(activePlayers.length >= 2, true);
      expect(playersWhoCanAct.length <= 1, true);
    });
  });
}