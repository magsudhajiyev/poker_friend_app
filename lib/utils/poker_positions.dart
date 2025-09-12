/// Utility functions for converting poker seat numbers to position names
/// relative to the button position
class PokerPositions {
  /// Get the position name for a seat relative to the button position
  static String getPositionName(int seatNumber, int buttonPosition, int playerCount) {
    // Calculate the position relative to the button
    int position = (seatNumber - buttonPosition + playerCount) % playerCount;
    
    // Convert position to poker terminology
    switch (playerCount) {
      case 2: // Heads-up
        return _getHeadsUpPosition(position);
      case 3: // 3-handed
        return _get3HandedPosition(position);
      case 4: // 4-handed
        return _get4HandedPosition(position);
      case 5: // 5-handed
        return _get5HandedPosition(position);
      case 6: // 6-handed
        return _get6HandedPosition(position);
      case 7: // 7-handed
        return _get7HandedPosition(position);
      case 8: // 8-handed
        return _get8HandedPosition(position);
      case 9: // 9-handed
        return _get9HandedPosition(position);
      case 10: // 10-handed (full ring)
        return _get10HandedPosition(position);
      default:
        // For unusual player counts, use generic position names
        return _getGenericPosition(position, playerCount);
    }
  }

  static String _getHeadsUpPosition(int position) {
    switch (position) {
      case 0: return 'BTN/SB'; // Button is also small blind
      case 1: return 'BB';
      default: return 'P$position';
    }
  }

  static String _get3HandedPosition(int position) {
    switch (position) {
      case 0: return 'BTN';
      case 1: return 'SB';
      case 2: return 'BB';
      default: return 'P$position';
    }
  }

  static String _get4HandedPosition(int position) {
    switch (position) {
      case 0: return 'BTN';
      case 1: return 'SB';
      case 2: return 'BB';
      case 3: return 'UTG';
      default: return 'P$position';
    }
  }

  static String _get5HandedPosition(int position) {
    switch (position) {
      case 0: return 'BTN';
      case 1: return 'SB';
      case 2: return 'BB';
      case 3: return 'UTG';
      case 4: return 'CO';
      default: return 'P$position';
    }
  }

  static String _get6HandedPosition(int position) {
    switch (position) {
      case 0: return 'BTN';
      case 1: return 'SB';
      case 2: return 'BB';
      case 3: return 'UTG';
      case 4: return 'HJ';
      case 5: return 'CO';
      default: return 'P$position';
    }
  }

  static String _get7HandedPosition(int position) {
    switch (position) {
      case 0: return 'BTN';
      case 1: return 'SB';
      case 2: return 'BB';
      case 3: return 'UTG';
      case 4: return 'UTG+1';
      case 5: return 'HJ';
      case 6: return 'CO';
      default: return 'P$position';
    }
  }

  static String _get8HandedPosition(int position) {
    switch (position) {
      case 0: return 'BTN';
      case 1: return 'SB';
      case 2: return 'BB';
      case 3: return 'UTG';
      case 4: return 'UTG+1';
      case 5: return 'UTG+2';
      case 6: return 'HJ';
      case 7: return 'CO';
      default: return 'P$position';
    }
  }

  static String _get9HandedPosition(int position) {
    switch (position) {
      case 0: return 'BTN';
      case 1: return 'SB';
      case 2: return 'BB';
      case 3: return 'UTG';
      case 4: return 'UTG+1';
      case 5: return 'UTG+2';
      case 6: return 'MP';
      case 7: return 'HJ';
      case 8: return 'CO';
      default: return 'P$position';
    }
  }

  static String _get10HandedPosition(int position) {
    switch (position) {
      case 0: return 'BTN';
      case 1: return 'SB';
      case 2: return 'BB';
      case 3: return 'UTG';
      case 4: return 'UTG+1';
      case 5: return 'UTG+2';
      case 6: return 'MP1';
      case 7: return 'MP2';
      case 8: return 'HJ';
      case 9: return 'CO';
      default: return 'P$position';
    }
  }

  static String _getGenericPosition(int position, int playerCount) {
    // For unusual player counts, use descriptive names where possible
    if (position == 0) return 'BTN';
    if (position == 1) return 'SB';
    if (position == 2) return 'BB';
    if (position == 3) return 'UTG';
    if (position == playerCount - 1) return 'CO';
    
    // For middle positions, just use position numbers
    return 'P${position + 1}';
  }

  /// Get a full description of the position for tooltips/help
  static String getPositionDescription(String positionName) {
    switch (positionName) {
      case 'BTN':
        return 'Button - Last to act post-flop, best position';
      case 'SB':
        return 'Small Blind - Posts small blind, acts first post-flop';
      case 'BB':
        return 'Big Blind - Posts big blind, last to act pre-flop';
      case 'UTG':
        return 'Under The Gun - First to act pre-flop, tight range';
      case 'UTG+1':
        return 'Under The Gun +1 - Second to act pre-flop';
      case 'UTG+2':
        return 'Under The Gun +2 - Third to act pre-flop';
      case 'MP':
      case 'MP1':
        return 'Middle Position - Moderate position strength';
      case 'MP2':
        return 'Middle Position 2 - Late middle position';
      case 'HJ':
        return 'Hijack - Two seats right of button';
      case 'CO':
        return 'Cutoff - One seat right of button, strong position';
      case 'BTN/SB':
        return 'Button/Small Blind - Heads-up: button posts small blind';
      default:
        if (positionName.startsWith('P')) {
          return 'Position ${positionName.substring(1)}';
        }
        return positionName;
    }
  }

  /// Get all position names for a given player count and button position
  static List<String> getAllPositions(int playerCount, int buttonPosition) {
    List<String> positions = [];
    for (int seat = 1; seat <= playerCount; seat++) {
      positions.add(getPositionName(seat, buttonPosition, playerCount));
    }
    return positions;
  }

  /// Format player name with position in brackets if it's a custom name
  static String formatPlayerNameWithPosition(String playerName, int seatNumber, int buttonPosition, int playerCount) {
    final positionName = getPositionName(seatNumber, buttonPosition, playerCount);
    
    // If the player name is already a position name, return as is
    if (playerName == positionName) {
      return playerName;
    }
    
    // If it's a custom name, add position in brackets
    if (playerName.isNotEmpty && playerName != positionName) {
      return '$playerName ($positionName)';
    }
    
    // Fallback to position name
    return positionName;
  }

  /// Check if a name is a standard position name
  static bool isPositionName(String name) {
    final standardPositions = [
      'BTN', 'SB', 'BB', 'UTG', 'UTG+1', 'UTG+2', 
      'MP', 'MP1', 'MP2', 'HJ', 'CO', 'BTN/SB'
    ];
    
    // Also check for generic position patterns like P1, P2, etc.
    if (name.startsWith('P') && name.length > 1) {
      final numPart = name.substring(1);
      if (int.tryParse(numPart) != null) {
        return true;
      }
    }
    
    return standardPositions.contains(name);
  }

  /// Get UTG (Under The Gun) seat number relative to button position
  static int getUTGSeat(int buttonPosition, int playerCount) {
    // UTG is always 3 positions after the button (after SB and BB)
    // Button -> SB (+1) -> BB (+2) -> UTG (+3)
    return ((buttonPosition + 3 - 1) % playerCount) + 1;
  }

  /// Get the preflop action order starting from UTG
  static List<int> getPreflopActionOrder(int buttonPosition, int playerCount) {
    List<int> actionOrder = [];
    
    // Start from UTG (3 positions after button)
    int startSeat = getUTGSeat(buttonPosition, playerCount);
    
    // Add all positions starting from UTG, going clockwise
    for (int i = 0; i < playerCount; i++) {
      int seat = ((startSeat - 1 + i) % playerCount) + 1;
      actionOrder.add(seat);
    }
    
    return actionOrder;
  }

  /// Get the postflop action order starting from SB
  static List<int> getPostflopActionOrder(int buttonPosition, int playerCount) {
    List<int> actionOrder = [];
    
    // Start from SB (1 position after button)
    int startSeat = (buttonPosition % playerCount) + 1;
    
    // Add all positions starting from SB, going clockwise
    for (int i = 0; i < playerCount; i++) {
      int seat = ((startSeat - 1 + i) % playerCount) + 1;
      actionOrder.add(seat);
    }
    
    return actionOrder;
  }
}