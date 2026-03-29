# UI Redesign Batch 2 — March 29, 2026

## Changes Made

### 1. Individual Session Tracking Screen (`individual_session_tracking_screen.dart`)
- Reordered session stats: Starting Stack → Initial Buy-in → Rebuys → Total Invested → Blinds → Hands Logged
- Removed "Biggest Pot" stat row
- Replaced `PopupMenuButton` with custom overlay popup (GlobalKey + showDialog + Positioned)
- Added `useSafeArea: false` to fix popup appearing too far below the dots icon

### 2. Quick Stack Update Screen (`quick_stack_update_screen.dart`)
- Full redesign from legacy `PokerFriendTheme` to modern design system
- Compact player cards: open seats collapsed to slim rows, active players ~40% shorter
- Position label moved inline as a pill next to player name
- Slider labels removed, slider height reduced to 28px
- "D" letter replaces emoji for button indicator, mint accent instead of amber
- Select Player dialog: fixed input-within-input visual bug (removed double Container wrapping)
- Added "Add as new opponent" functionality — when searching for a name not in opponent list, shows mint "Add [name]" option that saves via `OpponentService.saveOpponent()`
- All dialogs restyled: `#131616` bg, borderRadius 18, ibmPlexSans, mint accents

### 3. Opponent Hands Screen (`opponent_hands_screen.dart`)
- Full redesign: teal gradient bg, `#131616` cards, ibmPlexSans throughout
- Hand cards restructured: hand number pill + session/date + position chips + pot amount
- "Opponent Won" badge changed from gold trophy to red "OPP WON" pill
- Position chips: inline label + tinted pill (mint for hero, white for opponent)
- Loading/error/empty states restyled to match design system

### 4. Gradient Position — All 7 Screens
- Moved teal radial gradient higher: `top: -screenWidth * 0.3` → `top: -screenWidth * 0.5`
- Standardized `quick_stack_update_screen` and `opponent_hands_screen` from hardcoded values to responsive pattern
- Affected: hand_actions, session_hands, statistics, session_analytics, individual_session_tracking, quick_stack_update, opponent_hands

### 5. Back Button Consistency — All Screens
- Standardized to: 44x44 circle, solid `#101115` bg, `Icons.arrow_back` at 22px white
- Fixed in: hand_actions, session_hands, statistics, session_analytics, earnings_chart, my_opponents, opponent_detail, opponent_hands
- Replaced SVG `back.svg` with Material `Icons.arrow_back` in opponents and opponent detail screens

## Key Patterns
- Custom overlay popup: use `useSafeArea: false` in `showDialog` when using `Positioned` with `localToGlobal` coordinates
- Move GlobalKey to the exact widget (Container) not the wrapping GestureDetector for accurate position measurement
- Responsive gradient: `top: -screenWidth * 0.5, right: -screenWidth * 0.2, size: screenWidth * 1.2`
