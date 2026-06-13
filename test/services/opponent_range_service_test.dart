import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/observed_range.dart';
import 'package:poker_logger/services/opponent_range_service.dart';

/// Builds a stored-hand map with one shown opponent seat.
Map<String, dynamic> handWith({
  required int seat,
  required String name,
  required String position,
  required String action, // preflop action type for that seat
  required String card1,
  required String card2,
  double bigBlind = 2,
  double stack = 200,
  int? winnerId,
  List<Map<String, dynamic>> extraActions = const [],
}) {
  return {
    'handNumber': 1,
    'bigBlind': bigBlind,
    'gameType': 'cash',
    'winnerId': winnerId,
    'startTime': '2026-01-01T00:00:00.000',
    'playerNames': {'$seat': name},
    'actions': [
      ...extraActions,
      {
        'player': seat,
        'action': action,
        'street': 'preflop',
        'playerPosition': position,
        'playerStack': stack,
      },
    ],
    'showdownData': {
      'playerCards': {
        '$seat': {'card1': card1, 'card2': card2},
      },
    },
  };
}

ObservedCombo combo(String handClass, {String action = 'raise'}) => ObservedCombo(
      opponentId: 'opp1',
      handClass: handClass,
      positionGroup: 'CO',
      primaryAction: action,
      actionLabel: 'Open-raised',
      scenario: 'rfi',
      stackBB: 100,
      stackBucket: null,
      gameType: 'cash',
      won: false,
      timestamp: 0,
      dedupeKey: 'opp1:s:1:3:$handClass',
    );

void main() {
  group('OpponentRangeService.combosFromHand', () {
    test('extracts an attributed combo for a shown saved opponent', () {
      final hand = handWith(
        seat: 3,
        name: 'Tony',
        position: 'CO',
        action: 'raise',
        card1: 'A♠',
        card2: 'K♠',
        winnerId: 3,
      );
      final combos = OpponentRangeService.combosFromHand(
        hand: hand,
        sessionId: 's1',
        nameToId: {'Tony': 'opp_tony'},
      );
      expect(combos.length, 1);
      final c = combos.first;
      expect(c.opponentId, 'opp_tony');
      expect(c.handClass, 'AKs');
      expect(c.positionGroup, 'CO');
      expect(c.primaryAction, 'raise');
      expect(c.actionLabel, 'Open-raised');
      expect(c.scenario, 'rfi');
      expect(c.stackBB, 100);
      expect(c.won, isTrue);
    });

    test('a raise facing an open is tagged as the vs_raise spot', () {
      final hand = handWith(
        seat: 5,
        name: 'Anna',
        position: 'BTN',
        action: 'raise',
        card1: 'Q♥',
        card2: 'Q♦',
        extraActions: [
          {
            'player': 2,
            'action': 'raise', // an open before Anna's re-raise
            'street': 'preflop',
            'playerPosition': 'UTG',
          },
        ],
      );
      final combos = OpponentRangeService.combosFromHand(
        hand: hand,
        sessionId: 's1',
        nameToId: {'Anna': 'opp_anna'},
      );
      expect(combos.single.handClass, 'QQ');
      expect(combos.single.primaryAction, 'raise');
      expect(combos.single.scenario, 'vs_raise');
    });

    test('skips seats not mapped to a saved opponent', () {
      final hand = handWith(
        seat: 3,
        name: 'Stranger',
        position: 'CO',
        action: 'raise',
        card1: 'A♠',
        card2: 'K♠',
      );
      final combos = OpponentRangeService.combosFromHand(
        hand: hand,
        sessionId: 's1',
        nameToId: {'Tony': 'opp_tony'},
      );
      expect(combos, isEmpty);
    });

    test('returns nothing when the hand has no showdown cards', () {
      final hand = handWith(
        seat: 3,
        name: 'Tony',
        position: 'CO',
        action: 'raise',
        card1: 'A♠',
        card2: 'K♠',
      )..remove('showdownData');
      final combos = OpponentRangeService.combosFromHand(
        hand: hand,
        sessionId: 's1',
        nameToId: {'Tony': 'opp_tony'},
      );
      expect(combos, isEmpty);
    });
  });

  group('OpponentRangeService.classify', () {
    test('too few showdowns reads as insufficient but still counts', () {
      final r = OpponentRangeService.classify('opp1', 'Tony', [
        combo('AA'),
        combo('KK'),
        combo('72o'),
      ]);
      expect(r.total, 3);
      expect(r.shape, ObservedShape.insufficient);
      expect(r.isReliable, isFalse);
    });

    test('all premiums read as value-heavy', () {
      final r = OpponentRangeService.classify('opp1', 'Tony', [
        combo('AA'),
        combo('KK'),
        combo('QQ'),
        combo('AKs'),
        combo('AKo'),
        combo('JJ'),
      ]);
      expect(r.shape, ObservedShape.valueHeavy);
      expect(r.premiumCount, greaterThan(0));
      expect(r.isReliable, isTrue);
    });

    test('a heavy share of trash reads as wide', () {
      final r = OpponentRangeService.classify('opp1', 'Tony', [
        combo('AA'),
        combo('72o'),
        combo('J4o'),
        combo('T6o'),
        combo('95o'),
        combo('Q3o'),
      ]);
      expect(r.shape, ObservedShape.wide);
      expect(r.wideCount, greaterThanOrEqualTo(3));
    });

    test('spot filter narrows the combos', () {
      final combos = [
        combo('AA'),
        ObservedCombo(
          opponentId: 'opp1',
          handClass: '76s',
          positionGroup: 'BB',
          primaryAction: 'call',
          actionLabel: 'Called raise',
          scenario: 'vs_raise',
          stackBB: 100,
          stackBucket: null,
          gameType: 'cash',
          won: false,
          timestamp: 0,
          dedupeKey: 'opp1:s:2:3:76s',
        ),
      ];
      final co = OpponentRangeService.classify('opp1', 'Tony', combos,
          posGroup: 'CO');
      expect(co.total, 1);
      expect(co.combos.single.handClass, 'AA');
    });
  });
}
