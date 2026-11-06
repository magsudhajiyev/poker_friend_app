import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/hand_state_machine.dart';
import 'package:poker_logger/models/poker_game_state.dart';
import 'package:poker_logger/services/easy_logging_flow.dart';
import 'package:poker_logger/services/local_storage_service.dart';

/// Dead button / dead SB through PokerSessionManager: frozen position names,
/// blind seats, the record's button, and the tick/stub rotation.

PokerGameState game(List<int> live, {int seats = 6}) {
  final g = PokerGameState(
      numberOfPlayers: seats, smallBlind: 1, bigBlind: 2, isCashGame: true);
  for (final s in live) {
    g.setPlayerActive(s, true);
    g.setPlayerStack(s, 100);
  }
  g.finalizeInitialization();
  g.initializePot();
  return g;
}

PokerSessionManager manager(PokerGameState g, List<int> live, int hero) {
  final m = PokerSessionManager(
      smallBlind: 1,
      bigBlind: 2,
      playerCount: g.numberOfPlayers,
      ourSeatNumber: hero);
  for (final s in live) {
    m.activeSeats.add(s);
    m.setPlayerName(s, 'P$s');
  }
  m.startHand(g.handNumber, g.buttonPosition,
      sbSeat: g.effectiveSBPosition, bbSeat: g.effectiveBBPosition);
  return m;
}

/// Next hand the way the screen does it.
void deal(PokerGameState g, PokerSessionManager m, List<int> live) {
  g.players[2].currentStack = 0; // seat 3 busts
  m.activeSeats
    ..clear()
    ..addAll(live);
  g.startNewHand();
  g.initializePot();
  m.startHand(g.handNumber, g.buttonPosition,
      sbSeat: g.effectiveSBPosition, bbSeat: g.effectiveBBPosition);
}

void main() {
  const six = [1, 2, 3, 4, 5, 6];
  const five = [1, 2, 4, 5, 6];

  test('dead SB hand: hero frozen position and labels are real', () {
    final g = game(six);
    final m = manager(g, six, 5);
    deal(g, m, five); // BTN2, SB dead (seat 3), BB4, UTG5
    expect(m.deadSeats, {3});
    expect(m.currentHand!.heroPositionName, 'UTG');
    final labels = {for (final s in five) s: m.getPlayerNameWithPosition(s)};
    expect(labels[4], contains('(BB)'));
    expect(labels[2], contains('(BTN)'));
    expect(labels.values.any((l) => l.contains('(SB)')), isFalse);
    expect(m.getOurPosition(g.buttonPosition), 'UTG');
  });

  test('dead button hand: nobody is BTN, hero SB is labelled SB', () {
    final g = game(six);
    final m = manager(g, six, 4);
    deal(g, m, five);
    deal2(g, m, five); // x3/4/5
    expect(m.deadSeats, {3});
    expect(g.buttonDead, isTrue);
    expect(m.currentHand!.heroPositionName, 'SB');
    final labels = {for (final s in five) s: m.getPlayerNameWithPosition(s)};
    expect(labels.values.any((l) => l.contains('(BTN)')), isFalse);
    expect(labels[5], contains('(BB)'));
    expect(labels[6], contains('(UTG)'));
  });

  test('BB removed before any action: blinds, dead seats, hero re-synced', () {
    final g = game(six);
    final m = manager(g, six, 5);
    deal(g, m, five); // 2/-/4
    g.setPlayerActive(4, false);
    m.activeSeats.remove(4);
    g.initializePot();
    g.recalculateActionOrder();
    m.refreshPreActionPositions(g);
    // Same as if seat 4 had left with seat 3: BB is now seat 5, dead SB seat 3
    // is still the previous BB, so BB moves on.
    expect(g.effectiveBBPosition, 5);
    expect(m.actualBBSeat, 5);
    expect(m.currentHand!.heroPositionName, 'BB');
    expect(m.deadSeats, g.deadSeats.toSet());
  });

  test('hero unseats before any action: record blinds are re-stamped', () {
    final g = game(six);
    final m = manager(g, six, 5);
    deal(g, m, five); // BTN2, dead SB (seat 3), BB4
    expect(m.currentHand!.smallBlindDead, isTrue);
    // Hero (seat 5) leaves; seat 3 comes back to life as a normal player.
    m.ourSeatNumber = null;
    m.activeSeats.remove(5);
    g.setPlayerActive(5, false);
    g.setPlayerActive(3, true);
    g.setPlayerStack(3, 100);
    m.activeSeats.add(3);
    g.initializePot();
    g.recalculateActionOrder();
    m.refreshPreActionPositions(g);
    final h = m.currentHand!;
    expect(h.smallBlindDead, isFalse);
    expect(h.sbSeat, 3);
    expect(h.bbSeat, 4);
    expect(h.buttonPosition, g.buttonPosition);
  });

  test('heads-up hand gains a third player pre-action: record button moves',
      () {
    final live = [1, 2];
    final g = game(live, seats: 3);
    final m = manager(g, live, 1);
    g.startNewHand();
    g.initializePot();
    m.startHand(g.handNumber, g.buttonPosition,
        sbSeat: g.effectiveSBPosition, bbSeat: g.effectiveBBPosition);
    g.setPlayerActive(3, true);
    g.setPlayerStack(3, 100);
    m.activeSeats.add(3);
    m.setPlayerName(3, 'P3');
    g.initializePot();
    g.recalculateActionOrder();
    m.refreshPreActionPositions(g);
    expect(m.currentHand!.buttonPosition, g.buttonPosition);
    expect(m.actualSBSeat, g.effectiveSBPosition);
  });

  test('fold tick without a hand in progress rotates like the engine', () {
    final g = game(six);
    final m = manager(g, six, 5);
    deal(g, m, five); // BB4, SB dead, BTN2
    m.currentHand = null;
    // Engine's next hand: BTN3 (dead), SB4, BB5.
    final tick = m.buildFoldTickRecord();
    expect(tick.buttonPosition, 3);
    expect(tick.heroPositionName, 'BB');
  });

  test('fold tick Undo with a short-stacked hero restores blinds and rotation',
      () {
    PokerGameState table() {
      final g = PokerGameState(
          numberOfPlayers: 6, smallBlind: 1, bigBlind: 2, isCashGame: true);
      for (final s in six) {
        g.setPlayerActive(s, true);
        g.setPlayerStack(s, s == 3 ? 2 : 100); // hero (seat 3) posts the BB all-in
      }
      g.finalizeInitialization();
      g.initializePot();
      return g;
    }

    final g = table();
    final control = table();
    final before = (g.buttonPosition, g.effectiveSBPosition, g.effectiveBBPosition);
    expect(before.$3, 3);

    final snap = TableSnapshot.capture(g);
    g.skipToNextHand(heroSeat: 3); // hero ends at 0 after paying the blind
    expect(g.players[2].currentStack, 0);
    snap.restore(g);

    expect((g.buttonPosition, g.effectiveSBPosition, g.effectiveBBPosition),
        before);
    g.startNewHand();
    control.startNewHand();
    expect(g.effectiveBBPosition, control.effectiveBBPosition);
    expect(g.effectiveSBPosition, control.effectiveSBPosition);
    expect(g.buttonPosition, control.buttonPosition);
  });

  test('hand records the real blinds: dead SB has no SB seat', () {
    final g = game(six);
    final m = manager(g, six, 5);
    expect(m.currentHand!.bbSeat, 3);
    expect(m.currentHand!.sbSeat, 2);
    expect(m.currentHand!.smallBlindDead, isFalse);
    deal(g, m, five); // BTN2, dead SB seat 3, BB4
    final h = m.currentHand!;
    expect((h.bbSeat, h.sbSeat, h.smallBlindDead), (4, null, true));
    final map = h.toMap();
    expect(map['bbSeat'], 4);
    expect(map.containsKey('sbSeat'), isFalse);
    expect(map['smallBlindDead'], true);
    final back = HandRecord.fromMap(map);
    expect((back.bbSeat, back.sbSeat, back.smallBlindDead), (4, null, true));
  });

  test('old maps without the fields load as null / false', () {
    final h = HandRecord(
        handNumber: 1,
        buttonPosition: 1,
        playerCount: 6,
        startTime: DateTime(2026));
    final map = h.toMap();
    expect(map.containsKey('bbSeat'), isFalse);
    expect(map.containsKey('smallBlindDead'), isFalse);
    final back = HandRecord.fromMap(map);
    expect((back.bbSeat, back.sbSeat, back.smallBlindDead), (null, null, false));
  });

  test('pre-action BB removal re-stamps the record', () {
    final g = game(six);
    final m = manager(g, six, 5);
    deal(g, m, five);
    g.setPlayerActive(4, false);
    m.activeSeats.remove(4);
    g.initializePot();
    g.recalculateActionOrder();
    m.refreshPreActionPositions(g);
    expect(m.currentHand!.bbSeat, 5);
  });

  test('local DB v21 adds only the missing blind columns', () {
    expect(LocalStorageService.missingHandsV21Statements({'id'}).length, 3);
    expect(
        LocalStorageService.missingHandsV21Statements(
            {'bbSeat', 'sbSeat', 'smallBlindDead'}),
        isEmpty);
  });
}

/// Second deal in a row (seat 3 stays gone).
void deal2(PokerGameState g, PokerSessionManager m, List<int> live) {
  g.startNewHand();
  g.initializePot();
  m.startHand(g.handNumber, g.buttonPosition,
      sbSeat: g.effectiveSBPosition, bbSeat: g.effectiveBBPosition);
}
