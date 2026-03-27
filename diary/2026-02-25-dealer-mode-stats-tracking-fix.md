# Dealer Mode Statistics Tracking Fix

**Date:** 2026-02-25

## Problem
In dealer-assisted logging mode, player statistics showed 0 because:
1. `_updateUserStatsFromHand()` only updated stats for `AuthService.userId` (the dealer)
2. The dealer is NOT playing - the seated players are
3. Players have their `playerId` (Firebase UID) in `SeatAssignment.playerId`
4. But `playerId` was NOT passed through the hand saving pipeline
5. Hand documents only stored `playerNames` (seat → name), not `playerIds` (seat → userId)

## Solution
1. Added `playerIds` map (seat → Firebase userId) to track registered players
2. Pass `playerIds` through PokerSessionManager to FirebaseService.saveHand()
3. Store `playerIds` in hand documents
4. Created `_updateAllPlayerStatsFromHand()` to update stats for ALL players in dealer mode
5. Added "Dealer is also playing" feature - dealer can sit at table and have stats tracked

## Features Added

### Dealer-Player Feature
- Dealer taps empty seat → choice dialog: "Add Player" or "Sit Here (I'm Playing)"
- Dealer can seat themselves with a starting stack
- Dealer's stats are tracked like any other player when playing
- Visual tracking of dealer's playing seat

### Stats Tracking for All Players
- `_updateAllPlayerStatsFromHand()` iterates through all `playerIds`
- Calculates position, VPIP, PFR, 3-bet, wins for each player
- Updates each player's stats atomically
- Manual players (no Firebase account) are skipped

## Files Modified
- `lib/services/firebase_service.dart`
  - Added `playerIds` parameter to `saveHand()`
  - Added `_updateAllPlayerStatsFromHand()` method
  - Conditional stats update based on dealer mode
  - Import for `PokerPositions`

- `lib/models/hand_state_machine.dart`
  - Added `playerIds` field to `PokerSessionManager`
  - Added `setPlayerIds()` setter method
  - Pass `playerIds` to `saveHand()` in `_saveHandToFirebase()`

- `lib/screens/dealer/dealer_table_screen.dart`
  - Added `_dealerPlayingSeat` state variable
  - Added `_getPlayerIdsMap()` helper
  - Added `_onEmptySeatTap()` with choice dialog
  - Added `_seatDealerAsPlayer()` method
  - Added `_showStackInputDialog()` helper
  - Updated `_syncPlayersFromSeats()` to call `setPlayerIds()`
  - Updated `_removePlayer()` to handle dealer seat
  - Import for `poker_friend_theme.dart`

## Bug Fix
- `lib/screens/dealer/dealer_qr_scan_screen.dart`
  - Fixed TextEditingController disposed error in blinds update dialog
  - Removed manual `controller.dispose()` call that caused race condition

## Verification Steps
1. Create dealer session with 2+ players (via QR scan)
2. Log a few hands with different winners
3. Check player stats in Statistics screen - should show VPIP, PFR, hands played
4. Verify dealer stats NOT updated when dealer is not playing
5. Test dealer playing: Tap empty seat → "Sit Here" → enter stack → dealer is now a player
6. Verify dealer stats ARE updated when dealer is playing
7. Check Firestore - hand documents should have `playerIds` field
