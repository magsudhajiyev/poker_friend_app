import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/poker_game_state.dart';
import '../models/game_types.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
import '../services/opponent_service.dart';
import '../services/opponent_stats_service.dart';
import '../services/user_stats_service.dart';
import '../services/logger_service.dart';
import '../utils/poker_positions.dart';
import '../onboarding/onboarding_state.dart';

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
  final String? playerName; // Display name only (for UI)
  final String? playerId; // Unique identifier: userId for current user, opponentId for opponents
  final bool isCurrentUser; // True if this is the logged-in user
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
    this.playerId,
    this.isCurrentUser = false,
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
      'playerName': playerName, // Keep for display/backward compatibility
      'playerId': playerId, // New: unique identifier
      'isCurrentUser': isCurrentUser, // New: flag for current user
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
      playerId: map['playerId'], // New field
      isCurrentUser: map['isCurrentUser'] ?? false, // New field
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
  String? heroPositionName; // Position name (UTG, BTN, etc.) calculated once at hand start
  int? heroSeatNumber; // Hero's seat number for player comparison

  // Chopped pot fields
  bool isChoppedPot = false;
  List<int>? choppedWinners;
  Map<int, double>? individualShares;
  double? sharePerWinner;

  // Table tracking (cash games)
  int? tableNumber;

  // Hand annotations (for review/tagging)
  bool isStarred = false;
  List<String> tags = [];
  String? notes;

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
    this.heroPositionName,
    this.heroSeatNumber,
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
      'heroPositionName': heroPositionName,
      'heroSeatNumber': heroSeatNumber,
      'isChoppedPot': isChoppedPot,
      'choppedWinners': choppedWinners,
      'individualShares': individualShares?.map((key, value) => MapEntry(key.toString(), value)),
      'sharePerWinner': sharePerWinner,
      // Table tracking
      if (tableNumber != null) 'tableNumber': tableNumber,
      // Hand annotations
      'isStarred': isStarred,
      'tags': tags,
      'notes': notes,
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
      heroPositionName: map['heroPositionName'] as String?,
      heroSeatNumber: map['heroSeatNumber'] as int?,
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

    // Set table number
    hand.tableNumber = map['tableNumber'] as int?;

    // Set annotation fields
    hand.isStarred = map['isStarred'] ?? false;
    hand.tags = List<String>.from(map['tags'] ?? []);
    hand.notes = map['notes'];

    return hand;
  }
}

class RebuyRecord {
  final DateTime timestamp;
  final double amount; // Rebuy amount
  final double stack; // Stack size after rebuy (for MTT)
  final int handNumber; // Hand number when rebuy occurred

  RebuyRecord({
    required this.timestamp,
    required this.amount,
    required this.stack,
    required this.handNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch,
      'amount': amount,
      'stack': stack,
      'handNumber': handNumber,
    };
  }

  factory RebuyRecord.fromMap(Map<String, dynamic> map) {
    return RebuyRecord(
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      amount: map['amount']?.toDouble() ?? 0.0,
      stack: map['stack']?.toDouble() ?? 0.0,
      handNumber: map['handNumber'] ?? 0,
    );
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
  String? sessionName; // User-provided session name
  bool isLive; // True for dealer/live sessions
  int buttonPosition = 1; // Current button position
  DateTime? sessionStartTime;
  DateTime? sessionEndTime;
  
  // Player management
  Map<int, String> playerNames = {}; // seat number -> player name
  Set<int> activeSeats = {}; // seats that have players
  Map<int, double> playerStacks = {}; // seat number -> stack size
  Map<int, String> playerIds = {}; // seat number -> Firebase userId (for dealer mode)
  String? dealerSessionId; // Links to dealer_sessions collection for live sessions
  String? eventId; // Links to club events for tournament session grouping
  int? actualSBSeat; // Track who actually posted SB (may differ from calculated)
  int? actualBBSeat; // Track who actually posted BB (may differ from calculated)

  // Opponent session tracking
  Set<String> opponentsSeenThisSession = {}; // Track opponents for session count

  // Rebuy tracking
  List<RebuyRecord> rebuys = []; // Track all rebuys during session
  double totalBuyIn = 0.0; // Total amount invested including rebuys
  double? initialStartingStack; // Initial chip count (for MTT) or buy-in amount (for cash)

  // Stack history tracking for analytics
  List<Map<String, dynamic>> stackHistory = [];

  // Biggest pot tracking
  double biggestPot = 0.0;
  int biggestPotBB = 0; // BB level when biggest pot occurred
  // Best/worst hand tracking — uses pot-to-stack ratio for meaningful comparison
  double _bestHandRatio = 0.0;  // potWon / heroPreHandStack
  String? biggestPotWonCards; // e.g. "A♠ K♥"
  double _worstHandRatio = 0.0; // potLost / heroPreHandStack
  String? biggestPotLostCards; // e.g. "Q♦ J♣"

  // Table change tracking (cash games)
  int currentTableNumber = 1;

  PokerSessionManager({
    required this.smallBlind,
    required this.bigBlind,
    required this.playerCount,
    this.ourSeatNumber,
    this.gameType = GameType.cash,
    this.sessionName,
    this.isLive = false,  // True for dealer/live sessions
    String? existingSessionId,
    double? initialBuyIn,
    double? startingStack,
  }) {
    // If we have an existing session ID, use it
    if (existingSessionId != null) {
      sessionId = existingSessionId;
    }

    // Initialize total buy-in with initial buy-in amount
    totalBuyIn = initialBuyIn ?? 0.0;

    // Store initial starting stack (chips for MTT, same as buy-in for cash)
    initialStartingStack = startingStack;
  }

  // Start a new session
  Future<void> startSession({double? initialStack}) async {
    sessionStartTime = DateTime.now();

    // Clear opponent tracking for new session
    opponentsSeenThisSession.clear();

    // If we already have a session ID (from individual session), don't create a new one
    if (sessionId == null) {
      sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';

      try {
        // Try Firebase first
        final firebaseId = await FirebaseService.createSession(
          smallBlind: smallBlind,
          bigBlind: bigBlind,
          playerCount: playerCount,
          ourSeatNumber: ourSeatNumber,
          gameType: gameType,
          sessionName: sessionName,
          startingStack: initialStack,
          totalBuyIn: totalBuyIn, // Pass total buy-in (money invested)
          isLive: isLive, // True for dealer/live sessions
          dealerSessionId: dealerSessionId,
          eventId: eventId,
        );
        sessionId = firebaseId;
      } catch (e) {
        await LoggerService.error('Firebase session creation failed, using local fallback', e, StackTrace.current);
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
        buyInAmount: initialStack,
      );
    } else {
      // We already have an existing session (individual session case)
    }

    // Initialize stack history with initial stack
    // Always add initial entry to ensure stack tracking works
    final startingStack = initialStack ?? totalBuyIn ?? 100.0;
    _addStackHistoryEntry(startingStack, 'initial', 0.0, 0);

    sessionState = SessionState.active;
  }

  // Start a new hand
  void startHand(int handNumber, int buttonPosition, {int? sbSeat, int? bbSeat}) {
    // Only complete previous hand if it has actions (not empty)
    if (currentHand != null && currentHand!.state == HandState.inProgress) {
      if (currentHand!.actions.isNotEmpty) {
        completeCurrentHand();
      } else {
        // Discard empty hand without saving
        currentHand = null;
      }
    }

    // Update current button position and blind positions
    this.buttonPosition = buttonPosition;
    this.actualSBSeat = sbSeat;
    this.actualBBSeat = bbSeat;

    currentHand = HandRecord(
      handNumber: handNumber,
      buttonPosition: buttonPosition,
      playerCount: playerCount,
      startTime: DateTime.now(),
    );
    currentHand!.state = HandState.inProgress;
    currentHand!.tableNumber = currentTableNumber;

    // CRITICAL: Explicitly ensure board cards are null for new hand
    currentHand!.boardCards = null;
    currentHand!.ourHoleCards = null;

    LoggerService.info('Hand #$handNumber started - board cards and hole cards cleared');

    // CRITICAL: Calculate and store hero position ONCE at hand start
    if (ourSeatNumber != null) {
      final heroPos = PokerPositions.getPositionNameForActivePlayers(
        ourSeatNumber!,
        buttonPosition,
        activeSeats.toList(),
      );
      currentHand!.heroPositionName = heroPos;
      currentHand!.heroSeatNumber = ourSeatNumber;

      // Log position calculation for debugging
      LoggerService.logPositionCalculation({
        'handNumber': handNumber,
        'heroSeat': ourSeatNumber,
        'buttonPosition': buttonPosition,
        'activeSeats': activeSeats.toList().toString(),
        'playerCount': playerCount,
        'calculatedPosition': heroPos,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } else {
      LoggerService.warning('Hand #$handNumber started but ourSeatNumber is null - cannot calculate position');
    }

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
      return;
    }

    // Get player name and position using consistent logic
    final playerName = getPlayerName(player);
    final playerPosition = PokerPositions.getPositionNameForActivePlayers(
      player,
      buttonPosition,
      activeSeats.toList()
    );

    // Determine if this is the current user and get their ID
    final isCurrentUser = (ourSeatNumber != null && player == ourSeatNumber);
    String? playerId;

    if (isCurrentUser) {
      // This is the current user - use their Firebase user ID
      final currentUser = FirebaseAuth.instance.currentUser;
      playerId = currentUser?.uid;
    } else {
      // This is an opponent - use their name as ID for now (will be improved with opponent ID system)
      playerId = playerName;
    }

    final actionRecord = ActionRecord(
      player: player,
      action: action,
      street: street,
      timestamp: DateTime.now(),
      buttonPosition: buttonPosition,
      playerName: playerName,
      playerId: playerId,
      isCurrentUser: isCurrentUser,
      playerPosition: playerPosition,
      playerStack: playerStack,
      amount: amount,
    );

    currentHand!.addAction(actionRecord);

    // DISABLED: Don't save actions to Firebase immediately
    // Actions are stored in memory and only saved when hand completes
    // This allows proper undo functionality without database complications
    //
    // // Optionally save action to Firebase immediately for real-time tracking
    // if (sessionId != null && !sessionId!.startsWith('offline_')) {
    //   FirebaseService.saveAction(
    //     sessionId: sessionId!,
    //     handNumber: currentHand!.handNumber,
    //     player: player,
    //     action: action.name,
    //     street: street.name,
    //     buttonPosition: buttonPosition,
    //   ).catchError((e) {
    //     debugPrint('Failed to save action real-time: $e');
    //   });
    // }

  }

  // Save pot amount at the end of each street
  void savePotForStreet(BettingRound street, double potAmount) {
    if (currentHand == null) return;

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
  }

  /// Apply street-by-street pot data from game state to current hand.
  /// Called automatically by completeCurrentHand/completeCurrentHandWithChop.
  /// Does NOT touch currentHand.potAmount (that's set by the caller).
  void _applyStreetPots(PokerGameState gameState) {
    if (currentHand == null) return;
    final pots = gameState.streetPots;
    currentHand!.preflopPot = pots[BettingRound.preflop] ?? 0;
    currentHand!.flopPot = pots[BettingRound.flop] ?? 0;
    currentHand!.turnPot = pots[BettingRound.turn] ?? 0;
    currentHand!.riverPot = pots[BettingRound.river] ?? 0;
    // If hand completes ON a street that wasn't snapshotted yet (river, or early fold),
    // use currentPot for that street (set the field directly, don't call savePotForStreet
    // which would overwrite potAmount)
    if (!pots.containsKey(gameState.currentRound)) {
      switch (gameState.currentRound) {
        case BettingRound.preflop:
          currentHand!.preflopPot = gameState.currentPot;
          break;
        case BettingRound.flop:
          currentHand!.flopPot = gameState.currentPot;
          break;
        case BettingRound.turn:
          currentHand!.turnPot = gameState.currentPot;
          break;
        case BettingRound.river:
          currentHand!.riverPot = gameState.currentPot;
          break;
      }
    }
  }

  void _trackBiggestPotWonLost(double? potAmount, int? winnerId) {
    if (potAmount == null || potAmount <= 0 || currentHand == null) return;
    final cards = currentHand!.ourHoleCards;
    final cardsStr = (cards != null && cards.isComplete)
        ? '${cards.card1} ${cards.card2}'
        : null;

    // Use pot relative to hero's stack for meaningful comparison.
    // Hero's pre-hand stack = last stack history entry (end of previous hand).
    final heroPreHandStack = stackHistory.isNotEmpty
        ? (stackHistory.last['stackSize'] as num).toDouble()
        : totalBuyIn;
    final ratio = heroPreHandStack > 0 ? potAmount / heroPreHandStack : 0.0;

    final heroWon = ourSeatNumber != null && winnerId == ourSeatNumber;
    if (heroWon && ratio > _bestHandRatio) {
      _bestHandRatio = ratio;
      // Show cards if available, otherwise show hand number
      biggestPotWonCards = cardsStr ?? 'Hand #${currentHand!.handNumber}';
    } else if (!heroWon && ratio > _worstHandRatio) {
      _worstHandRatio = ratio;
      biggestPotLostCards = cardsStr ?? 'Hand #${currentHand!.handNumber}';
    }
  }

  // Complete the current hand
  void completeCurrentHand({double? potAmount, int? winnerId, double? currentStack, PokerGameState? gameState}) {
    if (currentHand == null) return;

    // Set pot amount and winner if provided
    if (potAmount != null) {
      currentHand!.potAmount = potAmount;
      // Track biggest pot with BB level for display
      if (potAmount > biggestPot) {
        biggestPot = potAmount;
        biggestPotBB = bigBlind;
      }
    }
    if (winnerId != null) {
      currentHand!.winnerId = winnerId;
    }

    // Track biggest pot won/lost with hole cards
    _trackBiggestPotWonLost(potAmount, winnerId);

    // Apply street-by-street pot data from game state (unified for manual + dealer)
    if (gameState != null) {
      _applyStreetPots(gameState);
    }

    // Note: heroPositionName is already set at hand start, don't overwrite it

    // Track stack history if current stack is provided
    if (currentStack != null) {
      if (stackHistory.isEmpty) {
        _addStackHistoryEntry(currentStack, 'initial', 0.0, 0);
      } else {
        final previousStack = stackHistory.last['stackSize'] as double;
        final stackChange = currentStack - previousStack;
        final changeType = stackChange >= 0 ? 'win' : 'loss';
        _addStackHistoryEntry(currentStack, changeType, stackChange.abs(), currentHand!.handNumber);
      }
    }

    currentHand!.markCompleted();
    completedHands.add(currentHand!);


    // Update opponent statistics for this hand
    _updateOpponentStats();

    // Save hand to Firebase and local storage
    _saveHandToFirebase(currentHand!);

    // Update session with latest hand count
    _updateSessionProgress();

    currentHand = null;
  }

  void completeCurrentHandWithChop({
    required double potAmount,
    required List<int> winnerIds,
    Map<int, double>? individualShares,
    double? sharePerWinner,
    double? currentStack,
    PokerGameState? gameState,
  }) {
    if (currentHand == null) return;

    // Set pot amount
    currentHand!.potAmount = potAmount;

    // Track biggest pot with BB level for display
    if (potAmount > biggestPot) {
      biggestPot = potAmount;
      biggestPotBB = bigBlind;
    }

    // For chopped pots, we'll store the first winner in winnerId for compatibility
    // and store additional chop data in a custom field
    currentHand!.winnerId = winnerIds.first;

    // Track biggest pot won/lost with hole cards (hero wins if in winnerIds)
    final heroWon = ourSeatNumber != null && winnerIds.contains(ourSeatNumber);
    _trackBiggestPotWonLost(potAmount, heroWon ? ourSeatNumber : null);

    // Add chop data to the hand record
    currentHand!.isChoppedPot = true;
    currentHand!.choppedWinners = winnerIds;
    currentHand!.individualShares = individualShares;
    currentHand!.sharePerWinner = sharePerWinner;

    // Apply street-by-street pot data from game state (unified for manual + dealer)
    if (gameState != null) {
      _applyStreetPots(gameState);
    }

    // Note: heroPositionName is already set at hand start, don't overwrite it

    // Track stack history if current stack is provided
    if (currentStack != null) {
      if (stackHistory.isEmpty) {
        // If no initial entry exists, add it first with the current stack as starting point
        _addStackHistoryEntry(currentStack, 'initial', 0.0, 0);
      } else {
        final previousStack = stackHistory.last['stackSize'] as double;
        final stackChange = currentStack - previousStack;
        final changeType = stackChange >= 0 ? 'win' : 'loss';
        _addStackHistoryEntry(currentStack, changeType, stackChange.abs(), currentHand!.handNumber);
      }
    }

    currentHand!.markCompleted();
    completedHands.add(currentHand!);

    // Update opponent statistics for this hand
    _updateOpponentStats();

    // Save hand to Firebase and local storage
    _saveHandToFirebase(currentHand!);

    // Update session with latest hand count
    _updateSessionProgress();

    currentHand = null;
  }

  // Save a completed hand to both Firebase and local storage
  Future<void> _saveHandToFirebase(HandRecord hand) async {
    if (sessionId == null) return;
    // Tour hands are never persisted — they don't affect stats or hand counts
    if (OnboardingState.isGuidedHandActive) return;

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
      // heroPositionName: hand.heroPositionName,  // TODO: Add to local_storage_service.dart
      // heroSeatNumber: hand.heroSeatNumber,  // TODO: Add to local_storage_service.dart
      playerNames: playerNames,
      smallBlind: smallBlind,
      bigBlind: bigBlind,
      gameType: gameType.name,
      // Chopped pot fields
      isChoppedPot: hand.isChoppedPot,
      choppedWinners: hand.choppedWinners,
      individualShares: hand.individualShares,
      sharePerWinner: hand.sharePerWinner,
      // Hand annotations
      isStarred: hand.isStarred,
      tags: hand.tags,
      notes: hand.notes,
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
        heroPositionName: hand.heroPositionName,
        heroSeatNumber: ourSeatNumber,
        playerNames: playerNames,
        smallBlind: smallBlind,
        bigBlind: bigBlind,
        gameType: gameType.name,
        // Chopped pot fields
        isChoppedPot: hand.isChoppedPot,
        choppedWinners: hand.choppedWinners,
        individualShares: hand.individualShares,
        sharePerWinner: hand.sharePerWinner,
        // Hand annotations
        isStarred: hand.isStarred,
        tags: hand.tags,
        notes: hand.notes,
        // Dealer mode: pass playerIds for stats tracking
        playerIds: playerIds.isNotEmpty ? playerIds : null,
      );

      hand.markSaved();

      // Update optimized stats for all participants
      await _updateOptimizedStats(hand);
    } catch (e) {
      await LoggerService.error('Firebase hand save failed, using local fallback', e, StackTrace.current);
      // Mark as saved since we have it locally
      hand.markSaved();

      // Still update optimized stats even if Firebase failed
      await _updateOptimizedStats(hand);
    }
  }

  /// Update optimized statistics for all participants in the hand
  Future<void> _updateOptimizedStats(HandRecord hand) async {
    try {
      // Get all player names from this hand
      Set<String> playersInHand = {};

      // Collect all player names who took actions
      for (final action in hand.actions) {
        if (action.playerName != null &&
            action.playerName!.isNotEmpty &&
            !action.playerName!.toLowerCase().contains('player')) {
          playersInHand.add(action.playerName!);
        }
      }

      // Process each player's actions in this hand
      for (final playerName in playersInHand) {

        // Calculate stats for this specific hand
        int vpipDelta = 0;
        int pfrDelta = 0;
        int aggressionDelta = 0;
        int passiveDelta = 0;
        int foldDelta = 0;
        int checkDelta = 0;
        int callDelta = 0;
        int betDelta = 0;
        int raiseDelta = 0;

        bool vpipThisHand = false;
        bool pfrThisHand = false;
        bool playedPastPreflop = false; // Track if player saw flop/turn/river
        String currentStreet = 'preflop';

        // Process this player's actions in this hand
        for (final action in hand.actions) {
          if (action.playerName == playerName) {
            // Track street changes
            if (action.street != null) {
              currentStreet = action.street!.name.toLowerCase();
              // If player has action on flop/turn/river, they played past preflop
              if (currentStreet != 'preflop') {
                playedPastPreflop = true;
              }
            }

            final actionType = action.action.name.toLowerCase();

            // Count action types
            switch (actionType) {
              case 'fold':
                foldDelta++;
                break;
              case 'call':
                callDelta++;
                passiveDelta++;
                if (currentStreet == 'preflop' && !vpipThisHand) {
                  vpipThisHand = true;
                }
                break;
              case 'bet':
                betDelta++;
                aggressionDelta++;
                if (currentStreet == 'preflop') {
                  if (!vpipThisHand) vpipThisHand = true;
                  if (!pfrThisHand) pfrThisHand = true;
                }
                break;
              case 'raise':
                raiseDelta++;
                aggressionDelta++;
                if (currentStreet == 'preflop') {
                  if (!vpipThisHand) vpipThisHand = true;
                  if (!pfrThisHand) pfrThisHand = true;
                }
                break;
              case 'check':
                checkDelta++;
                passiveDelta++;
                break;
            }
          }
        }

        if (vpipThisHand) {
          vpipDelta = 1;
        }
        if (pfrThisHand) {
          pfrDelta = 1;
        }

        // Update opponent stats (incremental)
        if (playerName.toLowerCase() != 'hero' && playerName.toLowerCase() != 'you') {
          // Check if this is first time seeing this opponent in this session
          final isFirstTimeSeen = !opponentsSeenThisSession.contains(playerName);
          if (isFirstTimeSeen) {
            opponentsSeenThisSession.add(playerName);
          }

          await OpponentStatsService.updateStatsIncremental(
            opponentId: playerName,
            handsDelta: 1,
            sessionsDelta: isFirstTimeSeen ? 1 : 0, // Increment session only first time
            vpipDelta: vpipDelta,
            pfrDelta: pfrDelta,
            aggressionDelta: aggressionDelta,
            passiveDelta: passiveDelta,
            foldDelta: foldDelta,
            checkDelta: checkDelta,
            callDelta: callDelta,
            betDelta: betDelta,
            raiseDelta: raiseDelta,
          );
        } else {
          // DO NOT update user stats here - already done in FirebaseService.saveHand()
          // via _updateUserStatsFromHand(). This block was causing DOUBLE-COUNTING
          // of stats (stats were being incremented twice per hand).
          // See: https://github.com/anthropics/claude-code/issues/stats-double-counting
          //
          // The correct stats update flow is:
          // 1. PokerSessionManager._saveHandToFirebase() calls FirebaseService.saveHand()
          // 2. FirebaseService.saveHand() calls _updateUserStatsFromHand() - INCREMENT #1 (correct)
          // 3. This _updateOptimizedStats() method should ONLY update opponent stats
          //
          // Previously this block also called UserStatsService.updateStatsAtomic() - INCREMENT #2 (DUPLICATE!)
          // which caused all stats to be ~2x the actual values.
        }
      }
    } catch (e) {
      await LoggerService.error('Error updating optimized stats', e, StackTrace.current);
    }
  }

  // Add stack history entry
  void _addStackHistoryEntry(double stackSize, String changeType, double changeAmount, int handNumber) {
    final entry = {
      'timestamp': DateTime.now().toIso8601String(),
      'stackSize': stackSize,
      'changeType': changeType,
      'changeAmount': changeAmount,
      'handNumber': handNumber,
    };
    stackHistory.add(entry);
  }

  // Add final stack entry before ending session
  void addFinalStackEntry(double finalStack) {
    if (stackHistory.isEmpty) {
      _addStackHistoryEntry(finalStack, 'final', 0.0, completedHands.length);
    } else {
      final lastStack = stackHistory.last['stackSize'] as double;
      if (finalStack != lastStack) {
        final change = finalStack - lastStack;
        _addStackHistoryEntry(finalStack, 'final', change.abs(), completedHands.length);
      }
    }
  }

  // Update session with current progress (hand count, etc.)
  Future<void> _updateSessionProgress() async {
    if (sessionId == null) return;

    try {
      // Update Firebase session with stack history, totalBuyIn, and stats
      await FirebaseService.updateSession(
        sessionId: sessionId!,
        handsLogged: completedHands.length,
        biggestPot: biggestPot,
        stackHistory: stackHistory,
        totalBuyIn: totalBuyIn,
      );
    } catch (e) {
      await LoggerService.error('Error updating session progress in Firebase', e, StackTrace.current);
    }

    // Always update local storage with stack history, totalBuyIn, and stats
    await LocalStorageService.updateSession(
      sessionId: sessionId!,
      handsLogged: completedHands.length,
      biggestPot: biggestPot,
      stackHistory: stackHistory,
      totalBuyIn: totalBuyIn,
    );
  }

  // Update opponent lastSeenAt timestamp for completed hand
  // NOTE: Statistical updates happen via _updateOptimizedStats() which updates OpponentStats
  Future<void> _updateOpponentStats() async {
    if (currentHand == null) return;

    try {
      // Get all player names from active seats who are not the hero
      for (final seatNumber in activeSeats) {
        if (seatNumber != ourSeatNumber) {
          final playerName = playerNames[seatNumber];
          if (playerName != null &&
              playerName.isNotEmpty &&
              !playerName.toLowerCase().contains('player')) {

            try {
              // Find opponent by name and update lastSeenAt
              final opponent = await OpponentService.findOpponentByName(playerName);
              if (opponent != null) {
                await OpponentService.updateLastSeen(opponent.id);
              }
            } catch (e) {
              // Continue with other opponents
            }
          }
        }
      }
    } catch (e) {
      await LoggerService.error('Error updating opponent stats', e, StackTrace.current);
    }
  }

  // End the session
  Future<void> endSession() async {
    // Complete current hand if active and has actions, otherwise discard empty hand
    if (currentHand != null && currentHand!.state == HandState.inProgress) {
      if (currentHand!.actions.isNotEmpty) {
        completeCurrentHand();
      } else {
        // Discard empty hand without saving
        currentHand = null;
      }
    }

    sessionEndTime = DateTime.now();
    sessionState = SessionState.ended;

    // Save final stack history before ending
    await _updateSessionProgress();

    // Always update local storage
    if (sessionId != null) {
      await LocalStorageService.endSession(sessionId!, sessionEndTime!.toIso8601String());
    }
    
    // End session in Firebase
    if (sessionId != null && !sessionId!.startsWith('offline_')) {
      try {
        await FirebaseService.endSession(sessionId!);
      } catch (e) {
        await LoggerService.error('Error ending Firebase session', e, StackTrace.current);
      }
    } else {
    }

  }

  // Add a rebuy to the session
  void addRebuy({
    required double amount,
    required double stack,
  }) {
    final rebuy = RebuyRecord(
      timestamp: DateTime.now(),
      amount: amount,
      stack: stack,
      handNumber: completedHands.length + 1, // Next hand number
    );

    rebuys.add(rebuy);
    totalBuyIn += amount;

    // Add stack history entry for rebuy
    _addStackHistoryEntry(stack, 'rebuy', amount, completedHands.length + 1);


    // Update session immediately with new totalBuyIn
    _updateSessionProgress();
  }

  // Get total rebuy amount
  double getTotalRebuyAmount() {
    return rebuys.fold(0.0, (sum, rebuy) => sum + rebuy.amount);
  }

  // Get rebuy count
  int getRebuyCount() {
    return rebuys.length;
  }

  // Retry failed saves
  Future<void> retrySaving() async {
    if (sessionId == null || sessionId!.startsWith('offline_')) return;

    final failedHands = completedHands.where((h) => h.state != HandState.saved).toList();
    
    for (var hand in failedHands) {
      try {
        await _saveHandToFirebase(hand);
      } catch (e) {
        await LoggerService.error('Retry save failed for hand #${hand.handNumber}', e, StackTrace.current);
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

    // Use the same logic as getPlayerName but with the provided button position
    final activeSeatsList = activeSeats.toList()..sort();
    final currentActivePlayerCount = activeSeatsList.length;

    // Check if we are actually posting blinds or button
    if (ourSeatNumber == actualBBSeat) {
      return 'BB';
    } else if (ourSeatNumber == actualSBSeat) {
      return 'SB';
    } else if (ourSeatNumber == handButtonPosition) {
      return 'BTN';
    } else {
      // For non-blind positions, calculate based on active players only
      int activeButtonIndex = activeSeatsList.indexOf(handButtonPosition);
      int activePlayerIndex = activeSeatsList.indexOf(ourSeatNumber!);

      if (activeButtonIndex == -1 || activePlayerIndex == -1) {
        // Fallback if something goes wrong
        final effectivePlayerCount = currentActivePlayerCount > 0 ? currentActivePlayerCount : playerCount;
        return PokerPositions.getPositionName(ourSeatNumber!, handButtonPosition, effectivePlayerCount);
      } else {
        // Calculate position relative to button among active players only
        int relativePosition = (activePlayerIndex - activeButtonIndex + currentActivePlayerCount) % currentActivePlayerCount;
        return PokerPositions.getPositionName(relativePosition + 1, 1, currentActivePlayerCount);
      }
    }
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
      playerNames[i] = 'Player $i'; // Use Player X format based on seat number
    }
  }

  void setPlayerName(int seatNumber, String name) {
    if (seatNumber >= 1 && seatNumber <= playerCount) {
      if (name.trim().isEmpty) {
        // Use default "Player #" format based on seat number
        playerNames[seatNumber] = 'Player $seatNumber';
      } else {
        playerNames[seatNumber] = name;
      }
      activeSeats.add(seatNumber);
    }
  }

  void removePlayer(int seatNumber) {
    activeSeats.remove(seatNumber);
    // Reset to initial state when seat is deactivated
    playerNames[seatNumber] = 'Player $seatNumber';
    playerStacks.remove(seatNumber);
    playerIds.remove(seatNumber);
  }

  void addPlayer(int seatNumber, String name) {
    if (seatNumber >= 1 && seatNumber <= playerCount) {
      activeSeats.add(seatNumber);
      if (name.trim().isEmpty) {
        // Use default "Player #" format based on seat number
        playerNames[seatNumber] = 'Player $seatNumber';
      } else {
        playerNames[seatNumber] = name;
      }
    }
  }

  void setPlayerStack(int seatNumber, double stack) {
    if (seatNumber >= 1 && seatNumber <= playerCount) {
      playerStacks[seatNumber] = stack;
    }
  }

  /// Atomically move the hero from their current seat to [newSeat].
  /// Deactivates the old seat (unless [keepOldSeatActive] is true, e.g. when
  /// another player is taking the old seat) and activates the new one.
  /// [gameState] is updated in sync if provided.
  void reseatHero({
    required int newSeat,
    required PokerGameState? gameState,
    String? heroName,
    double? heroStack,
    bool keepOldSeatActive = false,
  }) {
    final oldSeat = ourSeatNumber;
    if (oldSeat == newSeat) return;

    // Determine hero's current stack/name before clearing old seat
    final currentStack = heroStack ??
        (oldSeat != null ? (playerStacks[oldSeat] ?? 0.0) : 0.0);
    final currentName = heroName ??
        (oldSeat != null ? (playerNames[oldSeat] ?? 'You') : 'You');

    // --- Deactivate old seat ---
    if (oldSeat != null && !keepOldSeatActive) {
      activeSeats.remove(oldSeat);
      playerNames.remove(oldSeat);
      playerStacks.remove(oldSeat);
      gameState?.setPlayerActive(oldSeat, false);
    }

    // --- Activate new seat ---
    ourSeatNumber = newSeat;
    activeSeats.add(newSeat);
    playerNames[newSeat] = currentName;
    playerStacks[newSeat] = currentStack;
    if (gameState != null) {
      gameState.setPlayerActive(newSeat, true);
      gameState.setPlayerStack(newSeat, currentStack);
    }
  }

  /// Set playerIds map for dealer-assisted mode (seat → Firebase userId)
  void setPlayerIds(Map<int, String> ids) {
    playerIds = Map.from(ids);
  }

  double? getPlayerStack(int seatNumber) {
    return playerStacks[seatNumber];
  }

  String getPlayerName(int seatNumber) {
    if (playerNames[seatNumber] != null && playerNames[seatNumber]!.isNotEmpty) {
      return playerNames[seatNumber]!;
    }

    // Default to "Player #" format based on seat number
    return 'Player $seatNumber';
  }

  /// Get player name with current position for display purposes
  String getPlayerNameWithPosition(int seatNumber) {
    final playerName = playerNames[seatNumber];

    // Get active seats sorted
    final activeSeatsList = activeSeats.toList()..sort();
    final currentActivePlayerCount = activeSeatsList.length;

    // Check if this player is actually posting blinds or button
    String currentPosition;
    if (seatNumber == actualBBSeat) {
      currentPosition = 'BB';
    } else if (seatNumber == actualSBSeat) {
      currentPosition = 'SB';
    } else if (seatNumber == buttonPosition) {
      currentPosition = 'BTN';
    } else {
      // For non-blind positions, we need to calculate based on active players only
      // Find the player's position in the active seats relative to button
      int activeButtonIndex = activeSeatsList.indexOf(buttonPosition);
      int activePlayerIndex = activeSeatsList.indexOf(seatNumber);

      if (activeButtonIndex == -1 || activePlayerIndex == -1) {
        // Fallback if something goes wrong
        final effectivePlayerCount = currentActivePlayerCount > 0 ? currentActivePlayerCount : playerCount;
        currentPosition = PokerPositions.getPositionName(seatNumber, buttonPosition, effectivePlayerCount);
      } else {
        // Calculate position relative to button among active players only
        int relativePosition = (activePlayerIndex - activeButtonIndex + currentActivePlayerCount) % currentActivePlayerCount;

        // Create a "virtual" seat number based on position in active players
        // This ensures positions are calculated correctly for the current active player count
        currentPosition = PokerPositions.getPositionName(relativePosition + 1, 1, currentActivePlayerCount);
      }
    }

    // If no custom name assigned or name is just the position, show "Seat X (Position)"
    if (playerName == null || playerName == currentPosition || PokerPositions.isPositionName(playerName)) {
      return 'Seat $seatNumber ($currentPosition)';
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