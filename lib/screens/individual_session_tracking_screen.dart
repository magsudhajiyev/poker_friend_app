import 'package:flutter/material.dart';
import 'dart:async';
import '../design_system/poker_friend_theme.dart';
import '../models/game_types.dart';
import '../services/firebase_service.dart';
import 'poker_hand_screen.dart';

class IndividualSessionTrackingScreen extends StatefulWidget {
  final String sessionName;
  final double buyInAmount;
  final double startingStack;
  final GameType gameType;
  final int smallBlind;
  final int bigBlind;
  final bool hasBBante;

  // Optional parameters for when returning from hand tracking
  final double? currentStack;
  final String? sessionId;

  const IndividualSessionTrackingScreen({
    super.key,
    required this.sessionName,
    required this.buyInAmount,
    required this.startingStack,
    required this.gameType,
    required this.smallBlind,
    required this.bigBlind,
    required this.hasBBante,
    this.currentStack,
    this.sessionId,
  });

  @override
  State<IndividualSessionTrackingScreen> createState() => _IndividualSessionTrackingScreenState();
}

class _IndividualSessionTrackingScreenState extends State<IndividualSessionTrackingScreen> {
  // Session management
  String? _sessionId;

  // Stack management
  late double _currentStack;
  late double _initialStack;

  // Timer management
  Timer? _timer;
  Duration _sessionDuration = Duration.zero;
  DateTime? _sessionStartTime;

  // Stats
  int _handsLogged = 0;
  double _biggestPot = 0.0;

  // Rebuy tracking
  List<Map<String, dynamic>> _rebuys = [];
  double _totalBuyIn = 0.0;
  List<Map<String, dynamic>> _stackHistory = [];

  // Current blinds (can be updated during session)
  int _currentSmallBlind = 0;
  int _currentBigBlind = 0;
  bool _currentHasBBante = false;

  // Display mode
  bool _showBBMode = false;

  @override
  void initState() {
    super.initState();
    _currentStack = widget.currentStack ?? widget.startingStack;
    _initialStack = widget.startingStack;
    _sessionId = widget.sessionId;

    // Initialize rebuy tracking
    _totalBuyIn = widget.buyInAmount; // Start with initial buy-in

    // Add initial stack to history
    _stackHistory.add({
      'timestamp': DateTime.now().toIso8601String(),
      'stackSize': _currentStack,
      'changeType': 'initial',
      'changeAmount': widget.buyInAmount,
    });

    // Initialize current blinds with widget values
    _currentSmallBlind = widget.smallBlind;
    _currentBigBlind = widget.bigBlind;
    _currentHasBBante = widget.hasBBante;

    if (_sessionId == null) {
      _initializeSession();
    } else {
      _resumeSession();
    }

    _startTimer();
  }

  Future<void> _initializeSession() async {
    // Create a new session in Firebase
    _sessionStartTime = DateTime.now();

    try {
      // Create session in Firebase
      final sessionId = await FirebaseService.createSession(
        smallBlind: widget.smallBlind,
        bigBlind: widget.bigBlind,
        playerCount: 6, // Default for individual sessions
        gameType: widget.gameType,
        isIndividualSession: true,
        sessionName: widget.sessionName,
        startingStack: widget.startingStack,
        hasBBante: widget.hasBBante,
      );

      setState(() {
        _sessionId = sessionId;
      });

    } catch (e) {
      print('Error creating individual session: $e');
      // Fallback to local session ID
      setState(() {
        _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      });
    }
  }

  Future<void> _resumeSession() async {
    // Resume existing session
    // TODO: Load session data from Firebase
    if (_sessionStartTime == null) {
      _sessionStartTime = DateTime.now();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_sessionStartTime != null) {
          _sessionDuration = DateTime.now().difference(_sessionStartTime!);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Calculate stack growth percentage
  double get stackGrowthPercentage {
    if (_initialStack == 0) return 0;
    return ((_currentStack - _initialStack) / _initialStack) * 100;
  }


  // Get color based on stack performance
  Color get stackColor {
    if (_currentStack == _initialStack) {
      return PokerFriendColors.dark9; // Gray for initial/no change
    } else if (_currentStack > _initialStack) {
      return Colors.green; // Green for profit
    } else {
      return PokerFriendColors.red; // Red for loss
    }
  }

  // Format duration
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  // Format stack value based on display mode
  String _formatStackValue(double value) {
    if (_showBBMode && _currentBigBlind > 0) {
      final bbValue = value / _currentBigBlind;
      return '${bbValue.toStringAsFixed(1)} BB';
    } else {
      return widget.gameType == GameType.cash
          ? '\$${value.toStringAsFixed(2)}'
          : value.toStringAsFixed(0);
    }
  }




  // Manual stack update dialog
  Future<void> _showUpdateStackDialog() async {
    final controller = TextEditingController(text: _currentStack.toString());

    final newStack = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PokerFriendColors.dark3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Update Current Stack',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: TextStyle(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            hintText: 'Enter current stack',
            hintStyle: TextStyle(color: PokerFriendColors.dark9),
            prefixText: widget.gameType == GameType.cash ? '\$ ' : '',
            prefixStyle: TextStyle(color: Colors.white, fontSize: 18),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: PokerFriendColors.red),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: PokerFriendColors.red, width: 2),
            ),
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
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              Navigator.pop(context, value);
            },
            child: Text(
              'Update',
              style: TextStyle(color: PokerFriendColors.red),
            ),
          ),
        ],
      ),
    );

    if (newStack != null && newStack >= 0) {
      setState(() {
        _currentStack = newStack;
      });

      // Update session in Firebase
      if (_sessionId != null) {
        FirebaseService.updateIndividualSession(
          sessionId: _sessionId!,
          currentStack: _currentStack,
        ).catchError((e) {});
      }
    }
  }

  // Update blinds dialog
  Future<void> _showUpdateBlindsDialog() async {
    final smallBlindController = TextEditingController(text: _currentSmallBlind.toString());
    final bigBlindController = TextEditingController(text: _currentBigBlind.toString());
    bool tempHasBBante = _currentHasBBante;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
        backgroundColor: PokerFriendColors.dark3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Update Blinds',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: smallBlindController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: Colors.white, fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Small Blind',
                labelStyle: TextStyle(color: PokerFriendColors.dark9),
                hintStyle: TextStyle(color: PokerFriendColors.dark9),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: PokerFriendColors.red),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: PokerFriendColors.red, width: 2),
                ),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: bigBlindController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: Colors.white, fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Big Blind',
                labelStyle: TextStyle(color: PokerFriendColors.dark9),
                hintStyle: TextStyle(color: PokerFriendColors.dark9),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: PokerFriendColors.red),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: PokerFriendColors.red, width: 2),
                ),
              ),
            ),
            // Ante switch only for tournaments
            if (widget.gameType == GameType.tournament) ...[
              SizedBox(height: 16),
              Row(
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
                    value: tempHasBBante,
                    onChanged: (value) => setState(() => tempHasBBante = value),
                    activeColor: PokerFriendColors.red,
                  ),
                ],
              ),
            ],
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
          TextButton(
            onPressed: () {
              final smallBlind = int.tryParse(smallBlindController.text);
              final bigBlind = int.tryParse(bigBlindController.text);

              if (smallBlind != null && bigBlind != null &&
                  smallBlind > 0 && bigBlind > smallBlind) {
                Navigator.pop(context, {
                  'smallBlind': smallBlind,
                  'bigBlind': bigBlind,
                  'hasBBante': tempHasBBante,
                });
              }
            },
            child: Text(
              'Update',
              style: TextStyle(color: PokerFriendColors.red),
            ),
          ),
        ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _currentSmallBlind = result['smallBlind']!;
        _currentBigBlind = result['bigBlind']!;
        _currentHasBBante = result['hasBBante']!;
      });

      // Update session in Firebase with new blinds
      if (_sessionId != null) {
        FirebaseService.updateIndividualSession(
          sessionId: _sessionId!,
          smallBlind: _currentSmallBlind,
          bigBlind: _currentBigBlind,
          hasBBante: _currentHasBBante,
        ).catchError((e) {});
      }
    }
  }

  // Navigate to hand logging
  Future<void> _logHand() async {
    // Navigate to PokerHandScreen with individual session context
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => PokerHandScreen(
          smallBlind: _currentSmallBlind,
          bigBlind: _currentBigBlind,
          levelDuration: 15, // Default for individual sessions
          numberOfPlayers: 6, // Default active players
          gameType: widget.gameType,
          hasBBante: _currentHasBBante,
          ante: _currentHasBBante ? _currentBigBlind : 0,
          isIndividualSession: true,
          individualCurrentStack: _currentStack,
          individualSessionId: _sessionId,
        ),
      ),
    );

    if (result != null && result['completed'] == true) {
      // Hand was completed, update our stack
      final newStack = result['finalStack'] as double?;
      if (newStack != null) {
        setState(() {
          _currentStack = newStack;
          _handsLogged++;
          // Update biggest pot if applicable
          final potSize = result['potSize'] as double?;
          if (potSize != null && potSize > _biggestPot) {
            _biggestPot = potSize;
          }
        });

        // Update session in Firebase
        if (_sessionId != null) {
          FirebaseService.updateIndividualSession(
            sessionId: _sessionId!,
            currentStack: _currentStack,
            handsLogged: _handsLogged,
            biggestPot: _biggestPot,
          ).catchError((e) {});
        }
      }
    }
  }

  // Stop session
  Future<void> _stopSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PokerFriendColors.dark3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'End Session?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to end this session?',
          style: TextStyle(
            color: PokerFriendColors.dark10,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: PokerFriendColors.dark9),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'End Session',
              style: TextStyle(color: PokerFriendColors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Save final session data
      if (_sessionId != null) {
        try {
          // End the session in Firebase
          await FirebaseService.endSession(_sessionId!);

          // Also update the session status to completed
          await FirebaseService.updateIndividualSession(
            sessionId: _sessionId!,
            sessionStatus: 'completed',
            currentStack: _currentStack,
            handsLogged: _handsLogged,
            biggestPot: _biggestPot,
          );

        } catch (e) {
        }
      }

      // Navigate back to home
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  // Rebuy dialog - handles both Cash and MTT differently
  Future<void> _showRebuyDialog() async {
    final rebuyAmountController = TextEditingController();
    final stackSizeController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
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
                widget.gameType == GameType.cash
                    ? 'Enter rebuy amount (stack will equal rebuy amount)'
                    : 'Enter rebuy amount and new stack size',
                style: TextStyle(
                  color: PokerFriendColors.dark10,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 20),

              // Rebuy Amount Input (always shown)
              TextField(
                controller: rebuyAmountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
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

              // Stack Size Input (only for MTT)
              if (widget.gameType == GameType.tournament) ...[
                SizedBox(height: 16),
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
              ],

              SizedBox(height: 20),

              // Current session info
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PokerFriendColors.dark4,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: PokerFriendColors.dark6, width: 1),
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
                      'Total Invested: \$${_totalBuyIn.toStringAsFixed(2)}',
                      style: TextStyle(color: PokerFriendColors.dark10, fontSize: 12),
                    ),
                    Text(
                      'Current Stack: ${_formatStackValue(_currentStack)}',
                      style: TextStyle(color: PokerFriendColors.dark10, fontSize: 12),
                    ),
                    Text(
                      'Rebuys: ${_rebuys.length}',
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
            onPressed: () => Navigator.pop(context),
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

              // Validate inputs first
              if (rebuyAmount == null || rebuyAmount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please enter a valid rebuy amount'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (widget.gameType == GameType.cash) {
                // Cash game: rebuy amount = stack size
                Navigator.pop(context, {
                  'rebuyAmount': rebuyAmount,
                  'newStack': rebuyAmount, // For cash, stack equals rebuy amount
                });
              } else {
                // MTT: need both rebuy amount and stack size
                final stackSize = double.tryParse(stackSizeController.text);
                if (stackSize == null || stackSize <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter a valid stack size'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(context, {
                  'rebuyAmount': rebuyAmount,
                  'newStack': stackSize,
                });
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
      ),
    );

    // Handle the rebuy result
    if (result != null) {
      final rebuyAmount = result['rebuyAmount'] as double;
      final newStack = result['newStack'] as double;

      // Update local tracking data
      setState(() {
        _currentStack = newStack;
        _initialStack = newStack; // Reset initial stack so it shows gray
        _totalBuyIn += rebuyAmount;

        // Add rebuy record
        _rebuys.add({
          'timestamp': DateTime.now().toIso8601String(),
          'amount': rebuyAmount,
          'stackSize': newStack,
        });

        // Add stack history entry
        _stackHistory.add({
          'timestamp': DateTime.now().toIso8601String(),
          'stackSize': newStack,
          'changeType': 'rebuy',
          'changeAmount': rebuyAmount,
        });
      });

      // Update session in Firebase with rebuy data
      if (_sessionId != null) {
        try {
          await FirebaseService.addRebuyToSession(
            sessionId: _sessionId!,
            rebuyAmount: rebuyAmount,
            newStackSize: newStack,
            newTotalBuyIn: _totalBuyIn,
          );
        } catch (e) {
          print('Error saving rebuy: $e');
        }
      }

      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.gameType == GameType.cash
                ? 'Rebuy added: \$${rebuyAmount.toStringAsFixed(2)}'
                : 'Rebuy added: \$${rebuyAmount.toStringAsFixed(2)} (Stack: ${newStack.toStringAsFixed(0)})',
          ),
          backgroundColor: PokerFriendColors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profitLoss = _currentStack - _initialStack;
    final isInitial = _currentStack == _initialStack;
    final isProfit = _currentStack > _initialStack;

    return Scaffold(
      backgroundColor: PokerFriendColors.dark1,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(maxWidth: 375),
            margin: EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Padding(
                  padding: EdgeInsets.fromLTRB(0, 32, 0, 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.sessionName,
                            style: TextStyle(
                              fontSize: 28,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _formatDuration(_sessionDuration),
                            style: TextStyle(
                              fontSize: 18,
                              color: PokerFriendColors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: PokerFriendColors.red,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: IconButton(
                              onPressed: _stopSession,
                              icon: Icon(
                                Icons.stop_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: PokerFriendColors.dark4,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: PopupMenuButton<String>(
                              icon: Icon(
                                Icons.settings,
                                color: Colors.white,
                                size: 20,
                              ),
                              color: PokerFriendColors.dark3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              onSelected: (value) {
                                if (value == 'rebuy') {
                                  _showRebuyDialog();
                                }
                                // Future settings options will be handled here
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'rebuy',
                                  child: Row(
                                    children: [
                                      Icon(Icons.add_circle_outline, color: PokerFriendColors.red, size: 18),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Rebuy',
                                        style: TextStyle(color: Colors.white, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                                // Future menu items will be added here
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // BB Mode Toggle
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: PokerFriendColors.dark3,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'BB Mode',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Switch(
                        value: _showBBMode,
                        onChanged: (value) => setState(() => _showBBMode = value),
                        activeColor: PokerFriendColors.red,
                      ),
                    ],
                  ),
                ),

                // Main Stack Card
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isInitial
                        ? [PokerFriendColors.dark4, PokerFriendColors.dark3]
                        : isProfit
                          ? [Color(0xFF2E7D32), Color(0xFF1B5E20)]
                          : [Color(0xFFB71C1C), Color(0xFF7F0000)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Current Stack',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          GestureDetector(
                            onTap: _showUpdateStackDialog,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Update',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        _formatStackValue(_currentStack),
                        style: TextStyle(
                          fontSize: 42,
                          color: stackColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'P/L',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                                Text(
                                  '${profitLoss >= 0 ? '+' : ''}${widget.gameType == GameType.cash ? '\$' : ''}${profitLoss.toStringAsFixed(widget.gameType == GameType.cash ? 2 : 0)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Growth',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                                Text(
                                  '${stackGrowthPercentage >= 0 ? '+' : ''}${stackGrowthPercentage.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
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

                SizedBox(height: 24),

                // Session Stats
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: PokerFriendColors.dark3,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            child: Image.asset(
                              'icons/stats.png',
                              width: 40,
                              height: 40,
                              fit: BoxFit.contain,
                            ),
                          ),
                          SizedBox(width: 16),
                          Text(
                            'Session Stats',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: PokerFriendColors.dark1,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _buildStatRow('Initial Buy-in', '\$${widget.buyInAmount.toStringAsFixed(2)}'),
                            _buildStatRow('Total Invested', '\$${_totalBuyIn.toStringAsFixed(2)}'),
                            _buildStatRow('Rebuys', '${_rebuys.length}'),
                            _buildStatRow('Hands Logged', '$_handsLogged'),
                            _buildStatRow('Biggest Pot', widget.gameType == GameType.cash
                              ? '\$${_biggestPot.toStringAsFixed(2)}'
                              : _biggestPot.toStringAsFixed(0)),
                            _buildClickableStatRow('Blinds', '$_currentSmallBlind/$_currentBigBlind', _showUpdateBlindsDialog),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 32),

                // Log a Hand Button
                Container(
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
                    onPressed: _logHand,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      'LOG A HAND',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: PokerFriendColors.dark9,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClickableStatRow(String label, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: PokerFriendColors.dark9,
              ),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.edit,
                  color: PokerFriendColors.red,
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}