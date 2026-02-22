# TODO: Color-Coded Stack Indicators on Live Rankings

**Date:** 2026-02-21
**Branch:** feature/dealer-assisted-logging
**Status:** TODO (Feature Enhancement)
**Priority:** Medium

---

## Feature Description

Display color-coded indicators on live rankings based on each player's stack relative to the average stack:

- **Green**: Above average
- **Orange**: Within ±10% of average
- **Red**: Below average

This gives players and spectators instant visual feedback on who's doing well and who's struggling.

---

## Current Behavior

- Live rankings show player stacks as plain numbers
- No visual indication of stack health relative to field

---

## Expected Behavior

- Calculate average stack in real-time
- Color-code each player's stack display:
  - **Green** (healthy): Stack > avg + 10%
  - **Orange** (average): Stack within avg ± 10%
  - **Red** (short): Stack < avg - 10%
- Updates dynamically as stacks change

---

## Implementation Notes

### Calculate Average Stack

```dart
double calculateAverageStack(List<PlayerRanking> players) {
  if (players.isEmpty) return 0;
  final totalChips = players.fold<double>(
    0,
    (sum, p) => sum + p.stack,
  );
  return totalChips / players.length;
}
```

### Determine Stack Status

```dart
enum StackStatus { above, average, below }

StackStatus getStackStatus(double stack, double avgStack) {
  if (avgStack == 0) return StackStatus.average;

  final upperBound = avgStack * 1.10;  // +10%
  final lowerBound = avgStack * 0.90;  // -10%

  if (stack > upperBound) {
    return StackStatus.above;
  } else if (stack < lowerBound) {
    return StackStatus.below;
  } else {
    return StackStatus.average;
  }
}
```

### Get Color for Status

```dart
Color getStackColor(StackStatus status) {
  switch (status) {
    case StackStatus.above:
      return Colors.green;      // or PokerFriendColors.green
    case StackStatus.average:
      return Colors.orange;     // or PokerFriendColors.yellow
    case StackStatus.below:
      return Colors.red;        // or PokerFriendColors.red
  }
}
```

### UI Integration

```dart
Widget _buildPlayerRankingTile(PlayerRanking player, double avgStack) {
  final status = getStackStatus(player.stack, avgStack);
  final stackColor = getStackColor(status);

  return ListTile(
    leading: _buildRankBadge(player.rank),
    title: Text(player.name),
    trailing: Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: stackColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: stackColor),
      ),
      child: Text(
        formatStack(player.stack),
        style: TextStyle(
          color: stackColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}
```

### Alternative: Chip Count with Icon

```dart
Row(
  children: [
    Icon(
      status == StackStatus.above ? Icons.arrow_upward :
      status == StackStatus.below ? Icons.arrow_downward :
      Icons.remove,
      color: stackColor,
      size: 16,
    ),
    SizedBox(width: 4),
    Text(
      formatStack(player.stack),
      style: TextStyle(color: stackColor),
    ),
  ],
)
```

### Show Average Stack Info

Consider showing the average stack somewhere on the rankings screen:

```dart
Text(
  'Avg Stack: ${formatStack(avgStack)}',
  style: TextStyle(color: PokerFriendColors.dark9),
)
```

---

## Visual Design Options

### Option 1: Colored Background
Stack number with colored background pill

### Option 2: Colored Text
Just the stack number in green/orange/red

### Option 3: Colored Border + Icon
Border around stack with up/down/neutral arrow

### Option 4: Progress Bar
Show stack as progress bar relative to chip leader or average

---

## Related Files

- `lib/screens/club/event_dashboard_screen.dart` - Live rankings display
- `lib/models/event_ranking.dart` - Ranking data model
- `lib/services/event_service.dart` - Rankings calculation

---

## Edge Cases

1. **Single player**: No meaningful average, show neutral/orange
2. **All equal stacks**: Everyone is "average" (orange)
3. **One big stack, rest short**: Most will be red, one green
4. **Player busted (0 chips)**: Show red, maybe with "BUSTED" label

---

## Acceptance Criteria

- [ ] Average stack calculated in real-time from all active players
- [ ] Players above avg +10% shown in green
- [ ] Players within avg ±10% shown in orange
- [ ] Players below avg -10% shown in red
- [ ] Colors update dynamically as stacks change
- [ ] Average stack value displayed somewhere on screen
- [ ] Works for both player view and spectator view
