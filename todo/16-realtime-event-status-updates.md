# Real-time Event Status Updates

## Problem
When event status changes (e.g., admin starts the event), it does not update in real-time on other devices. Users need to go back or refresh the page to see that the event is live.

## Current Behavior
- Admin starts event → status changes in Firestore
- Other users viewing event detail don't see update
- Must manually navigate away and back, or pull to refresh

## Expected Behavior
- Event status changes should propagate immediately to all viewers
- UI should update in real-time without user action
- Visual indication when event goes live (banner, animation, etc.)

## Root Cause
- Event detail screen likely uses `Future` instead of `Stream` for event data
- Not listening to real-time updates from Firestore

## Solution
1. Change event fetching from `Future` to `Stream` using Firestore snapshots
2. Use `StreamBuilder` in event detail screen
3. Add visual feedback when status changes (toast, banner, etc.)

## Files to Modify
- `lib/screens/club/event_detail_screen.dart` - use StreamBuilder for event
- `lib/services/event_service.dart` - add `watchEvent()` stream method

## Implementation
```dart
// Add to EventService
static Stream<ClubEvent?> watchEvent(String clubId, String eventId) {
  return _firestore
      .collection(_eventsCollection)
      .doc(eventId)
      .snapshots()
      .map((doc) => doc.exists ? ClubEvent.fromFirestore(doc) : null);
}
```

## Priority
High - affects user experience significantly
