# Dealer Change/Handoff Feature

**Date:** 2026-02-22
**Status:** DONE

---

## Feature Description

Allow dealers to hand off a table to another dealer without destroying the session. The new dealer scans the table QR and continues exactly where the previous dealer left off.

---

## Implementation

- Added swap icon button between QR and Stop Session buttons
- Dealer change dialog confirms handoff and pauses session
- QR scan detects paused sessions and shows resume dialog
- New dealer can resume with all state preserved (players, blinds, button, hand number)

---

## Files Modified

- `lib/screens/dealer/dealer_table_screen.dart` - Dealer change button + dialog
- `lib/screens/dealer/dealer_qr_scan_screen.dart` - Detect paused sessions, resume logic
- `lib/services/dealer_service.dart` - `getPausedSessionForTable()`, `resumeSessionWithNewDealer()`
- `lib/models/dealer_session.dart` - Updated `copyWith()` for dealer fields
