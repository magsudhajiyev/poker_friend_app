# Player Can Edit Any Hand During Session

## Feature Request
Player should be able to add hole cards, notes, and tags to ANY hand during the course of the session - not just the current hand.

## Current Behavior
- Player can only add hole cards/notes/tags to the current active hand
- Once hand is completed, cannot go back and add data

## Expected Behavior
- Show list of completed hands during live session
- Player can tap on any past hand to add/edit:
  - Hole cards
  - Notes
  - Tags
- Changes saved immediately to Firestore

## Implementation Ideas
1. Add "Hand History" section to PlayerSessionScreen
2. Show scrollable list of completed hands with quick summary
3. Tap to expand and add hole cards/notes/tags
4. Use same `DealerService.savePlayerHandData()` method

## Files to Modify
- `lib/screens/player/player_session_screen.dart` - add hand history UI
- `lib/services/dealer_service.dart` - ensure savePlayerHandData works for any hand

## Priority
Medium
