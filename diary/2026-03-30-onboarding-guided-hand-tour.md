# Onboarding System — Multi-Screen Tour + Reactive Guided Hand

**Date:** 2026-03-30

## Summary
Implemented a complete 6-phase onboarding tour that guides first-time users through the entire hand logging flow, from home screen to session results.

## Phases
- **Phase 0 (Home):** Welcome overlay, highlights FAB button to start logging
- **Phase 1 (Logging Mode):** Highlights Full Session option
- **Phase 2 (Session Setup):** Highlights start button
- **Phase 3 (Seat Setup):** Seat dialog tour + button token tour
- **Phase 4 (Hand Logging):** Reactive guided example hand (see below)
- **Phase 5 (Session Result):** Highlights Sessions nav tab, then shows "You're All Set!" completion dialog

## Phase 4 — Reactive Guided Hand
The guided hand adapts to user choices rather than following a fixed script:

1. **Gesture Info Spotlight** — TutorialCoachMark on the info icon to teach gesture controls
2. **Scripted pre-hero actions** — UTG opens (tap to bet), others fold until hero's turn
3. **Hero's turn** — Shows all valid actions with gesture hints (teal highlight)
4. **Adaptive reactions** — After hero acts:
   - Fold → next player calls, rest fold, hand continues with 2 players
   - Call → remaining fold, flop with hero + opener
   - Raise → opener calls, rest fold, flop with hero + opener
5. **Postflop repeats** — Each street adapts to hero's choice
6. **End of hand** — Hole cards → opponent cards → "Hand Complete!" → 3-dot menu spotlight → stop session

## Key Architecture
- `OnboardingState` (static singleton) tracks progress across screens
- `GuidedPhase` enum: `gestureInfo → scriptedAction → heroTurn → boardCards → holeCards → handComplete → endSession → done`
- `GuidedHandOverlay` widget with `liveCurrentPlayer` callback to avoid stale widget params
- `onSkipOrFinish` callback notifies parent to rebuild (hides progress bar)

## Files Created
- `lib/onboarding/onboarding_state.dart` — Cross-screen state tracker
- `lib/onboarding/onboarding_tour.dart` — TutorialCoachMark tours for each phase
- `lib/onboarding/guided_hand_overlay.dart` — Reactive floating overlay for Phase 4
- `lib/onboarding/onboarding_progress_bar.dart` — Thin progress indicator
- `lib/onboarding/onboarding_prefs.dart` — SharedPreferences for seen/unseen

## Files Modified
- `lib/screens/home_screen.dart` — Phase 0 + Phase 5 tours, sessions nav key
- `lib/screens/logging_mode_selection_screen.dart` — Phase 1 tour
- `lib/screens/individual_session_setup_screen.dart` — Phase 2 tour
- `lib/screens/seat_setup_screen.dart` — Phase 3 tour (seat dialog + button token)
- `lib/screens/poker_hand_screen.dart` — Phase 4 overlay integration, notification hooks
- `lib/screens/settings_screen.dart` — "Replay Onboarding" option
- `lib/widgets/global_bottom_nav_bar.dart` — Sessions nav key param
- `pubspec.yaml` — Added `tutorial_coach_mark: ^1.2.11`

## Bugs Fixed During Development

### Off-by-one hero detection
**Problem:** Overlay checked `widget.currentPlayerSeat == heroSeat` but the widget param was stale after `gameState.performAction()` advanced currentPlayer.
**Fix:** Added `liveCurrentPlayer` callback that reads `gameState.currentPlayer` directly at decision time.

### 3-dot coach mark fired before dialogs closed
**Problem:** `onHoleCardsCompleted()` was called inside `_showHoleCardsDialog()`, but opponent cards dialog runs after that. Coach mark appeared over the opponent cards dialog.
**Fix:** Moved `onHoleCardsCompleted()` to after ALL dialogs (hole cards + opponent cards) complete in each hand-completion path.

### New hand started during onboarding end-of-hand
**Problem:** After hand completed, code immediately called `gameState.startNewHand()` which disrupted the endSession coach mark flow.
**Fix:** Added `OnboardingState.isGuidedHandActive` guard in 3 places to skip starting next hand during onboarding.

### Undo desynced overlay state
**Problem:** `_undoLastAction()` restored game state but never notified the guided overlay. Progress counter and phase got out of sync.
**Fix:** Added `onActionUndone()` method that decrements counter and re-evaluates current phase.

### Progress bar persisted after skip/completion
**Problem:** `OnboardingProgressBar` is a StatelessWidget inside poker_hand_screen and home_screen. `skip()` called `OnboardingState.complete()` but only the overlay's setState fired, not the parent.
**Fix:** Added `onSkipOrFinish` callback to overlay and `onComplete` callback to SessionResultTour. Parents pass `() => setState(() {})`.
