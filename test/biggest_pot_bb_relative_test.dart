import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/game_types.dart';
import 'package:poker_logger/models/hand_state_machine.dart';

void main() {
  group('PokerSessionManager.updateBiggestPot', () {
    test(
        'REGRESSION: tournament compares pots in BB terms across blind levels',
        () {
      // Live bug 2026-08-04 ("Ferajna Monday", 9h MTT, finished 2nd): a
      // 43,000-chip pot at 3000/6000 (7 BB) displaced a 6,340-chip pot from
      // the 10/20 level (317 BB), so the summary card said "Biggest pot 7 BB".
      final m = PokerSessionManager(
        smallBlind: 10,
        bigBlind: 20,
        playerCount: 9,
        ourSeatNumber: 3,
        gameType: GameType.tournament,
      );

      m.updateBiggestPot(6340); // 317 BB at the 10/20 level
      expect(m.biggestPot, 6340);
      expect(m.biggestPotBB, 20);

      m.bigBlind = 6000; // blinds have escalated to 3000/6000
      m.updateBiggestPot(43000); // only ~7.2 BB — NOT a bigger pot
      expect(m.biggestPot, 6340, reason: '7BB pot must not displace 317BB pot');
      expect(m.biggestPotBB, 20);

      m.updateBiggestPot(2000000); // 333 BB at 6000 — genuinely bigger
      expect(m.biggestPot, 2000000);
      expect(m.biggestPotBB, 6000);
    });

    test('cash games keep absolute comparison', () {
      final m = PokerSessionManager(
        smallBlind: 2,
        bigBlind: 5,
        playerCount: 6,
        ourSeatNumber: 3,
        gameType: GameType.cash,
      );

      m.updateBiggestPot(120);
      m.updateBiggestPot(80);
      expect(m.biggestPot, 120);
      expect(m.biggestPotBB, 5);
      m.updateBiggestPot(385);
      expect(m.biggestPot, 385);
    });

    test('first pot always recorded; zero/negative pots ignored', () {
      final m = PokerSessionManager(
        smallBlind: 100,
        bigBlind: 200,
        playerCount: 9,
        gameType: GameType.tournament,
      );
      m.updateBiggestPot(0);
      expect(m.biggestPot, 0);
      m.updateBiggestPot(700);
      expect(m.biggestPot, 700);
      expect(m.biggestPotBB, 200);
    });
  });
}
