import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/drill_models.dart';
import 'package:poker_logger/services/drill_engine.dart';
import 'package:poker_logger/services/drill_grader.dart';
import 'package:poker_logger/services/drill_insights.dart';
import 'package:poker_logger/services/drill_gto_charts.dart';
import 'package:poker_logger/services/drill_nash_pushfold.dart';

/// GTO baseline validation: chart membership keyed by BOTH positions,
/// the chart-derived playability ordering (Chen retired from grading),
/// and the self-computed Nash push/fold tables. Validated headlessly
/// (16/16) against known reference spots; kept here for CI.



void check(bool c, String m) {
  if (!c) throw 'ASSERT: $m';
}

DrillVillainProfile prof({
  String name = 'V',
  double vpip = 24,
  double pfr = 17,
  double threeBet = 7,
  double fold3bet = 55,
  int hands = 250,
  String archetype = 'Regular',
}) =>
    DrillVillainProfile(
        opponentId: 'o_$name',
        name: name,
        handsObserved: hands,
        vpip: vpip,
        pfr: pfr,
        threeBet: threeBet,
        fold3bet: fold3bet,
        aggression: 50,
        archetype: archetype);

DrillDecisionContext ctx({
  required String hand,
  required String pos,
  double stack = 100,
  DrillScenario scenario = DrillScenario.unopened,
  DrillVillainProfile? opener,
  String openerPos = '',
  double toCall = 0,
  double bet = 1,
  int raises = 0,
}) =>
    DrillDecisionContext(
      handClass: hand,
      positionGroup: pos,
      stackBB: stack,
      scenario: scenario,
      opener: opener,
      openerPosGroup: openerPos,
      limpers: const [],
      playersBehind: const [],
      toCallBB: toCall,
      currentBetBB: bet,
      potBB: 1.5 + toCall,
      raisesBeforeHero: raises,
    );


void scenario(String name, void Function() body) => test(name, body);

void main() {
  // ── Chart membership: the reported bug class stays dead ────────────
  scenario('RFI: 55 opens from every position', () {
    for (final p in ['EP', 'MP', 'CO', 'BTN', 'SB']) {
      final r = DrillGrader.grade(ctx(hand: '55', pos: p), 'raise',
          raiseToBB: 2.5);
      check(r.gtoAction == 'raise', '55 opens from $p');
    }
  });

  scenario('RFI: 72o folds everywhere; A2o only on the BTN', () {
    for (final p in ['EP', 'MP', 'CO', 'BTN', 'SB']) {
      check(DrillGrader.grade(ctx(hand: '72o', pos: p), 'fold').gtoAction ==
          'fold', '72o folds $p');
    }
    check(DrillGrader.grade(ctx(hand: 'A2o', pos: 'BTN'), 'raise',
                raiseToBB: 2.5)
            .gtoAction ==
        'raise', 'A2o opens BTN');
    check(DrillGrader.grade(ctx(hand: 'A2o', pos: 'EP'), 'fold').gtoAction ==
        'fold', 'A2o folds EP');
  });

  // ── Opener position now matters (the big theory gap, closed) ───────
  scenario('vs-open: TT 3-bets BTN-vs-CO but only CALLS BTN-vs-EP', () {
    final vsCO = DrillGrader.grade(
        ctx(hand: 'TT', pos: 'BTN', scenario: DrillScenario.vsRaise,
            opener: prof(), openerPos: 'CO', toCall: 2.5, bet: 2.5, raises: 1),
        'raise', raiseToBB: 8);
    check(vsCO.gtoAction == 'raise', 'TT 3-bets vs CO, got ${vsCO.gtoAction}');
    final vsEP = DrillGrader.grade(
        ctx(hand: 'TT', pos: 'BTN', scenario: DrillScenario.vsRaise,
            opener: prof(), openerPos: 'EP', toCall: 2.5, bet: 2.5, raises: 1),
        'call');
    check(vsEP.gtoAction == 'call', 'TT flats vs EP, got ${vsEP.gtoAction}');
  });

  scenario('vs-open: suited connector beats offsuit broadway (Chen bug dead)',
      () {
    // BTN vs MP: 76s continues, KJo folds — Chen ordered these backwards
    final sc = DrillGrader.grade(
        ctx(hand: '76s', pos: 'BTN', scenario: DrillScenario.vsRaise,
            opener: prof(), openerPos: 'MP', toCall: 2.5, bet: 2.5, raises: 1),
        'call');
    check(sc.gtoAction == 'call', '76s continues BTN vs MP, got ${sc.gtoAction}');
    final kj = DrillGrader.grade(
        ctx(hand: 'KJo', pos: 'BTN', scenario: DrillScenario.vsRaise,
            opener: prof(), openerPos: 'MP', toCall: 2.5, bet: 2.5, raises: 1),
        'fold');
    check(kj.gtoAction == 'fold', 'KJo folds BTN vs MP, got ${kj.gtoAction}');
  });

  scenario('SB defends 3-bet-or-fold: AQs 3-bets, T9s folds vs CO', () {
    final aq = DrillGrader.grade(
        ctx(hand: 'AQs', pos: 'SB', scenario: DrillScenario.vsRaise,
            opener: prof(), openerPos: 'CO', toCall: 2.0, bet: 2.5, raises: 1),
        'raise', raiseToBB: 9);
    check(aq.gtoAction == 'raise', 'AQs 3-bets SB vs CO');
    final t9 = DrillGrader.grade(
        ctx(hand: 'T9s', pos: 'SB', scenario: DrillScenario.vsRaise,
            opener: prof(), openerPos: 'CO', toCall: 2.0, bet: 2.5, raises: 1),
        'fold');
    check(t9.gtoAction == 'fold', 'T9s folds SB vs CO (no flat range)');
  });

  // ── Vs 3-bet keyed by hero's opening seat ───────────────────────────
  scenario('vs-3bet: QQ 4-bets from BTN open but CALLS from EP open', () {
    final btn = DrillGrader.grade(
        ctx(hand: 'QQ', pos: 'BTN', scenario: DrillScenario.vs3betAsAggressor,
            opener: prof(), toCall: 5, bet: 7.5, raises: 2),
        'raise', raiseToBB: 18);
    check(btn.gtoAction == 'raise', 'QQ 4-bets from BTN, got ${btn.gtoAction}');
    final ep = DrillGrader.grade(
        ctx(hand: 'QQ', pos: 'EP', scenario: DrillScenario.vs3betAsAggressor,
            opener: prof(), toCall: 5, bet: 7.5, raises: 2),
        'call');
    check(ep.gtoAction == 'call', 'QQ calls from EP (KK+ 4-bets), got ${ep.gtoAction}');
  });

  // ── Playability ordering (replaces Chen) ────────────────────────────
  scenario('playability: 76s ranks above K9o and J8o', () {
    final sc = DrillGtoCharts.playabilityPercent('76s');
    check(sc < DrillGtoCharts.playabilityPercent('K9o'),
        '76s (${sc.toStringAsFixed(0)}%) above K9o');
    check(sc < DrillGtoCharts.playabilityPercent('J8o'), '76s above J8o');
  });

  scenario('widen adds suited playables before offsuit junk', () {
    final wide = DrillGtoCharts.widen(DrillGtoCharts.openRange('EP'), 8);
    check(wide.contains('54s'), 'widened EP contains 54s');
    check(!wide.contains('J8o'), 'widened EP does not contain J8o');
  });

  // ── Nash short-stack tables ──────────────────────────────────────────
  scenario('Nash: SB@10BB jam range is in the known 45–70% window', () {
    final jam = DrillNashPushfold.jamRange('SB', 10);
    final pct = DrillGtoCharts.coverageOf(jam);
    check(pct > 45 && pct < 70, 'SB@10 jam ${pct.toStringAsFixed(1)}%');
    check(jam.contains('A2s'), 'A2s always a jam at 10BB');
    check(!jam.contains('72o'), '72o not a jam at 10BB');
  });

  scenario('Nash: ranges tighten as stacks deepen', () {
    final j5 = DrillGtoCharts.coverageOf(DrillNashPushfold.jamRange('SB', 5));
    final j10 = DrillGtoCharts.coverageOf(DrillNashPushfold.jamRange('SB', 10));
    final j20 = DrillGtoCharts.coverageOf(DrillNashPushfold.jamRange('SB', 20));
    check(j5 > j10 && j10 > j20, 'monotone: $j5 > $j10 > $j20');
    final c5 = DrillGtoCharts.coverageOf(DrillNashPushfold.callVsJamRange(5));
    final c20 = DrillGtoCharts.coverageOf(DrillNashPushfold.callVsJamRange(20));
    check(c5 > c20, 'call range tightens with depth: $c5 > $c20');
  });

  scenario('Nash: earlier position jams tighter than SB at same stack', () {
    final sb = DrillGtoCharts.coverageOf(DrillNashPushfold.jamRange('SB', 10));
    final utg = DrillGtoCharts.coverageOf(DrillNashPushfold.jamRange('EP', 10));
    check(utg < sb, 'UTG (${utg.toStringAsFixed(1)}%) < SB (${sb.toStringAsFixed(1)}%)');
  });

  scenario('grader: unopened @12BB uses Nash tables (trace says so)', () {
    final r = DrillGrader.grade(
        ctx(hand: 'A5s', pos: 'SB', stack: 12), 'raise', raiseToBB: 12);
    check(r.trace.any((l) => l.contains('Nash push/fold')),
        'trace mentions Nash: ${r.trace}');
    check(r.gtoAction == 'raise', 'A5s jams SB@12BB');
  });

  scenario('grader: facing a jam @10BB uses Nash call table', () {
    final r = DrillGrader.grade(
        ctx(hand: 'KQs', pos: 'BB', stack: 10,
            scenario: DrillScenario.vsRaise, opener: prof(),
            openerPos: 'SB', toCall: 9, bet: 10, raises: 1),
        'call');
    check(r.trace.any((l) => l.contains('call-vs-jam')),
        'trace mentions Nash call: ${r.trace}');
    check(r.gtoAction == 'call', 'KQs calls a 10BB jam, got ${r.gtoAction}');
  });

  // ── Exploit layer still works on top of charts ───────────────────────
  scenario('exploit: foldy opener turns a GTO-fold into a 3-bet (diverge)', () {
    final foldy = prof(name: 'FoldyFred', fold3bet: 78);
    // A hand just outside the BTN-vs-CO 3-bet chart, first in the
    // playability-ordered widening frontier and the GTO call set: 88
    final r = DrillGrader.grade(
        ctx(hand: '88', pos: 'BTN', scenario: DrillScenario.vsRaise,
            opener: foldy, openerPos: 'CO', toCall: 2.5, bet: 2.5, raises: 1),
        'raise', raiseToBB: 8);
    check(r.gtoAction == 'call', 'GTO flats 88, got ${r.gtoAction}');
    check(r.exploitAction == 'raise',
        'exploit 3-bets vs 78% folder, got ${r.exploitAction}');
    check(r.explanation.contains('FoldyFred'), 'names the opponent');
    check(!r.linesAgree, 'lines diverge');
  });

  scenario('every grade carries a non-empty decision trace', () {
    final r = DrillGrader.grade(ctx(hand: 'AA', pos: 'BTN'), 'raise',
        raiseToBB: 2.5);
    check(r.trace.length >= 3, 'trace has steps: ${r.trace.length}');
    check(r.trace.first.contains('spot:'), 'trace starts with spot line');
  });

  // ── Engine smoke: full drill hand with trace logging ────────────────
  scenario('engine smoke: drill hand grades + prints trace via debugPrint', () {
    final seats = [
      const DrillSeat(seatNumber: 1, isHero: true),
      DrillSeat(seatNumber: 2, isHero: false, profile: prof(name: 'A')),
      DrillSeat(seatNumber: 3, isHero: false, profile: prof(name: 'B')),
    ];
    final e = DrillEngine(seats: seats, stackBB: 40);
    var update = e.startHand();
    var guard = 0;
    while (!update.handComplete && guard++ < 10) {
      if (update.awaitingHero) {
        update = e.applyHeroAction(
            update.heroTurn!.canCheck ? 'check' : 'fold');
        if (update.grade != null) {
          check(update.grade!.trace.isNotEmpty, 'engine-run grade has trace');
        }
      }
    }
    check(update.handComplete, 'hand completed');
  });


  // ── Insight engine: repeated read-less spots vary their teaching ────
  scenario('insights: same read-less spot gives varied explanations', () {
    DrillInsights.resetRotation();
    final seen = <String>{};
    for (var i = 0; i < 3; i++) {
      final r = DrillGrader.grade(ctx(hand: '55', pos: 'EP'), 'raise',
          raiseToBB: 2.5);
      seen.add(r.explanation);
      check(r.trace.any((l) => l.startsWith('insight: variant')),
          'trace records the chosen insight variant');
    }
    check(seen.length >= 2,
        'explanations vary: got ${seen.length} distinct of 3');
  });

  scenario('insights: opponent-read reasons keep the name (not templated)', () {
    final foldy = prof(name: 'FoldyFred', fold3bet: 78);
    final r = DrillGrader.grade(
        ctx(hand: '88', pos: 'BTN', scenario: DrillScenario.vsRaise,
            opener: foldy, openerPos: 'CO', toCall: 2.5, bet: 2.5, raises: 1),
        'raise', raiseToBB: 8);
    check(r.explanation.contains('FoldyFred'),
        'read-based explanation still names the opponent');
  });

  // ── Ante format: SB is complete-or-raise, not raise-or-fold ─────────
  scenario('ante SB: 65o completes (GTO call), fold is a mistake', () {
    DrillDecisionContext sb(bool ante) => DrillDecisionContext(
        handClass: '65o', positionGroup: 'SB', stackBB: 100,
        scenario: DrillScenario.unopened, opener: null,
        limpers: const [], playersBehind: [prof(name: 'BBguy')],
        toCallBB: 0.5, currentBetBB: 1, potBB: 2.5, raisesBeforeHero: 0,
        anteMode: ante);
    final call = DrillGrader.grade(sb(true), 'call');
    check(call.gtoAction == 'call', 'GTO completes 65o, got ${call.gtoAction}');
    check(call.grade == DrillGrade.correct, 'completing graded correct');
    final fold = DrillGrader.grade(sb(true), 'fold');
    check(fold.grade == DrillGrade.mistake, 'folding a completing hand = mistake');
    final raise = DrillGrader.grade(sb(true), 'raise', raiseToBB: 3);
    check(raise.grade == DrillGrade.ok, 'raise = acceptable low-freq mix (CLOSE)');
    // Cash stays raise-or-fold
    final cash = DrillGrader.grade(sb(false), 'fold');
    check(cash.gtoAction == 'fold', 'cash SB still folds 65o');
    check(cash.grade == DrillGrade.correct, 'cash fold graded correct');
  });

  scenario('ante RFI comes from engine data and out-widens the cash charts', () {
    // Engine MTT (ante) charts are wider than the curated cash baselines,
    // and much more so in late position (the old flat +3% was wrong there).
    for (final p in ['EP', 'MP', 'CO', 'BTN']) {
      final data = DrillGtoCharts.mttOpenRange(p, '100bb');
      check(data != null, 'engine RFI export exists for $p');
      final mtt = DrillGtoCharts.coverageOf(data!.$1);
      final cash = DrillGtoCharts.coverageOf(DrillGtoCharts.openRange(p));
      check(mtt > cash,
          '$p ante RFI ${mtt.toStringAsFixed(1)}% > cash ${cash.toStringAsFixed(1)}%');
    }
    final r = DrillGrader.grade(
        DrillDecisionContext(
            handClass: 'K7o', positionGroup: 'BTN', stackBB: 100,
            scenario: DrillScenario.unopened, opener: null,
            limpers: const [], playersBehind: const [],
            toCallBB: 0, currentBetBB: 1, potBB: 2.5, raisesBeforeHero: 0,
            anteMode: true),
        'raise', raiseToBB: 2.5);
    check(r.trace.any((l) => l.contains('engine MTT chart')),
        'ante trace cites the engine chart: ${r.trace}');
  });

  scenario('ante SB continue set matches the engine (~86%, folds ~14%)', () {
    final cov = DrillGtoCharts.mttSbContinueCoverage('100bb');
    check(cov > 80 && cov < 92,
        'SB continue coverage ${cov.toStringAsFixed(1)}% in engine window');
    check(DrillGtoCharts.sbCompletesMtt('65o', '100bb'), '65o completes');
    check(!DrillGtoCharts.sbCompletesMtt('72o', '100bb'), '72o still folds');
  });

  scenario('ante 40BB defend uses the real engine chart (no transform)', () {
    final r = DrillGrader.grade(
        DrillDecisionContext(
            handClass: 'TT', positionGroup: 'BTN', stackBB: 40,
            scenario: DrillScenario.vsRaise, opener: prof(),
            openerPosGroup: 'CO', limpers: const [], playersBehind: const [],
            toCallBB: 2.5, currentBetBB: 2.5, potBB: 4, raisesBeforeHero: 1,
            anteMode: true),
        'call');
    check(r.trace.any((l) => l.contains('engine data')),
        '40bb ante defend cites engine data: ${r.trace}');
    check(r.gtoAction != 'fold', 'TT continues BTN vs CO at 40bb ante');
  });
}
