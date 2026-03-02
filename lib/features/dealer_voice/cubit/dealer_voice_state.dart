import 'package:equatable/equatable.dart';

enum VoiceStatus {
  disabled,
  listening,
  processing,
  error,
  // Note: cooldown is handled internally by SpeechBuffer, not tracked in state
}

class DealerVoiceState extends Equatable {
  final VoiceStatus status;
  final String? partialText;
  final String? lastUtterance;
  final String? lastError;
  final List<String> lastCorrections;

  // TODO: Add pendingAction field for future confirmation tier implementation
  // final ParsedAction? pendingAction;

  const DealerVoiceState({
    this.status = VoiceStatus.disabled,
    this.partialText,
    this.lastUtterance,
    this.lastError,
    this.lastCorrections = const [],
  });

  DealerVoiceState copyWith({
    VoiceStatus? status,
    String? partialText,
    String? lastUtterance,
    String? lastError,
    List<String>? lastCorrections,
  }) {
    return DealerVoiceState(
      status: status ?? this.status,
      partialText: partialText ?? this.partialText,
      lastUtterance: lastUtterance ?? this.lastUtterance,
      lastError: lastError ?? this.lastError,
      lastCorrections: lastCorrections ?? this.lastCorrections,
    );
  }

  @override
  List<Object?> get props => [
        status,
        partialText,
        lastUtterance,
        lastError,
        lastCorrections,
      ];
}
