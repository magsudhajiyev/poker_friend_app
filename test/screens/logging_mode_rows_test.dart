import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/onboarding/onboarding_state.dart';
import 'package:poker_logger/screens/logging_mode_selection_screen.dart';
import 'package:poker_logger/services/feature_flag_service.dart';
import 'package:poker_logger/services/live_session_logic.dart';
import 'package:poker_logger/widgets/running_session_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app({double scale = 1}) => MaterialApp(
      builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LoggingModeSelectionScreen(),
    );

final _running = LiveSessionRecord(
    sessionId: 's1',
    name: 'Friday game',
    gameType: 'cash',
    startTime: DateTime(2026, 11, 25, 13),
    kind: LiveSessionRecord.kindTracked);

void main() {
  late AppLocalizations l10n;
  LiveSessionRecord? running;
  final goToCalls = <String>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
    running = null;
    goToCalls.clear();
    OnboardingState.isOnboardingActive = false;
    OnboardingState.currentPhase = 0;
    RunningSessionGuard.current = () async => running;
    RunningSessionGuard.goTo = (nav, r) async => goToCalls.add(r.sessionId);
    await FeatureFlagService.applyRemote({
      'single_hand': 'on',
      'tracked_session': 'on',
      'training_drills': 'on',
    });
  });

  tearDown(() {
    OnboardingState.isOnboardingActive = false;
    OnboardingState.currentPhase = 0;
  });

  Future<void> open(WidgetTester t, {Size size = const Size(390, 844), double scale = 1}) async {
    t.view.physicalSize = size * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(const SizedBox()); // fresh state on every open
    await t.pumpWidget(_app(scale: scale));
    await t.pumpAndSettle();
  }

  double y(WidgetTester t, String text) => t.getTopLeft(find.text(text)).dy;

  testWidgets('rows are ordered by speed, then PRACTICE and drills', (t) async {
    await open(t);
    final order = [
      y(t, l10n.singleHandCardTitle),
      y(t, l10n.trackedCardTitle),
      y(t, l10n.loggingModeFullTitle),
      y(t, 'PRACTICE'),
      y(t, l10n.loggingTrainingDrills),
    ];
    expect(order, orderedEquals([...order]..sort()));
    expect(find.text(l10n.singleHandCardSubtitle), findsOneWidget);
    expect(find.text(l10n.loggingModeRowTrackedSubtitle), findsOneWidget);
    expect(find.text(l10n.loggingModeRowFullSubtitle), findsOneWidget);
    expect(find.text(l10n.loggingPro), findsOneWidget);
    // No feature bullet lists any more.
    expect(find.text(l10n.loggingModeFullFeature1), findsNothing);
  });

  testWidgets('flags off hide their rows; drills off hides the header too',
      (t) async {
    await FeatureFlagService.applyRemote({
      'single_hand': 'off',
      'tracked_session': 'off',
      'training_drills': 'off',
    });
    await open(t);
    expect(find.text(l10n.singleHandCardTitle), findsNothing);
    expect(find.text(l10n.trackedCardTitle), findsNothing);
    expect(find.text(l10n.loggingTrainingDrills), findsNothing);
    expect(find.text('PRACTICE'), findsNothing);
    expect(find.text(l10n.loggingModeFullTitle), findsOneWidget);
  });

  testWidgets('during the tour only Full logging (and drills) are listed',
      (t) async {
    OnboardingState.isOnboardingActive = true;
    OnboardingState.currentPhase = 2; // not phase 1: no coach mark overlay
    await open(t);
    expect(find.text(l10n.singleHandCardTitle), findsNothing);
    expect(find.text(l10n.trackedCardTitle), findsNothing);
    expect(find.text(l10n.loggingModeFullTitle), findsOneWidget);
  });

  testWidgets('the tour GlobalKey sits on the Full logging row', (t) async {
    await open(t);
    final keyed = find.byWidgetPredicate(
        (w) => w.key is GlobalKey && w.runtimeType.toString() == '_ModeRow',
        description: 'row with a GlobalKey');
    final full = find.ancestor(
        of: find.text(l10n.loggingModeFullTitle), matching: keyed);
    expect(full, findsOneWidget);
    // The key holds the whole row: the tour highlights its full rectangle.
    final r = t.getRect(full);
    expect(r.height, greaterThanOrEqualTo(64));
    expect(r.width, greaterThan(t.getSize(find.text(l10n.loggingModeFullTitle)).width));
  });

  testWidgets('running banner shows the session, tap goes to it', (t) async {
    running = _running;
    await open(t);
    expect(find.text('Friday game is running · Log a hand saves there'),
        findsOneWidget);
    await t.tap(find.textContaining('Friday game is running'));
    await t.pumpAndSettle();
    expect(goToCalls, ['s1']);
  });

  testWidgets('no banner when nothing runs', (t) async {
    await open(t);
    expect(find.textContaining('is running'), findsNothing);
  });

  testWidgets('Full logging row still hits the running-session gate',
      (t) async {
    running = _running;
    await open(t);
    await t.tap(find.text(l10n.loggingModeFullTitle));
    await t.pumpAndSettle();
    expect(find.text(l10n.trackedRunningTitle), findsOneWidget);
  });

  for (final size in const [Size(320, 568), Size(360, 640)]) {
    testWidgets('no overflow at $size with text scale 1.3 and a banner',
        (t) async {
      running = _running;
      await open(t, size: size, scale: 1.3);
      expect(t.takeException(), isNull);
      // Rows are tall enough to be targets.
      expect(t.getSize(find.text(l10n.loggingModeFullTitle)).height, greaterThan(0));
    });
  }

  // Height of the sheet panel (the bordered container that holds the rows).
  double panelHeight(WidgetTester t) => t
      .getSize(find
          .ancestor(
              of: find.text(l10n.loggingModeChooseMode),
              matching: find.byType(Container))
          .last)
      .height;

  double rowsBottom(WidgetTester t) {
    final all = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_ModeRow');
    return t.getRect(all.last).bottom;
  }

  testWidgets('the sheet hugs its content: no gap, shrinks without banner/drills',
      (t) async {
    await open(t);
    final full = panelHeight(t);
    // Rows end just above the bottom padding (xl) + safe area (0 in tests).
    final screenH = t.view.physicalSize.height / 3;
    expect(screenH - rowsBottom(t), lessThan(48));
    expect(full, lessThan(screenH * 0.9));

    running = _running;
    await open(t);
    final withBanner = panelHeight(t);
    expect(withBanner, greaterThan(full));
    expect(screenH - rowsBottom(t), lessThan(48));

    running = null;
    await FeatureFlagService.applyRemote({
      'single_hand': 'on',
      'tracked_session': 'on',
      'training_drills': 'off',
    });
    await open(t);
    expect(panelHeight(t), lessThan(full));
    expect(screenH - rowsBottom(t), lessThan(48));
  });

  testWidgets('taller than the cap: capped at 90% and scrolls', (t) async {
    running = _running;
    await open(t, size: const Size(320, 360), scale: 1.3);
    expect(t.takeException(), isNull);
    expect(panelHeight(t), lessThanOrEqualTo(360 * 0.9 + 0.5));
  });

  testWidgets('content is centred and capped on a wide screen', (t) async {
    await open(t, size: const Size(900, 900));
    final w = t.getSize(find.ancestor(
        of: find.text(l10n.loggingModeFullTitle),
        matching: find.byType(AnimatedContainer)).first).width;
    expect(w, lessThanOrEqualTo(560));
  });
}
