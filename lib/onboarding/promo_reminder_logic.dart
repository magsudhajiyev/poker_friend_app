/// Pure decision logic for the free-month expiry reminder sync — extracted
/// so the audit fix (H1: never cancel on UNKNOWN RevenueCat state) is unit
/// testable without Flutter/Firebase plumbing.
enum PromoReminderAction {
  /// Promo entitlement confirmed live → (re)schedule the reminders.
  schedule,

  /// RC data affirmatively shows the promo is over (expired, or superseded
  /// by a paid subscription) → cancel any pending reminders.
  cancel,

  /// Not a promo user, or RC state UNKNOWN (customerInfo not loaded yet —
  /// e.g. the sync raced RevenueCat init on a cold start). Do nothing:
  /// cancelling on unknown deletes valid reminders (audit finding H1).
  none,
}

PromoReminderAction promoReminderAction({
  required bool markerSet,
  required bool customerInfoLoaded,
  required bool entitlementActive,
  required bool entitlementIsPromotional,
}) {
  if (!markerSet) return PromoReminderAction.none;
  if (!customerInfoLoaded) return PromoReminderAction.none; // unknown ≠ inactive
  if (entitlementActive && entitlementIsPromotional) {
    return PromoReminderAction.schedule;
  }
  return PromoReminderAction.cancel;
}
