# Onboarding Flow Changes Summary

## What Was Implemented

### Part 1: Pre-Release Reminder File
- **`pre_release.md`** (NEW) — Checklist of items to update before app store release (placeholder URLs, Firebase config, RevenueCat, etc.)

### Part 2: Auto-Generate Club Download QR Codes on Approval
- **`lib/models/club.dart`** — Added `appStoreQRUrl` and `playStoreQRUrl` fields to Club model (constructor, fromFirestore, fromMap, toFirestore, toMap, copyWith)
- **`lib/services/club_service.dart`** — Added `appStoreQRUrl` and `playStoreQRUrl` params to `updateClub()`
- **`lib/services/club_request_service.dart`** — In `approveRequest()`, auto-stores placeholder App Store + Play Store URLs on the club document after creation

### Part 3: Club QR PDF Download
- **`lib/screens/club/club_settings_screen.dart`** — Added `_buildAppQRSection()` (shows when club has store URLs) and `_downloadAppQRCodePDF()` (generates A4 PDF with two QR codes side by side for iOS/Android, using existing QrPainter + pdf + Share pattern)

### Part 4: Welcome Slides (Pre-Auth)
- **`lib/screens/intro_screen.dart`** — Converted from StatelessWidget to StatefulWidget with PageView. 4 pages: Track Every Hand, Know Your Game, Play at Clubs, Register/Login. Animated dot indicators, Skip button on slides.

### Part 5: Knowledge Base in Settings
- **`lib/screens/knowledge_base_screen.dart`** (NEW) — Info screens for "Understanding Your Stats" (7 metrics explained) and "Clubs & Events" (feature overview)
- **`lib/onboarding/onboarding_state.dart`** — Added `startFromPhase()`, `completeReplay()`, `isReplay` flag for Knowledge Base replay without marking onboarding as seen
- **`lib/screens/settings_screen.dart`** — Added "LEARN THE APP" section with 3 entries: Logging a Hand (replays tour from phase 2), Understanding Your Stats, Clubs & Events

### Part 6: Delayed Onboarding Nudge
- **`lib/screens/home_screen.dart`** — Dismissible nudge card ("New here? Take a quick tour") shown if user hasn't completed onboarding and hasn't dismissed it. "Start" button triggers onboarding, "X" dismisses permanently.
- **`lib/services/notification_service.dart`** — Added `scheduleOnboardingReminder()` (2hr delay after registration) and `cancelOnboardingReminder()`
- **`lib/screens/auth_screen_experimental.dart`** — Schedules onboarding reminder after successful email registration
- **`lib/onboarding/onboarding_prefs.dart`** — Cancels onboarding reminder when `markOnboardingSeen()` is called

## Files Changed (11 modified + 2 new)

| File | Type | Change |
|------|------|--------|
| `pre_release.md` | NEW | Pre-release checklist |
| `lib/screens/knowledge_base_screen.dart` | NEW | Stats & clubs info screens |
| `lib/models/club.dart` | Modified | QR URL fields |
| `lib/services/club_service.dart` | Modified | updateClub() QR params |
| `lib/services/club_request_service.dart` | Modified | Auto-store QR URLs on approval |
| `lib/screens/club/club_settings_screen.dart` | Modified | App QR PDF section + download |
| `lib/screens/intro_screen.dart` | Modified | Welcome slides PageView |
| `lib/onboarding/onboarding_state.dart` | Modified | startFromPhase() replay |
| `lib/screens/settings_screen.dart` | Modified | Learn the App section |
| `lib/screens/home_screen.dart` | Modified | Onboarding nudge card |
| `lib/services/notification_service.dart` | Modified | Onboarding reminder |
| `lib/screens/auth_screen_experimental.dart` | Modified | Schedule reminder on register |
| `lib/onboarding/onboarding_prefs.dart` | Modified | Cancel reminder on completion |

## Known Issue
- Welcome slides require a full app restart (not hot reload) to see after code change, since IntroScreen was converted from StatelessWidget to StatefulWidget.

## Remaining Plan Items (Not Yet Implemented)
- Welcome slides content could be enhanced with illustrations/images
- PDF download for individual table seat QR codes (already exists, just enhanced with app QR)
- Testing the full flow end-to-end on physical devices
