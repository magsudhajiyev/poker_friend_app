# Fix: Tournament Session Summary Card — Net P/L, Biggest Pot BB, Best/Worst Hand

**Date**: 2026-05-15
**Status**: Confirmed fixed

## Problem

After ending a tournament session with rebuys, the shareable session summary card showed wildly incorrect numbers (e.g., "+172,000" instead of "-600 PLN"). Additionally:
- Biggest pot showed raw chip amounts (meaningless without blind context)
- Best/worst hand used absolute pot size, not relative to stack
- Best/worst hand was blank when hole cards weren't entered
- Tournament placement and prize data weren't passed to the summary card

## Root Cause

### 1. Tournament Net P/L mixed chips and money
`_showSessionSummary()` computed profit as `finalStack - totalBuyIn` for ALL game types. In tournaments, `finalStack` is in **chips** (e.g., 172,000) while `totalBuyIn` is in **money** (e.g., 600 PLN). The subtraction is meaningless.

### 2. Biggest pot had no BB context
`biggestPot` stored raw chip amount but never tracked what the big blind was at that moment.

### 3. Best/worst hand used absolute pot size
In tournaments with escalating blinds, a 50,000 pot at 100/200 is huge but a 50,000 pot at 5000/10000 is tiny. Absolute comparison is meaningless.

## Fix

### Files Modified
- `lib/screens/poker_hand_screen.dart` — `_showSessionSummary()`, `_stopSession()`, `_handleNavigationAttempt()`, `_endSessionFromGate()`
- `lib/models/hand_state_machine.dart` — `biggestPotBB` field, `_bestHandRatio`/`_worstHandRatio`, `_trackBiggestPotWonLost()`
- `lib/widgets/session_summary_card.dart` — `biggestPotBB` field, `_formatBiggestPot()`, header layout, tournament hero stat
- `lib/screens/profile_screen.dart` — Debug test button for summary card

### Changes

1. **Tournament P/L**: `_showSessionSummary()` now accepts optional `bankrollResult` parameter from `SessionEndBankrollSheet`. For tournaments, uses `bankrollResult['profitLoss']` (prize - totalBuyIn) instead of chips - money. All 3 session-ending code paths (`_stopSession`, `_handleNavigationAttempt`, `_endSessionFromGate`) pass this through.

2. **Biggest Pot BB**: Added `int biggestPotBB = 0` to `PokerSessionManager`. Set to `bigBlind` in `completeCurrentHand()` and `completeCurrentHandWithChop()` whenever a new biggest pot is recorded. `SessionSummaryData` carries `int? biggestPotBB`. Display: cash shows currency, tournament shows `{pot/bb} BB` (e.g., "95 BB").

3. **Best/Worst Hand Ratio**: Replaced `biggestPotWon`/`biggestPotLost` (absolute) with `_bestHandRatio`/`_worstHandRatio` (pot / hero's pre-hand stack). This makes comparison meaningful across blind levels. Falls back to `"Hand #N"` when hole cards aren't entered.

4. **Tournament metadata**: `finishedPlace`, `fieldSize`, `prizeWon` now passed from `bankrollResult` to `SessionSummaryData` and displayed in the tournament hero stat section.

5. **Header layout**: Changed from vertical (logo alone, then info below) to horizontal Row (48x48 logo left, session name + badge/duration stacked right).

6. **Debug tooling**: Added "Test Summary Card (Tournament)" button to Profile screen dev tools for quick iteration.

## Key Patterns

- `SessionEndBankrollSheet.show()` returns `Map<String, dynamic>?` with keys: `profitLoss`, `finishedPlace`, `fieldSize`, `prizeWon`
- Tournament chips are NOT money — never subtract money from chips
- For meaningful cross-blind-level comparisons, use ratios (pot/stack, pot/BB), not absolutes
- `biggestPotBB` stores the BB level at the time the biggest pot occurred, NOT the pot in BB units

## Testing

1. Create tournament session → log 2-3 hands → end session → enter placement/field/prize → verify summary card shows correct net P/L, BB-equivalent biggest pot, and placement
2. Use Profile → Dev Tools → "Test Summary Card (Tournament)" for quick verification
3. Test cash session to verify currency formatting still works for biggest pot
