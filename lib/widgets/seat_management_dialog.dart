import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/hand_state_machine.dart';
import '../utils/poker_positions.dart';
import '../services/auth_service.dart';
import '../services/currency_service.dart';
import '../services/free_tier_limits.dart';
import '../services/opponent_service.dart';
import '../models/opponent.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';
import '../utils/user_facing_error.dart';

class SeatManagementDialog extends StatefulWidget {
  final int playerCount;
  final int buttonPosition;
  final int? currentSeat;
  final PokerSessionManager sessionManager;
  final bool isInitialSetup;
  final bool isCashGame;

  const SeatManagementDialog({
    Key? key,
    required this.playerCount,
    required this.buttonPosition,
    this.currentSeat,
    required this.sessionManager,
    this.isInitialSetup = true,
    this.isCashGame = true,
  }) : super(key: key);

  @override
  _SeatManagementDialogState createState() => _SeatManagementDialogState();
}

class _SeatManagementDialogState extends State<SeatManagementDialog> {
  int? selectedSeat;
  int? selectedButtonPosition;
  Map<int, TextEditingController> nameControllers = {};
  Map<int, TextEditingController> stackControllers = {};
  Map<int, bool> seatActive = {};
  List<Opponent> allOpponents = [];
  Map<int, bool> showSaveOpponentTip = {};

  @override
  void initState() {
    super.initState();
    selectedSeat = widget.currentSeat;
    selectedButtonPosition = widget.buttonPosition;
    
    // If this is initial setup, initialize default players FIRST
    if (widget.isInitialSetup) {
      widget.sessionManager.initializeDefaultPlayers();
    }

    // Always initialize 9 seats regardless of player count
    for (int i = 1; i <= 9; i++) {
      // First determine active status
      if (widget.isInitialSetup) {
        // For initial setup, activate only up to playerCount seats
        seatActive[i] = i <= widget.playerCount;
      } else {
        seatActive[i] = widget.sessionManager.isPlayerActive(i);
      }

      // Then initialize controllers based on active status
      if (seatActive[i] == true) {
        nameControllers[i] = TextEditingController(
          text: widget.sessionManager.getPlayerName(i)
        );

        // Initialize stack from sessionManager if available
        final stack = widget.sessionManager.getPlayerStack(i);
        if (stack != null) {
          stackControllers[i] = TextEditingController(
            text: widget.isCashGame ? stack.toStringAsFixed(2) : stack.toInt().toString()
          );
        } else {
          stackControllers[i] = TextEditingController(
            text: widget.isCashGame ? '100.00' : '1500'
          );
        }
      } else {
        nameControllers[i] = TextEditingController(text: '');
        stackControllers[i] = TextEditingController(
          text: widget.isCashGame ? '100.00' : '1500'
        );
      }
    }
    
    // Load opponents for autocomplete
    _loadOpponents();
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
      setState(() {
        allOpponents = opponents;
      });
    } catch (e) {
      debugPrint('Failed to load opponents: $e');
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

  void _showSaveOpponentDialog(int seatNumber, String name) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant1,
            borderRadius: BorderRadius.circular(AppDecorations.radius20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant2,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(AppDecorations.radius20),
                    topRight: Radius.circular(AppDecorations.radius20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.profitGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppDecorations.radius10),
                      ),
                      child: Icon(
                        Icons.person_add,
                        color: AppColors.profitGreen,
                        size: 18,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      AppLocalizations.of(context).seatManagementSaveOpponentTitle,
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
                child: Text(
                  AppLocalizations.of(context).seatManagementSaveOpponentMessage(name),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
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
                          color: AppColors.surfaceVariant2,
                          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                        ),
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() {
                              showSaveOpponentTip[seatNumber] = false;
                            });
                          },
                          child: Text(
                            AppLocalizations.of(context).seatManagementNotNow,
                            style: TextStyle(
                              color: AppColors.textMuted,
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
                            colors: [AppColors.profitGreen, Color(0xFF4CAF50)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                        ),
                        child: ElevatedButton(
                          onPressed: () async {
                            // Free-tier gate: enforce opponent profile cap.
                            if (!FreeTierLimits.canCreateAnotherOpponent(
                              allOpponents.length,
                            )) {
                              Navigator.pop(context);
                              await FreeTierLimits.showOpponentLimitDialog(
                                context,
                              );
                              return;
                            }
                            try {
                              final sMessenger = ScaffoldMessenger.of(context);
                              final sL10n = AppLocalizations.of(context);
                              final existingOpp = await OpponentService.findOpponentByName(name);
                              if (existingOpp != null) {
                                Navigator.pop(context);
                                sMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(sL10n.opponentAlreadyExists(name)),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              final opponent = OpponentService.createNewOpponent(name: name);
                              await OpponentService.saveOpponent(opponent);
                              await _loadOpponents(); // Refresh the list
                              
                              Navigator.pop(context);
                              setState(() {
                                showSaveOpponentTip[seatNumber] = false;
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(AppLocalizations.of(context).seatManagementOpponentSavedSuccess(name)),
                                  backgroundColor: AppColors.profitGreen,
                                ),
                              );
                            } catch (e) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(AppLocalizations.of(context).seatManagementFailedToSaveOpponent(UserFacingError.message(e))),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.of(context).commonSave,
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
    );
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
    if (!activeSeats.contains(seatNumber)) return AppLocalizations.of(context).seatManagementEmpty;

    // Calculate position based on active players only
    final buttonPos = selectedButtonPosition ?? widget.buttonPosition;
    final activePlayerCount = activeSeats.length;

    // Check if this is the button
    if (seatNumber == buttonPos) {
      return 'BTN';
    }

    // For heads-up
    if (activePlayerCount == 2) {
      if (seatNumber == buttonPos) {
        return 'BTN/SB';
      } else {
        return 'BB';
      }
    }

    // Find SB and BB positions among active players
    int sbSeat = buttonPos;
    int bbSeat = buttonPos;

    // Find next active player for SB
    int position = buttonPos;
    for (int i = 0; i < 9; i++) {
      position = (position % 9) + 1;
      if (activeSeats.contains(position)) {
        sbSeat = position;
        break;
      }
    }

    // Find next active player for BB
    position = sbSeat;
    for (int i = 0; i < 9; i++) {
      position = (position % 9) + 1;
      if (activeSeats.contains(position)) {
        bbSeat = position;
        break;
      }
    }

    if (seatNumber == sbSeat) {
      return 'SB';
    }
    if (seatNumber == bbSeat) {
      return 'BB';
    }

    // Calculate relative position among active players
    activeSeats.sort();
    int activeButtonIndex = activeSeats.indexOf(buttonPos);
    int activePlayerIndex = activeSeats.indexOf(seatNumber);
    int relativePosition = (activePlayerIndex - activeButtonIndex + activePlayerCount) % activePlayerCount;

    return PokerPositions.getPositionName(relativePosition + 1, 1, activePlayerCount);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(20),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 420,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant1,
          borderRadius: BorderRadius.circular(AppDecorations.radiusXl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant2,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppDecorations.radiusXl),
                  topRight: Radius.circular(AppDecorations.radiusXl),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.profitGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                    ),
                    child: Icon(
                      Icons.group_outlined,
                      color: AppColors.profitGreen,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isInitialSetup ? l10n.seatManagementSetupSeats : l10n.seatManagementManagePlayers,
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.isInitialSetup
                              ? l10n.seatManagementChooseSeatSubtitle
                              : l10n.seatManagementUpdatePlayerSubtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Container(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.isInitialSetup) ...[
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant2,
                          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.casino_outlined,
                                  color: AppColors.profitGreen,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  l10n.seatManagementButtonPosition,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: List.generate(9, (index) {
                                  final seatNum = index + 1;
                                  final isSelected = selectedButtonPosition == seatNum;
                                  final isActive = seatActive[seatNum] ?? false;
                                  return GestureDetector(
                                    onTap: isActive ? () => setState(() {
                                      selectedButtonPosition = seatNum;
                                      _updatePlayerNamesForButtonChange();
                                    }) : null,
                                    child: Container(
                                      margin: EdgeInsets.only(right: 12),
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: !isActive
                                            ? Color(0xFF0A0A0C)
                                            : isSelected
                                            ? AppColors.profitGreen
                                            : AppColors.surfaceVariant1,
                                        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                                        border: Border.all(
                                          color: !isActive
                                              ? AppColors.surfaceVariant4
                                              : isSelected
                                              ? AppColors.profitGreen
                                              : AppColors.surfaceVariant3,
                                          width: 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$seatNum',
                                          style: TextStyle(
                                            color: isActive ? Colors.white : Color(0xFF4A4A4E),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                    ],
                    Expanded(
                      child: ListView.builder(
                        itemCount: 9,
                        itemBuilder: (context, index) {
                          final seatNumber = index + 1;
                          final isButtonSeat = seatNumber == (selectedButtonPosition ?? widget.buttonPosition);
                          final isSelected = selectedSeat == seatNumber;
                          final isActive = seatActive[seatNumber] ?? false;
                          
                          return Container(
                            margin: EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? AppColors.profitGreen.withOpacity(0.1)
                                  : AppColors.surfaceVariant2,
                              borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
                              border: isSelected 
                                  ? Border.all(color: AppColors.profitGreen, width: 1)
                                  : null,
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  // Seat header with selection and status
                                  Row(
                                    children: [
                                      // Seat selection (only for initial setup)
                                      if (widget.isInitialSetup)
                                        Container(
                                          width: 24,
                                          height: 24,
                                          margin: EdgeInsets.only(right: 12),
                                          decoration: BoxDecoration(
                                            color: isSelected ? AppColors.profitGreen : AppColors.surfaceVariant1,
                                            borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                                            border: Border.all(
                                              color: isSelected ? AppColors.profitGreen : AppColors.surfaceVariant3,
                                            ),
                                          ),
                                          child: InkWell(
                                            onTap: () {
                                              setState(() {
                                                selectedSeat = seatNumber;
                                                _autoInsertUsernameForSeat(seatNumber);
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                                            child: Center(
                                              child: isSelected 
                                                  ? Icon(Icons.check, color: Colors.white, size: 16)
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      // Seat info
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      l10n.seatManagementSeatLabel(seatNumber),
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    if (isButtonSeat) ...[
                                                      SizedBox(width: 8),
                                                      Container(
                                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: Colors.orange,
                                                          borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
                                                        ),
                                                        child: Text(
                                                          'BTN',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                SizedBox(height: 2),
                                                Text(
                                                  isActive ? _getPositionForActiveSeat(seatNumber) : l10n.seatManagementEmpty,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.textMuted,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Active toggle
                                      Column(
                                        children: [
                                          Switch(
                                            value: isActive,
                                            activeColor: AppColors.profitGreen,
                                            inactiveThumbColor: Colors.white,
                                            inactiveTrackColor: AppColors.surfaceVariant3,
                                            onChanged: (value) {
                                              setState(() {
                                                seatActive[seatNumber] = value;
                                                if (value) {
                                                  // When activating a seat, check if it needs to be reset to defaults
                                                  final currentName = widget.sessionManager.getPlayerName(seatNumber);
                                                  if (currentName == 'Player $seatNumber') {
                                                    // Seat was reset (player left), use defaults
                                                    nameControllers[seatNumber]!.text = 'Player $seatNumber';
                                                    stackControllers[seatNumber]!.text = widget.isCashGame ? '100.00' : '1500';
                                                  } else {
                                                    // Seat still has player data, keep it
                                                    nameControllers[seatNumber]!.text = currentName;
                                                    final stack = widget.sessionManager.getPlayerStack(seatNumber);
                                                    if (stack != null) {
                                                      stackControllers[seatNumber]!.text = widget.isCashGame
                                                        ? stack.toStringAsFixed(2)
                                                        : stack.toInt().toString();
                                                    } else {
                                                      stackControllers[seatNumber]!.text = widget.isCashGame ? '100.00' : '1500';
                                                    }
                                                  }
                                                }
                                              });
                                            },
                                          ),
                                          Text(
                                            isActive ? l10n.seatManagementActive : l10n.seatManagementEmpty,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isActive ? AppColors.profitGreen : AppColors.textMuted,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  // Player name input (only if active)
                                  if (isActive) ...[
                                    SizedBox(height: 16),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Autocomplete<String>(
                                          initialValue: TextEditingValue(text: nameControllers[seatNumber]!.text),
                                          optionsBuilder: (TextEditingValue textEditingValue) {
                                            return _getSuggestions(textEditingValue.text);
                                          },
                                          onSelected: (String selection) {
                                            nameControllers[seatNumber]!.text = selection;
                                            widget.sessionManager.setPlayerName(seatNumber, selection);
                                            _checkIfShouldShowSaveTip(seatNumber, selection);
                                          },
                                          fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                                            // Sync with our original controller
                                            if (controller.text != nameControllers[seatNumber]!.text) {
                                              controller.text = nameControllers[seatNumber]!.text;
                                            }
                                            
                                            return Container(
                                              decoration: BoxDecoration(
                                                color: AppColors.surfaceVariant1,
                                                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                                                border: Border.all(color: AppColors.surfaceVariant3),
                                              ),
                                              child: TextField(
                                                controller: controller,
                                                focusNode: focusNode,
                                                onEditingComplete: onEditingComplete,
                                                style: TextStyle(color: Colors.white, fontSize: 16),
                                                decoration: InputDecoration(
                                                  labelText: l10n.seatManagementPlayerNameLabel,
                                                  labelStyle: TextStyle(color: AppColors.textMuted),
                                                  hintText: l10n.seatManagementEnterPlayerName,
                                                  hintStyle: TextStyle(color: AppColors.textMuted),
                                                  border: InputBorder.none,
                                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                  suffixIcon: allOpponents.isNotEmpty 
                                                      ? Icon(Icons.search, size: 18, color: AppColors.textMuted) 
                                                      : null,
                                                ),
                                                textCapitalization: TextCapitalization.words,
                                                onChanged: (value) {
                                                  // Update our original controller
                                                  nameControllers[seatNumber]!.text = value;
                                                  // Auto-update the session manager
                                                  widget.sessionManager.setPlayerName(seatNumber, value);
                                                  // Check if we should show save tip
                                                  _checkIfShouldShowSaveTip(seatNumber, value);
                                                },
                                              ),
                                            );
                                          },
                                          optionsViewBuilder: (context, onSelected, options) {
                                            return Align(
                                              alignment: Alignment.topLeft,
                                              child: Material(
                                                elevation: 8,
                                                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                                                color: AppColors.surfaceVariant2,
                                                child: Container(
                                                  constraints: BoxConstraints(maxHeight: 200, maxWidth: 300),
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                                                    border: Border.all(color: AppColors.surfaceVariant3),
                                                  ),
                                                  child: ListView.builder(
                                                    padding: EdgeInsets.all(8),
                                                    shrinkWrap: true,
                                                    itemCount: options.length,
                                                    itemBuilder: (context, index) {
                                                      final option = options.elementAt(index);
                                                      final opponent = allOpponents.firstWhere(
                                                        (o) => o.name == option,
                                                        orElse: () => Opponent(
                                                          id: '',
                                                          name: option,
                                                          notes: '',
                                                          createdAt: DateTime.now(),
                                                          lastSeenAt: DateTime.now(),
                                                        ),
                                                      );
                                                      
                                                      return Container(
                                                        margin: EdgeInsets.only(bottom: 4),
                                                        decoration: BoxDecoration(
                                                          color: AppColors.surfaceVariant1,
                                                          borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
                                                        ),
                                                        child: ListTile(
                                                          dense: true,
                                                          title: Text(
                                                            option,
                                                            style: TextStyle(color: Colors.white, fontSize: 14),
                                                          ),
                                                          subtitle: opponent.notes != null && opponent.notes!.isNotEmpty
                                                              ? Text(
                                                                  opponent.notes!,
                                                                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                )
                                                              : null,
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
                                            onTap: () => _showSaveOpponentDialog(seatNumber, nameControllers[seatNumber]!.text),
                                            child: Container(
                                              padding: EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: AppColors.profitGreen.withOpacity(0.1),
                                                border: Border.all(color: AppColors.profitGreen.withOpacity(0.3)),
                                                borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.person_add, size: 16, color: AppColors.profitGreen),
                                                  SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      l10n.seatManagementSaveAsOpponentPrompt(nameControllers[seatNumber]!.text),
                                                      style: TextStyle(fontSize: 12, color: AppColors.profitGreen),
                                                    ),
                                                  ),
                                                  Icon(Icons.arrow_forward, size: 16, color: AppColors.profitGreen),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                        
                                        // Stack size input
                                        SizedBox(height: 16),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceVariant1,
                                            borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                                            border: Border.all(color: AppColors.surfaceVariant3),
                                          ),
                                          child: TextField(
                                            controller: stackControllers[seatNumber],
                                            keyboardType: TextInputType.numberWithOptions(decimal: widget.isCashGame),
                                            style: TextStyle(color: Colors.white, fontSize: 16),
                                            decoration: InputDecoration(
                                              labelText: widget.isCashGame ? l10n.seatManagementBuyInAmountCash : l10n.seatManagementStartingChips,
                                              labelStyle: TextStyle(color: AppColors.textMuted),
                                              hintText: widget.isCashGame ? '100.00' : '1500',
                                              hintStyle: TextStyle(color: AppColors.textMuted),
                                              prefixText: widget.isCashGame ? CurrencyService.prefixText : '',
                                              suffixText: widget.isCashGame ? CurrencyService.suffixText : null,
                                              prefixStyle: TextStyle(color: AppColors.textMuted),
                                              suffixStyle: TextStyle(color: AppColors.textMuted),
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            ),
                                            onChanged: (value) {
                                              // Validate input format
                                              if (widget.isCashGame) {
                                                // For cash games, ensure decimal format
                                                if (value.isNotEmpty && !RegExp(r'^\d*\.?\d{0,2}$').hasMatch(value)) {
                                                  // Reset to previous valid value
                                                  stackControllers[seatNumber]!.text = stackControllers[seatNumber]!.text.substring(0, stackControllers[seatNumber]!.text.length - 1);
                                                  stackControllers[seatNumber]!.selection = TextSelection.fromPosition(TextPosition(offset: stackControllers[seatNumber]!.text.length));
                                                }
                                              } else {
                                                // For tournaments, ensure integer format
                                                if (value.isNotEmpty && !RegExp(r'^\d+$').hasMatch(value)) {
                                                  // Reset to previous valid value
                                                  stackControllers[seatNumber]!.text = stackControllers[seatNumber]!.text.substring(0, stackControllers[seatNumber]!.text.length - 1);
                                                  stackControllers[seatNumber]!.selection = TextSelection.fromPosition(TextPosition(offset: stackControllers[seatNumber]!.text.length));
                                                }
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
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
            // Actions
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant2,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(AppDecorations.radiusXl),
                  bottomRight: Radius.circular(AppDecorations.radiusXl),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant1,
                        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                        border: Border.all(color: AppColors.surfaceVariant3),
                      ),
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                          ),
                        ),
                        child: Text(
                          l10n.commonCancel,
                          style: TextStyle(
                            color: AppColors.textMuted,
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
                          colors: [AppColors.profitGreen, Color(0xFF4CAF50)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                      ),
                      child: ElevatedButton(
                        onPressed: _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                          ),
                        ),
                        child: Text(
                          widget.isInitialSetup ? l10n.seatManagementStartSession : l10n.seatManagementSaveChanges,
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

  void _updatePlayerNamesForButtonChange() {
    // Player names don't need to change when button position changes
    // Position labels are shown separately and calculated dynamically
    // Player names remain as "Player X" or custom names
  }

  void _autoInsertUsernameForSeat(int seatNumber) {
    // Auto-insert the current user's display name for their selected seat
    final userName = AuthService.userDisplayName;
    final controller = nameControllers[seatNumber];
    
    if (controller != null && userName.isNotEmpty) {
      controller.text = userName;
      // Make sure the seat is active
      seatActive[seatNumber] = true;
      widget.sessionManager.setPlayerName(seatNumber, userName);
    }
  }

  void _saveChanges() {
    // For initial setup, ensure a seat is selected
    if (widget.isInitialSetup && selectedSeat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).seatManagementSelectYourSeat),
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
        widget.sessionManager.addPlayer(seat, name);
        
        // Parse and store stack size
        final stackText = stackControllers[seat]?.text ?? '0';
        double stackSize = 0.0;
        try {
          stackSize = double.parse(stackText);
        } catch (e) {
          stackSize = widget.isCashGame ? 100.0 : 1500.0; // Default values
        }
        playerStacks[seat] = stackSize;
      } else {
        widget.sessionManager.removePlayer(seat);
      }
    }

    // Return the selected seat, button position, and stack sizes for initial setup
    Navigator.pop(context, {
      'seat': selectedSeat,
      'buttonPosition': selectedButtonPosition ?? widget.buttonPosition,
      'playerStacks': playerStacks,
      'isCashGame': widget.isCashGame,
    });
  }
}