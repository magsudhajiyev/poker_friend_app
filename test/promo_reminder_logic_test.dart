import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/onboarding/promo_reminder_logic.dart';

/// Audit H1 — the heal-on-open reminder sync must never CANCEL scheduled
/// expiry reminders just because RevenueCat state is UNKNOWN (customerInfo
/// not loaded yet, e.g. the sync raced RC init on a cold start).
void main() {
  group('promoReminderAction', () {
    test('promo user + live promotional entitlement → schedule', () {
      expect(
        promoReminderAction(
          markerSet: true,
          customerInfoLoaded: true,
          entitlementActive: true,
          entitlementIsPromotional: true,
        ),
        PromoReminderAction.schedule,
      );
    });

    test('H1 regression: RC state UNKNOWN → none (must NOT cancel)', () {
      expect(
        promoReminderAction(
          markerSet: true,
          customerInfoLoaded: false, // cold start, RC init not finished
          entitlementActive: false,
          entitlementIsPromotional: false,
        ),
        PromoReminderAction.none,
      );
    });

    test('promo expired (RC data present, inactive) → cancel', () {
      expect(
        promoReminderAction(
          markerSet: true,
          customerInfoLoaded: true,
          entitlementActive: false,
          entitlementIsPromotional: false,
        ),
        PromoReminderAction.cancel,
      );
    });

    test('upgraded to PAID mid-promo (active but not promotional) → cancel',
        () {
      expect(
        promoReminderAction(
          markerSet: true,
          customerInfoLoaded: true,
          entitlementActive: true,
          entitlementIsPromotional: false,
        ),
        PromoReminderAction.cancel,
      );
    });

    test('non-promo user → none regardless of RC state', () {
      for (final loaded in [true, false]) {
        expect(
          promoReminderAction(
            markerSet: false,
            customerInfoLoaded: loaded,
            entitlementActive: true,
            entitlementIsPromotional: true,
          ),
          PromoReminderAction.none,
        );
      }
    });
  });
}
