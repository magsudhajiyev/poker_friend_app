import 'package:flutter/material.dart';
import '../design_system/poker_friend_theme.dart';
import '../utils/poker_positions.dart';
import '../services/opponent_service.dart';
import '../services/auth_service.dart';
import '../models/opponent.dart';
import '../models/game_types.dart';

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
  }

  Future<void> _loadOpponents() async {
    try {
      final loadedOpponents = await OpponentService.getAllOpponents();
      setState(() {
        opponents = loadedOpponents;
        _loadingOpponents = false;
      });
    } catch (e) {
      print('Error loading opponents: $e');
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

          return AlertDialog(
            backgroundColor: PokerFriendColors.dark3,
            title: Text(
              'Select Player',
              style: TextStyle(color: Colors.white),
            ),
            content: Container(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Option to clear name
                  if (customPlayerNames.containsKey(playerId)) ...[
                    ListTile(
                      leading: Icon(Icons.clear, color: Colors.red),
                      title: Text(
                        'Clear Name',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () => Navigator.pop(context, '__CLEAR__'),
                    ),
                    Divider(color: PokerFriendColors.dark9),
                  ],

                  // Search bar
                  Container(
                    margin: EdgeInsets.only(bottom: 16),
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    height: 48,
                    decoration: BoxDecoration(
                      color: PokerFriendColors.dark1,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      style: TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Search players...',
                        hintStyle: TextStyle(color: PokerFriendColors.dark9),
                        prefixIcon: Icon(
                          Icons.search,
                          color: PokerFriendColors.dark9,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                  ),

                  // Players list
                  Flexible(
                    child: Container(
                      constraints: BoxConstraints(maxHeight: 300),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          // User's name at top
                          if (showUserName) ...[
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: PokerFriendColors.red,
                                child: Icon(Icons.person, color: Colors.white, size: 20),
                              ),
                              title: Text(
                                userName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'You',
                                style: TextStyle(
                                  color: PokerFriendColors.dark9,
                                  fontSize: 12,
                                ),
                              ),
                              onTap: () => Navigator.pop(context, userName),
                            ),
                            if (filteredOpponents.isNotEmpty)
                              Divider(color: PokerFriendColors.dark9),
                          ],

                          // Opponents list
                          if (filteredOpponents.isEmpty && !showUserName)
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'No results found.\nTry a different search term.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: PokerFriendColors.dark9),
                              ),
                            )
                          else
                            ...filteredOpponents.map((opponent) {
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getOpponentColor(opponent.color),
                                  child: Text(
                                    opponent.name[0].toUpperCase(),
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(
                                  opponent.name,
                                  style: TextStyle(color: Colors.white),
                                ),
                                onTap: () => Navigator.pop(context, opponent.name),
                              );
                            }).toList(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: PokerFriendColors.dark9),
                ),
              ),
            ],
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
      builder: (context) => AlertDialog(
        backgroundColor: PokerFriendColors.dark3,
        title: Text(
          'Edit Stack',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: TextStyle(color: Colors.white, fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Stack in BB',
                labelStyle: TextStyle(color: PokerFriendColors.dark9),
                suffixText: 'BB',
                suffixStyle: TextStyle(color: PokerFriendColors.dark9),
                filled: true,
                fillColor: PokerFriendColors.dark1,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            SizedBox(height: 12),
            Text(
              widget.gameType == GameType.cash
                  ? 'Current: ${currentBB.toInt()} BB = \$${currentChips}'
                  : 'Current: ${currentBB.toInt()} BB = $currentChips',
              style: TextStyle(
                color: PokerFriendColors.dark9,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: PokerFriendColors.dark9),
            ),
          ),
          ElevatedButton(
            onPressed: () {
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
            style: ElevatedButton.styleFrom(
              backgroundColor: PokerFriendColors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Save',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
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
      backgroundColor: PokerFriendColors.dark1,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Update Stacks & Button',
                              style: TextStyle(
                                fontSize: 28,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              widget.gameType == GameType.cash
                                  ? 'Blinds: \$${widget.smallBlind}/\$${widget.bigBlind}'
                                  : 'Blinds: ${widget.smallBlind}/${widget.bigBlind}',
                              style: TextStyle(
                                fontSize: 16,
                                color: PokerFriendColors.dark9,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: PokerFriendColors.dark3,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  // Instruction text
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: PokerFriendColors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: PokerFriendColors.red.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: PokerFriendColors.red,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tap stack to edit • Slide to adjust • Tap 🟡 for button',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white,
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
                padding: EdgeInsets.symmetric(horizontal: 24),
                itemCount: widget.numberOfPlayers,
                itemBuilder: (context, index) {
                  final playerId = index + 1;
                  return _buildPlayerRow(playerId);
                },
              ),
            ),

            // Continue button
            Padding(
              padding: EdgeInsets.all(24),
              child: Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [PokerFriendColors.red, Color(0xFFb8442f)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ElevatedButton(
                  onPressed: _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'CONTINUE TO LOG HAND',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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

  Widget _buildPlayerRow(int playerId) {
    final isButton = playerId == buttonPlayerId;
    final bbValue = _getBBValue(playerId);
    final chipAmount = _getChipAmount(playerId);
    final playerName = _getPlayerName(playerId);
    final positionLabel = _getPositionLabel(playerId);
    final isSeatOpen = seatIsOpen[playerId] ?? false;
    final isCashGame = widget.gameType == GameType.cash;

    return Opacity(
      opacity: isSeatOpen ? 0.4 : 1.0,
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PokerFriendColors.dark3,
          borderRadius: BorderRadius.circular(20),
          border: isButton && !isSeatOpen
              ? Border.all(color: Colors.amber, width: 2)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: Seat toggle + Button selector + Name + Position + Stack
            Row(
              children: [
                // Seat open/closed toggle
                GestureDetector(
                  onTap: () => _toggleSeatOpen(playerId),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSeatOpen ? PokerFriendColors.dark1 : PokerFriendColors.red,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSeatOpen ? PokerFriendColors.dark9 : PokerFriendColors.red,
                        width: 2,
                      ),
                    ),
                    child: isSeatOpen
                        ? null
                        : Icon(Icons.check, color: Colors.white, size: 16),
                  ),
                ),
                SizedBox(width: 8),

                // Button selector (dealer chip icon)
                GestureDetector(
                  onTap: isSeatOpen ? null : () => _setButtonPosition(playerId),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isButton && !isSeatOpen
                          ? Colors.amber.withOpacity(0.2)
                          : PokerFriendColors.dark1,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isButton && !isSeatOpen ? Colors.amber : PokerFriendColors.dark9,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        isButton && !isSeatOpen ? '🟡' : '○',
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),

                // Position + Name (Clickable)
                Expanded(
                  child: GestureDetector(
                    onTap: isSeatOpen ? null : () => _showOpponentSelectionDialog(playerId),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Position label
                          Text(
                            isSeatOpen ? 'OPEN' : positionLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSeatOpen
                                  ? PokerFriendColors.dark9
                                  : (isButton ? Colors.amber : PokerFriendColors.red),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          // Player name with edit indicator
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  isSeatOpen ? 'Empty Seat' : playerName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (!isSeatOpen)
                                Icon(
                                  Icons.edit,
                                  size: 14,
                                  color: PokerFriendColors.dark9,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Stack display (BB + chips) - Clickable to edit
                if (!isSeatOpen)
                  GestureDetector(
                    onTap: () => _showStackEditDialog(playerId),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: PokerFriendColors.dark1.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${bbValue.toInt()} BB',
                                style: TextStyle(
                                  fontSize: 22,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.edit,
                                size: 14,
                                color: PokerFriendColors.dark9,
                              ),
                            ],
                          ),
                          Text(
                            isCashGame ? '\$$chipAmount' : '$chipAmount',
                            style: TextStyle(
                              fontSize: 16,
                              color: PokerFriendColors.dark9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            if (!isSeatOpen) ...[
              SizedBox(height: 12),

              // Slider
              Builder(
                builder: (context) {
                  final sliderMax = _getSliderMaxBB();
                  return Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: PokerFriendColors.red,
                          inactiveTrackColor: PokerFriendColors.dark1,
                          thumbColor: PokerFriendColors.red,
                          overlayColor: PokerFriendColors.red.withOpacity(0.2),
                          trackHeight: 4.0,
                          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8.0),
                        ),
                        child: Slider(
                          min: 0.0,
                          max: sliderMax,
                          divisions: sliderMax.toInt(),
                          value: bbValue > sliderMax ? sliderMax : bbValue,
                          onChanged: (value) => _updateStack(playerId, value),
                        ),
                      ),
                      // Slider labels (dynamic based on max)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSliderLabel('0'),
                          _buildSliderLabel('${(sliderMax * 0.25).toInt()}'),
                          _buildSliderLabel('${(sliderMax * 0.5).toInt()}'),
                          _buildSliderLabel('${(sliderMax * 0.75).toInt()}'),
                          _buildSliderLabel('${sliderMax.toInt()}'),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSliderLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        color: PokerFriendColors.dark9,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
