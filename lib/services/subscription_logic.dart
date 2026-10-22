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

// ---------------------------------------------------------------------------
// Free trial (hard paywall). Store introductory offers: monthly plans 7 days,
// annual plans 1 month — the LENGTH always comes from the store; this logic
// only trusts the entitlement's period type + expiry.
// ---------------------------------------------------------------------------

/// An active free trial: when it ends (= the first charge), whether the
/// subscription will renew into a paid period, and the store product.
class TrialStatus {
  final DateTime endsAt;
  final bool willRenew;
  final String? productId;
  const TrialStatus(
      {required this.endsAt, required this.willRenew, this.productId});
}

/// The trial state from an entitlement snapshot, or null when the user is not
/// in an active trial (normal paid period, no expiry, unparsable or past
/// expiry).
TrialStatus? trialStatusFrom({
  required bool inTrial,
  required bool willRenew,
  required String? expirationIso,
  String? productId,
  required DateTime now,
}) {
  if (!inTrial || expirationIso == null) return null;
  final endsAt = DateTime.tryParse(expirationIso);
  if (endsAt == null || !endsAt.isAfter(now)) return null;
  return TrialStatus(endsAt: endsAt, willRenew: willRenew, productId: productId);
}

/// When the "your free trial ends tomorrow" reminder fires, in LOCAL time:
/// 24 h before the first charge, but never in quiet hours (22:00–09:00) —
/// then 19:00 the evening before. Always moved EARLIER, never later, so the
/// user keeps at least 24 h to cancel.
DateTime trialReminderTime(DateTime chargeAt) {
  final base = chargeAt.subtract(const Duration(hours: 24));
  if (base.hour >= 22) {
    return DateTime(base.year, base.month, base.day, 19);
  }
  if (base.hour < 9) {
    final prev = base.subtract(const Duration(days: 1));
    return DateTime(prev.year, prev.month, prev.day, 19);
  }
  return base;
}

enum TrialReminderAction { schedule, showNow, cancel }

/// What to do about the trial reminder right now.
class TrialReminderDecision {
  final TrialReminderAction action;

  /// When to fire (schedule only).
  final DateTime? at;

  /// The trial end it is for — the dedupe key shared with the server push.
  final int? endsAtMs;
  const TrialReminderDecision(this.action, {this.at, this.endsAtMs});
}

/// Minimum time before the charge for a reminder to still be useful.
const Duration kTrialReminderMinLead = Duration(hours: 2);

/// Decide the reminder for [trial] at [now] (local time):
/// - no trial, or cancelled (will not renew) → cancel (nothing to charge)
/// - reminder moment still ahead → schedule it
/// - moment passed but ≥ [kTrialReminderMinLead] left → show now (a late
///   reminder beats none — e.g. the trial started on another device)
/// - less than that left → cancel
/// The caller must remember which [TrialReminderDecision.endsAtMs] it already
/// handled, so "show now" fires once, not on every app open.
TrialReminderDecision decideTrialReminder(TrialStatus? trial, DateTime now) {
  if (trial == null || !trial.willRenew) {
    return const TrialReminderDecision(TrialReminderAction.cancel);
  }
  final endsLocal = trial.endsAt.toLocal();
  final endsMs = trial.endsAt.millisecondsSinceEpoch;
  final at = trialReminderTime(endsLocal);
  if (at.isAfter(now)) {
    return TrialReminderDecision(TrialReminderAction.schedule,
        at: at, endsAtMs: endsMs);
  }
  if (endsLocal.difference(now) >= kTrialReminderMinLead) {
    return TrialReminderDecision(TrialReminderAction.showNow, endsAtMs: endsMs);
  }
  return const TrialReminderDecision(TrialReminderAction.cancel);
}

/// Unit of a free-trial length as the paywall shows it.
enum TrialUnit { day, month }

/// A FREE introductory offer on a plan: "7 days" / "1 month". App-owned so
/// the paywall never touches SDK types.
class TrialOffer {
  final TrialUnit unit;
  final int count;
  const TrialOffer(this.unit, this.count);

  @override
  bool operator ==(Object other) =>
      other is TrialOffer && other.unit == unit && other.count == count;
  @override
  int get hashCode => Object.hash(unit, count);
}

/// Map a store intro offer to a [TrialOffer]. [unit] is the SDK period unit
/// name ('day' | 'week' | 'month' | 'year' | 'unknown'). Weeks show as days
/// ("7 days", not "1 week"), years as months. A PAID intro price is not a
/// free trial → null; so is an unknown unit or a non-positive length.
TrialOffer? freeTrialOffer({
  required String unit,
  required int count,
  required double price,
}) {
  if (price != 0 || count <= 0) return null;
  return switch (unit) {
    'day' => TrialOffer(TrialUnit.day, count),
    'week' => TrialOffer(TrialUnit.day, count * 7),
    'month' => TrialOffer(TrialUnit.month, count),
    'year' => TrialOffer(TrialUnit.month, count * 12),
    _ => null,
  };
}

/// Index of the package the user's entitlement product belongs to (to show
/// its price), or -1. iOS: the entitlement product id IS the store product
/// ('elite_annual'). Android: the entitlement carries the subscription id +
/// base plan ('pro' + 'annual') and the package's store product is
/// 'pro:annual'. An Android id without a plan never guesses.
int matchEntitlementPackage(
    String? productId, String? planId, List<PackageRef> packages) {
  if (productId == null || productId.isEmpty) return -1;
  final wanted = planId == null || planId.isEmpty
      ? productId
      : '$productId:$planId';
  return packages.indexWhere((p) => p.storeProductIdentifier == wanted);
}
