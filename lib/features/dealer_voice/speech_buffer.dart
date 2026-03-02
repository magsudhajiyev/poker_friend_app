import 'dart:async';

/// Accumulates final transcripts until silence gap, then flushes.
/// Replaces _TranscriptDebouncer with a simpler time-based approach.
///
/// Key differences from old debouncer:
/// - NO _lastTranscript comparison
/// - NO _lastParsedActions tracking
/// - NO _findStartEndOverlap() logic
/// - NO suffix checking
/// - Simple time-based buffering + cooldown
class SpeechBuffer {
  final Duration silenceGap;
  final Duration extendedSilenceGap;
  final Duration cooldownDuration;
  final void Function(String utterance) onCompleteUtterance;
  final void Function(String partial) onPartialTranscript;

  Timer? _silenceTimer;
  Timer? _cooldownTimer;
  final StringBuffer _buffer = StringBuffer();
  bool _inCooldown = false;
  bool _isStreaming = false;

  /// Pattern to detect buffer ending with potential incomplete number.
  /// Matches when buffer ends with digit or comma (e.g., "reraise 2" or "reraise 2,").
  static final RegExp _incompleteNumberPattern = RegExp(r'[\d,]$');

  SpeechBuffer({
    this.silenceGap = const Duration(milliseconds: 1000),
    this.extendedSilenceGap = const Duration(milliseconds: 1800),
    this.cooldownDuration = const Duration(milliseconds: 2000),
    required this.onCompleteUtterance,
    required this.onPartialTranscript,
  });

  /// Whether currently in cooldown mode (ignoring new transcripts)
  bool get inCooldown => _inCooldown;

  /// Whether streaming is active
  bool get isStreaming => _isStreaming;

  /// Call when a FINAL transcript arrives from Soniox
  void onFinalTranscript(String text) {
    // Ignore if in cooldown or not streaming
    if (_inCooldown || !_isStreaming) return;

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // Reset silence timer
    _silenceTimer?.cancel();

    // Accumulate text with space separator
    if (_buffer.isNotEmpty) _buffer.write(' ');
    _buffer.write(trimmed);

    // Detect if buffer ends with potentially incomplete number (e.g., "reraise 2" or "reraise 2,")
    // When Soniox splits "reraise 2,000" across two finals, we need to wait longer
    final currentText = _buffer.toString().trim();
    final endsWithIncompleteNumber = _incompleteNumberPattern.hasMatch(currentText);
    final timeout = endsWithIncompleteNumber ? extendedSilenceGap : silenceGap;

    // Start silence timer - will flush after timeout of no new input
    _silenceTimer = Timer(timeout, _flush);
  }

  /// Pass partial transcripts directly to UI (no processing)
  void onPartial(String text) {
    onPartialTranscript(text);
  }

  /// Flush accumulated buffer and enter cooldown
  void _flush() {
    if (_buffer.isEmpty) return;

    final utterance = _buffer.toString().trim();
    _buffer.clear();

    // Enter cooldown - ignore new finals for cooldownDuration
    _inCooldown = true;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(cooldownDuration, () {
      _inCooldown = false;
    });

    // Emit complete utterance
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
    _cooldownTimer?.cancel();
    _buffer.clear();
    _inCooldown = false;
  }

  /// Call on new hand start to clear any accumulated state
  void reset() {
    _silenceTimer?.cancel();
    _cooldownTimer?.cancel();
    _buffer.clear();
    _inCooldown = false;
  }

  /// Dispose timers
  void dispose() {
    _silenceTimer?.cancel();
    _cooldownTimer?.cancel();
  }
}
