import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/game_types.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
import '../services/auth_service.dart';
import 'poker_hand_screen.dart';
import 'quick_stack_update_screen.dart';
import '../design_system/components/drawer_dots.dart';
import '../onboarding/onboarding_state.dart';
import '../onboarding/onboarding_tour.dart';
import '../onboarding/onboarding_progress_bar.dart';

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
  final bool isFromActiveSession;

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
    this.isFromActiveSession = false,
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

  // Average growth tracking (for tournaments)
  double _averageGrowth = 0.0;
  double _previousStack = 0.0;

  // Current blinds (can be updated during session)
  int _currentSmallBlind = 0;
  int _currentBigBlind = 0;
  bool _currentHasBBante = false;

  // Track if blinds were explicitly changed by user
  bool _blindsWereChanged = false;

  // Display mode
  bool _showBBMode = false;

  // Menu key
  final GlobalKey _dotsKey = GlobalKey();

  // Onboarding GlobalKeys
  final GlobalKey _updateStackBtnKey = GlobalKey(debugLabel: 'updateStackBtn');
  final GlobalKey _logHandBtnKey = GlobalKey(debugLabel: 'logHandBtn');
  final GlobalKey _stopSessionBtnKey = GlobalKey(debugLabel: 'stopSessionBtn');

  // Quick stack update tracking
  int _lastButtonPosition = 1;
  Map<int, double> _lastPlayerStacks = {};
  Map<int, String> _lastPlayerNames = {};

  @override
  void initState() {
    super.initState();
    _currentStack = widget.currentStack ?? widget.startingStack;
    _initialStack = widget.startingStack;
    _sessionId = widget.sessionId;
    _totalBuyIn = widget.buyInAmount;
    _previousStack = _currentStack;

    _stackHistory.add({
      'timestamp': DateTime.now().toIso8601String(),
      'stackSize': _currentStack,
      'changeType': 'initial',
      'changeAmount': widget.buyInAmount,
    });

    _currentSmallBlind = widget.smallBlind;
    _currentBigBlind = widget.bigBlind;
    _currentHasBBante = widget.hasBBante;

    if (_sessionId == null) {
      _initializeSession();
    } else {
      _resumeSession();
    }

    _startTimer();
    _scheduleIndividualTrackingTour();
  }

  void _scheduleIndividualTrackingTour() {
    if (!OnboardingState.isOnboardingActive ||
        OnboardingState.currentPhase != 3 ||
        !OnboardingState.individualTrackingTourPending) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      IndividualTrackingTour(
        updateStackButtonKey: _updateStackBtnKey,
        logHandButtonKey: _logHandBtnKey,
      ).show(context);
    });
  }

  Future<void> _initializeSession() async {
    _sessionStartTime = DateTime.now();

    try {
      final sessionId = await FirebaseService.createSession(
        smallBlind: widget.smallBlind,
        bigBlind: widget.bigBlind,
        playerCount: 9,
        gameType: widget.gameType,
        isIndividualSession: true,
        sessionName: widget.sessionName,
        startingStack: widget.startingStack,
        hasBBante: widget.hasBBante,
        totalBuyIn: widget.buyInAmount,
      );

      setState(() {
        _sessionId = sessionId;
      });
    } catch (e) {
      print('Error creating individual session in Firebase: $e');
      final localSessionId = DateTime.now().millisecondsSinceEpoch.toString();

      await LocalStorageService.saveSession(
        sessionId: localSessionId,
        smallBlind: widget.smallBlind,
        bigBlind: widget.bigBlind,
        playerCount: 9,
        startTime: DateTime.now().toIso8601String(),
        gameType: widget.gameType,
        buyInAmount: widget.buyInAmount,
      );

      setState(() {
        _sessionId = localSessionId;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session created locally. Will sync to cloud when connection is available.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _resumeSession() async {
    if (_sessionId != null) {
      try {
        Map<String, dynamic>? sessionData;

        try {
          sessionData = await FirebaseService.getSession(_sessionId!);
        } catch (e) {
          sessionData = await LocalStorageService.getSession(_sessionId!);
        }

        if (sessionData != null) {
          setState(() {
            _totalBuyIn = sessionData!['totalBuyIn']?.toDouble() ?? _totalBuyIn;
            _handsLogged = sessionData['handsLogged'] ?? 0;
            _biggestPot = sessionData['biggestPot']?.toDouble() ?? 0.0;

            if (!widget.isFromActiveSession) {
              _currentSmallBlind = sessionData['smallBlind'] ?? _currentSmallBlind;
              _currentBigBlind = sessionData['bigBlind'] ?? _currentBigBlind;
              _currentHasBBante = sessionData['hasBBante'] ?? _currentHasBBante;
            }

            if (widget.gameType == GameType.tournament) {
              _averageGrowth = sessionData['averageGrowth']?.toDouble() ?? 0.0;
            }

            if (sessionData['rebuys'] != null) {
              _rebuys = List<Map<String, dynamic>>.from(sessionData['rebuys']);
            }

            if (sessionData['stackHistory'] != null) {
              _stackHistory = List<Map<String, dynamic>>.from(sessionData['stackHistory']);
            }

            if (sessionData['startTime'] != null) {
              try {
                if (sessionData['startTime'] is Timestamp) {
                  _sessionStartTime = (sessionData['startTime'] as Timestamp).toDate();
                } else if (sessionData['startTime'] is String) {
                  _sessionStartTime = DateTime.parse(sessionData['startTime']);
                }
              } catch (e) {
                print('Error parsing session start time: $e');
              }
            }
          });
        }
      } catch (e) {}
    }

    if (_sessionStartTime == null) {
      _sessionStartTime = DateTime.now();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
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

  double get stackGrowthPercentage {
    if (_initialStack == 0) return 0;
    return ((_currentStack - _initialStack) / _initialStack) * 100;
  }

  Color get stackColor {
    if (_currentStack == _initialStack) {
      return Colors.white;
    } else if (_currentStack > _initialStack) {
      return const Color(0xFF89F1EC);
    } else {
      return Colors.red;
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

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

  // ─── Dialogs ───

  Future<void> _showUpdateStackDialog() async {
    final newStackController = TextEditingController(text: _currentStack.toString());
    final changeAmountController = TextEditingController();

    final newStack = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131616),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          'Update Current Stack',
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Stack Display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Current Stack:',
                      style: GoogleFonts.ibmPlexSans(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _formatStackValue(_currentStack),
                      style: GoogleFonts.ibmPlexSans(
                        color: const Color(0xFF89F1EC),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'Set New Total',
                style: GoogleFonts.ibmPlexSans(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: newStackController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Enter new total stack',
                  hintStyle: GoogleFonts.ibmPlexSans(color: Colors.white.withOpacity(0.3)),
                  prefixText: widget.gameType == GameType.cash ? '\$ ' : '',
                  prefixStyle: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 16),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'Add/Subtract Amount',
                style: GoogleFonts.ibmPlexSans(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: changeAmountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Amount',
                        hintStyle: GoogleFonts.ibmPlexSans(color: Colors.white.withOpacity(0.3)),
                        prefixText: widget.gameType == GameType.cash ? '\$ ' : '',
                        prefixStyle: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 16),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Plus Button
                  GestureDetector(
                    onTap: () {
                      final amount = double.tryParse(changeAmountController.text);
                      if (amount != null && amount > 0) {
                        final newTotal = _currentStack + amount;
                        Navigator.pop(context, newTotal);
                      }
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF89F1EC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add, color: Colors.black, size: 22),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Minus Button
                  GestureDetector(
                    onTap: () {
                      final amount = double.tryParse(changeAmountController.text);
                      if (amount != null && amount > 0) {
                        final newTotal = _currentStack - amount;
                        if (newTotal >= 0) {
                          Navigator.pop(context, newTotal);
                        }
                      }
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.remove, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.ibmPlexSans(color: Colors.white.withOpacity(0.5)),
            ),
          ),
          TextButton(
            onPressed: () {
              final value = double.tryParse(newStackController.text);
              Navigator.pop(context, value);
            },
            child: Text(
              'Set Total',
              style: GoogleFonts.ibmPlexSans(
                color: const Color(0xFF89F1EC),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (newStack != null && newStack >= 0) {
      final previousStack = _currentStack;
      final stackChange = newStack - previousStack;

      setState(() {
        _currentStack = newStack;
        _stackHistory.add({
          'timestamp': DateTime.now().toIso8601String(),
          'stackSize': newStack,
          'changeType': stackChange >= 0 ? 'manual_increase' : 'manual_decrease',
          'changeAmount': stackChange.abs(),
        });
      });

      if (_sessionId != null) {
        FirebaseService.updateIndividualSession(
          sessionId: _sessionId!,
          currentStack: _currentStack,
          stackHistory: _stackHistory,
        ).catchError((e) {});
      }
    }
  }

  void _showOptionsMenu() {
    final RenderBox renderBox = _dotsKey.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      useSafeArea: false,
      builder: (context) => Stack(
        children: [
          // Dismiss on tap outside
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.transparent),
            ),
          ),
          // Positioned popup menu — anchored to dots icon position
          Positioned(
            right: 16,
            top: offset.dy + size.height + 4,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 184,
                decoration: BoxDecoration(
                  color: const Color(0xFF02050B),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.45),
                      blurRadius: 34,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rebuy row
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _showRebuyDialog();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          const Icon(Icons.add_circle_outline, color: Color(0xFF89F1EC), size: 16),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Rebuy',
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                  height: 1.44,
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
        ],
      ),
    );
  }

  Future<void> _showUpdateBlindsDialog() async {
    final smallBlindController = TextEditingController(text: _currentSmallBlind.toString());
    final bigBlindController = TextEditingController(text: _currentBigBlind.toString());

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF131616),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Update Blinds',
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: smallBlindController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  labelText: 'Small Blind',
                  labelStyle: GoogleFonts.ibmPlexSans(color: Colors.white.withOpacity(0.5)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bigBlindController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  labelText: 'Big Blind',
                  labelStyle: GoogleFonts.ibmPlexSans(color: Colors.white.withOpacity(0.5)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.ibmPlexSans(color: Colors.white.withOpacity(0.5)),
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
                  });
                }
              },
              child: Text(
                'Update',
                style: GoogleFonts.ibmPlexSans(
                  color: const Color(0xFF89F1EC),
                  fontWeight: FontWeight.w600,
                ),
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
        _blindsWereChanged = true;
      });

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

  Future<void> _logHand() async {
    if (widget.isFromActiveSession) {
      final Map<String, dynamic> result = {
        'updatedStack': _currentStack,
        'totalBuyIn': _totalBuyIn,
      };

      if (_blindsWereChanged) {
        result['smallBlind'] = _currentSmallBlind;
        result['bigBlind'] = _currentBigBlind;
        result['hasBBante'] = _currentHasBBante;
      }

      Navigator.pop(context, result);
      return;
    }

    String userName = 'You';
    try {
      final user = AuthService.currentUser;
      if (user != null && user.displayName?.isNotEmpty == true) {
        userName = user.displayName!;
      }
    } catch (e) {}

    final stackResult = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => QuickStackUpdateScreen(
          smallBlind: _currentSmallBlind,
          bigBlind: _currentBigBlind,
          numberOfPlayers: 9,
          gameType: widget.gameType,
          currentStacks: _lastPlayerStacks.isNotEmpty ? _lastPlayerStacks : null,
          currentButtonPosition: _lastButtonPosition,
          playerNames: _lastPlayerNames.isNotEmpty ? _lastPlayerNames : null,
          userCurrentStack: _currentStack,
          userName: userName,
        ),
      ),
    );

    if (stackResult == null) return;

    final Map<int, double> playerStacks = Map<int, double>.from(stackResult['playerStacks']);
    final int buttonPosition = stackResult['buttonPosition'];
    final Map<int, String>? playerNames = stackResult['playerNames'] != null
        ? Map<int, String>.from(stackResult['playerNames'])
        : null;

    setState(() {
      _lastPlayerStacks = playerStacks;
      _lastButtonPosition = buttonPosition;
      if (playerNames != null) {
        _lastPlayerNames.addAll(playerNames);
      }
    });

    Map<int, String> completePlayerNames = Map<int, String>.from(_lastPlayerNames);
    if (playerNames != null) {
      completePlayerNames.addAll(playerNames);
    }

    int? userSeat;
    for (var entry in completePlayerNames.entries) {
      if (entry.value == userName) {
        userSeat = entry.key;
        break;
      }
    }

    if (userSeat != null && playerStacks.containsKey(userSeat)) {
      _currentStack = playerStacks[userSeat]!;
    }

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => PokerHandScreen(
          smallBlind: _currentSmallBlind,
          bigBlind: _currentBigBlind,
          numberOfPlayers: 9,
          gameType: widget.gameType,
          hasBBante: _currentHasBBante,
          ante: _currentHasBBante ? _currentBigBlind : 0,
          isIndividualSession: true,
          individualCurrentStack: _currentStack,
          individualSessionId: _sessionId,
          individualTotalBuyIn: _totalBuyIn,
          preConfiguredStacks: playerStacks,
          preConfiguredButtonPosition: buttonPosition,
          preConfiguredPlayerNames: completePlayerNames.isNotEmpty ? completePlayerNames : null,
          skipTableSetup: true,
        ),
      ),
    );

    if (result != null && result['completed'] == true) {
      final newStack = result['finalStack'] as double?;
      final startingStack = result['startingStack'] as double?;
      if (newStack != null) {
        final actualStartingStack = startingStack ?? _currentStack;
        final stackChange = newStack - actualStartingStack;

        if (widget.gameType == GameType.tournament && actualStartingStack > 0) {
          final handGrowth = ((newStack - actualStartingStack) / actualStartingStack) * 100;
          _averageGrowth = (_averageGrowth * _handsLogged + handGrowth) / (_handsLogged + 1);
        }

        setState(() {
          _currentStack = newStack;
          _handsLogged++;
          final potSize = result['potSize'] as double?;
          if (potSize != null && potSize > _biggestPot) {
            _biggestPot = potSize;
          }

          if (result['smallBlind'] != null) {
            _currentSmallBlind = result['smallBlind'] as int;
          }
          if (result['bigBlind'] != null) {
            _currentBigBlind = result['bigBlind'] as int;
          }
          if (result['hasBBante'] != null) {
            _currentHasBBante = result['hasBBante'] as bool;
          }
        });

        _stackHistory.add({
          'timestamp': DateTime.now().toIso8601String(),
          'stackSize': _currentStack,
          'changeType': stackChange >= 0 ? 'win' : 'loss',
          'changeAmount': stackChange.abs(),
          'handNumber': _handsLogged,
        });

        if (_sessionId != null) {
          FirebaseService.updateIndividualSession(
            sessionId: _sessionId!,
            currentStack: _currentStack,
            handsLogged: _handsLogged,
            biggestPot: _biggestPot,
            stackHistory: _stackHistory,
            smallBlind: _currentSmallBlind,
            bigBlind: _currentBigBlind,
            hasBBante: _currentHasBBante,
            averageGrowth: widget.gameType == GameType.tournament ? _averageGrowth : null,
          ).catchError((e) {});
        }

        // Onboarding: trigger stop-session tour after first hand in individual mode
        if (OnboardingState.isOnboardingActive &&
            OnboardingState.isIndividualMode) {
          OnboardingState.individualStopSessionTourPending = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await Future.delayed(const Duration(milliseconds: 400));
            if (!mounted) return;
            IndividualStopSessionTour(
              stopSessionButtonKey: _stopSessionBtnKey,
            ).show(context);
          });
        }
      }
    }
  }

  Future<void> _stopSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
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

    if (confirm == true) {
      if (_sessionId != null) {
        try {
          await FirebaseService.endSession(_sessionId!);
          await FirebaseService.updateIndividualSession(
            sessionId: _sessionId!,
            sessionStatus: 'completed',
            currentStack: _currentStack,
            handsLogged: _handsLogged,
            biggestPot: _biggestPot,
            stackHistory: _stackHistory,
            totalBuyIn: _totalBuyIn,
          );
        } catch (e) {}
      }

      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  Future<bool?> _showRebuyConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131616),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            const SizedBox(width: 12),
            Text(
              'Confirm Rebuy',
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You currently have ${_formatStackValue(_currentStack)} remaining.',
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Proceeding with a rebuy will replace your current stack. Are you sure you want to continue?',
              style: GoogleFonts.ibmPlexSans(
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
              style: GoogleFonts.ibmPlexSans(color: Colors.white.withOpacity(0.5)),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context, true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(60),
              ),
              child: Text(
                'Proceed with Rebuy',
                style: GoogleFonts.ibmPlexSans(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRebuyDialog() async {
    if (_currentStack > 0) {
      final confirmed = await _showRebuyConfirmationDialog();
      if (confirmed != true) return;
    }
    final rebuyAmountController = TextEditingController();
    final stackSizeController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131616),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Row(
          children: [
            const Icon(Icons.add_circle_outline, color: Color(0xFF89F1EC), size: 24),
            const SizedBox(width: 12),
            Text(
              'Rebuy',
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.gameType == GameType.cash
                    ? 'Enter rebuy amount (stack will equal rebuy amount)'
                    : 'Enter rebuy amount and new stack size',
                style: GoogleFonts.ibmPlexSans(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: rebuyAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Rebuy Amount',
                  labelStyle: GoogleFonts.ibmPlexSans(color: Colors.white.withOpacity(0.5)),
                  prefixText: '\$ ',
                  prefixStyle: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 16),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),

              if (widget.gameType == GameType.tournament) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: stackSizeController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'New Stack Size',
                    labelStyle: GoogleFonts.ibmPlexSans(color: Colors.white.withOpacity(0.5)),
                    hintText: 'Chip count after rebuy',
                    hintStyle: GoogleFonts.ibmPlexSans(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Current session info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session Info',
                      style: GoogleFonts.ibmPlexSans(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total Invested: \$${_totalBuyIn.toStringAsFixed(2)}',
                      style: GoogleFonts.ibmPlexSans(color: Colors.white.withOpacity(0.5), fontSize: 12),
                    ),
                    Text(
                      'Current Stack: ${_formatStackValue(_currentStack)}',
                      style: GoogleFonts.ibmPlexSans(color: Colors.white.withOpacity(0.5), fontSize: 12),
                    ),
                    Text(
                      'Rebuys: ${_rebuys.length}',
                      style: GoogleFonts.ibmPlexSans(color: Colors.white.withOpacity(0.5), fontSize: 12),
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
              style: GoogleFonts.ibmPlexSans(color: Colors.white.withOpacity(0.5)),
            ),
          ),
          GestureDetector(
            onTap: () {
              final rebuyAmount = double.tryParse(rebuyAmountController.text);

              if (rebuyAmount == null || rebuyAmount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid rebuy amount'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (widget.gameType == GameType.cash) {
                Navigator.pop(context, {
                  'rebuyAmount': rebuyAmount,
                  'newStack': rebuyAmount,
                });
              } else {
                final stackSize = double.tryParse(stackSizeController.text);
                if (stackSize == null || stackSize <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF89F1EC),
                borderRadius: BorderRadius.circular(60),
              ),
              child: Text(
                'Add Rebuy',
                style: GoogleFonts.ibmPlexSans(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      final rebuyAmount = result['rebuyAmount'] as double;
      final newStack = result['newStack'] as double;

      setState(() {
        _currentStack = newStack;
        _initialStack = newStack;
        _totalBuyIn += rebuyAmount;

        _rebuys.add({
          'timestamp': DateTime.now().toIso8601String(),
          'amount': rebuyAmount,
          'stackSize': newStack,
        });

        _stackHistory.add({
          'timestamp': DateTime.now().toIso8601String(),
          'stackSize': newStack,
          'changeType': 'rebuy',
          'changeAmount': rebuyAmount,
        });
      });

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.gameType == GameType.cash
                ? 'Rebuy added: \$${rebuyAmount.toStringAsFixed(2)}'
                : 'Rebuy added: \$${rebuyAmount.toStringAsFixed(2)} (Stack: ${newStack.toStringAsFixed(0)})',
          ),
          backgroundColor: const Color(0xFF89F1EC),
        ),
      );
    }
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final profitLoss = _currentStack - _initialStack;
    final isProfit = _currentStack > _initialStack;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Teal radial gradient at top
          Positioned(
            top: -screenWidth * 0.5,
            right: -screenWidth * 0.2,
            child: Container(
              width: screenWidth * 1.2,
              height: screenWidth * 1.2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1A4A4A).withOpacity(0.6),
                    const Color(0xFF133538).withOpacity(0.3),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const OnboardingProgressBar(),
                  // Header
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 24),
                    child: Row(
                      children: [
                        // Stop button - red circle
                        GestureDetector(
                          onTap: _stopSession,
                          child: Container(
                            key: _stopSessionBtnKey,
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.stop_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Session name + timer
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.sessionName,
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 20,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatDuration(_sessionDuration),
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 14,
                                  color: const Color(0xFF89F1EC),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Settings dots
                        SizedBox(
                          key: _dotsKey,
                          child: DrawerDots(onTap: () => _showOptionsMenu()),
                        ),
                      ],
                    ),
                  ),

                  // BB Mode Toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131616),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'BB Mode',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Switch(
                          value: _showBBMode,
                          onChanged: (value) => setState(() => _showBBMode = value),
                          activeColor: const Color(0xFF89F1EC),
                        ),
                      ],
                    ),
                  ),

                  // Main Stack Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131616),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Current Stack',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                            GestureDetector(
                              onTap: _showUpdateStackDialog,
                              child: Container(
                                key: _updateStackBtnKey,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF89F1EC).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(60),
                                  border: Border.all(
                                    color: const Color(0xFF89F1EC).withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.edit, color: Color(0xFF89F1EC), size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Update',
                                      style: GoogleFonts.ibmPlexSans(
                                        color: const Color(0xFF89F1EC),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _formatStackValue(_currentStack),
                            style: GoogleFonts.familjenGrotesk(
                              fontSize: 42,
                              color: stackColor,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
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
                                    style: GoogleFonts.ibmPlexSans(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                  ),
                                  Text(
                                    '${profitLoss >= 0 ? '+' : ''}${widget.gameType == GameType.cash ? '\$' : ''}${profitLoss.toStringAsFixed(widget.gameType == GameType.cash ? 2 : 0)}',
                                    style: GoogleFonts.ibmPlexSans(
                                      fontSize: 18,
                                      color: isProfit ? const Color(0xFF89F1EC) : (profitLoss < 0 ? Colors.red : Colors.white),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Growth',
                                    style: GoogleFonts.ibmPlexSans(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                  ),
                                  Text(
                                    '${stackGrowthPercentage >= 0 ? '+' : ''}${stackGrowthPercentage.toStringAsFixed(1)}%',
                                    style: GoogleFonts.ibmPlexSans(
                                      fontSize: 18,
                                      color: isProfit ? const Color(0xFF89F1EC) : (profitLoss < 0 ? Colors.red : Colors.white),
                                      fontWeight: FontWeight.w600,
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

                  const SizedBox(height: 16),

                  // Session Stats
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131616),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Session Stats',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 17,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildStatRow('Starting Stack', widget.gameType == GameType.cash
                            ? '\$${widget.startingStack.toStringAsFixed(2)}'
                            : widget.startingStack.toStringAsFixed(0)),
                        _buildDivider(),
                        _buildStatRow('Initial Buy-in', '\$${widget.buyInAmount.toStringAsFixed(2)}'),
                        _buildDivider(),
                        _buildStatRow('Rebuys', '${_rebuys.length}'),
                        _buildDivider(),
                        _buildStatRow('Total Invested', '\$${_totalBuyIn.toStringAsFixed(2)}'),
                        _buildDivider(),
                        _buildClickableStatRow('Blinds', '$_currentSmallBlind/$_currentBigBlind', _showUpdateBlindsDialog),
                        _buildDivider(),
                        _buildStatRow('Hands Logged', '$_handsLogged'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Log Hand Button
                  GestureDetector(
                    onTap: _logHand,
                    child: Container(
                      key: _logHandBtnKey,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: widget.isFromActiveSession
                            ? const Color(0xFF131616)
                            : const Color(0xFF89F1EC),
                        borderRadius: BorderRadius.circular(60),
                        border: widget.isFromActiveSession
                            ? Border.all(color: Colors.white.withOpacity(0.1))
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.isFromActiveSession)
                            const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                          if (widget.isFromActiveSession)
                            const SizedBox(width: 8),
                          Text(
                            widget.isFromActiveSession ? 'Go Back to Hand' : 'Log a Hand',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: widget.isFromActiveSession ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: Colors.white.withOpacity(0.1),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              color: Colors.white.withOpacity(0.5),
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              color: const Color(0xFF89F1EC),
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 15,
                color: Colors.white.withOpacity(0.5),
                fontWeight: FontWeight.w400,
              ),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    color: const Color(0xFF89F1EC),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.edit,
                  color: Color(0xFF89F1EC),
                  size: 14,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
