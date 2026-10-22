import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'subscription_logic.dart' show TrialOffer, freeTrialOffer;

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

  /// The HIGHEST active entitlement (club > elite > pro) — the one the user
  /// is paying for: whether it is in a free-trial period, whether it will
  /// renew (false once the user cancels), its expiry (= trial end / next
  /// charge) and the store product. Defaults describe "no subscription".
  final bool topInTrial;
  final bool topWillRenew;
  final String? topExpirationIso;
  final String? topProductId;

  /// Google Play base plan of [topProductId] ('annual'); null on iOS.
  final String? topProductPlanId;

  const TierEntitlements({
    required this.proActive,
    required this.eliteActive,
    required this.clubActive,
    this.proIsPromotional,
    this.proExpirationIso,
    this.topInTrial = false,
    this.topWillRenew = false,
    this.topExpirationIso,
    this.topProductId,
    this.topProductPlanId,
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

  /// FREE trials the CURRENT user can still start, keyed by package
  /// identifier. A package is absent when it has no free trial or the user
  /// is not eligible (already used one) — the paywall must then not promise
  /// a trial. Never throws.
  Future<Map<String, TrialOffer>> freeTrials(List<Package> packages);
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
    // Highest ACTIVE entitlement carries the trial / renewal state.
    final top = [all[_club], all[_elite], proEnt]
        .firstWhere((e) => e?.isActive ?? false, orElse: () => null);
    return TierEntitlements(
      proActive: proEnt?.isActive ?? false,
      eliteActive: all[_elite]?.isActive ?? false,
      clubActive: all[_club]?.isActive ?? false,
      proIsPromotional:
          proEnt == null ? null : proEnt.store == Store.promotional,
      proExpirationIso: proEnt?.expirationDate,
      topInTrial: top?.periodType == PeriodType.trial,
      topWillRenew: top?.willRenew ?? false,
      topExpirationIso: top?.expirationDate,
      topProductId: top?.productIdentifier,
      topProductPlanId: top?.productPlanIdentifier,
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
  Future<Map<String, TrialOffer>> freeTrials(List<Package> packages) async {
    final out = <String, TrialOffer>{};
    try {
      if (Platform.isAndroid) {
        // Google Play only returns offers this user is ELIGIBLE for. Scan ALL
        // subscription options for a free-trial phase — NOT just defaultOption,
        // which RevenueCat may point at the base plan (and "Backwards
        // compatible" legacy offers are not always the default). The trial is
        // a phase with a freePhase, or any phase priced at 0.
        for (final p in packages) {
          final options = p.storeProduct.subscriptionOptions ??
              [
                if (p.storeProduct.defaultOption != null)
                  p.storeProduct.defaultOption!
              ];
          if (kDebugMode) {
            debugPrint('🎁 trial scan ${p.identifier} '
                '(${p.storeProduct.identifier}): '
                '${options.length} option(s) → '
                '${options.map((o) => '${o.id}[free=${o.freePhase != null},'
                    'phases=${o.pricingPhases.map((ph) => ph.price.amountMicros).toList()}]').join(', ')}');
          }
          PricingPhase? trialPhase;
          for (final o in options) {
            final phase = o.freePhase ??
                o.pricingPhases.cast<PricingPhase?>().firstWhere(
                      (ph) => (ph?.price.amountMicros ?? -1) == 0,
                      orElse: () => null,
                    );
            if (phase?.billingPeriod != null) {
              trialPhase = phase;
              break;
            }
          }
          final period = trialPhase?.billingPeriod;
          if (period == null) continue;
          final t = freeTrialOffer(
            unit: period.unit.name,
            count: period.value * (trialPhase!.billingCycleCount ?? 1),
            price: 0,
          );
          if (t != null) out[p.identifier] = t;
        }
        return out;
      }
      // iOS: the intro offer is on the product; eligibility is per Apple ID
      // (one trial per subscription group), so ask StoreKit via RevenueCat.
      final candidates = <Package, TrialOffer>{};
      for (final p in packages) {
        final intro = p.storeProduct.introductoryPrice;
        if (intro == null) continue;
        final t = freeTrialOffer(
          unit: intro.periodUnit.name,
          count: intro.periodNumberOfUnits * (intro.cycles > 0 ? intro.cycles : 1),
          price: intro.price,
        );
        if (t != null) candidates[p] = t;
      }
      if (candidates.isEmpty) return out;
      final eligibility = await Purchases.checkTrialOrIntroductoryPriceEligibility(
          [for (final p in candidates.keys) p.storeProduct.identifier]);
      candidates.forEach((p, t) {
        if (eligibility[p.storeProduct.identifier]?.status ==
            IntroEligibilityStatus.introEligibilityStatusEligible) {
          out[p.identifier] = t;
        }
      });
      return out;
    } catch (_) {
      // Unknown eligibility → promise nothing (the store still applies a
      // trial at purchase if the user qualifies).
      return const {};
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
