import 'package:poker_logger/models/poker_game_state.dart';
import 'package:poker_logger/services/action_parser.dart';

/// Result of validating a parsed action against game state.
class ActionValidationResult {
  final bool isValid;
  final ParsedAction correctedAction;
  final List<String> corrections;
  final String? rejectionReason;
  final bool isSeatMismatch;

  const ActionValidationResult({
    required this.isValid,
    required this.correctedAction,
    this.corrections = const [],
    this.rejectionReason,
    this.isSeatMismatch = false,
  });

  factory ActionValidationResult.valid(
    ParsedAction action, [
    List<String> corrections = const [],
  ]) {
    return ActionValidationResult(
      isValid: true,
      correctedAction: action,
      corrections: corrections,
    );
  }

  factory ActionValidationResult.invalid(ParsedAction action, String reason) {
    return ActionValidationResult(
      isValid: false,
      correctedAction: action,
      rejectionReason: reason,
    );
  }

  factory ActionValidationResult.seatMismatch(ParsedAction action, String reason) {
    return ActionValidationResult(
      isValid: false,
      correctedAction: action,
      rejectionReason: reason,
      isSeatMismatch: true,
    );
  }
}

/// Validates parsed actions against game state.
///
/// This replaces the overlap-based deduplication with game-state validation.
/// After an action executes and currentPlayer advances, the next parsed action
/// validates against the NEW game state. This naturally prevents duplicates.
class ActionValidator {
  /// Validate a parsed action against the current game state.
  /// Returns validation result with possible corrections.
  ActionValidationResult validate(
    ParsedAction parsed,
    PokerGameState gameState, {
    required bool isHandActive,
  }) {
    final corrections = <String>[];
    final currentPlayer = gameState.currentPlayer;

    // Check 0: Seat number required
    if (parsed.seatNumber == null) {
      return ActionValidationResult.invalid(parsed, 'No seat number specified');
    }

    // Check 1: Seat matches current player
    if (parsed.seatNumber != currentPlayer) {
      return ActionValidationResult.seatMismatch(
        parsed,
        'Seat ${parsed.seatNumber} not current (expected seat $currentPlayer)',
      );
    }

    // Check 2: Is hand active?
    if (!isHandActive) {
      return ActionValidationResult.invalid(parsed, 'No active hand');
    }

    // Check 3: Is there a current player who can act?
    if (!gameState.canPlayerAct(currentPlayer)) {
      return ActionValidationResult.invalid(
        parsed,
        'Current player cannot act (folded, all-in, or not their turn)',
      );
    }

    // Check 3: Map action string to PlayerAction and validate
    var playerAction = _mapToPlayerAction(parsed.action);
    var amount = parsed.amount;

    // Handle all-in specially - convert to bet/raise with full stack
    if (parsed.action == 'all-in') {
      final stack = gameState.getPlayerStack(currentPlayer);
      final playerBet = gameState.players[currentPlayer - 1].betThisRound;
      amount = stack + playerBet;
      // Determine if this is a bet or raise based on game state
      playerAction = gameState.isValidAction(PlayerAction.bet)
          ? PlayerAction.bet
          : PlayerAction.raise;
      corrections.add('all-in → ${_actionName(playerAction)} $amount');
    }

    // Check 4: Is action legal? If not, attempt auto-correction
    if (playerAction != PlayerAction.none &&
        !gameState.isValidAction(playerAction)) {
      final corrected = _attemptAutoCorrection(playerAction, gameState);
      if (corrected != null) {
        corrections.add('${_actionName(playerAction)} → ${_actionName(corrected)}');
        playerAction = corrected;
      } else {
        return ActionValidationResult.invalid(
          parsed,
          'Invalid action: ${parsed.action} (no valid alternative)',
        );
      }
    }

    // Check for invalid/unknown action
    if (playerAction == PlayerAction.none) {
      return ActionValidationResult.invalid(
        parsed,
        'Unknown action: ${parsed.action}',
      );
    }

    // Check 5: For bet/raise with amount - validate range
    if (amount != null &&
        (playerAction == PlayerAction.bet ||
            playerAction == PlayerAction.raise)) {
      final stack = gameState.getPlayerStack(currentPlayer);
      final playerBet = gameState.players[currentPlayer - 1].betThisRound;
      final maxBet = stack + playerBet;

      if (amount > maxBet) {
        corrections.add('Amount ${amount.toInt()} → all-in ${maxBet.toInt()}');
        amount = maxBet;
      }
      // Note: no min-raise enforcement — trust the dealer's spoken amount
    }

    // Return corrected action
    return ActionValidationResult.valid(
      ParsedAction(
        action: _playerActionToString(playerAction),
        amount: amount,
        confidence: parsed.confidence,
        seatNumber: parsed.seatNumber,
      ),
      corrections,
    );
  }

  PlayerAction _mapToPlayerAction(String action) {
    switch (action.toLowerCase()) {
      case 'fold':
        return PlayerAction.fold;
      case 'check':
        return PlayerAction.check;
      case 'call':
        return PlayerAction.call;
      case 'bet':
        return PlayerAction.bet;
      case 'raise':
        return PlayerAction.raise;
      case 'all-in':
        // Will be handled specially in validate()
        return PlayerAction.raise;
      default:
        return PlayerAction.none;
    }
  }

  String _playerActionToString(PlayerAction action) {
    switch (action) {
      case PlayerAction.fold:
        return 'fold';
      case PlayerAction.check:
        return 'check';
      case PlayerAction.call:
        return 'call';
      case PlayerAction.bet:
        return 'bet';
      case PlayerAction.raise:
        return 'raise';
      default:
        return 'none';
    }
  }

  String _actionName(PlayerAction action) {
    return action.toString().split('.').last;
  }

  /// Attempt to auto-correct an invalid action.
  ///
  /// Auto-correction rules:
  /// - call when there's no bet → check
  /// - bet when there's already a bet → raise
  /// - raise when there's no bet → bet
  ///
  /// NOT auto-corrected (rejected instead):
  /// - check when there's a bet → NOT converted to call (dealer must explicitly say "call")
  PlayerAction? _attemptAutoCorrection(
    PlayerAction action,
    PokerGameState gameState,
  ) {
    switch (action) {
      case PlayerAction.check:
        // check when there's a bet → reject (do NOT auto-correct to call)
        break;
      case PlayerAction.call:
        // call when there's no bet → check
        if (gameState.isValidAction(PlayerAction.check)) {
          return PlayerAction.check;
        }
        break;
      case PlayerAction.bet:
        // bet when there's already a bet → raise
        if (gameState.isValidAction(PlayerAction.raise)) {
          return PlayerAction.raise;
        }
        break;
      case PlayerAction.raise:
        // raise when there's no bet → bet
        if (gameState.isValidAction(PlayerAction.bet)) {
          return PlayerAction.bet;
        }
        break;
      default:
        break;
    }
    return null;
  }
}
