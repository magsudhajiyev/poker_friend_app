# 2026-03-27: Design Updates - Opponents, Seat Setup, Navbar

## Changes Made

### Navbar
- Wrapped nav item labels in `FittedBox(fit: BoxFit.scaleDown)` to prevent text overflow on smaller devices (iPhone 11)

### Opponents Screen - Empty State
- Updated to match Figma: `#101115` bg, black border, 16px radius
- Icon color: teal `#89F1EC` (was white)
- Title: w400 (was w600), subtitle: 17px `#D3FFFD` (was 14px `#89F1EC`)
- Button: cyan `#89F1EC` bg with plus icon (was white bg)
- Card positioned top-aligned, width matches search bar

### Opponent Detail Screen
- "View Hand History" button: removed fixed height, uses padding for proper text centering
- "No Hands Found" modal redesigned:
  - Ghost icon (new SVG asset) replaces info icon
  - Close button: `#4B9A96` muted teal (was white)
  - Title: w500, subtitle: 15px `#CCCDCE`
  - Spacing matches Figma: 34px gaps

### Seat Setup Screen
- Seat circles: 38px black bg + 2px cyan border (was 48px solid fill)
- Number font: Inter Bold 17px (was IBM Plex Sans 18px)
- 3 layout variants for label placement (prevents overlap with table line):
  - Seat 1 (top): label below
  - Seats 6,7,8,9 (left side): label to the right
  - Seats 2,3,4,5 (right side): label to the left
- Inactive seats: gray bg `#2A2A2E`, dimmed border/text
- Default label shows "Player" (not "Player N" — number is in circle)
- Table oval enlarged: 70%×80% → 80%×88%

### Seat Setup - Functional Fix
- **Bug**: Deactivating a seat didn't reset player name and stack
- **Fix**: When toggling seat OFF in dialog, immediately reset name to empty, stack to default, clear "my seat" flag
- **Fix**: Save handler also resets on deactivation + clears selectedSeat if it was user's seat

## Files Modified
- `lib/widgets/global_bottom_nav_bar.dart`
- `lib/screens/my_opponents_screen.dart`
- `lib/screens/opponent_detail_screen.dart`
- `lib/screens/seat_setup_screen.dart`
- `icons/figma_icons/ghost.svg` (new asset)
