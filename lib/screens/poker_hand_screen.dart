import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import '../design_system/poker_friend_theme.dart';
import '../widgets/drawing_painter.dart';
import '../widgets/board_cards_dialog.dart';
import '../widgets/hole_cards_dialog.dart';
import '../widgets/showdown_dialog.dart';
import 'seat_setup_screen.dart';
import '../widgets/action_button_grid.dart';
import '../widgets/winner_selection_dialog.dart';
import '../models/poker_game_state.dart';
import '../models/hand_state_machine.dart';
import '../models/game_types.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
import 'introduction_screen.dart';
import 'session_history_screen.dart';

class PokerHandScreen extends StatefulWidget {
  final int smallBlind;
  final int bigBlind;
  final int levelDuration;
  final int numberOfPlayers;
  final GameType gameType;

  const PokerHandScreen({
    super.key,
    required this.smallBlind,
    required this.bigBlind,
    required this.levelDuration,
    required this.numberOfPlayers,
    this.gameType = GameType.cash,
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
    
    // Initialize poker game state
    gameState = PokerGameState(
      numberOfPlayers: widget.numberOfPlayers,
      smallBlind: widget.smallBlind,
      bigBlind: widget.bigBlind,
      isCashGame: widget.gameType == GameType.cash,
    );
    
    // Initialize session manager
    sessionManager = PokerSessionManager(
      smallBlind: widget.smallBlind,
      bigBlind: widget.bigBlind,
      playerCount: widget.numberOfPlayers,
      gameType: widget.gameType,
    );
    
    // Load button mode setting
    _loadButtonModeSetting();
    
    // Start session and first hand
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSession();
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
    
    // Set our seat number and button position
    sessionManager.ourSeatNumber = ourSeat;
    gameState.buttonPosition = buttonPosition;
    
    // Initialize player stacks
    for (final entry in playerStacks.entries) {
      gameState.setPlayerStack(entry.key, entry.value);
    }
    
    // Initialize pot with blinds
    gameState.initializePot();
    
    await sessionManager.startSession();
    
    sessionManager.startHand(
      gameState.handNumber,
      gameState.buttonPosition,
    );
    
    // Auto-start the hand
    actions.add("🔥 Session started - Firebase ID: ${sessionManager.sessionId?.substring(0, 8)}...");
    actions.add("Game started. Blinds: ${widget.smallBlind}/${widget.bigBlind}");
    actions.add("Your seat: #$ourSeat (${sessionManager.getOurPosition(gameState.buttonPosition) ?? 'UNK'})");
    actions.add(gameState.getGameStateInfo());
    actions.add("${sessionManager.getPlayerNameWithPosition(gameState.currentPlayer)} to act");
    
    
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
        ),
      ),
    );
  }

  Future<void> _stopSession() async {
    print('🔄 DEBUG: _stopSession called');
    print('🔄 DEBUG: Session ID: ${sessionManager.sessionId}');
    print('🔄 DEBUG: Completed hands: ${sessionManager.completedHands.length}');
    
    // Show session name input dialog
    final sessionName = await _showSessionNameDialog();
    if (sessionName == null) {
      print('🔄 DEBUG: Session name dialog cancelled by user');
      return; // User cancelled
    }
    
    print('🔄 DEBUG: Session name entered: "$sessionName"');
    
    try {
      print('🔄 DEBUG: Calling sessionManager.endSession()');
      // End the current session
      await sessionManager.endSession();
      print('🔄 DEBUG: sessionManager.endSession() completed successfully');
      
      print('🔄 DEBUG: Calling _updateSessionName("$sessionName")');
      // Update session with the provided name
      await _updateSessionName(sessionName);
      print('🔄 DEBUG: _updateSessionName completed successfully');
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Session "$sessionName" saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      print('🔄 DEBUG: Session "$sessionName" completed successfully');
      
      // Navigate back to home screen
      Navigator.of(context).popUntil((route) => route.isFirst);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save session: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _showSessionNameDialog() async {
    final TextEditingController controller = TextEditingController();
    final now = DateTime.now();
    final defaultName = 'Session ${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
    
    controller.text = defaultName;
    
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Save Session'),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Enter a name for this poker session:'),
              SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Session Name',
                  border: OutlineInputBorder(),
                ),
                maxLength: 50,
                autofocus: true,
              ),
              SizedBox(height: 16),
              Text(
                'Total hands played: ${sessionManager.completedHands.length}',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, name);
              }
            },
            child: Text('Save Session'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateSessionName(String sessionName) async {
    print('💾 DEBUG: _updateSessionName called with: "$sessionName"');
    if (sessionManager.sessionId == null) {
      print('💾 DEBUG: No session ID found, returning early');
      return;
    }
    
    print('💾 DEBUG: Session ID: ${sessionManager.sessionId}');
    
    try {
      print('💾 DEBUG: Attempting to update Firebase...');
      // Try to update in Firebase first
      await FirebaseService.updateSessionName(sessionManager.sessionId!, sessionName);
      print('💾 DEBUG: Firebase update successful');
    } catch (e) {
      print('💾 DEBUG: Failed to update session name in Firebase: $e');
    }
    
    try {
      print('💾 DEBUG: Attempting to update local storage...');
      // Always update in local storage
      await LocalStorageService.updateSessionName(sessionManager.sessionId!, sessionName);
      print('💾 DEBUG: Local storage update successful');
    } catch (e) {
      print('💾 DEBUG: Failed to update session name in local storage: $e');
      rethrow;
    }
    
    print('💾 DEBUG: _updateSessionName completed successfully');
  }

  Future<void> _managePlayersDialog() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => SeatSetupScreen(
          playerCount: widget.numberOfPlayers,
          buttonPosition: gameState.buttonPosition,
          currentSeat: sessionManager.ourSeatNumber,
          sessionManager: sessionManager,
          isInitialSetup: false,
          isCashGame: widget.gameType == GameType.cash,
        ),
      ),
    );
    
    // Refresh the UI to show updated player names/status
    setState(() {});
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    _tapTimer = null;
    
    // End session when leaving
    if (sessionManager.sessionState == SessionState.active) {
      sessionManager.endSession().catchError((e) {
        print('Error ending session: $e');
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
      print('Error getting current player stack: $e');
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
      print('Error getting current player name: $e');
      return 'Unknown';
    }
  }

  // Race condition prevention for PostFrameCallbacks
  void _schedulePostFrameAction(VoidCallback action) {
    if (_isProcessingPostFrameAction) {
      print('Preventing duplicate PostFrameCallback execution');
      return;
    }
    
    _isProcessingPostFrameAction = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          action();
        } catch (e) {
          print('Error in PostFrameCallback action: $e');
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
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SessionHistoryScreen(),
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.history,
                            color: Colors.white,
                            size: 18,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      if (gameState.bettingRoundComplete && gameState.currentRound != BettingRound.river)
                        Container(
                          width: 40,
                          height: 40,
                          margin: EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Color(0xFF5AC95A),
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
                          color: Color(0xFF5AC95A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: completeHand,
                          icon: Icon(
                            Icons.check,
                            color: Colors.white,
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
              } else if (value == 'managePlayers') {
                _managePlayersDialog();
              } else if (value == 'stopSession') {
                _stopSession();
              } else if (value == 'settings') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const IntroductionScreen()),
                );
              }
            },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'endStreet',
                          child: Row(
                            children: [
                              Icon(Icons.stop, color: Color(0xFF9A9A9A), size: 18),
                              SizedBox(width: 12),
                              Text(
                                'End Street',
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
                              SizedBox(width: 12),
                              Text(
                                'Manage Players',
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
                              SizedBox(width: 12),
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
                              SizedBox(width: 12),
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
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(0xFF1F1F23),
                        borderRadius: BorderRadius.circular(PokerFriendRadius.l),
                        border: Border.all(color: Color(0xFF2A2A2E), width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(PokerFriendSpacing.xs),
                        child: _buildInfoItem(context, 'Pot', gameState.formatCurrency(gameState.currentPot), Icons.monetization_on_rounded),
                      ),
                    ),
                  ),
                  SizedBox(width: PokerFriendSpacing.xxs),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(0xFF1F1F23),
                        borderRadius: BorderRadius.circular(PokerFriendRadius.l),
                        border: Border.all(color: Color(0xFF2A2A2E), width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(PokerFriendSpacing.xs),
                        child: _buildInfoItem(context, 'To Act', _getCurrentPlayerNameSafely(), Icons.person_rounded),
                      ),
                    ),
                  ),
                  SizedBox(width: PokerFriendSpacing.xxs),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(0xFF1F1F23),
                        borderRadius: BorderRadius.circular(PokerFriendRadius.l),
                        border: Border.all(color: Color(0xFF2A2A2E), width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(PokerFriendSpacing.xs),
                        child: _buildInfoItem(context, 'Stack', _getCurrentPlayerStackSafely(), Icons.account_balance_wallet_rounded),
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
                  backgroundColor: Theme.of(context).colorScheme.secondary,
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
          color: Color(0xFF5AC95A),
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

  void _enterDragBettingMode(PlayerAction action) {
    setState(() {
      _isDragBetting = true;
      _pendingAction = action;
      _dragBetAmount = gameState.getMinimumBet().toDouble();
      _dragStartPosition = null;
      _dragBarPosition = 0.0; // Start at minimum bet (top)
    });
    
    // Start listening for drag gestures
    _showDragBettingInstruction();
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
    final minBet = gameState.getMinimumBet().toDouble();
    final maxBet = currentPlayer.currentStack;
    final betRange = maxBet - minBet;
    
    // Use actual screen height for better sensitivity calculation
    // Use 60% of screen height as effective drag area
    final screenHeight = MediaQuery.of(context).size.height;
    final effectiveDragArea = screenHeight * 0.6; // 60% of screen height
    final sensitivity = betRange / effectiveDragArea;
    
    // Calculate new bet amount based on total drag distance from start
    // Negative totalDeltaY = drag up = increase bet
    // Positive totalDeltaY = drag down = decrease bet
    final totalBetChange = -totalDeltaY * sensitivity;
    
    double newBetAmount = (minBet + totalBetChange).clamp(minBet, maxBet);
    
    // Round to appropriate increments
    if (widget.gameType == GameType.cash) {
      // Round to nearest $0.25
      newBetAmount = (newBetAmount * 4).round() / 4;
    } else {
      // Round to nearest 5 chips for tournaments
      newBetAmount = (newBetAmount / 5).round() * 5;
    }
    
    // Calculate drag bar position (0 = bottom/min bet, 1 = top/max bet)
    final betProgress = (newBetAmount - minBet) / betRange;
    final dragBarPosition = betProgress.clamp(0.0, 1.0);
    
    setState(() {
      _dragBetAmount = newBetAmount;
      _dragBarPosition = dragBarPosition;
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
          if (gameState.areAllPlayersAllIn()) {
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
    
    // Record action in session manager BEFORE performing it
    sessionManager.recordAction(
      gameState.currentPlayer,
      action,
      gameState.currentRound,
      gameState.buttonPosition,
      playerStack: currentPlayerStack,
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
          if (gameState.areAllPlayersAllIn()) {
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

  void _showBoardCardsDialog(BettingRound round) {
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

  void _proceedToNextStreet() {
    setState(() {
      gameState.startNewStreet(
        onStreetComplete: (BettingRound completedStreet, double potAmount) {
          // Save pot amount for the completed street
          sessionManager.savePotForStreet(completedStreet, potAmount);
        },
      );
      addAction("--- ${gameState.getCurrentStreetName()} ---");
      addAction("${sessionManager.getPlayerNameWithPosition(gameState.currentPlayer)} to act");
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
    // Save pot amount BEFORE distributing
    final potAmount = gameState.currentPot;
    print('DEBUG: Auto-completing hand with pot amount: $potAmount');
    
    // Get the remaining active player
    List<int> activePlayers = _getActivePlayers();
    
    // Instead of automatically awarding, ALWAYS show winner selection
    // This gives the user control and ensures the winner is always captured
    completeHand(); // This will show the winner selection dialog
  }

  void completeHand() async {
    // Save the pot amount BEFORE showing any dialogs
    final potAmount = gameState.currentPot;
    print('DEBUG: Completing hand with pot amount: $potAmount');
    
    // First, show winner selection dialog - ALWAYS show it
    List<int> activePlayers = _getActivePlayers();
    if (activePlayers.isEmpty) {
      // If no active players, get all players for selection
      activePlayers = List.generate(gameState.numberOfPlayers, (i) => i + 1);
    }
    
    List<String> playerNames = [];
    
    // Get player names for the dialog
    for (int i = 1; i <= gameState.numberOfPlayers; i++) {
      playerNames.add(sessionManager.getPlayerName(i));
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

    // If user somehow cancelled (shouldn't happen with barrierDismissible: false),
    // show again until they select someone
    while (winnerResult == null) {
      winnerResult = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => WinnerSelectionDialog(
          activePlayers: activePlayers,
          playerNames: playerNames,
          potAmount: potAmount,
          gameType: widget.gameType, // Pass game type
          buttonPosition: gameState.buttonPosition,
          playerCount: gameState.numberOfPlayers,
        ),
      );
    }

    final bool isChoppedPot = winnerResult['isChoppedPot'] ?? false;
    final List<int> winners = isChoppedPot
        ? List<int>.from(winnerResult['winners'] ?? [])
        : [winnerResult['winner'] as int];
    final Map<int, double> individualShares = isChoppedPot && winnerResult['individualShares'] != null
        ? Map<int, double>.from(winnerResult['individualShares'])
        : {};
    final double sharePerWinner = winnerResult['sharePerWinner'] ?? potAmount;

    print('DEBUG: Winner result: $winnerResult');
    print('DEBUG: Is chopped pot: $isChoppedPot');
    print('DEBUG: Winners: $winners');
    print('DEBUG: Individual shares: $individualShares');
    print('DEBUG: Share per winner: $sharePerWinner');
    
    // Then show hole cards dialog
    await _showHoleCardsDialog();
    
    setState(() {
      if (isChoppedPot) {
        // Complete current hand in session manager with pot and multiple winners
        sessionManager.completeCurrentHandWithChop(
          potAmount: potAmount,
          winnerIds: winners,
          individualShares: individualShares,
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
        // Complete current hand in session manager with single winner
        sessionManager.completeCurrentHand(
          potAmount: potAmount,
          winnerId: winners.first,
        );

        // Distribute pot to single winner
        _distributePotToWinner(winners.first);

        // Add action log for single winner
        String winnerName = sessionManager.getPlayerNameWithPosition(winners.first);
        actions.add("🏆 $winnerName wins ${_formatCurrency(potAmount)}");
      }

      // Start new hand in game state
      gameState.startNewHand();

      // Start new hand in session manager
      sessionManager.startHand(
        gameState.handNumber,
        gameState.buttonPosition,
      );

      // Clear actions for new hand but keep the winner announcement
      String lastWinnerAction = actions.isNotEmpty ? actions.last : '';
      actions.clear();
      if (lastWinnerAction.isNotEmpty) actions.add(lastWinnerAction);
      actions.add("💾 Hand #${gameState.handNumber - 1} saved to Firebase");
      actions.add("Hand #${gameState.handNumber} started");
      actions.add(gameState.getGameStateInfo());
      actions.add("${sessionManager.getPlayerNameWithPosition(gameState.currentPlayer)} to act");
    });
  }

  Future<void> _showHoleCardsDialog() async {
    // Collect board cards as used cards
    Set<String> usedCards = {};
    final boardCards = sessionManager.currentHand?.boardCards;
    if (boardCards != null) {
      if (boardCards.flop.isNotEmpty) usedCards.addAll(boardCards.flop);
      if (boardCards.turn != null && boardCards.turn!.isNotEmpty) usedCards.add(boardCards.turn!);
      if (boardCards.river != null && boardCards.river!.isNotEmpty) usedCards.add(boardCards.river!);
    }
    
    final holeCards = await showDialog<HoleCards>(
      context: context,
      barrierDismissible: true,
      builder: (context) => HoleCardsDialog(
        existingCards: sessionManager.currentHand?.ourHoleCards,
        usedCards: usedCards,
      ),
    );

    if (holeCards != null && sessionManager.currentHand != null) {
      sessionManager.currentHand!.ourHoleCards = holeCards;
      if (holeCards.isComplete) {
        addAction("🂠 Your cards: ${holeCards.card1} ${holeCards.card2}");
      }
    }
  }

  void _handleHandComplete() {
    // Hand complete - just finish it up
    // Winner selection is now handled manually in completeHand()
    _finalizeHand();
  }

  List<int> _getActivePlayers() {
    // Get players who haven't folded from the game state
    return gameState.getActivePlayers();
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
    
    // Start a new hand without calling completeHand again
    setState(() {
      // Start new hand in game state
      gameState.startNewHand();
      
      // Start new hand in session manager
      sessionManager.startHand(
        gameState.handNumber,
        gameState.buttonPosition,
      );
      
      actions.clear(); // Clear actions for new hand
      actions.add("💾 Hand #${gameState.handNumber - 1} saved");
      actions.add("Hand #${gameState.handNumber} started");
      actions.add(gameState.getGameStateInfo());
      actions.add("${sessionManager.getPlayerNameWithPosition(gameState.currentPlayer)} to act");
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