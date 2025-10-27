import 'package:flutter/material.dart';
import '../models/hand_state_machine.dart';
import '../utils/poker_positions.dart';
import '../services/auth_service.dart';
import '../services/opponent_service.dart';
import '../services/opponent_stats_service.dart';
import '../models/opponent.dart';
import '../models/opponent_stats.dart';
import '../models/poker_game_state.dart';
import '../models/game_types.dart';
import 'poker_hand_screen.dart';
import 'dart:math' as math;

class SeatSetupScreen extends StatefulWidget {
  final int? playerCount;
  final int? buttonPosition;
  final int? currentSeat;
  final PokerSessionManager? sessionManager;
  final bool isInitialSetup;
  final bool isCashGame;
  final PokerGameState? gameState;

  // Individual session parameters
  final bool isIndividualSession;
  final double? individualCurrentStack;

  // Session parameters from Session Setup
  final String? sessionName;
  final double? buyInAmount;
  final double? startingStack;
  final GameType? gameType;
  final int? smallBlind;
  final int? bigBlind;
  final bool? hasBBante;

  const SeatSetupScreen({
    Key? key,
    this.playerCount,
    this.buttonPosition,
    this.currentSeat,
    this.sessionManager,
    this.isInitialSetup = true,
    this.isCashGame = true,
    this.gameState,
    this.isIndividualSession = false,
    this.individualCurrentStack,
    this.sessionName,
    this.buyInAmount,
    this.startingStack,
    this.gameType,
    this.smallBlind,
    this.bigBlind,
    this.hasBBante,
  }) : super(key: key);

  @override
  _SeatSetupScreenState createState() => _SeatSetupScreenState();
}

class _SeatSetupScreenState extends State<SeatSetupScreen> {
  int? selectedSeat;
  int? selectedButtonPosition;
  Map<int, TextEditingController> nameControllers = {};
  Map<int, TextEditingController> stackControllers = {};
  Map<int, bool> seatActive = {};
  List<Opponent> allOpponents = [];
  Map<String, OpponentStats> opponentStats = {}; // For accessing playingStyle
  Map<int, bool> showSaveOpponentTip = {};
  Offset? buttonDragPosition;
  bool isDraggingButton = false;

  /// Check if button can be moved
  /// Button is locked once any player has acted (folded/called/raised)
  /// Button can be moved: before hand starts, or after blinds posted but before first action
  bool _isButtonLocked() {
    if (widget.gameState == null) return false;

    // Check if any player has acted
    for (final player in widget.gameState!.players) {
      if (player.isActive && player.hasActed) {
        return true; // At least one player acted, button is locked
      }
    }

    return false; // No actions taken yet, button can be moved
  }

  @override
  void initState() {
    super.initState();
    selectedSeat = widget.currentSeat;
    selectedButtonPosition = widget.buttonPosition ?? 1; // Default button to seat 1

    // Always initialize 9 seats regardless of player count
    for (int i = 1; i <= 9; i++) {
      // First determine active status
      if (widget.isInitialSetup) {
        // For initial setup, all 9 seats are active - user will deactivate seats they don't want
        seatActive[i] = true;
      } else if (widget.gameState != null) {
        // Use gameState player status
        try {
          final player = widget.gameState!.players.firstWhere((p) => p.playerId == i);
          seatActive[i] = player.isActive;
        } catch (e) {
          seatActive[i] = false;
        }
      } else {
        seatActive[i] = widget.sessionManager?.isPlayerActive(i) ?? false;
      }

      // Then initialize controllers based on active status
      if (seatActive[i] == true) {
        nameControllers[i] = TextEditingController(
          text: widget.sessionManager?.getPlayerName(i) ?? ''
        );
      } else {
        nameControllers[i] = TextEditingController(text: '');
      }

      stackControllers[i] = TextEditingController(
        text: _getCurrentStackForSeat(i)
      );
    }

    // Load opponents for autocomplete
    _loadOpponents();
  }

  String _getCurrentStackForSeat(int seatNumber) {
    // If we have gameState and this is not initial setup, use current stacks
    if (widget.gameState != null && !widget.isInitialSetup) {
      final currentStack = widget.gameState!.getPlayerStack(seatNumber);
      return widget.isCashGame ? currentStack.toStringAsFixed(2) : currentStack.toInt().toString();
    }
    // Otherwise use default values
    return widget.isCashGame ? '100.00' : '1500';
  }

  @override
  void dispose() {
    nameControllers.values.forEach((controller) => controller.dispose());
    stackControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _loadOpponents() async {
    try {
      final opponents = await OpponentService.getAllOpponents();
      final statsMap = <String, OpponentStats>{};

      // Load stats for each opponent
      for (final opponent in opponents) {
        final stats = await OpponentStatsService.getOpponentStats(opponent.name);
        if (stats != null) {
          statsMap[opponent.name] = stats;
        }
      }

      setState(() {
        allOpponents = opponents;
        opponentStats = statsMap;
      });
    } catch (e) {
      print('Failed to load opponents: $e');
    }
  }

  List<String> _getSuggestions(String query) {
    if (query.isEmpty) return [];

    return allOpponents
        .where((opponent) => opponent.name.toLowerCase().contains(query.toLowerCase()))
        .map((opponent) => opponent.name)
        .take(5)
        .toList();
  }

  void _checkIfShouldShowSaveTip(int seatNumber, String name) {
    if (name.trim().isEmpty) {
      setState(() {
        showSaveOpponentTip[seatNumber] = false;
      });
      return;
    }

    // Check if this name exists in our opponents
    final existingOpponent = allOpponents
        .where((opponent) => opponent.name.toLowerCase() == name.toLowerCase())
        .isNotEmpty;

    // Show tip if name doesn't exist and it's not a position name
    final isPositionName = PokerPositions.isPositionName(name);

    setState(() {
      showSaveOpponentTip[seatNumber] = !existingOpponent && !isPositionName;
    });
  }

  Color _getColorForOpponent(OpponentColor color) {
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

  String _getPositionForActiveSeat(int seatNumber) {
    // Get all active seats
    List<int> activeSeats = [];
    for (int i = 1; i <= 9; i++) {
      if (seatActive[i] == true) {
        activeSeats.add(i);
      }
    }

    if (activeSeats.isEmpty) return '';

    // If this seat is not active, return empty
    if (!activeSeats.contains(seatNumber)) return 'Empty';

    // Use the new position calculation method that considers active players only
    final buttonPos = selectedButtonPosition ?? widget.buttonPosition ?? 1;
    return PokerPositions.getPositionNameForActivePlayers(seatNumber, buttonPos, activeSeats);
  }

  Offset _getSeatPosition(int seatNumber, Size tableSize) {
    // Define seat positions ON the table border
    // Seats should sit exactly on the oval border line
    final double centerX = tableSize.width / 2;
    final double centerY = tableSize.height / 2;
    // Match the table size (80% width, 70% height)
    final double radiusX = (tableSize.width * 0.80) / 2;
    final double radiusY = (tableSize.height * 0.70) / 2;

    // Evenly distribute 9 seats around the oval
    // Seat 1 at top-left, then 2-9 going clockwise
    // Clockwise from top-left: 1(top-left), 2(left), 3(bottom-left), 4(bottom-center),
    //         5(bottom-right), 6(right), 7(top-right), 8(top-center), 9(between 8 and 1)

    // Position seats evenly: 360° / 9 = 40° between each seat
    // Starting position: top-left (225° or 5π/4)
    final double startAngle = math.pi * 1.25; // Start at top-left (225°)
    final double angleStep = (2 * math.pi) / 9; // 40° in radians

    // Calculate angle for this seat (clockwise = add angle, not subtract)
    final double angle = startAngle + (angleStep * (seatNumber - 1));

    final x = centerX + radiusX * math.cos(angle);
    final y = centerY + radiusY * math.sin(angle);

    return Offset(x, y);
  }

  void _showSeatDialog(int seatNumber) {
    final isActive = seatActive[seatNumber] ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxWidth: 400),
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
                      child: Center(
                        child: Text(
                          '$seatNumber',
                          style: TextStyle(
                            color: Color(0xFFcb5242),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seat $seatNumber',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _getPositionForActiveSeat(seatNumber),
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9A9A9A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Active toggle
                    Switch(
                      value: isActive,
                      activeColor: Color(0xFFcb5242),
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: Color(0xFF2A2A2E),
                      onChanged: (value) {
                        setState(() {
                          seatActive[seatNumber] = value;
                          if (value) {
                            if (nameControllers[seatNumber]!.text.isEmpty) {
                              nameControllers[seatNumber]!.text = 'Player $seatNumber';
                            }
                          }
                        });
                        Navigator.pop(context);
                        if (value) {
                          // Reopen dialog to edit
                          Future.delayed(Duration(milliseconds: 100), () {
                            _showSeatDialog(seatNumber);
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              // Content
              if (isActive) ...[
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // My Seat selection (always available)
                      InkWell(
                          onTap: () {
                            setState(() {
                              // Restore defaults for previous seat before selecting new one
                              _restoreDefaultsForPreviousSeat(selectedSeat);

                              selectedSeat = seatNumber;
                              _autoInsertUsernameForSeat(seatNumber);

                              // Set the user's stack from session setup
                              if (widget.isIndividualSession && widget.individualCurrentStack != null) {
                                stackControllers[seatNumber]?.text = widget.isCashGame
                                  ? widget.individualCurrentStack!.toStringAsFixed(2)
                                  : widget.individualCurrentStack!.toInt().toString();
                              } else if (widget.startingStack != null) {
                                stackControllers[seatNumber]?.text = widget.gameType == GameType.cash
                                  ? widget.startingStack!.toStringAsFixed(2)
                                  : widget.startingStack!.toInt().toString();
                              }
                            });
                            // Close and reopen dialog to refresh with updated name
                            Navigator.pop(context);
                            Future.delayed(Duration(milliseconds: 100), () {
                              _showSeatDialog(seatNumber);
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: selectedSeat == seatNumber
                                ? Color(0xFFcb5242).withOpacity(0.1)
                                : Color(0xFF1F1F23),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedSeat == seatNumber
                                  ? Color(0xFFcb5242)
                                  : Color(0xFF2A2A2E),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  selectedSeat == seatNumber ? Icons.check_circle : Icons.circle_outlined,
                                  color: selectedSeat == seatNumber ? Color(0xFFcb5242) : Color(0xFF9A9A9A),
                                  size: 20,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'This is my seat',
                                  style: TextStyle(
                                    color: selectedSeat == seatNumber ? Color(0xFFcb5242) : Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      SizedBox(height: 16),
                      // Player name
                      Autocomplete<String>(
                        initialValue: TextEditingValue(text: nameControllers[seatNumber]!.text),
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          return _getSuggestions(textEditingValue.text);
                        },
                        onSelected: (String selection) {
                          nameControllers[seatNumber]!.text = selection;
                          widget.sessionManager?.setPlayerName(seatNumber, selection);
                          setState(() {
                            _checkIfShouldShowSaveTip(seatNumber, selection);
                          });
                          setDialogState(() {});
                        },
                        fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                          // Sync with our original controller
                          if (controller.text != nameControllers[seatNumber]!.text) {
                            controller.text = nameControllers[seatNumber]!.text;
                          }

                          return Container(
                            decoration: BoxDecoration(
                              color: Color(0xFF1F1F23),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Color(0xFF2A2A2E)),
                            ),
                            child: TextField(
                              controller: controller,
                              focusNode: focusNode,
                              onEditingComplete: onEditingComplete,
                              style: TextStyle(color: Colors.white, fontSize: 16),
                              decoration: InputDecoration(
                                labelText: 'Player Name',
                                labelStyle: TextStyle(color: Color(0xFF9A9A9A)),
                                hintText: 'Enter player name',
                                hintStyle: TextStyle(color: Color(0xFF9A9A9A)),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                suffixIcon: allOpponents.isNotEmpty
                                    ? Icon(Icons.search, size: 18, color: Color(0xFF9A9A9A))
                                    : null,
                              ),
                              textCapitalization: TextCapitalization.words,
                              onChanged: (value) {
                                nameControllers[seatNumber]!.text = value;
                                widget.sessionManager?.setPlayerName(seatNumber, value);
                                setState(() {
                                  _checkIfShouldShowSaveTip(seatNumber, value);
                                });
                                setDialogState(() {});
                              },
                            ),
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(12),
                              color: Color(0xFF1F1F23),
                              child: Container(
                                constraints: BoxConstraints(maxHeight: 200, maxWidth: 300),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Color(0xFF2A2A2E)),
                                ),
                                child: ListView.builder(
                                  padding: EdgeInsets.all(8),
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (context, index) {
                                    final option = options.elementAt(index);
                                    final opponent = allOpponents.firstWhere(
                                      (o) => o.name == option,
                                      orElse: () => allOpponents.first,
                                    );

                                    return Container(
                                      margin: EdgeInsets.only(bottom: 4),
                                      decoration: BoxDecoration(
                                        color: Color(0xFF161618),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ListTile(
                                        dense: true,
                                        title: Text(
                                          option,
                                          style: TextStyle(color: Colors.white, fontSize: 14),
                                        ),
                                        subtitle: Text(
                                          opponentStats[opponent.name]?.playingStyle ?? 'No Data',
                                          style: TextStyle(fontSize: 11, color: Color(0xFF9A9A9A)),
                                        ),
                                        leading: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: _getColorForOpponent(opponent.color),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        onTap: () => onSelected(option),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      // Save opponent tip
                      if (showSaveOpponentTip[seatNumber] == true) ...[
                        SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            // Immediately hide the save prompt to prevent double-tap
                            setState(() {
                              showSaveOpponentTip[seatNumber] = false;
                            });
                            setDialogState(() {});

                            try {
                              final opponent = OpponentService.createNewOpponent(name: nameControllers[seatNumber]!.text);
                              await OpponentService.saveOpponent(opponent);
                              await _loadOpponents();

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Opponent saved successfully!'),
                                  backgroundColor: Color(0xFFcb5242),
                                ),
                              );
                            } catch (e) {
                              // Show the prompt again if save failed
                              setState(() {
                                showSaveOpponentTip[seatNumber] = true;
                              });
                              setDialogState(() {});

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to save opponent: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Color(0xFFcb5242).withOpacity(0.1),
                              border: Border.all(color: Color(0xFFcb5242).withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.person_add, size: 16, color: Color(0xFFcb5242)),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Save "${nameControllers[seatNumber]!.text}" as opponent?',
                                    style: TextStyle(fontSize: 12, color: Color(0xFFcb5242)),
                                  ),
                                ),
                                Icon(Icons.arrow_forward, size: 16, color: Color(0xFFcb5242)),
                              ],
                            ),
                          ),
                        ),
                      ],

                      // Stack size input
                      SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Color(0xFF1F1F23),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Color(0xFF2A2A2E)),
                        ),
                        child: TextField(
                          controller: stackControllers[seatNumber],
                          keyboardType: TextInputType.numberWithOptions(decimal: widget.isCashGame),
                          style: TextStyle(color: Colors.white, fontSize: 16),
                          decoration: InputDecoration(
                            labelText: widget.isCashGame ? 'Buy-in Amount (\$)' : 'Starting Chips',
                            labelStyle: TextStyle(color: Color(0xFF9A9A9A)),
                            hintText: widget.isCashGame ? '100.00' : '1500',
                            hintStyle: TextStyle(color: Color(0xFF9A9A9A)),
                            prefixText: widget.isCashGame ? '\$ ' : '',
                            prefixStyle: TextStyle(color: Color(0xFF9A9A9A)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onChanged: (value) {
                            // Validate input format
                            if (widget.isCashGame) {
                              if (value.isNotEmpty && !RegExp(r'^\d*\.?\d{0,2}$').hasMatch(value)) {
                                stackControllers[seatNumber]!.text = stackControllers[seatNumber]!.text.substring(0, stackControllers[seatNumber]!.text.length - 1);
                                stackControllers[seatNumber]!.selection = TextSelection.fromPosition(TextPosition(offset: stackControllers[seatNumber]!.text.length));
                              }
                            } else {
                              if (value.isNotEmpty && !RegExp(r'^\d+$').hasMatch(value)) {
                                stackControllers[seatNumber]!.text = stackControllers[seatNumber]!.text.substring(0, stackControllers[seatNumber]!.text.length - 1);
                                stackControllers[seatNumber]!.selection = TextSelection.fromPosition(TextPosition(offset: stackControllers[seatNumber]!.text.length));
                              }
                            }
                          },
                        ),
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
                            gradient: LinearGradient(
                              colors: [Color(0xFFcb5242), Color(0xFFb8442f)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Done',
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
              // For inactive seats, still show seat selection option
              if (!isActive) ...[
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            // Restore defaults for previous seat before selecting new one
                            _restoreDefaultsForPreviousSeat(selectedSeat);

                            // Activate this seat when selecting it as user's seat
                            seatActive[seatNumber] = true;
                            selectedSeat = seatNumber;
                            _autoInsertUsernameForSeat(seatNumber);

                            // Set the user's stack from session setup
                            if (widget.isIndividualSession && widget.individualCurrentStack != null) {
                              stackControllers[seatNumber]?.text = widget.isCashGame
                                  ? widget.individualCurrentStack!.toStringAsFixed(2)
                                  : widget.individualCurrentStack!.toInt().toString();
                            } else if (widget.startingStack != null) {
                              stackControllers[seatNumber]?.text = widget.gameType == GameType.cash
                                  ? widget.startingStack!.toStringAsFixed(2)
                                  : widget.startingStack!.toInt().toString();
                            }
                          });
                          // Close and reopen dialog to refresh
                          Navigator.pop(context);
                          Future.delayed(Duration(milliseconds: 100), () {
                            _showSeatDialog(seatNumber);
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: selectedSeat == seatNumber
                                ? Color(0xFFcb5242).withOpacity(0.1)
                                : Color(0xFF1F1F23),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedSeat == seatNumber
                                  ? Color(0xFFcb5242)
                                  : Color(0xFF2A2A2E),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selectedSeat == seatNumber ? Icons.check_circle : Icons.circle_outlined,
                                color: selectedSeat == seatNumber ? Color(0xFFcb5242) : Color(0xFF9A9A9A),
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'This is my seat',
                                style: TextStyle(
                                  color: selectedSeat == seatNumber ? Color(0xFFcb5242) : Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'This seat is currently empty. Select it as your seat to activate it, or toggle the switch above to assign another player.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9A9A9A),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1F1F23),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 20),
              decoration: BoxDecoration(
                color: Color(0xFF1F1F23),
              ),
              child: Row(
                children: [
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
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isInitialSetup ? 'Setup Seats' : 'Manage Players',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          widget.isInitialSetup
                              ? 'Click seats to configure. Drag button to position.'
                              : _isButtonLocked()
                                  ? 'Button locked - hand in progress'
                                  : 'Update player information',
                          style: TextStyle(
                            fontSize: 12,
                            color: _isButtonLocked() ? Colors.red.withOpacity(0.8) : Color(0xFF9A9A9A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Visual Poker Table
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      // Table background with depth
                      Center(
                        child: Container(
                          width: constraints.maxWidth * 0.80,
                          height: constraints.maxHeight * 0.70,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(200),
                            boxShadow: [
                              // Outer shadow for elevation
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 30,
                                spreadRadius: 0,
                                offset: Offset(0, 10),
                              ),
                              // Inner shadow for depth
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 15,
                                spreadRadius: -5,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              // Gradient for felt texture depth
                              gradient: RadialGradient(
                                center: Alignment.center,
                                radius: 0.8,
                                colors: [
                                  Color(0xFF0F6B33), // Lighter green center
                                  Color(0xFF0D5D2D), // Medium green
                                  Color(0xFF0A4A24), // Darker green edges
                                ],
                                stops: [0.0, 0.6, 1.0],
                              ),
                              borderRadius: BorderRadius.circular(200),
                              border: Border.all(
                                color: Color(0xFF2A2A2E),
                                width: 6,
                              ),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(194),
                                // Inner border highlight
                                border: Border.all(
                                  color: Color(0xFF1A1A1E).withOpacity(0.5),
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Opacity(
                                  opacity: 0.12,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        'icons/logo.png',
                                        width: 100,
                                        height: 100,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'POKER FRIEND',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Seats positioned around the table
                      ...List.generate(9, (index) {
                        final seatNumber = index + 1;
                        final isActive = seatActive[seatNumber] ?? false;
                        final isSelected = selectedSeat == seatNumber;
                        final isButtonSeat = seatNumber == (selectedButtonPosition ?? widget.buttonPosition);
                        final position = _getSeatPosition(seatNumber, Size(constraints.maxWidth, constraints.maxHeight));

                        // Calculate button position (towards center of table)
                        final double startAngle = math.pi * 1.25;
                        final double angleStep = (2 * math.pi) / 9;
                        final double seatAngle = startAngle + (angleStep * (seatNumber - 1));

                        // Button offset towards center (negative of seat direction)
                        // Use larger offset (50 pixels) to position button well inside the table
                        final buttonOffsetX = -50 * math.cos(seatAngle);
                        final buttonOffsetY = -50 * math.sin(seatAngle);

                        return Stack(
                          children: [
                            // Seat circle
                            Positioned(
                              left: position.dx - 30,
                              top: position.dy - 30,
                              child: GestureDetector(
                                onTap: () => _showSeatDialog(seatNumber),
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: !isActive
                                        ? Color(0xFF0A0A0C)
                                        : isSelected
                                        ? Color(0xFFcb5242)
                                        : Color(0xFF2A2A2E),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: !isActive
                                          ? Color(0xFF1A1A1E)
                                          : isSelected
                                          ? Color(0xFFcb5242)
                                          : Color(0xFF4A4A4E),
                                      width: 2,
                                    ),
                                    boxShadow: isSelected ? [
                                      BoxShadow(
                                        color: Color(0xFFcb5242).withOpacity(0.5),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ] : null,
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '$seatNumber',
                                          style: TextStyle(
                                            color: isActive ? Colors.white : Color(0xFF4A4A4E),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        if (isActive && nameControllers[seatNumber]!.text.isNotEmpty)
                                          Padding(
                                            padding: EdgeInsets.only(top: 2),
                                            child: Text(
                                              nameControllers[seatNumber]!.text.length > 6
                                                  ? '${nameControllers[seatNumber]!.text.substring(0, 6)}...'
                                                  : nameControllers[seatNumber]!.text,
                                              style: TextStyle(
                                                color: isSelected ? Colors.white : Color(0xFFBBBBBB),
                                                fontSize: 8,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        if (!isActive)
                                          Padding(
                                            padding: EdgeInsets.only(top: 2),
                                            child: Text(
                                              'Empty',
                                              style: TextStyle(
                                                color: Color(0xFF4A4A4E),
                                                fontSize: 8,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Button positioned towards center
                            if (isButtonSeat)
                              Positioned(
                                left: position.dx - 16 + buttonOffsetX,
                                top: position.dy - 16 + buttonOffsetY,
                                child: _isButtonLocked()
                                  ? // Button is locked - show with lock icon
                                    Opacity(
                                      opacity: 0.6,
                                      child: Stack(
                                        children: [
                                          Image.asset(
                                            'icons/button.png',
                                            width: 32,
                                            height: 32,
                                          ),
                                          Positioned.fill(
                                            child: Icon(
                                              Icons.lock,
                                              color: Colors.red.withOpacity(0.8),
                                              size: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : // Button is unlocked - can be dragged
                                    Draggable<int>(
                                      data: seatNumber,
                                      feedback: Opacity(
                                        opacity: 0.7,
                                        child: Image.asset(
                                          'icons/button.png',
                                          width: 40,
                                          height: 40,
                                        ),
                                      ),
                                      childWhenDragging: Opacity(
                                        opacity: 0.3,
                                        child: Image.asset(
                                          'icons/button.png',
                                          width: 32,
                                          height: 32,
                                        ),
                                      ),
                                      onDragStarted: () {
                                        setState(() {
                                          isDraggingButton = true;
                                        });
                                      },
                                      onDragEnd: (details) {
                                        // Find closest active seat to drop position
                                        int? closestSeat;
                                        double minDistance = double.infinity;

                                        // Get the local position relative to the widget
                                        final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
                                        if (renderBox != null) {
                                          final localPosition = renderBox.globalToLocal(details.offset);

                                          for (int i = 1; i <= 9; i++) {
                                            if (seatActive[i] == true) {
                                              final seatPos = _getSeatPosition(i, Size(constraints.maxWidth, constraints.maxHeight));
                                              final distance = (seatPos - localPosition).distance;

                                              if (distance < minDistance) {
                                                minDistance = distance;
                                                closestSeat = i;
                                              }
                                            }
                                          }

                                          // Increase detection radius to 150 pixels for better UX
                                          if (closestSeat != null && minDistance < 150) {
                                            setState(() {
                                              selectedButtonPosition = closestSeat;
                                              isDraggingButton = false;
                                            });
                                          } else {
                                            setState(() {
                                              isDraggingButton = false;
                                            });
                                          }
                                        } else {
                                          setState(() {
                                            isDraggingButton = false;
                                          });
                                        }
                                      },
                                      child: Image.asset(
                                        'icons/button.png',
                                        width: 32,
                                        height: 32,
                                      ),
                                    ),
                                ),
                          ],
                        );
                      }),
                    ],
                  );
                },
              ),
            ),

            // Actions
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Color(0xFF1F1F23),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Color(0xFF161618),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Color(0xFF2A2A2E)),
                      ),
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Color(0xFF9A9A9A),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFcb5242), Color(0xFFb8442f)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        onPressed: _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          widget.isInitialSetup ? 'Start Session' : 'Save Changes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
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
    );
  }

  void _restoreDefaultsForPreviousSeat(int? previousSeat) {
    if (previousSeat == null) return;

    final userName = AuthService.userDisplayName;
    final nameController = nameControllers[previousSeat];
    final stackController = stackControllers[previousSeat];

    if (nameController != null && stackController != null) {
      bool wasUserSeat = nameController.text == userName ||
                        nameController.text == "You" ||
                        nameController.text.isEmpty;

      if (wasUserSeat) {
        // Reset to default player name
        nameController.text = 'Player $previousSeat';

        // Reset to default stack based on session settings
        if (widget.startingStack != null) {
          stackController.text = widget.gameType == GameType.cash
              ? widget.startingStack!.toStringAsFixed(2)
              : widget.startingStack!.toInt().toString();
        } else {
          // Fallback to generic defaults if no session settings
          stackController.text = widget.isCashGame ? '100.00' : '1500';
        }

        // Deactivate the previous seat (user moved away from it)
        seatActive[previousSeat] = false;
        widget.sessionManager?.setPlayerName(previousSeat, 'Player $previousSeat');
      }
    }
  }

  void _autoInsertUsernameForSeat(int seatNumber) {
    final userName = AuthService.userDisplayName;
    final controller = nameControllers[seatNumber];

    if (controller != null && userName.isNotEmpty) {
      controller.text = userName;
      seatActive[seatNumber] = true;
      widget.sessionManager?.setPlayerName(seatNumber, userName);
    }
  }

  void _saveChanges() {
    // For initial setup, ensure a seat is selected
    if (widget.isInitialSetup && selectedSeat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select your seat'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Update all player names and active status
    Map<int, double> playerStacks = {};

    for (int seat = 1; seat <= 9; seat++) {
      final isActive = seatActive[seat] ?? false;
      final name = nameControllers[seat]?.text ?? '';

      if (isActive) {
        widget.sessionManager?.addPlayer(seat, name);

        // Parse and store stack size
        final stackText = stackControllers[seat]?.text ?? '0';
        double stackSize = 0.0;
        try {
          stackSize = double.parse(stackText);
        } catch (e) {
          stackSize = widget.isCashGame ? 100.0 : 1500.0;
        }
        playerStacks[seat] = stackSize;
        widget.sessionManager?.setPlayerStack(seat, stackSize);
      } else {
        widget.sessionManager?.removePlayer(seat);
      }
    }

    // Check if this is part of the full session setup flow
    if (widget.sessionName != null && widget.smallBlind != null && widget.bigBlind != null) {
      // Navigate to PokerHandScreen for full session flow
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PokerHandScreen(
            smallBlind: widget.smallBlind!,
            bigBlind: widget.bigBlind!,
            levelDuration: 15,
            numberOfPlayers: 9,
            gameType: widget.gameType ?? GameType.cash,
            hasBBante: widget.hasBBante ?? false,
            ante: (widget.hasBBante ?? false) ? widget.bigBlind! : 0,
            sessionName: widget.sessionName,
            buyInAmount: widget.buyInAmount,
            startingStack: widget.startingStack,
            initialSeat: selectedSeat,
            initialButtonPosition: selectedButtonPosition ?? widget.buttonPosition,
            sessionManager: widget.sessionManager,
          ),
        ),
      );
    } else {
      // Return data for the old flow
      Navigator.pop(context, {
        'seat': selectedSeat,
        'buttonPosition': selectedButtonPosition ?? widget.buttonPosition,
        'playerStacks': playerStacks,
        'isCashGame': widget.isCashGame,
      });
    }
  }
}
