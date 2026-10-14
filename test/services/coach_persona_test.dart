import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:poker_logger/models/drill_models.dart';
import 'package:poker_logger/services/coach_persona.dart';

/// Coach personas (Tier 1): character leads wrap the grader's factual
/// reason without changing the coaching content; rotation is deterministic;
/// selection persists.
void main() {
  DrillGradeResult grade({
    DrillGrade g = DrillGrade.correct,
    String recommended = 'raise',
    String reason = 'A5s is a standard button open.',
    String gtoAction = 'raise',
    String exploitAction = 'raise',
  }) =>
      DrillGradeResult(
        grade: g,
        heroAction: 'raise',
        recommendedAction: recommended,
        explanation: 'Correct — raise. $reason',
        headlineReason: reason,
        gtoAction: gtoAction,
        exploitAction: exploitAction,
      );

  group('persona roster', () {
    test('every persona covers every verdict tier with variety', () {
      for (final p in CoachPersonas.all) {
        expect(p.correctLeads.length, greaterThanOrEqualTo(3),
            reason: '${p.id} correct leads');
        expect(p.okLeads.length, greaterThanOrEqualTo(3));
        expect(p.mistakeLeads.length, greaterThanOrEqualTo(3));
        expect(p.greeting, isNotEmpty);
      }
      expect(CoachPersonas.all.map((p) => p.id).toSet().length,
          CoachPersonas.all.length);
    });

    test('byId resolves and falls back to the default', () {
      expect(CoachPersonas.byId('nova').name, 'Nova');
      expect(CoachPersonas.byId('nonsense').id, CoachPersonas.grinder.id);
      expect(CoachPersonas.byId(null).id, CoachPersonas.grinder.id);
      // Retired persona ids (e.g. a persisted 'rocket' selection) resolve
      // to the default instead of crashing.
      expect(CoachPersonas.byId('rocket').id, CoachPersonas.grinder.id);
    });
  });

  group('compose', () {
    test('lead mentions the recommended action, reason is kept verbatim',
        () {
      for (final p in CoachPersonas.all) {
        final line = p.compose(grade(g: DrillGrade.mistake, recommended: 'fold'),
            0);
        expect(line.toLowerCase(), contains('fold'),
            reason: '${p.id} lead names the action');
        expect(line, contains('A5s is a standard button open.'),
            reason: '${p.id} keeps the grader reason untouched');
      }
    });

    test('rotation is deterministic and varies with the decision index', () {
      final p = CoachPersonas.professor;
      final a0 = p.compose(grade(), 0);
      final a0again = p.compose(grade(), 0);
      final a1 = p.compose(grade(), 1);
      expect(a0, a0again, reason: 'same index → same line (shared puzzle)');
      expect(a0, isNot(a1), reason: 'next decision → next lead variant');
    });

    test('divergence note appended only when GTO and exploit disagree', () {
      final p = CoachPersonas.nova;
      final agree = p.compose(grade(), 0);
      expect(agree.contains('Pure GTO'), isFalse);
      final diverge = p.compose(
          grade(gtoAction: 'fold', exploitAction: 'raise'), 0);
      expect(diverge, contains('Pure GTO would fold'));
    });

    test('aiLine IS the whole line — no template lead, no grader reason',
        () {
      final p = CoachPersonas.professor;
      const ai = 'Correct open. A5s sits comfortably in your button range.';
      final line = p.compose(grade(), 0, aiLine: ai);
      expect(line, ai, reason: 'the AI line is used verbatim');
      expect(line, isNot(contains('A5s is a standard button open')));
    });

    test('empty/null aiLine falls back to the template lead + reason', () {
      final p = CoachPersonas.professor;
      final withNull = p.compose(grade(), 0, aiLine: null);
      final withEmpty = p.compose(grade(), 0, aiLine: '   ');
      expect(withNull, contains('A5s is a standard button open'));
      expect(withEmpty, contains('A5s is a standard button open'));
    });

    test('aiLine suppresses the raw GTO-divergence note', () {
      final p = CoachPersonas.professor;
      final line = p.compose(
          grade(gtoAction: 'fold', exploitAction: 'raise'), 0,
          aiLine: 'Against this table, raising prints.');
      expect(line.contains('Pure GTO would'), isFalse);
    });

    test('falls back to explanation when headlineReason is absent (legacy)',
        () {
      const legacy = DrillGradeResult(
        grade: DrillGrade.correct,
        heroAction: 'fold',
        recommendedAction: 'fold',
        explanation: 'Correct — folding is right, the opener is tight.',
      );
      final line = CoachPersonas.grinder.compose(legacy, 0);
      expect(line, contains('the opener is tight'));
    });
  });

  group('mentionFraction (card-highlight timing)', () {
    test('returns the position of the hand mention as a fraction', () {
      const line = 'Nah, kid. fold was the move. A2o is too weak here.';
      final frac = CoachPersonas.mentionFraction(line, 'A2o');
      expect(frac, closeTo(line.indexOf('A2o') / line.length, 0.001));
    });

    test('returns null when the line does not name the hand', () {
      expect(
          CoachPersonas.mentionFraction('Good fold here.', 'A2o'), isNull);
      expect(CoachPersonas.mentionFraction('', 'A2o'), isNull);
      expect(CoachPersonas.mentionFraction('A2o opens', ''), isNull);
    });

    test('mention at the start gives fraction zero', () {
      expect(CoachPersonas.mentionFraction('QQ is a 3-bet.', 'QQ'), 0.0);
    });
  });

  group('persistence', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('save → load round-trips; empty prefs give the default', () async {
      SharedPreferences.setMockInitialValues({});
      expect((await CoachPersonas.load()).id, CoachPersonas.grinder.id);
      await CoachPersonas.save(CoachPersonas.nova);
      expect((await CoachPersonas.load()).id, 'nova');
    });
  });
}
