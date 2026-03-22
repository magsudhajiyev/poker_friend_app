# Dealer Action Rollback & Stats Sync Verification

**Priority**: High
**Created**: 2026-02-27

---

## Task 1: Dealer Action Rollback

### Description
Add action rollback functionality for dealers, similar to the existing manual logging mode. Each click on the undo button should:
- Roll back the last action
- Return chips back to the player accordingly
- Update pot correctly
- Restore previous game state

### Current State
- Manual logging mode has undo functionality
- Dealer mode currently lacks this feature
- Dealers cannot correct mistakes without starting over

### Requirements
- [ ] Add undo button to dealer interface
- [ ] Roll back action from action history
- [ ] Return bet/raise amounts to player's stack
- [ ] Update pot amount (subtract returned chips)
- [ ] Handle edge cases:
  - [ ] Undo all-in (restore player stack)
  - [ ] Undo call (return call amount)
  - [ ] Undo raise (return raise amount)
  - [ ] Undo fold (restore player to active)
  - [ ] Undo across street changes (e.g., undo flop action)

### Reference
Look at manual logging undo implementation:
- `lib/screens/poker_hand_screen.dart` - undo action logic
- `lib/models/hand_state_machine.dart` - state management

### Files to Modify
- `lib/screens/dealer/dealer_table_screen.dart` - add undo UI
- `lib/services/dealer_service.dart` - undo logic
- `lib/models/dealer_session.dart` - action history management

---

## Task 2: Stats & Session Sync Verification

### Description
Verify that player statistics and session data are correctly synced after completed dealer-assisted sessions.

### Items to Verify
- [ ] Player's total hands count updates correctly
- [ ] VPIP count increments when player voluntarily puts money in
- [ ] PFR count increments on preflop raises
- [ ] 3-bet count tracked correctly
- [ ] Won hands count updates
- [ ] Session appears in player's session history
- [ ] Bankroll updates reflect session results
- [ ] Opponent stats update for players at the table

### Test Scenarios
1. Complete a dealer session with multiple hands
2. Check each player's stats before and after
3. Verify session record created in `poker_sessions` collection
4. Verify `user_stats` document updated atomically
5. Test with multiple players at table

### Files to Review
- `lib/services/firebase_service.dart` - `_updateUserStatsFromHand()`
- `lib/services/dealer_service.dart` - `endSession()` flow
- `lib/services/user_stats_service.dart` - stats update logic

---

## Notes
- Task 1 is user-facing and improves dealer UX
- Task 2 is verification/debugging to ensure data integrity
- Both are important for production readiness of dealer mode
