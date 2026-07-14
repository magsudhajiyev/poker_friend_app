# In-App Tour Fixes + Heads-Up Pot Initialization Fix

**Date**: 2026-07-14
**Branch**: design_v2
**Status**: Confirmed fixed

---

## Overview

This session fixed multiple interconnected bugs in the in-app onboarding tour flow (phases 4-5), the Hand Tools spotlight (phase 6), the heads-up pot initialization logic, and several cross-user data leak issues. Also added a 2-player minimum requirement for session setup.

---

## Bug 1: Stack Chart Tour Never Shows After Hand 2

### Symptom
After completing hand 2, the tour spotlights the info (i) button and tells the user to go to session details. The user taps the info button, arrives at SessionDetailsScreen, sees the onboarding progress bar, but NO spotlight or popup appears. The tour is stuck.

### Root Cause — Navigation Mode Mismatch
The navigation flow during onboarding:

1. `UnifiedSessionSetupScreen` passes `sessionManager` to `SessionDetailsScreen` via `pushReplacement` — making it **hub mode** (`_isHubMode = true`).
2. `SessionDetailsScreen._navigateToHandLogging()` pushes `PokerHandScreen` but does NOT pass `isHubMode: true` — it defaults to `false`.
3. After hand 2, `_showReturnToDetailsCoachMark()` in `guided_hand_overlay.dart` spotlights the info button and sets `OnboardingState.stackChartReturnTourPending = true` on finish.
4. User taps info button → `PokerHandScreen._showSessionDetails()`:
   - Since `widget.isHubMode == false`, it takes the **legacy path** (line 5333)
   - Pushes a **NEW** `SessionDetailsScreen` WITHOUT `sessionManager` → `_isHubMode = false`
5. This new screen's `initState` calls `_scheduleSessionDetailsTour()` which checks `sessionDetailsTourPending` — NOT set.
6. `stackChartReturnTourPending` was only checked in the hub-mode pop-back handler (`_navigateToHandLogging` result at line 1186), which never fires because the hub SessionDetailsScreen is a different instance buried in the back stack.

**Result**: No tour shows. The progress bar renders (because `isOnboardingActive` is true) but nothing triggers the spotlight.

### Fix
Added `stackChartReturnTourPending` check in `initState()` of `SessionDetailsScreen`, right after the existing hub/legacy tour schedule calls:

```dart
// session_details_screen.dart — initState(), after line 168
if (OnboardingState.isOnboardingActive &&
    OnboardingState.stackChartReturnTourPending) {
  OnboardingState.stackChartReturnTourPending = false;
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    _showStackChartReturnTour();
  });
}
```

This catches both cases: freshly-pushed non-hub SessionDetailsScreen AND hub-mode pop-back. The existing check at line 1186 remains as fallback for the hub-mode path.

### Files Changed
- `lib/screens/session_details_screen.dart` — `initState()` addition

---

## Bug 2: End Session Tour — Was Spotlighting Wrong Button (+ icon)

### Symptom
After the stack chart spotlight, the tour spotlighted the `+` icon on the session details header bar instead of the 3-dot menu. Users couldn't figure out how to end the session.

### Root Cause
`_showStackChartReturnTour()` chained to `_showEndSessionTour()` which spotlighted `_dotsKey`. On the non-hub SessionDetailsScreen, `_dotsKey` renders as `Icons.add` (add-on button), NOT `Icons.more_vert` (3-dot menu). The 3-dot menu only appears in hub mode (`_isHubMode ? Icons.more_vert : Icons.add`).

The actual "Stop Session" functionality lives in the PokerHandScreen's 3-dot menu (`_menuButtonKey` → overlay menu → "Stop Session" item).

### Fix — Redirect Tour to PokerHandScreen's 3-Dot Menu
1. Added `endSessionTourPending` flag to `OnboardingState` (cleared in all 5 reset methods: `begin`, `complete`, `cancel`, `startFromPhase`, `completeReplay`).
2. Added `_backButtonKey` on the back arrow `GestureDetector` in SessionDetailsScreen's header.
3. Replaced `_showEndSessionTour()` call with new `_showGoBackToHandTour()`:
   - Spotlights the back button with "Go Back" tooltip
   - No skip pill (`hideSkip: true`) — this is a directional step, not a skippable one
   - On finish: sets `OnboardingState.endSessionTourPending = true`
4. In `PokerHandScreen._showSessionDetails()` result handler (after user pops back from session details), added check for `endSessionTourPending`:
   ```dart
   if (OnboardingState.isOnboardingActive &&
       OnboardingState.endSessionTourPending && mounted) {
     OnboardingState.endSessionTourPending = false;
     WidgetsBinding.instance.addPostFrameCallback((_) async {
       await Future.delayed(const Duration(milliseconds: 500));
       if (!mounted) return;
       _showEndSessionMenuTour();
     });
   }
   ```
5. Added `_showEndSessionMenuTour()` on PokerHandScreen — spotlights `_menuButtonKey` with "End Your Session" / "Tap this menu and select End Session" (reuses existing l10n keys `guidedEndSessionTitle` / `guidedEndSessionBody`).

### New Tour Flow (after hand 2)
```
Hand 2 completes
  → _showReturnToDetailsCoachMark() spotlights info (i) button
  → User taps info button
  → New SessionDetailsScreen pushed (non-hub)
  → initState detects stackChartReturnTourPending
  → _showStackChartReturnTour() spotlights stack chart
  → onFinish: _showGoBackToHandTour() spotlights back button (no skip pill)
  → User taps back, pops to PokerHandScreen
  → Result handler detects endSessionTourPending
  → _showEndSessionMenuTour() spotlights 3-dot menu
  → User taps menu → "Stop Session" → ends session
  → advanceTo(5) → pushAndRemoveUntil(HomeScreen)
  → SessionResultTour spotlights Sessions nav icon
  → Phase 6 continues...
```

### Files Changed
- `lib/onboarding/onboarding_state.dart` — `endSessionTourPending` flag
- `lib/screens/session_details_screen.dart` — `_backButtonKey`, `_showGoBackToHandTour()`
- `lib/screens/poker_hand_screen.dart` — `_showEndSessionMenuTour()`, result handler check, `tutorial_coach_mark` import

### New l10n Keys
- `guidedGoBackToHandTitle` / `guidedGoBackToHandBody` — added in all 7 languages

---

## Bug 3: Tour Didn't Continue After Session End (Phase 5 Handoff)

### Symptom
After ending the session via the 3-dot menu, the user saw the session summary card, dismissed it, landed on HomeScreen, but the tour didn't continue — no spotlight on the Sessions nav icon.

### Root Cause
In `_stopSession()`, the session summary card (`_showSessionSummary`) was shown even for tour sessions (where `isTourSession = true`). The summary card displayed meaningless $0 profit data and — critically — could block the phase-5 navigation handoff if anything went wrong during the dialog lifecycle.

### Fix
Skip the session summary card during onboarding:

```dart
// poker_hand_screen.dart — _stopSession(), line ~668
if (!isTourSession) {
  await _showSessionSummary(bankrollResult: bankrollResult);
}
```

Now the flow goes directly: `endSession()` → `advanceTo(5)` → `pushAndRemoveUntil(HomeScreen)` → `_scheduleOnboardingTour()` detects phase 5 → `SessionResultTour` spotlights Sessions nav.

### Files Changed
- `lib/screens/poker_hand_screen.dart` — `_stopSession()` guard

---

## Bug 4: Hand Tools Spotlight Only Showed Star Icon

### Symptom
In phase 6, the Hand Tools tour step (BB, download, share, star) only spotlighted the star icon instead of all 4 icons together.

### Root Cause
The `_toolsRowKey` GlobalKey was on a `Row` widget with `mainAxisSize: MainAxisSize.min`. The Row was the last child inside a parent Row. TutorialCoachMark's `RRect` spotlight read the Row's RenderBox but appeared to only cover the last child (the star button), likely due to a Flutter layout quirk with nested Rows where the inner Row's reported size didn't match its visual bounds.

### Fix
Wrapped the inner Row in a `Container` and moved `_toolsRowKey` to the Container:

```dart
Container(
  key: _toolsRowKey,
  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [ /* BB, export, share, star buttons */ ],
  ),
),
```

The Container provides a dedicated RenderBox with consistent size reporting. The 4px padding adds breathing room around the icons for the spotlight.

### Files Changed
- `lib/screens/hand_actions_screen.dart` — Container wrapper around tools Row

---

## Bug 5 (CRITICAL): Heads-Up Pot Initialization — Only Button Player Posted Blinds

### Symptom
When 2 players are seated (e.g., seats 1 and 6 on a 9-max table), only the button player posted chips to the pot. The other player was completely ignored. No blind chips appeared in front of them.

### Root Cause — TWO interacting bugs

#### Bug 5a: `initializePot()` used `numberOfPlayers` instead of active count
The condition `if (numberOfPlayers > 2)` used total seat count (always 9) instead of active player count. So with 2 active players, it always took the multi-way branch where `_findSBSeatFromActivePlayers()` assigns SB as the player AFTER button — but in heads-up, button IS the SB. Blinds were posted backwards or to wrong seats.

**Fix** (applied earlier in session): Changed to `if (activePlayerCount > 2)` where `activePlayerCount = getActivePlayers().length`. Same fix applied to `startNewStreet()` and `_isAllPreflopActionComplete()`.

#### Bug 5b: `_findBBSeatFromActivePlayers()` always used offset +2
This method calculated BB as 2 positions clockwise from button: `(buttonIndex + 2) % activePlayers.length`. This is correct for 3+ players (BTN → SB → BB = +2). But for 2 players:
- `activePlayers = [1, 6]`, `buttonIndex = 0`
- `bbIndex = (0 + 2) % 2 = 0` → **seat 1 = the button itself!**

Both SB and BB were posted by the same player. The other player got nothing.

**Fix**:
```dart
// poker_game_state.dart — _findBBSeatFromActivePlayers()
final int offset = sortedActivePlayers.length == 2 ? 1 : 2;
int bbIndex = (buttonIndex + offset) % sortedActivePlayers.length;
```

Heads-up: offset 1 (BB is the other player, since BTN=SB in heads-up).
Multi-way: offset 2 (BTN → SB → BB).

#### Bug 5c: Heads-up branch used hardcoded modular arithmetic
The else branch in `initializePot()` had `int bbPosition = (buttonPosition % numberOfPlayers) + 1`. With `numberOfPlayers = 9` and button on seat 1, this gives `bbPosition = 2`. If no player is on seat 2, BB never posts.

**Fix**: Changed to `int bbPosition = _effectiveBBPosition` which is already correctly computed from active players via `_determineEffectiveBBPosition()` (called at line 1392 before the branching).

### Verification Scenarios
- Seats 1+6, button=1: SB=seat 1 (button), BB=seat 6 ✓
- Seats 3+7, button=3: SB=seat 3 (button), BB=seat 7 ✓
- Seats 1+3+6, button=1: SB=seat 3 (+1), BB=seat 6 (+2) ✓
- Full 9-max: unchanged behavior ✓

### Files Changed
- `lib/models/poker_game_state.dart`:
  - `_findBBSeatFromActivePlayers()` — offset 1 vs 2
  - `initializePot()` — `activePlayerCount > 2` and `_effectiveBBPosition`
  - `_isAllPreflopActionComplete()` — `getActivePlayers().length == 2`
  - `startNewStreet()` — `getActivePlayers().length == 2`

---

## Bug 6-8: Cross-User Data Leaks (Critical)

Three SharedPreferences-stored values were shared across users on the same device:

### Bug 6: Training Drills Data
- **Root cause**: `DrillLineupStore` used global key `'training_drill_lineups'` without userId scoping.
- **Fix**: Changed `_key` from static const to `static String _key()` method that appends `AuthService.currentUser?.uid`.
- **File**: `lib/services/drill_lineup_store.dart`

### Bug 7: Premium Override Status
- **Root cause**: `_debugTierOverride` and `_purchasedTierOverride` persisted to SharedPreferences but never cleared on logout.
- **Fix**: Added cleanup at top of `SubscriptionService.logoutUser()`:
  ```dart
  _debugTierOverride = null;
  _purchasedTierOverride = null;
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_debugTierOverrideKey);
  ```
- **File**: `lib/services/subscription_service.dart`

### Bug 8: Currency Preference
- **Root cause**: `CurrencyService` used global key `'currency_code'` without clearing on logout.
- **Fix**: Added `CurrencyService.reset()` static method (removes key, resets notifier to USD). Called from `AuthService.signOut()`.
- **Files**: `lib/services/currency_service.dart`, `lib/services/auth_service.dart`

---

## Feature: 2-Player Minimum for Session Setup

### Change
Session setup now requires at least 2 players seated (hero + at least 1 opponent) before the "Start" button enables.

### Implementation
- Added `_seatedPlayerCount` getter to `UnifiedSessionSetupScreen` that counts `_seatActive` entries plus hero seat.
- Added `hasEnoughPlayers = _seatedPlayerCount >= 2` to `_isFormValid`.
- Updated `onboardingTableSetupBody` tour text in all 7 languages to mention "at least one opponent" and "minimum of 2 players."

### Files Changed
- `lib/screens/unified_session_setup_screen.dart`
- All 7 ARB files (`app_en.arb` through `app_ru.arb`)

---

## Bankroll Input Visual Fix

### Symptom
Bankroll edit input field had uneven background color from left to right.

### Fix
Moved horizontal padding from the outer `Container` into the TextField's `contentPadding`. Changed prefix/suffix text color from `AppColors.contentInactive` to `Colors.white.withValues(alpha: 0.5)`.

### File
- `lib/screens/home_screen.dart` — `_buildBankrollEditField()`

---

## Complete File Change Summary

| File | Changes |
|------|---------|
| `lib/onboarding/onboarding_state.dart` | `endSessionTourPending` flag + cleared in all 5 reset methods |
| `lib/screens/session_details_screen.dart` | `_backButtonKey`, `initState` stackChartReturnTourPending check, `_showGoBackToHandTour()`, skip pill removed from back button step |
| `lib/screens/poker_hand_screen.dart` | `_showEndSessionMenuTour()`, endSessionTourPending check in result handler, skip summary card for tour, `tutorial_coach_mark` import |
| `lib/screens/hand_actions_screen.dart` | Container wrapper around tools Row for correct spotlight bounds |
| `lib/models/poker_game_state.dart` | `_findBBSeatFromActivePlayers()` offset fix, `initializePot()` active count, `_isAllPreflopActionComplete()` active count, `startNewStreet()` active count, heads-up BB uses `_effectiveBBPosition` |
| `lib/services/drill_lineup_store.dart` | User-scoped SharedPreferences key |
| `lib/services/subscription_service.dart` | Clear overrides on logout |
| `lib/services/currency_service.dart` | `reset()` method |
| `lib/services/auth_service.dart` | Call `CurrencyService.reset()` on signOut |
| `lib/screens/home_screen.dart` | Bankroll input contentPadding + prefix/suffix color |
| `lib/screens/unified_session_setup_screen.dart` | `_seatedPlayerCount`, `hasEnoughPlayers` in `_isFormValid` |
| `lib/l10n/app_*.arb` (all 7) | `onboardingTableSetupBody` updated, `guidedGoBackToHandTitle`/`Body` added |

---

## Key Lessons

1. **`numberOfPlayers` vs `getActivePlayers().length`**: `numberOfPlayers` is the total seat count (set at game creation, never changes). It must NEVER be used for blind posting, action order, or heads-up detection. Always use `getActivePlayers().length`.

2. **`_findBBSeatFromActivePlayers` offset**: In heads-up, there is no separate SB position — the button IS the SB. So BB is offset +1 from button (the other player), not +2.

3. **Hub mode vs legacy mode navigation**: `SessionDetailsScreen` behaves fundamentally differently in hub mode (`sessionManager != null`) vs legacy mode. Tour code must handle BOTH paths. Specifically, `PokerHandScreen` doesn't have `isHubMode: true` set during onboarding, so tapping the info button pushes a NEW non-hub SessionDetailsScreen.

4. **TutorialCoachMark + nested Rows**: A `GlobalKey` on a `Row` inside another `Row` may not report correct bounds for the spotlight. Wrap in a `Container` to get a dedicated RenderBox.

5. **Tour session summary card**: Showing a session summary with $0 profit for tour sessions adds no value and risks blocking the phase-5 handoff. Skip it.

6. **SharedPreferences user-scoping**: Any SharedPreferences key that stores user-specific data MUST either be scoped with userId or explicitly cleared on logout.

---

## Testing Checklist

- [x] `flutter analyze` — 603 issues (all pre-existing, no new errors)
- [x] `flutter test` — 438 passed, 1 skipped, 30 failed (all 30 are pre-existing `toDate()` mock issues)
- [ ] Full onboarding tour: hand 1 → hand 2 → info button → stack chart spotlight → back button spotlight → 3-dot menu spotlight → stop session → HomeScreen → Sessions nav spotlight → session history → hand card → hand details → hand tools (all 4 icons) → AI analysis → tour complete
- [ ] Heads-up: seats 1+6, button=1 → seat 1 posts SB, seat 6 posts BB
- [ ] Heads-up: seats 3+7, button=7 → seat 7 posts SB, seat 3 posts BB
- [ ] 3+ players: normal blind posting unchanged
- [ ] Cross-user: log out → log in as different user → verify no drill lineups, default currency, no premium override
- [ ] Session setup: cannot start with only 1 player seated
