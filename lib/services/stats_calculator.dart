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

  /// Detect if a player made a 3-bet (the 3rd raise preflop).
  ///
  /// In poker, preflop raises are counted as:
  ///   1st raise = open raise
  ///   2nd raise = re-raise
  ///   3rd raise = 3-bet
  ///   4th raise = 4-bet, etc.
  ///
  /// A player 3-bet if they made the raise that was the 3rd raise in the hand.
  static bool didPlayerThreeBet(List<Map<String, dynamic>> actions, int playerSeatNumber) {
    int raiseCount = 0;

    for (final action in actions) {
      final street = action['street']?.toString().toLowerCase() ?? '';
      if (street != 'preflop') continue;

      final playerId = action['player'] as int?;
      final actionType = action['action']?.toString().toLowerCase() ?? '';

      if (!isRaiseAction(actionType)) continue;

      raiseCount++;

      // The 3rd raise is the 3-bet
      if (raiseCount == 3 && playerId == playerSeatNumber) {
        return true;
      }

      // Past 3rd raise, no point continuing
      if (raiseCount >= 3) break;
    }
    return false;
  }

  /// Check if player had opportunity to 3-bet (exactly 2 raises already
  /// happened in the hand, and player can make the 3rd).
  ///
  /// This covers two scenarios:
  /// 1. Player hasn't raised yet — 2 raises by others, player can 3-bet
  /// 2. Player opened (1st raise) — someone else raised (2nd), player can 3-bet
  ///
  /// Only counts when totalRaiseCount == 2 (not 3+, which would be 4-bet opp).
  static bool hadThreeBetOpportunity(List<Map<String, dynamic>> actions, int playerSeatNumber) {
    int totalRaiseCount = 0;

    for (final action in actions) {
      final street = action['street']?.toString().toLowerCase() ?? '';
      if (street != 'preflop') continue;

      final playerId = action['player'] as int?;
      final actionType = action['action']?.toString().toLowerCase() ?? '';

      if (isRaiseAction(actionType)) {
        // If this IS the player's action AND exactly 2 raises already happened,
        // they had the opportunity and took it (3-bet)
        if (playerId == playerSeatNumber && totalRaiseCount == 2) {
          return true;
        }
        totalRaiseCount++;
      } else if (playerId == playerSeatNumber) {
        // Non-raise action by player — if exactly 2 raises already happened,
        // they had 3-bet opportunity but declined (called/folded)
        if (totalRaiseCount == 2) {
          return true;
        }
      }
    }

    return false;
  }

  /// Check if player raised pre-flop and then faced a 3-bet (the 3rd raise).
  ///
  /// The player must have raised at some point, and then the 3rd raise
  /// in the hand happened (by someone else), leaving the player to act.
  static bool facedThreeBet(List<Map<String, dynamic>> actions, int playerSeatNumber) {
    int raiseCount = 0;
    bool playerRaised = false;

    for (final action in actions) {
      final street = action['street']?.toString().toLowerCase() ?? '';
      if (street != 'preflop') continue;

      final playerId = action['player'] as int?;
      final actionType = action['action']?.toString().toLowerCase() ?? '';

      if (isRaiseAction(actionType)) {
        raiseCount++;
        if (playerId == playerSeatNumber) {
          playerRaised = true;
        } else if (playerRaised && raiseCount >= 3) {
          // The 3rd+ raise happened after player raised
          return true;
        }
      }
    }

    return false;
  }

  /// Check if player folded to a 3-bet (raised earlier, then the 3rd raise
  /// happened, and the player folded).
  static bool didFoldTo3Bet(List<Map<String, dynamic>> actions, int playerSeatNumber) {
    int raiseCount = 0;
    bool playerRaised = false;
    bool faced3Bet = false;

    for (final action in actions) {
      final street = action['street']?.toString().toLowerCase() ?? '';
      if (street != 'preflop') continue;

      final playerId = action['player'] as int?;
      final actionType = action['action']?.toString().toLowerCase() ?? '';

      if (isRaiseAction(actionType)) {
        raiseCount++;
        if (playerId == playerSeatNumber) {
          playerRaised = true;
        } else if (playerRaised && raiseCount >= 3) {
          faced3Bet = true;
        }
      }

      // Check if player folded after facing 3-bet
      if (actionType == 'fold' && playerId == playerSeatNumber && faced3Bet) {
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

  /// Check if player is in Big Blind position.
  /// Also checks other players' actions for BB position info (handles walk
  /// hands where BB never acts and has no action in the list).
  static bool isBigBlind(List<Map<String, dynamic>> actions, int playerSeatNumber) {
    for (final action in actions) {
      final playerId = action['player'] as int?;
      final actionType = action['action']?.toString().toLowerCase() ?? '';

      if (playerId == playerSeatNumber && actionType == 'big blind') {
        return true;
      }

      // Check position field on this player's actions
      final position = action['playerPosition']?.toString().toUpperCase() ?? '';
      if (playerId == playerSeatNumber && position == 'BB') {
        return true;
      }
    }
    return false;
  }

  /// Find the BB seat number from action list.
  /// Useful for walk hands where BB may not have any actions recorded.
  static int? findBigBlindSeat(List<Map<String, dynamic>> actions) {
    for (final action in actions) {
      final actionType = action['action']?.toString().toLowerCase() ?? '';
      if (actionType == 'big blind') {
        return action['player'] as int?;
      }
      final position = action['playerPosition']?.toString().toUpperCase() ?? '';
      if (position == 'BB') {
        return action['player'] as int?;
      }
    }
    return null;
  }
}
