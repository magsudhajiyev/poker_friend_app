import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/hand_state_machine.dart';
import 'package:poker_logger/models/poker_game_state.dart';
import 'package:poker_logger/utils/poker_positions.dart';

/// HL-1 / HL-3 — the seating boundary rule.
///
/// Boundary: `currentHand.actions.isEmpty`.
///  - PRE-ACTION seat change joins the CURRENT hand: blinds re-posted
///    (idempotent initializePot), action order recomputed (new player after
///    the BB becomes UTG), blind seats + frozen hero position re-synced.
///  - MID-HAND seat change is DEFERRED: sessionManager.pendingSeats holds it,
///    the engine only learns about it via flushPendingSeats() at next hand
///    start. Same rule for the hero (deferHeroReseat).
///
/// Deeper entry rules (can't enter as SB, no BTN next hand, dead button) are
/// intentionally NOT implemented — see POKER_SEATING_RULES.md.

void check(bool cond, String msg) {
  if (!cond) throw 'ASSERT: $msg';
}

void checkNear(double a, double b, String msg) {
  if ((a - b).abs() > 1e-6) throw 'ASSERT: $msg (got $a, want $b)';
}

double committed(PokerGameState g) =>
    g.players.fold(0.0, (s, p) => s + p.betThisRound + p.totalContribution);

PokerGameState buildGame({
  int seats = 6,
  required List<int> active,
  Map<int, double> stacks = const {},
  int button = 1,
}) {
  final g = PokerGameState(
      numberOfPlayers: seats,
      smallBlind: 1,
      bigBlind: 2,
      isCashGame: true,
      hasBBante: false);
  for (final s in active) {
    g.setPlayerActive(s, true);
  }
  stacks.forEach(g.setPlayerStack);
  g.buttonPosition = button;
  g.finalizeInitialization();
  g.initializePot();
  return g;
}

PokerSessionManager buildManager(PokerGameState g,
    {required List<int> active, int? heroSeat}) {
  final m = PokerSessionManager(
    smallBlind: 1,
    bigBlind: 2,
    playerCount: g.numberOfPlayers,
    ourSeatNumber: heroSeat,
  );
  for (final s in active) {
    m.activeSeats.add(s);
    m.setPlayerName(s, 'P$s');
    m.playerStacks[s] = g.getPlayerStack(s);
  }
  m.buttonPosition = g.buttonPosition;
  m.startHand(1, g.buttonPosition,
      sbSeat: g.effectiveSBPosition, bbSeat: g.effectiveBBPosition);
  return m;
}

/// Mirrors the screen's PRE-ACTION seat-add path (_onSeatTapped onSave).
void addPlayerPreAction(
    PokerGameState g, PokerSessionManager m, int seat, double stack) {
  m.setPlayerName(seat, 'P$seat');
  m.playerStacks[seat] = stack;
  m.activeSeats.add(seat);
  g.setPlayerActive(seat, true);
  g.setPlayerStack(seat, stack);
  g.initializePot();
  g.recalculateActionOrder();
  m.refreshPreActionPositions(g);
}

/// Mirrors the screen's MID-HAND seat-add path.
void addPlayerMidHand(PokerSessionManager m, int seat, double stack) {
  m.setPlayerName(seat, 'P$seat');
  m.playerStacks[seat] = stack;
  m.activeSeats.add(seat);
  m.pendingSeats.add(seat);
}

void main() {
  // ── HL-1: pre-action seat fill after the BB → new UTG ────────────────

  test('HL-1 exact repro: seat left of BB filled pre-action becomes UTG', () {
    // 6-max, seat 4 empty. BTN=1, SB=2, BB=3 → UTG is seat 5.
    final g = buildGame(
        active: [1, 2, 3, 5, 6],
        stacks: {1: 200, 2: 200, 3: 200, 5: 200, 6: 200});
    final m = buildManager(g, active: [1, 2, 3, 5, 6], heroSeat: 6);
    check(g.currentPlayer == 5, 'before: UTG is seat 5, got ${g.currentPlayer}');
    checkNear(g.currentPot, 3, 'before: pot = SB+BB');

    // User's test case: seat the new player directly left of the BB.
    addPlayerPreAction(g, m, 4, 200);

    check(g.currentPlayer == 4,
        'AFTER: action must go to the new seat 4 as UTG, got ${g.currentPlayer}');
    check(g.effectiveSBPosition == 2 && g.effectiveBBPosition == 3,
        'blind seats unchanged (SB=2, BB=3)');
    checkNear(g.currentPot, 3, 'blinds not double-posted');
    checkNear(committed(g), 3, 'chip conservation');
    check(m.actualSBSeat == 2 && m.actualBBSeat == 3,
        'sessionManager blind seats synced');
  });

  test('HL-1 hero position label re-frozen after pre-action join', () {
    final g = buildGame(
        active: [1, 2, 3, 5, 6],
        stacks: {1: 200, 2: 200, 3: 200, 5: 200, 6: 200});
    final m = buildManager(g, active: [1, 2, 3, 5, 6], heroSeat: 6);

    addPlayerPreAction(g, m, 4, 200);

    final expected = PokerPositions.getPositionNameForActivePlayers(
        6, 1, [1, 2, 3, 4, 5, 6]);
    check(m.currentHand!.heroPositionName == expected,
        'hero position recomputed with new seat: '
        'got ${m.currentHand!.heroPositionName}, want $expected');
  });

  test('HL-1 seat filled between BTN and SB: blind ownership recomputed', () {
    // 3-handed [1,3,5], BTN=1 → SB=3, BB=5. Filling seat 2 makes it SB.
    final g = buildGame(
        seats: 6, active: [1, 3, 5], stacks: {1: 200, 3: 200, 5: 200});
    final m = buildManager(g, active: [1, 3, 5], heroSeat: 1);
    check(g.effectiveSBPosition == 3 && g.effectiveBBPosition == 5,
        'before: SB=3 BB=5');

    addPlayerPreAction(g, m, 2, 200);

    check(g.effectiveSBPosition == 2, 'new SB is seat 2');
    check(g.effectiveBBPosition == 3, 'new BB is seat 3');
    checkNear(g.currentPot, 3, 'old blinds refunded, new ones posted');
    checkNear(g.players[4].betThisRound, 0, 'old BB (seat 5) refunded');
    checkNear(g.players[1].betThisRound, 1, 'seat 2 posted SB');
    checkNear(g.players[2].betThisRound, 2, 'seat 3 posted BB');
    checkNear(committed(g), 3, 'chip conservation');
  });

  // ── HL-3: mid-hand seat add is deferred ──────────────────────────────

  test('HL-3 mid-hand add: engine unaware until flush at next hand', () {
    final g = buildGame(
        active: [1, 2, 3, 5, 6],
        stacks: {1: 200, 2: 200, 3: 200, 5: 200, 6: 200});
    final m = buildManager(g, active: [1, 2, 3, 5, 6], heroSeat: 6);

    // First action happens → hand in progress.
    m.recordAction(5, PlayerAction.call, BettingRound.preflop, 1,
        playerStack: 200, amount: 2);
    g.performAction(PlayerAction.call); // seat 5 calls in the engine

    addPlayerMidHand(m, 4, 200);

    check(!g.players[3].isActive, 'engine does NOT know seat 4 yet');
    check(m.pendingSeats.contains(4), 'seat 4 pending');
    check(m.activeSeats.contains(4), 'seat renders occupied (dimmed)');
    // The turn scan must never reach seat 4 this hand.
    check(g.currentPlayer != 4, 'action never goes to the pending seat');

    // Next hand: flush BEFORE startNewHand (as the screen does).
    m.flushPendingSeats(g);
    check(g.players[3].isActive, 'seat 4 active after flush');
    checkNear(g.getPlayerStack(4), 200, 'stack applied at flush');
    check(m.pendingSeats.isEmpty, 'pending cleared');
  });

  test('HL-3 pending seat removed before next hand never reaches engine', () {
    final g = buildGame(
        active: [1, 2, 3, 5, 6],
        stacks: {1: 200, 2: 200, 3: 200, 5: 200, 6: 200});
    final m = buildManager(g, active: [1, 2, 3, 5, 6], heroSeat: 6);
    m.recordAction(5, PlayerAction.call, BettingRound.preflop, 1,
        playerStack: 200, amount: 2);

    addPlayerMidHand(m, 4, 200);
    // Player changes their mind and is removed while pending (screen also
    // removes from activeSeats/names/stacks).
    m.activeSeats.remove(4);
    m.pendingSeats.remove(4);

    m.flushPendingSeats(g);
    check(!g.players[3].isActive, 'removed pending seat stays inactive');
  });

  test('HL-3 stale pending entry (not in activeSeats) is skipped by flush',
      () {
    final g = buildGame(active: [1, 2, 3], stacks: {1: 200, 2: 200, 3: 200});
    final m = buildManager(g, active: [1, 2, 3], heroSeat: 1);
    m.pendingSeats.add(5); // pending but never added to activeSeats
    m.flushPendingSeats(g);
    check(!g.players[4].isActive, 'stale pending seat not activated');
    check(m.pendingSeats.isEmpty, 'pending cleared regardless');
  });

  // ── HL-3: hero re-seat mid-hand is deferred too ──────────────────────

  test('HL-3 hero mid-hand re-seat deferred until next hand', () {
    final g = buildGame(
        active: [1, 2, 3, 5, 6],
        stacks: {1: 200, 2: 200, 3: 200, 5: 200, 6: 350});
    final m = buildManager(g, active: [1, 2, 3, 5, 6], heroSeat: 6);
    m.recordAction(5, PlayerAction.call, BettingRound.preflop, 1,
        playerStack: 200, amount: 2);

    m.deferHeroReseat(newSeat: 4, heroName: 'Me', heroStack: 350);

    check(m.ourSeatNumber == 6, 'hero still at old seat mid-hand');
    check(m.pendingHeroSeat == 4, 'target recorded');
    check(!g.players[3].isActive, 'engine unaware of target seat');

    m.flushPendingSeats(g);

    check(m.ourSeatNumber == 4, 'hero moved at next hand');
    check(g.players[3].isActive, 'new hero seat active in engine');
    checkNear(g.getPlayerStack(4), 350, 'hero stack carried over');
    check(!g.players[5].isActive, 'old hero seat released in engine');
    check(!m.activeSeats.contains(6), 'old seat released in manager');
    check(m.pendingHeroSeat == null, 'deferred move consumed');
  });

  // ── Guard: recalculateActionOrder is preflop-only ────────────────────

  test('recalculateActionOrder is a no-op when betting round is complete',
      () {
    final g = buildGame(active: [1, 2, 3], stacks: {1: 200, 2: 200, 3: 200});
    // BTN=1 acts first 3-handed; everyone calls/checks to close the round.
    g.performAction(PlayerAction.call); // 1
    g.performAction(PlayerAction.call); // 2 (SB)
    g.performAction(PlayerAction.check); // 3 (BB option)
    check(g.bettingRoundComplete, 'round closed');
    final before = g.currentPlayer;
    g.recalculateActionOrder();
    check(g.currentPlayer == before, 'no reshuffle after round completion');
  });
}
