# Multilingual Speech Recognition Challenge: Poker Terms + Foreign Numbers

**Date:** 2026-02-09
**Status:** Unresolved - Seeking Solutions
**Languages:** English (poker terms) + Polish (numbers)

---

## Problem Statement

We need speech recognition that can handle **mixed-language input**:
- **English poker actions:** "raise", "bet", "fold", "check", "call", "all-in"
- **Polish numbers:** "sto" (100), "dwa" (2), "trzy" (3), "pięć" (5), etc.

**Example utterances:**
- "raise sto" → raise 100
- "bet dwa tysiące" → bet 2000
- "fold" → fold (English only)

---

## Technical Setup

### Speech Recognition Service
- **Provider:** Deepgram
- **Model:** nova-2
- **API:** Real-time WebSocket streaming
- **Audio:** 16kHz, 16-bit, mono PCM

### Backend Stack
- **Framework:** FastAPI + Socket.IO
- **Files:**
  - `app/core/speech_processing/realtime_transcriber.py` - Deepgram WebSocket client
  - `app/core/speech_processing/action_parser.py` - Regex-based action parsing
  - `app/core/speech_processing/dealer_brain.py` - AI-powered semantic parsing
  - `app/websocket/speech_stream.py` - Socket.IO event handlers

### Current Deepgram Configuration
```python
self._context_manager = self.client.listen.v1.connect(
    model="nova-2",
    language="en",  # Language setting
    smart_format="true",
    punctuate="false",
    interim_results="true",
    utterance_end_ms="1000",
    vad_events="true",
    endpointing="300",
    sample_rate="16000",
    encoding="linear16",
    channels="1",
    keywords=["fold:2", "check:2", "call:2", "bet:2", "raise:2", "all in:2"],
)
```

---

## Solutions Attempted

### Attempt 1: Add Polish Numbers to Word Mappings

**Approach:** Add Polish number words directly to WORD_NUMBERS dictionary.

**Changes:**
```python
WORD_NUMBERS = {
    # English numbers
    "one": 1, "two": 2, ..., "hundred": 100, "thousand": 1000,

    # Polish numbers
    "jeden": 1, "dwa": 2, "trzy": 3, "cztery": 4,
    "sto": 100, "dwiescie": 200, "tysiac": 1000,
    ...
}
```

**Result:** ❌ Failed
- Deepgram transcribes Polish words as English phonetic approximations
- "sto" → "stop", "stock", "store", "stupa"
- The Polish words never appear in the transcript

---

### Attempt 2: Switch Deepgram to Polish Language Mode

**Approach:** Change `language="en"` to `language="pl"` in Deepgram config.

**Changes:**
```python
language="pl"  # Polish mode
```

**Result:** ❌ Failed
- Transcriptions still came out in English
- "raise sto" → "raise stop", "please stop", "raise pinch"
- Polish mode doesn't seem to change the output language
- Poker terms like "raise" still recognized (good), but Polish numbers not

**Logs:**
```
RealtimeSpeech: Partial: "please stop." (final=true)
RealtimeSpeech: Partial: "raise pinch." (final=true)
RealtimeSpeech: Partial: "raise stupa." (final=true)
```

---

### Attempt 3: Switch to Multi-Language Mode

**Approach:** Use Deepgram's multi-language detection (`language="multi"`).

**Changes:**
```python
language="multi"  # Multi-language detection
```

**Result:** ❌ Failed
- Same behavior as Polish mode
- "bet sto" → "bet store"
- Still outputs English phonetic approximations
- No actual Polish transcription

**Logs:**
```
RealtimeSpeech: Partial: "bet store" (final=true)
RealtimeSpeech: Partial: "raise stock." (final=true)
```

---

### Attempt 4: Phonetic Approximation Mappings (Current)

**Approach:** Keep English mode but map English mishearings of Polish words to their intended values.

**Changes:**
```python
WORD_NUMBERS = {
    # ... existing English and Polish numbers ...

    # Phonetic mishearings (what Deepgram outputs for Polish words)
    # "sto" (100) commonly misheard as:
    "stop": 100, "stow": 100, "stove": 100, "stock": 100,
    "stoke": 100, "store": 100, "stupa": 100, "stool": 100,

    # "dwa" (2) commonly misheard as:
    "duva": 2, "diva": 2, "tva": 2,

    # "trzy" (3) commonly misheard as:
    "tshi": 3, "chi": 3, "tshe": 3,

    # "piec" (5) commonly misheard as:
    "pinch": 5, "peach": 5, "piench": 5,
    ...
}
```

**Result:** ⚠️ Partial Success
- Works when Deepgram outputs a mapped word
- Problem: "stop" also means STOP in English - creates ambiguity
- Problem: Mishearings are inconsistent - sometimes get unmapped words
- Problem: Need to keep adding new mishearings as they're discovered

---

## Observed Deepgram Behavior

### Polish Word Transcriptions (English Mode)
| Polish Word | Meaning | Deepgram Output |
|-------------|---------|-----------------|
| sto | 100 | stop, stock, store, stupa, stow |
| dwa | 2 | duva, diva, tva (inconsistent) |
| trzy | 3 | tree, tshi, chi |
| pięć | 5 | pinch, peach, piench |
| dziesięć | 10 | jest, jesh (rare) |

### Key Observations
1. **Deepgram always outputs English-like words** regardless of language setting
2. **Polish mode doesn't produce Polish text** - it seems to only affect the acoustic model, not the output vocabulary
3. **Multi-mode behaves same as English mode** for our use case
4. **Keyword boosting only works for exact matches** - can't boost Polish words if they're never in the output
5. **Mishearings are inconsistent** - same word can be transcribed differently each time

---

## Root Cause Analysis

The fundamental issue is that Deepgram's models are trained to output **English vocabulary**, even when processing non-English audio. The language setting appears to affect:
- Acoustic model (how sounds are interpreted)
- But NOT the output vocabulary (always English words)

This means Polish words like "sto" are:
1. Heard correctly as /stɔ/ sound
2. Mapped to closest English word: "stop", "stock", "store"
3. Never output as the actual Polish word "sto"

---

## Potential Solutions to Explore

### 1. Alternative Speech Recognition Providers

#### Google Cloud Speech-to-Text
- Supports 125+ languages including Polish
- Has `alternative_language_codes` for multi-language
- May output actual Polish words

#### Azure Speech Services
- Supports Polish (pl-PL)
- Has "language identification" feature
- Can switch languages mid-utterance

#### Whisper (OpenAI)
- Multilingual model
- Transcribes in actual source language
- Self-hosted option available
- May have latency issues for real-time

#### AssemblyAI
- Has multilingual support
- Real-time transcription available

### 2. Custom Vocabulary / Phrase Lists

Some providers support custom vocabularies:
- Add Polish number words as "expected phrases"
- May improve recognition of specific terms
- Deepgram has "keywords" but only for boosting, not vocabulary expansion

### 3. Two-Pass Approach

1. First pass: Get English transcription with phonetic approximations
2. Second pass: Use phoneme-based matching to identify Polish words
3. Could use a small language model to detect "does this sound like Polish?"

### 4. Client-Side Speech Recognition

Use device's native speech recognition (iOS/Android) which may have better multi-language support:
- iOS: `SFSpeechRecognizer` with Polish locale
- Android: `SpeechRecognizer` with Polish locale
- Then send transcribed text to backend

Flutter package: `speech_to_text` already supports locale configuration.

### 5. Train Custom Model

- Fine-tune a speech model on poker + Polish numbers dataset
- Expensive and time-consuming
- Requires significant audio data

### 6. Hybrid Approach

- Keep Deepgram for English poker terms (works well)
- Add extensive phonetic mappings for Polish numbers
- Accept ~80% accuracy for Polish numbers
- Allow manual correction in UI

---

## Files Modified During Attempts

### Backend (poker_friend_ai)
| File | Changes |
|------|---------|
| `app/core/speech_processing/realtime_transcriber.py` | Language settings (en, pl, multi) |
| `app/core/speech_processing/action_parser.py` | Added Polish numbers + phonetic mappings to WORD_NUMBERS |
| `app/core/speech_processing/dealer_brain.py` | Added Polish numbers + phonetic mappings to WORD_NUMBERS |
| `app/websocket/speech_stream.py` | Default language parameter |

### Current Phonetic Mappings
Located in both `action_parser.py` and `dealer_brain.py`:
```python
# "sto" (100) commonly misheard as:
"stop": 100, "stow": 100, "stove": 100, "stock": 100,
"stoke": 100, "store": 100, "stupa": 100, "stool": 100,

# "dwa" (2) commonly misheard as:
"duva": 2, "diva": 2, "tva": 2,

# "trzy" (3) commonly misheard as:
"tshi": 3, "chi": 3, "tshe": 3,

# "piec" (5) commonly misheard as:
"pinch": 5, "peach": 5, "piench": 5,

# "dziesiec" (10) commonly misheard as:
"jest": 10, "jesh": 10,

# "tysiac" (1000) commonly misheard as:
"teeshonts": 1000, "tisyonts": 1000,
```

---

## Questions to Research

1. Does Deepgram have a true multilingual model that outputs non-English text?
2. Can Google/Azure/Whisper handle code-switching (mixing languages mid-sentence)?
3. Is there a way to get phoneme-level output from Deepgram for custom matching?
4. Would client-side speech recognition (Flutter) work better for Polish?
5. Are there any poker-specific speech recognition models/datasets?

---

## Current Workaround

Using **English mode with phonetic mappings**:
- Poker terms work reliably
- Polish numbers work ~60-70% of the time (when mishearing matches our mappings)
- Need to continuously add new mishearings as discovered
- Some ambiguity with English words (e.g., "stop" could mean STOP or 100)

---

## Next Steps

1. [ ] Research Google Cloud Speech-to-Text multi-language support
2. [ ] Research Azure Speech Services language identification
3. [ ] Test Whisper for multi-language transcription
4. [ ] Consider Flutter's on-device speech recognition with Polish locale
5. [ ] Evaluate if partial solution (English + mappings) is acceptable for MVP

---

**Last Updated:** 2026-02-09
