import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'continuous_speech_service.dart'; // For DetectedPokerAction class
import 'action_parser.dart';

/// Debouncer to prevent duplicate rapid actions.
class _ActionDebouncer {
  DateTime? _lastActionTime;
  String? _lastAction;

  // Timing for real-time speech:
  // - 800ms same-action allows natural "fold fold" with pause
  // - 200ms any-action catches rapid duplicates
  static const int sameActionCooldownMs = 800;
  static const int anyActionCooldownMs = 200;

  bool canExecute(String action) {
    final now = DateTime.now();
    if (_lastActionTime == null) {
      _lastActionTime = now;
      _lastAction = action;
      return true;
    }

    final elapsed = now.difference(_lastActionTime!).inMilliseconds;

    if (action == _lastAction && elapsed < sameActionCooldownMs) {
      return false;
    }

    if (elapsed < anyActionCooldownMs) {
      return false;
    }

    _lastActionTime = now;
    _lastAction = action;
    return true;
  }

  void reset() {
    _lastActionTime = null;
    _lastAction = null;
  }
}

/// Direct Soniox speech recognition service.
///
/// Connects Flutter directly to Soniox WebSocket, bypassing the Python backend
/// for minimal latency (~100-200ms total).
///
/// Drop-in replacement for RealtimeSpeechService.
class SonioxService {
  static final SonioxService _instance = SonioxService._internal();
  factory SonioxService() => _instance;
  SonioxService._internal();

  static SonioxService get instance => _instance;

  static const String _wsUrl = 'wss://stt-rt.soniox.com/transcribe-websocket';
  static const String _apiKey = 'd6b70a1463e1c697ae879aefa9b7e0586e1c8b027cc165b58614798fc9fb6ada';

  WebSocketChannel? _channel;
  StreamSubscription? _wsSubscription;
  AudioRecorder? _recorder;
  StreamSubscription? _audioSubscription;
  bool _isConnected = false;
  bool _isStreaming = false;

  final _ActionDebouncer _debouncer = _ActionDebouncer();
  Completer<void>? _finishedCompleter;
  String _lastPartialTranscript = ''; // Track last partial for fallback

  // Stream controllers
  final _actionController = StreamController<DetectedPokerAction>.broadcast();
  final _partialController = StreamController<String>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  /// Stream of parsed poker actions.
  Stream<DetectedPokerAction> get actionStream => _actionController.stream;

  /// Stream of partial transcriptions (for UI feedback).
  Stream<String> get partialStream => _partialController.stream;

  /// Stream of connection status updates.
  Stream<String> get statusStream => _statusController.stream;

  /// Whether currently streaming audio.
  bool get isStreaming => _isStreaming;

  /// Start speech recognition.
  ///
  /// Connects to Soniox and starts streaming audio from microphone.
  Future<bool> startStreaming({String language = 'auto'}) async {
    if (_isStreaming) {
      debugPrint('SonioxService: Already streaming');
      return true;
    }

    try {
      _lastPartialTranscript = '';
      _statusController.add('connecting');

      // Connect to Soniox WebSocket
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));

      // Send configuration with poker context
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
          _statusController.add('disconnected');
          _isConnected = false;
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

      // Process tokens
      final tokens = data['tokens'] as List?;
      if (tokens == null || tokens.isEmpty) {
        return;
      }

      // Concatenate all token texts
      final text = tokens.map((t) => t['text'] ?? '').join('');
      final anyFinal = tokens.any((t) => t['is_final'] == true);

      if (text.trim().isEmpty) {
        return;
      }

      final transcript = text.trim().toLowerCase();

      // Store last partial for fallback when stopping
      _lastPartialTranscript = transcript;

      // Emit partial for UI feedback
      _partialController.add(transcript);

      // Only parse final transcriptions
      if (!anyFinal) {
        return;
      }

      debugPrint('SonioxService: Final transcript: "$transcript"');
      _processTranscriptAsAction(transcript);
    } catch (e) {
      debugPrint('SonioxService: Message parse error: $e');
    }
  }

  /// Parse transcript and emit detected actions
  void _processTranscriptAsAction(String transcript) {
    final actions = ActionParser.parse(transcript);

    for (final parsed in actions) {
      // Apply debouncer
      if (!_debouncer.canExecute(parsed.action)) {
        continue;
      }

      // Create DetectedPokerAction
      final action = DetectedPokerAction(
        action: parsed.action,
        amount: parsed.amount,
        confidence: parsed.confidence,
        transcript: transcript,
        matchScore: 100,
      );

      debugPrint('SonioxService: Action detected: $action');
      _actionController.add(action);
    }
  }

  /// Stop speech recognition.
  /// Waits for Soniox to send final transcription before closing.
  Future<void> stopStreaming() async {
    if (!_isStreaming) return;

    _isStreaming = false;

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

        // Send end signals to Soniox
        _channel!.sink.add(Uint8List(0)); // Empty audio signal
        _channel!.sink.add(jsonEncode({'eof': true})); // JSON EOF signal

        // Wait for finished signal (max 500ms timeout)
        bool timedOut = false;
        await _finishedCompleter!.future.timeout(
          const Duration(milliseconds: 500),
          onTimeout: () => timedOut = true,
        );

        // Fallback: if timed out, process last partial transcript
        if (timedOut && _lastPartialTranscript.isNotEmpty) {
          debugPrint('SonioxService: Processing partial: "$_lastPartialTranscript"');
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
    _statusController.add('stopped');
  }

  /// Dispose the service.
  void dispose() {
    stopStreaming();
    _actionController.close();
    _partialController.close();
    _statusController.close();
  }
}
