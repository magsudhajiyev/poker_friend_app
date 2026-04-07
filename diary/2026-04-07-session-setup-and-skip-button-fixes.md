# Session Setup Validation & Skip Button Confirmation

**Date:** 2026-04-07

## Changes

### 1. Tournament Starting Stack Validation
**File:** `lib/screens/individual_session_setup_screen.dart`

**Problem:** Users could set a starting stack lower than the big blind for tournament games (e.g., stack=50, BB=200), which makes no poker sense.

**Fix:**
- `isFormValid` now requires `startingStack >= bigBlind` for tournaments
- Starting Stack TextField border turns red when value < big blind
- Error text appears below: "Starting stack must be at least equal to the Big Blind (X)"
- Error only shows when a parseable value is entered (not when field is empty)
- Re-validates automatically when big blind is changed

### 2. Skip Button Confirmation During Active Hand
**File:** `lib/screens/poker_hand_screen.dart`

**Problem:** The >| (skip/forward) button instantly discards the current hand and moves the dealer button — even when actions have been taken mid-hand. No warning, easy to accidentally lose hand progress.

**Fix:**
- When `sessionManager.currentHand.actions` is non-empty, a confirmation dialog appears before skipping
- Dialog: "Hand in Progress" — "There's a hand in progress. Moving to the next hand will discard all actions and restore player stacks."
- Actions: Cancel / Move to Next Hand
- If no actions taken (just blinds posted), skips immediately as before

**Bug also fixed:** Added `sessionManager.currentHand = null` before calling `sessionManager.startHand()` during skip. Previously, `startHand()` would detect actions on the current hand and call `completeCurrentHand()`, saving an incomplete/garbage hand to Firebase and SQLite. Now the hand is properly discarded.

## Key Pattern
- Detect mid-hand state: `sessionManager.currentHand?.actions.isNotEmpty == true`
- Stack rollback on skip: existing refund loop adds back `betThisRound + totalContribution` to each player's stack
- Discard hand record: set `sessionManager.currentHand = null` before `startHand()` to prevent saving
