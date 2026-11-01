import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/screens/leak_detector_screen.dart';
import 'package:poker_logger/services/leak_engine.dart';
import 'package:poker_logger/services/leak_focus_store.dart';
import 'package:poker_logger/services/leak_report_service.dart';
import 'package:poker_logger/services/leak_snapshot_store.dart';
import 'package:poker_logger/widgets/leak_detector/unlock_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'leak_test_harness.dart';

Widget _screen({
  LeakReportLoader? loader,
  RangeShapeLoader? shape,
}) =>
    LeakDetectorScreen(
      loader: loader ?? () async => fakeBundle(),
      shapeLoader: shape ?? () async => fakeShape(),
    );

/// "Show N more" inside the unlock section (hands lists use the same copy).
final Finder _unlockMore = find.descendant(
    of: find.byType(UnlockSection), matching: find.text('Show 2 more'));

Future<void> _settle(WidgetTester t) async {
  await t.pumpAndSettle(const Duration(milliseconds: 100));
}

/// The tab list (a keyed ListView) for [tab]: leaks / ranges / health.
Finder _list(String tab) => find.byKey(PageStorageKey<String>('leak_tab_$tab'));

/// Scrolls [tab]'s list a few screens down, failing on any layout error.
Future<void> _scrollThrough(WidgetTester t,
    {int steps = 6, String tab = 'leaks'}) async {
  for (var i = 0; i < steps; i++) {
    await t.drag(_list(tab), const Offset(0, -260));
    await _settle(t);
    expectNoLayoutErrors(t);
  }
}

/// Scrolls [tab]'s list until [finder] is built and on screen.
Future<void> _reveal(WidgetTester t, Finder finder,
    {String tab = 'leaks'}) async {
  // Back to the top first: finders may sit above the current offset.
  await t.fling(_list(tab), const Offset(0, 4000), 8000);
  await _settle(t);
  await t.scrollUntilVisible(finder, 200,
      scrollable: find
          .descendant(of: _list(tab), matching: find.byType(Scrollable))
          .first);
  await t.ensureVisible(finder.first);
  await _settle(t);
}

Future<void> _openTab(WidgetTester t, String label) async {
  await t.tap(find.text(label));
  await _settle(t);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('no-overflow matrix', () {
    for (final size in const [kSmall, kPhone]) {
      for (final scale in const [1.0, 1.5, 2.0]) {
        final tag = '${size.width.toInt()}x${size.height.toInt()} x$scale';

        testWidgets('Leaks tab, every card expanded, $tag', (t) async {
          await pumpLeakApp(t, _screen(), size: size, scale: scale);
          await _settle(t);
          expectNoLayoutErrors(t);

          // Expand the other leaks and the unlock list, then scroll the lot.
          for (final title in ['Defending the big blind vs steals', kLongTitle]) {
            await _reveal(t, find.text(title));
            await t.tap(find.text(title));
            await _settle(t);
            expectNoLayoutErrors(t, 'expanding "$title"');
          }
          await _scrollThrough(t);
          await _reveal(t, _unlockMore);
          await t.tap(_unlockMore);
          await _settle(t);
          await _scrollThrough(t, steps: 3);
        });

        testWidgets('Ranges tab, $tag', (t) async {
          await pumpLeakApp(t, _screen(), size: size, scale: scale);
          await _settle(t);
          await _openTab(t, 'Ranges');
          expectNoLayoutErrors(t);
          expect(find.text('EP'), findsWidgets);
          await _scrollThrough(t, steps: 5, tab: 'ranges');
        });

        testWidgets('Health tab, $tag', (t) async {
          await LeakFocusStore.recordFixed(FixedLeak(
            findingId: 'x',
            title: 'Folding too much to 3-bets and some more words',
            startedAt: DateTime.now().subtract(const Duration(days: 9)),
            fixedAt: DateTime.now(),
            startValue: 0.8,
            fixedValue: 0.5,
          ));
          await pumpLeakApp(t, _screen(), size: size, scale: scale);
          await _settle(t);
          await _openTab(t, 'Health');
          expectNoLayoutErrors(t);
          expect(find.text('Healthy 0'), findsOneWidget);
          await _scrollThrough(t, steps: 6, tab: 'health');
        });
      }
    }
  });

  group('content', () {
    testWidgets('header says what matters; sections follow the new IA',
        (t) async {
      await pumpLeakApp(t, _screen());
      await _settle(t);
      expect(find.text('3 leaks to fix · 4 solid'), findsOneWidget);
      expect(find.text('Based on 240 hands · Updated just now'),
          findsOneWidget);
      expect(find.text('FIX FIRST'), findsOneWidget);
      await _reveal(t, find.text('ALSO DETECTED'));
      expect(find.text('ALSO DETECTED'), findsOneWidget);
      await _reveal(t, find.text('WHAT WE SAW'));
      // Hero (top leak) starts expanded; meaning is not the coach summary.
      expect(find.text('WHAT WE SAW'), findsOneWidget);
      expect(find.text('Your biggest leak is folding to 3-bets.'), findsNothing);
    });

    testWidgets('unlock shows only the nearest detector until "Show more"',
        (t) async {
      await pumpLeakApp(t, _screen());
      await _settle(t);
      await _reveal(t, find.text('UNLOCK WITH MORE HANDS'));
      expect(find.text('Locked detector 2'), findsOneWidget); // nearest
      expect(find.text('Locked detector 0'), findsNothing);
      expect(_unlockMore, findsOneWidget);
      await t.tap(_unlockMore);
      await _settle(t);
      expect(find.text('Locked detector 0'), findsOneWidget);
      expect(find.text('Show less'), findsWidgets);
    });

    testWidgets('since-last-visit news and per-card delta text', (t) async {
      // Previous visit: the top leak was healthy-ish and lower.
      final before = fakeReport();
      final tweaked = LeakReport(
        handsAnalyzed: 200,
        findings: [
          for (final f in before.findings)
            if (f.id == 'fold_to_3bet')
              finding('fold_to_3bet', f.title, value: 0.9)
            else
              f,
        ],
      );
      await LeakSnapshotStore.save(
          LeakSnapshot.fromReport(tweaked, DateTime.now()
              .subtract(const Duration(days: 3))));
      await pumpLeakApp(t, _screen());
      await _settle(t);
      expect(find.textContaining('since your last visit'), findsWidgets);
      expect(find.text('12pt closer to healthy since your last visit'),
          findsOneWidget);
      expect(find.textContaining('Last visit 3d ago'), findsOneWidget);
      await t.tap(find.textContaining('1 change'));
      await _settle(t);
      expect(find.textContaining('is improving · 90% → 78%'), findsOneWidget);
    });

    testWidgets('set focus persists and shows progress', (t) async {
      await pumpLeakApp(t, _screen());
      await _settle(t);
      await t.tap(find.text('Work on this'));
      await _settle(t);
      expect(find.text('YOUR FOCUS'), findsOneWidget);
      expect(find.textContaining('Day 1'), findsOneWidget);
      expect((await LeakFocusStore.loadFocus())?.findingId, 'fold_to_3bet');
      await t.tap(find.byIcon(Icons.close));
      await _settle(t);
      expect(await LeakFocusStore.loadFocus(), isNull);
      expect(find.text('FIX FIRST'), findsOneWidget);
    });

    testWidgets('ranges tab caps deviation chips and expands', (t) async {
      await pumpLeakApp(t, _screen(), size: kPhone);
      await _settle(t);
      await _openTab(t, 'Ranges');
      expect(find.text('RANGE SHAPE · OPENING'), findsOneWidget);
      await _reveal(t, find.text('Show all 10'), tab: 'ranges');
      expect(find.textContaining('×'), findsNWidgets(5));
      await t.tap(find.text('Show all 10'));
      await _settle(t);
      expect(find.textContaining('×'), findsNWidgets(10));
      expect(find.text('Show less'), findsOneWidget);
    });

    testWidgets('info button opens the merged disclaimer sheet', (t) async {
      await pumpLeakApp(t, _screen());
      await _settle(t);
      await _openTab(t, 'Ranges');
      await t.tap(find.byIcon(Icons.info_outline).first);
      await _settle(t);
      expect(find.text('About range shape'), findsOneWidget);
      expect(find.textContaining('directional, not a verdict'), findsOneWidget);
    });
  });

  group('states', () {
    testWidgets('0 hands shows the dedicated empty state', (t) async {
      await pumpLeakApp(
        t,
        _screen(
          loader: () async => const LeakReportBundle(
              LeakReport(findings: [], handsAnalyzed: 0), {}),
        ),
      );
      await _settle(t);
      expect(find.text('No hands to analyze yet'), findsOneWidget);
      expect(find.text('Log a hand'), findsOneWidget);
      expect(find.text('Leaks'), findsNothing); // no tabs without data
      expectNoLayoutErrors(t);
    });

    testWidgets('first-load error shows ErrorStateCard + working retry',
        (t) async {
      var calls = 0;
      await pumpLeakApp(
        t,
        _screen(loader: () async {
          if (calls++ == 0) throw Exception('boom');
          return fakeBundle();
        }),
      );
      await _settle(t);
      expect(find.text("Couldn't load your report"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expectNoLayoutErrors(t);
      await t.tap(find.text('Retry'));
      await _settle(t);
      expect(find.text('3 leaks to fix · 4 solid'), findsOneWidget);
    });

    testWidgets('failed refresh keeps the report and says so', (t) async {
      var calls = 0;
      await pumpLeakApp(
        t,
        _screen(loader: () async {
          if (calls++ > 0) throw Exception('offline');
          return fakeBundle();
        }),
      );
      await _settle(t);
      await t.fling(_list('leaks'), const Offset(0, 400), 1000);
      await _settle(t);
      expect(calls, 2);
      expect(find.text("Couldn't refresh. Showing your last report."),
          findsOneWidget);
      expect(find.text('3 leaks to fix · 4 solid'), findsOneWidget);
    });

    testWidgets('content is capped to a centred column on wide screens',
        (t) async {
      await pumpLeakApp(t, _screen(), size: const Size(1000, 900));
      await _settle(t);
      final w = t.getSize(find.text('FIX FIRST').first).width;
      expect(w, lessThan(600));
      final header = t.getRect(find.text('3 leaks to fix · 4 solid'));
      expect(header.left, greaterThan(150));
      expectNoLayoutErrors(t);
    });

    testWidgets('reduced motion renders the final state immediately',
        (t) async {
      t.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(t.platformDispatcher.clearAllTestValues);
      await pumpLeakApp(t, _screen());
      await t.pump();
      await t.pump();
      expect(find.text('3 leaks to fix · 4 solid'), findsOneWidget);
      expectNoLayoutErrors(t);
    });
  });
}
