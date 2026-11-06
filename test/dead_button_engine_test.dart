import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/poker_game_state.dart';

/// Dead button / dead small blind through the real engine
/// (startNewHand + initializePot). Pure vectors: dead_button_rotation_test.dart.

PokerGameState table(
  List<int> live, {
  int seats = 6,
  int button = 1,
  bool ante = false,
  double sb = 1,
  double bb = 2,
}) {
  final g = PokerGameState(
      numberOfPlayers: seats,
      smallBlind: sb,
      bigBlind: bb,
      isCashGame: true,
      hasBBante: ante);
  for (final s in live) {
    g.setPlayerActive(s, true);
    g.setPlayerStack(s, 100);
  }
  g.buttonPosition = button;
  g.finalizeInitialization();
  g.initializePot();
  return g;
}

void nextHand(PokerGameState g) {
  g.startNewHand();
  g.initializePot();
}

/// A player busts: zero stack, deactivated by the next startNewHand.
void bust(PokerGameState g, int seat) => g.players[seat - 1].currentStack = 0;

String roles(PokerGameState g) =>
    '${g.buttonDead ? 'x' : ''}${g.buttonPosition}/'
    '${g.smallBlindDead ? '-' : g.effectiveSBPosition}/${g.effectiveBBPosition}';

double bet(PokerGameState g, int seat) => g.players[seat - 1].betThisRound;

double chips(PokerGameState g) => g.players.fold(
    0.0, (s, p) => s + p.currentStack + p.betThisRound + p.totalContribution);

/// Everybody limps / checks to the flop; returns the postflop actor order.
List<int> flopOrder(PokerGameState g) {
  var guard = 0;
  while (!g.bettingRoundComplete && guard++ < 20) {
    g.performAction(g.isValidAction(PlayerAction.check)
        ? PlayerAction.check
        : PlayerAction.call);
  }
  g.startNewStreet();
  final order = <int>[];
  guard = 0;
  while (!g.bettingRoundComplete && guard++ < 20) {
    order.add(g.currentPlayer);
    g.performAction(PlayerAction.check);
  }
  return order;
}

void main() {
  group('dead small blind (seat 3 = BB busts)', () {
    test('hand 2: BTN2, no SB posted, BB4 posts only the BB', () {
      final g = table([1, 2, 3, 4, 5, 6]);
      expect(roles(g), '1/2/3');
      bust(g, 3);
      nextHand(g);
      expect(roles(g), '2/-/4');
      expect(g.smallBlindDead, isTrue);
      expect(g.currentPot, 2.0);
      expect(bet(g, 2), 0.0);
      expect(bet(g, 4), 2.0);
      expect(g.currentBet, 2.0);
      expect(g.currentPlayer, 5, reason: 'UTG is the first live seat after BB');
    });

    test('hand 3: dead button on seat 3, SB4, BB5', () {
      final g = table([1, 2, 3, 4, 5, 6]);
      bust(g, 3);
      nextHand(g);
      nextHand(g);
      expect(roles(g), 'x3/4/5');
      expect(g.buttonDead, isTrue);
      expect(g.currentPot, 3.0);
      expect(bet(g, 4), 1.0);
      expect(bet(g, 5), 2.0);
      expect(g.currentPlayer, 6);
    });

    test('hand 4 is normal again', () {
      final g = table([1, 2, 3, 4, 5, 6]);
      bust(g, 3);
      for (var i = 0; i < 3; i++) {
        nextHand(g);
      }
      expect(roles(g), '4/5/6');
      expect(g.currentPot, 3.0);
    });
  });

  group('BB ante on dead SB and dead button hands', () {
    test('BB posts the full ante; dead SB pot is BB + ante only', () {
      final g = table([1, 2, 3, 4, 5, 6], ante: true);
      bust(g, 3);
      nextHand(g);
      expect(g.smallBlindDead, isTrue);
      expect(bet(g, 4), 4.0);
      expect(g.currentPot, 4.0);
      nextHand(g);
      expect(g.buttonDead, isTrue);
      expect(g.currentPot, 5.0, reason: 'SB 1 + BB 2 + ante 2');
      expect(bet(g, 5), 4.0);
    });
  });

  group('action order', () {
    test('4 live, BB (C) busts: preflop A,B,D then postflop D,A,B', () {
      final g = table([1, 2, 3, 4], seats: 4);
      bust(g, 3);
      nextHand(g);
      expect(roles(g), '2/-/4');
      expect(g.currentPlayer, 1, reason: 'preflop starts at A (seat 1)');
      expect(flopOrder(g), [4, 1, 2]);
    });

    test('4 live, hand 3: dead button seat 3, postflop D,A,B', () {
      final g = table([1, 2, 3, 4], seats: 4);
      bust(g, 3);
      nextHand(g);
      nextHand(g);
      expect(roles(g), 'x3/4/1');
      expect(g.currentPlayer, 2, reason: 'preflop B, D, A');
      expect(flopOrder(g), [4, 1, 2]);
    });

    test('4 live, SB (B) busts: preflop A,C,D then postflop C,D,A', () {
      final g = table([1, 2, 3, 4], seats: 4);
      bust(g, 2);
      nextHand(g);
      expect(roles(g), 'x2/3/4');
      expect(g.currentPlayer, 1);
      expect(flopOrder(g), [3, 4, 1]);
    });

    test('seats 2 and 3 bust: seat 1 acts last postflop three hands in a row',
        () {
      final g = table([1, 2, 3, 4, 5, 6]);
      expect(flopOrder(g).last, 1, reason: 'hand 1');
      bust(g, 2);
      bust(g, 3);
      for (var i = 2; i <= 3; i++) {
        nextHand(g);
        expect(flopOrder(g).last, 1, reason: 'hand $i');
      }
      nextHand(g);
      expect(flopOrder(g).last, 4, reason: 'hand 4: button 4 acts last');
    });
  });

  group('position names are real', () {
    test('dead button: nobody is BTN, SB and BB keep their names', () {
      final g = table([1, 2, 3, 4, 5, 6]);
      bust(g, 3);
      nextHand(g);
      nextHand(g); // x3/4/5
      final names = {for (final s in [1, 2, 4, 5, 6]) s: g.getPlayerPositionName(s)};
      expect(names.values.contains('BTN'), isFalse);
      expect(names[4], 'SB');
      expect(names[5], 'BB');
      expect(names[6], 'UTG');
    });

    test('dead SB: nobody is SB, button and BB keep their names', () {
      final g = table([1, 2, 3, 4, 5, 6]);
      bust(g, 3);
      nextHand(g); // 2/-/4
      final names = {for (final s in [1, 2, 4, 5, 6]) s: g.getPlayerPositionName(s)};
      expect(names.values.contains('SB'), isFalse);
      expect(names[2], 'BTN');
      expect(names[4], 'BB');
      expect(names[5], 'UTG');
    });
  });

  group('idempotency', () {
    test('initializePot / recalculateActionOrder never advance the rotation',
        () {
      final g = table([1, 2, 3, 4, 5, 6]);
      bust(g, 3);
      nextHand(g);
      final before = roles(g);
      for (var i = 0; i < 4; i++) {
        g.initializePot();
        g.recalculateActionOrder();
      }
      expect(roles(g), before);
      expect(g.currentPot, 2.0);
      nextHand(g);
      expect(roles(g), 'x3/4/5');
    });

    test('BB removed before any action == left before the hand started', () {
      // A: seat 4 (this hand's BB) is removed after the hand was dealt.
      final a = table([1, 2, 3, 4, 5, 6]);
      bust(a, 3);
      nextHand(a); // 2/-/4
      a.setPlayerActive(4, false);
      a.initializePot();
      a.recalculateActionOrder();

      // B: seat 4 left in the same window as seat 3 busted (before the hand).
      final b = table([1, 2, 3, 4, 5, 6]);
      bust(b, 3);
      b.setPlayerActive(4, false);
      nextHand(b);

      expect(roles(a), roles(b));
      expect(a.currentPot, b.currentPot);
      expect(a.currentPlayer, b.currentPlayer);
      expect(chips(a), chips(b), reason: 'removed BB blind was refunded');
    });

    test('rotateBlindsForNextHand + initializePot == startNewHand path (Skip)',
        () {
      final a = table([1, 2, 3, 4, 5, 6]);
      bust(a, 3);
      nextHand(a);
      final b = table([1, 2, 3, 4, 5, 6]);
      bust(b, 3);
      b.deactivateBustedPlayers();
      b.rotateBlindsForNextHand();
      b.initializePot();
      expect(roles(b), roles(a));
      b.rotateBlindsForNextHand();
      a.startNewHand();
      a.initializePot();
      b.initializePot();
      expect(roles(b), roles(a));
      expect(roles(a), 'x3/4/5');
    });
  });

  group('manual button move sets a new baseline', () {
    test('later hands continue from the moved button, never revert', () {
      final g = table([1, 2, 3, 4, 5, 6]);
      nextHand(g); // 2/3/4
      g.buttonPosition = 5;
      g.initializePot();
      expect(roles(g), '5/6/1');
      expect(g.currentPot, 3.0);
      nextHand(g);
      expect(roles(g), '6/1/2');
    });

    test('move onto an empty seat is a dead button; SB is the next live seat',
        () {
      final g = table([1, 2, 4, 5, 6]);
      g.buttonPosition = 3;
      g.initializePot();
      expect(roles(g), 'x3/4/5');
      expect(g.currentPot, 3.0);
      nextHand(g);
      expect(roles(g), '4/5/6');
    });

    test('heads-up move onto an empty seat snaps to a live SB', () {
      final g = table([2, 5]);
      g.buttonPosition = 3;
      g.initializePot();
      expect(g.buttonPosition, 5);
      expect(g.effectiveBBPosition, 2);
      expect(g.currentPlayer, 5);
    });
  });

  group('undo / restore', () {
    test('restoreBlinds puts button and memory back exactly', () {
      final g = table([1, 2, 3, 4, 5, 6]);
      final mem = g.blindMemory;
      final btn = g.buttonPosition;
      bust(g, 3);
      nextHand(g);
      // Undo restores the seats' active flags first (TableSnapshot).
      g.setPlayerActive(3, true);
      g.setPlayerStack(3, 100);
      g.restoreBlinds(btn, mem);
      expect(roles(g), '1/2/3');
      expect(g.blindMemory, mem);
      nextHand(g);
      expect(roles(g), '2/3/4');
    });
  });

  group('heads-up transitions', () {
    test('3 live to heads-up: nobody pays BB twice, button is SB', () {
      final g = table([1, 2, 3], seats: 3);
      bust(g, 1);
      nextHand(g);
      expect(roles(g), '3/3/2');
      expect(bet(g, 3), 1.0);
      expect(bet(g, 2), 2.0);
      expect(g.currentPlayer, 3);
      nextHand(g);
      expect(roles(g), '2/2/3');
    });

    test('heads-up back to 3 live does not crash or double-charge BB', () {
      final g = table([1, 2, 3], seats: 3);
      bust(g, 3);
      nextHand(g); // 2/2/1
      expect(g.effectiveBBPosition, 1);
      g.setPlayerActive(3, true);
      g.setPlayerStack(3, 100);
      nextHand(g);
      expect(g.effectiveBBPosition, 2);
      expect(g.effectiveSBPosition, 1);
      expect(g.buttonPosition, 3);
      expect(bet(g, 2), 2.0);
      expect(bet(g, 1), 1.0);
    });
  });

  group('a player sits in the dead SB seat', () {
    test('seat becomes live and posts the SB', () {
      final g = table([1, 2, 3, 4, 5, 6]);
      bust(g, 3);
      nextHand(g);
      expect(g.smallBlindDead, isTrue);
      g.setPlayerActive(3, true);
      g.setPlayerStack(3, 100);
      g.initializePot();
      g.recalculateActionOrder();
      expect(g.smallBlindDead, isFalse);
      expect(roles(g), '2/3/4');
      expect(bet(g, 3), 1.0);
      expect(g.currentPot, 3.0);
      expect(g.players[2].currentStack + bet(g, 3), 100.0);
      expect(g.players[3].currentStack + bet(g, 4), 100.0);
    });
  });

  group('regression: no seat changes equals today', () {
    for (var n = 2; n <= 9; n++) {
      test('$n players, two orbits', () {
        final live = [for (var s = 1; s <= n; s++) s];
        final g = table(live, seats: 9);
        for (var i = 0; i < n * 2; i++) {
          if (i > 0) nextHand(g);
          final btn = (i % n) + 1;
          if (n == 2) {
            expect(g.effectiveSBPosition, g.buttonPosition);
            expect(g.currentPot, 3.0);
            continue;
          }
          expect(g.buttonPosition, btn, reason: 'n=$n hand ${i + 1}');
          expect(g.effectiveSBPosition, (btn % n) + 1);
          expect(g.effectiveBBPosition, ((btn + 1) % n) + 1);
          expect(g.smallBlindDead || g.buttonDead, isFalse);
          expect(g.currentPot, 3.0);
        }
      });
    }

    test('sparse table [1,3,5,7,9]', () {
      final g = table([1, 3, 5, 7, 9], seats: 9);
      final seen = <String>[];
      for (var i = 0; i < 5; i++) {
        if (i > 0) nextHand(g);
        seen.add(roles(g));
      }
      expect(seen, ['1/3/5', '3/5/7', '5/7/9', '7/9/1', '9/1/3']);
    });
  });

  group('rotation and posting agree on who is live', () {
    test('Skip with an active zero-stack seat: heads-up, no chip-less seat',
        () {
      final g = table([1, 2, 3], seats: 3);
      g.players[2].currentStack = 0; // seat 3 busted, not yet deactivated
      g.players[2].betThisRound = 0;
      g.skipToNextHand(heroSeat: 1);
      expect(g.players[2].isActive, isFalse);
      expect(g.getActivePlayers(), [1, 2]);
      expect(g.effectiveSBPosition, g.buttonPosition, reason: 'heads-up');
      expect(g.currentPlayer, g.buttonPosition);
      expect(g.currentPot, 3.0);
    });

    test('Skip refunds the hand and charges the hero blind once', () {
      final g = table([1, 2, 3, 4], seats: 4); // BTN1 SB2 BB3
      g.skipToNextHand(heroSeat: 3); // hero is BB: owes 2
      // Hero (BB) paid 2 for the skipped hand; next hand they are the SB.
      expect(roles(g), '2/3/4');
      expect(g.players[2].currentStack + bet(g, 3), 98.0);
      expect(g.currentPot, 3.0);
    });

    test('Skip: a hero whose blind takes the whole stack stays seated at 0',
        () {
      final g = table([1, 2, 3, 4], seats: 4); // BTN1 SB2 BB3
      final hero = g.players[2];
      hero.currentStack = 0;
      hero.betThisRound = 2; // hero (stack 2) posted the BB
      g.skipToNextHand(heroSeat: 3);
      expect(hero.isActive, isTrue);
      expect(hero.currentStack, 0.0);
      expect(hero.betThisRound, 0.0);
      // Next hand: the hero has no chips, so their BB seat is a dead SB and
      // they neither post nor act first.
      expect(roles(g), '2/-/4');
      expect(g.smallBlindDead, isTrue);
      expect(g.getActivePlayers(), contains(3));
      expect(bet(g, 3), 0.0);
      expect(g.currentPlayer, 1);
      expect(g.currentPot, 2.0);
    });

    test('Skip rotates exactly once, same result as startNewHand', () {
      final a = table([1, 2, 3, 4, 5, 6]);
      a.skipToNextHand();
      final b = table([1, 2, 3, 4, 5, 6]);
      nextHand(b);
      expect(roles(a), roles(b));
      expect(a.currentPlayer, b.currentPlayer);
    });

    test('a seat added pre-action with ZERO chips is ignored by the blinds',
        () {
      final g = table([1, 2], seats: 3);
      g.setPlayerActive(3, true);
      g.setPlayerStack(3, 0);
      g.initializePot();
      g.recalculateActionOrder();
      expect(g.effectiveSBPosition, g.buttonPosition, reason: 'still heads-up');
      expect(bet(g, 3), 0.0);
      expect(g.currentPot, 3.0);
    });

    test('property: the seat that posts the BB is always the one remembered',
        () {
      final rng = Random(7);
      final g = table([1, 2, 3, 4, 5, 6], seats: 9);
      for (var hand = 0; hand < 300; hand++) {
        final liveNow = [
          for (final p in g.players)
            if (p.isActive && p.currentStack > 0) p.playerId
        ];
        final bb = g.effectiveBBPosition;
        final sb = g.effectiveSBPosition;
        if (liveNow.length >= 2) {
          expect(bet(g, bb), greaterThan(0), reason: 'hand $hand BB posts');
          if (!g.smallBlindDead) {
            expect(bet(g, sb), greaterThan(0), reason: 'hand $hand SB posts');
          } else if (liveNow.length > 2) {
            expect(g.players[sb - 1].isActive, isFalse);
          }
        }
        // Random churn between hands: busts, leaves, joins.
        for (var s = 1; s <= 6; s++) {
          final r = rng.nextInt(10);
          final p = g.players[s - 1];
          if (p.isActive && r == 0) p.currentStack = 0;
          if (p.isActive && r == 1) g.setPlayerActive(s, false);
          if (!p.isActive && r >= 7) {
            g.setPlayerActive(s, true);
            g.setPlayerStack(s, 100);
          }
        }
        final before = (g.effectiveBBPosition, g.effectiveSBPosition);
        g.startNewHand();
        if (g.getActivePlayers().length < 2) {
          for (final s in [1, 2]) {
            g.setPlayerActive(s, true);
            g.setPlayerStack(s, 100);
          }
        }
        g.initializePot();
        if (g.blindMemory != null && before.$1 != 0) {
          expect(g.blindMemory, before, reason: 'hand $hand memory');
        }
      }
    });
  });
}
