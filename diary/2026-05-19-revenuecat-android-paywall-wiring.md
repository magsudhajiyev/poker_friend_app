# RevenueCat Android Support + Paywall Purchase Flow Wiring

**Date**: 2026-05-19
**Status**: Confirmed working on Android device via sideload

## What Changed

### 1. Android RevenueCat API Key (`.env`)
- Replaced placeholder `goog_YOUR_ANDROID_API_KEY` with real RevenueCat Android API key
- Platform detection in `subscription_service.dart` already handled iOS vs Android key selection

### 2. Entitlement ID Fix (`subscription_service.dart`)
- Changed `premiumEntitlement` from `'premium'` to `'pro'` to match RevenueCat dashboard configuration

### 3. Paywall Purchase Flow (`paywall_screen.dart`)
- Added Monthly/Annual billing toggle at top of paywall
- Wired "Continue" button to RevenueCat `purchasePackage()` for Pro tier
- Elite/Club tiers show "coming soon" snackbar (not yet in RevenueCat)
- Prices fetched from RevenueCat offerings (with hardcoded fallbacks)
- Added restore purchases button in footer
- Added purchasing/restoring loading states
- Added new i18n keys across all 7 languages for paywall UI strings

### 4. RevenueCat ↔ Auth Integration (`auth_service.dart`, `auth_wrapper.dart`)
- `SubscriptionService.loginUser(uid)` called on: email sign-in, Google sign-in, Google linking
- `SubscriptionService.logoutUser()` called on sign-out
- Auth wrapper associates RevenueCat user on app restart with existing session
- All RevenueCat calls are fire-and-forget (`unawaited`) to not block auth flow

### 5. Version Bump (`pubspec.yaml`)
- Bumped from `1.0.2+9` to `1.0.2+10`

## Google Play Billing Testing Notes

### Prerequisites for Test Purchases
1. Upload signed AAB to Google Play Console internal test track
2. Add tester's Google account to **License testing** (Play Console → Setup → License testing)
3. Tester must **opt in** via internal test link (under Testers tab)
4. Wait 15-60 minutes for Play Store propagation
5. App must be installed **from Play Store** (not sideloaded) for billing to work

### Sideload Testing
- `flutter build apk --release` + `flutter install -d <device_id>` works for UI verification
- Sideloaded APKs cannot perform Google Play billing (shows "not configured for billing" error)
- Useful to verify code changes before Play Store propagation completes

### Common Error
- "This version of the application is not configured for billing through Google Play" — means the device hasn't received the test track build or account isn't a license tester

## Files Changed
- `.env` — Android API key
- `lib/services/subscription_service.dart` — entitlement ID fix
- `lib/screens/paywall_screen.dart` — purchase flow + billing toggle
- `lib/services/auth_service.dart` — RevenueCat login/logout hooks
- `lib/screens/auth_wrapper.dart` — RevenueCat user association on restart
- `lib/l10n/app_*.arb` + `app_localizations_*.dart` — new paywall strings
- `pubspec.yaml` — version bump to 1.0.2+10
- `ios/Products.storekit` — iOS StoreKit config
- `ios/Runner.xcodeproj/project.pbxproj` — Xcode project update
