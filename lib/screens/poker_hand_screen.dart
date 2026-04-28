import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../design_system/poker_friend_theme.dart';
import '../design_system/design_system.dart';
import '../widgets/drawing_painter.dart';
import '../widgets/global_bottom_nav_bar.dart';
import '../widgets/board_cards_dialog.dart';
import '../widgets/all_in_board_cards_dialog.dart';
import '../widgets/hole_cards_dialog.dart';
import '../widgets/hand_review_dialog.dart';
import 'individual_session_tracking_screen.dart';
import '../widgets/showdown_dialog.dart';
import 'seat_setup_screen.dart';
import '../widgets/action_button_grid.dart';
import '../widgets/table_management_sheet.dart';
import '../widgets/raise_snap_overlay.dart';
import '../widgets/winner_selection_dialog.dart';
import '../widgets/multi_pot_winner_dialog.dart';
import '../models/poker_game_state.dart';
import '../models/hand_state_machine.dart';
import '../models/game_types.dart';
import '../models/stack_bucket.dart';
import '../widgets/stack_range_circle.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
import '../services/auth_service.dart';
import '../services/logger_service.dart';
import '../services/free_tier_limits.dart';
import '../services/subscription_service.dart';
import '../onboarding/onboarding_state.dart';
import 'home_screen.dart';
import '../onboarding/onboarding_tour.dart';
import '../onboarding/onboarding_progress_bar.dart';
import '../onboarding/guided_hand_overlay.dart';
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

  // Quick stack update parameters (for individual session)
  final Map<int, double>? preConfiguredStacks;
  final int? preConfiguredButtonPosition;
  final Map<int, String>? preConfiguredPlayerNames;
  final bool skipTableSetup;

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
    this.preConfiguredStacks,
    this.preConfiguredButtonPosition,
    this.preConfiguredPlayerNames,
    this.skipTableSetup = false,
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

class _PokerHandScreenState extends State<PokerHandScreen> with TickerProviderStateMixin {
  late PokerGameState gameState;
  late PokerSessionManager sessionManager;
  bool _allInHandCompleted = false;
  bool _showStreetCompleteIndicator = false;
  bool _isSettlingBetweenHands = false; // Brief pause after hand completes
  String? _settlingWinnerName; // Winner name for settling overlay
  double? _settlingPotAmount; // Pot amount for settling overlay
  // Swipe gesture state
  Offset? _swipePanStart;
  // Raise snap overlay state
  bool _isRaiseSnapping = false;
  List<SnapPoint> _raiseSnapPoints = [];
  int _activeSnapIndex = 0;
  double _raiseSnapProgress = 0.0;
  double _raiseSnapAmount = 0.0;
  PlayerAction? _raiseSnapAction;
  // Action flash state
  String? _actionFlashText;
  Color _actionFlashColor = Colors.white;
  Color _actionFlashBgColor = Colors.black;
  Timer? _actionFlashTimer;
  AnimationController? _actionFlashController;
  Animation<double>? _actionFlashSlide;
  Animation<double>? _actionFlashOpacity;
  // Fold swipe animation state
  double _foldSwipeDx = 0.0; // horizontal displacement during swipe
  bool _isFoldSwiping = false;
  // Tap flash animation state (check/call ripple)
  AnimationController? _tapFlashController;
  Animation<double>? _tapFlashOpacity;
  Color _tapFlashColor = Colors.transparent;
  // Set to true once the free-tier hand gate has fired for this session.
  bool _freeTierLocked = false;

  // Track user's starting stack for accurate win/loss calculation
  double? _userStartingStack;
  
  // Race condition prevention
  bool _isProcessingPostFrameAction = false;

  // Menu overlay state
  bool _showMenuOverlay = false;
  final GlobalKey _menuButtonKey = GlobalKey();

  // Onboarding keys
  final GlobalKey _drawingAreaKey = GlobalKey(debugLabel: 'drawingArea');
  final GlobalKey _potInfoKey = GlobalKey(debugLabel: 'potInfo');
  final GlobalKey _statsRowKey = GlobalKey(debugLabel: 'statsRow');
  final GlobalKey<GuidedHandOverlayState> _guidedOverlayKey = GlobalKey();
  final GlobalKey _gestureInfoKey = GlobalKey(debugLabel: 'gestureInfo');
  final GlobalKey _skipButtonKey = GlobalKey(debugLabel: 'skipButton');

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
    _scheduleOnboardingTour();

    // Start session and first hand
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // If we have pre-configured stacks and button (from quick stack update), use those
      if (widget.skipTableSetup &&
          widget.preConfiguredStacks != null &&
          widget.preConfiguredButtonPosition != null) {
        _initializeWithPreConfiguredData(
          widget.preConfiguredStacks!,
          widget.preConfiguredButtonPosition!,
          widget.preConfiguredPlayerNames,
        );
      }
      // If we have initial seat info from session setup, skip seat selection
      else if (widget.initialSeat != null && widget.initialButtonPosition != null) {
        _initializeWithSeatInfo(widget.initialSeat!, widget.initialButtonPosition!);
      } else {
        _initializeSession();
      }
    });
  }

  void _scheduleOnboardingTour() {
    if (!OnboardingState.isOnboardingActive ||
        OnboardingState.currentPhase != 4) return;

    // Guided hand overlay shows automatically via build() —
    // just ensure the phase is initialized.
    OnboardingState.guidedHandPhase = GuidedPhase.gestureInfo;
  }

  Future<void> _loadButtonModeSetting() async {
    // Quick swipe is now the only gesture mode — no loading needed
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

    // Add blind posting actions
    List<int> activePlayers = gameState.getActivePlayers();
    if (activePlayers.length > 2) {

      if (widget.hasBBante) {
      }
    }

    setState(() {});
  }

  Future<void> _initializeWithPreConfiguredData(
    Map<int, double> playerStacks,
    int buttonPosition,
    Map<int, String>? playerNames,
  ) async {
    // Initialize with pre-configured stacks and button from quick stack update
    // This skips the table selection UI entirely

    // Get user's name to identify which seat they selected for themselves
    String ourName = "You"; // Default name
    try {
      final user = AuthService.currentUser;
      if (user != null && user.displayName?.isNotEmpty == true) {
        ourName = user.displayName!;
      }
    } catch (e) {
      // Use default if auth fails
    }

    // CRITICAL: Find which seat the user selected for themselves in Quick Stack Update
    // Look through playerNames to find if user's name was assigned to any seat
    int? ourSeatFromNames;
    if (playerNames != null) {
      for (var entry in playerNames.entries) {
        if (entry.value == ourName) {
          ourSeatFromNames = entry.key;
          break;
        }
      }
    }

    // Set our seat number: use the seat where user placed themselves, or default to first active seat
    if (ourSeatFromNames != null) {
      sessionManager.ourSeatNumber = ourSeatFromNames;
    } else {
      // User didn't select themselves, default to first active seat with a stack
      int? firstActiveSeat;
      for (var entry in playerStacks.entries) {
        if (entry.value > 0) {
          firstActiveSeat = entry.key;
          break;
        }
      }
      sessionManager.ourSeatNumber = firstActiveSeat ?? 1;
    }

    // Apply ALL pre-configured player names from quick stack update
    // This includes the user's name if they selected themselves
    if (playerNames != null) {
      for (var entry in playerNames.entries) {
        final seatNumber = entry.key;
        final playerName = entry.value;
        if (seatNumber >= 1 && seatNumber <= 9 && playerName.isNotEmpty) {
          sessionManager.setPlayerName(seatNumber, playerName);
        }
      }
    }

    // If user didn't select themselves in any seat, set their name to ourSeatNumber
    if (ourSeatFromNames == null && sessionManager.ourSeatNumber != null) {
      sessionManager.setPlayerName(sessionManager.ourSeatNumber!, ourName);
    }

    // Initialize ALL player stacks and active status
    for (int i = 1; i <= 9; i++) {
      if (playerStacks.containsKey(i) && playerStacks[i]! > 0) {
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
    final initialStack = sessionSeat != null ? gameState.players[sessionSeat - 1].currentStack : (widget.individualCurrentStack ?? widget.startingStack);

    // CRITICAL: Store user's actual starting stack for accurate win/loss calculation
    // This reflects what they actually started with (including manual adjustments in Quick Stack Update)
    _userStartingStack = initialStack;

    // Start the session and hand (CRITICAL for proper action order)
    await sessionManager.startSession(initialStack: initialStack);

    sessionManager.startHand(
      gameState.handNumber,
      gameState.buttonPosition,
      sbSeat: gameState.effectiveSBPosition,
      bbSeat: gameState.effectiveBBPosition,
    );

    // Add action messages with proper context
    if (!widget.isIndividualSession) {
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

  Future<void> _handleTableChange() async {
    // Get hero's current stack to carry over
    final heroSeat = sessionManager.ourSeatNumber;
    final heroStack = heroSeat != null ? gameState.getPlayerStack(heroSeat) : 0.0;
    final heroName = heroSeat != null ? sessionManager.playerNames[heroSeat] : null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1E),
        title: Text(
          'Change Table',
          style: GoogleFonts.ibmPlexSans(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Moving to Table ${sessionManager.currentTableNumber + 1}. Your stack (${gameState.formatCurrency(heroStack)}) will carry over. Other players will be cleared.',
          style: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Change Table', style: GoogleFonts.ibmPlexSans(color: const Color(0xFF62E3BC))),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      // Increment table number
      sessionManager.currentTableNumber++;

      // Clear all seats except hero
      final allSeats = Set<int>.from(sessionManager.activeSeats);
      for (final seat in allSeats) {
        if (seat != heroSeat) {
          sessionManager.activeSeats.remove(seat);
          sessionManager.playerNames.remove(seat);
          sessionManager.playerStacks.remove(seat);
          sessionManager.playerIds.remove(seat);
          gameState.setPlayerActive(seat, false);
        }
      }

      // Reset hero confidence to high (known stack at table change)
      if (heroSeat != null) {
        gameState.setPlayerStack(heroSeat, heroStack);
      }
    });

    // Open table management sheet so user can add new opponents
    if (mounted) {
      TableManagementSheet.show(
        context: context,
        gameState: gameState,
        sessionManager: sessionManager,
        heroSeat: sessionManager.ourSeatNumber ?? 1,
        onChanged: () => setState(() {}),
      );
    }
  }

  Future<void> _stopSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 309,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF101115),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1B1E24)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black,
                  blurRadius: 114,
                  offset: Offset(20, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Stop icon - ring with filled square
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFD55A41),
                      width: 0.857,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 11.14,
                      height: 11.14,
                      color: const Color(0xFFD55A41),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Stop Session?',
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    height: 1.44,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to stop this session? All hands will be saved.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.ibmPlexSans(
                    color: const Color(0xFF8C8C8C),
                    fontSize: 15,
                    height: 1.44,
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
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(110),
                            border: Border.all(color: Colors.white),
                          ),
                          child: Center(
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.ibmPlexSans(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.5,
                                height: 24 / 17,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD55A41),
                            borderRadius: BorderRadius.circular(110),
                          ),
                          child: Center(
                            child: Text(
                              'Stop',
                              style: GoogleFonts.ibmPlexSans(
                                color: Colors.black,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.5,
                                height: 24 / 17,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      try {
        // Capture final stack before ending session
        final ourSeat = sessionManager.ourSeatNumber;
        if (ourSeat != null && ourSeat >= 1 && ourSeat <= gameState.players.length) {
          final finalStack = gameState.players[ourSeat - 1].currentStack;
          sessionManager.addFinalStackEntry(finalStack);
        }

        // End the session and save all data
        await sessionManager.endSession();

        // Check if widget is still mounted before using context
        if (!mounted) return;

        // Navigate back to main screen
        if (OnboardingState.isOnboardingActive && OnboardingState.currentPhase == 5) {
          // Push a fresh home screen so initState runs and detects phase 5
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => HomeScreen()),
            (route) => false,
          );
        } else {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        // Check if widget is still mounted before showing snackbar
        if (!mounted) return;

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
          // Button moved to Player $newButtonPosition
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
        // addAction removed
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
            // addAction removed
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
            // addAction removed
          }
        }
      } else if (currentPlayerStillActive && !buttonChanged) {
        // addAction removed
      }
    });
  }

  Future<void> _showBlindsEditDialog() async {
    final sbController = TextEditingController(text: gameState.smallBlind.toString());
    final bbController = TextEditingController(text: gameState.bigBlind.toString());

    final result = await showDialog<Map<String, int>>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161618),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Blinds',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Takes effect next hand',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SB', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: sbController,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        style: GoogleFonts.robotoMono(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF1B1E24),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('/', style: GoogleFonts.robotoMono(fontSize: 24, color: Colors.white.withValues(alpha: 0.3))),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('BB', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: bbController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.robotoMono(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF1B1E24),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        actions: [
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                final sb = int.tryParse(sbController.text) ?? gameState.smallBlind;
                final bb = int.tryParse(bbController.text) ?? gameState.bigBlind;
                Navigator.pop(context, {'sb': sb, 'bb': bb >= sb ? bb : sb});
              },
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF89F1EC),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                'Apply',
                style: GoogleFonts.ibmPlexSans(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      final sb = result['sb']!;
      final bb = result['bb']!;

      setState(() {
        sessionManager.smallBlind = sb;
        sessionManager.bigBlind = bb;
        gameState.smallBlind = sb;
        gameState.bigBlind = bb;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('small_blind', sb);
      await prefs.setInt('big_blind', bb);

      if (widget.isIndividualSession && sessionManager.sessionId != null) {
        await FirebaseService.updateIndividualSession(
          sessionId: sessionManager.sessionId!,
          smallBlind: sb,
          bigBlind: bb,
          hasBBante: gameState.hasBBante,
        ).catchError((e) {});
      }
    }
  }


  @override
  void dispose() {
    _actionFlashTimer?.cancel();
    _actionFlashTimer = null;
    _actionFlashController?.dispose();
    _tapFlashController?.dispose();

    // End session when leaving, but only if there's actual data to save
    if (sessionManager.sessionState == SessionState.active) {
      final hasData = sessionManager.completedHands.isNotEmpty ||
          (sessionManager.currentHand?.actions.isNotEmpty ?? false);
      if (hasData) {
        sessionManager.endSession().catchError((e) {});
      }
    }

    super.dispose();
  }

  // Navigation confirmation helpers

  /// Returns true if there's unsaved session data that should be confirmed before leaving
  bool _hasUnsavedSessionData() {
    // Session must be active
    if (sessionManager.sessionState != SessionState.active) {
      return false;
    }

    // Check if there are any completed hands OR current hand has actions
    final hasCompletedHands = sessionManager.completedHands.isNotEmpty;
    final hasCurrentHandActions = sessionManager.currentHand?.actions.isNotEmpty ?? false;

    return hasCompletedHands || hasCurrentHandActions;
  }

  /// Shows confirmation dialog when user tries to navigate away from active session
  /// Returns: 'save' to save and exit, 'discard' to exit without saving, null to cancel
  Future<String?> _showNavigationConfirmationDialog() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161618),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Leave Session?',
            style: AppTypography.pageTitle().copyWith(fontSize: 20),
            textAlign: TextAlign.center,
          ),
          content: Text(
            'You have an active session with ${sessionManager.completedHands.length} hand(s) logged. What would you like to do?',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall(
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Save & Exit (primary — cyan/mint text)
                TextButton(
                  onPressed: () => Navigator.pop(context, 'save'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Save & Exit',
                    style: AppTypography.bodyLarge(
                      color: AppColors.buttonPrimary,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 4),
                // Discard & Exit (destructive — red text)
                TextButton(
                  onPressed: () => Navigator.pop(context, 'discard'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Discard & Exit',
                    style: AppTypography.bodyLarge(
                      color: const Color(0xFFFF4444),
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 4),
                // Cancel (secondary — subtle white)
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Cancel',
                    style: AppTypography.bodyLarge(
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Handles navigation attempt with confirmation if needed
  Future<void> _handleNavigationAttempt({bool isBackButton = false}) async {
    if (!_hasUnsavedSessionData()) {
      // No data logged - delete the empty session from Firebase/local storage
      final sessionId = sessionManager.sessionId;
      if (sessionId != null) {
        await FirebaseService.deleteSession(sessionId);
        await LocalStorageService.deleteSession(sessionId);
      }
      sessionManager.sessionState = SessionState.ended;
      if (isBackButton) {
        Navigator.pop(context);
      }
      return;
    }

    final result = await _showNavigationConfirmationDialog();

    if (result == null) {
      // User cancelled, stay on screen
      return;
    }

    if (result == 'save') {
      // Save session and exit
      try {
        // Capture final stack before ending session
        final ourSeat = sessionManager.ourSeatNumber;
        if (ourSeat != null && ourSeat >= 1 && ourSeat <= gameState.players.length) {
          final finalStack = gameState.players[ourSeat - 1].currentStack;
          sessionManager.addFinalStackEntry(finalStack);
        }

        await sessionManager.endSession();

        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else if (result == 'discard') {
      // Discard - delete the session from Firebase and local storage
      final sessionId = sessionManager.sessionId;
      if (sessionId != null) {
        await FirebaseService.deleteSession(sessionId);
        await LocalStorageService.deleteSession(sessionId);
      }
      sessionManager.sessionState = SessionState.ended;

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  // Null-safe helper methods to prevent crashes
  String _getCurrentPlayerStackSafely() {
    try {
      if (gameState.currentPlayer < 1 || gameState.currentPlayer > gameState.numberOfPlayers) {
        return gameState.formatCurrency(0.0);
      }
      final stack = gameState.getPlayerStack(gameState.currentPlayer);
      final isHero = gameState.currentPlayer == sessionManager.ourSeatNumber;
      return StackBucketHelper.displayForPlayer(
        stack: stack,
        bigBlind: sessionManager.bigBlind,
        isHero: isHero,
        formatCurrency: gameState.formatCurrency,
      );
    } catch (e) {
      return gameState.formatCurrency(0.0);
    }
  }

  StackConfidence _getCurrentPlayerStackConfidence() {
    try {
      if (gameState.currentPlayer < 1 || gameState.currentPlayer > gameState.numberOfPlayers) {
        return StackConfidence.high;
      }
      if (gameState.currentPlayer == sessionManager.ourSeatNumber) {
        return StackConfidence.high; // Hero stack is always known
      }
      return gameState.getPlayerStackConfidence(gameState.currentPlayer);
    } catch (e) {
      return StackConfidence.high;
    }
  }

  void _showAdjustStackDialog() {
    final player = gameState.currentPlayer;
    final currentStack = gameState.getPlayerStack(player);
    final controller = TextEditingController(text: currentStack.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1E),
        title: Text(
          'Adjust Stack',
          style: GoogleFonts.ibmPlexSans(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            hintText: 'Enter stack amount',
            hintStyle: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C)),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF62E3BC)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF62E3BC), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C))),
          ),
          TextButton(
            onPressed: () {
              final newStack = double.tryParse(controller.text);
              if (newStack != null && newStack >= 0) {
                setState(() {
                  gameState.setPlayerStack(player, newStack);
                });
              }
              Navigator.pop(ctx);
            },
            child: Text('Update', style: GoogleFonts.ibmPlexSans(color: const Color(0xFF62E3BC))),
          ),
        ],
      ),
    );
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
    
    final screenWidth = MediaQuery.of(context).size.width;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _handleNavigationAttempt(isBackButton: true);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBody: true,
        bottomNavigationBar: GlobalBottomNavBar(
          currentScreen: '',
          onNavigationAttempt: () async {
            if (!_hasUnsavedSessionData()) {
              // No data logged - delete the empty session from Firebase/local storage
              final sessionId = sessionManager.sessionId;
              if (sessionId != null) {
                await FirebaseService.deleteSession(sessionId);
                await LocalStorageService.deleteSession(sessionId);
              }
              sessionManager.sessionState = SessionState.ended;
              return true; // Allow navigation
            }

            final result = await _showNavigationConfirmationDialog();

            if (result == 'save') {
              try {
                final ourSeat = sessionManager.ourSeatNumber;
                if (ourSeat != null && ourSeat >= 1 && ourSeat <= gameState.players.length) {
                  final finalStack = gameState.players[ourSeat - 1].currentStack;
                  sessionManager.addFinalStackEntry(finalStack);
                }
                await sessionManager.endSession();
                return true; // Allow navigation after save
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to save session: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return false; // Block navigation on error
              }
            } else if (result == 'discard') {
              // Discard - delete the session from Firebase and local storage
              final sessionId = sessionManager.sessionId;
              if (sessionId != null) {
                await FirebaseService.deleteSession(sessionId);
                await LocalStorageService.deleteSession(sessionId);
              }
              sessionManager.sessionState = SessionState.ended;
              return true; // Allow navigation after discard
            }

            return false; // Cancel - block navigation
          },
        ),
        body: Stack(
        children: [
          // Teal gradient background (consistent with other screens)
          Positioned(
            top: -screenWidth * 0.3,
            right: -screenWidth * 0.25,
            child: Transform.scale(
              scaleX: 1.0,
              scaleY: 0.7,
              child: Container(
                width: screenWidth * 1.5,
                height: screenWidth * 1.2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.5,
                    colors: [
                      Color(0xFF1A4A4A),
                      Color(0xFF133538).withOpacity(0.7),
                      Color(0xFF133538).withOpacity(0.3),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.3, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                OnboardingProgressBar(),
                // Header - Figma Design
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Row(
                    children: [
                      // Back button - 44px circle
                      GestureDetector(
                        onTap: () => _handleNavigationAttempt(isBackButton: true),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFF101115),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title section
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hand #${gameState.handNumber}',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 27,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.5,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Builder(
                              builder: (context) {
                                final baseSubtitle =
                                    '${gameState.currentRound.name.toUpperCase()} • ${gameState.getActivePlayers().length} players';
                                // Show "N/5 free" counter for users on the free tier,
                                // hidden for premium so paying users get a clean header.
                                final showFreeCounter =
                                    !SubscriptionService.isPremium;
                                final handsUsed = sessionManager
                                    .completedHands.length;
                                final subtitle = showFreeCounter
                                    ? '$baseSubtitle • $handsUsed/${FreeTierLimits.maxHandsPerSession} free'
                                    : baseSubtitle;
                                return Text(
                                  subtitle,
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 13,
                                    color: const Color(0xFFD3FFFD),
                                    fontWeight: FontWeight.w400,
                                    height: 1.47,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      // Action buttons - 44px circles
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Next street auto-advances via _autoAdvanceWithIndicator()
                          // Next Hand (skip) button
                          GestureDetector(
                            onTap: _skipCurrentAction,
                            child: Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF101115),
                                borderRadius: BorderRadius.circular(110),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Next Hand',
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Menu button
                          _buildMenuButton(context),
                        ],
                      ),
                    ],
                  ),
                ),

              // Main Gesture Area - Dark background
              Expanded(
                child: Container(
                  key: _drawingAreaKey,
                  margin: EdgeInsets.fromLTRB(16, 4, 16, 7),
                  decoration: BoxDecoration(
                    color: Color(0xFF35373C),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                  children: [
                    // Gesture input area — tap=check/call, swipe out=fold, swipe up=raise
                    GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) => _isRaiseSnapping ? _cancelRaiseSnap() : _handleQuickSwipeTap(),
                        onPanStart: (details) {
                          _swipePanStart = details.localPosition;
                        },
                        onPanUpdate: _handleQuickSwipePanUpdate,
                        onPanEnd: _handleQuickSwipePanEnd,
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: Colors.transparent,
                        ),
                      ),

                    // Fold swipe visual feedback — directional "FOLD" indicator
                    if (_isFoldSwiping)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final progress = (_foldSwipeDx.abs() / (constraints.maxWidth * 0.4)).clamp(0.0, 1.0);
                              final direction = _foldSwipeDx >= 0 ? 1.0 : -1.0;
                              return Stack(
                                children: [
                                  // Directional gradient overlay
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: direction > 0 ? Alignment.centerLeft : Alignment.centerRight,
                                          end: direction > 0 ? Alignment.centerRight : Alignment.centerLeft,
                                          colors: [
                                            Colors.transparent,
                                            Color(0xFFE85D5D).withValues(alpha: 0.12 * progress),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // "FOLD" text that slides with swipe
                                  Center(
                                    child: Transform.translate(
                                      offset: Offset(_foldSwipeDx * 0.3, 0),
                                      child: Opacity(
                                        opacity: progress * 0.7,
                                        child: Transform.rotate(
                                          angle: direction * -0.08 * progress,
                                          child: Text(
                                            'FOLD',
                                            style: GoogleFonts.ibmPlexSans(
                                              fontSize: 32,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFFE85D5D),
                                              letterSpacing: 6,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),

                    // (Folded to me + Next Hand buttons moved below canvas)

                    // Table icon + blinds display
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Table icon
                          GestureDetector(
                            onTap: () {
                              TableManagementSheet.show(
                                context: context,
                                gameState: gameState,
                                sessionManager: sessionManager,
                                heroSeat: sessionManager.ourSeatNumber ?? 1,
                                onChanged: () => setState(() {}),
                              );
                            },
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.table_restaurant_outlined,
                                color: Color(0xFF8C8C8C),
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Session Details info button
                          GestureDetector(
                            onTap: () => _showSessionDetails(),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.info_outline,
                                color: Color(0xFF8C8C8C),
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Blinds pill — tappable to edit
                          GestureDetector(
                            onTap: () => _showBlindsEditDialog(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${gameState.smallBlind}/${gameState.bigBlind}',
                                style: GoogleFonts.robotoMono(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tap flash — brief color wash on drawing board for check/call/bet/raise
                    if (_tapFlashController != null && _tapFlashController!.isAnimating)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              color: _tapFlashColor.withValues(alpha: 0.08 * (_tapFlashOpacity?.value ?? 0.0)),
                            ),
                          ),
                        ),
                      ),

                    // Action flash overlay (top of drawing board) — animated slide + fade
                    if (_actionFlashText != null)
                      Positioned(
                        top: 12,
                        left: 16,
                        right: 16,
                        child: Opacity(
                          opacity: _actionFlashOpacity?.value ?? 1.0,
                          child: Transform.translate(
                            offset: Offset(0, _actionFlashSlide?.value ?? 0.0),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _actionFlashBgColor.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _actionFlashColor.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  _actionFlashText!,
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 14,
                                    color: _actionFlashColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Street Complete indicator (brief flash before auto-advance)
                    if (_showStreetCompleteIndicator)
                      Center(
                        child: AnimatedOpacity(
                          opacity: _showStreetCompleteIndicator ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF62E3BC).withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(40),
                            ),
                            child: Text(
                              'Street Complete',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 15,
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Raise snap overlay (quick swipe mode)
                    if (_isRaiseSnapping)
                      RaiseSnapOverlay(
                        snapPoints: _raiseSnapPoints,
                        currentAmount: _raiseSnapAmount,
                        activeSnapIndex: _activeSnapIndex,
                        dragProgress: _raiseSnapProgress,
                        actionLabel: _raiseSnapAction == PlayerAction.raise ? 'RAISE' : 'BET',
                        formattedAmount: gameState.formatCurrency(_raiseSnapAmount),
                        isCashGame: gameState.isCashGame,
                        onTapAmount: _openNumpadFromSnap,
                      ),

                    // Settling overlay between hands
                    if (_isSettlingBetweenHands)
                      GestureDetector(
                        onTap: _skipSettling,
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.6),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_settlingWinnerName != null) ...[
                                  Text(
                                    _settlingWinnerName!,
                                    style: GoogleFonts.ibmPlexSans(
                                      fontSize: 22,
                                      color: const Color(0xFF62E3BC),
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'wins ${_settlingPotAmount != null ? '${widget.gameType == GameType.cash ? '\$' : ''}${_settlingPotAmount!.toStringAsFixed(0)}' : 'the pot'}',
                                    style: GoogleFonts.ibmPlexSans(
                                      fontSize: 16,
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ] else
                                  Text(
                                    'Hand Complete',
                                    style: GoogleFonts.ibmPlexSans(
                                      fontSize: 20,
                                      color: const Color(0xFF62E3BC),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                Text(
                                  'Tap to continue',
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Gesture tooltip backdrop (dismiss on tap anywhere in drawing area)
                    if (_showGestureTooltip)
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () => setState(() => _showGestureTooltip = false),
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                    // Gesture tooltip overlay (positioned, doesn't push layout)
                    if (_showGestureTooltip)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _buildGestureTooltip(),
                      ),
                  ],
                ),
              ),
            ),
          ),
          
          // Folded to me + Next Hand — side by side below canvas
          if (_canShowFoldedToMe() || _canShowNextHand())
            Container(
              margin: const EdgeInsets.fromLTRB(16, 7, 16, 0),
              child: Row(
                children: [
                  if (_canShowFoldedToMe())
                    Expanded(
                      child: GestureDetector(
                        onTap: _handleFoldedToMe,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF62E3BC),
                            borderRadius: BorderRadius.circular(110),
                          ),
                          child: Center(
                            child: Text(
                              'Folded to me',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 17,
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.5,
                                height: 24 / 17,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_canShowFoldedToMe() && _canShowNextHand())
                    const SizedBox(width: 10),
                  if (_canShowNextHand())
                    Expanded(
                      child: GestureDetector(
                        onTap: _skipCurrentAction,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(110),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Next Hand',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 17,
                                color: Colors.white.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.5,
                                height: 24 / 17,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Undo Last Action Button - White pill
          if (_canUndoLastAction())
            Container(
              margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
              width: double.infinity,
              child: GestureDetector(
                onTap: _undoLastAction,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(110),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildIcon('icons/figma_icons/undo.svg', 24, Colors.black),
                      SizedBox(width: 8),
                      Text(
                        'Undo Last Action',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 17,
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                          height: 24 / 17,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Game Info Row - Pot, Stack, To Act
          Container(
            key: _statsRowKey,
            margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: gameState.areAllPlayersAllIn()
              ? Container(
                  key: _potInfoKey,
                  decoration: BoxDecoration(
                    color: Color(0xFF62E3BC).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFF62E3BC), width: 2),
                  ),
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.casino, color: Color(0xFF62E3BC), size: 24),
                      SizedBox(width: 12),
                      Text(
                        'ALL IN HAND',
                        style: GoogleFonts.ibmPlexSans(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        '• POT: ${gameState.formatCurrency(gameState.currentPot)}',
                        style: GoogleFonts.ibmPlexSans(
                          color: Color(0xFF62E3BC),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : Row(
                  key: _potInfoKey,
                  children: [
                    Expanded(child: _buildInfoCard('Pot', gameState.formatCurrency(gameState.currentPot))),
                    SizedBox(width: 8),
                    Expanded(child: _buildStackInfoCard()),
                    SizedBox(width: 8),
                    Expanded(child: _buildInfoCard('To Act', _getCurrentPlayerNameSafely())),
                  ],
                ),
          ),

          // Bottom padding for nav bar
          SizedBox(height: _canUndoLastAction() ? 16 : 20),
            ],
          ),
        ),
        // Guided hand overlay (onboarding phase 4)
        GuidedHandOverlay(
          key: _guidedOverlayKey,
          menuButtonKey: _menuButtonKey,
          gestureInfoKey: _gestureInfoKey,
          skipButtonKey: _skipButtonKey,
          onOpenMenu: () => setState(() => _showMenuOverlay = true),
          onCloseMenu: () => setState(() => _showMenuOverlay = false),
          heroSeat: sessionManager.ourSeatNumber,
          currentPlayerSeat: gameState.currentPlayer,
          isValidAction: gameState.isValidAction,
          currentRound: gameState.currentRound,
          liveCurrentPlayer: () => gameState.currentPlayer,
          onSkipOrFinish: () => setState(() {}),
        ),
        // Gesture tooltip backdrop (closes tooltip when tapping outside drawing area)
        if (_showGestureTooltip)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _showGestureTooltip = false),
              child: Container(color: Colors.transparent),
            ),
          ),
        // Menu overlay backdrop (closes menu when tapping outside)
        if (_showMenuOverlay)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _showMenuOverlay = false),
              child: Container(color: Colors.transparent),
            ),
          ),
        // Menu overlay
        if (_showMenuOverlay)
          _buildMenuOverlay(),
        ],  // Stack children
        ),  // Stack
      ),  // Scaffold
    );  // PopScope
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

  // === Icon Helper ===

  Widget _buildIcon(String path, double size, Color color) {
    if (path.endsWith('.svg')) {
      return SvgPicture.asset(
        path,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    } else {
      return Image.asset(
        path,
        width: size,
        height: size,
        color: color,
      );
    }
  }

  // === Menu Button with Custom Overlay ===

  Widget _buildMenuButton(BuildContext context) {
    return GestureDetector(
      key: _menuButtonKey,
      onTap: () {
        setState(() {
          _showMenuOverlay = !_showMenuOverlay;
        });
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: Color(0xFF101115),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: _buildIcon('icons/figma_icons/dots_vertical.svg', 18, Colors.white),
        ),
      ),
    );
  }

  Widget _buildMenuOverlay() {
    // Get the position of the menu button
    final RenderBox? renderBox = _menuButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return SizedBox.shrink();

    final buttonPosition = renderBox.localToGlobal(Offset.zero);
    final buttonSize = renderBox.size;

    return Positioned(
      top: buttonPosition.dy + buttonSize.height + 8,
      right: 25,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Color(0xFF141414),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SizedBox(
            width: 113,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _buildMenuItem(
                  icon: 'icons/figma_icons/info.svg',
                  label: 'Gesture Guide',
                  onTap: () {
                    setState(() {
                      _showMenuOverlay = false;
                      _showGestureTooltip = true;
                    });
                  },
                ),
                SizedBox(height: 12),
                _buildMenuSeparator(),
                SizedBox(height: 12),
                _buildMenuItem(
                  icon: 'icons/figma_icons/menu_players.svg',
                  label: 'Manage Players',
                  onTap: () {
                    setState(() => _showMenuOverlay = false);
                    _managePlayersDialog();
                  },
                ),
                SizedBox(height: 12),
                _buildMenuSeparator(),
                SizedBox(height: 12),
                _buildMenuItem(
                  icon: 'icons/figma_icons/forward.svg',
                  label: 'Change Table',
                  onTap: () {
                    setState(() => _showMenuOverlay = false);
                    _handleTableChange();
                  },
                  iconColor: Color(0xFF62E3BC),
                ),
                if (widget.gameType == GameType.tournament) ...[
                  SizedBox(height: 12),
                  _buildMenuSeparator(),
                  SizedBox(height: 12),
                  _buildMenuItem(
                    icon: 'icons/figma_icons/plus.svg',
                    label: 'Rebuy',
                    onTap: () {
                      setState(() => _showMenuOverlay = false);
                      _showRebuyDialog();
                    },
                    iconColor: Color(0xFF62E3BC),
                  ),
                ],
                SizedBox(height: 12),
                _buildMenuSeparator(),
                SizedBox(height: 12),
                _buildMenuItem(
                  icon: 'icons/figma_icons/menu_stop.svg',
                  label: 'Stop Session',
                  onTap: () {
                    setState(() => _showMenuOverlay = false);
                    _stopSession();
                  },
                  textColor: Color(0xFFD55A41),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    Key? key,
    required String icon,
    required String label,
    required VoidCallback onTap,
    Color textColor = Colors.white,
    Color? iconColor,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 113,
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: iconColor != null
                ? _buildIcon(icon, 16, iconColor)
                : SvgPicture.asset(icon, width: 16, height: 16),
            ),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: textColor,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSeparator() {
    return Container(
      height: 1,
      width: 113,
      color: Color(0xFF555555),
    );
  }

  // === Info Card (simple dark card) ===

  Widget _buildStackInfoCard() {
    final confidence = _getCurrentPlayerStackConfidence();
    final isHero = gameState.currentPlayer == sessionManager.ourSeatNumber;
    final currentPlayer = gameState.currentPlayer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF101115),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Stack',
            style: GoogleFonts.ibmPlexSans(
              color: const Color(0xFF8C8C8C),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          if (isHero)
            Text(
              _getCurrentPlayerStackSafely(),
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            )
          else
            StackRangeCircle(
              currentStack: gameState.getPlayerStack(currentPlayer),
              bigBlind: sessionManager.bigBlind,
              confidence: confidence,
              isHero: false,
              isInteractive: gameState.currentRound == BettingRound.preflop,
              formatCurrency: gameState.formatCurrency,
              onRangeSelected: (StackRange range) {
                final newStack = StackBucketHelper.midpointBB(range) * sessionManager.bigBlind;
                setState(() {
                  gameState.setPlayerStack(currentPlayer, newStack);
                  // Override to medium — it's a range estimate, not exact
                  gameState.players[currentPlayer - 1].stackConfidence = StackConfidence.medium;
                  gameState.players[currentPlayer - 1].handsSinceLastObservation = 0;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF101115),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              color: const Color(0xFF8C8C8C),
              fontSize: 17,
              fontWeight: FontWeight.w500,
              height: 1.44,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            value,
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.44,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // === Stat Card for bottom panel ===

  Widget _buildStatCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF101115),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.46,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              color: const Color(0xFF8C8C8C),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.46,
            ),
          ),
        ],
      ),
    );
  }

  // === Pot & Stack Info Panel Helpers ===

  Widget _buildInfoStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF9A9A9A),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatPotAmount(double amount) {
    if (sessionManager.gameType == GameType.cash) {
      return '\$${amount.toStringAsFixed(0)}';
    }
    return amount.toStringAsFixed(0);
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
    return GestureDetector(
      key: _gestureInfoKey,
      onTap: () {
        setState(() {
          _showGestureTooltip = !_showGestureTooltip;
        });
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Color(0xFF101115),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: _buildIcon('icons/figma_icons/info.svg', 20, Color(0xFFADF9F5)),
        ),
      ),
    );
  }

  Widget _buildGestureTooltip() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Color(0xFF101115),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gestures',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              color: Color(0xFF9A9B9E),
              fontSize: 10,
              height: 1.5,
            ),
          ),
          SizedBox(height: 4),
          Container(height: 0.5, width: 140, color: Color(0xFF555555)),
          SizedBox(height: 6),
          SizedBox(
            width: 140,
            child: Column(
              children: [
                _buildGestureRow('Tap', 'Check / Call'),
                Container(height: 0.5, color: Color(0xFF555555)),
                SizedBox(height: 6),
                _buildGestureRow('Swipe Out', 'Fold'),
                Container(height: 0.5, color: Color(0xFF555555)),
                SizedBox(height: 6),
                _buildGestureRow('Swipe Up', 'Bet / Raise'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGestureRow(String gesture, String action) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            '$gesture:',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              color: Color(0xFF9A9B9E),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          SizedBox(width: 4),
          Text(
            action,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              color: Colors.white,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── GESTURE HANDLERS ──────────────────────────────

  /// Tap in Quick Swipe mode: check if no bet, call if bet exists.
  void _handleQuickSwipeTap() {
    if (gameState.bettingRoundComplete) return;
    if (gameState.isValidAction(PlayerAction.check)) {
      _performPokerAction(PlayerAction.check);
    } else if (gameState.isValidAction(PlayerAction.call)) {
      _performPokerAction(PlayerAction.call);
    }
  }

  /// Pan update in Quick Swipe mode: detect upward drag and enter raise snap mode.
  void _handleQuickSwipePanUpdate(DragUpdateDetails details) {
    final start = _swipePanStart;
    if (start == null) return;
    if (gameState.bettingRoundComplete) return;

    final dx = details.localPosition.dx - start.dx;
    final dy = details.localPosition.dy - start.dy;

    // If already in raise snap mode, update the snap position
    if (_isRaiseSnapping) {
      _updateRaiseSnap(details.localPosition.dy - start.dy);
      return;
    }

    // Track horizontal displacement for fold swipe visual feedback
    if (dx.abs() > 15 && dy.abs() < dx.abs() && gameState.isValidAction(PlayerAction.fold)) {
      if (!_isFoldSwiping) {
        setState(() => _isFoldSwiping = true);
      }
      setState(() => _foldSwipeDx = dx);
    } else if (_isFoldSwiping && dy < -30) {
      // User changed direction to vertical — cancel fold visual
      setState(() {
        _isFoldSwiping = false;
        _foldSwipeDx = 0.0;
      });
    }

    // Enter raise snap mode when dragging up past threshold (40px)
    if (dy < -40) {
      if (_isFoldSwiping) {
        setState(() {
          _isFoldSwiping = false;
          _foldSwipeDx = 0.0;
        });
      }
      PlayerAction? action;
      if (gameState.isValidAction(PlayerAction.bet)) {
        action = PlayerAction.bet;
      } else if (gameState.isValidAction(PlayerAction.raise)) {
        action = PlayerAction.raise;
      }
      if (action != null) {
        _enterRaiseSnapMode(action);
      }
    }

    // Swipe down past threshold → open numpad for manual bet entry
    if (dy > 60) {
      _swipePanStart = null; // prevent further processing
      setState(() {
        _isFoldSwiping = false;
        _foldSwipeDx = 0.0;
      });
      PlayerAction? action;
      if (gameState.isValidAction(PlayerAction.bet)) {
        action = PlayerAction.bet;
      } else if (gameState.isValidAction(PlayerAction.raise)) {
        action = PlayerAction.raise;
      }
      if (action != null) {
        _showBetAmountDialog(action).then((customAmount) {
          if (customAmount != null) {
            _performPokerActionWithAmount(action!, customAmount);
          }
        });
      }
    }
  }

  /// Enter raise snap mode: calculate snap points and show overlay.
  void _enterRaiseSnapMode(PlayerAction action) {
    final currentPlayer = gameState.getCurrentPlayer();
    if (currentPlayer == null) return;

    final isPreflop = gameState.currentRound == BettingRound.preflop;
    final minBet = action == PlayerAction.raise
        ? gameState.getMinimumRaise()
        : gameState.getMinimumBet();
    final maxBet = currentPlayer.currentStack + currentPlayer.betThisRound;
    final potAmount = gameState.currentPot;
    final bigBlind = gameState.bigBlind.toDouble();
    final isCash = gameState.isCashGame;
    final lastBet = gameState.getCurrentBet();

    List<SnapPoint> points;
    if (isPreflop) {
      points = RaiseSnapOverlay.preflopSnapPoints(
        minRaise: minBet,
        bigBlind: bigBlind,
        potAmount: potAmount,
        maxBet: maxBet,
        isCashGame: isCash,
        lastBet: lastBet,
      );
    } else {
      points = RaiseSnapOverlay.postflopSnapPoints(
        minBet: minBet,
        potAmount: potAmount,
        maxBet: maxBet,
        isCashGame: isCash,
        bigBlind: bigBlind,
        lastBet: lastBet,
      );
    }

    setState(() {
      _isRaiseSnapping = true;
      _raiseSnapPoints = points;
      _raiseSnapAction = action;
      _activeSnapIndex = 0;
      _raiseSnapProgress = 0.0;
      _raiseSnapAmount = points.isNotEmpty ? points.first.amount : minBet;
    });

    // Haptic feedback on entering raise mode
    HapticFeedback.mediumImpact();
  }

  /// Update raise snap position based on drag delta Y.
  void _updateRaiseSnap(double deltaY) {
    if (_raiseSnapPoints.isEmpty) return;

    // Map drag distance to progress (0 to 1)
    // Dragging up 200px = full range
    final dragRange = 200.0;
    final progress = (-deltaY - 40) / dragRange; // subtract initial threshold
    final clampedProgress = progress.clamp(0.0, 1.0);

    final newSnapIndex = RaiseSnapOverlay.findClosestSnap(_raiseSnapPoints, clampedProgress);
    final newAmount = _raiseSnapPoints[newSnapIndex].amount;

    // Haptic feedback when crossing a snap point
    if (newSnapIndex != _activeSnapIndex) {
      HapticFeedback.selectionClick();
    }

    setState(() {
      _raiseSnapProgress = clampedProgress;
      _activeSnapIndex = newSnapIndex;
      _raiseSnapAmount = newAmount;
    });
  }

  /// Cancel raise snap mode without performing action.
  void _cancelRaiseSnap() {
    setState(() {
      _isRaiseSnapping = false;
      _raiseSnapPoints = [];
      _raiseSnapAction = null;
      _activeSnapIndex = 0;
      _raiseSnapProgress = 0.0;
      _raiseSnapAmount = 0.0;
    });
  }

  /// Open numpad dialog for custom amount while in raise snap mode.
  void _openNumpadFromSnap() async {
    final action = _raiseSnapAction;
    if (action == null) return;

    // Cancel snap overlay first
    _cancelRaiseSnap();

    // Open numpad dialog
    final amount = await _showBetAmountDialog(action);
    if (amount != null) {
      _performPokerActionWithAmount(action, amount);
    }
  }

  /// Pan end in Quick Swipe mode: confirm raise snap or detect fold.
  void _handleQuickSwipePanEnd(DragEndDetails details) {
    // If in raise snap mode, confirm the bet or open numpad
    if (_isRaiseSnapping) {
      final action = _raiseSnapAction;
      final amount = _raiseSnapAmount;
      final progress = _raiseSnapProgress;
      _cancelRaiseSnap();
      _swipePanStart = null;

      if (action == null) return;

      // If user dragged back down (progress near 0), open numpad for custom entry
      if (progress < 0.05) {
        _showBetAmountDialog(action).then((customAmount) {
          if (customAmount != null) {
            _performPokerActionWithAmount(action, customAmount);
          }
        });
        return;
      }

      if (amount > 0) {
        // Round amount based on game type
        double finalAmount = amount;
        if (gameState.isCashGame) {
          finalAmount = (finalAmount * 4).round() / 4; // nearest $0.25
        } else {
          finalAmount = finalAmount.roundToDouble();
        }
        _performPokerActionWithAmount(action, finalAmount);
      }
      return;
    }

    // Reset fold swipe visual state
    setState(() {
      _isFoldSwiping = false;
      _foldSwipeDx = 0.0;
    });

    final start = _swipePanStart;
    _swipePanStart = null;
    if (start == null) return;
    if (gameState.bettingRoundComplete) return;

    final velocity = details.velocity.pixelsPerSecond;
    final speed = velocity.distance;

    // Need minimum speed to register as a fold swipe
    if (speed > 200) {
      if (gameState.isValidAction(PlayerAction.fold)) {
        _performPokerAction(PlayerAction.fold);
      }
    }
  }

  // ─── CLASSIC DRAWING GESTURE HANDLERS ───────��─────────────────

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
          elevation: 0,
          insetPadding: EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            constraints: BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(
              color: const Color(0xFF101115),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF1B1E24),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    children: [
                      Text(
                        action == PlayerAction.raise ? 'Raise Amount' : 'Bet Amount',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 17,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Min: ${widget.gameType == GameType.cash ? '\$${effectiveMinBet.toStringAsFixed(2)}' : effectiveMinBet.toInt()} · Max: ${widget.gameType == GameType.cash ? '\$${maxBet.toStringAsFixed(2)}' : maxBet.toInt()}',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 13,
                          color: const Color(0xFF8C8C8C),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                // Input field
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF4E5054)),
                    ),
                    child: TextField(
                      controller: amountController,
                      autofocus: true,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: widget.gameType == GameType.cash,
                      ),
                      style: GoogleFonts.ibmPlexSans(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        prefixText: widget.gameType == GameType.cash ? '\$ ' : '',
                        prefixStyle: GoogleFonts.ibmPlexSans(
                          color: const Color(0xFF8C8C8C),
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 14),
                // Multiplier buttons
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
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
                      _buildAllInButton(maxBet, amountController, setState),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                // Action buttons
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: [
                      // Full-width Confirm button
                      GestureDetector(
                        onTap: () {
                          final text = amountController.text.trim();
                          double? amount;
                          try {
                            amount = double.parse(text);
                            if (amount < effectiveMinBet || amount > maxBet) {
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
                        child: Container(
                          width: double.infinity,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF89F1EC),
                            borderRadius: BorderRadius.circular(110),
                          ),
                          child: Center(
                            child: Text(
                              action == PlayerAction.raise ? 'Raise' : 'Bet',
                              style: GoogleFonts.ibmPlexSans(
                                color: Colors.black,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      // Cancel button
                      GestureDetector(
                        onTap: () => Navigator.pop(context, null),
                        child: Container(
                          width: double.infinity,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(110),
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                          ),
                          child: Center(
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.ibmPlexSans(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.5,
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
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: const Color(0xFF4E5054)),
        ),
        child: Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            color: const Color(0xFF89F1EC),
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
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: const Color(0xFF4E5054)),
        ),
        child: Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            color: const Color(0xFF89F1EC),
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
          color: const Color(0xFFD55A41),
          borderRadius: BorderRadius.circular(40),
        ),
        child: Text(
          'All-In',
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _performPokerActionWithAmount(PlayerAction action, double amount) {
    if (_freeTierLocked) {
      _showFreeTierGate();
      return;
    }
    if (gameState.bettingRoundComplete) {
      // addAction removed
      _triggerInvalidActionVibration();
      return;
    }

    // Check if action is valid before performing it
    if (!gameState.isValidAction(action)) {
      _triggerInvalidActionVibration();
      // addAction removed
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

    // Flash the action on screen
    _showActionFlash(_actionFlashLabel(action, amount), action: action);

    // Perform action with specified amount
    String result = gameState.performActionWithAmount(action, amount);

    // Split result into individual lines and add each as separate action
    for (String line in result.split('\n')) {
      if (line.trim().isNotEmpty) {
        // addAction removed
      }
    }

    // Notify guided hand overlay
    _guidedOverlayKey.currentState?.onActionPerformed(action);

    // Check if hand ended automatically (only one player remaining)
    if (result.contains("Hand ends: Only one player remaining")) {
      // Use a post frame callback to avoid calling setState during build
      _schedulePostFrameAction(() {
        // addAction removed
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
            // addAction removed
            _showAllInBoardCardsDialog();
          } else {
            _autoAdvanceWithIndicator();
          }
        });
      } else if (gameState.bettingRoundComplete && gameState.currentRound == BettingRound.river) {
        // River betting complete - trigger showdown/winner selection
        _schedulePostFrameAction(() {
          _handleHandComplete();
        });
      } else if (gameState.areAllPlayersAllIn() && gameState.currentRound != BettingRound.river && !gameState.bettingRoundComplete) {
        // Handle edge case: all-in detected but betting round not marked complete yet
        _schedulePostFrameAction(() {
          // addAction removed
          gameState.bettingRoundComplete = true;
          setState(() {});
        });
      }
    }

    // Update UI
    setState(() {});
  }

  Future<void> _skipCurrentAction() async {
    // If actions have been taken in this hand, confirm before discarding
    final hasActions = sessionManager.currentHand?.actions.isNotEmpty == true;
    if (hasActions) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1B1E24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Hand in Progress',
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'There\'s a hand in progress. Moving to the next hand will discard all actions and restore player stacks.',
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.ibmPlexSans(
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF89F1EC),
              ),
              child: Text(
                'Move to Next Hand',
                style: GoogleFonts.ibmPlexSans(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    // Skip the entire hand - move button and start fresh without incrementing hand number
    setState(() {
      // Determine hero's blind obligation for THIS hand (before refunding)
      final ourSeat = sessionManager.ourSeatNumber;
      double heroBlindDeduction = 0.0;
      if (ourSeat != null) {
        if (ourSeat == gameState.effectiveSBPosition) {
          heroBlindDeduction = gameState.smallBlind.toDouble();
        } else if (ourSeat == gameState.effectiveBBPosition) {
          heroBlindDeduction = gameState.bigBlind.toDouble();
          if (gameState.hasBBante) {
            heroBlindDeduction += gameState.bigBlind.toDouble();
          }
        }
      }

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

      // Refund all pot contributions back to players before resetting
      for (var player in gameState.players) {
        if (player.isActive) {
          final totalContribution = player.betThisRound + player.totalContribution;
          if (totalContribution > 0) {
            player.currentStack += totalContribution;
          }
        }
      }

      // Deduct hero's blind from the skipped hand (blinds are a cost even if hand is not played out)
      if (ourSeat != null && heroBlindDeduction > 0) {
        final heroPlayer = gameState.players[ourSeat - 1];
        // Cap deduction to hero's stack (in case of all-in for less)
        final actualDeduction = heroBlindDeduction > heroPlayer.currentStack
            ? heroPlayer.currentStack
            : heroBlindDeduction;
        heroPlayer.currentStack -= actualDeduction;
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

      // Discard current hand to prevent saving incomplete hand
      sessionManager.currentHand = null;

      // Restart the hand in session manager to recalculate positions
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
    });
  }

  /// Action-specific flash colors.
  static const _actionColors = {
    PlayerAction.fold: (text: Color(0xFFE85D5D), bg: Color(0xFF2A1010)),       // red
    PlayerAction.check: (text: Color(0xFF89F1EC), bg: Color(0xFF0A1A1A)),      // teal/cyan
    PlayerAction.call: (text: Color(0xFF89F1EC), bg: Color(0xFF0A1A1A)),       // teal/cyan
    PlayerAction.bet: (text: Color(0xFFFFC857), bg: Color(0xFF2A2210)),        // gold
    PlayerAction.raise: (text: Color(0xFFFFC857), bg: Color(0xFF2A2210)),      // gold
  };

  void _showActionFlash(String text, {PlayerAction? action}) {
    _actionFlashTimer?.cancel();
    _actionFlashController?.dispose();

    // Set action-specific colors
    final colors = action != null ? _actionColors[action] : null;
    _actionFlashColor = colors?.text ?? Colors.white;
    _actionFlashBgColor = colors?.bg ?? Colors.black;

    final controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _actionFlashController = controller;

    // Slide in from slight offset + fade in, then fade out at end
    _actionFlashSlide = Tween<double>(begin: -12.0, end: 0.0).animate(
      CurvedAnimation(parent: controller, curve: const Interval(0.0, 0.3, curve: Curves.easeOut)),
    );
    _actionFlashOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(controller);

    setState(() => _actionFlashText = text);
    HapticFeedback.mediumImpact();

    controller.addListener(() {
      if (mounted) setState(() {});
    });
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _actionFlashText = null);
      }
    });
    controller.forward();

    // Trigger tap flash for check/call (brief color wash on drawing board)
    if (action == PlayerAction.check || action == PlayerAction.call) {
      _triggerTapFlash(const Color(0xFF89F1EC));
    } else if (action == PlayerAction.bet || action == PlayerAction.raise) {
      _triggerTapFlash(const Color(0xFFFFC857));
    }
  }

  /// Brief color wash on the drawing board for tap-based actions.
  void _triggerTapFlash(Color color) {
    _tapFlashController?.dispose();
    _tapFlashColor = color;

    final controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _tapFlashController = controller;

    _tapFlashOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 80),
    ]).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));

    controller.addListener(() {
      if (mounted) setState(() {});
    });
    controller.forward();
  }

  String _actionFlashLabel(PlayerAction action, [double? amount]) {
    final playerName = sessionManager.getPlayerName(gameState.currentPlayer) ?? 'Seat ${gameState.currentPlayer}';
    switch (action) {
      case PlayerAction.fold: return '$playerName FOLDS';
      case PlayerAction.check: return '$playerName CHECKS';
      case PlayerAction.call:
        if (amount != null) return '$playerName CALLS ${gameState.formatCurrency(amount)}';
        return '$playerName CALLS';
      case PlayerAction.bet:
        if (amount != null) return '$playerName BETS ${gameState.formatCurrency(amount)}';
        return '$playerName BETS';
      case PlayerAction.raise:
        if (amount != null) return '$playerName RAISES ${gameState.formatCurrency(amount)}';
        return '$playerName RAISES';
      default: return '$playerName acts';
    }
  }

  void _performPokerAction(PlayerAction action) {
    if (_freeTierLocked) {
      _showFreeTierGate();
      return;
    }
    if (gameState.bettingRoundComplete) {
      // addAction removed
      _triggerInvalidActionVibration();
      return;
    }

    // Check if action is valid before performing it
    if (!gameState.isValidAction(action)) {
      _triggerInvalidActionVibration();
      // addAction removed
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

    // Flash the action on screen
    _showActionFlash(_actionFlashLabel(action, actionAmount), action: action);

    String result = gameState.performAction(action);

    // Split result into individual lines and add each as separate action
    for (String line in result.split('\n')) {
      if (line.trim().isNotEmpty) {
        // addAction removed
      }
    }

    // Notify guided hand overlay
    _guidedOverlayKey.currentState?.onActionPerformed(action);

    // Check if hand ended automatically (only one player remaining)
    if (result.contains("Hand ends: Only one player remaining")) {
      // Use a post frame callback to avoid calling setState during build
      _schedulePostFrameAction(() {
        // addAction removed
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
            // addAction removed
            _showAllInBoardCardsDialog();
          } else {
            _autoAdvanceWithIndicator();
          }
        });
      } else if (gameState.bettingRoundComplete && gameState.currentRound == BettingRound.river) {
        // River betting complete - trigger showdown/winner selection
        _schedulePostFrameAction(() {
          _handleHandComplete();
        });
      } else if (gameState.areAllPlayersAllIn() && gameState.currentRound != BettingRound.river && !gameState.bettingRoundComplete) {
        // Handle edge case: all-in detected but betting round not marked complete yet
        _schedulePostFrameAction(() {
          // addAction removed
          gameState.bettingRoundComplete = true;
          setState(() {});
        });
      }
    }

    // Update UI
    setState(() {});
  }

  /// Whether we can show the "Folded to me" shortcut button.
  /// Conditions: preflop, hero hasn't acted yet, no voluntary non-fold
  /// actions recorded yet, and current player is NOT the hero (so there
  /// are players to fold).
  bool _canShowFoldedToMe() {
    if (gameState.currentRound != BettingRound.preflop) return false;
    if (gameState.bettingRoundComplete) return false;
    final heroSeat = sessionManager.ourSeatNumber;
    if (heroSeat == null) return false;
    // Don't show if hero already folded
    if (gameState.players[heroSeat - 1].hasFolded) return false;
    // Only show when it's NOT hero's turn — we'll fold everyone to hero
    if (gameState.currentPlayer == heroSeat) return false;

    // Check that no voluntary (non-blind, non-fold) actions happened
    final actions = sessionManager.currentHand?.actions ?? [];
    for (final a in actions) {
      if (a.street != BettingRound.preflop) continue;
      if (a.action == PlayerAction.fold) continue;
      // Any call/bet/raise means someone voluntarily entered
      if (a.action == PlayerAction.call ||
          a.action == PlayerAction.bet ||
          a.action == PlayerAction.raise) {
        return false;
      }
    }

    return true;
  }

  /// Folds all players from current player until it's the hero's turn.
  void _handleFoldedToMe() {
    final heroSeat = sessionManager.ourSeatNumber;
    if (heroSeat == null) return;

    // Fold players one at a time until hero has action
    // Safety: max 9 iterations to prevent infinite loop
    for (int i = 0; i < 9; i++) {
      if (gameState.currentPlayer == heroSeat) break;
      if (gameState.bettingRoundComplete) break;
      _performPokerAction(PlayerAction.fold);
    }
  }

  /// Whether to show the "Next Hand" button: hero has folded and
  /// there are 2+ active (non-folded) players still in the hand.
  bool _canShowNextHand() {
    final heroSeat = sessionManager.ourSeatNumber;
    if (heroSeat == null) return false;
    final heroPlayer = gameState.players[heroSeat - 1];
    if (!heroPlayer.hasFolded) return false;
    // Need 2+ active players still playing for there to be actions to skip
    final activePlayers = gameState.getActivePlayers();
    return activePlayers.length >= 2;
  }

  /// Shows a brief "Street Complete" indicator, then auto-advances.
  void _autoAdvanceWithIndicator() {
    setState(() => _showStreetCompleteIndicator = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _showStreetCompleteIndicator = false);
      nextStreet();
    });
  }

  void nextStreet() {
    // Check if we're transitioning from River - might need showdown
    if (gameState.currentRound == BettingRound.river) {
      _handleHandComplete();
      return;
    }

    // Check if this is an all-in situation where no one can act
    if (gameState.shouldAutoAdvanceToShowdown()) {
      // addAction removed
      _showAllInBoardCardsDialog();
      return;
    }

    // First proceed to next street
    _proceedToNextStreet();

    // Notify guided hand overlay about street advance
    _guidedOverlayKey.currentState?.onStreetAdvance(gameState.currentRound);

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
      // addAction removed

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

    // Check if we need side pot calculation
    // Log each player's state for debugging
    await LoggerService.debug('  Player states before side pot calculation:');
    for (var player in gameState.players) {
      if (player.isActive && !player.hasFolded) {
        final totalContrib = player.totalContribution + player.betThisRound;
        await LoggerService.debug('    P${player.playerId}: active=${player.isActive}, folded=${player.hasFolded}, '
            'totalContrib=${player.totalContribution}, betThisRound=${player.betThisRound}, '
            'total=${totalContrib}, stack=${player.currentStack}');
      }
    }

    List<SidePot> sidePots = SidePotCalculator.calculateSidePots(gameState.players);
    await LoggerService.debug('  Side pots calculated: ${sidePots.length} pots');
    for (var pot in sidePots) {
      await LoggerService.debug('    ${pot.toString()}');
    }

    Map<String, dynamic>? winnerResult;

    // Show multi-pot dialog if there are 2+ pots (main + side), otherwise show regular dialog
    if (sidePots.length >= 2) {
      await LoggerService.info('  Showing multi-pot winner dialog with ${sidePots.length} pots');

      // Create player ID to name map
      Map<int, String> playerIdToName = {};
      for (int playerId in activePlayers) {
        playerIdToName[playerId] = sessionManager.getPlayerNameWithPosition(playerId);
      }

      winnerResult = await MultiPotWinnerDialog.show(
        context: context,
        sidePots: sidePots,
        playerNames: playerNames,
        playerIdToName: playerIdToName,
        gameType: widget.gameType,
        buttonPosition: gameState.buttonPosition,
        playerCount: gameState.numberOfPlayers,
      );
    } else {
      await LoggerService.debug('  Showing regular winner selection dialog (${sidePots.length} pot)');
      winnerResult = await showDialog<Map<String, dynamic>>(
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
    }

    if (winnerResult != null) {
      // Process the winner result and complete the hand
      _processAllInWinnerResult(winnerResult);
    }
  }

  void _processAllInWinnerResult(Map<String, dynamic> winnerResult) {
    LoggerService.info('💰 _processAllInWinnerResult() called - Processing all-in winner');

    // Check if this is a multi-pot scenario
    final bool isMultiPot = winnerResult.containsKey('potResults');

    if (isMultiPot) {
      // Handle multi-pot scenario
      LoggerService.info('  Processing multi-pot winner result');

      _allInHandCompleted = true;
      setState(() {});
      // addAction removed

      final Map<int, Map<String, dynamic>> potResults =
          Map<int, Map<String, dynamic>>.from(winnerResult['potResults']);
      final List<SidePot> resultSidePots =
          List<SidePot>.from(winnerResult['sidePots']);

      // Collect all unique winners across all pots for showdown dialogs
      Set<int> allWinners = {};
      for (var potResult in potResults.values) {
        if (potResult['isChoppedPot'] == true) {
          allWinners.addAll(List<int>.from(potResult['winners']));
        } else {
          allWinners.add(potResult['winner'] as int);
        }
      }

      // Show hole cards dialog first, then complete the hand with winner info
      Future.delayed(Duration(milliseconds: 500), () async {
        // Show hole cards dialog first
        await _showHoleCardsDialog();

        final activePlayers = gameState.getActivePlayers();
        await LoggerService.info('About to call _showOpponentCardsDialog with activePlayers=$activePlayers');

        // Show opponent hole cards dialog for showdown situations
        await _showOpponentCardsDialog(activePlayers, allWinners.toList());

        setState(() {
          // Distribute each pot to its winner(s)
          List<String> potLogs = [];
          double totalDistributed = 0.0;

          for (int potIndex = 0; potIndex < resultSidePots.length; potIndex++) {
            final potResult = potResults[potIndex]!;
            final sidePot = resultSidePots[potIndex];
            final potName = potIndex == 0 ? 'Main Pot' : 'Side Pot $potIndex';

            if (potResult['isChoppedPot'] == true) {
              final winners = List<int>.from(potResult['winners']);
              final individualShares = Map<int, double>.from(potResult['individualShares']);

              for (int winnerId in winners) {
                final winnerShare = individualShares[winnerId]!;
                final winnerPlayer = gameState.players[winnerId - 1];
                winnerPlayer.currentStack += winnerShare;
                totalDistributed += winnerShare;
              }

              List<String> winnerDetails = winners.map((id) {
                final name = sessionManager.getPlayerNameWithPosition(id);
                final amount = individualShares[id]!;
                return '$name (${_formatCurrency(amount)})';
              }).toList();
              potLogs.add("🏆 $potName chopped: ${winnerDetails.join(', ')}");
            } else {
              final winnerId = potResult['winner'] as int;
              final potAmount = potResult['potAmount'] as double;
              final winnerPlayer = gameState.players[winnerId - 1];
              winnerPlayer.currentStack += potAmount;
              totalDistributed += potAmount;

              String winnerName = sessionManager.getPlayerNameWithPosition(winnerId);
              potLogs.add("🏆 $potName: $winnerName wins ${_formatCurrency(potAmount)}");
            }
          }

          // Reset the pot after distributing all pots
          gameState.currentPot = 0.0;

          // Add action logs for all pots
          for (String log in potLogs) {
          }

          // Complete hand in session manager
          final ourSeat = sessionManager.ourSeatNumber;
          final currentStack = ourSeat != null ? gameState.players[ourSeat - 1].currentStack : null;

          // For multi-pot, complete with the primary winner (first pot's winner)
          final firstPotResult = potResults[0]!;
          if (firstPotResult['isChoppedPot'] == true) {
            final winners = List<int>.from(firstPotResult['winners']);
            final individualShares = Map<int, double>.from(firstPotResult['individualShares']);
            sessionManager.completeCurrentHandWithChop(
              potAmount: totalDistributed,
              winnerIds: winners,
              individualShares: individualShares,
              currentStack: currentStack,
              gameState: gameState,
            );
          } else {
            sessionManager.completeCurrentHand(
              potAmount: totalDistributed,
              winnerId: firstPotResult['winner'] as int,
              currentStack: currentStack,
              gameState: gameState,
            );
          }
        });

        // Check for busted players and start next hand
        await _checkForBustedPlayers();
        _advanceToNextHand();
      });
    } else {
      // Handle single-pot scenario (existing logic)
      final isChoppedPot = winnerResult['isChoppedPot'] as bool? ?? false;
      LoggerService.debug('  isChoppedPot: $isChoppedPot');

      // Mark hand as completed and use the standard finalization flow
      _allInHandCompleted = true;
      setState(() {});
      // addAction removed

      if (isChoppedPot) {
        // Handle chopped pot
        final winnerIds = List<int>.from(winnerResult['winnerIds'] ?? []);
        final potAmount = winnerResult['potAmount'] as double? ?? gameState.currentPot;
        final individualShares = winnerResult['individualShares'] as Map<int, double>?;
        final sharePerWinner = winnerResult['sharePerWinner'] as double?;

        // addAction removed
      } else {
        // Handle single winner
        final winnerId = winnerResult['winnerId'] as int? ?? winnerResult['winner'] as int?;
        final potAmount = winnerResult['potAmount'] as double? ?? gameState.currentPot;

        if (winnerId != null) {
          final winnerName = sessionManager.getPlayerNameWithPosition(winnerId);
          // addAction removed
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
            gameState: gameState,
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
              gameState: gameState,
            );

            // Update winner's stack in game state to prevent them being marked as busted
            final winnerPlayer = gameState.players[winnerId - 1];
            winnerPlayer.currentStack += potAmount;
          }
        }

        // Check for busted players and start next hand
        await _checkForBustedPlayers();
        _advanceToNextHand();
      });
    }
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
    } else {
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
        // Street advance confirmed — clear rollback snapshot
        gameState.clearStreetSnapshot();

        // Save board cards to current hand
        sessionManager.currentHand?.setBoardCards(result);

        // Add board cards info to actions
        _addBoardCardsAction(result, round);

        // Notify guided hand overlay about board cards
        _guidedOverlayKey.currentState?.onBoardCardsDealt(round);
      } else {
        // Cancel pressed — roll back the street advance so user can undo actions
        setState(() {
          _rollbackStreetAdvance(round);
        });
      }
    });
  }

  void _addBoardCardsAction(BoardCards cards, BettingRound round) {
    switch (round) {
      case BettingRound.flop:
        if (cards.flop.isNotEmpty) {
          // addAction removed
        }
        break;
      case BettingRound.turn:
        if (cards.turn != null) {
          // addAction removed
        }
        break;
      case BettingRound.river:
        if (cards.river != null) {
          // addAction removed
        }
        break;
      default:
        break;
    }
  }

  // Navigate to session details screen
  Future<void> _showSessionDetails() async {
    // Get current stack for our seat
    // Try multiple sources to find the correct seat number
    int? ourSeat = sessionManager.ourSeatNumber;

    // Fallback: if ourSeat is null but we have a seat number from widget, use that
    if (ourSeat == null && widget.initialSeat != null) {
      ourSeat = widget.initialSeat;
    }

    // Get current stack from game state if we have a valid seat
    double currentStack;
    if (ourSeat != null && ourSeat >= 1 && ourSeat <= gameState.players.length) {
      currentStack = gameState.players[ourSeat - 1].currentStack;
    } else if (widget.individualCurrentStack != null) {
      currentStack = widget.individualCurrentStack!;
    } else {
      // Last resort: use the starting stack
      currentStack = sessionManager.initialStartingStack ?? widget.startingStack ?? 0.0;
    }

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
          liveStackHistory: List<Map<String, dynamic>>.from(sessionManager.stackHistory),
          completedHands: List<HandRecord>.from(sessionManager.completedHands),
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
          final seatIndex = ourSeat - 1;
          setState(() {
            gameState.players[seatIndex].currentStack = updatedStack;
            sessionManager.totalBuyIn = updatedTotalBuyIn;
          });
        }
      }

      // Update blinds if they were changed
      if (result['smallBlind'] != null && result['bigBlind'] != null) {
        final newSmallBlind = result['smallBlind'] as int;
        final newBigBlind = result['bigBlind'] as int;

        setState(() {
          // Update sessionManager blinds
          sessionManager.smallBlind = newSmallBlind;
          sessionManager.bigBlind = newBigBlind;

          // Update gameState blinds
          gameState.smallBlind = newSmallBlind;
          gameState.bigBlind = newBigBlind;
          // BB Ante remains unchanged - it's set once at session start
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
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 45, sigmaY: 45),
            child: Container(
              constraints: BoxConstraints(maxWidth: 340),
              decoration: BoxDecoration(
                color: AppColors.glassyCardColor(),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.whiteBorder(),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Confirm Rebuy',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You currently have ${formatStackValue(currentStack)} remaining.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Proceeding with a rebuy will replace your current stack. Are you sure you want to continue?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 24),
                        // Actions
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.whiteBorder()),
                                ),
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
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
                                    colors: [AppColors.gradientGreenEnd, AppColors.gradientGreenStart],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Proceed',
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 45, sigmaY: 45),
              child: Container(
                constraints: BoxConstraints(maxWidth: 340),
                decoration: BoxDecoration(
                  color: AppColors.glassyCardColor(),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.whiteBorder(),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: EdgeInsets.all(24),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.accentGreen.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.add_circle_outline,
                              color: AppColors.accentGreen,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Rebuy',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Content
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enter rebuy details for the tournament',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 20),

                          // Rebuy Amount Input
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.whiteBorder()),
                            ),
                            child: TextField(
                              controller: rebuyAmountController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(color: Colors.white, fontSize: 16),
                              decoration: InputDecoration(
                                labelText: 'Rebuy Amount',
                                labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                prefixText: '\$ ',
                                prefixStyle: TextStyle(color: Colors.white, fontSize: 16),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),

                          SizedBox(height: 16),

                          // Stack Size Input
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.whiteBorder()),
                            ),
                            child: TextField(
                              controller: stackSizeController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(color: Colors.white, fontSize: 16),
                              decoration: InputDecoration(
                                labelText: 'New Stack Size',
                                labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                hintText: 'Chip count after rebuy',
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),

                          SizedBox(height: 20),

                          // Current session info
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.whiteBorder()),
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
                                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                                ),
                                Text(
                                  'Rebuys: ${sessionManager.getRebuyCount()}',
                                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 24),

                          // Actions
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.whiteBorder()),
                                  ),
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
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
                                      colors: [AppColors.gradientGreenEnd, AppColors.gradientGreenStart],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ElevatedButton(
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
                                            backgroundColor: AppColors.gradientGreenEnd,
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
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      'Add Rebuy',
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _proceedToNextStreet() {
    setState(() {
      gameState.snapshotBeforeStreetAdvance();
      String streetTransitionResult = gameState.startNewStreet();

      // Show uncalled bet returns if any
      if (streetTransitionResult.isNotEmpty) {
        for (String line in streetTransitionResult.split('\n')) {
          if (line.trim().isNotEmpty) {
            // addAction removed
          }
        }
      }

      // addAction removed
      // addAction removed
    });
  }

  /// Roll back a street advance when user cancels the board card dialog.
  /// Restores full game state (pot, bets, player state) from snapshot.
  void _rollbackStreetAdvance(BettingRound dialogRound) {
    if (!gameState.restoreFromStreetSnapshot()) {
      // Fallback if no snapshot (shouldn't happen)
      switch (dialogRound) {
        case BettingRound.flop:
          gameState.currentRound = BettingRound.preflop;
        case BettingRound.turn:
          gameState.currentRound = BettingRound.flop;
        case BettingRound.river:
          gameState.currentRound = BettingRound.turn;
        case BettingRound.preflop:
          break;
      }
    }
    // Always clear bettingRoundComplete so undo button is available.
    gameState.bettingRoundComplete = false;
  }

  void endStreetManually() {
    setState(() {
      gameState.bettingRoundComplete = true;
      // addAction removed
      if (gameState.currentRound != BettingRound.river) {
        // addAction removed
      }
    });
  }

  /// Check if any meaningful actions have been logged (excluding blind posts)
  /// Returns true if there are any actions with PlayerAction != none
  /// Check if undo is allowed
  /// Returns true if there are actions that can be undone on the current street
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

    // Find the last non-blind action ON THE CURRENT STREET
    final actions = sessionManager.currentHand!.actions;
    final currentStreet = gameState.currentRound;

    for (int i = actions.length - 1; i >= 0; i--) {
      final action = actions[i];
      // Only allow undo for actions on current street (except blind posts)
      if (action.action != PlayerAction.none && action.street == currentStreet) {
        return true;
      }
    }

    return false;
  }

  /// Undo the last action and restore game state
  void _undoLastAction() {
    if (!_canUndoLastAction()) {
      // addAction removed
      _triggerInvalidActionVibration();
      return;
    }

    final actions = sessionManager.currentHand!.actions;
    final currentStreet = gameState.currentRound;

    // Find the last non-blind action ON CURRENT STREET
    int lastActionIndex = -1;
    for (int i = actions.length - 1; i >= 0; i--) {
      final action = actions[i];
      if (action.action != PlayerAction.none && action.street == currentStreet) {
        lastActionIndex = i;
        break;
      }
    }

    if (lastActionIndex == -1) {
      // addAction removed
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
          // Call amounts are recorded as ADDITIONAL (getCurrentBet - betThisRound),
          // NOT as total bet. So the amount IS what was added to pot — use it directly.

          player.currentStack += amount;
          player.isAllIn = false;

          // Restore betThisRound by subtracting the call amount
          player.betThisRound -= amount;
          if (player.betThisRound < 0) player.betThisRound = 0;

          gameState.currentPot -= amount;
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
      // addAction removed
      // addAction removed
    });

    // Notify guided hand overlay so it can roll back its state
    _guidedOverlayKey.currentState?.onActionUndone();
  }

  /// Get the amount a player had bet BEFORE a specific action index.
  /// This looks at all previous actions in the same street by the same player,
  /// and accounts for blind posts on preflop (which aren't in the action list).
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

    // On preflop, if no prior voluntary action was found, the player may have
    // posted a blind which isn't recorded in the action list.
    if (totalBet == 0.0 && undoingStreet == BettingRound.preflop) {
      if (playerId == gameState.effectiveSBPosition) {
        totalBet = gameState.smallBlind.toDouble();
      } else if (playerId == gameState.effectiveBBPosition) {
        totalBet = gameState.bigBlind.toDouble();
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

  /// Recalculate currentBet based on remaining bets/raises (current street only)
  void _recalculateCurrentBet(int upToIndex) {
    final actions = sessionManager.currentHand!.actions;
    final currentStreet = gameState.currentRound.name;  // 'preflop', 'flop', 'turn', 'river'
    double maxBet = 0;

    for (int i = 0; i < upToIndex; i++) {
      final action = actions[i];
      // Only consider actions from the current street
      if (action.street != currentStreet) continue;
      if (action.action == PlayerAction.bet || action.action == PlayerAction.raise) {
        if (action.amount != null && action.amount! > maxBet) {
          maxBet = action.amount!;
        }
      }
    }

    gameState.currentBet = maxBet;
  }

  /// Recalculate hasBetThisRound based on remaining actions (current street only)
  void _recalculateHasBetThisRound(int upToIndex) {
    final actions = sessionManager.currentHand!.actions;
    final currentStreet = gameState.currentRound.name;  // 'preflop', 'flop', 'turn', 'river'
    bool hasBet = false;

    for (int i = 0; i < upToIndex; i++) {
      final action = actions[i];
      // Only consider actions from the current street
      if (action.street != currentStreet) continue;
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

  void _checkForAutomaticHandEnd() {
    // Check if everyone has folded to BB preflop
    if (gameState.currentRound == BettingRound.preflop) {
      List<int> activePlayers = _getActivePlayers();
      if (activePlayers.length == 1) {
        // Only one player left - automatically end the hand
        _schedulePostFrameAction(() {
          // addAction removed
          _completeHandAutomatically();
        });
      }
    }
  }

  void _completeHandAutomatically() async {
    await LoggerService.info('🤖 _completeHandAutomatically() called - Auto-completing hand');

    // Notify guided hand overlay
    _guidedOverlayKey.currentState?.onHandComplete();

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

      // addAction removed

      // Show hole cards dialog BEFORE completing the hand — skip only if hero
      // folded preflop WITHOUT voluntarily entering the pot (no call/bet/raise)
      final heroSeat = sessionManager.ourSeatNumber ?? 1;
      final heroFolded = gameState.players[heroSeat - 1].hasFolded;
      final isPreflopOnly = gameState.currentRound == BettingRound.preflop;
      bool heroVoluntarilyEntered = false;
      if (heroFolded && isPreflopOnly) {
        final actions = sessionManager.currentHand?.actions ?? [];
        for (final a in actions) {
          if (a.player == heroSeat &&
              (a.action == PlayerAction.call ||
               a.action == PlayerAction.bet ||
               a.action == PlayerAction.raise)) {
            heroVoluntarilyEntered = true;
            break;
          }
        }
      }
      if (!heroFolded || !isPreflopOnly || heroVoluntarilyEntered) {
        await _showHoleCardsDialog();
      }

      // Notify guided overlay after all dialogs are done (no opponent dialog in this path)
      _guidedOverlayKey.currentState?.onHoleCardsCompleted();

      // Now complete hand in session manager (hole cards are already saved to currentHand)
      final currentStack = gameState.getPlayerStack(heroSeat);
      sessionManager.completeCurrentHand(
        potAmount: potAmount,
        winnerId: winnerId,
        currentStack: currentStack,
        gameState: gameState,
      );

      // For individual sessions, return to the session tracking screen
      if (widget.isIndividualSession) {
        final ourSeat = sessionManager.ourSeatNumber;
        final finalStack = ourSeat != null ? gameState.players[ourSeat - 1].currentStack : widget.individualCurrentStack ?? 0.0;

        Navigator.pop(context, {
          'completed': true,
          'finalStack': finalStack,
          'startingStack': _userStartingStack ?? finalStack,
          'potSize': potAmount,
          'smallBlind': sessionManager.smallBlind,
          'bigBlind': sessionManager.bigBlind,
          'hasBBante': gameState.hasBBante,
        });
        return;
      }

      // During onboarding, don't start the next hand — wait for user to end session
      if (OnboardingState.isGuidedHandActive) {
        setState(() {});
        return;
      }

      // For full sessions, start next hand
      await _checkForBustedPlayers();
      _advanceToNextHand();
    } else {
      // Multiple players remain, show winner selection dialog
      await LoggerService.info('  ↪️ Multiple players path - calling _showWinnerSelectionAndComplete()');
      _showWinnerSelectionAndComplete();
    }
  }

  /// Advance to the next hand. Shows a brief settling overlay (1.5s) with
  /// winner info, then starts the next hand. Checks free-tier limits first.
  ///
  /// Returns true if a new hand was started, false if blocked by the gate.
  bool _advanceToNextHand() {
    if (_freeTierLocked ||
        !FreeTierLimits.canLogAnotherHand(
          sessionManager.completedHands.length,
        )) {
      setState(() {
        _allInHandCompleted = false;
        _freeTierLocked = true;
      });
      _showFreeTierGate();
      return false;
    }

    // Capture settling info from last completed hand
    final lastHand = sessionManager.completedHands.isNotEmpty
        ? sessionManager.completedHands.last
        : null;
    final winnerName = lastHand?.winnerId != null
        ? sessionManager.getPlayerName(lastHand!.winnerId!)
        : null;
    final potAmount = lastHand?.potAmount;

    // Show settling overlay
    setState(() {
      _allInHandCompleted = false;
      _isSettlingBetweenHands = true;
      _settlingWinnerName = winnerName;
      _settlingPotAmount = potAmount;
    });

    // After 1.5s, dismiss settling and start next hand (unless already dismissed)
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted || !_isSettlingBetweenHands) return;
      _skipSettling();
    });
    return true;
  }

  /// Skip settling state immediately (user tapped to dismiss).
  void _skipSettling() {
    if (!_isSettlingBetweenHands) return;
    setState(() {
      _isSettlingBetweenHands = false;
      _settlingWinnerName = null;
      _settlingPotAmount = null;
      gameState.startNewHand();
      gameState.initializePot();
      sessionManager.startHand(
        gameState.handNumber,
        gameState.buttonPosition,
        sbSeat: gameState.effectiveSBPosition,
        bbSeat: gameState.effectiveBBPosition,
      );
    });
  }

  /// Shows the free-tier gate dialog. On dismiss ("End session") the
  /// session is saved and the user is routed home. On "Upgrade" the
  /// paywall opens; if the user comes back without becoming premium,
  /// the gate stays active so they cannot keep logging.
  Future<void> _showFreeTierGate() async {
    final upgradeTapped = await FreeTierLimits.showHandsLimitDialog(
      context,
      dismissLabel: 'End session',
    );
    if (!mounted) return;
    if (upgradeTapped == true) {
      // Paywall was shown and closed. If the user is now premium,
      // unlock the gate; otherwise re-show the gate dialog.
      if (SubscriptionService.isPremium) {
        setState(() => _freeTierLocked = false);
      } else {
        _showFreeTierGate();
      }
      return;
    }
    _endSessionFromGate();
  }

  /// Saves and closes the session when the free-tier hand gate is hit.
  /// Mirrors the "save" branch of [_handleNavigationAttempt].
  Future<void> _endSessionFromGate() async {
    try {
      final ourSeat = sessionManager.ourSeatNumber;
      if (ourSeat != null &&
          ourSeat >= 1 &&
          ourSeat <= gameState.players.length) {
        final finalStack = gameState.players[ourSeat - 1].currentStack;
        sessionManager.addFinalStackEntry(finalStack);
      }
      await sessionManager.endSession();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save session: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCardSelectionForNextHand() async {
    // addAction removed

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
        'startingStack': _userStartingStack ?? finalStack,
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
    _advanceToNextHand();
  }

  /// Internal function to show winner selection dialog and complete the hand.
  /// Only called by game logic (showdown, auto-completion), not by user action.
  void _showWinnerSelectionAndComplete() async {
    await LoggerService.info('═══ _showWinnerSelectionAndComplete() called ═══');

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

    // Check if we need side pot calculation
    // Log each player's state for debugging
    await LoggerService.debug('  Player states before side pot calculation:');
    for (var player in gameState.players) {
      if (player.isActive && !player.hasFolded) {
        final totalContrib = player.totalContribution + player.betThisRound;
        await LoggerService.debug('    P${player.playerId}: active=${player.isActive}, folded=${player.hasFolded}, '
            'totalContrib=${player.totalContribution}, betThisRound=${player.betThisRound}, '
            'total=${totalContrib}, stack=${player.currentStack}');
      }
    }

    List<SidePot> sidePots = SidePotCalculator.calculateSidePots(gameState.players);
    await LoggerService.debug('  Side pots calculated: ${sidePots.length} pots');
    for (var pot in sidePots) {
      await LoggerService.debug('    ${pot.toString()}');
    }

    Map<String, dynamic>? winnerResult;

    // Loop to allow going back from hole cards to winner selection
    while (true) {
      // Show multi-pot dialog if there are 2+ pots (main + side), otherwise show regular dialog
      if (sidePots.length >= 2) {
        await LoggerService.info('  Showing multi-pot winner dialog with ${sidePots.length} pots');

        // Create player ID to name map
        Map<int, String> playerIdToName = {};
        for (int playerId in activePlayers) {
          playerIdToName[playerId] = sessionManager.getPlayerNameWithPosition(playerId);
        }

        winnerResult = await MultiPotWinnerDialog.show(
          context: context,
          sidePots: sidePots,
          playerNames: playerNames,
          playerIdToName: playerIdToName,
          gameType: widget.gameType,
          buttonPosition: gameState.buttonPosition,
          playerCount: gameState.numberOfPlayers,
        );
      } else {
        await LoggerService.debug('  Showing regular winner selection dialog (${sidePots.length} pot)');
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
      }

      // User can cancel the dialog if they want to continue the hand
      if (winnerResult == null) {
        // addAction removed
        return;
      }

      // Show hole cards dialog — if user goes back, re-show winner selection
      final goBackToWinner = await _showHoleCardsDialog();
      if (goBackToWinner) continue;
      break; // Proceed to opponent cards + completion
    }

    // Check if this is a multi-pot scenario
    final bool isMultiPot = winnerResult!.containsKey('potResults');

    if (isMultiPot) {
      await LoggerService.info('  Processing multi-pot winner result');

      final Map<int, Map<String, dynamic>> potResults =
          Map<int, Map<String, dynamic>>.from(winnerResult['potResults']);
      final List<SidePot> resultSidePots =
          List<SidePot>.from(winnerResult['sidePots']);

      // Collect all unique winners across all pots for showdown dialogs
      Set<int> allWinners = {};
      for (var potResult in potResults.values) {
        if (potResult['isChoppedPot'] == true) {
          allWinners.addAll(List<int>.from(potResult['winners']));
        } else {
          allWinners.add(potResult['winner'] as int);
        }
      }

      // Notify guided hand overlay that hand is complete
      _guidedOverlayKey.currentState?.onHandComplete();

      await LoggerService.info('About to call _showOpponentCardsDialog with activePlayers=$activePlayers');

      // Show opponent hole cards dialog for showdown situations
      await _showOpponentCardsDialog(activePlayers, allWinners.toList());

      // Notify guided overlay after ALL dialogs are done
      _guidedOverlayKey.currentState?.onHoleCardsCompleted();

      setState(() {
        // Distribute each pot to its winner(s)
        List<String> potLogs = [];
        double totalDistributed = 0.0;

        for (int potIndex = 0; potIndex < resultSidePots.length; potIndex++) {
          final potResult = potResults[potIndex]!;
          final sidePot = resultSidePots[potIndex];
          final potName = potIndex == 0 ? 'Main Pot' : 'Side Pot $potIndex';

          if (potResult['isChoppedPot'] == true) {
            final winners = List<int>.from(potResult['winners']);
            final individualShares = Map<int, double>.from(potResult['individualShares']);

            for (int winnerId in winners) {
              final winnerShare = individualShares[winnerId]!;
              _distributePotToWinner(winnerId, winnerShare);
              totalDistributed += winnerShare;
            }

            List<String> winnerDetails = winners.map((id) {
              final name = sessionManager.getPlayerNameWithPosition(id);
              final amount = individualShares[id]!;
              return '$name (${_formatCurrency(amount)})';
            }).toList();
            potLogs.add("🏆 $potName chopped: ${winnerDetails.join(', ')}");
          } else {
            final winnerId = potResult['winner'] as int;
            final potAmount = potResult['potAmount'] as double;
            _distributePotToWinner(winnerId, potAmount);
            totalDistributed += potAmount;

            String winnerName = sessionManager.getPlayerNameWithPosition(winnerId);
            potLogs.add("🏆 $potName: $winnerName wins ${_formatCurrency(potAmount)}");
          }
        }

        // Reset the pot after distributing all pots
        gameState.currentPot = 0.0;

        // Add action logs for all pots
        for (String log in potLogs) {
        }

        // Complete hand in session manager
        final ourSeat = sessionManager.ourSeatNumber;
        final currentStack = ourSeat != null ? gameState.players[ourSeat - 1].currentStack : null;

        // For multi-pot, complete with the primary winner (first pot's winner)
        final firstPotResult = potResults[0]!;
        if (firstPotResult['isChoppedPot'] == true) {
          final winners = List<int>.from(firstPotResult['winners']);
          final individualShares = Map<int, double>.from(firstPotResult['individualShares']);
          sessionManager.completeCurrentHandWithChop(
            potAmount: totalDistributed,
            winnerIds: winners,
            individualShares: individualShares,
            currentStack: currentStack,
            gameState: gameState,
          );
        } else {
          sessionManager.completeCurrentHand(
            potAmount: totalDistributed,
            winnerId: firstPotResult['winner'] as int,
            currentStack: currentStack,
            gameState: gameState,
          );
        }
      });
    } else {
      // Regular single-pot scenario
      final bool isChoppedPot = winnerResult['isChoppedPot'] ?? false;
      final List<int> winners = isChoppedPot
          ? List<int>.from(winnerResult['winners'] ?? [])
          : [winnerResult['winner'] as int];
      final Map<int, double> individualShares = isChoppedPot && winnerResult['individualShares'] != null
          ? Map<int, double>.from(winnerResult['individualShares'])
          : {};
      final double sharePerWinner = winnerResult['sharePerWinner'] ?? potAmount;

      await LoggerService.debug('  Winner selection result: isChoppedPot=$isChoppedPot, winners=$winners');

      // Notify guided hand overlay that hand is complete
      _guidedOverlayKey.currentState?.onHandComplete();

      await LoggerService.info('About to call _showOpponentCardsDialog with activePlayers=$activePlayers');

      // Show opponent hole cards dialog for showdown situations
      await _showOpponentCardsDialog(activePlayers, winners);

      // Notify guided overlay after ALL dialogs are done
      _guidedOverlayKey.currentState?.onHoleCardsCompleted();

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
          gameState: gameState,
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
        } else {
          String winnerNames = winners.map((id) =>
            sessionManager.getPlayerNameWithPosition(id)).join(', ');
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
          gameState: gameState,
        );

        // Distribute pot to single winner
        _distributePotToWinner(winners.first);

        // Add action log for single winner
        String winnerName = sessionManager.getPlayerNameWithPosition(winners.first);
      }
    });
    } // Close the else block for regular single-pot scenario

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
        'startingStack': _userStartingStack ?? finalStack,
        'potSize': potSize,
        'smallBlind': sessionManager.smallBlind,
        'bigBlind': sessionManager.bigBlind,
        'hasBBante': gameState.hasBBante,
      });
      return;
    }

    // During onboarding, don't start the next hand — wait for user to end session
    if (OnboardingState.isGuidedHandActive) {
      setState(() {});
      return;
    }

    // For full sessions, continue with normal flow
    // Check for busted players before starting new hand
    await _checkForBustedPlayers();
    _advanceToNextHand();
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
        // addAction removed
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
      // addAction removed
      return;
    }

    // addAction removed

    // The position adjustment happens automatically when the next hand starts
    // because getPositionName() calculates positions based on active players
    // But we log it here for clarity
    String nextBBSeat = _findNextBBAfterRemoval(removedPlayerId);
    if (nextBBSeat.isNotEmpty) {
      // addAction removed
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
      // addAction removed
    } else if (removedPlayerId == bbPosition) {
      // addAction removed
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
          // addAction removed
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

          // addAction removed

          // If this was SB or BB, note special blind situation
          _checkSpecialBlindSituation(playerId);
        }
      }
    }
  }

  /// Returns true if user wants to go back to winner selection.
  Future<bool> _showHoleCardsDialog({bool isForCompletedHand = true}) async {
    // Collect board cards as used cards
    Set<String> usedCards = {};
    BoardCards? boardCards;
    HoleCards? existingHoleCards;
    bool existingIsStarred = false;
    List<String> existingTags = [];
    String? existingNotes;

    // IMPORTANT: When called for a hand that's about to be completed, currentHand still exists
    // So we should use currentHand (not completedHands.last) to avoid showing previous hand's cards
    if (sessionManager.currentHand != null) {
      // Use the current hand being played/completed
      boardCards = sessionManager.currentHand?.boardCards;
      existingHoleCards = sessionManager.currentHand?.ourHoleCards;
      existingIsStarred = sessionManager.currentHand?.isStarred ?? false;
      existingTags = sessionManager.currentHand?.tags ?? [];
      existingNotes = sessionManager.currentHand?.notes;
    } else if (sessionManager.completedHands.isNotEmpty) {
      // Fallback to last completed hand (for editing after hand is fully complete)
      boardCards = sessionManager.completedHands.last.boardCards;
      existingHoleCards = sessionManager.completedHands.last.ourHoleCards;
      existingIsStarred = sessionManager.completedHands.last.isStarred;
      existingTags = sessionManager.completedHands.last.tags;
      existingNotes = sessionManager.completedHands.last.notes;
    }

    if (boardCards != null) {
      if (boardCards.flop.isNotEmpty) usedCards.addAll(boardCards.flop);
      if (boardCards.turn != null && boardCards.turn!.isNotEmpty) usedCards.add(boardCards.turn!);
      if (boardCards.river != null && boardCards.river!.isNotEmpty) usedCards.add(boardCards.river!);
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => HandReviewDialog(
        existingCards: existingHoleCards,
        usedCards: usedCards,
        existingIsStarred: existingIsStarred,
        existingTags: existingTags,
        existingNotes: existingNotes,
      ),
    );

    // User wants to go back to winner selection
    if (result != null && result['goBack'] == true) {
      return true;
    }

    if (result != null) {
      // Save data to the current hand (or last completed if current doesn't exist)
      if (sessionManager.currentHand != null) {
        // Apply hole cards
        if (result['holeCards'] != null) {
          sessionManager.currentHand!.ourHoleCards = result['holeCards'];
        }
        // Apply annotations
        sessionManager.currentHand!.isStarred = result['isStarred'] ?? false;
        sessionManager.currentHand!.tags = List<String>.from(result['tags'] ?? []);
        sessionManager.currentHand!.notes = result['notes'];
      } else if (sessionManager.completedHands.isNotEmpty) {
        if (result['holeCards'] != null) {
          sessionManager.completedHands.last.ourHoleCards = result['holeCards'];
        }
        sessionManager.completedHands.last.isStarred = result['isStarred'] ?? false;
        sessionManager.completedHands.last.tags = List<String>.from(result['tags'] ?? []);
        sessionManager.completedHands.last.notes = result['notes'];
      }

      // Log actions
      final holeCards = result['holeCards'] as HoleCards?;
      if (holeCards != null && holeCards.isComplete) {
        // addAction removed
      }
      if (result['isStarred'] == true) {
        // addAction removed
      }
      final tags = result['tags'] as List<String>?;
      if (tags != null && tags.isNotEmpty) {
        // addAction removed
      }
    }

    return false;
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

    // Reorder opponents: winners first, then others
    // This ensures winner's cards are collected first (they must show)
    List<int> reorderedOpponents = [];
    List<int> nonWinners = [];

    for (int opponentId in opponents) {
      if (winners.contains(opponentId)) {
        reorderedOpponents.add(opponentId);
      } else {
        nonWinners.add(opponentId);
      }
    }
    reorderedOpponents.addAll(nonWinners);

    await LoggerService.info('✅ Showing opponent cards dialog for ${reorderedOpponents.length} opponent(s)');
    await LoggerService.debug('  Reordered (winners first): $reorderedOpponents');

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

    for (int i = 0; i < reorderedOpponents.length; i++) {
      final opponentId = reorderedOpponents[i];
      final opponentName = sessionManager.getPlayerNameWithPosition(opponentId);
      final isWinner = winners.contains(opponentId);
      final remainingAfterThis = reorderedOpponents.length - i - 1;

      // Show dialog for this opponent
      final cards = await showDialog<HoleCards>(
        context: context,
        barrierDismissible: true,
        builder: (context) => HoleCardsDialog(
          playerName: opponentName,
          isWinner: isWinner,
          usedCards: usedCards,
          existingCards: existingCards?[opponentId],
          showSkipAll: remainingAfterThis > 0,
        ),
      );

      // If user cancelled/skipped, continue to next opponent (don't break entire loop)
      if (cards == null) {
        await LoggerService.debug('  Skipped opponent $opponentId ($opponentName) - continuing to next opponent');
        continue;
      }

      // If user chose "Skip All", break out of the loop entirely
      if (cards.card1 == 'SKIP_ALL') {
        await LoggerService.debug('  Skip All selected at opponent $opponentId - skipping remaining opponents');
        break;
      }

      // If cards were selected, add them to the collection and update usedCards
      if (cards.isComplete) {
        opponentCards[opponentId] = cards;
        usedCards.add(cards.card1!);
        usedCards.add(cards.card2!);
        await LoggerService.debug('  Collected cards for opponent $opponentId: ${cards.card1} ${cards.card2}');
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
            // addAction removed
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
    _showWinnerSelectionAndComplete();
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
        // addAction removed
        if (showdownData.handDescription != null) {
          // addAction removed
        }
        
        // Distribute pot to winner
        _distributePotToWinner(showdownData.winner!);
      }
      
      // Show opponent cards
      for (int player in activePlayers) {
        final playerCards = showdownData.playerCards[player];
        if (playerCards != null && playerCards.isComplete) {
          // addAction removed
        }
      }
    }
    
    _finalizeHand();
  }

  void _finalizeHand() async {
    // addAction removed

    // Notify guided hand overlay that hand is complete
    _guidedOverlayKey.currentState?.onHandComplete();

    // Show hole cards dialog for the completed hand
    await _showHoleCardsDialog();

    // Notify guided overlay after all dialogs are done (no opponent dialog in this path)
    _guidedOverlayKey.currentState?.onHoleCardsCompleted();

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
        'startingStack': _userStartingStack ?? finalStack,
        'potSize': potSize,
        'smallBlind': sessionManager.smallBlind,
        'bigBlind': sessionManager.bigBlind,
        'hasBBante': gameState.hasBBante,
      });
      return;
    }

    // During onboarding, don't start the next hand — wait for user to end session
    if (OnboardingState.isGuidedHandActive) {
      setState(() {});
      return;
    }

    // For full sessions, continue with normal flow
    // Check for busted players before starting new hand
    await _checkForBustedPlayers();
    _advanceToNextHand();
  }

  void _triggerInvalidActionVibration() {
    Vibration.vibrate(duration: 200);
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

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 309,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF101115),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1B1E24)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              blurRadius: 114,
              offset: Offset(20, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warning icon
            SvgPicture.asset(
              'icons/figma_icons/warning.svg',
              width: 24,
              height: 24,
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.playerName} is busted!',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w500,
                height: 1.44,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose an option:',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSans(
                color: const Color(0xFF8C8C8C),
                fontSize: 15,
                height: 1.44,
              ),
            ),
            const SizedBox(height: 32),
            // Rebuy Chips input with floating label
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF4E5054)),
              ),
              child: TextField(
                controller: _amountController,
                keyboardType: TextInputType.numberWithOptions(decimal: widget.isCashGame),
                style: GoogleFonts.ibmPlexSans(
                  color: const Color(0xFF8C8C8C),
                  fontSize: 17,
                  height: 1.44,
                ),
                decoration: InputDecoration(
                  labelText: widget.isCashGame ? 'Rebuy Amount (\$)' : 'Rebuy Chips',
                  labelStyle: GoogleFonts.ibmPlexSans(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Rebuy and Leave buttons
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      double amount = double.tryParse(_amountController.text) ?? 100.0;
                      Navigator.pop(context, {
                        'action': 'rebuy',
                        'amount': amount,
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(110),
                        border: Border.all(color: Colors.white),
                      ),
                      child: Center(
                        child: Text(
                          'Rebuy',
                          style: GoogleFonts.ibmPlexSans(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                            height: 24 / 17,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context, {
                        'action': 'leave',
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD55A41),
                        borderRadius: BorderRadius.circular(110),
                      ),
                      child: Center(
                        child: Text(
                          'Leave',
                          style: GoogleFonts.ibmPlexSans(
                            color: Colors.black,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                            height: 24 / 17,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Confirm button
            GestureDetector(
              onTap: () {
                double amount = double.tryParse(_amountController.text) ?? 100.0;
                Navigator.pop(context, {
                  'action': 'rebuy',
                  'amount': amount,
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF89F1EC),
                  borderRadius: BorderRadius.circular(110),
                ),
                child: Center(
                  child: Text(
                    'Confirm',
                    style: GoogleFonts.ibmPlexSans(
                      color: Colors.black,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                      height: 24 / 17,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

