# VPIP Calculation Comprehensive Fix

**Date:** October 27, 2025
**Status:** ✅ Resolved
**Severity:** High - Core statistics calculation error

## Problem Statement

VPIP (Voluntarily Put money In Pot) percentage was consistently showing 100% for all users, regardless of actual play behavior. User reported having 39 total hands with only 17 hands played (seeing flop), but VPIP displayed as 100% instead of the correct lower percentage.

### Understanding VPIP

**VPIP Definition**: Percentage of hands where a player voluntarily put money in the pot preflop.

**What COUNTS as VPIP:**
- Calling a preflop bet/raise
- Betting preflop
- Raising preflop

**What DOES NOT count as VPIP:**
- Posting mandatory small blind (SB)
- Posting mandatory big blind (BB)
- Folding preflop
- Checking big blind when there's no raise

**Correct Formula:**
```
VPIP % = (vpipCount / totalHands) × 100
```

Where:
- `vpipCount`: Hands where player voluntarily put money in preflop
- `totalHands`: ALL hands dealt (including folds)

**Common Mistake:**
```
VPIP % = (vpipCount / handsPlayed) × 100  ❌ WRONG
```

Where:
- `handsPlayed`: Only hands where player saw flop/turn/river

## Root Cause Analysis

Found **4 separate bugs** across different parts of the codebase:

### Bug 1: Wrong denominator in UserStats model (user_stats.dart)
**Location:** Lines 42-44
**Problem:** Calculating VPIP/PFR/3-Bet percentages using `handsPlayed` instead of `totalHands`

### Bug 2: handsDelta always incrementing (hand_state_machine.dart)
**Location:** Line 867
**Problem:** `handsDelta` was always set to 1 for every hand, causing `handsPlayed` counter to include ALL hands dealt, not just hands where player saw flop/turn/river. This made `vpipCount == handsPlayed` in the database.

### Bug 3: Display calculations in verification service (stats_verification_service.dart)
**Location:** Lines 208, 222, 240
**Problem:** Three different print statements calculating VPIP % using wrong denominator (`handsPlayed` or `sessionHandsPlayed` instead of total hands)

### Bug 4: Statistics screen display (statistics_screen.dart)
**Location:** Line 100
**Problem:** UI screen calculating VPIP using `handsPlayed` instead of `totalHands`

## Testing Methodology

User created "Test VPIP" session with 4 carefully designed hands to verify fix:

**Hand #1: Won BB (everyone folded)**
- Action: No voluntary action (BB mandatory)
- Expected: NOT counted as VPIP ✅

**Hand #2: Called preflop, bet flop/turn**
- Action: Called preflop raise, then bet on flop and turn
- Expected: Counted as VPIP ✅

**Hand #3: Checked preflop (BB), folded flop**
- Action: Checked BB (no raise), then folded on flop
- Expected: NOT counted as VPIP ✅

**Hand #4: Folded preflop**
- Action: Folded to preflop raise
- Expected: NOT counted as VPIP ✅

**Expected Result:** 1 VPIP out of 4 hands = 25%

## Solution Implementation

### Fix 1: user_stats.dart (Lines 41-45)

**Before:**
```dart
double get vpipPercentage => handsPlayed > 0 ? (vpipCount / handsPlayed * 100) : 0.0;
double get pfrPercentage => handsPlayed > 0 ? (pfrCount / handsPlayed * 100) : 0.0;
double get threeBetPercentage => handsPlayed > 0 ? (threeBetCount / handsPlayed * 100) : 0.0;
```

**After:**
```dart
double get vpipPercentage => totalHands > 0 ? (vpipCount / totalHands * 100) : 0.0;
double get pfrPercentage => totalHands > 0 ? (pfrCount / totalHands * 100) : 0.0;
double get threeBetPercentage => totalHands > 0 ? (threeBetCount / totalHands * 100) : 0.0;
double get winRate => handsPlayed > 0 ? (wonHands / handsPlayed * 100) : 0.0;
```

### Fix 2: hand_state_machine.dart

**Added playedPastPreflop flag (Line 788):**
```dart
bool vpipThisHand = false;
bool pfrThisHand = false;
bool playedPastPreflop = false; // Track if player saw flop/turn/river
String currentStreet = 'preflop';
```

**Track when player plays past preflop (Lines 794-801):**
```dart
// Track street changes
if (action.street != null) {
  currentStreet = action.street!.name.toLowerCase();
  // If player has action on flop/turn/river, they played past preflop
  if (currentStreet != 'preflop') {
    playedPastPreflop = true;
  }
}
```

**Fixed handsDelta to use flag (Line 872):**
```dart
await UserStatsService.updateStatsAtomic(
  userId: currentUser.uid,
  handsDelta: playedPastPreflop ? 1 : 0, // Only count if player saw flop/turn/river
  totalHandsDelta: 1, // Always count total hands dealt
  vpipDelta: vpipDelta,
  pfrDelta: pfrDelta,
  wonHandsDelta: (hand.winnerId != null && hand.winnerId == hand.heroPosition) ? 1 : 0,
);
```

**Added debug logging (Lines 841-850):**
```dart
if (vpipThisHand) {
  vpipDelta = 1;
  print('🎯 VPIP counted for $playerName in hand #${hand.handNumber}');
}
if (pfrThisHand) {
  pfrDelta = 1;
  print('🎯 PFR counted for $playerName in hand #${hand.handNumber}');
}

print('📊 Hand #${hand.handNumber} - $playerName: playedPastPreflop=$playedPastPreflop, vpip=$vpipThisHand, pfr=$pfrThisHand');
```

### Fix 3: stats_verification_service.dart

**Session summary (Lines 208-209):**
```dart
print('     VPIP: $sessionVpip (${hands.length > 0 ? (sessionVpip / hands.length * 100).toStringAsFixed(1) : "0.0"}%)');
print('     PFR: $sessionPfr (${hands.length > 0 ? (sessionPfr / hands.length * 100).toStringAsFixed(1) : "0.0"}%)');
```

**Calculated stats (Lines 222-224):**
```dart
print('VPIP %: ${totalHandsCalc > 0 ? (vpipCountCalc / totalHandsCalc * 100).toStringAsFixed(1) : "0.0"}%');
print('PFR Count: $pfrCountCalc');
print('PFR %: ${totalHandsCalc > 0 ? (pfrCountCalc / totalHandsCalc * 100).toStringAsFixed(1) : "0.0"}%');
```

**Database stats (Lines 240-242):**
```dart
print('VPIP %: ${userStats.totalHands > 0 ? (userStats.vpipCount / userStats.totalHands * 100).toStringAsFixed(1) : "0.0"}%');
print('PFR Count: ${userStats.pfrCount}');
print('PFR %: ${userStats.totalHands > 0 ? (userStats.pfrCount / userStats.totalHands * 100).toStringAsFixed(1) : "0.0"}%');
```

### Fix 4: statistics_screen.dart (Lines 98-107)

**Before:**
```dart
if (handsPlayed > 0) {
  vpip = (userStats.vpipCount / handsPlayed) * 100;
  pfr = (userStats.pfrCount / handsPlayed) * 100;
  threeBet = (userStats.threeBetCount / handsPlayed) * 100;
  winRate = (userStats.wonHands / handsPlayed) * 100;
}
```

**After:**
```dart
// Calculate percentages from database stats
if (totalHands > 0) {
  vpip = (userStats.vpipCount / totalHands) * 100;
  pfr = (userStats.pfrCount / totalHands) * 100;
  threeBet = (userStats.threeBetCount / totalHands) * 100;
}
// Win rate uses handsPlayed (only count hands you actually played)
if (handsPlayed > 0) {
  winRate = (userStats.wonHands / handsPlayed) * 100;
}
```

## Files Modified

1. **lib/models/user_stats.dart** - Fixed percentage getters (lines 41-45)
2. **lib/models/hand_state_machine.dart** - Fixed handsDelta tracking + debug logs (lines 788, 794-801, 841-850, 872)
3. **lib/services/stats_verification_service.dart** - Fixed 3 display calculations (lines 208-209, 222-224, 240-242)
4. **lib/screens/statistics_screen.dart** - Fixed VPIP/PFR/3-Bet calculation (lines 98-107)

## Verification Results

User tested the fix with the 4-hand test session and confirmed:
- Logs showed correct VPIP logic (1 out of 4 = 25%)
- Statistics screen displayed correct percentage
- All test scenarios passed

**User Confirmation:** "Perfect it is fixed now finally."

## Key Takeaways

1. **VPIP Formula Must Use totalHands:** Never use `handsPlayed` as denominator for VPIP/PFR/3-Bet calculations
2. **Win Rate is Different:** Win rate correctly uses `handsPlayed` as denominator (only count hands you played)
3. **handsDelta vs totalHandsDelta:** These are separate counters with different purposes:
   - `totalHandsDelta`: Always 1 (every hand dealt)
   - `handsDelta`: Only 1 if player saw flop/turn/river
4. **Multiple Calculation Points:** Fixed bug required changes in 4 different locations - model getters, state machine, verification service, and UI screen
5. **Debug Logging Critical:** Added logging helped identify that VPIP logic was correct but display calculations were wrong

## Impact

- ✅ VPIP now shows accurate percentages reflecting actual play style
- ✅ PFR and 3-Bet calculations also corrected
- ✅ Users can now accurately track their preflop aggression statistics
- ✅ Debug logging added for future troubleshooting
- ✅ All test scenarios pass successfully
