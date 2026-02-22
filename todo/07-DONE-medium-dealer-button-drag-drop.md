# TODO: Dealer Button Drag-Drop, Horizontal View, and Blinds Control

**Date:** 2026-02-21
**Branch:** feature/dealer-assisted-logging
**Status:** DONE (Button Drag-Drop + Blinds Change)
**Priority:** Medium

---

## Feature Requests

### 1. Button Drag-Drop for Dealer

Allow dealer to drag and drop the dealer button to any seat instead of tapping or using arrows.

**Current Behavior:**
- Dealer taps arrows or buttons to move dealer button position

**Expected Behavior:**
- Dealer can drag the button icon and drop it on any seat
- Visual feedback while dragging (button follows finger)
- Snap to nearest valid seat on drop

**Implementation Notes:**
```dart
Draggable<int>(
  data: currentButtonPosition,
  child: ButtonIcon(),
  feedback: ButtonIcon(opacity: 0.7),
  childWhenDragging: ButtonIcon(opacity: 0.3),
)

// Each seat is a DragTarget
DragTarget<int>(
  onAccept: (fromSeat) {
    setState(() => _buttonPosition = seatNumber);
  },
  builder: (context, candidateData, rejectedData) {
    return SeatWidget(
      isHighlighted: candidateData.isNotEmpty,
    );
  },
)
```

---

### 2. Adjust Dealer View for Horizontal/Landscape Mode

Dealer screen should work well in landscape orientation for tablets and phones held horizontally.

**Current Behavior:**
- Dealer screen designed for portrait mode only
- May have layout issues in landscape

**Expected Behavior:**
- Table layout adapts to landscape (oval table shape)
- Controls repositioned for horizontal use
- Better use of screen real estate on tablets

**Implementation Notes:**
```dart
OrientationBuilder(
  builder: (context, orientation) {
    if (orientation == Orientation.landscape) {
      return _buildLandscapeLayout();
    }
    return _buildPortraitLayout();
  },
)
```

---

### 3. "Blinds Are Up" Button

Quick button for dealer to signal that blinds have increased (tournament mode).

**Current Behavior:**
- No easy way to update blinds during session
- Dealer must go to settings or can't change at all

**Expected Behavior:**
- "Blinds Up" button visible in tournament mode
- Tapping shows quick picker for new blind level
- Or auto-advances to next preset level

**Implementation Notes:**
```dart
// Only show in tournament mode
if (gameType == 'tournament')
  ElevatedButton.icon(
    icon: Icon(Icons.arrow_upward),
    label: Text('Blinds Up'),
    onPressed: _showBlindsUpDialog,
  )
```

---

### 4. Blinds Adjusted by Club Admin

Club admin should be able to set and change blind levels for an event, which syncs to dealer screens.

**Current Behavior:**
- Blinds set at session start by dealer
- No remote control by admin

**Expected Behavior:**
- Club admin can set blind structure in event settings
- Admin can push "Blinds Up" to all tables in event
- Dealer screens receive real-time blind updates
- Optional: Automatic blind increases on timer

**Implementation Notes:**

**Event Model Addition:**
```dart
class ClubEvent {
  // ... existing fields
  final List<BlindLevel> blindStructure;
  final int currentBlindLevel;
  final DateTime? nextBlindIncrease;
}

class BlindLevel {
  final int smallBlind;
  final int bigBlind;
  final int ante;
  final int durationMinutes;
}
```

**Admin UI:**
- Blind structure editor in event creation/edit
- "Advance Blinds" button in live event dashboard
- Timer display showing time until next level

**Dealer Screen:**
- Listen to event updates for blind changes
- Show notification when blinds increase
- Update session blinds automatically

```dart
// Watch for event blind changes
EventService.watchEvent(clubId, eventId).listen((event) {
  if (event.currentBlindLevel != _currentLevel) {
    _updateBlinds(event.blindStructure[event.currentBlindLevel]);
    _showBlindsUpNotification();
  }
});
```

---

## Related Files

- `lib/screens/dealer/dealer_table_screen.dart` - Main dealer screen
- `lib/models/club_event.dart` - Event model (add blind structure)
- `lib/services/event_service.dart` - Event updates
- `lib/screens/club/event_detail_screen.dart` - Admin event controls

---

## Acceptance Criteria

**Button Drag-Drop:** ✅ DONE
- [x] Dealer can drag button to any seat (occupied or not)
- [x] Visual feedback during drag (seat glows, button semi-transparent)
- [x] Button snaps to seat on drop
- [x] Persisted to Firestore with error handling

**Horizontal View:** DEFERRED
- [ ] Dealer screen works in landscape orientation
- [ ] Table layout adapts appropriately
- [ ] All controls accessible in both orientations

**Blinds Up Button:** ✅ DONE (in separate commit)
- [x] Blinds info is clickable in dealer screen
- [x] Dialog for entering new blind levels
- [x] Session updates immediately

**Admin Blind Control:** DEFERRED
- [ ] Admin can define blind structure for event
- [ ] Admin can advance blinds for all tables
- [ ] Dealer screens update in real-time
- [ ] Optional automatic timer-based increases
