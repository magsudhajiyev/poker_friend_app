import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/leak_engine.dart';
import 'package:poker_logger/services/leak_focus_store.dart';
import 'package:poker_logger/widgets/leak_detector/leak_card.dart';
import 'package:poker_logger/widgets/leak_detector/leak_detail.dart';
import 'package:poker_logger/widgets/leak_detector/leak_format.dart';
import 'package:poker_logger/widgets/playing_card_face.dart';

import 'leak_test_harness.dart';

Widget _card(
  LeakFinding f, {
  bool emphasis = false,
  bool expanded = false,
  LeakCardActions? actions,
  LeakFocusGoal? focus,
  LeakDelta? delta,
  Map<String, Map<String, dynamic>>? hands,
}) =>
    Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LeakCard(
            finding: f,
            emphasis: emphasis,
            initiallyExpanded: expanded,
            focus: focus,
            delta: delta,
            handsByRef: hands ?? fakeBundle().handsByRef,
            actions: actions ?? LeakCardActions(onShowBandInfo: () {}),
          ),
        ],
      ),
    );

LeakFinding _top() => fakeReport().findings.first;

void main() {
  testWidgets('collapsed card shows title, severity word + icon, caption',
      (t) async {
    await pumpLeakApp(t, _card(_top()));
    expect(find.text('Folding too much to 3-bets'), findsOneWidget);
    // Severity is a word AND an icon, not colour alone.
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.textContaining('You 78% · Healthy 45%–65%'), findsOneWidget);
    expect(find.textContaining('60 spots'), findsOneWidget);
    // Detail is not built while collapsed.
    expect(find.text('WHAT WE SAW'), findsNothing);
  });

  testWidgets('emerging leak uses the warning icon and word', (t) async {
    final f = finding('x', 'Emerging one',
        verdict: LeakVerdict.emerging, value: 0.7);
    await pumpLeakApp(t, _card(f));
    expect(find.text('Emerging'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('tap expands in place and collapses again; reports intent',
      (t) async {
    final toggles = <bool>[];
    await pumpLeakApp(
        t,
        _card(_top(),
            actions: LeakCardActions(
                onShowBandInfo: () {}, onToggle: toggles.add)));
    await t.tap(find.text('Folding too much to 3-bets'));
    await t.pumpAndSettle();
    expect(find.text('WHAT WE SAW'), findsOneWidget);
    expect(find.text('WHAT IT COSTS'), findsOneWidget);
    expect(find.text('THE FIX'), findsOneWidget);
    expect(find.text('BY POSITION'), findsOneWidget);
    expect(find.text('YOUR HANDS (5)'), findsOneWidget);

    await t.tap(find.text('Folding too much to 3-bets'));
    await t.pumpAndSettle();
    expect(find.text('WHAT WE SAW'), findsNothing);
    expect(toggles, [true, false]);
    expectNoLayoutErrors(t);
  });

  testWidgets('title wraps to at most two lines', (t) async {
    final f = finding('x', kLongTitle);
    await pumpLeakApp(t, _card(f), size: kSmall, scale: 1.5);
    final title = t.widget<Text>(find.text(kLongTitle));
    expect(title.maxLines, 2);
    expectNoLayoutErrors(t);
  });

  testWidgets('emphasis shows meaning collapsed and hides it when expanded',
      (t) async {
    await pumpLeakApp(t, _card(_top(), emphasis: true));
    expect(find.textContaining('You fold to a 3-bet far more'), findsOneWidget);
    expect(find.text('Your biggest leak is folding to 3-bets.'), findsNothing);
    await t.tap(find.text('Folding too much to 3-bets'));
    await t.pumpAndSettle();
    // Now only the labelled "What we saw" block carries the meaning.
    expect(find.textContaining('You fold to a 3-bet far more'), findsOneWidget);
    expect(find.text('WHAT WE SAW'), findsOneWidget);
  });

  testWidgets('example hands: 3 shown, Show more reveals the rest, '
      'unavailable hand is disabled with a label', (t) async {
    await pumpLeakApp(t, _card(_top(), expanded: true), size: kPhone);
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Show 2 more'));
    await t.pumpAndSettle();
    expect(find.text('Hand no longer available'), findsNothing);
    await t.tap(find.text('Show 2 more'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Hand no longer available'));
    await t.pumpAndSettle();
    expect(find.text('Hand no longer available'), findsOneWidget);
    expect(find.text('Show less'), findsOneWidget);
    expect(find.byType(PlayingCardFace), findsWidgets);
    expectNoLayoutErrors(t);
  });

  testWidgets('every interactive target in an expanded card is >= 44px',
      (t) async {
    await pumpLeakApp(
        t,
        _card(_top(),
            emphasis: true,
            expanded: true,
            actions: LeakCardActions(
              onShowBandInfo: () {},
              onSetFocus: () {},
              onReviewAll: (_) {},
              onOpenHand: (_, __) {},
              onPractice: () {},
              onSeeHands: () {},
            )));
    await t.pumpAndSettle();
    final finders = [
      find.byType(InkWell),
      find.byType(TextButton),
      find.byType(IconButton),
    ];
    var checked = 0;
    for (final finder in finders) {
      for (var i = 0; i < finder.evaluate().length; i++) {
        final h = t.getSize(finder.at(i)).height;
        expect(h, greaterThanOrEqualTo(44), reason: '$finder #$i is ${h}px');
        checked++;
      }
    }
    expect(checked, greaterThan(4));
  });

  testWidgets('at most two filled/outlined buttons at the bottom', (t) async {
    await pumpLeakApp(
        t,
        _card(_top(),
            expanded: true,
            actions: LeakCardActions(
              onShowBandInfo: () {},
              onPractice: () {},
              onSeeHands: () {},
            )));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Practice this spot'));
    await t.pumpAndSettle();
    expect(find.text('Practice this spot'), findsOneWidget);
    expect(find.text('See the hands behind it'), findsOneWidget);
    expect(find.text('Work on this'), findsNothing);
  });

  testWidgets('focus prompt calls back; active focus shows progress + clear',
      (t) async {
    var set = 0, cleared = 0;
    await pumpLeakApp(
        t,
        _card(_top(),
            emphasis: true,
            actions: LeakCardActions(
                onShowBandInfo: () {}, onSetFocus: () => set++)));
    await t.tap(find.text('Work on this'));
    expect(set, 1);

    final goal = LeakFocusGoal(
        findingId: 'fold_to_3bet',
        title: 'Folding too much to 3-bets',
        startedAt: DateTime.now(),
        startValue: 0.9,
        startSampleCount: 40);
    await pumpLeakApp(
        t,
        _card(_top(),
            emphasis: true,
            focus: goal,
            actions: LeakCardActions(
                onShowBandInfo: () {}, onClearFocus: () => cleared++)));
    expect(find.textContaining('Day 1 · +20 spots · 90% → 78%'), findsOneWidget);
    await t.tap(find.byIcon(Icons.close));
    expect(cleared, 1);
  });

  testWidgets('delta is plain text in the caption', (t) async {
    await pumpLeakApp(
        t, _card(_top(), delta: const LeakDelta(3, LeakDeltaKind.closer)));
    expect(find.text('3pt closer to healthy since your last visit'),
        findsOneWidget);
  });

  testWidgets('caption opens the band explainer', (t) async {
    var opened = 0;
    await pumpLeakApp(
        t,
        _card(_top(),
            actions: LeakCardActions(onShowBandInfo: () => opened++)));
    await t.tap(find.textContaining('You 78%'));
    expect(opened, 1);
  });

  testWidgets('card exposes button + expanded semantics', (t) async {
    final handle = t.ensureSemantics();
    await pumpLeakApp(t, _card(_top(), expanded: true));
    await t.pumpAndSettle();
    expect(
      find.bySemanticsLabel(
          'Folding too much to 3-bets, Confirmed. Expanded'),
      findsOneWidget,
    );
    handle.dispose();
  });
}
