import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/onboarding/onboarding_state.dart';
import 'package:poker_logger/screens/paywall_screen.dart';
import 'package:poker_logger/services/analytics_service.dart';
import 'package:poker_logger/services/subscription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/subscription_service_test.dart' show FakeRevenueCatClient;

typedef _Ev = (String, Map<String, Object>?);

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<_Ev> events;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SubscriptionService.debugInitializeWithClient(FakeRevenueCatClient());
    events = [];
    AnalyticsService.debugSink = (e, p) => events.add((e, p));
    addTearDown(() => AnalyticsService.debugSink = null);
  });

  List<_Ev> paywall() => events.where((e) => e.$1 == 'paywall_opened').toList();

  Future<void> pumpAt(WidgetTester t, Widget w) async {
    t.view.physicalSize = const Size(430, 2600) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(w));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
  }

  testWidgets('direct construction fires once with its source as feature',
      (t) async {
    await pumpAt(t, const PaywallScreen(hardGate: true, source: 'hard_gate'));
    expect(paywall().length, 1);
    expect(
        paywall().single.$2, {'feature': 'hard_gate', 'launch_promo': false});
  });

  testWidgets('rebuilds of the same paywall do not fire again', (t) async {
    await pumpAt(t, const PaywallScreen(hardGate: true, source: 'hard_gate'));
    await t.pumpWidget(
        _app(const PaywallScreen(hardGate: true, source: 'hard_gate')));
    await t.pump();
    expect(paywall().length, 1);
  });

  testWidgets('show() keeps feature, tier and promo props, fires once',
      (t) async {
    await pumpAt(
        t,
        Builder(
            builder: (c) => TextButton(
                onPressed: () => PaywallScreen.show(c,
                    featureName: 'ai_analysis', preselectedTier: 1),
                child: const Text('open'))));
    await t.tap(find.text('open'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(paywall().length, 1);
    expect(paywall().single.$2, {
      'feature': 'ai_analysis',
      'preselected_tier': 1,
      'launch_promo': false,
    });
  });

  test('tour_started fires on a real start, not on replay', () {
    OnboardingState.start();
    expect(events.where((e) => e.$1 == 'tour_started').length, 1);
    OnboardingState.cancel();
    events.clear();
    OnboardingState.startFromPhase(1);
    expect(events.where((e) => e.$1 == 'tour_started'), isEmpty);
    OnboardingState.cancel();
  });

  test('tour_skipped carries the phase', () {
    AnalyticsService.tourSkipped('4_heroTurn');
    expect(events.single.$1, 'tour_skipped');
    expect(events.single.$2, {'phase': '4_heroTurn'});
    OnboardingState.start();
    OnboardingState.advanceTo(2);
    expect(OnboardingState.analyticsPhase, '2');
    OnboardingState.cancel();
  });
}
