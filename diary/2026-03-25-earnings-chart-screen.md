# Earnings Chart Screen Implementation

**Date:** 2026-03-25

## Summary
Implemented a full-screen horizontal earnings chart with zoom/pan functionality, accessible from the home screen earnings widget and sidebar drawer.

## Changes Made

### New Files
- `lib/screens/earnings_chart_screen.dart` - Full-screen landscape earnings chart

### Modified Files
- `lib/screens/home_screen.dart` - Navigation to chart, bottom sheet dialog for no data
- `lib/widgets/navigation_drawer.dart` - Added Bankroll menu item with chart navigation

### Deleted Files
- `lib/screens/bankroll_screen.dart` - Removed intermediate screen (using Profile for bankroll management)

## Features

### Earnings Chart Screen
- Landscape orientation with `SystemChrome.setPreferredOrientations`
- Pinch-to-zoom (1x to 5x) using `InteractiveViewer`
- Fixed Y-axis and X-axis outside zoom area
- Cumulative tournament (blue) and cash (green) lines
- Properly handles negative values (losses)
- Shows $0 reference line
- Zoom indicator with reset button

### Navigation
- Tap earnings widget on home screen → opens chart (if data exists)
- Tap Bankroll in sidebar drawer → opens chart (if data exists)
- Shows bottom sheet warning dialog if no session results

### Bottom Sheet Dialog
- Slides up from bottom with blur backdrop
- Chart icon, title, description
- Consistent style with other app dialogs

## Key Technical Details

### Negative Value Handling
Fixed `_roundToNice()` function to properly round negative values away from zero:
```dart
final shouldRoundAwayFromZero = isNegative ? !roundUp : roundUp;
```

### Single Data Point Fix
For single data points, chart now properly calculates min/max to show negative side:
```dart
if (minCumulative < 0) {
  finalMin = minCumulative * 1.2;
  finalMax = math.max(0, maxCumulative) * 1.2;
}
```

### Session Results Check
Both entry points check `SessionResultService.getAllSessionResults()` before navigating:
```dart
Future<void> _navigateToEarningsChart() async {
  final results = await SessionResultService.getAllSessionResults();
  if (results.isEmpty) {
    _showNoEarningsDataDialog();
  } else {
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => const EarningsChartScreen(),
    ));
  }
}
```

## Testing Notes
- Test with both positive and negative session results
- Test with single data point
- Test with multiple data points on different dates
- Verify zoom/pan works correctly
- Verify axes stay fixed during zoom
