# Flutter 3.41.x Firestore Write Performance Regression — March 29, 2026

## Problem
After migrating from old laptop to new laptop, all Firestore write operations became extremely slow (multi-second delays per write). This affected:
- "Add Test Players" in dealer mode (18 sequential writes took 30+ seconds)
- All Firestore document creation/updates throughout the app
- Both Android device and iOS simulator

## Investigation Timeline
1. Initially suspected code issue — added batch optimization for test players (WriteBatch + Future.wait)
2. Rolled back to last known working commit (9f5b2d6) — **still slow**
3. Confirmed old laptop with same code, same phone, same WiFi worked perfectly
4. Ruled out: google-services.json, SHA-1 fingerprints, network, Firestore cache, debug keystore
5. Discovered old laptop had **Flutter 3.35.4**, new laptop had **Flutter 3.41.6**
6. Downgraded to Flutter 3.35.4 → Firestore writes fast again → **Flutter version was the root cause**

## Root Cause
**Flutter 3.41.x introduces a Firestore write performance regression.** The cloud_firestore plugin (and its underlying native SDK) resolved by Flutter 3.41.x has a significant performance degradation for document writes.

## Solution
Downgraded to **Flutter 3.38.10** as the sweet spot:
- Firestore writes are fast (like 3.35.4)
- Compatible with Xcode 26 (unlike 3.35.4 which can't target iOS 26 simulators)
- Requires iOS 18.5 simulator runtime (download via Xcode → Platforms → Get)

### Dependency Downgrades (pubspec.yaml)
All dependencies had to be downgraded to versions compatible with Flutter 3.38 / Dart 3.9:

| Package | 3.41.x Version | 3.38.x Version |
|---------|---------------|----------------|
| firebase_core | ^4.6.0 | ^3.8.0 |
| cloud_firestore | ^6.2.0 | ^5.5.0 |
| firebase_auth | ^6.3.0 | ^5.3.3 |
| firebase_messaging | ^16.1.3 | ^15.1.6 |
| flutter_local_notifications | ^21.0.0 | ^18.0.1 |
| purchases_flutter | ^9.15.1 | ^8.1.0 |
| fl_chart | ^1.2.0 | ^0.68.0 |
| socket_io_client | ^3.1.4 | ^2.0.0 |
| app_links | ^7.0.0 | ^6.1.1 |
| flutter_dotenv | ^6.0.0 | ^5.1.0 |
| intl | ^0.20.2 | ^0.19.0 |
| vibration | ^3.1.8 | ^2.0.0 |
| timezone | ^0.11.0 | ^0.9.4 |
| share_plus | ^12.0.1 | ^10.1.2 |
| google_fonts | ^8.0.2 | ^6.1.0 |
| mobile_scanner | ^7.2.0 | ^6.0.0 |
| record | ^6.2.0 | ^5.1.0 |
| web_socket_channel | ^3.0.3 | ^2.4.0 |
| flutter_bloc | ^9.1.1 | ^8.1.3 |

### API Compatibility Fixes
Three files required code changes due to older package APIs:

**notification_service.dart** (flutter_local_notifications v18 vs v21):
- `initialize(settings: initSettings)` → `initialize(initSettings)` (positional params)
- `zonedSchedule(id: ..., title: ..., body: ..., scheduledDate: ..., notificationDetails: ...)` → `zonedSchedule(id, title, body, scheduledDate, notificationDetails, ...)`
- `cancel(id: ...)` → `cancel(...)`
- `show(id: ..., title: ..., body: ..., notificationDetails: ...)` → `show(id, title, body, notificationDetails)`
- Added `uiLocalNotificationDateInterpretation` parameter to `zonedSchedule`

**subscription_service.dart** (purchases_flutter v8 vs v9):
- `Purchases.purchasePackage()` returns `CustomerInfo` directly in v8 (not a wrapper with `.customerInfo`)
- `result.customerInfo` → `result`

**session_analytics_screen.dart** (fl_chart v0.68 vs v1.2):
- `SideTitleWidget(meta: meta, ...)` → `SideTitleWidget(axisSide: meta.axisSide, ...)`

### iOS Simulator Setup
- Flutter 3.38.10 doesn't support iOS 26 simulators
- Downloaded iOS 18.5 runtime via Xcode → Settings → Platforms → iOS → Get
- Created iPhone 16 Pro simulator with iOS 18.5 runtime
- Both iOS 18.5 and iOS 26.1 runtimes coexist

### Debug Keystore
- Copied old laptop's debug.keystore to `~/.android/debug.keystore`
- SHA1: `9F:26:C7:87:7E:4E:AA:DE:7D:BF:03:37:96:BA:27:3D:52:9F:BA:60`
- New laptop's original backed up as `~/.android/debug.keystore.new-laptop-backup`
- Old keystore SHA-1 needs to be registered in Firebase Console for Google Sign-In

## Key Learnings
1. **Always check Flutter/SDK version** when debugging Firestore performance across machines
2. Flutter stable versions between 3.35 and 3.41 are sparse: only 3.35.x, 3.38.x, 3.41.x exist
3. When downgrading Flutter, ALL Firebase/plugin dependencies must be downgraded together
4. iOS simulator runtimes can coexist — download older ones via Xcode → Platforms
5. Debug keystore affects Google Sign-In but NOT basic Firestore operations

## Files Modified
- `pubspec.yaml` — downgraded all dependency constraints
- `pubspec.lock` — regenerated for Flutter 3.38.10
- `lib/services/notification_service.dart` — API compatibility (positional params)
- `lib/services/subscription_service.dart` — API compatibility (CustomerInfo directly)
- `lib/screens/session_analytics_screen.dart` — API compatibility (axisSide)
- `ios/Podfile.lock` — regenerated for compatible Firebase iOS SDK versions

## Development Environment (New Laptop)
- **Flutter**: 3.38.10 (DO NOT upgrade to 3.41.x until Firestore regression is fixed)
- **Dart**: 3.9.x (comes with Flutter 3.38.10)
- **Xcode**: 26.3
- **iOS Simulator**: iPhone 16 Pro with iOS 18.5 runtime
- **Android**: Physical device via USB debug
- **Debug Keystore SHA1**: 9F:26:C7:87:7E:4E:AA:DE:7D:BF:03:37:96:BA:27:3D:52:9F:BA:60

## Pending
- Register old keystore SHA-1 in Firebase Console for Google Sign-In OAuth
- Monitor Flutter releases for Firestore regression fix before upgrading
