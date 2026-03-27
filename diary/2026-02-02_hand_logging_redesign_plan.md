# Hand Logging Screen Redesign Plan

**Date:** 2026-02-02
**Branch:** `feature/hand-logging-redesign`
**Target File:** `lib/screens/poker_hand_screen.dart`

---

## Current State Analysis

The `poker_hand_screen.dart` is a large file (~55k tokens) with the following UI elements:

### Current Design Patterns (Old Style)
- Background: `Color(0xFF161618)` (dark gray)
- Header: Manual `Container` with `Color(0xFF1F1F23)`
- Buttons: Manual `Container` with `BorderRadius.circular(12)`
- Dialogs: `AlertDialog` with `backgroundColor: PokerFriendColors.dark3`
- Colors: Mix of hardcoded colors and `PokerFriendColors`

### Key UI Sections to Update
1. **Main Scaffold Background** (line 822-823)
2. **Header Bar** (lines 828-1010)
3. **Dialogs** (multiple throughout file):
   - Stop Session dialog
   - Bet amount dialog
   - Blinds adjustment dialog
   - Rebuy dialog
   - Session details dialog
4. **Action Buttons** (throughout)
5. **Menu/Popup** styling

---

## New Design System Components to Use

| Component | Usage |
|-----------|-------|
| `GradientBackground` | Main screen background |
| `GlassyIconButton` | Header action buttons (back, skip, complete, menu) |
| `GlassyCard` | Dialog containers, info cards |
| `SemiTransparentCard` | Larger selection areas |
| `PillLabel` | Status badges, labels |
| `AppColors` | Consistent color palette |
| `AppTypography` | Text styles |
| `AppSpacing` | Consistent spacing |

---

## Implementation Plan

### Phase 1: Core Structure (High Impact)

#### 1.1 Add Design System Import
```dart
import '../design_system/design_system.dart';
```

#### 1.2 Update Scaffold Background
```dart
// Before:
Scaffold(
  backgroundColor: Color(0xFF161618),
  body: SafeArea(...)
)

// After:
Scaffold(
  backgroundColor: Colors.black,
  body: Stack(
    children: [
      GradientBackground(),
      SafeArea(...)
    ],
  ),
)
```

#### 1.3 Update Header Bar
Replace manual Container header with glassmorphic style:
```dart
// New header pattern
Container(
  padding: EdgeInsets.fromLTRB(16, 16, 16, 20),
  child: Row(
    children: [
      GlassyIconButton(
        icon: Icons.arrow_back,
        onPressed: () => Navigator.pop(context),
      ),
      Expanded(
        child: Column(
          children: [
            Text('Hand #${gameState.handNumber}',
              style: AppTypography.pageTitle()),
            Text('${gameState.currentRound.name.toUpperCase()} • ${gameState.getActivePlayers().length} players',
              style: AppTypography.pageSubtitle()),
          ],
        ),
      ),
      // Action buttons as GlassyIconButtons
      GlassyIconButton(
        icon: Icons.skip_next,
        onPressed: _skipCurrentAction,
      ),
      SizedBox(width: 8),
      GlassyIconButton(
        icon: Icons.check,
        backgroundColor: AppColors.accentGreen.withOpacity(0.3),
        onPressed: completeHand,
      ),
      // ... more buttons
    ],
  ),
)
```

### Phase 2: Dialogs (Medium Impact)

#### 2.1 Update Dialog Base Pattern
Create reusable glassmorphic dialog wrapper:
```dart
Dialog(
  backgroundColor: Colors.transparent,
  child: GlassyCard(
    padding: EdgeInsets.all(24),
    child: Column(...),
  ),
)
```

#### 2.2 Dialogs to Update:
- `_showBetAmountDialog()` (~line 1838)
- `_stopSession()` confirmation dialog (~line 478)
- `_showBlindsDialog()` (~line 5427)
- `_showRebuyDialog()` (~line 3432)
- `BustedPlayerDialog` (~line 5080)

### Phase 3: Action Buttons & Controls (Medium Impact)

#### 3.1 Update ElevatedButton Styles
Replace hardcoded colors with design system:
```dart
// Before:
ElevatedButton.styleFrom(
  backgroundColor: Colors.red,
)

// After:
ElevatedButton.styleFrom(
  backgroundColor: AppColors.accentRed,
)
```

#### 3.2 Update Icon Buttons in Various Sections
- Blind adjustment buttons
- Player seat controls
- Action grid buttons (may be in separate widget)

### Phase 4: Color Consistency (Low Impact)

Replace all hardcoded colors:
- `Color(0xFF161618)` → `Colors.black` or `AppColors.backgroundDark`
- `Color(0xFF1F1F23)` → `AppColors.cardBackground` or glassmorphic
- `Color(0xFF5AC95A)` → `AppColors.accentGreen`
- `Colors.red` → `AppColors.accentRed`

---

## Files That May Need Updates

1. **Main target:** `lib/screens/poker_hand_screen.dart`
2. **Related widgets:**
   - `lib/widgets/action_button_grid.dart`
   - `lib/widgets/board_cards_dialog.dart`
   - `lib/widgets/hole_cards_dialog.dart`
   - `lib/widgets/showdown_dialog.dart`
   - `lib/widgets/winner_selection_dialog.dart`

---

## Estimated Changes

| Section | Lines Affected | Complexity |
|---------|----------------|------------|
| Scaffold + Background | ~5 lines | Low |
| Header Bar | ~100 lines | Medium |
| Dialogs (5+) | ~300 lines | Medium |
| Action Buttons | ~50 lines | Low |
| Color replacements | ~30 lines | Low |

**Total Estimated:** ~500 lines of changes across main file

---

## Testing Checklist

- [ ] App launches without errors
- [ ] Gradient background displays correctly
- [ ] Header buttons work (back, skip, complete, menu)
- [ ] All dialogs open and function
- [ ] Betting flow works
- [ ] Hand completion works
- [ ] Visual consistency with other updated screens

---

## Notes

- The file is very large, so changes should be incremental
- Test after each major section
- Some dialogs may be reused across screens - consider extracting to design system
- The action_button_grid.dart may need separate updates
