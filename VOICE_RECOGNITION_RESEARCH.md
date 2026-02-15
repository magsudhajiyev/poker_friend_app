# Voice Recognition for Dealer-Assisted Poker Logging

## Project Context

Building a dealer-assisted poker logging system where the dealer speaks player actions ("fold", "raise 200", "all-in") and the app logs them automatically. The app will be used internationally, starting with Poland.

---

## What We've Accomplished

### 1. On-Device Speech Recognition (Current Implementation)

**File:** `lib/services/continuous_speech_service.dart`

- Using Flutter's `speech_to_text` package for on-device recognition
- Implemented fuzzy matching with `fuzzywuzzy` package (Levenshtein distance)
- Added comprehensive keyword lists for poker actions
- Built debouncing system (prevents duplicate rapid actions)
- Added exponential backoff for error recovery
- Implemented confidence thresholds per action type

**File:** `lib/screens/dealer/dealer_table_screen.dart`

- Auto-correction logic (check↔call, bet↔raise when one is invalid)
- Visual feedback for detected actions
- Integration with game state

### 2. What Works

- "fold" detection works well (including mishearings like "cold", "fault")
- Debouncing prevents duplicate actions
- Error recovery with exponential backoff
- Auto-correction for invalid game state actions

### 3. Current Problems

| Issue | Description |
|-------|-------------|
| Language-specific | Hardcoded English keywords won't work for Polish or other languages |
| Mishearings | On-device ASR quality varies - "pause" heard instead of "pass" |
| No vocabulary hints | On-device models can't be tuned for poker terminology |
| Inconsistent accuracy | Recognition quality depends heavily on device and environment |

---

## What We Need

### Requirements for Cloud ASR Solution

1. **Real-time / Low Latency**
   - Dealer needs immediate feedback
   - Target: < 500ms from speech end to action logged
   - Streaming preferred over batch processing

2. **Multilingual Support**
   - Must work with Polish speakers
   - Ideally supports: Polish, English, German, Spanish, Russian
   - Should handle accents and code-switching

3. **Custom Vocabulary / Keyword Boosting**
   - Ability to boost poker terms: fold, check, call, bet, raise, all-in
   - Number recognition (amounts): "two hundred", "pięćset" (Polish for 500)
   - Should not require full model fine-tuning

4. **Accuracy**
   - High accuracy for limited vocabulary (6 action words + numbers)
   - Context-aware (we know valid actions at any time)

5. **Cost-Effective**
   - Will process many short audio clips (1-3 seconds each)
   - Need to estimate cost per hand (~10-20 actions per hand)

---

## Cloud ASR Options to Research

### 1. Deepgram
- **Website:** https://deepgram.com
- **Streaming:** Yes, real-time WebSocket API
- **Languages:** 30+ including Polish
- **Keyword Boosting:** Yes, via `keywords` parameter
- **Latency:** ~300ms
- **Pricing:** Pay-per-minute, free tier available
- **Notes:** Popular for real-time applications

### 2. OpenAI Whisper API
- **Website:** https://platform.openai.com/docs/guides/speech-to-text
- **Streaming:** No (batch only)
- **Languages:** 50+ including Polish
- **Keyword Boosting:** Via `prompt` parameter (limited)
- **Latency:** 1-2 seconds
- **Pricing:** $0.006/minute
- **Notes:** Best accuracy, but not real-time

### 3. Google Cloud Speech-to-Text
- **Website:** https://cloud.google.com/speech-to-text
- **Streaming:** Yes
- **Languages:** 125+ including Polish
- **Keyword Boosting:** Yes, via `speechContexts.phrases`
- **Latency:** ~300-500ms
- **Pricing:** $0.006-0.009/minute depending on model
- **Notes:** Most mature, complex setup

### 4. Azure Speech Services
- **Website:** https://azure.microsoft.com/en-us/services/cognitive-services/speech-services/
- **Streaming:** Yes
- **Languages:** 100+ including Polish
- **Keyword Boosting:** Yes, via phrase lists
- **Latency:** ~300-500ms
- **Pricing:** $1/audio hour (~$0.017/minute)
- **Notes:** Good enterprise option

### 5. AssemblyAI
- **Website:** https://www.assemblyai.com
- **Streaming:** Yes, real-time WebSocket
- **Languages:** Multiple (check Polish support)
- **Keyword Boosting:** Yes, via word boost
- **Latency:** ~300ms
- **Pricing:** Pay-per-minute
- **Notes:** Developer-friendly API

### 6. Rev.ai
- **Website:** https://www.rev.ai
- **Streaming:** Yes
- **Languages:** Multiple (check Polish support)
- **Keyword Boosting:** Yes
- **Latency:** ~300-500ms
- **Notes:** Known for accuracy

### 7. Self-Hosted Whisper (via faster-whisper)
- **GitHub:** https://github.com/guillaumekln/faster-whisper
- **Streaming:** Can be implemented
- **Languages:** All Whisper languages (50+)
- **Keyword Boosting:** Via prompt engineering
- **Latency:** Depends on hardware (GPU recommended)
- **Pricing:** Infrastructure cost only
- **Notes:** Full control, no per-minute costs, requires GPU server

---

## Research Questions to Answer

1. **Polish language support quality**
   - Test each service with Polish poker terms
   - Test with Polish-accented English

2. **Keyword boosting effectiveness**
   - Does boosting "fold" actually improve recognition?
   - Can we boost Polish equivalents too?

3. **Real-time streaming setup**
   - WebSocket vs REST for each provider
   - How to stream from Flutter → Backend → Cloud ASR

4. **Cost estimation**
   - Assume 100 hands/session, 15 actions/hand = 1500 audio clips
   - Each clip ~2 seconds = 50 minutes of audio/session
   - Calculate monthly cost for active usage

5. **Latency in real conditions**
   - Test with actual poker club network conditions
   - Account for: recording → upload → ASR → response

---

## Proposed Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Flutter App    │────▶│  Python Backend │────▶│   Cloud ASR     │
│  (Dealer)       │     │  (WebSocket)    │     │   (Deepgram/    │
│                 │◀────│                 │◀────│    Whisper/etc) │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │
        │                       │
        ▼                       ▼
   Records audio          Parses response
   Sends via WS           Returns structured action
   Shows feedback         Logs to database
```

### Flow:
1. Dealer taps mic button (or continuous listening)
2. Flutter records audio, streams to Python backend via WebSocket
3. Backend forwards to Cloud ASR with vocabulary hints
4. Cloud ASR returns transcript
5. Backend parses transcript → structured action (fold/check/call/bet/raise/all-in + amount)
6. Backend returns action to Flutter
7. Flutter applies action to game state, shows feedback

---

## Files Reference

| File | Purpose |
|------|---------|
| `lib/services/continuous_speech_service.dart` | Current on-device implementation |
| `lib/screens/dealer/dealer_table_screen.dart` | Dealer UI with voice integration |
| `pubspec.yaml` | Dependencies (speech_to_text, fuzzywuzzy) |

---

## Next Steps

1. [x] Research and test top 3 ASR providers with Polish → **Deepgram selected**
2. [x] Build proof-of-concept with chosen provider → **Backend already built**
3. [x] Implement backend speech endpoint → **`/api/v1/speech/transcribe` exists**
4. [x] Update Flutter to use cloud ASR instead of on-device → **CloudSpeechService created**
5. [ ] Test in real poker environment

## Implementation Status (Feb 2026)

### What Was Done

**Root Cause Found:** The Flutter app was using on-device `speech_to_text` instead of the backend's Deepgram endpoint.

**Fix Applied:**
1. Created `lib/services/cloud_speech_service.dart` - HTTP client for backend
2. Updated `dealer_table_screen.dart` to use `CloudSpeechService`
3. Kept on-device service as potential fallback for offline mode

### Backend Endpoint (Already Built)

**Location:** `poker_friend_ai/app/api/routes/speech.py`

**Endpoint:** `POST /api/v1/speech/transcribe`

**Request:**
```json
{
  "audio_base64": "base64_encoded_wav_audio",
  "mimetype": "audio/wav",
  "language": "pl"
}
```

**Response:**
```json
{
  "transcript": "fold",
  "action": "fold",
  "amount": null,
  "confidence": 0.95,
  "success": true
}
```

### Testing Steps

1. Start Python backend: `cd poker_friend_ai && uvicorn app.main:app --reload --port 8000`
2. Update `app_config.dart` with your machine's IP if testing on real device
3. Run Flutter app
4. Open dealer mode, start a session
5. Toggle voice mode on
6. Say "fold", "check", "raise 500" etc.
7. Actions should be detected with high accuracy via Deepgram

---

## Notes

- On-device recognition will remain as fallback for offline mode
- Consider hybrid: on-device for quick feedback, cloud for verification
- MVP is in Poland - Polish language support is critical
