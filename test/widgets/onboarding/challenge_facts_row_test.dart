import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/widgets/onboarding/challenge_facts_row.dart';

Widget _host({bool reduced = false, double scale = 1.0}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          disableAnimations: reduced,
          textScaler: TextScaler.linear(scale),
        ),
        child: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: ChallengeFactsRow(
              header: 'How it works',
              startDelay: Duration(milliseconds: 100),
              facts: [
                (Icons.today_rounded, '5 spots a day, the same for everyone'),
                (Icons.school_rounded, 'Your coach explains every line'),
                (Icons.bolt_rounded, 'One attempt per day. Make it count.'),
              ],
              bodies: [
                'Everyone plays the same hands.',
                'Learn why, not just what.',
                'No retries, so focus.',
              ],
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('renders 3 steps and settles with reduced motion', (t) async {
    await t.pumpWidget(_host(reduced: true));
    await t.pumpAndSettle();
    expect(find.byType(Icon), findsNWidgets(3));
    expect(find.text('Your coach explains every line'), findsOneWidget);
    final o = t.widget<Opacity>(find.byType(Opacity).first);
    expect(o.opacity, 1);
  });

  testWidgets('animated entrance ends fully visible', (t) async {
    await t.pumpWidget(_host());
    expect(t.widget<Opacity>(find.byType(Opacity).last).opacity, 0);
    await t.pumpAndSettle(const Duration(seconds: 3));
    for (final o in t.widgetList<Opacity>(find.byType(Opacity))) {
      expect(o.opacity, 1);
    }
  });

  testWidgets('no overflow at 320 px and text scale 1.3', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_host(reduced: true, scale: 1.3));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
