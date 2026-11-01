import 'package:flutter_test/flutter_test.dart';

import '../../lib/services/board_texture.dart';
import '../../lib/services/leak_engine.dart';
import '../../lib/services/leak_extractor.dart';
import '../fixtures/mock_hand_actions.dart';

Map<String, dynamic> _hand({
  required List<Map<String, dynamic>> actions,
  int heroSeat = 3,
  bool flopDealt = true,
  bool reachedShowdown = false,
  int? winnerId,
  bool isScouted = false,
}) {
  return {
    'heroSeatNumber': heroSeat,
    'actions': actions,
    'boardCards': {
      'flop': flopDealt ? ['A♠', 'K♥', '7♦'] : <String>[],
    },
    'reachedShowdown': reachedShowdown,
    if (winnerId != null) 'winnerId': winnerId,
    if (isScouted) 'isScouted': true,
  };
}

void main() {
  group('LeakExtractor', () {
    test('scouted hands and missing hero are skipped', () {
      expect(
          LeakExtractor.extract(
              _hand(actions: [MockHandActions.fold(3)], isScouted: true)),
          isNull);
      expect(LeakExtractor.extract({'actions': []}), isNull);
    });

    test('river facing response: fold detected', () {
      final facts = LeakExtractor.extract(_hand(actions: [
        MockHandActions.smallBlind(1, 1),
        MockHandActions.bigBlind(2, 2),
        MockHandActions.call(3, 2),
        MockHandActions.check(2),
        MockHandActions.check(2, street: 'flop'),
        MockHandActions.check(3, street: 'flop'),
        MockHandActions.check(2, street: 'turn'),
        MockHandActions.check(3, street: 'turn'),
        MockHandActions.bet(2, 10, street: 'river'),
        MockHandActions.fold(3, street: 'river'),
      ]))!;
      expect(facts.riverFacingResponse, 'fold');
      expect(facts.flopFacingResponse, isNull);
      expect(facts.turnFacingResponse, isNull);
    });

    test('facing response ignores hero acting first (no bet outstanding)',
        () {
      final facts = LeakExtractor.extract(_hand(actions: [
        MockHandActions.smallBlind(1, 1),
        MockHandActions.bigBlind(2, 2),
        MockHandActions.call(3, 2),
        MockHandActions.check(2),
        MockHandActions.bet(3, 5, street: 'flop'),
        MockHandActions.fold(2, street: 'flop'),
      ]))!;
      expect(facts.flopFacingResponse, isNull);
    });

    test('open detection: hero first voluntary raise', () {
      final facts = LeakExtractor.extract(_hand(actions: [
        MockHandActions.smallBlind(1, 1),
        MockHandActions.bigBlind(2, 2),
        MockHandActions.raise(3, 6),
        MockHandActions.fold(1),
        MockHandActions.fold(2),
      ], flopDealt: false))!;
      expect(facts.openedPot, true);
      expect(facts.facedThreeBetAfterOpen, false);
    });

    test('fold to 3-bet after open', () {
      final facts = LeakExtractor.extract(_hand(actions: [
        MockHandActions.smallBlind(1, 1),
        MockHandActions.bigBlind(2, 2),
        MockHandActions.raise(3, 6),
        MockHandActions.raise(4, 18),
        MockHandActions.fold(1),
        MockHandActions.fold(2),
        MockHandActions.fold(3),
      ], flopDealt: false))!;
      expect(facts.openedPot, true);
      expect(facts.facedThreeBetAfterOpen, true);
      expect(facts.foldedToThreeBet, true);
    });

    test('limp then fold to raise', () {
      final facts = LeakExtractor.extract(_hand(actions: [
        MockHandActions.smallBlind(1, 1),
        MockHandActions.bigBlind(2, 2),
        MockHandActions.call(3, 2), // hero limps
        MockHandActions.raise(4, 10),
        MockHandActions.fold(1),
        MockHandActions.fold(2),
        MockHandActions.fold(3), // limp-fold
      ], flopDealt: false))!;
      expect(facts.limped, true);
      expect(facts.limpFacedRaise, true);
      expect(facts.limpFolded, true);
    });

    test('BB vs steal: fold to BTN open detected', () {
      final facts = LeakExtractor.extract(_hand(actions: [
        MockHandActions.smallBlind(1, 1),
        MockHandActions.bigBlind(3, 2), // hero is BB
        MockHandActions.action(
            player: 5,
            actionType: 'raise',
            amount: 5,
            playerPosition: 'BTN'),
        MockHandActions.fold(1),
        MockHandActions.fold(3), // hero folds BB vs steal
      ], flopDealt: false))!;
      expect(facts.bbFacedSteal, true);
      expect(facts.bbFoldedToSteal, true);
    });

    test('BB vs steal: UTG open is not a steal spot', () {
      final facts = LeakExtractor.extract(_hand(actions: [
        MockHandActions.smallBlind(1, 1),
        MockHandActions.bigBlind(3, 2),
        MockHandActions.action(
            player: 6,
            actionType: 'raise',
            amount: 5,
            playerPosition: 'UTG'),
        MockHandActions.fold(1),
        MockHandActions.fold(3),
      ], flopDealt: false))!;
      expect(facts.bbFacedSteal, false);
    });

    test('showdown facts: hero wins at showdown', () {
      final facts = LeakExtractor.extract(_hand(
        actions: [
          MockHandActions.smallBlind(1, 1),
          MockHandActions.bigBlind(2, 2),
          MockHandActions.call(3, 2),
          MockHandActions.check(2),
          MockHandActions.bet(2, 4, street: 'flop'),
          MockHandActions.call(3, 4, street: 'flop'),
        ],
        reachedShowdown: true,
        winnerId: 3,
      ))!;
      expect(facts.sawFlop, true);
      expect(facts.wentToShowdown, true);
      expect(facts.wonAtShowdown, true);
    });

    test('walk hands flagged', () {
      final facts = LeakExtractor.extract(_hand(actions: [
        MockHandActions.smallBlind(1, 1),
        MockHandActions.bigBlind(3, 2),
        MockHandActions.fold(1),
        MockHandActions.fold(2),
      ], flopDealt: false))!;
      expect(facts.isWalk, true);
    });
  });

  group('LeakEngine', () {
    LeakHandFacts riverFacts(String response) => LeakHandFacts(
          isWalk: false,
          openedPot: false,
          facedThreeBetAfterOpen: false,
          foldedToThreeBet: false,
          limped: false,
          limpFacedRaise: false,
          limpFolded: false,
          bbFacedSteal: false,
          bbFoldedToSteal: false,
          flopFacingResponse: null,
          turnFacingResponse: null,
          riverFacingResponse: response,
          sawFlop: true,
          wentToShowdown: false,
          wonAtShowdown: false,
          wonWithoutShowdown: false,
        );

    test('fix text never mentions drills; drill pointer is separate', () {
      LeakHandFacts f({bool fold3 = false, bool bb = false, bool limp = false}) =>
          LeakHandFacts(
            isWalk: false,
            openedPot: fold3,
            facedThreeBetAfterOpen: fold3,
            foldedToThreeBet: fold3,
            limped: limp,
            limpFacedRaise: false,
            limpFolded: false,
            bbFacedSteal: bb,
            bbFoldedToSteal: bb,
            flopFacingResponse: null,
            turnFacingResponse: null,
            riverFacingResponse: null,
            sawFlop: false,
            wentToShowdown: false,
            wonAtShowdown: false,
            wonWithoutShowdown: false,
          );
      final report = LeakEngine.analyze([
        ...List.generate(60, (_) => f(fold3: true)),
        ...List.generate(60, (_) => f(bb: true)),
        ...List.generate(120, (_) => f(limp: true)),
      ]);
      final withFix = report.findings.where((x) => x.fix.isNotEmpty);
      expect(withFix, isNotEmpty);
      for (final x in withFix) {
        expect(x.fix.toLowerCase(), isNot(contains('drill')), reason: x.id);
      }
      expect(report.findings.any((x) => x.practiceHint.contains('Drill')),
          isTrue);
    });

    test('insufficient data below minimum sample', () {
      final report = LeakEngine.analyze(List.generate(5, (_) => riverFacts('fold')));
      final river =
          report.findings.firstWhere((f) => f.id == 'river_overfold');
      expect(river.verdict, LeakVerdict.insufficientData);
    });

    test('river overfold: emerging at minSample, confirmed at larger n', () {
      // 12 river spots, 10 folds = 83% > 62% band top.
      final emerging = LeakEngine.analyze([
        ...List.generate(10, (_) => riverFacts('fold')),
        ...List.generate(2, (_) => riverFacts('call')),
      ]).findings.firstWhere((f) => f.id == 'river_overfold');
      expect(emerging.verdict, LeakVerdict.emerging);
      expect(emerging.aboveBand, true);

      final confirmed = LeakEngine.analyze([
        ...List.generate(25, (_) => riverFacts('fold')),
        ...List.generate(5, (_) => riverFacts('call')),
      ]).findings.firstWhere((f) => f.id == 'river_overfold');
      expect(confirmed.verdict, LeakVerdict.confirmed);
    });

    test('healthy inside the band', () {
      final report = LeakEngine.analyze([
        ...List.generate(6, (_) => riverFacts('fold')),
        ...List.generate(6, (_) => riverFacts('call')),
      ]);
      final river =
          report.findings.firstWhere((f) => f.id == 'river_overfold');
      expect(river.verdict, LeakVerdict.healthy);
    });

    test('walks excluded from hands analyzed', () {
      final walk = LeakHandFacts(
        isWalk: true,
        openedPot: false,
        facedThreeBetAfterOpen: false,
        foldedToThreeBet: false,
        limped: false,
        limpFacedRaise: false,
        limpFolded: false,
        bbFacedSteal: false,
        bbFoldedToSteal: false,
        flopFacingResponse: null,
        turnFacingResponse: null,
        riverFacingResponse: null,
        sawFlop: false,
        wentToShowdown: false,
        wonAtShowdown: false,
        wonWithoutShowdown: false,
      );
      final report = LeakEngine.analyze([walk, riverFacts('call')]);
      expect(report.handsAnalyzed, 1);
    });

    test('leaks ranked by severity', () {
      final report = LeakEngine.analyze([
        // 20 river folds of 20 -> way above band
        ...List.generate(20, (_) => riverFacts('fold')),
      ]);
      expect(report.leaks.isNotEmpty, true);
      expect(report.leaks.first.id, 'river_overfold');
      expect(report.leaks.first.severity, greaterThan(0.5));
    });
  });

  group('BoardTextureClassifier', () {
    test('paired board', () {
      expect(BoardTextureClassifier.classifyFlop(['2\u2663', '9\u2666', '9\u2660']),
          BoardTexture.paired);
    });
    test('monotone board', () {
      expect(BoardTextureClassifier.classifyFlop(['A\u2660', 'K\u2660', '7\u2660']),
          BoardTexture.monotone);
    });
    test('two-tone connected is wet', () {
      expect(BoardTextureClassifier.classifyFlop(['5\u2663', 'T\u2663', '8\u2666']),
          BoardTexture.wet);
    });
    test('rainbow disconnected is dry', () {
      expect(BoardTextureClassifier.classifyFlop(['J\u2666', '7\u2663', '3\u2665']),
          BoardTexture.dry);
    });
    test('rainbow but connected is wet', () {
      expect(BoardTextureClassifier.classifyFlop(['9\u2666', '8\u2663', '6\u2665']),
          BoardTexture.wet);
    });
    test('wheel-connected ace board is wet', () {
      expect(BoardTextureClassifier.classifyFlop(['A\u2666', '2\u2663', '4\u2665']),
          BoardTexture.wet);
    });
    test('unparsable returns null', () {
      expect(BoardTextureClassifier.classifyFlop(null), isNull);
      expect(BoardTextureClassifier.classifyFlop(['A\u2660']), isNull);
      expect(BoardTextureClassifier.classifyFlop(['X\u2660', 'K\u2660', '7\u2660']), isNull);
    });
  });

  group('LeakExtractor money reconstruction (netBB)', () {
    Map<String, dynamic> moneyHand(List<Map<String, dynamic>> actions,
        {double pot = 0, int? winnerId, double bigBlind = 2}) {
      return {
        'heroSeatNumber': 3,
        'actions': actions,
        'bigBlind': bigBlind,
        'potAmount': pot,
        if (winnerId != null) 'winnerId': winnerId,
        'boardCards': {'flop': ['A\u2660', 'K\u2665', '7\u2666']},
        'reachedShowdown': false,
      };
    }

    test('open, c-bet, win: preflop total + postflop bet semantics', () {
      // Hero raises TO 6 preflop (total), bets 8 on flop -> invested 14.
      final f = LeakExtractor.extract(moneyHand([
        MockHandActions.smallBlind(1, 1),
        MockHandActions.bigBlind(2, 2),
        MockHandActions.raise(3, 6),
        MockHandActions.call(2, 4),
        MockHandActions.check(2, street: 'flop'),
        MockHandActions.bet(3, 8, street: 'flop'),
        MockHandActions.fold(2, street: 'flop'),
      ], pot: 21, winnerId: 3))!;
      // net = (21 - 14) / 2bb = 3.5
      expect(f.netBB, closeTo(3.5, 0.001));
    });

    test('postflop raise is ADDITIONAL on top of current bet', () {
      // Villain bets 10, hero raises 20 on top -> hero street total 30.
      final f = LeakExtractor.extract(moneyHand([
        MockHandActions.smallBlind(1, 1),
        MockHandActions.bigBlind(3, 2), // hero posts BB (2)
        MockHandActions.call(5, 2),
        MockHandActions.check(3),
        MockHandActions.bet(5, 10, street: 'flop'),
        MockHandActions.raise(3, 20, street: 'flop'),
        MockHandActions.fold(5, street: 'flop'),
      ], pot: 45, winnerId: 3))!;
      // invested = 2 (BB) + 30 (flop) = 32; net = (45-32)/2 = 6.5
      expect(f.netBB, closeTo(6.5, 0.001));
    });

    test('losing hand: invested is negative net', () {
      final f = LeakExtractor.extract(moneyHand([
        MockHandActions.smallBlind(1, 1),
        MockHandActions.bigBlind(2, 2),
        MockHandActions.call(3, 2),
        MockHandActions.raise(5, 10),
        MockHandActions.fold(1),
        MockHandActions.fold(2),
        MockHandActions.fold(3), // limp-fold: invested 2
      ], pot: 15, winnerId: 5))!;
      expect(f.netBB, closeTo(-1.0, 0.001));
    });

    test('chopped pot uses hero share', () {
      final hand = moneyHand([
        MockHandActions.smallBlind(1, 1),
        MockHandActions.bigBlind(2, 2),
        MockHandActions.call(3, 2),
        MockHandActions.check(2),
      ], pot: 20);
      hand['isChoppedPot'] = true;
      hand['choppedWinners'] = [2, 3];
      hand['sharePerWinner'] = 10.0;
      final f = LeakExtractor.extract(hand)!;
      // invested 2, share 10 -> net (10-2)/2 = 4
      expect(f.netBB, closeTo(4.0, 0.001));
    });

    test('stackBB from first hero action, opener position captured', () {
      final f = LeakExtractor.extract(moneyHand([
        MockHandActions.smallBlind(1, 1),
        MockHandActions.bigBlind(2, 2),
        MockHandActions.action(
            player: 5, actionType: 'raise', amount: 6,
            playerPosition: 'CO'),
        MockHandActions.action(
            player: 3, actionType: 'call', amount: 6,
            playerPosition: 'BTN'),
        MockHandActions.fold(1),
        MockHandActions.fold(2),
      ], pot: 15, winnerId: 5)
        ..['actions'][3]['playerStack'] = 80.0)!;
      expect(f.stackBB, closeTo(40.0, 0.001));
      expect(f.openerPosGroup, 'CO');
      expect(f.heroVpip, true);
    });
  });
}
