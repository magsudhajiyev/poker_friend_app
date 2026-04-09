import 'dart:async';
import 'package:flutter/foundation.dart';

/// Accumulates final transcripts until silence gap, then flushes.
///
/// Uses smart silence gaps:
/// - Quick flush (400ms) for recognized simple actions (fold, check, call, all-in)
/// - Standard gap (1000ms) for amount-bearing actions (bet, raise)
/// - Extended gap (1800ms) when buffer ends with an incomplete number
///
/// No cooldown — echo detection is handled by DealerVoiceCubit._stripEchoedPrefix().
class SpeechBuffer {
  final Duration silenceGap;
  final Duration extendedSilenceGap;
  final Duration quickSilenceGap;
  final void Function(String utterance) onCompleteUtterance;
  final void Function(String partial) onPartialTranscript;

  Timer? _silenceTimer;
  final StringBuffer _buffer = StringBuffer();
  bool _isStreaming = false;

  /// Pattern to detect buffer ending with potential incomplete number.
  /// Matches when buffer ends with digit or comma (e.g., "reraise 2" or "reraise 2,").
  static final RegExp _incompleteNumberPattern = RegExp(r'[\d,]$');

  /// Amount-bearing action keywords that need to wait for a number.
  static final RegExp _amountActionPattern = RegExp(
    r'\b(?:bet|betting|raise|re-raise|reraise|raising)\b',
    caseSensitive: false,
  );

  /// Any recognized poker action keyword.
  static final RegExp _anyActionPattern = RegExp(
    r'\b(?:fold|pass|muck|check|checking|call|calling|all[- ]?in|shove|jam|bet|betting|raise|re-raise|reraise|raising)\b',
    caseSensitive: false,
  );

  SpeechBuffer({
    this.silenceGap = const Duration(milliseconds: 1000),
    this.extendedSilenceGap = const Duration(milliseconds: 1800),
    this.quickSilenceGap = const Duration(milliseconds: 400),
    required this.onCompleteUtterance,
    required this.onPartialTranscript,
  });

  /// Whether streaming is active
  bool get isStreaming => _isStreaming;

  /// Call when a FINAL transcript arrives from Soniox
  void onFinalTranscript(String text) {
    if (!_isStreaming) return;

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // Reset silence timer
    _silenceTimer?.cancel();

    // Accumulate text with space separator
    if (_buffer.isNotEmpty) _buffer.write(' ');
    _buffer.write(trimmed);

    // Determine appropriate silence gap based on buffer content
    final currentText = _buffer.toString().trim();
    final hasAmountAction = _amountActionPattern.hasMatch(currentText);
    final endsWithIncompleteNumber = _incompleteNumberPattern.hasMatch(currentText);

    Duration timeout;
    String gapReason;
    if (hasAmountAction || endsWithIncompleteNumber) {
      // "raise" or "bet" detected, or ends with digit — wait for potential number
      timeout = endsWithIncompleteNumber ? extendedSilenceGap : silenceGap;
      gapReason = endsWithIncompleteNumber ? 'extended (incomplete number)' : 'standard (amount action)';
    } else if (_anyActionPattern.hasMatch(currentText)) {
      // Simple action like "fold", "check", "call" — flush quickly
      timeout = quickSilenceGap;
      gapReason = 'quick (simple action)';
    } else {
      // No recognized action yet — use standard gap
      timeout = silenceGap;
      gapReason = 'standard (no action detected)';
    }

    debugPrint('[STT:BUFFER] Final token: "$trimmed" | Buffer: "$currentText" | Gap: ${timeout.inMilliseconds}ms ($gapReason)');

    // Start silence timer - will flush after timeout of no new input
    _silenceTimer = Timer(timeout, _flush);
  }

  /// Pass partial transcripts directly to UI (no processing)
  void onPartial(String text) {
    onPartialTranscript(text);
  }

  /// Flush accumulated buffer
  void _flush() {
    if (_buffer.isEmpty) return;

    final utterance = _buffer.toString().trim();
    _buffer.clear();

    debugPrint('[STT:BUFFER] FLUSH → "$utterance"');

    // No cooldown — echo detection is handled by DealerVoiceCubit._stripEchoedPrefix()
    onCompleteUtterance(utterance);
  }

  /// Call when streaming starts
  void startStreaming() {
    _isStreaming = true;
  }

  /// Call when streaming stops - DO NOT flush partial
  /// This prevents phantom actions from incomplete utterances on disconnect
  void stopStreaming() {
    _isStreaming = false;
    _silenceTimer?.cancel();
    _buffer.clear();
  }

  /// Call on new hand start to clear any accumulated state
  void reset() {
    _silenceTimer?.cancel();
    _buffer.clear();
  }

  /// Dispose timers
  void dispose() {
    _silenceTimer?.cancel();
  }
}
