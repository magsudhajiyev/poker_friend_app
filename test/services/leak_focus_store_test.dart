import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/leak_focus_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Focus goal + fixed-leaks shelf persistence (retention doc R2).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  LeakFocusGoal goal({String id = 'fold_to_3bet'}) => LeakFocusGoal(
        findingId: id,
        title: 'Folding to 3-bets after opening',
        startedAt: DateTime(2026, 10, 1),
        startValue: 0.18,
        startSampleCount: 14,
      );

  group('LeakFocusStore — focus goal', () {
    test('save/load/clear round-trip', () async {
      expect(await LeakFocusStore.loadFocus(), isNull);
      await LeakFocusStore.saveFocus(goal());
      final loaded = await LeakFocusStore.loadFocus();
      expect(loaded, isNotNull);
      expect(loaded!.findingId, 'fold_to_3bet');
      expect(loaded.startValue, 0.18);
      expect(loaded.startSampleCount, 14);
      expect(loaded.startedAt, DateTime(2026, 10, 1));
      await LeakFocusStore.clearFocus();
      expect(await LeakFocusStore.loadFocus(), isNull);
    });

    test('corrupt storage degrades to null, never throws', () async {
      SharedPreferences.setMockInitialValues(
          {'leak_focus_goal_v1': '{broken'});
      expect(await LeakFocusStore.loadFocus(), isNull);
    });
  });

  group('LeakFocusStore — fixed shelf', () {
    test('recordFixed appends newest-first AND clears the focus', () async {
      await LeakFocusStore.saveFocus(goal());
      await LeakFocusStore.recordFixed(FixedLeak(
        findingId: 'fold_to_3bet',
        title: 'Folding to 3-bets after opening',
        startedAt: DateTime(2026, 10, 1),
        fixedAt: DateTime(2026, 10, 24),
        startValue: 0.18,
        fixedValue: 0.41,
      ));
      await LeakFocusStore.recordFixed(FixedLeak(
        findingId: 'river_overfold',
        title: 'Folding vs river bets',
        startedAt: DateTime(2026, 11, 1),
        fixedAt: DateTime(2026, 11, 8),
        startValue: 0.70,
        fixedValue: 0.55,
      ));

      expect(await LeakFocusStore.loadFocus(), isNull,
          reason: 'fixing the goal must clear the focus slot');
      final shelf = await LeakFocusStore.loadFixed();
      expect(shelf.length, 2);
      expect(shelf.first.findingId, 'river_overfold',
          reason: 'newest first');
      expect(shelf.first.daysToFix, 7);
      expect(shelf.last.daysToFix, 23);
    });

    test('shelf survives a reload (persisted JSON round-trip)', () async {
      await LeakFocusStore.recordFixed(FixedLeak(
        findingId: 'a',
        title: 'A',
        startedAt: DateTime(2026, 10, 1),
        fixedAt: DateTime(2026, 10, 2),
        startValue: 0.1,
        fixedValue: 0.4,
      ));
      final shelf = await LeakFocusStore.loadFixed();
      expect(shelf.single.startValue, 0.1);
      expect(shelf.single.fixedValue, 0.4);
    });
  });
}
