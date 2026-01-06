# Poker Logger - Project Documentation

## Overview
Flutter/Dart poker hand logging application with Firebase backend. Allows users to track poker hands, sessions, statistics, opponents, and bankroll.

---

## Project Rules
- **DO NOT push to git unless explicitly asked by user**
- Always check `/diary` folder for previously solved bugs before implementing fixes
- Create diary entry after user confirms a fix
- Never commit debug logging, unnecessary files, or unstabilized code
- Wait for user confirmation before any git operations

---

## Architecture

### Tech Stack
- **Frontend**: Flutter/Dart
- **Backend**: Firebase (Firestore, Auth)
- **Local Storage**: SharedPreferences
- **State Management**: StatefulWidget pattern

### Data Flow
1. User logs hand actions during gameplay
2. Actions saved to HandRecord with player stacks
3. On hand completion:
   - Saved to Firebase (`poker_sessions/{sessionId}/poker_hands`)
   - Saved to local storage (backup)
   - User stats updated **incrementally** (not recalculated)
   - Opponent stats updated **incrementally**

---

## Key Features

### 1. Hand Logging (Full Tracking)
- Log every action for every player across all streets
- Track: player seat, action type, amount, stack size, street
- Support: fold, check, call, bet, raise, all-in
- Track board cards (flop, turn, river)
- Track hole cards (hero only by default)
- Track showdown data
- Support chopped pots (multiple winners)

### 2. Individual Session Tracking (Quick Logging)
- Quick profit/loss tracking without full hand details
- Records: start time, end time, profit/loss, session name
- Does NOT update hand-based stats (VPIP, PFR, etc.)

### 3. Statistics Tracking
Tracks per-hand stats incrementally:
- **Total Hands**: All hands dealt to player
- **Hands Played**: Hands where player voluntarily put money in (VPIP hands)
- **Won Hands**: Hands won by player
- **VPIP Count**: Times player voluntarily put money in preflop
- **PFR Count**: Times player raised/bet preflop
- **3-Bet Count**: Times player re-raised preflop after seeing a raise
- **Total Sessions**: Number of completed sessions
- **Total Play Time**: Minutes played across all sessions

### 4. Play Style Detection
Automatically categorizes player style based on stats:
- **Tight-Aggressive (TAG)**: VPIP < 25%, PFR/VPIP > 0.65, AF > 1.5
- **Loose-Aggressive (LAG)**: VPIP > 28%, PFR/VPIP > 0.5, AF > 1.5
- **Tight-Passive**: VPIP < 20%, AF < 1.0
- **Loose-Passive (Calling Station)**: VPIP > 35%, AF < 1.0
- **Unknown**: Not enough data (< 50 hands)

### 5. Opponent Tracking
- Automatically creates opponent profiles from logged hands
- Tracks same stats as user
- Associates opponents with userId via `playerNames` map
- Displays opponent hands filtered by opponent

### 6. Bankroll Management
- Track current bankroll and goals
- Calculate progress to goal
- Show bankroll statistics

### 7. AI Hand Analysis
- Analyze specific hands using AI
- Store analysis results per hand
- Retrieve cached analysis

---

## Data Structures

### Hand Data Format
```dart
{
  'handNumber': int,
  'buttonPosition': int,
  'playerCount': int,
  'actions': List<Map<String, dynamic>>,
  'startTime': String (ISO 8601),
  'endTime': String (ISO 8601),
  'boardCards': {
    'flop': List<String>,  // ['A♠', 'K♥', 'Q♦']
    'turn': String?,       // '2♣'
    'river': String?       // '9♠'
  },
  'ourHoleCards': {
    'card1': String,  // 'A♠'
    'card2': String   // 'K♥'
  },
  'showdownData': {
    'seat1': {'card1': String, 'card2': String},
    'seat2': {...},
    ...
  },
  'reachedShowdown': bool,
  'potAmount': double,
  'preflopPot': double?,
  'flopPot': double?,
  'turnPot': double?,
  'riverPot': double?,
  'winnerId': int,
  'heroPositionName': String,  // 'BTN', 'CO', 'MP', etc.
  'heroSeatNumber': int,
  'playerNames': {
    '1': String,  // seat number -> player name
    '2': String,
    ...
  },
  'smallBlind': int,
  'bigBlind': int,
  'gameType': String,  // 'cash' or 'tournament'
  'isChoppedPot': bool?,
  'choppedWinners': List<int>?,
  'individualShares': Map<int, double>?,
  'sharePerWinner': double?
}
```

### Action Data Format
```dart
{
  'player': int,              // Seat number (1-9)
  'action': String,           // 'fold', 'check', 'call', 'bet', 'raise', 'all-in'
  'street': String,           // 'preflop', 'flop', 'turn', 'river'
  'timestamp': String,        // ISO 8601
  'buttonPosition': int,
  'playerName': String?,      // Display name
  'playerId': String?,        // userId or opponentId
  'isCurrentUser': bool,
  'playerPosition': String?,  // 'BTN', 'CO', etc.
  'playerStack': double?,     // CRITICAL: Stack size at time of action
  'amount': double?           // Amount for bet/raise/call
}
```

**Important Notes on Action Amounts:**
- **Preflop raises**: Store TOTAL amount (e.g., raise to 1500)
- **Postflop raises**: Store ADDITIONAL amount (e.g., raise 20000 on top of current bet)
- **Calls**: Store actual amount player put in (handles all-in for less)

### User Stats Format
```dart
{
  'userId': String,
  'totalHands': int,        // All hands dealt
  'handsPlayed': int,       // VPIP hands only
  'wonHands': int,
  'vpipCount': int,
  'pfrCount': int,
  'threeBetCount': int,
  'totalSessions': int,
  'totalPlayTimeMinutes': int
}
```

### Session Data Format
```dart
{
  'userId': String,
  'sessionName': String?,
  'smallBlind': int,
  'bigBlind': int,
  'hasBBante': bool,
  'playerCount': int,
  'ourSeatNumber': int?,
  'gameType': String,        // 'cash' or 'tournament'
  'startTime': Timestamp,
  'endTime': Timestamp?,
  'totalHands': int,
  'isIndividualSession': bool,  // Quick tracking vs full hand logging
  'buyInAmount': double?,       // Money paid (for cash games)
  'totalBuyIn': double?,        // Total invested including rebuys
  'startingStack': double?,     // Chips received
  'currentStack': double?,      // Current chip count
  'stackHistory': List<Map>,    // Stack changes over time
}
```

---

## Critical Statistics Calculations

### VPIP (Voluntarily Put Money In Pot)
```dart
vpip% = (vpipCount / totalHands) * 100
```
- **Denominator**: `totalHands` (ALL dealt hands)
- **NOT**: `handsPlayed` (that would give 100%)

### PFR (Preflop Raise)
```dart
pfr% = (pfrCount / totalHands) * 100
```
- **Denominator**: `totalHands` (ALL dealt hands)

### 3-Bet Percentage
```dart
threeBet% = (threeBetCount / totalHands) * 100
```
- **Definition**: A 3-bet is when a player **re-raises** after seeing another player's raise
- **NOT**: Just raising 2+ times in a hand (that never happens)
- **Detection Logic**:
  1. Track if we've seen a raise from another player
  2. If hero raises AFTER seeing that raise → 3-bet
  3. Must be preflop only

### Win Rate
```dart
winRate% = (wonHands / handsPlayed) * 100
```
- Only count hands where player VPIP'd

### Aggression Factor
```dart
AF = aggressiveActions / passiveActions
AF = pfrCount / (vpipCount - pfrCount)
```

---

## Key Services

### FirebaseService (`lib/services/firebase_service.dart`)
- `createSession()` - Create new poker session
- `saveHand()` - Save completed hand to Firestore
- `endSession()` - End current session
- `getAllSessions()` - Fetch all user sessions
- `_updateUserStatsFromHand()` - Incrementally update user stats
- `_updateOpponentStatsFromHand()` - Incrementally update opponent stats
- `_didPlayerThreeBet()` - Detect if player 3-bet

### LocalStorageService (`lib/services/local_storage_service.dart`)
- Mirrors FirebaseService operations for offline backup
- Uses SharedPreferences for persistence
- `saveHand()`, `getUserSessions()`, etc.

### UserStatsService (`lib/services/user_stats_service.dart`)
- `getUserStats()` - Fetch user stats document
- `updateStatsAtomic()` - Atomic increment/decrement operations
- Uses Firestore transactions for consistency

### BankrollService (`lib/services/bankroll_service.dart`)
- `getCurrentBankroll()`, `setBankrollGoal()`
- `getPlayerStatistics()` - Aggregates stats from UserStatsService
- **IMPORTANT**: Calculates VPIP/PFR/3-bet using `totalHands`

### OpponentService (`lib/services/opponent_service.dart`)
- `getOrCreateOpponent()` - Get or create opponent by name
- `getOpponentById()`, `getAllOpponents()`

### OpponentStatsService (`lib/services/opponent_stats_service.dart`)
- Same structure as UserStatsService but for opponents
- Tracks per-opponent statistics

### AuthService (`lib/services/auth_service.dart`)
- Firebase Authentication wrapper
- `currentUser`, `userId`, `userDisplayName`

---

## Game Settings

### BB Ante
- **Immutable**: Set at session creation, cannot be changed mid-session
- Stored as `hasBBante: bool` in session document
- Applied automatically before each hand

### Blinds
- Must be synchronized: SB and BB always set together
- Stored in session document
- Can increase during tournament (level changes)

### Button Position
- Tracks dealer button location (seat 1-9)
- Used to calculate blinds positions
- Rotates each hand

### Empty Seats
- Some seats may be unoccupied (e.g., 6-handed at 9-max table)
- Only occupied seats should be listed in hand histories
- Blinds skip empty seats

---

## UI Screens

### Home Screen (`lib/screens/home_screen.dart`)
- Main navigation hub
- Start new session
- View statistics
- Access opponents

### Hand Actions Screen (`lib/screens/hand_actions_screen.dart`)
- Display single hand details
- Show all actions by street
- AI hand analysis button
- View opponent cards at showdown

### Statistics Screen (`lib/screens/statistics_screen.dart`)
- **REMOVED**: Tabs (Sessions, Overview, Opponents)
- **NOW**: Only shows Overview content directly
- Displays: Play style, VPIP, PFR, win rate, etc.

### Poker Hand Screen (`lib/screens/poker_hand_screen.dart`)
- Main screen during hand logging
- Action buttons (fold, check, call, bet, raise)
- Board card input
- Pot tracking

### Seat Setup Screen (`lib/screens/seat_setup_screen.dart`)
- Configure table layout
- Set button position
- Assign player names
- Set starting stacks

---

## Recent Major Changes

### ✅ Completed (Current State)
1. **Statistics Screen Tabs Removed**
   - Removed Sessions, Overview, Opponents tabs
   - Now shows only Overview content
   - File: `lib/screens/statistics_screen.dart`

2. **BB Ante Made Immutable**
   - Cannot change after session starts
   - Set only in session creation dialog
   - Files: Multiple dialogs and screens

3. **Button Mode Feature Removed**
   - Removed "Button View" toggle
   - Removed associated UI elements
   - File: `lib/screens/seat_setup_screen.dart`

4. **VPIP/PFR/3-Bet Calculations Fixed**
   - Changed denominator from `handsPlayed` to `totalHands`
   - Fixed in: `lib/services/bankroll_service.dart`
   - Now correctly shows percentages (e.g., 42% not 100%)

5. **3-Bet Detection Logic Fixed**
   - Old: Counted if player raised 2+ times (wrong)
   - New: Detects re-raise after seeing another raise (correct)
   - Added `_didPlayerThreeBet()` function
   - File: `lib/services/firebase_service.dart` (lines 904-934)

6. **Debug Logs Cleaned Up**
   - Commented out most debug print statements
   - Kept only critical logs
   - Files: Multiple service files

---

## Common Issues & Solutions

### Issue: VPIP showing 100% or incorrect values
**Cause**: Using `handsPlayed` as denominator instead of `totalHands`
**Solution**: Always use `totalHands` for VPIP/PFR/3-bet percentages

### Issue: 3-bet count always 0
**Cause**: Wrong detection logic (checking if player raised 2+ times)
**Solution**: Use `_didPlayerThreeBet()` to detect sequential re-raises

### Issue: Play style shows "N/A" or "Unknown"
**Cause**: Not enough hands (< 50) or missing `handsPlayed` field
**Solution**: Wait for 50+ hands, ensure stats are updating

### Issue: Player actions missing in hand history
**Cause**: Actions not logged during gameplay
**Solution**: Ensure all player actions are recorded, including folds

### Issue: Stack sizes incorrect
**Cause**: Not extracting from `playerStack` field in actions
**Solution**: Extract stacks from action records, not using defaults

---

## Testing Checklist

When testing new features:
- [ ] Test with both cash and tournament games
- [ ] Test with different player counts (2-9 players)
- [ ] Test with empty seats (e.g., 6-handed at 9-max)
- [ ] Verify stats update correctly after each hand
- [ ] Check VPIP/PFR/3-bet calculations
- [ ] Verify play style detection with 50+ hands
- [ ] Test with BB ante enabled and disabled
- [ ] Test blind level changes in tournaments
- [ ] Verify local storage fallback when offline

---

## Code Style Guidelines

### Naming Conventions
- Classes: PascalCase (`HandStateManager`)
- Files: snake_case (`hand_state_machine.dart`)
- Variables: camelCase (`heroSeatNumber`)
- Constants: SCREAMING_SNAKE_CASE (`DEFAULT_STACK`)

### Debug Logging
- Comment out debug logs in production
- Keep critical error logs
- Use format: `// print('Debug message')`

### Comments
- Document complex logic
- Explain "why" not "what"
- Update comments when changing code

---

## Firebase Structure

```
users/
  {userId}/
    email, displayName, createdAt, stats

poker_sessions/
  {sessionId}/
    userId, smallBlind, bigBlind, hasBBante, playerCount,
    gameType, startTime, endTime, totalHands, isIndividualSession,
    buyInAmount, totalBuyIn, startingStack, stackHistory

    poker_hands/
      {handId}/
        handNumber, buttonPosition, actions[], boardCards,
        ourHoleCards, showdownData, potAmount, winnerId, etc.

user_stats/
  {userId}/
    totalHands, handsPlayed, wonHands, vpipCount, pfrCount,
    threeBetCount, totalSessions, totalPlayTimeMinutes

opponents/
  {opponentId}/
    name, userId, gamesPlayed, lastPlayed

opponent_stats/
  {opponentId}/
    Same structure as user_stats
```

---

## Important Files Reference

### Models
- `lib/models/hand_state_machine.dart` - Hand and session state management
- `lib/models/poker_game_state.dart` - Player state and game state
- `lib/models/game_types.dart` - Enums for game types, actions, streets

### Services
- `lib/services/firebase_service.dart` - Firebase operations (CRITICAL)
- `lib/services/local_storage_service.dart` - Local backup
- `lib/services/user_stats_service.dart` - User statistics
- `lib/services/bankroll_service.dart` - Bankroll and aggregated stats
- `lib/services/opponent_service.dart` - Opponent management
- `lib/services/opponent_stats_service.dart` - Opponent stats
- `lib/services/auth_service.dart` - Authentication

### Screens
- `lib/screens/home_screen.dart` - Main navigation
- `lib/screens/poker_hand_screen.dart` - Hand logging interface
- `lib/screens/hand_actions_screen.dart` - Hand detail view
- `lib/screens/statistics_screen.dart` - User statistics (Overview only)
- `lib/screens/seat_setup_screen.dart` - Table configuration

---

## Version History

### Recent Sessions
1. **BB Ante Immutability & Button Mode Removal**
   - Made BB Ante immutable after session start
   - Removed Button Mode feature completely
   - Synchronized blind changes

2. **Statistics Fixes**
   - Fixed VPIP/PFR calculations (use totalHands not handsPlayed)
   - Fixed 3-bet detection (re-raise logic)
   - Cleaned up debug logs
   - Fixed play style detection

3. **Copy Hand Feature** (Discarded)
   - Attempted to add hand history export
   - Issues with GTO Wizard format compatibility
   - Feature removed, code reverted

---

## Future Considerations

### Potential Features
- Advanced filtering for hand history
- Multi-table support
- Tournament structure tracking
- Graph/chart visualizations
- Export to CSV/Excel
- Backup/restore functionality
- Hand replay animations

### Known Limitations
- No real-time sync between devices
- Limited offline functionality
- No hand history import from other sources
- Play style detection requires 50+ hands

---

## Troubleshooting

### Stats not updating
1. Check if Firebase is connected
2. Verify user is authenticated
3. Check if hand was saved successfully
4. Look for errors in console

### App crashes on hand completion
1. Check all required fields are present
2. Verify action amounts are valid
3. Check playerStack values exist
4. Review recent code changes

### Incorrect statistics
1. Verify calculation logic in BankrollService
2. Check UserStatsService atomic updates
3. Review firebase_service.dart hand processing
4. Run StatsVerificationService to debug

---

## Support & Debugging

### Debug Tools
- `StatsVerificationService` - Verify stats calculations
- Firebase Console - View/edit Firestore data
- Flutter DevTools - Performance and state inspection

### Common Debug Commands
```bash
flutter clean
flutter pub get
flutter run --debug
```

### Log Locations
- User stats: Firestore `user_stats/{userId}`
- Hands: Firestore `poker_sessions/{sessionId}/poker_hands`
- Local: SharedPreferences (device storage)

---

**Last Updated**: January 2026
**Maintained by**: User + Claude
**Update this file**: After major feature additions or architectural changes
