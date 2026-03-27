# Experimental Design System Implementation

**Date**: January 18, 2026
**Branch**: `design-experimentation`
**Commit**: fc207bb

## Summary

Implemented a comprehensive experimental design system for the poker logger app with new visual aesthetics including intro screen, authentication screens, and redesigned home screen with custom icons and modern UI components.

## Changes Made

### 1. Intro Screen (`lib/screens/intro_screen.dart`)
- Created welcome screen with full-screen background image (`assets/main_background.png`)
- Added "READ THE GAME LIKE A PRO" headline with Inter font (40px, 800 weight)
- Implemented "P" logo placeholder in top-left corner
- Added two action buttons:
  - "Create account" (white filled button)
  - "Log in" (transparent with border)
- Background color: Dark forest green (#1A3A2E)

### 2. Auth Screen Experimental (`lib/screens/auth_screen_experimental.dart`)
- Created new authentication screen with toggle between sign up and login modes
- Dark forest green background (#1A3A2E)
- Features:
  - Back arrow navigation to intro screen
  - Dynamic title based on mode (Sign up / Log in to your account)
  - Form inputs with lime green focus border (#A5EC44)
  - White rounded buttons (100px border radius)
  - Terms of Service text (no checkbox)
- Accepts `initialIsSignUp` parameter to control initial mode

### 3. Home Screen Experimental (`lib/screens/home_screen_experimental.dart`)
- Redesigned entire home screen with black background and green gradient overlay
- **Gradient Implementation**:
  - Position: left -98px, top -148px
  - Size: 595×727px
  - Colors: #ABFFB4 (60% opacity) → #006434 → #000000
  - Stops: 0%, 32%, 100%
  - Added 132px blur filter for softer appearance
  - Circular shape

- **Custom Icons**:
  - Sessions: `assets/session.png`
  - Win Rate: `assets/trophy.png`
  - Hours: `assets/clock.png`
  - Play Style: Dynamic based on detected style (TAG, LAG, Nit, Maniac, etc.)
  - Recent sessions also use session icon
  - Icons are 40×40px with no background circles

- **Upcoming Events Redesign**:
  - Card background changed from #1D2A27 to #181818
  - Horizontal card layout with:
    - Event name and buy-in on top row
    - Date and time pills on bottom row (#3D3D3D background, 12px radius)
  - "View all" button matches Recent section style (semi-transparent white container)

- **Bottom Navigation Bar**:
  - Floating design with 20px margin all around
  - Dark gray background (#2D2D2D) with 35px border radius
  - Height: 70px
  - 5 items:
    1. Home icon
    2. Stats/Chart icon
    3. Center green + button (56×56px, #A5EC44)
    4. Cards/Game icon
    5. Profile icon
  - Navigation to respective screens

### 4. Navigation Fixes
- Updated `lib/main.dart` with named routes (`initialRoute: '/'`)
- Modified `lib/screens/auth_wrapper.dart` to show `IntroScreen` when not authenticated
- Fixed logout in `lib/screens/profile_screen.dart` to use `pushNamedAndRemoveUntil('/', (route) => false)`

## Technical Details

### Color Palette
- **Primary Dark**: #000000 (black background)
- **Forest Green**: #1A3A2E (intro/auth screens)
- **Card Background**: #1C2926 (Recent section)
- **Events Background**: #181818
- **Lime Green Accent**: #A5EC44
- **Nav Bar**: #2D2D2D
- **Pills/Labels**: #3D3D3D

### Typography
- **Font Family**: Inter
- **Weights**: 400 (regular), 500 (medium), 600 (semi-bold), 700 (bold), 800 (extra-bold)

### Border Radius
- **Buttons**: 100px (fully rounded)
- **Cards**: 12px
- **Pills**: 12px
- **Navigation Bar**: 35px

## Files Modified
- `lib/main.dart` - Added named routes
- `lib/screens/auth_screen.dart` - Updated to use HomeScreenExperimental
- `lib/screens/auth_wrapper.dart` - Show IntroScreen when not authenticated
- `lib/screens/profile_screen.dart` - Fixed logout navigation

## Files Created
- `assets/main_background.png` - Background image for intro screen
- `lib/screens/intro_screen.dart` - Welcome screen
- `lib/screens/auth_screen_experimental.dart` - New auth screens
- `lib/screens/home_screen_experimental.dart` - Redesigned home screen

## Bug Fixes
- Fixed null check operator error in `_getPlayStyleName()` by replacing `result['style']!` with `result['style'] ?? 'Balanced'`

## Design Consistency
- All "View all" buttons use same style (semi-transparent white container)
- All pills/labels use consistent 12px border radius
- Icons are consistent size (40×40px) across all sections
- Inter font family used throughout

## Next Steps
- Move on to Statistics screen redesign
- Apply experimental design to remaining screens
- Test navigation flows thoroughly
- Gather user feedback on new design

## Notes
- Branch `design-experimentation` created for testing new designs
- Original screens remain intact for comparison
- Can easily switch between old and new designs by changing screen references
