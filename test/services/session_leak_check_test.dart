import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/leak_engine.dart';
import 'package:poker_logger/services/leak_snapshot_store.dart';
import 'package:poker_logger/services/session_leak_check.dart';

import '../fixtures/mock_hand_actions.dart';

/// Session-end leak chip evaluator: one factual line per session, compared
/// against the player's stored "usual" — never a session-sized verdict.
void main() {
  /// A hand where the hero (seat 3) faces a river bet and folds or calls.
  Map<String, dynamic> riverSpot({required bool fold}) => {
        'heroSeatNumber': 3,
        'actions': [
          MockHandActions.smallBlind(1, 1),
          MockHandActions.bigBlind(2, 2),
          MockHandActions.call(3, 2),
          MockHandActions.check(2),
          MockHandActions.check(2, street: 'flop'),
          MockHandActions.check(3, street: 'flop'),
          MockHandActions.check(2, street: 'turn'),
          MockHandActions.check(3, street: 'turn'),
          MockHandActions.bet(2, 10, street: 'river'),
          fold
              ? MockHandActions.fold(3, street: 'river')
              : MockHandActions.call(3, 10, street: 'river'),
        ],
        'boardCards': {
          'flop': ['A♠', 'K♥', '7♦']
        },
        'reachedShowdown': !fold,
      };

  List<Map<String, dynamic>> session({required int folds, required int calls}) =>
      [
        for (var i = 0; i < folds; i++) riverSpot(fold: true),
        for (var i = 0; i < calls; i++) riverSpot(fold: false),
      ];

  LeakSnapshot snapshot(Map<String, LeakSnapshotEntry> entries) =>
      LeakSnapshot(
          takenAt: DateTime(2026, 10, 1), handsAnalyzed: 200, entries: entries);

  LeakSnapshotEntry entry(
    String id, {
    double value = 0.45,
    LeakVerdict verdict = LeakVerdict.healthy,
    int n = 40,
  }) =>
      LeakSnapshotEntry(
        id: id,
        title: id,
        value: value,
        sampleCount: n,
        verdict: verdict,
        bandLow: 0.30,
        bandHigh: 0.62,
      );

  group('SessionLeakCheck.evaluate — highlights', () {
    test('session above the stored usual → aboveUsual with exact tallies',
        () {
      final chip = SessionLeakCheck.evaluate(
        hands: session(folds: 5, calls: 1),
        snapshot: snapshot({'river_overfold': entry('river_overfold')}),
      )!;
      expect(chip.findingId, 'river_overfold');
      expect(chip.kind, SessionLeakChipKind.aboveUsual);
      expect(chip.spots, 6);
      expect(chip.hits, 5);
      expect(chip.sessionRate, closeTo(5 / 6, 0.001));
      expect(chip.usualRate, 0.45);
    });

    test('session below usual → belowUsual; near usual → nearUsual', () {
      final below = SessionLeakCheck.evaluate(
        hands: session(folds: 1, calls: 5),
        snapshot: snapshot({'river_overfold': entry('river_overfold')}),
      )!;
      expect(below.kind, SessionLeakChipKind.belowUsual);

      final near = SessionLeakCheck.evaluate(
        hands: session(folds: 2, calls: 2),
        snapshot: snapshot(
            {'river_overfold': entry('river_overfold', value: 0.50)}),
      )!;
      expect(near.kind, SessionLeakChipKind.nearUsual);
    });

    test('detector flagged as current leak is marked as such', () {
      final chip = SessionLeakCheck.evaluate(
        hands: session(folds: 5, calls: 1),
        snapshot: snapshot({
          'river_overfold': entry('river_overfold',
              value: 0.70, verdict: LeakVerdict.confirmed),
        }),
      )!;
      expect(chip.relatesToCurrentLeak, isTrue);
    });

    test('no snapshot → factOnly intro line, still exact counting', () {
      final chip = SessionLeakCheck.evaluate(
        hands: session(folds: 4, calls: 2),
        snapshot: null,
      )!;
      expect(chip.kind, SessionLeakChipKind.factOnly);
      expect(chip.usualRate, isNull);
      expect(chip.spots, 6);
      expect(chip.hits, 4);
    });
  });

  group('SessionLeakCheck.evaluate — unlock progress', () {
    test('too few spots for a highlight → progress toward locked detector',
        () {
      // 2 river spots (< minSpots) against a snapshot where the detector
      // is still locked at 6/12.
      final chip = SessionLeakCheck.evaluate(
        hands: session(folds: 1, calls: 1),
        snapshot: snapshot({
          'river_overfold': entry('river_overfold',
              verdict: LeakVerdict.insufficientData, n: 6),
        }),
      )!;
      expect(chip.kind, SessionLeakChipKind.unlockProgress);
      expect(chip.spots, 2);
      expect(chip.remainingToUnlock, 4); // 12 − (6 + 2)
    });

    test('session pushes a detector past minSample → unlockReady', () {
      final chip = SessionLeakCheck.evaluate(
        hands: session(folds: 1, calls: 1),
        snapshot: snapshot({
          'river_overfold': entry('river_overfold',
              verdict: LeakVerdict.insufficientData, n: 11),
        }),
      )!;
      expect(chip.kind, SessionLeakChipKind.unlockReady);
      expect(chip.remainingToUnlock, 0);
    });
  });

  group('SessionLeakCheck.evaluate — focus preference', () {
    test('the focused detector outranks a bigger deviation elsewhere', () {
      // river_overfold deviates hugely from usual, but the player's
      // focus is wtsd — the chip must report the focus.
      final chip = SessionLeakCheck.evaluate(
        hands: session(folds: 5, calls: 1),
        snapshot: snapshot({
          'river_overfold': entry('river_overfold', value: 0.10),
          'wtsd': entry('wtsd', value: 0.30, verdict: LeakVerdict.emerging),
        }),
        focusFindingId: 'wtsd',
      )!;
      expect(chip.findingId, 'wtsd');
    });
  });

  group('SessionLeakCheck.evaluate — short-session floor', () {
    test('empty session → null (truly nothing happened)', () {
      expect(
          SessionLeakCheck.evaluate(hands: const [], snapshot: null), isNull);
    });

    test('scouted-only session → null (nothing extractable)', () {
      final hands = session(folds: 5, calls: 1)
          .map((h) => {...h, 'isScouted': true})
          .toList();
      expect(SessionLeakCheck.evaluate(hands: hands, snapshot: null), isNull);
    });

    test(
        'short session below every threshold → sessionBanked floor, '
        'never silence (the "2 hands, no chip" bug)', () {
      final chip = SessionLeakCheck.evaluate(
        hands: session(folds: 1, calls: 0),
        snapshot: null,
      )!;
      expect(chip.kind, SessionLeakChipKind.sessionBanked);
      expect(chip.handsAnalyzed, 1);
      expect(chip.spots, greaterThan(0),
          reason: 'the river fold is at least one banked spot');
    });
  });
}
