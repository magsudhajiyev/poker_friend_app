# Google SSO Integration

**Date**: 2026-03-28
**Status**: Completed

## What Was Done
- Added Google Sign-In as authentication option on login and create account screens
- Account deduplication: if user tries Google SSO with an email already registered via email/password, a linking dialog prompts for password and merges accounts
- Google profile photo synced to Firebase Auth and Firestore, displayed in navigation drawer and profile screen
- Greeting on home screen shows first name only ("Hey, John" not "Hey, John Smith")

## Files Changed
- `pubspec.yaml` — added `google_sign_in: ^6.2.2`, `cached_network_image: ^3.3.1`, registered `assets/icons/` directory
- `lib/services/auth_service.dart` — added `signInWithGoogle()`, `linkGoogleToExistingAccount()`, `_syncGoogleProfileData()`, `userPhotoURL` getter, `GoogleSignInAccountLinkException` class, `serverClientId` on GoogleSignIn init, updated `signOut()` to also sign out of Google
- `lib/screens/intro_screen.dart` — reverted to StatelessWidget, removed Google button (kept only Create Account + Log In)
- `lib/screens/auth_screen_experimental.dart` — added OR divider + "Continue with Google" button to both sign-up and sign-in forms
- `lib/screens/profile_screen.dart` — avatar shows Google photo via CachedNetworkImage when available, falls back to initials
- `lib/widgets/navigation_drawer.dart` — same avatar logic as profile screen
- `lib/design_system/components/headers/home_header.dart` — greeting uses first name only via `split(' ').first`
- `android/app/google-services.json` — updated with OAuth client IDs after adding SHA-1 fingerprint
- `ios/Runner/Info.plist` — added REVERSED_CLIENT_ID URL scheme for iOS Google Sign-In
- `assets/icons/google_logo.svg` — Google "G" logo for buttons

## Setup Requirements (Not Code)
- SHA-1 debug fingerprint added to Firebase Console for Android app
- Google sign-in provider enabled in Firebase Console → Authentication → Sign-in method
- iOS: REVERSED_CLIENT_ID URL scheme configured in Info.plist

## Key Decisions
- `serverClientId` (web client type 3) must be passed to `GoogleSignIn()` on Android — without it, `DEVELOPER_ERROR` occurs
- Account linking uses `GoogleSignInAccountLinkException` custom exception to signal UI to show password dialog
- Photo sync is non-fatal — errors caught silently so sign-in still completes
- FCM setup runs in background after Google sign-in (fire-and-forget)
- CocoaPods required `pod update GTMSessionFetcher --repo-update` to resolve version conflict between GoogleSignIn and FirebaseAuth

## Bug Patterns to Remember
- `DEVELOPER_ERROR` on Android Google Sign-In = missing SHA-1, missing serverClientId, or Google provider not enabled in Firebase Console
- `google-services.json` must contain `oauth_client` entries with `client_type: 1` (Android) and `client_type: 3` (Web) — empty `oauth_client: []` means SHA-1 wasn't added
- `assets/icons/` directory must be registered in `pubspec.yaml` under `flutter.assets` — asset files exist but Flutter won't find them without this
