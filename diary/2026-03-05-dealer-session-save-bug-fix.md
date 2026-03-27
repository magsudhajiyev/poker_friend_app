# Dealer Session Save Bug Fix

**Date:** 2026-03-05
**Status:** Fixed
**Commit:** 109cd4e

---

## Problem

Sessions were being saved for users who didn't actually play:

1. **Dealers who only dealt** - When a dealer created and ran a club event but didn't sit as a player, the session was still saved to their account with inflated session count and play time.

2. **Users without seat assignment** - Sessions could be created with `ourSeatNumber: null`, and stats would still be incremented when the session ended.

### Symptoms
- Dealer's session history showed sessions they only facilitated
- Dealer's stats showed incorrect session count and play time
- Stack growth charts appeared for dealers who had no stack

---

## Root Cause

### Issue 1: `endSession()` unconditionally incremented stats

**File:** `lib/services/firebase_service.dart` (lines 358-390)

```dart
// BEFORE: Always incremented stats for session creator
await UserStatsService.updateStatsAtomic(
  userId: userId,
  sessionsDelta: 1,
  playTimeMinutesDelta: duration,
);
```

No validation checked whether the user actually participated.

### Issue 2: `getAllSessions()` returned all dealer-created sessions

**File:** `lib/services/firebase_service.dart` (lines 523-569)

```dart
// Query 1 returned ALL sessions where userId == currentUser
// Including live/dealer sessions where dealer didn't play
final ownedSnapshot = await _firestore
    .collection(_sessionsCollection)
    .where('userId', isEqualTo: userId)
    .get();
```

---

## Solution

### Fix 1: Validate participation before incrementing stats

Added checks in `endSession()` to only increment stats if user participated:

```dart
// Check if user actually participated in the session
final ourSeatNumber = sessionData['ourSeatNumber'] as int?;
final participantIds = (sessionData['participantIds'] as List<dynamic>?)?.cast<String>() ?? [];
final totalHands = sessionData['totalHands'] as int? ?? 0;

// User participated if:
// 1. They had a seat assigned (regular sessions), OR
// 2. They are in participantIds (live/dealer sessions), OR
// 3. They logged at least one hand
final userParticipated = ourSeatNumber != null ||
    participantIds.contains(userId) ||
    totalHands > 0;

if (userParticipated) {
  // Only then increment stats
}
```

### Fix 2: Filter dealer-only sessions from history

Updated `getAllSessions()` to filter live sessions where user didn't play:

```dart
for (final doc in ownedSnapshot.docs) {
  final data = doc.data();
  final isLive = data['isLive'] as bool? ?? false;
  final participantIds = (data['participantIds'] as List<dynamic>?)?.cast<String>() ?? [];

  // Include if:
  // 1. Not a live session (regular manual logging), OR
  // 2. Live session AND user is in participantIds (dealer played)
  if (!isLive || participantIds.contains(userId)) {
    allDocs[doc.id] = doc;
  }
}
```

---

## Files Modified

| File | Change |
|------|--------|
| `lib/services/firebase_service.dart` | Added participation validation in `endSession()`, filtered dealer-only sessions in `getAllSessions()` |

---

## Testing

1. **Dealer-only session**: Create club event, deal hands without playing, end event
   - Session should NOT appear in dealer's history
   - Dealer's stats should NOT be incremented

2. **Dealer-as-player session**: Create club event, sit as player, play hands, end event
   - Session SHOULD appear in dealer's history
   - Dealer's stats SHOULD be incremented

3. **Regular session without seat**: Start session, don't assign seat, end
   - Stats should NOT be incremented

4. **Regular session with seat**: Start session, assign seat, play hands, end
   - Stats SHOULD be incremented

---

## Key Insight

The `participantIds` array is the authoritative source for who actually played in a live/dealer session. The session's `userId` only indicates who created/ran the session, not who participated.
