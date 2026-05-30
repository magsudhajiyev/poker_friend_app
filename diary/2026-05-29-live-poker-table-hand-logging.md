# Live Poker Table on Hand Logging Screen

**Date**: 2026-05-29
**Branch**: design_v2
**Commit**: 138d018

## Summary

Added a live poker table visualization to the hand logging screen, splitting the drawing board into two sections: a compact horizontal table on top and the gesture input area on the bottom.

## Changes

### Layout Restructure (`poker_hand_screen.dart`)
- Split the single Expanded drawing board into a Column with:
  - **Top (flex: 2)**: Live poker table via `_buildHandTable()`
  - **16px gap**
  - **Bottom (flex: 3)**: Gesture input area (tap/swipe/raise snap)
- Commented out the Pot/Stack/To Act info cards (no longer needed with table)
- Removed duplicate Next Hand button from below canvas
- Moved blinds pill + Next Hand button into the gesture area's Stack overlay
- Added session info (i) button next to Next Hand button

### Horizontal Rotated Table
- Renders `PokerTableWidget` in swapped dimensions with `RotatedBox(quarterTurns: 3)` for horizontal layout
- Each seat and center content counter-rotated (`quarterTurns: 1`) to keep text upright
- Uses `Table_clean.svg` (logo text removed) for clean table surface

### Seat Number Remapping
- Standard poker seating: seat 1 is immediately CW from the dealer (notch), seats go 1-9 clockwise
- `_widgetSeatToLogical()` / `_logicalSeatToWidget()` remap between widget positions and logical seat numbers
- All callbacks (tap, long-press, dealer button) use logical seat numbers

### Per-Seat Player State (`_buildHandSeat`)
- Shows: seat number pill, player name (blue badge or text), stack amount (cyan), status pill
- Status pills: FOLD (gray), ALL-IN (red), bet amount (blue), CHECK (green)
- Border colors: amber glow = current player, green = hero, faded green = folded, gray = empty
- Seats are ~20% smaller than default PokerTableWidget for compact fit

### Draggable Dealer Button
- `isDealerButtonDraggable: !handInProgress` — only draggable between hands
- On drop: updates button position, calls `gameState.initializePot()` to refund old blinds and post new ones
- Spade icon always points up via `dealerButtonQuarterTurns: 1` counter-rotation

### PokerTableWidget Enhancements
- `showLogo` param: when false, uses `Table_clean.svg` instead of `Table.svg`
- `dealerButtonSize` param: configurable button size (default 32, hand table uses 22)
- `dealerButtonQuarterTurns` param: counter-rotate button image to keep spade upright

## Bug Fixes

### Empty name collision when adding players
- **Problem**: Adding two unnamed players would cause the first one to be removed (both had empty string name, matched in `seatedPlayers` dedup map)
- **Fix**: Skip the "move player if already seated elsewhere" logic when `name.isEmpty`

### Board cards not appearing immediately
- **Problem**: After selecting board cards in the dialog, they didn't show on the table until the next action was taken
- **Fix**: Added `setState(() {})` in the `.then()` success callback of the board cards dialog (line ~4879)

## Files Modified
- `lib/screens/poker_hand_screen.dart` — Major layout restructure, new methods
- `lib/widgets/poker_table_widget.dart` — 3 new params (showLogo, dealerButtonSize, dealerButtonQuarterTurns)
- `assets/icons/Table_clean.svg` — New SVG (oval without logo text)

## Key Methods Added
- `_buildHandTable()` — Horizontal rotated table with remapped seats
- `_buildHandSeat()` — Compact seat with full player state
- `_buildTableCenterContent()` — Pot + board cards in table center
- `_buildCompactBoardCards()` — Compact 18x24px card display
- `_onDealerButtonMoved()` — Button drag handler with blind re-posting
- `_widgetSeatToLogical()` / `_logicalSeatToWidget()` — Seat remapping
- `_formatCompactAmount()` — Compact number formatting (1K, 1.5M, etc.)
