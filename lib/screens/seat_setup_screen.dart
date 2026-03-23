import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/hand_state_machine.dart';
import '../utils/poker_positions.dart';
import '../services/auth_service.dart';
import '../services/opponent_service.dart';
import '../services/opponent_stats_service.dart';
import '../models/opponent.dart';
import '../models/opponent_stats.dart';
import '../models/poker_game_state.dart';
import '../models/game_types.dart';
import '../widgets/global_bottom_nav_bar.dart';
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
  Map<String, OpponentStats> opponentStats = {};
  Map<int, bool> showSaveOpponentTip = {};
  Offset? buttonDragPosition;
  bool isDraggingButton = false;

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

  bool _isButtonLocked() {
    if (widget.gameState == null) return false;
    for (final player in widget.gameState!.players) {
      if (player.isActive && player.hasActed) {
        return true;
      }
    }
    return false;
  }

  bool _areSeatChangesLocked() {
    if (widget.gameState == null) return false;
    for (final player in widget.gameState!.players) {
      if (player.isActive && player.hasActed) {
        return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    selectedSeat = widget.currentSeat;
    selectedButtonPosition = widget.buttonPosition ?? 1;

    for (int i = 1; i <= 9; i++) {
      if (widget.isInitialSetup) {
        seatActive[i] = true;
      } else if (widget.gameState != null) {
        try {
          final player = widget.gameState!.players.firstWhere((p) => p.playerId == i);
          seatActive[i] = player.isActive;
        } catch (e) {
          seatActive[i] = false;
        }
      } else {
        seatActive[i] = widget.sessionManager?.isPlayerActive(i) ?? false;
      }

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

    _loadOpponents();
  }

  String _getCurrentStackForSeat(int seatNumber) {
    if (widget.gameState != null && !widget.isInitialSetup) {
      final currentStack = widget.gameState!.getPlayerStack(seatNumber);
      return widget.isCashGame ? currentStack.toStringAsFixed(2) : currentStack.toInt().toString();
    }
    if (widget.startingStack != null) {
      return widget.isCashGame
          ? widget.startingStack!.toStringAsFixed(2)
          : widget.startingStack!.toInt().toString();
    }
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

      for (final opponent in opponents) {
        final stats = await OpponentStatsService.getOpponentStats(opponent.id);
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

    final existingOpponent = allOpponents
        .where((opponent) => opponent.name.toLowerCase() == name.toLowerCase())
        .isNotEmpty;

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
    List<int> activeSeats = [];
    for (int i = 1; i <= 9; i++) {
      if (seatActive[i] == true) {
        activeSeats.add(i);
      }
    }

    if (activeSeats.isEmpty) return '';
    if (!activeSeats.contains(seatNumber)) return 'Empty';

    final buttonPos = selectedButtonPosition ?? widget.buttonPosition ?? 1;
    return PokerPositions.getPositionNameForActivePlayers(seatNumber, buttonPos, activeSeats);
  }

  Offset _getSeatPosition(int seatNumber, Size tableSize) {
    final double centerX = tableSize.width / 2;
    final double centerY = tableSize.height / 2;
    // Match the new table dimensions (70% width, 80% height) - vertical oval
    final double radiusX = (tableSize.width * 0.70) / 2;
    final double radiusY = (tableSize.height * 0.80) / 2;

    final double startAngle = math.pi * 1.25;
    final double angleStep = (2 * math.pi) / 9;
    final double angle = startAngle + (angleStep * (seatNumber - 1));

    final x = centerX + radiusX * math.cos(angle);
    final y = centerY + radiusY * math.sin(angle);

    return Offset(x, y);
  }

  void _showSeatDialog(int seatNumber) {
    // Store original values to restore on cancel
    final originalIsActive = seatActive[seatNumber] ?? false;
    final originalSelectedSeat = selectedSeat;
    final originalName = nameControllers[seatNumber]?.text ?? '';
    final originalStack = stackControllers[seatNumber]?.text ?? '';

    // Create temporary state for the dialog
    bool tempIsActive = originalIsActive;
    bool tempIsMySeat = selectedSeat == seatNumber;
    String tempName = originalName;
    String tempStack = originalStack;

    // Create temporary controllers for the dialog
    final tempNameController = TextEditingController(text: tempName);
    final tempStackController = TextEditingController(text: tempStack);

    void saveChanges() {
      setState(() {
        // Apply all changes
        seatActive[seatNumber] = tempIsActive;
        nameControllers[seatNumber]?.text = tempName;
        stackControllers[seatNumber]?.text = tempStack;

        if (tempIsMySeat && selectedSeat != seatNumber) {
          // Restore defaults for previous seat if changing my seat
          if (selectedSeat != null && selectedSeat != seatNumber) {
            _restoreDefaultsForPreviousSeat(selectedSeat);
          }
          selectedSeat = seatNumber;
          widget.sessionManager?.setPlayerName(seatNumber, tempName);
        } else if (!tempIsMySeat && originalSelectedSeat == seatNumber) {
          // Unchecked "this is my seat"
          selectedSeat = null;
        }

        // Update session manager
        if (tempIsActive) {
          widget.sessionManager?.setPlayerName(seatNumber, tempName);
        }
      });

      Navigator.pop(context);
    }

    void cancelChanges() {
      // Just close - no changes applied
      Navigator.pop(context);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: Color(0xFF131616),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Header with X, title, checkmark
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // X button - cancel without saving
                      GestureDetector(
                        onTap: cancelChanges,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Color(0xFF3C3C43).withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: _buildIcon(
                              'icons/figma_icons/close.svg',
                              16,
                              Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Title
                      Text(
                        'Set up Seat',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 17,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.43,
                        ),
                      ),
                      // Checkmark button - save changes
                      GestureDetector(
                        onTap: saveChanges,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Color(0xFF3C3C43).withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: _buildIcon(
                              'icons/figma_icons/check.svg',
                              16,
                              Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // Seat info card with toggle
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Seat $seatNumber',
                                    style: GoogleFonts.ibmPlexSans(
                                      fontSize: 17,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    _getPositionForActiveSeat(seatNumber),
                                    style: GoogleFonts.ibmPlexSans(
                                      fontSize: 15,
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                              // Toggle - teal switch matching app design
                              GestureDetector(
                                onTap: _areSeatChangesLocked() ? null : () {
                                  setDialogState(() {
                                    tempIsActive = !tempIsActive;
                                    if (tempIsActive && tempName.isEmpty) {
                                      tempName = 'Player $seatNumber';
                                      tempNameController.text = tempName;
                                    }
                                  });
                                },
                                child: Container(
                                  width: 51,
                                  height: 31,
                                  decoration: BoxDecoration(
                                    color: tempIsActive ? Color(0xFF62E3BC) : Color(0xFF39393D),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: EdgeInsets.all(2),
                                  child: AnimatedAlign(
                                    duration: Duration(milliseconds: 200),
                                    alignment: tempIsActive ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(
                                      width: 27,
                                      height: 27,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 12),

                        // "This is my seat" row
                        GestureDetector(
                          onTap: _areSeatChangesLocked() ? null : () {
                            setDialogState(() {
                              if (!tempIsMySeat) {
                                tempIsMySeat = true;
                                tempIsActive = true;
                                // Auto-insert username
                                final userName = AuthService.userDisplayName;
                                if (userName.isNotEmpty) {
                                  tempName = userName;
                                  tempNameController.text = userName;
                                }
                                // Set stack
                                if (widget.isIndividualSession && widget.individualCurrentStack != null) {
                                  tempStack = widget.isCashGame
                                    ? widget.individualCurrentStack!.toStringAsFixed(2)
                                    : widget.individualCurrentStack!.toInt().toString();
                                  tempStackController.text = tempStack;
                                } else if (widget.startingStack != null) {
                                  tempStack = widget.gameType == GameType.cash
                                    ? widget.startingStack!.toStringAsFixed(2)
                                    : widget.startingStack!.toInt().toString();
                                  tempStackController.text = tempStack;
                                }
                              } else {
                                tempIsMySeat = false;
                              }
                            });
                          },
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Color(0xFF1C1C1E),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                // Simple circle outline
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: tempIsMySeat ? Color(0xFF62E3BC) : Color(0xFF48484A),
                                      width: 1.5,
                                    ),
                                    color: tempIsMySeat ? Color(0xFF62E3BC) : Colors.transparent,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'This is my seat',
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 15,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: 12),

                        // Player Name and Buy-in fields in one card
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              // Player Name field
                              Autocomplete<String>(
                                initialValue: TextEditingValue(text: tempName),
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  return _getSuggestions(textEditingValue.text);
                                },
                                onSelected: (String selection) {
                                  setDialogState(() {
                                    tempName = selection;
                                    tempNameController.text = selection;
                                    _checkIfShouldShowSaveTip(seatNumber, selection);
                                  });
                                },
                                fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                                  // Sync controller with tempName
                                  if (controller.text != tempNameController.text) {
                                    controller.text = tempNameController.text;
                                  }

                                  return TextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    onEditingComplete: onEditingComplete,
                                    enabled: !_areSeatChangesLocked(),
                                    style: GoogleFonts.ibmPlexSans(
                                      color: Colors.white,
                                      fontSize: 17,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Player Name',
                                      hintStyle: GoogleFonts.ibmPlexSans(
                                        color: Colors.white.withOpacity(0.4),
                                        fontSize: 15,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      focusedErrorBorder: InputBorder.none,
                                      filled: false,
                                      contentPadding: EdgeInsets.fromLTRB(16, 16, 16, 16),
                                    ),
                                    textCapitalization: TextCapitalization.words,
                                    onChanged: (value) {
                                      tempName = value;
                                      tempNameController.text = value;
                                      setDialogState(() {
                                        _checkIfShouldShowSaveTip(seatNumber, value);
                                      });
                                    },
                                  );
                                },
                                optionsViewBuilder: (context, onSelected, options) {
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 8,
                                      borderRadius: BorderRadius.circular(12),
                                      color: Color(0xFF1C1C1E),
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
                                                color: Color(0xFF131616),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: ListTile(
                                                dense: true,
                                                title: Text(
                                                  option,
                                                  style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 14),
                                                ),
                                                subtitle: Text(
                                                  opponentStats[opponent.name]?.playingStyle ?? 'No Data',
                                                  style: GoogleFonts.ibmPlexSans(fontSize: 11, color: Colors.white.withOpacity(0.6)),
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

                              // Divider
                              Container(
                                margin: EdgeInsets.symmetric(horizontal: 16),
                                height: 0.5,
                                color: Color(0xFF38383A),
                              ),

                              // Buy-in Amount field
                              TextField(
                                controller: tempStackController,
                                enabled: !_areSeatChangesLocked(),
                                keyboardType: TextInputType.numberWithOptions(decimal: widget.isCashGame),
                                style: GoogleFonts.ibmPlexSans(
                                  color: Colors.white,
                                  fontSize: 17,
                                ),
                                decoration: InputDecoration(
                                  hintText: widget.isCashGame ? 'Buy-in Amount (\$)' : 'Starting Chips',
                                  hintStyle: GoogleFonts.ibmPlexSans(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 15,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  filled: false,
                                  contentPadding: EdgeInsets.fromLTRB(16, 16, 16, 16),
                                ),
                                onChanged: (value) {
                                  if (widget.isCashGame) {
                                    if (value.isNotEmpty && !RegExp(r'^\d*\.?\d{0,2}$').hasMatch(value)) {
                                      tempStackController.text = tempStackController.text.substring(0, tempStackController.text.length - 1);
                                      tempStackController.selection = TextSelection.fromPosition(TextPosition(offset: tempStackController.text.length));
                                    }
                                  } else {
                                    if (value.isNotEmpty && !RegExp(r'^\d+$').hasMatch(value)) {
                                      tempStackController.text = tempStackController.text.substring(0, tempStackController.text.length - 1);
                                      tempStackController.selection = TextSelection.fromPosition(TextPosition(offset: tempStackController.text.length));
                                    }
                                  }
                                  tempStack = tempStackController.text;
                                },
                              ),
                            ],
                          ),
                        ),

                        // Save opponent tip
                        if (showSaveOpponentTip[seatNumber] == true) ...[
                          SizedBox(height: 12),
                          InkWell(
                            onTap: () async {
                              setState(() {
                                showSaveOpponentTip[seatNumber] = false;
                              });
                              setDialogState(() {});

                              try {
                                final opponent = OpponentService.createNewOpponent(name: tempName);
                                await OpponentService.saveOpponent(opponent);
                                await _loadOpponents();

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Opponent saved!'),
                                    backgroundColor: Color(0xFF62E3BC),
                                  ),
                                );
                              } catch (e) {
                                setState(() {
                                  showSaveOpponentTip[seatNumber] = true;
                                });
                                setDialogState(() {});

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to save: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Color(0xFF62E3BC).withOpacity(0.1),
                                border: Border.all(color: Color(0xFF62E3BC).withOpacity(0.3)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.person_add, size: 16, color: Color(0xFF62E3BC)),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Save "$tempName" as opponent?',
                                      style: GoogleFonts.ibmPlexSans(fontSize: 12, color: Color(0xFF62E3BC)),
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward, size: 16, color: Color(0xFF62E3BC)),
                                ],
                              ),
                            ),
                          ),
                        ],

                        SizedBox(height: 24),

                        // Done button - saves changes
                        GestureDetector(
                          onTap: saveChanges,
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Color(0xFF62E3BC),
                              borderRadius: BorderRadius.circular(110),
                            ),
                            child: Center(
                              child: Text(
                                'Done',
                                style: GoogleFonts.ibmPlexSans(
                                  color: Colors.black,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).then((_) {
      // Dispose temporary controllers when dialog closes
      tempNameController.dispose();
      tempStackController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: Stack(
        children: [
          // Teal gradient background
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
                // Header
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Color(0xFF3C3C43).withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: _buildIcon(
                              'icons/figma_icons/back.svg',
                              24,
                              Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isInitialSetup ? 'Setup Seat' : 'Manage Players',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 24,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              widget.isInitialSetup
                                  ? 'Click seat to configure. Drag button to position'
                                  : _isButtonLocked()
                                      ? 'Button locked - hand in progress'
                                      : 'Update player information',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 14,
                                color: _isButtonLocked() ? Colors.orange : Colors.white.withOpacity(0.6),
                                fontWeight: FontWeight.w400,
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
                          // Table with teal border - vertical oval shape
                          Center(
                            child: Container(
                              width: constraints.maxWidth * 0.70,
                              height: constraints.maxHeight * 0.80,
                              decoration: BoxDecoration(
                                color: Color(0xFF0A0A0C),
                                borderRadius: BorderRadius.circular(200),
                                border: Border.all(
                                  color: Color(0xFF62E3BC),
                                  width: 2,
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

                            final double startAngle = math.pi * 1.25;
                            final double angleStep = (2 * math.pi) / 9;
                            final double seatAngle = startAngle + (angleStep * (seatNumber - 1));

                            final buttonOffsetX = -50 * math.cos(seatAngle);
                            final buttonOffsetY = -50 * math.sin(seatAngle);

                            return Stack(
                              children: [
                                // Seat circle with label below
                                Positioned(
                                  left: position.dx - 24,
                                  top: position.dy - 24,
                                  child: GestureDetector(
                                    onTap: () => _showSeatDialog(seatNumber),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Seat circle
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: !isActive
                                                ? Color(0xFF2A2A2E) // Gray for empty seats
                                                : isSelected
                                                    ? Color(0xFF62E3BC) // Teal for selected
                                                    : Colors.white, // White for active
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              '$seatNumber',
                                              style: GoogleFonts.ibmPlexSans(
                                                color: !isActive
                                                    ? Colors.white.withOpacity(0.4) // Dim text for empty
                                                    : Colors.black,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 18,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        // Player label
                                        Text(
                                          isActive && nameControllers[seatNumber]!.text.isNotEmpty
                                              ? (nameControllers[seatNumber]!.text.length > 8
                                                  ? '${nameControllers[seatNumber]!.text.substring(0, 8)}...'
                                                  : nameControllers[seatNumber]!.text)
                                              : 'Player',
                                          style: GoogleFonts.ibmPlexSans(
                                            color: isActive
                                                ? Colors.white.withOpacity(0.8)
                                                : Colors.white.withOpacity(0.4), // Dim label for empty
                                            fontSize: 11,
                                            fontWeight: FontWeight.w400,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Button positioned towards center
                                if (isButtonSeat)
                                  Positioned(
                                    left: position.dx - 16 + buttonOffsetX,
                                    top: position.dy - 16 + buttonOffsetY,
                                    child: _isButtonLocked()
                                      ? Opacity(
                                          opacity: 0.6,
                                          child: Image.asset(
                                            'icons/button.png',
                                            width: 32,
                                            height: 32,
                                          ),
                                        )
                                      : Draggable<int>(
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
                                            int? closestSeat;
                                            double minDistance = double.infinity;

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

                // Bottom buttons
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      // Start Session button
                      GestureDetector(
                        onTap: _saveChanges,
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: Color(0xFF62E3BC),
                            borderRadius: BorderRadius.circular(110),
                          ),
                          child: Center(
                            child: Text(
                              widget.isInitialSetup ? 'Start Session' : 'Save Changes',
                              style: GoogleFonts.ibmPlexSans(
                                color: Colors.black,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.43,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      // Cancel button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.ibmPlexSans(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 60), // Space for bottom nav
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: GlobalBottomNavBar(currentScreen: ''),
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
        nameController.text = 'Player $previousSeat';

        if (widget.startingStack != null) {
          stackController.text = widget.gameType == GameType.cash
              ? widget.startingStack!.toStringAsFixed(2)
              : widget.startingStack!.toInt().toString();
        } else {
          stackController.text = widget.isCashGame ? '100.00' : '1500';
        }

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
    if (widget.isInitialSetup && selectedSeat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select your seat'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Map<int, double> playerStacks = {};

    for (int seat = 1; seat <= 9; seat++) {
      final isActive = seatActive[seat] ?? false;
      final name = nameControllers[seat]?.text ?? '';

      if (isActive) {
        widget.sessionManager?.addPlayer(seat, name);

        final stackText = stackControllers[seat]?.text ?? '0';
        double stackSize = 0.0;
        try {
          stackSize = double.parse(stackText);
        } catch (e) {
          stackSize = widget.startingStack ?? (widget.isCashGame ? 100.0 : 1500.0);
        }
        playerStacks[seat] = stackSize;
        widget.sessionManager?.setPlayerStack(seat, stackSize);
      } else {
        widget.sessionManager?.removePlayer(seat);
      }
    }

    if (widget.sessionName != null && widget.smallBlind != null && widget.bigBlind != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PokerHandScreen(
            smallBlind: widget.smallBlind!,
            bigBlind: widget.bigBlind!,
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
      Navigator.pop(context, {
        'seat': selectedSeat,
        'buttonPosition': selectedButtonPosition ?? widget.buttonPosition,
        'playerStacks': playerStacks,
        'isCashGame': widget.isCashGame,
      });
    }
  }
}
