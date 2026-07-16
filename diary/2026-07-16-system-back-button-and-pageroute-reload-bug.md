# System Back Button & PageRouteBuilder Reload Bug

**Date**: 2026-07-16
**Branch**: design_v2

## Problem

After the startup performance optimizations (same day), navigating back from **any** pushed screen (session analytics, settings drawer, etc.) caused the entire app to reload — the splash logo replayed as if the app was killed and relaunched. This happened with both in-app back chevrons and the Android system back button.

## Root Cause 1: PageRouteBuilder Doesn't Maintain Child State

The startup optimization replaced `MaterialPageRoute` with `PageRouteBuilder` (crossfade transition) for the SplashScreen → AuthWrapper navigation. This caused a critical issue:

`PageRouteBuilder` does not maintain its child widget's state the same way `MaterialPageRoute` does. When any route pushed on top of AuthWrapper was popped, the `StreamBuilder<User?>` inside AuthWrapper **re-entered `ConnectionState.waiting`**, which:

1. Showed the loading screen (splash logo)
2. Unmounted `MainShell` → disposed all tab screens
3. When the stream re-resolved, created a brand new `MainShell` and `HomeScreen` from scratch
4. HomeScreen's loading future restarted, showing the splash logo again

**Debug log sequence** that revealed the issue:
```
📍 AUTH_WRAPPER: build() called
📍 AUTH: Stream state=ConnectionState.waiting, hasData=true, user=FELwuk4X
🏠 HOME: dispose() called — HomeScreen being destroyed
📍 AUTH: Stream state=ConnectionState.active, hasData=true, user=FELwuk4X
🐚 SHELL: initState() called — MainShell created from scratch
🏠 HOME: initState() called — HomeScreen created from scratch
🏠 HOME: build() → showing SPLASH
```

### Fix

Reverted to `MaterialPageRoute` in `splash_screen.dart`:
```dart
Navigator.of(context).pushReplacement(
  MaterialPageRoute(builder: (_) => const AuthWrapper()),
);
```

## Root Cause 2: Android System Back Button Pops Root Route

After fixing PageRouteBuilder, in-app chevron back buttons worked correctly. However, the **Android system back button** (Xiaomi) still caused the same reload.

The cause: AuthWrapper is the **only route** in the navigator stack (SplashScreen used `pushReplacement`). When the system back button is pressed on this root route, Android pops it entirely, restarting the app.

### Fix

Wrapped AuthWrapper's widget tree with `PopScope(canPop: false)`:
```dart
return PopScope(
  canPop: false,
  child: StreamBuilder<User?>(
    stream: AuthService.authStateChanges,
    // ...
  ),
);
```

This blocks the system back button from popping the root route. Screens pushed on top of MainShell (session analytics, settings, etc.) still handle their own back navigation normally — `PopScope` only affects the route it's directly placed on.

## Files Changed

| File | Change |
|---|---|
| `lib/screens/splash_screen.dart` | Reverted `PageRouteBuilder` → `MaterialPageRoute` |
| `lib/screens/auth_wrapper.dart` | Added `PopScope(canPop: false)` around root widget |

## Key Lesson

`PageRouteBuilder` is not a drop-in replacement for `MaterialPageRoute` when the built widget contains `StreamBuilder` or other stateful widgets that depend on route lifecycle. The crossfade animation is cosmetic but the route type affects how Flutter preserves widget state during navigation events.
