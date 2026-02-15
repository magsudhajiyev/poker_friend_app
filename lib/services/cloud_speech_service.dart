import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../config/app_config.dart';
import 'continuous_speech_service.dart'; // For DetectedPokerAction class

/// Voice Activity Detection states
enum VADState { listening, recording, processing }

/// Cloud-based speech recognition service with NON-STOP listening.
///
/// Key design: NEVER stop listening while processing.
/// - Records in short segments (1.5 seconds)
/// - Processes previous segment while recording next one
/// - Always listening, processing happens in parallel
class CloudSpeechService {
  static final CloudSpeechService _instance = CloudSpeechService._internal();
  factory CloudSpeechService() => _instance;
  CloudSpeechService._internal();

  static CloudSpeechService get instance => _instance;

  AudioRecorder? _recorder;

  bool _isRecording = false;
  bool _isContinuousMode = false;
  String? _currentRecordingPath;
  Timer? _segmentTimer;
  Timer? _amplitudeTimer;

  // VAD state
  VADState _vadState = VADState.listening;
  double _currentAmplitude = -60.0;
  double _peakAmplitude = -60.0;
  bool _speechDetectedInSegment = false;

  // Processing state (for UI feedback, doesn't block listening)
  bool _isProcessing = false;

  // Thresholds
  static const double speechThresholdDb = -40.0; // Lower threshold to catch quieter speech
  static const int segmentDurationMs = 2500; // 2.5 second segments for complete phrases

  // Language setting
  String _language = 'en';

  // Debouncer
  final _ActionDebouncer _debouncer = _ActionDebouncer();

  // Stream controllers
  final _actionController = StreamController<DetectedPokerAction>.broadcast();
  Stream<DetectedPokerAction> get actionStream => _actionController.stream;

  final _statusController = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  final _partialController = StreamController<String>.broadcast();
  Stream<String> get partialStream => _partialController.stream;

  final _amplitudeController = StreamController<double>.broadcast();
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  final _vadStateController = StreamController<VADState>.broadcast();
  Stream<VADState> get vadStateStream => _vadStateController.stream;

  bool get isRecording => _isRecording;
  bool get isContinuousMode => _isContinuousMode;
  String get language => _language;
  VADState get vadState => _vadState;
  double get currentAmplitude => _currentAmplitude;

  void setLanguage(String languageCode) {
    _language = languageCode;
  }

  Future<bool> isAvailable() async {
    try {
      _recorder ??= AudioRecorder();
      return await _recorder!.hasPermission();
    } catch (e) {
      debugPrint('CloudSpeechService: Error checking availability: $e');
      return false;
    }
  }

  /// Start recording a new segment
  Future<bool> _startSegmentRecording() async {
    try {
      _recorder ??= AudioRecorder();

      if (!await _recorder!.hasPermission()) {
        return false;
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${tempDir.path}/poker_speech_$timestamp.wav';

      await _recorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      _speechDetectedInSegment = false;
      _peakAmplitude = -60.0;

      return true;
    } catch (e) {
      debugPrint('CloudSpeechService: Error starting recording: $e');
      _isRecording = false;
      return false;
    }
  }

  /// Stop current recording and return the file path (fast operation)
  Future<String?> _stopSegmentRecording() async {
    if (!_isRecording || _recorder == null) return null;

    try {
      final path = await _recorder!.stop();
      _isRecording = false;
      return path;
    } catch (e) {
      debugPrint('CloudSpeechService: Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Read audio file and return bytes (can run in parallel with new recording)
  Future<List<int>?> _readAudioFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;

      final audioBytes = await file.readAsBytes();
      try { await file.delete(); } catch (e) { /* ignore */ }

      return audioBytes;
    } catch (e) {
      debugPrint('CloudSpeechService: Error reading audio file: $e');
      return null;
    }
  }

  /// Transcribe audio bytes using Dealer Brain (semantic multi-action parsing)
  Future<List<DetectedPokerAction>> _transcribeWithBrain(List<int> audioBytes) async {
    final endpoint = '${AppConfig.serverUrl}/api/v1/speech/transcribe-brain';
    debugPrint('CloudSpeechService: Sending ${audioBytes.length} bytes to $endpoint');

    try {
      final base64Audio = base64Encode(audioBytes);

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'audio_base64': base64Audio,
          'mimetype': 'audio/wav',
          'language': _language,
        }),
      ).timeout(const Duration(seconds: 10));

      debugPrint('CloudSpeechService: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final transcript = data['transcript'] as String? ?? '';
        final actionsList = data['actions'] as List<dynamic>? ?? [];
        final success = data['success'] as bool? ?? false;
        final error = data['error'] as String?;

        debugPrint('CloudSpeechService: Transcript: "$transcript", actions: ${actionsList.length}, success: $success, error: $error');

        if (success && actionsList.isNotEmpty) {
          final actions = <DetectedPokerAction>[];

          for (final actionData in actionsList) {
            final action = actionData['action'] as String?;
            final amount = actionData['amount'] != null
                ? (actionData['amount'] as num).toDouble()
                : null;
            final confidence = (actionData['confidence'] as num?)?.toDouble() ?? 0.9;

            if (action != null) {
              actions.add(DetectedPokerAction(
                action: action,
                amount: amount,
                confidence: confidence,
                transcript: transcript,
              ));
            }
          }

          if (actions.isNotEmpty) {
            debugPrint('CloudSpeechService: Brain parsed "$transcript" -> ${actions.map((a) => a.action).toList()}');
            return actions;
          }
        } else if (transcript.isNotEmpty) {
          debugPrint('CloudSpeechService: Heard "$transcript" but no actions detected');
        } else {
          debugPrint('CloudSpeechService: Empty transcript received');
        }
      } else {
        debugPrint('CloudSpeechService: HTTP error ${response.statusCode}: ${response.body}');
      }
      return [];
    } catch (e, stackTrace) {
      debugPrint('CloudSpeechService: Brain transcription error: $e');
      debugPrint('CloudSpeechService: Stack trace: $stackTrace');
      return [];
    }
  }

  // ============================================================
  // NON-STOP CONTINUOUS LISTENING
  // ============================================================

  Future<bool> startContinuousListening() async {
    if (_isContinuousMode) {
      return true;
    }

    await _cleanup();

    if (!await isAvailable()) {
      debugPrint('CloudSpeechService: Microphone not available');
      return false;
    }

    _isContinuousMode = true;
    _debouncer.reset();
    _vadState = VADState.listening;
    _isProcessing = false;
    _vadStateController.add(_vadState);
    _statusController.add('listening');
    _partialController.add('Listening...');

    // Start the recording loop
    _startRecordingLoop();

    debugPrint('CloudSpeechService: Non-stop listening started');
    return true;
  }

  Future<void> stopContinuousListening() async {
    debugPrint('CloudSpeechService: Stopping');
    _isContinuousMode = false;
    await _cleanup();

    _vadState = VADState.listening;
    _isProcessing = false;
    _vadStateController.add(_vadState);
    _statusController.add('stopped');
    _partialController.add('');
    _amplitudeController.add(-60.0);
  }

  Future<void> _cleanup() async {
    _segmentTimer?.cancel();
    _segmentTimer = null;
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;

    if (_isRecording && _recorder != null) {
      try { await _recorder!.stop(); } catch (e) { /* ignore */ }
      _isRecording = false;
    }

    _recorder?.dispose();
    _recorder = null;
  }

  /// Main recording loop - runs continuously
  void _startRecordingLoop() async {
    if (!_isContinuousMode) return;

    // Start recording
    final started = await _startSegmentRecording();
    if (!started) {
      debugPrint('CloudSpeechService: Failed to start recording');
      _partialController.add('Mic error');
      // Retry after delay
      if (_isContinuousMode) {
        Future.delayed(const Duration(seconds: 1), _startRecordingLoop);
      }
      return;
    }

    // Update UI
    if (!_isProcessing) {
      _partialController.add('Listening...');
    }

    // Monitor amplitude during this segment
    _startAmplitudeMonitoring();

    // Schedule end of this segment
    _segmentTimer?.cancel();
    _segmentTimer = Timer(Duration(milliseconds: segmentDurationMs), () {
      _endSegmentAndContinue();
    });
  }

  void _startAmplitudeMonitoring() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) async {
      if (!_isRecording || !_isContinuousMode || _recorder == null) {
        timer.cancel();
        return;
      }

      try {
        final amplitude = await _recorder!.getAmplitude();
        _currentAmplitude = amplitude.current;
        _amplitudeController.add(_currentAmplitude);

        if (_currentAmplitude > _peakAmplitude) {
          _peakAmplitude = _currentAmplitude;
        }

        // Detect speech
        if (_currentAmplitude > speechThresholdDb && !_speechDetectedInSegment) {
          _speechDetectedInSegment = true;
          _vadState = VADState.recording;
          _vadStateController.add(_vadState);
          if (!_isProcessing) {
            _partialController.add('Speaking...');
          }
        }
      } catch (e) {
        // Ignore amplitude errors
      }
    });
  }

  /// End current segment and IMMEDIATELY start next one
  /// Key: Minimize gap between recordings by separating stop from file read
  void _endSegmentAndContinue() async {
    if (!_isContinuousMode) return;

    _amplitudeTimer?.cancel();

    // Capture segment data before stopping
    final hadSpeech = _speechDetectedInSegment;
    final peak = _peakAmplitude;

    // STEP 1: Stop recording (fast - just stops the recorder, doesn't read file)
    final audioPath = await _stopSegmentRecording();

    // STEP 2: IMMEDIATELY start next segment - before reading file!
    // This minimizes the gap between recordings
    if (_isContinuousMode) {
      _startRecordingLoop();
    }

    // STEP 3: Read and process old file in background (parallel with new recording)
    // Always process if we have audio, even if speech wasn't detected (catches quiet commands)
    if (audioPath != null && audioPath.isNotEmpty) {
      _readAndProcessInBackground(audioPath, peak, hadSpeech);
    }
  }

  /// Read audio file and process it - runs completely in background
  void _readAndProcessInBackground(String audioPath, double peakAmplitude, bool hadSpeech) async {
    // Read the file (this happens while new recording is already running)
    final audioBytes = await _readAudioFile(audioPath);

    if (audioBytes == null || audioBytes.isEmpty) return;

    // Always send to Deepgram - let it decide if there's speech
    // This catches quiet commands that might be below our threshold
    _processAudioInBackground(audioBytes, peakAmplitude);
  }

  /// Process audio in background - doesn't block recording
  /// Uses Dealer Brain for semantic multi-action parsing
  void _processAudioInBackground(List<int> audioBytes, double peakAmplitude) async {
    _isProcessing = true;
    _vadState = VADState.processing;
    _vadStateController.add(_vadState);
    _partialController.add('Processing...');

    debugPrint('CloudSpeechService: Processing segment (peak: ${peakAmplitude.toStringAsFixed(1)} dB)');

    // Use brain for semantic parsing - returns multiple actions
    final actions = await _transcribeWithBrain(audioBytes);

    _isProcessing = false;

    if (!_isContinuousMode) return; // Stopped while processing

    if (actions.isNotEmpty) {
      // Check batch-level debouncing (prevents duplicate utterances)
      final actionTypes = actions.map((a) => a.action).toList();

      if (!_debouncer.canExecuteBatch(actionTypes)) {
        debugPrint('CloudSpeechService: Duplicate batch rejected: $actionTypes');
        // Still update UI back to listening
      } else {
        // Emit each action with a small delay between them
        final actionStrings = <String>[];

        for (final action in actions) {
          _actionController.add(action);
          actionStrings.add('${action.action.toUpperCase()}${action.amount != null ? ' ${action.amount!.toInt()}' : ''}');

          // Small delay between actions for UI to process
          if (actions.length > 1) {
            await Future.delayed(const Duration(milliseconds: 200));
          }
        }

        if (actionStrings.isNotEmpty) {
          // Show all detected actions briefly
          _partialController.add('✓ ${actionStrings.join(' → ')}');
          await Future.delayed(const Duration(milliseconds: 800));
        }
      }
    }

    // Update UI back to listening (if still active and not processing another)
    if (_isContinuousMode && !_isProcessing) {
      _vadState = _speechDetectedInSegment ? VADState.recording : VADState.listening;
      _vadStateController.add(_vadState);
      _partialController.add(_speechDetectedInSegment ? 'Speaking...' : 'Listening...');
    }
  }

  void dispose() {
    _isContinuousMode = false;
    _cleanup();
    _actionController.close();
    _statusController.close();
    _partialController.close();
    _amplitudeController.close();
    _vadStateController.close();
  }
}

/// Debouncer to prevent duplicate rapid actions from SEPARATE utterances
/// Allows same action in quick succession when part of the same phrase (multi-action)
class _ActionDebouncer {
  DateTime? _lastBatchTime;
  List<String> _lastBatchActions = [];

  // Cooldown between separate utterances (not within same phrase)
  static const int batchCooldownMs = 1500;

  /// Check if we can execute this batch of actions
  /// Multi-action batches from the same phrase are allowed
  bool canExecuteBatch(List<String> actions) {
    final now = DateTime.now();

    if (_lastBatchTime == null) {
      _lastBatchTime = now;
      _lastBatchActions = List.from(actions);
      return true;
    }

    final elapsed = now.difference(_lastBatchTime!).inMilliseconds;

    // If same exact batch within cooldown, reject (duplicate utterance)
    if (elapsed < batchCooldownMs && _listEquals(actions, _lastBatchActions)) {
      return false;
    }

    _lastBatchTime = now;
    _lastBatchActions = List.from(actions);
    return true;
  }

  /// For single action compatibility - always allows within a batch
  bool canExecute(String action) {
    // Single actions within a batch are always allowed
    // The batch-level debouncing handles duplicates
    return true;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void reset() {
    _lastBatchTime = null;
    _lastBatchActions = [];
  }
}
