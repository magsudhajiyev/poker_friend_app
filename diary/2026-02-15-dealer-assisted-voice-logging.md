# Dealer-Assisted Voice Logging - Implementation Journey

**Date:** 2026-02-15
**Feature:** Voice recognition for dealer-announced poker actions using Soniox WebSocket API

---

## Overview

Implemented a dealer-assisted logging system that uses real-time speech recognition to automatically record poker actions as they're announced by the dealer. This enables hands-free hand logging during live poker sessions.

---

## Problems Encountered & Solutions

### 1. Soniox WebSocket Configuration Error

**Problem:** Initial connection to Soniox failed with "Control request invalid type" error.

**Cause:** Attempted to send JSON EOF signal after configuration was established. Soniox doesn't accept JSON control messages after the initial config.

**Solution:** Send empty audio packet (`Uint8List(0)`) to signal end of stream instead of JSON.

---

### 2. Calibration Phrase Validation Mismatch

**Problem:** Calibration failed with "content_mismatch" even when saying the correct phrase "Table 1, dealer Jack".

**Cause:** Strict validation required both "table" AND "dealer" keywords. Soniox sometimes transcribed "dealer check" instead of "dealer Jack" due to poker term interference.

**Solution:**
- Made validation more lenient: accept if EITHER "table" OR "dealer" is present
- Speaker diarization is the primary signal (whoever speaks IS the dealer)
- Added fallback: if dealer name is a poker term (fold, check, etc.), use "Dealer" as default

---

### 3. Token Spacing Issues

**Problem:** Transcription showed "t t able" instead of "table" - tokens were being joined with spaces incorrectly.

**Cause:** Soniox sends partial tokens that shouldn't be space-separated when building words.

**Solution:**
- Join tokens without spaces for word reconstruction
- Only store FINAL tokens for text validation (avoids duplicates)
- Normalize multiple spaces after joining

---

### 4. Polish Number Words Not Recognized

**Problem:** "raise pi\u0119\u0107" (raise five in Polish) wasn't being parsed correctly.

**Cause:** ActionParser only had English number words mapped to digits.

**Solution:** Added comprehensive Polish number word mappings to `_numberWords` map in `action_parser.dart`:
```dart
'jeden': '1', 'dwa': '2', 'trzy': '3', 'cztery': '4', 'pi\u0119\u0107': '5',
'sze\u015b\u0107': '6', 'siedem': '7', 'osiem': '8', 'dziewi\u0119\u0107': '9', 'dziesi\u0119\u0107': '10',
// ... and compound numbers
```

---

### 5. "Sixty" Parsed as "6" Instead of "60"

**Problem:** "bet sixty" was executed as "bet 6" instead of "bet 60".

**Cause:** Number word replacement was processing "six" before "sixty", turning "sixty" into "6ty".

**Solution:** Sort number words by length DESCENDING before replacement so longer words are processed first:
```dart
final sortedWords = _numberWords.keys.toList()
  ..sort((a, b) => b.length.compareTo(a.length));
```

---

### 6. Action-Level Debouncing Blocked Legitimate Actions

**Problem:** "fold fold fold" for three consecutive players only registered one fold.

**Cause:** Initial implementation used action-level debouncing with 400ms cooldown, blocking rapid same-actions.

**Solution:** Removed action-level debouncing. The real issue was transcript overlap, not action duplication. Multiple actions in a single transcript should all be processed.

---

### 7. Soniox Sends Overlapping/Trailing Transcripts (MAJOR ISSUE)

**Problem:** Soniox sends the same content multiple times:
```
22:55:49 - "fold. fold. raise six." \u2192 [fold, fold, raise 6] \u2713
22:55:51 - "raise six."            \u2192 [raise 6] \u2190 DUPLICATE!
```

This caused duplicate action execution for the wrong player.

**Root Cause:** Soniox's real-time streaming sends:
1. Full transcript as final
2. Trailing fragments of the same transcript as separate finals

**Solution:** Implemented multi-layered overlap detection in `_TranscriptDebouncer`:

#### Layer 1: Exact Duplicate Check
Skip if same transcript received within 500ms cooldown.

#### Layer 2: Proper Suffix Detection
Skip if new transcript is a **proper suffix** of previous (contained at end, but not equal):
```dart
if (_lastTranscript!.endsWith(normalized) && normalized != _lastTranscript) {
  return false; // Trailing fragment
}
```

This correctly handles:
- "fold. fold. raise six." \u2192 "raise six." = SKIP (proper suffix)
- "check." \u2192 "check." = PROCESS (equal, not proper suffix)

#### Layer 3: Start-End Overlap Detection
Handle when new transcript STARTS with how previous ENDED:
```
Previous: "pass. fold. raise five." \u2192 actions: [fold, fold, raise(5)]
New:      "raise five. call"        \u2192 actions: [raise(5), call]
                                     \u2191 overlap: skip first action
```

**Implementation:**
```dart
class _ActionSignature {
  final String action;
  final double? amount;

  bool matches(_ActionSignature other) {
    if (action != other.action) return false;
    if (amount != null && other.amount != null) {
      return amount == other.amount;
    }
    return true;
  }
}
```

Compare parsed actions (with amounts) to detect overlap between end of previous and start of new transcript.

---

### 8. Bet/Raise Without Amount Opening Manual Dialog

**Problem:** When dealer said "raise" without immediately saying the amount, the app opened a manual betting dialog.

**User Requirement:** Wait for the amount to be transcribed, then execute automatically.

**Solution:** Implemented pending action state:
```dart
String? _pendingActionType; // 'bet' or 'raise'
DateTime? _pendingActionTime;
static const int _pendingActionTimeoutMs = 3000;
```

When bet/raise detected without amount:
1. Store as pending
2. Listen to partial transcripts for numbers
3. When number found, complete the action
4. Timeout after 3 seconds if no amount received

---

## Architecture

### Key Files Modified

1. **`lib/services/soniox_service.dart`**
   - VoiceSessionState enum (uninitialized, calibrating, dealerLocked, connectionLost, rotating)
   - Speaker diarization and dealer voice locking
   - `_TranscriptDebouncer` with multi-layered overlap detection
   - `_ActionSignature` for comparing parsed actions with amounts
   - Hold action mode for pausing action execution
   - Connection recovery with grace period

2. **`lib/services/action_parser.dart`**
   - English and Polish number word mappings
   - Length-sorted replacement to handle "sixty" vs "six"
   - Regex patterns for poker actions

3. **`lib/screens/dealer/dealer_table_screen.dart`**
   - Voice mode toggle and push-to-talk UI
   - Pending action state for bet/raise without amount
   - Action execution with auto-correction (check\u2194call, bet\u2194raise)
   - Visual feedback for detected actions

### State Machine

```
UNINITIALIZED \u2192 CALIBRATING \u2192 DEALER_LOCKED
                              \u2192 CONNECTION_LOST \u2192 CALIBRATING (after grace period)
                              \u2192 ROTATING \u2192 CALIBRATING
```

### Calibration Flow

1. User starts voice mode
2. Service enters CALIBRATING state
3. Dealer says "Table [X], dealer [name]"
4. 7-second calibration window tracks:
   - Speaker token counts (diarization)
   - Content validation (table/dealer keywords)
5. Majority speaker locked as dealer
6. Service enters DEALER_LOCKED state
7. Only dealer's speech processed for actions

---

## Testing Checklist

- [x] "fold fold raise six" \u2192 3 actions (no duplicate from trailing fragment)
- [x] "check" [pause] "check" \u2192 2 separate check actions
- [x] "check check check" quickly \u2192 3 check actions in one transcript
- [x] "raise" [pause] "ten" \u2192 raise 10 (pending action completion)
- [x] "bet sixty" \u2192 bet 60 (not bet 6)
- [x] Polish numbers: "raise pi\u0119\u0107" \u2192 raise 5

---

## Configuration

API key stored in `.env`:
```
SONIOX_API_KEY=your_key_here
```

Loaded via `EnvConfig.sonioxApiKey` in `lib/config/env_config.dart`.

---

## Future Improvements

1. **Player name recognition** - Detect which player is acting from speech
2. **Board card recognition** - "Flop is ace of spades, king of hearts, queen of diamonds"
3. **Pot amount tracking** - "Pot is 1500"
4. **Showdown logging** - "Player 3 shows two pair"
5. **Multi-language support** - Currently English/Polish, could add more

---

## Lessons Learned

1. **Real-time STT is noisy** - Expect overlapping transcripts, partial results, and streaming artifacts
2. **Speaker diarization isn't perfect** - Use content validation as secondary signal
3. **Number word parsing is tricky** - Order matters, longer words first
4. **Debouncing at wrong level causes problems** - Transcript-level, not action-level
5. **Test with real speech** - Synthetic test data doesn't capture STT quirks
