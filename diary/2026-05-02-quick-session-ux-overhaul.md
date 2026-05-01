# Quick Session UX Overhaul — 2026-05-02

## Summary
Major UX improvements to individual (now "Quick Session") logging mode, session end flow, earnings chart, and FormDrawer keyboard behavior.

## Changes

### Stack Chart Enhancements
- **HandRecord in charts**: Chart tooltips now show hole cards and position from completed hands
- **Index mapping fix**: Use `handNumber - 1` instead of `index - 1` to correctly map hand records when manual updates exist between hands
- **Note support**: Stack history entries support optional `note` field; chart tooltips show notes with pencil icon; long notes (>30 chars) use scrollable custom overlay instead of fl_chart tooltip
- **Note support in session analytics**: Session analytics and full stack chart screens also show notes and manual update labels

### Quick Stack Update Screen
- **Position pills**: Non-BTN position pills changed to red (#FF5252) for visibility
- **Dealer button**: Changed from teal to golden (#FFD700) — circle, border, text, card border, BTN pill
- **Live BB preview**: Stack edit dialog shows real-time chip amount as user types BB value

### Individual Session Tracking (renamed to Quick Session)
- **Update stack as FormDrawer**: Converted from AlertDialog to FormDrawer matching add-opponent drawer design
- **Stack update redesign**: Removed Add/Subtract section, added autofocus on Set New Total, added optional note field (max 100 chars)
- **Add-on feature**: + icon replaces 3-dot menu icon; Add-on menu item added. Cash: single amount field. Tournament: price + chips fields. Updates totalBuyIn, currentStack, and chart
- **Cash game + button**: Directly opens add-on dialog (no dropdown) since cash games only have add-ons, not rebuys
- **Back navigation confirmation**: PopScope with save/discard/cancel dialog
- **Session end flow restructured**: Bankroll sheet shown BEFORE ending session; X = cancel and resume; checkmark = apply and end

### FormDrawer
- **Keyboard push-up**: Drawer now pushed up by keyboard via outer `Padding(bottom: viewInsets.bottom)`; removed duplicate inner keyboard padding
- **Update stack drawer always shows actual value**: Not BB-converted, regardless of BB mode

### Session End Bankroll Sheet
- **Converted to FormDrawer**: Replaced custom container with FormDrawer.show(); X = skip/cancel, checkmark = apply
- **Controller disposal fix**: Delayed disposal by 500ms to prevent "TextEditingController used after disposed" error during closing animation
- **Input border fix**: Added explicit `enabledBorder: InputBorder.none`, `focusedBorder: InputBorder.none`, `filled: false`

### Earnings Chart (Home Screen)
- **Replaced CustomPainter with fl_chart**: Now uses `LineChart` matching stack growth chart style — dots at every data point, smooth curves, left-side Y labels, proper grid
- **Deduplicated date labels**: Overlapping dates at bottom axis filtered by unique date strings
- **Y-axis boundary labels**: Skipped min/max auto-labels to prevent overlap

### Session Analytics
- **Share icon grayed out**: When 0 hands logged, share icon is 25% opacity and tap disabled

### Naming
- "Individual Logging Mode" renamed to "Quick Session Logging Mode" across all 7 languages

## Key Patterns
- FormDrawer keyboard handling: outer `Padding(bottom: viewInsets.bottom)` wrapping the Container — single source, no double padding
- Controller disposal in static `show()` methods: delay disposal with `Future.delayed(500ms)` to survive closing animation
- Session end flow: always show result sheet before ending session so user can cancel

## Files Modified (25 files)
- `lib/design_system/components/form_drawer.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/individual_session_tracking_screen.dart`
- `lib/screens/poker_hand_screen.dart`
- `lib/screens/quick_stack_update_screen.dart`
- `lib/screens/session_analytics_screen.dart`
- `lib/screens/stack_chart_screen.dart`
- `lib/widgets/session_end_bankroll_sheet.dart`
- `lib/widgets/stack_growth_chart.dart`
- `lib/widgets/table_management_sheet.dart`
- `lib/l10n/app_*.arb` (7 files) + generated localizations (7 files)
