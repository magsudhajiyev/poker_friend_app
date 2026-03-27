# Dealer Voice Logging System — Technical Documentation

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Data Flow](#data-flow)
4. [Component Reference](#component-reference)
   - [SonioxService](#1-sonioxservice)
   - [SpeechBuffer](#2-speechbuffer)
   - [ActionParser](#3-actionparser)
   - [DealerVoiceCubit](#4-dealervoicecubit)
   - [ActionValidator](#5-actionvalidator)
   - [DealerTableScreen Integration](#6-dealertablescreen-integration)
5. [Echo Problem & Solution](#echo-problem--solution)
6. [Echo Defense Layers](#echo-defense-layers)
   - [Layer 1: Cooldown](#layer-1-cooldown-speechbuffer)
   - [Layer 2: Echo Prefix Stripping](#layer-2-echo-prefix-stripping-dealervoicecubit)
   - [Layer 3: Fuzzy Signature Matching](#layer-3-fuzzy-signature-matching)
   - [Layer 4: Game State Validation](#layer-4-game-state-validation-actionvalidator)
7. [Processing Queue & Concurrency](#processing-queue--concurrency)
8. [Split Number Handling](#split-number-handling)
9. [Timing Parameters](#timing-parameters)
10. [Auto-Corrections](#auto-corrections)
11. [Known Failure Modes & Mitigations](#known-failure-modes--mitigations)
12. [File Structure](#file-structure)
13. [Debugging Guide](#debugging-guide)

---

## Overview

The Dealer Voice Logging System converts live poker dealer speech into structured game actions in real time. A poker dealer announces actions such as "pass, fold, bet 700, reraise 1500" and the system parses, validates, and executes those actions sequentially against the game state — without requiring any manual input from the user.

The system uses Soniox cloud speech-to-text with speaker diarization (locked to the dealer's voice), and includes a multi-layered defense system against the echo/duplication problem inherent in streaming STT providers.

---

## Architecture

The pipeline consists of five stages, each solving a specific problem:

```
┌─────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────────────┐    ┌──────────────────┐
│  Microphone  │───▶│ SonioxService│───▶│ SpeechBuffer │───▶│  DealerVoiceCubit    │───▶│ DealerTableScreen│
│  (16kHz)     │    │  (STT)       │    │  (Buffering) │    │  (Parser + Echo Guard│    │  (Game State)    │
│              │    │              │    │              │    │   + Validator + Queue)│    │                  │
└─────────────┘    └──────────────┘    └──────────────┘    └──────────────────────┘    └──────────────────┘
     Audio              Text               Utterance            ParsedAction              PlayerAction
                     fragments             (complete)           (validated)               (executed)
```

**Separation of concerns:**

| Component | Responsibility | Knows about game state? |
|---|---|---|
| SonioxService | WebSocket to Soniox, audio streaming, diarization | No |
| SpeechBuffer | Timing, buffering, cooldown | No |
| ActionParser | Text → structured actions | No |
| DealerVoiceCubit | Orchestration, echo guard, validation dispatch | Yes (receives updates) |
| ActionValidator | Legality checks, auto-corrections | Yes (reads state) |
| DealerTableScreen | Game model mutation, UI | Yes (owns state) |

---

## Data Flow

A concrete example showing what happens when the dealer says **"pass, fold, bet 700"**:

```
1. MICROPHONE → 16kHz PCM audio stream

2. SONIOX (via WebSocket)
   → FINAL: "pass. fold. bet 700"           (primary delivery)
   → FINAL: "fold. bet 700. reraise"        (overlapping re-delivery, 0.5s later)
   → FINAL: ". bet 700. reraise 1,500."     (another overlap, 1.2s later)

3. SPEECH BUFFER
   → Receives "pass. fold. bet 700" → starts 1800ms timer (ends with digit)
   → Receives "fold. bet 700. reraise" → IGNORED (cooldown active)
   → Timer fires → FLUSH: "pass. fold. bet 700"
   → Enters 2000ms cooldown

4. DEALER VOICE CUBIT
   → _onCompleteUtterance("pass. fold. bet 700")
   → ActionParser.parse() → [fold(null), fold(null), bet(700.0)]
   → _enqueueActions() → _processNext()
   → _stripEchoedPrefix() → no recent batches → all 3 actions proceed

5. SEQUENTIAL EXECUTION (inside _processActionsSequentially)
   → Action 1: fold(null)
     → Raw signature recorded: "fold:null"
     → ActionValidator: seat 4 can fold → VALID
     → onExecuteAction(fold) → screen executes → currentPlayer advances to 5
     → updateGameState(currentPlayer=5)

   → Action 2: fold(null)
     → Raw signature recorded: "fold:null"
     → ActionValidator: seat 5 can fold → VALID
     → onExecuteAction(fold) → screen executes → currentPlayer advances to 6
     → updateGameState(currentPlayer=6)

   → Action 3: bet(700.0)
     → Raw signature recorded: "bet:700.0"
     → ActionValidator: seat 6, there's already a blind → bet corrected to raise
     → VALID with corrections: [bet → raise]
     → onExecuteAction(raise(700.0)) → screen executes → currentPlayer advances to 7
     → updateGameState(currentPlayer=7)

   → Record batch raw signatures: "fold:null|fold:null|bet:700.0"

6. ECHO ARRIVES (after cooldown expires)
   → FINAL: ". bet 700. reraise 1,500." gets through cooldown
   → SpeechBuffer flushes: ". bet 700. reraise 1,500."
   → ActionParser: [bet(700.0), raise(1500.0)]
   → _stripEchoedPrefix(): "bet:700.0" matches end of previous batch → strip 1
   → Only raise(1500.0) executes for seat 7
```

---

## Component Reference

### 1. SonioxService

**File:** `lib/services/soniox_service.dart`

**Purpose:** Manages the WebSocket connection to Soniox cloud STT, streams microphone audio, and emits raw transcript text.

**Key behaviors:**

- Opens a WebSocket to Soniox with speaker diarization enabled
- Locks onto the dealer's voice during a calibration phase (dealer says a specific phrase)
- Streams 16kHz mono PCM audio from the device microphone
- Emits `VoiceSessionState` changes (calibrating, dealer_locked, action listening, etc.)
- Emits raw final transcript strings via `finalTranscriptStream`

**What it does NOT do (anymore):**

- Does NOT parse actions (removed `ActionParser` import and `_processTranscriptAsAction()`)
- Does NOT debounce transcripts (removed `_TranscriptDebouncer` class)
- Does NOT manage an `actionStream` (removed `_actionController`)
- Does NOT flush partial transcripts on disconnect (fixed partial-on-disconnect bug)

**Hold mode:** When the user taps the hold button, the service stops emitting finals. The cubit tracks hold state via `VoiceSessionState` updates. Transcripts that arrive during hold are tagged as "held" and not forwarded to the buffer.

**Diarization:** Soniox identifies different speakers in the audio. During calibration, the dealer speaks a known phrase and the service locks onto their speaker ID. Subsequent transcripts from other speakers (players) are filtered out. This prevents player chatter from being interpreted as dealer announcements.

---

### 2. SpeechBuffer

**File:** `lib/features/dealer_voice/speech_buffer.dart`

**Purpose:** Accumulates Soniox final transcript fragments into complete utterances using silence-gap detection, then emits them via a callback. Provides cooldown to block immediate echo re-deliveries.

**Constructor parameters:**

| Parameter | Default | Purpose |
|---|---|---|
| `silenceGap` | 1000ms | Time to wait after last final before flushing |
| `extendedSilenceGap` | 1800ms | Used when buffer ends with digit/comma (split number) |
| `cooldownDuration` | 2000ms | How long to ignore all finals after a flush |
| `onUtteranceComplete` | required | Callback invoked with the complete utterance string |

**State machine:**

```
                    ┌──────────┐
                    │  IDLE    │ (not streaming)
                    └────┬─────┘
                         │ startStreaming()
                         ▼
                    ┌──────────┐  final arrives   ┌──────────────┐
                    │ LISTENING│ ───────────────▶  │  BUFFERING   │
                    └──────────┘                   │ (timer runs) │
                         ▲                         └──────┬───────┘
                         │                                │ silence gap expires
                         │                                ▼
                         │                         ┌──────────────┐
                         │    cooldown expires      │   COOLDOWN   │
                         │◀─────────────────────── │ (ignoring)   │
                         │                         └──────┬───────┘
                         │                                │ flush → callback
                         │                                │
                         └────────────────────────────────┘
```

**Silence gap selection logic:**

```dart
// Detect if buffer might end with an incomplete number
final needsExtended = RegExp(r'[\d,]$').hasMatch(currentBufferText);
final gap = needsExtended ? extendedSilenceGap : silenceGap;
```

If the buffer text ends with a digit or comma (e.g., "raise 2,00" or "reraise 10,"), the extended gap is used. This gives Soniox time to deliver the rest of a split number before flushing.

**Cooldown behavior:**

After flushing, the buffer enters cooldown mode. ANY incoming final transcript during cooldown is silently discarded with a log message: `IGNORED - cooldown=true`. This is the first and most effective echo defense — Soniox typically re-delivers content within 1-3 seconds, and the 2-second cooldown blocks most of these.

**Reset vs. stopStreaming:**

- `reset()`: Clears buffer, cancels timers, resets cooldown. Called on new hand.
- `stopStreaming()`: Discards buffer contents WITHOUT flushing. Prevents partial transcripts from executing when the mic is turned off. Does NOT call `onUtteranceComplete`.

---

### 3. ActionParser

**File:** `lib/services/action_parser.dart`

**Purpose:** Stateless parser that converts a transcript string into a list of `ParsedAction` objects.

**Signature:** `static List<ParsedAction> parse(String text)`

**ParsedAction model:**

```dart
class ParsedAction {
  final String action;    // "fold", "call", "check", "bet", "raise", "all-in"
  final double? amount;   // null for fold/call/check/all-in, numeric for bet/raise
}
```

**Vocabulary mapping:**

| Dealer says | Parsed as |
|---|---|
| "pass", "fold" | `fold(null)` |
| "call", "flat" | `call(null)` |
| "check" | `check(null)` |
| "bet 700" | `bet(700.0)` |
| "raise 2000", "reraise 2,000", "make it 2k" | `raise(2000.0)` |
| "all in" | `all-in(null)` |

**Number parsing:**

- Comma-separated: "10,000" → 10000.0
- K-notation: "1.5k" → 1500.0, "2k" → 2000.0
- Decimal amounts: "1.4000" → 1.4 (this is a Soniox quirk, handled by validator snapping)
- Period-terminated: "700." → 700.0 (trailing period stripped)

**Unparseable content:** Fragments like "aler max", "0.", ".", "eraise. 1,500.", "one, dealer max." produce empty results and are silently ignored. The parser is conservative — if it can't confidently identify an action keyword, it drops the fragment.

**Multi-action parsing:** The parser splits on sentence boundaries (periods) and processes each segment independently. "pass. fold. bet 700." produces `[fold, fold, bet(700.0)]`.

---

### 4. DealerVoiceCubit

**File:** `lib/features/dealer_voice/cubit/dealer_voice_cubit.dart`
**State file:** `lib/features/dealer_voice/cubit/dealer_voice_state.dart`

**Purpose:** Central orchestrator. Wires SonioxService → SpeechBuffer → ActionParser → ActionValidator → execution callback. Owns the processing queue, echo guard, and voice UI state.

**State model:**

```dart
class DealerVoiceState {
  final VoiceStatus status;        // disabled, listening, processing, error
  final String? partialText;       // current partial transcript (for UI display)
  final String? lastUtterance;     // last complete utterance processed
  final List<String> lastCorrections; // corrections applied to last batch
}
```

**Cubit explanation:** A Cubit is the simpler sibling of Bloc from the `flutter_bloc` package. It holds a single state object and exposes methods to change it. Calling `emit(newState)` triggers widget rebuilds automatically via `BlocBuilder`. No `setState()`, no manual stream management. Separates state and logic from UI. Testable without Flutter widgets.

**Internal fields:**

```dart
// Pipeline components
final SonioxService _soniox;
final SpeechBuffer _speechBuffer;
final ActionParser _parser;
final ActionValidator _validator;

// Game state (pushed from screen)
PokerGameState? _gameState;
bool _isHandActive = false;

// Echo guard
final List<_ExecutedBatch> _recentBatches = [];  // 5-second sliding window

// Processing queue
bool _isProcessing = false;
final List<List<ParsedAction>> _pendingBatches = [];

// Execution callback (set by screen)
Future<void> Function(ParsedAction)? onExecuteAction;
```

**Lifecycle:**

| Method | When called | What it does |
|---|---|---|
| `startListening()` | User taps mic button | Starts Soniox + SpeechBuffer streaming |
| `stopListening()` | User taps mic button again | Stops streaming, discards buffer |
| `updateGameState()` | After every action execution | Pushes fresh game state for next validation |
| `onNewHand()` | New hand dealt | Resets buffer, clears echo history + queue |
| `dispose()` | Screen disposed | Cleans up subscriptions |

#### Processing Queue

See [Processing Queue & Concurrency](#processing-queue--concurrency) section for detailed explanation.

#### Echo Guard

See [Echo Defense Layers](#echo-defense-layers) section for detailed explanation.

---

### 5. ActionValidator

**File:** `lib/features/dealer_voice/action_validator.dart`

**Purpose:** Validates a parsed action against the current game state and applies auto-corrections where possible.

**Signature:**

```dart
ActionValidationResult validate(
  ParsedAction action,
  PokerGameState gameState,
  {required bool isHandActive}
)
```

**Return type:**

```dart
class ActionValidationResult {
  final bool isValid;
  final ParsedAction correctedAction;  // may differ from input
  final List<String> corrections;       // human-readable correction descriptions
  final String? rejectionReason;        // null if valid
}
```

**Validation checks (in order):**

1. **Hand active?** — If no hand is in progress, reject with "No active hand"
2. **Player can act?** — If current player has folded, is all-in, or it's not their turn, reject with "Current player cannot act"
3. **Action legal?** — Is this action type legal given the current betting state?
4. **Amount in range?** — For raises/bets, is the amount within min/max limits?

**Auto-corrections (see [Auto-Corrections](#auto-corrections) section):**

- `bet` → `raise` when there's an existing bet
- `check` → `call` when there's a bet to call
- `call` → `check` when there's nothing to call
- Amount snapping to minimum raise
- `all-in` → `raise(playerStack)` with actual stack amount

---

### 6. DealerTableScreen Integration

**File:** `lib/screens/dealer/dealer_table_screen.dart`

**What was removed (old system):**

- `_isHoldingActions` — manual hold state tracking
- `_pendingActionType` — queued action for hold mode
- `_lastDetectedAction` — last action for manual dedup
- `_executeVoiceAction()` — direct action execution from STT

**What was added (new system):**

- `DealerVoiceCubit` instance created in `initState()`
- `onExecuteAction` callback maps `ParsedAction` to `PlayerAction` enum
- `_onVoiceActionValidated()` calls `_performAction()` on the game model
- `_updateVoiceCubitState()` pushes fresh `PokerGameState` to cubit after every action
- `BlocBuilder<DealerVoiceCubit, DealerVoiceState>` for UI updates (status indicator, corrections display)

**Game state freshness guarantee:** After every `_performAction()`, the screen immediately calls `_voiceCubit.updateGameState()`. This ensures the next action in a multi-action batch validates against the new state (new current player, updated pot, etc.).

---

## Echo Problem & Solution

### What causes echoes

Soniox streaming STT delivers **overlapping incremental final transcripts**. When the dealer speaks continuously, Soniox doesn't give you one clean transcript per utterance. Instead, it delivers multiple overlapping "final" results where each new final contains some already-delivered content plus new content.

Example — dealer says "pass, fold, bet 700, reraise 1500":

```
t=0.0s  FINAL: "pass. fold. bet 700"              ← primary delivery
t=0.5s  FINAL: "fold. bet 700. reraise"            ← overlap: "fold. bet 700"
t=1.2s  FINAL: ". bet 700. reraise 1,500."         ← overlap: "bet 700"
t=2.5s  FINAL: ". reraise 1,500. pass."            ← overlap: "reraise 1,500"
t=3.8s  FINAL: "pass. pass."                       ← overlap: "pass"
```

Without echo protection, each of these would be parsed and executed, causing phantom folds, duplicate raises, and game state corruption.

### Why overlap-based text deduplication doesn't work

The original approach tried to compare transcript text and remove overlapping substrings. This failed because:

1. Soniox doesn't guarantee consistent word boundaries across finals
2. Partial words ("reraise" vs "eraise") break string matching
3. Numbers get reformatted ("3,000" vs "3000" vs "3,00")
4. The overlap window is unpredictable (sometimes 2 words, sometimes 8)

### Why game-state validation is the right approach

Poker game state is highly constrained: one player acts per turn, there's a limited set of legal actions, and amounts have defined ranges. Instead of comparing fragmented text, we validate each parsed action against what's actually legal in the current game state. Combined with echo signature tracking, this provides robust deduplication.

---

## Echo Defense Layers

The system uses four defense layers. Each catches what the previous ones miss.

### Layer 1: Cooldown (SpeechBuffer)

**Mechanism:** After flushing an utterance, the SpeechBuffer ignores ALL incoming finals for 2000ms.

**What it catches:** ~60% of echoes. Soniox typically re-delivers content within 1-3 seconds. Most immediate re-deliveries fall within the cooldown window.

**Log signature:** `[SpeechBuffer] IGNORED - cooldown=true, streaming=true`

**What it misses:** Echoes that arrive after 2 seconds, especially when the dealer pauses before continuing. Soniox may re-deliver content up to 4-5 seconds after the original.

**Configuration:** `cooldownDuration: Duration(milliseconds: 2000)` in SpeechBuffer constructor.

### Layer 2: Echo Prefix Stripping (DealerVoiceCubit)

**Mechanism:** Detects when the START of a new batch overlaps with the END of a recent batch, and strips the overlapping prefix.

**The pattern:** Soniox echoes follow a specific structure — they prepend the tail of a previous transcript to new content:

```
Previous batch:  [fold, fold, bet:700]      ← "fold fold bet 700"
Echo arrives:    [bet:700, raise:1500]       ← "bet 700 reraise 1500"
                  ^^^^^^^^
                  This is the TAIL of the previous batch
                  Strip it, execute only [raise:1500]
```

**Implementation detail — `_stripEchoedPrefix()`:**

1. Cleans `_recentBatches` of entries older than 5 seconds
2. For each recent batch, attempts to find overlap between the END of the previous batch and the START of the new batch
3. Tries the largest possible overlap first, working down to overlap of 1
4. Uses `_signaturesMatch()` for comparison (supports fuzzy matching)
5. Strips the overlapping prefix, returns only non-echoed actions

**Critical rule — proper suffix check:**

```dart
if (match && overlapLen > maxStrip && overlapLen < prevSigs.length) {
```

The overlap must be a PROPER suffix of the previous batch (`overlapLen < prevSigs.length`). If the overlap equals the entire previous batch, it's not a tail echo — it's a legitimate repeated action. This prevents false positives on consecutive all-ins, consecutive folds, etc.

**Examples:**

| Previous batch | New batch | Overlap | Action |
|---|---|---|---|
| `[fold, fold, bet:700]` | `[bet:700, raise:1500]` | 1 < 3 | Strip "bet:700", execute "raise:1500" |
| `[raise:10000, fold]` | `[fold, call]` | 1 < 2 | Strip "fold", execute "call" |
| `[all-in:null]` | `[all-in:null]` | 1 = 1 | Don't strip — genuine repeat |
| `[fold:null]` | `[fold:null]` | 1 = 1 | Don't strip — genuine repeat |

**Log signatures:**
- `[DealerVoiceCubit] Echo prefix stripped: 1 action(s) from bet:700.0|raise:1500.0`
- `[DealerVoiceCubit] Processing 1 actions after stripping 1 echo(es)`
- `[DealerVoiceCubit] Entire batch was echo - skipping`

### Layer 3: Fuzzy Signature Matching

**Mechanism:** When comparing signatures in the echo guard, allows "close enough" amount matches to catch truncated-number echoes.

**The problem it solves:** Soniox sometimes splits numbers across finals. "raise 3,000" arrives as:

```
Final 1: "reraise. 3,00"  → parser sees raise(300.0) → recorded as "raise:300.0"
Final 2: "reraise. 3,000." → parser sees raise(3000.0) → checked as "raise:3000.0"
```

Exact comparison: "raise:300.0" ≠ "raise:3000.0" → echo not detected → duplicate raise.

**Fuzzy matching via `_signaturesMatch()`:**

```dart
bool _signaturesMatch(String sig1, String sig2) {
  if (sig1 == sig2) return true;

  // Action type must match exactly
  if (parts1[0] != parts2[0]) return false;

  // Fuzzy amount: one integer is a prefix of the other
  final int1 = amt1.toInt().toString();  // "300"
  final int2 = amt2.toInt().toString();  // "3000"

  // "300" is a prefix of "3000" → truncated number → match
  if (int1.length != int2.length &&
      (int2.startsWith(int1) || int1.startsWith(int2))) {
    return true;
  }
  return false;
}
```

**Why this doesn't false-positive:** The integer string prefix check is specific. "300" is a prefix of "3000" (truncation of thousands), but "600" is NOT a prefix of "3000" (genuinely different amounts). The amounts must also be different lengths, preventing "100" from matching "100".

### Layer 4: Game State Validation (ActionValidator)

**Mechanism:** Even if an echo slips through all previous layers, it must still be a legal action for the current player. If it's not, the validator rejects it.

**What it catches:** Edge cases where echo content happens to survive prefix stripping but is illegal in the current game context. For example, a "fold" echo arrives for a player who has already folded — the validator rejects with "Current player cannot act".

**Log signature:** `[DealerVoiceCubit] Action REJECTED: fold - Current player cannot act (folded, all-in, or not their turn)`

**Limitation:** This layer cannot catch echoes where the echoed action happens to also be legal for the next player. A "raise 700" echo that arrives when the next player could legally raise 700 will execute incorrectly. This is why layers 1-3 are essential.

---

## Processing Queue & Concurrency

### The problem

`SpeechBuffer.onUtteranceComplete` fires whenever the silence gap expires after a flush — this is independent of whether the cubit has finished processing the previous batch. Since `_processActionsSequentially` is async (it awaits each action execution), a new batch can arrive mid-processing.

Without a queue, this causes a race condition:

```
t=0.0s  Batch A starts processing: [fold, fold, raise:1500]
t=0.1s  Batch A: fold(seat8) executes...
t=0.3s  Batch A: fold(seat9) executes...
t=0.5s  SpeechBuffer flushes Batch B: [fold, fold, raise:10000]
        → Batch A's signatures NOT YET RECORDED in _recentBatches
        → Batch B's echo check finds nothing → ALL actions execute ✗
t=0.7s  Batch A: raise(seat1) executes... → signatures finally recorded
```

Batch B's "fold, fold" was an echo of Batch A's "fold, fold", but since Batch A hadn't finished recording its signatures yet, the echo guard had no history to check against.

### The solution

A simple processing lock with a FIFO queue:

```dart
bool _isProcessing = false;
final List<List<ParsedAction>> _pendingBatches = [];

void _enqueueActions(List<ParsedAction> actions) {
  if (_isProcessing) {
    _pendingBatches.add(actions);  // Queue it
    return;
  }
  _processNext(actions);  // Process immediately
}

Future<void> _processNext(List<ParsedAction> actions) async {
  _isProcessing = true;

  await _processActionsSequentially(actions);  // Batch A completes fully

  while (_pendingBatches.isNotEmpty) {
    final next = _pendingBatches.removeAt(0);
    await _processActionsSequentially(next);   // Batch B sees A's signatures
  }

  _isProcessing = false;
  emit(state.copyWith(status: VoiceStatus.listening));
}
```

**Guarantee:** Batch N's signatures are recorded in `_recentBatches` BEFORE batch N+1's `_stripEchoedPrefix` runs. The echo guard always has complete history.

**Log signature:** `[DealerVoiceCubit] Already processing - queuing 3 actions`

---

## Split Number Handling

### The problem

Soniox sometimes delivers a number across two separate finals:

```
t=0.0s  FINAL: "reraise. 2,00"     ← number truncated
t=1.2s  FINAL: ",000."             ← rest of the number
```

If the buffer flushes after the first final (1000ms silence gap), "reraise 2,00" parses as raise(200.0) or raise(2.0), which then gets snapped to minimum raise — the wrong amount.

### The solution

**Extended silence gap:** When the buffer text ends with a digit or comma, the silence gap extends from 1000ms to 1800ms. This gives Soniox an extra 800ms to deliver the rest of the number.

**Detection regex:** `RegExp(r'[\d,]$').hasMatch(currentBufferText)`

**Log signature:** `[SpeechBuffer] Silence timer started (1800ms) [extended - possible split number]`

**When it's not enough:** If the number takes longer than 1800ms to complete, the truncated version flushes. The fuzzy signature matching in the echo guard (Layer 3) then prevents the complete version from executing as a duplicate when it arrives in a later transcript.

---

## Timing Parameters

| Parameter | Value | Location | Purpose |
|---|---|---|---|
| Silence gap | 1000ms | SpeechBuffer | Time to wait after last final before flushing |
| Extended silence gap | 1800ms | SpeechBuffer | Used when buffer ends with digit/comma |
| Cooldown | 2000ms | SpeechBuffer | Ignore all finals after a flush |
| Echo window | 5 seconds | DealerVoiceCubit | How long echo signatures are retained |

**Tuning rationale:**

- **1000ms silence gap:** Soniox delivers rapid fragments 200-500ms apart. 1000ms catches all fragments from a single speech segment without waiting too long between actions.
- **1800ms extended gap:** Numbers split across finals typically arrive within 1-1.5 seconds. 1800ms covers the 95th percentile case.
- **2000ms cooldown:** Soniox echo re-deliveries peak at 1-2 seconds. 2000ms blocks most immediate echoes while being short enough to not miss genuinely new speech.
- **5-second echo window:** Soniox can re-deliver content up to 4-5 seconds after the original, especially in noisy environments. 5 seconds covers the tail end of the echo distribution.

---

## Auto-Corrections

The ActionValidator applies these corrections automatically, logging each one:

| Spoken | Context | Corrected to | Reason |
|---|---|---|---|
| "bet 700" | Blind or previous bet exists | raise(700) | Dealers often say "bet" when the correct poker term is "raise" |
| "check" | There's a bet to call | call | Dealer misspoke or player asked to check but must call |
| "call" | Nothing to call | check | No outstanding bet to call |
| "raise 300" | Min raise is 1200 | raise(1200) | Amount below minimum, snap to min |
| "all in" | Player stack is 59586 | raise(59586) | Convert to actual raise amount |

Corrections are tracked in `lastCorrections` on the cubit state and can be displayed in the UI as feedback to the user.

---

## Known Failure Modes & Mitigations

### 1. Echo matches a legal action for the next player

**Scenario:** Echo of "raise 700" arrives when the next player could legally raise 700.

**Mitigation:** Layers 1-3 (cooldown, prefix stripping, fuzzy matching) handle most cases. The remaining risk window is when an echo survives all three layers AND happens to be legal. This is rare in practice because the prefix stripping catches the pattern.

### 2. Soniox misrecognizes words

**Scenario:** Dealer says "call" but Soniox hears "all" (no action keyword found) or "fold" (wrong action).

**Mitigation:** The user can use hold mode to pause processing, manually correct via UI, or undo the last action. The ActionValidator prevents the most catastrophic misrecognitions (e.g., "fold" when the player hasn't acted yet will still execute as a fold, which is wrong but reversible).

### 3. Background noise triggers false actions

**Scenario:** A player's conversation gets parsed as an action.

**Mitigation:** Soniox speaker diarization locks onto the dealer's voice during calibration. Transcripts from other speakers are filtered. This works well in typical poker room environments but can degrade in very noisy settings or if the dealer's voice characteristics change (e.g., they clear their throat).

### 4. Very long pauses between actions

**Scenario:** Dealer pauses for 10+ seconds mid-sentence. The buffer flushes a partial utterance.

**Mitigation:** The echo guard and validator handle this gracefully. The partial batch executes what it can, and the continuation (when the dealer resumes speaking) processes as a new batch. The echo guard strips any overlapping content.

### 5. Database schema error

**Visible in logs:** `table hands has no column named isStarred`

**Impact:** Hand saving to local SQLite fails. Actions still execute correctly — this is a separate database migration issue that needs to be fixed independently.

---

## File Structure

```
lib/
├── features/
│   └── dealer_voice/
│       ├── speech_buffer.dart              # Timing, buffering, cooldown
│       ├── action_validator.dart           # Game state validation + corrections
│       └── cubit/
│           ├── dealer_voice_cubit.dart     # Orchestrator, echo guard, queue
│           └── dealer_voice_state.dart     # VoiceStatus, state model
├── services/
│   ├── soniox_service.dart                 # WebSocket STT, diarization
│   └── action_parser.dart                  # Text → ParsedAction (stateless)
├── screens/
│   └── dealer/
│       └── dealer_table_screen.dart        # UI integration, game state bridge
└── models/
    └── poker_game_state.dart               # Game model (not modified)
```

**Dependency graph:**

```
DealerTableScreen
    │
    └──▶ DealerVoiceCubit
              │
              ├──▶ SonioxService (audio → text)
              ├──▶ SpeechBuffer (text → utterances)
              ├──▶ ActionParser (utterances → actions)
              └──▶ ActionValidator (actions → validated actions)
```

No circular dependencies. SonioxService, SpeechBuffer, ActionParser, and ActionValidator are all independent — they don't know about each other. The cubit is the only component that wires them together.

---

## Debugging Guide

### Reading the logs

Every component prefixes its logs with a tag. Filter by these to isolate issues:

| Filter | Shows |
|---|---|
| `[SonioxService]` | Raw finals from Soniox, hold/session status |
| `[SpeechBuffer]` | Buffer accumulation, flush timing, cooldown |
| `[DealerVoiceCubit]` | Parsing, echo guard, queue, execution flow |
| `[ActionValidator]` | Validation results, corrections, rejections |
| `[DealerTableScreen]` | Action execution, player advancement |

### Common log patterns

**Healthy action execution:**
```
[SpeechBuffer] FLUSH: "pass. fold. bet 700"
[DealerVoiceCubit] Parsed 3 actions: [fold(null), fold(null), bet(700.0)]
[ActionValidator] VALID: fold ... for seat 4
[DealerTableScreen] Executing PlayerAction.fold for seat 4
[DealerTableScreen] Action executed. New currentPlayer: 5
```

**Echo blocked by cooldown:**
```
[SpeechBuffer] IGNORED - cooldown=true, streaming=true
```

**Echo caught by prefix stripping:**
```
[DealerVoiceCubit] Echo prefix stripped: 1 action(s) from bet:700.0|raise:1500.0
[DealerVoiceCubit] Processing 1 actions after stripping 1 echo(es)
```

**Entire batch was echo:**
```
[DealerVoiceCubit] Entire batch was echo - skipping
[DealerVoiceCubit] All actions were echoes - skipping batch
```

**Fuzzy match caught truncated number:**
```
[DealerVoiceCubit] Fuzzy amount match: raise:300.0 ≈ raise:3000.0 (truncated number)
```

**Action rejected by validator:**
```
[DealerVoiceCubit] Action REJECTED: fold - Current player cannot act (folded, all-in, or not their turn)
```

**Queued batch (concurrency protection):**
```
[DealerVoiceCubit] Already processing - queuing 3 actions
[DealerVoiceCubit] Processing queued batch: 3 actions
```

### Diagnosing a wrong action

1. Find the `FLUSH` log to see what text was processed
2. Check the `ActionParser.parse()` output — was the parsing correct?
3. Check `_processActionsSequentially` — was echo stripping applied? Should it have been?
4. Check `[ActionValidator]` — was the action valid? Were corrections applied correctly?
5. Check `Action executed. New currentPlayer:` — did the right seat advance?

### Diagnosing a missed action

1. Check if the transcript was delivered by Soniox (`[SonioxService] FINAL:`)
2. Check if cooldown blocked it (`IGNORED - cooldown=true`)
3. Check if the echo guard stripped it (`Echo prefix stripped`)
4. Check if the validator rejected it (`Action REJECTED`)

---

*Last updated: March 2, 2026*
*System version: Post-refactor with echo prefix stripping, fuzzy matching, and processing queue*
