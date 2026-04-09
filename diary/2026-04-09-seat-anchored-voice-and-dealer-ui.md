# Seat-Anchored Dealer Voice Commands + STT Pipeline Fixes + Dealer UI Improvements

**Date**: 2026-04-09
**Status**: Confirmed working (voice flow is solid, UI adjustments tested)

---

## Overview

Major overhaul of the dealer voice STT pipeline and dealer table UI. The core change is a new **seat-anchored command format** where every voice action must include a seat number (e.g., "seat 4 call", "s4 fold"). This eliminates the fundamental problem of actions being attributed to wrong players when the dealer speaks quickly.

Additionally: multiple STT pipeline robustness fixes, WebSocket keep-alive, connection recovery improvements, and dealer table UI enhancements (check pills, all-in pills, ante display, board cards on table).

---

## Files Changed (8 files)

| File | Change Type | Description |
|------|-------------|-------------|
| `lib/services/action_parser.dart` | **Rewrite** | Seat-anchored parsing with two regex patterns |
| `lib/features/dealer_voice/action_validator.dart` | **Modified** | Seat validation, mismatch detection, removed min-raise snap |
| `lib/features/dealer_voice/cubit/dealer_voice_cubit.dart` | **Modified** | Mismatch callback, pending-amount hold mechanism, debug logging |
| `lib/features/dealer_voice/speech_buffer.dart` | **Modified** | Smart silence gaps, removed cooldown, quick flush for simple actions |
| `lib/services/soniox_service.dart` | **Modified** | Keep-alive packets, connection loss fix, seat context hints |
| `lib/screens/dealer/dealer_table_screen.dart` | **Modified** | Check/all-in pills, ante display, board cards, voice restart bar, haptic feedback |
| `test/action_parser_test.dart` | **New** | 20 test cases for seat-anchored parser |
| `devtools_options.yaml` | Auto-generated | Flutter devtools config |

---

## Part 1: Seat-Anchored Voice Commands (Core Architecture Change)

### Problem
When the dealer spoke quickly, Soniox would group multiple players' actions into a single utterance (e.g., `"call. all in."`). The pipeline processed them sequentially against `currentPlayer`, but by the time the second action was processed, `currentPlayer` had already advanced — causing wrong-player attribution.

### Solution: Require seat number in every command
The dealer must now say **"seat 4 call"** or **"s4 call"** or **"4 call"** for every action. The validator checks the spoken seat against `currentPlayer` and rejects mismatches with haptic feedback.

### action_parser.dart — Complete Rewrite

**Old behavior**: Matched bare action keywords like "fold", "check", "call" anywhere in text.

**New behavior**: Two seat-anchored regex patterns:

1. `_seatActionPattern`: Matches `"seat 4 call"`, `"s4 call"`, `"seat 3 raise 2000"`
   - Pattern: `(?:seat\s+|s)(\d)[,.\s]+` + action keywords + optional amount

2. `_bareSeatPattern`: Matches `"4 call"`, `"5 fold"` (bare digit prefix)
   - Pattern: `(?:^|[.\s,])([1-9])[,.\s]+` + action keywords + optional amount
   - Only matches digits 1-9, skips regions already consumed by pattern 1

**Critical regex details**:
- `[,.\s]+` between seat and action (not just `\s+`) — Soniox inserts commas after numbers (e.g., `"s4, fold."`)
- Action keywords listed longest-first to prevent partial matches (`all[\s-]?in` before `call`)
- `all-in` uses `startsWith('all')` in `_normalizeAction()` to prevent "call" being normalized to "all-in"
- Consumed character ranges tracked to prevent duplicate matches between pattern 1 and 2

**`ParsedAction` model**: Added `seatNumber` field (optional `int?`).

### action_validator.dart — Seat Validation

**New checks** (before existing hand/player checks):
- **Check 0**: `seatNumber == null` → reject with "No seat number specified"
- **Check 1**: `seatNumber != currentPlayer` → reject with `seatMismatch` factory

**New `ActionValidationResult` fields**:
- `isSeatMismatch: bool` — allows cubit to distinguish mismatch from other rejections
- `seatMismatch()` factory constructor

**Removed min-raise enforcement**: Dealer's spoken amount is trusted. Only max-bet (all-in cap) is enforced. Previously, "raise 5500" would be bumped to 5854 min-raise — this is wrong in dealer mode since the dealer knows the correct amount.

**Preserves `seatNumber`** in corrected action output.

### dealer_voice_cubit.dart — Mismatch Callback + Pending Amount

**Mismatch callback**:
- New `onSeatMismatch` callback `(int spokenSeat, int expectedSeat)`
- Invoked when validator returns `isSeatMismatch == true`
- Wired to `HapticFeedback.heavyImpact()` in dealer_table_screen

**Pending amount mechanism** (handles Soniox splitting "raise 5000" across utterances):
- When raise/bet arrives with `amount == null`, stored as `_pendingAmountAction`
- 1.5s timer starts (`_pendingAmountTimeoutMs`)
- If next utterance has same seat + action + amount → merge and execute
- If different action arrives → flush pending first, then process new
- If timer fires → execute as-is (triggers min-raise in game state)
- Cleared on new hand and dispose

**Echo detection fix** (from prior session, preserved):
- `rawSignatures.add()` moved inside `isValid` block
- Rejected actions not recorded in echo history
- Allows Soniox re-sends of rejected actions without them being stripped

### soniox_service.dart — Context Hints

Updated Soniox ASR context:
- Text: Describes seat-anchored format with examples
- Terms: Added "seat", "seat 1" through "seat 9" for better recognition
- Translation terms preserved (Polish → English)

---

## Part 2: WebSocket Connection Robustness

### Problem 1: Connection lost, no recovery
Soniox WebSocket would die during pauses. `_handleConnectionLoss()` didn't reset `_isStreaming = false`, so `startStreaming()` returned `true` immediately without reconnecting.

### Fix: `soniox_service.dart`
- `_handleConnectionLoss()` now resets `_isStreaming = false` at the top
- Dead audio recorder cleaned up (`_recorder!.stop()`, `_recorder = null`)
- `_audioSubscription` cancelled

### Problem 2: WebSocket timeout during holds
Soniox closes the connection if no audio is received for ~30 seconds. Dealer often pauses to deal cards.

### Fix: Keep-alive mechanism
- New `_keepAliveTimer` sends 320 bytes of silent PCM audio every 10s
- Only sends if no real audio for 8s (avoids unnecessary packets)
- Started in `startStreaming()`, stopped in `stopStreaming()`, `dispose()`, `_handleConnectionLoss()`

### Problem 3: No way to restart voice after stopping
`_stopContinuousListening()` didn't set `_isVoiceMode = false`, so the restart bar never appeared.

### Fix: `dealer_table_screen.dart`
- Added `_isVoiceMode = false` to `_stopContinuousListening()`
- Added `_buildVoiceRestartBar()` widget — shown when `!_isVoiceMode && _isHandActive`
- Tapping restarts voice mode and calls `_startContinuousListening()`

---

## Part 3: SpeechBuffer Smart Silence Gaps

### Problem
Fixed 2-second cooldown caused missed actions. Single gap duration couldn't handle both fast "fold" and slow "raise 2,000" scenarios.

### Fix: `speech_buffer.dart`
- **Removed cooldown entirely** — echo detection handled by cubit's `_stripEchoedPrefix()`
- **Smart gap selection**:
  - `quickSilenceGap` (400ms): Simple actions (fold, check, call, all-in) — flush fast
  - `silenceGap` (1000ms): Amount-bearing actions (bet, raise) — wait for number
  - `extendedSilenceGap` (1800ms): Buffer ends with digit/comma — wait for more digits
- Added `_amountActionPattern` and `_anyActionPattern` for gap classification
- Added debug logging for gap decisions

---

## Part 4: Dealer Table UI Improvements

### Check pill
- Green `#3BA55D` "CHECK" pill shown next to seats when `lastAction == PlayerAction.check && betThisRound == 0 && !hasFolded`
- Same styling as bet pill (8px/1px padding, rounded, 9px font w600)
- Added to both side-layout (left/right seats) and top-layout (seat 1)

### All-in pill
- Bet pill turns red `#E53935` with "ALL-IN" text when `playerState.isAllIn`
- Replaces amount display — shows "ALL-IN" instead of the number
- Both side-layout and top-layout

### BB ante display
- When `hasBBante` is active and it's preflop:
  - BB seat pill shows only the blind portion (`betThisRound / 2`) instead of full BB+ante
  - Blue `#4C94FF` "ANTE {amount}" pill appears in table center (same color/size as bet pills)
- Ante pill hidden after preflop (ante merged into pot)

### Board cards display
- After card selection, mini card widgets (32x44px) appear in table center above pot
- White background, rounded corners, drop shadow
- Red text for hearts/diamonds, black for spades/clubs
- IBM Plex Mono font, 12px w600

### Voice restart bar
- Shown when voice is off but hand is active (`!_isVoiceMode && _isHandActive`)
- Dark container with mic_off icon + "Voice off" text + play arrow
- Tapping re-enables voice mode

### Fire-and-forget DealerService.logAction
- Changed from `await` with try-catch to `unawaited()` with `.catchError()`
- Prevents blocking the UI on Firebase write latency

---

## Part 5: Debug Logging Improvements

All STT debug prints now use consistent prefixes:
- `[STT:BUFFER]` — SpeechBuffer accumulation and flush events
- `[STT:PARSE]` — ActionParser output with seat numbers: `S4:fold(null)`
- `[STT:ECHO]` — Echo detection strip events
- `[STT:VALIDATE]` — Validation results and corrections
- `[STT:EXEC]` — Action execution with player name: `Seat 4 (Diana) → PlayerAction.fold`
- `[STT:AMOUNT]` — Pending amount hold/resolve/timeout events
- `[STT:MISMATCH]` — Seat mismatch warnings
- `[STT:KEEPALIVE]` — Silent packet sends

---

## Test Coverage

New file: `test/action_parser_test.dart` (20 test cases):
- Basic seat prefix parsing (seat N, sN, bare N)
- Comma-separated Soniox format (`"s4, fold."`, `"seat 6, call."`)
- Amount with comma separator (`"s2, raise, 5000."`)
- "call" NOT parsed as "all-in" (critical regression test)
- Two folds in one utterance — no duplicates
- "pass" → fold normalization
- Amount with k suffix (`"seat 8 bet 2.5k"`)
- No actions from garbage text
- Bare "fold" without seat returns empty

---

## Bugs Found and Fixed During Testing

### Bug: "call" parsed as "all-in"
- **Root cause**: `all[\s-]?in` regex matched "all" inside "c**all**" when followed by text containing "in"
- **Fix**: Listed `all[\s-]?in` before `call` in regex alternation; `_normalizeAction()` uses `startsWith('all')` not `contains('all')`

### Bug: Duplicate matches (4 actions from 2)
- **Root cause**: Both `_seatPrefixPattern` and `_bareSeatPattern` matched same text at slightly different offsets
- **Fix**: Track consumed character ranges; bare pattern skips regions already matched by seat prefix pattern

### Bug: Soniox comma insertion breaks parsing
- **Root cause**: Soniox sends `"s4, fold."` with comma between seat and action; regex had `\s+` which doesn't match `, `
- **Fix**: Changed `\s+` to `[,.\s]+` in both patterns

### Bug: Raise executed without amount, then amount rejected
- **Root cause**: Soniox splits `"s2 raise 5000"` into `"s1, all in. s2, raise."` then `"s2, raise. 5000."`. First utterance executes raise with no amount, advancing turn. Second utterance rejected as seat mismatch.
- **Fix**: Pending amount mechanism — hold raise/bet without amount for 1.5s, merge with incoming amount

### Bug: Min-raise snapping overrides dealer
- **Root cause**: Validator snapped "raise 5500" up to min-raise 5854
- **Fix**: Removed min-raise enforcement in voice validator. Dealer's spoken amount is trusted.

---

## Part 6: Board Cards Icon + Street Rollback

### Cards icon in dealer header
- Added a cards icon (next to QR code) in dealer table header bar
- When `bettingRoundComplete == true`, tapping the icon reopens the board cards dialog
- Routes through `_handleBettingRoundComplete()` to properly handle all-in scenarios (shows all-in board dialog vs regular flop/turn/river dialog)

### Street rollback on undo
- Removed `bettingRoundComplete` guard from `_canUndoLastAction()` — undo button now works even after a betting round completes
- Added `bettingRoundComplete = false` reset in `_undoLastAction()`
- When all non-blind actions on current street are undone, triggers `_rollbackToPreviousStreet()`:
  - Removes board cards for the rolled-back street
  - Restores `currentRound` to previous street
  - Reconstructs each player's `betThisRound` and `totalContribution` from action history
  - Recalculates pot from scratch
- Added `_getPreviousRound()` and `_getNextRound()` helpers

### Firestore sync for undo/rollback
- Added `DealerService.syncActions()` — overwrites entire Firestore actions array atomically on undo
- Added `DealerService.clearBoardCards()` — always writes all board card fields (even empty/null) to clear them for player screens
- `_syncActionsToFirestore()` helper converts `ActionRecord` list to Firestore format and syncs after every undo

### BoardCardsDialog RangeError fix
- Empty flop list after rollback caused `_flop[0]` crash
- Fixed by ensuring `_flop` always has 3 elements via `List.generate(3, ...)`

---

## Part 7: Player Session Screen Tweaks

- **Dealer name tag**: Reduced to 10px font, 11px icon, 7h/3v padding
- **Rankings icon**: Changed from amber `#FFA726` to teal `#62E3BC`
- **Collapsible street grouping**: Actions grouped by street (Preflop, Flop, Turn, River) with tap-to-toggle headers. Latest street auto-expands, previous streets auto-collapse when new street starts.

---

## Part 8: Pot Calculation Fixes

### Fix: `_getPreviousBetThisRound()` blind amounts
- Was returning 0 for blind positions because blind posts aren't recorded as actions
- Added `_getBlindAmountForSeat()` helper using `effectiveSBPosition`/`effectiveBBPosition` (includes BB ante)
- Call amounts are DELTAS (ADD to total), bet/raise amounts are TOTALS (REPLACE total)

### Fix: "Call 0" → Check conversion
- When BB says "call" at BB option (already matched current bet), `recordAmount = 0`
- Now converts to `PlayerAction.check` with `recordAmount = null`

### Fix: Raise clamping mismatch (pot wrong on undo)
- **Root cause**: `_performAction()` recorded raw user input as `recordAmount` for raise/bet, but `performActionWithAmount()` internally clamps to `[minBet, maxStack]`. Pot received clamped delta, but undo subtracted unclamped delta — leaving extra chips in pot.
- **Fix**: Reordered `_performAction()` to execute game state FIRST, then read back `player.betThisRound` (the clamped value) as `recordAmount`. Also captures `recordStreet`/`recordButton` before execution since game state may advance.
- Also fixed Firestore log to use `recordAmount` (clamped) instead of raw `amount`.

### Fix: `_rollbackToPreviousStreet()` streetBet reconstruction
- Call amounts (deltas) were treated as totals (`streetBet = action.amount`)
- Fixed to ADD for calls, REPLACE for bet/raise, and include blind base for preflop

---

## Part 9: Voice Raise/Bet — Wait Indefinitely for Amount

### Problem
1.5s timeout fired `_executePendingAction()` with null amount → "ghost raise" that moved game state without changing pot or chips.

### Fix
- Removed timeout entirely for pending raise/bet without amount
- Action held indefinitely until:
  - Amount arrives via voice (merged and executed)
  - Different seat's action arrives (pending discarded — dealer moved on)
  - Dealer taps manual button (clears voice state)

---

## Known Limitations / Future Improvements
- No visual feedback for seat mismatch rejection (only haptic) — could add brief red flash on the expected seat
- Board cards display is compact (32x44px) — may want larger cards or tap-to-zoom on table center
- Polish number words are in the parser but Soniox translates to English before we see it, so they may not be needed
