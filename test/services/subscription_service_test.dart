import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart' show Offerings, Package;
import 'package:poker_logger/services/revenuecat_client.dart';
import 'package:poker_logger/services/subscription_service.dart';

/// Drives SubscriptionService through a fake RevenueCat client so the
/// purchase/restore/login/logout/override behavior is verified without the
/// SDK. These lock the CONTRACT before the 9.x bump — after the bump, the
/// only thing that can break these is the LiveRevenueCatClient adaptation
/// (which these don't touch), so a failure localizes the regression.
class FakeRevenueCatClient implements RevenueCatClient {
  TierEntitlements entitlements;
  PurchaseOutcome nextPurchase;
  TierEntitlements restoreResult;
  TierEntitlements loginResult;
  TierEntitlements logoutResult;

  void Function(TierEntitlements)? _listener;

  int configureCalls = 0;
  int invalidateCalls = 0;

  FakeRevenueCatClient({
    this.entitlements = TierEntitlements.empty,
    PurchaseOutcome? nextPurchase,
    TierEntitlements? restoreResult,
    TierEntitlements? loginResult,
    TierEntitlements? logoutResult,
  })  : nextPurchase = nextPurchase ?? const PurchaseOutcome(cancelled: true),
        restoreResult = restoreResult ?? TierEntitlements.empty,
        loginResult = loginResult ?? TierEntitlements.empty,
        logoutResult = logoutResult ?? TierEntitlements.empty;

  /// Simulate an out-of-band customer-info push from RevenueCat.
  void pushUpdate(TierEntitlements e) {
    entitlements = e;
    _listener?.call(e);
  }

  @override
  Future<void> configure(String apiKey) async => configureCalls++;

  @override
  void addCustomerInfoUpdateListener(void Function(TierEntitlements) listener) {
    _listener = listener;
  }

  @override
  Future<TierEntitlements> getEntitlements() async => entitlements;

  @override
  Future<void> invalidateCustomerInfoCache() async => invalidateCalls++;

  @override
  Future<Offerings?> getOfferings() async => null;

  @override
  Future<PurchaseOutcome> purchasePackage(Package package) async => nextPurchase;

  @override
  Future<TierEntitlements> restorePurchases() async => restoreResult;

  @override
  Future<TierEntitlements> logIn(String userId) async => loginResult;

  @override
  Future<TierEntitlements> logOut() async => logoutResult;
}

const _proActive = TierEntitlements(
    proActive: true, eliteActive: false, clubActive: false);
const _eliteActive = TierEntitlements(
    proActive: true, eliteActive: true, clubActive: false);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // These assertions read effectiveTier/isPremium, which apply the debug
  // override. In debug test mode kReleaseMode is false, so ensure no stale
  // override leaks between tests by resetting the client each time.
  setUp(() {
    SubscriptionService.debugSetClient(FakeRevenueCatClient());
  });

  test('starts free with a fresh (empty) client', () {
    expect(SubscriptionService.isPremium, isFalse);
    expect(SubscriptionService.effectiveTier, 'free');
    expect(SubscriptionService.currentTier, 'free');
  });

  test('init with a live pro entitlement → pro', () async {
    final fake = FakeRevenueCatClient(entitlements: _proActive);
    await SubscriptionService.debugInitializeWithClient(fake);
    expect(fake.configureCalls, 1);
    expect(SubscriptionService.isPremium, isTrue);
    expect(SubscriptionService.currentTier, 'pro');
    expect(SubscriptionService.proEntitlement.proActive, isTrue);
  });

  test('purchase success → tier set immediately via override', () async {
    // Entitlements lag (still free), but purchasing elite must reflect
    // immediately through the purchased-tier override.
    final fake = FakeRevenueCatClient(
      entitlements: TierEntitlements.empty,
      nextPurchase: const PurchaseOutcome(entitlements: TierEntitlements.empty),
    );
    await SubscriptionService.debugInitializeWithClient(fake);

    final ok = await SubscriptionService.purchasePackage(
        _FakePackage(SubscriptionService.pkgEliteMonthly));

    expect(ok, isTrue);
    expect(SubscriptionService.currentTier, 'elite'); // override wins the lag
    expect(SubscriptionService.isElite, isTrue);
  });

  test('purchase cancel → no tier change, no override', () async {
    final fake = FakeRevenueCatClient(
      entitlements: TierEntitlements.empty,
      nextPurchase: const PurchaseOutcome(cancelled: true),
    );
    await SubscriptionService.debugInitializeWithClient(fake);

    final ok = await SubscriptionService.purchasePackage(
        _FakePackage(SubscriptionService.pkgProMonthly));

    expect(ok, isFalse);
    expect(SubscriptionService.isPremium, isFalse);
    expect(SubscriptionService.currentTier, 'free');
  });

  test('purchase error → false, stays free', () async {
    final fake = FakeRevenueCatClient(
      nextPurchase: PurchaseOutcome(error: Exception('boom')),
    );
    await SubscriptionService.debugInitializeWithClient(fake);
    final ok = await SubscriptionService.purchasePackage(
        _FakePackage(SubscriptionService.pkgProMonthly));
    expect(ok, isFalse);
    expect(SubscriptionService.isPremium, isFalse);
  });

  test('override clears once real entitlements catch up (via push)', () async {
    final fake = FakeRevenueCatClient(
      nextPurchase: const PurchaseOutcome(entitlements: TierEntitlements.empty),
    );
    await SubscriptionService.debugInitializeWithClient(fake);
    await SubscriptionService.purchasePackage(
        _FakePackage(SubscriptionService.pkgProMonthly));
    expect(SubscriptionService.currentTier, 'pro'); // via override

    // RevenueCat pushes the real pro entitlement → override should clear,
    // tier stays pro but now from real entitlements.
    fake.pushUpdate(_proActive);
    expect(SubscriptionService.currentTier, 'pro');
    expect(SubscriptionService.isPremium, isTrue);
  });

  test('restore → tier updated from restored entitlements', () async {
    final fake = FakeRevenueCatClient(restoreResult: _eliteActive);
    await SubscriptionService.debugInitializeWithClient(fake);
    final ok = await SubscriptionService.restorePurchases();
    expect(ok, isTrue);
    expect(SubscriptionService.isElite, isTrue);
  });

  test('logout → state cleared to free', () async {
    final fake = FakeRevenueCatClient(
      entitlements: _proActive,
      logoutResult: TierEntitlements.empty,
    );
    await SubscriptionService.debugInitializeWithClient(fake);
    expect(SubscriptionService.isPremium, isTrue);

    await SubscriptionService.logoutUser();
    expect(SubscriptionService.isPremium, isFalse);
    expect(SubscriptionService.currentTier, 'free');
  });

  test('refreshOnResume invalidates cache + re-reads entitlements', () async {
    final fake = FakeRevenueCatClient(entitlements: _proActive);
    await SubscriptionService.debugInitializeWithClient(fake);

    fake.entitlements = TierEntitlements.empty; // user cancelled externally
    await SubscriptionService.refreshOnResume();

    expect(fake.invalidateCalls, 1);
    expect(SubscriptionService.isPremium, isFalse); // reverted
  });

  test('promotional pro entitlement is surfaced for the promo flow', () async {
    const promo = TierEntitlements(
      proActive: true,
      eliteActive: false,
      clubActive: false,
      proIsPromotional: true,
      proExpirationIso: '2026-08-25T00:00:00Z',
    );
    final fake = FakeRevenueCatClient(entitlements: promo);
    await SubscriptionService.debugInitializeWithClient(fake);

    final ent = SubscriptionService.proEntitlement;
    expect(ent.proActive, isTrue);
    expect(ent.proIsPromotional, isTrue);
    expect(ent.proExpirationIso, '2026-08-25T00:00:00Z');
  });
}

/// Minimal stub — SubscriptionService.purchasePackage only reads
/// `package.identifier`, so we don't need a real SDK Package.
class _FakePackage implements Package {
  @override
  final String identifier;
  _FakePackage(this.identifier);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
