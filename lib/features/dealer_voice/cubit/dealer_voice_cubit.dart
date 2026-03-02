import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:poker_logger/services/soniox_service.dart';
import 'package:poker_logger/services/action_parser.dart';
import 'package:poker_logger/models/poker_game_state.dart';
import '../speech_buffer.dart';
import '../action_validator.dart';
import 'dealer_voice_state.dart';

/// Tracks recently executed action batches for echo detection.
/// Stores RAW parsed signatures (before validation/correction) for accurate matching.
class _ExecutedBatch {
  final List<String> actionSignatures; // Raw: ["fold:null", "fold:null", "bet:600.0"]
  final DateTime time;
  const _ExecutedBatch({required this.actionSignatures, required this.time});
}

/// Orchestrates the dealer voice pipeline:
/// SonioxService → SpeechBuffer → ActionParser → ActionValidator → execution
///
/// Replaces the old overlap-based deduplication with game-state validation.
/// After an action executes and currentPlayer advances, the next parsed action
/// validates against the NEW game state. This naturally prevents duplicates.
class DealerVoiceCubit extends Cubit<DealerVoiceState> {
  final SonioxService _sonioxService;
  final ActionValidator _validator = ActionValidator();

  late final SpeechBuffer _speechBuffer;
  StreamSubscription? _finalSub;
  StreamSubscription? _partialSub;
  StreamSubscription? _statusSub;

  PokerGameState? _gameState;
  bool _isHandActive = false;

  /// Tracks recent batches for echo detection (cleared after 5 seconds or new hand).
  final List<_ExecutedBatch> _recentBatches = [];

  /// Processing queue to prevent race conditions in echo detection.
  /// Ensures batch N finishes and records signatures before batch N+1 checks.
  bool _isProcessing = false;
  final List<List<ParsedAction>> _pendingBatches = [];

  /// Callback to execute validated actions.
  /// The callback should:
  /// 1. Execute the action (updates game state)
  /// 2. Call updateGameState() with fresh state after execution
  final Future<void> Function(ParsedAction action)? onExecuteAction;

  DealerVoiceCubit({
    SonioxService? sonioxService,
    this.onExecuteAction,
  })  : _sonioxService = sonioxService ?? SonioxService.instance,
        super(const DealerVoiceState()) {
    _speechBuffer = SpeechBuffer(
      onCompleteUtterance: _onCompleteUtterance,
      onPartialTranscript: _onPartialTranscript,
    );
  }

  /// Update game state reference.
  /// CRITICAL: Call this after each action execution to ensure
  /// next action validates against fresh state.
  void updateGameState(PokerGameState? state, bool isHandActive) {
    _gameState = state;
    _isHandActive = isHandActive;
  }

  /// Start listening for voice input.
  Future<void> startListening() async {
    final success = await _sonioxService.startStreaming();
    if (!success) {
      emit(state.copyWith(
        status: VoiceStatus.error,
        lastError: 'Failed to start voice streaming',
      ));
      return;
    }

    _speechBuffer.startStreaming();

    _finalSub = _sonioxService.finalTranscriptStream.listen(
      _speechBuffer.onFinalTranscript,
    );
    _partialSub = _sonioxService.partialStream.listen(
      _speechBuffer.onPartial,
    );
    _statusSub = _sonioxService.statusStream.listen(_onStatus);

    emit(state.copyWith(status: VoiceStatus.listening));
  }

  /// Stop listening for voice input.
  Future<void> stopListening() async {
    _speechBuffer.stopStreaming();
    await _sonioxService.stopStreaming();

    _finalSub?.cancel();
    _partialSub?.cancel();
    _statusSub?.cancel();

    emit(state.copyWith(status: VoiceStatus.disabled));
  }

  /// Called when SpeechBuffer flushes a complete utterance.
  void _onCompleteUtterance(String utterance) {
    if (state.status == VoiceStatus.disabled) return;

    emit(state.copyWith(
      status: VoiceStatus.processing,
      lastUtterance: utterance,
    ));

    // Parse actions from utterance
    final actions = ActionParser.parse(utterance);

    if (actions.isEmpty) {
      if (state.status != VoiceStatus.disabled) {
        emit(state.copyWith(status: VoiceStatus.listening));
      }
      return;
    }

    _enqueueActions(actions);
  }

  /// Queue actions for processing, preventing concurrent batch execution.
  void _enqueueActions(List<ParsedAction> actions) {
    if (_isProcessing) {
      _pendingBatches.add(actions);
      return;
    }
    _processNext(actions);
  }

  /// Process current batch and any queued batches sequentially.
  Future<void> _processNext(List<ParsedAction> actions) async {
    _isProcessing = true;

    await _processActionsSequentially(actions);

    while (_pendingBatches.isNotEmpty) {
      final next = _pendingBatches.removeAt(0);
      await _processActionsSequentially(next);
    }

    _isProcessing = false;

    if (state.status != VoiceStatus.disabled) {
      emit(state.copyWith(status: VoiceStatus.listening));
    }
  }

  /// Process parsed actions one by one, validating each against current game state.
  Future<void> _processActionsSequentially(List<ParsedAction> actions) async {
    // Strip any echoed prefix from this batch
    final cleanActions = _stripEchoedPrefix(actions);

    if (cleanActions.isEmpty) return;

    final allCorrections = <String>[];
    final rawSignatures = <String>[];

    for (final parsed in cleanActions) {
      // Guard: check if voice was stopped mid-processing
      if (state.status == VoiceStatus.disabled || _gameState == null) {
        break;
      }

      // Record RAW signature BEFORE validation/correction
      rawSignatures.add('${parsed.action}:${parsed.amount}');

      final result = _validator.validate(
        parsed,
        _gameState!,
        isHandActive: _isHandActive,
      );

      if (result.isValid) {
        allCorrections.addAll(result.corrections);

        // Execute the action (this should advance currentPlayer)
        if (onExecuteAction != null) {
          await onExecuteAction!(result.correctedAction);
          // Note: onExecuteAction callback should call updateGameState()
          // to ensure next action validates against fresh state
        }
      }
    }

    // Record batch with RAW signatures (not corrected ones)
    if (rawSignatures.isNotEmpty) {
      _recentBatches.add(_ExecutedBatch(
        actionSignatures: rawSignatures,
        time: DateTime.now(),
      ));
    }
  }

  void _onPartialTranscript(String text) {
    emit(state.copyWith(partialText: text));
  }

  void _onStatus(String status) {
    // Handle Soniox status updates (connection, calibration, etc.)
  }

  /// Fuzzy signature matching for echo detection.
  /// Handles truncated numbers from Soniox split transcripts.
  /// e.g., "raise:300.0" should match "raise:3000.0" (300 is prefix of 3000)
  bool _signaturesMatch(String sig1, String sig2) {
    if (sig1 == sig2) return true;

    final parts1 = sig1.split(':');
    final parts2 = sig2.split(':');

    // Action type must match exactly
    if (parts1[0] != parts2[0]) return false;

    // Both null amounts already caught by exact match
    if (parts1[1] == 'null' || parts2[1] == 'null') return parts1[1] == parts2[1];

    // Fuzzy amount: check if one integer is a prefix of the other (truncated number)
    final amt1 = double.tryParse(parts1[1]);
    final amt2 = double.tryParse(parts2[1]);
    if (amt1 == null || amt2 == null) return false;

    final int1 = amt1.toInt().toString();
    final int2 = amt2.toInt().toString();

    if (int1.length != int2.length && (int2.startsWith(int1) || int1.startsWith(int2))) {
      return true;
    }

    return false;
  }

  /// Check if the START of a new batch overlaps with the END of a recent batch.
  /// Returns the actions with any echoed prefix removed.
  ///
  /// Example:
  ///   Recent batch raw: [fold:null, fold:null, bet:600.0]
  ///   New batch raw:    [bet:600.0, fold:null]
  ///   Overlap: "bet:600.0" matches end of previous → strip it → return just [fold]
  List<ParsedAction> _stripEchoedPrefix(List<ParsedAction> actions) {
    if (actions.isEmpty) return actions;

    final now = DateTime.now();
    _recentBatches.removeWhere((b) => now.difference(b.time).inSeconds > 5);

    if (_recentBatches.isEmpty) return actions;

    final newSigs = actions.map((a) => '${a.action}:${a.amount}').toList();

    int maxStrip = 0;

    for (final batch in _recentBatches) {
      final prevSigs = batch.actionSignatures;

      // Check: does the START of newSigs overlap with the END of prevSigs?
      // Try largest overlap first
      final maxOverlap = newSigs.length < prevSigs.length ? newSigs.length : prevSigs.length;

      for (int overlapLen = maxOverlap; overlapLen > 0; overlapLen--) {
        final prevSuffix = prevSigs.sublist(prevSigs.length - overlapLen);
        final newPrefix = newSigs.sublist(0, overlapLen);

        bool match = true;
        for (int i = 0; i < overlapLen; i++) {
          if (!_signaturesMatch(prevSuffix[i], newPrefix[i])) {
            match = false;
            break;
          }
        }

        // Only count as echo if overlap is a PROPER suffix of previous batch.
        // If overlap == prevSigs.length, the entire previous batch matches,
        // which means this could be a genuine repeated action, not a tail echo.
        if (match && overlapLen > maxStrip && overlapLen < prevSigs.length) {
          maxStrip = overlapLen;
          break;
        }
      }
    }

    if (maxStrip > 0) {
      if (maxStrip >= actions.length) {
        return [];
      }
      return actions.sublist(maxStrip);
    }

    return actions;
  }

  /// Reset for new hand - clears buffer, corrections, echo history, and processing queue.
  void onNewHand() {
    _speechBuffer.reset();
    _recentBatches.clear();
    _pendingBatches.clear();
    _isProcessing = false;
    emit(state.copyWith(
      lastCorrections: [],
      partialText: null,
      lastUtterance: null,
    ));
  }

  /// Toggle hold mode on SonioxService.
  void toggleHold() {
    _sonioxService.toggleHoldAction();
  }

  /// Enable hold mode.
  void enableHold() {
    _sonioxService.enableHoldAction();
  }

  /// Disable hold mode.
  void disableHold() {
    _sonioxService.disableHoldAction();
  }

  /// Whether hold mode is active.
  bool get isHoldActive => _sonioxService.isHoldingActions;

  @override
  Future<void> close() {
    _speechBuffer.dispose();
    _finalSub?.cancel();
    _partialSub?.cancel();
    _statusSub?.cancel();
    return super.close();
  }
}
