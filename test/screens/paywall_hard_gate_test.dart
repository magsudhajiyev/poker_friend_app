import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/screens/paywall_screen.dart';
import 'package:poker_logger/services/subscription_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/subscription_service_test.dart' show FakeRevenueCatClient;

/// Step 6a (hard paywall): the non-dismissible paywall mode. A hard-gated
/// paywall must NOT be skippable or back-dismissible, and must still expose the
/// escape hatches (Restore / Sign out / Delete account).

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

Future<void> _pump(WidgetTester tester, {required bool hardGate}) async {
  tester.view.physicalSize = const Size(430, 2600) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: PaywallScreen(hardGate: hardGate),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final fake = FakeRevenueCatClient()..offerings = _offerings();
    await SubscriptionService.debugInitializeWithClient(fake);
    await SubscriptionService.fetchOfferings();
  });

  testWidgets('hard gate: no Skip, no back button; shows Sign out + Delete',
      (tester) async {
    await _pump(tester, hardGate: true);

    // Non-dismissible: neither affordance is present.
    expect(find.text('Skip'), findsNothing);
    expect(find.byType(BackButton), findsNothing);

    // Escape hatches that must stay reachable.
    expect(find.text('Restore'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
  });

  testWidgets('hard gate blocks the system back button (PopScope canPop=false)',
      (tester) async {
    await _pump(tester, hardGate: true);

    final popScope = tester.widget<PopScope>(
      find.descendant(
        of: find.byType(PaywallScreen),
        matching: find.byType(PopScope),
      ).first,
    );
    expect(popScope.canPop, isFalse);
  });

  testWidgets('non-hard paywall stays dismissible (PopScope canPop=true)',
      (tester) async {
    await _pump(tester, hardGate: false);

    final popScope = tester.widget<PopScope>(
      find.descendant(
        of: find.byType(PaywallScreen),
        matching: find.byType(PopScope),
      ).first,
    );
    expect(popScope.canPop, isTrue);
    // No hard-gate hatches on the normal paywall.
    expect(find.text('Sign out'), findsNothing);
    expect(find.text('Delete account'), findsNothing);
  });
}
