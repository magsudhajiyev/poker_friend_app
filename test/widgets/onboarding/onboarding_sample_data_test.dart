import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/widgets/onboarding/onboarding_sample_data.dart';

void main() {
  test('four rows, bounded, one You', () {
    final rows = OnboardingSampleData.rows();
    expect(rows.length, 4);
    expect(rows.where((r) => r.isYou).length, 1);
    for (final r in rows) {
      expect(r.accuracy, inInclusiveRange(0, 100));
    }
    expect(OnboardingSampleData.youBumpedAccuracy, inInclusiveRange(0, 100));
  });

  test('orders are sorted descending', () {
    for (final o in [
      OnboardingSampleData.initialOrder(),
      OnboardingSampleData.finalOrder(),
    ]) {
      for (var i = 1; i < o.length; i++) {
        expect(o[i - 1].accuracy >= o[i].accuracy, isTrue);
      }
    }
  });

  test('You moves from 4th to 1st', () {
    expect(OnboardingSampleData.youRank(OnboardingSampleData.initialOrder()), 4);
    expect(OnboardingSampleData.youRank(OnboardingSampleData.finalOrder()), 1);
  });

  test('deterministic', () {
    expect(
      OnboardingSampleData.finalOrder().map((r) => r.accuracy).toList(),
      OnboardingSampleData.finalOrder().map((r) => r.accuracy).toList(),
    );
  });
}
