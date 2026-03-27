# Dealer Screen UI Simplification

**Date:** 2026-03-16
**File:** `lib/screens/dealer/dealer_table_screen.dart`

## Problem

The dealer voice UI was overly complex with multiple states and buttons:
- Manual start/stop voice mode toggle
- Recalibrate button during normal operation
- Stop voice mode button
- Voice mode replaced manual action buttons (either/or)

This created friction for dealers who had to:
1. Manually start voice mode each session
2. Choose between voice OR manual input
3. Navigate through multiple UI states

## Solution

Simplified the UI with these principles:
1. **One-time calibration**: Once dealer calibrates, never ask again during session
2. **Pause button only**: No stop/recalibrate during normal operation
3. **Keep Soniox stream open**: Pause just stops processing, preserves speaker_id
4. **Action buttons always visible**: Voice and manual input coexist

## Changes Made

### New Voice Status Bar
```dart
Widget _buildVoiceStatusBar() {
  final isPaused = _voiceCubit?.isHoldActive ?? false;
  // Compact bar: icon + status + dealer info + pause toggle
}
```
- Green when listening, amber when paused
- Shows dealer name and table
- Shows partial transcript while speaking
- Single pause/resume toggle button

### Modified Action Buttons Section
- Voice status bar shown at top (when dealer locked)
- Calibration UI only shown as fallback (connection loss)
- Action buttons (FOLD, CHECK/CALL, BET/RAISE, ALL-IN) always visible
- Player-to-act indicator always visible

### Auto-Start Voice
Added to `_startNewHand()`:
```dart
if (!_isVoiceMode) {
  setState(() => _isVoiceMode = true);
  _startContinuousListening();
}
```

### Removed Obsolete Methods
- `_buildVoiceActionUI()` - no longer needed
- `_buildStartVoiceModeUI()` - auto-start removes manual trigger
- `_buildDealerLockedUI()` - replaced by `_buildVoiceStatusBar()`
- `_buildRotatingUI()` - unused
- `_recalibrateDealer()` - only needed for connection loss fallback
- `_getVoiceModeColor/BorderColor/Icon/Label()` - helpers for removed UI
- `_toggleVoiceMode()` - no manual toggle anymore

### Kept for Fallback
- `_buildCalibrationUI()` - shown if connection lost and reconnect fails
- `_buildConnectionLostUI()` - shown during reconnect attempts

## New UI Layout

```
┌─────────────────────────────────────────────────┐
│  🎤 Listening (Dealer Name • Table)    [⏸️]    │
├─────────────────────────────────────────────────┤
│        Player X to act ($5,000)                 │
├─────────────────────────────────────────────────┤
│  [FOLD] [CHECK/CALL] [BET/RAISE] [ALL IN]      │
└─────────────────────────────────────────────────┘
```

## Session Flow

```
Session Start
    ↓
Start First Hand → Auto-connect Soniox
    ↓
Calibration (if not already calibrated)
    ↓
Voice Status Bar + Action Buttons shown
    ↓
Dealer uses voice OR buttons (or both)
    ↓
Pause → stops processing (stream stays open)
    ↓
Resume → continues processing
    ↓
End Session → Close WebSocket

--- Connection Loss Fallback ---
Stream Lost → Show "Connection Lost"
    ↓
[If reconnect fails] → Show calibration UI
    ↓
Dealer recalibrates → Resume normal flow
```

## Testing Checklist

- [ ] Start dealer session - voice should auto-start on first hand
- [ ] Action buttons visible alongside voice status bar
- [ ] Tap pause - status shows "Paused", voice ignored
- [ ] Tap manual FOLD - action executes while paused
- [ ] Tap resume - status shows "Listening"
- [ ] Say "fold" - action executes
- [ ] End session - WebSocket closes properly
