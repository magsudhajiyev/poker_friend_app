# Development Diary - Poker Logger

## 2025-10-01: Stack Tracking & Total Invested Fixes

### Issues Identified
Today we resolved critical issues with stack tracking and total invested calculations in individual session mode:

1. **Manual Stack Updates Not Tracked**: The "Update" button in individual sessions wasn't adding entries to stack history, resulting in flat lines instead of wave charts
2. **Total Invested Showing Wrong Value**: Was displaying starting stack instead of actual buy-in amount
3. **Session Data Not Persisting**: When resuming sessions, totalBuyIn and other data wasn't being loaded from database
4. **UI Enhancement Needed**: Stack update dialog needed quick adjustment options (+/- buttons)

### 🔍 Investigation Process

#### Manual Stack Update Issue
**Symptoms**: User updates stack multiple times via "Update" button, but session analytics shows flat line instead of wave pattern.

**Root Cause**: The `_showUpdateStackDialog()` method was only updating `_currentStack` in memory but NOT adding entries to `_stackHistory` array.

**Debug Strategy**: Added comprehensive logging to track when stack updates occur and what data is saved.

#### Total Invested Issue
**Symptoms**: "Total Invested" field showing starting stack value (e.g., 10,000 chips) instead of buy-in amount (e.g., $50).

**Investigation Path**:
1. Checked initialization: `_totalBuyIn = widget.buyInAmount` ✓ Correct
2. Checked display: Shows `_totalBuyIn` ✓ Correct
3. Checked session creation: `totalBuyIn` NOT being saved to Firebase ✗ Found issue!
4. Checked session resumption: `_resumeSession()` had TODO instead of implementation ✗ Found issue!

### 🛠️ Solutions Implemented

#### 1. Manual Stack Update Tracking
**File**: `lib/screens/individual_session_tracking_screen.dart`

**Line 266-298**: Enhanced `_showUpdateStackDialog()`:
```dart
// Calculate and track stack changes
final previousStack = _currentStack;
final stackChange = newStack - previousStack;

// Add stack history entry for manual update
_stackHistory.add({
  'timestamp': DateTime.now().toIso8601String(),
  'stackSize': newStack,
  'changeType': stackChange >= 0 ? 'manual_increase' : 'manual_decrease',
  'changeAmount': stackChange.abs(),
});

// Update Firebase with stack history
FirebaseService.updateIndividualSession(
  sessionId: _sessionId!,
  currentStack: _currentStack,
  stackHistory: _stackHistory,
)
```

**Line 558**: Fixed `_stopSession()` to include stackHistory when ending session

#### 2. Session Data Persistence
**File**: `lib/screens/individual_session_tracking_screen.dart`

**Lines 144-180**: Implemented complete `_resumeSession()`:
```dart
// Load session data from Firebase or local storage
Map<String, dynamic>? sessionData;
try {
  sessionData = await FirebaseService.getSession(_sessionId!);
} catch (e) {
  sessionData = await LocalStorageService.getSession(_sessionId!);
}

if (sessionData != null) {
  // Restore all session data
  _totalBuyIn = sessionData['totalBuyIn']?.toDouble() ?? _totalBuyIn;
  _handsLogged = sessionData['handsLogged'] ?? 0;
  _biggestPot = sessionData['biggestPot']?.toDouble() ?? 0.0;

  // Load rebuys and stack history
  if (sessionData['rebuys'] != null) {
    _rebuys = List<Map<String, dynamic>>.from(sessionData['rebuys']);
  }
  if (sessionData['stackHistory'] != null) {
    _stackHistory = List<Map<String, dynamic>>.from(sessionData['stackHistory']);
  }
}
```

#### 3. Total Invested Firebase Storage
**File**: `lib/services/firebase_service.dart`

**Line 28**: Added `totalBuyIn` parameter to `createSession()` method

**Line 57**: Include totalBuyIn in session data:
```dart
if (isIndividualSession) {
  sessionData.addAll({
    'startingStack': startingStack ?? 0.0,
    'currentStack': startingStack ?? 0.0,
    'totalBuyIn': totalBuyIn ?? 0.0, // Now properly saved
    'handsLogged': 0,
    'biggestPot': 0.0,
    'sessionStatus': 'active',
  });
}
```

**File**: `lib/screens/individual_session_tracking_screen.dart`

**Line 130**: Pass totalBuyIn when creating session:
```dart
final sessionId = await FirebaseService.createSession(
  // ... other params
  totalBuyIn: widget.buyInAmount, // Include initial buy-in
);
```

#### 4. Enhanced Stack Update Dialog
**File**: `lib/screens/individual_session_tracking_screen.dart`

**Lines 249-457**: Complete redesign of `_showUpdateStackDialog()`:

**New Features**:
- Current stack display at top
- Method 1: Set new total (original functionality preserved)
- Method 2: Quick adjust with amount field and +/- buttons
- Green + button for adding to stack
- Red - button for subtracting from stack
- Validation to prevent negative stacks
- Proper formatting for cash vs tournament display

**UI Structure**:
```
┌─────────────────────────┐
│ Current Stack: $500.00  │
├─────────────────────────┤
│ Method 1: Set New Total │
│ [Input field]           │
├─────────────────────────┤
│ Method 2: Add/Subtract  │
│ [Amount] [+] [-]        │
└─────────────────────────┘
```

### 🎯 Key Technical Insights

1. **State vs Persistence Gap**: In-memory state updates don't automatically persist. Must explicitly save to database.

2. **Session Lifecycle**: Critical to handle both creation AND resumption paths for data consistency.

3. **User Experience**: Quick adjustment buttons (+/-) significantly improve usability during live play.

4. **Data Model Clarity**: Clear distinction between:
   - `buyInAmount`: Actual money invested
   - `startingStack`: Chips received (same for cash, different for tournaments)
   - `totalBuyIn`: Cumulative invested (buyIn + all rebuys)

### 📋 Files Changed Summary

```
lib/screens/individual_session_tracking_screen.dart
  - Enhanced stack update dialog with +/- buttons
  - Fixed manual stack updates to save to history
  - Implemented session data loading on resume
  - Added comprehensive debug logging

lib/services/firebase_service.dart
  - Added totalBuyIn parameter to createSession
  - Include totalBuyIn in individual session data

lib/screens/individual_session_setup_screen.dart
  - Added debug logging for value tracking
```

### 🧪 Testing Scenarios

**Test 1: Manual Stack Updates**
1. Start individual session
2. Use "Update" button multiple times
3. Add/subtract amounts using new +/- buttons
4. End session
5. Check session analytics
✅ Expected: Wave chart showing all stack changes

**Test 2: Total Invested (Tournament)**
1. Create tournament session (Buy-in: $50, Stack: 10,000)
2. Check "Total Invested" display
3. Add rebuy ($50 for 5,000 chips)
4. Check updated "Total Invested"
✅ Expected: Shows $100 (not chip values)

**Test 3: Session Persistence**
1. Create session with stack updates and rebuys
2. Close app completely
3. Resume session
4. Check all values restored correctly
✅ Expected: totalBuyIn, stackHistory, rebuys all preserved

### 🚀 Improvements Delivered

1. **Wave Charts Working**: Manual stack updates now create proper wave patterns in analytics
2. **Accurate Financial Tracking**: Total Invested shows actual money, not chip stacks
3. **Better UX**: Quick +/- buttons for rapid stack adjustments during play
4. **Data Integrity**: Complete session data persistence and restoration
5. **Debug Visibility**: Comprehensive logging for troubleshooting

### 🔒 Stability Notes

These fixes are foundational to the stack tracking system. The implementation is now stable and should not require further breaking changes. Key principles established:

- Always persist state changes to database
- Maintain clear separation between money values and chip counts
- Provide both direct entry and incremental adjustment options
- Ensure data survives app restarts

---

*Session completed successfully with all critical issues resolved and tested.*