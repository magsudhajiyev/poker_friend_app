import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/drill_models.dart';
import 'package:poker_logger/services/drill_grader.dart';
import 'package:poker_logger/services/drill_gto_charts.dart';

DrillVillainProfile prof({
  String name = 'V',
  double threeBet = 7,
  double fold3bet = 55,
  double aggression = 50,
  double steal = 28,
  double cbet = 65,
  double blindDefend = 35,
  double showdown = 28,
  double checkRaiseFlop = 8,
  int hands = 200,
  String archetype = 'Regular',
}) =>
    DrillVillainProfile(
      opponentId: 'opp_$name',
      name: name,
      handsObserved: hands,
      threeBet: threeBet,
      fold3bet: fold3bet,
      aggression: aggression,
      steal: steal,
      cbet: cbet,
      blindDefend: blindDefend,
      showdown: showdown,
      checkRaiseFlop: checkRaiseFlop,
      archetype: archetype,
    );

/// Grade a steal attempt from BTN vs a single blind defender.
DrillGradeResult gradeSteal({
  required String handClass,
  required DrillVillainProfile blindProfile,
  bool anteMode = false,
}) {
  final ctx = DrillDecisionContext(
    handClass: handClass,
    positionGroup: 'BTN',
    stackBB: 100,
    scenario: DrillScenario.unopened,
    opener: null,
    limpers: [],
    playersBehind: [blindProfile],
    behindDetail: [
      DrillSeatRef(
        profile: blindProfile,
        positionGroup: 'BB',
        isBlind: true,
        isDirectLeft: true,
      ),
    ],
    toCallBB: 0,
    currentBetBB: 1,
    potBB: 1.5,
    raisesBeforeHero: 0,
    anteMode: anteMode,
  );
  return DrillGrader.grade(ctx, 'raise', raiseToBB: 2.5);
}

/// Grade folding vs a single raise (defend / 3-bet scenario).
DrillGradeResult gradeDefend({
  required String handClass,
  required DrillVillainProfile openerProfile,
  String heroPos = 'BB',
  String openerPos = 'BTN',
  bool anteMode = false,
}) {
  final ctx = DrillDecisionContext(
    handClass: handClass,
    positionGroup: heroPos,
    stackBB: 100,
    scenario: DrillScenario.vsRaise,
    opener: openerProfile,
    openerPosGroup: openerPos,
    limpers: [],
    playersBehind: [],
    behindDetail: [],
    toCallBB: 2.5,
    currentBetBB: 2.5,
    potBB: 4.0,
    raisesBeforeHero: 1,
    anteMode: anteMode,
  );
  return DrillGrader.grade(ctx, 'fold');
}

/// Grade raising vs limpers from BTN.
DrillGradeResult gradeVsLimper({
  required String handClass,
  required DrillVillainProfile limperProfile,
  bool anteMode = false,
}) {
  final ctx = DrillDecisionContext(
    handClass: handClass,
    positionGroup: 'BTN',
    stackBB: 100,
    scenario: DrillScenario.vsLimpers,
    opener: null,
    limpers: [limperProfile],
    playersBehind: [],
    behindDetail: [],
    toCallBB: 1,
    currentBetBB: 1,
    potBB: 3.5,
    raisesBeforeHero: 0,
    anteMode: anteMode,
  );
  return DrillGrader.grade(ctx, 'raise', raiseToBB: 4.0);
}

/// Grade vs an all-in jam at short stacks.
DrillGradeResult gradeVsJam({
  required String handClass,
  required DrillVillainProfile jammerProfile,
  bool anteMode = false,
}) {
  final ctx = DrillDecisionContext(
    handClass: handClass,
    positionGroup: 'BB',
    stackBB: 15,
    scenario: DrillScenario.vsRaise,
    opener: jammerProfile,
    openerPosGroup: 'SB',
    limpers: [],
    playersBehind: [],
    behindDetail: [],
    toCallBB: 15,
    currentBetBB: 15,
    potBB: 16.5,
    raisesBeforeHero: 1,
    anteMode: anteMode,
  );
  return DrillGrader.grade(ctx, 'fold');
}

/// Helper: check whether any trace entry contains [substring].
bool traceContains(DrillGradeResult r, String substring) =>
    r.trace.any((t) => t.toLowerCase().contains(substring.toLowerCase()));

void main() {
  // ────────────────────────────────────────────────────────────────────
  group('Blind defense exploits — cash', () {
    test('tight blind (25%) triggers steal-relentlessly exploit', () {
      final r = gradeSteal(
        handClass: 'A2o',
        blindProfile: prof(blindDefend: 25),
      );
      expect(traceContains(r, 'steal relentlessly') ||
          r.exploitReason.toLowerCase().contains('steal relentlessly'), isTrue,
          reason: 'blind defend 25% < cash threshold 28% should trigger '
              '"steal relentlessly". Trace: ${r.trace}');
    });

    test('normal blind (29%) does NOT trigger steal-relentlessly exploit', () {
      final r = gradeSteal(
        handClass: 'A2o',
        blindProfile: prof(blindDefend: 29),
      );
      expect(traceContains(r, 'steal relentlessly'), isFalse,
          reason: 'blind defend 29% > cash threshold 28% must NOT trigger '
              '"steal relentlessly". Trace: ${r.trace}');
    });

    test('wide-defending blind (50%) triggers defends-wide exploit', () {
      final r = gradeSteal(
        handClass: 'A2o',
        blindProfile: prof(blindDefend: 50),
      );
      final triggered = traceContains(r, 'defends wide') ||
          traceContains(r, 'drop') ||
          r.exploitReason.toLowerCase().contains('defends wide') ||
          r.exploitReason.toLowerCase().contains('drop');
      expect(triggered, isTrue,
          reason: 'blind defend 50% >= cash threshold 50% should trigger '
              '"defends wide" or "drop". Trace: ${r.trace}');
    });

    test('moderately defending blind (49%) does NOT trigger defends-wide exploit', () {
      final r = gradeSteal(
        handClass: 'A2o',
        blindProfile: prof(blindDefend: 49),
      );
      expect(
          traceContains(r, 'wide-defending') ||
              r.exploitReason.toLowerCase().contains('defends wide'),
          isFalse,
          reason: 'blind defend 49% < cash threshold 50% must NOT trigger '
              '"defends wide". Trace: ${r.trace}');
    });
  });

  // ────────────────────────────────────────────────────────────────────
  group('Blind defense exploits — MTT', () {
    test('tight blind (30%) triggers steal-relentlessly in MTT', () {
      final r = gradeSteal(
        handClass: 'A2o',
        blindProfile: prof(blindDefend: 30),
        anteMode: true,
      );
      expect(traceContains(r, 'steal relentlessly') ||
          r.exploitReason.toLowerCase().contains('steal relentlessly'), isTrue,
          reason: 'blind defend 30% < MTT threshold 35% should trigger '
              '"steal relentlessly". Trace: ${r.trace}');
    });

    test('normal blind (36%) does NOT trigger steal-relentlessly in MTT', () {
      final r = gradeSteal(
        handClass: 'A2o',
        blindProfile: prof(blindDefend: 36),
        anteMode: true,
      );
      expect(traceContains(r, 'steal relentlessly'), isFalse,
          reason: 'blind defend 36% > MTT threshold 35% must NOT trigger '
              '"steal relentlessly". Trace: ${r.trace}');
    });

    test('wide-defending blind (60%) triggers defends-wide in MTT', () {
      final r = gradeSteal(
        handClass: 'A2o',
        blindProfile: prof(blindDefend: 60),
        anteMode: true,
      );
      final triggered = traceContains(r, 'defends wide') ||
          traceContains(r, 'drop') ||
          r.exploitReason.toLowerCase().contains('defends wide') ||
          r.exploitReason.toLowerCase().contains('drop');
      expect(triggered, isTrue,
          reason: 'blind defend 60% >= MTT threshold 60% should trigger '
              '"defends wide" or "drop". Trace: ${r.trace}');
    });

    test('moderately defending blind (59%) does NOT trigger defends-wide in MTT', () {
      final r = gradeSteal(
        handClass: 'A2o',
        blindProfile: prof(blindDefend: 59),
        anteMode: true,
      );
      expect(
          traceContains(r, 'wide-defending') ||
              r.exploitReason.toLowerCase().contains('defends wide'),
          isFalse,
          reason: 'blind defend 59% < MTT threshold 60% must NOT trigger '
              '"defends wide". Trace: ${r.trace}');
    });
  });

  // ────────────────────────────────────────────────────────────────────
  group('Station/limper detection', () {
    test('passive station behind (aggression 28, showdown 42) triggers station exploit', () {
      // Use an unopened spot with the station-like player behind (non-blind)
      final stationPlayer = prof(aggression: 28, showdown: 42, name: 'Station');
      final ctx = DrillDecisionContext(
        handClass: 'A9o',
        positionGroup: 'CO',
        stackBB: 100,
        scenario: DrillScenario.unopened,
        opener: null,
        limpers: [],
        playersBehind: [stationPlayer],
        behindDetail: [
          DrillSeatRef(
            profile: stationPlayer,
            positionGroup: 'BTN',
            isBlind: false,
            isDirectLeft: true,
          ),
        ],
        toCallBB: 0,
        currentBetBB: 1,
        potBB: 1.5,
        raisesBeforeHero: 0,
      );
      final r = DrillGrader.grade(ctx, 'raise', raiseToBB: 2.5);
      final triggered = traceContains(r, 'calls down passively') ||
          traceContains(r, 'station') ||
          traceContains(r, 'flop well') ||
          r.exploitReason.toLowerCase().contains('calls down passively') ||
          r.exploitReason.toLowerCase().contains('flop well');
      expect(triggered, isTrue,
          reason: 'aggression 28 <= 30 and showdown 42 >= 40 should trigger '
              'station exploit. Trace: ${r.trace}');
    });

    test('non-station behind (aggression 31, showdown 42) does NOT trigger station exploit', () {
      final nonStation = prof(aggression: 31, showdown: 42, name: 'Active');
      final ctx = DrillDecisionContext(
        handClass: 'A9o',
        positionGroup: 'CO',
        stackBB: 100,
        scenario: DrillScenario.unopened,
        opener: null,
        limpers: [],
        playersBehind: [nonStation],
        behindDetail: [
          DrillSeatRef(
            profile: nonStation,
            positionGroup: 'BTN',
            isBlind: false,
            isDirectLeft: true,
          ),
        ],
        toCallBB: 0,
        currentBetBB: 1,
        potBB: 1.5,
        raisesBeforeHero: 0,
      );
      final r = DrillGrader.grade(ctx, 'raise', raiseToBB: 2.5);
      expect(traceContains(r, 'calls down'), isFalse,
          reason: 'aggression 31 > 30 must NOT trigger station exploit. '
              'Trace: ${r.trace}');
    });

    test('passive limper (aggression 28, showdown 36) triggers isolate-wide exploit', () {
      final r = gradeVsLimper(
        handClass: 'KTo',
        limperProfile: prof(aggression: 28, showdown: 36, name: 'Limpy'),
      );
      final triggered = traceContains(r, 'isolate wide') ||
          traceContains(r, 'limps') ||
          traceContains(r, 'loose-passive limper') ||
          r.exploitReason.toLowerCase().contains('isolate wide') ||
          r.exploitReason.toLowerCase().contains('limps');
      expect(triggered, isTrue,
          reason: 'aggression 28 <= 30 and showdown 36 >= 35 should trigger '
              'limper exploit. Trace: ${r.trace}');
    });

    test('active limper (aggression 31, showdown 36) does NOT trigger isolate exploit', () {
      final r = gradeVsLimper(
        handClass: 'KTo',
        limperProfile: prof(aggression: 31, showdown: 36, name: 'Active'),
      );
      expect(traceContains(r, 'isolate') || traceContains(r, 'loose-passive'),
          isFalse,
          reason: 'aggression 31 > 30 must NOT trigger limper exploit. '
              'Trace: ${r.trace}');
    });
  });

  // ────────────────────────────────────────────────────────────────────
  group('Opener steal-based exploits — cash vs MTT', () {
    test('cash: loose opener (steal 42%) triggers opens-loose exploit', () {
      final r = gradeDefend(
        handClass: 'K8o',
        openerProfile: prof(steal: 42),
      );
      final triggered = traceContains(r, 'opens loose') ||
          traceContains(r, 'loose opener') ||
          r.exploitReason.toLowerCase().contains('opens loose') ||
          r.exploitReason.toLowerCase().contains('steal');
      expect(triggered, isTrue,
          reason: 'steal 42% >= cash looseSteal 42% should trigger '
              '"opens loose". Trace: ${r.trace}');
    });

    test('MTT: opener with steal 42% does NOT trigger opens-loose exploit', () {
      final r = gradeDefend(
        handClass: 'K8o',
        openerProfile: prof(steal: 42),
        anteMode: true,
      );
      expect(
          traceContains(r, 'loose opener') ||
              r.exploitReason.toLowerCase().contains('opens loose'),
          isFalse,
          reason: 'steal 42% < MTT looseSteal 52% must NOT trigger '
              '"opens loose". Trace: ${r.trace}');
    });

    test('cash: tight nit opener (steal 18%, 3bet 3%) triggers respect exploit', () {
      final r = gradeDefend(
        handClass: 'K8o',
        openerProfile: prof(steal: 18, threeBet: 3),
      );
      final triggered = traceContains(r, 'respect') ||
          traceContains(r, 'tight') ||
          traceContains(r, 'nitty') ||
          r.exploitReason.toLowerCase().contains('respect') ||
          r.exploitReason.toLowerCase().contains('tight');
      expect(triggered, isTrue,
          reason: 'steal 18% <= tightSteal+4=22% and 3bet 3% <= nitThreeBet 3.5% '
              'should trigger "respect/tight". Trace: ${r.trace}');
    });

    test('cash: maniac opener (steal 55%, aggression 62%) triggers aggressive exploit', () {
      final r = gradeDefend(
        handClass: 'K8o',
        openerProfile: prof(steal: 55, aggression: 62),
      );
      final triggered = traceContains(r, 'aggressively') ||
          traceContains(r, 'maniac') ||
          traceContains(r, 'play back') ||
          r.exploitReason.toLowerCase().contains('aggressively') ||
          r.exploitReason.toLowerCase().contains('play back');
      expect(triggered, isTrue,
          reason: 'steal 55% >= maniacSteal 55% and aggression 62% >= 60% '
              'should trigger aggressive/maniac exploit. Trace: ${r.trace}');
    });

    test('MTT: opener (steal 55%, aggression 62%) does NOT trigger maniac exploit', () {
      final r = gradeDefend(
        handClass: 'K8o',
        openerProfile: prof(steal: 55, aggression: 62),
        anteMode: true,
      );
      // In MTT, maniacSteal is 65, so 55% should not trigger the maniac line
      expect(
          traceContains(r, 'maniac opener') ||
              r.exploitReason.toLowerCase().contains('aggressively'),
          isFalse,
          reason: 'steal 55% < MTT maniacSteal 65% must NOT trigger '
              'maniac/aggressively exploit. Trace: ${r.trace}');
    });
  });

  // ────────────────────────────────────────────────────────────────────
  group('Jammer exploits', () {
    test('maniac jammer (steal 55%, aggression 62%) triggers maniac-jammer exploit', () {
      final r = gradeVsJam(
        handClass: 'A9o',
        jammerProfile: prof(steal: 55, aggression: 62),
      );
      expect(traceContains(r, 'maniac jammer'), isTrue,
          reason: 'steal 55% >= cash maniacSteal 55% and aggression 62% >= 60% '
              'should trigger maniac jammer. Trace: ${r.trace}');
    });

    test('nit jammer (steal 15%, 3bet 3%) triggers nit-jammer exploit', () {
      final r = gradeVsJam(
        handClass: 'A9o',
        jammerProfile: prof(steal: 15, threeBet: 3),
      );
      expect(traceContains(r, 'nit jammer'), isTrue,
          reason: 'steal 15% <= cash tightSteal 18% and 3bet 3% <= nitThreeBet 3.5% '
              'should trigger nit jammer. Trace: ${r.trace}');
    });
  });

  // ────────────────────────────────────────────────────────────────────
  group('3-bet exploits (unchanged, opportunity-based)', () {
    test('opener folding to 3bets 65% triggers 3-bet-relentlessly exploit', () {
      final r = gradeDefend(
        handClass: 'K8o',
        openerProfile: prof(fold3bet: 65),
      );
      final triggered = traceContains(r, '3-bet') &&
          (traceContains(r, 'relentlessly') ||
              r.exploitReason.toLowerCase().contains('relentlessly'));
      expect(triggered, isTrue,
          reason: 'fold3bet 65% >= 60% should trigger "3-bet relentlessly". '
              'Trace: ${r.trace}');
    });

    test('wide 3-bettor (threeBet 11%) triggers continue-lighter exploit', () {
      // Build a vs-3bet scenario where the hero opened and is now facing a 3-bet
      final threeBettor = prof(threeBet: 11, name: '3Bettor');
      final ctx = DrillDecisionContext(
        handClass: 'ATo',
        positionGroup: 'CO',
        stackBB: 100,
        scenario: DrillScenario.vs3betAsAggressor,
        opener: threeBettor,
        limpers: [],
        playersBehind: [],
        behindDetail: [],
        toCallBB: 7.5,
        currentBetBB: 9,
        potBB: 13.5,
        raisesBeforeHero: 2,
      );
      final r = DrillGrader.grade(ctx, 'fold');
      final triggered = traceContains(r, 'continue lighter') ||
          traceContains(r, '4-bet') ||
          traceContains(r, 'wide 3-bettor') ||
          r.exploitReason.toLowerCase().contains('continue lighter') ||
          r.exploitReason.toLowerCase().contains('4-bet');
      expect(triggered, isTrue,
          reason: 'threeBet 11% >= 9% should trigger "continue lighter" or '
              '"4-bet". Trace: ${r.trace}');
    });
  });

  // ────────────────────────────────────────────────────────────────────
  group('Profile priors', () {
    test('cashPrior has correct values', () {
      final c = DrillVillainProfile.cashPrior;
      expect(c.steal, 28);
      expect(c.blindDefend, 35);
      expect(c.threeBet, 6);
      expect(c.fold3bet, 58);
      expect(c.aggression, 45);
      expect(c.cbet, 65);
      expect(c.showdown, 28);
      expect(c.checkRaiseFlop, 8);
    });

    test('mttPrior has correct values', () {
      final m = DrillVillainProfile.mttPrior;
      expect(m.steal, 38);
      expect(m.blindDefend, 45);
      expect(m.threeBet, 8);
      expect(m.fold3bet, 52);
      expect(m.aggression, 52);
      expect(m.cbet, 62);
      expect(m.showdown, 26);
      expect(m.checkRaiseFlop, 9);
    });

    test('prior(anteMode: false) returns cashPrior', () {
      final p = DrillVillainProfile.prior(anteMode: false);
      expect(p.steal, DrillVillainProfile.cashPrior.steal);
      expect(p.threeBet, DrillVillainProfile.cashPrior.threeBet);
      expect(p.blindDefend, DrillVillainProfile.cashPrior.blindDefend);
    });

    test('prior(anteMode: true) returns mttPrior', () {
      final p = DrillVillainProfile.prior(anteMode: true);
      expect(p.steal, DrillVillainProfile.mttPrior.steal);
      expect(p.threeBet, DrillVillainProfile.mttPrior.threeBet);
      expect(p.blindDefend, DrillVillainProfile.mttPrior.blindDefend);
    });

    test('limpRate for cashPrior produces a sane value (~5%)', () {
      final rate = DrillVillainProfile.cashPrior.limpRate;
      // cashPrior: aggression=45, showdown=28
      // passivity = 100-45 = 55, showdownExcess = max(28-28,0) = 0
      // limpRate = 55*0.10 + 0*0.5 = 5.5
      expect(rate, greaterThanOrEqualTo(3));
      expect(rate, lessThanOrEqualTo(8));
    });

    test('defendRate for cashPrior produces a sane value (~4%)', () {
      final rate = DrillVillainProfile.cashPrior.defendRate;
      // cashPrior: aggression=45, showdown=28
      // passivity = 55, showdownExcess = 0
      // defendRate = 55*0.08 + 0*0.4 = 4.4
      expect(rate, greaterThanOrEqualTo(3));
      expect(rate, lessThanOrEqualTo(7));
    });
  });
}
