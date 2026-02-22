import 'dart:math';
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
  double totalContribution; // Total amount contributed to pot across all betting rounds

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
    this.totalContribution = 0.0,
  });

  void reset() {
    // Only reset active players (don't reset empty seats)
    if (isActive) {
      hasFolded = false;
      hasActed = false;
      hasCalledCurrentBet = false;
      isAllIn = false;
      lastAction = PlayerAction.none;
      betThisRound = 0.0;
      totalContribution = 0.0;
      // Keep currentStack and startingStack unchanged for new hand
    }
  }

  void resetForNewStreet() {
    hasActed = false;
    hasCalledCurrentBet = false;
    lastAction = PlayerAction.none;
    // Add current round bet to total contribution before resetting
    totalContribution += betThisRound;
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
    // Note: Don't auto-deactivate here - players should remain active during the current hand
    // even if all-in. Deactivation should happen at the end of the hand if they're busted.
  }

  double getEffectiveStack() {
    return currentStack;
  }

  void _updateAllInStatus() {
    bool wasAllIn = isAllIn;
    isAllIn = (currentStack == 0.0);
    if (!wasAllIn && isAllIn) {
    } else if (wasAllIn && !isAllIn) {
    }
  }
}

class PokerGameState {
  final int numberOfPlayers;
  int smallBlind;
  int bigBlind;
  final bool isCashGame;
  bool hasBBante = false;
  
  List<PlayerState> players;
  int _buttonPosition = 1;
  int _currentPlayer = 1;
  double currentPot = 0.0;
  double currentBet = 0.0;
  int _effectiveBBPosition = 1; // Track who actually posted BB
  int _effectiveSBPosition = 1; // Track who actually posted SB
  bool _isInitializing = true; // CRITICAL: Flag to prevent premature action order calculation

  // Getters for effective blind positions
  int get effectiveBBPosition => _effectiveBBPosition;
  int get effectiveSBPosition => _effectiveSBPosition;

  // Button position property
  int get buttonPosition => _buttonPosition;
  set buttonPosition(int value) {
    if (_buttonPosition != value) {
      _buttonPosition = value;
      // CRITICAL: Recalculate action order when button position changes
      // BUT ONLY if we're not still initializing
      if (!_isInitializing && currentRound == BettingRound.preflop && !bettingRoundComplete) {
        _setInitialActionOrder();
      }
    }
  }
  bool hasBetThisRound;
  
  // Current player property
  int get currentPlayer => _currentPlayer;
  set currentPlayer(int value) {
    if (_currentPlayer != value) {
      // Validate current player is within bounds
      if (value < 1 || value > numberOfPlayers) {
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
    this.hasBBante = false,
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

    // Initialize players with default stacks but mark as inactive initially
    double defaultStack = isCashGame ? 100.0 : 1500.0;
    for (int i = 1; i <= numberOfPlayers; i++) {
      PlayerState player = PlayerState(playerId: i, isActive: false); // Start inactive
      player.setStack(defaultStack);
      players.add(player);
    }

    // CRITICAL: _setInitialActionOrder() will be called when finalizeInitialization() is called
    // after players are properly activated and button position is set
  }

  // CRITICAL: Method to complete initialization and trigger action order calculation
  void finalizeInitialization() {
    _isInitializing = false;
    if (currentRound == BettingRound.preflop && !bettingRoundComplete) {
      _setInitialActionOrder();
    }
  }

  void _setInitialActionOrder() {

    List<int> activePlayers = getActivePlayers();

    if (activePlayers.length < 2) {
      currentPlayer = activePlayers.isNotEmpty ? activePlayers[0] : 1;
      return;
    }

    if (activePlayers.length == 2) {
      // Heads up: button posts small blind and acts first preflop
      if (activePlayers.contains(buttonPosition)) {
        currentPlayer = buttonPosition;
      } else {
        // Find first active player
        currentPlayer = activePlayers[0];
      }
    } else {
      // Multi-way: UTG (Under The Gun) acts first
      // Find effective SB and BB positions among active players using proper calculation
      _effectiveSBPosition = _findSBSeatFromActivePlayers(activePlayers);
      _effectiveBBPosition = _findBBSeatFromActivePlayers(activePlayers);


      // UTG is the first active player after BB
      int utgPosition = _findNextActivePlayerAfter(_effectiveBBPosition);

      currentPlayer = utgPosition;
    }

  }

  int _getPositionFromButton(int seatsLeft) {
    // Validate inputs
    if (seatsLeft < 0) {
      return buttonPosition;
    }
    if (buttonPosition < 1 || buttonPosition > numberOfPlayers) {
      return 1;
    }

    // Calculate position going clockwise from button
    // seatsLeft=1 means SB (next seat clockwise from button)
    // seatsLeft=2 means BB (two seats clockwise from button)
    int position = buttonPosition;
    for (int i = 0; i < seatsLeft; i++) {
      position = (position % numberOfPlayers) + 1;
    }
    return position;
  }

  // Helper method to find the next active player from a starting position
  int _findNextActivePlayer(int startingPosition) {
    int position = startingPosition;
    int checked = 0;

    while (checked < numberOfPlayers) {
      PlayerState player = _getPlayer(position);
      if (player.isActive && player.currentStack > 0) {
        return position;
      }
      position = (position % numberOfPlayers) + 1;
      checked++;
    }

    // No active players found - return the starting position as fallback
    return startingPosition;
  }

  // Helper method to find the next active player AFTER a starting position
  int _findNextActivePlayerAfter(int startingPosition) {
    int position = (startingPosition % numberOfPlayers) + 1; // Start one position clockwise
    int checked = 0;

    while (checked < numberOfPlayers) {
      PlayerState player = _getPlayer(position);
      if (player.isActive && player.currentStack > 0) {
        return position;
      }
      position = (position % numberOfPlayers) + 1;
      checked++;
    }

    // No active players found - return the starting position as fallback
    return startingPosition;
  }

  // Helper method to determine who will post the BB (before actually posting)
  int _determineEffectiveBBPosition() {
    // Get list of active players
    List<int> activePlayers = getActivePlayers();
    if (activePlayers.length < 2) {
      return activePlayers.isNotEmpty ? activePlayers.first : 1;
    }


    // Find BB position using active players only
    int bbSeat = _findBBSeatFromActivePlayers(activePlayers);

    PlayerState bbPlayer = _getPlayer(bbSeat);

    if (bbPlayer.isActive && bbPlayer.currentStack > 0) {
      return bbSeat;
    } else {
      // Find next active player to post BB
      int nextBB = _findNextActivePlayer(bbSeat);
      return nextBB;
    }
  }

  // Helper method to find SB seat based on active players only
  int _findSBSeatFromActivePlayers(List<int> activePlayers) {
    if (activePlayers.length < 2) {
      return activePlayers.isNotEmpty ? activePlayers.first : 1;
    }

    // Sort active players for consistent ordering
    List<int> sortedActivePlayers = List<int>.from(activePlayers)..sort();

    // Find button index in sorted active players
    int buttonIndex = sortedActivePlayers.indexOf(buttonPosition);
    if (buttonIndex == -1) {
      // Button is not active, find next active seat clockwise
      buttonIndex = 0;
      for (int i = 0; i < sortedActivePlayers.length; i++) {
        if (sortedActivePlayers[i] > buttonPosition) {
          buttonIndex = i;
          break;
        }
      }
    }

    // SB is 1 position clockwise from button in active player order
    int sbIndex = (buttonIndex + 1) % sortedActivePlayers.length;
    return sortedActivePlayers[sbIndex];
  }

  // Helper method to find BB seat based on active players only
  int _findBBSeatFromActivePlayers(List<int> activePlayers) {
    if (activePlayers.length < 2) {
      return activePlayers.isNotEmpty ? activePlayers.first : 1;
    }

    // Sort active players for consistent ordering
    List<int> sortedActivePlayers = List<int>.from(activePlayers)..sort();

    // Find button index in sorted active players
    int buttonIndex = sortedActivePlayers.indexOf(buttonPosition);
    if (buttonIndex == -1) {
      // Button is not active, find next active seat clockwise
      buttonIndex = 0;
      for (int i = 0; i < sortedActivePlayers.length; i++) {
        if (sortedActivePlayers[i] > buttonPosition) {
          buttonIndex = i;
          break;
        }
      }
    }

    // BB is 2 positions clockwise from button in active player order
    // Button -> SB (+1) -> BB (+2)
    int bbIndex = (buttonIndex + 2) % sortedActivePlayers.length;
    return sortedActivePlayers[bbIndex];
  }

  PlayerState _getPlayer(int playerId) {
    try {
      return players.firstWhere((p) => p.playerId == playerId);
    } catch (e) {
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
      return 1; // Return player 1 as fallback
    }
    
    do {
      nextPlayer = (nextPlayer % numberOfPlayers) + 1;
      attempts++;
      
      // Failsafe: prevent infinite loop if no valid next player exists
      if (attempts > numberOfPlayers) {
        // Return original player if no other valid player found
        return fromPlayer;
      }
      
      final playerState = _getPlayer(nextPlayer);
      // Skip inactive players, folded players, and all-in players (who cannot act)
      if (playerState.isActive && !playerState.hasFolded && !playerState.isAllIn) {
        break;
      }
    } while (nextPlayer != fromPlayer);
    
    return nextPlayer;
  }

  List<int> getActivePlayers() {
    return players.where((p) => p.isActive && !p.hasFolded).map((p) => p.playerId).toList();
  }

  List<int> getPlayersWhoCanAct() {
    return players.where((p) => p.isActive && !p.hasFolded && !p.isAllIn).map((p) => p.playerId).toList();
  }

  List<int> getAllInPlayers() {
    return players.where((p) => p.isActive && !p.hasFolded && p.isAllIn).map((p) => p.playerId).toList();
  }

  bool areAllPlayersAllIn() {
    List<int> activePlayers = getActivePlayers();
    if (activePlayers.length <= 1) return false;

    List<int> playersWhoCanAct = getPlayersWhoCanAct();
    List<int> allInPlayers = getAllInPlayers();


    // Check if any players who can act still need to respond to the current bet
    for (int playerId in playersWhoCanAct) {
      PlayerState player = _getPlayer(playerId);
      // If there's a bet and they haven't called it, they need to act
      if (hasBetThisRound && !player.hasCalledCurrentBet) {
        return false;
      }
      // If they haven't acted this round at all, they need to act
      if (!player.hasActed) {
        return false;
      }
    }

    // All-in scenario: at least 2 active players, but 0 or 1 can act
    if (playersWhoCanAct.length == 0) {
      // Everyone is all-in
      return true;
    } else if (playersWhoCanAct.length == 1) {
      // Special case: If exactly 2 players are active (heads-up) and 1 is all-in,
      // the other player has had their chance to act - automatic showdown
      if (activePlayers.length == 2 && allInPlayers.length == 1) {
        PlayerState lastPlayer = _getPlayer(playersWhoCanAct[0]);
        // Only if they've already acted and called/checked
        if (lastPlayer.hasActed && (lastPlayer.hasCalledCurrentBet || !hasBetThisRound)) {
          return true;
        }
      }

      // Multi-way or heads-up where the last player has responded
      PlayerState lastActingPlayer = _getPlayer(playersWhoCanAct[0]);
      if (lastActingPlayer.hasActed && (lastActingPlayer.hasCalledCurrentBet || !hasBetThisRound)) {
        return true;
      }
    }
    return false; // Multiple players can still act
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
    List<PlayerState> activePlayers = players.where((p) => p.isActive && !p.hasFolded).toList();
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
      }
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
        
        player.lastAction = PlayerAction.call;
        player.hasCalledCurrentBet = true;
        actionText = "Player $currentPlayer: Call ${formatCurrency(actualAmount)}";
        break;

      case PlayerAction.bet:
        // Ensure amount is valid
        double minBet = getMinimumBet();
        // For all-in, max bet is current stack + what they've already bet this round
        double maxTotalBet = player.currentStack + player.betThisRound;
        double betAmount = amount.clamp(minBet, maxTotalBet);
        
        // Calculate additional amount beyond what player has already bet this round
        double additionalAmount = betAmount - player.betThisRound;
        
        // Update stack and bet tracking
        player.currentStack -= additionalAmount;
        player._updateAllInStatus();
        player.betThisRound = betAmount;
        
        // Update pot and current bet (only add the additional amount)
        currentPot += additionalAmount;
        currentBet = betAmount;
        
        hasBetThisRound = true;
        player.lastAction = PlayerAction.bet;
        player.hasCalledCurrentBet = true;
        actionText = "Player $currentPlayer: Bet ${formatCurrency(betAmount)}";
        // Reset all other players' call status when someone bets
        _resetCallStatusExcept(currentPlayer);
        break;

      case PlayerAction.raise:
        // Ensure amount is valid
        double minRaise = getMinimumRaise();
        // For all-in, max bet is current stack + what they've already bet this round
        double maxTotalBet = player.currentStack + player.betThisRound;

        // If player is short-stacked (can't meet min raise), allow all-in for whatever they have
        double raiseAmount;
        if (maxTotalBet < minRaise) {
          raiseAmount = maxTotalBet; // Short stack all-in
        } else {
          raiseAmount = amount.clamp(minRaise, maxTotalBet);
        }

        // Calculate additional amount beyond what player has already bet this round
        double additionalAmount = raiseAmount - player.betThisRound;
        
        // Update stack and bet tracking
        player.currentStack -= additionalAmount;
        player._updateAllInStatus();
        player.betThisRound = raiseAmount;
        
        // Update pot and current bet (only add the additional amount)
        currentPot += additionalAmount;
        currentBet = raiseAmount;
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
    List<PlayerState> activePlayers = players.where((p) => p.isActive && !p.hasFolded).toList();
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
      int bbPosition = _effectiveBBPosition;
      if (currentPlayer == bbPosition) {
        List<PlayerState> activePlayers = players.where((p) => p.isActive && !p.hasFolded).toList();
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
    List<PlayerState> activePlayers = players.where((p) => p.isActive && !p.hasFolded).toList();

    // If only one player left, round is complete
    if (activePlayers.length <= 1) {
      return true;
    }

    // Check for all-in scenarios first
    if (areAllPlayersAllIn()) {
      return true;
    }

    // For preflop, special handling for Big Blind
    if (currentRound == BettingRound.preflop && activePlayers.length >= 2) {
      // Use the effective BB position (who actually posted the blind)
      PlayerState bbPlayer = _getPlayer(_effectiveBBPosition);

      // If BB has folded, they don't need to act
      if (bbPlayer.hasFolded) {
        // BB folded, check if all other active players have acted and called current bet
        for (PlayerState player in activePlayers) {
          if (!player.hasActed || (!player.hasCalledCurrentBet && hasBetThisRound)) {
            return false;
          }
        }
        return true;
      }

      // If there was betting action (raises), BB must act
      if (hasBetThisRound && !bbPlayer.hasActed) {
        return false;
      }

      // If no betting (everyone just calls/checks to BB), BB can check to end round
      if (!hasBetThisRound) {
        // All players except BB must have acted
        for (PlayerState player in activePlayers) {
          if (player.playerId != _effectiveBBPosition && !player.hasActed) {
            return false;
          }
        }
        // Round is complete if everyone has acted (including BB option to check)
        bool allHaveActed = bbPlayer.hasActed;
        for (PlayerState player in activePlayers) {
          if (!player.hasActed) {
            allHaveActed = false;
            break;
          }
        }
        return allHaveActed;
      }

      // There was betting - check if everyone has called current bet
      for (PlayerState player in activePlayers) {
        if (!player.hasCalledCurrentBet) {
          return false;
        }
      }
      return true;
    }

    // Post-flop: all active players must have called current bet
    for (PlayerState player in activePlayers) {
      if (!player.hasCalledCurrentBet) {
        return false;
      }
    }

    return true;
  }

  String startNewStreet({Function(BettingRound, double)? onStreetComplete}) {
    String result = "";
    if (bettingRoundComplete) {
      // Process uncalled bet returns before street transition
      String uncalledReturns = processUncalledBetReturns();
      if (uncalledReturns.isNotEmpty) {
        result = uncalledReturns;
      }

      // Save pot amount for the completed street AFTER processing returns
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
      // But first check if anyone can actually act
      List<int> playersWhoCanAct = getPlayersWhoCanAct();

      if (playersWhoCanAct.isEmpty) {
        // No one can act - everyone is all-in or folded
        // Keep current player as is (doesn't matter since no one acts)
      } else if (numberOfPlayers == 2) {
        // Heads up: non-button (BB) acts first post-flop
        int nextPlayer = _getNextActivePlayer(buttonPosition);
        // Verify this player can actually act
        if (playersWhoCanAct.contains(nextPlayer)) {
          currentPlayer = nextPlayer;
        } else {
          // Fall back to first player who can act
          currentPlayer = playersWhoCanAct.first;
        }
      } else {
        // Multi-way: Use proper postflop action order starting from SB
        List<int> postflopOrder = PokerPositions.getPostflopActionOrder(buttonPosition, numberOfPlayers);

        // Find the first player in postflop order who can actually act
        bool foundActivePlayer = false;
        for (int playerSeat in postflopOrder) {
          if (playersWhoCanAct.contains(playerSeat)) {
            currentPlayer = playerSeat;
            foundActivePlayer = true;
            break;
          }
        }

        // Fallback if somehow no player found (shouldn't happen)
        if (!foundActivePlayer && playersWhoCanAct.isNotEmpty) {
          currentPlayer = playersWhoCanAct.first;
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
    return result;
  }

  void deactivateBustedPlayers() {
    for (PlayerState player in players) {
      if (player.isActive && player.currentStack <= 0.0) {
        player.isActive = false;
      }
    }
  }

  // Call this when a hand is complete to deactivate busted players
  void finalizeHandAndDeactivateBusted() {
    deactivateBustedPlayers();
  }

  void startNewHand() {
    // Deactivate busted players before starting new hand
    deactivateBustedPlayers();

    handNumber++;

    // Only move button for subsequent hands (not the first hand)
    if (handNumber > 1) {
      int oldButtonPosition = buttonPosition;

      // Check if current button position is still active
      if (!players[buttonPosition - 1].isActive || players[buttonPosition - 1].currentStack <= 0) {
      }

      // Move button to next active player
      int nextButton = buttonPosition;
      int attempts = 0;
      do {
        nextButton = (nextButton % numberOfPlayers) + 1;
        attempts++;
      } while ((!players[nextButton - 1].isActive || players[nextButton - 1].currentStack <= 0) && attempts < numberOfPlayers);

      if (attempts < numberOfPlayers) {
        buttonPosition = nextButton;

        // Button position moved successfully
      } else {
      }
    } else {
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
    _setInitialActionOrder();
  }

  // Auto-advance to showdown when all remaining players are all-in
  bool shouldAutoAdvanceToShowdown() {
    // First check if betting round is complete
    if (!bettingRoundComplete) return false;

    List<int> activePlayers = getActivePlayers();
    List<int> playersWhoCanAct = getPlayersWhoCanAct();
    List<int> allInPlayers = getAllInPlayers();

    // Need at least 2 active players for a hand
    if (activePlayers.length < 2) return false;


    // Auto-advance if NO players can act (all are all-in)
    if (playersWhoCanAct.length == 0) {
      return true;
    }

    // Special case: heads-up all-in (2 active, 1 all-in, 1 can act)
    if (activePlayers.length == 2 && allInPlayers.length == 1 && playersWhoCanAct.length <= 1) {
      return true;
    }

    // Multi-way: 1 player can act and they've responded
    if (playersWhoCanAct.length == 1) {
      PlayerState lastPlayer = _getPlayer(playersWhoCanAct[0]);
      bool shouldAdvance = lastPlayer.hasActed && (lastPlayer.hasCalledCurrentBet || !hasBetThisRound);
      if (shouldAdvance) {
      }
      return shouldAdvance;
    }

    return false;
  }

  // Auto-advance to the next street only (not all the way to showdown)
  String autoAdvanceToNextStreet() {
    if (!shouldAutoAdvanceToShowdown()) {
      return "Cannot auto-advance: players can still act";
    }

    List<String> advances = [];
    List<int> allInPlayers = getAllInPlayers();

    advances.add("🔥 AUTO-ADVANCE: All remaining players all-in (${allInPlayers.join(', ')})");

    // Process uncalled bet returns first
    String uncalledReturns = processUncalledBetReturns();
    if (uncalledReturns.isNotEmpty) {
      advances.add(uncalledReturns);
    }

    // Show side pot information if multiple all-in players with different stack sizes
    if (allInPlayers.length > 1) {
      List<SidePot> sidePots = calculateSidePots();
      if (sidePots.length > 1) {
        advances.add("💰 Multiple side pots created:");
        advances.add(getSidePotInfo());
      }
    }

    // Only advance one street at a time to allow board card input
    if (currentRound != BettingRound.river) {
      switch (currentRound) {
        case BettingRound.preflop:
          currentRound = BettingRound.flop;
          advances.add("Auto-advance to FLOP - deal the flop cards");
          break;
        case BettingRound.flop:
          currentRound = BettingRound.turn;
          advances.add("Auto-advance to TURN - deal the turn card");
          break;
        case BettingRound.turn:
          currentRound = BettingRound.river;
          advances.add("Auto-advance to RIVER - deal the river card");
          break;
        case BettingRound.river:
          break; // Already at river
      }

      // Reset betting round state for the new street
      bettingRoundComplete = false;
      hasBetThisRound = false;
      currentBet = 0.0;

      // Reset player states for new street, but handle all-in scenarios carefully
      List<int> activePlayers = getActivePlayers();
      List<int> playersWhoCanAct = getPlayersWhoCanAct();
      List<int> allInPlayers = getAllInPlayers();

      // In heads-up all-in scenarios, don't reset the non-all-in player's action state
      // because they've already called/responded to the all-in
      bool isHeadsUpAllIn = activePlayers.length == 2 && allInPlayers.length == 1 && playersWhoCanAct.length <= 1;

      if (isHeadsUpAllIn && playersWhoCanAct.length == 1) {
        PlayerState remainingPlayer = _getPlayer(playersWhoCanAct[0]);
        if (remainingPlayer.hasActed && remainingPlayer.hasCalledCurrentBet) {
          advances.add("🎯 Heads-up all-in - no action reset needed");
          // Don't reset anyone's action state
        } else {
          // Still need the remaining player to act, reset normally
          for (PlayerState player in players) {
            player.resetForNewStreet();
          }
        }
      } else if (playersWhoCanAct.isEmpty) {
        // Everyone is all-in, no action needed
        advances.add("🎯 All players all-in - no action reset needed");
      } else {
        // Normal situation, reset for new street
        for (PlayerState player in players) {
          player.resetForNewStreet();
        }
      }
    } else {
      // At river, mark as complete and ready for showdown
      bettingRoundComplete = true;
      advances.add("All betting complete - ready for showdown");
    }

    return advances.join('\n');
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
      info.add("SB: Player $_effectiveSBPosition, BB: Player $_effectiveBBPosition");
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

  void setPlayerActive(int playerId, bool isActive) {
    PlayerState player = _getPlayer(playerId);
    player.isActive = isActive;
  }

  PlayerState? getCurrentPlayer() {
    if (currentPlayer <= 0 || currentPlayer > numberOfPlayers) return null;
    return _getPlayer(currentPlayer);
  }

  double getCurrentBet() {
    return currentBet;
  }

  double getMinimumBet() {
    // For betting (not raising), minimum is always 1 big blind
    return bigBlind.toDouble();
  }

  double getMinimumRaise() {
    // For raising, minimum is the current bet amount or the last raise size, whichever is larger
    // If no bet has been made, minimum raise is 2x big blind
    if (currentBet == 0) {
      return bigBlind.toDouble() * 2;
    }
    return currentBet.clamp(bigBlind.toDouble() * 2, double.infinity);
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
    // Reset all player bets first (in case initializePot is called multiple times)
    // This handles the case where button position changes between hands
    for (PlayerState player in players) {
      // Refund any previous blind bets back to player stack
      if (player.betThisRound > 0) {
        player.currentStack += player.betThisRound;
        player.betThisRound = 0.0;
      }
    }

    currentPot = 0.0;
    currentBet = bigBlind.toDouble();
    _effectiveBBPosition = _determineEffectiveBBPosition(); // Set before posting

    // Post blinds
    if (numberOfPlayers > 2) {
      // Multi-way: Use active players for SB/BB positions
      List<int> activePlayers = getActivePlayers();
      int sbPosition = _findSBSeatFromActivePlayers(activePlayers);
      int bbPosition = _effectiveBBPosition; // Already calculated above

      PlayerState sbPlayer = _getPlayer(sbPosition);
      PlayerState bbPlayer = _getPlayer(bbPosition);

      // Check if SB seat is active and has chips to post blind
      if (sbPlayer.isActive && sbPlayer.currentStack > 0) {
        // Small blind posts
        double sbAmount = smallBlind.toDouble();
        if (sbPlayer.currentStack < sbAmount) {
          sbAmount = sbPlayer.currentStack; // All-in for less
        }
        sbPlayer.betThisRound = sbAmount;
        sbPlayer.currentStack -= sbAmount;
        sbPlayer._updateAllInStatus();
        currentPot += sbAmount;
        _effectiveSBPosition = sbPosition; // Track who posted SB
      } else {

        // Find the next active player to post the SB
        int nextSBPosition = _findNextActivePlayer(sbPosition);
        PlayerState nextSBPlayer = _getPlayer(nextSBPosition);

        if (nextSBPlayer.isActive && nextSBPlayer.currentStack > 0 && nextSBPosition != sbPosition) {

          // Post the SB with the active player
          double sbAmount = smallBlind.toDouble();
          if (nextSBPlayer.currentStack < sbAmount) {
            sbAmount = nextSBPlayer.currentStack; // All-in for less
          }
          nextSBPlayer.betThisRound = sbAmount;
          nextSBPlayer.currentStack -= sbAmount;
          nextSBPlayer._updateAllInStatus();
          currentPot += sbAmount;
          _effectiveSBPosition = nextSBPosition; // Track who actually posted SB
        } else {
        }
      }

      // Check if BB seat is active and has chips to post blind
      if (bbPlayer.isActive && bbPlayer.currentStack > 0) {
        // Big blind posts
        double bbAmount = bigBlind.toDouble();
        double anteAmount = 0.0;

        // If BB ante is enabled, BB posts an additional ante equal to BB amount
        if (hasBBante) {
          anteAmount = bigBlind.toDouble();
        }

        double totalBBPost = bbAmount + anteAmount;

        if (bbPlayer.currentStack < totalBBPost) {
          totalBBPost = bbPlayer.currentStack; // All-in for less
          // If all-in, split proportionally between BB and ante
          if (hasBBante && totalBBPost > 0) {
            bbAmount = totalBBPost / 2;
            anteAmount = totalBBPost - bbAmount;
          } else {
            bbAmount = totalBBPost;
            anteAmount = 0.0;
          }
          currentBet = bbAmount; // Adjust current bet if BB is all-in for less
        } else {
          // Normal case: BB has enough chips
          currentBet = bbAmount; // Current bet is just the BB portion (not including ante)
        }

        bbPlayer.betThisRound = totalBBPost; // Track full amount (BB + ante) for side pot calculation
        bbPlayer.currentStack -= totalBBPost;
        bbPlayer._updateAllInStatus();
        currentPot += totalBBPost;
        _effectiveBBPosition = bbPosition; // Track who posted BB

        if (hasBBante) {
        } else {
        }
      } else {

        // Find the next active player to post the BB
        int nextBBPosition = _findNextActivePlayer(bbPosition);
        PlayerState nextBBPlayer = _getPlayer(nextBBPosition);

        if (nextBBPlayer.isActive && nextBBPlayer.currentStack > 0 && nextBBPosition != bbPosition) {

          // Post the BB with the active player
          double bbAmount = bigBlind.toDouble();
          double anteAmount = 0.0;

          // If BB ante is enabled, BB posts an additional ante equal to BB amount
          if (hasBBante) {
            anteAmount = bigBlind.toDouble();
          }

          double totalBBPost = bbAmount + anteAmount;

          if (nextBBPlayer.currentStack < totalBBPost) {
            totalBBPost = nextBBPlayer.currentStack; // All-in for less
            // If all-in, split proportionally between BB and ante
            if (hasBBante && totalBBPost > 0) {
              bbAmount = totalBBPost / 2;
              anteAmount = totalBBPost - bbAmount;
            } else {
              bbAmount = totalBBPost;
              anteAmount = 0.0;
            }
            currentBet = bbAmount; // Adjust current bet if BB is all-in for less
          } else {
            // Normal case: BB has enough chips
            currentBet = bbAmount; // Current bet is just the BB portion (not including ante)
          }

          nextBBPlayer.betThisRound = totalBBPost; // Track full amount (BB + ante) for side pot calculation
          nextBBPlayer.currentStack -= totalBBPost;
          nextBBPlayer._updateAllInStatus();
          currentPot += totalBBPost;
          _effectiveBBPosition = nextBBPosition; // Track who actually posted BB

          if (hasBBante) {
          } else {
          }
        } else {
          // If BB seat is empty, adjust current bet based on what's actually in the pot
          if (sbPlayer.isActive && sbPlayer.currentStack > 0) {
            // Only SB posted, so minimum bet should be SB amount
            currentBet = smallBlind.toDouble();
          } else {
            // Both SB and BB empty - no mandatory betting
            currentBet = 0.0;
          }
        }
      }

    } else {
      // Heads-up: button posts SB, other player posts BB
      int sbPosition = buttonPosition;
      int bbPosition = (buttonPosition % numberOfPlayers) + 1;

      PlayerState sbPlayer = _getPlayer(sbPosition);
      PlayerState bbPlayer = _getPlayer(bbPosition);

      // Post SB if player is active
      if (sbPlayer.isActive && sbPlayer.currentStack > 0) {
        double sbAmount = smallBlind.toDouble();
        if (sbPlayer.currentStack < sbAmount) {
          sbAmount = sbPlayer.currentStack;
        }
        sbPlayer.betThisRound = sbAmount;
        sbPlayer.currentStack -= sbAmount;
        sbPlayer._updateAllInStatus();
        currentPot += sbAmount;
        _effectiveSBPosition = sbPosition; // Track who posted SB in heads-up
      }

      // Post BB if player is active
      if (bbPlayer.isActive && bbPlayer.currentStack > 0) {
        double bbAmount = bigBlind.toDouble();
        double anteAmount = 0.0;

        // If BB ante is enabled, BB posts an additional ante equal to BB amount
        if (hasBBante) {
          anteAmount = bigBlind.toDouble();
        }

        double totalBBPost = bbAmount + anteAmount;

        if (bbPlayer.currentStack < totalBBPost) {
          totalBBPost = bbPlayer.currentStack;
          // If all-in, split proportionally between BB and ante
          if (hasBBante && totalBBPost > 0) {
            bbAmount = totalBBPost / 2;
            anteAmount = totalBBPost - bbAmount;
          } else {
            bbAmount = totalBBPost;
            anteAmount = 0.0;
          }
          currentBet = bbAmount; // Adjust current bet if BB is all-in for less
        } else {
          // Normal case: BB has enough chips
          currentBet = bbAmount; // Current bet is just the BB portion (not including ante)
        }

        bbPlayer.betThisRound = totalBBPost; // Track full amount (BB + ante) for side pot calculation
        bbPlayer.currentStack -= totalBBPost;
        bbPlayer._updateAllInStatus();
        currentPot += totalBBPost;
        _effectiveBBPosition = bbPosition; // Track who posted BB in heads-up

        if (hasBBante) {
        } else {
        }
      }
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
        // Calculate the additional amount needed
        double targetBetAmount = amount;
        double additionalAmount = targetBetAmount - player.betThisRound;

        // Cap additional amount to available stack
        if (additionalAmount > player.currentStack) {
          additionalAmount = player.currentStack; // All-in with what's available
          targetBetAmount = player.betThisRound + additionalAmount;
        }

        // Update player state
        player.betThisRound = targetBetAmount;
        player.currentStack -= additionalAmount;
        player._updateAllInStatus();
        currentPot += additionalAmount;

        // Update current bet only if this is the new highest bet
        if (targetBetAmount > currentBet) {
          currentBet = targetBetAmount;
        }
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

  // Handle uncalled bet returns when all-in player can't cover larger bets
  String processUncalledBetReturns() {
    List<PlayerState> activePlayers = players.where((p) => p.isActive && !p.hasFolded).toList();

    if (activePlayers.length <= 1) return "";

    // Find the maximum bet that can be called by all players
    double maxCallableAmount = activePlayers
        .map((p) => p.betThisRound)
        .reduce((a, b) => a < b ? a : b);

    List<String> returns = [];
    double totalReturned = 0;

    for (PlayerState player in activePlayers) {
      if (player.betThisRound > maxCallableAmount) {
        double returnAmount = player.betThisRound - maxCallableAmount;
        player.betThisRound = maxCallableAmount;
        player.currentStack += returnAmount;
        currentPot -= returnAmount;
        totalReturned += returnAmount;
        returns.add("${formatCurrency(returnAmount)} returned to Player ${player.playerId}");
      }
    }

    // Update current bet to the maximum callable amount
    if (totalReturned > 0) {
      currentBet = maxCallableAmount;
      returns.insert(0, "💰 Uncalled bet returns:");
    }

    return returns.join('\n');
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
    // Get list of active players for accurate position calculation
    List<int> activePlayers = getActivePlayers();
    String positionName = PokerPositions.getPositionNameForActivePlayers(playerId, buttonPosition, activePlayers);

    // Only track non-fold actions for activity
    if (action != PlayerAction.fold && action != PlayerAction.none) {
      positionActivity[positionName] = (positionActivity[positionName] ?? 0) + 1;
    }
  }

  // Calculate side pots for the current hand
  List<SidePot> calculateSidePots() {
    // Add current round contributions to total contributions for calculation
    List<PlayerState> playersForCalculation = players.map((p) {
      PlayerState tempPlayer = PlayerState(
        playerId: p.playerId,
        isActive: p.isActive,
        hasFolded: p.hasFolded,
        hasActed: p.hasActed,
        hasCalledCurrentBet: p.hasCalledCurrentBet,
        isAllIn: p.isAllIn,
        lastAction: p.lastAction,
        startingStack: p.startingStack,
        currentStack: p.currentStack,
        betThisRound: p.betThisRound,
        totalContribution: p.totalContribution + p.betThisRound,
      );
      return tempPlayer;
    }).toList();

    return SidePotCalculator.calculateSidePots(playersForCalculation);
  }

  // Get formatted side pot information
  String getSidePotInfo() {
    List<SidePot> sidePots = calculateSidePots();
    return SidePotCalculator.formatSidePots(sidePots);
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

  /// Get the position name for a specific player considering current active players
  String getPlayerPositionName(int playerId) {
    List<int> activePlayers = getActivePlayers();
    return PokerPositions.getPositionNameForActivePlayers(playerId, buttonPosition, activePlayers);
  }

  // === Pot & Stack Info Panel Helper Methods ===

  /// Get effective stack (minimum stack among active non-folded players who can still act)
  double getEffectiveStackForInfoPanel() {
    final activePlayers = players
        .where((p) => p.isActive && !p.hasFolded)
        .toList();
    if (activePlayers.isEmpty) return 0;
    return activePlayers.map((p) => p.currentStack + p.betThisRound).reduce(min);
  }

  /// Get SPR (Stack-to-Pot Ratio) based on effective stack
  double getSPR() {
    if (currentPot <= 0) return 0;
    final effStack = getEffectiveStackForInfoPanel();
    return effStack / currentPot;
  }

  /// Get pot odds as percentage (when facing a bet)
  /// Returns null if not facing a bet
  double? getPotOdds(int heroSeat) {
    final hero = players.firstWhere(
      (p) => p.playerId == heroSeat,
      orElse: () => PlayerState(playerId: -1),
    );
    if (hero.playerId == -1) return null;

    final toCall = currentBet - hero.betThisRound;
    if (toCall <= 0) return null; // Not facing a bet

    final potAfterCall = currentPot + toCall;
    return (toCall / potAfterCall) * 100;
  }

  /// Get amount hero needs to call
  double getToCall(int heroSeat) {
    final hero = players.firstWhere(
      (p) => p.playerId == heroSeat,
      orElse: () => PlayerState(playerId: -1),
    );
    if (hero.playerId == -1) return 0;
    return max(0.0, currentBet - hero.betThisRound);
  }
}

// Side pot calculation structure
class SidePot {
  final double amount;
  final List<int> eligiblePlayers;
  final double maxContribution;

  SidePot({
    required this.amount,
    required this.eligiblePlayers,
    required this.maxContribution,
  });

  @override
  String toString() {
    return 'SidePot(amount: $amount, eligible: $eligiblePlayers, maxContrib: $maxContribution)';
  }
}

class SidePotCalculator {
  static List<SidePot> calculateSidePots(List<PlayerState> players) {
    // Filter to only active players (not folded)
    List<PlayerState> activePlayers = players.where((p) => p.isActive && !p.hasFolded).toList();

    if (activePlayers.length <= 1) {
      return []; // No side pots needed with 0 or 1 players
    }

    // Create a list of player contributions with their IDs
    // IMPORTANT: Include both totalContribution AND betThisRound to get full hand contribution
    List<MapEntry<int, double>> contributions = activePlayers
        .map((p) => MapEntry(p.playerId, p.totalContribution + p.betThisRound))
        .toList();

    // Sort by contribution amount (lowest first)
    contributions.sort((a, b) => a.value.compareTo(b.value));

    List<SidePot> sidePots = [];
    double previousLevel = 0.0;

    for (int i = 0; i < contributions.length; i++) {
      double currentLevel = contributions[i].value;

      if (currentLevel > previousLevel) {
        double potAmount = (currentLevel - previousLevel) * (contributions.length - i);

        // Players eligible for this side pot (those who contributed at least this much)
        List<int> eligiblePlayers = contributions
            .skip(i)
            .map((entry) => entry.key)
            .toList();

        sidePots.add(SidePot(
          amount: potAmount,
          eligiblePlayers: eligiblePlayers,
          maxContribution: currentLevel,
        ));

        previousLevel = currentLevel;
      }
    }

    return sidePots;
  }

  static String formatSidePots(List<SidePot> sidePots) {
    if (sidePots.isEmpty) return "No side pots";

    List<String> descriptions = [];
    for (int i = 0; i < sidePots.length; i++) {
      SidePot pot = sidePots[i];
      String potName = i == 0 ? "Main pot" : "Side pot ${i}";
      descriptions.add("$potName: \$${pot.amount.toStringAsFixed(2)} (Players: ${pot.eligiblePlayers.join(', ')})");
    }

    return descriptions.join('\n');
  }
}