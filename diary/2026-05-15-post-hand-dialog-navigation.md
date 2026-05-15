# Post-Hand Dialog Chain: Full Back Navigation + Winner Confirm

**Date**: 2026-05-15
**Status**: Fixed & Verified

## Problems

### 1. Winner Selection — Instant Single-Tap
Tapping a player in the winner selection dialog immediately selected them AND saved, advancing to hole cards. No way to correct a mistap.

### 2. Hole Cards Back Button — All-In Path Broken
In the all-in code path (`_showWinnerSelectionForAllIn`), clicking the back chevron in the hero hole cards dialog skipped hole card selection entirely instead of going back to winner selection.

### 3. No Back Navigation on Opponent Hole Card Dialogs
After hero hole cards, opponent hole card dialogs (`HoleCardsDialog`) had no back button at all. Users couldn't go back to correct hero cards or navigate between opponents.

### 4. Back From Opponents Skipped Hero Cards (v1 bug during fix)
Initial implementation used a single while-loop for winner ↔ hero ↔ opponents. Going back from the first opponent's dialog triggered `continue` on the outer loop, which re-showed the **winner** dialog instead of hero hole cards — skipping one step.

## Root Causes

1. Single-tap in `WinnerSelectionDialog` called `_saveChanges()` immediately
2. `_showWinnerSelectionForAllIn` didn't have the while-loop pattern; `_processAllInWinnerResult` ignored `goBack` return
3. `HoleCardsDialog` had no back button — only Save/Skip/Skip All
4. Single while-loop can't distinguish "go back to hero" vs "go back to winner"

## Fixes

### Winner Selection Two-Step Confirm (`winner_selection_dialog.dart`)
- Single tap now **toggles selection** (highlight on/off) instead of immediately saving
- "Confirm Winner" button always visible (was only shown in chopped pot mode)
- Added `winnerSelectionConfirmWinner` i18n key to all 7 ARB files

### Hole Cards Back Chevron (`hole_cards_dialog.dart`)
- Added circular back-chevron button to `_buildHeader()` matching `HandReviewDialog` style
- Returns sentinel `HoleCards(card1: 'GO_BACK', card2: 'GO_BACK')` — same pattern as existing `SKIP_ALL`

### Opponent Cards Index-Based Navigation (`poker_hand_screen.dart`)
- `_showOpponentCardsDialog` return type changed from `Future<void>` to `Future<bool>`
- Replaced simple `for` loop with index-based `while` loop:
  - `GO_BACK` at index 0 → return `true` (go back to hero)
  - `GO_BACK` at index N>0 → decrement index (go to previous opponent)
  - `SKIP_ALL` / `null` → same behavior as before
- `usedCards` rebuilt dynamically each iteration (base cards + cards from earlier opponents only)
- Previously entered opponent cards preserved in local `opponentCards` map
- `barrierDismissible` changed to `false` (Skip button provides dismiss)

### Nested While-Loops for Correct Step Navigation (`poker_hand_screen.dart`)
Both `_showWinnerSelectionAndComplete` and `_showWinnerSelectionForAllIn` now use:
- **Outer loop**: Winner selection (hero goBack breaks inner, continues outer)
- **Inner loop**: Hero hole cards ↔ Opponent cards (opponent goBack continues inner → re-shows hero)

### All-In Path Restructure
- Moved `_showOpponentCardsDialog` from inside `_processAllInWinnerResult` into the while-loop
- Removed `Future.delayed` wrappers around opponent dialog
- Added `_extractWinnersFromResult` helper for multi-pot/single-pot winner extraction
- `_processAllInWinnerResult` now only handles pot distribution + hand completion

## Full Navigation Flow
```
Winner Selection  ← back ← Hero Hole Cards  ← back ← Opponent 1  ← back ← Opponent 2
     ↓ confirm              ↓ save                    ↓ save               ↓ save
Hero Hole Cards  →  forward → Opponent 1    → forward → Opponent 2 → forward → Hand Complete
```

## Files Changed
- `lib/widgets/winner_selection_dialog.dart` — two-step confirm
- `lib/widgets/hole_cards_dialog.dart` — back chevron + GO_BACK sentinel
- `lib/screens/poker_hand_screen.dart` — nested loops, index-based opponent navigation, _extractWinnersFromResult helper
- `lib/l10n/app_*.arb` + generated files — `winnerSelectionConfirmWinner` key

## Key Pattern: Nested While-Loops for Multi-Step Dialog Navigation
```dart
// Outer loop: step A ↔ step B+C
while (true) {
  resultA = await showDialogA();
  if (resultA == null) return; // cancelled

  // Inner loop: step B ↔ step C
  bool goBackToA = false;
  while (true) {
    final bGoBack = await showDialogB();
    if (bGoBack) { goBackToA = true; break; }

    final cGoBack = await showDialogC();
    if (cGoBack) continue; // re-show B

    break; // B+C done
  }
  if (goBackToA) continue; // re-show A

  break; // all done
}
```

## Testing
- [x] Forward-only flow: Winner → Hero → Opponents → completes
- [x] Back from first opponent → shows hero cards (not winner)
- [x] Back from opponent N → shows opponent N-1 with cards preserved
- [x] Back from hero → shows winner selection
- [x] Winner selection requires explicit confirm tap
- [x] Skip / Skip All still work
- [x] All-in path: same navigation works
