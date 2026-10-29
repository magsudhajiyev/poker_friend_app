import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/coach_persona.dart';
import 'package:poker_logger/widgets/onboarding/coach_trio.dart';

void main() {
  testWidgets('tap picks persona and shows greeting', (tester) async {
    CoachPersona? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CoachTrio(
          selected: CoachPersonas.grinder,
          onPick: (p) => picked = p,
          tagsById: const {'grinder': 'a', 'professor': 'b', 'nova': 'c'},
          hint: 'Tap a coach',
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Tap a coach'), findsOneWidget);
    await tester.tap(find.text(CoachPersonas.nova.name));
    await tester.pump();
    expect(picked?.id, 'nova');
    expect(find.text('Tap a coach'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });
}
