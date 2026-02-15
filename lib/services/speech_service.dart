import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';

/// Parsed action result from speech-to-text
class ParsedPokerAction {
  final String? action;      // fold, check, call, bet, raise, all-in
  final double? amount;      // Amount for bet/raise
  final double confidence;   // Confidence score (0-1)
  final String transcript;   // Raw transcribed text
  final bool success;
  final String? error;

  ParsedPokerAction({
    this.action,
    this.amount,
    required this.confidence,
    required this.transcript,
    required this.success,
    this.error,
  });

  factory ParsedPokerAction.fromJson(Map<String, dynamic> json) {
    return ParsedPokerAction(
      action: json['action'] as String?,
      amount: json['amount'] != null ? (json['amount'] as num).toDouble() : null,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      transcript: json['transcript'] as String? ?? '',
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }

  @override
  String toString() {
    return 'ParsedPokerAction(action: $action, amount: $amount, confidence: $confidence, transcript: "$transcript")';
  }
}

/// Service for speech-to-text functionality
/// Handles audio recording and sends to backend for transcription
class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  static SpeechService get instance => _instance;

  final AudioRecorder _recorder = AudioRecorder();
  String? _currentRecordingPath;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  /// Request microphone permission
  Future<bool> requestPermission() async {
    return await _recorder.hasPermission();
  }

  /// Start recording audio
  /// Returns true if recording started successfully
  Future<bool> startRecording() async {
    try {
      if (_isRecording) {
        debugPrint('SpeechService: Already recording');
        return false;
      }

      // Check permission
      if (!await hasPermission()) {
        debugPrint('SpeechService: No microphone permission');
        return false;
      }

      // Get temp directory for recording
      final directory = await getTemporaryDirectory();
      _currentRecordingPath = '${directory.path}/poker_voice_${DateTime.now().millisecondsSinceEpoch}.wav';

      // Start recording
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,  // Good for speech recognition
          numChannels: 1,     // Mono
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      debugPrint('SpeechService: Started recording to $_currentRecordingPath');
      return true;
    } catch (e) {
      debugPrint('SpeechService: Failed to start recording: $e');
      return false;
    }
  }

  /// Stop recording and transcribe the audio
  /// Returns the parsed poker action, or null if failed
  Future<ParsedPokerAction?> stopRecordingAndTranscribe() async {
    try {
      if (!_isRecording) {
        debugPrint('SpeechService: Not recording');
        return null;
      }

      // Stop recording
      final path = await _recorder.stop();
      _isRecording = false;

      if (path == null) {
        debugPrint('SpeechService: No recording path returned');
        return null;
      }

      debugPrint('SpeechService: Stopped recording at $path');

      // Read audio file
      final file = File(path);
      if (!await file.exists()) {
        debugPrint('SpeechService: Recording file does not exist');
        return null;
      }

      final audioBytes = await file.readAsBytes();
      debugPrint('SpeechService: Audio file size: ${audioBytes.length} bytes');

      // Send to backend for transcription
      final result = await _sendForTranscription(audioBytes);

      // Clean up temp file
      try {
        await file.delete();
      } catch (e) {
        debugPrint('SpeechService: Failed to delete temp file: $e');
      }

      return result;
    } catch (e) {
      debugPrint('SpeechService: Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Cancel recording without transcribing
  Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        await _recorder.stop();
        _isRecording = false;

        // Clean up temp file
        if (_currentRecordingPath != null) {
          try {
            final file = File(_currentRecordingPath!);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            debugPrint('SpeechService: Failed to delete temp file: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('SpeechService: Error canceling recording: $e');
    }
  }

  /// Send audio to backend for transcription
  Future<ParsedPokerAction?> _sendForTranscription(List<int> audioBytes) async {
    try {
      final url = Uri.parse('${AppConfig.serverUrl}/api/v1/speech/transcribe');

      // Encode audio as base64
      final audioBase64 = base64Encode(audioBytes);

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'audio_base64': audioBase64,
          'mimetype': 'audio/wav',
          'language': 'en',
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return ParsedPokerAction.fromJson(json);
      } else {
        debugPrint('SpeechService: Transcription failed with status ${response.statusCode}: ${response.body}');
        return ParsedPokerAction(
          confidence: 0.0,
          transcript: '',
          success: false,
          error: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('SpeechService: Network error during transcription: $e');
      return ParsedPokerAction(
        confidence: 0.0,
        transcript: '',
        success: false,
        error: 'Network error: $e',
      );
    }
  }

  /// Parse text directly (for testing or manual input)
  Future<ParsedPokerAction?> parseText(String text) async {
    try {
      final url = Uri.parse('${AppConfig.serverUrl}/api/v1/speech/parse');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return ParsedPokerAction(
          action: json['action'] as String?,
          amount: json['amount'] != null ? (json['amount'] as num).toDouble() : null,
          confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
          transcript: text,
          success: json['success'] as bool? ?? false,
          error: json['error'] as String?,
        );
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('SpeechService: Parse error: $e');
      return null;
    }
  }

  /// Check if the speech backend is available
  Future<bool> checkBackendAvailable() async {
    try {
      final url = Uri.parse('${AppConfig.serverUrl}/api/v1/speech/test');
      final response = await http.get(url).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Dispose the recorder
  void dispose() {
    _recorder.dispose();
  }
}
