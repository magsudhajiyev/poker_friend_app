import 'package:flutter_test/flutter_test.dart';
import '../lib/models/poker_game_state.dart';
import '../lib/models/game_types.dart';

// Crashlytics issue 90a88414 (2.1.2): PokerGameState.performActionWithAmount
// threw `Invalid argument(s): 10000.0` from double.clamp when the minimum bet
// (1 BB) exceeded the player's remaining stack — clamp(min, max) requires
// min <= max. The raise case already resolved this as an all-in for less;
// the bet case must do the same.
void main() {
  group('Short-stack bet below minimum (clamp crash regression)', () {
    late PokerGameState gameState;

    setUp(() {
      // Late-tournament shape: blinds 5000/10000, hero has less than 1 BB.
      gameState = PokerGameState(
        numberOfPlayers: 3,
        smallBlind: 5000,
        bigBlind: 10000,
        isCashGame: false,
      );
      for (int i = 1; i <= 3; i++) {
        gameState.setPlayerStack(i, 100000.0);
        gameState.setPlayerActive(i, true);
      }
      // The crash scenario is postflop (bet is invalid preflop).
      gameState.currentRound = BettingRound.flop;
    });

    test('bet with stack below minimum bet resolves to all-in, not a throw',
        () {
      // Postflop, no bet yet this round; player 1 to act with 4000 behind
      // (less than the 10000 minimum bet).
      gameState.setPlayerStack(1, 4000.0);
      gameState.currentPlayer = 1;

      final player = gameState.players[0];
      expect(player.currentStack, 4000.0);

      // The swiped amount (min-bet suggestion) is 10000 — more than the stack.
      final result = gameState.performActionWithAmount(
        PlayerAction.bet,
        10000.0,
      );

      expect(result, isNotNull);
      expect(player.currentStack, 0.0);
      expect(player.isAllIn, true);
      expect(player.betThisRound, 4000.0);
      expect(gameState.currentBet, 4000.0);
    });

    test('raise with stack below minimum raise resolves to all-in (guard kept)',
        () {
      // Player 2 bets 10000, player 1 tries to raise with only 12000 behind
      // (min raise would be 20000).
      gameState.setPlayerStack(1, 12000.0);
      gameState.currentPlayer = 2;
      gameState.performActionWithAmount(PlayerAction.bet, 10000.0);

      gameState.currentPlayer = 1;
      final player = gameState.players[0];
      final result = gameState.performActionWithAmount(
        PlayerAction.raise,
        20000.0,
      );

      expect(result, isNotNull);
      expect(player.currentStack, 0.0);
      expect(player.isAllIn, true);
      expect(player.betThisRound, 12000.0);
    });

    test('normal bet above minimum still clamps to stack ceiling', () {
      gameState.currentPlayer = 1;
      final player = gameState.players[0];

      // Bet far above stack: clamps to all-in at 100000.
      gameState.performActionWithAmount(PlayerAction.bet, 500000.0);
      expect(player.betThisRound, 100000.0);
      expect(player.isAllIn, true);
    });
  });
}
