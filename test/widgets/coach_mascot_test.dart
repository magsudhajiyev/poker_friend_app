import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/drill_models.dart';
import 'package:poker_logger/widgets/coach_mascot.dart';

/// Coach mascots: verdict → expression mapping and a paint smoke test over
/// every persona × expression (CustomPaint actually renders in widget
/// tests, so a drawing error here fails loudly instead of on device).
void main() {
  test('verdict → expression mapping', () {
    expect(CoachMascot.expressionFor(DrillGrade.correct),
        CoachExpression.happy);
    expect(CoachMascot.expressionFor(DrillGrade.ok), CoachExpression.ok);
    expect(CoachMascot.expressionFor(DrillGrade.mistake),
        CoachExpression.upset);
  });

  testWidgets('every persona renders every expression without errors',
      (tester) async {
    for (final persona in const ['grinder', 'professor', 'nova']) {
      for (final expression in CoachExpression.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: CoachMascot(
                personaId: persona,
                expression: expression,
                size: 60,
              ),
            ),
          ),
        );
        // Let one-shot reactions (bounce/shake) run to completion.
        await tester.pumpAndSettle();
        expect(find.byType(CoachMascot), findsOneWidget,
            reason: '$persona/$expression');
        expect(tester.takeException(), isNull,
            reason: '$persona/$expression painted cleanly');
      }
    }
  });

  testWidgets('reactions are one-shot — everything settles, nothing loops',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: CoachMascot(
            personaId: 'grinder',
            expression: CoachExpression.happy,
            size: 60,
          ),
        ),
      ),
    );
    // The bounce settles on its own; pumpAndSettle would hang forever if
    // any animation looped (the "constant wiggle" regression guard).
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });
}
