import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/hand_state_machine.dart';
import 'package:poker_logger/models/poker_game_state.dart';
import 'package:poker_logger/services/stats_calculator.dart';

/// HL-5 — recording cards an opponent SHOWED after the hand (settling
/// overlay press-and-hold). Persistence uses the captured storage ids; the
/// in-memory contract is tested here via the `persist: false` seam.
void main() {
  PokerSessionManager manager() => PokerSessionManager(
        smallBlind: 1,
        bigBlind: 2,
        playerCount: 6,
        ourSeatNumber: 5,
      );

  HandRecord finishedHand({int number = 1}) {
    final h = HandRecord(
      handNumber: number,
      buttonPosition: 1,
      playerCount: 6,
      startTime: DateTime(2026, 7, 22, 20),
    );
    h.markCompleted();
    return h;
  }

  group('attachShownCards', () {
    test('stores full shown cards on the last finished hand', () async {
      final m = manager();
      m.lastFinishedHand = finishedHand();

      await m.attachShownCards(
          seat: 3,
          cards: HoleCards(card1: 'A♠', card2: 'K♠'),
          persist: false);

      final sd = m.lastFinishedHand!.showdownData;
      expect(sd, isNotNull);
      expect(sd!.playerCards[3]!.card1, 'A♠');
      expect(sd.playerCards[3]!.card2, 'K♠');
      expect(m.lastFinishedHand!.reachedShowdown, isFalse,
          reason: 'shown cards are not a showdown');
    });

    test('single shown card is stored (card2 stays null)', () async {
      final m = manager();
      m.lastFinishedHand = finishedHand();

      await m.attachShownCards(
          seat: 7, cards: HoleCards(card1: 'Q♥'), persist: false);

      final cards = m.lastFinishedHand!.showdownData!.playerCards[7]!;
      expect(cards.card1, 'Q♥');
      expect(cards.card2, isNull);
      expect(cards.isComplete, isFalse,
          reason: 'range pipeline must skip incomplete pairs');
    });

    test('recording a second player preserves the first', () async {
      final m = manager();
      m.lastFinishedHand = finishedHand();

      await m.attachShownCards(
          seat: 2, cards: HoleCards(card1: '9♦', card2: '9♣'), persist: false);
      await m.attachShownCards(
          seat: 4, cards: HoleCards(card1: 'J♠'), persist: false);

      final sd = m.lastFinishedHand!.showdownData!;
      expect(sd.playerCards.length, 2);
      expect(sd.playerCards[2]!.card1, '9♦');
      expect(sd.playerCards[4]!.card1, 'J♠');
    });

    test('re-recording the same seat overwrites (correction flow)', () async {
      final m = manager();
      m.lastFinishedHand = finishedHand();

      await m.attachShownCards(
          seat: 3, cards: HoleCards(card1: 'A♠'), persist: false);
      await m.attachShownCards(
          seat: 3,
          cards: HoleCards(card1: 'A♣', card2: 'T♣'),
          persist: false);

      final cards = m.lastFinishedHand!.showdownData!.playerCards[3]!;
      expect(cards.card1, 'A♣');
      expect(cards.card2, 'T♣');
    });

    test('no-ops safely with no finished hand or empty cards', () async {
      final m = manager();
      // No lastFinishedHand at all:
      await m.attachShownCards(
          seat: 3, cards: HoleCards(card1: 'A♠'), persist: false);
      // Empty cards on a real hand:
      m.lastFinishedHand = finishedHand();
      await m.attachShownCards(seat: 3, cards: HoleCards(), persist: false);
      expect(m.lastFinishedHand!.showdownData, isNull);
    });

    test('works on a scout hand that is NOT in completedHands', () async {
      final m = manager();
      final scout = finishedHand()..isScouted = true;
      m.lastFinishedHand = scout; // scout hands never enter completedHands
      expect(m.completedHands, isEmpty);

      await m.attachShownCards(
          seat: 6, cards: HoleCards(card1: 'K♦', card2: 'Q♦'), persist: false);

      expect(scout.showdownData!.playerCards[6]!.card1, 'K♦');
    });
  });

  group('serialization', () {
    test('single-card showdownData survives toMap/fromMap round-trip', () {
      final h = finishedHand();
      h.showdownData = ShowdownData();
      h.showdownData!.playerCards[3] = HoleCards(card1: 'Q♥');
      h.showdownData!.playerCards[8] = HoleCards(card1: '7♠', card2: '2♦');

      final restored = HandRecord.fromMap(h.toMap());

      expect(restored.showdownData!.playerCards[3]!.card1, 'Q♥');
      expect(restored.showdownData!.playerCards[3]!.card2, isNull);
      expect(restored.showdownData!.playerCards[8]!.card2, '2♦');
      expect(restored.reachedShowdown, isFalse);
    });

    test('storage ids are in-memory only (not serialized)', () {
      final h = finishedHand();
      h.cloudHandId = 'hand_1_123';
      h.localHandId = 'sess_hand_1_123';
      final map = h.toMap();
      expect(map.containsKey('cloudHandId'), isFalse);
      expect(map.containsKey('localHandId'), isFalse);
    });
  });

  group('heroFoldedPreflop (history exclusion rule)', () {
    ActionRecord act(int seat, PlayerAction a, BettingRound street) =>
        ActionRecord(
          player: seat,
          action: a,
          street: street,
          timestamp: DateTime(2026, 7, 22),
          buttonPosition: 1,
        );

    HandRecord hand(List<ActionRecord> actions) => HandRecord(
          handNumber: 1,
          buttonPosition: 1,
          playerCount: 6,
          startTime: DateTime(2026, 7, 22),
          actions: actions,
        )..heroSeatNumber = 5;

    test('open, 3-bet, shove, hero folds preflop → hidden', () {
      final h = hand([
        act(5, PlayerAction.raise, BettingRound.preflop), // hero opens
        act(2, PlayerAction.raise, BettingRound.preflop), // 3-bet
        act(3, PlayerAction.raise, BettingRound.preflop), // shove
        act(5, PlayerAction.fold, BettingRound.preflop), // hero folds
      ]);
      expect(h.heroFoldedPreflop, isTrue);
    });

    test('hero calls preflop, folds on the FLOP → stays in history', () {
      final h = hand([
        act(5, PlayerAction.call, BettingRound.preflop),
        act(2, PlayerAction.bet, BettingRound.flop),
        act(5, PlayerAction.fold, BettingRound.flop),
      ]);
      expect(h.heroFoldedPreflop, isFalse);
    });

    test('walk (hero BB, no hero actions) → stays in history', () {
      final h = hand([
        act(1, PlayerAction.fold, BettingRound.preflop),
        act(2, PlayerAction.fold, BettingRound.preflop),
      ]);
      expect(h.heroFoldedPreflop, isFalse);
    });

    test('hero wins preflop (opens, everyone folds) → stays in history', () {
      final h = hand([
        act(5, PlayerAction.raise, BettingRound.preflop),
        act(2, PlayerAction.fold, BettingRound.preflop),
        act(3, PlayerAction.fold, BettingRound.preflop),
      ]);
      expect(h.heroFoldedPreflop, isFalse);
    });

    test('no hero seat set → never hidden', () {
      final h = hand([act(5, PlayerAction.fold, BettingRound.preflop)])
        ..heroSeatNumber = null;
      expect(h.heroFoldedPreflop, isFalse);
    });

    test('map-based twin matches (list-screen filter)', () {
      final foldedMap = [
        {'player': 5, 'action': 'raise', 'street': 'preflop'},
        {'player': 2, 'action': 'raise', 'street': 'preflop'},
        {'player': 5, 'action': 'fold', 'street': 'preflop'},
      ];
      final flopFoldMap = [
        {'player': 5, 'action': 'call', 'street': 'preflop'},
        {'player': 5, 'action': 'fold', 'street': 'flop'},
      ];
      expect(StatsCalculator.playerFoldedPreflop(foldedMap, 5), isTrue);
      expect(StatsCalculator.playerFoldedPreflop(flopFoldMap, 5), isFalse);
      expect(StatsCalculator.playerFoldedPreflop(foldedMap, 2), isFalse,
          reason: 'seat 2 never folded');
    });
  });
}
