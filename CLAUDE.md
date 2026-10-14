# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Poker Friend - Project Documentation

## Overview
Flutter/Dart poker hand logging application with Firebase backend, club management, dealer-assisted voice logging, and real-time WebSocket sync. Allows users to track poker hands, sessions, statistics, opponents, and bankroll.

**The app is LIVE** (v2.1.0+14 submitted to Google Play on launch night 2026-07-24; iOS submission pending). Current working version: 2.1.3+17 (DAU heartbeat, Settings→"Menu" rename, feature-flagged Leak Detector). Post-launch work is queued in `ROADMAP.md` — check it before planning any change.

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

# Cloud Functions (run from functions/)
npm run build            # tsc compile
npm run deploy           # firebase deploy --only functions
npm run logs             # firebase functions:log

# Deploy Firestore rules (editing firestore.rules alone does nothing live)
firebase deploy --only firestore:rules
```

---

## Project Rules
- **Language of answers**: Write all answers and results to the user in ASD-STE100 Simplified Technical English. Use short sentences. Use the active voice. Use simple approved words. Give one instruction for each sentence.
- **DO NOT push to git unless explicitly asked by user**
- **DO NOT commit unless explicitly asked by user**
- **Authoritative docs**: `BUG_TRACKER.md` (live status of hand-logging bugs + features in flight), `test/HAND_LOGGING_SPEC.md` (hand-logging behaviour spec + bug diagnoses), `POKER_SEATING_RULES.md` (seating/dead-button rules), `ROADMAP.md` (post-launch work queue incl. HARD Aug 31 2026 Play Billing deadline + deferred security fixes), `SECURITY_AUDIT_2026-07-23.md` (audit findings + per-item status), `BACKLOG.md` (triaged product backlog with stable B#/U#/F#/M#/G# IDs). Check these before touching hand-logging code, and check ROADMAP.md before planning any update.
- **`marketing/` folder**: `MARKETING_MASTER.md` is the single-file source of truth for the marketing agent; video scripts and prompts live alongside it. Not app code.
- **`docs/` folder**: reference docs (`ARCHITECTURE.md`, `SERVICES.md`, `SCREENS.md`, `NAVIGATION.md`, `STATE.md`, `DESIGN_SYSTEM.md`, `SUBSCRIPTIONS.md`, `GLOSSARY.md`) plus feature specs — **`docs/social-feed-spec.md` is the decision record for the social feed** (D1–D11); any feed/follow change must respect it.
- Always check `/diary` folder for previously solved bugs before implementing fixes. Treat every entry there as authoritative documentation of the current behaviour — respect it and do not break it. **In particular, `/diary/2026-07-15-in-app-tour-complete-reference.md` is the canonical reference for the in-app tour flow: any change touching onboarding, guided overlays, tour phases, `OnboardingState`, `guided_hand_overlay`, `onboarding_tour`, or the screens the tour highlights (home, session details, poker hand, session end) must preserve the behaviour documented there.**
- Create diary entry after user confirms a fix
- Never commit debug logging, unnecessary files, or unstabilized code
- Wait for user confirmation before any git operations
- **After work is done and branch has been pushed: always open a PR targeting the `design_v2` branch** (not `main`)
- **Responsive Design (CRITICAL)**: All UI sizing, spacing, padding, font sizes, and layout dimensions MUST be responsive across different device sizes. Do NOT hardcode pixel values that only work on one device (e.g., iPhone 16 Pro). Use `MediaQuery`, `LayoutBuilder`, `FractionallySizedBox`, `Flexible`, `FittedBox`, relative sizing, or screen-fraction-based calculations to ensure the app looks correct on iPhone 11, iPhone 13, iPhone 16 Pro, and various Android devices. When implementing Figma designs, treat pixel values as reference for proportions, not absolute values.

---

## Development Environment

Full machine setup (tool versions, keystores, step-by-step install) lives in `SETUP.md`.

### CRITICAL: Flutter Version Constraint
- **Flutter 3.38.10** — DO NOT upgrade to 3.41.x (Firestore write performance regression)
- **Dart**: 3.9.x (bundled with Flutter 3.38.10)
- **Xcode**: 26.3
- Monitor Flutter releases for the Firestore regression fix before upgrading
- See `diary/2026-03-29-flutter-firestore-regression-fix.md` for full details

### iOS Simulator
- Runner iOS deployment target: **15.5** (raised from 13.0, commit 3aaabf4)
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
- Key version constraints: cloud_firestore ^5.5.0, firebase_core ^3.8.0, purchases_flutter ^9.15.1 (bundles Play Billing 8 — required for Play updates after Aug 31 2026)
- API differences exist between old and new versions (positional vs named params) — see diary entry
- RevenueCat SDK calls are isolated in `lib/services/revenuecat_client.dart` — a future purchases_flutter bump should only touch that file (see Subscription section)

---

## Architecture

### Tech Stack
- **Frontend**: Flutter/Dart (300+ Dart files)
- **Backend**: Firebase (Firestore, Auth, FCM, Cloud Functions in `functions/`) + FastAPI backend (Render)
- **Local Storage**: SQLite (sqflite, DB schema v19) + SharedPreferences
- **Real-time**: Socket.IO WebSocket + Firestore Snapshot listeners
- **Voice Recognition**: Deepgram ASR via backend "Dealer Brain" endpoint
- **Payments**: RevenueCat SDK
- **State Management**: StatefulWidget pattern (no Provider/BLoC/Riverpod — **exception**: the dealer voice pipeline uses `flutter_bloc` via `lib/features/dealer_voice/cubit/`)
- **Localization**: Flutter's built-in `gen-l10n` system; `.arb` files in `lib/l10n/`; 11 locales: EN, DE, ES, FR, IT, PT, RO, RU, PL, SK, UK. Use `AppLocalizations.of(context)` — never hardcode UI strings. When enumerating locales, list `lib/l10n/app_*.arb` dynamically — don't trust hardcoded lists.
- **Note**: the root `package.json` and `src/` are a legacy TypeScript prototype ("poker-logger") — NOT the app and NOT the Cloud Functions. The real Functions codebase is `functions/` (own `package.json`).

### Cloud Functions (`functions/src/index.ts`)
Node 20 / TypeScript, firebase-functions v7. Deploy with `npm run deploy` from `functions/`. Current functions:
- `sendPushNotification` — FCM push on `user_notifications` doc create
- `sendClubNotification` — topic-based FCM to all club members
- `grantFreeMonthOnSignup` — launch promo: RevenueCat promotional Pro month on `users/{uid}` create, gated by `app_config/promotions.freeMonthOnSignup`
- `cleanupOldTokens` — daily scheduled FCM token cleanup
- `notifyFollowersOnSessionStart` — social feed: one FCM topic message (`live_{userId}`) on `feed_sessions` create — no per-follower fan-out
- `revenuecatWebhook` — mirrors subscription tier onto `users/{uid}` (`subscriptionTier` + `subscriptionTierExpiresAt`) by re-fetching the subscriber from the RC REST API on every event; Firestore rules use the mirror to gate paid features (rules can't see RC entitlements)
- `coachSpeech` — Daily Challenge neural coach voice: ElevenLabs TTS proxy (key in Secret Manager `ELEVENLABS_API_KEY`, never in the app), Firebase-Auth-gated, caches MP3s in Storage keyed by sha256(voiceId|coach|text) with download tokens; persona→voice casting lives server-side (deployed 2026-10-14)

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
Loaded at startup via `flutter_dotenv`. Required keys: `SONIOX_API_KEY`, `REVENUECAT_IOS_API_KEY`, `REVENUECAT_ANDROID_API_KEY`, `RESEND_API_KEY`, `AI_API_KEY`, `WEBSOCKET_SERVER_URL`, `API_SERVER_URL`, `ENVIRONMENT`; optional `POSTHOG_API_KEY` (analytics silently disabled without it). Access via `EnvConfig.*` (never `dotenv.env` directly).

### Subscription Tiers (RevenueCat)
**Play Billing 8 migration SHIPPED 2026-08-05** (`purchases_flutter` 8.11.0 → ^9.15.1, bundles `com.android.billingclient:billing:8.0.0` — required for Play updates after Aug 31 2026). Unit tests + Gradle build verified; **on-device sandbox matrix NOT yet run** (all 6 packages, restore, cancel-and-repurchase override, external cancellation on resume, promo entitlement) — run it before the next store release.

The subscription code is split into three layers (keep it that way):
- `lib/services/subscription_service.dart` — orchestration + cached state; the API the app calls
- `lib/services/revenuecat_client.dart` — the ONLY place `Purchases.*` is called (`LiveRevenueCatClient`); returns app-owned value types (`TierEntitlements`, `PurchaseOutcome`) so SDK version differences are absorbed here. Tests inject `FakeRevenueCatClient` via `SubscriptionService.debugSetClient()`
- `lib/services/subscription_logic.dart` — pure tier/override/package-resolution functions (no SDK, no static state); package-ID constants (`kPkg*`) live here and must match the RevenueCat dashboard. Pro uses the standard `$rc_monthly`/`$rc_annual` identifiers; Elite/Club use custom ones

Launch promo: new sign-ups can receive a free Pro month as a RevenueCat **promotional** entitlement (admin-toggled in User Management). `TierEntitlements.proIsPromotional`/`proExpirationIso` carry this; promo expiry notifications fire 1 day before.

Four tiers — check via `SubscriptionService`:
- **Free**: 10 hands/session, 5 opponents, 30-day session history
- **Pro** (`isPro`/`isPremium`): 50 hands/session, 30 opponents, 90-day history
- **Elite** (`isElite`/`isPremium`): unlimited everything, AI analysis, all history
- **Club** (`isClub`/`isPremium`): like Elite + club creation rights (owner pays; club members operate freely regardless of their own tier)

Feature gates live in `lib/services/free_tier_limits.dart` (hand/opponent caps) and `lib/services/feature_flag_service.dart` (remote Firestore flags for `training_drills`, `ai_hand_analysis`, `leak_detector`, `daily_challenge`). Use `FreeTierLimits.showHandsLimitDialog()` / `PaywallScreen.show()` for upgrade prompts.

**Partner grants** (`lib/services/partner_grant_service.dart`): super-admin can grant users a free tier (Pro/Elite/Club) with expiry (1 week / 1 month / 3 months). `partnerTier` getter returns `null` for expired grants client-side; `init()` awaits the first Firestore snapshot (3s timeout) and must be `await`ed in sign-in paths (not `unawaited`) or the user briefly appears free-tier. Admin UI: `lib/screens/admin/partner_grants_screen.dart`. See `diary/2026-07-08-partner-grants-system.md`.

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

### 1b. Live Scouting Mode
- Opt-in setting (`SkipHandScoutingService`, gated behind the `training_drills` feature flag): when the hero folds preflop, the logger enters scouting mode — keep logging opponents' real preflop actions (type-only, no bet sizes) and finish the hand early
- Saved as a preflop-only record with `isScouted: true`; feeds **opponent** stats (incl. winner → Showdown stat) but hero stat gating is split so scouted hands don't distort hero postflop stats
- Entry points: `poker_hand_screen.dart` `_scoutingMode` / `_finishScoutedHand`

### 2. Individual Session Tracking (Quick Logging)
- Quick profit/loss tracking without full hand details
- Records: start time, end time, profit/loss, session name
- Does NOT update hand-based stats (VPIP, PFR, etc.)

### 2b. Post-Session Summary Card (`lib/widgets/session_summary_card.dart`)
- Shareable PNG card shown after ending any session (full or quick logging)
- Shows: session name, game type badge, duration, net P/L, hands played, biggest pot, best/worst hand
- **Cash**: Net P/L = `finalStack - totalBuyIn` (both in currency)
- **Tournament**: Net P/L = `prizeWon - totalBuyIn` from `SessionEndBankrollSheet` result (NEVER use chips - money). Also shows placement (e.g., "11th / 28"), prize won, and net profit
- **Biggest pot**: Cash shows currency; Tournament shows BB equivalent (`biggestPot / biggestPotBB` where `biggestPotBB` is the BB level when the biggest pot occurred). **Selection is BB-relative for tournaments** (`PokerSessionManager.updateBiggestPot`): pots are compared as `pot / currentBB`, NOT absolute chips — blind levels grow ~100x across an MTT, so absolute comparison let a late 7 BB pot displace an early 317 BB pot (bug 2026-08-04). Cash keeps absolute comparison. `biggestPotBB` is persisted on the session doc.
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
| 3-Bet | threeBetCount | threeBetOpportunity | The 2nd **voluntary** raise preflop (open=1st voluntary raise, 3-bet=2nd). Blinds are NOT an open. |
| Fold-3Bet | fold3betCount | facing3BetCount | Opened (1st voluntary raise), the 2nd voluntary raise (a 3-bet) happened, player folded |
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
- **Unknown**: ONLY when < 50 hands or zeroed stats. With a full sample the detector is total: specific branches first, then a coarse quadrant fallback (tight/loose at VPIP 22 × aggressive/passive at AF 2 or PFR/VPIP ≥ 0.6) — it must never return Unknown for ≥50 hands (bug 2026-08-04: home tile showed "762/50" for a profile no branch matched). Home tile renders `N/50` only when N < 50. Tests: `test/services/play_style_detector_test.dart` (includes an exhaustive no-holes sweep).

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

### 11. Training Drills
- GTO practice drills (gated by `training_drills` feature flag): open-raise/3-bet/blind-defend charts, Nash push-fold
- Engine/grading/data in `lib/services/drill_*.dart`; screens in `lib/screens/training/` (`drill_setup_screen`, `drill_table_screen`)
- Tests: `test/services/drill_*_test.dart`

### 12. Range Grid
- `RangeGridService` (`lib/services/range_grid_service.dart`) indexes hero hands into a 13×13 range grid; dedupe key `{sessionId}:{handNumber}` merges local SQLite and Firestore copies of the same hand; cloud backfill via `range_grid_cloud_backfill.dart`
- `primaryAction` is the hero's FIRST voluntary preflop action: `'allin' | 'raise' | 'call' | 'fold' | 'check'`. `'allin'` means an explicit jam only — an all-in CALL stays `'call'` (a call is never aggressive). Changing this classification requires bumping the backfill flag key (`range_grid_backfilled_vN`) so existing local indexes rebuild
- Grid cell colors are tokenized in `AppColors` (`rangeRaise`/`rangeCall`/`rangeFold`/`rangeAllIn`; check uses `accentPrimary`); all-in is hidden by default in the grid and chip-toggled

### 13. In-App Tour / Onboarding
- Guided first-hand tour lives in `lib/onboarding/` (`onboarding_tour.dart`, `guided_hand_overlay.dart`, `onboarding_state.dart`)
- Tour hands are NOT persisted (`OnboardingState.isGuidedHandActive` guard in save path)
- **Canonical reference: `diary/2026-07-15-in-app-tour-complete-reference.md`** — see Project Rules

### 14. Social Feed (ON HOLD — client code lives in git stash "social-feed-client-phases-1-3", deliberately NOT in the billing-update release; backend rules/CFs ARE committed and deployed. Spec: `docs/social-feed-spec.md`)
Follow other players and "rail" their shared sessions: delayed stack chart + hand replay, plus 48h recap cards. Key invariants (all from the spec's decision record — read it before changing anything):
- **Paid-only hard wall** (D9/D10): free users see no entry points; Firestore rules independently enforce via the tier mirrored on `users/{uid}` by `revenuecatWebhook`. Client checks are UX, not security.
- **1-hour lag** (D5/D6): presence is immediate; hands + stack lag via `visibleAt` stamps that rules enforce (`request.time >= visibleAt`). ⚠️ `FeedPublisher.lag` is currently `Duration.zero` **for testing only** — rules deliberately don't enforce a minimum, so this constant is the only privacy barrier. **Restore `Duration(hours: 1)` before any release.**
- **Sanitization is a privacy guarantee** (D11): `feed_sanitizer.dart` is pure functions (unit-tested in `test/services/feed_sanitizer_test.dart`); non-hero seats render as positions (BTN/SB/…) or `P{seat}`, real `playerNames`/`playerIds` stripped, non-hero showdown cards stripped in ALL modes, hero cards only in `cards` mode.
- **Client dual-write** (D6): `feed_publisher.dart` writes sanitized copies to `feed_sessions`/`feed_hands`/`feed_stack`; every method is best-effort (feed failures must never break gameplay).
- Per-session share modes: `off` / `no_cards` / `cards` (`FeedShareMode`), default from settings.
- Files: services `feed_sanitizer.dart`, `feed_publisher.dart`, `feed_service.dart`, `follow_service.dart` (follow graph: `follows/{follower}_{followed}`, `blocks/{blocker}_{blocked}`, FCM topic `live_{uid}` subscribe on follow); screens `lib/screens/social/` (feed, rail viewer, public profile, follows, find players); home entry `lib/widgets/live_now_strip.dart`.
- Phase 4 (bell-mute UI) + tier-mirror backfill for existing subscribers are outstanding — see MEMORY/ROADMAP before shipping.

### 15. Leak Detector (feature-flagged: `leak_detector`)
Frequency-based leak coaching over the player's own hand history. Design doc: `docs/features/leak-detector.md` — read it before changing bands/detectors. Three layers, all pure below the service:
- `lib/services/leak_extractor.dart` (phase 1) — per-hand fact extraction (hand map → `LeakHandFacts`); reuses `StatsCalculator` for spots it already detects — never re-derive tested detection logic
- `lib/services/leak_engine.dart` (phase 2) — frequency detectors + coach layer. A leak is a deviation from a healthy BAND, not a raw number; every detector has minimum samples (below them → "not enough data", never a verdict); every finding explains meaning/cost/fix + example hands. Money view is BB-normalized TOTALS (not per-hand rates on tiny n)
- `lib/services/leak_report_service.dart` — loads ALL user hands from Firestore and aggregates at read time (deliberately NO incremental counters — see stats double-counting history); excludes tutorial sessions, quick sessions, scouted hands. Returns `LeakReportBundle` (report + raw hands keyed by ref for "show me the hand" drill-through)
- Supporting pure helpers: `board_texture.dart` (flop texture classification), `flop_strength.dart` (hero flop strength labels)
- Screen: `lib/screens/leak_detector_screen.dart` (entry from Settings/"Menu" screen). Tests: `test/services/leak_detector_test.dart`, `test/services/flop_strength_test.dart`

### 16. DAU Heartbeat
`ActivityHeartbeatService` (`lib/services/activity_heartbeat_service.dart`) stamps `users/{uid}.lastActiveAt` (server timestamp) on sign-in and app foreground, throttled to once/hour via SharedPreferences. Fire-and-forget like FCM/analytics — must never break the app. The admin dashboard's daily cron counts these into `daily_stats` (dashboard lives outside this repo). Test: `test/services/activity_heartbeat_test.dart`.

### 17. LED Range Board (EXPERIMENTAL)
Physical 13×13 range display (ESP32 + WS2812B), firmware in `hardware/led-range-board/` (`led_range_board.ino`). `lib/services/led_grid_publisher.dart` encodes the range grid into a 1014-char hex payload (3 bytes/cell: raise/call/check/fold shares largest-remainder-normalized to 15, + intensity) and pushes over local HTTP. The wire spec stays 4-action even though the app tracks all-in separately — all-in jams count into the raise share (v0; v1 plan = Firebase RTDB). **Payload spec is shared with the .ino — keep both in sync.** Docs: `docs/features/led-board-live-range.md`, `led-board-gtow-import.md`. Test: `test/services/led_grid_publisher_test.dart`.

### 18. Daily Challenge (feature-flagged: `daily_challenge`)
Chess.com-style daily ritual: 5 preflop decisions on the drill table, graded move-by-move by a "talking" coach (typed-text bubble + verdict badge + haptic ladder), with streaks and a Wordle-style spoiler-safe share. The spot set is **identical for every user per calendar day** — `DailyChallengeService.configFor(date)` picks a weekday theme (stack depth/table size/format; ≤20BB days grade on Nash) and seeds the drill engine with `Random(yyyymmdd)`. Determinism contract: generic bots only, never the user's real opponents. Layers: `lib/services/daily_challenge_service.dart` (pure config/seed/verdicts/share), `lib/services/daily_challenge_store.dart` (SharedPreferences results + streak math; streak survives a pending today, breaks on a missed day), `lib/screens/training/daily_challenge_screen.dart` (intro/results host), challenge mode on `DrillTableScreen` (`rng` + `challengeDecisions` params), home-screen entry card. Each graded decision also offers **Show range** (engine `lastGradedContext` → pure `DrillRangeLookup.chartFor` mirrors the grader's baseline selection → `drill_range_chart_grid.dart` with the hero hand ringed) and a **speaking coach** with selectable **personas** (`coach_persona.dart`: Duke/Prof. Vega/Nova — original characters only, never real players; character leads wrap the reason, picker on the intro). The voice is **neural only** (no device-TTS fallback): `CoachVoiceService.speak(coachId:)` hits the `coachSpeech` CF (ElevenLabs behind Firebase Auth, Storage + on-device MP3 caching keyed by voiceId|coach|text), stays quiet on failure. Verdict is gated until the voice is ready (text+voice land together); card suits glow when the coach names the hand. One attempt counts per day; abandoning records nothing. The coach also **adapts its tone+depth to the player's experience tier** (beginner/intermediate/advanced): `coach_level_resolver.dart` resolves the tier from real play once the hand sample is meaningful, falling back to the onboarding "poker journey" self-report while the sample is thin (pure functions; the IO wrapper reads Firestore in the caller/CF). The AI teaching line per spot×coach×level comes from `daily_coach_lines_service.dart` (`DailyCoachLinesService.lineFor`, READS `daily_challenge_lines/{dayKey}`, falls back to persona templates on miss). Lines are generated MANUALLY out of band (maintainer/Claude): a gitignored Dart dev tool `tool/daily_lines/print_spots_test.dart` prints a day's spot facts from the real engine, Claude writes the per-coach/per-level lines, and they are stored to `daily_challenge_lines/{dayKey}` (read-only to clients). No in-app upload, no Cloud Function trigger. Each persona renders as a 3D mascot still with a one-shot bounce/head-shake (`lib/widgets/coach_mascot.dart`, assets `assets/mascots/{persona}_{expression}.png`, vector painter fallback). Debug hooks: `CoachLevelResolver.debugOverride` (force a tier) and `DailyChallengeService.debugDayOffset` (shift "today") are in-memory, not persisted, and default to no-ops — the admin "Daily Challenge Tester" screen that drives them is kept out of the shipped tree on purpose. Doc: `docs/features/daily-challenge.md`. Tests: `test/services/daily_challenge_test.dart`, `test/services/drill_range_lookup_test.dart`, `test/services/coach_level_resolver_test.dart`, `test/services/coach_persona_test.dart`.

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
  'isStarred': bool?, 'tags': List<String>?, 'notes': String?,
  'isScouted': bool?  // preflop-only scouting record (hero folded, opponents logged)
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
A 3-bet is the **2nd voluntary raise** preflop. Blinds are forced bets, NOT an
open — they do NOT count as raises. Counting voluntary raises only:
- 1st voluntary raise = the open ("2-bet"; a limp/call before it is not an open)
- 2nd voluntary raise = **3-bet**
- 3rd voluntary raise = 4-bet, etc.
```dart
int raiseCount = 0;
for action in preflop_actions:
  if isRaiseAction(action):   // excludes blinds; includes all-in
    raiseCount++;
    if raiseCount == 2 && action.player == hero:
      return true;  // THIS is a 3-bet (the re-raise over the open)
```
- All-in counts as a raise for detection purposes
- `hadThreeBetOpportunity`: exactly 1 voluntary raise (the open) already happened when the player acts. Does NOT count 4-bet opportunities (2+ prior raises).
- `facedThreeBet`: player opened (1st voluntary raise), then the 2nd voluntary raise (a 3-bet) happened by someone else
- `didFoldTo3Bet`: facing a 3-bet and folded

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
| LocalStorageService | `lib/services/local_storage_service.dart` | SQLite mirror of Firebase (schema v19) |
| UserStatsService | `lib/services/user_stats_service.dart` | Atomic user stat transactions |
| OpponentStatsService | `lib/services/opponent_stats_service.dart` | Atomic opponent stat transactions |
| StatsCalculator | `lib/services/stats_calculator.dart` | Pure stat detection functions (testable) |
| PlayStyleDetector | `lib/services/play_style_detector.dart` | Player classification |
| BankrollService | `lib/services/bankroll_service.dart` | Bankroll goals + stats aggregation |
| AuthService | `lib/services/auth_service.dart` | Firebase Auth wrapper. Forgot-password uses Firebase's built-in reset email; the branded reset page is NOT in this repo — it lives in the separate `final-table-web` repo (finaltable.io/reset_password, deployed via Vercel) |

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
| SubscriptionService | `lib/services/subscription_service.dart` | Subscription orchestration (see Subscription section for the 3-layer split with `revenuecat_client.dart` + `subscription_logic.dart`) |
| FCMService | `lib/services/fcm_service.dart` | Push notifications (fire-and-forget!) |
| DeepLinkService | `lib/services/deep_link_service.dart` | Email invitation deep links |
| AiAnalyzerService | `lib/services/ai_analyzer_service.dart` | Hand analysis API calls |
| FeatureFlagService | `lib/services/feature_flag_service.dart` | Global remote feature flags (Firestore `app_config/feature_flags`, super-admin toggles on Profile, offline cache). Gated: training_drills, ai_hand_analysis, leak_detector, daily_challenge |
| AnalyticsService | `lib/services/analytics_service.dart` | PostHog product analytics (EU cloud). distinct_id = Firebase uid (matches RevenueCat customer_id — the warehouse join key); identity auto-follows authStateChanges. Event vocabulary lives in the service header — fire each event at ONE canonical site only. All calls fire-and-forget/no-throw; no-op without `POSTHOG_API_KEY` (tests, dev) |
| PartnerGrantService | `lib/services/partner_grant_service.dart` | Admin-granted free tiers with expiry (see Subscription section) |
| SkipHandScoutingService | `lib/services/skip_hand_scouting_service.dart` | On/off toggle for live scouting mode |
| RangeGridService | `lib/services/range_grid_service.dart` | Hero hand range-grid index (local+cloud dedupe) |
| ActivityHeartbeatService | `lib/services/activity_heartbeat_service.dart` | DAU heartbeat: `users/{uid}.lastActiveAt`, 1h throttle, fire-and-forget |
| Leak Detector services | `lib/services/leak_extractor.dart`, `leak_engine.dart`, `leak_report_service.dart` | Frequency leak coaching (see Key Feature 15) |
| LedGridPublisher | `lib/services/led_grid_publisher.dart` | Experimental ESP32 LED range board payload + push (see Key Feature 17) |
| StatsVerificationService | `lib/services/stats_verification_service.dart` | Debug audit: recompute stats from raw hands, print report |
| Drill services | `lib/services/drill_*.dart` | Training drills: engine, grader, GTO charts, Nash push-fold |

### Social Feed Services (see Key Feature 14)
| Service | File | Purpose |
|---------|------|---------|
| FeedSanitizer | `lib/services/feed_sanitizer.dart` | Pure sanitization (identity/card stripping) — privacy-critical, unit-tested |
| FeedPublisher | `lib/services/feed_publisher.dart` | Best-effort dual-write of sanitized, delay-stamped feed docs |
| FeedService | `lib/services/feed_service.dart` | Follower-side reads: live sessions, recaps, rail data |
| FollowService | `lib/services/follow_service.dart` | Follow graph, blocks, FCM `live_{uid}` topic subscriptions |

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
| Session Setup | `lib/screens/unified_session_setup_screen.dart` | Unified full/quick session setup |
| Paywall | `lib/screens/paywall_screen.dart` | 3 paid tiers, `preselectedTier` param |
| Admin | `lib/screens/admin/` | Partner grants, club requests, support requests (super-admin only) |
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
  uid, displayName, displayNameLower, email, createdAt, updatedAt,
  lastActiveAt?,   — DAU heartbeat (ActivityHeartbeatService), server timestamp, ≤1/hour
  subscriptionTier?, subscriptionTierExpiresAt?   — mirrored by revenuecatWebhook CF; rules gate paid features on these

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
  biggestPot, biggestPotBB, isIndividualSession, buyInAmount, totalBuyIn,
  startingStack, currentStack, stackHistory, participantIds, isLive,
  isDealerSession, finishedPlace?, fieldSize?, prizeWon?
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

partner_grants/{grantId}/
  userId, tier, status ('active'|'expired'|'revoked'), expiresAt (Timestamp)

follows/{followerId}_{followedId}/ — follow edge + denormalized display names
blocks/{blockerId}_{blockedId}/    — existence denies future follow creates in rules

feed_sessions/{sessionId}/    — sanitized session presence + stackHistory copy (social feed)
feed_hands/{...}/             — sanitized hand copies, visibleAt-stamped
feed_stack/{...}/             — sanitized stack entries, visibleAt-stamped

app_admins/{userId}/          — super-admin allowlist
club_requests/{requestId}/    — club registration requests (admin approves)
support_requests/{requestId}/ — in-app support requests
app_config/                   — feature_flags, promotions (super-admin toggles)
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
- All money/chip inputs accept comma OR dot as decimal separator via `DecimalInputFormatter` + `parseDecimal()` (`lib/utils/decimal_input.dart`) — see UI Bugs pattern 5
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
3. **3-bet = 2nd voluntary raise**: Count voluntary raises preflop: open=1st, 3-bet=2nd, 4-bet=3rd. Blinds are forced (not an open) and don't count.
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
6. **Short-stack clamp crash**: `double.clamp(min, max)` throws when min > max — any bet/raise amount clamp must first check whether the player's stack is below the minimum and resolve it as all-in for less (Crashlytics 90a88414; see `test/short_stack_bet_clamp_test.dart`)

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
5. **Comma decimal separator**: EVERY money/chip/blind text input must use `DecimalInputFormatter` and be parsed with `parseDecimal()` (`lib/utils/decimal_input.dart`) — never `FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))` (silently deletes the comma: RO user typing "50,00" got BB 5000) and never bare `double.tryParse` on user-typed text

### Firestore Rules Bugs
1. **Admin-on-behalf-of-user writes**: flows the super admin performs FOR another user (club-request approval writes the new owner's `dealers/{uid}` doc and updates a club whose `ownerId` is the requester) need explicit `isSuperAdmin()` allowances in `firestore.rules` — owner-only rules deny them (production bug 2026-08-02, fixed + deployed). When adding admin flows, trace EVERY write against the rules.
2. Rules changes must be deployed (`firebase deploy --only firestore:rules`) — editing the file does nothing live. Smoke-test club flows after any rules scoping change (ROADMAP item 3).

### Tournament Math Bugs
1. **Never compare chip amounts across blind levels**: blinds grow ~100x in an MTT. Biggest-pot uses BB-relative comparison; best/worst hand uses pot-to-stack ratio. Any new "biggest/best X" tournament stat must normalize by BB level or stack.

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
- `test/HAND_LOGGING_SPEC.md` — hand-logging behaviour spec (bug diagnoses live here, not in code comments)
- Hand-logging regression suite: `hand_logging_edge_cases_test.dart`, `raise_gesture_mode_test.dart`, `seating_boundary_test.dart`, `shown_cards_test.dart`, `table_change_discard_test.dart`, `side_pot_display_test.dart`
- `test/onboarding_state_test.dart` — tour state machine
- `test/services/subscription_logic_test.dart` + `test/services/subscription_service_test.dart` — tier resolution, purchase overrides, service flow against `FakeRevenueCatClient`
- `test/services/feed_sanitizer_test.dart` — social feed privacy guarantees (identity/card stripping) — treat failures here as privacy leaks, not glitches
- `test/services/leak_detector_test.dart`, `test/services/flop_strength_test.dart` — leak detector extraction/bands
- `test/services/daily_challenge_test.dart` — Daily Challenge shared-puzzle determinism, verdict/score mapping, streak math
- `test/services/activity_heartbeat_test.dart`, `test/services/led_grid_publisher_test.dart`, `test/short_stack_bet_clamp_test.dart`

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
- ⚠️ **Club rules hardening (audit B5, commit 725c067) committed but NOT yet deployed** — run `firebase deploy --only firestore:rules` together with a club smoke test (invitation, approval, role flows)
- ⚠️ **Social feed lag disabled for testing**: the STASHED `FeedPublisher.lag = Duration.zero` — restore `Duration(hours: 1)` when the feed stash is popped, before ANY release with feed code (see Key Feature 14)
- Social feed tier-mirror backfill for existing subscribers not run (rules deny paid users until their next RevenueCat event)
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

**Last Updated**: October 7, 2026
**Maintained by**: User + Claude
**Update this file**: After major feature additions, architectural changes, or new bug patterns
