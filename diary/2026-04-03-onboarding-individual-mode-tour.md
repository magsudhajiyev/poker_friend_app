# Onboarding — Individual Logging Mode Tour + Settings Redesign + Bug Fixes

**Date:** 2026-04-03

## Summary
Extended the onboarding system to fully support Individual Logging Mode alongside the existing Full Logging Mode tour. Redesigned the Settings Knowledge Base section with a collapsible Guided Tour that lists both tours separately. Fixed several onboarding bugs: progress bar not disappearing on skip, spotlight misalignment across devices, underlined text in completion dialog, and dev-only restrictions removed.

---

## Changes Overview

### 1. Individual Logging Mode Tour (New)
Added a complete guided tour for users who choose Individual Logging Mode. The tour covers:

**On IndividualSessionTrackingScreen (phase 3):**
- Update Stack button — teaches manual chip count updating
- Log a Hand button — prompts user to try logging a hand

**On QuickStackUpdateScreen (phase 3, sub-tour):**
- Checkmark icon (seat 1) — toggle seat occupied/empty
- Dealer Button "D" (seat 1) — assign dealer button position
- Player Name area (seat 1) — seat yourself or saved opponent (mentions auto stack)
- Stack Slider (seat 2) — drag to set opponent stack in BBs

**On PokerHandScreen (phase 4):**
- Reuses existing GuidedHandOverlay
- Skips menuSettings and endSession coach marks (not relevant for individual mode)
- After hand completion, overlay sets GuidedPhase.done without calling _finishOnboarding()

**Back on IndividualSessionTrackingScreen (post-hand):**
- Stop Session button (red circle) — highlighted after first hand returns
- Then advances to phase 5 (Sessions tab on home, reuses existing SessionResultTour)

### 2. OnboardingState Expansion
Added to `lib/onboarding/onboarding_state.dart`:
```dart
static bool isIndividualMode = false;
static bool individualTrackingTourPending = false;
static bool quickStackUpdateTourPending = false;
static bool individualStopSessionTourPending = false;
```

All flags are reset in `start()`, `cancel()`, `complete()`, `completeReplay()`.

`startFromPhase()` now accepts `{bool individualMode = false}` parameter for replay support.

### 3. Phase Branching
- `LoggingModeSelectionScreen._navigateToMode()` now records the mode choice on `OnboardingState.isIndividualMode`
- `SessionSetupTour.onFinish` sets `individualTrackingTourPending = true` when in individual mode
- Phase 3 branches: full mode → SeatSetupTour (as before), individual mode → IndividualTrackingTour → QuickStackUpdateTour
- `GuidedHandOverlay._showMenuSettingsCoachMark()` skips to endSession for individual mode
- `GuidedHandOverlay._showEndSessionCoachMark()` sets phase to done and returns without finishing onboarding (tour continues on tracking screen)

### 4. Settings Screen — Collapsible Guided Tour
Replaced the single "Guided Tour" toggle + "Logging a Hand" nav row with:
- **Collapsible "Guided Tour" header** using `AnimatedRotation` chevron + `AnimatedCrossFade` (same pattern as drawer clubs list)
- **Two sub-items when expanded:**
  - "Full Logging Tour" → `startFromPhase(1, individualMode: false)` → LoggingModeSelectionScreen
  - "Individual Logging Tour" → `startFromPhase(1, individualMode: true)` → LoggingModeSelectionScreen
- Kept "Understanding Your Stats" and "Clubs & Events" rows below
- Removed the toggle on/off — now you just tap the tour you want to replay
- Removed unused `_onboardingEnabled`, `_loadOnboardingState()`, `_toggleOnboarding()`, `OnboardingPrefs` import

### 5. LoggingModeTour — Mode-Specific Highlighting
When replaying from Settings, `LoggingModeTour` now only highlights the relevant mode card:
- Full Logging Tour replay → only highlights Full Logging Mode card
- Individual Logging Tour replay → only highlights Individual Logging Mode card
- Initial onboarding (not replay) → highlights both cards as before

### 6. Menu Settings Onboarding Step (Full Mode)
Added a new step between "Hand Complete" and "End Session" in the full mode guided hand:
- **Step 1:** Highlight 3-dot menu button → "Game Menu" / "This menu has useful options."
- **Step 2:** Programmatically open menu → highlight Settings item → "Game Settings" / "Here you can change blinds mid-session."
- Added `GuidedPhase.menuSettings` to the enum
- Added `settingsMenuItemKey`, `onOpenMenu`, `onCloseMenu` params to GuidedHandOverlay
- Added `_settingsMenuItemKey` GlobalKey to PokerHandScreen's Settings menu item

### 7. Bug Fixes (from earlier in session)

**Progress bar not disappearing on skip:**
- Root cause: `OnboardingState.cancel()` sets `isOnboardingActive = false` but no `setState` triggered
- Fix: Added `ValueNotifier<int> notifier` to `OnboardingState`, fires `_notify()` on every state change. `OnboardingProgressBar` wraps in `ValueListenableBuilder` for self-rebuilding.

**Spotlight misalignment across devices:**
- Root cause: `extendBody: true` on Scaffold shifted coordinate space for `tutorial_coach_mark`
- Attempted fix: Switched all `keyTarget` to `targetPosition` with `localToGlobal` — BROKE Xiaomi phone
- Final fix: Reverted to `keyTarget` (library-managed coordinates), removed `extendBody: true` from LoggingModeSelectionScreen and SeatSetupScreen, moved `_tableKey` to outer Expanded widget, used `addPostFrameCallback` + delay for scheduling
- Key lesson: **Never use `targetPosition` — it snapshots coordinates at call time which can be stale/wrong across devices. Always use `keyTarget`.**

**Seat setup table spotlight only highlighting right side:**
- Root cause: `_tableKey` was on inner Container (80% width, centered)
- Fix: Moved key to outer `Expanded` widget

**Underlined text in "You're All Set!" dialog:**
- Fix: Added `decoration: TextDecoration.none` to title and body TextStyles

**Dev-only restrictions removed:**
- Removed `_devUserId` constant and all `firebase_auth` imports from onboarding_tour.dart, guided_hand_overlay.dart, settings_screen.dart
- Knowledge Base and onboarding skip → markOnboardingSeen now works for all users

---

## New Tour Classes (in onboarding_tour.dart)

| Class | Screen | Phase | Guard |
|-------|--------|-------|-------|
| `IndividualTrackingTour` | IndividualSessionTrackingScreen | 3 | `individualTrackingTourPending` |
| `QuickStackUpdateTour` | QuickStackUpdateScreen | 3 | `quickStackUpdateTourPending` |
| `IndividualStopSessionTour` | IndividualSessionTrackingScreen | 3→5 | `individualStopSessionTourPending` |

## GuidedPhase Enum (Updated)
```
gestureInfo → scriptedAction → heroTurn → boardCards → holeCards → handComplete → menuSettings → endSession → done
```
- `menuSettings` and `endSession` are skipped for individual mode

## Files Modified

| File | Changes |
|------|---------|
| `lib/onboarding/onboarding_state.dart` | Added `isIndividualMode`, 3 sub-tour flags, `ValueNotifier`, updated `startFromPhase()` signature, resets in all lifecycle methods |
| `lib/onboarding/onboarding_tour.dart` | 3 new tour classes, `SessionSetupTour` branching, `LoggingModeTour` mode-specific highlighting, completion dialog text decoration fix |
| `lib/onboarding/guided_hand_overlay.dart` | Added `menuSettings` phase, `settingsMenuItemKey`/`onOpenMenu`/`onCloseMenu` params, skip logic for individual mode, removed dev-user checks |
| `lib/onboarding/onboarding_progress_bar.dart` | Converted to `ValueListenableBuilder` for reactive rebuilds |
| `lib/screens/settings_screen.dart` | Collapsible Guided Tour section, removed toggle/prefs, cleaned up unused code |
| `lib/screens/logging_mode_selection_screen.dart` | Records `isIndividualMode` on mode selection, removed `extendBody: true` |
| `lib/screens/individual_session_tracking_screen.dart` | Added 3 GlobalKeys, `OnboardingProgressBar`, tour scheduling in initState + post-hand |
| `lib/screens/quick_stack_update_screen.dart` | Added 4 GlobalKeys in `_buildPlayerRow`, `OnboardingProgressBar`, tour scheduling |
| `lib/screens/poker_hand_screen.dart` | Added `_settingsMenuItemKey`, passed new params to GuidedHandOverlay |
| `lib/screens/seat_setup_screen.dart` | Removed `extendBody: true`, moved `_tableKey` to Expanded |

## Flow Diagram

### Full Logging Mode (unchanged)
```
Home (phase 0) → LoggingMode (phase 1, both cards) → SessionSetup (phase 2)
→ SeatSetup (phase 3: table → seat dialog → button token)
→ HandLogging (phase 4: gestureInfo → scripted → hero → ... → handComplete → menuSettings → endSession)
→ Home (phase 5: sessions tab → "You're All Set!")
```

### Individual Logging Mode (new)
```
Home (phase 0) → LoggingMode (phase 1, both cards) → SessionSetup (phase 2)
→ IndividualTracking (phase 3: update stack → log hand)
→ QuickStackUpdate (phase 3: checkmark → button → player name → slider)
→ HandLogging (phase 4: gestureInfo → scripted → hero → ... → handComplete → DONE, skip menu/endSession)
→ IndividualTracking (phase 3→5: stop session button)
→ Home (phase 5: sessions tab → "You're All Set!")
```

### Settings Replay (new)
```
Settings → Guided Tour (expand) → "Full Logging Tour" or "Individual Logging Tour"
→ LoggingMode (phase 1, only relevant card highlighted) → same flow as above
→ On return: completeReplay() (doesn't mark as seen)
```

## Key Architecture Decisions

1. **Sub-tour flags vs new phases:** Used `individualTrackingTourPending`/`quickStackUpdateTourPending`/`individualStopSessionTourPending` flags within phase 3 rather than adding new phase numbers. This avoids breaking the existing 6-phase progress bar and keeps the architecture consistent with `seatDialogTourPending`/`buttonTokenTourPending`.

2. **GlobalKey placement in ListView:** Keys are assigned conditionally (`playerId == 1` for most, `playerId == 2` for slider) since `_buildPlayerRow` is called in a loop. Only the first two seats get keys — they're guaranteed to be visible without scrolling.

3. **GuidedHandOverlay skip pattern:** Rather than adding `isIndividualMode` checks deep in the phase machine, the skip happens at the two entry points (`_showMenuSettingsCoachMark` and `_showEndSessionCoachMark`). The overlay sets `GuidedPhase.done` and calls `onSkipOrFinish` without `_finishOnboarding()`, so the tour continues back on the tracking screen.

4. **Collapsible pattern reuse:** The Settings screen collapsible Guided Tour uses the exact same `AnimatedRotation` + `AnimatedCrossFade` pattern as the navigation drawer's clubs list, maintaining UI consistency.
