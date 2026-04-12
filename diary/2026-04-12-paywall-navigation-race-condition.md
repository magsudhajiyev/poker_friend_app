# Paywall Navigation Race Condition Fix

**Date**: 2026-04-12
**Status**: Confirmed fixed by user

## Bug
When a free user hits the hand limit (`maxHandsPerSession`) and taps "Upgrade" on the gate dialog, the app kicks them back to the home screen instead of showing the PaywallScreen.

## Root Cause
`_showLimitDialog()` in `lib/services/free_tier_limits.dart` used a `Completer<bool?>` pattern with `showDialog().then()` to sequence the gate dialog → paywall flow. The race condition:

1. User taps "Upgrade" → `Navigator.of(dialogContext).pop()` closes the dialog
2. The `showDialog` future resolves, triggering the `.then()` handler
3. Inside `.then()`, `PaywallScreen.show()` is awaited, but the dismiss button's `completer.complete(false)` could fire first (or the `.then()` handler's else branch)
4. `_showFreeTierGate()` in `poker_hand_screen.dart` receives `false` → calls `_endSessionFromGate()` → `popUntil(route.isFirst)` → kicked to home

## Fix
Eliminated the `Completer` entirely. Replaced with simple `async/await`:

```dart
static Future<bool?> _showLimitDialog(...) async {
  final result = await showDialog<String>(
    context: context,
    barrierDismissible: false,  // Force button tap
    ...
    // Dismiss button: pop('dismiss')
    // Upgrade button: pop('upgrade')
  );

  if (result == 'upgrade') {
    await PaywallScreen.show(context, featureName: featureName);
    return true;
  }
  return false;
}
```

Key changes:
- `await showDialog<String>()` — blocks until dialog is fully closed
- `barrierDismissible: false` — prevents accidental barrier taps
- Both buttons pop with explicit string values (`'dismiss'` / `'upgrade'`)
- PaywallScreen opens sequentially AFTER dialog closes, no race possible
- Also made `_showFreeTierGate()` use `async/await` instead of `.then()`
- Added re-show gate loop: if user closes paywall without upgrading, gate reappears

## Additional Fixes in Same Session
- **Paywall pricing**: $19.99/mo → $29.99/mo, $149.99/yr → $249.99/yr
- **Opponent limit UX**: Moved check from `saveOpponent()` to `_showAddOpponentDialog()` — dialog shows BEFORE the form, not after filling it
- **Premium debug toggle**: Added persistent toggle to Profile screen (SharedPreferences) for testing premium features

## Files Changed
- `lib/services/free_tier_limits.dart` — Removed Completer, async/await, barrierDismissible: false
- `lib/screens/poker_hand_screen.dart` — `_showFreeTierGate()` async/await + re-show loop
- `lib/screens/paywall_screen.dart` — Pricing update
- `lib/screens/my_opponents_screen.dart` — Opponent limit check moved earlier
- `lib/screens/profile_screen.dart` — Dev Tools premium toggle
- `lib/services/subscription_service.dart` — Debug premium override with SharedPreferences

## Lesson
Avoid `Completer` + `showDialog().then()` for sequencing navigation. Use `async/await` directly — it's simpler and eliminates race conditions between the dialog future resolving and the Completer being completed from multiple code paths.
