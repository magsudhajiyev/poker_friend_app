import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/hand_state_machine.dart';

/// latestHeroStack: pre-fills "This is me" re-seating with the hero's real
/// stack instead of the 100bb table default — including after the hero was
/// removed mid-hand (ourSeatNumber == null).
void main() {
  PokerSessionManager manager({int? seat}) => PokerSessionManager(
        smallBlind: 1,
        bigBlind: 2,
        playerCount: 9,
        ourSeatNumber: seat,
      );

  group('latestHeroStack', () {
    test('unseated hero falls back to the last stack-history entry', () {
      final m = manager(seat: null);
      m.stackHistory = [
        {'timestamp': 't1', 'stackSize': 200.0, 'changeType': 'initial'},
        {'timestamp': 't2', 'stackSize': 340.0, 'changeType': 'hand_completed'},
      ];
      expect(m.latestHeroStack(null), 340.0);
    });

    test('unseated hero with no history yields 0 (caller uses default)', () {
      final m = manager(seat: null);
      expect(m.latestHeroStack(null), 0.0);
    });

    test('seated hero without game state uses the tracked seat stack', () {
      final m = manager(seat: 4);
      m.playerStacks[4] = 512.0;
      m.stackHistory = [
        {'timestamp': 't1', 'stackSize': 999.0, 'changeType': 'initial'},
      ];
      // Live/tracked seat value wins over stale history.
      expect(m.latestHeroStack(null), 512.0);
    });

    test('seated hero with no tracked stack falls back to history', () {
      final m = manager(seat: 4);
      m.stackHistory = [
        {'timestamp': 't1', 'stackSize': 275.0, 'changeType': 'initial'},
      ];
      expect(m.latestHeroStack(null), 275.0);
    });

    test('int-typed stackSize (Firestore round-trip) is accepted', () {
      final m = manager(seat: null);
      m.stackHistory = [
        {'timestamp': 't1', 'stackSize': 300, 'changeType': 'initial'},
      ];
      expect(m.latestHeroStack(null), 300.0);
    });
  });
}
