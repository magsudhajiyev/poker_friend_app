import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/poker_positions.dart';
import '../services/free_tier_limits.dart';
import '../services/opponent_service.dart';
import '../services/auth_service.dart';
import '../models/opponent.dart';
import '../models/game_types.dart';
import '../onboarding/onboarding_state.dart';
import '../onboarding/onboarding_tour.dart';
import '../onboarding/onboarding_progress_bar.dart';

class QuickStackUpdateScreen extends StatefulWidget {
  final int smallBlind;
  final int bigBlind;
  final int numberOfPlayers;
  final GameType gameType;
  final Map<int, String>? playerNames;
  final Map<int, double>? currentStacks; // Pre-populate from last hand
  final int? currentButtonPosition; // Remember last button position
  final double? userCurrentStack; // User's current stack (to auto-apply)
  final String? userName; // User's name (to detect when they seat themselves)

  const QuickStackUpdateScreen({
    super.key,
    required this.smallBlind,
    required this.bigBlind,
    required this.numberOfPlayers,
    required this.gameType,
    this.playerNames,
    this.currentStacks,
    this.currentButtonPosition,
    this.userCurrentStack,
    this.userName,
  });

  @override
  State<QuickStackUpdateScreen> createState() => _QuickStackUpdateScreenState();
}

class _QuickStackUpdateScreenState extends State<QuickStackUpdateScreen> {
  late Map<int, double> playerStacksInBB;
  late int buttonPlayerId;
  Map<int, String> customPlayerNames = {}; // Player ID → Custom name
  Map<int, bool> seatIsOpen = {}; // Player ID → true if seat is open/empty
  List<Opponent> opponents = []; // Available opponents
  bool _loadingOpponents = true;

  static const _cardColor = Color(0xFF131616);
  static const _mint = Color(0xFF89F1EC);

  // Onboarding GlobalKeys
  final GlobalKey _seatToggleKey = GlobalKey(debugLabel: 'seatToggle1');
  final GlobalKey _buttonIndicatorKey = GlobalKey(debugLabel: 'buttonIndicator1');
  final GlobalKey _playerNameAreaKey = GlobalKey(debugLabel: 'playerNameArea1');
  final GlobalKey _stackSliderKey = GlobalKey(debugLabel: 'stackSlider2');

  @override
  void initState() {
    super.initState();

    // Initialize button position (default to player 1 or use last position)
    buttonPlayerId = widget.currentButtonPosition ?? 1;

    // Load opponents
    _loadOpponents();

    // Initialize customPlayerNames with pre-filled names from previous hand
    // This ensures the duplicate-checking logic works correctly across hands
    if (widget.playerNames != null) {
      customPlayerNames = Map<int, String>.from(widget.playerNames!);
    }

    // Initialize player stacks in BB and seat status
    playerStacksInBB = {};
    seatIsOpen = {};
    for (int i = 1; i <= widget.numberOfPlayers; i++) {
      if (widget.currentStacks != null && widget.currentStacks!.containsKey(i)) {
        // Convert existing chip stack to BB
        playerStacksInBB[i] = widget.currentStacks![i]! / widget.bigBlind;
        // Seat is open if stack is 0
        seatIsOpen[i] = widget.currentStacks![i]! == 0;
      } else {
        // Default to 100 BB
        playerStacksInBB[i] = 100.0;
        // Default to seat closed (player present)
        seatIsOpen[i] = false;
      }
    }

    // CRITICAL: If user's name is already present in a seat (from previous hand),
    // automatically apply their current stack to that seat
    if (widget.userName != null && widget.userCurrentStack != null) {
      // Find which seat has the user's name
      int? userSeat;
      for (var entry in customPlayerNames.entries) {
        if (entry.value == widget.userName) {
          userSeat = entry.key;
          break;
        }
      }

      // Apply user's current stack to their seat
      if (userSeat != null) {
        playerStacksInBB[userSeat] = widget.userCurrentStack! / widget.bigBlind;
      }
    }

    _scheduleQuickStackUpdateTour();
  }

  void _scheduleQuickStackUpdateTour() {
    if (!OnboardingState.isOnboardingActive ||
        OnboardingState.currentPhase != 3 ||
        !OnboardingState.quickStackUpdateTourPending) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      QuickStackUpdateTour(
        seatToggleKey: _seatToggleKey,
        buttonIndicatorKey: _buttonIndicatorKey,
        playerNameAreaKey: _playerNameAreaKey,
        stackSliderKey: _stackSliderKey,
      ).show(context);
    });
  }

  Future<void> _loadOpponents() async {
    try {
      final loadedOpponents = await OpponentService.getAllOpponents();
      setState(() {
        opponents = loadedOpponents;
        _loadingOpponents = false;
      });
    } catch (e) {
      // print('Error loading opponents: $e');
      setState(() {
        _loadingOpponents = false;
      });
    }
  }

  void _setButtonPosition(int playerId) {
    setState(() {
      buttonPlayerId = playerId;
    });
  }

  void _toggleSeatOpen(int playerId) {
    setState(() {
      final wasOpen = seatIsOpen[playerId] ?? false;
      seatIsOpen[playerId] = !wasOpen;

      // CRITICAL: If this seat was the button and is now being marked as open,
      // move the button to the next available (non-open) seat
      if (!wasOpen && playerId == buttonPlayerId) {
        // Find next available seat clockwise
        int? nextAvailableSeat;
        for (int offset = 1; offset <= widget.numberOfPlayers; offset++) {
          final candidateSeat = ((playerId - 1 + offset) % widget.numberOfPlayers) + 1;
          if (!(seatIsOpen[candidateSeat] ?? false)) {
            nextAvailableSeat = candidateSeat;
            break;
          }
        }

        // Move button to next available seat (or keep on current if all seats are open)
        if (nextAvailableSeat != null) {
          buttonPlayerId = nextAvailableSeat;
        }
      }
    });
  }

  Future<void> _addNewOpponent(String name) async {
    // Free-tier gate: enforce the opponent profile cap.
    if (!FreeTierLimits.canCreateAnotherOpponent(opponents.length)) {
      await FreeTierLimits.showOpponentLimitDialog(context);
      return;
    }

    final now = DateTime.now();
    final opponent = Opponent(
      id: 'opp_${now.millisecondsSinceEpoch}',
      name: name.trim(),
      createdAt: now,
      lastSeenAt: now,
    );
    await OpponentService.saveOpponent(opponent);
    // Add to local list so it appears immediately
    setState(() {
      opponents.add(opponent);
    });
  }

  Future<void> _showOpponentSelectionDialog(int playerId) async {
    String searchQuery = '';

    // Get user's name
    String userName = 'You';
    try {
      final user = AuthService.currentUser;
      if (user != null && user.displayName?.isNotEmpty == true) {
        userName = user.displayName!;
      }
    } catch (e) {}

    final selected = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Filter opponents based on search query
          final filteredOpponents = searchQuery.isEmpty
              ? opponents
              : opponents.where((opponent) {
                  return opponent.name.toLowerCase().contains(searchQuery.toLowerCase());
                }).toList();

          // Check if user name matches search
          final showUserName = searchQuery.isEmpty ||
              userName.toLowerCase().contains(searchQuery.toLowerCase());

          // Check if search query exactly matches an existing opponent or user name
          final queryTrimmed = searchQuery.trim();
          final hasExactMatch = queryTrimmed.isEmpty ||
              userName.toLowerCase() == queryTrimmed.toLowerCase() ||
              opponents.any((o) => o.name.toLowerCase() == queryTrimmed.toLowerCase());

          return Dialog(
            backgroundColor: _cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row with clear option
                  Row(
                    children: [
                      Text(
                        'Select Player',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (customPlayerNames.containsKey(playerId))
                        GestureDetector(
                          onTap: () => Navigator.pop(context, '__CLEAR__'),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Clear',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 13,
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Search bar — plain TextField, no outer Container
                  TextField(
                    style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Search or add player...',
                      hintStyle: GoogleFonts.ibmPlexSans(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 15,
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 12, right: 8),
                        child: Icon(
                          Icons.search,
                          color: Colors.white.withValues(alpha: 0.35),
                          size: 20,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        searchQuery = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),

                  // Players list
                  Flexible(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        children: [
                          // "Add as new opponent" option when no exact match
                          if (!hasExactMatch) ...[
                            GestureDetector(
                              onTap: () async {
                                await _addNewOpponent(queryTrimmed);
                                if (context.mounted) {
                                  Navigator.pop(context, queryTrimmed);
                                }
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: _mint.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.person_add, color: _mint, size: 17),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Add "$queryTrimmed"',
                                            style: GoogleFonts.ibmPlexSans(
                                              fontSize: 14,
                                              color: _mint,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            'Save to opponent list',
                                            style: GoogleFonts.ibmPlexSans(
                                              fontSize: 12,
                                              color: Colors.white.withValues(alpha: 0.4),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              height: 1,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ],

                          // User's name at top
                          if (showUserName) ...[
                            GestureDetector(
                              onTap: () => Navigator.pop(context, userName),
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 17,
                                      backgroundColor: _mint,
                                      child: const Icon(Icons.person, color: Colors.black, size: 16),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            userName,
                                            style: GoogleFonts.ibmPlexSans(
                                              fontSize: 14,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            'You',
                                            style: GoogleFonts.ibmPlexSans(
                                              fontSize: 11,
                                              color: Colors.white.withValues(alpha: 0.4),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (filteredOpponents.isNotEmpty)
                              Container(
                                height: 1,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                          ],

                          // Opponents list
                          if (filteredOpponents.isEmpty && !showUserName && hasExactMatch)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'No players found.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.ibmPlexSans(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 14,
                                ),
                              ),
                            )
                          else
                            ...filteredOpponents.map((opponent) {
                              return GestureDetector(
                                onTap: () => Navigator.pop(context, opponent.name),
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 17,
                                        backgroundColor: _getOpponentColor(opponent.color),
                                        child: Text(
                                          opponent.name[0].toUpperCase(),
                                          style: GoogleFonts.ibmPlexSans(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        opponent.name,
                                        style: GoogleFonts.ibmPlexSans(
                                          fontSize: 14,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  // Cancel button
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (selected != null) {
      setState(() {
        if (selected == '__CLEAR__') {
          // Set to empty string to explicitly clear (overrides widget.playerNames)
          customPlayerNames[playerId] = '';
        } else {
          // First, remove this player name from any other seat if it exists
          // This ensures each player appears in only ONE position
          final existingSeatWithThisName = customPlayerNames.entries
              .firstWhere(
                (entry) => entry.value == selected && entry.key != playerId,
                orElse: () => MapEntry(-1, ''),
              )
              .key;

          if (existingSeatWithThisName != -1) {
            // Set to empty string to clear the previous seat (overrides widget.playerNames)
            customPlayerNames[existingSeatWithThisName] = '';
          }

          // Now assign the player to the new seat
          customPlayerNames[playerId] = selected;

          // CRITICAL: If user selected themselves, automatically set their stack
          if (widget.userName != null &&
              widget.userCurrentStack != null &&
              selected == widget.userName) {
            // Convert user's chip stack to BB (slider max will adjust dynamically)
            playerStacksInBB[playerId] = widget.userCurrentStack! / widget.bigBlind;
          }
        }
      });
    }
  }

  Color _getOpponentColor(OpponentColor color) {
    switch (color) {
      case OpponentColor.red:
        return Colors.red;
      case OpponentColor.blue:
        return Colors.blue;
      case OpponentColor.green:
        return Colors.green;
      case OpponentColor.orange:
        return Colors.orange;
      case OpponentColor.purple:
        return Colors.purple;
      case OpponentColor.teal:
        return Colors.teal;
      case OpponentColor.pink:
        return Colors.pink;
      case OpponentColor.indigo:
        return Colors.indigo;
    }
  }

  void _updateStack(int playerId, double bbValue) {
    setState(() {
      playerStacksInBB[playerId] = bbValue;
    });
  }

  double _getSliderMaxBB() {
    // Find the largest stack in BB
    double maxStack = 200.0; // Default minimum
    for (var stack in playerStacksInBB.values) {
      if (stack > maxStack) {
        maxStack = stack;
      }
    }
    // Round up to nearest 100 BB for cleaner slider range
    return ((maxStack / 100).ceil() * 100).toDouble();
  }

  Future<void> _showStackEditDialog(int playerId) async {
    final currentBB = _getBBValue(playerId);
    final currentChips = _getChipAmount(playerId);
    final controller = TextEditingController(text: currentBB.toInt().toString());

    final result = await showDialog<double>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Stack',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 17),
                  decoration: InputDecoration(
                    labelText: 'Stack in BB',
                    labelStyle: GoogleFonts.ibmPlexSans(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    suffixText: 'BB',
                    suffixStyle: GoogleFonts.ibmPlexSans(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.gameType == GameType.cash
                    ? 'Current: ${currentBB.toInt()} BB = \$${currentChips}'
                    : 'Current: ${currentBB.toInt()} BB = $currentChips',
                style: GoogleFonts.ibmPlexSans(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      final value = double.tryParse(controller.text);
                      if (value != null && value >= 0 && value <= 1000) {
                        Navigator.pop(context, value);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Please enter a value between 0 and 1000 BB'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: _mint,
                        borderRadius: BorderRadius.circular(60),
                      ),
                      child: Text(
                        'Save',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 15,
                          color: Colors.black,
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

    if (result != null) {
      _updateStack(playerId, result);
    }
  }

  String _getPlayerName(int playerId) {
    // First check custom names set by user
    if (customPlayerNames.containsKey(playerId)) {
      final name = customPlayerNames[playerId]!;
      // Empty string means explicitly cleared (overrides widget.playerNames)
      if (name.isEmpty) {
        return 'Player $playerId';
      }
      return name;
    }
    // Then check if passed from previous session
    if (widget.playerNames != null && widget.playerNames!.containsKey(playerId)) {
      return widget.playerNames![playerId]!;
    }
    // Default
    return 'Player $playerId';
  }

  String _getPositionLabel(int playerId) {
    // Get list of active (non-open) player IDs
    List<int> activePlayers = [];
    for (int i = 1; i <= widget.numberOfPlayers; i++) {
      if (!(seatIsOpen[i] ?? false)) {
        activePlayers.add(i);
      }
    }

    // Calculate position based on active players only
    return PokerPositions.getPositionNameForActivePlayers(
      playerId,
      buttonPlayerId,
      activePlayers,
    );
  }

  double _getBBValue(int playerId) {
    return playerStacksInBB[playerId] ?? 100.0;
  }

  int _getChipAmount(int playerId) {
    return (_getBBValue(playerId) * widget.bigBlind).round();
  }

  void _continue() {
    // Convert BB to chips, excluding open seats
    Map<int, double> playerStacks = {};
    for (var entry in playerStacksInBB.entries) {
      // Only include if seat is not open
      if (!(seatIsOpen[entry.key] ?? false)) {
        playerStacks[entry.key] = entry.value * widget.bigBlind;
      } else {
        // Set stack to 0 for open seats
        playerStacks[entry.key] = 0.0;
      }
    }

    // Build final player names map (merge custom names with defaults)
    Map<int, String> finalPlayerNames = {};
    for (int i = 1; i <= widget.numberOfPlayers; i++) {
      finalPlayerNames[i] = _getPlayerName(i);
    }

    // Filter out empty strings from customPlayerNames before returning
    // Empty strings mean "cleared/reset to default", so don't pass them
    Map<int, String> filteredPlayerNames = {};
    for (var entry in customPlayerNames.entries) {
      if (entry.value.isNotEmpty) {
        filteredPlayerNames[entry.key] = entry.value;
      }
    }

    Navigator.pop(context, {
      'playerStacks': playerStacks,
      'buttonPosition': buttonPlayerId,
      'playerNames': filteredPlayerNames, // Only return non-empty custom names
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Teal radial gradient at top
          Positioned(
            top: -MediaQuery.of(context).size.width * 0.5,
            right: -MediaQuery.of(context).size.width * 0.2,
            child: Container(
              width: MediaQuery.of(context).size.width * 1.2,
              height: MediaQuery.of(context).size.width * 1.2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1A4A4A).withValues(alpha: 0.6),
                    const Color(0xFF133538).withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const OnboardingProgressBar(),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Close button
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF3C3C43).withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Title + Blinds
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Update Stacks & Button',
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 20,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.gameType == GameType.cash
                                      ? 'Blinds: \$${widget.smallBlind}/\$${widget.bigBlind}'
                                      : 'Blinds: ${widget.smallBlind}/${widget.bigBlind}',
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Instruction text
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _mint.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _mint.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: _mint,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tap stack to edit  •  Slide to adjust  •  Tap D for button',
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Player list with sliders
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: widget.numberOfPlayers,
                    itemBuilder: (context, index) {
                      final playerId = index + 1;
                      return _buildPlayerRow(playerId);
                    },
                  ),
                ),

                // Continue button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: GestureDetector(
                    onTap: _continue,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _mint,
                        borderRadius: BorderRadius.circular(60),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.black,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'CONTINUE TO LOG HAND',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                              letterSpacing: 0.5,
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
        ],
      ),
    );
  }

  Widget _buildPlayerRow(int playerId) {
    final isButton = playerId == buttonPlayerId;
    final bbValue = _getBBValue(playerId);
    final chipAmount = _getChipAmount(playerId);
    final playerName = _getPlayerName(playerId);
    final positionLabel = _getPositionLabel(playerId);
    final isSeatOpen = seatIsOpen[playerId] ?? false;
    final isCashGame = widget.gameType == GameType.cash;

    // Compact open seat row
    if (isSeatOpen) {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Seat toggle
            GestureDetector(
              onTap: () => _toggleSeatOpen(playerId),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Seat $playerId',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.3),
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              'Empty',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.25),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: isButton
            ? Border.all(color: _mint.withValues(alpha: 0.35), width: 1.5)
            : null,
      ),
      child: Column(
        children: [
          // Top row: checkbox + D + position/name + stack
          Row(
            children: [
              // Seat toggle
              GestureDetector(
                onTap: () => _toggleSeatOpen(playerId),
                child: Container(
                  key: playerId == 1 ? _seatToggleKey : null,
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _mint,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: _mint, width: 1.5),
                  ),
                  child: const Icon(Icons.check, color: Colors.black, size: 14),
                ),
              ),
              const SizedBox(width: 6),

              // Button selector
              GestureDetector(
                onTap: () => _setButtonPosition(playerId),
                child: Container(
                  key: playerId == 1 ? _buttonIndicatorKey : null,
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isButton
                        ? _mint.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isButton ? _mint : Colors.white.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'D',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isButton ? _mint : Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Position + Name inline
              Expanded(
                child: GestureDetector(
                  key: playerId == 1 ? _playerNameAreaKey : null,
                  onTap: () => _showOpponentSelectionDialog(playerId),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      // Position pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isButton
                              ? _mint.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          positionLabel,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 11,
                            color: isButton ? _mint : Colors.white.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          playerName,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.edit,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Stack display - tappable to edit
              GestureDetector(
                onTap: () => _showStackEditDialog(playerId),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${bbValue.toInt()} BB',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 17,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          isCashGame ? '\$$chipAmount' : '$chipAmount',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.4),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Slider row — slim, no labels
          SizedBox(
            key: playerId == 2 ? _stackSliderKey : null,
            height: 28,
            child: Builder(
              builder: (context) {
                final sliderMax = _getSliderMaxBB();
                return SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: _mint,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
                    thumbColor: _mint,
                    overlayColor: _mint.withValues(alpha: 0.1),
                    trackHeight: 2.5,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                  ),
                  child: Slider(
                    min: 0.0,
                    max: sliderMax,
                    divisions: sliderMax.toInt(),
                    value: bbValue > sliderMax ? sliderMax : bbValue,
                    onChanged: (value) => _updateStack(playerId, value),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
