# Bug: Position Mismatch Between Hand Card and Hand Details View

**Status**: 🔴 Open - Investigation Needed
**Date Reported**: 2025-10-31
**Severity**: Medium
**Impact**: Data inconsistency in UI display

## Description

In some hands, the hero's position is displayed differently in two places:
1. Hand card (in hand list/history)
2. Hand details view (when clicking on a hand)

This creates confusion as the same hand shows different position information depending on where you're viewing it.

## Suspected Causes

### Primary Suspect: Button Position Adjustments During Hand Logging
- During hand logging, user sometimes needs to readjust button position
- This might cause position calculations to differ between when hand is logged vs. when it's displayed

### Secondary Suspect: Empty Seat Edge Case
**Scenario**: Player busts from Small Blind seat
- SB player busts out
- In next hand, button moves to the (now empty) SB seat
- Hand is played without a Small Blind player
- Position calculations may be incorrect because:
  - System expects SB seat to be occupied
  - Button is on an empty seat
  - Player positions relative to button might be calculated incorrectly

## Where It Manifests

- **Hand Card**: Shows one position (e.g., "BTN")
- **Hand Details View**: Shows different position (e.g., "CO")

## Technical Context

Relevant files:
- Position calculation logic in hand state management
- Hand card rendering
- Hand details view rendering
- Button position tracking during hand logging

## Questions to Investigate

1. When is the position calculated and stored?
   - During hand logging?
   - When saving to Firebase?
   - When displaying in UI?

2. Is position stored in the hand record, or calculated on-the-fly?

3. How does the system handle:
   - Button position changes mid-hand?
   - Empty seats where button should be?
   - Situations where SB or BB seats are empty?

4. Are there two different position calculation functions?
   - One for hand cards?
   - One for hand details?

5. What happens when button position is adjusted:
   - Does it update existing hands?
   - Does it only affect future hands?
   - Is there a timing issue?

## Reproduction Steps

**Unknown** - Need to document when this occurs:
- [ ] Does it happen after button position adjustments?
- [ ] Does it happen when seats are empty?
- [ ] Does it happen consistently or randomly?
- [ ] Can it be reproduced with specific seat configurations?

## Next Steps

1. Add debug logging to position calculation functions
2. Log position when hand is saved to Firebase
3. Log position when hand is displayed in both views
4. Test with empty SB scenario:
   - Remove player from SB seat
   - Move button to empty SB seat
   - Log a hand
   - Check if position matches in both views

## Related Code Areas

```
/lib/models/hand_state_machine.dart - Hand position tracking
/lib/screens/poker_hand_screen.dart - Hand logging and button position
/lib/screens/hand_actions_screen.dart - Hand details display
/lib/services/firebase_service.dart - Hand saving logic
```

## Workaround

None available - data inconsistency must be fixed

## Fix Strategy (TBD)

Once root cause is identified:
1. Ensure position is calculated consistently
2. Store position in hand record at time of logging (don't recalculate)
3. Handle empty seat edge cases properly
4. Add validation to ensure position makes sense given button position

---

**Notes**:
- This bug affects data integrity and user trust in the app
- Position is critical for poker hand analysis
- AI analyzer depends on accurate position information
- Should be investigated before rolling out to production
