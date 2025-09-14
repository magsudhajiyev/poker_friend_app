import '../utils/poker_positions.dart';

enum PlayerAction {
  none,
  fold,
  check,
  call,
  bet,
  raise,
}

enum BettingRound {
  preflop,
  flop,
  turn,
  river,
}

class PlayerState {
  final int playerId;
  bool isActive;
  bool hasFolded;
  bool hasActed;
  bool hasCalledCurrentBet;
  bool isAllIn;
  PlayerAction lastAction;
  double startingStack;
  double currentStack;
  double betThisRound;

  PlayerState({
    required this.playerId,
    this.isActive = true,
    this.hasFolded = false,
    this.hasActed = false,
    this.hasCalledCurrentBet = false,
    this.isAllIn = false,
    this.lastAction = PlayerAction.none,
    this.startingStack = 0.0,
    this.currentStack = 0.0,
    this.betThisRound = 0.0,
  });

  void reset() {
    isActive = true;
    hasFolded = false;
    hasActed = false;
    hasCalledCurrentBet = false;
    isAllIn = false;
    lastAction = PlayerAction.none;
    betThisRound = 0.0;
    // Keep currentStack and startingStack unchanged for new hand
  }

  void resetForNewStreet() {
    hasActed = false;
    hasCalledCurrentBet = false;
    lastAction = PlayerAction.none;
    betThisRound = 0.0;
  }

  void setStack(double amount) {
    startingStack = amount;
    currentStack = amount;
  }

  void updateStack(double amount) {
    currentStack = amount;
    // Update all-in status
    isAllIn = (currentStack == 0.0);
  }

  double getEffectiveStack() {
    return currentStack;
  }

  void _updateAllInStatus() {
    bool wasAllIn = isAllIn;
    isAllIn = (currentStack == 0.0);
    if (!wasAllIn && isAllIn) {
      print('🔴 DEBUG: Player $playerId is now all-in (stack: $currentStack)');
    } else if (wasAllIn && !isAllIn) {
      print('🟢 DEBUG: Player $playerId is no longer all-in (stack: $currentStack)');
    }
  }
}

class PokerGameState {
  final int numberOfPlayers;
  final int smallBlind;
  final int bigBlind;
  final bool isCashGame;
  
  List<PlayerState> players;
  int _buttonPosition = 1;
  int _currentPlayer = 1;
  double currentPot = 0.0;
  double currentBet = 0.0;
  
  // Debug property with logging for buttonPosition
  int get buttonPosition => _buttonPosition;
  set buttonPosition(int value) {
    if (_buttonPosition != value) {
      print('DEBUG: buttonPosition changing from $_buttonPosition to $value');
      _buttonPosition = value;
      // Recalculate action order when button position changes
      if (currentRound == BettingRound.preflop && !bettingRoundComplete) {
        _setInitialActionOrder();
        print('DEBUG: Action order recalculated due to button position change');
      }
    }
  }
  bool hasBetThisRound;
  
  // Debug property with logging
  int get currentPlayer => _currentPlayer;
  set currentPlayer(int value) {
    if (_currentPlayer != value) {
      print('DEBUG: currentPlayer changing from $_currentPlayer to $value');
      
      // Validate current player is within bounds
      if (value < 1 || value > numberOfPlayers) {
        print('ERROR: Invalid currentPlayer $value. Must be between 1 and $numberOfPlayers');
        print('DEBUG: Stack trace: ${StackTrace.current}');
        // Don't update to invalid value
        return;
      }
      
      _currentPlayer = value;
    }
  }
  int handNumber;
  BettingRound currentRound;
  bool bettingRoundComplete;
  Map<String, int> positionActivity;

  PokerGameState({
    required this.numberOfPlayers,
    required this.smallBlind,
    required this.bigBlind,
    this.isCashGame = true,
  }) : players = [],
       _buttonPosition = 1,
       _currentPlayer = 1,
       hasBetThisRound = false,
       handNumber = 1,
       currentRound = BettingRound.preflop,
       bettingRoundComplete = false,
       currentPot = 0.0,
       currentBet = 0.0,
       positionActivity = {} {
    
    // Initialize players
    for (int i = 1; i <= numberOfPlayers; i++) {
      players.add(PlayerState(playerId: i));
    }
    
    // Set initial action order for preflop
    _setInitialActionOrder();
  }

  void _setInitialActionOrder() {
    if (numberOfPlayers == 2) {
      // Heads up: button posts small blind and acts first preflop
      currentPlayer = buttonPosition;
      print('DEBUG: Heads-up preflop, currentPlayer set to $currentPlayer (BTN)');
    } else {
      // Multi-way: UTG (Under The Gun) acts first
      // UTG is always 3 positions after button (after SB and BB)
      int utgPosition = PokerPositions.getUTGSeat(buttonPosition, numberOfPlayers);
      currentPlayer = utgPosition;
      print('DEBUG: Multi-way preflop, BTN=$buttonPosition, UTG calculated as $utgPosition, currentPlayer set to $currentPlayer');
    }
    
    // No one has "called" yet in preflop - everyone needs to act including BB
    // BB has posted big blind but still needs to act if there's betting action
  }

  int _getPositionFromButton(int seatsLeft) {
    // Validate inputs
    if (seatsLeft < 0) {
      print('ERROR: Invalid seatsLeft $seatsLeft in _getPositionFromButton');
      return buttonPosition;
    }
    if (buttonPosition < 1 || buttonPosition > numberOfPlayers) {
      print('ERROR: Invalid buttonPosition $buttonPosition in _getPositionFromButton');
      return 1;
    }
    
    int position = buttonPosition;
    for (int i = 0; i < seatsLeft; i++) {
      position = (position % numberOfPlayers) + 1;
    }
    return position;
  }

  PlayerState _getPlayer(int playerId) {
    try {
      return players.firstWhere((p) => p.playerId == playerId);
    } catch (e) {
      print('Error: Player $playerId not found. Available players: ${players.map((p) => p.playerId).toList()}');
      // Return a default player state to prevent crash
      return PlayerState(
        playerId: playerId,
        isActive: false,
        hasFolded: true,
        currentStack: 0.0,
      );
    }
  }

  int _getNextActivePlayer(int fromPlayer) {
    int nextPlayer = fromPlayer;
    int attempts = 0;
    
    // Validate input
    if (fromPlayer < 1 || fromPlayer > numberOfPlayers) {
      print('ERROR: Invalid fromPlayer $fromPlayer in _getNextActivePlayer');
      return 1; // Return player 1 as fallback
    }
    
    do {
      nextPlayer = (nextPlayer % numberOfPlayers) + 1;
      attempts++;
      
      // Failsafe: prevent infinite loop if no valid next player exists
      if (attempts > numberOfPlayers) {
        print('WARNING: No valid next player found after checking all players');
        // Return original player if no other valid player found
        return fromPlayer;
      }
      
      final playerState = _getPlayer(nextPlayer);
      // Skip folded players and all-in players (who cannot act)
      if (!playerState.hasFolded && !playerState.isAllIn) {
        break;
      }
    } while (nextPlayer != fromPlayer);
    
    return nextPlayer;
  }

  List<int> getActivePlayers() {
    return players.where((p) => !p.hasFolded).map((p) => p.playerId).toList();
  }

  List<int> getPlayersWhoCanAct() {
    return players.where((p) => !p.hasFolded && !p.isAllIn).map((p) => p.playerId).toList();
  }

  List<int> getAllInPlayers() {
    return players.where((p) => !p.hasFolded && p.isAllIn).map((p) => p.playerId).toList();
  }

  bool areAllPlayersAllIn() {
    List<int> activePlayers = getActivePlayers();
    if (activePlayers.length <= 1) return false;
    
    List<int> playersWhoCanAct = getPlayersWhoCanAct();
    // All-in scenario: at least 2 active players, but 0 or 1 can act
    // This means everyone else is all-in
    return activePlayers.length >= 2 && playersWhoCanAct.length <= 1;
  }

  bool canPlayerAct(int playerId) {
    PlayerState player = _getPlayer(playerId);
    if (player.hasFolded) return false;
    if (player.isAllIn) return false; // All-in players can't act
    return currentPlayer == playerId && !bettingRoundComplete;
  }

  bool isValidAction(PlayerAction action) {
    PlayerState player = _getPlayer(currentPlayer);
    
    switch (action) {
      case PlayerAction.fold:
        return true; // Can always fold
      
      case PlayerAction.check:
        // Cannot check preflop before all players have acted past the big blind
        if (currentRound == BettingRound.preflop) {
          // Preflop: can only check if no betting action has occurred AND you're the big blind after everyone has called
          return !hasBetThisRound && _isAllPreflopActionComplete();
        }
        // Post-flop: can check if no one has bet this round
        return !hasBetThisRound;
      
      case PlayerAction.call:
        // Preflop: can always call the big blind (unless you are the big blind and no raises)
        if (currentRound == BettingRound.preflop) {
          return !player.hasCalledCurrentBet; // Can call BB if haven't called yet
        }
        // Post-flop: can only call if there's a bet and haven't called
        return hasBetThisRound && !player.hasCalledCurrentBet;
      
      case PlayerAction.bet:
        // Cannot bet preflop - must raise instead since BB is already a "bet"
        if (currentRound == BettingRound.preflop) {
          return false;
        }
        // Post-flop: can bet if no one has bet this round
        return !hasBetThisRound;
      
      case PlayerAction.raise:
        // Preflop: can always raise (since BB is always a "bet")
        if (currentRound == BettingRound.preflop) {
          return true;
        }
        // Post-flop: can raise if there's already a bet
        return hasBetThisRound;
      
      case PlayerAction.none:
        return false;
    }
  }

  String performAction(PlayerAction action) {
    if (!canPlayerAct(currentPlayer)) {
      return "Player $currentPlayer cannot act right now";
    }

    if (!isValidAction(action)) {
      return "Invalid action: ${action.name} (${_getValidActionsText()})";
    }

    PlayerState player = _getPlayer(currentPlayer);
    String actionText = "";

    switch (action) {
      case PlayerAction.fold:
        player.hasFolded = true;
        player.lastAction = PlayerAction.fold;
        actionText = "Player $currentPlayer: Fold";
        break;

      case PlayerAction.check:
        player.lastAction = PlayerAction.check;
        player.hasCalledCurrentBet = true; // Checking means you're good with current bet (zero)
        actionText = "Player $currentPlayer: Check";
        break;

      case PlayerAction.call:
        player.lastAction = PlayerAction.call;
        player.hasCalledCurrentBet = true;
        updatePotWithAction(currentPlayer, PlayerAction.call, 0.0);
        actionText = "Player $currentPlayer: Call";
        break;

      case PlayerAction.bet:
        hasBetThisRound = true;
        player.lastAction = PlayerAction.bet;
        player.hasCalledCurrentBet = true;
        actionText = "Player $currentPlayer: Bet";
        // Reset all other players' call status when someone bets
        _resetCallStatusExcept(currentPlayer);
        break;

      case PlayerAction.raise:
        player.lastAction = PlayerAction.raise;
        player.hasCalledCurrentBet = true;
        actionText = "Player $currentPlayer: Raise";
        // Reset all other players' call status when someone raises
        _resetCallStatusExcept(currentPlayer);
        break;

      case PlayerAction.none:
        return "No action performed";
    }

    player.hasActed = true;
    
    // Track position activity
    trackPositionActivity(currentPlayer, action);
    
    // Check if only one player remains (automatic hand end)
    List<PlayerState> activePlayers = players.where((p) => !p.hasFolded).toList();
    if (activePlayers.length <= 1) {
      bettingRoundComplete = true;
      return "$actionText\n--- Hand ends: Only one player remaining ---";
    }
    
    // Check if betting round is complete
    if (_isBettingRoundComplete()) {
      bettingRoundComplete = true;
      return "$actionText\n--- Betting round complete ---";
    } else {
      // Move to next active player
      int nextPlayer = _getNextActivePlayer(currentPlayer);
      List<int> allInPlayers = getAllInPlayers();
      if (allInPlayers.isNotEmpty) {
        print('DEBUG: All-in players: $allInPlayers');
      }
      print('DEBUG: Moving from player $currentPlayer to next active player $nextPlayer');
      currentPlayer = nextPlayer;
      return "$actionText\nPlayer $currentPlayer to act";
    }
  }

  String performActionWithAmount(PlayerAction action, double amount) {
    if (!canPlayerAct(currentPlayer)) {
      return "Player $currentPlayer cannot act right now";
    }

    if (!isValidAction(action)) {
      return "Invalid action: ${action.name} (${_getValidActionsText()})";
    }

    PlayerState player = _getPlayer(currentPlayer);
    String actionText = "";
    print('🎯 DEBUG: Before action - currentPot: $currentPot');

    switch (action) {
      case PlayerAction.fold:
        player.hasFolded = true;
        player.lastAction = PlayerAction.fold;
        actionText = "Player $currentPlayer: Fold";
        break;

      case PlayerAction.check:
        player.lastAction = PlayerAction.check;
        player.hasCalledCurrentBet = true;
        actionText = "Player $currentPlayer: Check";
        break;

      case PlayerAction.call:
        // Calculate call amount
        double callAmount = getCurrentBet() - player.betThisRound;
        double actualAmount = callAmount.clamp(0.0, player.currentStack);
        
        // Update stack and bet tracking
        player.currentStack -= actualAmount;
        player._updateAllInStatus();
        player.betThisRound += actualAmount;
        
        // Update pot directly
        currentPot += actualAmount;
        print('🎯 DEBUG: After call - currentPot: $currentPot (added $actualAmount)');
        
        player.lastAction = PlayerAction.call;
        player.hasCalledCurrentBet = true;
        actionText = "Player $currentPlayer: Call ${formatCurrency(actualAmount)}";
        break;

      case PlayerAction.bet:
        // Ensure amount is valid
        double betAmount = amount.clamp(getMinimumBet().toDouble(), player.currentStack);
        
        // Calculate additional amount beyond what player has already bet this round
        double additionalAmount = betAmount - player.betThisRound;
        
        // Update stack and bet tracking
        player.currentStack -= additionalAmount;
        player._updateAllInStatus();
        player.betThisRound = betAmount;
        
        // Update pot and current bet (only add the additional amount)
        currentPot += additionalAmount;
        currentBet = betAmount;
        print('🎯 DEBUG: After bet - currentPot: $currentPot (added $additionalAmount)');
        
        hasBetThisRound = true;
        player.lastAction = PlayerAction.bet;
        player.hasCalledCurrentBet = true;
        actionText = "Player $currentPlayer: Bet ${formatCurrency(betAmount)}";
        // Reset all other players' call status when someone bets
        _resetCallStatusExcept(currentPlayer);
        break;

      case PlayerAction.raise:
        // Ensure amount is valid
        double raiseAmount = amount.clamp(getMinimumBet().toDouble(), player.currentStack);
        
        // Calculate additional amount beyond what player has already bet this round
        double additionalAmount = raiseAmount - player.betThisRound;
        
        // Update stack and bet tracking
        player.currentStack -= additionalAmount;
        player._updateAllInStatus();
        player.betThisRound = raiseAmount;
        
        // Update pot and current bet (only add the additional amount)
        currentPot += additionalAmount;
        currentBet = raiseAmount;
        print('🎯 DEBUG: After raise - currentPot: $currentPot (added $additionalAmount)');
        hasBetThisRound = true;
        
        player.lastAction = PlayerAction.raise;
        player.hasCalledCurrentBet = true;
        actionText = "Player $currentPlayer: Raise to ${formatCurrency(raiseAmount)}";
        // Reset all other players' call status when someone raises
        _resetCallStatusExcept(currentPlayer);
        break;

      case PlayerAction.none:
        return "No action performed";
    }

    player.hasActed = true;
    
    // Track position activity
    trackPositionActivity(currentPlayer, action);
    
    // Check if only one player remains (automatic hand end)
    List<PlayerState> activePlayers = players.where((p) => !p.hasFolded).toList();
    if (activePlayers.length <= 1) {
      bettingRoundComplete = true;
      return "$actionText\n--- Hand ends: Only one player remaining ---";
    }
    
    // Check if betting round is complete
    if (_isBettingRoundComplete()) {
      bettingRoundComplete = true;
      return "$actionText\n--- Betting round complete ---";
    } else {
      // Move to next active player
      int nextPlayer = _getNextActivePlayer(currentPlayer);
      print('DEBUG: Moving from player $currentPlayer to next active player $nextPlayer');
      currentPlayer = nextPlayer;
      return "$actionText\nPlayer $currentPlayer to act";
    }
  }

  String _getValidActionsText() {
    List<String> validActions = [];
    if (isValidAction(PlayerAction.fold)) validActions.add("fold");
    if (isValidAction(PlayerAction.check)) validActions.add("check");
    if (isValidAction(PlayerAction.call)) validActions.add("call");
    if (isValidAction(PlayerAction.bet)) validActions.add("bet");
    if (isValidAction(PlayerAction.raise)) validActions.add("raise");
    return "Valid: ${validActions.join(', ')}";
  }

  void _resetCallStatusExcept(int exceptPlayer) {
    for (PlayerState player in players) {
      if (player.playerId != exceptPlayer && !player.hasFolded) {
        player.hasCalledCurrentBet = false;
      }
    }
  }

  bool _isAllPreflopActionComplete() {
    // For preflop checking, this should only return true when it's the BB's turn 
    // and everyone else has called (no raises)
    
    if (numberOfPlayers == 2) {
      // Heads up: BB can check if SB has called (not raised)
      int bbPosition = (buttonPosition % numberOfPlayers) + 1;
      if (currentPlayer == bbPosition) {
        int sbPosition = buttonPosition;
        PlayerState sbPlayer = _getPlayer(sbPosition);
        // BB can check if SB has acted (called) and no raises occurred
        return sbPlayer.hasActed && !hasBetThisRound;
      }
      return false;
    } else {
      // Multi-way: BB can check if everyone has called and no raises
      int bbPosition = _getPositionFromButton(2);
      if (currentPlayer == bbPosition) {
        List<PlayerState> activePlayers = players.where((p) => !p.hasFolded).toList();
        // All active players except BB must have called current bet (the big blind)
        for (PlayerState player in activePlayers) {
          if (player.playerId != bbPosition && !player.hasCalledCurrentBet) {
            return false;
          }
        }
        return true;
      }
      return false;
    }
  }

  bool _isBettingRoundComplete() {
    List<PlayerState> activePlayers = players.where((p) => !p.hasFolded).toList();
    
    // If only one player left, round is complete
    if (activePlayers.length <= 1) return true;
    
    // If all players are all-in, round is complete
    if (areAllPlayersAllIn()) return true;
    
    // For preflop, special handling for Big Blind
    if (currentRound == BettingRound.preflop && numberOfPlayers > 2) {
      int bbPosition = _getPositionFromButton(2);
      PlayerState bbPlayer = _getPlayer(bbPosition);
      
      // If there was betting action (raises), BB must act
      if (hasBetThisRound && !bbPlayer.hasActed && !bbPlayer.hasFolded) {
        return false;
      }
      
      // If no betting (everyone just calls/checks to BB), BB can check to end round
      if (!hasBetThisRound) {
        // All players except BB must have acted
        for (PlayerState player in activePlayers) {
          if (player.playerId != bbPosition && !player.hasActed) {
            return false;
          }
        }
        // Round is only complete if action is on BB (so BB gets chance to act)
        return currentPlayer == bbPosition;
      }
    }
    
    // Post-flop and heads-up: all active players must have called current bet
    for (PlayerState player in activePlayers) {
      if (!player.hasCalledCurrentBet) {
        return false;
      }
    }
    
    return true;
  }

  void startNewStreet({Function(BettingRound, double)? onStreetComplete}) {
    if (bettingRoundComplete) {
      // Save pot amount for the completed street BEFORE transitioning
      print('🎯 DEBUG: startNewStreet() - currentRound: ${currentRound.name}, currentPot: $currentPot');
      if (onStreetComplete != null) {
        onStreetComplete(currentRound, currentPot);
      }
      
      // Reset for new street
      bettingRoundComplete = false;
      hasBetThisRound = false;
      
      // Reset all players for new street
      for (PlayerState player in players) {
        if (!player.hasFolded) {
          player.resetForNewStreet();
        }
      }
      
      // Post-flop action starts with Small Blind position (or first active player after SB)
      if (numberOfPlayers == 2) {
        // Heads up: non-button (BB) acts first post-flop
        currentPlayer = _getNextActivePlayer(buttonPosition);
      } else {
        // Multi-way: Start from SB, then BB, then UTG, etc.
        int sbPosition = _getPositionFromButton(1);
        int bbPosition = _getPositionFromButton(2);
        
        // Check if SB is still active (not folded and not all-in)
        if (!_getPlayer(sbPosition).hasFolded && !_getPlayer(sbPosition).isAllIn) {
          currentPlayer = sbPosition;
        } else if (!_getPlayer(bbPosition).hasFolded && !_getPlayer(bbPosition).isAllIn) {
          // SB is out, start from BB
          currentPlayer = bbPosition;
        } else {
          // Both SB and BB are out, start from UTG (or first active player after BB)
          int utgPosition = PokerPositions.getUTGSeat(buttonPosition, numberOfPlayers);
          currentPlayer = utgPosition;
          // If UTG is also folded or all-in, find next active player
          while (_getPlayer(currentPlayer).hasFolded || _getPlayer(currentPlayer).isAllIn) {
            currentPlayer = _getNextActivePlayer(currentPlayer);
          }
        }
      }
      
      // Move to next street
      switch (currentRound) {
        case BettingRound.preflop:
          currentRound = BettingRound.flop;
          break;
        case BettingRound.flop:
          currentRound = BettingRound.turn;
          break;
        case BettingRound.turn:
          currentRound = BettingRound.river;
          break;
        case BettingRound.river:
          // Hand is complete
          break;
      }
    }
  }

  void startNewHand() {
    print('DEBUG: startNewHand() called - handNumber was $handNumber, buttonPosition was $buttonPosition');
    handNumber++;
    
    // Only move button for subsequent hands (not the first hand)
    if (handNumber > 1) {
      int oldButtonPosition = buttonPosition;
      buttonPosition = (buttonPosition % numberOfPlayers) + 1;
      print('DEBUG: Button moved from $oldButtonPosition to $buttonPosition for hand #$handNumber');
    } else {
      print('DEBUG: First hand - keeping button at position $buttonPosition');
    }
    
    // Reset all players
    for (PlayerState player in players) {
      player.reset();
    }
    
    // Reset game state
    currentRound = BettingRound.preflop;
    bettingRoundComplete = false;
    hasBetThisRound = false;
    currentPot = 0.0;
    currentBet = 0.0;
    
    // Initialize pot with blinds for new hand
    initializePot();
    
    // Set action order for new hand
    print('DEBUG: About to call _setInitialActionOrder() with button=$buttonPosition, players=$numberOfPlayers');
    _setInitialActionOrder();
  }

  String getCurrentStreetName() {
    switch (currentRound) {
      case BettingRound.preflop:
        return "Pre-flop";
      case BettingRound.flop:
        return "Flop";
      case BettingRound.turn:
        return "Turn";
      case BettingRound.river:
        return "River";
    }
  }

  String getGameStateInfo() {
    List<String> info = [];
    info.add("Hand #$handNumber - ${getCurrentStreetName()}");
    info.add("Button: Player $buttonPosition");
    
    if (numberOfPlayers > 2) {
      int sbPosition = _getPositionFromButton(1);
      int bbPosition = _getPositionFromButton(2);
      info.add("SB: Player $sbPosition, BB: Player $bbPosition");
    }
    
    if (bettingRoundComplete) {
      info.add("Betting round complete");
    } else {
      info.add("Player $currentPlayer to act");
    }
    
    return info.join(" | ");
  }

  // Stack management methods
  void setPlayerStack(int playerId, double stackSize) {
    PlayerState player = _getPlayer(playerId);
    player.setStack(stackSize);
  }

  PlayerState? getCurrentPlayer() {
    if (currentPlayer <= 0 || currentPlayer > numberOfPlayers) return null;
    return _getPlayer(currentPlayer);
  }

  double getCurrentBet() {
    return currentBet;
  }

  int getMinimumBet() {
    return bigBlind;
  }

  double getPlayerStack(int playerId) {
    PlayerState player = _getPlayer(playerId);
    return player.currentStack;
  }

  String formatCurrency(double amount) {
    if (isCashGame) {
      return '\$${amount.toStringAsFixed(2)}';
    } else {
      return '${amount.toInt()}';
    }
  }

  // Pot calculation methods
  void initializePot() {
    currentPot = 0.0;
    currentBet = bigBlind.toDouble();
    print('🎯 DEBUG: initializePot() - Starting with currentPot: $currentPot');
    
    // Post blinds
    if (numberOfPlayers > 2) {
      // Multi-way: standard SB/BB positions
      int sbPosition = _getPositionFromButton(1);
      int bbPosition = _getPositionFromButton(2);
      
      PlayerState sbPlayer = _getPlayer(sbPosition);
      PlayerState bbPlayer = _getPlayer(bbPosition);
      
      // Small blind posts
      double sbAmount = smallBlind.toDouble();
      sbPlayer.betThisRound = sbAmount;
      sbPlayer.currentStack -= sbAmount;
      sbPlayer._updateAllInStatus();
      currentPot += sbAmount;
      print('🎯 DEBUG: Added SB $sbAmount - currentPot: $currentPot');
      
      // Big blind posts
      double bbAmount = bigBlind.toDouble();
      bbPlayer.betThisRound = bbAmount;
      bbPlayer.currentStack -= bbAmount;
      bbPlayer._updateAllInStatus();
      currentPot += bbAmount;
      print('🎯 DEBUG: Added BB $bbAmount - currentPot: $currentPot');
      
    } else {
      // Heads-up: button posts SB, other player posts BB
      int sbPosition = buttonPosition;
      int bbPosition = (buttonPosition % numberOfPlayers) + 1;
      
      PlayerState sbPlayer = _getPlayer(sbPosition);
      PlayerState bbPlayer = _getPlayer(bbPosition);
      
      double sbAmount = smallBlind.toDouble();
      sbPlayer.betThisRound = sbAmount;
      sbPlayer.currentStack -= sbAmount;
      sbPlayer._updateAllInStatus();
      currentPot += sbAmount;

      double bbAmount = bigBlind.toDouble();
      bbPlayer.betThisRound = bbAmount;
      bbPlayer.currentStack -= bbAmount;
      bbPlayer._updateAllInStatus();
      currentPot += bbAmount;
    }
  }

  void updatePotWithAction(int playerId, PlayerAction action, double amount) {
    PlayerState player = _getPlayer(playerId);
    
    switch (action) {
      case PlayerAction.call:
        double callAmount = currentBet - player.betThisRound;
        callAmount = callAmount > player.currentStack ? player.currentStack : callAmount;
        player.betThisRound += callAmount;
        player.currentStack -= callAmount;
        player._updateAllInStatus();
        currentPot += callAmount;
        break;
        
      case PlayerAction.bet:
      case PlayerAction.raise:
        double betAmount = amount;
        if (betAmount > player.currentStack) {
          betAmount = player.currentStack; // All-in
        }
        
        // Add the difference to current bet
        double additionalAmount = betAmount - player.betThisRound;
        player.betThisRound = betAmount;
        player.currentStack -= additionalAmount;
        player._updateAllInStatus();
        currentPot += additionalAmount;
        currentBet = betAmount;
        hasBetThisRound = true;
        break;
        
      case PlayerAction.fold:
        // No pot change for fold
        break;
        
      case PlayerAction.check:
        // No pot change for check
        break;
        
      case PlayerAction.none:
        break;
    }
  }

  String getPotInfo() {
    return "Pot: ${formatCurrency(currentPot)}";
  }

  String getPlayerStackInfo(int playerId) {
    PlayerState player = _getPlayer(playerId);
    return "${formatCurrency(player.currentStack)}";
  }

  void resetPotForNewStreet() {
    currentBet = 0.0;
    hasBetThisRound = false;
    for (PlayerState player in players) {
      player.betThisRound = 0.0;
    }
  }

  /// Get current pot amount for street-specific tracking
  double getPotAmountForStreet() {
    return currentPot;
  }

  void trackPositionActivity(int playerId, PlayerAction action) {
    String positionName = PokerPositions.getPositionName(playerId, buttonPosition, numberOfPlayers);
    
    // Only track non-fold actions for activity
    if (action != PlayerAction.fold && action != PlayerAction.none) {
      positionActivity[positionName] = (positionActivity[positionName] ?? 0) + 1;
    }
  }

  String getMostActivePosition() {
    if (positionActivity.isEmpty) return 'No activity yet';
    
    String mostActive = positionActivity.keys.first;
    int maxActivity = positionActivity[mostActive]!;
    
    for (String position in positionActivity.keys) {
      if (positionActivity[position]! > maxActivity) {
        maxActivity = positionActivity[position]!;
        mostActive = position;
      }
    }
    
    return '$mostActive (${maxActivity} actions)';
  }

  Map<String, int> getPositionActivityStats() {
    return Map.from(positionActivity);
  }
}