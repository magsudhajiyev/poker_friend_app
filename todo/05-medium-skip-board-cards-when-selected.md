# TODO: Skip Board Cards Dialog When Already Selected During All-In

**Date:** 2026-02-21
**Branch:** feature/dealer-assisted-logging
**Status:** TODO (Future Enhancement)
**Priority:** Medium

---

## Problem Description

When a hand goes to showdown with all players all-in on the river, the dealer is prompted to select community cards again via the board cards selection dialog, even though they have already selected all 5 community cards (flop, turn, river) throughout the hand.

This creates unnecessary friction for the dealer.

---

## Current Behavior

1. Dealer deals flop, selects 3 flop cards
2. Dealer deals turn, selects turn card
3. Dealer deals river, selects river card
4. All players go all-in on river
5. Hand goes to showdown
6. **Dealer is prompted again to select all 5 community cards** (redundant)

---

## Expected Behavior

1. Dealer deals flop, selects 3 flop cards
2. Dealer deals turn, selects turn card
3. Dealer deals river, selects river card
4. All players go all-in on river
5. Hand goes to showdown
6. **System uses already-selected board cards, no dialog shown**

---

## Implementation Notes

### Where to Fix

File: `lib/screens/dealer/dealer_table_screen.dart`

Look for the all-in showdown handling logic (likely in `_handleAllInShowdown()` or similar method).

### Logic Change

Before showing `AllInBoardCardsDialog`, check if board cards are already complete:

```dart
// Check if we already have all board cards
final hasCompleteBoard =
    _boardCards.flop.isNotEmpty &&
    _boardCards.turn != null &&
    _boardCards.river != null;

if (hasCompleteBoard) {
  // Skip dialog, proceed directly to winner selection
  _showWinnerSelectionDialog();
} else {
  // Show dialog to collect missing cards
  _showAllInBoardCardsDialog();
}
```

### Edge Cases to Consider

1. **All-in preflop**: No board cards selected yet - show dialog for all 5 cards
2. **All-in on flop**: Only flop cards selected - show dialog for turn + river
3. **All-in on turn**: Flop + turn selected - show dialog for river only
4. **All-in on river**: All 5 cards already selected - skip dialog entirely

---

## Related Files

- `lib/screens/dealer/dealer_table_screen.dart` - Main dealer screen
- `lib/widgets/all_in_board_cards_dialog.dart` - Board cards selection dialog
- `lib/models/board_cards.dart` - Board cards state model

---

## Acceptance Criteria

- [ ] When all 5 board cards are already selected, skip the board cards dialog on all-in showdown
- [ ] When some board cards are missing, show dialog for only the missing cards
- [ ] Existing all-in preflop flow continues to work (show full 5-card dialog)
