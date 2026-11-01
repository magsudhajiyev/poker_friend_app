import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/poker_game_state.dart';
import 'package:poker_logger/models/hand_completeness.dart';
import 'package:poker_logger/models/hand_state_machine.dart';

HandRecord _hand() => HandRecord(
      handNumber: 7,
      buttonPosition: 2,
      playerCount: 6,
      startTime: DateTime.utc(2026, 10, 31, 20),
      actions: [
        ActionRecord(
          player: 3,
          action: PlayerAction.fold,
          street: BettingRound.preflop,
          timestamp: DateTime.utc(2026, 10, 31, 20, 1),
          buttonPosition: 2,
        ),
      ],
      heroSeatNumber: 3,
      heroPositionName: 'CO',
    );

void main() {
  group('parse / wire', () {
    test('null, unknown and empty map to full', () {
      expect(HandCompletenessX.parse(null), HandCompleteness.full);
      expect(HandCompletenessX.parse(''), HandCompleteness.full);
      expect(HandCompletenessX.parse('weird'), HandCompleteness.full);
      expect(HandCompletenessX.parse(42), HandCompleteness.full);
    });

    test('wire round trip for every level', () {
      for (final c in HandCompleteness.values) {
        expect(HandCompletenessX.parse(c.wire), c);
      }
      expect(HandCompleteness.foldTick.wire, 'fold_tick');
    });

    test('fromHandMap handles null map and legacy docs', () {
      expect(HandCompletenessX.fromHandMap(null), HandCompleteness.full);
      expect(HandCompletenessX.fromHandMap({'handNumber': 1}),
          HandCompleteness.full);
      expect(HandCompletenessX.fromHandMap({'completeness': 'flagged'}),
          HandCompleteness.flagged);
    });
  });

  group('gating matrix (section 2.2)', () {
    const expected = {
      // level: [isStub, heroTotals, opponents, history, analyzable]
      HandCompleteness.foldTick: [false, true, false, false, false],
      HandCompleteness.preflop: [false, true, true, false, false],
      HandCompleteness.flagged: [true, false, false, false, false],
      HandCompleteness.reconstructed: [false, true, false, true, false],
      HandCompleteness.full: [false, true, true, true, true],
    };
    for (final e in expected.entries) {
      test(e.key.wire, () {
        final c = e.key;
        expect(c.isStub, e.value[0], reason: 'isStub');
        expect(c.countsForHeroTotals, e.value[1], reason: 'heroTotals');
        expect(c.countsForOpponentStats, e.value[2], reason: 'opponents');
        expect(c.showsInHandHistory, e.value[3], reason: 'history');
        expect(c.isAnalyzable, e.value[4], reason: 'analyzable');
      });
    }

    test('reconstructed opponent feed follows the const', () {
      expect(HandCompleteness.reconstructed.countsForOpponentStats,
          kReconstructedFeedsOpponents);
    });
  });

  group('HandRecord serialisation', () {
    test('full hand adds NO new keys (flag-off parity)', () {
      final m = _hand().toMap();
      expect(m.containsKey('completeness'), isFalse);
      expect(m.containsKey('flag'), isFalse);
      expect(m.containsKey('statsApplied'), isFalse);
      expect((m['actions'] as List).first.containsKey('synthetic'), isFalse);
    });

    test('legacy map without the field parses as full / applied', () {
      final back = HandRecord.fromMap(_hand().toMap());
      expect(back.completeness, HandCompleteness.full);
      expect(back.statsApplied, isTrue);
      expect(back.flagMeta, isNull);
    });

    for (final c in HandCompleteness.values.where((c) => c != HandCompleteness.full)) {
      test('round trip ${c.wire}', () {
        final h = _hand()
          ..completeness = c
          ..statsApplied = !c.isStub
          ..flagMeta = c.isStub
              ? {'tags': ['cooler'], 'source': 'flag', 'bigBlind': 2.0}
              : null;
        final m = h.toMap();
        expect(m['completeness'], c.wire);
        expect(m.containsKey('statsApplied'), c.isStub);
        final back = HandRecord.fromMap(m);
        expect(back.completeness, c);
        expect(back.statsApplied, !c.isStub);
        expect(back.flagMeta, h.flagMeta);
      });
    }

    test('synthetic action flag survives a round trip', () {
      final a = ActionRecord(
        player: 1,
        action: PlayerAction.fold,
        street: BettingRound.preflop,
        timestamp: DateTime.utc(2026),
        buttonPosition: 1,
        synthetic: true,
      );
      expect(ActionRecord.fromMap(a.toMap()).synthetic, isTrue);
    });
  });
}
