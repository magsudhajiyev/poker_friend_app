import 'package:flutter_test/flutter_test.dart';

/// B11: multi-pot hands previously persisted only the FIRST pot's winner, so
/// a side-pot winner vanished from the hand-details view. The award loop now
/// aggregates every pot's winner into a combined shares map. This pins that
/// aggregation logic (pure, mirrors poker_hand_screen's creditWinner loop)
/// and the winnerId back-compat ordering.

/// Mirror of the combined-shares accumulation + winnerId selection in
/// poker_hand_screen._distributeMultiPot.
({Map<int, double> shares, List<int> winnerIds}) aggregate(
    List<Map<String, dynamic>> pots) {
  final Map<int, double> combined = {};
  void credit(int id, double amt) =>
      combined[id] = (combined[id] ?? 0) + amt;
  for (final pot in pots) {
    if (pot['isChoppedPot'] == true) {
      final shares = Map<int, double>.from(pot['individualShares']);
      shares.forEach(credit);
    } else {
      credit(pot['winner'] as int, pot['potAmount'] as double);
    }
  }
  final winnerIds = combined.keys.toList()
    ..sort((a, b) => combined[b]!.compareTo(combined[a]!));
  return (shares: combined, winnerIds: winnerIds);
}

void main() {
  group('multi-pot winner aggregation (B11)', () {
    test('main pot and side pot with DIFFERENT winners keeps both', () {
      // Main pot 300 → player 2, side pot 100 → player 3.
      final r = aggregate([
        {'winner': 2, 'potAmount': 300.0},
        {'winner': 3, 'potAmount': 100.0},
      ]);
      expect(r.shares, {2: 300.0, 3: 100.0});
      // Two distinct winners → saved as split pot, both preserved.
      expect(r.winnerIds.length, 2);
      // winnerId (first) = largest-pot winner, for stats back-compat.
      expect(r.winnerIds.first, 2);
    });

    test('same player wins both pots collapses to one winner', () {
      final r = aggregate([
        {'winner': 1, 'potAmount': 500.0},
        {'winner': 1, 'potAmount': 200.0},
      ]);
      expect(r.shares, {1: 700.0});
      expect(r.winnerIds, [1]);
    });

    test('chopped main pot plus distinct side-pot winner', () {
      // Main pot 200 chopped between 1 & 2 (100 each); side pot 150 → player 3.
      final r = aggregate([
        {'isChoppedPot': true, 'individualShares': {1: 100.0, 2: 100.0}},
        {'winner': 3, 'potAmount': 150.0},
      ]);
      expect(r.shares, {1: 100.0, 2: 100.0, 3: 150.0});
      expect(r.winnerIds.toSet(), {1, 2, 3});
      // Largest single share (player 3) leads for winnerId back-compat.
      expect(r.winnerIds.first, 3);
    });

    test('total distributed equals sum of pots (chip conservation)', () {
      final r = aggregate([
        {'winner': 2, 'potAmount': 300.0},
        {'winner': 3, 'potAmount': 100.0},
        {'isChoppedPot': true, 'individualShares': {2: 25.0, 4: 25.0}},
      ]);
      final total = r.shares.values.fold<double>(0, (a, b) => a + b);
      expect(total, 450.0);
      // Player 2 won main pot 300 + half of the 50 chop = 325.
      expect(r.shares[2], 325.0);
    });
  });
}
