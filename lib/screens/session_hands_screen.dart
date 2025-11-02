import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../utils/poker_positions.dart';
import '../widgets/loading_screen.dart';
import 'hand_actions_screen.dart';

class SessionHandsScreen extends StatefulWidget {
  final Map<String, dynamic> session;

  const SessionHandsScreen({Key? key, required this.session}) : super(key: key);

  @override
  _SessionHandsScreenState createState() => _SessionHandsScreenState();
}

class _SessionHandsScreenState extends State<SessionHandsScreen> {
  List<Map<String, dynamic>> hands = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadHands();
  }

  Future<void> _loadHands() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final loadedHands = await FirebaseService.getSessionHands(widget.session['id']);
      
      setState(() {
        hands = loadedHands;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load hands: $e';
        isLoading = false;
      });
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
                  // Session info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.session['sessionName'] != null && 
                          widget.session['sessionName'].isNotEmpty 
                              ? widget.session['sessionName']
                              : 'Session ${widget.session['id'].substring(0, 8)}...',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${hands.length} hands logged',
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
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return LoadingScreen(message: 'Loading hands...');
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 64),
            SizedBox(height: 16),
            Text(
              'Error',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              error!,
              style: TextStyle(color: Color(0xFF9A9A9A)),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadHands,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF5AC95A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (hands.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Color(0xFF2A2A2E),
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/logo.png',
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.casino_outlined,
                      color: Color(0xFF9A9A9A),
                      size: 40,
                    );
                  },
                ),
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No Hands Logged',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'This session has no recorded hands yet.',
              style: TextStyle(
                color: Color(0xFF9A9A9A),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(24),
      itemCount: hands.length,
      itemBuilder: (context, index) => _buildHandCard(hands[index], index + 1),
    );
  }

  Widget _buildHandCard(Map<String, dynamic> hand, int handNumber) {
    final actions = hand['actions'] as List<dynamic>? ?? [];
    final startTime = DateTime.parse(hand['startTime']);
    
    return GestureDetector(
      onTap: () => _navigateToHandActions(hand),
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Color(0xFF1F1F23),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Color(0xFF2A2A2E),
            width: 1,
          ),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hand Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF5AC95A), Color(0xFF4CAF50)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '#$handNumber',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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
                      'Your Position: ${hand['heroPositionName'] ?? PokerPositions.getPositionName(hand['heroPosition'] ?? 1, hand['buttonPosition'], hand['playerCount'])}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${actions.length} actions • ${DateFormat('HH:mm:ss').format(startTime)}',
                      style: TextStyle(
                        color: Color(0xFF9A9A9A),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF9A9A9A),
                size: 16,
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Hand Info Grid
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF161618),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildHandStat('Players', '${hand['playerCount']}'),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Color(0xFF2A2A2E),
                ),
                Expanded(
                  child: _buildHandStat('Actions', '${actions.length}'),
                ),
                // Show hero cards if available
                if (_hasHeroCards(hand)) ...[
                  Container(
                    width: 1,
                    height: 30,
                    color: Color(0xFF2A2A2E),
                  ),
                  Expanded(
                    child: _buildHeroCardsColumn(hand),
                  ),
                ],
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildHandStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Color(0xFF9A9A9A),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  bool _hasHeroCards(Map<String, dynamic> hand) {
    final ourHoleCards = hand['ourHoleCards'] as Map<String, dynamic>?;
    if (ourHoleCards == null) return false;
    return ourHoleCards['card1'] != null || ourHoleCards['card2'] != null;
  }

  Widget _buildHeroCardsColumn(Map<String, dynamic> hand) {
    final ourHoleCards = hand['ourHoleCards'] as Map<String, dynamic>?;
    final card1 = ourHoleCards?['card1'] as String?;
    final card2 = ourHoleCards?['card2'] as String?;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (card1 != null) _buildMiniCard(card1),
            if (card1 != null && card2 != null) SizedBox(width: 4),
            if (card2 != null) _buildMiniCard(card2),
          ],
        ),
        SizedBox(height: 4),
        Text(
          'Hero Cards',
          style: TextStyle(
            color: Color(0xFF9A9A9A),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniCard(String? card) {
    if (card == null || card.isEmpty) return SizedBox.shrink();

    final suit = card.length > 1 ? card.substring(1) : '';
    final rank = card.isNotEmpty ? card[0] : '';

    // Determine if suit is red (hearts, diamonds) or black (spades, clubs)
    final isRedSuit = suit == '♥' || suit == '♦';
    final cardColor = isRedSuit ? Colors.red : Colors.black;

    return Container(
      width: 24,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Color(0xFF2A2A2E), width: 0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            rank,
            style: TextStyle(
              color: cardColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            suit,
            style: TextStyle(
              color: cardColor,
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoleCardsSection(Map<String, dynamic> hand) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hole Cards',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              if (hand['holeCard1'] != null) _buildCard(hand['holeCard1']),
              if (hand['holeCard1'] != null && hand['holeCard2'] != null) SizedBox(width: 8),
              if (hand['holeCard2'] != null) _buildCard(hand['holeCard2']),
              if (hand['holeCard1'] == null && hand['holeCard2'] == null)
                Text(
                  'No cards recorded', 
                  style: TextStyle(
                    fontStyle: FontStyle.italic, 
                    color: Color(0xFF9A9A9A),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String? card) {
    if (card == null || card.isEmpty) return SizedBox.shrink();
    
    final suit = card.length > 1 ? card.substring(1) : '';
    final rank = card.isNotEmpty ? card[0] : '';
    
    Color suitColor = Colors.white;
    if (suit == '♥' || suit == '♦') suitColor = Colors.red;
    
    return Container(
      width: 32,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Color(0xFF2A2A2E)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            rank,
            style: TextStyle(
              color: suitColor == Colors.red ? Colors.red : Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            suit,
            style: TextStyle(
              color: suitColor,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToHandActions(Map<String, dynamic> hand) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HandActionsScreen(hand: hand),
      ),
    );
  }
}