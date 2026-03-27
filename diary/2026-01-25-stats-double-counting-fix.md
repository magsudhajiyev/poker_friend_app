# Statistics Double-Counting Fix

**Date:** January 25, 2026
**Status:** Implemented (Pending User Verification)
**Severity:** Critical - Core statistics calculation error

## Problem Statement

User stats were showing approximately **2x the actual values**:
- Calculated from raw data: Total=16, Played=6, Won=2, VPIP=6, PFR=2
- Database stored: Total=27, Played=13, Won=6, VPIP=13, PFR=5

All stats inflated by similar ratio (~2x), indicating systematic double-counting.

## Root Cause Analysis

### Primary Issue: Double-Counting in Two Code Paths

When a hand was saved, stats were being updated **TWICE**:

| Path | Location | When Called |
|------|----------|-------------|
| PATH 1 | `FirebaseService._updateUserStatsFromHand()` | Inside `saveHand()` |
| PATH 2 | `PokerSessionManager._updateOptimizedStats()` | After `saveHand()` returns |

**Flow that caused double-counting:**
```
PokerSessionManager._saveHandToFirebase()
  └─> FirebaseService.saveHand()
       └─> _updateUserStatsFromHand()  ← INCREMENT #1
  └─> _updateOptimizedStats()          ← INCREMENT #2 (DUPLICATE!)
```

Both paths called `UserStatsService.updateStatsAtomic()`, incrementing stats TWICE per hand.

### Secondary Issues

1. **BankrollService used wrong denominator**: Used `handsPlayed` instead of `totalHands` for VPIP/PFR percentages
2. **3-bet detection was wrong**: Counted total raises instead of detecting re-raises after opponent's raise

## Solution Implementation

### Phase 1: Remove Double-Counting (CRITICAL)

**File:** `lib/models/hand_state_machine.dart` (lines 913-926)

Commented out the hero stats update in `_updateOptimizedStats()`:
```dart
} else {
  // DO NOT update user stats here - already done in FirebaseService.saveHand()
  // via _updateUserStatsFromHand(). This block was causing DOUBLE-COUNTING
  // of stats (stats were being incremented twice per hand).
  //
  // The correct stats update flow is:
  // 1. PokerSessionManager._saveHandToFirebase() calls FirebaseService.saveHand()
  // 2. FirebaseService.saveHand() calls _updateUserStatsFromHand() - INCREMENT #1 (correct)
  // 3. This _updateOptimizedStats() method should ONLY update opponent stats
}
```

### Phase 2: Fix 3-Bet Detection

**File:** `lib/services/firebase_service.dart`

Added proper 3-bet detection function:
```dart
/// Detect if a player made a 3-bet (re-raised AFTER seeing an opponent's raise)
static bool _didPlayerThreeBet(List<Map<String, dynamic>> actions, int playerSeatNumber) {
  bool sawOpponentRaise = false;

  for (final action in actions) {
    final street = action['street']?.toString().toLowerCase() ?? '';
    if (street != 'preflop') continue;

    final playerId = action['player'] as int?;
    final actionType = action['action']?.toString().toLowerCase() ?? '';

    if (actionType != 'raise') continue;

    if (playerId != playerSeatNumber) {
      sawOpponentRaise = true;
    } else if (sawOpponentRaise) {
      return true; // Hero raised AFTER opponent = 3-bet
    }
  }
  return false;
}
```

### Phase 3: Fix BankrollService Denominator

**File:** `lib/services/bankroll_service.dart` (lines 157-169)

Changed from `handsPlayed` to `totalHands`:
```dart
// BEFORE (wrong):
final vpip = userStats.handsPlayed > 0
    ? (userStats.vpipCount / userStats.handsPlayed) * 100 : 0.0;

// AFTER (correct):
final vpip = userStats.totalHands > 0
    ? (userStats.vpipCount / userStats.totalHands) * 100 : 0.0;
```

### Phase 4: Add Stats Recalculation Function

**File:** `lib/services/user_stats_service.dart`

Added `recalculateUserStats()` method to rebuild stats from raw hand data:
- Resets all stats to zero
- Iterates through all hands in poker_sessions
- Recalculates each stat with correct logic
- Saves corrected totals

### Phase 5: Fix 3-Bet in Migration Function

**File:** `lib/services/user_stats_service.dart`

Updated `migrateUserStats()` to use proper 3-bet detection:
```dart
// Check for 3-bet using proper detection logic
if (didPlay) {
  didThreeBet = _didPlayerThreeBetInHand(actions, ourSeatNumber);
}
```

### Phase 6: Add Double-Counting Detection Warning

**File:** `lib/services/stats_verification_service.dart`

Added `_checkDoubleCountingPattern()` method:
- Calculates ratios between database and calculated values
- Detects if stats are inflated by ~2x
- Provides clear warning and fix recommendation

## Files Modified

| File | Changes |
|------|---------|
| `lib/models/hand_state_machine.dart` | Removed hero stats update from `_updateOptimizedStats()` |
| `lib/services/firebase_service.dart` | Added `_didPlayerThreeBet()`, fixed `_updateUserStatsFromHand()` |
| `lib/services/bankroll_service.dart` | Changed denominator to `totalHands` |
| `lib/services/user_stats_service.dart` | Added `recalculateUserStats()`, fixed 3-bet in migration |
| `lib/services/stats_verification_service.dart` | Added `_checkDoubleCountingPattern()` |

## How to Repair Existing Stats

After deploying this fix, users need to run stats recalculation:

```dart
// In your code or debug screen:
final result = await UserStatsService.recalculateUserStats(userId);
print(result); // Shows recalculated values
```

This will:
1. Reset all stats to zero
2. Recalculate from raw hand data
3. Save corrected values to database

## Verification Steps

1. Run `StatsVerificationService.verifyAllStats()` to check current state
2. Look for "DOUBLE-COUNTING DETECTED" warning
3. Run `UserStatsService.recalculateUserStats(userId)` to repair
4. Run verification again to confirm match

## Key Definitions Reminder

| Stat | Definition | Denominator |
|------|------------|-------------|
| **Total Hands** | All hands user logged (even if folded preflop immediately) | - |
| **Hands Played** | Hands where user took ANY voluntary action | - |
| **VPIP** | Voluntarily Put money In Pot preflop | totalHands |
| **PFR** | Preflop Raise (bet/raise preflop) | totalHands |
| **3-Bet** | Re-raise after seeing opponent's raise preflop | totalHands |
| **Win Rate** | Percentage of hands won | handsPlayed |

## Lessons Learned

1. **Single source of truth**: Stats should be updated in ONE place only
2. **Audit trails matter**: Having verification service helped identify the pattern
3. **Double-counting is sneaky**: Stats looked plausible individually but ratio analysis revealed the bug
4. **Always use totalHands for VPIP/PFR/3-Bet**: These are percentages of all dealt hands

## Impact

- Fixes inflated stats for all users going forward
- Provides recalculation tool to repair existing corrupted data
- Adds detection mechanism to catch similar issues in future
- Correct VPIP/PFR percentages will now reflect actual play style
