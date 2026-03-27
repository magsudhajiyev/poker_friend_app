# Session Setup Screen Redesign - Figma Specification Implementation

**Date:** January 25, 2026
**Branch:** design-experimentation
**Commit:** aa1d8df

## Overview

Complete redesign of the Session Setup screen (`individual_session_setup_screen.dart`) to match Figma design specifications. This involved comprehensive UI overhaul with precise attention to typography, spacing, colors, and component styling.

## Key Changes

### 1. Design System Integration

**What Changed:**
- Added `GradientBackground` component wrapper
- Replaced custom header with `MainScreenHeader` component
- Removed all PNG icon dependencies throughout the screen

**Why:**
- Ensures consistency across app screens
- Reduces maintenance overhead by using shared components
- Eliminates asset dependencies for cleaner codebase

**Implementation Details:**
```dart
body: Stack(
  children: [
    GradientBackground(),
    SafeArea(
      child: Column(
        children: [
          MainScreenHeader(
            title: 'Session Setup',
            subtitle: widget.loggingMode == LoggingMode.full
                ? 'Full session tracking'
                : 'Individual session tracking',
            rightIcon: Icons.close_rounded,
            onRightPressed: () => Navigator.pop(context),
            showLeftIcon: false,
            padding: const EdgeInsets.all(16),
          ),
          // ... rest of content
        ],
      ),
    ),
  ],
)
```

### 2. Session Name Section

**What Changed:**
- Updated to Inter font family with precise typography specs
- Applied 24px vertical padding (removed excessive 32px gap with divider)
- Implemented rounded input border (58px radius) with glassmorphic styling
- Updated color scheme to match Figma precisely

**Typography:**
- Title: 18px, weight 700, color #f7fff7, letter-spacing 0, height 1.0
- Input: 14px, weight 400, color white, height 1.2
- Placeholder: 14px, weight 400, color #ebffef99

**Colors:**
- Background: #ffffff0a
- Border: #13321b
- Title: #f7fff7
- Placeholder: #ebffef99

### 3. Game Type Selection

**What Changed:**
- Updated button colors based on selection state
- Applied precise letter spacing (-1.0px)
- Added equal height to both pills by adding invisible line to Cash Game
- Increased spacing to 32px around dividers

**Color Specifications:**
- Selected state: #6de17f4c
- Unselected state: #2b3e2e4c
- Cash Game title: #cde63b
- MTT title: #76c527
- Subtitle text: #e4ffe3

**Technical Solution for Equal Heights:**
```dart
Text(
  isCash ? 'Cash Game\n ' : 'MTT\n(Tournament)',
  // Added invisible line to Cash Game to match MTT's two-line layout
)
```

### 4. Buy-in Amount & Starting Stack Sections

**What Changed:**
- Added 1px solid dividers (#214028) between sections
- Applied 32px vertical padding to both sections for consistency
- Reduced gap between input field and info box from wide gap to 24px
- Updated info text styling

**Spacing Pattern:**
```
[Section Name Input]  (24px padding top)
[Input Field]
(24px gap)
[Info Box]           (24px padding bottom)
```

**Info Text Styling:**
- Color: #c2c8c2
- Font size: 12px
- Line height: 1.5
- Font weight: 400

### 5. Blind Cards

**What Changed:**
- Updated border radius to 8px
- Added glassmorphic increment/decrement buttons
- Applied RobotoMono font for numeric values
- Implemented precise box shadows for glass effect

**Button Styling:**
- Background: #00ff6614
- Border radius: 20px (fully rounded)
- Border: 0.5px solid white
- Icon size: 18px
- 10px gap between buttons

**Box Shadows (Glassmorphic Effect):**
```dart
boxShadow: [
  BoxShadow(color: Colors.white.withOpacity(0.4), offset: Offset(0, 1)),
  BoxShadow(color: Colors.white.withOpacity(0.32), offset: Offset(1, 0)),
  BoxShadow(color: Colors.black.withOpacity(0.13), offset: Offset(0, -1), blurRadius: 1),
  BoxShadow(color: Colors.black.withOpacity(0.11), offset: Offset(-1, 0), blurRadius: 1),
]
```

### 6. BB Ante Toggle (Tournament Mode Only)

**What Changed:**
- Replaced Flutter Switch with custom toggle matching Figma
- Changed from rounded card background to top/bottom borders
- Implemented glassmorphic toggle with smooth animation
- Applied 32px vertical padding

**Custom Toggle Specifications:**
- Container width: 48px
- Background: #ffffff0a
- Border: 1px solid #13321b
- Border radius: 58px (fully rounded)
- Padding: 4px
- Indicator: 18x18px circle, color #baff9a
- Animation: AnimatedAlign with 200ms duration

**Layout:**
```
─────────────────────────── (top border #214028)
        (32px padding)
BB Ante              [Toggle]
        (32px padding)
─────────────────────────── (bottom border #214028)
```

### 7. Start Session Button

**What Changed:**
- Changed from space-between to centered layout
- Added 12px gap between text and icon
- Updated font weight to w700 (Bold)
- Adjusted line height to 27px
- Removed letter spacing (0 instead of 1.0)
- Increased vertical padding from 14px to 16px

**Before:**
```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [Text('Start Session'), Icon(arrow)],
)
```

**After:**
```dart
Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Text('Start Session'),
    SizedBox(width: 12),
    Icon(arrow),
  ],
)
```

## Typography System

### Font Families
- **Inter**: Used for all UI text (titles, labels, buttons)
- **RobotoMono**: Used specifically for numeric values in blind cards

### Common Text Styles

**Section Titles:**
```dart
TextStyle(
  fontFamily: 'Inter',
  fontSize: 18,
  color: Color(0xFFF7FFF7),
  fontWeight: FontWeight.w700,
  letterSpacing: 0,
  height: 1.0,
)
```

**Input Fields:**
```dart
TextStyle(
  fontFamily: 'Inter',
  fontSize: 14,
  color: Colors.white,
  fontWeight: FontWeight.w400,
  letterSpacing: 0,
  height: 1.2,
)
```

**Game Type / Blind Cards:**
```dart
TextStyle(
  fontFamily: 'Inter',
  fontSize: 16,
  fontWeight: FontWeight.w700,
  letterSpacing: -1.0,
  height: 1.0,
)
```

## Color Palette

| Usage | Hex Code | Description |
|-------|----------|-------------|
| Section Title | #f7fff7 | Bright white for headings |
| Placeholder Text | #ebffef99 | Greenish white with opacity |
| Input Background | #ffffff0a | Subtle white overlay |
| Input Border | #13321b | Dark green border |
| Unselected Game Type | #2b3e2e4c | Dark green with opacity |
| Selected Game Type | #6de17f4c | Light green with opacity |
| Cash Game Title | #cde63b | Yellow-green |
| MTT Title | #76c527 | Bright green |
| Subtitle Text | #e4ffe3 | Light greenish white |
| Info Text | #c2c8c2 | Gray-green |
| Icons | #b9ff99 / #baff9a | Bright lime green |
| Divider Lines | #214027 / #214028 | Dark green |
| Blind Button BG | #00ff6614 | Green with low opacity |

## Spacing Standards

The redesign follows a consistent spacing pattern:

- **16px**: Gap between title and input within sections, gap between blind card buttons
- **24px**: Vertical padding for Session Name section, gap between input and info box
- **32px**: Spacing around dividers, vertical padding for Buy-in/Starting Stack/BB Ante sections
- **12px**: Gap between button text and icon

## Technical Patterns

### Padding Widget Usage
For vertical-only padding, used `Padding` widget instead of `Container`:
```dart
Padding(
  padding: EdgeInsets.symmetric(vertical: 32),
  child: Column(...),
)
```

### Conditional Rendering
Game type-specific UI elements use if statements:
```dart
if (gameType == GameType.tournament) ...[
  // Starting Stack section
],
```

### Input Field Consistency
All text inputs follow the same border pattern:
```dart
decoration: InputDecoration(
  filled: true,
  fillColor: Color(0x0AFFFFFF),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(58),
    borderSide: BorderSide(color: Color(0xFF13321B), width: 1),
  ),
  enabledBorder: OutlineInputBorder(...),
  focusedBorder: OutlineInputBorder(...),
  contentPadding: EdgeInsets.fromLTRB(20, 14, 14, 14),
)
```

## Challenges & Solutions

### Challenge 1: Game Type Pills Different Sizes
**Problem:** MTT button was taller than Cash Game due to two-line text layout.

**Solution:** Added invisible newline and space to Cash Game text to match MTT's height:
```dart
isCash ? 'Cash Game\n ' : 'MTT\n(Tournament)'
```

### Challenge 2: Custom Toggle Switch
**Problem:** Flutter's default Switch widget didn't match Figma design.

**Solution:** Built custom toggle using Container with AnimatedAlign for smooth animation:
```dart
AnimatedAlign(
  duration: Duration(milliseconds: 200),
  alignment: hasBBante ? Alignment.centerRight : Alignment.centerLeft,
  child: Container(
    width: 18,
    height: 18,
    decoration: BoxDecoration(
      color: Color(0xFFBAFF9A),
      borderRadius: BorderRadius.circular(9),
    ),
  ),
)
```

### Challenge 3: Glassmorphic Box Shadows
**Problem:** Needed to replicate Figma's inset box shadows for glassmorphic effects.

**Solution:** Applied 4 box shadows in specific order to simulate inset lighting:
- Top light: white 0.4 opacity at (0, 1)
- Right light: white 0.32 opacity at (1, 0)
- Bottom shadow: black 0.13 opacity at (0, -1)
- Left shadow: black 0.11 opacity at (-1, 0)

### Challenge 4: Excessive Spacing
**Problem:** Original implementation had too much spacing between sections.

**Solution:** Carefully removed extra `SizedBox` widgets and relied on section padding to control spacing. Removed 32px gap between Session Name and its divider, keeping only the 24px bottom padding from the section itself.

## File Changes

**Modified:**
- `lib/screens/individual_session_setup_screen.dart` (+629, -485 lines)

**Impact:**
- Complete visual transformation matching Figma
- Improved consistency with design system
- Better spacing and typography hierarchy
- Enhanced glassmorphic effects
- Cleaner code structure

## Testing Checklist

- [x] Session Name input displays correctly
- [x] Game Type selection shows correct colors for both states
- [x] Cash Game and MTT pills have equal height
- [x] Buy-in Amount section spacing is correct
- [x] Starting Stack section only shows for tournaments
- [x] Blind cards display with proper styling
- [x] BB Ante toggle animates smoothly (tournaments only)
- [x] Start Session button is centered with correct styling
- [x] All dividers appear with correct color and position
- [x] Spacing between sections matches Figma
- [x] No debug logging present in code
- [x] Form validation still works correctly

## Related Commits

This is part of ongoing design system implementation:
- 2026-01-18: Experimental design system implementation
- 2026-01-18: Statistics screen redesign and global navigation
- 2026-01-18: Opponents screen redesign and bottom sheet modal
- **2026-01-25: Session Setup screen redesign** (this entry)

## Next Steps

Potential future enhancements:
- Apply similar design patterns to other setup/configuration screens
- Consider extracting common input field styles to design system
- Document glassmorphic button pattern for reuse in other screens
- Apply consistent divider styling across all screens

## Notes

- No debug logging was present or added during redesign
- All changes are purely visual; business logic remains unchanged
- Custom toggle implementation avoids dependency on third-party packages
- RobotoMono font specifically chosen for numeric values in blind cards
- The invisible space in Cash Game text is intentional for equal pill heights
