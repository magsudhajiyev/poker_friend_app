# Hand Logging Phase 3 Cleanup & UX Improvements

**Date**: 2026-04-23
**Status**: Complete

## Summary

Major cleanup of the hand logging flow: removed legacy gesture system, simplified settings, improved table management, and added opponent search to mid-session player additions.

## Changes

### Gesture System Simplification
- Removed old drawing-based gesture mode (circle=call, line=fold, L-shape=raise)
- Quick swipe is now the only gesture mode (tap=check/call, swipe out=fold, swipe up=raise)
- Removed ~507 lines of dead gesture code from `poker_hand_screen.dart`
- Removed `GestureModeService` (now unused)
- Updated gesture info tooltip to show new gestures instead of old drawing ones
- Fixed tooltip pushing drawing board down — now renders as `Positioned` overlay in Stack

### Settings Cleanup
- Removed auto-advance toggle — always auto-advance (removed from settings_screen.dart and game settings dialog)
- Removed Game Settings from 3-dot menu entirely (only BB ante remained, which is immutable per CLAUDE.md)
- Removed `_SettingsDialog` class and `_showSettingsDialog()` method
- "Change Table" now available for both cash games AND tournaments (was cash-only)

### Raise / Bet Improvements
- Fixed minimum re-raise logic: now correctly uses `currentBet + lastRaiseSize` (not just `currentBet * 2`)
- Added `_lastRaiseSize` tracking through all bet/raise/blind code paths in `PokerGameState`
- Raise snap multipliers (2.2x, 2.5x, 3x) now use last bet as base when facing a raise
- Fixed cluttered snap points — capped at 2 intermediates per gap with adaptive step sizing
- Visual hierarchy: key labels (x multipliers, Pot, All-In, Min) bold/larger, round numbers lighter/smaller
- Track line no longer extends beyond All-In/Min dots

### Blinds Display
- Moved blinds from Game Settings dialog to tappable pill next to table icon (top-left)
- Tapping opens side-by-side SB/BB edit dialog

### Table Management
- Added dealer button selector (row of seat chips) to table management sheet
- Added "This is me" toggle to Add Player sheet — allows moving hero to different seat
- Added opponent search with autocomplete when adding players mid-session
- Added "Save as opponent" option for new names
- Already-seated opponents show "Seat #" badge in search results
- Reseating: selecting an already-seated player auto-clears their old seat
- Stack range circles locked after preflop (no accidental stack changes during hand)

### Session Setup (unified_session_setup_screen.dart)
- "This is me" now properly clears the old hero seat when moving
- Opponent reseating works — selecting already-seated player clears old seat
- Seat badges shown in opponent search results

### Poker Table Widget
- Table shape now truly elliptical (Radius.elliptical instead of circular)
- Proportions: wider (0.85) and shorter (0.72) for realistic poker table look
- Seat positions shifted one position clockwise
- Label placement variants updated for new positions

### Bug Fixes
- Fixed "Folded to me" button reappearing after hero folds (caused confusing hand completion)
- Fixed gesture tooltip pushing drawing board down (overlay instead of Column child)

## Files Changed

### Modified
- `lib/screens/poker_hand_screen.dart` — Major: -2320/+1596 lines
- `lib/models/poker_game_state.dart` — `_lastRaiseSize`, `getMinimumRaise()` fix
- `lib/models/hand_state_machine.dart` — `currentTableNumber` support
- `lib/screens/settings_screen.dart` — Removed auto-advance
- `lib/screens/logging_mode_selection_screen.dart` — Routes to unified setup
- `lib/screens/unified_session_setup_screen.dart` — Hero reseating, opponent reseating, seat badges
- `lib/widgets/poker_table_widget.dart` — Elliptical shape, seat shift
- `lib/widgets/winner_selection_dialog.dart` — Single-tap select
- `lib/widgets/board_cards_dialog.dart` — Skip button, CardKeyboard migration
- `lib/widgets/hole_cards_dialog.dart` — CardKeyboard migration
- `lib/widgets/hand_review_dialog.dart` — CardKeyboard migration
- `lib/widgets/all_in_board_cards_dialog.dart` — CardKeyboard migration
- `lib/widgets/seat_config_sheet.dart` — Seat badges for opponents
- `lib/widgets/table_management_sheet.dart` — BTN selector, This is me, opponent search

### New Files
- `lib/widgets/card_keyboard.dart` — Shared card selection widget
- `lib/widgets/raise_snap_overlay.dart` — Snap point overlay for raise gesture
- `lib/widgets/table_management_sheet.dart` — Table state management bottom sheet
- `lib/widgets/seat_config_sheet.dart` — Per-seat config with opponent search
- `lib/widgets/stack_range_circle.dart` — Stack range display widget
- `lib/models/stack_bucket.dart` — BB bucket enum + confidence
- `lib/screens/unified_session_setup_screen.dart` — Merged session + seat setup

### Not Included (dead code)
- `lib/services/gesture_mode_service.dart` — No longer imported anywhere, not committed

## Key Technical Notes

### Minimum Raise Formula
```dart
double getMinimumRaise() {
  if (currentBet == 0) return bigBlind.toDouble();
  final raiseSize = _lastRaiseSize > 0 ? _lastRaiseSize : bigBlind.toDouble();
  return currentBet + raiseSize;
}
```
`_lastRaiseSize` is tracked through: bet actions, raise actions, dealer actions, blind posting, and reset at street/hand boundaries.

### Snap Point Visual Hierarchy
- Key labels (`isKeyPoint`): contains 'x', '%', 'Pot', 'All-In', 'Min' → 13px w600
- Round numbers: 11px w400, lower opacity
- Max 2 intermediate round numbers per gap between key points
