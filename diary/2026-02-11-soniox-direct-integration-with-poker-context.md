# Soniox Direct Integration with Poker Context

**Date:** 2026-02-11
**Status:** STABLE - Working in production

---

## Summary

Implemented direct Flutter-to-Soniox WebSocket connection for real-time speech recognition with poker domain context. This replaces the previous Python backend approach, reducing latency from ~2 seconds to ~200ms.

---

## Problem

The previous architecture had multiple issues:

1. **High latency**: Flutter → Python backend → Soniox → Claude → Flutter took 1-2 seconds
2. **Polish transcription errors**: "rejs" (Polish for raise) was translated to "flight" (literal meaning)
3. **Misheard words**: "raise" heard as "race"
4. **Language detection issues**: Sometimes output Cyrillic characters

---

## Solution

### Architecture Change

- **Before**: Flutter → Python WebSocket → Soniox → Claude API → Flutter
- **After**: Flutter → Soniox WebSocket (direct) with local parsing

### Key Components

1. **SonioxService** (`lib/services/soniox_service.dart`)
   - Direct WebSocket connection to `wss://stt-rt.soniox.com/transcribe-websocket`
   - Poker domain context configuration
   - Real-time audio streaming (16kHz, 16-bit PCM, mono)
   - Action debouncing to prevent duplicates

2. **ActionParser** (`lib/services/action_parser.dart`)
   - Local regex-based action parsing
   - English number word conversion (five → 5, etc.)
   - Simple English patterns only (Soniox handles translation)

---

## Soniox Configuration

The key to making this work was using Soniox's context feature:

```dart
final config = {
  'api_key': _apiKey,
  'model': 'stt-rt-preview',
  'audio_format': 's16le',
  'sample_rate': 16000,
  'num_channels': 1,
  'language_hints': ['en', 'pl'],
  'context': {
    'general': [
      {'key': 'domain', 'value': 'Poker'},
      {'key': 'topic', 'value': 'Live poker game action logging'},
    ],
    'text': 'Dealer announces player actions during a poker hand. Common actions include fold, check, call, bet, raise, reraise, and all-in. Amounts are stated in chips.',
    'terms': [
      'fold', 'check', 'call', 'bet', 'raise', 'reraise', 're-raise', 'all-in', 'all in', 'shove',
    ],
    'translation_terms': [
      {'source': 'pas', 'target': 'fold'},
      {'source': 'rejs', 'target': 'raise'},
      {'source': 'czek', 'target': 'check'},
      {'source': 'sprawdzam', 'target': 'check'},
      {'source': 'kol', 'target': 'call'},
      {'source': 'podbijam', 'target': 'raise'},
      {'source': 'wszystko', 'target': 'all-in'},
    ],
  },
};
```

### What Each Part Does

- **general**: Tells Soniox we're in poker domain
- **text**: Provides context about what's being said
- **terms**: Boosts recognition of poker vocabulary (prevents "race" vs "raise")
- **translation_terms**: Maps Polish poker words to English equivalents

---

## ActionParser Patterns

Simple English-only patterns since Soniox handles Polish translation:

```dart
// Fold: fold, pass, muck
RegExp(r'\b(fold|pass|muck)\b')

// Check: check, checking
RegExp(r'\b(check|checking)\b')

// Call: call, calling
RegExp(r'\b(call|calling)\b')

// Bet with amount: bet 25
RegExp(r'\b(?:bet|betting)\s+(\d+)')

// Raise with amount: raise 100, reraise 50
RegExp(r'\b(?:raise|re-raise|reraise|raising)\s+(\d+)')

// Raise without amount: raise, reraise
RegExp(r'\b(raise|re-raise|reraise)\b(?!\s+\d)')

// All-in: all-in, all in, shove, jam
RegExp(r'\b(all-in|all in|allin|shove|jam)\b')
```

---

## Debouncing Logic

Prevents duplicate actions from rapid speech:

- **Same action cooldown**: 800ms (allows natural "fold fold" with pause)
- **Any action cooldown**: 200ms (catches rapid duplicates)

---

## Files Modified/Created

1. **Created**: `lib/services/soniox_service.dart`
   - Direct WebSocket connection to Soniox
   - Audio streaming from microphone
   - Action detection with debouncing

2. **Created**: `lib/services/action_parser.dart`
   - Local action parsing with regex
   - English number word conversion

3. **Modified**: `lib/screens/dealer/dealer_table_screen.dart`
   - Changed from RealtimeSpeechService to SonioxService

4. **Modified**: `pubspec.yaml`
   - Added `web_socket_channel: ^2.4.0`

---

## Dependencies

```yaml
record: ^5.1.0          # Audio recording
web_socket_channel: ^2.4.0  # Direct WebSocket to Soniox
```

---

## Test Results

Verified working with:
- English: "fold", "check", "call", "raise 15", "reraise 100", "all in"
- Polish: "pas" (→ fold), "rejs" (→ raise), transcribed correctly
- Mixed language: Dealer announcing in Polish/English mix
- Amounts: "bet 25", "raise 5", "reraise 17"

---

## Previous Approaches (Failed)

### 1. Translation Mode (stt-rt-v4 + translation)
- Set `translation: {type: 'one_way', target_language: 'en'}`
- **Failed**: Translated literally ("rejs" → "flight", not "raise")

### 2. Manual Polish Patterns
- Added every Polish variant to ActionParser
- **Failed**: Not scalable, edge cases kept appearing

### 3. Python Backend with Claude
- Used Claude API for action parsing
- **Failed**: Too slow (~2 second latency)

---

## API Key

Soniox API key stored in `soniox_service.dart`:
```
d6b70a1463e1c697ae879aefa9b7e0586e1c8b027cc165b58614798fc9fb6ada
```

---

## Performance

- **Latency**: ~200ms (vs ~2s with Python backend)
- **Accuracy**: Near perfect with poker context
- **Languages**: English + Polish supported via translation_terms

---

## Notes

- The `context` feature in Soniox is the key to making this work
- `translation_terms` maps Polish poker jargon to English (not general translation)
- `terms` boost prevents mishearing (e.g., "raise" not "race")
- Debouncing is essential because Soniox sends incremental results

---

## Maintainer Notes

If recognition accuracy degrades:
1. Check if `terms` list covers the misheard word
2. Add to `translation_terms` if a Polish word is not being converted
3. Check debouncer timing if actions are duplicated or missed
