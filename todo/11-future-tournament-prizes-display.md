# TODO: Tournament Prizes Display

**Date:** 2026-02-22
**Branch:** main
**Status:** TODO (Future Feature)
**Priority:** Low (Future)

---

## Feature Description

Club admin can input prize structure for tournaments. When a player busts in the money, the app displays how much they won.

---

## Requirements

1. **Admin Prize Configuration:**
   - Club admin sets prize pool structure during event creation
   - Options: percentage-based or fixed amounts
   - Example: 1st: 50%, 2nd: 30%, 3rd: 20%

2. **In-the-Money Detection:**
   - When player busts, check if their finish position is in the money
   - If yes, display prize amount in dialog/notification

3. **Prize Display:**
   - Show on bust dialog: "Congratulations! You finished 3rd - $500"
   - Show in final standings with prize column
   - Show in player's session history

---

## Data Model

```dart
class PrizeStructure {
  final int position;        // 1st, 2nd, 3rd, etc.
  final double? percentage;  // % of prize pool
  final double? fixedAmount; // Fixed prize
}

class EventPrizes {
  final double totalPrizePool;
  final List<PrizeStructure> payouts;
}
```

---

## Related Files

- `lib/models/club_event.dart` - Add prizes field
- `lib/screens/club/create_event_screen.dart` - Prize configuration UI
- `lib/screens/dealer/dealer_table_screen.dart` - Show prize on bust
- Final standings screen - Prize column

---

## Acceptance Criteria

- [ ] Admin can configure prize structure when creating event
- [ ] Prize structure saved with event
- [ ] When player busts in the money, show prize amount
- [ ] Final standings display prize column
- [ ] Player session history shows prize won
