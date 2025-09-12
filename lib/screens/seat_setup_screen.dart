import 'package:flutter/material.dart';
import '../models/hand_state_machine.dart';
import '../utils/poker_positions.dart';
import '../services/auth_service.dart';
import '../services/opponent_service.dart';
import '../models/opponent.dart';

class SeatSetupScreen extends StatefulWidget {
  final int playerCount;
  final int buttonPosition;
  final int? currentSeat;
  final PokerSessionManager sessionManager;
  final bool isInitialSetup;
  final bool isCashGame;

  const SeatSetupScreen({
    Key? key,
    required this.playerCount,
    required this.buttonPosition,
    this.currentSeat,
    required this.sessionManager,
    this.isInitialSetup = true,
    this.isCashGame = true,
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
  Map<int, bool> showSaveOpponentTip = {};

  @override
  void initState() {
    super.initState();
    selectedSeat = widget.currentSeat;
    selectedButtonPosition = widget.buttonPosition;
    
    // Initialize controllers and seat states
    for (int i = 1; i <= widget.playerCount; i++) {
      nameControllers[i] = TextEditingController(
        text: widget.sessionManager.getPlayerName(i)
      );
      stackControllers[i] = TextEditingController(
        text: widget.isCashGame ? '100.00' : '1500'
      );
      seatActive[i] = widget.isInitialSetup ? true : widget.sessionManager.isPlayerActive(i);
    }
    
    // If this is initial setup, initialize default players
    if (widget.isInitialSetup) {
      widget.sessionManager.initializeDefaultPlayers();
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

  void _showSaveOpponentDialog(int seatNumber, String name) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                        Icons.person_add,
                        color: Color(0xFFcb5242),
                        size: 18,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Save Opponent?',
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
                  'Would you like to save "$name" to your opponents list for future tracking?',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF9A9A9A),
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
                          color: Color(0xFF1F1F23),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() {
                              showSaveOpponentTip[seatNumber] = false;
                            });
                          },
                          child: Text(
                            'Not Now',
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
                          onPressed: () async {
                            try {
                              final opponent = OpponentService.createNewOpponent(name: name);
                              await OpponentService.saveOpponent(opponent);
                              await _loadOpponents(); // Refresh the list
                              
                              Navigator.pop(context);
                              setState(() {
                                showSaveOpponentTip[seatNumber] = false;
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Opponent "$name" saved successfully!'),
                                  backgroundColor: Color(0xFFcb5242),
                                ),
                              );
                            } catch (e) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to save opponent: $e'),
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
                            'Save',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF161618),
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
                              ? 'Choose your seat and configure table' 
                              : 'Update player information',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9A9A9A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.isInitialSetup) ...[
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Color(0xFF1F1F23),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.casino_outlined,
                                  color: Color(0xFFcb5242),
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Button Position',
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
                                children: List.generate(widget.playerCount, (index) {
                                  final seatNum = index + 1;
                                  final isSelected = selectedButtonPosition == seatNum;
                                  return GestureDetector(
                                    onTap: () => setState(() {
                                      selectedButtonPosition = seatNum;
                                      _updatePlayerNamesForButtonChange();
                                    }),
                                    child: Container(
                                      margin: EdgeInsets.only(right: 12),
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: isSelected 
                                            ? Color(0xFFcb5242)
                                            : Color(0xFF161618),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected 
                                              ? Color(0xFFcb5242)
                                              : Color(0xFF2A2A2E),
                                          width: 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$seatNum',
                                          style: TextStyle(
                                            color: Colors.white,
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
                    
                    // Player seats
                    ...List.generate(widget.playerCount, (index) {
                      final seatNumber = index + 1;
                      final isButtonSeat = seatNumber == (selectedButtonPosition ?? widget.buttonPosition);
                      final isSelected = selectedSeat == seatNumber;
                      final isActive = seatActive[seatNumber] ?? false;
                      
                      return Container(
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? Color(0xFFcb5242).withOpacity(0.1)
                              : Color(0xFF1F1F23),
                          borderRadius: BorderRadius.circular(16),
                          border: isSelected 
                              ? Border.all(color: Color(0xFFcb5242), width: 1)
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
                                        color: isSelected ? Color(0xFFcb5242) : Color(0xFF161618),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected ? Color(0xFFcb5242) : Color(0xFF2A2A2E),
                                        ),
                                      ),
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            selectedSeat = seatNumber;
                                            _autoInsertUsernameForSeat(seatNumber);
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(12),
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
                                                  'Seat $seatNumber',
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
                                                      borderRadius: BorderRadius.circular(8),
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
                                              PokerPositions.getPositionName(seatNumber, selectedButtonPosition ?? widget.buttonPosition, widget.playerCount),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF9A9A9A),
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
                                        activeColor: Color(0xFFcb5242),
                                        inactiveThumbColor: Colors.white,
                                        inactiveTrackColor: Color(0xFF2A2A2E),
                                        onChanged: (value) {
                                          setState(() {
                                            seatActive[seatNumber] = value;
                                            if (value) {
                                              if (nameControllers[seatNumber]!.text.isEmpty) {
                                                final positionName = PokerPositions.getPositionName(
                                                  seatNumber, 
                                                  selectedButtonPosition ?? widget.buttonPosition, 
                                                  widget.playerCount
                                                );
                                                nameControllers[seatNumber]!.text = positionName;
                                              }
                                            }
                                          });
                                        },
                                      ),
                                      Text(
                                        isActive ? 'Active' : 'Empty',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isActive ? Color(0xFFcb5242) : Color(0xFF9A9A9A),
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
                                            color: Color(0xFF161618),
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
                                                        opponent.playingStyle, 
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
                                        onTap: () => _showSaveOpponentDialog(seatNumber, nameControllers[seatNumber]!.text),
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
                                        color: Color(0xFF161618),
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
                    }),
                  ],
                ),
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

  void _updatePlayerNamesForButtonChange() {
    // Update position names for players who haven't been given custom names
    for (int seat = 1; seat <= widget.playerCount; seat++) {
      final controller = nameControllers[seat];
      if (controller != null && seatActive[seat] == true) {
        final currentText = controller.text;
        final currentButtonPos = selectedButtonPosition ?? widget.buttonPosition;
        
        // Check if the current text is a position name (not a custom name)
        final expectedPositionName = PokerPositions.getPositionName(seat, widget.buttonPosition, widget.playerCount);
        final newPositionName = PokerPositions.getPositionName(seat, currentButtonPos, widget.playerCount);
        
        // If current text matches the old position name, update it to new position name
        if (currentText == expectedPositionName || currentText.isEmpty) {
          controller.text = newPositionName;
          widget.sessionManager.setPlayerName(seat, newPositionName);
        }
      }
    }
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
          content: Text('Please select your seat'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Update all player names and active status
    Map<int, double> playerStacks = {};
    
    for (int seat = 1; seat <= widget.playerCount; seat++) {
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