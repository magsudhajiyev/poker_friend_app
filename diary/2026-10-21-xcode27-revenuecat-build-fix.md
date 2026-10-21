# 2026-10-21 — iOS build broken on Xcode 27: RevenueCat `PaywallColor` errors

## Symptom
Archiving for TestFlight failed inside the RevenueCat pod:
`Ambiguous use of 'init(light:dark:)'` / `Invalid redeclaration of synthesized
memberwise 'init(...)'` on `PaywallColor` (RevenueCatUI).

## Cause
The dev Mac now has **Xcode 27.0 / Swift 6.4** (Xcode 26.3 is no longer
installed). The app was on `purchases_flutter` ^9.15.1 → 9.16.1, and EVERY
9.x release pins RevenueCat iOS **5.67.x**, which does not compile with
Swift 6.4. RevenueCat fixed this in iOS SDK 5.78; only `purchases_flutter`
10.x pulls those versions.

## Fix
- `pubspec.yaml`: `purchases_flutter: 10.15.2` (pinned; RevenueCat iOS 5.94.0,
  PurchasesHybridCommon 19.10.0 — includes the Xcode 27 compile fix and the
  Xcode 27 Customer Center crash fix). Chose a release ≥2 weeks old.
- `pod update purchases_flutter PurchasesHybridCommon RevenueCat`.
- No Dart change was needed: all SDK calls are isolated in
  `lib/services/revenuecat_client.dart`, and the 10.x breaking changes
  (Android Billing 8.3 / minSdk 23 — app is 24; consumables — app has none)
  do not touch our API surface.

## Verified
`flutter build ios --release --no-codesign` ✓ (Xcode 27), `flutter build apk
--debug` ✓, subscription tests (24) ✓. Archive then reached App Store Connect
(the next blocker, "You do not have required contracts", was an unaccepted
agreement in the developer account — not code).

## Still owed
The on-device RevenueCat sandbox matrix (iOS + Android: all 6 packages,
restore, cancel-and-repurchase, external cancellation, promo entitlement) —
it was never run for Billing 8.0 and is now more important after the 10.x bump.
