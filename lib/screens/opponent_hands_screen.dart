import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/opponent.dart';
import '../services/local_storage_service.dart';
import '../widgets/loading_screen.dart';
import '../utils/poker_positions.dart';
import 'hand_actions_screen.dart';

class OpponentHandsScreen extends StatefulWidget {
  final Opponent opponent;

  const OpponentHandsScreen({Key? key, required this.opponent}) : super(key: key);

  @override
  _OpponentHandsScreenState createState() => _OpponentHandsScreenState();
}

class _OpponentHandsScreenState extends State<OpponentHandsScreen> {
  List<Map<String, dynamic>> hands = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadOpponentHands();
  }

  Future<void> _loadOpponentHands() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final allHands = await _getHandsWithOpponent(widget.opponent.name);
      
      setState(() {
        hands = allHands;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load hands: $e';
        isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _getHandsWithOpponent(String opponentName) async {
    try {
      final db = await LocalStorageService.database;
      final sessions = await db.query('sessions');
      
      List<Map<String, dynamic>> opponentHands = [];
      
      for (final session in sessions) {
        // Get all hands for this session
        final sessionHands = await LocalStorageService.getSessionHands(session['id'] as String);
        
        for (final hand in sessionHands) {
          // Check if opponent was involved in this hand
          final playerNamesData = hand['playerNames'];
          bool opponentInvolved = false;
          
          if (playerNamesData != null && playerNamesData is Map) {
            // Check if opponent name appears in any player slot
            opponentInvolved = playerNamesData.values.any((name) => 
              name.toString().toLowerCase().trim() == opponentName.toLowerCase().trim()
            );
          }
          
          // Also check actions for opponent name (fallback)
          if (!opponentInvolved) {
            final actions = List<Map<String, dynamic>>.from(hand['actions'] ?? []);
            opponentInvolved = actions.any((action) => 
              action['playerName']?.toString().toLowerCase().trim() == opponentName.toLowerCase().trim()
            );
          }
          
          if (opponentInvolved) {
            // Add session info to hand
            final handWithSession = Map<String, dynamic>.from(hand);
            handWithSession['sessionName'] = session['sessionName'] ?? 'Session ${session['id']}';
            handWithSession['sessionDate'] = session['startTime'];
            opponentHands.add(handWithSession);
          }
        }
      }
      
      // Sort by date (most recent first)
      opponentHands.sort((a, b) {
        final aTime = DateTime.parse(a['startTime'] ?? '1970-01-01');
        final bTime = DateTime.parse(b['startTime'] ?? '1970-01-01');
        return bTime.compareTo(aTime);
      });
      
      return opponentHands;
    } catch (e) {
      print('Error getting opponent hands: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF161618),
      body: SafeArea(
        child: Column(
          children: [
            // Modern Header
            Container(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 20),
              decoration: BoxDecoration(
                color: Color(0xFF1F1F23),
              ),
              child: Row(
                children: [
                  // Back button
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
                  // Header info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.opponent.name} History',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${hands.length} hands played together',
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
              child: isLoading
                  ? LoadingScreen(message: "Loading hand history...")
                  : error != null
                      ? _buildErrorState()
                      : hands.isEmpty
                          ? _buildEmptyState()
                          : _buildHandsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          SizedBox(height: 16),
          Text(
            error!,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadOpponentHands,
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Color(0xFF1F1F23),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Image.asset(
                'assets/images/logo.png',
                width: 50,
                height: 50,
                color: Color(0xFF9A9A9A),
              ),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No Hands Found',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You haven\'t played any hands with ${widget.opponent.name} yet.',
            style: TextStyle(
              color: Color(0xFF9A9A9A),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHandsList() {
    return ListView.builder(
      padding: EdgeInsets.all(24),
      itemCount: hands.length,
      itemBuilder: (context, index) {
        final hand = hands[index];
        return _buildHandCard(hand, index);
      },
    );
  }

  Widget _buildHandCard(Map<String, dynamic> hand, int index) {
    final startTime = DateTime.parse(hand['startTime']);
    final sessionName = hand['sessionName'] ?? 'Unknown Session';
    final handNumber = hand['handNumber'] ?? (index + 1);
    final buttonPosition = hand['buttonPosition'] ?? 1;
    final playerCount = hand['playerCount'] ?? 6;
    final heroPosition = hand['heroPosition'] ?? 1;
    final potAmount = hand['potAmount'] ?? 0;
    final winnerId = hand['winnerId'];
    
    // Get hero position name
    final heroPositionName = PokerPositions.getPositionName(heroPosition, buttonPosition, playerCount);
    
    // Check if opponent won
    bool opponentWon = false;
    String? opponentPosition;
    if (winnerId != null) {
      final playerNamesData = hand['playerNames'];
      if (playerNamesData != null && playerNamesData is Map) {
        final winnerName = playerNamesData[winnerId.toString()];
        opponentWon = winnerName?.toString().toLowerCase().trim() == widget.opponent.name.toLowerCase().trim();
        
        // Get opponent's position
        playerNamesData.forEach((seat, name) {
          if (name.toString().toLowerCase().trim() == widget.opponent.name.toLowerCase().trim()) {
            final seatNum = int.tryParse(seat) ?? 1;
            opponentPosition = PokerPositions.getPositionName(seatNum, buttonPosition, playerCount);
          }
        });
      }
    }
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HandActionsScreen(hand: hand),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Color(0xFF1F1F23),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Color(0xFF2A2A2E)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hand #$handNumber',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (opponentWon)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(0xFFFFD700).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Color(0xFFFFD700)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 14),
                        SizedBox(width: 4),
                        Text(
                          'OPPONENT WON',
                          style: TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            
            SizedBox(height: 12),
            
            // Info row
            Row(
              children: [
                // Session info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sessionName,
                        style: TextStyle(
                          color: Color(0xFF9A9A9A),
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, HH:mm').format(startTime),
                        style: TextStyle(
                          color: Color(0xFF9A9A9A),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Positions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Text(
                          'You: ',
                          style: TextStyle(
                            color: Color(0xFF9A9A9A),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          heroPositionName,
                          style: TextStyle(
                            color: Color(0xFF5AC95A),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (opponentPosition != null) ...[
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${widget.opponent.name}: ',
                            style: TextStyle(
                              color: Color(0xFF9A9A9A),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            opponentPosition!,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            // Bottom row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pot: ${hand['gameType'] == 'cash' ? '\$' : ''}${potAmount.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: Color(0xFF5AC95A),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFF9A9A9A),
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