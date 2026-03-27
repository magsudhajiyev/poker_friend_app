# Opponents Screen Redesign and Bottom Sheet Modal

**Date**: January 18, 2026
**Branch**: `design-experimentation`
**Commit**: 5f825ae

## Summary

Completed comprehensive redesign of the Opponents screen with glassy translucent cards, gradient background, global navigation integration, and a custom bouncy bottom sheet modal for editing opponents.

## Opponents Screen Updates

### 1. Gradient Background Integration
- Added same elliptical gradient as home and statistics screens
- Background: Linear gradient from `rgba(171, 255, 180, 0.6)` → `rgba(0, 100, 52, 0.6)` → `rgba(0, 0, 0, 0.6)`
- Border radius: `297.5px/363.5px` (elliptical)
- Blur: 132px
- Positioned: -98px left, -148px top
- Stays fixed during scroll

### 2. Global Navigation Integration
**Top Header:**
- Integrated `GlobalTopHeader(currentScreen: 'opponents')`
- Statistics button highlights when on opponents screen
- Profile and notification buttons accessible
- Fixed position (doesn't scroll)

**Bottom Navigation:**
- Integrated `GlobalBottomNavBar(currentScreen: 'opponents')`
- Opponents icon highlights in lime green (#A5EC44)
- Provides consistent navigation across app

### 3. Header Section Redesign
**Layout:**
- Row with title/subtitle on left, + button on right
- 16px horizontal padding
- Fixed position (doesn't scroll)

**Typography:**
- Title: "Opponents"
  - Font: Inter SemiBold, 28px, weight 600
  - Color: White
  - Letter spacing: -0.56px
  - Line height: 28px (1.0)
- Subtitle: "X tracked players"
  - Font: Inter Regular, 16px, weight 400
  - Color: White 80% opacity
  - Letter spacing: -0.32px
  - Line height: 16px (1.0)
- Gap between: 7px

**Add Button:**
- Size: 44×44px circular
- Background: White 15% opacity
- Icon: Plus (+), white, 24px
- Action: Opens add opponent bottom sheet
- Replaced floating action button

### 4. Search Bar Redesign
**Glassy Style:**
- Background: `#546165` at 74% opacity
- Backdrop blur: 45px
- Border radius: 12px
- Height: 50px
- Horizontal padding: 16px

**Typography:**
- Input text: Inter, 16px, white
- Placeholder: Inter, 16px, white 50% opacity
- Search icon: 20px, white 70% opacity

**Position:**
- Fixed (doesn't scroll)
- 24px bottom margin

### 5. Opponent Cards Redesign
**Container:**
- Glassy translucent design
- Background: `#546165` at 74% opacity
- Backdrop blur: 45px (sigmaX, sigmaY)
- Border radius: 12px
- Padding: 18px vertical, 16px horizontal
- Margin: 16px bottom

**Layout Structure:**
```
┌─────────────────────────────────────┐
│  [Avatar]  Name          Hands: 0   │
│            Game Style    Hands       │
│                                      │
│  👁 Last Seen: Jan 18  [Edit] [Del] │
└─────────────────────────────────────┘
```

**Top Section:**
- Left side:
  - Color indicator avatar: 44×44px circular
  - Background: Color at 20% opacity
  - Inner dot: 18×18px, full color
  - Border radius: 55px
  - 8px gap to name
  - Name: Inter Medium, 18px, weight 500, white 84%, line height 1.4
  - Game style: Inter Regular, 12px, weight 400, colored 84%, line height 1.4
- Right side:
  - Hands number: Inter Medium, 18px, weight 500, white 100%, line height 1.4
  - "Hands" label: Inter Medium, 14px, weight 500, white 100%, line height 1.4
  - Column aligned right

**Bottom Section (24px gap from top):**
- Left side:
  - Eye icon: 18px, white 84%
  - Last seen text: Inter Regular, 12px, weight 400, white 84%, line height 1.3
  - 4px gap between icon and text
- Right side:
  - Edit button:
    - Size: 38×38px circular
    - Background: White 15% opacity
    - Icon: Edit, 18px, white
    - Shadow: Black 20% opacity, 28.5px blur
  - Delete button:
    - Size: 38×38px circular
    - Background: `#B63131` (red)
    - Icon: Delete, 18px, white
    - Shadow: Black 20% opacity, 28.5px blur
  - 8px gap between buttons

**Removed Elements:**
- Notes section (no longer displayed on cards)

### 6. Scroll Behavior
**Fixed Elements (Don't Scroll):**
- Background gradient
- Top header (profile, statistics, notifications)
- "Opponents" title and count
- Search bar
- Bottom navigation bar

**Scrollable Element:**
- Opponent cards list only
- Uses `Expanded` widget with ListView
- 20px bottom padding
- Smooth scrolling

## Bottom Sheet Modal Redesign

### 1. Animation and Behavior
**Slide-Up Animation:**
- Duration: 600ms
- Curve: `Curves.elasticOut` (bouncy effect)
- Slides up from bottom edge
- Overshoots slightly and bounces back
- Smooth, playful animation

**Interaction:**
- `isScrollControlled: true` - full height control
- `isDismissible: true` - tap outside to close
- `enableDrag: true` - swipe down to close
- Keyboard adjusts layout when opened
- No auto-focus (keyboard only shows on tap)

### 2. Container Design
**Background:**
- Color: `#1a2925` (dark green)
- Border radius: 24px (top corners only)
- Modal background: Transparent

**Structure:**
- SingleChildScrollView for keyboard handling
- Padding bottom adjusts for keyboard
- Centered content with 24px horizontal padding

### 3. Drag Handle
- Size: 80px × 2px
- Color: White 50% opacity
- Border radius: 1px
- Centered horizontally
- 14px top margin

### 4. Title Section
- Text: "Edit Opponent" or "Add Opponent"
- Font: Inter SemiBold, 18px, weight 600
- Color: White
- Letter spacing: 0
- Line height: 1.2 (21.6px)
- Left aligned
- 38px margin from drag handle
- 24px margin to inputs

### 5. Input Fields
**Opponent Name Field:**
- Height: 56px
- Background: Black 30% opacity
- Border: White 20% opacity, 1px
- Border radius: 12px
- Padding: 16px horizontal, 16px vertical
- Input text: Inter, 16px, white
- Placeholder: "Opponent Name", Inter, white 50% opacity
- No auto-focus (keyboard shows on tap only)

**Notes Field:**
- Height: 150px
- Background: Black 30% opacity
- Border: White 20% opacity, 1px
- Border radius: 12px
- Padding: 16px all around
- Max lines: 6
- Input text: Inter, 16px, white
- Placeholder: "Notes (Optional)", Inter, white 50% opacity

**Gap:** 18px between fields

### 6. Color Picker Section
**Label:**
- Text: "Pick a color:"
- Font: Inter Bold, 14px, weight 700
- Color: White
- Letter spacing: -0.28px
- 16px gap to color circles

**Color Circles:**
- Size: 48×48px (was 32×32px)
- Shape: Circle
- Colors: All 8 opponent colors
- Layout: Wrap with 12px spacing (horizontal and vertical)
- Selected state:
  - Border: White, 3px width
  - No border when not selected
- 24px gap from input fields

### 7. Action Buttons
**Update Button:**
- Background: `#A5EC44` (lime green)
- Width: Full width (with 24px padding)
- Height: 50px
- Border radius: 12px
- Text: "Update"
  - Font: Inter Medium, 16px, weight 500
  - Color: Black
- Elevation: 0
- 56px top margin from color picker

**Cancel Button:**
- Background: White
- Width: Full width (with 24px padding)
- Height: 50px
- Border radius: 12px
- Text: "Cancel"
  - Font: Inter Medium, 16px, weight 500
  - Color: Black
- Elevation: 0
- 16px gap from Update button
- 24px bottom padding

### 8. Functionality Preserved
- ✅ Pre-fills fields when editing existing opponent
- ✅ Empty fields when adding new opponent
- ✅ Color selection with visual feedback (white border)
- ✅ Name validation (required field)
- ✅ Save opponent (create or update)
- ✅ Close modal on cancel tap
- ✅ Close modal on successful save
- ✅ Reload opponents list after save
- ✅ Success snackbar (lime green background)
- ✅ Error snackbar (red background)
- ✅ Keyboard handling (adjusts layout)
- ✅ Tap outside to dismiss
- ✅ Swipe down to dismiss

## Files Modified

### `lib/screens/my_opponents_screen.dart`
**Major Changes:**
- Complete layout restructure from SingleChildScrollView to fixed + scrollable sections
- Integrated global navigation components
- Redesigned opponent cards with glassy effect
- Redesigned search bar with glassy effect
- Replaced `showDialog` with `showModalBottomSheet`
- Complete rewrite of opponent dialog (lines 657-966)

**Line Changes:**
- +613 lines added
- -388 lines removed
- Net: +225 lines

## Technical Details

### Color Palette
- **Card Background**: `#546165` at 74% opacity (glassy)
- **Modal Background**: `#1a2925` (dark green)
- **Input Background**: Black 30% opacity
- **Input Border**: White 20% opacity
- **Lime Green Button**: `#A5EC44`
- **Delete Button**: `#B63131` (red)
- **Icon Containers**: White 15% opacity
- **Drag Handle**: White 50% opacity

### Typography (Inter Font)
**Opponents Header:**
- Title: 28px, weight 600, -0.56px spacing
- Subtitle: 16px, weight 400, -0.32px spacing

**Cards:**
- Name: 18px, weight 500, white 84%
- Style: 12px, weight 400, colored 84%
- Hands: 18px/14px, weight 500, white 100%
- Last seen: 12px, weight 400, white 84%

**Modal:**
- Title: 18px, weight 600
- Inputs: 16px, white
- Placeholders: 16px, white 50%
- Color label: 14px, weight 700, -0.28px spacing
- Buttons: 16px, weight 500, black

### Border Radius
- **Cards**: 12px
- **Search bar**: 12px
- **Modal**: 24px (top corners only)
- **Input fields**: 12px
- **Buttons**: 12px
- **Color circles**: 50% (circular)
- **Edit/delete buttons**: 50% (circular)

### Spacing
- **Card padding**: 18px vertical, 16px horizontal
- **Card sections gap**: 24px
- **Horizontal padding**: 16px (screen edges)
- **Input fields gap**: 18px
- **Color circles**: 12px spacing
- **Buttons gap**: 16px
- **Modal sections**: 24px, 38px, 56px

### Shadows
- Edit/delete buttons: Black 20% opacity, 28.5px blur

### Animation
- Duration: 600ms
- Curve: Curves.elasticOut
- Effect: Bouncy slide-up from bottom

## Design Consistency

### Achieved
- ✅ Global navigation with active state tracking
- ✅ Gradient background consistent with other screens
- ✅ Glassy cards matching design system
- ✅ Proper scroll behavior (fixed header, scrollable content)
- ✅ Typography using Inter font throughout
- ✅ Consistent spacing and padding
- ✅ Lime green accent for primary actions
- ✅ Smooth animations with bounce effect

### Benefits
- **Visual Harmony**: Glassy translucent cards create modern aesthetic
- **User Experience**: Bouncy animation delights users, clear visual feedback
- **Consistency**: Global navigation ensures uniform experience
- **Accessibility**: Larger touch targets (44px, 48px, 50px)
- **Flexibility**: Bottom sheet allows keyboard interaction without blocking content
- **Performance**: Efficient scroll with fixed headers

## Before vs After

### Before
- Old solid card design (#1F1F23 background)
- Floating action button for adding
- AlertDialog for editing
- Notes displayed on cards
- Smaller color circles (32px)
- Fixed height content container
- Scroll-back issue
- Auto-focus keyboard opening

### After
- Glassy translucent cards (#546165 at 74% opacity + blur)
- + button in header (cleaner UI)
- Bottom sheet with bouncy animation
- Notes removed from card display
- Larger color circles (48px) with better touch targets
- Proper scroll behavior (Expanded + ListView)
- Smooth scrolling without issues
- Keyboard only shows on tap

## Next Steps
- Apply global navigation to remaining screens (Sessions, Profile)
- Implement opponent detail screen redesign
- Add animations to opponent list (fade in, etc.)
- Consider adding pull-to-refresh for opponent list
- Gather user feedback on bottom sheet UX

## Notes
- Bottom sheet provides better UX than dialog for mobile
- Bouncy animation adds personality to the app
- Glassy cards create cohesive visual language
- Fixed scroll behavior improves usability significantly
- No auto-focus prevents jarring keyboard pop-up
- All functionality preserved from original implementation
