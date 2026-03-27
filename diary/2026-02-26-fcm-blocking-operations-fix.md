# FCM Blocking Operations Fix - Production Level

**Date:** 2026-02-26

## Problem

App would hang/freeze during login, logout, or startup when Firebase Cloud Messaging (FCM) was unavailable. This happened on physical devices (especially Xiaomi phones) where Google Play Services had issues.

### Symptoms
- Black screen on physical Android phone while emulator worked fine
- Login took forever or hung indefinitely
- Logout blocked the UI
- App startup was slow

### Root Cause
FCM operations were **awaited** (blocking) during critical user flows:
- `signInWithEmail()` awaited FCM token storage and club subscriptions
- `signOut()` awaited FCM cleanup
- `main()` awaited FCM setup for already-logged-in users

When FCM service was unavailable (`SERVICE_NOT_AVAILABLE`), these operations would hang indefinitely or wait for long timeouts.

### Error Messages Seen
```
W/FLTFireMsgReceiver: Unable to log event: analytics library is missing
E/FirebaseMessaging: Failed to get FCM token
Unable to resolve host "firestore.googleapis.com": No address associated with hostname
```

---

## Solution: Fire-and-Forget Pattern

FCM operations are **non-critical** for app functionality. Users can use the app without push notifications. The fix makes all FCM operations run in the background without blocking the UI.

### Key Insight
- **Critical (must await):** `requestPermissions()` - needs user response
- **Non-critical (fire-and-forget):** `getToken()`, `storeToken()`, `subscribeToUserClubs()`, `unsubscribeFromAllClubs()`

---

## Files Modified

### 1. `lib/services/fcm_service.dart`

Added timeouts to prevent indefinite hangs:

```dart
import 'dart:async';

static const _fcmTimeout = Duration(seconds: 5);

// getToken() - added timeout
static Future<String?> getToken() async {
  try {
    if (Platform.isIOS) {
      final apnsToken = await _messaging.getAPNSToken()
          .timeout(_fcmTimeout, onTimeout: () => null);
      if (apnsToken == null) {
        print('FCM: APNs token not available yet');
        return null;
      }
    }
    _currentToken = await _messaging.getToken()
        .timeout(_fcmTimeout, onTimeout: () => null);
    // ...
  }
}

// subscribeToTopic() - added timeout
static Future<void> subscribeToTopic(String topic) async {
  try {
    await _messaging.subscribeToTopic(topic)
        .timeout(_fcmTimeout, onTimeout: () {
      print('FCM: Subscribe to $topic timed out');
    });
  }
}

// subscribeToUserClubs() - parallelized with timeout
static Future<void> subscribeToUserClubs() async {
  // ... get clubIds ...
  await Future.wait(
    clubIds.map((clubId) => subscribeToClub(clubId)),
  ).timeout(const Duration(seconds: 10), onTimeout: () {
    print('FCM: Bulk subscribe timed out');
    return [];
  });
}

// unsubscribeFromAllClubs() - parallelized with timeout
static Future<void> unsubscribeFromAllClubs() async {
  // ... get clubIds ...
  await Future.wait(
    clubIds.map((clubId) => unsubscribeFromClub(clubId)),
  ).timeout(const Duration(seconds: 10), onTimeout: () {
    print('FCM: Bulk unsubscribe timed out');
    return [];
  });
}

// initialize() - added timeout to getInitialMessage
final initialMessage = await _messaging.getInitialMessage()
    .timeout(_fcmTimeout, onTimeout: () => null);
```

### 2. `lib/services/auth_service.dart`

Made FCM operations fire-and-forget using `unawaited()`:

```dart
import 'dart:async';

// signInWithEmail() - fire-and-forget FCM setup
static Future<UserCredential?> signInWithEmail(String email, String password) async {
  // ... auth logic ...
  if (credential.user != null) {
    await ensureUserDocument();
    // FCM setup runs in background - don't block sign-in
    unawaited(_setupFcmInBackground());
  }
  return credential;
}

// registerWithEmail() - fire-and-forget FCM setup
static Future<UserCredential?> registerWithEmail(...) async {
  // ... registration logic ...
  if (credential.user != null) {
    await _createUserDocument(...);
    await ensureUserDocument();
    // FCM setup runs in background - don't block registration
    unawaited(_setupFcmInBackground());
  }
  return credential;
}

// signOut() - fire-and-forget FCM cleanup
static Future<void> signOut() async {
  try {
    // FCM cleanup runs in background - don't block sign-out
    unawaited(_cleanupFcmInBackground());
    clearAccountTypeCache();
    await _auth.signOut();
  }
}

// Helper methods
static Future<void> _setupFcmInBackground() async {
  try {
    final token = await FCMService.getToken();
    if (token != null) {
      await FCMService.storeToken(token);
    }
    await FCMService.subscribeToUserClubs();
  } catch (e) {
    print('FCM setup failed (background): $e');
  }
}

static Future<void> _cleanupFcmInBackground() async {
  try {
    await FCMService.unsubscribeFromAllClubs();
    await FCMService.removeToken();
  } catch (e) {
    print('FCM cleanup failed (background): $e');
  }
}
```

### 3. `lib/main.dart`

Made app startup FCM operations fire-and-forget:

```dart
import 'dart:async';

// In main() - fire-and-forget FCM for logged-in user
if (AuthService.isSignedIn) {
  unawaited(_setupFcmForLoggedInUser());
}

// Helper function
Future<void> _setupFcmForLoggedInUser() async {
  try {
    final token = await FCMService.getToken();
    if (token != null) {
      await FCMService.storeToken(token);
    }
    await FCMService.subscribeToUserClubs();
  } catch (e) {
    // Silent failure - FCM is non-critical for app functionality
  }
}
```

---

## What `unawaited()` Does

From `dart:async`, `unawaited()` explicitly marks a Future as intentionally not awaited:
- The Future runs in the background
- Errors are caught inside the async function (not propagated)
- The calling code continues immediately without waiting

---

## Result

| Operation | Before | After |
|-----------|--------|-------|
| App startup | Hung if FCM unavailable | Instant |
| Login | Hung if FCM unavailable | Instant |
| Logout | Hung if FCM unavailable | Instant |
| FCM operations | Sequential, blocking | Parallel, background |

---

## Key Learnings

1. **Never block user flows with non-critical services** - FCM is nice-to-have, not required
2. **Use `unawaited()` for fire-and-forget** - Makes intent clear, prevents lint warnings
3. **Add timeouts to all external service calls** - Never trust network operations to complete
4. **Parallelize independent operations** - `Future.wait()` for multiple subscriptions
5. **Test on physical devices** - Emulators often have better Google Services connectivity

---

## When to Apply This Pattern

Use fire-and-forget for:
- Push notification setup/cleanup
- Analytics events
- Non-critical logging
- Background sync operations

Do NOT use fire-and-forget for:
- User authentication (must complete)
- Data saves the user expects to see
- Permission requests (need user response)
- Any operation whose failure should block the flow

---

## Verification

1. Run app on physical device with poor Google Services
2. Login should be instant (no hang)
3. Logout should be instant (no hang)
4. App startup should be instant
5. FCM operations fail silently in background logs
