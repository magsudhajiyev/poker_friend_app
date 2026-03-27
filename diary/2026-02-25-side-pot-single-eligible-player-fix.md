# Fix: Side Pot Handling Improvements

**Date:** 2026-02-25

## Changes Made

### 1. Auto-Award Single-Eligible Side Pots (Dealer Mode)

**Problem:** When 2 players go all-in (e.g., 300 vs 350 chips), a meaningless side pot of 50 was created that only the bigger stack could win.

**Solution:** In `_handleShowdown()`, filter out side pots with only 1 eligible player and auto-award them before showing winner selection.

**File:** `lib/screens/dealer/dealer_table_screen.dart`
**Method:** `_handleShowdown()` (~line 755)

```dart
// Filter out side pots with only 1 eligible player (auto-award those)
final contestedPots = <SidePot>[];
final autoAwardPots = <SidePot>[];

for (final pot in allSidePots) {
  if (pot.eligiblePlayers.length == 1) {
    autoAwardPots.add(pot);
  } else {
    contestedPots.add(pot);
  }
}

// Auto-award single-eligible pots
for (final pot in autoAwardPots) {
  final winnerId = pot.eligiblePlayers.first;
  _gameState!.players[winnerId - 1].currentStack += pot.amount;
  _gameState!.currentPot -= pot.amount;
}
```

---

### 2. Auto-Award Side Pots When Main Pot Winner is Biggest Stack

**Problem:** When the main pot winner is the biggest stack (eligible for all pots), dealer still had to manually select them as winner for each side pot.

**Solution:** Modified `MultiPotWinnerDialog` to auto-award side pots when main pot winner is eligible for them.

**File:** `lib/widgets/multi_pot_winner_dialog.dart`

**Key changes:**
- Added `autoAwardedPots` set to track which pots are auto-filled
- Added `_updateAutoAwards()` method called when main pot winner changes
- Auto-awarded pots show green "Auto-awarded to [winner] (main pot winner)" message
- Side pot selection only shown for pots where main pot winner is NOT eligible

**Example:** 3-way all-in (10, 50, 160 chips):
- Main pot: 30 (all three eligible)
- Side pot 1: 80 (50 and 160 eligible)
- Side pot 2: 110 (only 160 eligible - auto-awarded)

If player with 160 chips wins main pot:
- Side pots 1 and 2 auto-award to them (no selection needed)

If player with 10 chips wins main pot:
- Side pot 1: Must select between 50 and 160 chip players
- Side pot 2: Auto-awarded to 160 chip player

---

### 3. Record Only Main Pot Winner in Hand History

**Problem:** When multiple pots had different winners, ALL winners were recorded in the hand history.

**Solution:** Only the main pot winner(s) are recorded as the hand winner. Side pot winners still receive their chips, but aren't recorded as "hand winners".

**Files:**
- `lib/screens/dealer/dealer_table_screen.dart` - `_showMultiPotWinnerDialog()`
- `lib/screens/poker_hand_screen.dart` - Already correct (uses `potResults[0]`)

**Key logic:**
```dart
// For hand record, only use the MAIN POT winner(s)
final mainPotResult = potResults[0]!;
final bool isMainPotChopped = mainPotResult['isChoppedPot'] == true;
final List<int> mainPotWinners = isMainPotChopped
    ? List<int>.from(mainPotResult['winners'])
    : [mainPotResult['winner'] as int];

// Record hand with main pot winner only
sessionManager.completeCurrentHand(
  potAmount: totalDistributed,
  winnerId: mainPotWinners.first,
);
```

---

### 4. Cascading Side Pot Auto-Award

**Problem:** When there are multiple side pots (3+ players all-in), the auto-award logic didn't cascade properly.

**Example scenario:**
- Eve (368 chips), Diana (1.6K), Test (2.4K), Grace (11.8K) all go all-in
- Pots: Main pot (all 4 eligible), SP1 (Diana/Test/Grace), SP2 (Test/Grace)
- User selects Eve as main pot winner
- User selects Test as SP1 winner
- **Bug:** SP2 still required selection even though Test is eligible for SP2

**Root cause:** `_updateAutoAwards()` only checked if the MAIN POT winner was eligible for side pots. It didn't cascade through side pots.

**Solution:** Modified `_updateAutoAwards()` to cascade through all pots:
1. Track the "current winner" starting from main pot
2. For each subsequent pot:
   - If current winner is eligible → auto-award to them
   - If current winner is NOT eligible → check if manual selection exists, use that as new current winner
3. Call `_updateAutoAwards()` whenever ANY pot winner changes (not just main pot)

**File:** `lib/widgets/multi_pot_winner_dialog.dart`

**Key changes:**
```dart
void _updateAutoAwards() {
  autoAwardedPots.clear();
  int? currentWinner = isChoppedPot[0] == true ? null : singleWinners[0];

  for (int i = 1; i < widget.sidePots.length; i++) {
    if (currentWinner != null &&
        widget.sidePots[i].eligiblePlayers.contains(currentWinner)) {
      // Auto-award this pot to the current winner
      autoAwardedPots.add(i);
      singleWinners[i] = currentWinner;
      isChoppedPot[i] = false;
      choppedWinners[i] = <int>{};
    } else {
      // Check if this pot has a manual selection to use as new current winner
      if (isChoppedPot[i] == true) {
        currentWinner = null;
      } else if (singleWinners[i] != null) {
        currentWinner = singleWinners[i];
      } else {
        currentWinner = null;
      }
    }
  }
}
```

- Updated auto-award display to show "(eligible from previous pot)" when not main pot winner

---

## Files Modified

| File | Change |
|------|--------|
| `lib/screens/dealer/dealer_table_screen.dart` | Auto-award single-eligible pots, record main pot winner only |
| `lib/widgets/multi_pot_winner_dialog.dart` | Auto-award side pots with cascading logic |

---

## Verification

### Test 1: 2-Way All-In (Auto-Award Single-Eligible)
1. Player A: 300 chips, Player B: 350 chips
2. Both go all-in
3. **Expected:** Only "Main Pot: 600" shown (no 50 chip side pot)

### Test 2: 3-Way All-In (Main Pot Winner is Biggest Stack)
1. Players with 10, 50, 160 chips all-in
2. Select 160-chip player as main pot winner
3. **Expected:** All side pots auto-award to them, no additional selection needed

### Test 3: 3-Way All-In (Main Pot Winner is Smallest Stack)
1. Players with 10, 50, 160 chips all-in
2. Select 10-chip player as main pot winner
3. **Expected:**
   - Side pot 1 (80): Must select between 50 and 160 chip players
   - Side pot 2 (110): Auto-awarded to 160 chip player
   - Hand record shows only 10-chip player as winner

### Test 4: Hand History Display
1. Complete any multi-pot hand
2. Check hand history
3. **Expected:** Only main pot winner shown as "Winner"

### Test 5: Cascading Side Pot Auto-Award (4+ Players)
1. 4-way all-in: Eve (368), Diana (1.6K), Test (2.4K), Grace (11.8K)
2. Select Eve as main pot winner
3. Select Test as SP1 winner
4. **Expected:** SP2 auto-awards to Test (shows "Auto-awarded to Test (eligible from previous pot)")

### Test 6: No Cascade When Winner Not Eligible
1. Same scenario as Test 5
2. Select Eve as main pot winner
3. Select Diana as SP1 winner
4. **Expected:** SP2 still requires selection (Diana not eligible for SP2)
