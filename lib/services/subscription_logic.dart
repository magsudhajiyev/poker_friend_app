/// Pure subscription decision logic — no RevenueCat SDK, no static state.
///
/// Extracted from [SubscriptionService] so the tier/override/package rules
/// (the part that actually breaks on a version bump) are unit-testable
/// without mocking the `purchases_flutter` SDK. SubscriptionService calls
/// these; the SDK glue lives in `revenuecat_client.dart`.
library;

/// Tier rank for precedence comparisons. Mirrors the map used inline in the
/// original SubscriptionService.
const Map<String, int> kTierRank = {'free': 0, 'pro': 1, 'elite': 2, 'club': 3};

/// The raw RevenueCat tier from entitlement flags, with a just-purchased
/// override taking precedence (handles sandbox lag where a cancelled higher
/// tier still reads active). Mirrors `SubscriptionService.currentTier`.
String resolveCurrentTier({
  required bool proActive,
  required bool eliteActive,
  required bool clubActive,
  String? purchasedOverride,
}) {
  if (purchasedOverride != null) return purchasedOverride;
  return clubActive
      ? 'club'
      : eliteActive
          ? 'elite'
          : proActive
              ? 'pro'
              : 'free';
}

/// Effective tier: debug override wins outright; otherwise a partner grant
/// applies only when it is STRICTLY HIGHER than the RevenueCat tier.
/// Mirrors `SubscriptionService._effectiveTier`.
String resolveEffectiveTier({
  required String rcTier,
  String? debugOverride,
  String? partnerTier,
}) {
  if (debugOverride != null) return debugOverride;
  if (partnerTier == null) return rcTier;
  return (kTierRank[partnerTier] ?? 0) > (kTierRank[rcTier] ?? 0)
      ? partnerTier
      : rcTier;
}

/// Whether a just-purchased override should be cleared: clear once the real
/// entitlements have caught up to (or exceeded) the override's rank.
/// Mirrors the clear logic in `_updatePremiumStatus`.
bool shouldClearPurchaseOverride({
  required String? purchasedOverride,
  required String entitlementTier,
}) {
  if (purchasedOverride == null) return false;
  final overrideRank = kTierRank[purchasedOverride] ?? 0;
  final entitlementRank = kTierRank[entitlementTier] ?? 0;
  return entitlementRank >= overrideRank;
}

/// The tier a purchased package grants, derived from its identifier.
/// Mirrors the switch in `purchasePackage`. Anything not club/elite is 'pro'.
String tierForPurchasedPackageId(String packageId) {
  if (packageId == kPkgClubMonthly || packageId == kPkgClubAnnual) {
    return 'club';
  }
  if (packageId == kPkgEliteMonthly || packageId == kPkgEliteAnnual) {
    return 'elite';
  }
  return 'pro';
}

// Package identifier constants — must match the RevenueCat dashboard.
const String kPkgProMonthly = r'$rc_monthly';
const String kPkgProAnnual = r'$rc_annual';
const String kPkgEliteMonthly = 'elite_monthly';
const String kPkgEliteAnnual = 'elite_annual';
const String kPkgClubMonthly = 'club_monthly';
const String kPkgClubAnnual = 'club_annual';

/// Aliases: the Pro packages are the offering's STANDARD monthly/annual
/// packages ($rc_monthly / $rc_annual), but callers look them up as
/// 'pro_monthly' / 'pro_annual'.
const Map<String, String> kPackageIdAliases = {
  'pro_monthly': kPkgProMonthly,
  'pro_annual': kPkgProAnnual,
};

/// Minimal package shape for [matchPackageId] — lets us test the lookup
/// without the SDK's `Package` type.
class PackageRef {
  final String identifier;
  final String storeProductIdentifier;
  const PackageRef(this.identifier, this.storeProductIdentifier);
}

/// Find the index of the package matching [identifier], or -1.
/// Mirrors `SubscriptionService.packageById`:
/// 1. exact identifier match (alias-aware for pro_monthly/pro_annual)
/// 2. fallback: store-product identifier with '_' → ':' normalization.
int matchPackageId(String identifier, List<PackageRef> packages) {
  final alias = kPackageIdAliases[identifier];
  for (var i = 0; i < packages.length; i++) {
    final p = packages[i];
    if (p.identifier == identifier) return i;
    if (alias != null && p.identifier == alias) return i;
  }
  final normalized = identifier.replaceAll('_', ':');
  for (var i = 0; i < packages.length; i++) {
    if (packages[i].storeProductIdentifier == normalized) return i;
  }
  return -1;
}
