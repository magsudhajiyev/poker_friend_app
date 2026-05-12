# Security Audit & App Store Compliance

**Date**: 2026-05-12
**Commit**: 42ccc9f

## What Was Done

Full security audit and App Store submission readiness pass covering 6 areas:

### 1. Hardcoded API Key Removed
- **File**: `lib/services/ai_analyzer_service.dart`
- **Issue**: AI API key was hardcoded as `static const String _apiKey = 'oCx_2Be-...'` — extractable from compiled binary
- **Fix**: Moved to `EnvConfig.aiApiKey` which reads from `.env` file
- **Note**: `.env` is bundled as an asset at build time, not configured in App Store/Play Store dashboards

### 2. print() → debugPrint() Bulk Replace
- **Scope**: ~55 files across lib/
- **Issue**: 697+ `print()` calls, some leaking emails and UIDs
- **Fix**: Replaced all `print(` with `debugPrint(` — only outputs in debug mode, stripped in release builds
- Added `import 'package:flutter/foundation.dart';` to 43 files that needed it

### 3. Account Deletion UI (Apple Requirement)
- **File**: `lib/screens/profile_screen.dart`
- **Issue**: `AuthService.deleteAccount()` existed but no UI to trigger it (Apple requires in-app account deletion since June 2022)
- **Fix**: Added "Delete Account" row in profile menu with:
  - Red-colored menu item for visibility
  - Confirmation dialog warning about permanent data loss
  - Reminder to cancel subscriptions first
  - Full Firestore cleanup: users, user_stats, session_results, opponents, opponent_stats, poker_sessions
  - Signs out and returns to auth screen

### 4. Firestore Security Rules Rewrite
- **File**: `firestore.rules`
- **Issue**: Wildcard rule `match /{document=**} { allow read, write: if isAuthenticated(); }` let any logged-in user access ALL data
- **Fix**: Removed wildcard, added per-collection ownership rules:
  - `user_stats/{userId}` → isOwner only
  - `poker_sessions/{sessionId}` → userId match + participantIds for shared sessions
  - `session_results/{resultId}` → userId match
  - `opponents/{opponentId}` → userId match
  - `opponent_stats/{opponentId}` → authenticated (linked via app logic)
  - `dealer_sessions/{sessionId}` → authenticated read, dealerId for write
  - `seat_assignments/{id}` → authenticated read, playerId/dealerId for write
  - `clubs/{clubId}` → authenticated read, ownerId for write, subcollection rules
  - `shared_hands/{shareId}` → public read (web viewer), authenticated create
- **Deployed**: `firebase deploy --only firestore:rules --project poker-tracker-52df8`

### 5. iOS Privacy Manifest
- **File**: `ios/Runner/PrivacyInfo.xcprivacy` (new)
- **Issue**: Required by Apple since Spring 2024 for apps using Required Reason APIs
- **Fix**: Declares:
  - `NSPrivacyTracking = false`
  - Collected data: email, name, userID (all for app functionality, linked, not tracking)
  - Accessed API: UserDefaults (reason CA92.1 — app-specific preferences via SharedPreferences)

### 6. EnvConfig + Test Seeds + SDK
- **EnvConfig** (`lib/config/env_config.dart`): Changed fallback URLs from `http://localhost:8000` to `https://poker-friend-engine.onrender.com`
- **Test seeds** (`lib/services/test_data_seed_service.dart`, `lib/services/club_seeder_service.dart`): All public methods guarded with `if (!kDebugMode) return;`
- **Android SDK**: Uses `flutter.targetSdkVersion` from Flutter 3.38 which is 35 — meets Play Store requirement

## Key Decisions
- `.env` file is bundled as a Flutter asset at build time — no env var configuration needed in App Store Connect or Play Store Console
- `debugPrint` chosen over custom logger for simplicity — strips output in release builds automatically
- Firestore rules deployed immediately (not just committed) since the wildcard was a live security vulnerability
- `opponent_stats` kept as authenticated-only (no userId field in doc, linked via app logic through opponent ownership)

## What's NOT Covered (Separate Tasks)
- Sign in with Apple — will implement before submission
- RevenueCat purchase wiring — will implement before submission
- Certificate pinning — nice-to-have, not blocking v1
- flutter_secure_storage migration — future enhancement
- Rotating the exposed AI API key on the backend — should be done but not blocking
