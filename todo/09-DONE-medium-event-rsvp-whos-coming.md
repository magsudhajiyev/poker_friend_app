# DONE: Display "Who's Coming" for Events with Auto-Reload

**Date:** 2026-02-21
**Status:** COMPLETED
**Priority:** Medium

---

## Feature Description

Show a real-time list of players who have confirmed attendance for an event. This is visible to all club members from the moment the event is created, and auto-refreshes as players RSVP.

---

## Implementation Summary

The RSVP system was already mostly implemented. This update added:

1. **Real-time updates on Event Detail Screen**
   - Added `StreamSubscription` to watch attendance changes
   - UI updates automatically when any user RSVPs

2. **Going count on Event Cards in Home Screen**
   - Added `_eventGoingCounts` map to track counts per event
   - Display "X going" badge on event cards with green styling

---

## Files Modified

| File | Changes |
|------|---------|
| `lib/screens/home_screen.dart` | Added `_eventGoingCounts` map, `_loadEventAttendanceCounts()` method, "going" badge in `_buildEventItem()` |
| `lib/screens/club/event_detail_screen.dart` | Added `_attendanceSubscription`, `_setupAttendanceListener()` for real-time updates |

---

## Already Existed (No Changes Needed)

- `lib/models/event_attendance.dart` - Full model with status enum
- `lib/services/event_attendance_service.dart` - Complete RSVP service
- `lib/screens/club/event_attendees_screen.dart` - Full attendee list
- RSVP buttons (Going/Maybe/Can't Go)
- "Who's Coming" section with counts and names
- Calendar integration

---

## Acceptance Criteria

- [x] Players can RSVP as Going / Maybe / Can't Go
- [x] "Who's Coming" section shows on event detail
- [x] List updates in real-time without manual refresh
- [x] Going count visible on event cards in list view
- [x] Shows player names and avatars
- [x] Works from event creation through event completion
- [x] Current user's RSVP status is highlighted

---

## Completed: 2026-02-23
