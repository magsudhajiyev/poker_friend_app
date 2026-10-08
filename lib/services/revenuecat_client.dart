import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Thin wrapper over the RevenueCat SDK — the ONLY place `Purchases.*` is
/// called. SubscriptionService depends on this interface, not the SDK, so a
/// purchases_flutter version bump is confined to [LiveRevenueCatClient] and
/// the service stays testable with [FakeRevenueCatClient] in tests.
///
/// The wrapper returns app-owned value types ([TierEntitlements],
/// [PurchaseOutcome]) so the 8.x→9.x difference in purchase return shape
/// (CustomerInfo vs PurchaseResult) is absorbed here, not in the service.

/// Entitlement snapshot the app cares about, derived from a CustomerInfo.
class TierEntitlements {
  final bool proActive;
  final bool eliteActive;
  final bool clubActive;

  /// Whether the active 'pro' entitlement is a promotional grant (the free
  /// month). Null when there's no active pro entitlement.
  final bool? proIsPromotional;

  /// Expiry of the active 'pro' entitlement, ISO-8601 string as RC returns it.
  final String? proExpirationIso;

  const TierEntitlements({
    required this.proActive,
    required this.eliteActive,
    required this.clubActive,
    this.proIsPromotional,
    this.proExpirationIso,
  });

  static const empty = TierEntitlements(
    proActive: false,
    eliteActive: false,
    clubActive: false,
  );
}

/// Result of a purchase attempt, normalized across SDK versions.
class PurchaseOutcome {
  final TierEntitlements? entitlements;
  final bool cancelled;
  final Object? error;

  const PurchaseOutcome({this.entitlements, this.cancelled = false, this.error});

  bool get isSuccess => entitlements != null && !cancelled && error == null;
}

abstract class RevenueCatClient {
  Future<void> configure(String apiKey);
  void addCustomerInfoUpdateListener(void Function(TierEntitlements) listener);
  Future<TierEntitlements> getEntitlements();
  Future<void> invalidateCustomerInfoCache();
  Future<Offerings?> getOfferings();
  Future<PurchaseOutcome> purchasePackage(Package package);
  Future<TierEntitlements> restorePurchases();
  Future<TierEntitlements> logIn(String userId);
  Future<TierEntitlements> logOut();
}

/// Production implementation forwarding to the RevenueCat SDK.
class LiveRevenueCatClient implements RevenueCatClient {
  // Entitlement identifiers — must match the RevenueCat dashboard.
  static const _pro = 'pro';
  static const _elite = 'elite';
  static const _club = 'club';

  /// Map a CustomerInfo into the app's entitlement snapshot. This is the one
  /// spot that reads SDK entitlement fields (isActive/store/expirationDate) —
  /// re-verify these getters on the 9.x bump.
  static TierEntitlements _fromCustomerInfo(CustomerInfo info) {
    final all = info.entitlements.all;
    final proEnt = all[_pro];
    return TierEntitlements(
      proActive: proEnt?.isActive ?? false,
      eliteActive: all[_elite]?.isActive ?? false,
      clubActive: all[_club]?.isActive ?? false,
      proIsPromotional:
          proEnt == null ? null : proEnt.store == Store.promotional,
      proExpirationIso: proEnt?.expirationDate,
    );
  }

  @override
  Future<void> configure(String apiKey) {
    return Purchases.configure(PurchasesConfiguration(apiKey));
  }

  @override
  void addCustomerInfoUpdateListener(
      void Function(TierEntitlements) listener) {
    Purchases.addCustomerInfoUpdateListener(
      (info) => listener(_fromCustomerInfo(info)),
    );
  }

  @override
  Future<TierEntitlements> getEntitlements() async {
    return _fromCustomerInfo(await Purchases.getCustomerInfo());
  }

  @override
  Future<void> invalidateCustomerInfoCache() {
    return Purchases.invalidateCustomerInfoCache();
  }

  @override
  Future<Offerings?> getOfferings() {
    return Purchases.getOfferings();
  }

  @override
  Future<PurchaseOutcome> purchasePackage(Package package) async {
    try {
      // 9.x API: purchase(PurchaseParams) → PurchaseResult (replaces the
      // deprecated purchasePackage, which returned CustomerInfo in 8.x).
      final result =
          await Purchases.purchase(PurchaseParams.package(package));
      return PurchaseOutcome(
          entitlements: _fromCustomerInfo(result.customerInfo));
    } on PlatformException catch (e) {
      // Canonical 9.x check, with the legacy details flag as fallback.
      final code = PurchasesErrorHelper.getErrorCode(e);
      final legacyCancelled =
          e.details is Map && (e.details as Map)['userCancelled'] == true;
      if (code == PurchasesErrorCode.purchaseCancelledError ||
          legacyCancelled) {
        return const PurchaseOutcome(cancelled: true);
      }
      return PurchaseOutcome(error: e);
    } catch (e) {
      return PurchaseOutcome(error: e);
    }
  }

  @override
  Future<TierEntitlements> restorePurchases() async {
    return _fromCustomerInfo(await Purchases.restorePurchases());
  }

  @override
  Future<TierEntitlements> logIn(String userId) async {
    final result = await Purchases.logIn(userId);
    return _fromCustomerInfo(result.customerInfo);
  }

  @override
  Future<TierEntitlements> logOut() async {
    return _fromCustomerInfo(await Purchases.logOut());
  }
}
