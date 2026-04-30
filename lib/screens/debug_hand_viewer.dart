import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../l10n/app_localizations.dart';
import '../services/firebase_service.dart';

/// Debug screen to fetch and analyze specific hands from Firebase
/// This helps diagnose position calculation bugs
class DebugHandViewerScreen extends StatefulWidget {
  const DebugHandViewerScreen({Key? key}) : super(key: key);

  @override
  _DebugHandViewerScreenState createState() => _DebugHandViewerScreenState();
}

class _DebugHandViewerScreenState extends State<DebugHandViewerScreen> {
  final TextEditingController _sessionNameController = TextEditingController(text: 'Deep Stack Test');
  final TextEditingController _handNumbersController = TextEditingController(text: '27,28');

  bool _isLoading = false;
  String? _sessionId;
  Map<String, dynamic>? _sessionData;
  List<Map<String, dynamic>> _allHands = [];
  Map<int, Map<String, dynamic>> _targetHands = {};
  String _output = '';

  @override
  void dispose() {
    _sessionNameController.dispose();
    _handNumbersController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _output = '';
      _targetHands.clear();
    });

    try {
      final sessionName = _sessionNameController.text.trim();
      final handNumbersStr = _handNumbersController.text.trim();

      if (sessionName.isEmpty) {
        throw 'Please enter a session name';
      }

      List<int> targetHandNumbers = [];
      if (handNumbersStr.isNotEmpty) {
        targetHandNumbers = handNumbersStr
            .split(',')
            .map((s) => int.tryParse(s.trim()))
            .whereType<int>()
            .toList();
      }

      _log('🔍 Searching for session: "$sessionName"...\n');

      // Get all sessions
      final allSessions = await FirebaseService.getAllSessions();

      // Find matching session
      Map<String, dynamic>? matchingSession;
      for (final session in allSessions) {
        if (session['sessionName'] == sessionName) {
          matchingSession = session;
          break;
        }
      }

      if (matchingSession == null) {
        _log('❌ Session "$sessionName" not found\n');
        _log('\n📋 Available sessions:\n');
        for (final session in allSessions.take(20)) {
          _log('  - ${session['sessionName'] ?? 'Unnamed'}\n');
        }
        return;
      }

      _sessionId = matchingSession['id'];
      _sessionData = matchingSession;

      _log('✅ Found session: ${matchingSession['sessionName']}\n');
      _log('   Session ID: $_sessionId\n');
      _log('   Total Hands: ${matchingSession['totalHands']}\n');
      _log('   Player Count: ${matchingSession['playerCount']}\n');
      _log('   Small Blind: ${matchingSession['smallBlind']}\n');
      _log('   Big Blind: ${matchingSession['bigBlind']}\n\n');

      // Fetch all hands
      _log('📥 Fetching hands...\n');
      _allHands = await FirebaseService.getSessionHands(_sessionId!);
      _log('📊 Total hands fetched: ${_allHands.length}\n\n');

      // Filter target hands
      if (targetHandNumbers.isEmpty) {
        _log('⚠️ No specific hand numbers provided. Showing all hands.\n');
        for (final hand in _allHands) {
          final handNum = hand['handNumber'] as int?;
          if (handNum != null) {
            _targetHands[handNum] = hand;
          }
        }
      } else {
        for (final hand in _allHands) {
          final handNum = hand['handNumber'] as int?;
          if (handNum != null && targetHandNumbers.contains(handNum)) {
            _targetHands[handNum] = hand;
          }
        }

        for (final targetNum in targetHandNumbers) {
          if (!_targetHands.containsKey(targetNum)) {
            _log('❌ Hand #$targetNum not found\n');
          }
        }
      }

      // Display detailed hand data
      final sortedHandNumbers = _targetHands.keys.toList()..sort();
      for (final handNum in sortedHandNumbers) {
        _displayHandDetails(handNum, _targetHands[handNum]!);
      }

      // Comparison if we have exactly 2 hands
      if (_targetHands.length == 2) {
        _displayComparison();
      }

    } catch (e, stackTrace) {
      _log('❌ Error: $e\n');
      _log('Stack trace: $stackTrace\n');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _displayHandDetails(int handNum, Map<String, dynamic> hand) {
    _log('═══════════════════════════════════════════════════════════\n');
    _log('🎴 HAND #$handNum\n');
    _log('═══════════════════════════════════════════════════════════\n\n');

    _log('📌 Basic Info:\n');
    _log('   Document ID: ${hand['id']}\n');
    _log('   Button Position: ${hand['buttonPosition']}\n');
    _log('   Player Count: ${hand['playerCount']}\n');
    _log('   Hero Position: ${hand['heroPositionName'] ?? 'N/A'}\n');
    _log('   Hero Seat: ${hand['heroSeatNumber'] ?? 'N/A'}\n\n');

    // Player names
    if (hand['playerNames'] != null) {
      _log('👥 Player Names:\n');
      final playerNames = hand['playerNames'] as Map<String, dynamic>;
      final sortedSeats = playerNames.keys.map((k) => int.parse(k.toString())).toList()..sort();
      for (final seat in sortedSeats) {
        _log('   Seat $seat: ${playerNames[seat.toString()]}\n');
      }
      _log('\n');
    }

    // Active seats
    if (hand['activeSeats'] != null) {
      _log('✓ Active Seats: ${hand['activeSeats']}\n\n');
    }

    // Actions with position info
    if (hand['actions'] != null) {
      _log('🎯 Actions:\n');
      final actions = hand['actions'] as List<dynamic>;

      for (int i = 0; i < actions.length; i++) {
        final action = actions[i] as Map<String, dynamic>;
        final playerSeat = action['player'];
        final actionType = action['action'];
        final street = action['street'];
        final amount = action['amount'];
        final playerPosition = action['playerPosition'] ?? 'N/A';
        final playerName = action['playerName'] ?? 'Unknown';

        _log('   ${i + 1}. [${street.toString().toUpperCase()}] '
              'Seat $playerSeat ($playerPosition) - $playerName: '
              '$actionType${amount != null ? ' \$$amount' : ''}\n');
      }
      _log('\n');
    }

    // Board cards
    if (hand['boardCards'] != null) {
      _log('🃏 Board Cards:\n');
      final boardCards = hand['boardCards'] as Map<String, dynamic>;
      if (boardCards['flop'] != null) {
        _log('   Flop: ${(boardCards['flop'] as List).join(', ')}\n');
      }
      if (boardCards['turn'] != null) {
        _log('   Turn: ${boardCards['turn']}\n');
      }
      if (boardCards['river'] != null) {
        _log('   River: ${boardCards['river']}\n');
      }
      _log('\n');
    }

    // Winner
    if (hand['winnerId'] != null) {
      _log('🏆 Winner: Seat ${hand['winnerId']}\n\n');
    }

    // Pot amounts
    _log('💵 Pot Amounts:\n');
    if (hand['preflopPot'] != null) _log('   Preflop: \$${hand['preflopPot']}\n');
    if (hand['flopPot'] != null) _log('   Flop: \$${hand['flopPot']}\n');
    if (hand['turnPot'] != null) _log('   Turn: \$${hand['turnPot']}\n');
    if (hand['riverPot'] != null) _log('   River: \$${hand['riverPot']}\n');
    if (hand['potAmount'] != null) _log('   Final: \$${hand['potAmount']}\n');
    _log('\n');

    // Raw JSON
    _log('📄 Raw JSON:\n');
    final encoder = JsonEncoder.withIndent('  ');
    _log('${encoder.convert(hand)}\n\n');
  }

  void _displayComparison() {
    final handNumbers = _targetHands.keys.toList()..sort();
    final hand1Num = handNumbers[0];
    final hand2Num = handNumbers[1];
    final hand1 = _targetHands[hand1Num]!;
    final hand2 = _targetHands[hand2Num]!;

    _log('═══════════════════════════════════════════════════════════\n');
    _log('📊 COMPARISON: Hand #$hand1Num vs Hand #$hand2Num\n');
    _log('═══════════════════════════════════════════════════════════\n\n');

    _log('Button Position:\n');
    _log('  Hand #$hand1Num: ${hand1['buttonPosition']}\n');
    _log('  Hand #$hand2Num: ${hand2['buttonPosition']}\n\n');

    _log('Player Count:\n');
    _log('  Hand #$hand1Num: ${hand1['playerCount']}\n');
    _log('  Hand #$hand2Num: ${hand2['playerCount']}\n\n');

    _log('Hero Position:\n');
    _log('  Hand #$hand1Num: ${hand1['heroPositionName']} (Seat ${hand1['heroSeatNumber']})\n');
    _log('  Hand #$hand2Num: ${hand2['heroPositionName']} (Seat ${hand2['heroSeatNumber']})\n\n');

    if (hand1['activeSeats'] != null && hand2['activeSeats'] != null) {
      _log('Active Seats:\n');
      _log('  Hand #$hand1Num: ${hand1['activeSeats']}\n');
      _log('  Hand #$hand2Num: ${hand2['activeSeats']}\n\n');
    }

    final actions1 = (hand1['actions'] as List?)?.length ?? 0;
    final actions2 = (hand2['actions'] as List?)?.length ?? 0;
    _log('Total Actions:\n');
    _log('  Hand #$hand1Num: $actions1 actions\n');
    _log('  Hand #$hand2Num: $actions2 actions\n\n');

    _log('🔍 Position Analysis in Actions:\n\n');
    _analyzeActionsPositions(hand1Num, hand1);
    _analyzeActionsPositions(hand2Num, hand2);
  }

  void _analyzeActionsPositions(int handNum, Map<String, dynamic> hand) {
    final actions = hand['actions'] as List?;
    if (actions == null) return;

    _log('  Hand #$handNum:\n');
    final positions = <String>{};
    final seats = <int>{};

    for (final action in actions) {
      final pos = action['playerPosition'];
      final seat = action['player'];
      if (pos != null) positions.add(pos.toString());
      if (seat != null) seats.add(seat as int);
    }

    _log('    Unique Positions: ${positions.join(', ')}\n');
    _log('    Unique Seats: ${(seats.toList()..sort()).join(', ')}\n\n');
  }

  void _log(String message) {
    setState(() {
      _output += message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF161618),
      appBar: AppBar(
        backgroundColor: Color(0xFF1F1F23),
        title: Text(AppLocalizations.of(context).debugHandViewerTitle, style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Input section
          Container(
            padding: EdgeInsets.all(16),
            color: Color(0xFF1F1F23),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _sessionNameController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).debugHandViewerSessionName,
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: _handNumbersController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).debugHandViewerHandNumbers,
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _fetchData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(AppLocalizations.of(context).debugHandViewerFetchData, style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _output.isEmpty ? null : () {
                        Clipboard.setData(ClipboardData(text: _output));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context).debugHandViewerCopied)),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                      ),
                      child: Icon(Icons.copy, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Output section
          Expanded(
            child: Container(
              padding: EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: SelectableText(
                  _output.isEmpty ? AppLocalizations.of(context).debugHandViewerNoData : _output,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
