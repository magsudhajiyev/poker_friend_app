import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/hand_state_machine.dart';
import '../../lib/services/range_grid_service.dart';

Map<String, dynamic> _action(
  int player,
  String action, {
  String street = 'preflop',
  double? stack,
  double? amount,
  bool isHero = false,
}) {
  return {
    'player': player,
    'action': action,
    'street': street,
    'playerStack': stack,
    'amount': amount,
    'isCurrentUser': isHero,
  };
}

void main() {
  group('canonicalHandClass', () {
    test('suited and offsuit combos, high rank first', () {
      expect(RangeGridService.canonicalHandClass(HoleCards(card1: 'A♠', card2: 'K♠')), 'AKs');
      expect(RangeGridService.canonicalHandClass(HoleCards(card1: 'A♠', card2: 'K♥')), 'AKo');
      expect(RangeGridService.canonicalHandClass(HoleCards(card1: 'K♥', card2: 'A♠')), 'AKo',
          reason: 'Order of entry must not matter');
      expect(RangeGridService.canonicalHandClass(HoleCards(card1: '2♦', card2: '7♣')), '72o');
    });

    test('pairs', () {
      expect(RangeGridService.canonicalHandClass(HoleCards(card1: '7♦', card2: '7♣')), '77');
      expect(RangeGridService.canonicalHandClass(HoleCards(card1: 'A♦', card2: 'A♣')), 'AA');
    });

    test('ten rank in both T and 10 notations', () {
      expect(RangeGridService.canonicalHandClass(HoleCards(card1: 'T♠', card2: '9♠')), 'T9s');
      expect(RangeGridService.canonicalHandClass(HoleCards(card1: '10♠', card2: '9♠')), 'T9s');
    });

    test('missing or malformed cards return null', () {
      expect(RangeGridService.canonicalHandClass(null), null);
      expect(RangeGridService.canonicalHandClass(HoleCards(card1: 'A♠')), null);
      expect(RangeGridService.canonicalHandClass(HoleCards(card1: 'X♠', card2: 'K♠')), null);
      expect(RangeGridService.canonicalHandClass(HoleCards(card1: '', card2: 'K♠')), null);
    });
  });

  group('positionGroup', () {
    test('maps exact positions to coarse groups', () {
      expect(RangeGridService.positionGroup('UTG'), 'EP');
      expect(RangeGridService.positionGroup('UTG+1'), 'EP');
      expect(RangeGridService.positionGroup('UTG+2'), 'EP');
      expect(RangeGridService.positionGroup('LJ'), 'MP');
      expect(RangeGridService.positionGroup('HJ'), 'MP');
      expect(RangeGridService.positionGroup('P5'), 'MP');
      expect(RangeGridService.positionGroup('CO'), 'CO');
      expect(RangeGridService.positionGroup('BTN'), 'BTN');
      expect(RangeGridService.positionGroup('BTN/SB'), 'BTN');
      expect(RangeGridService.positionGroup('SB'), 'SB');
      expect(RangeGridService.positionGroup('BB'), 'BB');
    });
  });

  group('derivePreflopLine', () {
    test('open raise', () {
      final actions = [
        _action(2, 'fold'),
        _action(3, 'raise', amount: 6, isHero: true),
        _action(5, 'call', amount: 6),
      ];
      final (primary, line, scenario) =
          RangeGridService.derivePreflopLine(actions, 3);
      expect(primary, 'raise');
      expect(line, 'Open-raised');
      expect(scenario, 'rfi', reason: 'Unopened pot — classic RFI spot');
    });

    test('3-bet (third raise, app convention)', () {
      final actions = [
        _action(2, 'raise', amount: 6),
        _action(4, 'raise', amount: 18),
        _action(3, 'raise', amount: 50, isHero: true),
      ];
      final (primary, line, scenario) =
          RangeGridService.derivePreflopLine(actions, 3);
      expect(primary, 'raise');
      expect(line, '3-bet');
      expect(scenario, 'vs_raise');
    });

    test('limp and call', () {
      final limp = [_action(3, 'call', amount: 2, isHero: true)];
      expect(RangeGridService.derivePreflopLine(limp, 3).$2, 'Limped');
      expect(RangeGridService.derivePreflopLine(limp, 3).$3, 'rfi');

      final call = [
        _action(2, 'raise', amount: 6),
        _action(3, 'call', amount: 6, isHero: true),
      ];
      final (primary, line, scenario) =
          RangeGridService.derivePreflopLine(call, 3);
      expect(primary, 'call');
      expect(line, 'Called raise');
      expect(scenario, 'vs_raise');
    });

    test('folds, open and facing a raise', () {
      final openFold = [_action(3, 'fold', isHero: true)];
      expect(RangeGridService.derivePreflopLine(openFold, 3).$2, 'Folded');
      expect(RangeGridService.derivePreflopLine(openFold, 3).$3, 'rfi',
          reason: 'Open-fold belongs to the RFI chart');

      final foldToRaise = [
        _action(2, 'raise', amount: 6),
        _action(3, 'fold', isHero: true),
      ];
      final (primary, line, scenario) =
          RangeGridService.derivePreflopLine(foldToRaise, 3);
      expect(primary, 'fold');
      expect(line, 'Folded to raise');
      expect(scenario, 'vs_raise');
    });

    test('raised then folded to a re-raise', () {
      final actions = [
        _action(3, 'raise', amount: 6, isHero: true),
        _action(5, 'raise', amount: 20),
        _action(3, 'fold', isHero: true),
      ];
      final (primary, line, scenario) =
          RangeGridService.derivePreflopLine(actions, 3);
      expect(primary, 'raise',
          reason: 'Cell frequencies use the first voluntary action');
      expect(line, 'Open-raised → folded');
      expect(scenario, 'rfi',
          reason: 'The pot was unopened when hero first acted');
    });

    test('all-in over a raise is its own allin category', () {
      final actions = [
        _action(2, 'raise', amount: 6),
        _action(3, 'all-in', amount: 200, isHero: true),
      ];
      final (primary, line, scenario) =
          RangeGridService.derivePreflopLine(actions, 3);
      expect(primary, 'allin');
      expect(line, 'Shoved over a raise');
      expect(scenario, 'vs_raise');
    });

    test('open-shove in an unopened pot', () {
      final actions = [
        _action(2, 'fold'),
        _action(3, 'all-in', amount: 200, isHero: true),
      ];
      final (primary, line, scenario) =
          RangeGridService.derivePreflopLine(actions, 3);
      expect(primary, 'allin');
      expect(line, 'Open-shoved');
      expect(scenario, 'rfi');
    });

    test('all-in CALL stays call (HL-8), never allin', () {
      final actions = [
        _action(2, 'all-in', amount: 200),
        _action(3, 'call', amount: 150, stack: 150, isHero: true),
      ];
      final (primary, line, scenario) =
          RangeGridService.derivePreflopLine(actions, 3);
      expect(primary, 'call');
      expect(line, 'All-in call');
      expect(scenario, 'vs_raise');
    });

    test('walk: hero has no recorded actions', () {
      final (primary, line, scenario) =
          RangeGridService.derivePreflopLine([], 3);
      expect(primary, 'check');
      expect(line, 'No action (walk)');
      expect(scenario, 'rfi');
    });

    test('only preflop actions are considered', () {
      final actions = [
        _action(3, 'call', amount: 2, isHero: true),
        _action(3, 'bet', street: 'flop', amount: 10, isHero: true),
      ];
      expect(RangeGridService.derivePreflopLine(actions, 3).$2, 'Limped');
    });
  });

  group('heroStackBB', () {
    test('uses the hero\'s first recorded stack', () {
      final actions = [
        _action(2, 'raise', stack: 1000, amount: 6),
        _action(3, 'call', stack: 200, amount: 6, isHero: true),
        _action(3, 'bet', street: 'flop', stack: 150, amount: 20, isHero: true),
      ];
      expect(RangeGridService.heroStackBB(actions, 3, 2.0), 100.0);
    });

    test('prefers the preflop stack, falls back to any hero stack', () {
      // Older hands may only carry a stack on a postflop action — usable
      // as a fallback, but a preflop stack always wins.
      final onlyFlop = [
        _action(3, 'bet', street: 'flop', stack: 180, amount: 20, isHero: true),
      ];
      expect(RangeGridService.heroStackBB(onlyFlop, 3, 2.0), 90.0);

      final both = [
        _action(3, 'call', stack: 200, amount: 6, isHero: true),
        _action(3, 'bet', street: 'flop', stack: 180, amount: 20, isHero: true),
      ];
      expect(RangeGridService.heroStackBB(both, 3, 2.0), 100.0);
    });

    test('null when big blind or stack unknown', () {
      expect(RangeGridService.heroStackBB([], 3, 2.0), null);
      expect(
          RangeGridService.heroStackBB(
              [_action(3, 'call', isHero: true)], 3, 0.0),
          null);
    });
  });

  group('buildEntry', () {
    final actions = [
      _action(3, 'raise', stack: 200, amount: 6, isHero: true),
    ];

    test('builds a complete entry', () {
      final entry = RangeGridService.buildEntry(
        handKey: 's1:1',
        localHandId: 'h1',
        sessionId: 's1',
        userId: 'u1',
        timestamp: DateTime(2026, 6, 1),
        gameType: 'cash',
        holeCards: HoleCards(card1: 'A♠', card2: 'K♥'),
        heroPositionName: 'BTN',
        heroSeat: 3,
        actions: actions,
        bigBlind: 2.0,
        potAmount: 24.0,
        winnerId: 3,
        choppedWinners: null,
      );
      expect(entry, isNotNull);
      expect(entry!.handClass, 'AKo');
      expect(entry.position, 'BTN');
      expect(entry.posGroup, 'BTN');
      expect(entry.stackBB, 100.0);
      expect(entry.stackBucket, 'veryDeep');
      expect(entry.primaryAction, 'raise');
      expect(entry.scenario, 'rfi');
      expect(entry.preflopLine, 'Open-raised');
      expect(entry.potBB, 12.0);
      expect(entry.won, true);
    });

    test('won via chopped pot', () {
      final entry = RangeGridService.buildEntry(
        handKey: 's1:1',
        localHandId: 'h1',
        sessionId: 's1',
        userId: 'u1',
        timestamp: DateTime(2026, 6, 1),
        gameType: 'cash',
        holeCards: HoleCards(card1: 'A♠', card2: 'K♥'),
        heroPositionName: 'BB',
        heroSeat: 3,
        actions: actions,
        bigBlind: 2.0,
        potAmount: 24.0,
        winnerId: 5,
        choppedWinners: [3, 5],
      );
      expect(entry!.won, true);
    });

    test('null without hole cards, position or seat', () {
      RangeGridEntry? build({
        HoleCards? cards,
        String? position,
        int? seat,
      }) =>
          RangeGridService.buildEntry(
            handKey: 's1:1',
            sessionId: 's1',
            userId: 'u1',
            timestamp: DateTime(2026, 6, 1),
            gameType: 'cash',
            holeCards: cards,
            heroPositionName: position,
            heroSeat: seat,
            actions: actions,
            bigBlind: 2.0,
            potAmount: 24.0,
            winnerId: null,
            choppedWinners: null,
          );

      expect(build(position: 'BTN', seat: 3), null);
      expect(build(cards: HoleCards(card1: 'A♠', card2: 'K♥'), seat: 3), null);
      expect(
          build(cards: HoleCards(card1: 'A♠', card2: 'K♥'), position: 'BTN'),
          null);
    });
  });

  group('RangeCellAggregate', () {
    test('accumulates action counts', () {
      var agg = const RangeCellAggregate(handClass: 'AKs');
      agg = agg.addingAction('raise', 3);
      agg = agg.addingAction('call', 1);
      agg = agg.addingAction('fold', 2);
      expect(agg.raiseCount, 3);
      expect(agg.callCount, 1);
      expect(agg.foldCount, 2);
      expect(agg.total, 6);
    });
  });

  group('RangeGridEntry serialization', () {
    test('round-trips through the DB map', () {
      const entry = RangeGridEntry(
        handKey: 's1:7',
        localHandId: 'h-local',
        cloudHandId: 'h-cloud',
        sessionId: 's1',
        userId: 'u1',
        timestamp: 1234567890,
        gameType: 'tournament',
        handClass: 'QJs',
        position: 'CO',
        posGroup: 'CO',
        stackBB: 35.5,
        stackBucket: 'average',
        primaryAction: 'call',
        scenario: 'vs_raise',
        preflopLine: 'Called raise',
        potBB: 18.0,
        won: false,
      );
      final restored = RangeGridEntry.fromDbMap(entry.toDbMap());
      expect(restored.handKey, entry.handKey);
      expect(restored.localHandId, 'h-local');
      expect(restored.cloudHandId, 'h-cloud');
      expect(restored.timestamp, entry.timestamp);
      expect(restored.handClass, entry.handClass);
      expect(restored.stackBB, entry.stackBB);
      expect(restored.stackBucket, entry.stackBucket);
      expect(restored.primaryAction, entry.primaryAction);
      expect(restored.scenario, 'vs_raise');
      expect(restored.won, false);
    });
  });
}
