# TODO: Share Showdown Hole Cards Between Players at Table

**Date:** 2026-02-21
**Branch:** feature/dealer-assisted-logging
**Status:** TODO (Future Enhancement)
**Priority:** Medium

---

## Feature Description

When multiple players at the same table are using Poker Friend, they should be able to see each other's hole cards in their hand history - but **only for hands that went to showdown**.

This creates a richer hand history experience where players can review showdown hands with complete information.

---

## Current Behavior

1. Player A and Player B are at same table, both using Poker Friend
2. Hand goes to showdown
3. Player A enters their hole cards
4. Player B enters their hole cards
5. Each player can only see their own hole cards in hand history
6. No visibility into opponent's actual holdings at showdown

---

## Expected Behavior

1. Player A and Player B are at same table, both using Poker Friend
2. Hand goes to showdown (`reachedShowdown: true`)
3. Player A enters their hole cards
4. Player B enters their hole cards
5. **Both players can see each other's hole cards in hand history**
6. Non-showdown hands remain private (only see your own cards)

---

## Implementation Notes

### Data Storage

Currently, player hole cards are stored in:
- `dealer_sessions/{sessionId}/hands/{handId}/player_data/{playerId}`

For showdown hands, we need to make this data visible to other players at the table.

### Approach 1: Shared Showdown Data (Recommended)

When a hand reaches showdown, copy hole cards to a shared location:

```dart
// In hand document
{
  'reachedShowdown': true,
  'showdownData': {
    'seat1': {'card1': 'A♠', 'card2': 'K♥', 'playerId': 'user123'},
    'seat5': {'card1': 'Q♦', 'card2': 'Q♣', 'playerId': 'user456'},
  }
}
```

### Approach 2: Query Player Data for Showdown Hands

When displaying a showdown hand, fetch all player_data subcollection documents:

```dart
if (hand['reachedShowdown'] == true) {
  final playerDataSnapshot = await _firestore
      .collection('dealer_sessions')
      .doc(sessionId)
      .collection('hands')
      .doc(handId)
      .collection('player_data')
      .get();

  // Merge all player hole cards into showdownData
}
```

### Privacy Rules

1. **Showdown hands only**: Only share hole cards if `reachedShowdown == true`
2. **Same session only**: Only players who participated in that session can see
3. **After hand completion**: Only visible after hand is marked complete
4. **Mucked hands excluded**: If player folded at showdown without showing, don't reveal

### UI Changes

**Hand Details Screen:**
- For showdown hands, show all revealed hole cards with player names
- Add "Showdown" section showing all hands that were shown
- Display winner's hand prominently

**Hand Card (in history list):**
- Maybe show small indicator if showdown data is available from other players

---

## Related Files

- `lib/services/dealer_service.dart` - `savePlayerHandData()`, `completeHand()`
- `lib/screens/hand_actions_screen.dart` - Hand details display
- `lib/screens/player/player_session_screen.dart` - Player's live session view
- `lib/screens/session_hands_screen.dart` - Session hand history

---

## Edge Cases

1. **Player enters cards late**: Should still sync to other players' history
2. **Only one player using app**: Still works, just no shared data
3. **Player mucks at showdown**: Don't share their cards
4. **Chopped pot**: Show all winners' hands

---

## Security Considerations

- Firestore rules should verify user was participant in the session
- Only allow reading showdownData if `reachedShowdown == true`
- Prevent reading other players' private `player_data` for non-showdown hands

---

## Acceptance Criteria

- [ ] Players at same table can see each other's showdown hole cards
- [ ] Non-showdown hands remain completely private
- [ ] Hand history UI displays all showdown hands clearly
- [ ] Works when players enter cards at different times
- [ ] Mucked hands at showdown are not revealed
