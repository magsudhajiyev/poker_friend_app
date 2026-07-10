# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Poker Friend - Project Documentation

## Overview
Flutter/Dart poker hand logging application with Firebase backend, club management, dealer-assisted voice logging, and real-time WebSocket sync. Allows users to track poker hands, sessions, statistics, opponents, and bankroll.

---

## Commands

```bash
# Run on iOS simulator (iPhone 16 Pro, iOS 18.5 runtime required)
flutter run

# Run all tests
flutter test

# Run a single test file
flutter test test/services/stats_calculator_test.dart

# Run tests by name pattern
flutter test --name "VPIP"

# Lint / static analysis
flutter analyze

# Check hardcoded design values (must not increase before committing UI work)
python3 tool/design_lint.py

# Auto-replace exact token matches
python3 tool/design_lint.py --fix

# Regenerate l10n classes after editing .arb files
flutter gen-l10n

# Clean build artifacts
flutter clean && flutter pub get
```

---

## Project Rules
- **DO NOT push to git unless explicitly asked by user**
- **DO NOT commit unless explicitly asked by user**
- Always check `/diary` folder for previously solved bugs before implementing fixes
- Create diary entry after user confirms a fix
- Never commit debug logging, unnecessary files, or unstabilized code
- Wait for user confirmation before any git operations
- **After work is done and branch has been pushed: always open a PR targeting the `design_v2` branch** (not `main`)
- **Responsive Design (CRITICAL)**: All UI sizing, spacing, padding, font sizes, and layout dimensions MUST be responsive across different device sizes. Do NOT hardcode pixel values that only work on one device (e.g., iPhone 16 Pro). Use `MediaQuery`, `LayoutBuilder`, `FractionallySizedBox`, `Flexible`, `FittedBox`, relative sizing, or screen-fraction-based calculations to ensure the app looks correct on iPhone 11, iPhone 13, iPhone 16 Pro, and various Android devices. When implementing Figma designs, treat pixel values as reference for proportions, not absolute values.

---

## Development Environment

### CRITICAL: Flutter Version Constraint
- **Flutter 3.38.10** — DO NOT upgrade to 3.41.x (Firestore write performance regression)
- **Dart**: 3.9.x (bundled with Flutter 3.38.10)
- **Xcode**: 26.3
- Monitor Flutter releases for the Firestore regression fix before upgrading
- See `diary/2026-03-29-flutter-firestore-regression-fix.md` for full details

### iOS Simulator
- Use **iOS 18.5** runtime (Flutter 3.38 does not support iOS 26 simulators)
- iPhone 16 Pro simulator with iOS 18.5 runtime
- Download runtime via Xcode → Settings → Platforms → iOS → Get
- iOS 18.5 and iOS 26.1 runtimes coexist fine

### Android
- Physical device via USB debug
- Debug keystore SHA1: `9F:26:C7:87:7E:4E:AA:DE:7D:BF:03:37:96:BA:27:3D:52:9F:BA:60`
- Original new laptop keystore backed up as `~/.android/debug.keystore.new-laptop-backup`
- **Pending**: Register old keystore SHA-1 in Firebase Console for Google Sign-In

### Dependency Version Policy
- All dependencies pinned to Flutter 3.38-compatible versions (see pubspec.yaml)
- When upgrading Flutter, ALL Firebase/plugin dependencies must be upgraded together
- Key version constraints: cloud_firestore ^5.5.0, firebase_core ^3.8.0, purchases_flutter ^8.1.0
- API differences exist between old and new versions (positional vs named params) — see diary entry

---

## Architecture

### Tech Stack
- **Frontend**: Flutter/Dart (179+ Dart files)
- **Backend**: Firebase (Firestore, Auth, FCM) + FastAPI backend (Render)
- **Local Storage**: SQLite (sqflite v13) + SharedPreferences
- **Real-time**: Socket.IO WebSocket + Firestore Snapshot listeners
- **Voice Recognition**: Deepgram ASR via backend "Dealer Brain" endpoint
- **Payments**: RevenueCat SDK
- **State Management**: StatefulWidget pattern (no Provider/BLoC/Riverpod — **exception**: the dealer voice pipeline uses `flutter_bloc` via `lib/features/dealer_voice/cubit/`)
- **Localization**: Flutter's built-in `gen-l10n` system; `.arb` files in `lib/l10n/`; supported: EN, DE, ES, FR, PT, RU, PL. Use `AppLocalizations.of(context)` — never hardcode UI strings.

### Data Flow
1. User logs hand actions during gameplay
2. Actions saved to HandRecord with player stacks
3. On hand completion:
   - Saved to Firebase (`poker_sessions/{sessionId}/poker_hands`)
   - Saved to local SQLite (backup)
   - User stats updated **incrementally** via atomic transactions (not recalculated)
   - Opponent stats updated **incrementally** (only saved opponents)
4. Dual storage: ALL writes go to both Firebase and local storage

### API Endpoints
- **Backend**: `https://poker-friend-engine.onrender.com/api/v1`
- **Hand Analysis**: `/api/v1/analyze-hand` (deployed)
- **Session Analytics**: `/api/v1/analytics/sessions` (not deployed yet)
- **Speech**: `/api/v1/speech/transcribe-brain` (Deepgram via backend)
- All API calls require `X-API-Key` header

### Environment Configuration (`.env`)
Loaded at startup via `flutter_dotenv`. Required keys: `SONIOX_API_KEY`, `REVENUECAT_IOS_API_KEY`, `REVENUECAT_ANDROID_API_KEY`, `RESEND_API_KEY`, `AI_API_KEY`, `WEBSOCKET_SERVER_URL`, `API_SERVER_URL`, `ENVIRONMENT`. Access via `EnvConfig.*` (never `dotenv.env` directly).

### Subscription Tiers (RevenueCat)
Four tiers — check via `SubscriptionService`:
- **Free**: 10 hands/session, 5 opponents, 30-day session history
- **Pro** (`isPro`/`isPremium`): 50 hands/session, 15 opponents, 90-day history
- **Elite** (`isElite`/`isPremium`): unlimited everything, AI analysis, all history
- **Club** (`isClub`/`isPremium`): like Elite + club creation rights (owner pays; club members operate freely regardless of their own tier)

Feature gates live in `lib/services/free_tier_limits.dart` (hand/opponent caps) and `lib/services/feature_flag_service.dart` (remote Firestore flags for `training_drills`, `ai_hand_analysis`). Use `FreeTierLimits.showHandsLimitDialog()` / `PaywallScreen.show()` for upgrade prompts.

### Caching Pattern (`lib/services/app_data_cache.dart`)
`AppDataCache` is a static dirty-flag cache. Screens serve from cache if clean; write points (`saveHand`, `endSession`, bankroll/opponent changes) call `markHomeDirty()` / `markSessionsDirty()` / etc. **Always call the appropriate `mark*Dirty()` after any write** or the next screen visit will show stale data.

### Error Presentation
**Never** show `e.toString()` to users. Always use `UserFacingError.message(e)` (`lib/utils/user_facing_error.dart`) which maps network errors, Firestore permission errors, HTTP status codes, and intentional `throw 'human string'` patterns to localized messages.

### Logging
`LoggerService` (`lib/services/logger_service.dart`) writes to a local file, Crashlytics breadcrumbs, and Firebase Analytics. Log level controlled remotely via Firebase Remote Config. Use `LoggerService.log(level, tag, message)` — not `print()`.

---

## Design System

### Two Coexisting Themes
The app has two themes. **Modern Dark (AppTheme)** is used in all newer screens. **Legacy (PokerFriendTheme)** exists in older screens being phased out.

### Modern Dark Theme (AppTheme) — Primary
- **Primary**: Teal `#62E3BC`
- **Secondary/Buttons**: Cyan/Mint `#89F1EC`
- **Tertiary/Section Headers**: Lime `#87ED81`
- **Background**: Paper `#02050B`, Surface `#101115`
- **NavBar**: `#1E1E1E`
- **Text**: White (primary), Mint `#D3FFFD` (secondary), `#8C8C8C` (disabled)
- **Progress Bar**: `#54E98A` → `#66D9CC` gradient
- **Separator**: `#1C1F21`
- **Glassy Card Base**: `#546165` at 74% opacity

### Fonts
- **IBM Plex Sans** — Primary body/UI text (Google Fonts)
- **Roboto Mono** — Numbers, chart labels, monetary values
- **Familjen Grotesk** — Bankroll display amount

### Typography (AppTypography in `lib/design_system/constants/typography.dart`)
- Section headers: 12px w600 uppercase, lime green, letterSpacing 1.0
- Page titles: 28-32px w600-700, letterSpacing -0.5
- Body: 14-17px w400, height 1.44
- List rows: 17px w500 (label) / w400 (value)
- Buttons: 17px w600, letterSpacing -0.43
- Monetary large: 38px w700 Roboto Mono
- Bankroll: 40px w600 Familjen Grotesk

### Spacing (AppSpacing in `lib/design_system/constants/spacing.dart`)
- xxxs=4, xxs=8, xs=12, sm=14, md=16, lg=18, xl=24, xxl=28, xxxl=32
- bottomPadding=120 (nav bar clearance)

### Border Radius (AppDecorations in `lib/design_system/constants/decorations.dart`)
- card=12, button=60, navBar=70, pill=40, modeCard=24

### Effects
- Blur light: 45px (glassy cards via BackdropFilter)
- Blur heavy: 132px (gradient backgrounds)
- Glassmorphism: BackdropFilter + white 10% border + semi-transparent bg

### Reusable Components (`lib/design_system/components/`)
- **GlassyCard** — blur 45, border white 10%, radius 12, padding 16x18
- **PrimaryButton** — white bg, radius 60, padding 32x14, black text
- **GlassyIconButton** — white 10% bg, blur 2, circle, 38px default
- **HomeHeader** — gradient black→teal, elliptical glow, dark pill container
- **SectionHeader** — lime uppercase 12px w600
- **GradientBackground** — teal ellipse 595x727 at (-98,-148), blur 132
- **PillLabel** — white 20% bg, radius 40
- **AvgBadge** — mint bg, radius 140
- **InfoCard** — surface #101115, radius 16, black border
- **StatListRow** — padding 4x8, space-between layout
- **ListSeparator** — 1px #1C1F21
- **GradientDivider** — 1px white opacity gradient [10%,30%,10%]
- **CalendarPicker** — glassy card with day cells, green accent
- **ConfirmDialog** (`modals/confirm_dialog.dart`) — **MANDATORY for ALL delete/destructive confirmation modals**. Style: blurred backdrop (sigmaX/Y 8, black 45% overlay), white card radius 24, padding 24, header row [title 15px w600 black | grey X close], body 15px w400 #B9B9B9, two pill buttons (outlined Cancel + solid-colour action). Use via `ConfirmDialog.show(context, title:, message:, confirmLabel:, onConfirm:)`. Never use `AlertDialog` or custom inline implementations for delete confirmations.

### Design System Unification Status
See `lib/design_system/README.md` for the full phase plan. **Phase 1 + 2 are DONE** (mechanical token replacements, zero visual change). **Phase 2b + 3** remain and require design judgment. Before committing any UI work: run `python3 tool/design_lint.py` — the hardcoded-value count must not increase.

Top offenders still to migrate (Phase 4): `dealer/dealer_table_screen` (158), `poker_hand_screen` (154), `home_screen` (141), `player/player_session_screen` (113).

### Legacy Theme (PokerFriendTheme) — Being Phased Out
- Purple `#AB9FF2` based, Material 3 enabled, Roboto font
- Used in some older dialogs and components

---

## Key Features

### 1. Hand Logging (Full Tracking)
- Log every action for every player across all streets
- Track: player seat, action type, amount, stack size, street
- Support: fold, check, call, bet, raise, all-in
- Track board cards (flop, turn, river)
- Track hole cards (hero only by default)
- Track showdown data
- Support chopped pots (multiple winners) and side pots
- Undo last action with full state restoration
- Navigation confirmation dialog prevents accidental data loss

### 2. Individual Session Tracking (Quick Logging)
- Quick profit/loss tracking without full hand details
- Records: start time, end time, profit/loss, session name
- Does NOT update hand-based stats (VPIP, PFR, etc.)

### 2b. Post-Session Summary Card (`lib/widgets/session_summary_card.dart`)
- Shareable PNG card shown after ending any session (full or quick logging)
- Shows: session name, game type badge, duration, net P/L, hands played, biggest pot, best/worst hand
- **Cash**: Net P/L = `finalStack - totalBuyIn` (both in currency)
- **Tournament**: Net P/L = `prizeWon - totalBuyIn` from `SessionEndBankrollSheet` result (NEVER use chips - money). Also shows placement (e.g., "11th / 28"), prize won, and net profit
- **Biggest pot**: Cash shows currency; Tournament shows BB equivalent (`biggestPot / biggestPotBB` where `biggestPotBB` is the BB level when the biggest pot occurred)
- **Best/worst hand**: Uses pot-to-stack ratio (`pot / heroPreHandStack`) for meaningful cross-blind-level comparison. Falls back to "Hand #N" when hole cards not entered
- `SessionSummaryData` is the data class; `SessionSummaryCard.show()` displays it as a dialog
- Card is captured via `RepaintBoundary` for PNG sharing
- Three code paths call `_showSessionSummary()`: `_stopSession()`, `_handleNavigationAttempt('save')`, `_endSessionFromGate()`
- Debug test button on Profile screen dev tools for quick iteration

### 3. Statistics Tracking (7 Core Metrics)
All stats use **incremental atomic updates** (O(1)) with opportunity-based denominators:

| Metric | Counter | Denominator | Notes |
|--------|---------|-------------|-------|
| VPIP | vpipCount | totalHands - walksCount | Excludes blind posts & walks |
| PFR | pfrCount | totalHands - walksCount | Preflop raises only |
| 3-Bet | threeBetCount | threeBetOpportunity | The 3rd raise preflop (open=1st, re-raise=2nd, 3-bet=3rd) |
| Fold-3Bet | fold3betCount | facing3BetCount | Raised earlier, 3rd raise happened, player folded |
| C-Bet | cbetCount | cbetOpportunity | Flop bet as last pre-aggressor |
| Steal | stealCount | stealOpportunity | CO/BTN/SB with unopened pot |
| Check-Raise | checkRaiseFlopCount | checkRaiseFlopOpportunity | Flop only |

Additional: Win Rate = wonHands / handsPlayed, AF = pfrCount / (vpipCount - pfrCount)

Position-specific breakdowns tracked for: handsPlayed, vpipCount, pfrCount, threeBetCount

#### Session Financial Statistics (from `session_results`)
Statistics screen shows 3 sections — **General**, **Cash**, **Tournament** — computed on-the-fly from `session_results` documents:

**General**: Sessions, Total Time, Avg Session (from `user_stats`), Total Buy-In, Total Cash-Out, Net Profit, Hourly Rate
**Cash**: Sessions, Total Buy-In, Total Cash-Out, Net Profit, Hourly Rate
**Tournament**: Sessions, Total Buy-In, Total Cash-Out, Net Profit, Hourly Rate, ITM%, Avg Finish, Best Finish, ROI%, Final Tables (≤9), Avg Buy-In, Avg Field Size

Key formulas:
- Cash-Out (cash): buyIn + profit | Cash-Out (tournament): prizeWon
- Hourly Rate: netProfit / (totalMinutes / 60)
- ROI%: (cashOut - buyIn) / buyIn × 100
- ITM%: prizeWon > 0 count / tournament sessions × 100

Records without `buyInAmount` (old data) are excluded from financial stats.

### 4. Play Style Detection (`lib/services/play_style_detector.dart`)
Classifies based on VPIP, PFR, 3-bet%, AF thresholds:
- **Maniac**: VPIP≥40%, PFR≥20%, gap≤15%, 3-bet≥12%, AF≥4
- **LAG**: VPIP>25%, PFR>18%, gap≤8%, 3-bet≥7%, AF≥3
- **TAG**: VPIP 15-22%, PFR 12-18%, gap 2-4%, 3-bet 6-10%, AF 2.5-3.5
- **Balanced**: VPIP 20-28%, PFR 17-22%, gap 2-5%, AF 2-4
- **Calling Station**: VPIP≥25%, PFR<10%, gap≥15%, 3-bet<3%, AF<1
- **Nit**: VPIP≤15%, PFR≤12%, 3-bet≤5%, AF≤2
- **Unknown**: < 50 hands

### 5. Opponent Tracking
- Automatically creates opponent profiles from logged hands
- Tracks same 7 metrics as user (only for saved opponents)
- Associates opponents with userId via `playerNames` + `playerIds` maps

### 6. Bankroll Management
- Track current bankroll and goals (SharedPreferences)
- Progress bar with animated fill
- Earnings chart with pinch-to-zoom (landscape, cumulative lines)

### 7. AI Hand Analysis
- Per-hand analysis via deployed API endpoint
- Analysis results cached per hand
- Subscription-gated feature (RevenueCat)

### 8. Club Management
- **Roles**: Owner > Admin > Dealer > Player
- **Club registration requires Club tier** — non-Club users see the paywall (pre-scrolled to Club card)
- Once a club exists, all members/dealers operate freely regardless of their own subscription tier
- Club tier is a "club creator license" — the owner pays, everyone else participates free
- Club registration flow (user submits request, admin approves)
- Member invitation via email + in-app notifications
- Multi-table event management with live rankings
- QR-based seat assignments (per-seat and per-table QR codes)

### 9. Dealer-Assisted Voice Logging
- Real-time speech recognition via Deepgram/Soniox
- Voice + manual action buttons coexist
- Speaker diarization for dealer voice locking
- Multi-layered transcript debouncing for echo prevention
- Rollback/undo for voice recognition mistakes
- Auto-starts on first hand, pause/resume toggle

### 10. Real-Time Sync
- WebSocket (Socket.IO) broadcasts actions to all players/spectators
- Event types: hand_started, action_logged, board_dealt, hand_completed, ranking_update
- Firestore Snapshot listeners as primary, WebSocket for fast broadcasting
- Fallback: Firestore-based rankings when backend unavailable

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
  'ourHoleCards': { 'card1': String, 'card2': String },
  'showdownData': { 'seat1': {'card1': String, 'card2': String}, ... },
  'reachedShowdown': bool,
  'potAmount': double,
  'preflopPot': double?, 'flopPot': double?, 'turnPot': double?, 'riverPot': double?,
  'winnerId': int,
  'heroPositionName': String,  // 'BTN', 'CO', 'MP', etc.
  'heroSeatNumber': int,
  'playerNames': { '1': String, '2': String, ... },  // seat → name
  'playerIds': { '1': String, ... },                  // seat → userId (for dealer mode)
  'smallBlind': double, 'bigBlind': double,
  'gameType': String,  // 'cash' or 'tournament'
  'isChoppedPot': bool?, 'choppedWinners': List<int>?,
  'individualShares': Map<int, double>?, 'sharePerWinner': double?,
  'isStarred': bool?, 'tags': List<String>?, 'notes': String?
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
  'playerName': String?,
  'playerId': String?,        // userId or opponentId
  'isCurrentUser': bool,
  'playerPosition': String?,  // 'BTN', 'CO', etc. — calculated once at hand start
  'playerStack': double?,     // CRITICAL: Stack size at time of action
  'amount': double?           // Amount for bet/raise/call
}
```

**Action Amount Rules:**
- **Preflop raises**: Store TOTAL amount (e.g., raise to 1500)
- **Postflop raises**: Store ADDITIONAL amount (e.g., raise 20000 on top)
- **Calls**: Store actual amount player put in (handles all-in for less)
- **All-in**: Treated as equivalent to bet/raise for stats detection

### User Stats Format (`user_stats/{userId}`)
```dart
{
  'userId': String,
  'totalHands': int,        // ALL hands dealt (denominator for VPIP/PFR)
  'handsPlayed': int,       // VPIP hands only
  'walksCount': int,        // Everyone folded to BB
  'wonHands': int,
  'vpipCount': int, 'pfrCount': int,
  'threeBetCount': int, 'threeBetOpportunity': int,
  'fold3betCount': int, 'facing3BetCount': int,
  'cbetCount': int, 'cbetOpportunity': int,
  'stealCount': int, 'stealOpportunity': int,
  'checkRaiseFlopCount': int, 'checkRaiseFlopOpportunity': int,
  'totalSessions': int, 'totalPlayTimeMinutes': int,
  'positionHandsPlayed': Map, 'positionVpipCount': Map,
  'positionPfrCount': Map, 'positionThreeBetCount': Map,
  'lastUpdated': Timestamp
}
```

---

## Critical Statistics Logic

### VPIP/PFR Denominator
```dart
eligibleHands = totalHands - walksCount
vpip% = (vpipCount / eligibleHands) * 100
pfr% = (pfrCount / eligibleHands) * 100
```
- **NEVER** use `handsPlayed` as denominator (gives ~100%)
- Walk hands excluded because BB had no opportunity to act

### 3-Bet Detection (`StatsCalculator.didPlayerThreeBet`)
A 3-bet is the **3rd raise** preflop. Blinds do NOT count as raises.
- 1st raise = open raise
- 2nd raise = re-raise
- 3rd raise = **3-bet**
```dart
int raiseCount = 0;
for action in preflop_actions:
  if isRaiseAction(action):
    raiseCount++;
    if raiseCount == 3 && action.player == hero:
      return true;  // THIS is a 3-bet
```
- All-in counts as raise for detection purposes
- `hadThreeBetOpportunity`: exactly 2 total raises already happened when player acts (covers opener facing re-raise AND cold 3-bet spots). Does NOT count 4-bet opportunities (3+ raises).
- `facedThreeBet`: player raised earlier, then the 3rd raise happened by someone else
- `didFoldTo3Bet`: facing 3-bet and folded

### Stats Update Flow
```
saveHand() called
  ├─ Save to Firestore + local SQLite
  ├─ _updateUserStatsFromHand() → UserStatsService.updateStatsAtomic()
  │   └─ Runs ALL 7 StatsCalculator detection methods
  │   └─ Builds delta map, atomic Firestore transaction
  ├─ _updateOpponentStatsFromHand() → OpponentStatsService.updateStatsAtomic()
  │   └─ Only for saved opponents with created profiles
  └─ Session totalHands++
```

**CRITICAL**: Stats must be updated in ONE place only. Previously had double-counting bug where both `FirebaseService._updateUserStatsFromHand()` and `PokerSessionManager._updateOptimizedStats()` updated stats.

---

## Key Services

### Core Services
| Service | File | Purpose |
|---------|------|---------|
| FirebaseService | `lib/services/firebase_service.dart` (1631 lines) | Session/hand CRUD, stats orchestration |
| LocalStorageService | `lib/services/local_storage_service.dart` | SQLite v13 mirror of Firebase |
| UserStatsService | `lib/services/user_stats_service.dart` | Atomic user stat transactions |
| OpponentStatsService | `lib/services/opponent_stats_service.dart` | Atomic opponent stat transactions |
| StatsCalculator | `lib/services/stats_calculator.dart` | Pure stat detection functions (testable) |
| PlayStyleDetector | `lib/services/play_style_detector.dart` | Player classification |
| BankrollService | `lib/services/bankroll_service.dart` | Bankroll goals + stats aggregation |
| AuthService | `lib/services/auth_service.dart` | Firebase Auth wrapper |

### Club/Dealer Services
| Service | File | Purpose |
|---------|------|---------|
| ClubService | `lib/services/club_service.dart` | Club CRUD, membership, roles |
| EventService | `lib/services/event_service.dart` | Event lifecycle, rankings |
| DealerService | `lib/services/dealer_service.dart` | Dealer sessions, hand management |
| SeatService | `lib/services/seat_service.dart` | QR-based seat assignments |
| TableService | `lib/services/table_service.dart` | Table management |
| ClubNotificationService | `lib/services/club_notification_service.dart` | Club notifications |
| WaitlistService | `lib/services/waitlist_service.dart` | Cash game waitlist |

### Voice/Real-time Services
| Service | File | Purpose |
|---------|------|---------|
| CloudSpeechService | `lib/services/cloud_speech_service.dart` | Voice recognition (2.5s segments → Deepgram) |
| SonioxService | `lib/services/soniox_service.dart` | Direct Soniox WebSocket with poker context |
| WebSocketService | `lib/services/websocket_service.dart` | Socket.IO real-time sync |
| ActionParser | `lib/services/action_parser.dart` | Parse speech transcripts to poker actions |

### Other Services
| Service | File | Purpose |
|---------|------|---------|
| SubscriptionService | `lib/services/subscription_service.dart` | RevenueCat integration |
| FCMService | `lib/services/fcm_service.dart` | Push notifications (fire-and-forget!) |
| DeepLinkService | `lib/services/deep_link_service.dart` | Email invitation deep links |
| AiAnalyzerService | `lib/services/ai_analyzer_service.dart` | Hand analysis API calls |
| FeatureFlagService | `lib/services/feature_flag_service.dart` | Global remote feature flags (Firestore `app_config/feature_flags`, super-admin toggles on Profile, offline cache). Gated: training_drills, ai_hand_analysis |

---

## Key Models

| Model | File | Purpose |
|-------|------|---------|
| HandRecord, ActionRecord, PokerSessionManager | `lib/models/hand_state_machine.dart` | Hand/session state machine |
| PokerGameState, PlayerState | `lib/models/poker_game_state.dart` | Game state, player tracking |
| GameType, PlayerAction, BettingRound | `lib/models/game_types.dart` | Core enums |
| UserStats | `lib/models/user_stats.dart` | 7 metrics + position breakdowns |
| OpponentStats | `lib/models/opponent_stats.dart` | Same structure for opponents |
| Opponent, PlayerType | `lib/models/opponent.dart` | Opponent profile + classification |
| ClubEvent | `lib/models/club_event.dart` | Event data model |
| EventRanking | `lib/models/event_ranking.dart` | Live ranking data |

---

## Navigation

### Bottom Navigation Bar (`lib/widgets/global_bottom_nav_bar.dart`)
- **Home** → HomeScreen
- **Opponents** → MyOpponentsScreen
- **+FAB** (center) → LoggingModeSelectionScreen
- **Sessions** → SessionHistoryScreen
- **Profile** → ProfileScreen

### Key Screens
| Screen | File | Notes |
|--------|------|-------|
| Home | `lib/screens/home_screen.dart` | Bankroll, activity, events, club links |
| Hand Logging | `lib/screens/poker_hand_screen.dart` | Main gameplay interface |
| Hand Details | `lib/screens/hand_actions_screen.dart` | Review hand with AI analysis |
| Statistics | `lib/screens/statistics_screen.dart` | Overview only (tabs removed) |
| Session History | `lib/screens/session_history_screen.dart` | Cash/Tournament tabs |
| Opponents | `lib/screens/my_opponents_screen.dart` | Opponent list with stats |
| Profile | `lib/screens/profile_screen.dart` | User profile, bankroll |
| Seat Setup | `lib/screens/seat_setup_screen.dart` | Table config with visual layout |
| Logging Mode | `lib/screens/logging_mode_selection_screen.dart` | Full vs quick logging |
| Earnings Chart | `lib/screens/earnings_chart_screen.dart` | Landscape zoom/pan chart |
| Dealer Table | `lib/screens/dealer/dealer_table_screen.dart` | Dealer voice + manual logging |
| Club Dashboard | `lib/screens/club/club_dashboard_screen.dart` | Club overview, events |
| Event Dashboard | `lib/screens/club/event_dashboard_screen.dart` | Live rankings |

### Navigation Patterns
- Push/pop with MaterialPageRoute
- Named route `/player_session` for PlayerSessionScreen
- Deep links: `pkr://` scheme for club/event/seat invitations
- PopScope on poker_hand_screen prevents accidental back navigation

---

## Firebase Structure

```
users/{userId}/
  uid, displayName, displayNameLower, email, createdAt, updatedAt

user_stats/{userId}/
  totalHands, handsPlayed, walksCount, vpipCount, pfrCount,
  threeBetCount, threeBetOpportunity, fold3betCount, facing3BetCount,
  cbetCount, cbetOpportunity, stealCount, stealOpportunity,
  checkRaiseFlopCount, checkRaiseFlopOpportunity,
  wonHands, totalSessions, totalPlayTimeMinutes,
  positionHandsPlayed, positionVpipCount, positionPfrCount, positionThreeBetCount

poker_sessions/{sessionId}/
  userId, sessionName, smallBlind, bigBlind, hasBBante, playerCount,
  ourSeatNumber, gameType, startTime, endTime, totalHands, handsLogged,
  biggestPot, isIndividualSession, buyInAmount, totalBuyIn, startingStack,
  currentStack, stackHistory, participantIds, isLive, isDealerSession
  poker_hands/{handId}/
    handNumber, buttonPosition, actions[], boardCards, ourHoleCards,
    showdownData, potAmount, winnerId, playerNames, playerIds,
    isChoppedPot, choppedWinners, tags, notes, isStarred

opponents/{opponentId}/
  name, notes, createdAt, lastSeenAt, color, userId

opponent_stats/{opponentId}/
  (same structure as user_stats)

clubs/{clubId}/
  name, ownerId, settings, address, phone, description
  members/{memberId}/ - role, joinDate
  tables/{tableId}/ - status, dealerId, qrCodes
  events/{eventId}/ - status, tableIds, startTime, gameType, isPublic
    final_standings/results - ranked player list
  notifications/{notificationId}/

session_results/{resultId}/
  userId, userEmail, amount (net profit), gameType ('cash'|'tournament'),
  timestamp, createdAt, buyInAmount?, prizeWon?, finishedPlace?, fieldSize?,
  durationMinutes?

dealers/{userId}/
  accountType: 'player'|'dealer'|'admin', clubIds[]

dealer_sessions/{sessionId}/
  players, status, blinds, eventId
  hands/{handId}/ - actions, board, winner

seat_assignments/{id}/
  clubId, tableId, seatNumber, playerId, playerName, status, chipStack

user_notifications/{notificationId}/
  (club notifications for specific users)
```

---

## Game Settings

### BB Ante
- **Immutable**: Set at session creation, cannot be changed mid-session
- Stored as `hasBBante: bool` in session document
- BB ante amount included in player's `betThisRound` for pot calculations

### Blinds
- SB and BB always set together
- Stored as `double` throughout — supports decimal values for small-stakes cash games (e.g. $0.25/$0.50)
- Cash game input allows decimals; tournament input restricted to whole numbers
- Display uses `formatBlindValue()` helper (in `poker_game_state.dart`) — shows `0.25` not `0.25000`
- Can increase during tournament (level changes)
- On preflop: BET is always invalid, RAISE is always valid

### Button Position
- Locked during active hand (cannot be moved)
- Rotates each hand automatically
- Used to calculate SB/BB/UTG positions based on active players only

### Empty Seats
- Table supports up to 9 seats, some may be unoccupied
- Blinds and action order skip empty/inactive seats
- Player count uses active players, NOT total seats

---

## Known Bug Patterns & Prevention

### Stats Bugs (Most Common)
1. **Double-counting**: Stats must be updated in ONE place only (FirebaseService)
2. **Wrong denominator**: Use `totalHands - walksCount` for VPIP/PFR, NOT `handsPlayed`
3. **3-bet = 3rd raise**: Count total raises preflop: open=1st, re-raise=2nd, 3-bet=3rd. Blinds don't count.
4. **All-in ignored**: Always use `isRaiseAction()`/`isBetAction()` helpers that include 'all-in'. Also include 'all-in' in per-action switch statements.
5. **Dealer mode zero stats**: Must pass `playerIds` map and update ALL players' stats
6. **Opponent VPIP per-action**: VPIP must be per-hand (0 or 1), preflop only. Use boolean flags, not per-action increment.
7. **Walk BB missing**: In walk hands, BB has no actions recorded. Use `findBigBlindSeat()` from blind posts to identify BB for walk counting.

### Hand Logging Bugs
1. **Pot not initialized**: Must call `initializePot()` after `startNewHand()` in ALL code paths
2. **River no winner dialog**: Handle river betting completion case explicitly
3. **Preflop gesture**: Use `gameState.isValidAction()` not `hasBetThisRound` for raise detection
4. **Hole cards lost**: Show hole cards dialog BEFORE hand completion, not after
5. **Hand ID collision**: Always use timestamp suffix in hand document IDs

### Position Bugs
1. **UTG wrong seat**: Use active player count, NOT total seats (9)
2. **Position after skip**: Skip button must call `sessionManager.startHand()` to recalculate
3. **Calculate once**: Store position name in action records at hand start, never recalculate

### Session Bugs
1. **Field name mismatch**: Ensure save and read use same field names (totalHands vs handsLogged)
2. **Final stack lost**: Call `addFinalStackEntry()` before `endSession()`
3. **Duplicate sessions**: Only ONE code path should create poker_sessions records
4. **Non-player sessions**: Check `participantIds` before updating stats for live sessions
5. **Missing buyInAmount**: Individual sessions must save BOTH `buyInAmount` AND `totalBuyIn` — analytics reads `buyInAmount` for display, `totalBuyIn` for calculations

### UI Bugs
1. **FAB hit testing**: Stack clipBehavior is visual only — add GestureDetector within Row bounds
2. **Controller disposal crash**: Move `setState()` to `.then()` callback after dialog closes
3. **Cache staleness**: Static caches must be invalidated when data changes
4. **Gradient harshness**: Apply 0.6 opacity to ALL gradient colors, use elliptical shape

### Auth/Network Bugs
1. **Auto-logout**: Firebase authStateChanges emits null on network issues → add 3s recovery delay
2. **FCM blocking**: ALL FCM operations must be fire-and-forget with 5s timeouts using `unawaited()`
3. **Blind posting stale**: Always post blinds with CURRENT player list, not previous hand's

### Environment Bugs
1. **Firestore slow writes**: Flutter 3.41.x has Firestore write performance regression → use 3.38.10
2. **iOS simulator mismatch**: Flutter 3.38 requires iOS 18.5 runtime, not iOS 26
3. **Dependency version cascade**: Upgrading Flutter requires upgrading ALL Firebase/plugin deps together
4. **Debug keystore mismatch**: Different keystore = INSTALL_FAILED_UPDATE_INCOMPATIBLE → uninstall app first

---

## Testing

### Test Files (`test/`)
Tests are organized in subdirectories mirroring `lib/`:
- `test/services/stats_calculator_test.dart` — 950+ lines, 95+ test cases for all 7 metrics
- `test/models/user_stats_test.dart` — percentage calculations and edge cases
- `test/all_in_test.dart` + `test/all_in_edge_cases_test.dart` — All-in logic
- `test/side_pot_calculator_test.dart` — Side pot calculations
- `test/services/pokerstars_export_test.dart`, `test/services/csv_export_service_test.dart` — Export
- `test/services/drill_training_test.dart`, `test/services/drill_gto_charts_test.dart` — Training drills
- `test/utils/user_facing_error_test.dart` — Error message mapping
- `test/fixtures/mock_hand_actions.dart` — Shared test fixtures
- `test/multi_pot_dialog_selection_test.dart` — Dialog selection logic

### Testing Checklist
- [ ] Test with both cash and tournament games
- [ ] Test with different player counts (2-9 players)
- [ ] Test with empty seats (e.g., 6-handed at 9-max)
- [ ] Verify stats update correctly after each hand
- [ ] Check VPIP/PFR/3-bet calculations use correct denominators
- [ ] Verify play style detection with 50+ hands
- [ ] Test with BB ante enabled and disabled
- [ ] Test blind level changes in tournaments
- [ ] Verify local storage fallback when offline
- [ ] Test all-in with side pots and chopped pots
- [ ] Test dealer mode stats track for all players
- [ ] Verify navigation confirmation on active session

### Common Debug Commands
```bash
flutter clean && flutter pub get
flutter run --debug
flutter test
flutter test test/services/stats_calculator_test.dart
```

---

## Code Style Guidelines

### Naming Conventions
- Classes: PascalCase (`HandStateManager`)
- Files: snake_case (`hand_state_machine.dart`)
- Variables: camelCase (`heroSeatNumber`)
- Constants: camelCase or SCREAMING_SNAKE_CASE

### Debug Logging
- Use `LoggerService.log(LogLevel.DEBUG, tag, message)` — never `print()` in new code
- Comment out debug logs before committing: `// print('Debug message')`
- Never commit active print statements

### Design System Usage
- **Unification in progress** — see `lib/design_system/README.md` for the phase plan and rules; run `python3 tool/design_lint.py` before committing UI work (hardcoded-value count must not increase; `--fix` auto-replaces exact token matches)
- Always use `AppColors`, `AppTypography`, `AppSpacing`, `AppDecorations` constants
- Use design system components (GlassyCard, PrimaryButton, etc.) over custom containers
- New screens must use Modern Dark theme (AppTheme), not legacy PokerFriendTheme

---

## Open Items / Known Limitations
- Position mismatch between hand card and details view (needs investigation)
- Deep link app-not-installed handling not implemented
- Hand logging screen not yet migrated to new design system (plan exists)
- Voice speaker enrollment blocked (Soniox WebSocket doesn't support speaker ID)
- No real-time sync between user devices
- Play style detection requires 50+ hands
- Session analytics endpoint not deployed on backend
- Flutter 3.41.x Firestore regression — monitor releases before upgrading
- Google Sign-In: old debug keystore SHA-1 needs registering in Firebase Console

---

**Last Updated**: March 2026
**Maintained by**: User + Claude
**Update this file**: After major feature additions, architectural changes, or new bug patterns
