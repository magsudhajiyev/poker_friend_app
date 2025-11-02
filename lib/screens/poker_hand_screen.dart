import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import '../design_system/poker_friend_theme.dart';
import '../widgets/drawing_painter.dart';
import '../widgets/board_cards_dialog.dart';
import '../widgets/all_in_board_cards_dialog.dart';
import '../widgets/hole_cards_dialog.dart';
import 'individual_session_tracking_screen.dart';
import '../widgets/showdown_dialog.dart';
import 'seat_setup_screen.dart';
import '../widgets/action_button_grid.dart';
import '../widgets/winner_selection_dialog.dart';
import '../models/poker_game_state.dart';
import '../models/hand_state_machine.dart';
import '../models/game_types.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
import '../services/auth_service.dart';
import '../services/logger_service.dart';
import 'session_history_screen.dart';

class PokerHandScreen extends StatefulWidget {
  final int smallBlind;
  final int bigBlind;
  final int numberOfPlayers;
  final GameType gameType;
  final bool hasBBante;
  final int ante;

  // Individual session parameters
  final bool isIndividualSession;
  final double? individualCurrentStack;
  final String? individualSessionId;
  final double? individualTotalBuyIn;

  // Full session parameters
  final String? sessionName;
  final double? buyInAmount;
  final double? startingStack;
  final int? initialSeat;
  final int? initialButtonPosition;
  final PokerSessionManager? sessionManager;

  const PokerHandScreen({
    super.key,
    required this.smallBlind,
    required this.bigBlind,
    required this.numberOfPlayers,
    this.gameType = GameType.cash,
    this.hasBBante = false,
    this.ante = 0,
    this.isIndividualSession = false,
    this.individualCurrentStack,
    this.individualSessionId,
    this.individualTotalBuyIn,
    this.sessionName,
    this.buyInAmount,
    this.startingStack,
    this.initialSeat,
    this.initialButtonPosition,
    this.sessionManager,
  });

  @override
  State<PokerHandScreen> createState() => _PokerHandScreenState();
}

class _PokerHandScreenState extends State<PokerHandScreen> {
  List<String> actions = [];
  List<Offset> points = [];
  Timer? _tapTimer;
  int _tapCount = 0;
  late PokerGameState gameState;
  late PokerSessionManager sessionManager;
  bool useButtonMode = false;
  bool autoAdvanceStreets = false;
  bool _allInHandCompleted = false;
  
  // Drag betting state
  bool _isDragBetting = false;
  PlayerAction? _pendingAction;
  double _dragBetAmount = 0.0;
  Offset? _dragStartPosition;
  double _dragBarPosition = 0.0; // Y position for the drag bar (0-1 normalized)
  
  // Race condition prevention
  bool _isProcessingPostFrameAction = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize poker game state with 9 seats (standard poker table)
    gameState = PokerGameState(
      numberOfPlayers: 9, // Always 9 seats regardless of initial player count
      smallBlind: widget.smallBlind,
      bigBlind: widget.bigBlind,
      isCashGame: widget.gameType == GameType.cash,
      hasBBante: widget.hasBBante,
    );
    
    // Initialize session manager - use the one passed from SeatSetupScreen if available
    if (widget.sessionManager != null) {
      sessionManager = widget.sessionManager!;
    } else {
      sessionManager = PokerSessionManager(
        smallBlind: widget.smallBlind,
        bigBlind: widget.bigBlind,
        playerCount: widget.numberOfPlayers,
        gameType: widget.gameType,
        existingSessionId: widget.individualSessionId, // Use existing session ID for individual sessions
        initialBuyIn: widget.individualTotalBuyIn, // Pass total buy-in for individual sessions
        startingStack: widget.startingStack, // Pass starting stack (chips for MTT, same as buy-in for cash)
      );
    }
    
    // Load button mode setting
    _loadButtonModeSetting();
    
    // Start session and first hand
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // If we have initial seat info from session setup, skip seat selection
      if (widget.initialSeat != null && widget.initialButtonPosition != null) {
        _initializeWithSeatInfo(widget.initialSeat!, widget.initialButtonPosition!);
      } else {
        _initializeSession();
      }
    });
  }

  Future<void> _loadButtonModeSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      useButtonMode = prefs.getBool('use_button_mode') ?? false;
      autoAdvanceStreets = prefs.getBool('auto_advance_streets') ?? false;
    });
  }

  void _handleButtonAction(PlayerAction action) {
    _performPokerAction(action);
  }

  Set<PlayerAction> _getAvailableActions() {
    Set<PlayerAction> actions = {PlayerAction.fold}; // Fold is always available
    
    // Use existing game state logic
    if (gameState.isValidAction(PlayerAction.check)) {
      actions.add(PlayerAction.check);
    }
    if (gameState.isValidAction(PlayerAction.call)) {
      actions.add(PlayerAction.call);
    }
    if (gameState.isValidAction(PlayerAction.bet)) {
      actions.add(PlayerAction.bet);
    }
    if (gameState.isValidAction(PlayerAction.raise)) {
      actions.add(PlayerAction.raise);
    }
    
    return actions;
  }

  Future<void> _initializeWithSeatInfo(int seat, int buttonPosition) async {
    // Initialize with provided seat info, skipping seat selection dialog

    // CRITICAL: Set our seat number
    sessionManager.ourSeatNumber = seat;

    // Set our player name (get from auth service or use "You") - only if not already set
    String? existingName = sessionManager.getPlayerName(seat);

    if (existingName == null || existingName.isEmpty || existingName.startsWith('Player ')) {
      String ourName = "You"; // Default name
      try {
        final user = AuthService.currentUser;
        if (user != null && user.displayName?.isNotEmpty == true) {
          ourName = user.displayName!;
        }
      } catch (e) {
        // Use default if auth fails
      }
      sessionManager.setPlayerName(seat, ourName);
    }

    // Build playerStacks - use active seats from sessionManager (configured in SeatSetupScreen)
    Map<int, double> playerStacks = {};

    // Use ONLY the active seats from sessionManager (user's configuration from seat setup)
    for (int seatNum in sessionManager.activeSeats) {
      // First try to get custom stack from sessionManager
      final customStack = sessionManager.getPlayerStack(seatNum);
      if (customStack != null) {
        // Use the custom stack configured in seat setup
        playerStacks[seatNum] = customStack;
      } else if (seatNum == seat && widget.startingStack != null) {
        // Fallback: Use the starting stack from session setup for our seat
        playerStacks[seatNum] = widget.startingStack!;
      } else {
        // Fallback: For other active seats, use default stack
        playerStacks[seatNum] = widget.gameType == GameType.cash ? 100.0 : 1500.0;
      }
    }

    // CRITICAL: Initialize player stacks and set inactive players FIRST
    for (int i = 1; i <= 9; i++) {
      if (playerStacks.containsKey(i)) {
        // Active player - set their stack
        gameState.setPlayerStack(i, playerStacks[i]!);
        gameState.setPlayerActive(i, true);
        // Make sure session manager knows this seat is active
        if (!sessionManager.activeSeats.contains(i)) {
          sessionManager.activeSeats.add(i);
        }
      } else {
        // Inactive player - set stack to 0 and mark inactive
        gameState.setPlayerStack(i, 0.0);
        gameState.setPlayerActive(i, false);
        // Make sure session manager knows this seat is inactive
        sessionManager.activeSeats.remove(i);
      }
    }

    // CRITICAL: NOW set button position AFTER players are initialized
    gameState.buttonPosition = buttonPosition;

    // CRITICAL: Complete initialization and calculate action order
    gameState.finalizeInitialization();

    // Initialize pot with blinds - this will deduct blinds from stacks and add to pot
    gameState.initializePot();

    // Get initial stack for our seat to track in session history
    final sessionSeat = sessionManager.ourSeatNumber;
    final initialStack = sessionSeat != null ? gameState.players[sessionSeat - 1].currentStack : widget.startingStack;

    await sessionManager.startSession(initialStack: initialStack);

    sessionManager.startHand(
      gameState.handNumber,
      gameState.buttonPosition,
      sbSeat: gameState.effectiveSBPosition,
      bbSeat: gameState.effectiveBBPosition,
    );

    // Auto-start the hand
    actions.add("🔥 Session started - Firebase ID: ${sessionManager.sessionId?.substring(0, 8)}...");
    actions.add("Game started. Blinds: ${sessionManager.smallBlind}/${sessionManager.bigBlind}");

    // Add blind posting actions
    List<int> activePlayers = gameState.getActivePlayers();
    if (activePlayers.length > 2) {
      actions.add("Player ${gameState.effectiveSBPosition} posts small blind \$${sessionManager.smallBlind}");
      actions.add("Player ${gameState.effectiveBBPosition} posts big blind \$${sessionManager.bigBlind}");

      if (widget.hasBBante) {
        actions.add("Player ${gameState.effectiveBBPosition} posts ante \$${sessionManager.bigBlind} for all players");
      }
    }

    setState(() {});
  }

  Future<void> _initializeSession() async {
    // First show seat selection dialog
    final result = await _showSeatSelectionDialog();
    if (result == null) {
      // User cancelled, go back
      Navigator.pop(context);
      return;
    }
    
    final ourSeat = result['seat'] as int?;
    final buttonPosition = result['buttonPosition'] as int;
    final playerStacks = result['playerStacks'] as Map<int, double>? ?? {};
    final isCashGame = result['isCashGame'] as bool? ?? true;
    
    if (ourSeat == null) {
      // No seat selected, go back
      Navigator.pop(context);
      return;
    }

    // CRITICAL: Set our seat number
    sessionManager.ourSeatNumber = ourSeat;

    // CRITICAL: Initialize player stacks and set inactive players FIRST
    for (int i = 1; i <= 9; i++) {
      if (playerStacks.containsKey(i)) {
        // Active player - set their stack
        gameState.setPlayerStack(i, playerStacks[i]!);
        gameState.setPlayerActive(i, true);
        // Make sure session manager knows this seat is active
        if (!sessionManager.activeSeats.contains(i)) {
          sessionManager.activeSeats.add(i);
        }
      } else {
        // Inactive player - set stack to 0 and mark inactive
        gameState.setPlayerStack(i, 0.0);
        gameState.setPlayerActive(i, false);
        // Make sure session manager knows this seat is inactive
        sessionManager.activeSeats.remove(i);
      }
    }

    // CRITICAL: NOW set button position AFTER players are initialized
    gameState.buttonPosition = buttonPosition;

    // CRITICAL: Complete initialization and calculate action order
    gameState.finalizeInitialization();

    // Initialize pot with blinds
    gameState.initializePot();

    // Get initial stack for our seat to track in session history
    final sessionSeat = sessionManager.ourSeatNumber;
    final initialStack = sessionSeat != null ? gameState.players[sessionSeat - 1].currentStack : widget.startingStack;

    await sessionManager.startSession(initialStack: initialStack);
    
    sessionManager.startHand(
      gameState.handNumber,
      gameState.buttonPosition,
      sbSeat: gameState.effectiveSBPosition,
      bbSeat: gameState.effectiveBBPosition,
    );
    
    // Auto-start the hand
    actions.add("🔥 Session started - Firebase ID: ${sessionManager.sessionId?.substring(0, 8)}...");
    actions.add("Game started. Blinds: ${sessionManager.smallBlind}/${sessionManager.bigBlind}");
    actions.add("Your seat: #$ourSeat (${sessionManager.getOurPosition(gameState.buttonPosition) ?? 'UNK'})");
    actions.add(gameState.getGameStateInfo());
    actions.add(_getToActMessage());
    
    
    setState(() {});
  }

  Future<Map<String, dynamic>?> _showSeatSelectionDialog() async {
    return Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => SeatSetupScreen(
          playerCount: widget.numberOfPlayers,
          buttonPosition: gameState.buttonPosition,
          sessionManager: sessionManager,
          isInitialSetup: true,
          isCashGame: widget.gameType == GameType.cash,
          isIndividualSession: widget.isIndividualSession,
          individualCurrentStack: widget.individualCurrentStack,
        ),
      ),
    );
  }

  Future<void> _stopSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: PokerFriendColors.dark3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Stop Session?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to stop this session? All hands will be saved.',
            style: TextStyle(
              color: PokerFriendColors.dark10,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false); // Cancel
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: PokerFriendColors.dark10,
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true); // Confirm
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: PokerFriendColors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Stop Session',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        // End the session and save all data
        await sessionManager.endSession();

        // Navigate back to main screen
        Navigator.of(context).popUntil((route) => route.isFirst);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to end session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Future<void> _managePlayersDialog() async {
    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (context) => SeatSetupScreen(
          playerCount: widget.numberOfPlayers,
          buttonPosition: gameState.buttonPosition,
          currentSeat: sessionManager.ourSeatNumber,
          sessionManager: sessionManager,
          isInitialSetup: false,
          isCashGame: widget.gameType == GameType.cash,
          gameState: gameState,
          isIndividualSession: widget.isIndividualSession,
          individualCurrentStack: widget.individualCurrentStack,
        ),
      ),
    );

    // Sync gameState with sessionManager's active seats
    setState(() {
      // Store the current player and button before changes
      final previousCurrentPlayer = gameState.currentPlayer;
      final previousButton = gameState.buttonPosition;

      // Store previous active player count BEFORE making changes
      final previousActiveCount = gameState.getActivePlayers().length;

      // Update button position if it was changed
      if (result != null && result['buttonPosition'] != null) {
        final newButtonPosition = result['buttonPosition'] as int;
        if (newButtonPosition != previousButton) {
          gameState.buttonPosition = newButtonPosition;
          sessionManager.buttonPosition = newButtonPosition;
          addAction("🔘 Button moved to Player $newButtonPosition");
        }
      }

      for (int seat = 1; seat <= widget.numberOfPlayers; seat++) {
        final isActive = sessionManager.activeSeats.contains(seat);
        gameState.setPlayerActive(seat, isActive);

        // Sync player stack from sessionManager to gameState
        if (isActive && sessionManager.playerStacks.containsKey(seat)) {
          final stackSize = sessionManager.playerStacks[seat]!;
          gameState.players[seat - 1].currentStack = stackSize;
          gameState.players[seat - 1].startingStack = stackSize;
        }
      }

      // Get active players for position calculations
      List<int> activePlayers = gameState.getActivePlayers();
      final activeCountChanged = activePlayers.length != previousActiveCount;

      // Recalculate blind positions based on new button position
      if (activePlayers.length >= 2) {
        if (activePlayers.length == 2) {
          // Heads-up: button is SB, other player is BB
          if (activePlayers.contains(gameState.buttonPosition)) {
            sessionManager.actualSBSeat = gameState.buttonPosition;
            // Find the other active player for BB
            sessionManager.actualBBSeat = activePlayers.firstWhere((p) => p != gameState.buttonPosition);
          }
        } else {
          // Multi-way: find SB and BB positions among active players
          int sbPosition = gameState.buttonPosition;
          int attempts = 0;
          // Find first active player after button for SB
          do {
            sbPosition = (sbPosition % gameState.numberOfPlayers) + 1;
            attempts++;
            if (activePlayers.contains(sbPosition)) {
              break;
            }
          } while (attempts < gameState.numberOfPlayers);
          sessionManager.actualSBSeat = sbPosition;

          // Find next active player after SB for BB
          int bbPosition = sbPosition;
          attempts = 0;
          do {
            bbPosition = (bbPosition % gameState.numberOfPlayers) + 1;
            attempts++;
            if (activePlayers.contains(bbPosition)) {
              break;
            }
          } while (attempts < gameState.numberOfPlayers);
          sessionManager.actualBBSeat = bbPosition;
        }
      }

      // Check if the current player was deactivated or if button/positions changed
      final currentPlayerStillActive = sessionManager.activeSeats.contains(previousCurrentPlayer);
      final buttonChanged = gameState.buttonPosition != previousButton;

      if (!currentPlayerStillActive && !gameState.bettingRoundComplete) {
        // Current player was deactivated, advance to next active player
        int nextPlayer = previousCurrentPlayer;
        int attempts = 0;
        do {
          nextPlayer = (nextPlayer % gameState.numberOfPlayers) + 1;
          attempts++;

          if (attempts > gameState.numberOfPlayers) {
            break;
          }

          final playerState = gameState.players[nextPlayer - 1];
          if (playerState.isActive && !playerState.hasFolded) {
            break;
          }
        } while (nextPlayer != previousCurrentPlayer);

        gameState.currentPlayer = nextPlayer;
        addAction("⏭️ Player ${previousCurrentPlayer} removed - Player ${nextPlayer} to act");
      } else if ((buttonChanged || activeCountChanged) && !gameState.bettingRoundComplete) {
        // Button or active players changed, recalculate who should act
        if (activePlayers.length >= 2) {
          if (gameState.currentRound == BettingRound.preflop) {
            // For preflop: UTG is first active player after BB
            // We already calculated actualBBSeat above
            int bbPosition = sessionManager.actualBBSeat ?? gameState.buttonPosition;
            int utgPosition = gameState.currentPlayer;
            int nextPlayer = bbPosition;
            int attempts = 0;
            do {
              nextPlayer = (nextPlayer % gameState.numberOfPlayers) + 1;
              attempts++;
              if (activePlayers.contains(nextPlayer) && !gameState.players[nextPlayer - 1].hasFolded) {
                utgPosition = nextPlayer;
                break;
              }
            } while (attempts < gameState.numberOfPlayers);
            gameState.currentPlayer = utgPosition;

            // Log with position name
            final playerName = sessionManager.getPlayerNameWithPosition(utgPosition);
            addAction("🔄 Positions recalculated - $playerName to act");
          } else {
            // Postflop: first active player after button who hasn't folded
            int nextPlayer = gameState.buttonPosition;
            int attempts = 0;
            do {
              nextPlayer = (nextPlayer % gameState.numberOfPlayers) + 1;
              attempts++;
              if (activePlayers.contains(nextPlayer) && !gameState.players[nextPlayer - 1].hasFolded) {
                gameState.currentPlayer = nextPlayer;
                break;
              }
            } while (attempts < gameState.numberOfPlayers);

            final playerName = sessionManager.getPlayerNameWithPosition(gameState.currentPlayer);
            addAction("🔄 Positions recalculated - $playerName to act");
          }
        }
      } else if (currentPlayerStillActive && !buttonChanged) {
        addAction("👥 Player configuration updated");
      }
    });
  }

  Future<void> _showSettingsDialog() async {
    final prefs = await SharedPreferences.getInstance();

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _SettingsDialog(
        currentSmallBlind: sessionManager.smallBlind,
        currentBigBlind: sessionManager.bigBlind,
        useButtonMode: useButtonMode,
        currentHasBBante: gameState.hasBBante,
        gameType: widget.gameType,
        onBlindsChanged: (smallBlind, bigBlind, hasBBante) async {

          setState(() {
            // Update both sessionManager and gameState blinds
            sessionManager.smallBlind = smallBlind;
            sessionManager.bigBlind = bigBlind;
            gameState.smallBlind = smallBlind;
            gameState.bigBlind = bigBlind;
            gameState.hasBBante = hasBBante;
          });

          // Save blinds to preferences for persistence
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('small_blind', smallBlind);
          await prefs.setInt('big_blind', bigBlind);

          // For individual sessions, also update Firebase so session details screen shows correct values
          if (widget.isIndividualSession && sessionManager.sessionId != null) {
            await FirebaseService.updateIndividualSession(
              sessionId: sessionManager.sessionId!,
              smallBlind: smallBlind,
              bigBlind: bigBlind,
              hasBBante: hasBBante,
            ).catchError((e) {});
          }
          // Note: These changes will take effect immediately for new hands
        },
        onButtonModeToggled: (value) async {
          setState(() {
            useButtonMode = value;
          });
          await prefs.setBool('use_button_mode', value);
        },
      ),
    );
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    _tapTimer = null;
    
    // End session when leaving
    if (sessionManager.sessionState == SessionState.active) {
      sessionManager.endSession().catchError((e) {
      });
    }
    
    super.dispose();
  }

  // Null-safe helper methods to prevent crashes
  String _getCurrentPlayerStackSafely() {
    try {
      if (gameState.currentPlayer < 1 || gameState.currentPlayer > gameState.numberOfPlayers) {
        return gameState.formatCurrency(0.0);
      }
      final stack = gameState.getPlayerStack(gameState.currentPlayer);
      return gameState.formatCurrency(stack);
    } catch (e) {
      return gameState.formatCurrency(0.0);
    }
  }

  String _getCurrentPlayerNameSafely() {
    try {
      if (gameState.currentPlayer < 1 || gameState.currentPlayer > gameState.numberOfPlayers) {
        return 'Unknown';
      }
      return sessionManager.getPlayerNameWithPosition(gameState.currentPlayer);
    } catch (e) {
      return 'Unknown';
    }
  }

  // Race condition prevention for PostFrameCallbacks
  void _schedulePostFrameAction(VoidCallback action) {
    if (_isProcessingPostFrameAction) {
      return;
    }
    
    _isProcessingPostFrameAction = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          action();
        } catch (e) {
        } finally {
          _isProcessingPostFrameAction = false;
        }
      } else {
        _isProcessingPostFrameAction = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: Color(0xFF161618),
      body: SafeArea(
        child: Column(
          children: [
            // Modern Header
            Container(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 20),
              decoration: BoxDecoration(
                color: Color(0xFF1F1F23),
              ),
              child: Row(
                children: [
                  // Back button
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(0xFF161618),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  
                  // Title section
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          Text(
                            'Hand #${gameState.handNumber}',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${gameState.currentRound.name.toUpperCase()} • ${gameState.getActivePlayers().length} players',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9A9A9A),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Action buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        margin: EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Color(0xFF161618),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: _skipCurrentAction,
                          icon: Icon(
                            Icons.skip_next,
                            color: Colors.white,
                            size: 18,
                          ),
                          padding: EdgeInsets.zero,
                          tooltip: 'Skip',
                        ),
                      ),
                      if (gameState.bettingRoundComplete && gameState.currentRound != BettingRound.river)
                        Container(
                          width: 40,
                          height: 40,
                          margin: EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            onPressed: nextStreet,
                            icon: Icon(
                              Icons.skip_next,
                              color: Colors.white,
                              size: 18,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: _allInHandCompleted ? null : completeHand,
                          icon: Icon(
                            Icons.check,
                            color: _allInHandCompleted ? Colors.grey : Colors.white,
                            size: 18,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  
                  // Menu button
                  Container(
                    width: 40,
                    height: 40,
                    margin: EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      color: Color(0xFF161618),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: Colors.white,
                        size: 18,
                      ),
                      color: Color(0xFF1F1F23),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
            onSelected: (value) {
              if (value == 'endStreet') {
                endStreetManually();
              } else if (value == 'sessionDetails') {
                _showSessionDetails();
              } else if (value == 'managePlayers') {
                _managePlayersDialog();
              } else if (value == 'rebuy') {
                _showRebuyDialog();
              } else if (value == 'stopSession') {
                _stopSession();
              } else if (value == 'settings') {
                _showSettingsDialog();
              }
            },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'endStreet',
                          child: Row(
                            children: [
                              Icon(Icons.stop, color: Color(0xFF9A9A9A), size: 18),
                              const SizedBox(width: 12),
                              Text(
                                'End Street',
                                style: TextStyle(color: Colors.white, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'sessionDetails',
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Color(0xFF9A9A9A), size: 18),
                              const SizedBox(width: 12),
                              Text(
                                'Session Details',
                                style: TextStyle(color: Colors.white, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'managePlayers',
                          child: Row(
                            children: [
                              Icon(Icons.people, color: Color(0xFF9A9A9A), size: 18),
                              const SizedBox(width: 12),
                              Text(
                                'Manage Players',
                                style: TextStyle(color: Colors.white, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        // Only show rebuy option for tournaments
                        if (widget.gameType == GameType.tournament)
                          PopupMenuItem(
                            value: 'rebuy',
                            child: Row(
                              children: [
                                Icon(Icons.add_circle_outline, color: Color(0xFF5AC95A), size: 18),
                                const SizedBox(width: 12),
                                Text(
                                  'Rebuy',
                                  style: TextStyle(color: Colors.white, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        PopupMenuItem(
                          value: 'stopSession',
                          child: Row(
                            children: [
                              Icon(Icons.exit_to_app, color: Colors.red, size: 18),
                              const SizedBox(width: 12),
                              Text(
                                'Stop Session',
                                style: TextStyle(color: Colors.red, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'settings',
                          child: Row(
                            children: [
                              Icon(Icons.settings, color: Color(0xFF9A9A9A), size: 18),
                              const SizedBox(width: 12),
                              Text(
                                'Settings',
                                style: TextStyle(color: Colors.white, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Game Info Header - Individual Cards (Dark Theme)
            Container(
              margin: const EdgeInsets.all(PokerFriendSpacing.xs),
              child: gameState.areAllPlayersAllIn()
                ? // All-in situation: Show single unified card
                  Container(
                    decoration: BoxDecoration(
                      color: Color(0xFF5AC95A).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(PokerFriendRadius.l),
                      border: Border.all(color: Color(0xFF5AC95A), width: 2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(PokerFriendSpacing.m),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.casino,
                            color: Color(0xFF5AC95A),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'ALL IN HAND',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '• POT: ${gameState.formatCurrency(gameState.currentPot)}',
                            style: TextStyle(
                              color: Color(0xFF5AC95A),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : // Normal situation: Show three cards
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 105, // Increased height to accommodate text
                          decoration: BoxDecoration(
                            color: Color(0xFF1F1F23),
                            borderRadius: BorderRadius.circular(PokerFriendRadius.l),
                            border: Border.all(color: Color(0xFF2A2A2E), width: 1),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0), // Reduced padding
                            child: _buildInfoItemWithAsset(context, 'Pot', gameState.formatCurrency(gameState.currentPot), 'icons/pot.png'),
                          ),
                        ),
                      ),
                      SizedBox(width: PokerFriendSpacing.xxs),
                      Expanded(
                        child: Container(
                          height: 105, // Increased height to accommodate text
                          decoration: BoxDecoration(
                            color: Color(0xFF1F1F23),
                            borderRadius: BorderRadius.circular(PokerFriendRadius.l),
                            border: Border.all(color: Color(0xFF2A2A2E), width: 1),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0), // Reduced padding
                            child: _buildInfoItemWithAsset(context, 'To Act', _getCurrentPlayerNameSafely(), 'icons/player.png'),
                          ),
                        ),
                      ),
                      SizedBox(width: PokerFriendSpacing.xxs),
                      Expanded(
                        child: Container(
                          height: 105, // Increased height to accommodate text
                          decoration: BoxDecoration(
                            color: Color(0xFF1F1F23),
                            borderRadius: BorderRadius.circular(PokerFriendRadius.l),
                            border: Border.all(color: Color(0xFF2A2A2E), width: 1),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0), // Reduced padding
                            child: _buildInfoItemWithAsset(context, 'Stack', _getCurrentPlayerStackSafely(), 'icons/wallet.png'),
                          ),
                        ),
                      ),
                    ],
                  ),
            ),

          
              // Main Gesture Area
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: PokerFriendSpacing.xs),
                  decoration: PokerFriendWidgets.primaryCard,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(PokerFriendRadius.l),
                    child: Stack(
                  children: [
                    // Conditional input area: drawing pad or action buttons
                    if (useButtonMode) ...[
                      // Action buttons mode
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                            ],
                          ),
                        ),
                        child: ActionButtonGrid(
                          onActionSelected: _handleButtonAction,
                          availableActions: _getAvailableActions(),
                        ),
                      ),
                    ] else ...[
                      // Drawing area mode
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) => _isDragBetting ? _completeDragBetting() : handleTap(),
                        onPanStart: (details) {
                          _cancelTapTimer();
                          if (_isDragBetting) {
                            _dragStartPosition = details.localPosition;
                          } else {
                            setState(() {
                              points.add(details.localPosition);
                            });
                          }
                        },
                        onPanUpdate: (details) {
                          if (_isDragBetting) {
                            // Initialize drag start position if not set
                            if (_dragStartPosition == null) {
                              _dragStartPosition = details.localPosition;
                            }
                            final deltaY = details.localPosition.dy - _dragStartPosition!.dy;
                            _updateDragBetAmount(deltaY);
                          } else {
                            setState(() {
                              points.add(details.localPosition);
                            });
                          }
                        },
                        onPanEnd: (details) {
                          if (_isDragBetting) {
                            _completeDragBetting();
                          } else {
                            if (points.length > 3) {
                              recognizeShape();
                            }
                            setState(() {
                              points.clear();
                            });
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: PokerFriendColors.dark3,
                          child: CustomPaint(
                            painter: DrawingPainter(points: points),
                            size: Size.infinite,
                          ),
                        ),
                      ),
                    ],
                    
                    // Gesture Guide Icon (only in drawing mode)
                    if (!useButtonMode)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: _buildGestureIcon(context),
                      ),
                    
                    // Drag Betting Amount Display (top-left corner)
                    if (_isDragBetting && (_pendingAction == PlayerAction.bet || _pendingAction == PlayerAction.raise))
                      Positioned(
                        top: 16,
                        left: 16,
                        child: _buildSimpleDragBetDisplay(context),
                      ),
                    
                    
                    // Firebase Connection Status
                    Positioned(
                      bottom: 16,
                      left: 16,
                      child: _buildFirebaseStatus(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // End Street Button (when needed)
          if (!gameState.bettingRoundComplete && gameState.getActivePlayers().length > 1)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: endStreetManually,
                icon: const Icon(Icons.skip_next_outlined),
                label: Text('End ${gameState.getCurrentStreetName()} Betting',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

          // Undo Last Action Button
          if (_canUndoLastAction())
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _undoLastAction,
                icon: const Icon(Icons.undo_outlined),
                label: const Text('Undo Last Action',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

          // Action Log
          Container(
            margin: const EdgeInsets.all(16),
            height: 140,
            child: Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.history_outlined,
                          color: theme.colorScheme.onPrimaryContainer,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Action Log',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        reverse: true,
                        itemCount: actions.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              actions[actions.length - 1 - index],
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer.withOpacity(0.9),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
            ],
          ),
        ),
    );
  }

  Widget _buildInfoItem(BuildContext context, String label, String value, IconData icon) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: Colors.red,
          size: 24,
        ),
        const SizedBox(height: PokerFriendSpacing.xxxs),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: Color(0xFF9A9A9A),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: PokerFriendSpacing.xxxs),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItemWithAsset(BuildContext context, String label, String value, String assetPath) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          assetPath,
          width: 24,
          height: 24,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: Color(0xFF9A9A9A),
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Center(
            child: Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }


  bool _showGestureTooltip = false;

  Widget _buildGestureIcon(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setStateLocal) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Info icon button
            GestureDetector(
              onTap: () {
                setStateLocal(() {
                  _showGestureTooltip = !_showGestureTooltip;
                });
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: PokerFriendColors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: PokerFriendColors.light6.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: PokerFriendColors.light6.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.info_outline,
                  color: PokerFriendColors.purple,
                  size: 20,
                ),
              ),
            ),
            // Gesture tooltip
            if (_showGestureTooltip) ...[
              SizedBox(height: 8),
              _buildGestureTooltip(context),
            ],
          ],
        );
      },
    );
  }

  Widget _buildGestureTooltip(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PokerFriendColors.white.withOpacity(0.98),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PokerFriendColors.light6.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: PokerFriendColors.light6.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.gesture_rounded,
                color: PokerFriendColors.purple,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Gestures',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: PokerFriendColors.midnightPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildGestureItem(context, '👆', 'Tap', 'Bet'),
          _buildGestureItem(context, '👆👆', 'Double Tap', 'Check'),
          _buildGestureItem(context, '📏', 'Draw Line', 'Fold'),
          _buildGestureItem(context, '⭕', 'Draw Circle', 'Call'),
          _buildGestureItem(context, '📐', 'Draw L', 'Raise'),
        ],
      ),
    );
  }

  Widget _buildGestureGuide(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(PokerFriendSpacing.xs),
      decoration: BoxDecoration(
        color: PokerFriendColors.white.withOpacity(0.98),
        borderRadius: BorderRadius.circular(PokerFriendRadius.m),
        border: Border.all(color: PokerFriendColors.light6.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: PokerFriendColors.light6.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.gesture_rounded,
                color: PokerFriendColors.purple,
                size: 18,
              ),
              const SizedBox(width: PokerFriendSpacing.xxs),
              Text(
                'Gestures',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: PokerFriendColors.midnightPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: PokerFriendSpacing.xxs),
          _buildGestureItem(context, '👆', 'Tap', 'Bet'),
          _buildGestureItem(context, '👆👆', 'Double Tap', 'Check'),
          _buildGestureItem(context, '📏', 'Draw Line', 'Fold'),
          _buildGestureItem(context, '⭕', 'Draw Circle', 'Call'),
          _buildGestureItem(context, '📐', 'Draw L', 'Raise'),
        ],
      ),
    );
  }

  Widget _buildSimpleDragBetDisplay(BuildContext context) {
    final theme = Theme.of(context);
    final actionName = _pendingAction == PlayerAction.raise ? 'RAISE' : 'BET';
    final formattedAmount = gameState.formatCurrency(_dragBetAmount);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$actionName: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            formattedAmount,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGestureItem(BuildContext context, String emoji, String gesture, String action) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          Text(
            '$gesture: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
          Text(
            action,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDragBetDisplay(BuildContext context) {
    final theme = Theme.of(context);
    final currentPlayer = gameState.getCurrentPlayer();
    final actionName = _pendingAction == PlayerAction.raise ? 'RAISE' : 'BET';
    final formattedAmount = gameState.formatCurrency(_dragBetAmount);
    
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            actionName,
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formattedAmount,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.drag_handle,
                color: Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Drag to adjust',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          if (currentPlayer != null) ...[
            const SizedBox(height: 4),
            Text(
              'Max: ${gameState.formatCurrency(currentPlayer.currentStack)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white60,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFirebaseStatus(BuildContext context) {
    final theme = Theme.of(context);
    final isOnline = sessionManager.sessionId != null && !sessionManager.sessionId!.startsWith('offline_');
    final stats = sessionManager.getSessionStats();
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOnline ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
            color: isOnline ? Colors.green : Colors.orange,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isOnline ? Colors.green : Colors.orange,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
          if (stats['totalHands'] > 0) ...[
            const SizedBox(width: 8),
            Text(
              '${stats['totalHands']}H',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _cancelTapTimer() {
    if (_tapTimer != null) {
      _tapTimer!.cancel();
      _tapTimer = null;
      _tapCount = 0;
    }
  }

  void handleTap() {
    _tapCount++;
    
    if (_tapTimer != null) {
      _tapTimer!.cancel();
    }
    
    _tapTimer = Timer(const Duration(milliseconds: 400), () {
      if (_tapCount == 1) {
        // Single tap - Enter drag mode for bet/raise
        if (gameState.isValidAction(PlayerAction.bet)) {
          _enterDragBettingMode(PlayerAction.bet);
        } else if (gameState.isValidAction(PlayerAction.raise)) {
          _enterDragBettingMode(PlayerAction.raise);
        } else if (gameState.isValidAction(PlayerAction.check)) {
          _performPokerAction(PlayerAction.check);
        } else {
          _performPokerAction(PlayerAction.fold);
        }
      } else if (_tapCount >= 2) {
        // Double tap - Check
        _performPokerAction(PlayerAction.check);
      }
      
      _tapCount = 0;
      _tapTimer = null;
    });
  }

  void recognizeShape() {
    if (points.length < 5) return;

    final bounds = getBounds();
    final width = bounds.width;
    final height = bounds.height;
    
    // Minimum size threshold for gestures
    if (width < 30 && height < 30) return;

    // Check in priority order: Circle first (most specific), then L-shape, then line (most general)
    if (isCircle()) {
      _performPokerAction(PlayerAction.call);
    } else if (hasRightAngle()) {
      // For raise, enter drag mode instead of immediate action
      _enterDragBettingMode(PlayerAction.raise);
    } else if (isLine(width, height)) {
      _performPokerAction(PlayerAction.fold);
    }
  }

  void _enterDragBettingMode(PlayerAction action) async {
    // Show number input dialog instead of drag mode
    final amount = await _showBetAmountDialog(action);

    if (amount != null) {
      // User entered an amount, perform the action
      _performPokerActionWithAmount(action, amount);
    }
    // If amount is null, user cancelled - do nothing
  }

  Future<double?> _showBetAmountDialog(PlayerAction action) async {
    final currentPlayer = gameState.getCurrentPlayer();
    if (currentPlayer == null) return null;

    final minBet = action == PlayerAction.raise
        ? gameState.getMinimumRaise()
        : gameState.getMinimumBet();
    final maxBet = currentPlayer.currentStack + currentPlayer.betThisRound;

    // If player is short-stacked (can't meet min bet), allow all-in for whatever they have
    final effectiveMinBet = maxBet < minBet ? maxBet : minBet;

    // Determine which multiplier mode to use
    final bool isPreflop = gameState.currentRound == BettingRound.preflop;
    final bool hasVoluntaryBet = gameState.hasBetThisRound; // True if someone voluntarily bet/raised (not just blinds)
    final double currentPot = gameState.currentPot;
    final double bigBlind = gameState.bigBlind.toDouble();

    final TextEditingController amountController = TextEditingController();

    return showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(
              color: Color(0xFF161618),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
                  decoration: BoxDecoration(
                    color: Color(0xFF1F1F23),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Color(0xFFcb5242).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.attach_money,
                          color: Color(0xFFcb5242),
                          size: 18,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        action == PlayerAction.raise ? 'Raise Amount' : 'Bet Amount',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Min: ${widget.gameType == GameType.cash ? '\$${effectiveMinBet.toStringAsFixed(2)}' : effectiveMinBet.toInt()} • Max: ${widget.gameType == GameType.cash ? '\$${maxBet.toStringAsFixed(2)}' : maxBet.toInt()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9A9A9A),
                        ),
                      ),
                      SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Color(0xFF1F1F23),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Color(0xFF2A2A2E)),
                        ),
                        child: TextField(
                          controller: amountController,
                          autofocus: true,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: widget.gameType == GameType.cash,
                          ),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            prefixText: widget.gameType == GameType.cash ? '\$ ' : '',
                            prefixStyle: TextStyle(
                              color: Color(0xFF9A9A9A),
                              fontSize: 24,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      // Multiplier buttons - dynamic based on context
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._buildDynamicMultiplierButtons(
                            isPreflop: isPreflop,
                            hasVoluntaryBet: hasVoluntaryBet,
                            currentPot: currentPot,
                            bigBlind: bigBlind,
                            minBet: effectiveMinBet,
                            maxBet: maxBet,
                            amountController: amountController,
                            setState: setState,
                          ),
                          // All-In button
                          _buildAllInButton(maxBet, amountController, setState),
                        ],
                      ),
                    ],
                  ),
                ),
              // Actions
              Container(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Color(0xFF1F1F23),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context, null);
                          },
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: Color(0xFF9A9A9A),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFcb5242), Color(0xFFb8442f)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            final text = amountController.text.trim();
                            double? amount;
                            try {
                              amount = double.parse(text);
                              if (amount < effectiveMinBet || amount > maxBet) {
                                // Show error
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Amount must be between ${effectiveMinBet.toStringAsFixed(widget.gameType == GameType.cash ? 2 : 0)} and ${maxBet.toStringAsFixed(widget.gameType == GameType.cash ? 2 : 0)}',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                            } catch (e) {
                              // Show error
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Please enter a valid number'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            Navigator.pop(context, amount);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Confirm',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDynamicMultiplierButtons({
    required bool isPreflop,
    required bool hasVoluntaryBet,
    required double currentPot,
    required double bigBlind,
    required double minBet,
    required double maxBet,
    required TextEditingController amountController,
    required void Function(void Function()) setState,
  }) {
    // Scenario 1: Preflop with no voluntary bet yet - use BB multipliers
    if (isPreflop && !hasVoluntaryBet) {
      return [
        _buildMultiplierButtonWithBase('2X', 2.0, bigBlind, maxBet, amountController, setState),
        _buildMultiplierButtonWithBase('2.2X', 2.2, bigBlind, maxBet, amountController, setState),
        _buildMultiplierButtonWithBase('2.5X', 2.5, bigBlind, maxBet, amountController, setState),
        _buildMultiplierButtonWithBase('3X', 3.0, bigBlind, maxBet, amountController, setState),
        _buildMultiplierButtonWithBase('4X', 4.0, bigBlind, maxBet, amountController, setState),
      ];
    }

    // Scenario 3: Postflop with pot - use pot percentage multipliers
    if (!isPreflop && currentPot > 0) {
      return [
        _buildPotPercentageButton('25%', 0.25, currentPot, minBet, maxBet, amountController, setState),
        _buildPotPercentageButton('50%', 0.50, currentPot, minBet, maxBet, amountController, setState),
        _buildPotPercentageButton('70%', 0.70, currentPot, minBet, maxBet, amountController, setState),
        _buildPotPercentageButton('100%', 1.0, currentPot, minBet, maxBet, amountController, setState),
        _buildPotPercentageButton('125%', 1.25, currentPot, minBet, maxBet, amountController, setState),
        _buildPotPercentageButton('150%', 1.50, currentPot, minBet, maxBet, amountController, setState),
      ];
    }

    // Scenario 2: There's already a bet/raise - use minBet multipliers
    return [
      _buildMultiplierButtonWithBase('2X', 2.0, minBet, maxBet, amountController, setState),
      _buildMultiplierButtonWithBase('2.2X', 2.2, minBet, maxBet, amountController, setState),
      _buildMultiplierButtonWithBase('2.5X', 2.5, minBet, maxBet, amountController, setState),
      _buildMultiplierButtonWithBase('3X', 3.0, minBet, maxBet, amountController, setState),
      _buildMultiplierButtonWithBase('4X', 4.0, minBet, maxBet, amountController, setState),
    ];
  }

  Widget _buildMultiplierButtonWithBase(
    String label,
    double multiplier,
    double baseAmount,
    double maxBet,
    TextEditingController controller,
    void Function(void Function()) setState,
  ) {
    return InkWell(
      onTap: () {
        double amount = baseAmount * multiplier;
        // Clamp to max bet
        if (amount > maxBet) {
          amount = maxBet;
        }
        // Round appropriately
        if (widget.gameType == GameType.cash) {
          amount = (amount * 4).round() / 4; // Round to nearest $0.25
        } else {
          amount = amount.round().toDouble(); // Round to nearest chip
        }
        setState(() {
          controller.text = widget.gameType == GameType.cash
              ? amount.toStringAsFixed(2)
              : amount.toInt().toString();
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Color(0xFF1F1F23),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Color(0xFF2A2A2E)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Color(0xFFcb5242),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildPotPercentageButton(
    String label,
    double percentage,
    double potSize,
    double minBet,
    double maxBet,
    TextEditingController controller,
    void Function(void Function()) setState,
  ) {
    return InkWell(
      onTap: () {
        double amount = potSize * percentage;
        // Ensure it's at least the minimum bet
        if (amount < minBet) {
          amount = minBet;
        }
        // Clamp to max bet
        if (amount > maxBet) {
          amount = maxBet;
        }
        // Round appropriately
        if (widget.gameType == GameType.cash) {
          amount = (amount * 4).round() / 4; // Round to nearest $0.25
        } else {
          amount = amount.round().toDouble(); // Round to nearest chip
        }
        setState(() {
          controller.text = widget.gameType == GameType.cash
              ? amount.toStringAsFixed(2)
              : amount.toInt().toString();
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Color(0xFF1F1F23),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Color(0xFF2A2A2E)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Color(0xFFcb5242),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildAllInButton(
    double maxBet,
    TextEditingController controller,
    void Function(void Function()) setState,
  ) {
    return InkWell(
      onTap: () {
        setState(() {
          controller.text = widget.gameType == GameType.cash
              ? maxBet.toStringAsFixed(2)
              : maxBet.toInt().toString();
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFcb5242), Color(0xFFb8442f)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Color(0xFFcb5242)),
        ),
        child: Text(
          'All-In',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMultiplierButton(
    String label,
    double multiplier,
    double minBet,
    double maxBet,
    TextEditingController controller,
    void Function(void Function()) setState,
  ) {
    return InkWell(
      onTap: () {
        double amount = minBet * multiplier;
        // Clamp to max bet
        if (amount > maxBet) {
          amount = maxBet;
        }
        // Round appropriately
        if (widget.gameType == GameType.cash) {
          amount = (amount * 4).round() / 4; // Round to nearest $0.25
        } else {
          amount = amount.round().toDouble(); // Round to nearest chip
        }
        setState(() {
          controller.text = widget.gameType == GameType.cash
              ? amount.toStringAsFixed(2)
              : amount.toInt().toString();
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Color(0xFF1F1F23),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Color(0xFF2A2A2E)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Color(0xFFcb5242),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showDragBettingInstruction() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _pendingAction == PlayerAction.raise 
            ? 'Drag to set raise amount' 
            : 'Drag to set bet amount',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _updateDragBetAmount(double totalDeltaY) {
    if (!_isDragBetting || _pendingAction == null) return;
    
    final currentPlayer = gameState.getCurrentPlayer();
    if (currentPlayer == null) return;
    
    // Calculate sensitivity dynamically based on player's stack and screen size
    final minBet = _pendingAction == PlayerAction.raise
        ? gameState.getMinimumRaise()
        : gameState.getMinimumBet();
    // For all-in calculation, include what player has already bet this round
    final maxBet = currentPlayer.currentStack + currentPlayer.betThisRound;

    // If player is short-stacked (can't meet min bet), use maxBet as both min and max
    final effectiveMinBet = maxBet < minBet ? maxBet : minBet;
    final betRange = maxBet - effectiveMinBet;

    // Use actual screen height for better sensitivity calculation
    // Use 60% of screen height as effective drag area
    final screenHeight = MediaQuery.of(context).size.height;
    final effectiveDragArea = screenHeight * 0.6; // 60% of screen height
    final sensitivity = betRange > 0 ? betRange / effectiveDragArea : 0;

    // Calculate new bet amount based on total drag distance from start
    // Negative totalDeltaY = drag up = increase bet
    // Positive totalDeltaY = drag down = decrease bet
    final totalBetChange = -totalDeltaY * sensitivity;

    double newBetAmount = (effectiveMinBet + totalBetChange).clamp(effectiveMinBet, maxBet);
    
    // Round to appropriate increments
    if (widget.gameType == GameType.cash) {
      // Round to nearest $0.25
      newBetAmount = (newBetAmount * 4).round() / 4;
    } else {
      // For tournaments, round to nearest 1 chip
      newBetAmount = newBetAmount.round().toDouble();

      // All-in detection: if within 5% of max bet, just go all-in
      final allInThreshold = (maxBet * 0.05).clamp(1.0, 10.0);
      if ((maxBet - newBetAmount) <= allInThreshold) {
        newBetAmount = maxBet;
      }
    }

    // Ensure we never exceed the player's stack
    newBetAmount = newBetAmount.clamp(effectiveMinBet, maxBet);

    // Calculate drag bar position (0 = bottom/min bet, 1 = top/max bet)
    final betProgress = betRange > 0 ? (newBetAmount - effectiveMinBet) / betRange : 0;
    final dragBarPosition = betProgress.clamp(0.0, 1.0);
    
    setState(() {
      _dragBetAmount = newBetAmount;
      _dragBarPosition = dragBarPosition.toDouble();
    });
  }

  void _completeDragBetting() {
    if (!_isDragBetting || _pendingAction == null) return;
    
    final action = _pendingAction!;
    final amount = _dragBetAmount;
    
    // Reset drag state BEFORE performing action to prevent corruption
    _resetDragBettingState();
    
    // Perform the action with the specified amount
    _performPokerActionWithAmount(action, amount);
  }

  void _resetDragBettingState() {
    setState(() {
      _isDragBetting = false;
      _pendingAction = null;
      _dragBetAmount = 0.0;
      _dragStartPosition = null;
      _dragBarPosition = 0.0;
    });
  }

  void _cancelDragBetting() {
    _resetDragBettingState();
  }

  void _performPokerActionWithAmount(PlayerAction action, double amount) {
    if (gameState.bettingRoundComplete) {
      addAction("Betting round is complete. Press 'Next Street' to continue.");
      _triggerInvalidActionVibration();
      return;
    }

    // Check if action is valid before performing it
    if (!gameState.isValidAction(action)) {
      _triggerInvalidActionVibration();
      addAction("Invalid action: ${action.name}. ${_getValidActionsHint()}");
      return;
    }

    // Get current player stack before action
    final currentPlayerStack = gameState.getPlayerStack(gameState.currentPlayer);

    // Record action in session manager BEFORE performing it
    sessionManager.recordAction(
      gameState.currentPlayer,
      action,
      gameState.currentRound,
      gameState.buttonPosition,
      playerStack: currentPlayerStack,
      amount: amount,
    );

    // Perform action with specified amount
    String result = gameState.performActionWithAmount(action, amount);

    // Split result into individual lines and add each as separate action
    for (String line in result.split('\n')) {
      if (line.trim().isNotEmpty) {
        addAction(line.trim());
      }
    }
    
    // Check if hand ended automatically (only one player remaining)
    if (result.contains("Hand ends: Only one player remaining")) {
      // Use a post frame callback to avoid calling setState during build
      _schedulePostFrameAction(() {
        addAction("🏆 Hand completed automatically - only one player remaining");
        _completeHandAutomatically();
      });
    } else {
      // Check if everyone has folded to BB preflop (special case)
      _checkForAutomaticHandEnd();
      
      // Check for auto-advance scenarios: all-in OR regular betting round completion
      if (gameState.bettingRoundComplete && gameState.currentRound != BettingRound.river) {
        // Use a post frame callback to avoid calling setState during build
        _schedulePostFrameAction(() {
          if (gameState.shouldAutoAdvanceToShowdown()) {
            // This is an all-in situation - show all-in board dialog
            addAction("🎯 All-in situation detected - no more actions possible");
            _showAllInBoardCardsDialog();
          } else if (gameState.areAllPlayersAllIn()) {
            addAction("🎯 All players all-in - auto-advancing to next street...");
            nextStreet();
          } else if (autoAdvanceStreets) {
            addAction("🚀 Auto-advancing to next street...");
            nextStreet();
          }
        });
      } else if (gameState.areAllPlayersAllIn() && gameState.currentRound != BettingRound.river && !gameState.bettingRoundComplete) {
        // Handle edge case: all-in detected but betting round not marked complete yet
        _schedulePostFrameAction(() {
          addAction("🎯 All players all-in - ending betting round...");
          gameState.bettingRoundComplete = true;
          setState(() {});
        });
      }
    }
    
    // Update UI
    setState(() {});
  }

  void _skipCurrentAction() {
    // Skip the entire hand - move button and start fresh without incrementing hand number
    setState(() {
      // Move button to next active player
      int nextButton = gameState.buttonPosition;
      int attempts = 0;
      do {
        nextButton = (nextButton % gameState.numberOfPlayers) + 1;
        attempts++;
      } while ((!gameState.players[nextButton - 1].isActive || gameState.players[nextButton - 1].currentStack <= 0) && attempts < gameState.numberOfPlayers);

      if (attempts < gameState.numberOfPlayers) {
        gameState.buttonPosition = nextButton;
      }

      // CRITICAL: Refund all pot contributions back to players before resetting
      // This ensures stacks remain correct when skipping incomplete hands
      for (var player in gameState.players) {
        if (player.isActive) {
          // Calculate total contribution (current round + previous rounds)
          final totalContribution = player.betThisRound + player.totalContribution;
          if (totalContribution > 0) {
            // Refund the contribution back to stack
            player.currentStack += totalContribution;
            addAction("💵 Refunded ${_formatCurrency(totalContribution)} to Player ${player.playerId}");
          }
        }
      }

      // Reset all players
      for (var player in gameState.players) {
        player.reset();
      }

      // Reset game state
      gameState.currentRound = BettingRound.preflop;
      gameState.bettingRoundComplete = false;
      gameState.hasBetThisRound = false;
      gameState.currentPot = 0.0;
      gameState.currentBet = 0.0;

      // Initialize pot with blinds for new hand
      gameState.initializePot();

      // Update sessionManager with new blind positions so position names show correctly
      sessionManager.actualSBSeat = gameState.effectiveSBPosition;
      sessionManager.actualBBSeat = gameState.effectiveBBPosition;
      sessionManager.buttonPosition = gameState.buttonPosition;

      // CRITICAL: Restart the hand in session manager to recalculate positions
      // This is necessary if players were added/removed since the hand originally started
      sessionManager.startHand(
        gameState.handNumber,
        gameState.buttonPosition,
        sbSeat: gameState.effectiveSBPosition,
        bbSeat: gameState.effectiveBBPosition,
      );

      // Set initial action order manually (can't call private _setInitialActionOrder)
      List<int> activePlayers = gameState.getActivePlayers();
      if (activePlayers.length >= 2) {
        if (activePlayers.length == 2) {
          // Heads up: button acts first preflop
          gameState.currentPlayer = activePlayers.contains(gameState.buttonPosition)
              ? gameState.buttonPosition
              : activePlayers[0];
        } else {
          // Multi-way: UTG acts first (first active player after BB)
          int bbPosition = gameState.effectiveBBPosition;
          int utgPosition = gameState.currentPlayer; // Will be set properly

          // Find first active player after BB
          int nextPlayer = bbPosition;
          int attempts = 0;
          do {
            nextPlayer = (nextPlayer % gameState.numberOfPlayers) + 1;
            attempts++;
            if (activePlayers.contains(nextPlayer)) {
              utgPosition = nextPlayer;
              break;
            }
          } while (attempts < gameState.numberOfPlayers);

          gameState.currentPlayer = utgPosition;
        }
      } else if (activePlayers.isNotEmpty) {
        gameState.currentPlayer = activePlayers[0];
      }

      // Clear actions and add skip message
      actions.clear();
      actions.add("⏭️ Hand skipped - Button moved to Player ${gameState.buttonPosition}");
      actions.add("Hand #${gameState.handNumber} ready");
      actions.add(gameState.getGameStateInfo());
      actions.add(_getToActMessage());
    });
  }

  void _performPokerAction(PlayerAction action) {
    if (gameState.bettingRoundComplete) {
      addAction("Betting round is complete. Press 'Next Street' to continue.");
      _triggerInvalidActionVibration();
      return;
    }

    // Check if action is valid before performing it
    if (!gameState.isValidAction(action)) {
      _triggerInvalidActionVibration();
      addAction("Invalid action: ${action.name}. ${_getValidActionsHint()}");
      return;
    }

    // Get current player stack before action
    final currentPlayerStack = gameState.getPlayerStack(gameState.currentPlayer);

    // For call actions, calculate the amount being called
    double? actionAmount;
    if (action == PlayerAction.call) {
      final player = gameState.players[gameState.currentPlayer - 1];
      final callAmount = gameState.getCurrentBet() - player.betThisRound;
      actionAmount = callAmount.clamp(0.0, player.currentStack);
    }

    // Record action in session manager BEFORE performing it
    sessionManager.recordAction(
      gameState.currentPlayer,
      action,
      gameState.currentRound,
      gameState.buttonPosition,
      playerStack: currentPlayerStack,
      amount: actionAmount,
    );

    String result = gameState.performAction(action);

    // Split result into individual lines and add each as separate action
    for (String line in result.split('\n')) {
      if (line.trim().isNotEmpty) {
        addAction(line.trim());
      }
    }
    
    // Check if hand ended automatically (only one player remaining)
    if (result.contains("Hand ends: Only one player remaining")) {
      // Use a post frame callback to avoid calling setState during build
      _schedulePostFrameAction(() {
        addAction("🏆 Hand completed automatically - only one player remaining");
        _completeHandAutomatically();
      });
    } else {
      // Check if everyone has folded to BB preflop (special case)
      _checkForAutomaticHandEnd();
      
      // Check for auto-advance scenarios: all-in OR regular betting round completion
      if (gameState.bettingRoundComplete && gameState.currentRound != BettingRound.river) {
        // Use a post frame callback to avoid calling setState during build
        _schedulePostFrameAction(() {
          if (gameState.shouldAutoAdvanceToShowdown()) {
            // This is an all-in situation - show all-in board dialog
            addAction("🎯 All-in situation detected - no more actions possible");
            _showAllInBoardCardsDialog();
          } else if (gameState.areAllPlayersAllIn()) {
            addAction("🎯 All players all-in - auto-advancing to next street...");
            nextStreet();
          } else if (autoAdvanceStreets) {
            addAction("🚀 Auto-advancing to next street...");
            nextStreet();
          }
        });
      } else if (gameState.areAllPlayersAllIn() && gameState.currentRound != BettingRound.river && !gameState.bettingRoundComplete) {
        // Handle edge case: all-in detected but betting round not marked complete yet
        _schedulePostFrameAction(() {
          addAction("🎯 All players all-in - ending betting round...");
          gameState.bettingRoundComplete = true;
          setState(() {});
        });
      }
    }
    
    // Update UI
    setState(() {});
  }

  Rect getBounds() {
    if (points.isEmpty) return Rect.zero;
    
    double minX = points.first.dx;
    double maxX = points.first.dx;
    double minY = points.first.dy;
    double maxY = points.first.dy;

    for (final point in points) {
      minX = point.dx < minX ? point.dx : minX;
      maxX = point.dx > maxX ? point.dx : maxX;
      minY = point.dy < minY ? point.dy : minY;
      maxY = point.dy > maxY ? point.dy : maxY;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  bool isLine(double width, double height) {
    if (width < 30 && height < 30) return false;
    
    // Check if it's predominantly horizontal or vertical
    final aspectRatio = width / height;
    if (aspectRatio < 3.0 && aspectRatio > 0.33) return false;
    
    // Check that start and end are NOT close (not closed)
    final firstPoint = points.first;
    final lastPoint = points.last;
    final closureDistance = sqrt(pow(lastPoint.dx - firstPoint.dx, 2) + pow(lastPoint.dy - firstPoint.dy, 2));
    final maxDimension = max(width, height);
    final closureRatio = closureDistance / maxDimension;
    
    if (closureRatio < 0.5) return false;
    
    return true;
  }

  bool isCircle() {
    if (points.length < 8) return false;
    
    final bounds = getBounds();
    final width = bounds.width;
    final height = bounds.height;
    
    if (width < 40 || height < 40) return false;
    
    // Check aspect ratio - should be roughly square
    final aspectRatio = width / height;
    if (aspectRatio < 0.4 || aspectRatio > 2.5) return false;
    
    // Check if start and end points are close (closed shape)
    final firstPoint = points.first;
    final lastPoint = points.last;
    final closureDistance = sqrt(pow(lastPoint.dx - firstPoint.dx, 2) + pow(lastPoint.dy - firstPoint.dy, 2));
    final maxDimension = max(width, height);
    final closureRatio = closureDistance / maxDimension;
    
    // For a circle/oval, start and end should be close
    if (closureRatio > 0.5) return false;
    
    return true;
  }

  bool hasRightAngle() {
    if (points.length < 6) return false;
    
    final bounds = getBounds();
    if (bounds.width < 30 || bounds.height < 30) return false;
    
    // Check that start and end are NOT close (not a closed shape like circle)
    final firstPoint = points.first;
    final lastPoint = points.last;
    final closureDistance = sqrt(pow(lastPoint.dx - firstPoint.dx, 2) + pow(lastPoint.dy - firstPoint.dy, 2));
    final maxDimension = max(bounds.width, bounds.height);
    final closureRatio = closureDistance / maxDimension;
    
    if (closureRatio < 0.3) return false;
    
    // Simple approach: divide gesture into two halves and check if they're perpendicular
    int midPoint = points.length ~/ 2;
    
    // First half direction
    Offset start1 = points[0];
    Offset end1 = points[midPoint];
    double dx1 = end1.dx - start1.dx;
    double dy1 = end1.dy - start1.dy;
    
    // Second half direction  
    Offset start2 = points[midPoint];
    Offset end2 = points[points.length - 1];
    double dx2 = end2.dx - start2.dx;
    double dy2 = end2.dy - start2.dy;
    
    double mag1 = sqrt(dx1 * dx1 + dy1 * dy1);
    double mag2 = sqrt(dx2 * dx2 + dy2 * dy2);
    
    if (mag1 < 20 || mag2 < 20) return false;
    
    // Check angle between segments
    double dotProduct = dx1 * dx2 + dy1 * dy2;
    double cosAngle = dotProduct / (mag1 * mag2);
    double angle = acos(cosAngle.clamp(-1.0, 1.0));
    double angleDegrees = angle * 180 / pi;
    
    // Check if angle is roughly 90 degrees (60-120 degrees tolerance)
    return angleDegrees >= 60 && angleDegrees <= 120;
  }

  void nextStreet() {
    // Check if we're transitioning from River - might need showdown
    if (gameState.currentRound == BettingRound.river) {
      // Save river pot before completing hand
      sessionManager.savePotForStreet(BettingRound.river, gameState.currentPot);
      _handleHandComplete();
      return;
    }

    // Check if this is an all-in situation where no one can act
    if (gameState.shouldAutoAdvanceToShowdown()) {
      addAction("🎯 All-in situation - selecting all board cards");
      _showAllInBoardCardsDialog();
      return;
    }

    // First proceed to next street
    _proceedToNextStreet();

    // Then show board cards dialog for the street we just entered
    if (gameState.currentRound == BettingRound.flop ||
        gameState.currentRound == BettingRound.turn ||
        gameState.currentRound == BettingRound.river) {
      _showBoardCardsDialog(gameState.currentRound);
    }
  }

  BettingRound? _getNextRound(BettingRound current) {
    switch (current) {
      case BettingRound.preflop: return BettingRound.flop;
      case BettingRound.flop: return BettingRound.turn;
      case BettingRound.turn: return BettingRound.river;
      case BettingRound.river: return null;
    }
  }

  bool _shouldShowBoardCards(BettingRound round) {
    return round == BettingRound.flop || 
           round == BettingRound.turn || 
           round == BettingRound.river;
  }

  // Check if we should show all-in board card dialog instead of street-by-street
  bool _shouldShowAllInBoardDialog() {
    // We should show all-in dialog when:
    // 1. We're in a situation where no one can act anymore (all-in showdown)
    // 2. AND we haven't set all board cards yet
    if (!gameState.shouldAutoAdvanceToShowdown()) return false;

    final currentHand = sessionManager.currentHand;
    final boardCards = currentHand?.boardCards;

    // Check if we have all board cards already
    if (boardCards != null) {
      bool hasAllCards = boardCards.flop.length == 3 &&
                        boardCards.turn != null && boardCards.turn!.isNotEmpty &&
                        boardCards.river != null && boardCards.river!.isNotEmpty;
      if (hasAllCards) return false; // Already has all cards
    }

    return true;
  }

  void _showAllInBoardCardsDialog() async {
    await LoggerService.info('🎲 _showAllInBoardCardsDialog() called - All-in board selection');

    // Collect hole cards to exclude from board card selection
    List<String> excludedCards = [];
    final ourHoleCards = sessionManager.currentHand?.ourHoleCards;
    if (ourHoleCards?.card1 != null && ourHoleCards!.card1!.isNotEmpty) {
      excludedCards.add(ourHoleCards!.card1!);
    }
    if (ourHoleCards?.card2 != null && ourHoleCards!.card2!.isNotEmpty) {
      excludedCards.add(ourHoleCards!.card2!);
    }

    final result = await showDialog<BoardCards>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AllInBoardCardsDialog(
        excludedCards: excludedCards,
        existingBoardCards: sessionManager.currentHand?.boardCards,
      ),
    );

    if (result != null && sessionManager.currentHand != null) {
      sessionManager.currentHand!.setBoardCards(result);
      addAction("🃏 All board cards selected: ${result.flop.join(' ')} ${result.turn} ${result.river}");

      // Skip to river (since we have all cards now)
      gameState.currentRound = BettingRound.river;
      gameState.bettingRoundComplete = true;

      setState(() {});

      // Now show winner selection
      _showWinnerSelectionForAllIn();
    }
  }


  void _showWinnerSelectionForAllIn() async {
    await LoggerService.info('🏆 _showWinnerSelectionForAllIn() called - Winner selection for all-in');

    // Get active players and their names
    final activePlayers = gameState.getActivePlayers();
    await LoggerService.debug('  Active players: $activePlayers (count: ${activePlayers.length})');
    List<String> playerNames = [];

    for (int playerId in activePlayers) {
      String playerName = sessionManager.getPlayerNameWithPosition(playerId);
      playerNames.add(playerName);
    }

    final potAmount = gameState.currentPot;

    final winnerResult = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => WinnerSelectionDialog(
        activePlayers: activePlayers,
        playerNames: playerNames,
        potAmount: potAmount,
        gameType: widget.gameType,
        buttonPosition: gameState.buttonPosition,
        playerCount: gameState.numberOfPlayers,
      ),
    );

    if (winnerResult != null) {
      // Process the winner result and complete the hand
      _processAllInWinnerResult(winnerResult);
    }
  }

  void _processAllInWinnerResult(Map<String, dynamic> winnerResult) {
    LoggerService.info('💰 _processAllInWinnerResult() called - Processing all-in winner');
    final isChoppedPot = winnerResult['isChoppedPot'] as bool? ?? false;
    LoggerService.debug('  isChoppedPot: $isChoppedPot');

    // Mark hand as completed and use the standard finalization flow
    _allInHandCompleted = true;
    setState(() {});
    addAction("✅ All-in hand completed!");

    if (isChoppedPot) {
      // Handle chopped pot
      final winnerIds = List<int>.from(winnerResult['winnerIds'] ?? []);
      final potAmount = winnerResult['potAmount'] as double? ?? gameState.currentPot;
      final individualShares = winnerResult['individualShares'] as Map<int, double>?;
      final sharePerWinner = winnerResult['sharePerWinner'] as double?;

      addAction("🏆 Chopped pot between ${winnerIds.length} players");
    } else {
      // Handle single winner
      final winnerId = winnerResult['winnerId'] as int? ?? winnerResult['winner'] as int?;
      final potAmount = winnerResult['potAmount'] as double? ?? gameState.currentPot;

      if (winnerId != null) {
        final winnerName = sessionManager.getPlayerNameWithPosition(winnerId);
        addAction("🏆 Winner: $winnerName");
      }
    }

    // Show hole cards dialog first, then complete the hand with winner info
    Future.delayed(Duration(milliseconds: 500), () async {
      // Show hole cards dialog first
      await _showHoleCardsDialog();

      // Get active players and winners for opponent cards dialog
      final activePlayers = gameState.getActivePlayers();
      final List<int> winners;
      if (isChoppedPot) {
        winners = List<int>.from(winnerResult['winnerIds'] ?? []);
      } else {
        final winnerId = winnerResult['winnerId'] as int? ?? winnerResult['winner'] as int?;
        winners = winnerId != null ? [winnerId] : [];
      }

      // Show opponent hole cards dialog for showdown situations
      await _showOpponentCardsDialog(activePlayers, winners);

      // Now complete the hand with proper winner info
      if (isChoppedPot) {
        final winnerIds = List<int>.from(winnerResult['winnerIds'] ?? []);
        final potAmount = winnerResult['potAmount'] as double? ?? gameState.currentPot;
        final individualShares = winnerResult['individualShares'] as Map<int, double>?;
        final sharePerWinner = winnerResult['sharePerWinner'] as double?;

        // Get current stack for our seat to track in session history
        final ourSeat = sessionManager.ourSeatNumber;
        final currentStack = ourSeat != null ? gameState.players[ourSeat - 1].currentStack : null;

        sessionManager.completeCurrentHandWithChop(
          potAmount: potAmount,
          winnerIds: winnerIds,
          individualShares: individualShares,
          sharePerWinner: sharePerWinner,
          currentStack: currentStack,
        );

        // Update winners' stacks in game state to prevent them being marked as busted
        for (int winnerId in winnerIds) {
          final winnerPlayer = gameState.players[winnerId - 1];
          final winnerShare = individualShares?[winnerId] ?? (sharePerWinner ?? (potAmount / winnerIds.length));
          winnerPlayer.currentStack += winnerShare;
        }
      } else {
        final winnerId = winnerResult['winnerId'] as int? ?? winnerResult['winner'] as int?;
        final potAmount = winnerResult['potAmount'] as double? ?? gameState.currentPot;

        if (winnerId != null) {
          // Get current stack for our seat to track in session history
          final ourSeat = sessionManager.ourSeatNumber;
          final currentStack = ourSeat != null ? gameState.players[ourSeat - 1].currentStack : null;

          sessionManager.completeCurrentHand(
            potAmount: potAmount,
            winnerId: winnerId,
            currentStack: currentStack,
          );

          // Update winner's stack in game state to prevent them being marked as busted
          final winnerPlayer = gameState.players[winnerId - 1];
          winnerPlayer.currentStack += potAmount;
        }
      }

      // Check for busted players and start next hand
      await _checkForBustedPlayers();

      setState(() {
        // Reset all-in completion flag for new hand
        _allInHandCompleted = false;

        // Start new hand in game state
        gameState.startNewHand();

        // Start new hand in session manager
        sessionManager.startHand(
          gameState.handNumber,
          gameState.buttonPosition,
          sbSeat: gameState.effectiveSBPosition,
          bbSeat: gameState.effectiveBBPosition,
        );

        actions.clear(); // Clear actions for new hand
        actions.add("💾 Hand #${gameState.handNumber - 1} saved");
        actions.add("Hand #${gameState.handNumber} started");
        actions.add(gameState.getGameStateInfo());
        actions.add(_getToActMessage());
      });
    });
  }

  void _showBoardCardsDialog(BettingRound round) {
    // Check if we should show all-in board card dialog instead
    if (_shouldShowAllInBoardDialog()) {
      _showAllInBoardCardsDialog();
      return;
    }

    // Log what board cards exist before showing dialog
    final currentBoardCards = sessionManager.currentHand?.boardCards;
    if (currentBoardCards != null) {
      print('🎴 Board cards dialog opening - existing cards found:');
      print('   Flop: ${currentBoardCards.flop}');
      print('   Turn: ${currentBoardCards.turn}');
      print('   River: ${currentBoardCards.river}');
    } else {
      print('🎴 Board cards dialog opening - NO existing cards (clean slate)');
    }

    // Regular street-by-street dialog
    // Collect hole cards to exclude from board card selection
    List<String> excludedCards = [];
    final ourHoleCards = sessionManager.currentHand?.ourHoleCards;
    if (ourHoleCards?.card1 != null && ourHoleCards!.card1!.isNotEmpty) {
      excludedCards.add(ourHoleCards.card1!);
    }
    if (ourHoleCards?.card2 != null && ourHoleCards!.card2!.isNotEmpty) {
      excludedCards.add(ourHoleCards.card2!);
    }
    
    // Collect cards already committed in previous streets
    Set<String> usedCards = {};
    final boardCards = sessionManager.currentHand?.boardCards;
    if (boardCards != null) {
      // Add flop cards if we're on turn or river
      if (round != BettingRound.flop && boardCards.flop.isNotEmpty) {
        usedCards.addAll(boardCards.flop);
      }
      // Add turn card if we're on river
      if (round == BettingRound.river && boardCards.turn != null && boardCards.turn!.isNotEmpty) {
        usedCards.add(boardCards.turn!);
      }
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BoardCardsDialog(
        currentRound: round,
        existingCards: sessionManager.currentHand?.boardCards,
        excludedCards: excludedCards,
        usedCards: usedCards,
      ),
    ).then((result) {
      if (result is BoardCards) {
        // Save board cards to current hand
        sessionManager.currentHand?.setBoardCards(result);
        
        // Add board cards info to actions
        _addBoardCardsAction(result, round);
      }
      
      // Always proceed to next street after dialog
      _proceedToNextStreet();
    });
  }

  void _addBoardCardsAction(BoardCards cards, BettingRound round) {
    switch (round) {
      case BettingRound.flop:
        if (cards.flop.isNotEmpty) {
          addAction("Flop: ${cards.flop.join(' ')}");
        }
        break;
      case BettingRound.turn:
        if (cards.turn != null) {
          addAction("Turn: ${cards.turn}");
        }
        break;
      case BettingRound.river:
        if (cards.river != null) {
          addAction("River: ${cards.river}");
        }
        break;
      default:
        break;
    }
  }

  // Navigate to session details screen
  Future<void> _showSessionDetails() async {
    // Get current stack for our seat
    final ourSeat = sessionManager.ourSeatNumber;
    final currentStack = ourSeat != null ? gameState.players[ourSeat - 1].currentStack : (widget.individualCurrentStack ?? 0.0);

    // Navigate to individual session tracking screen with current data
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => IndividualSessionTrackingScreen(
          sessionName: sessionManager.sessionName ?? 'Poker Session',
          buyInAmount: widget.buyInAmount ?? sessionManager.totalBuyIn, // Initial buy-in amount (money)
          startingStack: sessionManager.initialStartingStack ?? sessionManager.totalBuyIn, // Starting chips (MTT) or buy-in (cash)
          gameType: widget.gameType,
          smallBlind: sessionManager.smallBlind, // Use current blinds from sessionManager, not widget
          bigBlind: sessionManager.bigBlind, // Use current blinds from sessionManager, not widget
          hasBBante: gameState.hasBBante,
          currentStack: currentStack,
          sessionId: sessionManager.sessionId,
          isFromActiveSession: true, // Indicate this is from an active poker session
        ),
      ),
    );

    // Update stack and blinds if changed in session details
    if (result != null) {
      if (result['updatedStack'] != null) {
        final updatedStack = result['updatedStack'] as double;
        final updatedTotalBuyIn = result['totalBuyIn'] as double;

        // Update the player's stack in game state
        if (ourSeat != null && ourSeat >= 1 && ourSeat <= gameState.players.length) {
          setState(() {
            gameState.players[ourSeat - 1].currentStack = updatedStack;
            sessionManager.totalBuyIn = updatedTotalBuyIn;
          });
        }
      }

      // Update blinds if they were changed
      if (result['smallBlind'] != null && result['bigBlind'] != null) {
        final newSmallBlind = result['smallBlind'] as int;
        final newBigBlind = result['bigBlind'] as int;
        final newHasBBante = result['hasBBante'] as bool? ?? false;

        setState(() {
          // Update sessionManager blinds
          sessionManager.smallBlind = newSmallBlind;
          sessionManager.bigBlind = newBigBlind;

          // Update gameState blinds
          gameState.smallBlind = newSmallBlind;
          gameState.bigBlind = newBigBlind;
          gameState.hasBBante = newHasBBante;
        });

        // Save blinds to preferences for persistence
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('small_blind', newSmallBlind);
        await prefs.setInt('big_blind', newBigBlind);
      }
    }
  }

  // Confirmation dialog for rebuy when user has existing stack
  Future<bool?> _showRebuyConfirmationDialog(double currentStack) async {
    // Format stack value based on game type
    String formatStackValue(double value) {
      return widget.gameType == GameType.cash
          ? '\$${value.toStringAsFixed(2)}'
          : value.toStringAsFixed(0);
    }

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PokerFriendColors.dark3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: PokerFriendColors.red, size: 24),
            SizedBox(width: 12),
            Text(
              'Confirm Rebuy',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You currently have ${formatStackValue(currentStack)} remaining.',
              style: TextStyle(
                color: PokerFriendColors.dark10,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Proceeding with a rebuy will replace your current stack. Are you sure you want to continue?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: PokerFriendColors.dark10,
                fontSize: 16,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: PokerFriendColors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Proceed with Rebuy',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRebuyDialog() async {
    if (widget.gameType != GameType.tournament) return;

    // Check if user has existing stack and confirm they want to lose it
    final ourSeat = sessionManager.ourSeatNumber;
    final currentStack = ourSeat != null ? gameState.players[ourSeat - 1].currentStack : (widget.individualCurrentStack ?? 0.0);
    if (currentStack > 0) {
      final confirmed = await _showRebuyConfirmationDialog(currentStack);
      if (confirmed != true) {
        return; // User cancelled, don't proceed with rebuy
      }
    }

    final rebuyAmountController = TextEditingController();
    final stackSizeController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: PokerFriendColors.dark3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.add_circle_outline, color: PokerFriendColors.red, size: 24),
              SizedBox(width: 12),
              Text(
                'Rebuy',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter rebuy details for the tournament',
                  style: TextStyle(
                    color: PokerFriendColors.dark10,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 20),

                // Rebuy Amount Input
                TextField(
                  controller: rebuyAmountController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Rebuy Amount',
                    labelStyle: TextStyle(color: PokerFriendColors.dark9),
                    prefixText: '\$ ',
                    prefixStyle: TextStyle(color: Colors.white, fontSize: 16),
                    filled: true,
                    fillColor: PokerFriendColors.dark1,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),

                SizedBox(height: 16),

                // Stack Size Input
                TextField(
                  controller: stackSizeController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'New Stack Size',
                    labelStyle: TextStyle(color: PokerFriendColors.dark9),
                    hintText: 'Chip count after rebuy',
                    hintStyle: TextStyle(color: PokerFriendColors.dark8),
                    filled: true,
                    fillColor: PokerFriendColors.dark1,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),

                SizedBox(height: 20),

                // Current session info
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: PokerFriendColors.dark3,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: PokerFriendColors.dark4, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session Info',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Total Invested: \$${sessionManager.totalBuyIn.toStringAsFixed(2)}',
                        style: TextStyle(color: PokerFriendColors.dark10, fontSize: 12),
                      ),
                      Text(
                        'Rebuys: ${sessionManager.getRebuyCount()}',
                        style: TextStyle(color: PokerFriendColors.dark10, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: PokerFriendColors.dark10,
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final rebuyAmount = double.tryParse(rebuyAmountController.text);
                final stackSize = double.tryParse(stackSizeController.text);

                if (rebuyAmount != null && stackSize != null && rebuyAmount > 0 && stackSize > 0) {
                  // Add rebuy to session manager
                  sessionManager.addRebuy(
                    amount: rebuyAmount,
                    stack: stackSize,
                  );

                  // Update the player's current stack in game state
                  final ourSeat = sessionManager.ourSeatNumber;
                  if (ourSeat != null && ourSeat >= 1 && ourSeat <= gameState.players.length) {
                    setState(() {
                      gameState.players[ourSeat - 1].currentStack = stackSize;
                    });
                  }

                  Navigator.pop(context);

                  // Show confirmation
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Rebuy added: \$${rebuyAmount.toStringAsFixed(2)} (Stack: ${stackSize.toStringAsFixed(0)})'),
                      backgroundColor: PokerFriendColors.red,
                    ),
                  );
                } else {
                  // Show error
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter valid amounts'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: PokerFriendColors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Add Rebuy',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _proceedToNextStreet() {
    setState(() {
      String streetTransitionResult = gameState.startNewStreet(
        onStreetComplete: (BettingRound completedStreet, double potAmount) {
          // Save pot amount for the completed street
          sessionManager.savePotForStreet(completedStreet, potAmount);
        },
      );

      // Show uncalled bet returns if any
      if (streetTransitionResult.isNotEmpty) {
        for (String line in streetTransitionResult.split('\n')) {
          if (line.trim().isNotEmpty) {
            addAction(line.trim());
          }
        }
      }

      addAction("--- ${gameState.getCurrentStreetName()} ---");
      addAction(_getToActMessage());
    });
  }

  void endStreetManually() {
    setState(() {
      gameState.bettingRoundComplete = true;
      addAction("--- Street ended manually ---");
      if (gameState.currentRound != BettingRound.river) {
        addAction("Press 'Next Street' button to continue");
      }
    });
  }

  /// Check if undo is allowed
  /// Returns true if there are actions that can be undone (non-blind posts)
  bool _canUndoLastAction() {
    if (sessionManager.currentHand == null ||
        sessionManager.currentHand!.actions.isEmpty) {
      return false;
    }

    // Don't allow undo if hand is completed
    if (sessionManager.currentHand!.state != HandState.inProgress) {
      return false;
    }

    // Don't allow undo if betting round is complete (they need to advance first)
    if (gameState.bettingRoundComplete) {
      return false;
    }

    // Find the last non-blind action
    final actions = sessionManager.currentHand!.actions;
    for (int i = actions.length - 1; i >= 0; i--) {
      final action = actions[i];
      // Allow undo for any action except blind posts
      if (action.action != PlayerAction.none) {
        return true;
      }
    }

    return false;
  }

  /// Undo the last action and restore game state
  void _undoLastAction() {
    if (!_canUndoLastAction()) {
      addAction("⚠️ Cannot undo: no actions to undo");
      _triggerInvalidActionVibration();
      return;
    }

    final actions = sessionManager.currentHand!.actions;

    // Find the last non-blind action
    int lastActionIndex = -1;
    for (int i = actions.length - 1; i >= 0; i--) {
      final action = actions[i];
      if (action.action != PlayerAction.none) {
        lastActionIndex = i;
        break;
      }
    }

    if (lastActionIndex == -1) {
      addAction("⚠️ Cannot undo: no actions to undo");
      _triggerInvalidActionVibration();
      return;
    }

    setState(() {
      final undoneAction = actions[lastActionIndex];
      final playerId = undoneAction.player;
      final action = undoneAction.action;
      final amount = undoneAction.amount ?? 0.0;

      // Get the player state
      final player = gameState.players[playerId - 1];

      // Restore player state based on action type
      switch (action) {
        case PlayerAction.fold:
          // Restore fold state
          player.hasFolded = false;
          player.hasActed = false;
          player.lastAction = PlayerAction.none;
          break;

        case PlayerAction.check:
          // Restore check state
          player.hasActed = false;
          player.lastAction = PlayerAction.none;
          // Recalculate hasCalledCurrentBet based on remaining actions
          _recalculatePlayerCallStatus(playerId, lastActionIndex);
          break;

        case PlayerAction.call:
          // Calculate what the player had bet BEFORE this call
          double previousBetThisRound = _getPreviousBetThisRound(playerId, lastActionIndex);

          // Calculate the additional amount that was added to pot
          double additionalAmount = amount - previousBetThisRound;
          if (additionalAmount < 0) additionalAmount = 0;

          // Restore stack (add back only the additional amount)
          player.currentStack += additionalAmount;
          player.isAllIn = false;

          // Restore bet tracking to previous value
          player.betThisRound = previousBetThisRound;

          // Restore pot (subtract only the additional amount)
          gameState.currentPot -= additionalAmount;
          if (gameState.currentPot < 0) gameState.currentPot = 0;

          // Restore player status
          player.hasActed = false;
          player.hasCalledCurrentBet = false;
          player.lastAction = PlayerAction.none;
          break;

        case PlayerAction.bet:
        case PlayerAction.raise:
          // Calculate what the player had bet BEFORE this bet/raise
          double previousBetThisRound = _getPreviousBetThisRound(playerId, lastActionIndex);

          // Calculate the additional amount that was added to pot
          double additionalAmount = amount - previousBetThisRound;
          if (additionalAmount < 0) additionalAmount = 0;

          // Restore stack (add back only the additional amount)
          player.currentStack += additionalAmount;
          player.isAllIn = false;

          // Restore bet tracking to previous value
          player.betThisRound = previousBetThisRound;

          // Restore pot (subtract only the additional amount)
          gameState.currentPot -= additionalAmount;
          if (gameState.currentPot < 0) gameState.currentPot = 0;

          // Restore player status
          player.hasActed = false;
          player.hasCalledCurrentBet = false;
          player.lastAction = PlayerAction.none;

          // Recalculate currentBet based on remaining bets/raises
          _recalculateCurrentBet(lastActionIndex);

          // Recalculate hasBetThisRound
          _recalculateHasBetThisRound(lastActionIndex);

          // Recalculate other players' hasCalledCurrentBet status
          _recalculateAllPlayersCallStatus(lastActionIndex);
          break;

        default:
          break;
      }

      // Remove the action from the list
      actions.removeAt(lastActionIndex);

      // Set current player back to the player who made the undone action
      gameState.currentPlayer = playerId;

      // Reset betting round complete flag
      gameState.bettingRoundComplete = false;

      // Log the undo
      final playerName = sessionManager.getPlayerNameWithPosition(playerId);
      addAction("↩️ Undone: $playerName's ${action.name}");
      addAction(_getToActMessage());
    });
  }

  /// Get the amount a player had bet BEFORE a specific action index
  /// This looks at all previous actions in the same street by the same player
  double _getPreviousBetThisRound(int playerId, int beforeIndex) {
    final actions = sessionManager.currentHand!.actions;
    if (beforeIndex <= 0) return 0.0;

    // Get the street of the action we're undoing
    final undoingStreet = actions[beforeIndex].street;

    double totalBet = 0.0;

    // Look through all actions before this one
    for (int i = 0; i < beforeIndex; i++) {
      final action = actions[i];

      // Only consider actions by this player in the same street
      if (action.player == playerId && action.street == undoingStreet) {
        // For bet/raise/call actions, use the amount
        if (action.action == PlayerAction.bet ||
            action.action == PlayerAction.raise ||
            action.action == PlayerAction.call) {
          if (action.amount != null) {
            // The amount represents the total bet at that point, not additional
            // So we just take the latest value
            totalBet = action.amount!;
          }
        }
      }
    }

    return totalBet;
  }

  /// Recalculate hasCalledCurrentBet for a specific player based on remaining actions
  void _recalculatePlayerCallStatus(int playerId, int upToIndex) {
    final player = gameState.players[playerId - 1];
    final actions = sessionManager.currentHand!.actions;

    // Check if this player has called/raised/checked after the last bet/raise
    bool hasCalledAfterLastBet = false;
    for (int i = 0; i < upToIndex; i++) {
      final action = actions[i];
      if (action.player == playerId) {
        if (action.action == PlayerAction.call ||
            action.action == PlayerAction.raise ||
            action.action == PlayerAction.bet ||
            action.action == PlayerAction.check) {
          hasCalledAfterLastBet = true;
        }
      }
    }

    player.hasCalledCurrentBet = hasCalledAfterLastBet;
  }

  /// Recalculate currentBet based on remaining bets/raises
  void _recalculateCurrentBet(int upToIndex) {
    final actions = sessionManager.currentHand!.actions;
    double maxBet = 0;

    for (int i = 0; i < upToIndex; i++) {
      final action = actions[i];
      if (action.action == PlayerAction.bet || action.action == PlayerAction.raise) {
        if (action.amount != null && action.amount! > maxBet) {
          maxBet = action.amount!;
        }
      }
    }

    gameState.currentBet = maxBet;
  }

  /// Recalculate hasBetThisRound based on remaining actions
  void _recalculateHasBetThisRound(int upToIndex) {
    final actions = sessionManager.currentHand!.actions;
    bool hasBet = false;

    for (int i = 0; i < upToIndex; i++) {
      final action = actions[i];
      if (action.action == PlayerAction.bet || action.action == PlayerAction.raise) {
        hasBet = true;
        break;
      }
    }

    gameState.hasBetThisRound = hasBet;
  }

  /// Recalculate all players' hasCalledCurrentBet status
  void _recalculateAllPlayersCallStatus(int upToIndex) {
    final actions = sessionManager.currentHand!.actions;

    // Reset all players first
    for (var player in gameState.players) {
      if (!player.hasFolded) {
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
      final bettorPlayer = gameState.players[bettor - 1];
      bettorPlayer.hasCalledCurrentBet = true;

      for (int i = lastBetIndex + 1; i < upToIndex; i++) {
        final action = actions[i];
        if (action.action == PlayerAction.call ||
            action.action == PlayerAction.raise ||
            action.action == PlayerAction.bet) {
          final player = gameState.players[action.player - 1];
          player.hasCalledCurrentBet = true;
        }
      }
    } else {
      // No bet this round - check if players have checked
      for (int i = 0; i < upToIndex; i++) {
        final action = actions[i];
        if (action.action == PlayerAction.check) {
          final player = gameState.players[action.player - 1];
          player.hasCalledCurrentBet = true;
        }
      }
    }
  }

  void addAction(String action) {
    setState(() {
      actions.add("${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')} - $action");
      // Keep only the last 20 actions to avoid overflow
      if (actions.length > 20) {
        actions.removeAt(0);
      }
    });
  }

  void _checkForAutomaticHandEnd() {
    // Check if everyone has folded to BB preflop
    if (gameState.currentRound == BettingRound.preflop) {
      List<int> activePlayers = _getActivePlayers();
      if (activePlayers.length == 1) {
        // Only one player left - automatically end the hand
        _schedulePostFrameAction(() {
          addAction("🏆 Everyone folded - hand completed automatically");
          _completeHandAutomatically();
        });
      }
    }
  }

  void _completeHandAutomatically() async {
    await LoggerService.info('🤖 _completeHandAutomatically() called - Auto-completing hand');

    // Save pot amount BEFORE distributing
    final potAmount = gameState.currentPot;
    await LoggerService.debug('  Pot amount: \$${potAmount.toStringAsFixed(2)}');

    // Get the remaining active player
    List<int> activePlayers = _getActivePlayers();
    await LoggerService.debug('  Active players: $activePlayers (count: ${activePlayers.length})');

    // If only one player remains, award pot automatically without dialog
    if (activePlayers.length == 1) {
      await LoggerService.info('  ✅ Single winner path - awarding pot without dialogs');
      final winnerId = activePlayers[0];
      final winnerName = sessionManager.getPlayerName(winnerId);

      // Award pot to winner
      final winnerPlayer = gameState.players[winnerId - 1];
      winnerPlayer.currentStack += potAmount;

      addAction("🏆 $winnerName wins \$${potAmount.toStringAsFixed(widget.gameType == GameType.cash ? 2 : 0)} (last player standing)");

      // Show hole cards dialog BEFORE completing the hand
      addAction("✅ Hand completed!");
      await _showHoleCardsDialog();

      // Now complete hand in session manager (hole cards are already saved to currentHand)
      final currentStack = gameState.getPlayerStack(sessionManager.ourSeatNumber ?? 1);
      sessionManager.completeCurrentHand(
        potAmount: potAmount,
        winnerId: winnerId,
        currentStack: currentStack,
      );

      // For individual sessions, return to the session tracking screen
      if (widget.isIndividualSession) {
        final ourSeat = sessionManager.ourSeatNumber;
        final finalStack = ourSeat != null ? gameState.players[ourSeat - 1].currentStack : widget.individualCurrentStack ?? 0.0;

        Navigator.pop(context, {
          'completed': true,
          'finalStack': finalStack,
          'potSize': potAmount,
          'smallBlind': sessionManager.smallBlind,
          'bigBlind': sessionManager.bigBlind,
          'hasBBante': gameState.hasBBante,
        });
        return;
      }

      // For full sessions, start next hand
      await _checkForBustedPlayers();

      setState(() {
        _allInHandCompleted = false;
        gameState.startNewHand();
        sessionManager.startHand(
          gameState.handNumber,
          gameState.buttonPosition,
          sbSeat: gameState.effectiveSBPosition,
          bbSeat: gameState.effectiveBBPosition,
        );

        actions.clear();
        actions.add("💾 Hand #${gameState.handNumber - 1} saved");
        actions.add("Hand #${gameState.handNumber} started");
        actions.add(gameState.getGameStateInfo());
        actions.add(_getToActMessage());
      });
    } else {
      // Multiple players remain, show winner selection dialog
      await LoggerService.info('  ↪️ Multiple players path - calling completeHand()');
      completeHand();
    }
  }

  void _showCardSelectionForNextHand() async {
    addAction("✅ Hand completed!");

    // Show hole cards dialog for the completed hand
    await _showHoleCardsDialog();

    // For individual sessions, return to the session tracking screen
    if (widget.isIndividualSession) {
      final ourSeat = sessionManager.ourSeatNumber;
      final finalStack = ourSeat != null ? gameState.players[ourSeat - 1].currentStack : widget.individualCurrentStack ?? 0.0;
      final potSize = gameState.currentPot;

      Navigator.pop(context, {
        'completed': true,
        'finalStack': finalStack,
        'potSize': potSize,
        'smallBlind': sessionManager.smallBlind,
        'bigBlind': sessionManager.bigBlind,
        'hasBBante': gameState.hasBBante,
      });
      return;
    }

    // For full sessions, start next hand
    // Check for busted players before starting new hand
    await _checkForBustedPlayers();

    setState(() {
      // Reset all-in completion flag for new hand
      _allInHandCompleted = false;

      // Start new hand in game state
      gameState.startNewHand();

      // Start new hand in session manager
      sessionManager.startHand(
        gameState.handNumber,
        gameState.buttonPosition,
        sbSeat: gameState.effectiveSBPosition,
        bbSeat: gameState.effectiveBBPosition,
      );

      actions.clear(); // Clear actions for new hand
      actions.add("💾 Hand #${gameState.handNumber - 1} saved");
      actions.add("Hand #${gameState.handNumber} started");
      actions.add(gameState.getGameStateInfo());
      actions.add(_getToActMessage());
    });
  }

  void completeHand() async {
    await LoggerService.info('═══ completeHand() called ═══');

    // Save the pot amount BEFORE showing any dialogs
    final potAmount = gameState.currentPot;
    await LoggerService.debug('  Pot amount: \$${potAmount.toStringAsFixed(2)}');

    // First, show winner selection dialog - ALWAYS show it
    List<int> activePlayers = _getActivePlayers();
    await LoggerService.debug('  Active players from _getActivePlayers(): $activePlayers');

    if (activePlayers.isEmpty) {
      await LoggerService.warning('  No active players found - using all ${gameState.numberOfPlayers} players');
      // If no active players, get all players for selection
      activePlayers = List.generate(gameState.numberOfPlayers, (i) => i + 1);
    }

    List<String> playerNames = [];

    // Get player names with positions for the dialog
    for (int playerId in activePlayers) {
      String playerName = sessionManager.getPlayerNameWithPosition(playerId);
      playerNames.add(playerName);
    }

    Map<String, dynamic>? winnerResult;
    // ALWAYS show winner selection dialog
    winnerResult = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => WinnerSelectionDialog(
        activePlayers: activePlayers,
        playerNames: playerNames,
        potAmount: potAmount, // Use saved pot amount
        gameType: widget.gameType, // Pass game type
        buttonPosition: gameState.buttonPosition,
        playerCount: gameState.numberOfPlayers,
      ),
    );

    // User can cancel the dialog if they want to continue the hand
    if (winnerResult == null) {
      addAction("❌ Winner selection cancelled - hand continues");
      return;
    }

    final bool isChoppedPot = winnerResult['isChoppedPot'] ?? false;
    final List<int> winners = isChoppedPot
        ? List<int>.from(winnerResult['winners'] ?? [])
        : [winnerResult['winner'] as int];
    final Map<int, double> individualShares = isChoppedPot && winnerResult['individualShares'] != null
        ? Map<int, double>.from(winnerResult['individualShares'])
        : {};
    final double sharePerWinner = winnerResult['sharePerWinner'] ?? potAmount;

    await LoggerService.debug('  Winner selection result: isChoppedPot=$isChoppedPot, winners=$winners');

    // Then show hole cards dialog
    await _showHoleCardsDialog();

    await LoggerService.info('About to call _showOpponentCardsDialog with activePlayers=$activePlayers');

    // Show opponent hole cards dialog for showdown situations
    await _showOpponentCardsDialog(activePlayers, winners);

    setState(() {
      if (isChoppedPot) {
        // Get current stack for our seat to track in session history
        final ourSeat = sessionManager.ourSeatNumber;
        final currentStack = ourSeat != null ? gameState.players[ourSeat - 1].currentStack : null;

        // Complete current hand in session manager with pot and multiple winners
        sessionManager.completeCurrentHandWithChop(
          potAmount: potAmount,
          winnerIds: winners,
          individualShares: individualShares,
          currentStack: currentStack,
        );

        // Distribute pot to all winners with individual amounts
        for (int winnerId in winners) {
          final winnerShare = individualShares[winnerId] ?? sharePerWinner;
          _distributePotToWinner(winnerId, winnerShare);
        }

        // Reset the pot after distributing to all winners
        gameState.currentPot = 0.0;

        // Add action log for chopped pot with individual amounts
        if (individualShares.isNotEmpty) {
          List<String> winnerDetails = winners.map((id) {
            final name = sessionManager.getPlayerNameWithPosition(id);
            final amount = individualShares[id] ?? sharePerWinner;
            return '$name (${_formatCurrency(amount)})';
          }).toList();
          actions.add("🏆 Pot chopped: ${winnerDetails.join(', ')}");
        } else {
          String winnerNames = winners.map((id) =>
            sessionManager.getPlayerNameWithPosition(id)).join(', ');
          actions.add("🏆 Pot chopped between $winnerNames - ${_formatCurrency(sharePerWinner)} each");
        }
      } else {
        // Get current stack for our seat to track in session history
        final ourSeat = sessionManager.ourSeatNumber;
        final currentStack = ourSeat != null ? gameState.players[ourSeat - 1].currentStack : null;

        // Complete current hand in session manager with single winner
        sessionManager.completeCurrentHand(
          potAmount: potAmount,
          winnerId: winners.first,
          currentStack: currentStack,
        );

        // Distribute pot to single winner
        _distributePotToWinner(winners.first);

        // Add action log for single winner
        String winnerName = sessionManager.getPlayerNameWithPosition(winners.first);
        actions.add("🏆 $winnerName wins ${_formatCurrency(potAmount)}");
      }
    });

    // For individual sessions, return to the session tracking screen
    if (widget.isIndividualSession) {
      // Get the user's final stack and pot size
      final ourSeat = sessionManager.ourSeatNumber;
      final finalStack = ourSeat != null ? gameState.players[ourSeat - 1].currentStack : widget.individualCurrentStack ?? 0.0;
      final potSize = potAmount; // Use the potAmount we saved earlier

      // Return to session tracking screen with hand completion data
      Navigator.pop(context, {
        'completed': true,
        'finalStack': finalStack,
        'potSize': potSize,
        'smallBlind': sessionManager.smallBlind,
        'bigBlind': sessionManager.bigBlind,
        'hasBBante': gameState.hasBBante,
      });
      return;
    }

    // For full sessions, continue with normal flow
    // Check for busted players before starting new hand
    await _checkForBustedPlayers();

    setState(() {
      // Reset all-in completion flag for new hand
      _allInHandCompleted = false;

      // Start new hand in game state
      gameState.startNewHand();

      // Start new hand in session manager
      sessionManager.startHand(
        gameState.handNumber,
        gameState.buttonPosition,
        sbSeat: gameState.effectiveSBPosition,
        bbSeat: gameState.effectiveBBPosition,
      );

      // Clear actions for new hand but keep the winner announcement
      String lastWinnerAction = actions.isNotEmpty ? actions.last : '';
      actions.clear();
      if (lastWinnerAction.isNotEmpty) actions.add(lastWinnerAction);
      actions.add("💾 Hand #${gameState.handNumber - 1} saved to Firebase");
      actions.add("Hand #${gameState.handNumber} started");
      actions.add(gameState.getGameStateInfo());
      actions.add(_getToActMessage());
    });
  }

  String _getToActMessage() {
    // Check various scenarios where no one should act
    List<int> allInPlayers = gameState.getAllInPlayers();
    List<int> activePlayers = gameState.getActivePlayers();
    List<int> playersWhoCanAct = gameState.getPlayersWhoCanAct();


    // If all active players are all-in
    if (allInPlayers.length == activePlayers.length && activePlayers.length > 1) {
      return "All players all-in - dealing remaining cards";
    }

    // If only 0 or 1 players can act (others are folded/all-in)
    if (playersWhoCanAct.length <= 1 && activePlayers.length > 1) {
      return "Waiting for cards to be dealt";
    }

    // Also check if betting round is complete but we haven't moved to next street yet
    if (gameState.bettingRoundComplete) {
      return "Betting complete - ready for next street";
    }

    // Normal case - show which player needs to act
    return "${sessionManager.getPlayerNameWithPosition(gameState.currentPlayer)} to act";
  }

  void _adjustButtonForRemovedPlayer(int removedPlayerId) {
    // If the removed player had the button, move it to the next active player
    if (gameState.buttonPosition == removedPlayerId) {
      int nextButton = gameState.buttonPosition;
      int attempts = 0;
      do {
        nextButton = (nextButton % gameState.numberOfPlayers) + 1;
        attempts++;
      } while (!gameState.players[nextButton - 1].isActive && attempts < gameState.numberOfPlayers);

      if (attempts < gameState.numberOfPlayers) {
        gameState.buttonPosition = nextButton;
        addAction("🔄 Button moved to Player $nextButton (active seat)");
      }
    }
  }

  void _adjustPositionsAfterPlayerLeaves(int removedPlayerId) {
    // The core logic: when a player leaves, the positions shift to fill the gap
    // This affects blind obligations in the next hand

    // Get current position of the removed player
    String removedPosition = sessionManager.getPlayerNameWithPosition(removedPlayerId);

    // Get all active players (excluding the one who just left)
    List<int> activePlayers = gameState.getActivePlayers();
    int activePlayerCount = activePlayers.length;

    if (activePlayerCount < 2) {
      // End game if less than 2 players
      addAction("⚠️ Game cannot continue with less than 2 players");
      return;
    }

    addAction("📍 Position adjustment: $removedPosition left the table (${activePlayerCount} players remain)");

    // The position adjustment happens automatically when the next hand starts
    // because getPositionName() calculates positions based on active players
    // But we log it here for clarity
    String nextBBSeat = _findNextBBAfterRemoval(removedPlayerId);
    if (nextBBSeat.isNotEmpty) {
      addAction("🎯 Next hand: $nextBBSeat will be BB due to position shift");
    }
  }

  String _findNextBBAfterRemoval(int removedPlayerId) {
    // Find which seat will be BB in the next hand due to the position shift
    try {
      // Advance button to next hand position
      int nextButton = gameState.buttonPosition;
      int attempts = 0;
      do {
        nextButton = (nextButton % gameState.numberOfPlayers) + 1;
        attempts++;
      } while (!gameState.players[nextButton - 1].isActive && attempts < gameState.numberOfPlayers);

      if (attempts >= gameState.numberOfPlayers) return "";

      // Find BB position (clockwise from button)
      List<int> activePlayers = gameState.getActivePlayers();
      if (activePlayers.length < 2) return "";

      // In heads-up: button is SB, other player is BB
      if (activePlayers.length == 2) {
        int otherPlayer = activePlayers.firstWhere((p) => p != nextButton);
        return sessionManager.getPlayerNameWithPosition(otherPlayer);
      }

      // Multi-way: BB is 2nd clockwise from button
      int bbSeat = nextButton;
      int count = 0;
      do {
        bbSeat = (bbSeat % gameState.numberOfPlayers) + 1;
        if (gameState.players[bbSeat - 1].isActive) {
          count++;
        }
      } while (count < 2 && attempts < gameState.numberOfPlayers * 2);

      if (count == 2 && gameState.players[bbSeat - 1].isActive) {
        return sessionManager.getPlayerNameWithPosition(bbSeat);
      }

      return "";
    } catch (e) {
      return "";
    }
  }

  void _checkSpecialBlindSituation(int removedPlayerId) {
    // Calculate who would be SB and BB based on current button
    int sbPosition = (gameState.buttonPosition % gameState.numberOfPlayers) + 1;
    int bbPosition = (sbPosition % gameState.numberOfPlayers) + 1;

    // Check if removed player was supposed to be SB or BB
    if (removedPlayerId == sbPosition) {
      addAction("⚠️ Small blind seat empty - next hand will start with BB only");
    } else if (removedPlayerId == bbPosition) {
      addAction("⚠️ Big blind seat empty - adjusting blind positions");
    }
  }

  Future<void> _checkForBustedPlayers() async {
    // Find all busted players (stack = 0 or negative) who are still active
    List<int> bustedPlayers = [];
    for (int playerId = 1; playerId <= gameState.numberOfPlayers; playerId++) {
      PlayerState player = gameState.players[playerId - 1];
      double stack = gameState.getPlayerStack(playerId);

      // Only check players who are still active (haven't left the table)
      if (player.isActive) {
        if (stack <= 0) {
          bustedPlayers.add(playerId);
        }
      }
    }

    // Handle each busted player
    for (int playerId in bustedPlayers) {
      String playerName = sessionManager.getPlayerNameWithPosition(playerId) ?? "Player $playerId";

      // Show rebuy/leave dialog
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _BustedPlayerDialog(
          playerName: playerName,
          playerId: playerId,
          isCashGame: widget.gameType == GameType.cash,
        ),
      );

      if (result != null) {
        if (result['action'] == 'rebuy') {
          double rebuyAmount = result['amount'] ?? 100.0;
          gameState.setPlayerStack(playerId, rebuyAmount);
          addAction("💰 $playerName rebuys for ${gameState.formatCurrency(rebuyAmount)}");
        } else if (result['action'] == 'leave') {
          // Mark player as completely inactive (seat empty)
          PlayerState player = gameState.players[playerId - 1];
          player.isActive = false;
          player.currentStack = 0.0;
          player.startingStack = 0.0;
          player.hasFolded = true;

          // Remove from session manager's active seats
          sessionManager.removePlayer(playerId);

          // Adjust button position if needed
          _adjustButtonForRemovedPlayer(playerId);

          // Adjust positions after player removal
          _adjustPositionsAfterPlayerLeaves(playerId);

          addAction("👋 $playerName leaves the table");

          // If this was SB or BB, note special blind situation
          _checkSpecialBlindSituation(playerId);
        }
      }
    }
  }

  Future<void> _showHoleCardsDialog({bool isForCompletedHand = true}) async {
    // Collect board cards as used cards
    Set<String> usedCards = {};
    BoardCards? boardCards;
    HoleCards? existingHoleCards;

    // IMPORTANT: When called for a hand that's about to be completed, currentHand still exists
    // So we should use currentHand (not completedHands.last) to avoid showing previous hand's cards
    if (sessionManager.currentHand != null) {
      // Use the current hand being played/completed
      boardCards = sessionManager.currentHand?.boardCards;
      existingHoleCards = sessionManager.currentHand?.ourHoleCards;
    } else if (sessionManager.completedHands.isNotEmpty) {
      // Fallback to last completed hand (for editing after hand is fully complete)
      boardCards = sessionManager.completedHands.last.boardCards;
      existingHoleCards = sessionManager.completedHands.last.ourHoleCards;
    }

    if (boardCards != null) {
      if (boardCards.flop.isNotEmpty) usedCards.addAll(boardCards.flop);
      if (boardCards.turn != null && boardCards.turn!.isNotEmpty) usedCards.add(boardCards.turn!);
      if (boardCards.river != null && boardCards.river!.isNotEmpty) usedCards.add(boardCards.river!);
    }

    final holeCards = await showDialog<HoleCards>(
      context: context,
      barrierDismissible: true,
      builder: (context) => HoleCardsDialog(
        existingCards: existingHoleCards,
        usedCards: usedCards,
      ),
    );

    if (holeCards != null) {
      // Save hole cards to the current hand (or last completed if current doesn't exist)
      if (sessionManager.currentHand != null) {
        sessionManager.currentHand!.ourHoleCards = holeCards;
      } else if (sessionManager.completedHands.isNotEmpty) {
        sessionManager.completedHands.last.ourHoleCards = holeCards;
      }

      if (holeCards.isComplete) {
        addAction("🂠 Your cards: ${holeCards.card1} ${holeCards.card2}");
      }
    }
  }

  Future<void> _showOpponentCardsDialog(List<int> activePlayers, List<int> winners) async {
    // Log function entry
    await LoggerService.info('_showOpponentCardsDialog called');
    await LoggerService.debug('  activePlayers: $activePlayers (count: ${activePlayers.length})');
    await LoggerService.debug('  winners: $winners');
    await LoggerService.debug('  ourSeat: ${sessionManager.ourSeatNumber}');

    // Only show opponent cards dialog if hand reached showdown (not if everyone folded)
    if (activePlayers.length <= 1) {
      await LoggerService.warning('❌ Opponent cards dialog SKIPPED - activePlayers.length <= 1');
      return; // No showdown, everyone folded
    }

    // Get opponents (exclude our seat if we're one of the active players)
    final ourSeat = sessionManager.ourSeatNumber;
    final opponents = activePlayers.where((p) => p != ourSeat).toList();
    await LoggerService.debug('  opponents (after excluding hero): $opponents');

    if (opponents.isEmpty) {
      await LoggerService.warning('❌ Opponent cards dialog SKIPPED - no opponents (all were hero)');
      return; // No opponents to show cards for
    }

    await LoggerService.info('✅ Showing opponent cards dialog for ${opponents.length} opponent(s): $opponents');

    // Collect used cards (board + hero cards)
    Set<String> usedCards = {};
    BoardCards? boardCards;
    HoleCards? ourCards;

    if (sessionManager.currentHand != null) {
      boardCards = sessionManager.currentHand?.boardCards;
      ourCards = sessionManager.currentHand?.ourHoleCards;
    } else if (sessionManager.completedHands.isNotEmpty) {
      boardCards = sessionManager.completedHands.last.boardCards;
      ourCards = sessionManager.completedHands.last.ourHoleCards;
    }

    if (boardCards != null) {
      if (boardCards.flop.isNotEmpty) usedCards.addAll(boardCards.flop);
      if (boardCards.turn != null && boardCards.turn!.isNotEmpty) usedCards.add(boardCards.turn!);
      if (boardCards.river != null && boardCards.river!.isNotEmpty) usedCards.add(boardCards.river!);
    }

    if (ourCards != null && ourCards.isComplete) {
      usedCards.add(ourCards.card1!);
      usedCards.add(ourCards.card2!);
    }

    // Get existing opponent cards if any
    Map<int, HoleCards>? existingCards = sessionManager.currentHand?.showdownData?.playerCards;

    // Loop through each opponent and show HoleCardsDialog
    Map<int, HoleCards> opponentCards = {};

    for (int opponentId in opponents) {
      final opponentName = sessionManager.getPlayerNameWithPosition(opponentId);

      // Show dialog for this opponent
      final cards = await showDialog<HoleCards>(
        context: context,
        barrierDismissible: true,
        builder: (context) => HoleCardsDialog(
          title: '$opponentName Hole Cards',
          usedCards: usedCards,
          existingCards: existingCards?[opponentId],
        ),
      );

      // If user cancelled/skipped, stop collecting cards
      if (cards == null) {
        break;
      }

      // If cards were selected, add them to the collection and update usedCards
      if (cards.isComplete) {
        opponentCards[opponentId] = cards;
        usedCards.add(cards.card1!);
        usedCards.add(cards.card2!);
      }
    }

    // Save opponent cards to showdown data
    if (opponentCards.isNotEmpty) {
      if (sessionManager.currentHand != null) {
        // Initialize showdown data if it doesn't exist
        sessionManager.currentHand!.showdownData ??= ShowdownData();
        sessionManager.currentHand!.reachedShowdown = true;

        // Add opponent cards to showdown data
        opponentCards.forEach((playerId, cards) {
          if (cards.isComplete) {
            sessionManager.currentHand!.showdownData!.playerCards[playerId] = cards;
            addAction("🂠 ${sessionManager.getPlayerNameWithPosition(playerId)}: ${cards.card1} ${cards.card2}");
          }
        });
      } else if (sessionManager.completedHands.isNotEmpty) {
        // For completed hands
        sessionManager.completedHands.last.showdownData ??= ShowdownData();
        sessionManager.completedHands.last.reachedShowdown = true;

        opponentCards.forEach((playerId, cards) {
          if (cards.isComplete) {
            sessionManager.completedHands.last.showdownData!.playerCards[playerId] = cards;
          }
        });
      }
    }
  }

  void _handleHandComplete() {
    // Hand complete - show winner selection dialog first
    LoggerService.info('🏁 _handleHandComplete() called - Complete Hand button pressed');
    final allInPlayers = gameState.getAllInPlayers();
    final activePlayers = gameState.getActivePlayers();
    final playersWhoCanAct = gameState.getPlayersWhoCanAct();
    LoggerService.debug('  All-in players: $allInPlayers (count: ${allInPlayers.length})');
    LoggerService.debug('  Active players: $activePlayers (count: ${activePlayers.length})');
    LoggerService.debug('  Players who can act: $playersWhoCanAct (count: ${playersWhoCanAct.length})');
    completeHand();
  }

  List<int> _getActivePlayers() {
    // Get players who haven't folded from the game state
    final activePlayers = gameState.getActivePlayers();
    LoggerService.debug('_getActivePlayers() returned: $activePlayers');
    return activePlayers;
  }

  Future<void> _showShowdownDialog(List<int> activePlayers) async {
    if (sessionManager.currentHand == null) return;
    
    final showdownData = await showDialog<ShowdownData>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ShowdownDialog(
        playerCount: widget.numberOfPlayers,
        activePlayers: activePlayers,
        existingData: sessionManager.currentHand?.showdownData,
      ),
    );

    if (showdownData != null && sessionManager.currentHand != null) {
      sessionManager.currentHand!.showdownData = showdownData;
      sessionManager.currentHand!.reachedShowdown = true;
      
      if (showdownData.winner != null) {
        addAction("🏆 Winner: ${sessionManager.getPlayerName(showdownData.winner!)}");
        if (showdownData.handDescription != null) {
          addAction("💪 ${showdownData.handDescription}");
        }
        
        // Distribute pot to winner
        _distributePotToWinner(showdownData.winner!);
      }
      
      // Show opponent cards
      for (int player in activePlayers) {
        final playerCards = showdownData.playerCards[player];
        if (playerCards != null && playerCards.isComplete) {
          addAction("🂠 ${sessionManager.getPlayerName(player)}: ${playerCards.card1} ${playerCards.card2}");
        }
      }
    }
    
    _finalizeHand();
  }

  void _finalizeHand() async {
    addAction("✅ Hand completed!");

    // Show hole cards dialog for the completed hand
    await _showHoleCardsDialog();

    // For individual sessions, return to the session tracking screen
    if (widget.isIndividualSession) {
      // Get the user's final stack and pot size
      final ourSeat = sessionManager.ourSeatNumber;
      final finalStack = ourSeat != null ? gameState.players[ourSeat - 1].currentStack : widget.individualCurrentStack ?? 0.0;
      final potSize = gameState.currentPot;

      // Return to session tracking screen with hand completion data
      Navigator.pop(context, {
        'completed': true,
        'finalStack': finalStack,
        'potSize': potSize,
        'smallBlind': sessionManager.smallBlind,
        'bigBlind': sessionManager.bigBlind,
        'hasBBante': gameState.hasBBante,
      });
      return;
    }

    // For full sessions, continue with normal flow
    // Check for busted players before starting new hand
    await _checkForBustedPlayers();

    setState(() {
      // Reset all-in completion flag for new hand
      _allInHandCompleted = false;

      // Start new hand in game state
      gameState.startNewHand();

      // Start new hand in session manager
      sessionManager.startHand(
        gameState.handNumber,
        gameState.buttonPosition,
        sbSeat: gameState.effectiveSBPosition,
        bbSeat: gameState.effectiveBBPosition,
      );

      actions.clear(); // Clear actions for new hand
      actions.add("💾 Hand #${gameState.handNumber - 1} saved");
      actions.add("Hand #${gameState.handNumber} started");
      actions.add(gameState.getGameStateInfo());
      actions.add(_getToActMessage());
    });
  }

  void _triggerInvalidActionVibration() {
    Vibration.vibrate(duration: 200);
  }

  String _getValidActionsHint() {
    List<String> validActions = [];
    if (gameState.isValidAction(PlayerAction.fold)) validActions.add("Fold");
    if (gameState.isValidAction(PlayerAction.check)) validActions.add("Check");
    if (gameState.isValidAction(PlayerAction.call)) validActions.add("Call");
    if (gameState.isValidAction(PlayerAction.bet)) validActions.add("Bet");
    if (gameState.isValidAction(PlayerAction.raise)) validActions.add("Raise");
    return "Valid: ${validActions.join(', ')}";
  }

  void _distributePotToWinner(int winnerId, [double? shareAmount]) {
    // Use provided share amount or current pot amount
    double winAmount = shareAmount ?? gameState.currentPot;

    if (winAmount > 0) {
      // Add winnings to winner's stack
      double currentStack = gameState.getPlayerStack(winnerId);
      gameState.setPlayerStack(winnerId, currentStack + winAmount);

      // Only reset pot if we're distributing the full pot (no share amount specified)
      if (shareAmount == null) {
        gameState.currentPot = 0.0;
      }
    }
  }

  String _formatCurrency(double amount) {
    if (widget.gameType == GameType.cash) {
      return '\$${amount.toStringAsFixed(2)}';
    } else {
      return '${amount.toInt()}';
    }
  }

  // Drag bar widget positioned on the left side
  Widget _buildDragBar(BuildContext context) {
    // Calculate positioning based on actual Online status position
    final screenHeight = MediaQuery.of(context).size.height;
    final gameInfoHeight = 140; // Game info section height
    
    // Online status is positioned: bottom: 16, left: 16 in the stack
    // So its actual position from screen bottom is 16px + its own height
    final onlineStatusFromBottom = 16; // bottom position in CSS
    final onlineStatusHeight = 40; // actual height of the status container
    final endStreetButtonHeight = 60; // End Street button height
    
    // Calculate where Online status actually sits
    final onlineStatusTop = screenHeight - endStreetButtonHeight - onlineStatusFromBottom - onlineStatusHeight;
    
    // Position drag bar so its bottom edge is ABOVE the Online status with clear gap
    final clearanceGap = 25; // Clear gap above Online status
    final barHeight = 300.0; // Fixed height for the drag bar
    
    // Calculate bottom position: Online status top minus clearance gap
    final barBottom = onlineStatusTop - clearanceGap;
    final topMargin = barBottom - barHeight; // Position from bottom up
    
    // Calculate the current position of the drag indicator
    final indicatorPosition = topMargin + (barHeight * _dragBarPosition);
    
    return Positioned(
      left: 8,
      top: topMargin,
      child: Container(
        width: 40,
        height: barHeight,
        child: Stack(
          children: [
            // Background track
            Positioned.fill(
              child: Container(
                width: 6,
                margin: EdgeInsets.symmetric(horizontal: 17),
                decoration: BoxDecoration(
                  color: Color(0xFF2A2A2E),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: Color(0xFF3A3A3E), width: 1),
                ),
              ),
            ),
            
            // Progress fill (from bottom to current position)
            Positioned(
              left: 17,
              bottom: 0,
              child: Container(
                width: 6,
                height: barHeight * _dragBarPosition,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.6),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(3),
                    top: _dragBarPosition < 1.0 ? Radius.zero : Radius.circular(3),
                  ),
                ),
              ),
            ),
            
            // Drag indicator (thumb)
            Positioned(
              left: 12,
              bottom: (barHeight * _dragBarPosition) - 8,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            
            // Min/Max labels
            Positioned(
              right: 0,
              top: -8,
              child: Text(
                'MAX',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: -8,
              child: Text(
                'MIN',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Dialog for handling busted players
class _BustedPlayerDialog extends StatefulWidget {
  final String playerName;
  final int playerId;
  final bool isCashGame;

  const _BustedPlayerDialog({
    Key? key,
    required this.playerName,
    required this.playerId,
    required this.isCashGame,
  }) : super(key: key);

  @override
  _BustedPlayerDialogState createState() => _BustedPlayerDialogState();
}

class _BustedPlayerDialogState extends State<_BustedPlayerDialog> {
  final TextEditingController _amountController = TextEditingController(text: '100');
  bool _isRebuy = true;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Color(0xFF1F1F23),
      title: Column(
        children: [
          Icon(
            Icons.warning,
            color: Colors.orange,
            size: 48,
          ),
          SizedBox(height: 16),
          Text(
            '${widget.playerName} is busted!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Choose an option:',
            style: TextStyle(color: Colors.white70),
          ),
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => _isRebuy = true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRebuy ? Colors.green : Colors.grey[700],
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Rebuy',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => _isRebuy = false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !_isRebuy ? Colors.red : Colors.grey[700],
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Leave',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_isRebuy) ...[
            const SizedBox(height: 24),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.numberWithOptions(decimal: widget.isCashGame),
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: widget.isCashGame ? 'Rebuy Amount (\$)' : 'Rebuy Chips',
                labelStyle: TextStyle(color: Colors.white70),
                prefixText: widget.isCashGame ? '\$' : '',
                prefixStyle: TextStyle(color: Colors.white),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white30),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.green),
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (_isRebuy) {
              double amount = double.tryParse(_amountController.text) ?? 100.0;
              Navigator.pop(context, {
                'action': 'rebuy',
                'amount': amount,
              });
            } else {
              Navigator.pop(context, {
                'action': 'leave',
              });
            }
          },
          child: Text(
            'Confirm',
            style: TextStyle(
              color: _isRebuy ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsDialog extends StatefulWidget {
  final int currentSmallBlind;
  final int currentBigBlind;
  final bool useButtonMode;
  final bool currentHasBBante;
  final GameType gameType;
  final Function(int smallBlind, int bigBlind, bool hasBBante) onBlindsChanged;
  final Function(bool) onButtonModeToggled;

  const _SettingsDialog({
    Key? key,
    required this.currentSmallBlind,
    required this.currentBigBlind,
    required this.useButtonMode,
    required this.currentHasBBante,
    required this.gameType,
    required this.onBlindsChanged,
    required this.onButtonModeToggled,
  }) : super(key: key);

  @override
  _SettingsDialogState createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  static const int MIN_SMALL_BLIND = 1;

  late int smallBlind;
  late int bigBlind;
  late bool useButtonMode;
  late bool hasBBante;

  @override
  void initState() {
    super.initState();
    smallBlind = widget.currentSmallBlind;
    bigBlind = widget.currentBigBlind;
    useButtonMode = widget.useButtonMode;
    hasBBante = widget.currentHasBBante;
  }

  Future<void> _showBlindInputDialog(String title, int currentValue, Function(int) onValueChanged) async {
    final TextEditingController controller = TextEditingController(text: currentValue.toString());

    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF161618),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Enter $title',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            hintText: 'Enter value',
            hintStyle: TextStyle(color: Colors.white30),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF5AC95A)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF5AC95A), width: 2),
            ),
          ),
          onSubmitted: (value) {
            final intValue = int.tryParse(value);
            if (intValue != null && intValue > 0) {
              Navigator.pop(context, intValue);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF9A9A9A)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final intValue = int.tryParse(controller.text);
              if (intValue != null && intValue > 0) {
                Navigator.pop(context, intValue);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF5AC95A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'OK',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      onValueChanged(result);
    }
  }

  Widget _buildNumberAdjuster(String title, int value, VoidCallback onIncrement, VoidCallback onDecrement, VoidCallback onTap) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF2A2A2E)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onDecrement,
                icon: Icon(Icons.remove, color: Colors.white, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: Color(0xFF161618),
                  minimumSize: Size(36, 36),
                  padding: EdgeInsets.zero,
                ),
                tooltip: 'Decrease',
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onTap,
                child: Container(
                  constraints: BoxConstraints(minWidth: 50),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFF161618),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Color(0xFF5AC95A).withOpacity(0.3)),
                  ),
                  child: Text(
                    value.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF5AC95A),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onIncrement,
                icon: Icon(Icons.add, color: Colors.white, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: Color(0xFF161618),
                  minimumSize: Size(36, 36),
                  padding: EdgeInsets.zero,
                ),
                tooltip: 'Increase',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF2A2A2E)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Color(0xFF9A9A9A),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Color(0xFF5AC95A),
            activeTrackColor: Color(0xFF5AC95A).withOpacity(0.5),
            inactiveTrackColor: Color(0xFF2A2A2E),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Color(0xFF161618),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(Icons.settings, color: Color(0xFF5AC95A), size: 24),
          const SizedBox(width: 12),
          Text(
            'Game Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Blind adjustments section
            Text(
              'Blind Levels',
              style: TextStyle(
                color: Color(0xFF9A9A9A),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Changes take effect on the next hand',
              style: TextStyle(
                color: Color(0xFF9A9A9A).withOpacity(0.7),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),
            _buildNumberAdjuster(
              'Small Blind',
              smallBlind,
              () {
                setState(() {
                  smallBlind++;
                  // Ensure big blind is at least double the small blind
                  if (bigBlind < smallBlind * 2) {
                    bigBlind = smallBlind * 2;
                  }
                });
              },
              () {
                if (smallBlind > MIN_SMALL_BLIND) {
                  setState(() {
                    smallBlind--;
                    // Ensure big blind maintains proper relationship
                    if (bigBlind < smallBlind * 2) {
                      bigBlind = smallBlind * 2;
                    }
                  });
                }
              },
              () {
                _showBlindInputDialog('Small Blind', smallBlind, (value) {
                  setState(() {
                    smallBlind = value;
                    // Ensure big blind is at least double the small blind
                    if (bigBlind < smallBlind * 2) {
                      bigBlind = smallBlind * 2;
                    }
                  });
                });
              },
            ),
            const SizedBox(height: 12),
            _buildNumberAdjuster(
              'Big Blind',
              bigBlind,
              () {
                setState(() {
                  bigBlind++;
                });
              },
              () {
                // Big blind must be at least double the small blind
                if (bigBlind > smallBlind * 2) {
                  setState(() {
                    bigBlind--;
                  });
                }
              },
              () {
                _showBlindInputDialog('Big Blind', bigBlind, (value) {
                  setState(() {
                    // Ensure big blind is at least double the small blind
                    if (value >= smallBlind * 2) {
                      bigBlind = value;
                    } else {
                      bigBlind = smallBlind * 2;
                    }
                  });
                });
              },
            ),
            const SizedBox(height: 16),

            // BB Ante switch (only for tournaments)
            if (widget.gameType == GameType.tournament)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Color(0xFF1F1F23),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'BB Ante',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Switch(
                      value: hasBBante,
                      onChanged: (value) {
                        setState(() {
                          hasBBante = value;
                        });
                      },
                      activeColor: Color(0xFF5AC95A),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Interface settings section
            Text(
              'Interface',
              style: TextStyle(
                color: Color(0xFF9A9A9A),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            _buildToggle(
              'Button View',
              'Switch between button grid and drawing pad',
              useButtonMode,
              (value) {
                setState(() {
                  useButtonMode = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: Color(0xFF9A9A9A),
              fontSize: 16,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onBlindsChanged(smallBlind, bigBlind, hasBBante);
            widget.onButtonModeToggled(useButtonMode);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF5AC95A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text(
            'Apply',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }


}