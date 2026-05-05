# Chart Tooltip Navigation Fix

**Date**: 2026-05-05
**File**: `lib/screens/session_analytics_screen.dart`
**Issue**: Tapping anywhere on the stack chart after a tooltip is shown navigates to hand details screen.

## Root Cause

In the `touchCallback` of `LineTouchData`, when `_touchedSpotIndex != null` (tooltip visible), ANY `FlTapUpEvent` would navigate to the hand — regardless of where the tap landed on the chart.

## Fix

Changed the logic to check whether the tap landed on the SAME spot as the tooltip:
- If tap is on the same index as `_touchedSpotIndex` → navigate to hand details
- If tap is elsewhere (different spot or empty area) → just dismiss the tooltip

## Correct Pattern (DO NOT REGRESS)

```dart
touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
  if (event is FlTapUpEvent) {
    final tappedOnSpot = response != null && response.lineBarSpots != null && response.lineBarSpots!.isNotEmpty;
    final tappedIndex = tappedOnSpot ? response!.lineBarSpots!.first.x.toInt() : null;

    if (_touchedSpotIndex != null) {
      if (tappedIndex == _touchedSpotIndex) {
        // Tapped on the tooltip spot — navigate to hand
        final idx = _touchedSpotIndex!;
        setState(() => _touchedSpotIndex = null);
        _navigateToHandFromChart(idx);
      } else {
        // Tapped elsewhere — dismiss tooltip
        setState(() => _touchedSpotIndex = null);
      }
      return;
    }
    if (tappedOnSpot) {
      setState(() => _touchedSpotIndex = tappedIndex);
    }
  }
},
```

## Key Rule

Navigation to hand details should ONLY happen when user taps directly on the tooltip/spot, never on an empty area of the chart.
