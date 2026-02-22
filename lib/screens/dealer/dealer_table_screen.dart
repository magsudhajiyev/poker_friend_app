import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/app_config.dart';
import '../../models/club.dart';
import '../../models/poker_table.dart';
import '../../models/dealer_session.dart';
import '../../models/seat_assignment.dart';
import '../../models/poker_game_state.dart';
import '../../models/hand_state_machine.dart';
import '../../models/game_types.dart';
import '../../services/dealer_service.dart';
import '../../services/event_service.dart';
import '../../services/seat_service.dart';
import '../../models/club_event.dart';
import '../../services/websocket_service.dart';
import '../../services/auth_service.dart';
import '../../services/qr_service.dart';
import '../../services/continuous_speech_service.dart';
import '../../services/soniox_service.dart';
import '../../utils/poker_positions.dart';
import '../../widgets/board_cards_dialog.dart';
import '../../widgets/all_in_board_cards_dialog.dart';
import '../../widgets/winner_selection_dialog.dart';
import '../../widgets/multi_pot_winner_dialog.dart';
// Removed: showdown_dialog - dealers don't enter player hole cards
// Players enter their own hole cards on their devices

/// Main screen for dealers to log poker hands
/// Uses PokerGameState and PokerSessionManager for consistent hand logging
class DealerTableScreen extends StatefulWidget {
  final DealerSession session;
  final Club club;
  final PokerTable table;

  const DealerTableScreen({
    Key? key,
    required this.session,
    required this.club,
    required this.table,
  }) : super(key: key);

  @override
  State<DealerTableScreen> createState() => _DealerTableScreenState();
}

class _DealerTableScreenState extends State<DealerTableScreen> {
  final WebSocketService _wsService = WebSocketService.instance;

  // Session tracking for club/dealer context
  late DealerSession _dealerSession;
  Map<int, SeatAssignment> _seatAssignments = {};
  List<SeatAssignment> _pendingJoins = [];

  // Core game logic - reusing established architecture
  // Made nullable to handle initialization safely
  PokerGameState? _gameState;
  PokerSessionManager? _sessionManager;
  bool _isGameStateInitialized = false;

  StreamSubscription? _seatSubscription;
  StreamSubscription? _sessionSubscription;
  StreamSubscription? _pendingSubscription;
  StreamSubscription? _eventSubscription;

  bool _isHandActive = false;
  bool _isLoading = false;
  bool _sessionStarted = false;

  // Speech/voice mode state - real-time WebSocket streaming for lowest latency
  // Using direct Soniox connection for minimal latency (~200ms vs ~2s)
  final SonioxService _realtimeSpeechService = SonioxService.instance;
  bool _isVoiceMode = false;
  bool _isListening = false;
  String _partialTranscript = '';

  // Pending action state for bet/raise waiting for amount
  String? _pendingActionType; // 'bet' or 'raise'
  DateTime? _pendingActionTime;
  static const int _pendingActionTimeoutMs = 3000; // 3 second timeout
  String _connectionStatus = 'disconnected';
  DetectedPokerAction? _lastDetectedAction;
  StreamSubscription? _actionSubscription;
  StreamSubscription? _partialSubscription;
  StreamSubscription? _statusSubscription;

  // Dealer Voice Authority state tracking
  VoiceSessionState _voiceState = VoiceSessionState.uninitialized;
  String? _lockedDealerName;
  String? _lockedTableName;
  bool _isHoldingActions = false;

  // Guard flag to prevent duplicate board cards dialogs
  bool _isShowingBoardCardsDialog = false;

  // Guard flag to prevent duplicate event end dialogs
  bool _isShowingEventEndDialog = false;

  // Event info for rebuy handling
  ClubEvent? _currentEvent;
  double _rebuyStack = 0;

  // Local blind state (can be changed during session)
  int _smallBlind = 0;
  int _bigBlind = 0;

  @override
  void initState() {
    super.initState();
    _dealerSession = widget.session;
    _smallBlind = _dealerSession.smallBlind;
    _bigBlind = _dealerSession.bigBlind;
    _initializeGameState();
    _initialize();
  }

  void _initializeGameState() {
    // Initialize PokerGameState with 9 seats (standard poker table)
    // Use local blind state (allows mid-session changes)
    _gameState = PokerGameState(
      numberOfPlayers: 9,
      smallBlind: _smallBlind,
      bigBlind: _bigBlind,
      isCashGame: _dealerSession.gameType == 'cash',
      hasBBante: _dealerSession.hasBBante,
    );

    // Initialize PokerSessionManager for recording hands
    _sessionManager = PokerSessionManager(
      smallBlind: _smallBlind,
      bigBlind: _bigBlind,
      playerCount: 9,
      gameType: _dealerSession.gameType == 'cash' ? GameType.cash : GameType.tournament,
      sessionName: 'Dealer Session - ${widget.table.name}',
    );

    _isGameStateInitialized = true;
  }

  @override
  void dispose() {
    _seatSubscription?.cancel();
    _sessionSubscription?.cancel();
    _pendingSubscription?.cancel();
    _eventSubscription?.cancel();
    _actionSubscription?.cancel();
    _partialSubscription?.cancel();
    _statusSubscription?.cancel();

    // Stop voice listening if active
    if (_isListening) {
      _realtimeSpeechService.stopStreaming();
    }

    // End session manager if active (with null check)
    if (_sessionManager != null && _sessionManager!.sessionState == SessionState.active) {
      _sessionManager!.endSession().catchError((e) {});
    }

    super.dispose();
  }

  Future<void> _initialize() async {
    // Load seat assignments
    _seatAssignments = await SeatService.getTableSeats(
      clubId: widget.club.id,
      tableId: widget.table.id,
    );

    // Initialize player stacks and active seats in both gameState and sessionManager
    _syncPlayersFromSeats();

    // Subscribe to seat updates
    _seatSubscription = SeatService.watchTableSeats(
      clubId: widget.club.id,
      tableId: widget.table.id,
    ).listen((seats) {
      if (mounted) {
        setState(() {
          _seatAssignments = seats;
          // Sync new players if not in hand
          if (!_isHandActive) {
            _syncPlayersFromSeats();
          }
        });
      }
    });

    // Subscribe to pending join requests
    _pendingSubscription = SeatService.watchPendingJoins(
      clubId: widget.club.id,
      tableId: widget.table.id,
    ).listen((pending) {
      if (mounted) {
        setState(() {
          _pendingJoins = pending;
        });
      }
    });

    // Subscribe to dealer session updates
    _sessionSubscription = DealerService.watchSession(_dealerSession.id).listen((session) {
      if (session != null && mounted) {
        setState(() {
          _dealerSession = session;
        });
      } else if (session == null && mounted) {
        // Session was deleted or ended externally
        _handleSessionEnded();
      }
    });

    // Subscribe to event status updates (if linked to an event)
    if (_dealerSession.eventId != null) {
      _eventSubscription = EventService.watchEvent(
        widget.club.id,
        _dealerSession.eventId!,
      ).listen((event) {
        if (!mounted) return;
        if (event != null) {
          // Store event info for rebuy handling
          _currentEvent = event;
          _rebuyStack = event.startingStack ?? (_dealerSession.bigBlind * 100.0);
        }
        if (event == null ||
            event.status == EventStatus.completed ||
            event.status == EventStatus.cancelled) {
          _handleEventEnded(event?.status);
        }
      });
    } else {
      // No event linked - use default stack
      _rebuyStack = _dealerSession.bigBlind * 100.0;
    }

    // Connect to WebSocket server for real-time updates
    final serverUrl = AppConfig.serverUrl;
    final userId = AuthService.userId;

    if (!_wsService.isConnected) {
      _wsService.connect(serverUrl, userId: userId);
    }

    _wsService.joinTable(
      widget.table.id,
      seatNumber: 0,
      playerName: 'Dealer',
    );

    // Set initial button position from dealer session
    _gameState!.buttonPosition = _dealerSession.buttonPosition;

    setState(() {});
  }

  /// Sync players from seat assignments to game state and session manager
  void _syncPlayersFromSeats() {
    if (!_isGameStateInitialized || _gameState == null || _sessionManager == null) {
      return; // Not yet initialized
    }
    _sessionManager!.activeSeats.clear();
    _sessionManager!.playerNames.clear();
    _sessionManager!.playerStacks.clear();

    for (int i = 1; i <= 9; i++) {
      final assignment = _seatAssignments[i];
      if (assignment != null && assignment.isOccupied) {
        final stack = assignment.chipStack ?? (_dealerSession.bigBlind * 100.0);

        // Update PokerGameState - use BOTH direct array access AND method for reliability
        _gameState!.players[i - 1].setStack(stack);
        _gameState!.players[i - 1].isActive = true;
        _gameState!.setPlayerStack(i, stack);
        _gameState!.setPlayerActive(i, true);

        // Update PokerSessionManager
        _sessionManager!.activeSeats.add(i);
        _sessionManager!.setPlayerName(i, assignment.playerName ?? 'Player $i');
        _sessionManager!.setPlayerStack(i, stack);
      } else {
        // Inactive seat
        _gameState!.players[i - 1].setStack(0.0);
        _gameState!.players[i - 1].isActive = false;
        _gameState!.setPlayerStack(i, 0.0);
        _gameState!.setPlayerActive(i, false);
      }
    }
  }

  List<int> get _activePlayers => _gameState?.getActivePlayers() ?? [];

  Future<void> _startNewHand() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      // Start session manager if not already started
      if (!_sessionStarted) {
        await _sessionManager!.startSession();
        _sessionStarted = true;
        // Only set button from dealer session for the first hand
        // After that, _gameState.startNewHand() moves the button automatically
        _gameState!.buttonPosition = _dealerSession.buttonPosition;
        // Only sync from seats for the FIRST hand - after that, game state is source of truth
        _syncPlayersFromSeats();
      }
      // NOTE: Don't call _syncPlayersFromSeats() for subsequent hands -
      // game state tracks player stacks during active session

      // Finalize game state initialization and calculate blinds
      _gameState!.finalizeInitialization();
      _gameState!.initializePot();

      // Start hand in session manager
      _sessionManager!.startHand(
        _gameState!.handNumber,
        _gameState!.buttonPosition,
        sbSeat: _gameState!.effectiveSBPosition,
        bbSeat: _gameState!.effectiveBBPosition,
      );

      // Record the hand start in DealerService for Firebase sync
      final handId = await DealerService.startHand(
        sessionId: _dealerSession.id,
        playerStacks: _getPlayerStacksMap(),
        buttonPosition: _gameState!.buttonPosition,
      );

      // Emit WebSocket event
      _wsService.emitHandStarted(
        tableId: widget.table.id,
        sessionId: _dealerSession.id,
        handId: handId,
        handNumber: _gameState!.handNumber,
        buttonPosition: _gameState!.buttonPosition,
        players: _getPlayerNamesMap(),
      );

      setState(() {
        _isHandActive = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to start hand: ${e.toString()}');
    }
  }

  Map<int, double> _getPlayerStacksMap() {
    final stacks = <int, double>{};
    for (int i = 1; i <= 9; i++) {
      if (_gameState!.players[i - 1].isActive) {
        stacks[i] = _gameState!.players[i - 1].currentStack;
      }
    }
    return stacks;
  }

  Map<int, String> _getPlayerNamesMap() {
    final names = <int, String>{};
    for (int seat in _sessionManager!.activeSeats) {
      names[seat] = _sessionManager!.getPlayerName(seat);
    }
    return names;
  }

  /// Perform an action using the established game logic
  /// [transcript] and [confidence] are optional and used for voice-logged actions
  Future<void> _performAction(
    PlayerAction action, {
    double? amount,
    String? transcript,
    double? confidence,
  }) async {
    if (!_isHandActive) {
      return;
    }

    final currentSeat = _gameState!.currentPlayer;
    // Use direct array access for reliability (bypasses _getPlayer lookup)
    var playerStack = _gameState!.players[currentSeat - 1].currentStack;

    // Fallback if stack is unexpectedly 0
    if (playerStack <= 0) {
      playerStack = _sessionManager!.getPlayerStack(currentSeat) ??
                    (_dealerSession.bigBlind * 100.0);
    }

    final playerName = _sessionManager!.getPlayerName(currentSeat);

    // Record action in session manager (for Firebase/stats)
    _sessionManager!.recordAction(
      currentSeat,
      action,
      _gameState!.currentRound,
      _gameState!.buttonPosition,
      playerStack: playerStack,
      amount: amount,
    );

    // Perform action in game state (handles progression, pot, etc.)
    if (amount != null && (action == PlayerAction.bet || action == PlayerAction.raise)) {
      _gameState!.performActionWithAmount(action, amount);
    } else if (action == PlayerAction.call) {
      _gameState!.performActionWithAmount(action, 0); // Call calculates internally
    } else {
      _gameState!.performAction(action);
    }

    // Log action to Firebase for real-time player sync
    final handId = _dealerSession.currentHandId;
    if (handId != null && handId.isNotEmpty) {
      try {
        // Get current street from game state
        final streetName = _gameState!.currentRound.name; // 'preflop', 'flop', 'turn', 'river'

        // Calculate position using active seats (not folded players still count for position)
        final activeSeats = <int>[];
        for (int i = 1; i <= 9; i++) {
          if (_gameState!.players[i - 1].isActive) {
            activeSeats.add(i);
          }
        }
        final playerPosition = PokerPositions.getPositionNameForActivePlayers(
          currentSeat,
          _gameState!.buttonPosition,
          activeSeats,
        );

        await DealerService.logAction(
          sessionId: _dealerSession.id,
          handId: handId,
          seatNumber: currentSeat,
          action: action.name,
          street: streetName,
          amount: amount,
          playerName: playerName,
          playerStack: playerStack,
          playerPosition: playerPosition,
          transcript: transcript,
          confidence: confidence,
        );
      } catch (e) {
        // Log error but don't block the UI
        debugPrint('Error logging action to Firebase: $e');
      }
    }

    // Emit WebSocket event for real-time updates
    _wsService.emitDealerAction(
      tableId: widget.table.id,
      sessionId: _dealerSession.id,
      handId: handId ?? '',
      seatNumber: currentSeat,
      action: action.name,
      amount: amount,
      potAfter: _gameState!.currentPot,
    );

    setState(() {});

    // Check if hand should end (everyone folded to one player)
    if (_activePlayers.length <= 1 && _isHandActive) {
      _completeHandAutomatically();
      return;
    }

    // Check if betting round complete
    if (_gameState!.bettingRoundComplete) {
      _handleBettingRoundComplete();
    }
  }

  void _handleBettingRoundComplete() {
    // Guard: Check state validity
    if (_gameState == null) {
      debugPrint('_handleBettingRoundComplete: _gameState is null, skipping');
      return;
    }

    // Check if we should auto-advance to showdown (all-in scenario)
    if (_gameState!.shouldAutoAdvanceToShowdown()) {
      _showAllInBoardCardsDialog();
      return;
    }

    // Otherwise, advance to next street normally
    if (_gameState!.currentRound != BettingRound.river) {
      _advanceToNextStreet();
    } else {
      // River complete - show showdown/winner selection
      _handleShowdown();
    }
  }

  void _advanceToNextStreet() async {
    // Prevent duplicate dialogs from race conditions
    if (_isShowingBoardCardsDialog) {
      debugPrint('_advanceToNextStreet: Dialog already showing, skipping');
      return;
    }
    _isShowingBoardCardsDialog = true;

    try {
      // Save pot for completed street
      _sessionManager!.savePotForStreet(_gameState!.currentRound, _gameState!.currentPot);

      // Show board cards dialog based on next street
      final nextRound = _getNextRound(_gameState!.currentRound);

      final boardCards = await _showBoardCardsDialog(nextRound);
      if (boardCards == null) {
        // User cancelled - don't advance
        return;
      }

      // Update board cards in session manager from the BoardCards object
      if (_sessionManager!.currentHand != null) {
        _sessionManager!.currentHand!.boardCards = boardCards;
      }

      // Sync board cards to Firestore for player screens
      final handId = _dealerSession.currentHandId;
      if (handId != null && handId.isNotEmpty) {
        await DealerService.setBoardCards(
          sessionId: _dealerSession.id,
          handId: handId,
          flop: boardCards.flop.isNotEmpty ? boardCards.flop : null,
          turn: boardCards.turn,
          river: boardCards.river,
        );
      }

      // Advance game state to next street
      _gameState!.startNewStreet(onStreetComplete: (round, pot) {
        _sessionManager!.savePotForStreet(round, pot);
      });

      setState(() {});
    } finally {
      _isShowingBoardCardsDialog = false;
    }
  }

  BettingRound _getNextRound(BettingRound current) {
    switch (current) {
      case BettingRound.preflop:
        return BettingRound.flop;
      case BettingRound.flop:
        return BettingRound.turn;
      case BettingRound.turn:
        return BettingRound.river;
      case BettingRound.river:
        return BettingRound.river;
    }
  }

  Future<BoardCards?> _showBoardCardsDialog(BettingRound round) async {
    return showDialog<BoardCards>(
      context: context,
      barrierDismissible: false,
      builder: (context) => BoardCardsDialog(
        currentRound: round,
        existingCards: _sessionManager!.currentHand?.boardCards,
      ),
    );
  }

  void _showAllInBoardCardsDialog() async {
    // Prevent duplicate dialogs from race conditions
    if (_isShowingBoardCardsDialog) {
      debugPrint('_showAllInBoardCardsDialog: Dialog already showing, skipping');
      return;
    }

    // Early return if state is invalid
    if (_gameState == null || _sessionManager == null) {
      debugPrint('_showAllInBoardCardsDialog: state is null, skipping');
      return;
    }

    _isShowingBoardCardsDialog = true;

    try {
      // Save pot for current street before showing dialog
      _sessionManager!.savePotForStreet(_gameState!.currentRound, _gameState!.currentPot);

      // Check if all 5 board cards are already selected - skip dialog if complete
      final existingCards = _sessionManager!.currentHand?.boardCards;
      final hasCompleteBoard = existingCards != null &&
          existingCards.flop.length == 3 &&
          existingCards.turn != null &&
          existingCards.river != null;

      BoardCards? boardCards;

      if (hasCompleteBoard) {
        // All cards already selected - use existing cards, skip dialog
        boardCards = existingCards;
      } else {
        // Show dialog to collect missing cards
        boardCards = await showDialog<BoardCards>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AllInBoardCardsDialog(
            existingBoardCards: existingCards,
          ),
        );
      }

      // Guard after dialog returns
      if (!mounted) {
        debugPrint('_showAllInBoardCardsDialog: Widget disposed after dialog, skipping');
        return;
      }
      if (_gameState == null || _sessionManager == null) {
        debugPrint('_showAllInBoardCardsDialog: state became null after dialog, skipping');
        return;
      }

      if (boardCards == null) {
        // User cancelled
        debugPrint('_showAllInBoardCardsDialog: User cancelled board cards dialog');
        return;
      }

      // Update board cards in session manager
      if (_sessionManager!.currentHand != null) {
        _sessionManager!.currentHand!.boardCards = boardCards;
      }

      // Sync board cards to Firestore for player screens
      final handId = _dealerSession.currentHandId;
      if (handId != null && handId.isNotEmpty) {
        await DealerService.setBoardCards(
          sessionId: _dealerSession.id,
          handId: handId,
          flop: boardCards.flop.isNotEmpty ? boardCards.flop : null,
          turn: boardCards.turn,
          river: boardCards.river,
        );
      }

      // Skip to river (all cards are now entered)
      _gameState!.currentRound = BettingRound.river;
      _gameState!.bettingRoundComplete = true;

      setState(() {});

      // Go to showdown for winner selection
      _handleShowdown();
    } finally {
      _isShowingBoardCardsDialog = false;
    }
  }

  void _handleShowdown() async {
    // Guard: Early return if state is invalid
    if (_gameState == null || _sessionManager == null) {
      debugPrint('_handleShowdown: State is null, skipping');
      return;
    }
    if (!mounted) {
      debugPrint('_handleShowdown: Widget not mounted, skipping');
      return;
    }

    // Mark as reached showdown
    if (_sessionManager!.currentHand != null) {
      _sessionManager!.currentHand!.reachedShowdown = true;
    }

    // Get active players for winner selection
    final activePlayers = _activePlayers;

    // Guard: Check for valid active players
    if (activePlayers.isEmpty) {
      debugPrint('_handleShowdown: No active players, skipping');
      return;
    }

    if (activePlayers.length == 1) {
      // Only one player left - they win automatically
      _completeHandAutomatically();
      return;
    }

    // Note: Player hole cards are entered by players themselves on their devices
    // Dealer only needs to select the winner

    // Guard: Check state again before calculating pots
    if (_gameState == null) {
      debugPrint('_handleShowdown: _gameState became null, skipping');
      return;
    }

    // Check for side pots
    final sidePots = _gameState!.calculateSidePots();

    if (sidePots.length > 1) {
      // Multiple side pots - show multi-pot winner dialog
      await _showMultiPotWinnerDialog(sidePots);
    } else {
      // Single pot - show regular winner selection
      await _showWinnerSelectionDialog();
    }
  }

  void _completeHandAutomatically() async {
    // Guard: Check for valid active players
    final activePlayers = _activePlayers;
    if (activePlayers.isEmpty) {
      debugPrint('_completeHandAutomatically: No active players, skipping');
      return;
    }

    // Single winner - everyone else folded
    final winner = activePlayers.first;
    await _completeHand(winner);
  }

  List<String> _getPlayerNamesList() {
    return _activePlayers.map((seat) => _sessionManager!.getPlayerName(seat)).toList();
  }

  Future<void> _showWinnerSelectionDialog() async {
    final activePlayers = _activePlayers;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => WinnerSelectionDialog(
        activePlayers: activePlayers,
        playerNames: _getPlayerNamesList(),
        potAmount: _gameState!.currentPot,
        buttonPosition: _gameState!.buttonPosition,
        playerCount: 9,
        gameType: _dealerSession.gameType == 'cash' ? GameType.cash : GameType.tournament,
      ),
    );

    if (result != null) {
      if (result['isChoppedPot'] == true) {
        // Chopped pot
        await _completeHandWithChop(
          result['winners'] as List<int>,
          result['individualShares'] as Map<int, double>?,
        );
      } else {
        // Single winner
        await _completeHand(result['winner'] as int);
      }
    }
  }

  Future<void> _showMultiPotWinnerDialog(List<SidePot> sidePots) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => MultiPotWinnerDialog(
        sidePots: sidePots,
        playerNames: _getPlayerNamesList(),
        playerIdToName: _getPlayerNamesMap(),
        buttonPosition: _gameState!.buttonPosition,
        playerCount: 9,
        gameType: _dealerSession.gameType == 'cash' ? GameType.cash : GameType.tournament,
      ),
    );

    if (result != null) {
      // Process multi-pot result - potResults contains results per pot
      final potResults = result['potResults'] as Map<int, Map<String, dynamic>>?;
      if (potResults == null || potResults.isEmpty) return;

      // Collect all winners and their shares across all pots
      final allWinners = <int>{};
      final allShares = <int, double>{};

      for (final potResult in potResults.values) {
        if (potResult['isChoppedPot'] == true) {
          final winners = potResult['winners'] as List<int>;
          final shares = potResult['individualShares'] as Map<int, double>;
          allWinners.addAll(winners);
          for (final entry in shares.entries) {
            allShares[entry.key] = (allShares[entry.key] ?? 0) + entry.value;
          }
        } else {
          final winner = potResult['winner'] as int;
          final amount = potResult['potAmount'] as double;
          allWinners.add(winner);
          allShares[winner] = (allShares[winner] ?? 0) + amount;
        }
      }

      if (allWinners.length > 1) {
        await _completeHandWithChop(allWinners.toList(), allShares);
      } else {
        await _completeHand(allWinners.first);
      }
    }
  }

  Future<void> _completeHand(int winnerId) async {
    if (!_isHandActive) return;

    try {
      // Get winner's stack for tracking
      final winnerStack = _gameState!.getPlayerStack(winnerId) + _gameState!.currentPot;

      // Complete hand in session manager (saves to Firebase, updates stats)
      _sessionManager!.completeCurrentHand(
        potAmount: _gameState!.currentPot,
        winnerId: winnerId,
        currentStack: winnerStack,
      );

      // Update winner's stack in game state
      _gameState!.players[winnerId - 1].currentStack += _gameState!.currentPot;

      // Update DealerService (for dealer_sessions collection)
      await DealerService.completeHand(
        sessionId: _dealerSession.id,
        handId: _dealerSession.currentHandId ?? '',
        winnerId: winnerId,
        potAmount: _gameState!.currentPot,
      );

      // Emit WebSocket event
      final winnerName = _sessionManager!.getPlayerName(winnerId);
      _wsService.emitHandCompleted(
        tableId: widget.table.id,
        sessionId: _dealerSession.id,
        handId: _dealerSession.currentHandId ?? '',
        winnerSeat: winnerId,
        potAmount: _gameState!.currentPot,
        summary: '$winnerName wins \$${_gameState!.currentPot.toStringAsFixed(0)}',
      );

      _showSuccess('$winnerName wins \$${_gameState!.currentPot.toStringAsFixed(0)}');

      // Check for busted players BEFORE startNewHand() deactivates them
      // This allows the rebuy/remove dialog to appear while player is still marked active
      await _checkForBustedPlayers();

      // Now prepare for next hand (this will deactivate any remaining busted players)
      _gameState!.startNewHand();

      // Update seat chip stacks in Firebase
      await _updateSeatChipStacks();

      setState(() {
        _isHandActive = false;
      });
    } catch (e) {
      _showError('Failed to complete hand: ${e.toString()}');
    }
  }

  Future<void> _completeHandWithChop(List<int> winnerIds, Map<int, double>? shares) async {
    if (!_isHandActive) return;

    try {
      final sharePerWinner = shares != null
          ? null
          : _gameState!.currentPot / winnerIds.length;

      // Complete hand with chop in session manager
      _sessionManager!.completeCurrentHandWithChop(
        potAmount: _gameState!.currentPot,
        winnerIds: winnerIds,
        individualShares: shares,
        sharePerWinner: sharePerWinner,
      );

      // Update stacks for all winners
      for (final winnerId in winnerIds) {
        final share = shares?[winnerId] ?? sharePerWinner ?? 0;
        _gameState!.players[winnerId - 1].currentStack += share;
      }

      // Update DealerService with chop info
      await DealerService.completeHand(
        sessionId: _dealerSession.id,
        handId: _dealerSession.currentHandId ?? '',
        winnerId: winnerIds.first,
        potAmount: _gameState!.currentPot,
        isChoppedPot: true,
        choppedWinners: winnerIds,
        individualShares: shares,
      );

      // Emit WebSocket event
      final winnerNames = winnerIds.map((id) => _sessionManager!.getPlayerName(id)).join(', ');
      _wsService.emitHandCompleted(
        tableId: widget.table.id,
        sessionId: _dealerSession.id,
        handId: _dealerSession.currentHandId ?? '',
        winnerSeat: winnerIds.first,
        potAmount: _gameState!.currentPot,
        summary: 'Chop: $winnerNames split \$${_gameState!.currentPot.toStringAsFixed(0)}',
      );

      _showSuccess('Pot chopped between $winnerNames');

      // Check for busted players BEFORE startNewHand() deactivates them
      // This allows the rebuy/remove dialog to appear while player is still marked active
      await _checkForBustedPlayers();

      // Now prepare for next hand (this will deactivate any remaining busted players)
      _gameState!.startNewHand();

      // Update seat chip stacks
      await _updateSeatChipStacks();

      setState(() {
        _isHandActive = false;
      });
    } catch (e) {
      _showError('Failed to complete hand: ${e.toString()}');
    }
  }

  Future<void> _updateSeatChipStacks() async {
    // Update chip stacks in Firebase for all active players
    for (int i = 1; i <= 9; i++) {
      if (_gameState!.players[i - 1].isActive) {
        final stack = _gameState!.players[i - 1].currentStack;
        final playerName = _sessionManager?.getPlayerName(i) ?? 'Player $i';

        try {
          await SeatService.updateChipStack(
            clubId: widget.club.id,
            tableId: widget.table.id,
            seatNumber: i,
            chipStack: stack,
          );

          // Emit to WebSocket for live event rankings
          // Backend will check if table is in an event and broadcast rankings
          _wsService.emitPlayerStackUpdate(
            tableId: widget.table.id,
            playerId: 'seat_${widget.table.id}_$i',
            newStack: stack.toInt(),
            playerName: playerName,
            seatNumber: i,
          );
        } catch (e) {
          // Ignore individual update failures
        }
      }
    }
  }

  /// Check for busted players after hand completion and prompt dealer for action
  Future<void> _checkForBustedPlayers() async {
    if (_gameState == null || _sessionManager == null) return;

    // Count active players for finish position calculation
    int activePlayerCount = 0;
    for (int i = 0; i < 9; i++) {
      if (_gameState!.players[i].isActive && _gameState!.players[i].currentStack > 0) {
        activePlayerCount++;
      }
    }

    // Find all busted players (stack <= 0)
    final bustedPlayers = <int>[];
    for (int seatNumber = 1; seatNumber <= 9; seatNumber++) {
      final player = _gameState!.players[seatNumber - 1];
      if (player.isActive && player.currentStack <= 0) {
        bustedPlayers.add(seatNumber);
      }
    }

    // Process each busted player
    for (final seatNumber in bustedPlayers) {
      final playerName = _sessionManager!.getPlayerName(seatNumber);
      final action = await _showBustedPlayerDialog(playerName, seatNumber);

      if (action == 'rebuy') {
        // Give player the rebuy stack
        _gameState!.players[seatNumber - 1].currentStack = _rebuyStack;
        _sessionManager!.setPlayerStack(seatNumber, _rebuyStack);

        // Update seat with new stack
        await SeatService.updateChipStack(
          clubId: widget.club.id,
          tableId: widget.table.id,
          seatNumber: seatNumber,
          chipStack: _rebuyStack,
        );

        // Update local seat assignment to keep in sync
        if (_seatAssignments.containsKey(seatNumber)) {
          _seatAssignments[seatNumber] = _seatAssignments[seatNumber]!.copyWith(
            chipStack: _rebuyStack,
          );
        }

        // Emit stack update for rankings - player is back to active status
        // This clears any previous finish position from being busted
        _wsService.emitPlayerStackUpdate(
          tableId: widget.table.id,
          playerId: 'seat_${widget.table.id}_$seatNumber',
          newStack: _rebuyStack.toInt(),
          playerName: playerName,
          seatNumber: seatNumber,
          status: 'active', // Back in the game
          finishPosition: null, // Clear previous finish position
        );

        _showSuccess('$playerName rebuys for ${_rebuyStack.toStringAsFixed(0)}');
      } else {
        // Calculate finish position: active players + busted players being processed
        // If multiple players bust on same hand, they all get same position
        final finishPosition = activePlayerCount + bustedPlayers.length;

        // Remove player from game
        _gameState!.players[seatNumber - 1].isActive = false;
        _gameState!.players[seatNumber - 1].currentStack = 0;
        _gameState!.players[seatNumber - 1].betThisRound = 0;
        _sessionManager!.removePlayer(seatNumber);

        // Clear the seat in Firebase
        await SeatService.removeSeatOccupant(
          clubId: widget.club.id,
          tableId: widget.table.id,
          seatNumber: seatNumber,
        );

        // Remove from local seat assignments to keep in sync
        _seatAssignments.remove(seatNumber);

        // Emit player removal for rankings (busted with finish position)
        _wsService.emitPlayerStackUpdate(
          tableId: widget.table.id,
          playerId: 'seat_${widget.table.id}_$seatNumber',
          newStack: 0,
          playerName: playerName,
          seatNumber: seatNumber,
          status: 'busted',
          finishPosition: finishPosition,
        );

        _showSuccess('$playerName finishes in ${_getOrdinal(finishPosition)} place');
      }
    }

    // Update state if any players were processed
    if (bustedPlayers.isNotEmpty) {
      setState(() {});
    }
  }

  /// Show dialog asking dealer if busted player is rebuying or leaving
  Future<String> _showBustedPlayerDialog(String playerName, int seatNumber) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$playerName Busted!',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Player $playerName (Seat $seatNumber) has no chips remaining.',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Text(
              'Rebuy amount: ${_rebuyStack.toStringAsFixed(0)}',
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'remove'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove Player'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'rebuy'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Rebuy'),
          ),
        ],
      ),
    );

    return result ?? 'remove';
  }

  Future<void> _endSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('End Session?', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to end this session?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('End'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // End session manager
      if (_sessionManager!.sessionState == SessionState.active) {
        await _sessionManager!.endSession();
      }

      // End dealer session
      await DealerService.endSession(_dealerSession.id);

      _wsService.emitSessionEnded(
        tableId: widget.table.id,
        sessionId: _dealerSession.id,
        totalHands: _gameState!.handNumber - 1,
      );

      if (mounted) Navigator.pop(context);
    }
  }

  /// Handle event completion or cancellation by club admin
  void _handleEventEnded(EventStatus? status) {
    if (_isShowingEventEndDialog) return;
    _isShowingEventEndDialog = true;

    // Stop any ongoing voice recognition
    if (_isListening) {
      _stopContinuousListening();
    }

    // Cancel subscriptions to prevent further updates
    _seatSubscription?.cancel();
    _sessionSubscription?.cancel();
    _eventSubscription?.cancel();

    final title = status == EventStatus.cancelled ? 'Event Cancelled' : 'Event Finished';
    final message = status == EventStatus.cancelled
        ? 'The club admin has cancelled this event. All sessions have been saved.'
        : 'The club admin has finished this event. All sessions have been saved.';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Exit dealer screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Handle session ended externally (e.g., by event completion)
  void _handleSessionEnded() {
    if (_isShowingEventEndDialog) return;
    _isShowingEventEndDialog = true;

    // Stop any ongoing voice recognition
    if (_isListening) {
      _stopContinuousListening();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Session Ended', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This session has been ended. All data has been saved.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Exit dealer screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showQRCodesDialog() {
    showDialog(
      context: context,
      builder: (context) => _QRCodesDialog(
        clubId: widget.club.id,
        tableId: widget.table.id,
        tableName: widget.table.name,
      ),
    );
  }

  Future<double?> _showAmountDialog(String title) async {
    double amount = _gameState!.bigBlind.toDouble();
    final controller = TextEditingController(text: amount.toString());

    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          autofocus: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixText: '\$',
            prefixStyle: const TextStyle(color: Colors.white),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, double.tryParse(controller.text)),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  /// Get ordinal suffix for a number (1st, 2nd, 3rd, 4th, etc.)
  String _getOrdinal(int number) {
    if (number >= 11 && number <= 13) {
      return '${number}th';
    }
    switch (number % 10) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green.shade700),
    );
  }

  void _showAutoCorrection(String detected, String corrected) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Auto-corrected "$detected" → "$corrected"'),
        backgroundColor: Colors.amber.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showApproveJoinDialog(SeatAssignment pending) async {
    final controller = TextEditingController(
      text: (_dealerSession.bigBlind * 100).toString(),
    );

    final chipStack = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Text(
          'Approve ${pending.playerName ?? 'Player'}?',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seat ${pending.seatNumber}',
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Starting Chip Stack',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixText: '\$',
                prefixStyle: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await SeatService.rejectJoin(
                  clubId: widget.club.id,
                  tableId: widget.table.id,
                  seatNumber: pending.seatNumber,
                );
                if (context.mounted) Navigator.pop(context);
                _showSuccess('${pending.playerName} rejected');
              } catch (e) {
                _showError('Failed to reject: ${e.toString()}');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
          ElevatedButton(
            onPressed: () {
              final stack = double.tryParse(controller.text);
              if (stack != null && stack > 0) {
                Navigator.pop(context, stack);
              }
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (chipStack != null) {
      try {
        await SeatService.approveJoin(
          clubId: widget.club.id,
          tableId: widget.table.id,
          seatNumber: pending.seatNumber,
          chipStack: chipStack,
        );

        // Add player to dealer session's players map for session history tracking
        await DealerService.addPlayer(
          sessionId: _dealerSession.id,
          odPlayerId: pending.playerId ?? '',
          displayName: pending.playerName ?? 'Player ${pending.seatNumber}',
          seatNumber: pending.seatNumber,
          initialStack: chipStack,
        );

        // Update local game state
        _gameState!.setPlayerStack(pending.seatNumber, chipStack);
        _gameState!.setPlayerActive(pending.seatNumber, true);
        _sessionManager!.activeSeats.add(pending.seatNumber);
        _sessionManager!.setPlayerName(pending.seatNumber, pending.playerName ?? 'Player ${pending.seatNumber}');
        _sessionManager!.setPlayerStack(pending.seatNumber, chipStack);

        _showSuccess('${pending.playerName} joined with \$${chipStack.toStringAsFixed(0)}');
      } catch (e) {
        _showError('Failed to approve: ${e.toString()}');
      }
    }
  }

  Future<void> _showPlayerOptionsDialog(int seatNumber, String? playerName, double currentStack) async {
    final stackController = TextEditingController(text: currentStack.toStringAsFixed(0));

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Text(
          playerName ?? 'Seat $seatNumber',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seat $seatNumber',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: stackController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Chip Stack',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixText: '\$',
                prefixStyle: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context, 'remove'),
                    icon: const Icon(Icons.person_remove, color: Colors.red),
                    label: const Text('Remove', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, 'save:${stackController.text}'),
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result == null) return;

    if (result == 'remove') {
      await _removePlayer(seatNumber, playerName);
    } else if (result.startsWith('save:')) {
      final newStack = double.tryParse(result.substring(5));
      if (newStack != null && newStack >= 0) {
        try {
          await SeatService.updateChipStack(
            clubId: widget.club.id,
            tableId: widget.table.id,
            seatNumber: seatNumber,
            chipStack: newStack,
          );
          _gameState!.setPlayerStack(seatNumber, newStack);
          _sessionManager!.setPlayerStack(seatNumber, newStack);
          setState(() {});
          _showSuccess('Updated ${playerName ?? 'player'} stack to \$${newStack.toStringAsFixed(0)}');
        } catch (e) {
          _showError('Failed to update stack: ${e.toString()}');
        }
      }
    }
  }

  Future<void> _showAddPlayerDialog(int seatNumber) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _UserSearchDialog(
        seatNumber: seatNumber,
        defaultStack: (_dealerSession.bigBlind * 100).toDouble(),
      ),
    );

    if (result != null) {
      try {
        final playerId = result['playerId'] as String?;
        final playerName = result['name'] as String;
        final stack = result['stack'] as double;

        if (playerId != null) {
          // Seat registered user directly
          await SeatService.seatUserDirectly(
            clubId: widget.club.id,
            tableId: widget.table.id,
            seatNumber: seatNumber,
            playerId: playerId,
            playerName: playerName,
            chipStack: stack,
          );

          // Add player to dealer session's players map for session history tracking
          await DealerService.addPlayer(
            sessionId: _dealerSession.id,
            odPlayerId: playerId,
            displayName: playerName,
            seatNumber: seatNumber,
            initialStack: stack,
          );
        } else {
          // Add manual/walk-up player (no user account)
          final seatAssignment = await SeatService.addManualPlayer(
            clubId: widget.club.id,
            tableId: widget.table.id,
            seatNumber: seatNumber,
            playerName: playerName,
            chipStack: stack,
          );

          // Add manual player to dealer session's players map
          await DealerService.addPlayer(
            sessionId: _dealerSession.id,
            odPlayerId: seatAssignment.playerId ?? 'manual_$seatNumber',
            displayName: playerName,
            seatNumber: seatNumber,
            initialStack: stack,
          );
        }

        // Update local game state
        _gameState!.setPlayerStack(seatNumber, stack);
        _gameState!.setPlayerActive(seatNumber, true);
        _sessionManager!.activeSeats.add(seatNumber);
        _sessionManager!.setPlayerName(seatNumber, playerName);
        _sessionManager!.setPlayerStack(seatNumber, stack);

        setState(() {});
        _showSuccess('$playerName added to Seat $seatNumber');
      } catch (e) {
        _showError('Failed to add player: ${e.toString()}');
      }
    }
  }

  Future<void> _removePlayer(int seatNumber, String? playerName) async {
    try {
      await SeatService.removeSeatOccupant(
        clubId: widget.club.id,
        tableId: widget.table.id,
        seatNumber: seatNumber,
      );

      // Update local game state
      _gameState!.setPlayerActive(seatNumber, false);
      _gameState!.setPlayerStack(seatNumber, 0);
      _sessionManager!.activeSeats.remove(seatNumber);
      _sessionManager!.playerStacks.remove(seatNumber);

      setState(() {});
      _showSuccess('${playerName ?? 'Player'} removed from Seat $seatNumber');
    } catch (e) {
      _showError('Failed to remove player: ${e.toString()}');
    }
  }

  void _showPendingJoinsDialog() {
    if (_pendingJoins.isEmpty) {
      _showSuccess('No pending join requests');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Pending Join Requests', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _pendingJoins.map((pending) {
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange,
                child: Text(
                  pending.seatNumber.toString(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                pending.playerName ?? 'Unknown',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'Seat ${pending.seatNumber}',
                style: const TextStyle(color: Colors.white54),
              ),
              trailing: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showApproveJoinDialog(pending);
                },
                child: const Text('Review'),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading if game state not initialized
    if (!_isGameStateInitialized || _gameState == null || _sessionManager == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1117),
        appBar: AppBar(
          backgroundColor: const Color(0xFF161B22),
          title: Text(widget.table.name),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: Text(widget.table.name),
        actions: [
          // Pending join requests badge
          if (_pendingJoins.isNotEmpty)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.person_add),
                  onPressed: _showPendingJoinsDialog,
                  tooltip: 'Pending Join Requests',
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _pendingJoins.length.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.qr_code),
            onPressed: _showQRCodesDialog,
            tooltip: 'Show QR Codes',
          ),
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: _endSession,
            tooltip: 'End Session',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildGameInfo(),
          Expanded(child: _buildTableView()),
          if (_isHandActive) _buildActionButtons(),
          if (!_isHandActive) _buildStartHandSection(),
        ],
      ),
    );
  }

  Widget _buildGameInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: const Color(0xFF161B22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoItem('POT', '\$${_gameState!.currentPot.toStringAsFixed(0)}', Colors.amber),
          _buildInfoItem('STREET', _gameState!.currentRound.name.toUpperCase(), Colors.blue),
          GestureDetector(
            onTap: _showChangeBlindsDialog,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoItem('BLINDS', '$_smallBlind/$_bigBlind', Colors.green),
                const SizedBox(width: 4),
                Icon(Icons.edit, color: Colors.green.withOpacity(0.7), size: 14),
              ],
            ),
          ),
          _buildInfoItem('HAND', '#${_gameState!.handNumber}', Colors.purple),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Future<void> _showChangeBlindsDialog() async {
    final smallBlindController = TextEditingController(text: _smallBlind.toString());
    final bigBlindController = TextEditingController(text: _bigBlind.toString());

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2430),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Update Blinds',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Small Blind',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: smallBlindController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 18),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF2A3142),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Big Blind',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: bigBlindController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 18),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF2A3142),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'New blinds will apply from the next hand.',
              style: TextStyle(color: Colors.grey[400], fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final newSmallBlind = int.tryParse(smallBlindController.text) ?? _smallBlind;
              final newBigBlind = int.tryParse(bigBlindController.text) ?? _bigBlind;

              // Validate: SB should be less than BB
              if (newSmallBlind >= newBigBlind) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Small blind must be less than big blind'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (newSmallBlind <= 0 || newBigBlind <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Blinds must be greater than 0'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context, {'smallBlind': newSmallBlind, 'bigBlind': newBigBlind});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null) {
      final newSmallBlind = result['smallBlind']!;
      final newBigBlind = result['bigBlind']!;

      setState(() {
        _smallBlind = newSmallBlind;
        _bigBlind = newBigBlind;
      });

      // Update game state for next hand calculations
      if (_gameState != null) {
        _gameState!.smallBlind = newSmallBlind;
        _gameState!.bigBlind = newBigBlind;
      }

      // Update session manager for hand recording
      if (_sessionManager != null) {
        _sessionManager!.smallBlind = newSmallBlind;
        _sessionManager!.bigBlind = newBigBlind;
      }

      // Update session in Firestore
      try {
        await DealerService.updateSessionBlinds(
          sessionId: _dealerSession.id,
          smallBlind: newSmallBlind,
          bigBlind: newBigBlind,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Blinds updated to $newSmallBlind/$newBigBlind'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        // Rollback local changes on failure
        setState(() {
          _smallBlind = _dealerSession.smallBlind;
          _bigBlind = _dealerSession.bigBlind;
        });
        if (_gameState != null) {
          _gameState!.smallBlind = _dealerSession.smallBlind;
          _gameState!.bigBlind = _dealerSession.bigBlind;
        }
        if (_sessionManager != null) {
          _sessionManager!.smallBlind = _dealerSession.smallBlind;
          _sessionManager!.bigBlind = _dealerSession.bigBlind;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update blinds: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildTableView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final centerX = constraints.maxWidth / 2;
        final centerY = constraints.maxHeight / 2;
        final tableWidth = constraints.maxWidth * 0.80;
        final tableHeight = constraints.maxHeight * 0.70;
        final radiusX = constraints.maxWidth * 0.42;
        final radiusY = constraints.maxHeight * 0.38;

        return Stack(
          children: [
            // Table
            Center(
              child: Container(
                width: tableWidth,
                height: tableHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 30,
                      spreadRadius: 0,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 15,
                      spreadRadius: -5,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const RadialGradient(
                      center: Alignment.center,
                      radius: 0.8,
                      colors: [
                        Color(0xFF0F6B33),
                        Color(0xFF0D5D2D),
                        Color(0xFF0A4A24),
                      ],
                      stops: [0.0, 0.6, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(200),
                    border: Border.all(
                      color: const Color(0xFF2A2A2E),
                      width: 6,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(194),
                      border: Border.all(
                        color: const Color(0xFF1A1A1E).withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '\$${_gameState!.currentPot.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                            ),
                          ),
                          const Text('POT', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Seats
            ..._buildSeatsAroundTable(centerX, centerY, radiusX, radiusY),
          ],
        );
      },
    );
  }

  List<Widget> _buildSeatsAroundTable(double centerX, double centerY, double radiusX, double radiusY) {
    final double startAngle = math.pi * 1.25;
    final double angleStep = (2 * math.pi) / 9;

    return List.generate(9, (i) {
      final seatNumber = i + 1;
      final angle = startAngle + (angleStep * (seatNumber - 1));
      final x = centerX + radiusX * math.cos(angle) - 35;
      final y = centerY + radiusY * math.sin(angle) - 35;

      final assignment = _seatAssignments[seatNumber];
      final isOccupied = assignment?.isOccupied ?? false;
      final isPending = assignment?.isPending ?? false;
      final playerState = _gameState!.players[seatNumber - 1];
      final isFolded = playerState.hasFolded;
      final isCurrentPlayer = seatNumber == _gameState!.currentPlayer && _isHandActive;
      final isButton = seatNumber == _gameState!.buttonPosition;
      final stack = playerState.currentStack;
      final bet = playerState.betThisRound;

      return Positioned(
        left: x,
        top: y,
        child: _buildSeat(
          seatNumber: seatNumber,
          playerName: assignment?.playerName ?? _sessionManager!.getPlayerName(seatNumber),
          isOccupied: isOccupied || playerState.isActive,
          isPending: isPending,
          isFolded: isFolded,
          isCurrentPlayer: isCurrentPlayer,
          isButton: isButton,
          stack: stack,
          bet: bet,
          onPendingTap: isPending && assignment != null
              ? () => _showApproveJoinDialog(assignment)
              : null,
          onOccupiedTap: (isOccupied || playerState.isActive) && !_isHandActive && !isPending
              ? () => _showPlayerOptionsDialog(seatNumber, assignment?.playerName, stack)
              : null,
          onEmptyTap: !isOccupied && !playerState.isActive && !isPending && !_isHandActive
              ? () => _showAddPlayerDialog(seatNumber)
              : null,
          canAcceptButtonDrop: !_isHandActive,
          onButtonDropped: _onButtonDroppedOnSeat,
        ),
      );
    });
  }

  /// Handle dealer button being dropped on a seat
  Future<void> _onButtonDroppedOnSeat(int newButtonSeat) async {
    final oldPosition = _gameState!.buttonPosition;
    if (newButtonSeat == oldPosition) return;

    setState(() {
      _gameState!.buttonPosition = newButtonSeat;
      // Also update dealer session so _startNewHand uses correct position
      _dealerSession = _dealerSession.copyWith(buttonPosition: newButtonSeat);
    });

    // Persist to Firestore
    try {
      await DealerService.updateSessionButtonPosition(
        sessionId: _dealerSession.id,
        buttonPosition: newButtonSeat,
      );
    } catch (e) {
      // Rollback on error
      setState(() {
        _gameState!.buttonPosition = oldPosition;
        _dealerSession = _dealerSession.copyWith(buttonPosition: oldPosition);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to move button: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSeat({
    required int seatNumber,
    String? playerName,
    required bool isOccupied,
    bool isPending = false,
    required bool isFolded,
    required bool isCurrentPlayer,
    required bool isButton,
    required double stack,
    required double bet,
    VoidCallback? onPendingTap,
    VoidCallback? onOccupiedTap,
    VoidCallback? onEmptyTap,
    bool canAcceptButtonDrop = false,
    Function(int)? onButtonDropped,
  }) {
    Color bgColor;
    Color borderColor;

    if (isPending) {
      bgColor = Colors.orange.withValues(alpha: 0.3);
      borderColor = Colors.orange;
    } else if (!isOccupied) {
      bgColor = const Color(0xFF2A2A3A);
      borderColor = const Color(0xFF3A3A4A);
    } else if (isFolded) {
      bgColor = const Color(0xFF3A3A4A).withValues(alpha: 0.5);
      borderColor = const Color(0xFF4A4A5A);
    } else if (isCurrentPlayer) {
      bgColor = const Color(0xFF4A3A00);
      borderColor = Colors.amber;
    } else {
      bgColor = const Color(0xFF1E3A5F);
      borderColor = const Color(0xFF2E5A8F);
    }

    // Dealer button widget (extracted for reuse in Draggable)
    Widget dealerButtonBadge({double opacity = 1.0}) => Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withValues(alpha: opacity), width: 2),
      ),
      child: Center(
        child: Text('D', style: TextStyle(
          color: Colors.black.withValues(alpha: opacity),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        )),
      ),
    );

    final seatWidget = GestureDetector(
      onTap: isPending
          ? onPendingTap
          : (isOccupied && _isHandActive && !isFolded
              ? () => setState(() => _gameState!.currentPlayer = seatNumber)
              : (isOccupied && !_isHandActive
                  ? onOccupiedTap
                  : (!isOccupied ? onEmptyTap : null))),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main seat
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor,
                width: isPending ? 3 : (isCurrentPlayer ? 3 : 2),
              ),
              boxShadow: isPending
                  ? [BoxShadow(color: Colors.orange.withValues(alpha: 0.5), blurRadius: 15)]
                  : (isCurrentPlayer
                      ? [BoxShadow(color: Colors.amber.withValues(alpha: 0.5), blurRadius: 15)]
                      : null),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isPending) ...[
                  Text(
                    _truncateName(playerName ?? 'Player'),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'PENDING',
                    style: TextStyle(color: Colors.orange, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ] else ...[
                  Text(
                    seatNumber.toString(),
                    style: TextStyle(
                      color: isOccupied ? Colors.white : Colors.white38,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isOccupied) ...[
                    Text(
                      _truncateName(playerName ?? ''),
                      style: TextStyle(color: isFolded ? Colors.white38 : Colors.white70, fontSize: 9),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '\$${stack.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: isFolded ? Colors.white38 : Colors.greenAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          // Pending badge
          if (isPending)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Center(
                  child: Icon(Icons.person_add, size: 12, color: Colors.white),
                ),
              ),
            ),
          // Dealer button - draggable when hand is not active
          if (isButton && !isPending)
            Positioned(
              right: -4,
              top: -4,
              child: canAcceptButtonDrop
                  ? Draggable<int>(
                      data: seatNumber,
                      feedback: Material(
                        color: Colors.transparent,
                        child: dealerButtonBadge(opacity: 0.9),
                      ),
                      childWhenDragging: dealerButtonBadge(opacity: 0.3),
                      child: dealerButtonBadge(),
                    )
                  : dealerButtonBadge(),
            ),
          // Current bet
          if (bet > 0)
            Positioned(
              bottom: -8,
              left: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade800,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '\$${bet.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );

    // Wrap with DragTarget to accept button drops
    if (canAcceptButtonDrop && onButtonDropped != null) {
      return DragTarget<int>(
        onAcceptWithDetails: (details) {
          onButtonDropped(seatNumber);
        },
        builder: (context, candidateData, rejectedData) {
          // Highlight seat when button is dragged over it
          final isHovered = candidateData.isNotEmpty;
          if (isHovered) {
            return Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: seatWidget,
            );
          }
          return seatWidget;
        },
      );
    }

    return seatWidget;
  }

  String _truncateName(String name) {
    if (name.length <= 7) return name;
    return '${name.substring(0, 6)}..';
  }

  Widget _buildActionButtons() {
    final currentPlayer = _gameState!.currentPlayer;
    final canCheck = _gameState!.isValidAction(PlayerAction.check);
    final canCall = _gameState!.isValidAction(PlayerAction.call);
    final canBet = _gameState!.isValidAction(PlayerAction.bet);
    final canRaise = _gameState!.isValidAction(PlayerAction.raise);

    final callAmount = _gameState!.getCurrentBet() - _gameState!.players[currentPlayer - 1].betThisRound;
    final playerName = _sessionManager!.getPlayerName(currentPlayer);
    final playerStack = _gameState!.getPlayerStack(currentPlayer);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Player info and mode toggle row
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$playerName to act (\$${playerStack.toStringAsFixed(0)})',
                      style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Voice mode toggle - shows current state
                GestureDetector(
                  onTap: () => _toggleVoiceMode(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _getVoiceModeColor(),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getVoiceModeBorderColor(),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getVoiceModeIcon(),
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getVoiceModeLabel(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Show voice UI or manual buttons based on mode
            if (_isVoiceMode)
              _buildVoiceActionUI()
            else
              Row(
                children: [
                  _buildActionButton('FOLD', Colors.red.shade700,
                      () => _performAction(PlayerAction.fold)),
                  const SizedBox(width: 8),
                  if (canCheck)
                    _buildActionButton('CHECK', Colors.grey.shade700,
                        () => _performAction(PlayerAction.check))
                  else if (canCall)
                    _buildActionButton('CALL\n\$${callAmount.toStringAsFixed(0)}', Colors.green.shade700,
                        () => _performAction(PlayerAction.call)),
                  const SizedBox(width: 8),
                  if (canBet)
                    _buildActionButton('BET', Colors.blue.shade700, () async {
                      final amount = await _showAmountDialog('Bet amount');
                      if (amount != null && amount > 0) {
                        await _performAction(PlayerAction.bet, amount: amount);
                      }
                    })
                  else if (canRaise)
                    _buildActionButton('RAISE', Colors.blue.shade700, () async {
                      final amount = await _showAmountDialog('Raise to');
                      if (amount != null && amount > 0) {
                        await _performAction(PlayerAction.raise, amount: amount);
                      }
                    }),
                  const SizedBox(width: 8),
                  _buildActionButton('ALL IN', Colors.purple.shade700, () async {
                    // All-in is either a bet or raise for the player's full stack
                    final stack = _gameState!.getPlayerStack(currentPlayer);
                    final action = canBet ? PlayerAction.bet : PlayerAction.raise;
                    await _performAction(action, amount: stack + _gameState!.players[currentPlayer - 1].betThisRound);
                  }),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Build voice action UI based on current voice session state
  Widget _buildVoiceActionUI() {
    // Show last detected action briefly
    if (_lastDetectedAction != null) {
      return _buildLastActionFeedback(_lastDetectedAction!);
    }

    // State-based UI
    switch (_voiceState) {
      case VoiceSessionState.uninitialized:
        return _buildStartVoiceModeUI();
      case VoiceSessionState.calibrating:
        return _buildCalibrationUI();
      case VoiceSessionState.dealerLocked:
        return _buildDealerLockedUI();
      case VoiceSessionState.connectionLost:
        return _buildConnectionLostUI();
      case VoiceSessionState.rotating:
        return _buildRotatingUI();
    }
  }

  /// Build UI to start voice mode
  Widget _buildStartVoiceModeUI() {
    return GestureDetector(
      onTap: _startContinuousListening,
      child: Container(
        width: double.infinity,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade800,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blueGrey.shade600, width: 2),
        ),
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mic_none, color: Colors.white, size: 32),
              SizedBox(width: 12),
              Text(
                'TAP TO START VOICE MODE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build calibration UI - waiting for dealer to announce
  Widget _buildCalibrationUI() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade800,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Calibrating...',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Please announce: "Table [number], dealer [name]"',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Cancel button
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: _stopContinuousListening,
                tooltip: 'Cancel',
              ),
            ],
          ),
          // Show partial transcript during calibration
          if (_partialTranscript.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _partialTranscript,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build dealer locked UI - ready to receive commands
  Widget _buildDealerLockedUI() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isHoldingActions ? Colors.amber.shade700 : Colors.green.shade700,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Status row
          Row(
            children: [
              Icon(
                _isHoldingActions ? Icons.pause : Icons.mic,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isHoldingActions ? 'Actions Paused' : 'Listening',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Dealer: ${_lockedDealerName ?? 'Unknown'} • ${_lockedTableName ?? 'Table'}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              // Hold Action Toggle
              IconButton(
                icon: Icon(
                  _isHoldingActions ? Icons.play_arrow : Icons.pause,
                  color: Colors.white,
                ),
                onPressed: () {
                  _realtimeSpeechService.toggleHoldAction();
                  setState(() => _isHoldingActions = !_isHoldingActions);
                },
                tooltip: _isHoldingActions ? 'Resume Actions' : 'Hold Actions',
              ),
              // Recalibrate
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70),
                onPressed: _recalibrateDealer,
                tooltip: 'Recalibrate',
              ),
              // Stop button
              IconButton(
                icon: const Icon(Icons.stop, color: Colors.white70),
                onPressed: _stopContinuousListening,
                tooltip: 'Stop Voice Mode',
              ),
            ],
          ),
          // Transcript
          if (_partialTranscript.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _partialTranscript,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
          // Help text
          const SizedBox(height: 8),
          const Text(
            'Say: fold, check, call, bet [amount], raise [amount], all-in',
            style: TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }

  /// Build connection lost UI
  Widget _buildConnectionLostUI() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade800,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Connection Lost',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Attempting to reconnect...',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          // Manual reconnect
          ElevatedButton(
            onPressed: () => _realtimeSpeechService.startStreaming(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red.shade800,
            ),
            child: const Text('Reconnect'),
          ),
        ],
      ),
    );
  }

  /// Build rotating dealer UI
  Widget _buildRotatingUI() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade800,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Rotating Dealer...',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Recalibrate dealer voice
  void _recalibrateDealer() {
    _realtimeSpeechService.recalibrate();
    setState(() {
      _voiceState = VoiceSessionState.calibrating;
      _lockedDealerName = null;
      _lockedTableName = null;
      _partialTranscript = '';
    });
  }

  /// Get voice mode button color based on state
  Color _getVoiceModeColor() {
    if (!_isVoiceMode) return Colors.blueGrey.shade700;

    switch (_voiceState) {
      case VoiceSessionState.uninitialized:
        return Colors.blueGrey.shade700;
      case VoiceSessionState.calibrating:
        return Colors.orange.shade600;
      case VoiceSessionState.dealerLocked:
        return _isHoldingActions ? Colors.amber.shade700 : Colors.green.shade600;
      case VoiceSessionState.connectionLost:
        return Colors.red.shade600;
      case VoiceSessionState.rotating:
        return Colors.purple.shade600;
    }
  }

  /// Get voice mode button border color based on state
  Color _getVoiceModeBorderColor() {
    if (!_isVoiceMode) return Colors.blueGrey.shade500;

    switch (_voiceState) {
      case VoiceSessionState.uninitialized:
        return Colors.blueGrey.shade500;
      case VoiceSessionState.calibrating:
        return Colors.orange.shade400;
      case VoiceSessionState.dealerLocked:
        return _isHoldingActions ? Colors.amber.shade500 : Colors.green.shade400;
      case VoiceSessionState.connectionLost:
        return Colors.red.shade400;
      case VoiceSessionState.rotating:
        return Colors.purple.shade400;
    }
  }

  /// Get voice mode icon based on state
  IconData _getVoiceModeIcon() {
    if (!_isVoiceMode) return Icons.touch_app;

    switch (_voiceState) {
      case VoiceSessionState.uninitialized:
        return Icons.mic_none;
      case VoiceSessionState.calibrating:
        return Icons.settings_voice;
      case VoiceSessionState.dealerLocked:
        return _isHoldingActions ? Icons.pause : Icons.mic;
      case VoiceSessionState.connectionLost:
        return Icons.signal_wifi_off;
      case VoiceSessionState.rotating:
        return Icons.sync;
    }
  }

  /// Get voice mode label based on state
  String _getVoiceModeLabel() {
    if (!_isVoiceMode) return 'TAP';

    switch (_voiceState) {
      case VoiceSessionState.uninitialized:
        return 'OFF';
      case VoiceSessionState.calibrating:
        return 'CALIB';
      case VoiceSessionState.dealerLocked:
        return _isHoldingActions ? 'PAUSED' : 'LIVE';
      case VoiceSessionState.connectionLost:
        return 'LOST';
      case VoiceSessionState.rotating:
        return 'ROTATE';
    }
  }

  /// Show brief feedback when action is detected and executed
  Widget _buildLastActionFeedback(DetectedPokerAction action) {
    final actionDisplay = action.action.toUpperCase();
    final amountDisplay = action.amount != null ? ' \$${action.amount!.toStringAsFixed(0)}' : '';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.green.shade700,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Text(
                '$actionDisplay$amountDisplay',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Heard: "${action.transcript}"',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  /// Toggle voice mode on/off (shows/hides push-to-talk button)
  Future<void> _toggleVoiceMode() async {
    try {
      if (_isVoiceMode) {
        // Turn off voice mode - stop any active listening
        await _stopContinuousListening();
        if (mounted) setState(() => _isVoiceMode = false);
      } else {
        // Turn on voice mode - just show the push-to-talk UI
        // Actual streaming starts when button is held
        if (mounted) setState(() => _isVoiceMode = true);
      }
    } catch (e) {
      _showError('Voice mode error: $e');
      if (mounted) setState(() => _isVoiceMode = false);
    }
  }

  /// Start continuous listening using real-time WebSocket streaming
  Future<void> _startContinuousListening() async {
    try {
      // Subscribe to action stream from realtime service
      _actionSubscription?.cancel();
      _actionSubscription = _realtimeSpeechService.actionStream.listen(
        _onActionDetected,
        onError: (e) {},
      );

      // Subscribe to partial results for UI feedback
      _partialSubscription?.cancel();
      _partialSubscription = _realtimeSpeechService.partialStream.listen(
        (partial) {
          if (mounted) {
            setState(() => _partialTranscript = partial);

            // Check if this completes a pending bet/raise action
            if (_pendingActionType != null) {
              _checkForPendingAmount(partial);
            }
          }
        },
        onError: (e) {},
      );

      // Subscribe to status stream for connection state
      _statusSubscription?.cancel();
      _statusSubscription = _realtimeSpeechService.statusStream.listen(
        (status) {
          if (mounted) {
            setState(() {
              _connectionStatus = status;
              _voiceState = _realtimeSpeechService.state;
              _isHoldingActions = _realtimeSpeechService.isHoldingActions;
            });

            // Handle dealer locked event
            if (status.startsWith('dealer_locked:')) {
              final parts = status.split(':');
              if (parts.length >= 3) {
                setState(() {
                  _lockedDealerName = parts[1];
                  _lockedTableName = parts[2];
                });
                _showSuccess('Dealer locked: ${parts[1]} at table ${parts[2]}');
              }
            } else if (status == 'calibration_failed:no_speakers') {
              _showError('No speakers detected - please speak clearly');
            } else if (status == 'calibration_failed:content_mismatch') {
              _showError('Please say: "Table [number], dealer [name]"');
            } else if (status == 'connection_lost') {
              _showError('Connection lost - attempting to recover...');
            } else if (status == 'grace_period_expired') {
              _showError('Connection timeout - recalibration required');
            } else if (status == 'connection_recovered') {
              _showSuccess('Connection recovered!');
            } else if (status.startsWith('action_held:')) {
              final transcript = status.substring('action_held:'.length);
              _showAutoCorrection('Action held', transcript);
            }
          }
        },
        onError: (e) {},
      );

      final started = await _realtimeSpeechService.startStreaming();

      if (mounted) {
        setState(() {
          _isListening = started;
          _voiceState = _realtimeSpeechService.state;
        });
      }

      if (!started) {
        _showError('Failed to start streaming - check server connection and microphone');
      }
    } catch (e) {
      _showError('Failed to start voice: $e');
      if (mounted) {
        setState(() {
          _isVoiceMode = false;
          _isListening = false;
          _voiceState = VoiceSessionState.uninitialized;
        });
      }
    }
  }

  /// Stop continuous listening
  /// Waits for final results before cancelling subscriptions
  Future<void> _stopContinuousListening() async {
    // First stop the service (waits for final results from Soniox)
    await _realtimeSpeechService.stopStreaming();

    // THEN cancel subscriptions after final results have been processed
    _actionSubscription?.cancel();
    _actionSubscription = null;
    _partialSubscription?.cancel();
    _partialSubscription = null;
    _statusSubscription?.cancel();
    _statusSubscription = null;

    setState(() {
      _isListening = false;
      _partialTranscript = '';
      _connectionStatus = 'stopped';
      _voiceState = VoiceSessionState.uninitialized;
      _lockedDealerName = null;
      _lockedTableName = null;
      _isHoldingActions = false;
    });
  }

  /// Handle detected action from speech
  Future<void> _onActionDetected(DetectedPokerAction action) async {
    if (!_isHandActive) {
      return;
    }

    // Haptic feedback for action detection
    HapticFeedback.mediumImpact();

    // Show the detected action briefly
    setState(() => _lastDetectedAction = action);

    // Execute the action
    await _executeVoiceAction(action);

    // Clear the feedback after a delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _lastDetectedAction = null);
      }
    });
  }

  // Number words for extracting amounts from partial transcripts
  static const Map<String, String> _numberWords = {
    // English
    'one': '1', 'two': '2', 'three': '3', 'four': '4', 'five': '5',
    'six': '6', 'seven': '7', 'eight': '8', 'nine': '9', 'ten': '10',
    'eleven': '11', 'twelve': '12', 'thirteen': '13', 'fourteen': '14',
    'fifteen': '15', 'sixteen': '16', 'seventeen': '17', 'eighteen': '18',
    'nineteen': '19', 'twenty': '20', 'thirty': '30', 'forty': '40',
    'fifty': '50', 'sixty': '60', 'seventy': '70', 'eighty': '80',
    'ninety': '90', 'hundred': '100', 'thousand': '1000',
    // Polish
    'jeden': '1', 'dwa': '2', 'trzy': '3', 'cztery': '4', 'pięć': '5',
    'sześć': '6', 'siedem': '7', 'osiem': '8', 'dziewięć': '9', 'dziesięć': '10',
    'jedenaście': '11', 'dwanaście': '12', 'trzynaście': '13', 'czternaście': '14',
    'piętnaście': '15', 'szesnaście': '16', 'siedemnaście': '17', 'osiemnaście': '18',
    'dziewiętnaście': '19', 'dwadzieścia': '20', 'trzydzieści': '30',
    'czterdzieści': '40', 'pięćdziesiąt': '50', 'sześćdziesiąt': '60',
    'siedemdziesiąt': '70', 'osiemdziesiąt': '80', 'dziewięćdziesiąt': '90',
    'sto': '100', 'tysiąc': '1000',
  };

  /// Extract a number from transcript (handles Polish and English number words)
  /// Sorts by word length descending so "sixty" is replaced before "six".
  double? _extractNumber(String transcript) {
    var text = transcript.toLowerCase();

    // Sort by length descending so longer words are replaced first
    // This prevents "sixty" becoming "6ty" when "six" is replaced first
    final sortedWords = _numberWords.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final word in sortedWords) {
      text = text.replaceAll(word, _numberWords[word]!);
    }

    // Extract first number found
    final match = RegExp(r'\d+').firstMatch(text);
    if (match != null) {
      return double.tryParse(match.group(0)!);
    }
    return null;
  }

  /// Check if a partial transcript contains an amount for a pending action
  void _checkForPendingAmount(String transcript) {
    if (_pendingActionType == null) return;

    // Check timeout
    if (_pendingActionTime != null &&
        DateTime.now().difference(_pendingActionTime!).inMilliseconds > _pendingActionTimeoutMs) {
      _pendingActionType = null;
      _pendingActionTime = null;
      return;
    }

    // Try to extract a number from the transcript
    final amount = _extractNumber(transcript);
    if (amount != null && amount > 0) {

      // Create the complete action
      final action = DetectedPokerAction(
        action: _pendingActionType!,
        amount: amount,
        confidence: 1.0,
        transcript: transcript,
        matchScore: 100,
      );

      // Clear pending state
      _pendingActionType = null;
      _pendingActionTime = null;

      // Execute the action
      _executeVoiceAction(action);
    }
  }

  /// Execute a detected voice action
  Future<void> _executeVoiceAction(DetectedPokerAction action) async {
    if (_gameState == null || !_isHandActive) {
      return;
    }

    PlayerAction? playerAction;
    double? amount = action.amount;

    switch (action.action) {
      case 'fold':
        playerAction = PlayerAction.fold;
        break;
      case 'check':
        // Auto-correct: if check is invalid, try call instead
        if (!_gameState!.isValidAction(PlayerAction.check)) {
          if (_gameState!.isValidAction(PlayerAction.call)) {
            playerAction = PlayerAction.call;
            _showAutoCorrection('check', 'call');
          } else {
            _showError('Cannot check or call');
            return;
          }
        } else {
          playerAction = PlayerAction.check;
        }
        break;
      case 'call':
        // Auto-correct: if call is invalid, try check instead
        if (!_gameState!.isValidAction(PlayerAction.call)) {
          if (_gameState!.isValidAction(PlayerAction.check)) {
            playerAction = PlayerAction.check;
            _showAutoCorrection('call', 'check');
          } else {
            _showError('Cannot call or check');
            return;
          }
        } else {
          playerAction = PlayerAction.call;
        }
        break;
      case 'bet':
        // If no amount, store as pending and wait for amount to be transcribed
        if (amount == null) {
          _pendingActionType = 'bet';
          _pendingActionTime = DateTime.now();
          return; // Don't execute yet, wait for amount
        }
        // Auto-correct: if bet is invalid, try raise instead
        if (!_gameState!.isValidAction(PlayerAction.bet)) {
          if (_gameState!.isValidAction(PlayerAction.raise)) {
            playerAction = PlayerAction.raise;
            _showAutoCorrection('bet', 'raise');
          } else {
            _showError('Cannot bet or raise');
            return;
          }
        } else {
          playerAction = PlayerAction.bet;
        }
        // Clear pending state since we're executing
        _pendingActionType = null;
        _pendingActionTime = null;
        break;
      case 'raise':
        // If no amount, store as pending and wait for amount to be transcribed
        if (amount == null) {
          _pendingActionType = 'raise';
          _pendingActionTime = DateTime.now();
          return; // Don't execute yet, wait for amount
        }
        // Auto-correct: if raise is invalid, try bet instead
        if (!_gameState!.isValidAction(PlayerAction.raise)) {
          if (_gameState!.isValidAction(PlayerAction.bet)) {
            playerAction = PlayerAction.bet;
            _showAutoCorrection('raise', 'bet');
          } else {
            _showError('Cannot raise or bet');
            return;
          }
        } else {
          playerAction = PlayerAction.raise;
        }
        // Clear pending state since we're executing
        _pendingActionType = null;
        _pendingActionTime = null;
        break;
      case 'all-in':
        final canBet = _gameState!.isValidAction(PlayerAction.bet);
        playerAction = canBet ? PlayerAction.bet : PlayerAction.raise;
        final currentPlayer = _gameState!.currentPlayer;
        amount = _gameState!.getPlayerStack(currentPlayer) +
            _gameState!.players[currentPlayer - 1].betThisRound;
        break;
      default:
        _showError('Unknown action: ${action.action}');
        return;
    }

    // Execute the action
    await _performAction(
      playerAction,
      amount: amount,
      transcript: action.transcript,
      confidence: action.confidence,
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildStartHandSection() {
    final occupiedSeats = _gameState!.getActivePlayers().length;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text('$occupiedSeats players seated', style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: occupiedSeats >= 2 ? _startNewHand : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              disabledBackgroundColor: Colors.grey.shade800,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('START NEW HAND', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          if (occupiedSeats < 2)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Need at least 2 players to start', style: TextStyle(color: Colors.orange)),
            ),
          // Debug button to add random players for testing
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _addRandomPlayersForTesting,
            icon: const Icon(Icons.group_add, color: Colors.amber),
            label: const Text('Add Test Players', style: TextStyle(color: Colors.amber)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.amber),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Add random players to all empty seats for testing
  Future<void> _addRandomPlayersForTesting() async {
    final testNames = [
      'Alice', 'Bob', 'Charlie', 'Diana', 'Eve',
      'Frank', 'Grace', 'Henry', 'Ivy',
    ];

    final random = math.Random();
    final defaultStack = _dealerSession.bigBlind * 100.0;

    for (int seatNumber = 1; seatNumber <= 9; seatNumber++) {
      // Skip if seat is already occupied
      if (_gameState!.players[seatNumber - 1].isActive) {
        continue;
      }

      final playerName = testNames[seatNumber - 1];
      // Randomize stack a bit: 80-120 BBs (rounded to whole number)
      final stack = (defaultStack * (0.8 + random.nextDouble() * 0.4)).roundToDouble();

      try {
        final seatAssignment = await SeatService.addManualPlayer(
          clubId: widget.club.id,
          tableId: widget.table.id,
          seatNumber: seatNumber,
          playerName: playerName,
          chipStack: stack,
        );

        // Add test player to dealer session's players map for session history tracking
        await DealerService.addPlayer(
          sessionId: _dealerSession.id,
          odPlayerId: seatAssignment.playerId ?? 'manual_$seatNumber',
          displayName: playerName,
          seatNumber: seatNumber,
          initialStack: stack,
        );

        // Update local game state
        _gameState!.setPlayerStack(seatNumber, stack);
        _gameState!.setPlayerActive(seatNumber, true);
        _sessionManager!.activeSeats.add(seatNumber);
        _sessionManager!.setPlayerName(seatNumber, playerName);
        _sessionManager!.setPlayerStack(seatNumber, stack);
      } catch (e) {
        debugPrint('Error adding test player to seat $seatNumber: $e');
      }
    }

    setState(() {});
    _showSuccess('Added ${9 - _seatAssignments.length} test players');
  }
}

/// Dialog to display QR codes for all seats
class _QRCodesDialog extends StatefulWidget {
  final String clubId;
  final String tableId;
  final String tableName;

  const _QRCodesDialog({
    required this.clubId,
    required this.tableId,
    required this.tableName,
  });

  @override
  State<_QRCodesDialog> createState() => _QRCodesDialogState();
}

class _QRCodesDialogState extends State<_QRCodesDialog> {
  int _selectedSeat = 1;
  Map<int, SeatAssignment> _seatAssignments = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSeatAssignments();
  }

  Future<void> _loadSeatAssignments() async {
    try {
      final seats = await SeatService.getTableSeats(
        clubId: widget.clubId,
        tableId: widget.tableId,
      );
      if (mounted) {
        setState(() {
          _seatAssignments = seats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final qrData = QRService.generateQRData(
      clubId: widget.clubId,
      tableId: widget.tableId,
      seatNumber: _selectedSeat,
    );

    final isOccupied = _seatAssignments[_selectedSeat]?.isOccupied ?? false;
    final occupantName = _seatAssignments[_selectedSeat]?.playerName;

    return Dialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.tableName} - Seat $_selectedSeat',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (isOccupied)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Occupied by ${occupantName ?? "Player"}',
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
            const SizedBox(height: 20),
            if (!isOccupied) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: qrData.encode(),
                  version: QrVersions.auto,
                  size: 200,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Scan to join this seat',
                style: TextStyle(color: Colors.white54),
              ),
            ] else ...[
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person, size: 60, color: Colors.white38),
                      SizedBox(height: 12),
                      Text(
                        'Seat Occupied',
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Seat selector
            _isLoading
                ? const CircularProgressIndicator()
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(9, (i) {
                      final seat = i + 1;
                      final seatIsOccupied = _seatAssignments[seat]?.isOccupied ?? false;
                      final isSelected = seat == _selectedSeat;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedSeat = seat),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (seatIsOccupied ? Colors.orange : Colors.green)
                                : (seatIsOccupied ? Colors.orange.withValues(alpha: 0.3) : const Color(0xFF2A2A3A)),
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              seat.toString(),
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A3A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                const Text('Empty', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(width: 16),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                const Text('Occupied', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for searching and selecting users to seat
class _UserSearchDialog extends StatefulWidget {
  final int seatNumber;
  final double defaultStack;

  const _UserSearchDialog({
    required this.seatNumber,
    required this.defaultStack,
  });

  @override
  State<_UserSearchDialog> createState() => _UserSearchDialogState();
}

class _UserSearchDialogState extends State<_UserSearchDialog> {
  final _searchController = TextEditingController();
  final _stackController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedUser;
  bool _isSearching = false;
  bool _useManualEntry = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _stackController.text = widget.defaultStack.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _stackController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final results = await AuthService.searchUsersByName(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  void _selectUser(Map<String, dynamic> user) {
    setState(() {
      _selectedUser = user;
      _searchController.text = user['displayName'] ?? '';
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedUser = null;
      _searchController.clear();
      _searchResults = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      title: Text(
        'Add Player to Seat ${widget.seatNumber}',
        style: const TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toggle between search and manual entry
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _useManualEntry = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: !_useManualEntry ? Colors.amber : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        'Search User',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: !_useManualEntry ? Colors.amber : Colors.white54,
                          fontWeight: !_useManualEntry ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _useManualEntry = true;
                      _selectedUser = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _useManualEntry ? Colors.amber : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        'Manual Entry',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _useManualEntry ? Colors.amber : Colors.white54,
                          fontWeight: _useManualEntry ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (!_useManualEntry) ...[
              // Search field
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                autofocus: true,
                enabled: _selectedUser == null,
                onChanged: _selectedUser == null ? _onSearchChanged : null,
                decoration: InputDecoration(
                  labelText: 'Search by Name',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  hintText: 'Type to search users...',
                  hintStyle: const TextStyle(color: Colors.white30),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  suffixIcon: _selectedUser != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54),
                          onPressed: _clearSelection,
                        )
                      : (_isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null),
                ),
              ),

              // Search results or selected user
              if (_selectedUser != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedUser!['displayName'] ?? 'Unknown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _selectedUser!['email'] ?? '',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_searchResults.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final user = _searchResults[index];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.withValues(alpha: 0.3),
                          child: Text(
                            (user['displayName'] as String? ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          user['displayName'] ?? 'Unknown',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          user['email'] ?? '',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        onTap: () => _selectUser(user),
                      );
                    },
                  ),
                ),
              ] else if (_searchController.text.isNotEmpty && !_isSearching) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'No users found. Try manual entry.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ),
              ],
            ] else ...[
              // Manual entry mode
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Player Name',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  hintText: 'Enter player name',
                  hintStyle: const TextStyle(color: Colors.white30),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Chip stack field
            TextField(
              controller: _stackController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Starting Chip Stack',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixText: '\$',
                prefixStyle: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _canSubmit() ? _submit : null,
          child: const Text('Add Player'),
        ),
      ],
    );
  }

  bool _canSubmit() {
    final name = _searchController.text.trim();
    final stack = double.tryParse(_stackController.text);

    if (name.isEmpty || stack == null || stack <= 0) return false;

    // In search mode, require a selected user unless manual entry
    if (!_useManualEntry && _selectedUser == null) return false;

    return true;
  }

  void _submit() {
    final name = _searchController.text.trim();
    final stack = double.tryParse(_stackController.text);

    if (name.isEmpty || stack == null || stack <= 0) return;

    Navigator.pop(context, {
      'playerId': _selectedUser?['uid'],
      'name': _selectedUser?['displayName'] ?? name,
      'stack': stack,
    });
  }
}
