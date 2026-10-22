import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/screens/paywall_screen.dart';
import 'package:poker_logger/services/subscription_logic.dart';
import 'package:poker_logger/services/subscription_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/subscription_service_test.dart' show FakeRevenueCatClient;

/// Hard paywall step 3: the paywall shows the store free trial — length from
/// the store, only when the user is eligible — with a "Start free trial"
/// button and the store-required terms. Without a trial it is unchanged.

const _ctx = PresentedOfferingContext('default', null, null);

Package _pkg(String id, double price, String priceString) => Package(
      id,
      id.endsWith('annual') ? PackageType.annual : PackageType.monthly,
      StoreProduct(id, '', id, price, priceString, 'USD'),
      _ctx,
    );

Offerings _offerings() {
  final packages = [
    _pkg('pro_monthly', 19.99, '\$19.99'),
    _pkg('pro_annual', 159.99, '\$159.99'),
    _pkg('elite_monthly', 24.99, '\$24.99'),
    _pkg('elite_annual', 189.99, '\$189.99'),
    _pkg('club_monthly', 59.99, '\$59.99'),
    _pkg('club_annual', 449.99, '\$449.99'),
  ];
  final offering = Offering('default', '', const {}, packages);
  return Offerings({'default': offering}, current: offering);
}

Future<void> _pumpPaywall(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 2600) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: PaywallScreen(),
  ));
  await tester.pump(); // trial offers resolve
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('eligible trials: badge, "Free for…, then…", trial button, terms',
      (tester) async {
    final fake = FakeRevenueCatClient()
      ..offerings = _offerings()
      ..trials = const {
        'pro_annual': TrialOffer(TrialUnit.month, 1),
        'pro_monthly': TrialOffer(TrialUnit.day, 7),
      };
    // Real I/O (logger, prefs) must run outside the widget test's fake clock.
    await tester.runAsync(() async {
      await SubscriptionService.debugInitializeWithClient(fake);
      await SubscriptionService.fetchOfferings();
    });
    await _pumpPaywall(tester);

    // Annual is the default billing period; Pro is selected.
    expect(find.text('1 month free'), findsOneWidget);
    expect(find.text('Free for 1 month, then \$159.99/year'), findsOneWidget);
    expect(find.text('Start free trial'), findsOneWidget);
    expect(find.textContaining("You won't be charged if you cancel"),
        findsOneWidget);

    // Elite has no trial → normal button, no trial terms.
    await tester.tap(find.text('Elite'));
    await tester.pump();
    expect(find.text('Start free trial'), findsNothing);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.textContaining("You won't be charged if you cancel"),
        findsNothing);

    // Monthly Pro → the 7-day trial.
    await tester.tap(find.text('Monthly'));
    await tester.tap(find.text('Pro'));
    await tester.pump();
    expect(find.text('7 days free'), findsOneWidget);
    expect(find.text('Free for 7 days, then \$19.99/month'), findsOneWidget);
    expect(find.text('Start free trial'), findsOneWidget);
  });

  testWidgets('not eligible (trial already used) → no trial promised anywhere',
      (tester) async {
    final fake = FakeRevenueCatClient()..offerings = _offerings();
    // Real I/O (logger, prefs) must run outside the widget test's fake clock.
    await tester.runAsync(() async {
      await SubscriptionService.debugInitializeWithClient(fake);
      await SubscriptionService.fetchOfferings();
    });
    await _pumpPaywall(tester);

    expect(find.textContaining('free'), findsNothing);
    expect(find.text('Start free trial'), findsNothing);
    expect(find.text('Continue'), findsOneWidget);
  });
}
