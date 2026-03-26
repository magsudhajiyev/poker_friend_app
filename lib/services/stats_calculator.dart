/// Pure functions for poker statistics detection and calculation.
/// Extracted from FirebaseService for testability.
///
/// All methods are static and operate on action lists without
/// requiring Firebase or any external dependencies.
class StatsCalculator {
  // Private constructor - only static methods
  StatsCalculator._();

  /// Check if an action is a blind posting (not voluntary)
  static bool isBlindAction(Map<String, dynamic> action) {
    final actionType = (action['action'] as String?)?.toLowerCase();
    return actionType == 'small blind' ||
           actionType == 'big blind' ||
           actionType == 'ante';
  }

  /// Check if an action is a raise (includes all-in which is functionally a raise)
  static bool isRaiseAction(String actionType) {
    final type = actionType.toLowerCase();
    return type == 'raise' || type == 'all-in';
  }

  /// Check if an action is a bet (includes all-in which is functionally a bet)
  static bool isBetAction(String actionType) {
    final type = actionType.toLowerCase();
    return type == 'bet' || type == 'all-in';
  }

  /// Check if an action is aggressive (bet, raise, or all-in)
  static bool isAggressiveAction(String actionType) {
    final type = actionType.toLowerCase();
    return type == 'bet' || type == 'raise' || type == 'all-in';
  }

  /// Detect if a player made a 3-bet (re-raised AFTER seeing an opponent's raise)
  ///
  /// A 3-bet is when:
  /// 1. An opponent raises preflop FIRST
  /// 2. The player then raises (re-raises) after seeing that raise
  ///
  /// Important: If the player was the ORIGINAL raiser and then raises again
  /// after opponent's 3-bet, that's a 4-bet, NOT a 3-bet.
  ///
  /// A player can only make ONE 3-bet per hand (by definition).
  static bool didPlayerThreeBet(List<Map<String, dynamic>> actions, int playerSeatNumber) {
    bool sawOpponentRaise = false;
    bool playerAlreadyRaised = false;

    for (final action in actions) {
      final street = action['street']?.toString().toLowerCase() ?? '';
      if (street != 'preflop') continue;

      final playerId = action['player'] as int?;
      final actionType = action['action']?.toString().toLowerCase() ?? '';

      // Only look at raise actions (includes all-in)
      if (!isRaiseAction(actionType)) continue;

      if (playerId == playerSeatNumber) {
        if (sawOpponentRaise && !playerAlreadyRaised) {
          // Player raised AFTER seeing opponent raise, and hadn't raised before = 3-bet
          return true;
        }
        // Track that player has raised (could be open-raise or 4-bet+)
        playerAlreadyRaised = true;
      } else {
        // Opponent raised
        sawOpponentRaise = true;
      }
    }
    return false;
  }

  /// Check if player had opportunity to 3-bet (faced a raise pre-flop)
  static bool hadThreeBetOpportunity(List<Map<String, dynamic>> actions, int playerSeatNumber) {
    bool sawRaiseBeforePlayerActs = false;
    bool playerActedAfterRaise = false;

    for (final action in actions) {
      final street = action['street']?.toString().toLowerCase() ?? '';
      if (street != 'preflop') continue;

      final playerId = action['player'] as int?;
      final actionType = action['action']?.toString().toLowerCase() ?? '';

      if (isRaiseAction(actionType) && playerId != playerSeatNumber) {
        sawRaiseBeforePlayerActs = true;
      }

      // If player acted after seeing a raise, they had 3-bet opportunity
      if (playerId == playerSeatNumber && sawRaiseBeforePlayerActs) {
        playerActedAfterRaise = true;
        break;
      }
    }

    return playerActedAfterRaise;
  }

  /// Check if player raised pre-flop and then faced a 3-bet
  static bool facedThreeBet(List<Map<String, dynamic>> actions, int playerSeatNumber) {
    bool playerRaised = false;
    bool facedReRaise = false;

    for (final action in actions) {
      final street = action['street']?.toString().toLowerCase() ?? '';
      if (street != 'preflop') continue;

      final playerId = action['player'] as int?;
      final actionType = action['action']?.toString().toLowerCase() ?? '';

      if (isRaiseAction(actionType)) {
        if (playerId == playerSeatNumber) {
          playerRaised = true;
        } else if (playerRaised) {
          // Someone re-raised after player raised
          facedReRaise = true;
          break;
        }
      }
    }

    return facedReRaise;
  }

  /// Check if player folded to a 3-bet (raised, faced re-raise, then folded)
  static bool didFoldTo3Bet(List<Map<String, dynamic>> actions, int playerSeatNumber) {
    bool playerRaised = false;
    bool facedReRaise = false;

    for (final action in actions) {
      final street = action['street']?.toString().toLowerCase() ?? '';
      if (street != 'preflop') continue;

      final playerId = action['player'] as int?;
      final actionType = action['action']?.toString().toLowerCase() ?? '';

      if (isRaiseAction(actionType)) {
        if (playerId == playerSeatNumber) {
          playerRaised = true;
        } else if (playerRaised) {
          facedReRaise = true;
        }
      }

      // Check if player folded after facing 3-bet
      if (actionType == 'fold' && playerId == playerSeatNumber && facedReRaise) {
        return true;
      }
    }

    return false;
  }

  /// Check if player was last aggressor pre-flop and saw the flop (C-bet opportunity)
  static bool hadCbetOpportunity(List<Map<String, dynamic>> actions, int playerSeatNumber) {
    int? lastPreflopAggressor;
    bool sawFlop = false;

    for (final action in actions) {
      final street = action['street']?.toString().toLowerCase() ?? '';
      final playerId = action['player'] as int?;
      final actionType = action['action']?.toString().toLowerCase() ?? '';

      if (street == 'preflop') {
        // Track last aggressor (bet, raise, or all-in)
        if (isAggressiveAction(actionType)) {
          lastPreflopAggressor = playerId;
        }
      } else if (street == 'flop') {
        sawFlop = true;
        break;
      }
    }

    return sawFlop && lastPreflopAggressor == playerSeatNumber;
  }

  /// Check if player made a continuation bet (bet on flop as last preflop aggressor)
  static bool didCbet(List<Map<String, dynamic>> actions, int playerSeatNumber) {
    // First verify they had C-bet opportunity
    if (!hadCbetOpportunity(actions, playerSeatNumber)) return false;

    // Check if they bet on the flop (bet or all-in counts as c-bet)
    for (final action in actions) {
      final street = action['street']?.toString().toLowerCase() ?? '';
      if (street != 'flop') continue;

      final playerId = action['player'] as int?;
      final actionType = action['action']?.toString().toLowerCase() ?? '';

      if (playerId == playerSeatNumber && isBetAction(actionType)) {
        return true;
      }
    }

    return false;
  }

  /// Check if player was in steal position (CO/BTN/SB) with unopened pot
  static bool hadStealOpportunity(List<Map<String, dynamic>> actions, int playerSeatNumber) {
    // Get player's position
    String? playerPosition;

    for (final action in actions) {
      final street = action['street']?.toString().toLowerCase() ?? '';
      if (street != 'preflop') continue;

      final playerId = action['player'] as int?;
      final position = action['playerPosition']?.toString().toUpperCase() ?? '';

      // Track player's position
      if (playerId == playerSeatNumber && playerPosition == null) {
        playerPosition = position;
        break;
      }
    }

    // Steal positions: CO (Cutoff), BTN (Button), SB (Small Blind)
    final isStealPosition = playerPosition == 'CO' ||
        playerPosition == 'BTN' ||
        playerPosition == 'BU' ||
        playerPosition == 'SB';

    if (!isStealPosition) return false;

    // For steal opportunity, pot must be unopened when player acts
    bool potUnopenedWhenPlayerActs = true;
    for (final action in actions) {
      final street = action['street']?.toString().toLowerCase() ?? '';
      if (street != 'preflop') continue;

      final playerId = action['player'] as int?;
      final actionType = action['action']?.toString().toLowerCase() ?? '';

      if (playerId == playerSeatNumber) {
        // We've reached player's action, check if pot was opened
        break;
      }

      // If anyone raised, bet, all-in, or called before player, pot is opened
      if (isAggressiveAction(actionType) ||
          (actionType == 'call' && !isBlindAction(action))) {
        potUnopenedWhenPlayerActs = false;
        break;
      }
    }

    return potUnopenedWhenPlayerActs;
  }

  /// Check if player raised from steal position (attempted steal)
  static bool didSteal(List<Map<String, dynamic>> actions, int playerSeatNumber) {
    if (!hadStealOpportunity(actions, playerSeatNumber)) return false;

    for (final action in actions) {
      final street = action['street']?.toString().toLowerCase() ?? '';
      if (street != 'preflop') continue;

      final playerId = action['player'] as int?;
      final actionType = action['action']?.toString().toLowerCase() ?? '';

      if (playerId == playerSeatNumber && isRaiseAction(actionType)) {
        return true;
      }
    }

    return false;
  }

  /// Check if player had check/raise opportunity on flop (checked, then faced bet)
  static bool hadCheckRaiseFlopOpportunity(List<Map<String, dynamic>> actions, int playerSeatNumber) {
    bool playerCheckedFlop = false;
    bool facedBetAfterCheck = false;

    for (final action in actions) {
      final street = action['street']?.toString().toLowerCase() ?? '';
      if (street != 'flop') continue;

      final playerId = action['player'] as int?;
      final actionType = action['action']?.toString().toLowerCase() ?? '';

      if (playerId == playerSeatNumber && actionType == 'check') {
        playerCheckedFlop = true;
      }

      // If player checked and then someone bet/raised/all-in, they had check-raise opportunity
      if (playerCheckedFlop && playerId != playerSeatNumber &&
          isAggressiveAction(actionType)) {
        facedBetAfterCheck = true;
        break;
      }
    }

    return facedBetAfterCheck;
  }

  /// Check if player check-raised on flop
  static bool didCheckRaiseFlop(List<Map<String, dynamic>> actions, int playerSeatNumber) {
    if (!hadCheckRaiseFlopOpportunity(actions, playerSeatNumber)) return false;

    bool playerCheckedFlop = false;
    bool facedBet = false;

    for (final action in actions) {
      final street = action['street']?.toString().toLowerCase() ?? '';
      if (street != 'flop') continue;

      final playerId = action['player'] as int?;
      final actionType = action['action']?.toString().toLowerCase() ?? '';

      if (playerId == playerSeatNumber && actionType == 'check') {
        playerCheckedFlop = true;
      }

      if (playerCheckedFlop && playerId != playerSeatNumber &&
          isAggressiveAction(actionType)) {
        facedBet = true;
      }

      // Check if player raised after checking and facing bet (raise or all-in counts)
      if (playerCheckedFlop && facedBet &&
          playerId == playerSeatNumber && isRaiseAction(actionType)) {
        return true;
      }
    }

    return false;
  }

  /// Check if hand was a "walk" (everyone folded to BB)
  static bool isWalkHand(List<Map<String, dynamic>> actions) {
    int foldCount = 0;
    bool anyNonFoldPreflop = false;

    for (final action in actions) {
      final street = action['street']?.toString().toLowerCase() ?? '';
      if (street != 'preflop') continue;

      final actionType = action['action']?.toString().toLowerCase() ?? '';

      if (isBlindAction({'action': actionType})) continue;

      if (actionType == 'fold') {
        foldCount++;
      } else {
        anyNonFoldPreflop = true;
        break;
      }
    }

    // Walk = all players folded (except BB who wins by default)
    return foldCount > 0 && !anyNonFoldPreflop;
  }

  /// Check if player is in Big Blind position
  static bool isBigBlind(List<Map<String, dynamic>> actions, int playerSeatNumber) {
    for (final action in actions) {
      final playerId = action['player'] as int?;
      final actionType = action['action']?.toString().toLowerCase() ?? '';

      if (playerId == playerSeatNumber && actionType == 'big blind') {
        return true;
      }

      // Also check position field
      final position = action['playerPosition']?.toString().toUpperCase() ?? '';
      if (playerId == playerSeatNumber && position == 'BB') {
        return true;
      }
    }
    return false;
  }
}
