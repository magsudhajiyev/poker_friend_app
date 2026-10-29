import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/widgets/onboarding/streak_flame_strip.dart';

Widget _host({bool reduced = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: const Scaffold(
          body: StreakFlameStrip(
            header: 'h',
            caption: 'c',
            weekdayLetters: ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
            semanticsLabel: 's',
            startDelay: Duration(milliseconds: 100),
          ),
        ),
      ),
    );

Matrix4 _m(WidgetTester t) =>
    t.widget<Transform>(find.byKey(const Key('streakFlameTransform')))
        .transform
        .clone();

void main() {
  testWidgets('flame keeps flickering after the entrance', (t) async {
    await t.pumpWidget(_host());
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 2500));
    final a = _m(t);
    await t.pump(const Duration(milliseconds: 400));
    final b = _m(t);
    expect(a.storage, isNot(equals(b.storage)));
    await t.pump(const Duration(milliseconds: 400));
    expect(_m(t).storage, isNot(equals(b.storage)));
  });

  testWidgets('reduced motion: static flame, settles', (t) async {
    await t.pumpWidget(_host(reduced: true));
    await t.pumpAndSettle();
    final a = _m(t);
    await t.pump(const Duration(milliseconds: 400));
    expect(_m(t).storage, equals(a.storage));
  });
}
