# Tour Flow: Hand 2 Guidance, Post-Hand Spotlights & Session End

**Date**: 2026-07-13
**Status**: Fixed

## Problem
Several gaps in the onboarding tour (Phase 4):
1. After hand 1 completed, hand 2 had no scripted guidance (GuidedPhase was set to `done`)
2. BB pill and Next Hand button spotlights were defined in ARB files but never wired
3. The tour stalled after the stack chart with no guidance on ending the session
4. Manual bet gesture ("press & drag down") was never shown during gameplay
5. "Got it" / "Done" button in last tooltip was right-aligned instead of centered

## Solution

### Post-hand 1 spotlights (`guided_hand_overlay.dart`)
- Added `_showPostHandCoachMarks()` — after "Hand Complete!" 2s delay, spotlights BB pill (RRect) then Next Hand button (RRect radius 40, padding 4 to match pill size) before prompting hand 2

### Hand 2 scripted guidance (`guided_hand_overlay.dart` + `onboarding_state.dart`)
- Added `OnboardingState.resetForSecondHand()` — resets `guidedHandPhase` to `scriptedAction`, clears `openerSeat`/`heroFolded`, preserves one-time coach mark flags
- `promptSecondHand()` onFinish now calls `resetForSecondHand()` + `_beginScriptedHand()` after a 300ms delay so hand 2 gets full scripted opponent/hero guidance

### Manual bet hint (`guided_hand_overlay.dart`)
- `_buildHeroInstruction()` now appends "Manual bet: Press & drag down ↓" when bet/raise is valid

### Session end guidance (`session_details_screen.dart`)
- `_showEndSessionTour()` spotlights the 3-dot menu (`_dotsKey`) with instruction to tap it and select "End Session"
- User ends session themselves (no auto-end) — `_endSessionFromHub()` already handles `advanceTo(5)`
- Chained from `_showStackChartReturnTour()` onFinish

### Centered Done button (`onboarding_tour.dart`)
- `buildTooltip()` now centers the button when `isLast: true` (last step in a coach mark sequence)

### l10n updates (all 7 ARB files)
- New: `guidedGestureManualBet`, `guidedEndSessionHubBody`
- Updated: `guidedHandTwoBody` (practice-oriented text), `guidedEndSessionBody` (matched actual menu label "End Session" in all languages)

## Files Changed
- `lib/onboarding/guided_hand_overlay.dart`
- `lib/onboarding/onboarding_state.dart`
- `lib/onboarding/onboarding_tour.dart`
- `lib/screens/session_details_screen.dart`
- `lib/l10n/app_*.arb` (7 files)

## Tour Flow (new)
```
Hand 1 complete → "Hand Complete!" → BB pill spotlight → Next Hand spotlight
  → "Practice" card → hand 2 WITH scripted guidance
  → hand 2 complete → i spotlight → session details → stack chart
  → 3-dot menu spotlight ("select End Session") → user ends session
  → HomeScreen phase 5 → Sessions nav → session card → analytics → AI analysis → registration
```
