# In-App Tour — Complete Working Reference

**Date**: 2026-07-15
**Branch**: design_v2
**Status**: Fully working end-to-end

---

## Overview

This is the definitive reference for the in-app onboarding tour as of July 2026. It documents the complete flow, all files involved, the state machine, every spotlight/coach mark, and the key architectural decisions that keep it stable.

---

## Complete Tour Flow

```
PHASE 0 — Home Screen
  Welcome overlay → spotlight FAB (+) button → "Start Logging"

PHASE 1 — Logging Mode Selection
  Spotlight "Full Session" option

PHASE 2 — Session Setup (Unified)
  Spotlight session details form (name, game type, blinds, buy-in, stack)
  → User fills in details → tap OK

PHASE 3 — Table/Seat Setup
  Seat dialog sub-tour → button token tour → table section tour
  → User seats hero + at least 1 opponent (2-player minimum enforced)
  → Tap Start

PHASE 4 — Hand Logging (Guided Hand)
  Hand 1:
    1. Gesture info spotlight (info icon)
    2. Scripted NPC actions (open/call/check — NEVER fold in heads-up)
    3. Hero's turn — all valid actions shown with gesture hints
    4. Adaptive reactions based on hero's choice
    5. Board cards dialog (flop/turn/river)
    6. Hole cards dialog → opponent cards
    7. "Hand Complete!" message (2s)
    8. Post-hand coach marks: Stack ring (hold an opponent's seat) →
       Blinds pill → Next Hand button → Undo button
       (skip button hidden on undo step to avoid overlap)
       [2026-07-23: stack-ring step moved here from an unreliable mid-hand
        trigger that targeted a StackRangeCircle widget which never rendered
        during the guided hand — overlay param stackRingKey replaced by an
        opponentSeatKey resolver]
    9. "Practice" prompt — log one more hand

  Hand 2:
    1. resetForSecondHand() — re-enables scripted guidance
    2. Same scripted flow as hand 1 (preserves one-time coach mark flags)
    3. Hand completes → info (i) button spotlight
    4. User taps info → SessionDetailsScreen pushed

  Session Details:
    5. Stack chart return tour (spotlight stack chart)
    6. Go-back-to-hand spotlight (back button, no skip pill)
    7. User taps back → PokerHandScreen
    8. End session menu tour (spotlight 3-dot menu → "Stop Session")
    9. User ends session → popUntil(route.isFirst) back to MainShell

[2026-07-23 funnel change — sign-up-first]
  New-user order: intro → SIGN UP (AuthScreenExperimental register mode; guest
  creation removed) → startup gate routes 'onboarding_full' → OnboardingFlow
  (nickname + survey) → Home → tour auto-starts (hasSeenOnboarding false) →
  phases 0-6 → finishOnboardingTour (non-guest): markSeen + bankroll pending +
  postTourWrapUpPending → reset '/' → Home runs the tour's FINAL beats:
  BankrollCardTour (bankroll step) → showPostTourWrapUp ("you're done" dialog
  → once-ever paywall). Guest branch (stray sessions only) unchanged: inline
  dialog → completeGuestSignup chain. AuthWrapper sends ALL anonymous
  sessions to GuestSignupGate.

PHASE 5 — Session Result (Home Screen)
  OnboardingState.notifier listener detects phase 5 on HomeScreen
  → SessionResultTour spotlights Sessions nav icon
  → Sets sessionHistoryTourPending BEFORE advanceTo(6) (ordering matters!)

  Nav bar hidden during loading splash, restored when content ready

PHASE 6 — Session Review Chain
  6a. Session History:
      sessionsTabNotifier fires when user taps Sessions nav
      → _onSessionsTabVisible() reloads sessions + triggers tour
      → SessionHistoryTour spotlights tutorial session card
      → Sets handListTourPending

  6b. Session Analytics:
      User taps session card → Navigator.push(SessionAnalyticsScreen)
      → HandListTour spotlights stack chart + "View Logged Hands" button
      → Sets handCardTourPending

  6c. Logged Hands:
      User taps button → Navigator.push(SessionHandsScreen)
      → HandCardTour spotlights a hand card (prefers one with hole cards)
      → Sets aiAnalysisTourPending

  6d. Hand Details:
      User taps hand → Navigator.push(HandActionsPageView)
      → HandToolsTour spotlights BB/export/share/star row (elliptical pill, radius 40)
      → AiAnalysisTour spotlights AI analysis button
      → _runTourAnalysis() runs free analysis, sets tourCompletionPending
      → User reads analysis...

  6e. Deferred Completion:
      User taps back → SessionHandsScreen detects tourCompletionPending
      → finishOnboardingTour():
        - OnboardingState.complete()
        - Show "Congratulations!" dialog
        - Guest → auth screen + nickname + paywall
        - Logged in → paywall (once, skippable)
        - Pop all, return to Home
```

---

## State Machine

### OnboardingState (`lib/onboarding/onboarding_state.dart`)

Static singleton tracking all tour progress:

```
isOnboardingActive: bool     — master switch
currentPhase: int            — 0-6 (7 phases total)
guidedHandPhase: GuidedPhase — sub-state within phase 4
isReplay: bool               — Knowledge Base replay (no completion side effects)
```

### GuidedPhase Enum

```
gestureInfo → scriptedAction → heroTurn → boardCards → holeCards
  → handComplete → tableButton → blindsPill → nextHandButton
  → gestureInfoTap → done
```

### Pending Flags (consumed once, set before the transition that reads them)

| Flag | Set by | Consumed by |
|------|--------|-------------|
| `seatDialogTourPending` | Phase 2 finish | Seat setup screen |
| `buttonTokenTourPending` | Seat dialog close | Seat setup screen |
| `tableTourPending` | Session details OK | Unified setup screen |
| `sessionDetailsTourPending` | Phase 3 finish | Session details screen |
| `sessionDetailsHubTourPending` | Setup → hub | Session details screen |
| `sessionDetailsExplainReturnPending` | i button visit | Poker hand screen |
| `secondTourHandPending` | Next Hand coach mark | Guided overlay |
| `stackChartReturnTourPending` | Hand 2 complete | Session details initState |
| `endSessionTourPending` | Go-back tour finish | Poker hand screen result handler |
| `tourCompletionPending` | AI analysis tour | Session hands screen return |
| `sessionHistoryTourPending` | Phase 5 finish | Session history notifier listener |
| `handListTourPending` | Session history tour | Session analytics initState |
| `handCardTourPending` | Hand list tour | Session hands initState |
| `aiAnalysisTourPending` | Hand card tour | Hand actions initState |

### Critical Ordering Rule

**Always set pending flags BEFORE calling `advanceTo()`**. The `advanceTo` method fires `_notify()` synchronously, which triggers all `ValueNotifier` listeners immediately. If the flag isn't set yet, listeners will miss it.

```dart
// CORRECT:
OnboardingState.sessionHistoryTourPending = true;
OnboardingState.advanceTo(6);

// WRONG — listener fires before flag is set:
OnboardingState.advanceTo(6);
OnboardingState.sessionHistoryTourPending = true;
```

---

## Key Architectural Decisions

### 1. Game State is the Source of Truth

The guided overlay SUGGESTS actions but NEVER overrides core hand logging logic. After any action (hero or NPC), the overlay checks `isBettingRoundComplete` from the game state to decide what happens next:

- Round complete → do nothing, let auto-advance handle street transition
- Round not complete → script next opponent action OR show hero turn

The `guidedCoachMarkActive` guard was REMOVED because it deferred auto-advance and created deadlocks. Auto-advance ALWAYS runs regardless of coach marks.

### 2. `isBettingRoundComplete` Callback

```dart
// guided_hand_overlay.dart — widget param
final bool Function()? isBettingRoundComplete;

// poker_hand_screen.dart — passed to overlay
isBettingRoundComplete: () => gameState.bettingRoundComplete,
```

This is consulted in `_handlePostHeroPreflop`, `_handlePostHeroPostflop`, and `_advanceAfterScriptedAction` to decide whether to script more actions or let the game engine handle the transition.

### 3. IndexedStack Timing

`MainShell` uses `IndexedStack` for tab screens. ALL children run `initState()` once at app startup (phase 0), not when their tab becomes visible. Tour triggers that rely on `initState()` will miss phase transitions.

**Solution pattern** (used for HomeScreen phase 5 and SessionHistoryScreen phase 6):
- Add `OnboardingState.notifier.addListener` in `initState()`
- For SessionHistoryScreen: also listen to `MainShell.sessionsTabNotifier` which fires when the Sessions tab actually becomes visible

### 4. `popUntil` vs `pushAndRemoveUntil`

When ending a tour session and returning to MainShell, use `popUntil(route.isFirst)` — NOT `pushAndRemoveUntil(MainShell())`. Creating a new MainShell with the same static `GlobalKey` causes timing issues where nav keys (`sessionsNavKey`) have null contexts during the transition.

### 5. Tour Opponents Never Fold

During the tour, NPC opponents always call (never fold). This keeps the hand alive for teaching purposes and avoids the complexity of fold-count tracking. In heads-up specifically, folding would immediately end the hand, making the tour too short to be educational.

### 6. Deferred Tour Completion

The AI analysis tour sets `tourCompletionPending = true` but does NOT call `finishOnboardingTour()` immediately. This lets the user read the analysis results without being interrupted by the completion dialog. Completion fires when the user navigates back to the session hands screen.

### 7. Nav Bar Hidden During Splash

HomeScreen hides the MainShell nav bar during its loading splash via `MainShell.of(context)?.setNavVisible(false)` and restores it when content is ready. This prevents the nav bar from appearing before the home screen content loads.

---

## File Reference

### Core Onboarding Files

| File | Purpose |
|------|---------|
| `lib/onboarding/onboarding_state.dart` | Static state machine — phases, flags, guided hand sub-state |
| `lib/onboarding/onboarding_tour.dart` | All TutorialCoachMark tour classes (phases 0-6) + `finishOnboardingTour()` + `createOnboardingCoachMark()` helper |
| `lib/onboarding/guided_hand_overlay.dart` | Phase 4 reactive overlay — scripted actions, hero turn, post-hand coach marks |
| `lib/onboarding/onboarding_progress_bar.dart` | Thin progress indicator shown during tour |
| `lib/onboarding/onboarding_prefs.dart` | SharedPreferences for seen/unseen, post-tour paywall flag |

### Tour Classes in `onboarding_tour.dart`

| Class | Phase | Spotlights |
|-------|-------|------------|
| `HomeScreenTour` | 0 | FAB button |
| `LoggingModeTour` | 1 | Full Session option |
| `SessionSetupTour` | 2 | Session form |
| `SeatSetupTour` | 3 | Seat dialog, button token, table section |
| `SessionResultTour` | 5 | Sessions nav icon |
| `SessionHistoryTour` | 6a | Tutorial session card |
| `HandListTour` | 6b | Stack chart + "View Logged Hands" button |
| `HandCardTour` | 6c | Hand card |
| `HandToolsTour` | 6d | BB/export/share/star row (elliptical pill) |
| `AiAnalysisTour` | 6e | AI analysis button |

### Screens with Tour Integration

| Screen | File | Tour involvement |
|--------|------|-----------------|
| HomeScreen | `lib/screens/home_screen.dart` | Phase 0 + phase 5 (notifier listener), nav bar splash hiding |
| LoggingModeSelectionScreen | `lib/screens/logging_mode_selection_screen.dart` | Phase 1 |
| UnifiedSessionSetupScreen | `lib/screens/unified_session_setup_screen.dart` | Phase 2+3 |
| PokerHandScreen | `lib/screens/poker_hand_screen.dart` | Phase 4 overlay host, `isBettingRoundComplete` callback, end session menu tour, `popUntil` on session end |
| SessionDetailsScreen | `lib/screens/session_details_screen.dart` | Stack chart return tour, go-back tour, `popUntil` on session end |
| SessionHistoryScreen | `lib/screens/session_history_screen.dart` | Phase 6a (notifier + sessionsTabNotifier listeners) |
| SessionAnalyticsScreen | `lib/screens/session_analytics_screen.dart` | Phase 6b |
| SessionHandsScreen | `lib/screens/session_hands_screen.dart` | Phase 6c + deferred tour completion |
| HandActionsScreen | `lib/screens/hand_actions_screen.dart` | Phase 6d-e (hand tools + AI analysis) |
| MainShell | `lib/widgets/main_shell.dart` | `sessionsTabNotifier`, nav visibility |

---

## Guided Hand Overlay — Key Methods

### Action Flow

```
NPC turn:
  _determineNextScriptedAction()
    → Sets nextScriptedAction (raise if no opener, else call; postflop: check)
    → _setPhase(scriptedAction)
  User taps "got it" → _performScriptedAction()
    → widget.onActionPerformed(action)
    → _advanceAfterScriptedAction(action)
      → Check isBettingRoundComplete
      → Round done? Return (auto-advance handles it)
      → Hero's turn? _setPhase(heroTurn)
      → Still NPCs? _determineNextScriptedAction()

Hero turn:
  _setPhase(heroTurn) — shows all valid actions
  User performs action → _advanceAfterHeroAction(action)
    → _doAdvanceAfterHeroAction(action)
      → Preflop: _handlePostHeroPreflop(action)
      → Postflop: _handlePostHeroPostflop(action)
      → Both consult isBettingRoundComplete
      → Round done? Return
      → Script next NPC action
```

### Post-Hand Coach Marks

```
_showPostHandCoachMarks()
  Target 1: Blinds pill (RRect, radius 20) — "tap to update blinds"
  Target 2: Next Hand button (RRect, radius 40) — "tap to deal next hand"
  Target 3: Undo button (RRect, radius 24) — "undo last action"
    → showSkipInLastTarget: false (prevents overlap with skip button)
  onFinish: promptSecondHand()
```

---

## Spotlight Shapes & Sizes

| Target | Shape | Radius | Padding | Notes |
|--------|-------|--------|---------|-------|
| Blinds pill | RRect | 20 | 8 | |
| Next Hand button | RRect | 40 | 4 | Pill shape |
| Undo button | RRect | 24 | 8 | Skip hidden on this step |
| Hand tools row | RRect | 40 | 6 | Elliptical pill for 4 buttons |
| Session card | RRect | 12 | 4 | |
| Hand card | RRect | 12 | | |
| AI analysis button | RRect | 16 | | |
| All coach marks | — | — | 12 | Default `paddingFocus` in `createOnboardingCoachMark` |

---

## Common Pitfalls (Lessons Learned)

1. **`numberOfPlayers` vs `getActivePlayers().length`**: `numberOfPlayers` is total seat count (9), never changes. Use `getActivePlayers().length` for blind posting, action order, heads-up detection.

2. **`_findBBSeatFromActivePlayers` offset**: Heads-up offset is +1 (BTN=SB, other=BB). Multi-way offset is +2 (BTN→SB→BB).

3. **Hub mode vs non-hub SessionDetailsScreen**: During onboarding, `PokerHandScreen` pushes a NEW non-hub `SessionDetailsScreen` when user taps info button. Tour code must handle BOTH paths.

4. **TutorialCoachMark + nested Rows**: A `GlobalKey` on a `Row` inside another `Row` may not report correct bounds. Wrap in a `Container` for a dedicated RenderBox.

5. **Tour session summary card**: Skip for tour sessions ($0 profit is meaningless, risks blocking phase-5 handoff).

6. **SharedPreferences user-scoping**: Any per-user data must be scoped with userId or cleared on logout.

7. **`advanceTo()` notifier ordering**: Set pending flags BEFORE calling `advanceTo()`. The notifier fires synchronously inside `advanceTo`.

8. **`pushAndRemoveUntil` kills GlobalKeys**: Creating a new MainShell widget reuses the same static GlobalKey, causing null contexts on nav keys during transition. Use `popUntil(route.isFirst)` instead.

9. **IndexedStack initState timing**: All tab children run `initState()` at app startup, not when their tab becomes active. Use `ValueNotifier` listeners for deferred tour triggers.

10. **Auto-advance must always run**: Never gate auto-advance behind overlay state flags. The game state (`bettingRoundComplete`) is the only source of truth for when rounds end and streets advance.

---

## Testing Checklist

- [ ] Fresh install → full tour end-to-end: phase 0 through phase 6 completion
- [ ] Tour with 2 players (heads-up): hero SB calls → BB checks → flop dealt
- [ ] Tour with 2 players: hero folds postflop → hand ends immediately
- [ ] Tour with 3+ players: opener raises, hero acts, remaining call
- [ ] Hand 2 scripted guidance re-activates after hand 1
- [ ] Post-hand coach marks: blinds → next hand → undo (no skip overlap on undo)
- [ ] Session end: 3-dot menu → stop → popUntil to MainShell → Sessions nav spotlight
- [ ] Phase 6 chain: session card → analytics → logged hands → hand card → hand tools (elliptical) → AI analysis → completion
- [ ] Nav bar hidden during home loading splash
- [ ] Replay from Knowledge Base (Settings → Learn the App → Logging a Hand)
- [ ] Non-tour hand logging: completely unaffected by overlay code
- [ ] Skip tour at any point: clears all flags, returns to normal state
