import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/poker_game_state.dart';

/// HL-7 — side pot CREATION and DISPLAY coverage.
///
/// The engine's side-pot math is covered elsewhere (side_pot_calculator_test,
/// hand_logging_edge_cases_test). This file covers the two DISPLAY surfaces
/// the user actually sees, which were untested:
///
///  1. The live "side pot pills" model — `recalculateActiveSidePots()`
///     (poker_game_state.dart:1727), rendered by poker_hand_screen.dart:2541
///     with the gate `showSidePotPills = activeSidePots.length > 1`.
///  2. The winner-dialog pipeline (poker_hand_screen.dart:4902-4935):
///     processUncalledBetReturns() → calculateSidePots() → MultiPotWinnerDialog
///     shown when sidePots.length >= 2.
///
/// Group C replays the user-reported HL-7 hand step by step and asserts what
/// the UI would show after every single action.

void check(bool cond, String msg) {
  if (!cond) throw 'ASSERT: $msg';
}

void checkNear(double a, double b, String msg) {
  if ((a - b).abs() > 1e-6) throw 'ASSERT: $msg (got $a, want $b)';
}

double committed(PokerGameState g) =>
    g.players.fold(0.0, (s, p) => s + p.betThisRound + p.totalContribution);

void conserve(PokerGameState g, String where) {
  checkNear(g.currentPot, committed(g), 'chip conservation @$where');
  final pots = g.calculateSidePots();
  if (pots.isNotEmpty) {
    final sum = pots.fold(0.0, (s, p) => s + p.amount);
    checkNear(sum, committed(g), 'Σ(side pots)==committed @$where');
  }
}

PokerGameState build({
  int seats = 6,
  List<int>? active,
  Map<int, double> stacks = const {},
  int button = 1,
  double sb = 1,
  double bb = 2,
}) {
  final g = PokerGameState(
      numberOfPlayers: seats,
      smallBlind: sb,
      bigBlind: bb,
      isCashGame: true,
      hasBBante: false);
  for (final s in active ?? List.generate(seats, (i) => i + 1)) {
    g.setPlayerActive(s, true);
  }
  stacks.forEach(g.setPlayerStack);
  g.buttonPosition = button;
  g.finalizeInitialization();
  g.initializePot();
  return g;
}

PlayerState p(PokerGameState g, int id) => g.players[id - 1];

/// Acts as the current player. For raise, [amount] is the TOTAL to-amount.
String act(PokerGameState g, PlayerAction a, [double? amount]) {
  final r = amount != null
      ? g.performActionWithAmount(a, amount)
      : g.performAction(a);
  if (r.startsWith('Invalid') || r.contains('cannot act')) {
    throw 'engine rejected: $r';
  }
  return r;
}

/// EXACT replica of the screen's pill-visibility gate
/// (poker_hand_screen.dart:2541).
bool pillsVisible(PokerGameState g) => g.activeSidePots.length > 1;

/// EXACT replica of the winner-dialog pot pipeline
/// (poker_hand_screen.dart:4902-4924): return uncalled overage first, then
/// compute the pots the dialog receives. The engine reports refunds as a
/// display string, so actual refund amounts are measured via stack deltas.
({List<SidePot> pots, Map<int, double> refunds}) winnerDialogPots(
    PokerGameState g) {
  final stacksBefore = {
    for (final pl in g.players) pl.playerId: pl.currentStack
  };
  g.processUncalledBetReturns();
  final refunds = <int, double>{};
  for (final pl in g.players) {
    final delta = pl.currentStack - stacksBefore[pl.playerId]!;
    if (delta.abs() > 1e-9) refunds[pl.playerId] = delta;
  }
  final pots = SidePotCalculator.calculateSidePots(g.players);
  return (pots: pots, refunds: refunds);
}

void main() {
  // ── A. Pill-model gates (recalculateActiveSidePots) ──────────────────

  test('A1 no all-in: pills hidden regardless of pot size', () {
    final g = build(stacks: {for (var i = 1; i <= 6; i++) i: 500});
    act(g, PlayerAction.raise, 20); // UTG (4)
    act(g, PlayerAction.call); // 5
    act(g, PlayerAction.call); // 6
    act(g, PlayerAction.call); // 1
    check(g.activeSidePots.isEmpty, 'no all-in → no pill model');
    check(!pillsVisible(g), 'pills hidden');
    conserve(g, 'A1');
  });

  test('A2 all-in but single pot: pills hidden (nothing to break down)', () {
    final g = build(
        seats: 3, active: [1, 2, 3], stacks: {1: 100, 2: 100, 3: 30});
    // BTN=1, SB=2(1), BB=3(2). Seat 1 acts first (3-handed BTN=UTG).
    act(g, PlayerAction.raise, 30); // seat 1
    act(g, PlayerAction.call); // seat 2 (SB) — 30 total
    act(g, PlayerAction.call); // seat 3 (BB) all-in for 30
    check(p(g, 3).isAllIn, 'BB is all-in');
    // Everyone matched 30 → one pot only → no pills.
    check(!pillsVisible(g), 'single pot → pills hidden');
    conserve(g, 'A2');
  });

  test(
      'A3 raise OVER an all-in: side pot pill appears IMMEDIATELY (HL-7 fix)',
      () {
    final g = build(
        seats: 4,
        active: [1, 2, 3, 4],
        stacks: {1: 200, 2: 200, 3: 200, 4: 40});
    // BTN=1, SB=2, BB=3, UTG=4.
    act(g, PlayerAction.raise, 40); // seat 4 all-in 40
    check(p(g, 4).isAllIn, 'seat 4 all-in');
    act(g, PlayerAction.raise, 100); // seat 1 raises OVER the all-in
    // HL-7: the moment a raise exceeds an all-in, the side pot starts
    // forming and MUST be shown. Pending players (blinds still to act)
    // are eligible — they will either match or fold.
    check(pillsVisible(g), 'side pot pill visible at the raise-over moment');
    check(g.activeSidePots.length == 2,
        '2 pills, got ${g.activeSidePots.length}');
    // Main L40: 40 (s4) + 40 (s1) + SB 1 + BB 2 = 83.
    // Side L40→100: s1's 60 so far (in flight until called/folded).
    checkNear(g.activeSidePots[0].amount, 83, 'main pot pill');
    checkNear(g.activeSidePots[1].amount, 60, 'forming side pot pill');
    conserve(g, 'A3');
  });

  test('A4 raise over all-in IS called: pills appear with 2 pots', () {
    final g = build(
        seats: 4,
        active: [1, 2, 3, 4],
        stacks: {1: 200, 2: 200, 3: 200, 4: 40});
    act(g, PlayerAction.raise, 40); // seat 4 all-in
    act(g, PlayerAction.raise, 100); // seat 1 over the top
    act(g, PlayerAction.fold); // seat 2 (SB)
    act(g, PlayerAction.call); // seat 3 (BB) calls 100
    // Now L40 has {4,1,3}, L100 has {1,3} → two contested pots → pills ON.
    check(pillsVisible(g), 'pills visible once the over-raise is called');
    check(g.activeSidePots.length == 2,
        'exactly 2 pills, got ${g.activeSidePots.length}');
    // Main pot: 40×3 + dead SB 1 = 121. Side: (100-40)×2 = 120.
    checkNear(g.activeSidePots[0].amount, 121, 'main pot pill amount');
    checkNear(g.activeSidePots[1].amount, 120, 'side pot pill amount');
    check(g.activeSidePots[0].eligiblePlayers.toSet().containsAll({1, 3, 4}),
        'main pot eligibility includes the all-in player');
    check(!g.activeSidePots[1].eligiblePlayers.contains(4),
        'all-in player NOT eligible for the side pot');
    conserve(g, 'A4');
  });

  // ── B. Winner-dialog pipeline (uncalled return → pot list) ───────────

  test('B1 uncalled overage refunded BEFORE pots; dialog gets clean pots', () {
    final g = build(
        seats: 4,
        active: [1, 2, 3, 4],
        stacks: {1: 200, 2: 200, 3: 200, 4: 40});
    act(g, PlayerAction.raise, 40); // 4 all-in
    act(g, PlayerAction.raise, 100); // 1 over the top
    act(g, PlayerAction.fold); // 2
    act(g, PlayerAction.fold); // 3
    // Betting closed: seat 1's 60 above the 40 was never called.
    final r = winnerDialogPots(g);
    checkNear(r.refunds[1] ?? 0, 60, 'uncalled 60 returned to seat 1');
    check(r.pots.length == 1,
        'after refund only ONE real pot remains, got ${r.pots.length}');
    // Main pot: 40×2 + dead SB 1 + dead BB 2 = 83.
    checkNear(r.pots[0].amount, 83, 'main pot after refund');
    conserve(g, 'B1-post-refund');
  });

  test('B2 dialog trigger: >=2 pots → MultiPotWinnerDialog path', () {
    final g = build(
        seats: 4,
        active: [1, 2, 3, 4],
        stacks: {1: 200, 2: 200, 3: 200, 4: 40});
    act(g, PlayerAction.raise, 40); // 4 all-in
    act(g, PlayerAction.raise, 100); // 1
    act(g, PlayerAction.fold); // 2
    act(g, PlayerAction.call); // 3 calls 100
    final r = winnerDialogPots(g);
    check(r.refunds.isEmpty, 'nothing uncalled');
    check(r.pots.length >= 2, 'multi-pot dialog would be shown');
    check(r.pots.length == 2, 'exactly 2 pots, got ${r.pots.length}');
    conserve(g, 'B2');
  });

  // ── C. HL-7 user-reported scenario, step-by-step ─────────────────────
  //
  // "Someone opens, there's a call. I'm the shortest stack and I push.
  //  Couple of calls. Then a big stack raises my all-in (side pot should
  //  form). Afterwards a couple of overshoves — should be 3 pots."
  //
  // 6-max, BTN=1, SB=2 (posts 1), BB=3 (posts 2), UTG=4.
  // Stacks: s4=200 (big stack), s5=90, s6=20 (HERO, shortest), s1=150.

  test('C1 full user scenario: pill visibility at every step + 3 final pots',
      () {
    final g = build(stacks: {1: 150, 2: 50, 3: 50, 4: 200, 5: 90, 6: 20});

    act(g, PlayerAction.raise, 6); // s4 opens
    check(!pillsVisible(g), 'step1 open: no pills');

    act(g, PlayerAction.call); // s5 calls 6
    check(!pillsVisible(g), 'step2 call: no pills');

    act(g, PlayerAction.raise, 20); // s6 HERO shoves 20 (all-in)
    check(p(g, 6).isAllIn, 'hero is all-in');
    check(!pillsVisible(g), 'step3 hero shove: single level → no pills yet');

    act(g, PlayerAction.call); // s1 calls 20
    check(!pillsVisible(g), 'step4 call of shove: still one contested level');

    act(g, PlayerAction.fold); // s2 (SB)
    act(g, PlayerAction.fold); // s3 (BB)

    act(g, PlayerAction.raise, 60); // s4 raises OVER hero's all-in
    // The user's reported moment (HL-7): the raise over the all-in starts
    // the side pot — pills MUST appear right here.
    check(pillsVisible(g),
        'step5 raise-over-all-in: side pot pill appears immediately');
    check(g.activeSidePots.length == 2,
        'step5: main + forming side pot, got ${g.activeSidePots.length}');
    // Main L20: 20(s4)+6(s5)+20(s6)+20(s1)+dead 3 = 69. Side: s4's 40.
    checkNear(g.activeSidePots[0].amount, 69, 'step5 main pot');
    checkNear(g.activeSidePots[1].amount, 40, 'step5 forming side pot');

    act(g, PlayerAction.raise, 90); // s5 overshove all-in 90
    check(p(g, 5).isAllIn, 's5 all-in');
    // s5's 90 called s4's 60 and re-raised → L20 and L60 both contested.
    check(pillsVisible(g), 'step6 overshove: pills MUST now be visible');
    check(g.activeSidePots.length == 2,
        'step6: 2 contested pots, got ${g.activeSidePots.length}');

    act(g, PlayerAction.raise, 150); // s1 overshove all-in 150
    check(p(g, 1).isAllIn, 's1 all-in');
    check(pillsVisible(g), 'step7: pills stay visible');
    check(g.activeSidePots.length == 3,
        'step7: 3 contested pots, got ${g.activeSidePots.length}');

    act(g, PlayerAction.call); // s4 calls 150
    conserve(g, 'C1-final');

    // Winner-dialog pipeline: nothing uncalled, exactly 3 pots.
    final r = winnerDialogPots(g);
    check(r.refunds.isEmpty, 'no refunds — top level was called');
    check(r.pots.length == 3,
        'FINAL: 3 pots (user saw 2 → this is the detector), got '
        '${r.pots.length}');

    // Pot amounts. Committed: 150+1+2+150+90+20 = 413.
    // Main L20: 20×4 + dead(1+2) = 83  — hero eligible.
    // Side1 L90: (90-20)×3 = 210      — s4, s5, s1.
    // Side2 L150: (150-90)×2 = 120    — s4, s1.
    checkNear(r.pots[0].amount, 83, 'main pot');
    checkNear(r.pots[1].amount, 210, 'side pot 1');
    checkNear(r.pots[2].amount, 120, 'side pot 2');
    check(r.pots[0].eligiblePlayers.contains(6), 'hero eligible for main');
    check(!r.pots[1].eligiblePlayers.contains(6), 'hero NOT in side 1');
    check(!r.pots[2].eligiblePlayers.contains(6), 'hero NOT in side 2');
    check(!r.pots[2].eligiblePlayers.contains(5), 's5 NOT in side 2');
    final sum = r.pots.fold(0.0, (s, pot) => s + pot.amount);
    checkNear(sum, 413, 'all committed chips are in the pots');
  });

  test('C2 variant: caller cannot cover the last overshove → refund + 3 pots',
      () {
    // Same shape but s4 has only 120: s1's 150 overshove is partially
    // uncalled → 30 back to s1, pots capped at 120.
    final g = build(stacks: {1: 150, 2: 50, 3: 50, 4: 120, 5: 90, 6: 20});
    act(g, PlayerAction.raise, 6); // s4
    act(g, PlayerAction.call); // s5
    act(g, PlayerAction.raise, 20); // s6 hero all-in
    act(g, PlayerAction.call); // s1
    act(g, PlayerAction.fold); // s2
    act(g, PlayerAction.fold); // s3
    act(g, PlayerAction.raise, 60); // s4
    act(g, PlayerAction.raise, 90); // s5 all-in
    act(g, PlayerAction.raise, 150); // s1 all-in
    act(g, PlayerAction.call); // s4 calls all-in for 120
    check(p(g, 4).isAllIn, 's4 all-in for less');

    final r = winnerDialogPots(g);
    checkNear(r.refunds[1] ?? 0, 30, '30 uncalled returned to s1');
    check(r.pots.length == 3, '3 pots after refund, got ${r.pots.length}');
    // Main: 83. Side1: (90-20)×3=210. Side2: (120-90)×2=60. Σ=353.
    checkNear(r.pots[0].amount, 83, 'main');
    checkNear(r.pots[1].amount, 210, 'side 1');
    checkNear(r.pots[2].amount, 60, 'side 2 capped at caller stack');
    conserve(g, 'C2-post-refund');
  });

  test('C3 variant: middle player folds to the re-raise → 2 pots IS correct',
      () {
    // Documents the case where "only 2 pots" is right: s5 folds to s4's 60,
    // their 6 becomes dead money. Levels: hero 20, then 150 (s4=s1).
    final g = build(stacks: {1: 150, 2: 50, 3: 50, 4: 200, 5: 90, 6: 20});
    act(g, PlayerAction.raise, 6); // s4
    act(g, PlayerAction.call); // s5
    act(g, PlayerAction.raise, 20); // s6 hero all-in
    act(g, PlayerAction.call); // s1
    act(g, PlayerAction.fold); // s2
    act(g, PlayerAction.fold); // s3
    act(g, PlayerAction.raise, 60); // s4
    act(g, PlayerAction.fold); // s5 folds — 6 dead
    act(g, PlayerAction.raise, 150); // s1 all-in
    act(g, PlayerAction.call); // s4 calls 150

    final r = winnerDialogPots(g);
    check(r.refunds.isEmpty, 'no refunds');
    check(r.pots.length == 2, '2 pots is CORRECT here, got ${r.pots.length}');
    // Main: 20×3 + dead(1+2+6) = 69. Side: (150-20)×2 = 260. Σ=329.
    checkNear(r.pots[0].amount, 69, 'main incl. dead money');
    checkNear(r.pots[1].amount, 260, 'single side pot');
    conserve(g, 'C3');
  });

  test('C4 pills survive street advance during multi-pot hand', () {
    // Two all-ins preflop, two live players continue on the flop — the pill
    // model must persist across startNewStreet (call site pgs:994/1088).
    final g = build(stacks: {1: 150, 2: 50, 3: 50, 4: 200, 5: 90, 6: 20});
    act(g, PlayerAction.raise, 20); // s4 opens big
    act(g, PlayerAction.raise, 90); // s5 all-in over
    act(g, PlayerAction.call); // s6 hero calls all-in for 20
    act(g, PlayerAction.call); // s1 calls 90
    act(g, PlayerAction.fold); // s2
    act(g, PlayerAction.fold); // s3
    act(g, PlayerAction.call); // s4 calls 90
    check(pillsVisible(g), 'pills before street advance');
    final before = g.activeSidePots.length;
    g.startNewStreet();
    check(pillsVisible(g), 'pills still visible after street advance');
    check(g.activeSidePots.length == before,
        'pot breakdown unchanged across streets');
    conserve(g, 'C4-flop');
  });
}
