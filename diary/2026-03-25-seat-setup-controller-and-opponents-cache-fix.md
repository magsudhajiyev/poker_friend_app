# Seat Setup Controller Disposal and Opponents Cache Fix

**Date:** 2026-03-25

## Problem 1: TextEditingController Used After Disposal

When adding an opponent on the seat setup screen, the following error occurred:
```
A TextEditingController was used after being disposed.
```

**Root Cause:**
In `_showSeatDialog()`, temporary `TextEditingController`s were created for the modal bottom sheet. The `saveChanges()` function called `setState()` before `Navigator.pop()`, which triggered a widget rebuild while the dialog was closing. The `.then()` callback disposed the controllers immediately when `pop()` was called, but the closing animation was still running and trying to access the disposed controllers.

**Solution:**
1. Changed `saveChanges()` to only pop with result data (no setState)
2. Moved `setState()` to the `.then()` callback, which runs after the dialog fully closes
3. Delayed controller disposal by 350ms to ensure animation completes before disposal

```dart
// Before (buggy)
void saveChanges() {
  setState(() { /* changes */ });  // Triggers rebuild during animation
  Navigator.pop(context);
}
// ...
.then((_) {
  tempNameController.dispose();  // Disposed while animation running
  tempStackController.dispose();
});

// After (fixed)
void saveChanges() {
  Navigator.pop(context, {'save': true, /* data */});  // Just pop with data
}
// ...
.then((result) {
  if (result != null && result['save'] == true) {
    setState(() { /* apply changes */ });  // After dialog closed
  }
  Future.delayed(Duration(milliseconds: 350), () {
    tempNameController.dispose();  // After animation complete
    tempStackController.dispose();
  });
});
```

## Problem 2: My Opponents Screen Showing Empty

After adding an opponent from the seat setup screen, navigating to "My Opponents" showed an empty list.

**Root Cause:**
`MyOpponentsScreen` used a static cache that persisted across screen visits. When `initState` was called, it used `_loadOpponents(useCache: true)`, which returned stale cached data (empty list from before opponents were added).

**Solution:**
1. Changed `initState` to always load fresh data: `_loadOpponents(useCache: false)`
2. Added `invalidateCache()` static method on `MyOpponentsScreen` widget class
3. Called `MyOpponentsScreen.invalidateCache()` from seat setup screen when saving a new opponent

```dart
// In MyOpponentsScreen widget class
static void invalidateCache() {
  _cachedOpponents = null;
  _cachedHandsCounts = null;
  _cachedStats = null;
}

// In SeatSetupScreen when saving opponent
await OpponentService.saveOpponent(opponent);
MyOpponentsScreen.invalidateCache();  // Clear stale cache
```

## Files Modified

- `lib/screens/seat_setup_screen.dart` - Controller disposal timing, cache invalidation call
- `lib/screens/my_opponents_screen.dart` - Cache moved to Widget class, invalidateCache method, fresh load on init

## Key Lessons

1. **Modal animations and setState don't mix** - Don't call `setState()` before `Navigator.pop()` when the modal has controllers that will be disposed
2. **Delay disposal during animations** - Use `Future.delayed()` to wait for animation completion before disposing resources
3. **Static cache requires invalidation strategy** - When using static cache across screens, provide a way to invalidate it when data changes from other screens
4. **Pass data through Navigator.pop()** - Use the result parameter to pass data out of dialogs instead of relying on external state

## Testing

1. Go to Seat Setup screen
2. Tap on a seat, enter a new opponent name
3. Tap "Save Opponent" - should not crash
4. Navigate to "My Opponents" screen
5. Verify the new opponent appears in the list
