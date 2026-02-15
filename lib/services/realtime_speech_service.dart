import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';
import 'continuous_speech_service.dart'; // For DetectedPokerAction class

/// Debouncer to prevent duplicate rapid actions from speech recognition.
///
/// Blocks:
/// - Same action within 1 second (catches Whisper repeats)
/// - Any action within 300ms (catches rapid duplicates from same event)
class _ActionDebouncer {
  DateTime? _lastActionTime;
  String? _lastAction;

  // Adjusted timing for real-time speech:
  // - 1s same-action allows natural "fold fold" with 1-2s pause
  // - 300ms any-action catches rapid duplicates from same transcript
  static const int sameActionCooldownMs = 1000;
  static const int anyActionCooldownMs = 300;

  bool canExecute(String action) {
    final now = DateTime.now();
    if (_lastActionTime == null) {
      _lastActionTime = now;
      _lastAction = action;
      return true;
    }

    final elapsed = now.difference(_lastActionTime!).inMilliseconds;

    // Same action needs cooldown to avoid duplicates
    if (action == _lastAction && elapsed < sameActionCooldownMs) {
      debugPrint('RealtimeSpeech: Debounced duplicate $action (${elapsed}ms since last)');
      return false;
    }

    // Any action needs minimum cooldown to catch rapid-fire duplicates
    if (elapsed < anyActionCooldownMs) {
      debugPrint('RealtimeSpeech: Debounced rapid action (${elapsed}ms since last)');
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

/// Real-time speech recognition service using WebSocket streaming.
///
/// Key features:
/// - ~300ms latency (vs 2.5s with batch)
/// - Continuous audio streaming
/// - Partial transcripts for instant feedback
/// - Automatic action parsing
class RealtimeSpeechService {
  static final RealtimeSpeechService _instance = RealtimeSpeechService._internal();
  factory RealtimeSpeechService() => _instance;
  RealtimeSpeechService._internal();

  static RealtimeSpeechService get instance => _instance;

  io.Socket? _socket;
  AudioRecorder? _recorder;
  bool _isStreaming = false;
  bool _isConnected = false;
  Timer? _streamTimer;
  String _language = 'en';
  final _ActionDebouncer _debouncer = _ActionDebouncer();

  // Stream controllers
  final _actionController = StreamController<DetectedPokerAction>.broadcast();
  Stream<DetectedPokerAction> get actionStream => _actionController.stream;

  final _partialController = StreamController<String>.broadcast();
  Stream<String> get partialStream => _partialController.stream;

  final _statusController = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  bool get isStreaming => _isStreaming;
  bool get isConnected => _isConnected;

  void setLanguage(String languageCode) {
    _language = languageCode;
  }

  /// Connect to the WebSocket server
  Future<bool> connect() async {
    if (_isConnected) return true;

    try {
      debugPrint('RealtimeSpeech: Connecting to ${AppConfig.serverUrl}');

      _socket = io.io(
        AppConfig.serverUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .enableReconnection()
            .enableForceNew()  // Force a new connection, don't reuse existing
            .build(),
      );

      final completer = Completer<bool>();

      _socket!.onConnect((_) {
        debugPrint('RealtimeSpeech: Connected');
        _isConnected = true;
        _statusController.add('connected');
        if (!completer.isCompleted) completer.complete(true);
      });

      _socket!.onConnectError((error) {
        debugPrint('RealtimeSpeech: Connection error: $error');
        _isConnected = false;
        _statusController.add('error');
        if (!completer.isCompleted) completer.complete(false);
      });

      // Debug: Log all events
      _socket!.onAny((event, data) {
        debugPrint('RealtimeSpeech: Event "$event" received');
      });

      _socket!.onDisconnect((_) {
        debugPrint('RealtimeSpeech: Disconnected');
        _isConnected = false;
        _isStreaming = false;
        _statusController.add('disconnected');
      });

      // Handle speech events
      _socket!.on('speech_started', (data) {
        debugPrint('RealtimeSpeech: Speech session started');
        _statusController.add('listening');
        _partialController.add('Listening...');
      });

      _socket!.on('speech_partial', (data) {
        final text = data['text'] as String? ?? '';
        final isFinal = data['is_final'] as bool? ?? false;
        debugPrint('RealtimeSpeech: Partial: "$text" (final=$isFinal)');
        _partialController.add(text.isNotEmpty ? text : 'Listening...');
      });

      _socket!.on('speech_actions', (data) {
        debugPrint('RealtimeSpeech: Actions received: $data');
        final transcript = data['transcript'] as String? ?? '';
        final actions = data['actions'] as List<dynamic>? ?? [];

        for (final actionData in actions) {
          final actionType = actionData['action'] as String;

          // Debounce duplicate actions to prevent "fold fold" → 5 folds
          if (!_debouncer.canExecute(actionType)) {
            continue;  // Skip this duplicate action
          }

          final action = DetectedPokerAction(
            action: actionType,
            amount: actionData['amount'] != null
                ? (actionData['amount'] as num).toDouble()
                : null,
            confidence: (actionData['confidence'] as num?)?.toDouble() ?? 0.9,
            transcript: transcript,
          );
          _actionController.add(action);
          _partialController.add('✓ ${action.action.toUpperCase()}${action.amount != null ? ' ${action.amount!.toInt()}' : ''}');
        }
      });

      _socket!.on('speech_error', (data) {
        debugPrint('RealtimeSpeech: Error: $data');
        _statusController.add('error');
        _partialController.add('Error: ${data['error']}');
      });

      _socket!.on('speech_stopped', (data) {
        debugPrint('RealtimeSpeech: Speech session stopped');
        _statusController.add('stopped');
        _partialController.add('');
      });

      debugPrint('RealtimeSpeech: Calling connect()...');
      _socket!.connect();
      debugPrint('RealtimeSpeech: connect() called, waiting for response...');

      // Wait for connection with timeout
      return await completer.future.timeout(
        const Duration(seconds: 10),  // Increased timeout
        onTimeout: () {
          debugPrint('RealtimeSpeech: Connection timeout after 10s');
          debugPrint('RealtimeSpeech: Socket connected=${_socket?.connected}, id=${_socket?.id}');
          return false;
        },
      );
    } catch (e) {
      debugPrint('RealtimeSpeech: Connection error: $e');
      return false;
    }
  }

  StreamSubscription<Uint8List>? _audioSubscription;

  /// Start real-time speech streaming
  Future<bool> startStreaming() async {
    if (_isStreaming) return true;

    // Ensure connected
    if (!_isConnected) {
      final connected = await connect();
      if (!connected) return false;
    }

    try {
      // Initialize recorder
      _recorder ??= AudioRecorder();

      if (!await _recorder!.hasPermission()) {
        debugPrint('RealtimeSpeech: No microphone permission');
        return false;
      }

      // Tell server to start speech session
      _socket!.emit('speech_start', {'language': _language});

      // Start streaming audio using startStream()
      final audioStream = await _recorder!.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits, // Raw PCM for streaming
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      _isStreaming = true;
      _statusController.add('streaming');

      // Listen to audio stream and send to server
      _audioSubscription = audioStream.listen(
        (Uint8List audioData) {
          if (_isStreaming && _socket != null && _isConnected) {
            // Send audio chunk as base64
            final base64Audio = base64Encode(audioData);
            _socket!.emit('speech_audio', {'audio': base64Audio});
          }
        },
        onError: (error) {
          debugPrint('RealtimeSpeech: Audio stream error: $error');
        },
        onDone: () {
          debugPrint('RealtimeSpeech: Audio stream ended');
        },
      );

      debugPrint('RealtimeSpeech: Streaming started');
      return true;
    } catch (e) {
      debugPrint('RealtimeSpeech: Error starting stream: $e');
      return false;
    }
  }

  /// Stop streaming
  Future<void> stopStreaming() async {
    debugPrint('RealtimeSpeech: Stopping stream');
    _isStreaming = false;

    // Reset debouncer for fresh start next time
    _debouncer.reset();

    // Cancel audio subscription
    await _audioSubscription?.cancel();
    _audioSubscription = null;

    _streamTimer?.cancel();
    _streamTimer = null;

    if (_recorder != null) {
      try {
        await _recorder!.stop();
      } catch (e) {
        // Ignore stop errors
      }
    }

    if (_socket != null && _isConnected) {
      _socket!.emit('speech_stop', {});
    }

    _statusController.add('stopped');
    _partialController.add('');
  }

  /// Disconnect from server
  void disconnect() {
    stopStreaming();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _recorder?.dispose();
    _recorder = null;
  }

  void dispose() {
    disconnect();
    _actionController.close();
    _partialController.close();
    _statusController.close();
  }
}
