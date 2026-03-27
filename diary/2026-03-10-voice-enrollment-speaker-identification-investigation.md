# Voice Enrollment & Speaker Identification Investigation

**Date:** March 10, 2026
**Status:** BLOCKED - Technical Limitation Discovered
**Branch:** Current working branch

---

## Goal

Enable pre-enrolled dealers to skip the calibration phrase. When a dealer has enrolled their voice:
1. Tap voice button
2. Immediately start dictating poker actions
3. System recognizes dealer's voice and ONLY transcribes their speech
4. All other voices (TV, other people at table) are filtered out

---

## What We Built

### 1. Voice Enrollment (Cloud Function)
**File:** `functions/src/index.ts`

```typescript
// enrollSpeaker function
const grpcClient = new SpeechClient({ ... });
await grpcClient.addSpeaker({ name: speakerId }); // e.g., "dealer_FELwuk4XbvdibPCx9NesqP5dRIn1"
await grpcClient.addSpeakerAudio({ name: speakerId, audio: audioBuffer });
```

- User records voice sample in app
- Audio uploaded to Firebase Storage
- Cloud Function downloads audio and calls Soniox gRPC API
- Speaker profile stored in Soniox with ID like `dealer_FELwuk4XbvdibPCx9NesqP5dRIn1`

**Status:** Working correctly. Enrollment succeeds and speaker is stored in Soniox.

### 2. Real-time Speech Recognition
**File:** `lib/services/soniox_service.dart`

- Uses Soniox WebSocket API (`wss://stt-rt.soniox.com/transcribe-websocket`)
- Streams microphone audio in real-time
- Receives transcription tokens back

**Status:** Working. Speech is being transcribed.

---

## What We Tried

### Attempt 1: Speaker Identification Parameters

**Hypothesis:** Add `enable_speaker_identification: true` and `cand_speaker_names: [enrolledSpeakerId]` to WebSocket config. Soniox will match incoming audio to enrolled speaker profile.

**Code:**
```dart
final config = {
  'api_key': EnvConfig.sonioxApiKey,
  'model': 'stt-rt-preview',
  // ... other config ...
  'enable_speaker_diarization': true,
  'enable_speaker_identification': true,
  'cand_speaker_names': [enrolledSpeakerId], // e.g., "dealer_FELwuk4XbvdibPCx9NesqP5dRIn1"
};
```

**Expected Response:**
```json
{
  "speakers": {
    "1": { "name": "dealer_FELwuk4XbvdibPCx9NesqP5dRIn1" }
  },
  "tokens": [...]
}
```

**Actual Response:**
```json
{
  "tokens": [...],
  "final_audio_proc_ms": 123,
  "total_audio_proc_ms": 456
}
```

**Result:** FAILED. The `speakers` map is never returned. Debug logging showed:
```
RAW MESSAGE KEYS: [tokens, final_audio_proc_ms, total_audio_proc_ms]
speakerToNameMap={}
```

**Root Cause:** Soniox WebSocket API does NOT support speaker identification. The `enable_speaker_identification` and `cand_speaker_names` parameters are silently ignored.

---

### Attempt 2: Lock to First Speaker

**Hypothesis:** Since speaker identification doesn't work, use speaker diarization to separate speakers (1, 2, 3), then lock to the first speaker detected. Assumption: dealer will speak first after tapping button.

**Code:**
```dart
// Lock to first speaker we detect
for (final t in tokens) {
  final speaker = t['speaker']?.toString();
  if (speaker != null) {
    _enrolledDealerSpeakerNumber = speaker;
    break;
  }
}
```

**Result:** FAILED. Logs showed:
```
TOKEN STRUCTURE: {text: F, start_ms: 0, end_ms: 100, is_final: false}
TOKEN KEYS: [text, start_ms, end_ms, is_final]
```

The `speaker` field is not present in tokens. Diarization labels are not being returned.

---

### Attempt 3: Grace Period with Majority Speaker

**Hypothesis:** Track all speakers for 2 seconds, then lock to whoever spoke the most tokens. The active dealer calling actions should dominate over passive TV audio.

**Code:**
```dart
if (inGracePeriod) {
  for (final t in tokens) {
    final speaker = t['speaker']?.toString();
    if (speaker != null) {
      _enrolledSpeakerCounts[speaker] = (_enrolledSpeakerCounts[speaker] ?? 0) + 1;
    }
  }
  tokensToProcess = tokens; // Accept all during grace period
} else if (_enrolledDealerSpeakerNumber == null) {
  // Lock to majority speaker
  // ...
}
```

**Result:** FAILED. Logs showed:
```
[SonioxService] No speakers detected during grace period - accepting all voices
```

After 2 seconds, `_enrolledSpeakerCounts` was empty because no tokens ever had a `speaker` field.

---

## Key Finding: Diarization Not Working

Looking at the actual token structure from Soniox:
```dart
{text: "Fold", start_ms: 100, end_ms: 300, is_final: true}
```

**Missing:** The `speaker` field that should contain "1", "2", etc.

Even though we send `enable_speaker_diarization: true` in the config, the tokens don't include speaker labels. This could be because:

1. **Model limitation:** The `stt-rt-preview` model may not support diarization
2. **WebSocket API limitation:** Real-time WebSocket may not support diarization at all
3. **Configuration issue:** Something in our config is preventing diarization

---

## What Soniox APIs Actually Support

Based on investigation and documentation:

| Feature | gRPC API (Batch) | WebSocket API (Real-time) |
|---------|------------------|---------------------------|
| Basic Transcription | Yes | Yes |
| Speaker Diarization | Yes | **Unclear/Not Working** |
| Speaker Identification | Yes | **NO** |
| Enrolled Speaker Matching | Yes | **NO** |

The voice enrollment we implemented uses the gRPC API to store speaker profiles. However, **the WebSocket real-time API cannot access or match against these enrolled profiles**.

---

## Why Enrolled Voice is Useless

The fundamental problem:

1. **Enrollment uses gRPC API:** `grpcClient.addSpeaker()` and `addSpeakerAudio()` store the voice profile on Soniox's servers
2. **Real-time uses WebSocket API:** Our app streams audio via WebSocket for real-time transcription
3. **No bridge between them:** The WebSocket API cannot query or match against enrolled speakers

It's like storing a key in one lockbox (gRPC) but trying to unlock a different door (WebSocket) that doesn't accept that key.

---

## Current State of the Code

**File:** `lib/services/soniox_service.dart`

The code attempts a grace period approach, but since diarization isn't returning speaker labels, it falls back to "accepting all voices":

```
[SonioxService] No speakers detected during grace period - accepting all voices
```

This means TV audio and dealer voice are both transcribed, leading to garbage like:
```
"Fold. How people could tolerate shameless promotions so easily..."
```

---

## Possible Solutions

### Option A: Use Soniox Async API (Not Real-time)
- Record audio chunks
- Send to Soniox batch API with speaker identification
- Wait for response
- **Downside:** Not real-time. 2-5 second delay per utterance. Poor UX.

### Option B: Local Voice Activity Detection (VAD)
- Use on-device audio analysis to detect when someone is speaking
- Only send audio when speech is detected
- **Downside:** Doesn't distinguish WHOSE voice it is. TV audio would still pass through.

### Option C: Local Speaker Embedding
- Use a local ML model (e.g., TensorFlow Lite) to extract voice embeddings
- Compare real-time audio against enrolled voice embedding
- Only send audio that matches the dealer's voiceprint
- **Downside:** Complex to implement. Requires ML model. Battery/performance concerns.

### Option D: Hybrid Approach
- Use local speaker embedding for filtering
- Send only dealer's voice to Soniox for transcription
- Best of both worlds but most complex

### Option E: Keep Calibration Phrase
- Abandon pre-enrollment for real-time
- Use the existing calibration phrase approach
- Dealer says "Table X Dealer Y" to lock their voice via diarization (if it works)
- **Downside:** Defeats the purpose of enrollment

### Option F: Different Speech Provider
- Find a provider that supports real-time speaker identification
- Azure Speech Services, Google Cloud Speech have similar features
- **Downside:** Migration effort, potentially different accuracy

---

## What Soniox Documentation Says

From [Soniox Speaker Identification Docs](https://soniox.com/docs/how-to-guides/identify-speakers/):

> "Speaker identification allows you to identify known speakers in audio by matching their voice against pre-enrolled speaker profiles."

This is for the **batch/async API**, not real-time WebSocket.

From [Soniox WebSocket API Docs](https://soniox.com/docs/stt/api-reference/websocket-api):

The WebSocket API documentation does NOT mention:
- `enable_speaker_identification`
- `cand_speaker_names`
- Matching against enrolled speakers

It only mentions basic diarization (`enable_speaker_diarization`), which should label speakers as 1, 2, 3 - but even this doesn't seem to be working in our tests.

---

## Recommendations

### Short Term
1. **Test diarization independently:** Create a minimal test to verify if `enable_speaker_diarization: true` actually returns speaker labels in tokens. If not, contact Soniox support.

2. **Consider simpler UX:** Accept that pre-enrollment won't work for real-time. Keep the calibration phrase.

### Medium Term
3. **Explore local voice filtering:** Investigate on-device speaker embedding models that could pre-filter audio before sending to Soniox.

### Long Term
4. **Evaluate alternative providers:** Research if Azure, Google, or AWS offer real-time speaker identification.

---

## Files Modified During Investigation

- `lib/services/soniox_service.dart` - Main service with all speaker filtering attempts
- `lib/features/dealer_voice/cubit/dealer_voice_cubit.dart` - Cubit that orchestrates voice pipeline
- `functions/src/index.ts` - Cloud function for voice enrollment (working)

---

## Test Logs Reference

**Successful enrollment:**
```
DealerTableScreen: Enrolled speaker ID: dealer_FELwuk4XbvdibPCx9NesqP5dRIn1
```

**Failed speaker detection:**
```
[SonioxService] No speakers detected during grace period - accepting all voices
```

**TV audio being transcribed:**
```
[SonioxService] Received 21 tokens: " Call. How people could tolerate shameless promotions so easily."
```

---

## Conclusion

The voice enrollment feature was designed based on an incorrect assumption that Soniox's WebSocket API supports speaker identification. **It does not.**

The enrolled voice profile sits unused on Soniox's servers because the real-time API cannot access it. Until either:
- Soniox adds speaker identification to WebSocket API
- We implement local voice filtering
- We switch to a batch API (sacrificing real-time)

...the pre-enrollment feature will not work as intended.

---

**Last Updated:** March 10, 2026
