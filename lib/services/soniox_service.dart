import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/env_config.dart';
import 'continuous_speech_service.dart'; // For DetectedPokerAction class
import 'action_parser.dart';

/// Voice session state for the dealer authority system
enum VoiceSessionState {
  uninitialized, // No streaming, dealer mode not active
  calibrating, // Listening for dealer calibration phrase
  dealerLocked, // Locked to dealer, processing commands
  connectionLost, // Connection dropped, grace period active
  rotating, // Dealer rotation in progress
}

/// Result of calibration phrase validation
class _CalibrationValidation {
  final bool isValid;
  final String? dealerName;
  final String? tableName;
  _CalibrationValidation(this.isValid, this.dealerName, this.tableName);
}

/// Transcript-level debouncer to prevent duplicate rapid actions
class _TranscriptDebouncer {
  DateTime? _lastTime;
  String? _lastTranscript;
  List<_ActionSignature>? _lastParsedActions;
  int _currentOverlapCount = 0;  // Number of parsed actions to skip at start
  static const int cooldownMs = 500;

  /// Number of parsed actions to skip at start of current transcript (due to overlap)
  int get overlapCount => _currentOverlapCount;

  bool canProcess(String transcript) {
    final now = DateTime.now();
    final normalized = transcript.trim().toLowerCase();
    _currentOverlapCount = 0;  // Reset for each call

    // Check 1: Exact same transcript within cooldown
    if (_lastTime != null &&
        normalized == _lastTranscript &&
        now.difference(_lastTime!).inMilliseconds < cooldownMs) {
      // debugPrint('TranscriptDebouncer: Skipping exact duplicate within cooldown');
      return false;
    }

    // Check 2: New transcript is a PROPER suffix of previous
    // (Soniox sends trailing fragments as separate finals)
    // Proper suffix = previous ends with new AND they're not equal
    if (_lastTranscript != null &&
        _lastTranscript!.isNotEmpty &&
        _lastTranscript!.endsWith(normalized) &&
        normalized != _lastTranscript) {
      // debugPrint('TranscriptDebouncer: Skipping trailing fragment');
      return false;
    }

    _lastTime = now;
    _lastTranscript = normalized;
    // Note: _lastParsedActions will be updated by updateParsedActions()
    return true;
  }

  /// Update with parsed actions and calculate overlap
  /// Call this AFTER canProcess returns true, passing the parsed actions
  /// Returns number of actions to skip at start
  int updateParsedActions(List<ParsedAction> newActions) {
    final newSignatures = newActions.map((a) => _ActionSignature(a.action, a.amount)).toList();

    if (_lastParsedActions != null && _lastParsedActions!.isNotEmpty && newSignatures.isNotEmpty) {
      final overlap = _findStartEndOverlap(_lastParsedActions!, newSignatures);
      if (overlap > 0) {
        // debugPrint('TranscriptDebouncer: Found $overlap overlapping action(s)');
        _currentOverlapCount = overlap;
      }
    }

    _lastParsedActions = newSignatures;
    return _currentOverlapCount;
  }

  /// Find how many actions at the START of new match the END of prev
  int _findStartEndOverlap(List<_ActionSignature> prev, List<_ActionSignature> newActions) {
    final maxOverlap = prev.length < newActions.length ? prev.length : newActions.length;

    for (int overlapLen = maxOverlap; overlapLen > 0; overlapLen--) {
      final prevSuffix = prev.sublist(prev.length - overlapLen);
      final newPrefix = newActions.sublist(0, overlapLen);

      bool match = true;
      for (int i = 0; i < overlapLen; i++) {
        if (!prevSuffix[i].matches(newPrefix[i])) {
          match = false;
          break;
        }
      }

      if (match) {
        return overlapLen;
      }
    }

    return 0;
  }

  void reset() {
    _lastTime = null;
    _lastTranscript = null;
    _lastParsedActions = null;
    _currentOverlapCount = 0;
  }
}

/// Signature for comparing parsed actions
class _ActionSignature {
  final String action;
  final double? amount;

  _ActionSignature(this.action, this.amount);

  bool matches(_ActionSignature other) {
    if (action != other.action) return false;
    // For actions with amounts, amounts must match
    if (amount != null && other.amount != null) {
      return amount == other.amount;
    }
    // If one has amount and other doesn't, still consider it a match
    // (e.g., "raise 5" vs "raise" - the raise action itself matches)
    return true;
  }

  @override
  String toString() => amount != null ? '$action($amount)' : action;
}


/// Direct Soniox speech recognition service with Dealer Voice Authority.
///
/// Connects Flutter directly to Soniox WebSocket with speaker diarization
/// to identify and lock to the dealer's voice.
///
/// State machine:
/// UNINITIALIZED -> CALIBRATING -> DEALER_LOCKED
///                               -> CONNECTION_LOST -> CALIBRATING (after grace period)
///                               -> ROTATING -> CALIBRATING
class SonioxService {
  static final SonioxService _instance = SonioxService._internal();
  factory SonioxService() => _instance;
  SonioxService._internal();

  static SonioxService get instance => _instance;

  static const String _wsUrl = 'wss://stt-rt.soniox.com/transcribe-websocket';

  WebSocketChannel? _channel;
  StreamSubscription? _wsSubscription;
  AudioRecorder? _recorder;
  StreamSubscription? _audioSubscription;
  bool _isConnected = false;
  bool _isStreaming = false;

  // State machine
  VoiceSessionState _state = VoiceSessionState.uninitialized;
  String? _dealerSpeakerId;
  String? _dealerName;
  String? _tableName;

  // Calibration tracking
  final Map<String, int> _speakerTokenCounts = {};
  final Map<String, List<String>> _speakerTexts = {};
  DateTime? _calibrationStartTime;
  static const int calibrationDurationMs = 7000;
  static const double minConfidenceThreshold = 0.8;

  // Connection recovery
  DateTime? _connectionLostTime;
  Timer? _gracePeriodTimer;
  static const int gracePeriodMs = 5000;

  // Hold action mode
  bool _holdActionMode = false;

  final _TranscriptDebouncer _debouncer = _TranscriptDebouncer();
  Completer<void>? _finishedCompleter;
  String _lastPartialTranscript = '';

  // Stream controllers
  final _actionController = StreamController<DetectedPokerAction>.broadcast();
  final _partialController = StreamController<String>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  // Getters
  VoiceSessionState get state => _state;
  String? get dealerSpeakerId => _dealerSpeakerId;
  String? get dealerName => _dealerName;
  String? get tableName => _tableName;
  bool get isHoldingActions => _holdActionMode;

  /// Stream of parsed poker actions.
  Stream<DetectedPokerAction> get actionStream => _actionController.stream;

  /// Stream of partial transcriptions (for UI feedback).
  Stream<String> get partialStream => _partialController.stream;

  /// Stream of connection status updates.
  Stream<String> get statusStream => _statusController.stream;

  /// Whether currently streaming audio.
  bool get isStreaming => _isStreaming;

  /// Start speech recognition with dealer voice authority.
  ///
  /// Connects to Soniox with speaker diarization enabled and starts calibration.
  Future<bool> startStreaming({String language = 'auto'}) async {
    if (_isStreaming) {
      debugPrint('SonioxService: Already streaming');
      return true;
    }

    try {
      _lastPartialTranscript = '';

      // Set state to calibrating
      _state = VoiceSessionState.calibrating;
      _calibrationStartTime = DateTime.now();
      _speakerTokenCounts.clear();
      _speakerTexts.clear();

      _statusController.add('calibrating');

      // Connect to Soniox WebSocket
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));

      // Send configuration with poker context and speaker diarization
      final config = {
        'api_key': EnvConfig.sonioxApiKey,
        'model': 'stt-rt-preview',
        'audio_format': 's16le',
        'sample_rate': 16000,
        'num_channels': 1,
        'language_hints': ['en', 'pl'],
        'enable_speaker_diarization': true,
        'context': {
          'general': [
            {'key': 'domain', 'value': 'Poker'},
            {'key': 'topic', 'value': 'Live poker dealer commands'},
          ],
          'text':
              'Dealer announces table and name, then player actions. Common actions include fold, check, call, bet, raise, reraise, and all-in.',
          'terms': [
            'table',
            'dealer',
            'fold',
            'check',
            'call',
            'bet',
            'raise',
            'reraise',
            're-raise',
            'all-in',
            'all in',
            'shove',
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

      _channel!.sink.add(jsonEncode(config));

      // Listen for transcriptions
      _wsSubscription = _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          debugPrint('SonioxService: WebSocket error: $error');
          _statusController.add('error: $error');
          _isConnected = false;
        },
        onDone: () {
          debugPrint('SonioxService: WebSocket closed');
          _handleConnectionLoss();
        },
      );

      _isConnected = true;
      _statusController.add('connected');

      // Start audio recording
      _recorder = AudioRecorder();

      // Check permission
      final hasPermission = await _recorder!.hasPermission();
      if (!hasPermission) {
        debugPrint('SonioxService: No microphone permission');
        _statusController.add('no_permission');
        await stopStreaming();
        return false;
      }

      // Start streaming audio
      final audioStream = await _recorder!.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      _audioSubscription = audioStream.listen(
        (data) {
          if (_channel != null && _isConnected) {
            _channel!.sink.add(Uint8List.fromList(data));
          }
        },
        onError: (e) => debugPrint('SonioxService: Audio error: $e'),
      );

      _isStreaming = true;
      _statusController.add('streaming');
      return true;
    } catch (e) {
      debugPrint('SonioxService: Failed to start: $e');
      _statusController.add('error: $e');
      await stopStreaming();
      return false;
    }
  }

  /// Handle connection loss with grace period
  void _handleConnectionLoss() {
    if (_state == VoiceSessionState.dealerLocked) {
      _state = VoiceSessionState.connectionLost;
      _connectionLostTime = DateTime.now();
      _statusController.add('connection_lost');
      _startGracePeriodTimer();
    } else {
      _statusController.add('disconnected');
    }
    _isConnected = false;
  }

  /// Start grace period timer for connection recovery
  void _startGracePeriodTimer() {
    _gracePeriodTimer?.cancel();
    _gracePeriodTimer = Timer(Duration(milliseconds: gracePeriodMs), () {
      if (_state == VoiceSessionState.connectionLost) {
        // Grace period expired, require recalibration
        _state = VoiceSessionState.calibrating;
        _dealerSpeakerId = null;
        _dealerName = null;
        _tableName = null;
        _statusController.add('grace_period_expired');
        // Attempt to reconnect
        startStreaming();
      }
    });
  }

  /// Handle incoming WebSocket messages from Soniox.
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);

      // Check for errors
      if (data['error_code'] != null) {
        debugPrint('SonioxService: Error: ${data['error_message']}');
        _statusController.add('error: ${data['error_message']}');
        return;
      }

      // Check for session finished
      if (data['finished'] == true) {
        debugPrint('SonioxService: Session finished');
        _finishedCompleter?.complete();
        return;
      }

      // Process tokens based on state
      final tokens = data['tokens'] as List?;
      if (tokens == null || tokens.isEmpty) {
        return;
      }

      switch (_state) {
        case VoiceSessionState.calibrating:
          _processCalibrationTokens(tokens);
          break;
        case VoiceSessionState.dealerLocked:
          _processDealerTokens(tokens);
          break;
        case VoiceSessionState.connectionLost:
          // Check if we can recover - same speaker reconnected
          _checkConnectionRecovery(tokens);
          break;
        case VoiceSessionState.rotating:
        case VoiceSessionState.uninitialized:
          // Ignore tokens in these states
          break;
      }
    } catch (e) {
      debugPrint('SonioxService: Message parse error: $e');
    }
  }

  /// Process tokens during calibration phase
  void _processCalibrationTokens(List tokens) {
    for (final t in tokens) {
      final speaker = t['speaker'] as String?;
      final text = t['text'] as String? ?? '';
      final isFinal = t['is_final'] == true;

      // Track speaker by counting tokens
      final speakerId = speaker?.toString() ?? 'default';
      _speakerTokenCounts[speakerId] = (_speakerTokenCounts[speakerId] ?? 0) + 1;

      // Only store FINAL tokens for text validation (avoids duplicates)
      if (isFinal && text.isNotEmpty) {
        _speakerTexts.putIfAbsent(speakerId, () => []).add(text);
      }
    }

    // Emit partial for UI feedback
    final allText = tokens.map((t) => t['text'] ?? '').join('');
    if (allText.trim().isNotEmpty) {
      _partialController.add(allText.trim().toLowerCase());
    }

    // Check if calibration window complete
    final elapsed =
        DateTime.now().difference(_calibrationStartTime!).inMilliseconds;
    if (elapsed >= calibrationDurationMs) {
      _finalizeCalibration();
    }
  }

  /// Finalize calibration with dual validation
  void _finalizeCalibration() {
    if (_speakerTokenCounts.isEmpty) {
      _statusController.add('calibration_failed:no_speakers');
      // Stay in calibrating, allow retry
      _speakerTokenCounts.clear();
      _speakerTexts.clear();
      _calibrationStartTime = DateTime.now();
      return;
    }

    // Signal 1: Find majority speaker
    String? majoritySpeaker;
    int maxTokens = 0;
    _speakerTokenCounts.forEach((speaker, count) {
      if (count > maxTokens) {
        maxTokens = count;
        majoritySpeaker = speaker;
      }
    });

    // Signal 2: Content validation
    // Join tokens WITHOUT spaces since Soniox sends partial tokens
    // Then normalize by collapsing multiple spaces
    final rawText = _speakerTexts[majoritySpeaker]?.join('').toLowerCase() ?? '';
    final speakerText = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();

    final validationResult = _validateCalibrationPhrase(speakerText);

    if (!validationResult.isValid) {
      _statusController.add('calibration_failed:content_mismatch');
      // Stay in calibrating, allow retry
      _speakerTokenCounts.clear();
      _speakerTexts.clear();
      _calibrationStartTime = DateTime.now();
      return;
    }

    // Both signals agree - lock dealer
    // If speaker diarization isn't available, majoritySpeaker will be 'default'
    // In that case, we still process all speech but can't filter by speaker
    _dealerSpeakerId = majoritySpeaker;
    _dealerName = validationResult.dealerName;
    _tableName = validationResult.tableName;
    _state = VoiceSessionState.dealerLocked;
    _speakerTokenCounts.clear();
    _speakerTexts.clear();

    _statusController.add('dealer_locked:$_dealerName:$_tableName');
  }

  /// Validate calibration phrase contains required keywords
  /// More lenient validation - if we have "table" OR "dealer" and someone is speaking,
  /// that's enough to identify them as the dealer
  _CalibrationValidation _validateCalibrationPhrase(String text) {
    final hasTable = text.contains('table');
    final hasDealer = text.contains('dealer');

    // Also accept common variations
    final hasTableNumber = RegExp(r'table\s*\d+').hasMatch(text) ||
                           RegExp(r'table\s+\w+').hasMatch(text);

    // Extract table name/number
    final tableMatch = RegExp(r'table\s+(\w+)').firstMatch(text);

    // Extract dealer name - get word after "dealer" (even if it's a poker term)
    final dealerMatch = RegExp(r'dealer\s+(\w+)').firstMatch(text);

    // Accept if we have EITHER "table" OR "dealer" keyword
    // The speaker diarization is the primary signal - whoever speaks IS the dealer
    if (!hasTable && !hasDealer) {
      return _CalibrationValidation(false, null, null);
    }

    // Extract names, defaulting to reasonable values
    String? dealerName = dealerMatch?.group(1);
    String? tableName = tableMatch?.group(1);

    // If dealer name is a poker term, it was likely misheard - use "Dealer" as default
    final pokerTerms = ['fold', 'check', 'call', 'bet', 'raise', 'all-in', 'shove'];
    if (dealerName != null && pokerTerms.contains(dealerName.toLowerCase())) {
      dealerName = 'Dealer';
    }

    return _CalibrationValidation(
      true,
      dealerName ?? 'Dealer',
      tableName ?? 'Table',
    );
  }

  /// Process tokens when locked to dealer
  void _processDealerTokens(List tokens) {
    // Filter to dealer only (if diarization is available)
    // If dealerSpeakerId is 'default', process all tokens
    final dealerTokens = tokens.where((t) {
      final speaker = t['speaker'] as String?;
      // Accept token if:
      // 1. No speaker ID (diarization not available for this token)
      // 2. Speaker matches our locked dealer
      // 3. Our dealer is 'default' (no diarization at all)
      return speaker == null ||
             speaker == _dealerSpeakerId ||
             _dealerSpeakerId == 'default';
    }).toList();

    if (dealerTokens.isEmpty) {
      // Someone OTHER than the dealer is speaking - ignore
      return;
    }

    final text = dealerTokens.map((t) => t['text'] ?? '').join('');
    final anyFinal = dealerTokens.any((t) => t['is_final'] == true);

    if (text.trim().isEmpty) return;

    final transcript = text.trim().toLowerCase();
    _lastPartialTranscript = transcript;
    _partialController.add(transcript);

    if (!anyFinal) return;

    // Check hold action mode
    if (_holdActionMode) {
      _statusController.add('action_held:$transcript');
      return;
    }

    _processTranscriptAsAction(transcript);
  }

  /// Check if connection can be recovered with same dealer
  void _checkConnectionRecovery(List tokens) {
    // Check if majority speaker is still our dealer
    final dealerTokenCount = tokens
        .where((t) => t['speaker'] == _dealerSpeakerId)
        .length;

    if (dealerTokenCount > tokens.length / 2) {
      // Dealer reconnected within grace period
      _gracePeriodTimer?.cancel();
      _state = VoiceSessionState.dealerLocked;
      _statusController.add('connection_recovered');

      // Process any tokens we just received
      _processDealerTokens(tokens);
    }
  }

  /// Parse transcript and emit detected actions
  void _processTranscriptAsAction(String transcript) {
    if (!_debouncer.canProcess(transcript)) {
      return;
    }

    final actions = ActionParser.parse(transcript);

    // Check for start-end overlap with previous transcript
    final overlapCount = _debouncer.updateParsedActions(actions);

    // Skip if ALL actions are overlap
    if (overlapCount >= actions.length) {
      return;
    }

    // Start from overlapCount to skip overlapping actions
    for (int i = overlapCount; i < actions.length; i++) {
      final parsed = actions[i];

      // Trigger haptic feedback
      HapticFeedback.mediumImpact();

      // Create DetectedPokerAction
      final action = DetectedPokerAction(
        action: parsed.action,
        amount: parsed.amount,
        confidence: parsed.confidence,
        transcript: transcript,
        matchScore: 100,
      );

      _actionController.add(action);
    }
  }

  /// Enable hold action mode - transcriptions received but not executed
  void enableHoldAction() {
    _holdActionMode = true;
    _statusController.add('hold_action:enabled');
  }

  /// Disable hold action mode - resume action execution
  void disableHoldAction() {
    _holdActionMode = false;
    _statusController.add('hold_action:disabled');
  }

  /// Toggle hold action mode
  void toggleHoldAction() {
    if (_holdActionMode) {
      disableHoldAction();
    } else {
      enableHoldAction();
    }
  }

  /// Start dealer rotation - clears current dealer, requires new calibration
  Future<void> rotateDealer() async {
    if (_state == VoiceSessionState.uninitialized) return;

    _state = VoiceSessionState.rotating;
    _statusController.add('rotating');

    // Close current session
    await stopStreaming();

    // Clear dealer identity
    _dealerSpeakerId = null;
    _dealerName = null;
    _tableName = null;
    _holdActionMode = false;

    // Start new session for calibration
    await startStreaming();
  }

  /// Manual recalibration - clears dealer and restarts calibration
  void recalibrate() {
    if (_state == VoiceSessionState.uninitialized) return;

    _dealerSpeakerId = null;
    _dealerName = null;
    _tableName = null;
    _speakerTokenCounts.clear();
    _speakerTexts.clear();
    _calibrationStartTime = DateTime.now();
    _state = VoiceSessionState.calibrating;
    _holdActionMode = false;

    _statusController.add('recalibrating');
  }

  /// Stop speech recognition.
  /// Waits for Soniox to send final transcription before closing.
  Future<void> stopStreaming() async {
    if (!_isStreaming) return;

    _isStreaming = false;
    _gracePeriodTimer?.cancel();

    // 1. Stop audio recording (mic off)
    await _audioSubscription?.cancel();
    _audioSubscription = null;

    if (_recorder != null) {
      try {
        await _recorder!.stop();
      } catch (_) {}
      _recorder = null;
    }

    // 2. Send end signal and wait for "finished" from Soniox
    if (_channel != null && _isConnected) {
      try {
        _finishedCompleter = Completer<void>();

        // Send empty audio packet to signal end of stream
        // Note: Soniox doesn't accept JSON control messages after config
        _channel!.sink.add(Uint8List(0));

        // Wait for finished signal (max 300ms timeout - shorter since we may not get response)
        bool timedOut = false;
        await _finishedCompleter!.future.timeout(
          const Duration(milliseconds: 300),
          onTimeout: () => timedOut = true,
        );

        // Fallback: if timed out, process last partial transcript
        if (timedOut && _lastPartialTranscript.isNotEmpty && !_holdActionMode) {
          debugPrint(
              'SonioxService: Processing partial: "$_lastPartialTranscript"');
          _processTranscriptAsAction(_lastPartialTranscript);
        }
      } catch (e) {
        debugPrint('SonioxService: Error waiting for finish: $e');
      }
    }

    // 3. Now close WebSocket
    await _wsSubscription?.cancel();
    _wsSubscription = null;

    if (_channel != null) {
      try {
        await _channel!.sink.close();
      } catch (_) {}
      _channel = null;
    }

    _isConnected = false;
    _finishedCompleter = null;
    _lastPartialTranscript = '';
    _debouncer.reset();

    // Reset state only if we're doing a full stop
    if (_state != VoiceSessionState.rotating) {
      _state = VoiceSessionState.uninitialized;
    }

    _statusController.add('stopped');
  }

  /// Dispose the service.
  void dispose() {
    stopStreaming();
    _gracePeriodTimer?.cancel();
    _actionController.close();
    _partialController.close();
    _statusController.close();
  }
}
