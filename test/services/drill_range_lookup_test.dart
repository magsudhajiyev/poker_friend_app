import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/drill_models.dart';
import 'package:poker_logger/services/coach_persona.dart';
import 'package:poker_logger/services/coach_voice_service.dart';
import 'package:poker_logger/services/drill_gto_charts.dart';
import 'package:poker_logger/services/drill_nash_pushfold.dart';
import 'package:poker_logger/services/drill_range_lookup.dart';

/// "Show range" resolver: every drill scenario maps to the same baseline
/// chart the grader judged against. Plus the coach-voice speech transform.
void main() {
  DrillDecisionContext ctx({
    required DrillScenario scenario,
    String pos = 'BTN',
    double stackBB = 100,
    bool anteMode = false,
    String openerPosGroup = '',
  }) =>
      DrillDecisionContext(
        handClass: 'A5s',
        positionGroup: pos,
        stackBB: stackBB,
        scenario: scenario,
        opener: null,
        openerPosGroup: openerPosGroup,
        limpers: const [],
        playersBehind: const [],
        toCallBB: 0,
        currentBetBB: 1,
        potBB: 1.5,
        raisesBeforeHero: 0,
        anteMode: anteMode,
      );

  group('DrillRangeLookup.chartFor', () {
    test('deep unopened cash → the RFI chart for the position', () {
      final chart =
          DrillRangeLookup.chartFor(ctx(scenario: DrillScenario.unopened));
      expect(chart.title, contains('BTN'));
      expect(chart.layers.single.kind, DrillRangeLayerKind.raise);
      expect(chart.layers.single.hands, DrillGtoCharts.openRange('BTN'));
    });

    test('nash regime unopened → the jam range at the nearest stack', () {
      final chart = DrillRangeLookup.chartFor(
          ctx(scenario: DrillScenario.unopened, stackBB: 15));
      expect(chart.title, contains('Jamming'));
      expect(chart.layers.single.hands,
          DrillNashPushfold.jamRange('BTN', 15));
    });

    test('nash regime facing action → call-vs-jam range', () {
      final chart = DrillRangeLookup.chartFor(
          ctx(scenario: DrillScenario.vsRaise, stackBB: 12, pos: 'BB'));
      expect(chart.layers.single.kind, DrillRangeLayerKind.call);
      expect(chart.layers.single.hands,
          DrillNashPushfold.callVsJamRange(12));
    });

    test('vsRaise deep → defend chart with 3-bet and call layers', () {
      final chart = DrillRangeLookup.chartFor(ctx(
          scenario: DrillScenario.vsRaise,
          pos: 'BB',
          openerPosGroup: 'CO'));
      expect(chart.layers.length, 2);
      expect(chart.layers[0].kind, DrillRangeLayerKind.raise);
      expect(chart.layers[1].kind, DrillRangeLayerKind.call);
      final expected = DrillGtoCharts.defendFor('BB', 'CO')!.$1;
      expect(chart.layers[0].hands, expected.threeBet);
      expect(chart.layers[1].hands, expected.call);
    });

    test('vs3betAsAggressor → 4-bet and call layers', () {
      final chart = DrillRangeLookup.chartFor(
          ctx(scenario: DrillScenario.vs3betAsAggressor, pos: 'CO'));
      expect(chart.layers[0].label, '4-bet');
      expect(chart.layers[0].hands,
          DrillGtoCharts.vs3betFor('CO').fourBet);
    });

    test('vs3betCold → tight continue chart, layers do not overlap', () {
      final chart = DrillRangeLookup.chartFor(
          ctx(scenario: DrillScenario.vs3betCold, pos: 'MP'));
      final raise = chart.layers[0].hands;
      final cont = chart.layers[1].hands;
      expect(raise.intersection(cont), isEmpty);
      expect({...raise, ...cont}, DrillGtoCharts.coldVs3betContinue);
    });

    test('ante SB open adds a Complete layer disjoint from the opens', () {
      final chart = DrillRangeLookup.chartFor(ctx(
          scenario: DrillScenario.unopened,
          pos: 'SB',
          stackBB: 40,
          anteMode: true));
      expect(chart.layers.length, 2);
      expect(chart.layers[1].label, 'Complete');
      expect(
          chart.layers[0].hands.intersection(chart.layers[1].hands), isEmpty);
    });

    test('every engine-producible scenario resolves to a non-empty chart',
        () {
      for (final scenario in DrillScenario.values) {
        for (final stack in [8.0, 25.0, 100.0]) {
          for (final ante in [false, true]) {
            final chart = DrillRangeLookup.chartFor(ctx(
                scenario: scenario,
                stackBB: stack,
                anteMode: ante,
                openerPosGroup: 'MP'));
            expect(chart.allHands, isNotEmpty,
                reason: '$scenario @ ${stack}BB ante=$ante');
          }
        }
      }
    });
  });

  group('CoachVoiceService.speakable', () {
    test('suited/offsuit hands become words', () {
      expect(CoachVoiceService.speakable('A5s is a standard open'),
          'ace five suited is a standard open');
      expect(CoachVoiceService.speakable('fold AKo here'),
          'fold ace king offsuit here');
    });

    test('pairs become pocket Xs', () {
      expect(CoachVoiceService.speakable('QQ is a 3-bet'),
          'pocket queens is a 3-bet');
      expect(CoachVoiceService.speakable('jam 99'), 'jam pocket nines');
    });

    test('bet sizes become big blinds; the BB position is untouched', () {
      expect(CoachVoiceService.speakable('raise to 2.5BB'),
          'raise to 2.5 big blinds');
      expect(CoachVoiceService.speakable('defend from the BB'),
          'defend from the BB');
    });

    test('plain prose passes through unchanged', () {
      const line = 'Good fold — the opener is tight here.';
      expect(CoachVoiceService.speakable(line), line);
    });

    test('percentages become full words, never spelled digits', () {
      expect(CoachVoiceService.speakable('hand is top 24%'),
          'hand is top twenty-four percent');
      expect(CoachVoiceService.speakable('GTO opens 7% here'),
          'GTO opens seven percent here');
      expect(CoachVoiceService.speakable('about a third (34%)'),
          'about a third (thirty-four percent)');
      expect(CoachVoiceService.speakable('3-bet 10.4% of hands'),
          '3-bet ten point four percent of hands');
      expect(CoachVoiceService.speakable('100%'), 'one hundred percent');
    });

    test('plain digit pairs are numbers, not hands', () {
      // '24%' once read as 'two four percent' — the regression this guards.
      expect(CoachVoiceService.speakable('top 24% of hands'),
          'top twenty-four percent of hands');
      expect(CoachVoiceService.speakable('fold 72 here'), 'fold 72 here');
      // Equal digit pairs stay pocket pairs; suffixed hands stay hands.
      expect(CoachVoiceService.speakable('22 is a jam'),
          'pocket twos is a jam');
      expect(CoachVoiceService.speakable('open 72o never'),
          'open seven two offsuit never');
      // Digit pairs before BB are sizes, not pocket pairs.
      expect(CoachVoiceService.speakable('raise to 22BB'),
          'raise to 22 big blinds');
    });

    test('spaced/worded suffix folds into the hand (no "seventy-two")', () {
      // '72 off' once read as "seventy-two off" — the writer's natural
      // English must still speak as two ranks.
      expect(CoachVoiceService.speakable('fold 72 off from the CO'),
          'fold seven two offsuit from the CO');
      expect(CoachVoiceService.speakable('72 offsuit is trash'),
          'seven two offsuit is trash');
      expect(CoachVoiceService.speakable('T9 suited flats'),
          'ten nine suited flats');
      expect(CoachVoiceService.speakable('A5 off is a fold'),
          'ace five offsuit is a fold');
      // Redundant glued+word collapses, not doubled.
      expect(CoachVoiceService.speakable('jam 72o offsuit'),
          'jam seven two offsuit');
      // Ordinary English with 'off' is untouched (no rank pair precedes it).
      expect(CoachVoiceService.speakable('that paid off nicely'),
          'that paid off nicely');
      expect(CoachVoiceService.speakable('take the night off'),
          'take the night off');
    });

    test('rank-x shorthand gets the rank name', () {
      expect(CoachVoiceService.speakable('A-x suited 3-bets here'),
          'ace-x suited 3-bets here');
      expect(CoachVoiceService.speakable('any Kx hand'), 'any king-x hand');
      expect(CoachVoiceService.speakable('Q-x is weaker'),
          'queen-x is weaker');
      // Plain words with x stay untouched.
      expect(CoachVoiceService.speakable('a flexible line'),
          'a flexible line');
    });

    test('spoken hand phrase is findable in the spoken line (glow sync)',
        () {
      const line = 'Nah, kid. fold was the move. A2o is too weak here.';
      final spoken = CoachVoiceService.speakable(line);
      final phrase = CoachVoiceService.speakable('A2o');
      expect(phrase, 'ace two offsuit');
      final frac = CoachPersonas.mentionFraction(spoken, phrase);
      expect(frac, isNotNull);
      expect(frac, greaterThan(0.3), reason: 'mention is past the lead');
    });
  });
}
