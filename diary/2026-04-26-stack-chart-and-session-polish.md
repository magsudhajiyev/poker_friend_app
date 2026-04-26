# Stack Chart in Session Details + Session Polish

**Date**: 2026-04-26

## Stack Chart in Session Details Screen

Added a live stack chart inside the Session Details screen (`IndividualSessionTrackingScreen`) so players can see their stack trajectory during a session without ending it.

### Features
- **Inline chart card** — dark container with "Stack Chart" title and fullscreen expand button
- **fl_chart** with curved lines, white dots with teal stroke, gradient fill below (matches existing `StackChartScreen` style)
- **7-point viewport** — fits 7 data points in frame; additional points scroll the chart left, always showing the latest 7 by default
- **Swipe to scroll** — horizontal drag to see earlier stack changes; tooltips dismiss on scroll
- **Tap dots** — shows stack value, position, and hole cards via fl_chart tooltip (no hand review navigation during live session)
- **Dynamic Y-axis** — Y bounds recalculate based on visible data points when scrolling, with 15% padding so dots never touch axes
- **Fullscreen landscape mode** — matches `StackChartScreen` design exactly: gradient background, header with back button + session name, info pills (Avg Growth, Duration, P/L), 20-point viewport
- **Line color** — teal when winning, red when losing

### Files Changed
- `lib/widgets/stack_growth_chart.dart` — **NEW** — `StackGrowthChart` (stateful, scrollable) + `StackGrowthChartFullScreen` (landscape route)
- `lib/screens/individual_session_tracking_screen.dart` — added `liveStackHistory`/`completedHands` params, chart card, collapsible "Session Info" section
- `lib/screens/poker_hand_screen.dart` — passes `stackHistory` + `completedHands` to session details screen

## Other Changes

### BB Mode Persistence
- BB Mode toggle state now saved to SharedPreferences and restored when returning to session details

### Session Info Card Rename
- "Session Stats" collapsible card renamed to "Session Info"

### "Stack Chart" Rename (global)
- Renamed "Stack Growth" → "Stack Chart" across all screens: `stack_chart_screen.dart`, `session_analytics_screen.dart`, `individual_session_tracking_screen.dart`, `stack_growth_chart.dart`

### No $ in MTT Winner Flash
- The settling overlay between hands no longer shows `$` prefix for tournament game types

### Removed >> Forward Button
- Removed the `fast_forward` (>>) button that briefly appeared in the top bar when a street completed — auto-advance handles this already

### X-axis Label Overlap Fix
- Added 8px left padding to the first X-axis label in the chart to prevent overlap with Y-axis labels

### Main Stack Card Cleanup
- Consolidated P/L and Growth% into a single compact row (`+$150.00 (+15.0%)`) instead of two separate columns
