import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/app_config.dart';
import '../../design_system/poker_friend_theme.dart';
import '../../models/club.dart';
import '../../models/poker_table.dart';
import '../../models/dealer_session.dart';
import '../../models/seat_assignment.dart';
import '../../models/poker_game_state.dart';
import '../../models/hand_state_machine.dart';
import '../../models/game_types.dart';
import '../../services/dealer_service.dart';
import '../../services/event_service.dart';
import '../../services/firebase_service.dart';
import '../../services/seat_service.dart';
import '../../models/club_event.dart';
import '../../services/websocket_service.dart';
import '../../services/auth_service.dart';
import '../../services/qr_service.dart';
import '../../services/soniox_service.dart';
import '../../services/action_parser.dart';
import '../../features/dealer_voice/cubit/dealer_voice_cubit.dart';
import '../../features/dealer_voice/cubit/dealer_voice_state.dart';
import '../../utils/poker_positions.dart';
import '../../widgets/poker_table_widget.dart';
import '../../utils/number_formatter.dart';
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
  String _connectionStatus = 'disconnected';
  StreamSubscription? _partialSubscription;
  StreamSubscription? _statusSubscription;

  // Dealer Voice Authority state tracking
  VoiceSessionState _voiceState = VoiceSessionState.uninitialized;
  String? _lockedDealerName;
  String? _lockedTableName;

  // Voice pipeline orchestrator (replaces overlap-based dedup with game-state validation)
  DealerVoiceCubit? _voiceCubit;

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

  // Dealer-player tracking: seat number if dealer is also playing, null otherwise
  int? _dealerPlayingSeat;

  // Track players seated before session starts (will be added as participants on first hand)
  final Set<String> _pendingParticipants = {};

  // Guard flag to prevent actions during hand completion transition
  bool _isCompletingHand = false;

  /// Format amount with $ for cash games, without for tournaments
  String _formatAmount(num amount) {
    return _dealerSession.gameType == 'cash'
        ? formatCompactCurrency(amount)
        : formatCompactNumber(amount);
  }

  /// Whether this session is a tournament (no $ prefix)
  bool get _isTournament => _dealerSession.gameType != 'cash';

  @override
  void initState() {
    super.initState();
    _dealerSession = widget.session;
    _smallBlind = _dealerSession.smallBlind;
    _bigBlind = _dealerSession.bigBlind;
    _initializeGameState();
    _initializeVoiceCubit();
    _initialize();
  }

  void _initializeVoiceCubit() {
    _voiceCubit = DealerVoiceCubit(
      sonioxService: _realtimeSpeechService,
      onExecuteAction: _onVoiceActionValidated,
    );
  }

  /// Called by voice cubit when an action is validated and ready to execute
  Future<void> _onVoiceActionValidated(ParsedAction action) async {
    debugPrint('[DealerTableScreen] _onVoiceActionValidated: ${action.action} (amount=${action.amount})');

    // Map to PlayerAction and execute
    final playerAction = _mapParsedActionToPlayerAction(action);
    if (playerAction == null) {
      debugPrint('[DealerTableScreen] Could not map action to PlayerAction');
      return;
    }

    final currentSeat = _gameState?.currentPlayer;
    debugPrint('[DealerTableScreen] Executing $playerAction for seat $currentSeat');

    await _performAction(
      playerAction,
      amount: action.amount,
      transcript: action.action,
      confidence: action.confidence,
    );

    debugPrint('[DealerTableScreen] Action executed. New currentPlayer: ${_gameState?.currentPlayer}');

    // CRITICAL: Update cubit with fresh game state after execution
    // PokerGameState is mutated in place by _performAction, so currentPlayer
    // will have advanced. The cubit needs the updated state to validate
    // the next action in a multi-action sequence correctly.
    _voiceCubit?.updateGameState(_gameState, _isHandActive);
  }

  /// Map parsed action string to PlayerAction enum
  PlayerAction? _mapParsedActionToPlayerAction(ParsedAction parsed) {
    switch (parsed.action.toLowerCase()) {
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
      default:
        return null;
    }
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
      isLive: true,  // Mark as live/dealer session
    );
    _sessionManager!.dealerSessionId = _dealerSession.id;
    _sessionManager!.eventId = _dealerSession.eventId;

    _isGameStateInitialized = true;
  }

  @override
  void dispose() {
    _seatSubscription?.cancel();
    _sessionSubscription?.cancel();
    _pendingSubscription?.cancel();
    _eventSubscription?.cancel();
    _partialSubscription?.cancel();
    _statusSubscription?.cancel();

    // Close voice cubit (handles stopping and cleanup)
    _voiceCubit?.close();

    // End session manager if active AND not already ended by _handleEventEnded()
    // The _sessionStarted check prevents double-ending which can cause auth issues
    if (_sessionStarted && _sessionManager != null &&
        _sessionManager!.sessionState == SessionState.active) {
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
          // Update session with event info
          if (_sessionManager != null) {
            _sessionManager!.sessionName = event.name;
            // Set buy-in amount from event for Total Invested calculation
            _sessionManager!.totalBuyIn = event.buyInAmount ?? 0.0;
          }
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

  /// Build a map of seat number → Firebase userId for registered players
  /// Used for dealer mode stats tracking
  Map<int, String> _getPlayerIdsMap() {
    final ids = <int, String>{};
    for (final entry in _seatAssignments.entries) {
      final assignment = entry.value;
      if (assignment.isOccupied &&
          assignment.playerId != null &&
          !assignment.playerId!.startsWith('manual_')) {
        ids[entry.key] = assignment.playerId!;
      }
    }
    return ids;
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

    // Update playerIds for dealer mode stats tracking
    _sessionManager!.setPlayerIds(_getPlayerIdsMap());
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

        // Add all participants who were seated before session started
        for (final participantId in _pendingParticipants) {
          await FirebaseService.addSessionParticipant(
            sessionId: _sessionManager!.sessionId!,
            participantId: participantId,
            joinedAtHand: 1,
          );
        }
        _pendingParticipants.clear();

        // Only set button from dealer session for the first hand
        // After that, _gameState.startNewHand() moves the button automatically
        _gameState!.buttonPosition = _dealerSession.buttonPosition;
        // Only sync from seats for the FIRST hand - after that, game state is source of truth
        _syncPlayersFromSeats();

        // For first hand: initialize
        _gameState!.finalizeInitialization();
        _gameState!.initializePot();
      } else {
        // For subsequent hands: ALWAYS call initializePot() here
        // This ensures blinds are posted with the CURRENT player list
        // (after any additions/removals since previous hand completed)
        _gameState!.finalizeInitialization();
        _gameState!.initializePot();
      }

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

      // Reset voice cubit for new hand and update game state
      _voiceCubit?.onNewHand();
      _voiceCubit?.updateGameState(_gameState, _isHandActive);

      // Auto-start voice mode on first hand (voice stays on throughout session)
      if (!_isVoiceMode) {
        setState(() => _isVoiceMode = true);
        _startContinuousListening();
      }
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
    // Guard: prevent actions if hand is not active or if hand is being completed
    if (!_isHandActive || _isCompletingHand) {
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

    // Calculate actual amount for recording (especially for call actions)
    double? recordAmount = amount;
    if (action == PlayerAction.call && recordAmount == null) {
      // For calls, calculate the amount needed to match the current bet
      final player = _gameState!.players[currentSeat - 1];
      recordAmount = _gameState!.getCurrentBet() - player.betThisRound;
      if (recordAmount < 0) recordAmount = 0;
      // If player is going all-in for less, cap at their stack
      if (recordAmount > player.currentStack) {
        recordAmount = player.currentStack;
      }
    }

    // Record action in session manager (for Firebase/stats)
    _sessionManager!.recordAction(
      currentSeat,
      action,
      _gameState!.currentRound,
      _gameState!.buttonPosition,
      playerStack: playerStack,
      amount: recordAmount,
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

      // Advance game state to next street (streetPots auto-snapshotted)
      _gameState!.startNewStreet();

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
    final allSidePots = _gameState!.calculateSidePots();

    // Filter out side pots with only 1 eligible player (auto-award those)
    // These are meaningless pots that only one player can win
    final contestedPots = <SidePot>[];
    final autoAwardPots = <SidePot>[];

    for (final pot in allSidePots) {
      if (pot.eligiblePlayers.length == 1) {
        autoAwardPots.add(pot);
      } else {
        contestedPots.add(pot);
      }
    }

    // Auto-award single-eligible pots (add chips back to that player's stack)
    for (final pot in autoAwardPots) {
      final winnerId = pot.eligiblePlayers.first;
      _gameState!.players[winnerId - 1].currentStack += pot.amount;
      _gameState!.currentPot -= pot.amount;
    }

    if (contestedPots.length > 1) {
      // Multiple contested pots - show multi-pot winner dialog
      await _showMultiPotWinnerDialog(contestedPots);
    } else {
      // Single pot (or no contested pots) - show regular winner selection
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

      if (!_isHandActive) return;

      // Immediately disable action buttons to prevent race conditions
      setState(() {
        _isCompletingHand = true;
      });

      try {
        // Step 1: Calculate total shares for ALL winners across ALL pots (for stack updates)
        final allShares = <int, double>{};
        double totalDistributed = 0.0;

        for (final potResult in potResults.values) {
          if (potResult['isChoppedPot'] == true) {
            final shares = potResult['individualShares'] as Map<int, double>;
            for (final entry in shares.entries) {
              allShares[entry.key] = (allShares[entry.key] ?? 0) + entry.value;
              totalDistributed += entry.value;
            }
          } else {
            final winner = potResult['winner'] as int;
            final amount = potResult['potAmount'] as double;
            allShares[winner] = (allShares[winner] ?? 0) + amount;
            totalDistributed += amount;
          }
        }

        // Step 2: Update ALL player stacks based on their winnings from all pots
        for (final entry in allShares.entries) {
          _gameState!.players[entry.key - 1].currentStack += entry.value;
        }

        // Step 3: For hand record, only use the MAIN POT winner(s)
        // This is consistent with poker rules: the main pot winner is THE winner of the hand
        final mainPotResult = potResults[0]!;
        final bool isMainPotChopped = mainPotResult['isChoppedPot'] == true;
        final List<int> mainPotWinners = isMainPotChopped
            ? List<int>.from(mainPotResult['winners'])
            : [mainPotResult['winner'] as int];
        final int primaryWinnerId = mainPotWinners.first;

        // Calculate shares for main pot winners only (for the hand record)
        Map<int, double>? mainPotShares;
        if (isMainPotChopped) {
          mainPotShares = <int, double>{};
          for (final winnerId in mainPotWinners) {
            mainPotShares[winnerId] = allShares[winnerId] ?? 0;
          }
        }

        // Step 4: Complete hand in session manager with main pot winner(s)
        if (isMainPotChopped) {
          _sessionManager!.completeCurrentHandWithChop(
            potAmount: totalDistributed,
            winnerIds: mainPotWinners,
            individualShares: mainPotShares,
            gameState: _gameState,
          );
        } else {
          _sessionManager!.completeCurrentHand(
            potAmount: totalDistributed,
            winnerId: primaryWinnerId,
            gameState: _gameState,
          );
        }

        // Step 5: Update DealerService
        await DealerService.completeHand(
          sessionId: _dealerSession.id,
          handId: _dealerSession.currentHandId ?? '',
          winnerId: primaryWinnerId,
          potAmount: totalDistributed,
          isChoppedPot: isMainPotChopped,
          choppedWinners: isMainPotChopped ? mainPotWinners : null,
          individualShares: mainPotShares,
          preflopPot: _gameState!.streetPots[BettingRound.preflop],
          flopPot: _gameState!.streetPots[BettingRound.flop],
          turnPot: _gameState!.streetPots[BettingRound.turn],
          riverPot: _gameState!.streetPots[BettingRound.river] ??
              (_gameState!.currentRound == BettingRound.river ? _gameState!.currentPot : null),
        );

        // Step 6: Emit WebSocket event
        final winnerName = _sessionManager!.getPlayerName(primaryWinnerId);
        final summary = isMainPotChopped
            ? 'Chop: ${mainPotWinners.map((id) => _sessionManager!.getPlayerName(id)).join(', ')} split ${_formatAmount(totalDistributed)}'
            : '$winnerName wins ${_formatAmount(totalDistributed)}';
        _wsService.emitHandCompleted(
          tableId: widget.table.id,
          sessionId: _dealerSession.id,
          handId: _dealerSession.currentHandId ?? '',
          winnerSeat: primaryWinnerId,
          potAmount: totalDistributed,
          summary: summary,
        );

        _showSuccess(summary);

        // Step 7: Check for busted players and prepare for next hand
        await _checkForBustedPlayers();
        _gameState!.startNewHand();
        await _updateSeatChipStacks();

        setState(() {
          _isHandActive = false;
          _isCompletingHand = false;
        });

        // Update cubit with hand-ended state
        _voiceCubit?.updateGameState(_gameState, _isHandActive);
      } catch (e) {
        setState(() {
          _isCompletingHand = false;
        });
        _showError('Failed to complete hand: ${e.toString()}');
      }
    }
  }

  Future<void> _completeHand(int winnerId) async {
    if (!_isHandActive) return;

    // Immediately disable action buttons to prevent race conditions
    setState(() {
      _isCompletingHand = true;
    });

    try {
      // Get winner's stack for tracking
      final winnerStack = _gameState!.getPlayerStack(winnerId) + _gameState!.currentPot;

      // Complete hand in session manager (saves to Firebase, updates stats)
      _sessionManager!.completeCurrentHand(
        potAmount: _gameState!.currentPot,
        winnerId: winnerId,
        currentStack: winnerStack,
        gameState: _gameState,
      );

      // Update winner's stack in game state
      _gameState!.players[winnerId - 1].currentStack += _gameState!.currentPot;

      // Update DealerService (for dealer_sessions collection)
      await DealerService.completeHand(
        sessionId: _dealerSession.id,
        handId: _dealerSession.currentHandId ?? '',
        winnerId: winnerId,
        potAmount: _gameState!.currentPot,
        preflopPot: _gameState!.streetPots[BettingRound.preflop],
        flopPot: _gameState!.streetPots[BettingRound.flop],
        turnPot: _gameState!.streetPots[BettingRound.turn],
        riverPot: _gameState!.streetPots[BettingRound.river] ??
            (_gameState!.currentRound == BettingRound.river ? _gameState!.currentPot : null),
      );

      // Emit WebSocket event
      final winnerName = _sessionManager!.getPlayerName(winnerId);
      _wsService.emitHandCompleted(
        tableId: widget.table.id,
        sessionId: _dealerSession.id,
        handId: _dealerSession.currentHandId ?? '',
        winnerSeat: winnerId,
        potAmount: _gameState!.currentPot,
        summary: '$winnerName wins ${_formatAmount(_gameState!.currentPot)}',
      );

      _showSuccess('$winnerName wins ${_formatAmount(_gameState!.currentPot)}');

      // Check for busted players BEFORE startNewHand() deactivates them
      // This allows the rebuy/remove dialog to appear while player is still marked active
      await _checkForBustedPlayers();

      // Now prepare for next hand (this will deactivate any remaining busted players)
      _gameState!.startNewHand();

      // Update seat chip stacks in Firebase
      await _updateSeatChipStacks();

      setState(() {
        _isHandActive = false;
        _isCompletingHand = false;
      });

      // Update cubit with hand-ended state
      _voiceCubit?.updateGameState(_gameState, _isHandActive);
    } catch (e) {
      setState(() {
        _isCompletingHand = false;
      });
      _showError('Failed to complete hand: ${e.toString()}');
    }
  }

  Future<void> _completeHandWithChop(List<int> winnerIds, Map<int, double>? shares) async {
    if (!_isHandActive) return;

    // Immediately disable action buttons to prevent race conditions
    setState(() {
      _isCompletingHand = true;
    });

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
        gameState: _gameState,
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
        preflopPot: _gameState!.streetPots[BettingRound.preflop],
        flopPot: _gameState!.streetPots[BettingRound.flop],
        turnPot: _gameState!.streetPots[BettingRound.turn],
        riverPot: _gameState!.streetPots[BettingRound.river] ??
            (_gameState!.currentRound == BettingRound.river ? _gameState!.currentPot : null),
      );

      // Emit WebSocket event
      final winnerNames = winnerIds.map((id) => _sessionManager!.getPlayerName(id)).join(', ');
      _wsService.emitHandCompleted(
        tableId: widget.table.id,
        sessionId: _dealerSession.id,
        handId: _dealerSession.currentHandId ?? '',
        winnerSeat: winnerIds.first,
        potAmount: _gameState!.currentPot,
        summary: 'Chop: $winnerNames split ${_formatAmount(_gameState!.currentPot)}',
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
        _isCompletingHand = false;
      });

      // Update cubit with hand-ended state
      _voiceCubit?.updateGameState(_gameState, _isHandActive);
    } catch (e) {
      setState(() {
        _isCompletingHand = false;
      });
      _showError('Failed to complete hand: ${e.toString()}');
    }
  }

  Future<void> _updateSeatChipStacks() async {
    // Collect all active player stacks for bulk update
    final playerStacks = <int, double>{};

    // Update chip stacks in Firebase for all active players
    for (int i = 1; i <= 9; i++) {
      if (_gameState!.players[i - 1].isActive) {
        final stack = _gameState!.players[i - 1].currentStack;
        final playerName = _sessionManager?.getPlayerName(i) ?? 'Player $i';

        // Add to collection for stack history tracking
        playerStacks[i] = stack;

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

    // Update stack history in dealer session for session analytics
    if (playerStacks.isNotEmpty) {
      try {
        await DealerService.updateAllPlayerStacks(
          sessionId: _dealerSession.id,
          playerStacks: playerStacks,
          handNumber: _dealerSession.currentHandNumber,
        );
      } catch (e) {
        // Ignore stack history update failures
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

        // Record rebuy in dealer session for analytics tracking
        try {
          await DealerService.recordRebuy(
            sessionId: _dealerSession.id,
            seatNumber: seatNumber,
            newStack: _rebuyStack,
          );
        } catch (e) {
          // Ignore rebuy tracking failures
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

        // Get playerId BEFORE removing from seat assignments (for participation tracking)
        final assignment = _seatAssignments[seatNumber];
        final bustedPlayerId = assignment?.playerId;

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

        // Update dealer session in Firestore (marks player as inactive)
        await DealerService.removePlayer(
          sessionId: _dealerSession.id,
          seatNumber: seatNumber,
        );

        // Remove from local seat assignments to keep in sync
        _seatAssignments.remove(seatNumber);

        // Mark participant as left for Session History hand filtering
        if (bustedPlayerId != null &&
            !bustedPlayerId.startsWith('manual_') &&
            _sessionManager!.sessionId != null) {
          await FirebaseService.markParticipantLeft(
            sessionId: _sessionManager!.sessionId!,
            participantId: bustedPlayerId,
            leftAtHand: _sessionManager!.completedHands.length,
          );
        }

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
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF101115),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1B1E24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning icon
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFF1B1E24),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFBD8F2D),
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              // Title
              Text(
                '$playerName Busted!',
                style: GoogleFonts.ibmPlexSans(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              // Description
              Text(
                'Seat $seatNumber has no chips remaining.\nRebuy amount: ${_rebuyStack.toStringAsFixed(0)}',
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSans(
                  color: const Color(0xFFD3FFFD),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              // Remove Player button (red, full width)
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, 'remove'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD55A41),
                      borderRadius: BorderRadius.circular(110),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Remove Player',
                      style: GoogleFonts.ibmPlexSans(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Rebuy button (outline, full width)
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, 'rebuy'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(110),
                      border: Border.all(color: const Color(0xFF4E5054)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Rebuy',
                      style: GoogleFonts.ibmPlexSans(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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

  /// Show dialog to confirm dealer change/handoff
  Future<void> _showDealerChangeDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF101115),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1B1E24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon + title
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1B1E24),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.swap_vert,
                      color: Color(0xFFBD8F2D),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Dealer Change',
                      style: GoogleFonts.ibmPlexSans(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'The session will be paused and another dealer can scan the table QR code to continue where you left off.',
                style: GoogleFonts.ibmPlexSans(
                  color: const Color(0xFFD3FFFD),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'All players, blinds, and game state will be preserved.',
                style: GoogleFonts.ibmPlexSans(
                  color: const Color(0xFFD3FFFD),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'You can also resume this session yourself later.',
                style: GoogleFonts.ibmPlexSans(
                  color: const Color(0xFFD3FFFD),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.ibmPlexSans(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFBD8F2D),
                        borderRadius: BorderRadius.circular(60),
                      ),
                      child: Text(
                        'Hand Off',
                        style: GoogleFonts.ibmPlexSans(
                          color: Colors.black,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await _executeDealerChange();
    }
  }

  /// Execute dealer change - pause session and exit
  Future<void> _executeDealerChange() async {
    try {
      // Pause the session (preserves all state)
      await DealerService.pauseSession(_dealerSession.id);

      // Navigate back to dealer home
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session paused. Another dealer can now take over.'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Failed to pause session: $e');
    }
  }

  /// Handle event completion or cancellation by club admin
  Future<void> _handleEventEnded(EventStatus? status) async {
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

    // End session BEFORE navigation to prevent dispose() issues
    // This fixes the auto-logout bug when admin ends event
    if (_sessionManager != null &&
        _sessionManager!.sessionState == SessionState.active) {
      try {
        await _sessionManager!.endSession();
      } catch (e) {
        print('Error ending session during event end: $e');
      }
      _sessionStarted = false;
    }

    final title = status == EventStatus.cancelled ? 'Event Cancelled' : 'Event Finished';
    final message = status == EventStatus.cancelled
        ? 'The club admin has cancelled this event. All sessions have been saved.'
        : 'The club admin has finished this event. All sessions have been saved.';

    if (!mounted) return;

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
              // Pop until first route (club home) to avoid going back to event_detail_screen
              Navigator.of(context).popUntil((route) => route.isFirst);
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
    final controller = TextEditingController();

    return showDialog<double>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF101115),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1B1E24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w500),
                autofocus: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF02050B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4E5054))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4E5054))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF89F1EC))),
                  prefixText: _isTournament ? null : '\$',
                  prefixStyle: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C), fontSize: 17),
                  hintText: '0',
                  hintStyle: GoogleFonts.ibmPlexSans(color: const Color(0xFF4E5054), fontSize: 17),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        child: Text('Cancel', style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  GestureDetector(
                    onTap: () => Navigator.pop(context, double.tryParse(controller.text)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF89F1EC),
                        borderRadius: BorderRadius.circular(60),
                      ),
                      child: Text('Confirm', style: GoogleFonts.ibmPlexSans(color: Colors.black, fontSize: 17, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  /// Ask user to confirm leaving the dealer screen. Returns true if they confirm.
  Future<bool> _confirmExit() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF101115),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1B1E24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Leave dealer table?',
                style: GoogleFonts.ibmPlexSans(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isHandActive
                    ? 'A hand is currently in progress. Leaving now may disrupt logging.'
                    : 'The session stays live. You can return any time.',
                style: GoogleFonts.ibmPlexSans(
                  color: const Color(0xFFD3FFFD),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.ibmPlexSans(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF89F1EC),
                        borderRadius: BorderRadius.circular(60),
                      ),
                      child: Text(
                        'Leave',
                        style: GoogleFonts.ibmPlexSans(
                          color: Colors.black,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
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
    // Use event's starting stack if available, otherwise default to 100BB
    double defaultStack = _rebuyStack > 0 ? _rebuyStack : (_dealerSession.bigBlind * 100.0);

    // For event sessions, auto-restore the player's last stack from a previous table
    // (table break scenario — player is reseating with their existing chips)
    if (_dealerSession.eventId != null && pending.playerId != null) {
      final lastStack = await DealerService.getPlayerLastStack(
        eventId: _dealerSession.eventId!,
        playerId: pending.playerId!,
      );
      if (lastStack != null && lastStack > 0) {
        defaultStack = lastStack;
      }
    }

    final controller = TextEditingController(
      text: defaultStack.toInt().toString(),
    );

    final chipStack = await showDialog<double>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF101115),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1B1E24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Approve ${pending.playerName ?? 'Player'}?',
                style: GoogleFonts.ibmPlexSans(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: GoogleFonts.ibmPlexSans(
                  color: const Color(0xFF8C8C8C),
                  fontSize: 17,
                ),
                decoration: InputDecoration(
                  labelText: 'Starting Chip Stack',
                  labelStyle: GoogleFonts.ibmPlexSans(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF4E5054)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF89F1EC)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 32),
              // Approve button (full width, mint)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final stack = double.tryParse(controller.text);
                    if (stack != null && stack > 0) {
                      Navigator.pop(dialogContext, stack);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF89F1EC),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(110)),
                  ),
                  child: Text('Approve', style: GoogleFonts.ibmPlexSans(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
                ),
              ),
              const SizedBox(height: 14),
              // Cancel + Reject row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(110)),
                      ),
                      child: Text('Cancel', style: GoogleFonts.ibmPlexSans(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await SeatService.rejectJoin(
                            clubId: widget.club.id,
                            tableId: widget.table.id,
                            seatNumber: pending.seatNumber,
                          );
                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                          _showSuccess('${pending.playerName} rejected');
                        } catch (e) {
                          _showError('Failed to reject: ${e.toString()}');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD55A41),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(110)),
                      ),
                      child: Text('Reject', style: GoogleFonts.ibmPlexSans(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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

        // Track participant in poker_sessions for Session History visibility
        // Only for registered Firebase users (not manual players)
        final playerId = pending.playerId;
        if (playerId != null && !playerId.startsWith('manual_')) {
          if (_sessionManager!.sessionId != null) {
            await FirebaseService.addSessionParticipant(
              sessionId: _sessionManager!.sessionId!,
              participantId: playerId,
              joinedAtHand: _sessionManager!.completedHands.length + 1,
            );
          } else {
            // Session not started yet, queue for when it starts
            _pendingParticipants.add(playerId);
          }
        }

        _showSuccess('${pending.playerName} joined with ${_formatAmount(chipStack)}');
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
          _showSuccess('Updated ${playerName ?? 'player'} stack to ${_formatAmount(newStack)}');
        } catch (e) {
          _showError('Failed to update stack: ${e.toString()}');
        }
      }
    }
  }

  /// Handle tap on empty seat - show choice to add player or sit as dealer
  Future<void> _onEmptySeatTap(int seatNumber) async {
    // If dealer is already playing at another seat, just add player
    if (_dealerPlayingSeat != null) {
      _showAddPlayerDialog(seatNumber);
      return;
    }

    // Show choice dialog
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF101115),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1B1E24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'Seat $seatNumber',
                style: GoogleFonts.ibmPlexSans(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 20),
              // Add Player option
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(context, 'add_player'),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1B1E24),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_add, color: Color(0xFF89F1EC), size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Player',
                            style: GoogleFonts.ibmPlexSans(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Seat another player here',
                            style: GoogleFonts.ibmPlexSans(
                              color: const Color(0xFF8C8C8C),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(color: Color(0xFF1B1E24), height: 1),
              ),
              // Sit Here option
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(context, 'dealer_play'),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1B1E24),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.casino, color: Color(0xFFBD8F2D), size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sit Here',
                            style: GoogleFonts.ibmPlexSans(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Join the game as dealer-player',
                            style: GoogleFonts.ibmPlexSans(
                              color: const Color(0xFF8C8C8C),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Cancel button
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.ibmPlexSans(
                        color: const Color(0xFF8C8C8C),
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (choice == 'add_player') {
      _showAddPlayerDialog(seatNumber);
    } else if (choice == 'dealer_play') {
      _seatDealerAsPlayer(seatNumber);
    }
  }

  /// Seat the dealer as a player at the table
  Future<void> _seatDealerAsPlayer(int seatNumber) async {
    // Show stack input dialog - use event's starting stack if available
    final defaultStack = _rebuyStack > 0 ? _rebuyStack : (_dealerSession.bigBlind * 100.0);
    final stack = await _showStackInputDialog(
      defaultStack: defaultStack,
    );
    if (stack == null) return;

    try {
      final dealerId = AuthService.userId!;
      final dealerName = AuthService.userDisplayName ?? 'Dealer';

      // Seat dealer using same flow as registered user
      await SeatService.seatUserDirectly(
        clubId: widget.club.id,
        tableId: widget.table.id,
        seatNumber: seatNumber,
        playerId: dealerId,
        playerName: dealerName,
        chipStack: stack,
      );

      // Add to dealer session players map
      await DealerService.addPlayer(
        sessionId: _dealerSession.id,
        odPlayerId: dealerId,
        displayName: dealerName,
        seatNumber: seatNumber,
        initialStack: stack,
      );

      // Update local state
      _dealerPlayingSeat = seatNumber;
      _gameState!.setPlayerStack(seatNumber, stack);
      _gameState!.setPlayerActive(seatNumber, true);
      _sessionManager!.activeSeats.add(seatNumber);
      _sessionManager!.setPlayerName(seatNumber, dealerName);
      _sessionManager!.setPlayerStack(seatNumber, stack);
      // Set ourSeatNumber so stack tracking works for Avg Growth calculation
      _sessionManager!.ourSeatNumber = seatNumber;

      // Update playerIds map to include dealer
      _sessionManager!.setPlayerIds(_getPlayerIdsMap());

      // Track dealer as participant in poker_sessions for Session History visibility
      if (_sessionManager!.sessionId != null) {
        await FirebaseService.addSessionParticipant(
          sessionId: _sessionManager!.sessionId!,
          participantId: dealerId,
          joinedAtHand: _sessionManager!.completedHands.length + 1,
        );
      } else {
        // Session not started yet, queue for when it starts
        _pendingParticipants.add(dealerId);
      }

      setState(() {});
      _showSuccess('You are now playing at Seat $seatNumber');
    } catch (e) {
      _showError('Failed to sit at table: ${e.toString()}');
    }
  }

  /// Show dialog to input stack size
  Future<double?> _showStackInputDialog({required double defaultStack}) async {
    final controller = TextEditingController(text: defaultStack.toStringAsFixed(0));

    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PokerFriendColors.dark3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Enter Starting Stack', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            filled: true,
            fillColor: PokerFriendColors.dark5,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (value) {
            final parsed = double.tryParse(value);
            if (parsed != null && parsed > 0) {
              Navigator.pop(context, parsed);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text);
              if (parsed != null && parsed > 0) {
                Navigator.pop(context, parsed);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: PokerFriendColors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddPlayerDialog(int seatNumber) async {
    // Use event's starting stack if available
    final defaultStack = _rebuyStack > 0 ? _rebuyStack : (_dealerSession.bigBlind * 100.0);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _UserSearchDialog(
        seatNumber: seatNumber,
        defaultStack: defaultStack,
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

          // Track participant in poker_sessions for Session History visibility
          if (_sessionManager!.sessionId != null) {
            await FirebaseService.addSessionParticipant(
              sessionId: _sessionManager!.sessionId!,
              participantId: playerId,
              joinedAtHand: _sessionManager!.completedHands.length + 1,
            );
          } else {
            // Session not started yet, queue for when it starts
            _pendingParticipants.add(playerId);
          }
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
          // Note: Manual players don't get tracked in participantIds (no Firebase account)
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
      // Get player ID before removing (for participation tracking)
      final assignment = _seatAssignments[seatNumber];
      final playerId = assignment?.playerId;

      await SeatService.removeSeatOccupant(
        clubId: widget.club.id,
        tableId: widget.table.id,
        seatNumber: seatNumber,
      );

      // Update dealer session in Firestore (marks player as inactive)
      await DealerService.removePlayer(
        sessionId: _dealerSession.id,
        seatNumber: seatNumber,
      );

      // Update local game state
      _gameState!.setPlayerActive(seatNumber, false);
      _gameState!.setPlayerStack(seatNumber, 0);
      _sessionManager!.activeSeats.remove(seatNumber);
      _sessionManager!.playerStacks.remove(seatNumber);

      // Clear dealer playing seat if this was the dealer
      if (seatNumber == _dealerPlayingSeat) {
        _dealerPlayingSeat = null;
      }

      // Update playerIds map
      _sessionManager!.setPlayerIds(_getPlayerIdsMap());

      // Mark participant as left in poker_sessions for Session History filtering
      // Only for registered Firebase users (not manual players)
      if (playerId != null &&
          !playerId.startsWith('manual_') &&
          _sessionManager!.sessionId != null) {
        await FirebaseService.markParticipantLeft(
          sessionId: _sessionManager!.sessionId!,
          participantId: playerId,
          leftAtHand: _sessionManager!.completedHands.length,
        );
      }

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
        backgroundColor: const Color(0xFF02050B),
        appBar: AppBar(
          backgroundColor: const Color(0xFF101115),
          title: Text(widget.table.name, style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600)),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF89F1EC)),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _confirmExit();
        if (shouldExit && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      backgroundColor: const Color(0xFF02050B),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: SafeArea(
          bottom: false,
          child: Container(
            color: const Color(0xFF101115),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                // Back button
                _buildHeaderPillButton(
                  bgColor: const Color(0xFF101115),
                  onTap: () async {
                    final shouldExit = await _confirmExit();
                    if (shouldExit && mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                // Title
                Expanded(
                  child: Text(
                    widget.table.name,
                    style: GoogleFonts.ibmPlexSans(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                      height: 1.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // QR button
                _buildHeaderPillButton(
                  bgColor: const Color(0xFF1B1E24),
                  onTap: _showQRCodesDialog,
                  child: const Icon(Icons.qr_code, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 8),
                // Dealer change button (swap arrows)
                _buildHeaderPillButton(
                  bgColor: const Color(0xFF1B1E24),
                  onTap: _showDealerChangeDialog,
                  child: const Icon(Icons.swap_vert, color: Color(0xFFBD8F2D), size: 24),
                ),
                const SizedBox(width: 8),
                // End session button (red dot)
                _buildHeaderPillButton(
                  bgColor: const Color(0xFF1B1E24),
                  onTap: _endSession,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFD55A41), width: 1.2),
                    ),
                    child: Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD55A41),
                          shape: BoxShape.rectangle,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildGameInfo(),
          Expanded(child: _buildTableView()),
          if (_isHandActive) _buildActionButtons(),
          if (!_isHandActive) _buildStartHandSection(),
        ],
      ),
    ),
    );
  }

  Widget _buildHeaderPillButton({
    required Color bgColor,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Center(child: child),
      ),
    );
  }

  Widget _buildGameInfo() {
    // For small amounts show decimal (e.g. $0.00), for larger use compact form (e.g. $1.2k)
    final pot = _gameState!.currentPot;
    final isCash = _dealerSession.gameType == 'cash';
    final potDisplay = pot < 10000
        ? (isCash ? '\$${pot.toStringAsFixed(2)}' : pot.toStringAsFixed(0))
        : _formatAmount(pot);
    return Container(
      color: const Color(0xFF101115),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: _buildInfoItem(
              label: 'POT',
              value: potDisplay,
              labelColor: const Color(0xFF7C8125),
              valueColor: const Color(0xFFF3FF15),
            ),
          ),
          _buildStatusDivider(),
          Expanded(
            child: _buildInfoItem(
              label: 'STREET',
              value: _gameState!.currentRound.name.toUpperCase(),
              labelColor: const Color(0xFF6388A5),
              valueColor: const Color(0xFF97CBF3),
            ),
          ),
          _buildStatusDivider(),
          Expanded(
            child: GestureDetector(
              onTap: _showChangeBlindsDialog,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'BLINDS',
                          style: GoogleFonts.ibmPlexSans(
                            color: const Color(0xFF4B9A96),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.44,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF35373C),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF3C4D59), width: 0.5),
                          ),
                          child: const Icon(Icons.edit, color: Color(0xFF89F1EC), size: 9),
                        ),
                      ],
                    ),
                    Text(
                      '$_smallBlind/$_bigBlind',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSans(
                        color: const Color(0xFF89F1EC),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.64,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildStatusDivider(),
          Expanded(
            child: _buildInfoItem(
              label: 'HAND',
              value: '#${_gameState!.handNumber}',
              labelColor: const Color(0xFF8C8C8C),
              valueColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDivider() {
    return Container(
      width: 1,
      height: 38,
      color: const Color(0xFF1B1E24),
    );
  }

  Widget _buildInfoItem({
    required String label,
    required String value,
    required Color labelColor,
    required Color valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSans(
              color: labelColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.44,
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.ibmPlexSans(
              color: valueColor,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.64,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangeBlindsDialog() async {
    final smallBlindController = TextEditingController(text: _smallBlind.toString());
    final bigBlindController = TextEditingController(text: _bigBlind.toString());

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF101115),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1B1E24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Update Blinds',
                style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF02050B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF1B1E24)),
                      ),
                      child: Column(
                        children: [
                          Text('Small Blind', style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 14)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: smallBlindController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w500),
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4E5054))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4E5054))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF89F1EC))),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF02050B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF1B1E24)),
                      ),
                      child: Column(
                        children: [
                          Text('Big Blind', style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 14)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: bigBlindController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w500),
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4E5054))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4E5054))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF89F1EC))),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'New blinds will apply from the next hand.',
                style: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C), fontSize: 12, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        child: Text('Cancel', style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  GestureDetector(
                    onTap: () {
                      final newSmallBlind = int.tryParse(smallBlindController.text) ?? _smallBlind;
                      final newBigBlind = int.tryParse(bigBlindController.text) ?? _bigBlind;

                      if (newSmallBlind >= newBigBlind) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Small blind must be less than big blind'), backgroundColor: Colors.red),
                        );
                        return;
                      }
                      if (newSmallBlind <= 0 || newBigBlind <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Blinds must be greater than 0'), backgroundColor: Colors.red),
                        );
                        return;
                      }
                      Navigator.pop(context, {'smallBlind': newSmallBlind, 'bigBlind': newBigBlind});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF89F1EC),
                        borderRadius: BorderRadius.circular(60),
                      ),
                      child: Text('Update', style: GoogleFonts.ibmPlexSans(color: Colors.black, fontSize: 17, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
    return Stack(
      children: [
        PokerTableWidget(
          activeSeatMap: _getActiveSeatMapForTable(),
          showDealerButton: false, // Dealer button is managed inside custom seats
          tableWidthFraction: 0.78,
          tableHeightFraction: 0.78,
          seatBuilder: (seatNumber, isActive) => _buildDealerSeatWidget(seatNumber),
          centerContent: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatAmount(_gameState!.currentPot),
                style: GoogleFonts.ibmPlexSans(
                  color: const Color(0xFFD3FFFD),
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.59,
                  height: 1.0,
                ),
              ),
              Text(
                'POT',
                style: GoogleFonts.ibmPlexSans(
                  color: const Color(0xFF5EB7B3),
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  height: 1.44,
                ),
              ),
            ],
          ),
        ),
        // Rollback/Undo button - bottom right with fade effect
        Positioned(
          bottom: 20,
          right: 20,
          child: AnimatedOpacity(
            opacity: _canUndoLastAction() ? 0.85 : 0.3,
            duration: const Duration(milliseconds: 300),
            child: GestureDetector(
              onTap: _canUndoLastAction() ? _undoLastAction : null,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _canUndoLastAction()
                        ? Colors.orange.withValues(alpha: 0.6)
                        : Colors.white24,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.undo_rounded,
                  color: _canUndoLastAction()
                      ? Colors.orange.shade300
                      : Colors.white38,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Map<int, bool> _getActiveSeatMapForTable() {
    final map = <int, bool>{};
    for (int i = 1; i <= 9; i++) {
      final assignment = _seatAssignments[i];
      final isOccupied = assignment?.isOccupied ?? false;
      final isPending = assignment?.isPending ?? false;
      final playerState = _gameState!.players[i - 1];
      map[i] = isOccupied || isPending || playerState.isActive;
    }
    return map;
  }

  Widget _buildDealerSeatWidget(int seatNumber) {
    final assignment = _seatAssignments[seatNumber];
    final isOccupied = assignment?.isOccupied ?? false;
    final isPending = assignment?.isPending ?? false;
    final playerState = _gameState!.players[seatNumber - 1];
    final isFolded = playerState.hasFolded;
    final isCurrentPlayer = seatNumber == _gameState!.currentPlayer && _isHandActive;
    final isButton = seatNumber == _gameState!.buttonPosition;
    final stack = playerState.currentStack;
    final bet = playerState.betThisRound;

    return _buildSeat(
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
          ? () => _onEmptySeatTap(seatNumber)
          : null,
      canAcceptButtonDrop: !_isHandActive,
      onButtonDropped: _onButtonDroppedOnSeat,
    );
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
    // Determine circle border color based on state
    Color borderColor;
    if (isPending) {
      borderColor = const Color(0xFFF59E0B);
    } else if (!isOccupied) {
      borderColor = const Color(0xFF1B4341);
    } else if (isFolded) {
      borderColor = const Color(0xFF89F1EC).withValues(alpha: 0.3);
    } else if (isCurrentPlayer) {
      borderColor = Colors.amber;
    } else {
      borderColor = const Color(0xFF89F1EC);
    }

    // Seat number pill (compact 38×33, black bg, colored border)
    final seatCirclePill = Container(
      width: 38,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(42.6),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: isCurrentPlayer
            ? [BoxShadow(color: Colors.amber.withValues(alpha: 0.4), blurRadius: 10)]
            : (isPending
                ? [BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), blurRadius: 10)]
                : null),
      ),
      child: Text(
        seatNumber.toString(),
        textAlign: TextAlign.center,
        style: GoogleFonts.ibmPlexMono(
          color: isOccupied ? Colors.white : const Color(0xFF67696D),
          fontSize: 17,
          fontWeight: FontWeight.w500,
          height: 1.0,
        ),
      ),
    );

    // Player name + balance label (shown when occupied OR for empty-preview)
    final displayName = _truncateName(playerName ?? 'Player');
    final labelColumn = Column(
      crossAxisAlignment: _seatLabelIsRight(seatNumber) ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isPending) ...[
          Text(
            displayName,
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.44,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'PENDING',
            style: GoogleFonts.ibmPlexSans(
              color: Colors.orange,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.44,
            ),
          ),
        ] else if (isOccupied) ...[
          Text(
            displayName,
            style: GoogleFonts.ibmPlexSans(
              color: isFolded ? Colors.white38 : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.44,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            _formatAmount(stack),
            style: GoogleFonts.ibmPlexSans(
              color: isFolded ? Colors.white38 : const Color(0xFF89F1EC),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.44,
            ),
          ),
        ],
        // Bet pill (blue #4C94FF) — hidden for folded players
        if (bet > 0 && !isFolded) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF4C94FF),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              _formatAmount(bet),
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                height: 1.44,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );

    // Choose layout: pill + label side-by-side (right or left) or stacked (top)
    final layoutVariant = _seatLayoutVariant(seatNumber);
    Widget seatContent;

    if (isOccupied || isPending) {
      if (layoutVariant == 'top') {
        // Seat 1: pill on top, label below
        seatContent = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            seatCirclePill,
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (isPending) ...[
                    Text(
                      displayName,
                      style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500, height: 1.44),
                    ),
                    Text('PENDING', style: GoogleFonts.ibmPlexSans(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.w600, height: 1.44)),
                  ] else if (isOccupied) ...[
                    Text(
                      displayName,
                      style: GoogleFonts.ibmPlexSans(color: isFolded ? Colors.white38 : Colors.white, fontSize: 11, fontWeight: FontWeight.w500, height: 1.44),
                    ),
                    Text(
                      _formatAmount(stack),
                      style: GoogleFonts.ibmPlexSans(color: isFolded ? Colors.white38 : const Color(0xFF89F1EC), fontSize: 12, fontWeight: FontWeight.w500, height: 1.44),
                    ),
                  ],
                  if (bet > 0 && !isFolded) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                      decoration: BoxDecoration(color: const Color(0xFF4C94FF), borderRadius: BorderRadius.circular(30)),
                      child: Text(
                        _formatAmount(bet),
                        style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500, height: 1.44),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      } else if (layoutVariant == 'right') {
        // Label on the right of the pill (seats on left side of table: 6-9)
        seatContent = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            seatCirclePill,
            const SizedBox(width: 4),
            labelColumn,
          ],
        );
      } else {
        // Label on the left of the pill (seats on right side of table: 2-5)
        seatContent = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            labelColumn,
            const SizedBox(width: 4),
            seatCirclePill,
          ],
        );
      }
    } else {
      // Empty seat: just the pill
      seatContent = seatCirclePill;
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

    // Stack for pending/button badges overlaid on the pill
    final pillWithBadges = Stack(
      clipBehavior: Clip.none,
      children: [
        seatContent,
        // Pending badge (on the pill)
        if (isPending)
          Positioned(
            left: layoutVariant == 'left' ? null : -4,
            right: layoutVariant == 'left' ? -4 : null,
            top: -4,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Center(child: Icon(Icons.person_add, size: 10, color: Colors.white)),
            ),
          ),
        // Dealer button (on the pill)
        if (isButton && !isPending)
          Positioned(
            left: layoutVariant == 'left' ? null : -10,
            right: layoutVariant == 'left' ? -10 : null,
            top: -10,
            child: canAcceptButtonDrop
                ? Draggable<int>(
                    data: seatNumber,
                    feedback: Material(
                      color: Colors.transparent,
                      child: dealerButtonBadge(),
                    ),
                    childWhenDragging: const Padding(
                      padding: EdgeInsets.all(4),
                      child: SizedBox(width: 22, height: 22),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: dealerButtonBadge(),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(4),
                    child: dealerButtonBadge(),
                  ),
          ),
      ],
    );

    final seatWidget = GestureDetector(
      onTap: isPending
          ? onPendingTap
          : (isOccupied && _isHandActive && !isFolded
              ? () => setState(() => _gameState!.currentPlayer = seatNumber)
              : (isOccupied && !_isHandActive
                  ? onOccupiedTap
                  : (!isOccupied ? onEmptyTap : null))),
      behavior: HitTestBehavior.opaque,
      child: pillWithBadges,
    );

    // Wrap with DragTarget to accept button drops
    if (canAcceptButtonDrop && onButtonDropped != null) {
      return DragTarget<int>(
        onAcceptWithDetails: (details) {
          onButtonDropped(seatNumber);
        },
        builder: (context, candidateData, rejectedData) {
          final isHovered = candidateData.isNotEmpty;
          if (isHovered) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(42.6),
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

  /// Get the layout variant for a seat (matches PokerTableWidget logic).
  /// - 'top': seat 1 (label below pill)
  /// - 'right': seats 6-9 (left side of table → label to right of pill)
  /// - 'left': seats 2-5 (right side of table → label to left of pill)
  String _seatLayoutVariant(int seatNumber) {
    if (seatNumber == 1) return 'top';
    if (seatNumber >= 6 && seatNumber <= 9) return 'right';
    return 'left';
  }

  bool _seatLabelIsRight(int seatNumber) => _seatLayoutVariant(seatNumber) == 'right';

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
      decoration: const BoxDecoration(
        color: Color(0xFF101115),
        border: Border(top: BorderSide(color: Color(0xFF1C1F21))),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Voice status bar (shown when voice is active)
            if (_isVoiceMode && _voiceState == VoiceSessionState.dealerLocked)
              _buildVoiceStatusBar(),
            // Show calibration/connection UI only as fallback
            if (_isVoiceMode && _voiceState == VoiceSessionState.calibrating)
              _buildCalibrationUI(),
            if (_isVoiceMode && _voiceState == VoiceSessionState.connectionLost)
              _buildConnectionLostUI(),
            if (_isVoiceMode && (_voiceState == VoiceSessionState.dealerLocked ||
                _voiceState == VoiceSessionState.calibrating ||
                _voiceState == VoiceSessionState.connectionLost))
              const SizedBox(height: 12),
            // Player info row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF89F1EC).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$playerName to act (${_formatAmount(playerStack)})',
                style: GoogleFonts.ibmPlexSans(color: const Color(0xFF89F1EC), fontSize: 14, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            // Action buttons - always visible
            Row(
              children: [
                _buildActionButton('FOLD', const Color(0xFF3D1C1C), const Color(0xFFE55353),
                    () => _performAction(PlayerAction.fold)),
                const SizedBox(width: 8),
                if (canCheck)
                  _buildActionButton('CHECK', const Color(0xFF1C2E3D), const Color(0xFF89F1EC),
                      () => _performAction(PlayerAction.check))
                else if (canCall)
                  _buildActionButton('CALL\n${_formatAmount(callAmount)}', const Color(0xFF1C3D2A), const Color(0xFF54E98A),
                      () => _performAction(PlayerAction.call)),
                const SizedBox(width: 8),
                if (canBet)
                  _buildActionButton('BET', const Color(0xFF1B4341), const Color(0xFF89F1EC), () async {
                    final amount = await _showAmountDialog('Bet amount');
                    if (amount != null && amount > 0) {
                      await _performAction(PlayerAction.bet, amount: amount);
                    }
                  })
                else if (canRaise)
                  _buildActionButton('RAISE', const Color(0xFF1B4341), const Color(0xFF89F1EC), () async {
                    final amount = await _showAmountDialog('Raise to');
                    if (amount != null && amount > 0) {
                      await _performAction(PlayerAction.raise, amount: amount);
                    }
                  }),
                const SizedBox(width: 8),
                _buildActionButton('ALL IN', const Color(0xFF2D1C3D), const Color(0xFFB589F1), () async {
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

  /// Compact voice status bar - shows listening/paused state with pause toggle
  Widget _buildVoiceStatusBar() {
    final isPaused = _voiceCubit?.isHoldActive ?? false;
    final dealerInfo = _lockedDealerName != null
        ? '${_lockedDealerName}${_lockedTableName != null ? ' • $_lockedTableName' : ''}'
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isPaused ? Colors.amber.shade800 : Colors.green.shade800,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Status icon
          Icon(
            isPaused ? Icons.pause : Icons.mic,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          // Status text + dealer info + partial transcript
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      isPaused ? 'Paused' : 'Listening',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (dealerInfo != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '($dealerInfo)',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
                if (_partialTranscript.isNotEmpty)
                  Text(
                    '"$_partialTranscript"',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Pause/Resume button
          IconButton(
            icon: Icon(
              isPaused ? Icons.play_arrow : Icons.pause,
              color: Colors.white,
            ),
            onPressed: () {
              _voiceCubit?.toggleHold();
              setState(() {});
            },
            tooltip: isPaused ? 'Resume Voice' : 'Pause Voice',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  /// Build calibration UI - waiting for dealer to announce (fallback for connection loss)
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

  /// Build connection lost UI (fallback for reconnection)
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

  /// Start continuous listening using real-time WebSocket streaming
  Future<void> _startContinuousListening() async {
    try {
      // Update cubit with current game state before starting
      _voiceCubit?.updateGameState(_gameState, _isHandActive);

      // Subscribe to partial stream for UI display
      _partialSubscription?.cancel();
      _partialSubscription = _realtimeSpeechService.partialStream.listen(
        (partial) {
          if (mounted) {
            setState(() => _partialTranscript = partial);
          }
        },
        onError: (e) {},
      );

      // Subscribe to status stream for calibration/connection state
      _statusSubscription?.cancel();
      _statusSubscription = _realtimeSpeechService.statusStream.listen(
        (status) {
          if (mounted) {
            setState(() {
              _connectionStatus = status;
              _voiceState = _realtimeSpeechService.state;
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

      // Start the voice cubit (handles SonioxService and SpeechBuffer)
      await _voiceCubit?.startListening();

      if (mounted) {
        setState(() {
          _isListening = _voiceCubit?.state.status != VoiceStatus.disabled;
          _voiceState = _realtimeSpeechService.state;
        });
      }

      if (_voiceCubit?.state.status == VoiceStatus.error) {
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
    // Stop the voice cubit (handles SonioxService and cleanup)
    await _voiceCubit?.stopListening();

    // Cancel subscriptions
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
    });
  }

  Widget _buildActionButton(String label, Color bgColor, Color borderColor, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildStartHandSection() {
    final occupiedSeats = _gameState!.getActivePlayers().length;
    final canStart = occupiedSeats >= 2 && !_isLoading;
    final hasDealtHand = _gameState!.handNumber > 1;
    final buttonLabel = hasDealtHand ? 'Start New Hand' : 'Start Session';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Primary block: Start Session button + player count
          GestureDetector(
            onTap: canStart ? _startNewHand : null,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              decoration: BoxDecoration(
                color: canStart ? const Color(0xFF89F1EC) : const Color(0xFF4B9A96),
                borderRadius: BorderRadius.circular(110),
              ),
              child: _isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      ),
                    )
                  : Text(
                      buttonLabel,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                        letterSpacing: -0.5,
                        height: 24 / 17,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$occupiedSeats players selected',
            style: GoogleFonts.ibmPlexSans(
              color: const Color(0xFF4B9A96),
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 24 / 15,
            ),
          ),
          const SizedBox(height: 18),
          // Secondary block: Add Test Players + warning
          GestureDetector(
            onTap: _addRandomPlayersForTesting,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(110),
                border: Border.all(color: const Color(0xFFD3FFFD), width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add, color: Color(0xFFD3FFFD), size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Add Test Players',
                    style: GoogleFonts.ibmPlexSans(
                      color: const Color(0xFFD3FFFD),
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                      height: 24 / 17,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (occupiedSeats < 2) ...[
            const SizedBox(height: 8),
            Text(
              'Need at least 2 players to start',
              style: GoogleFonts.ibmPlexSans(
                color: const Color(0xFFBD8F2D),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 24 / 14,
              ),
            ),
          ],
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
    // Use event's starting stack if available
    final defaultStack = _rebuyStack > 0 ? _rebuyStack : (_dealerSession.bigBlind * 100.0);

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

  // ============== UNDO/ROLLBACK FUNCTIONALITY ==============

  /// Check if we can undo the last action
  bool _canUndoLastAction() {
    if (_gameState == null || _sessionManager == null) return false;
    if (_sessionManager!.currentHand == null) return false;
    if (_sessionManager!.currentHand!.actions.isEmpty) return false;
    if (_gameState!.bettingRoundComplete) return false;
    if (!_isHandActive) return false;

    // Find last non-blind action
    final actions = _sessionManager!.currentHand!.actions;
    for (int i = actions.length - 1; i >= 0; i--) {
      final action = actions[i];
      if (action.action != PlayerAction.none) {
        return true;
      }
    }
    return false;
  }

  /// Undo the last action - restores chips, pot, and player state
  void _undoLastAction() {
    if (!_canUndoLastAction()) return;

    final actions = _sessionManager!.currentHand!.actions;

    // Find last non-blind action
    int lastActionIndex = -1;
    for (int i = actions.length - 1; i >= 0; i--) {
      if (actions[i].action != PlayerAction.none) {
        lastActionIndex = i;
        break;
      }
    }

    if (lastActionIndex == -1) return;

    final lastAction = actions[lastActionIndex];
    final seatNumber = lastAction.player;
    final player = _gameState!.players[seatNumber - 1];

    // Restore based on action type
    switch (lastAction.action) {
      case PlayerAction.fold:
        player.hasFolded = false;
        player.hasActed = false;
        player.hasCalledCurrentBet = false;
        player.lastAction = PlayerAction.none;
        break;

      case PlayerAction.check:
        player.hasActed = false;
        player.hasCalledCurrentBet = false;
        player.lastAction = PlayerAction.none;
        _recalculateAllPlayersCallStatus(lastActionIndex);
        break;

      case PlayerAction.call:
        final callAmount = lastAction.amount ?? 0;
        final previousCallBet = _getPreviousBetThisRound(seatNumber, lastActionIndex);
        final callAdditional = callAmount - previousCallBet;

        if (callAdditional > 0) {
          player.currentStack += callAdditional;
          player.isAllIn = false;
          player.betThisRound = previousCallBet;
          _gameState!.currentPot -= callAdditional;
          if (_gameState!.currentPot < 0) _gameState!.currentPot = 0;
        }

        player.hasActed = false;
        player.hasCalledCurrentBet = false;
        player.lastAction = PlayerAction.none;
        break;

      case PlayerAction.bet:
      case PlayerAction.raise:
        final betAmount = lastAction.amount ?? 0;
        final previousBet = _getPreviousBetThisRound(seatNumber, lastActionIndex);
        final additionalAmount = betAmount - previousBet;

        if (additionalAmount > 0) {
          player.currentStack += additionalAmount;
          player.isAllIn = false;
          player.betThisRound = previousBet;
          _gameState!.currentPot -= additionalAmount;
          if (_gameState!.currentPot < 0) _gameState!.currentPot = 0;
        }

        player.hasActed = false;
        player.hasCalledCurrentBet = false;
        player.lastAction = PlayerAction.none;

        _recalculateCurrentBet(lastActionIndex);
        _recalculateHasBetThisRound(lastActionIndex);
        _recalculateAllPlayersCallStatus(lastActionIndex);
        break;

      default:
        break;
    }

    // Remove action from history
    actions.removeAt(lastActionIndex);

    // Check if all actions have been undone (only blinds remain)
    bool onlyBlindsRemain = true;
    for (final action in actions) {
      if (action.action != PlayerAction.none) {
        onlyBlindsRemain = false;
        break;
      }
    }

    if (onlyBlindsRemain && actions.isNotEmpty) {
      _showHandResetDialog();
    } else {
      _gameState!.currentPlayer = seatNumber;
    }

    // Show feedback
    final playerName = _sessionManager!.getPlayerName(seatNumber);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Undone: $playerName ${lastAction.action.name}'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.orange,
      ),
    );

    setState(() {});
  }

  /// Get the total bet a player had made before a specific action index
  double _getPreviousBetThisRound(int seatNumber, int beforeIndex) {
    double totalBet = 0;
    final currentStreet = _gameState!.currentRound;
    final actions = _sessionManager!.currentHand!.actions;

    for (int i = 0; i < beforeIndex; i++) {
      final action = actions[i];
      if (action.player == seatNumber &&
          action.street == currentStreet &&
          (action.action == PlayerAction.bet ||
           action.action == PlayerAction.raise ||
           action.action == PlayerAction.call)) {
        totalBet = action.amount ?? totalBet;
      }
    }
    return totalBet;
  }

  /// Recalculate the current bet after undoing an action
  void _recalculateCurrentBet(int upToIndex) {
    double maxBet = 0;
    final currentStreet = _gameState!.currentRound;
    final actions = _sessionManager!.currentHand!.actions;

    for (int i = 0; i < upToIndex; i++) {
      final action = actions[i];
      if (action.street == currentStreet &&
          (action.action == PlayerAction.bet ||
           action.action == PlayerAction.raise)) {
        maxBet = (action.amount ?? 0) > maxBet ? (action.amount ?? 0) : maxBet;
      }
    }

    // On preflop, minimum bet is the big blind (blinds are already posted)
    if (currentStreet == BettingRound.preflop && maxBet == 0) {
      maxBet = _dealerSession.bigBlind.toDouble();
    }

    _gameState!.currentBet = maxBet;
  }

  /// Recalculate if there has been a bet this round after undoing
  void _recalculateHasBetThisRound(int upToIndex) {
    final currentStreet = _gameState!.currentRound;
    final actions = _sessionManager!.currentHand!.actions;
    bool hasBet = false;

    for (int i = 0; i < upToIndex; i++) {
      final action = actions[i];
      if (action.street == currentStreet &&
          (action.action == PlayerAction.bet ||
           action.action == PlayerAction.raise)) {
        hasBet = true;
        break;
      }
    }
    _gameState!.hasBetThisRound = hasBet;
  }

  /// Recalculate all players' hasCalledCurrentBet status after undo
  void _recalculateAllPlayersCallStatus(int upToIndex) {
    final actions = _sessionManager!.currentHand!.actions;

    // Reset all active players first
    for (var player in _gameState!.players) {
      if (!player.hasFolded && player.isActive) {
        player.hasCalledCurrentBet = false;
      }
    }

    // Find the last bet/raise before upToIndex
    int lastBetIndex = -1;
    for (int i = upToIndex - 1; i >= 0; i--) {
      final action = actions[i];
      if (action.action == PlayerAction.bet || action.action == PlayerAction.raise) {
        lastBetIndex = i;
        break;
      }
    }

    // If there was a bet/raise, mark players who have called/raised after it
    if (lastBetIndex >= 0) {
      final bettor = actions[lastBetIndex].player;
      final bettorPlayer = _gameState!.players[bettor - 1];
      bettorPlayer.hasCalledCurrentBet = true;

      for (int i = lastBetIndex + 1; i < upToIndex; i++) {
        final action = actions[i];
        if (action.action == PlayerAction.call ||
            action.action == PlayerAction.raise ||
            action.action == PlayerAction.bet) {
          final player = _gameState!.players[action.player - 1];
          player.hasCalledCurrentBet = true;
        }
      }
    } else {
      // No bet this round - check if players have checked
      for (int i = 0; i < upToIndex; i++) {
        final action = actions[i];
        if (action.action == PlayerAction.check) {
          final player = _gameState!.players[action.player - 1];
          player.hasCalledCurrentBet = true;
        }
      }
    }
  }

  /// Show dialog to reset hand when all actions are undone
  void _showHandResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Reset Hand?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'All actions have been undone. Would you like to start a new hand?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Current'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _abortAndRestartHand();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('New Hand'),
          ),
        ],
      ),
    );
  }

  /// Abort current hand and reset for a new one
  void _abortAndRestartHand() {
    // Return all bets to players
    for (var player in _gameState!.players) {
      if (player.betThisRound > 0) {
        player.currentStack += player.betThisRound;
        player.betThisRound = 0;
      }
      player.hasFolded = false;
      player.hasActed = false;
      player.hasCalledCurrentBet = false;
      player.lastAction = PlayerAction.none;
    }

    // Reset pot
    _gameState!.currentPot = 0;

    // Clear actions
    _sessionManager!.currentHand!.actions.clear();

    // Reset hand state
    _isHandActive = false;

    setState(() {});

    // Update cubit with hand-ended state
    _voiceCubit?.updateGameState(_gameState, _isHandActive);

    _showSuccess('Hand reset - ready for new hand');
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
      backgroundColor: const Color(0xFF101115),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF1B1E24)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + close
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.tableName} · Seat $_selectedSeat',
                    style: GoogleFonts.ibmPlexSans(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1B1E24),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
            if (!isOccupied) ...[
              const SizedBox(height: 4),
              Text(
                'Scan to join this seat',
                style: GoogleFonts.ibmPlexSans(
                  color: const Color(0xFFD3FFFD),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 20),
            // QR code / occupied state
            Center(
              child: !isOccupied
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: QrImageView(
                        data: qrData.encode(),
                        version: QrVersions.auto,
                        size: 200,
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF02050B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1B1E24)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person,
                            size: 20,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 10),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Occupied · ',
                                  style: GoogleFonts.ibmPlexSans(
                                    color: const Color(0xFF8C8C8C),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                TextSpan(
                                  text: occupantName ?? 'Player',
                                  style: GoogleFonts.ibmPlexSans(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            // Seat selector
            Text(
              'SELECT SEAT',
              style: GoogleFonts.ibmPlexSans(
                color: const Color(0xFF8C8C8C),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF89F1EC),
                        ),
                      ),
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(9, (i) {
                      final seat = i + 1;
                      final seatIsOccupied =
                          _seatAssignments[seat]?.isOccupied ?? false;
                      final isSelected = seat == _selectedSeat;
                      final Color bg;
                      final Color borderColor;
                      final Color textColor;
                      if (isSelected) {
                        bg = seatIsOccupied
                            ? const Color(0xFFBD8F2D)
                            : const Color(0xFF89F1EC);
                        borderColor = bg;
                        textColor = Colors.black;
                      } else if (seatIsOccupied) {
                        bg = const Color(0xFF02050B);
                        borderColor =
                            const Color(0xFFBD8F2D).withValues(alpha: 0.5);
                        textColor = const Color(0xFFBD8F2D);
                      } else {
                        bg = const Color(0xFF02050B);
                        borderColor = const Color(0xFF1B4341);
                        textColor = Colors.white;
                      }
                      return GestureDetector(
                        onTap: () => setState(() => _selectedSeat = seat),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor, width: 1),
                          ),
                          child: Center(
                            child: Text(
                              seat.toString(),
                              style: GoogleFonts.ibmPlexMono(
                                color: textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
            const SizedBox(height: 14),
            // Legend
            Row(
              children: [
                _buildLegendDot(
                  const Color(0xFF02050B),
                  const Color(0xFF1B4341),
                ),
                const SizedBox(width: 6),
                Text(
                  'Empty',
                  style: GoogleFonts.ibmPlexSans(
                    color: const Color(0xFF8C8C8C),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 16),
                _buildLegendDot(
                  const Color(0xFF02050B),
                  const Color(0xFFBD8F2D).withValues(alpha: 0.5),
                ),
                const SizedBox(width: 6),
                Text(
                  'Occupied',
                  style: GoogleFonts.ibmPlexSans(
                    color: const Color(0xFF8C8C8C),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 16),
                _buildLegendDot(
                  const Color(0xFF89F1EC),
                  const Color(0xFF89F1EC),
                ),
                const SizedBox(width: 6),
                Text(
                  'Selected',
                  style: GoogleFonts.ibmPlexSans(
                    color: const Color(0xFF8C8C8C),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, Color borderColor) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: borderColor),
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
