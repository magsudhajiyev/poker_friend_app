import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/design_system/constants/colors.dart';
import 'package:poker_logger/widgets/turn_glow.dart';

void main() {
  test('turn glow is clearly stronger than the old 6-12 blur / 0.25-0.55 glow',
      () {
    final low = TurnGlow.shadows(0);
    final high = TurnGlow.shadows(1);
    // Old look: one shadow, blur 6..12, alpha 0.25..0.55, no spread.
    expect(low.first.blurRadius, greaterThanOrEqualTo(12));
    expect(low.first.color.a, greaterThanOrEqualTo(0.5));
    expect(low.first.spreadRadius, greaterThan(0));
    expect(high.first.blurRadius, greaterThan(low.first.blurRadius));
    expect(high.first.color.a, greaterThan(low.first.color.a));
    expect(high.first.spreadRadius, greaterThan(low.first.spreadRadius));
    expect(low.length, 2); // core + wide halo
    expect(high.last.blurRadius, greaterThan(low.first.blurRadius));
  });

  test('uses the amber design token and clamps the pulse value', () {
    expect(TurnGlow.color, AppColors.warningAmber);
    expect(TurnGlow.shadows(-3).first.blurRadius,
        TurnGlow.shadows(0).first.blurRadius);
    expect(TurnGlow.shadows(9).first.blurRadius,
        TurnGlow.shadows(1).first.blurRadius);
  });
}
