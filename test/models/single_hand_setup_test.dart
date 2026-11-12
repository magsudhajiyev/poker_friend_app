import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lib/models/game_types.dart';
import '../../lib/models/single_hand_setup.dart';
import '../../lib/utils/poker_positions.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('positionsFor', () {
    test('heads-up is BTN and BB only', () {
      expect(SingleHandSetup.positionsFor(2), ['BTN', 'BB']);
    });

    test('lists early to late with the blinds last', () {
      expect(SingleHandSetup.positionsFor(3), ['BTN', 'SB', 'BB']);
      expect(SingleHandSetup.positionsFor(6),
          ['UTG', 'HJ', 'CO', 'BTN', 'SB', 'BB']);
      expect(SingleHandSetup.positionsFor(9),
          ['UTG', 'UTG+1', 'UTG+2', 'LJ', 'HJ', 'CO', 'BTN', 'SB', 'BB']);
    });

    test('one name per seat for every player count', () {
      for (var n = 2; n <= 9; n++) {
        final p = SingleHandSetup.positionsFor(n);
        expect(p.length, n, reason: '$n players');
        expect(p.toSet().length, n, reason: '$n players: unique');
      }
    });
  });

  group('button derivation', () {
    test('hero (seat 1) gets the chosen position for 2..9 players', () {
      for (var n = 2; n <= 9; n++) {
        for (final pos in SingleHandSetup.positionsFor(n)) {
          final setup = SingleHandSetup(playerCount: n, heroPosition: pos);
          final snap = setup.toSnapshot();
          final hero = snap.seats.firstWhere((s) => s.seat == 1);
          // Heads-up the logger names the button "BTN/SB".
          final expected = n == 2 && pos == 'BTN' ? 'BTN/SB' : pos;
          expect(hero.position, expected, reason: '$n players, $pos');
          expect(snap.heroSeat, 1);
          expect(
            PokerPositions.getPositionNameForActivePlayers(
                1, snap.buttonPosition, [for (var s = 1; s <= n; s++) s]),
            expected,
          );
        }
      }
    });

    test('hero on the button sits on the button seat', () {
      expect(
          SingleHandSetup(playerCount: 6, heroPosition: 'BTN').buttonSeat, 1);
    });

    test('hero in the small blind: button is the previous seat', () {
      expect(SingleHandSetup(playerCount: 6, heroPosition: 'SB').buttonSeat, 6);
    });

    test('heads-up BB: the other seat holds the button', () {
      final s = SingleHandSetup(playerCount: 2, heroPosition: 'BB');
      expect(s.buttonSeat, 2);
    });
  });

  group('toSnapshot', () {
    test('all seats active with stackBB * bigBlind chips', () {
      final snap = SingleHandSetup(
        smallBlind: 0.5,
        bigBlind: 1,
        playerCount: 5,
        stackBB: 80,
        hasBBante: true,
      ).toSnapshot();
      expect(snap.seats.length, 5);
      expect(snap.seats.every((s) => s.active && s.stack == 80), true);
      expect(snap.hasBBante, true);
      expect(snap.gameType, 'cash');
      expect(snap.deadSbSeat, isNull);
    });

    test('tournament game type is carried', () {
      final snap = SingleHandSetup(gameType: GameType.tournament).toSnapshot();
      expect(snap.gameType, 'tournament');
    });
  });

  group('last used', () {
    test('first run gives cash 1/2, 6 players, BTN, 100 BB', () async {
      final s = await SingleHandSetup.loadLastUsed();
      expect(s.gameType, GameType.cash);
      expect(s.smallBlind, 1);
      expect(s.bigBlind, 2);
      expect(s.playerCount, 6);
      expect(s.heroPosition, 'BTN');
      expect(s.stackBB, 100);
      expect(s.card1, isNull);
    });

    test('round trip keeps the set-up but not the cards', () async {
      await SingleHandSetup(
        gameType: GameType.tournament,
        smallBlind: 100,
        bigBlind: 200,
        hasBBante: true,
        playerCount: 9,
        heroPosition: 'UTG+1',
        stackBB: 35.5,
        card1: 'A♠',
        card2: 'K♠',
      ).saveAsLastUsed();
      final s = await SingleHandSetup.loadLastUsed();
      expect(s.gameType, GameType.tournament);
      expect(s.bigBlind, 200);
      expect(s.hasBBante, true);
      expect(s.playerCount, 9);
      expect(s.heroPosition, 'UTG+1');
      expect(s.stackBB, 35.5);
      expect(s.card1, isNull);
      expect(s.card2, isNull);
    });

    test('a position invalid for the player count falls back to BTN', () {
      final s =
          SingleHandSetup.fromMap({'playerCount': 3, 'heroPosition': 'UTG'});
      expect(s.playerCount, 3);
      expect(s.heroPosition, 'BTN');
    });

    test('garbage values fall back to defaults', () {
      final s = SingleHandSetup.fromMap(
          {'playerCount': 99, 'bigBlind': -1, 'stackBB': 0});
      expect(s.playerCount, 9);
      expect(s.bigBlind, 2);
      expect(s.stackBB, 100);
    });
  });

  group('stack spread', () {
    SingleHandSetup mk(StackSpread sp,
            {GameType t = GameType.cash, double sb = 1, double bb = 2}) =>
        SingleHandSetup(
            gameType: t,
            smallBlind: sb,
            bigBlind: bb,
            stackBB: 100,
            playerCount: 9,
            stackSpread: sp);

    test('same: everyone has X, no rolled map', () {
      final s = mk(StackSpread.same)..rollStacks(Random(1));
      expect(s.villainStacks, isNull);
      for (final seat in s.toSnapshot().seats) {
        expect(seat.stack, 200);
      }
    });

    for (final (spread, pct) in [
      (StackSpread.near, 0.10),
      (StackSpread.similar, 0.25),
    ]) {
      for (final (t, sb, bb) in [
        (GameType.cash, 1.0, 2.0),
        (GameType.tournament, 100.0, 200.0),
      ]) {
        test('${spread.name} ${t.name}: hero X, villains within +-$pct', () {
          for (var seed = 0; seed < 50; seed++) {
            final s = mk(spread, t: t, sb: sb, bb: bb)
              ..rollStacks(Random(seed));
            final seats = {for (final x in s.toSnapshot().seats) x.seat: x};
            expect(seats[1]!.stack, 100 * bb);
            for (var i = 2; i <= 9; i++) {
              final inBB = seats[i]!.stack / bb;
              expect(inBB, inBB.roundToDouble());
              expect(inBB, greaterThanOrEqualTo(100 * (1 - pct) - 0.5));
              expect(inBB, lessThanOrEqualTo(100 * (1 + pct) + 0.5));
            }
          }
        });
      }
    }

    test('villain stacks never drop below 1 BB', () {
      final s = SingleHandSetup(
          stackBB: 1, playerCount: 9, stackSpread: StackSpread.similar);
      for (var seed = 0; seed < 50; seed++) {
        s.rollStacks(Random(seed));
        for (final v in s.villainStacks!.values) {
          expect(v / s.bigBlind, greaterThanOrEqualTo(1));
        }
      }
    });

    test('stable: snapshot and a copy use the same rolled stacks', () {
      final s = mk(StackSpread.similar)..rollStacks(Random(7));
      final a = s.toSnapshot().seats.map((x) => x.stack).toList();
      final b = s.copyWith().toSnapshot().seats.map((x) => x.stack).toList();
      expect(b, a);
      expect(s.toSnapshot().seats.map((x) => x.stack).toList(), a);
    });

    test('spread is persisted, villain stacks are not', () {
      final s = mk(StackSpread.near)..rollStacks(Random(3));
      final m = s.toMap();
      expect(m['stackSpread'], 'near');
      expect(m.containsKey('villainStacks'), isFalse);
      expect(SingleHandSetup.fromMap(m).stackSpread, StackSpread.near);
      expect(SingleHandSetup.fromMap({}).stackSpread, StackSpread.same);
    });
  });

  group('stack unit', () {
    test('chips -> BB at 100/200', () {
      expect(SingleHandSetup.stackToBB(52000, StackUnit.amount, 200), 260);
      expect(SingleHandSetup.stackToBB(260, StackUnit.bb, 200), 260);
    });
    test('money -> BB at 1/2', () {
      expect(SingleHandSetup.stackToBB(200, StackUnit.amount, 2), 100);
    });
    test('empty / zero input is null', () {
      expect(SingleHandSetup.stackToBB(null, StackUnit.bb, 2), isNull);
      expect(SingleHandSetup.stackToBB(0, StackUnit.amount, 2), isNull);
    });
    test('defaults and persistence per game type', () {
      final s = SingleHandSetup();
      expect(s.cashStackUnit, StackUnit.bb);
      expect(s.tournamentStackUnit, StackUnit.amount);
      s.tournamentStackUnit = StackUnit.bb;
      final r = SingleHandSetup.fromMap(s.toMap());
      expect(r.tournamentStackUnit, StackUnit.bb);
      expect(r.cashStackUnit, StackUnit.bb);
      expect(SingleHandSetup.fromMap({}).tournamentStackUnit, StackUnit.amount);
    });
  });
}
