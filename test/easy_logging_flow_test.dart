import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/game_types.dart';
import 'package:poker_logger/models/hand_state_machine.dart';
import 'package:poker_logger/models/poker_game_state.dart';
import 'package:poker_logger/services/easy_logging_flow.dart';

PokerGameState buildGame({int button = 1, List<int>? active}) {
  final g = PokerGameState(
      numberOfPlayers: 9,
      smallBlind: 1,
      bigBlind: 2,
      isCashGame: true,
      hasBBante: false);
  for (final s in active ?? [1, 2, 3, 4, 5, 6]) {
    g.setPlayerActive(s, true);
    g.setPlayerStack(s, 200);
  }
  g.buttonPosition = button;
  g.finalizeInitialization();
  g.initializePot();
  return g;
}

void main() {
  integrationMain();
  test('soleSurvivor is only set when exactly one player remains', () {
    final g = buildGame(active: [1, 2, 3]);
    expect(soleSurvivor(g), isNull);
    g.performAction(PlayerAction.fold);
    g.performAction(PlayerAction.fold);
    expect(soleSurvivor(g), isNotNull);
  });

  test('TableSnapshot restores table state after a skipped-hand reset', () {
    final g = buildGame();
    final before = TableSnapshot.capture(g);
    final pot = g.currentPot;
    final bet = g.currentBet;
    final actor = g.currentPlayer;
    final stacks = [for (final p in g.players) p.currentStack];

    g.performAction(PlayerAction.fold);
    g.handNumber++;
    g.buttonPosition = 2;
    for (final p in g.players) {
      p.reset();
    }
    g.initializePot();

    before.restore(g);
    expect(g.handNumber, 1);
    expect(g.buttonPosition, 1);
    expect(g.currentPot, pot);
    expect(g.currentBet, bet);
    expect(g.currentPlayer, actor);
    expect(g.players[3].hasFolded, isFalse);
    expect([for (final p in g.players) p.currentStack], stacks);
  });
}

void integrationMain() {
  test('tick then undo: next empty hand is swapped for the consumed one', () {
    final g = buildGame();
    final sm = PokerSessionManager(
        smallBlind: 1, bigBlind: 2, playerCount: 6, gameType: GameType.cash);
    sm.ourSeatNumber = 4;
    sm.activeSeats.addAll([1, 2, 3, 4, 5, 6]);
    var committed = 0;
    sm.persistOverride = (_) async => committed++;
    sm.startHand(1, 1, sbSeat: 2, bbSeat: 3);
    final live = sm.currentHand!;

    final snap = TableSnapshot.capture(g);
    final tick = sm.enqueueFoldTick();
    expect(sm.currentHand, isNull);
    expect(tick.committed, isFalse);

    // Screen advances to the next hand.
    g.handNumber++;
    sm.startHand(g.handNumber, 2, sbSeat: 3, bbSeat: 4);
    final next = sm.currentHand!;

    expect(sm.undoLastFoldTick(), isTrue);
    snap.restore(g);
    sm.currentHand = sm.lastUndoneLiveHand;

    expect(identical(sm.currentHand, live), isTrue);
    expect(identical(sm.currentHand, next), isFalse);
    expect(g.handNumber, 1);
    expect(committed, 0);
  });
}
