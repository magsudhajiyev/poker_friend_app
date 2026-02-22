# TODO: Winner Selection Dialog Doesn't Close After Selection

**Date:** 2026-02-21
**Branch:** feature/dealer-assisted-logging
**Status:** TODO (Bug Fix)
**Priority:** High

---

## Bug Description

After the dealer selects the winner of a hand, the winner selection dialog box does not disappear. The dealer has to manually dismiss it or the dialog stays on screen.

---

## Current Behavior

1. Hand reaches completion (all actions done)
2. Winner selection dialog appears
3. Dealer taps on winning player
4. **Dialog remains visible on screen**
5. Dealer must manually close or tap elsewhere

---

## Expected Behavior

1. Hand reaches completion
2. Winner selection dialog appears
3. Dealer taps on winning player
4. **Dialog closes automatically**
5. Hand is saved, next hand can begin

---

## Implementation Notes

### Where to Fix

File: `lib/screens/dealer/dealer_table_screen.dart`

Look for the winner selection dialog callback. After processing the winner selection, ensure `Navigator.pop(context)` is called.

### Likely Issue

The dialog's onWinnerSelected callback might be missing the Navigator.pop() call, or it might be called before an async operation completes:

```dart
// Bug - dialog closes before async completes, or doesn't close at all
onWinnerSelected: (winnerId) async {
  await _completeHand(winnerId);
  // Missing: Navigator.pop(context);
}

// Fix
onWinnerSelected: (winnerId) async {
  Navigator.pop(context);  // Close dialog first
  await _completeHand(winnerId);
}

// Or if dialog manages its own state
onWinnerSelected: (winnerId) async {
  await _completeHand(winnerId);
  if (mounted) Navigator.pop(context);
}
```

### Alternative Issue

If using `showDialog`, the dialog might not have the correct context or the pop might be happening on wrong navigator:

```dart
// Ensure using the dialog's context, not parent context
showDialog(
  context: context,
  builder: (dialogContext) {
    return WinnerDialog(
      onSelect: (winner) {
        Navigator.pop(dialogContext);  // Use dialogContext, not context
        // ...
      },
    );
  },
);
```

---

## Related Files

- `lib/screens/dealer/dealer_table_screen.dart` - Winner selection logic
- `lib/widgets/winner_selection_dialog.dart` - Dialog widget (if separate)

---

## Acceptance Criteria

- [ ] Winner selection dialog closes immediately after dealer selects winner
- [ ] Hand completion logic still executes correctly
- [ ] No visual glitches or flicker when dialog closes
- [ ] Works for both single winner and chopped pot scenarios
