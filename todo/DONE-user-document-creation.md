# User Document Creation on Email Verification

**Priority:** Medium
**Created:** 2026-02-17

---

## Problem

Currently, user documents in the `users` Firestore collection are created:
- On registration (new users)
- On sign-in (backfill for existing users)

However, this approach has limitations:
1. Users who register but don't immediately sign in won't have a document
2. Email verification status is not considered
3. Users should appear in the database immediately after verifying their email

---

## Current Implementation

**Location:** `lib/services/auth_service.dart`

```dart
// On registration - creates user document
static Future<UserCredential?> registerWithEmail(...) {
  // ... creates user in Firebase Auth
  await _createUserDocument(uid, displayName, email);
}

// On sign-in - backfills missing documents
static Future<UserCredential?> signInWithEmail(...) {
  // ... signs in
  await ensureUserDocument();
}
```

**Firestore `users` collection structure:**
```
users/{uid}/
  uid: string
  displayName: string
  displayNameLower: string (for case-insensitive search)
  email: string
  createdAt: timestamp
  updatedAt: timestamp
```

---

## Required Changes

### Option 1: Cloud Function (Recommended)

Create a Firebase Cloud Function that triggers on email verification:

```javascript
// functions/src/index.ts
exports.onEmailVerified = functions.auth.user().onUpdate((change) => {
  const before = change.before;
  const after = change.after;

  // Check if email was just verified
  if (!before.emailVerified && after.emailVerified) {
    return admin.firestore().collection('users').doc(after.uid).set({
      uid: after.uid,
      displayName: after.displayName || after.email.split('@')[0],
      displayNameLower: (after.displayName || after.email.split('@')[0]).toLowerCase(),
      email: after.email,
      emailVerified: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  }
  return null;
});
```

### Option 2: Client-Side Check

Add email verification check in the app:

```dart
// Check on app startup or after email verification link clicked
static Future<void> checkAndCreateUserDocument() async {
  final user = currentUser;
  if (user == null) return;

  // Only create document if email is verified
  if (user.emailVerified) {
    await ensureUserDocument();
  }
}
```

### Option 3: Hybrid Approach

1. Create document on registration (current behavior)
2. Add `emailVerified: false` field
3. Update to `emailVerified: true` via Cloud Function when verified
4. Only show verified users in search results

---

## Additional Considerations

1. **Search filtering:** Should unverified users appear in dealer search?
   - Probably NO - only show verified users
   - Add `.where('emailVerified', isEqualTo: true)` to search query

2. **Profile completeness:** Consider adding more user fields:
   - `photoURL`
   - `phoneNumber`
   - `lastLoginAt`
   - `accountType` (player/dealer/admin)

3. **Data consistency:** Ensure user document stays in sync with Firebase Auth:
   - Display name changes
   - Email changes
   - Account deletion

---

## Files to Modify

1. `lib/services/auth_service.dart` - Add email verification handling
2. `functions/src/index.ts` - Create Cloud Function (if using Option 1)
3. Firebase Console - Deploy Cloud Functions

---

## Testing Checklist

- [ ] New user registers → document created
- [ ] User verifies email → document updated with `emailVerified: true`
- [ ] Unverified users don't appear in dealer search
- [ ] Verified users appear in dealer search immediately
- [ ] Display name changes sync to user document
- [ ] User deletion removes user document

---

## Notes

- Cloud Functions require Firebase Blaze plan (pay-as-you-go)
- Consider rate limiting on user document creation
- Add proper error handling for Firestore write failures
