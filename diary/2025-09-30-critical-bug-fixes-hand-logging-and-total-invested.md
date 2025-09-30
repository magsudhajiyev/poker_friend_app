# Development Diary - Poker Logger

## 2025-09-30: Critical Bug Fixes - Hand Logging & Total Invested

### Issues Identified
Today we tackled two critical bugs that were affecting core functionality:

1. **Hand Logging Data Loss**: Only the last logged hand was visible in session analytics, despite multiple hands being logged during a session
2. **Total Invested Calculation**: The total invested amount was showing only the initial buy-in, ignoring rebuys

### 🔍 Investigation Process

#### Hand Logging Issue - Deep Dive
**Symptoms**: User reported logging 4-5 hands but only seeing 1 hand in session analytics after updating blinds mid-session.

**Initial Hypothesis**: SessionId changing during blind updates causing hands to be saved to different sessions.

**Debug Strategy**: Added comprehensive debug logging to track:
- SessionId consistency during blind updates
- Hand completion and saving processes
- Database storage operations

**Key Debug Output**:
```
🔧 DEBUG: Generated handId: BPY8RBQ4RLpFNJZM8wEe_hand_1_1759237472521 for sessionId: BPY8RBQ4RLpFNJZM8wEe, handNumber: 1
🔧 DEBUG: Generated handId: BPY8RBQ4RLpFNJZM8wEe_hand_1_1759237493146 for sessionId: BPY8RBQ4RLpFNJZM8wEe, handNumber: 1
```

**Root Cause Discovery**: Both hands had the same `handNumber: 1`, indicating that hand numbering was resetting and causing ID collisions.

#### Total Invested Issue - Analysis
**Symptoms**: Total invested showing only initial buy-in ($50) instead of initial + rebuys ($50 + $50 = $100).

**Investigation**: Found that `addRebuy()` method updated `totalBuyIn` in memory but never persisted it to the database.

### 🛠️ Root Causes & Solutions

#### 1. Hand Logging - Document ID Collision Bug

**Problem**: Two separate storage systems had identical ID collision issues:

**Local Storage (SQLite)**:
- HandId generation: `'${sessionId}_hand_${handNumber}'`
- When handNumber reset or repeated → later hands overwrote earlier ones
- **Fix**: Added timestamp suffix: `'${sessionId}_hand_${handNumber}_${DateTime.now().millisecondsSinceEpoch}'`

**Firebase (Firestore)**:
- Document ID generation: `handNumber.toString()` (just "1", "2", etc.)
- Multiple hands with same handNumber → document overwrites
- **Fix**: Added timestamp suffix: `'hand_${handNumber}_${DateTime.now().millisecondsSinceEpoch}'`

**Files Modified**:
- `lib/services/local_storage_service.dart`: Updated `saveHand()` method (line 218)
- `lib/services/firebase_service.dart`: Updated `saveHand()` method (line 200)

#### 2. Total Invested - Data Persistence Bug

**Problem**: Session updates weren't saving rebuy information to the database.

**Root Cause**: `addRebuy()` method updated in-memory `totalBuyIn` but didn't trigger database update.

**Solution Chain**:
1. Modified `addRebuy()` to call `_updateSessionProgress()` immediately after adding rebuy
2. Updated `_updateSessionProgress()` to pass `totalBuyIn` parameter to database update methods
3. Enhanced `LocalStorageService.updateSession()` to accept and store `totalBuyIn` parameter
4. Updated session analytics to prioritize `sessionData['totalBuyIn']` over manual calculation

**Files Modified**:
- `lib/models/hand_state_machine.dart`:
  - `addRebuy()` method (line 974): Added `_updateSessionProgress()` call
  - `_updateSessionProgress()` method (line 875): Added `totalBuyIn` parameter
- `lib/services/local_storage_service.dart`:
  - `updateSession()` method (line 493): Added `totalBuyIn` parameter handling
- `lib/screens/session_analytics_screen.dart`:
  - `_calculateSessionAnalytics()` method (line 74): Prioritize session `totalBuyIn`
  - Added `_formatTotalInvested()` method (line 133): Always show $ sign

### 🎯 Key Technical Insights

1. **Debugging Methodology**: Comprehensive debug logging was crucial - without it, we would have assumed sessionId inconsistency rather than discovering the document ID collision issue.

2. **Dual Storage Complexity**: The app uses both local SQLite and Firebase, requiring fixes in both systems for complete resolution.

3. **Unique ID Generation**: Using timestamps for unique IDs proved effective: `${baseId}_${DateTime.now().millisecondsSinceEpoch}`

4. **Data Flow Tracking**: The total invested bug revealed that in-memory updates don't automatically persist - explicit database update calls are required.

### 🧪 Testing & Validation

**Test Scenario**:
1. Start session, log 3-4 hands
2. Update blinds mid-session (trigger for handNumber reset)
3. Log 2-3 more hands
4. Add rebuy ($50 → $100 total invested)
5. Check session analytics

**Expected Results**:
- ✅ All 5-7 hands visible in "View Logged Hands"
- ✅ Total invested shows $100.00 (initial + rebuy)

### 🚀 Code Quality Improvements

- Added comprehensive debug logging throughout hand lifecycle
- Enhanced error handling in session update methods
- Improved data validation in analytics calculations
- Standardized currency formatting with dollar sign display

### 📋 Files Changed Summary

```
lib/models/hand_state_machine.dart
lib/services/local_storage_service.dart
lib/services/firebase_service.dart
lib/screens/session_analytics_screen.dart
```

### 🔄 Lessons Learned

1. **Always test dual storage systems**: Bugs can manifest in both local and cloud storage
2. **Unique IDs are critical**: Timestamp suffixes prevent collision issues effectively
3. **Memory vs Persistence**: In-memory updates require explicit database synchronization
4. **Debug logging investment**: Comprehensive logging upfront saves hours of investigation time

---

*End of session. Both critical bugs resolved and tested successfully.*