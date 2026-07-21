import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/poker_game_state.dart';

/// Hand-logging edge cases, validated headlessly against the production
/// engine (35/35 green) and kept here so regressions are caught in CI.
/// Invariant checked throughout — chip conservation:
///   pot == Σ(betThisRound + totalContribution) == Σ(sidePots).



void check(bool cond, String msg) {
  if (!cond) throw 'ASSERT: $msg';
}

void checkNear(double a, double b, String msg) {
  if ((a - b).abs() > 1e-6) throw 'ASSERT: $msg (got $a, want $b)';
}

double committed(PokerGameState g) => g.players
    .fold(0.0, (s, p) => s + p.betThisRound + p.totalContribution);

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
  bool ante = false,
  bool cash = true,
}) {
  final g = PokerGameState(
      numberOfPlayers: seats,
      smallBlind: sb,
      bigBlind: bb,
      isCashGame: cash,
      hasBBante: ante);
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


void scenario(String name, void Function() body) => test(name, body);

void main() {
  // ── A. Blinds & table setup ─────────────────────────────────────────

  scenario('A1 6-max: blinds posted, pot=SB+BB, UTG acts first', () {
    final g = build(button: 1);
    checkNear(g.currentPot, 3, 'pot after blinds');
    check(g.effectiveSBPosition == 2 && g.effectiveBBPosition == 3,
        'SB=2 BB=3 for BTN=1');
    check(g.currentPlayer == 4, 'UTG (seat 4) first, got ${g.currentPlayer}');
    conserve(g, 'A1');
  });

  scenario('A2 heads-up: button posts SB and acts first preflop', () {
    final g = build(seats: 2, button: 1);
    checkNear(g.currentPot, 3, 'pot after blinds');
    check(g.effectiveSBPosition == 1, 'HU button posts SB');
    check(g.effectiveBBPosition == 2, 'other posts BB');
    check(g.currentPlayer == 1, 'button first preflop, got ${g.currentPlayer}');
    conserve(g, 'A2');
  });

  scenario('A3 decimal blinds 0.25/0.50 stay exact', () {
    final g = build(sb: 0.25, bb: 0.5, stacks: {for (var i = 1; i <= 6; i++) i: 50});
    checkNear(g.currentPot, 0.75, 'pot');
    act(g, PlayerAction.call); // UTG
    checkNear(g.currentPot, 1.25, 'pot after call');
    check(formatBlindValue(0.25) == '0.25' && formatBlindValue(2) == '2',
        'formatBlindValue');
    conserve(g, 'A3');
  });

  scenario('A4 BB ante: pot includes the extra BB', () {
    final g = build(ante: true);
    checkNear(g.currentPot, 1 + 2 + 2, 'SB+BB+ante');
    check(g.currentBet == 2, 'currentBet stays one BB');
    conserve(g, 'A4');
  });

  scenario('A5 empty seats: 9-max, 5 active — blinds/turn skip inactive', () {
    final g = build(seats: 9, active: [1, 3, 5, 7, 9], button: 1);
    check(g.effectiveSBPosition == 3, 'SB skips seat 2, got ${g.effectiveSBPosition}');
    check(g.effectiveBBPosition == 5, 'BB skips seat 4, got ${g.effectiveBBPosition}');
    check(g.currentPlayer == 7, 'UTG = seat 7, got ${g.currentPlayer}');
    conserve(g, 'A5');
  });

  scenario('A6 3-handed: button is UTG preflop', () {
    final g = build(seats: 3, button: 1);
    check(g.effectiveSBPosition == 2 && g.effectiveBBPosition == 3, 'blind seats');
    check(g.currentPlayer == 1, 'button acts first 3-handed, got ${g.currentPlayer}');
  });

  scenario('A7 SB seat all-in for less while posting', () {
    final g = build(stacks: {2: 0.5}); // SB has half a blind
    check(p(g, 2).isAllIn, 'SB all-in posting');
    checkNear(p(g, 2).betThisRound, 0.5, 'partial SB post');
    conserve(g, 'A7');
  });

  scenario('A8 BB all-in for less: currentBet drops to posted amount', () {
    final g = build(stacks: {3: 1.0}); // BB has half a BB
    check(p(g, 3).isAllIn, 'BB all-in posting');
    checkNear(g.currentBet, 1.0, 'currentBet = short BB');
    conserve(g, 'A8');
  });

  // ── B. Betting semantics ────────────────────────────────────────────

  scenario('B1 preflop: BET invalid, RAISE valid', () {
    final g = build();
    check(!g.isValidAction(PlayerAction.bet), 'bet must be invalid preflop');
    check(g.isValidAction(PlayerAction.raise), 'raise must be valid preflop');
  });

  scenario('B2 preflop: UTG cannot check facing the BB', () {
    final g = build();
    check(!g.isValidAction(PlayerAction.check), 'check invalid facing BB');
  });

  scenario('B3 min-raise bookkeeping: raise to 6 makes min re-raise 10', () {
    final g = build();
    act(g, PlayerAction.raise, 6); // UTG raises to 6 (increment 4)
    checkNear(g.getMinimumRaise(), 10, 'min re-raise = 6+4');
    conserve(g, 'B3');
  });

  scenario('B4 call for less (short all-in call) caps at stack', () {
    final g = build(stacks: {5: 3});
    act(g, PlayerAction.raise, 20); // UTG(4) to 20
    act(g, PlayerAction.call); // seat 5 calls with only 3
    check(p(g, 5).isAllIn, 'short caller all-in');
    checkNear(p(g, 5).betThisRound, 3, 'called for stack only');
    conserve(g, 'B4');
  });

  scenario('B5 raise capped at stack (all-in for less than declared)', () {
    final g = build(stacks: {4: 10});
    act(g, PlayerAction.raise, 50); // UTG declares 50 with a 10 stack
    check(p(g, 4).isAllIn, 'raiser all-in');
    checkNear(p(g, 4).betThisRound, 10, 'raise capped at stack');
    checkNear(g.currentBet, 10, 'table bet = capped amount');
    conserve(g, 'B5');
  });

  scenario('B6 walk: all fold to BB ends the hand', () {
    final g = build();
    for (var i = 0; i < 5; i++) {
      final r = g.performAction(PlayerAction.fold);
      if (r.contains('Hand ends')) break;
    }
    final live = g.players.where((x) => x.isActive && !x.hasFolded).length;
    check(live == 1, 'only BB remains');
    check(g.bettingRoundComplete, 'round flagged complete');
    conserve(g, 'B6-walk');
  });

  scenario('B7 BB option: limps around, BB may check and round completes', () {
    final g = build();
    for (var i = 0; i < 5; i++) {
      act(g, PlayerAction.call); // UTG, MP, CO, BTN limp; SB completes
    }
    check(g.currentPlayer == 3, 'action on BB');
    check(g.isValidAction(PlayerAction.check), 'BB has the option');
    final r = act(g, PlayerAction.check);
    check(g.bettingRoundComplete, 'round complete after BB check: $r');
    conserve(g, 'B7');
  });

  scenario('B8 raise re-opens action for earlier callers', () {
    final g = build();
    act(g, PlayerAction.call); // UTG limps
    act(g, PlayerAction.raise, 8); // seat 5 raises
    check(!p(g, 4).hasCalledCurrentBet, 'limper must act again');
    check(!g.bettingRoundComplete, 'round not complete');
  });

  scenario('B9 postflop: bet valid, check valid before bet', () {
    final g = build(seats: 3, button: 1);
    act(g, PlayerAction.call); // BTN
    act(g, PlayerAction.call); // SB
    act(g, PlayerAction.check); // BB option
    check(g.bettingRoundComplete, 'preflop done');
    g.startNewStreet();
    check(g.currentRound == BettingRound.flop, 'on flop');
    check(g.isValidAction(PlayerAction.check), 'check ok postflop');
    check(g.isValidAction(PlayerAction.bet), 'bet ok postflop');
    check(!g.isValidAction(PlayerAction.raise), 'raise needs a bet first');
    conserve(g, 'B9');
  });

  scenario('B10 postflop first actor is SB (multiway)', () {
    final g = build(button: 1);
    for (var i = 0; i < 5; i++) {
      act(g, PlayerAction.call);
    }
    act(g, PlayerAction.check); // BB option
    g.startNewStreet();
    check(g.currentPlayer == 2, 'SB first postflop, got ${g.currentPlayer}');
  });

  // ── C. All-ins & side pots ──────────────────────────────────────────

  scenario('C1 two-way equal all-ins → ONE pot (no phantom side pot)', () {
    final g = build(seats: 2, button: 1, stacks: {1: 100, 2: 100});
    act(g, PlayerAction.raise, 100); // button jams
    act(g, PlayerAction.call); // BB calls all-in
    final pots = g.calculateSidePots();
    check(pots.length == 1, 'exactly one pot, got ${pots.length}: $pots');
    checkNear(pots.first.amount, 200, 'pot = both stacks');
    check(g.activeSidePots.isEmpty, 'no pills for a single pot');
    conserve(g, 'C1');
  });

  scenario('C2 three-way, two all-in sizes → main + one side pot', () {
    final g = build(seats: 3, button: 1, stacks: {1: 100, 2: 20, 3: 50});
    act(g, PlayerAction.raise, 100); // BTN jams 100
    act(g, PlayerAction.call); // SB all-in 20
    act(g, PlayerAction.call); // BB all-in 50
    g.processUncalledBetReturns(); // BTN's 50 overage comes back
    checkNear(p(g, 1).betThisRound, 50, 'BTN reduced to 50');
    final pots = g.calculateSidePots();
    check(pots.length == 2, 'main+side, got ${pots.length}: $pots');
    checkNear(pots[0].amount, 60, 'main 20×3');
    checkNear(pots[1].amount, 60, 'side (50-20)×2');
    check(pots[0].eligiblePlayers.length == 3, 'all eligible for main');
    check(!pots[1].eligiblePlayers.contains(2), 'short stack not in side');
    conserve(g, 'C2');
  });

  scenario('C3 folded dead money stays in pots, folder never eligible', () {
    final g = build(seats: 3, button: 1, stacks: {1: 100, 2: 30, 3: 100});
    act(g, PlayerAction.raise, 10); // BTN to 10
    act(g, PlayerAction.call); // SB calls 10
    act(g, PlayerAction.raise, 30); // BB to 30
    act(g, PlayerAction.call); // BTN calls 30
    act(g, PlayerAction.fold); // SB folds — 10 dead
    final pots = g.calculateSidePots();
    final sum = pots.fold(0.0, (s, x) => s + x.amount);
    checkNear(sum, 70, 'dead 10 kept (30+30+10)');
    for (final pot in pots) {
      check(!pot.eligiblePlayers.contains(2), 'folder not eligible');
    }
    conserve(g, 'C3');
  });

  scenario('C4 uncalled jam refund takes player OFF all-in', () {
    final g = build(seats: 2, button: 1, stacks: {1: 100, 2: 40});
    act(g, PlayerAction.raise, 100); // button jams 100
    check(p(g, 1).isAllIn, 'jammer all-in');
    act(g, PlayerAction.call); // BB calls all-in for 40
    final msg = g.processUncalledBetReturns();
    check(msg.isNotEmpty, 'refund happened');
    checkNear(p(g, 1).currentStack, 60, '60 returned');
    check(!p(g, 1).isAllIn, 'off all-in after refund');
    checkNear(g.currentPot, 80, 'pot 40×2');
    conserve(g, 'C4');
  });

  scenario('C5 auto-advance condition: all live players all-in', () {
    final g = build(seats: 3, button: 1, stacks: {1: 30, 2: 30, 3: 30});
    act(g, PlayerAction.raise, 30);
    act(g, PlayerAction.call);
    act(g, PlayerAction.call);
    check(g.shouldAutoAdvanceToShowdown(), 'must auto-advance');
  });

  scenario('C6 one live player NOT all-in vs jam → still auto-advance', () {
    final g = build(seats: 2, button: 1, stacks: {1: 50, 2: 200});
    act(g, PlayerAction.raise, 50); // jam
    act(g, PlayerAction.call); // covered call, not all-in
    check(!p(g, 2).isAllIn, 'caller has chips behind');
    check(g.shouldAutoAdvanceToShowdown(),
        'nobody can act — betting is closed');
  });

  scenario('C7 pills appear when a bet exceeds an all-in (HL-7 fix)', () {
    final g = build(seats: 3, button: 1, stacks: {1: 100, 2: 20, 3: 100});
    act(g, PlayerAction.raise, 60); // BTN 60
    act(g, PlayerAction.call); // SB all-in 20; BB still to act
    // HL-7: BTN's chips above the all-in start a side pot — show it now.
    // Pending BB is eligible (will match or fold; recalc runs every action).
    check(g.activeSidePots.length == 2,
        'main + forming side pot: ${g.activeSidePots}');
    checkNear(g.activeSidePots[0].amount, 42, 'main: 20+20+BB 2');
    checkNear(g.activeSidePots[1].amount, 40, 'side: BTN 40 over');
    conserve(g, 'C7');
  });

  scenario('C8 four-way, three all-in levels → 3 pots, correct eligibility', () {
    final g = build(seats: 4, button: 1, stacks: {1: 10, 2: 25, 3: 60, 4: 60});
    // order preflop (BTN=1): UTG=4 first
    act(g, PlayerAction.raise, 60); // seat 4 jams 60
    act(g, PlayerAction.call); // seat 1 (BTN) all-in 10
    act(g, PlayerAction.call); // seat 2 (SB) all-in 25
    act(g, PlayerAction.call); // seat 3 (BB) all-in 60
    final pots = g.calculateSidePots();
    check(pots.length == 3, '3 layered pots, got ${pots.length}: $pots');
    checkNear(pots[0].amount, 40, 'L1 10×4');
    checkNear(pots[1].amount, 45, 'L2 15×3');
    checkNear(pots[2].amount, 70, 'L3 35×2');
    check(pots[2].eligiblePlayers.length == 2, 'top pot: 3 & 4 only');
    conserve(g, 'C8');
  });

  // ── D. Street transitions & rollback ────────────────────────────────

  scenario('D1 street rollover moves betThisRound → totalContribution', () {
    final g = build(seats: 3, button: 1);
    act(g, PlayerAction.call);
    act(g, PlayerAction.call);
    act(g, PlayerAction.check);
    final potBefore = g.currentPot;
    g.startNewStreet();
    for (final pl in g.players.where((x) => x.isActive)) {
      checkNear(pl.betThisRound, 0, 'bets cleared');
      checkNear(pl.totalContribution, 2, 'contribution kept');
    }
    checkNear(g.currentPot, potBefore, 'pot survives street change');
    conserve(g, 'D1');
  });

  scenario('D2 snapshot → advance → restore = exact rollback', () {
    final g = build(seats: 3, button: 1, stacks: {1: 50, 2: 50, 3: 50});
    act(g, PlayerAction.call);
    act(g, PlayerAction.call);
    act(g, PlayerAction.check);
    final potBefore = g.currentPot;
    final playerBefore = g.currentPlayer;
    final betsBefore = g.players.map((x) => x.betThisRound).toList();
    g.snapshotBeforeStreetAdvance();
    g.startNewStreet(); // mutates round, bets, currentPlayer
    check(g.currentRound == BettingRound.flop, 'advanced');
    check(g.restoreFromStreetSnapshot(), 'restore succeeded');
    check(g.currentRound == BettingRound.preflop, 'round rolled back');
    checkNear(g.currentPot, potBefore, 'pot rolled back');
    check(g.currentPlayer == playerBefore, 'actor rolled back');
    for (var i = 0; i < g.players.length; i++) {
      checkNear(g.players[i].betThisRound, betsBefore[i], 'bets rolled back');
    }
    conserve(g, 'D2');
  });

  scenario('D3 restore with no snapshot returns false', () {
    final g = build();
    check(!g.restoreFromStreetSnapshot(), 'no snapshot → false');
  });

  scenario('D4 snapshot restores all-in flags too', () {
    final g = build(seats: 2, button: 1, stacks: {1: 20, 2: 100});
    act(g, PlayerAction.raise, 20); // jam
    act(g, PlayerAction.call);
    g.processUncalledBetReturns();
    g.snapshotBeforeStreetAdvance();
    final allInBefore = p(g, 1).isAllIn;
    g.startNewStreet();
    check(g.restoreFromStreetSnapshot(), 'restored');
    check(p(g, 1).isAllIn == allInBefore, 'all-in flag preserved');
    conserve(g, 'D4');
  });

  scenario('D5 side pots correct when built ACROSS streets', () {
    final g = build(seats: 3, button: 1, stacks: {1: 100, 2: 15, 3: 100});
    // preflop: everyone 10
    act(g, PlayerAction.raise, 10);
    act(g, PlayerAction.call);
    act(g, PlayerAction.call);
    g.startNewStreet();
    // flop: seat 2 jams remaining 5, others call 5
    check(g.currentPlayer == 2, 'SB first on flop');
    act(g, PlayerAction.bet, 5); // all-in
    check(p(g, 2).isAllIn, 'seat 2 all-in on flop');
    act(g, PlayerAction.call); // seat 3
    act(g, PlayerAction.call); // seat 1
    final pots = g.calculateSidePots();
    check(pots.length == 1, 'equal totals → one pot, got $pots');
    checkNear(pots.first.amount, 45, '15×3 across streets');
    conserve(g, 'D5');
  });

  scenario('D6 streetPots snapshot per completed street', () {
    final g = build(seats: 3, button: 1);
    act(g, PlayerAction.call);
    act(g, PlayerAction.call);
    act(g, PlayerAction.check);
    g.startNewStreet();
    checkNear(g.streetPots[BettingRound.preflop] ?? -1, 6, 'preflop pot recorded');
  });

  // ── E. Positions with gaps ──────────────────────────────────────────

  scenario('E1 position names use ACTIVE count, not seat count', () {
    final g = build(seats: 9, active: [1, 3, 5, 7, 9], button: 1);
    // 5 active: BTN(1) SB(3) BB(5) UTG(7) CO(9)
    check(g.getPlayerPositionName(7) == 'UTG', 'seat 7 is UTG, got ${g.getPlayerPositionName(7)}');
    check(g.getPlayerPositionName(9) == 'CO', 'seat 9 is CO, got ${g.getPlayerPositionName(9)}');
  });

  scenario('E2 full ring 6-max labels', () {
    final g = build(button: 1);
    check(g.getPlayerPositionName(1) == 'BTN', 'btn');
    check(g.getPlayerPositionName(2) == 'SB', 'sb');
    check(g.getPlayerPositionName(3) == 'BB', 'bb');
    check(g.getPlayerPositionName(4) == 'UTG', 'utg');
  });

  // ── F. Full-hand chip-conservation soak ─────────────────────────────

  scenario('F1 scripted messy hand conserves chips at every step', () {
    final g = build(seats: 5, button: 2, stacks: {1: 40, 2: 80, 3: 25, 4: 200, 5: 60});
    // BTN=2 → SB=3 BB=4, UTG=5
    final script = <void Function()>[
      () => act(g, PlayerAction.raise, 6), // 5
      () => act(g, PlayerAction.call), // 1
      () => act(g, PlayerAction.raise, 25), // 2 (BTN) 3-bets
      () => act(g, PlayerAction.call), // 3 (SB) all-in 25? stack 25-1=24 → short
      () => act(g, PlayerAction.fold), // 4 (BB)
      () => act(g, PlayerAction.call), // 5
      () => act(g, PlayerAction.call), // 1
    ];
    for (final step in script) {
      step();
      conserve(g, 'F1-step');
    }
    g.processUncalledBetReturns();
    conserve(g, 'F1-final');
    final pots = g.calculateSidePots();
    check(pots.isNotEmpty, 'pots exist');
  });

  }
