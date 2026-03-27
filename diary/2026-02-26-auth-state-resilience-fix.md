# Auth State Resilience Fix - Unexpected Auto-Logout

**Date:** 2026-02-26

## Problem

User was getting logged out unexpectedly while actively browsing the app on a Xiaomi phone. The logout would happen after ~20 seconds of browsing, without the user tapping any logout button.

### Symptoms
- User browsing the app normally
- Suddenly redirected to welcome/login screen
- Happened on Xiaomi phone with Google Play Services connectivity issues
- Network errors visible in logs (Firestore DNS resolution failures)

### Root Cause

Firebase Auth's `authStateChanges` stream would occasionally emit `null` during network instability, even though the user's session was still valid. The previous code immediately showed the login screen when the stream emitted `null`:

```dart
// OLD CODE - No resilience
if (snapshot.hasData && snapshot.data != null) {
  return HomeScreen();
}
return IntroScreen();  // Immediately shows login when stream is null
```

This was problematic because:
1. Firebase Auth token refresh failures could cause temporary `null` emissions
2. Network glitches on Xiaomi/MIUI phones are common (aggressive battery optimization)
3. The stream saying `null` doesn't always mean the session is invalid

---

## Solution: Auth State Resilience

### Strategy
1. Track if user was ever signed in during the session (`_wasSignedIn` flag)
2. Track if logout was explicit vs unexpected (`_isExplicitLogout` flag)
3. Wait briefly for auth to recover before showing login screen
4. Add detailed logging to diagnose future issues

### Implementation

#### File 1: `lib/services/auth_service.dart`

Added explicit logout tracking:
```dart
static bool _isExplicitLogout = false;

static bool get isExplicitLogout => _isExplicitLogout;

static void clearExplicitLogoutFlag() {
  _isExplicitLogout = false;
}

static Future<void> signOut() async {
  try {
    print('📍 LOGOUT: signOut() called');
    print('📍 LOGOUT: Stack trace: ${StackTrace.current}');

    _isExplicitLogout = true;  // Mark as explicit
    // ... rest of signOut
  }
}
```

#### File 2: `lib/screens/auth_wrapper.dart`

Added resilience with recovery delay:
```dart
class _AuthWrapperState extends State<AuthWrapper> {
  bool _wasSignedIn = false;        // Track if user was signed in
  bool _waitingForRecovery = false; // Track if waiting for auth recovery

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        // User is signed in
        if (snapshot.hasData && snapshot.data != null) {
          _wasSignedIn = true;  // Remember user was signed in
          _waitingForRecovery = false;
          return HomeScreen();
        }

        // Check 1: Stream says null but currentUser still exists
        if (!AuthService.isExplicitLogout && AuthService.currentUser != null) {
          return _buildLoadingScreen(context);  // Transient issue
        }

        // Check 2: Was signed in, now stream says null, wasn't explicit logout
        // Wait 3 seconds for auth to recover
        if (_wasSignedIn && !AuthService.isExplicitLogout && !_waitingForRecovery) {
          _waitingForRecovery = true;
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && _waitingForRecovery) {
              setState(() => _waitingForRecovery = false);
            }
          });
          return _buildLoadingScreen(context);
        }

        if (_waitingForRecovery) {
          return _buildLoadingScreen(context);
        }

        // Only now show login screen
        return IntroScreen();
      },
    );
  }
}
```

#### File 3: `lib/widgets/navigation_drawer.dart`

Added logging to track explicit logout:
```dart
onTap: () {
  print('📍 LOGOUT: Navigation drawer Sign Out tapped');
  Navigator.pop(context);
  _showSignOutConfirmation(context);
},

// In confirmation dialog:
onPressed: () async {
  print('📍 LOGOUT: Drawer confirmation confirmed');
  // ... signOut
},
```

#### File 4: `lib/screens/profile_screen.dart`

Added logging:
```dart
if (confirm == true) {
  print('📍 LOGOUT: Profile screen Log Out confirmed');
  await AuthService.signOut();
  // ...
}
```

---

## Why This Works

1. **`_wasSignedIn` flag**: Remembers if user was ever authenticated. If they were signed in but stream suddenly says null, we know it's unexpected.

2. **`_isExplicitLogout` flag**: Distinguishes between user clicking "Sign Out" vs Firebase internally invalidating session.

3. **3-second recovery delay**: Gives Firebase Auth time to recover from transient network issues before showing login screen.

4. **`currentUser` check**: Even if stream says null, `currentUser` might still be valid (cached). If so, show loading instead of login.

---

## Diagnostic Logging

Added emoji-prefixed logs for easy filtering:
- `📍 AUTH:` - Auth state changes
- `📍 LOGOUT:` - Explicit logout flow
- `⚠️ AUTH:` - Unexpected logout detection

---

## Files Modified

| File | Change |
|------|--------|
| `lib/services/auth_service.dart` | Added `_isExplicitLogout` flag, stack trace logging |
| `lib/screens/auth_wrapper.dart` | Added `_wasSignedIn`, `_waitingForRecovery`, 3s recovery delay |
| `lib/widgets/navigation_drawer.dart` | Added logout flow logging |
| `lib/screens/profile_screen.dart` | Added logout flow logging |

---

## Verification

1. **Before fix**: User logged out after ~20 seconds of browsing
2. **After fix**: User browsed for 2+ minutes with Firestore network errors without getting logged out
3. **Logs show**: Auth state remained stable despite network issues

---

## Related Issues

This fix works alongside the FCM fire-and-forget fix (see `2026-02-26-fcm-blocking-operations-fix.md`). Both address issues caused by network instability on the user's Xiaomi device:
- FCM fix: Prevents app hanging during login/logout when FCM unavailable
- Auth fix: Prevents unexpected logout when Firebase Auth stream has transient issues

---

## Key Learnings

1. **Don't trust auth streams blindly** - They can emit false negatives during network issues
2. **Add recovery delays for critical state changes** - Give services time to recover
3. **Track explicit vs unexpected state changes** - Helps distinguish user actions from bugs
4. **Xiaomi/MIUI devices have known Google Play Services issues** - Build resilience for them
5. **Diagnostic logging is essential** - Can't fix what you can't see
