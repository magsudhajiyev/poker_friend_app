# Statistics Screen Redesign and Global Navigation System

**Date**: January 18, 2026
**Branch**: `design-experimentation`
**Commit**: 6f28274

## Summary

Completed comprehensive redesign of the Statistics screen with new card layouts and implemented a global navigation system that provides consistent navigation across all screens with proper active state highlighting.

## Statistics Screen Updates

### 1. Statistics Header Section
- Added "Statistics" title with "Overall performance" subtitle
- Typography:
  - Title: Inter, 28px, weight 600, -0.56px letter spacing
  - Subtitle: Inter, 16px, weight 400, white 80% opacity, -0.32px letter spacing
- Positioned inside scrollable area (not fixed)
- 16px gap between header and cards

### 2. Stat Cards Redesign
**New Layout Structure**:
- Icon at top-left in circular container (48×48px)
- Label text below icon
- Value at bottom

**Card Styling**:
- Background: `#1d2a27` (glassy dark green)
- Border radius: `12px`
- Padding: `18px vertical, 16px horizontal`
- Grid spacing: `8px` (both horizontal and vertical)

**Icon Containers**:
- Size: 48×48px circular
- Background: White with 10% opacity
- Icon size: 32×32px inside container

**Typography**:
- Label: Inter, 16px, weight 500, white 84% opacity, height 1.4
- Value: Inter, 20px, weight 500, white 100%, height 1.4
- Letter spacing: 0 for both

### 3. Positional Statistics Card
- Updated container styling to match stat cards
- Background: `#1d2a27`
- Border radius: `12px`
- Padding: `18px vertical, 16px horizontal`
- Header row: `#161618` (solid dark)
- Data rows: `#161618` with 50% opacity

### 4. Session Statistics Card
- Updated container styling to match stat cards
- Background: `#1d2a27`
- Border radius: `12px`
- Padding: `18px vertical, 16px horizontal`

### 5. Scrollable Layout
- Made entire screen scrollable (header + content)
- Top header (profile + notifications) scrolls with content
- Statistics header scrolls with content
- Smooth scrolling experience

## Global Navigation System

### 1. GlobalBottomNavBar Widget
**Location**: `lib/widgets/global_bottom_nav_bar.dart`

**Features**:
- Shared across all screens for consistency
- Takes `currentScreen` parameter to track active screen
- Highlights active screen icon in lime green (#A5EC44)

**Layout**:
- Container: 70px height, 35px border radius
- Background: `#2D2D2D`
- Margin: 20px all around
- 5 icons evenly spaced

**Navigation Items**:
1. **Home** - Navigate to HomeScreenExperimental
2. **Opponents** (replaced Stats) - Navigate to MyOpponentsScreen
3. **+ Button** (center, green circle) - Navigate to LoggingModeSelectionScreen
4. **Sessions** - Navigate to SessionHistoryScreen
5. **Profile** - Navigate to ProfileScreen

**Active State**:
- Active icon color: `#A5EC44` (lime green)
- Inactive icon color: White
- Icon size: 28px
- Center button: 56×56px green circle with black + icon

### 2. GlobalTopHeader Widget
**Location**: `lib/widgets/global_top_header.dart`

**Features**:
- Shared across all screens
- Takes `currentScreen` parameter to highlight active buttons
- Consistent spacing and styling

**Layout**:
- Profile picture (60×60px) on left
- Statistics + Notifications buttons on right
- 12px spacing between right icons

**Elements**:
1. **Profile Picture** (left)
   - Size: 60×60px circular
   - Background: White 15% opacity
   - Icon: Person icon, white, 36px
   - Action: Navigate to ProfileScreen

2. **Statistics Button** (right-center)
   - Size: 52×52px circular
   - Normal: White 15% opacity background, white icon
   - Active: Lime green 20% opacity background, lime green icon (#A5EC44)
   - Icon: bar_chart_rounded, 26px
   - Action: Navigate to StatisticsScreen

3. **Notifications Button** (right)
   - Size: 52×52px circular
   - Background: White 15% opacity
   - Icon: notifications, white, 26px
   - Action: TODO (not yet implemented)

## Home Screen Updates

### Integration of Global Components
- Replaced local `_buildTopHeader()` with `GlobalTopHeader(currentScreen: 'home')`
- Replaced local `_buildBottomNavigationBar()` with `GlobalBottomNavBar(currentScreen: 'home')`

### Navigation Changes
- Added Statistics button to top header
- Replaced Stats icon with Opponents icon in bottom nav
- Home icon highlights when on home screen

## Statistics Screen Updates

### Integration of Global Components
- Replaced local `_buildTopHeader()` with `GlobalTopHeader(currentScreen: 'statistics')`
- Replaced local `_buildBottomNavigationBar()` with `GlobalBottomNavBar(currentScreen: 'statistics')`

### Navigation Changes
- Statistics button in top header highlights when on statistics screen
- Opponents icon in bottom nav navigates to MyOpponentsScreen
- Added import for MyOpponentsScreen

## Files Created

### `lib/widgets/global_bottom_nav_bar.dart`
Global bottom navigation bar component with active state highlighting.

**Key Features**:
- Consistent navigation across all screens
- Active screen highlighting
- Proper navigation routing
- Clean, reusable component

### `lib/widgets/global_top_header.dart`
Global top header component with profile, statistics, and notifications.

**Key Features**:
- Consistent header across screens
- Statistics button with active state
- Profile and notification access
- Reusable component

## Files Modified

### `lib/screens/statistics_screen.dart`
- Complete redesign of stat cards layout
- New card styling and typography
- Integrated GlobalTopHeader and GlobalBottomNavBar
- Made entire screen scrollable
- Added Statistics header section
- Updated Positional and Session Statistics cards

### `lib/screens/home_screen_experimental.dart`
- Integrated GlobalTopHeader and GlobalBottomNavBar
- Added Statistics button to top header
- Replaced Stats icon with Opponents icon in bottom nav

## Technical Details

### Color Palette
- **Card Background**: `#1d2a27` (glassy dark green)
- **Nav Bar**: `#2D2D2D`
- **Lime Green Accent**: `#A5EC44`
- **Icon Container**: White 10% opacity
- **Header Background**: White 15% opacity
- **Active Statistics**: Lime green 20% opacity

### Typography (Inter Font)
- **Card Labels**: 16px, weight 500, white 84% opacity
- **Card Values**: 20px, weight 500, white 100%
- **Statistics Title**: 28px, weight 600, -0.56px letter spacing
- **Statistics Subtitle**: 16px, weight 400, white 80% opacity

### Border Radius
- **Cards**: 12px
- **Nav Bar**: 35px
- **Icon Containers**: Circular (50%)

### Spacing
- **Card Padding**: 18px vertical, 16px horizontal
- **Grid Spacing**: 8px horizontal and vertical
- **Icon Spacing**: 12px between top header icons
- **Section Gaps**: 16-28px between major sections

## Navigation Flow

### Bottom Navigation (5 items)
1. Home → HomeScreenExperimental
2. Opponents → MyOpponentsScreen
3. + (center) → LoggingModeSelectionScreen
4. Sessions → SessionHistoryScreen
5. Profile → ProfileScreen

### Top Header (3 items)
1. Profile → ProfileScreen
2. Statistics → StatisticsScreen
3. Notifications → Not implemented yet

## Design Consistency

### Achieved
- ✅ All stat cards use same layout structure
- ✅ Consistent card styling across overview, positional, and session stats
- ✅ Global navigation components ensure UI consistency
- ✅ Active state highlighting provides clear user feedback
- ✅ Same typography throughout statistics screen
- ✅ Consistent spacing and padding

### Benefits
- **User Experience**: Clear active state, consistent navigation
- **Maintainability**: Single source of truth for navigation components
- **Scalability**: Easy to add new screens with same navigation
- **Visual Harmony**: Unified design language across app

## Before vs After

### Before
- Old card design with different layout
- Inconsistent navigation across screens
- No active state highlighting
- Fixed header (didn't scroll)
- Different card styling

### After
- Modern card design with icon-label-value layout
- Global navigation components
- Active state highlighting in both nav bars
- Fully scrollable screen
- Consistent card styling (#1d2a27, 12px radius)

## Next Steps
- Apply global navigation to other screens (Profile, Sessions, Opponents)
- Implement notifications functionality
- Continue experimental design to remaining screens
- Gather user feedback on new navigation and card layouts

## Notes
- Global navigation components are reusable across all screens
- Statistics button in top header provides quick access from any screen
- Opponents screen now accessible from bottom nav (replaced Stats)
- All navigation properly tracks active state
- Design maintains experimental branch separation for easy comparison
