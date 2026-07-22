import 'dart:async';

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
import '../services/range_grid_service.dart';
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
  // True when [choppedWinners] won SEPARATE side pots (not a split of one
  // pot). Lets the details view label winners accurately (B11).
  bool isSplitPot = false;

  // Table tracking (cash games)
  int? tableNumber;

  // Hand annotations (for review/tagging)
  bool isStarred = false;
  List<String> tags = [];
  String? notes;

  /// True when this hand was finished early via scouting mode (hero folded
  /// preflop, board skipped). The record is preflop-only and exists to feed
  /// opponent stats / the scouting report — it is excluded from the hero's own
  /// session summary. See PokerSessionManager scouting flow.
  bool isScouted = false;

  /// Storage identifiers, assigned AFTER the hand is saved (HL-5: needed to
  /// UPDATE the persisted record when shown cards are recorded during the
  /// settling overlay). In-memory only — the Firestore doc id IS the id.
  String? cloudHandId;
  String? localHandId;

  /// True when the hero's participation ended with a PREFLOP fold (open-fold,
  /// fold to a 3-bet, pure scout...). Such hands are saved — opponent stats,
  /// hero preflop stats, range grid all still count — but are hidden from the
  /// hero's hand history (walks and postflop folds are NOT affected).
  bool get heroFoldedPreflop {
    final hero = heroSeatNumber;
    if (hero == null) return false;
    return actions.any((a) =>
        a.player == hero &&
        a.action == PlayerAction.fold &&
        a.street == BettingRound.preflop);
  }

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
      'isSplitPot': isSplitPot,
      'choppedWinners': choppedWinners,
      'individualShares': individualShares?.map((key, value) => MapEntry(key.toString(), value)),
      'sharePerWinner': sharePerWinner,
      // Table tracking
      if (tableNumber != null) 'tableNumber': tableNumber,
      // Hand annotations
      'isStarred': isStarred,
      'isScouted': isScouted,
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
    hand.isSplitPot = map['isSplitPot'] ?? false;
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
    hand.isScouted = map['isScouted'] ?? false;
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

  /// The most recently completed hand, regardless of whether it entered
  /// [completedHands] (pure-scout hands don't). Target for post-hand
  /// shown-cards recording during the settling overlay (HL-5).
  HandRecord? lastFinishedHand;
  
  // Session settings
  double smallBlind;
  double bigBlind;
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

  // Stack history tracking for analytics. Entries may carry 'tableAvg'
  // (user-entered table-average stack) — see StackAnalytics.latestTableAverage.
  List<Map<String, dynamic>> stackHistory = [];

  // Hands the hero folded preflop and skipped via Next Hand. These have no
  // hand record, so exports/analytics need this counter to compute honest
  // VPIP/PFR denominators (hands dealt, not just hands logged).
  int skippedHands = 0;

  // True when this session was started during the first-run tour. Its hands
  // are persisted (session history must show them) but excluded from all
  // user/opponent stats and the range grid.
  bool isTutorialSession = false;

  // Biggest pot tracking
  double biggestPot = 0.0;
  double biggestPotBB = 0.0; // BB level when biggest pot occurred
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

    // Sessions started during the first-run tour are badged as tutorials and
    // excluded from stats/bankroll (replay never creates sessions). The flag
    // covers ALL hands of the tour session, not just the scripted one.
    final isTutorial =
        OnboardingState.isOnboardingActive && !OnboardingState.isReplay;
    isTutorialSession = isTutorial;

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
          isTutorial: isTutorial,
        );
        sessionId = firebaseId;
      } catch (e) {
        await LoggerService.error('Firebase session creation failed, using local fallback', e, StackTrace.current);
      }

      if (isTutorial) {
        OnboardingState.tourSessionId = sessionId;
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
        isTutorial: isTutorial,
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

  // Complete the current hand.
  //
  // [isScouted] finishes a preflop-only scouting hand (hero folded, board
  // skipped): the pot is NOT awarded and the hero's stack is unchanged. Such a
  // hand always feeds OPPONENT stats via saveHand; whether it also counts for
  // the hero (session summary + user stats) is decided by whether the hero
  // voluntarily entered the pot preflop (call/bet/raise) — a pure fold-around
  // scout is kept out of the hero's session history, while a "called then
  // folded" hand is a normal folded hand and stays in.
  void completeCurrentHand({double? potAmount, int? winnerId, double? currentStack, PokerGameState? gameState, bool isScouted = false}) {
    if (currentHand == null) return;

    currentHand!.isScouted = isScouted;

    // Whether the hero voluntarily put chips in preflop before folding.
    final heroVoluntarilyEntered = _heroVoluntarilyEnteredPot();
    // A pure scout (folded without entering) is excluded from the hero's
    // session summary + user stats. A voluntary-entry fold counts normally.
    final countForHero = !isScouted || heroVoluntarilyEntered;

    // Set pot amount and winner if provided. For scout hands the pot is not
    // awarded and must not affect the biggest-pot display.
    if (potAmount != null) {
      currentHand!.potAmount = potAmount;
      if (!isScouted && potAmount > biggestPot) {
        biggestPot = potAmount;
        biggestPotBB = bigBlind;
      }
    }
    if (winnerId != null) {
      currentHand!.winnerId = winnerId;
    }

    if (!isScouted) {
      // Track biggest pot won/lost with hole cards
      _trackBiggestPotWonLost(potAmount, winnerId);

      // Apply street-by-street pot data from game state
      if (gameState != null) {
        _applyStreetPots(gameState);
      }

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
    }

    // Note: heroPositionName is already set at hand start, don't overwrite it

    currentHand!.markCompleted();
    lastFinishedHand = currentHand;
    // Only hero-counted hands enter the in-memory session summary list —
    // and hands whose hero participation ended with a PREFLOP fold are
    // hidden from the hero's history entirely (HL-5 refinement): they are
    // still saved and still feed hero preflop stats + the range grid.
    if (countForHero && !currentHand!.heroFoldedPreflop) {
      completedHands.add(currentHand!);
    }

    // Update opponent statistics for this hand
    _updateOpponentStats();

    // Save hand to Firebase and local storage. Pure-scout hands skip hero
    // user-stats (skipHeroStats) but still update opponent stats.
    _saveHandToFirebase(currentHand!, skipHeroStats: !countForHero);

    // Update session with latest hand count
    _updateSessionProgress();

    currentHand = null;
  }

  /// True if the hero voluntarily put chips in the pot preflop (call/bet/raise)
  /// in the current hand — i.e. it's a real played hand, not a pure fold-around.
  bool _heroVoluntarilyEnteredPot() {
    final hero = ourSeatNumber;
    if (hero == null || currentHand == null) return false;
    for (final a in currentHand!.actions) {
      if (a.player == hero &&
          a.street == BettingRound.preflop &&
          (a.action == PlayerAction.call ||
              a.action == PlayerAction.bet ||
              a.action == PlayerAction.raise)) {
        return true;
      }
    }
    return false;
  }

  void completeCurrentHandWithChop({
    required double potAmount,
    required List<int> winnerIds,
    Map<int, double>? individualShares,
    double? sharePerWinner,
    double? currentStack,
    PokerGameState? gameState,
    bool isSplitPot = false,
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
    currentHand!.isSplitPot = isSplitPot;
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
    lastFinishedHand = currentHand;
    // Same history rule as completeCurrentHand: hero folded preflop while
    // the others chopped → saved, but not the hero's hand history.
    if (!currentHand!.heroFoldedPreflop) {
      completedHands.add(currentHand!);
    }

    // Update opponent statistics for this hand
    _updateOpponentStats();

    // Save hand to Firebase and local storage
    _saveHandToFirebase(currentHand!);

    // Update session with latest hand count
    _updateSessionProgress();

    currentHand = null;
  }

  // Save a completed hand to both Firebase and local storage
  Future<void> _saveHandToFirebase(HandRecord hand, {bool skipHeroStats = false}) async {
    if (sessionId == null) return;
    // Knowledge-Base replay hands are never persisted
    if (OnboardingState.isGuidedHandActive && OnboardingState.isReplay) return;
    // First-run tour hands ARE persisted (so the tour can show them in session
    // history) but must never touch user/opponent stats or the range grid.
    // Covers every hand of the tutorial session, not just the scripted one.
    final skipStats = isTutorialSession || OnboardingState.isGuidedHandActive;

    // Always save to local storage first
    final localHandId = await LocalStorageService.saveHand(
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
      isSplitPot: hand.isSplitPot,
      choppedWinners: hand.choppedWinners,
      individualShares: hand.individualShares,
      sharePerWinner: hand.sharePerWinner,
      // Hand annotations
      isStarred: hand.isStarred,
      isScouted: hand.isScouted,
      tags: hand.tags,
      notes: hand.notes,
    );

    hand.localHandId = localHandId;

    // Index for the range grid — local derived data, fire-and-forget so it
    // can never block or break the save path.
    if (localHandId != null && !skipStats) {
      unawaited(RangeGridService.indexHand(
        hand: hand,
        handId: localHandId,
        sessionId: sessionId!,
        heroSeat: ourSeatNumber,
        bigBlind: bigBlind,
        gameType: gameType.name,
      ));
    }

    try {
      // Try to save to Firebase as well
      final cloudHandId = await FirebaseService.saveHand(
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
        isSplitPot: hand.isSplitPot,
        choppedWinners: hand.choppedWinners,
        individualShares: hand.individualShares,
        sharePerWinner: hand.sharePerWinner,
        // Hand annotations
        isStarred: hand.isStarred,
        isScouted: hand.isScouted,
        tags: hand.tags,
        notes: hand.notes,
        // Dealer mode: pass playerIds for stats tracking
        playerIds: playerIds.isNotEmpty ? playerIds : null,
        skipStats: skipStats,
        skipHeroStats: skipHeroStats,
      );

      hand.cloudHandId = cloudHandId;
      hand.markSaved();

      // Update optimized stats for all participants
      if (!skipStats) await _updateOptimizedStats(hand);
    } catch (e) {
      await LoggerService.error('Firebase hand save failed, using local fallback', e, StackTrace.current);
      // Mark as saved since we have it locally
      hand.markSaved();

      // Still update optimized stats even if Firebase failed
      if (!skipStats) await _updateOptimizedStats(hand);
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

  // Get rebuy count — derived from stackHistory so it stays correct even
  // when the rebuys list hasn't been synced back from SessionDetailsScreen.
  int getRebuyCount() {
    return stackHistory.where((e) => e['changeType'] == 'rebuy').length;
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
  // ── Mid-hand seating (HL-1/HL-3) ──────────────────────────────────────
  //
  // Boundary rule: a seat change while currentHand.actions.isEmpty joins the
  // CURRENT hand (caller re-posts blinds + recalculates action order). A seat
  // change after any action is DEFERRED: it lives here (so the seat renders,
  // dimmed) and the game engine is only told at the next hand start.

  /// Seats added mid-hand, waiting to join at the next hand. The seat's
  /// name/stack already live in [playerNames]/[playerStacks]/[activeSeats];
  /// only the gameState activation is deferred.
  final Set<int> pendingSeats = <int>{};

  int? _pendingHeroSeat;
  String? _pendingHeroName;
  double? _pendingHeroStack;

  /// Hero re-seat requested mid-hand — applied at the next hand start.
  int? get pendingHeroSeat => _pendingHeroSeat;
  double? get pendingHeroStack => _pendingHeroStack;

  /// Defer a hero move to [newSeat] until the next hand (mid-hand re-seat
  /// follows the same sit-out rule as any other mid-hand seating).
  void deferHeroReseat({
    required int newSeat,
    String? heroName,
    double? heroStack,
  }) {
    _pendingHeroSeat = newSeat;
    _pendingHeroName = heroName;
    _pendingHeroStack = heroStack;
  }

  /// HL-2: throw away an in-progress hand (mid-hand table change). The
  /// discarded hand never happened: no record, no stats, and — critically —
  /// nulling it BEFORE the next startHand() prevents the auto-complete path
  /// (startHand → completeCurrentHand) from silently saving a corrupt
  /// half-hand. Returns the discarded hand's number so the replacement hand
  /// can reuse it (no numbering gap).
  int? discardCurrentHand() {
    final n = currentHand?.handNumber;
    currentHand = null;
    return n;
  }

  /// Activate all deferred seating in [gameState]. MUST be called before
  /// gameState.startNewHand() so button rotation and blind posting include
  /// the new players.
  void flushPendingSeats(PokerGameState gameState) {
    for (final seat in pendingSeats) {
      // Seat may have been removed again while pending — skip those.
      if (!activeSeats.contains(seat)) continue;
      gameState.setPlayerActive(seat, true);
      gameState.setPlayerStack(seat, playerStacks[seat] ?? 0.0);
    }
    pendingSeats.clear();

    if (_pendingHeroSeat != null) {
      reseatHero(
        newSeat: _pendingHeroSeat!,
        gameState: gameState,
        heroName: _pendingHeroName,
        heroStack: _pendingHeroStack,
      );
      _pendingHeroSeat = null;
      _pendingHeroName = null;
      _pendingHeroStack = null;
    }
  }

  /// Re-sync blind seats and the frozen hero position after a PRE-ACTION
  /// seat change (HL-1). Only valid while the current hand has no actions —
  /// the hero position is otherwise frozen for the hand (invariant I11).
  void refreshPreActionPositions(PokerGameState gameState) {
    actualSBSeat = gameState.effectiveSBPosition;
    actualBBSeat = gameState.effectiveBBPosition;
    final hand = currentHand;
    if (hand != null && hand.actions.isEmpty && ourSeatNumber != null) {
      hand.heroPositionName = PokerPositions.getPositionNameForActivePlayers(
        ourSeatNumber!,
        buttonPosition,
        activeSeats.toList(),
      );
      hand.heroSeatNumber = ourSeatNumber;
    }
  }

  // ── Shown cards after the hand (HL-5) ────────────────────────────────

  /// Record cards an opponent SHOWED after the hand ended (settling overlay
  /// press-and-hold). Stored in the finished hand's showdownData so the
  /// range/scouting pipeline picks them up; `reachedShowdown` stays false.
  ///
  /// The hand is already saved at this point, so the update is PERSISTED to
  /// both stores via the captured storage ids — never an in-memory-only
  /// patch (the HL-6 lesson). [persist] exists as a test seam.
  Future<void> attachShownCards({
    required int seat,
    required HoleCards cards,
    bool persist = true,
  }) async {
    final hand = lastFinishedHand;
    if (hand == null) return;
    if (cards.card1 == null && cards.card2 == null) return;

    hand.showdownData ??= ShowdownData();
    hand.showdownData!.playerCards[seat] = cards;

    if (!persist) return;
    final showdownMap = hand.showdownData!.toMap();

    if (hand.localHandId != null) {
      unawaited(LocalStorageService.updateHandShowdown(
        handId: hand.localHandId!,
        showdownData: showdownMap,
      ));
    }
    if (hand.cloudHandId != null && sessionId != null) {
      try {
        await FirebaseService.updateHandShowdown(
          sessionId: sessionId!,
          handId: hand.cloudHandId!,
          showdownData: showdownMap,
        );
      } catch (e) {
        await LoggerService.error(
            'Shown-cards cloud update failed (kept locally)', e, StackTrace.current);
      }
    }
  }

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

  /// Hero's latest known stack: the live seat stack while seated, otherwise
  /// the last tracked stack-history entry — so the value survives the hero
  /// being unseated/removed mid-session and can pre-fill re-seating flows.
  double latestHeroStack(PokerGameState? gameState) {
    final seat = ourSeatNumber;
    if (seat != null) {
      if (gameState != null && seat >= 1 && seat <= gameState.players.length) {
        return gameState.players[seat - 1].currentStack;
      }
      final tracked = playerStacks[seat];
      if (tracked != null) return tracked;
    }
    if (stackHistory.isNotEmpty) {
      return ((stackHistory.last['stackSize'] as num?) ?? 0).toDouble();
    }
    return 0.0;
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

    // If no custom name assigned or name is just the position, show "Player X (Position)"
    if (playerName == null || playerName.isEmpty || playerName == currentPosition || PokerPositions.isPositionName(playerName)) {
      return 'Player $seatNumber ($currentPosition)';
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