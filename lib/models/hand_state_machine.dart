import '../models/poker_game_state.dart';
import '../models/game_types.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
import '../services/auth_service.dart';
import '../services/opponent_service.dart';
import '../utils/poker_positions.dart';

enum HandState {
  notStarted,
  inProgress,
  completed,
  saved,
}

enum SessionState {
  notStarted,
  active,
  paused,
  ended,
}

class ActionRecord {
  final int player;
  final PlayerAction action;
  final BettingRound street;
  final DateTime timestamp;
  final int buttonPosition;
  final String? playerName;
  final String? playerPosition;
  final double? playerStack;
  final double? amount;

  ActionRecord({
    required this.player,
    required this.action,
    required this.street,
    required this.timestamp,
    required this.buttonPosition,
    this.playerName,
    this.playerPosition,
    this.playerStack,
    this.amount,
  });

  Map<String, dynamic> toMap() {
    return {
      'player': player,
      'action': action.name,
      'street': street.name,
      'timestamp': timestamp.toIso8601String(),
      'buttonPosition': buttonPosition,
      'playerName': playerName,
      'playerPosition': playerPosition,
      'playerStack': playerStack,
      'amount': amount,
    };
  }

  factory ActionRecord.fromMap(Map<String, dynamic> map) {
    return ActionRecord(
      player: map['player'] ?? 0,
      action: PlayerAction.values.firstWhere((e) => e.name == map['action'], orElse: () => PlayerAction.none),
      street: BettingRound.values.firstWhere((e) => e.name == map['street'], orElse: () => BettingRound.preflop),
      timestamp: DateTime.parse(map['timestamp']),
      buttonPosition: map['buttonPosition'] ?? 1,
      playerName: map['playerName'],
      playerPosition: map['playerPosition'],
      playerStack: map['playerStack']?.toDouble(),
      amount: map['amount']?.toDouble(),
    );
  }
}

class BoardCards {
  List<String> flop;
  String? turn;
  String? river;

  BoardCards({
    this.flop = const [],
    this.turn,
    this.river,
  });

  Map<String, dynamic> toMap() {
    return {
      'flop': flop,
      'turn': turn,
      'river': river,
    };
  }

  factory BoardCards.fromMap(Map<String, dynamic> map) {
    return BoardCards(
      flop: List<String>.from(map['flop'] ?? []),
      turn: map['turn'],
      river: map['river'],
    );
  }
}

class HoleCards {
  String? card1;
  String? card2;

  HoleCards({this.card1, this.card2});

  Map<String, dynamic> toMap() {
    return {
      'card1': card1,
      'card2': card2,
    };
  }

  factory HoleCards.fromMap(Map<String, dynamic> map) {
    return HoleCards(
      card1: map['card1'],
      card2: map['card2'],
    );
  }

  bool get isComplete => card1 != null && card2 != null && card1!.isNotEmpty && card2!.isNotEmpty;
}

class ShowdownData {
  Map<int, HoleCards> playerCards = {}; // player number -> hole cards
  int? winner;
  String? handDescription;

  ShowdownData({this.winner, this.handDescription});

  Map<String, dynamic> toMap() {
    return {
      'playerCards': playerCards.map((key, value) => MapEntry(key.toString(), value.toMap())),
      'winner': winner,
      'handDescription': handDescription,
    };
  }

  factory ShowdownData.fromMap(Map<String, dynamic> map) {
    final showdown = ShowdownData(
      winner: map['winner'],
      handDescription: map['handDescription'],
    );
    
    final playerCardsMap = map['playerCards'] as Map<String, dynamic>?;
    if (playerCardsMap != null) {
      playerCardsMap.forEach((key, value) {
        showdown.playerCards[int.parse(key)] = HoleCards.fromMap(value);
      });
    }
    
    return showdown;
  }
}

class HandRecord {
  final int handNumber;
  final int buttonPosition;
  final int playerCount;
  final List<ActionRecord> actions;
  final DateTime startTime;
  DateTime? endTime;
  HandState state;
  BoardCards? boardCards;
  HoleCards? ourHoleCards; // Our hole cards
  ShowdownData? showdownData; // Showdown information
  bool reachedShowdown = false;
  double potAmount = 0;
  
  // Per-street pot tracking
  double preflopPot = 0;
  double flopPot = 0;
  double turnPot = 0;
  double riverPot = 0;
  
  int? winnerId;
  int? heroPosition;

  // Chopped pot fields
  bool isChoppedPot = false;
  List<int>? choppedWinners;
  Map<int, double>? individualShares;
  double? sharePerWinner;

  HandRecord({
    required this.handNumber,
    required this.buttonPosition,
    required this.playerCount,
    required this.startTime,
    List<ActionRecord>? actions,
    this.endTime,
    this.state = HandState.notStarted,
    this.boardCards,
    this.ourHoleCards,
    this.showdownData,
    this.reachedShowdown = false,
    this.potAmount = 0,
    this.preflopPot = 0,
    this.flopPot = 0,
    this.turnPot = 0,
    this.riverPot = 0,
    this.winnerId,
    this.heroPosition,
  }) : actions = actions ?? [];

  void addAction(ActionRecord action) {
    // Check for duplicate actions to prevent multiple recordings
    final isDuplicate = actions.any((existing) =>
      existing.player == action.player &&
      existing.action == action.action &&
      existing.street == action.street &&
      (DateTime.now().difference(existing.timestamp).inMilliseconds < 2000) // Within 2 seconds
    );

    if (isDuplicate) {
      print('Duplicate action detected and ignored: Player ${action.player} ${action.action.name} on ${action.street.name}');
      return;
    }

    actions.add(action);
  }

  void markCompleted() {
    state = HandState.completed;
    endTime = DateTime.now();
  }

  void markSaved() {
    state = HandState.saved;
  }

  void setBoardCards(BoardCards cards) {
    boardCards = cards;
  }

  Map<String, dynamic> toMap() {
    return {
      'handNumber': handNumber,
      'buttonPosition': buttonPosition,
      'playerCount': playerCount,
      'actions': actions.map((a) => a.toMap()).toList(),
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'state': state.name,
      'boardCards': boardCards?.toMap(),
      'ourHoleCards': ourHoleCards?.toMap(),
      'showdownData': showdownData?.toMap(),
      'reachedShowdown': reachedShowdown,
      'potAmount': potAmount,
      'preflopPot': preflopPot,
      'flopPot': flopPot,
      'turnPot': turnPot,
      'riverPot': riverPot,
      'winnerId': winnerId,
      'heroPosition': heroPosition,
      'isChoppedPot': isChoppedPot,
      'choppedWinners': choppedWinners,
      'individualShares': individualShares?.map((key, value) => MapEntry(key.toString(), value)),
      'sharePerWinner': sharePerWinner,
    };
  }

  factory HandRecord.fromMap(Map<String, dynamic> map) {
    final hand = HandRecord(
      handNumber: map['handNumber'] ?? 0,
      buttonPosition: map['buttonPosition'] ?? 1,
      playerCount: map['playerCount'] ?? 6,
      startTime: DateTime.parse(map['startTime']),
      actions: (map['actions'] as List<dynamic>?)?.map((a) => ActionRecord.fromMap(a)).toList(),
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
      state: HandState.values.firstWhere((e) => e.name == map['state'], orElse: () => HandState.notStarted),
      boardCards: map['boardCards'] != null ? BoardCards.fromMap(map['boardCards']) : null,
      ourHoleCards: map['ourHoleCards'] != null ? HoleCards.fromMap(map['ourHoleCards']) : null,
      showdownData: map['showdownData'] != null ? ShowdownData.fromMap(map['showdownData']) : null,
      reachedShowdown: map['reachedShowdown'] ?? false,
      potAmount: (map['potAmount'] ?? 0).toDouble(),
      preflopPot: (map['preflopPot'] ?? 0).toDouble(),
      flopPot: (map['flopPot'] ?? 0).toDouble(),
      turnPot: (map['turnPot'] ?? 0).toDouble(),
      riverPot: (map['riverPot'] ?? 0).toDouble(),
      winnerId: map['winnerId'],
      heroPosition: map['heroPosition'],
    );

    // Set chopped pot fields
    hand.isChoppedPot = map['isChoppedPot'] ?? false;
    hand.choppedWinners = map['choppedWinners'] != null
        ? List<int>.from(map['choppedWinners'])
        : null;
    hand.individualShares = map['individualShares'] != null
        ? Map<int, double>.from(
            (map['individualShares'] as Map<String, dynamic>)
                .map((key, value) => MapEntry(int.parse(key), value.toDouble()))
          )
        : null;
    hand.sharePerWinner = map['sharePerWinner']?.toDouble();

    return hand;
  }
}

class PokerSessionManager {
  String? sessionId;
  SessionState sessionState = SessionState.notStarted;
  
  // Current hand tracking
  HandRecord? currentHand;
  final List<HandRecord> completedHands = [];
  
  // Session settings
  int smallBlind;
  int bigBlind;
  int playerCount;
  int? ourSeatNumber; // Our position at the table (1-playerCount)
  GameType gameType; // Cash game or tournament
  int buttonPosition = 1; // Current button position
  DateTime? sessionStartTime;
  DateTime? sessionEndTime;
  
  // Player management
  Map<int, String> playerNames = {}; // seat number -> player name
  Set<int> activeSeats = {}; // seats that have players

  PokerSessionManager({
    required this.smallBlind,
    required this.bigBlind,
    required this.playerCount,
    this.ourSeatNumber,
    this.gameType = GameType.cash,
  });

  // Start a new session
  Future<void> startSession() async {
    print('🚀 DEBUG: Starting session...');
    print('🚀 DEBUG: User authenticated: ${AuthService.isSignedIn}');
    print('🚀 DEBUG: Current user: ${AuthService.currentUser?.email ?? 'Anonymous'}');
    print('🚀 DEBUG: User ID: ${AuthService.userId ?? 'null'}');
    
    sessionStartTime = DateTime.now();
    sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      print('🚀 DEBUG: Attempting Firebase session creation...');
      // Try Firebase first
      final firebaseId = await FirebaseService.createSession(
        smallBlind: smallBlind,
        bigBlind: bigBlind,
        playerCount: playerCount,
        ourSeatNumber: ourSeatNumber,
        gameType: gameType,
      );
      sessionId = firebaseId;
      print('🚀 DEBUG: Session started with Firebase ID: $sessionId');
    } catch (e) {
      print('🚀 DEBUG: Failed to start Firebase session: $e');
      print('🚀 DEBUG: Session started OFFLINE with ID: $sessionId');
    }
    
    // Always save locally as backup
    await LocalStorageService.saveSession(
      sessionId: sessionId!,
      smallBlind: smallBlind,
      bigBlind: bigBlind,
      playerCount: playerCount,
      startTime: sessionStartTime!.toIso8601String(),
      ourSeatNumber: ourSeatNumber,
      gameType: gameType,
    );
    
    sessionState = SessionState.active;
  }

  // Start a new hand
  void startHand(int handNumber, int buttonPosition) {
    // Only complete previous hand if it has actions (not empty)
    if (currentHand != null && currentHand!.state == HandState.inProgress) {
      if (currentHand!.actions.isNotEmpty) {
        completeCurrentHand();
      } else {
        // Discard empty hand without saving
        print('Discarding empty hand #${currentHand!.handNumber}');
        currentHand = null;
      }
    }

    // Update current button position
    this.buttonPosition = buttonPosition;

    currentHand = HandRecord(
      handNumber: handNumber,
      buttonPosition: buttonPosition,
      playerCount: playerCount,
      startTime: DateTime.now(),
    );
    currentHand!.state = HandState.inProgress;
    
    print('Hand #$handNumber started (Button: Player $buttonPosition)');
  }

  // Record an action
  void recordAction(
    int player, 
    PlayerAction action, 
    BettingRound street, 
    int buttonPosition,
    {double? playerStack, double? amount}
  ) {
    if (currentHand == null || currentHand!.state != HandState.inProgress) {
      print('Warning: No active hand to record action');
      return;
    }

    // Get player name and position
    final playerName = getPlayerName(player);
    final playerPosition = PokerPositions.getPositionName(player, buttonPosition, playerCount);

    final actionRecord = ActionRecord(
      player: player,
      action: action,
      street: street,
      timestamp: DateTime.now(),
      buttonPosition: buttonPosition,
      playerName: playerName,
      playerPosition: playerPosition,
      playerStack: playerStack,
      amount: amount,
    );

    currentHand!.addAction(actionRecord);
    
    // Optionally save action to Firebase immediately for real-time tracking
    if (sessionId != null && !sessionId!.startsWith('offline_')) {
      FirebaseService.saveAction(
        sessionId: sessionId!,
        handNumber: currentHand!.handNumber,
        player: player,
        action: action.name,
        street: street.name,
        buttonPosition: buttonPosition,
      ).catchError((e) {
        print('Failed to save action real-time: $e');
      });
    }
    
    print('Action recorded: Player $player ${action.name} on ${street.name}');
  }

  // Save pot amount at the end of each street
  void savePotForStreet(BettingRound street, double potAmount) {
    if (currentHand == null) return;
    
    print('💰 Saving pot for ${street.name}: \$${potAmount.toStringAsFixed(0)}');
    
    switch (street) {
      case BettingRound.preflop:
        currentHand!.preflopPot = potAmount;
        break;
      case BettingRound.flop:
        currentHand!.flopPot = potAmount;
        break;
      case BettingRound.turn:
        currentHand!.turnPot = potAmount;
        break;
      case BettingRound.river:
        currentHand!.riverPot = potAmount;
        break;
    }
    
    // Update the final pot amount as well
    currentHand!.potAmount = potAmount;
    
    print('💰 Current hand pot tracking: Preflop: \$${currentHand!.preflopPot}, Flop: \$${currentHand!.flopPot}, Turn: \$${currentHand!.turnPot}, River: \$${currentHand!.riverPot}');
  }

  // Complete the current hand
  void completeCurrentHand({double? potAmount, int? winnerId}) {
    if (currentHand == null) return;
    
    // Set pot amount and winner if provided
    if (potAmount != null) {
      currentHand!.potAmount = potAmount;
    }
    if (winnerId != null) {
      currentHand!.winnerId = winnerId;
    }
    
    // Set hero position
    currentHand!.heroPosition = ourSeatNumber;
    
    currentHand!.markCompleted();
    completedHands.add(currentHand!);
    
    // Update opponent statistics for this hand
    _updateOpponentStats();
    
    // Save hand to Firebase and local storage
    _saveHandToFirebase(currentHand!);
    
    // Update session with latest hand count
    _updateSessionProgress();
    
    print('Hand #${currentHand!.handNumber} completed with pot: $potAmount, winner: $winnerId');
    currentHand = null;
  }

  void completeCurrentHandWithChop({
    required double potAmount,
    required List<int> winnerIds,
    Map<int, double>? individualShares,
    double? sharePerWinner
  }) {
    if (currentHand == null) return;

    // Set pot amount
    currentHand!.potAmount = potAmount;

    // For chopped pots, we'll store the first winner in winnerId for compatibility
    // and store additional chop data in a custom field
    currentHand!.winnerId = winnerIds.first;

    // Add chop data to the hand record
    currentHand!.isChoppedPot = true;
    currentHand!.choppedWinners = winnerIds;
    currentHand!.individualShares = individualShares;
    currentHand!.sharePerWinner = sharePerWinner;

    // Set hero position
    currentHand!.heroPosition = ourSeatNumber;

    currentHand!.markCompleted();
    completedHands.add(currentHand!);

    // Update opponent statistics for this hand
    _updateOpponentStats();

    // Save hand to Firebase and local storage
    _saveHandToFirebase(currentHand!);

    // Update session with latest hand count
    _updateSessionProgress();

    print('Hand #${currentHand!.handNumber} completed as chopped pot: $potAmount between ${winnerIds.length} players');
    currentHand = null;
  }

  // Save a completed hand to both Firebase and local storage
  Future<void> _saveHandToFirebase(HandRecord hand) async {
    if (sessionId == null) return;
    
    // Always save to local storage first
    await LocalStorageService.saveHand(
      sessionId: sessionId!,
      handNumber: hand.handNumber,
      buttonPosition: hand.buttonPosition,
      playerCount: hand.playerCount,
      actions: hand.actions.map((a) => a.toMap()).toList(),
      startTime: hand.startTime.toIso8601String(),
      endTime: hand.endTime?.toIso8601String(),
      boardCards: hand.boardCards?.toMap(),
      ourHoleCards: hand.ourHoleCards?.toMap(),
      showdownData: hand.showdownData?.toMap(),
      reachedShowdown: hand.reachedShowdown,
      potAmount: hand.potAmount,
      preflopPot: hand.preflopPot,
      flopPot: hand.flopPot,
      turnPot: hand.turnPot,
      riverPot: hand.riverPot,
      winnerId: hand.winnerId,
      heroPosition: hand.heroPosition,
      playerNames: playerNames,
      smallBlind: smallBlind,
      bigBlind: bigBlind,
      gameType: gameType.name,
      // Chopped pot fields
      isChoppedPot: hand.isChoppedPot,
      choppedWinners: hand.choppedWinners,
      individualShares: hand.individualShares,
      sharePerWinner: hand.sharePerWinner,
    );
    
    try {
      // Try to save to Firebase as well
      await FirebaseService.saveHand(
        sessionId: sessionId!,
        handNumber: hand.handNumber,
        buttonPosition: hand.buttonPosition,
        actions: hand.actions.map((a) => a.toMap()).toList(),
        playerCount: hand.playerCount,
        boardCards: hand.boardCards?.toMap(),
        ourHoleCards: hand.ourHoleCards?.toMap(),
        showdownData: hand.showdownData?.toMap(),
        reachedShowdown: hand.reachedShowdown,
        potAmount: hand.potAmount,
        preflopPot: hand.preflopPot,
        flopPot: hand.flopPot,
        turnPot: hand.turnPot,
        riverPot: hand.riverPot,
        winnerId: hand.winnerId,
        heroPosition: hand.heroPosition,
        playerNames: playerNames,
        smallBlind: smallBlind,
        bigBlind: bigBlind,
        gameType: gameType.name,
        // Chopped pot fields
        isChoppedPot: hand.isChoppedPot,
        choppedWinners: hand.choppedWinners,
        individualShares: hand.individualShares,
        sharePerWinner: hand.sharePerWinner,
      );
      
      hand.markSaved();
      print('Hand #${hand.handNumber} saved to both Firebase and local storage');
    } catch (e) {
      print('Failed to save hand to Firebase: $e');
      print('Hand #${hand.handNumber} saved to local storage only');
      // Mark as saved since we have it locally
      hand.markSaved();
    }
  }

  // Update session with current progress (hand count, etc.)
  Future<void> _updateSessionProgress() async {
    if (sessionId == null) return;
    
    try {
      // Update Firebase session
      await FirebaseService.updateSession(
        sessionId: sessionId!,
        totalHands: completedHands.length,
      );
    } catch (e) {
      print('Failed to update session in Firebase: $e');
    }
    
    // Always update local storage
    await LocalStorageService.updateSession(
      sessionId: sessionId!,
      totalHands: completedHands.length,
    );
  }

  // Update opponent statistics for completed hand
  Future<void> _updateOpponentStats() async {
    if (currentHand == null) return;
    
    print('🎯 Starting opponent stats update for completed hand #${currentHand?.handNumber}');
    print('🎯 Active seats: $activeSeats');
    print('🎯 Player names: $playerNames');
    print('🎯 Our seat: $ourSeatNumber');
    
    try {
      // Get all player names from active seats who are not the hero
      for (final seatNumber in activeSeats) {
        if (seatNumber != ourSeatNumber) {
          final playerName = playerNames[seatNumber];
          if (playerName != null && 
              playerName.isNotEmpty && 
              !playerName.toLowerCase().contains('player')) {
            
            try {
              // Find opponent by name first
              final opponent = await OpponentService.findOpponentByName(playerName);
              if (opponent != null) {
                // Update stats using opponent ID
                await OpponentService.updateOpponentStats(
                  opponent.id,
                  additionalHands: 1,
                );
                print('✅ Updated hand count for opponent: $playerName (now has ${opponent.handsPlayed + 1} hands)');
              } else {
                print('Opponent not found: $playerName');
              }
            } catch (e) {
              print('Failed to update stats for opponent $playerName: $e');
            }
          }
        }
      }
    } catch (e) {
      print('Error updating opponent stats: $e');
    }
  }

  // End the session
  Future<void> endSession() async {
    // Complete current hand if active
    if (currentHand != null && currentHand!.state == HandState.inProgress) {
      completeCurrentHand();
    }

    sessionEndTime = DateTime.now();
    sessionState = SessionState.ended;
    
    // Always update local storage
    if (sessionId != null) {
      await LocalStorageService.endSession(sessionId!, sessionEndTime!.toIso8601String());
    }
    
    // End session in Firebase
    if (sessionId != null && !sessionId!.startsWith('offline_')) {
      try {
        await FirebaseService.endSession(sessionId!);
        print('Session ended in both Firebase and local storage');
      } catch (e) {
        print('Failed to end session in Firebase: $e');
        print('Session ended in local storage only');
      }
    } else {
      print('Session ended in local storage');
    }

    print('Session ended. Total hands: ${completedHands.length}');
  }

  // Retry failed saves
  Future<void> retrySaving() async {
    if (sessionId == null || sessionId!.startsWith('offline_')) return;

    final failedHands = completedHands.where((h) => h.state != HandState.saved).toList();
    
    for (var hand in failedHands) {
      try {
        await _saveHandToFirebase(hand);
      } catch (e) {
        print('Retry failed for hand #${hand.handNumber}: $e');
      }
    }
  }

  // Get session statistics
  Map<String, dynamic> getSessionStats() {
    int totalActions = 0;
    Map<String, int> actionCounts = {};
    Map<int, int> playerActionCounts = {};

    for (var hand in completedHands) {
      for (var action in hand.actions) {
        totalActions++;
        actionCounts[action.action.name] = (actionCounts[action.action.name] ?? 0) + 1;
        playerActionCounts[action.player] = (playerActionCounts[action.player] ?? 0) + 1;
      }
    }

    return {
      'sessionId': sessionId,
      'totalHands': completedHands.length,
      'totalActions': totalActions,
      'actionBreakdown': actionCounts,
      'playerActivityBreakdown': playerActionCounts,
      'sessionDuration': sessionEndTime != null && sessionStartTime != null
          ? sessionEndTime!.difference(sessionStartTime!).inMinutes
          : null,
      'averageHandTime': completedHands.isNotEmpty
          ? completedHands
              .where((h) => h.endTime != null)
              .map((h) => h.endTime!.difference(h.startTime).inSeconds)
              .fold<int>(0, (a, b) => a + b) / completedHands.length
          : null,
    };
  }

  // Check if we have unsaved data
  bool hasUnsavedData() {
    return completedHands.any((h) => h.state != HandState.saved) ||
           (currentHand != null && currentHand!.state == HandState.inProgress);
  }

  // Get our position relative to button for a given hand
  String? getOurPosition(int handButtonPosition) {
    if (ourSeatNumber == null) return null;
    
    // Use the PokerPositions utility for consistent position naming
    return PokerPositions.getPositionName(ourSeatNumber!, handButtonPosition, playerCount);
  }

  // Check if we played in a hand (had any actions)
  bool didWePlayHand(HandRecord hand) {
    if (ourSeatNumber == null) return false;
    return hand.actions.any((action) => action.player == ourSeatNumber!);
  }

  // Check if we voluntarily put money in pot preflop (VPIP)
  bool didWeVPIP(HandRecord hand) {
    if (ourSeatNumber == null) return false;
    
    final ourPreflopActions = hand.actions.where((action) => 
      action.player == ourSeatNumber! && 
      action.street == BettingRound.preflop
    ).toList();
    
    // VPIP = voluntarily put money in pot (not including big blind)
    return ourPreflopActions.any((action) => 
      action.action == PlayerAction.bet || 
      action.action == PlayerAction.raise || 
      action.action == PlayerAction.call
    );
  }

  // Check if we raised preflop (PFR)
  bool didWePFR(HandRecord hand) {
    if (ourSeatNumber == null) return false;
    
    final ourPreflopActions = hand.actions.where((action) => 
      action.player == ourSeatNumber! && 
      action.street == BettingRound.preflop
    ).toList();
    
    return ourPreflopActions.any((action) => 
      action.action == PlayerAction.bet || 
      action.action == PlayerAction.raise
    );
  }

  // Player management methods
  void initializeDefaultPlayers() {
    activeSeats.clear();
    playerNames.clear();
    for (int i = 1; i <= playerCount; i++) {
      activeSeats.add(i);
      playerNames[i] = PokerPositions.getPositionName(i, buttonPosition, playerCount);
    }
  }

  void setPlayerName(int seatNumber, String name) {
    if (seatNumber >= 1 && seatNumber <= playerCount) {
      playerNames[seatNumber] = name.trim().isEmpty ? 
        PokerPositions.getPositionName(seatNumber, buttonPosition, playerCount) : name;
      activeSeats.add(seatNumber);
    }
  }

  void removePlayer(int seatNumber) {
    activeSeats.remove(seatNumber);
    // Keep the name in case they rejoin
  }

  void addPlayer(int seatNumber, String name) {
    if (seatNumber >= 1 && seatNumber <= playerCount) {
      activeSeats.add(seatNumber);
      playerNames[seatNumber] = name.trim().isEmpty ? 
        PokerPositions.getPositionName(seatNumber, buttonPosition, playerCount) : name;
    }
  }

  String getPlayerName(int seatNumber) {
    return playerNames[seatNumber] ?? 
      PokerPositions.getPositionName(seatNumber, buttonPosition, playerCount);
  }

  /// Get player name with current position for display purposes
  String getPlayerNameWithPosition(int seatNumber) {
    final playerName = playerNames[seatNumber];
    final currentPosition = PokerPositions.getPositionName(seatNumber, buttonPosition, playerCount);
    
    // If no custom name assigned, just return the position
    if (playerName == null || playerName == currentPosition || PokerPositions.isPositionName(playerName)) {
      return currentPosition;
    }
    
    // If custom name exists, show it with current position in brackets
    return '$playerName ($currentPosition)';
  }

  bool isPlayerActive(int seatNumber) {
    return activeSeats.contains(seatNumber);
  }

  List<int> getActiveSeats() {
    return activeSeats.toList()..sort();
  }
}