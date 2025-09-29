import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
import '../utils/poker_positions.dart';
import '../widgets/loading_screen.dart';
import 'session_hands_screen.dart';
import 'session_analytics_screen.dart';

class SessionHistoryScreen extends StatefulWidget {
  final String? targetSessionId;
  
  const SessionHistoryScreen({Key? key, this.targetSessionId}) : super(key: key);
  
  @override
  _SessionHistoryScreenState createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> sessions = [];
  bool isLoading = true;
  String? error;
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;

  List<Map<String, dynamic>> get cashSessions =>
      sessions.where((session) => session['gameType'] == 'cash').toList();

  List<Map<String, dynamic>> get tournamentSessions =>
      sessions.where((session) => session['gameType'] == 'tournament').toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSessions();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    try {
      print('📊 DEBUG: _loadSessions called');
      setState(() {
        isLoading = true;
        error = null;
      });

      List<Map<String, dynamic>> loadedSessions;
      try {
        print('📊 DEBUG: Attempting to load from Firebase...');
        // Try Firebase first
        loadedSessions = await FirebaseService.getAllSessions();
        print('📊 DEBUG: Loaded ${loadedSessions.length} sessions from Firebase');
        print('📊 DEBUG: Firebase sessions: ${loadedSessions.map((s) => '${s['id']?.substring(0, 8)}...(${s['sessionName'] ?? 'unnamed'})')}');
      } catch (e) {
        // Fallback to local storage
        print('📊 DEBUG: Firebase failed, trying local storage: $e');
        loadedSessions = await LocalStorageService.getUserSessions();
        print('📊 DEBUG: Loaded ${loadedSessions.length} sessions from local storage');
        print('📊 DEBUG: Local sessions: ${loadedSessions.map((s) => '${s['id']?.substring(0, 8)}...(${s['sessionName'] ?? 'unnamed'})')}');
      }
      
      setState(() {
        sessions = loadedSessions;
        isLoading = false;
      });
      
      // Auto-scroll to the target session if specified
      if (widget.targetSessionId != null) {
        _scrollToSession(widget.targetSessionId!);
      }
    } catch (e) {
      setState(() {
        error = 'Failed to load sessions: $e';
        isLoading = false;
      });
    }
  }

  void _scrollToSession(String sessionId) {
    print('📊 DEBUG: _scrollToSession called with sessionId: $sessionId');
    // Wait a bit for the UI to render
    Future.delayed(Duration(milliseconds: 300), () {
      final targetIndex = sessions.indexWhere((session) => session['id'] == sessionId);
      print('📊 DEBUG: Found target session at index: $targetIndex');
      
      if (targetIndex != -1) {
        // Calculate approximate position (each session card is roughly 120px + margins)
        const double itemHeight = 140.0;
        final double scrollOffset = targetIndex * itemHeight;
        
        // Scroll to the session with animation
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            scrollOffset,
            duration: Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
          print('📊 DEBUG: Scrolled to offset: $scrollOffset');
        }
      } else {
        print('📊 DEBUG: Target session not found!');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF161618),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Session History',
                      style: TextStyle(
                        fontSize: 32,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: _loadSessions,
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.white),
                    color: Color(0xFF1F1F23),
                    onSelected: (value) {
                      if (value == 'clear') {
                        _showClearConfirmation();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: 'clear',
                        child: Row(
                          children: [
                            Icon(Icons.delete_forever, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Clear All Sessions', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Tab Bar
            Container(
              margin: EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Color(0xFF1F1F23),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Color(0xFFcb5242),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Color(0xFF9A9A9A),
                labelStyle: TextStyle(fontWeight: FontWeight.w600),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('icons/cash.png', width: 20, height: 20),
                        SizedBox(width: 8),
                        Text('Cash'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('icons/podium.png', width: 20, height: 20),
                        SizedBox(width: 8),
                        Text('Tournament'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSessionsList(cashSessions, 'Cash'),
                  _buildSessionsList(tournamentSessions, 'Tournament'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionsList(List<Map<String, dynamic>> sessionList, String gameType) {
    if (isLoading) {
      return LoadingScreen(message: 'Loading sessions...');
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
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red, fontSize: 16),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSessions,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF5AC95A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Retry',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    if (sessionList.isEmpty) {
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
                  gameType == 'Cash' ? 'icons/cash.png' : 'icons/podium.png',
                  width: 40,
                  height: 40,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.sports_esports,
                      color: Color(0xFF9A9A9A),
                      size: 40,
                    );
                  },
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'No $gameType Sessions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Play some $gameType poker hands and they will appear here!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF9A9A9A),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 24),
      itemCount: sessionList.length,
      itemBuilder: (context, index) {
        final session = sessionList[index];
        return _buildSessionCard(session);
      },
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final startTime = DateTime.parse(session['startTime']);
    final endTime = session['endTime'] != null 
        ? DateTime.parse(session['endTime']) 
        : null;
    
    final duration = endTime != null 
        ? endTime.difference(startTime).inMinutes 
        : null;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(24),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _getGameTypeIcon(session['gameType']),
        ),
        title: Text(
          session['sessionName'] != null && session['sessionName'].isNotEmpty 
              ? session['sessionName']
              : 'Session ${session['id'].substring(0, 8)}...',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              '${DateFormat('MMM dd, yyyy HH:mm').format(startTime)}',
              style: TextStyle(
                color: Color(0xFF9A9A9A),
                fontSize: 14,
              ),
            ),
            Text(
              '${session['playerCount']} players • ${_formatBlinds(session)}',
              style: TextStyle(
                color: Color(0xFF9A9A9A),
                fontSize: 14,
              ),
            ),
            if (duration != null)
              Text(
                'Duration: ${duration} minutes',
                style: TextStyle(
                  color: Color(0xFF9A9A9A),
                  fontSize: 14,
                ),
              ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Color(0xFF9A9A9A),
          size: 16,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SessionAnalyticsScreen(
                sessionData: session,
                sessionId: session['id'],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showHandDetails(Map<String, dynamic> hand) {
    final actions = List<Map<String, dynamic>>.from(hand['actions'] ?? []);
    final boardCards = hand['boardCards'] as Map<String, dynamic>?;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hand #${hand['handNumber']} Details'),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Button Position: ${PokerPositions.getPositionName(hand['buttonPosition'], hand['buttonPosition'], hand['playerCount'])}'),
              Text('Player Count: ${hand['playerCount']}'),
              Text('Start Time: ${DateFormat('MMM dd, HH:mm:ss').format(DateTime.parse(hand['startTime']))}'),
              
              // Hole Cards Section  
              if (hand['ourHoleCards'] != null) ...[
                SizedBox(height: 16),
                Text('Your Cards:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                _buildHoleCardsDisplay(hand['ourHoleCards']),
              ],

              // Board Cards Section
              if (boardCards != null) ...[
                SizedBox(height: 16),
                Text('Board Cards:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                _buildBoardCardsDisplay(boardCards),
              ],
              
              // Pot Tracking Section
              if (_hasAnyPotData(hand)) ...[
                SizedBox(height: 16),
                Text('Pot by Street:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                _buildPotTrackingDisplay(hand, boardCards),
              ],

              // Winner Section
              SizedBox(height: 16),
              _buildWinnerDisplay(hand),

              SizedBox(height: 16),
              Text('Actions:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              if (actions.isEmpty)
                Text('No actions recorded')
              else
                ...actions.map((action) {
                  // Get the player name and position from the stored action record
                  final playerSeat = action['player'] as int;
                  final storedPlayerName = action['playerName'] as String?;
                  final storedPlayerPosition = action['playerPosition'] as String?;
                  
                  String displayName;
                  if (storedPlayerName != null && storedPlayerName.isNotEmpty) {
                    // Check if stored name is just a position name (like UTG, BB, etc.)
                    bool isPositionName = PokerPositions.isPositionName(storedPlayerName);
                    
                    if (isPositionName) {
                      // If it's just a position name, show seat number with current position
                      if (storedPlayerPosition != null && storedPlayerPosition.isNotEmpty) {
                        displayName = 'Seat $playerSeat ($storedPlayerPosition)';
                      } else {
                        displayName = 'Seat $playerSeat';
                      }
                    } else {
                      // Use custom player name with position: "Gringo (SB)"
                      if (storedPlayerPosition != null && storedPlayerPosition.isNotEmpty) {
                        displayName = '$storedPlayerName ($storedPlayerPosition)';
                      } else {
                        // Fallback to custom player name only
                        displayName = storedPlayerName;
                      }
                    }
                  } else {
                    // Fallback to seat number with position
                    if (storedPlayerPosition != null && storedPlayerPosition.isNotEmpty) {
                      displayName = 'Seat $playerSeat ($storedPlayerPosition)';
                    } else {
                      displayName = 'Seat $playerSeat';
                    }
                  }
                  
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${_getActionIcon(action['action'])} $displayName ${_formatAction(action['action'])} (${_formatStreet(action['street'])})',
                      style: TextStyle(fontFamily: 'monospace'),
                    ),
                  );
                }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildHoleCardsDisplay(Map<String, dynamic> holeCards) {
    final card1 = holeCards['card1'] as String?;
    final card2 = holeCards['card2'] as String?;
    
    return Row(
      children: [
        if (card1 != null) _buildCard(card1),
        if (card1 != null && card2 != null) SizedBox(width: 8),
        if (card2 != null) _buildCard(card2),
        if (card1 == null && card2 == null)
          Text('No cards recorded', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
      ],
    );
  }

  Widget _buildBoardCardsDisplay(Map<String, dynamic> boardCards) {
    final flop = List<String>.from(boardCards['flop'] ?? []);
    final turn = boardCards['turn'] as String?;
    final river = boardCards['river'] as String?;
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (flop.isNotEmpty) ...[
          Text('Flop: ', style: TextStyle(fontSize: 12)),
          ...flop.map((card) => _buildCard(card)),
        ],
        if (turn != null) ...[
          SizedBox(width: 16),
          Text('Turn: ', style: TextStyle(fontSize: 12)),
          _buildCard(turn),
        ],
        if (river != null) ...[
          SizedBox(width: 16),
          Text('River: ', style: TextStyle(fontSize: 12)),
          _buildCard(river),
        ],
      ],
    );
  }
  
  Widget _buildCard(String card) {
    final color = _getCardColor(card);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
        color: Colors.white,
      ),
      child: Text(
        card,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
  
  Color _getCardColor(String card) {
    if (card.contains('♥') || card.contains('♦')) {
      return Colors.red;
    }
    return Colors.black;
  }

  String _getActionIcon(String action) {
    switch (action.toLowerCase()) {
      case 'bet': return '💰';
      case 'call': return '✅';
      case 'raise': return '📈';
      case 'fold': return '❌';
      default: return '•';
    }
  }

  String _formatAction(String action) {
    return action.toUpperCase();
  }

  String _formatStreet(String street) {
    switch (street.toLowerCase()) {
      case 'preflop': return 'Preflop';
      case 'flop': return 'Flop';
      case 'turn': return 'Turn';
      case 'river': return 'River';
      default: return street;
    }
  }

  void _showClearConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Clear All Sessions?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will permanently delete all poker sessions and hands from both Firebase and local storage.'),
            SizedBox(height: 8),
            Text(
              'This action cannot be undone!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAllSessions();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllSessions() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });
      
      print('🗑️ DEBUG: Starting to clear all user sessions...');
      
      // Clear from Firebase first
      try {
        await FirebaseService.clearUserSessions();
        print('🗑️ DEBUG: Firebase sessions cleared successfully');
      } catch (e) {
        print('🗑️ DEBUG: Error clearing Firebase sessions: $e');
        // Continue with local clearing even if Firebase fails
      }
      
      // Clear from local storage
      try {
        await LocalStorageService.clearUserSessions();
        print('🗑️ DEBUG: Local sessions cleared successfully');
      } catch (e) {
        print('🗑️ DEBUG: Error clearing local sessions: $e');
      }
      
      // Refresh the sessions list
      await _loadSessions();
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All sessions have been cleared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      print('🗑️ DEBUG: All sessions cleared and UI refreshed');
    } catch (e) {
      setState(() {
        error = 'Failed to clear sessions: $e';
        isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear sessions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _hasAnyPotData(Map<String, dynamic> hand) {
    final preflopPot = (hand['preflopPot'] ?? 0).toDouble();
    final flopPot = (hand['flopPot'] ?? 0).toDouble();
    final turnPot = (hand['turnPot'] ?? 0).toDouble();
    final riverPot = (hand['riverPot'] ?? 0).toDouble();
    
    return preflopPot > 0 || flopPot > 0 || turnPot > 0 || riverPot > 0;
  }
  
  Widget _buildPotTrackingDisplay(Map<String, dynamic> hand, Map<String, dynamic>? boardCards) {
    final preflopPot = (hand['preflopPot'] ?? 0).toDouble();
    final flopPot = (hand['flopPot'] ?? 0).toDouble();
    final turnPot = (hand['turnPot'] ?? 0).toDouble();
    final riverPot = (hand['riverPot'] ?? 0).toDouble();
    final totalPot = (hand['potAmount'] ?? 0).toDouble();
    
    // Determine game type for currency formatting
    final gameTypeStr = hand['handGameType'] ?? hand['gameType'] ?? 'cash';
    final isCashGame = gameTypeStr == 'cash';
    
    String formatAmount(double amount) {
      if (amount <= 0) return '--';
      if (isCashGame) {
        return '\$${amount.toStringAsFixed(2)}';
      } else {
        return '${amount.toInt()}';
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Preflop:', style: TextStyle(fontSize: 12)),
            Text(formatAmount(preflopPot), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
        SizedBox(height: 4),
        if (boardCards?['flop'] != null && (boardCards!['flop'] as List).isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Flop:', style: TextStyle(fontSize: 12)),
              Text(formatAmount(flopPot), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          SizedBox(height: 4),
        ],
        if (boardCards?['turn'] != null && (boardCards!['turn'] as String).isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Turn:', style: TextStyle(fontSize: 12)),
              Text(formatAmount(turnPot), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          SizedBox(height: 4),
        ],
        if (boardCards?['river'] != null && (boardCards!['river'] as String).isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('River:', style: TextStyle(fontSize: 12)),
              Text(formatAmount(riverPot), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          SizedBox(height: 4),
        ],
        Divider(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Final Pot:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(formatAmount(totalPot), style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildWinnerDisplay(Map<String, dynamic> hand) {
    final isChoppedPot = hand['isChoppedPot'] == true;
    final winnerId = hand['winnerId'] as int?;
    final choppedWinners = hand['choppedWinners'] as List<dynamic>?;
    final individualShares = hand['individualShares'] as Map<String, dynamic>?;
    final potAmount = (hand['potAmount'] ?? 0).toDouble();
    final gameTypeStr = hand['handGameType'] ?? hand['gameType'] ?? 'cash';
    final isCashGame = gameTypeStr == 'cash';

    String formatAmount(double amount) {
      if (isCashGame) {
        return '\$${amount.toStringAsFixed(2)}';
      } else {
        return '${amount.toInt()}';
      }
    }

    if (isChoppedPot && choppedWinners != null && choppedWinners.isNotEmpty) {
      // Chopped pot display
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.call_split, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text(
                'Chopped Pot (${choppedWinners.length} winners):',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
              ),
            ],
          ),
          SizedBox(height: 8),
          if (individualShares != null && individualShares.isNotEmpty) ...[
            ...individualShares.entries.map((entry) {
              final playerId = int.parse(entry.key);
              final amount = (entry.value as num).toDouble();
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('🏆 Player $playerId wins:',
                         style: TextStyle(fontWeight: FontWeight.w500, color: Colors.green)),
                    Text(formatAmount(amount),
                         style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              );
            }).toList(),
          ] else ...[
            // Fallback to equal shares
            ...choppedWinners.map((winnerId) {
              final winnerIdInt = winnerId as int;
              final shareAmount = potAmount / choppedWinners.length;
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('🏆 Player $winnerIdInt wins:',
                         style: TextStyle(fontWeight: FontWeight.w500, color: Colors.green)),
                    Text(formatAmount(shareAmount),
                         style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      );
    } else if (winnerId != null) {
      // Single winner display
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                '🏆 Player $winnerId wins:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ],
          ),
          Text(
            formatAmount(potAmount),
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
          ),
        ],
      );
    } else {
      // No winner info available
      return Text(
        'Winner information not available',
        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      );
    }
  }


  String _formatBlinds(Map<String, dynamic> session) {
    final smallBlind = session['smallBlind'] ?? 0;
    final bigBlind = session['bigBlind'] ?? 0;
    final gameTypeStr = session['gameType'] ?? 'cash';

    // Check if it's a cash game
    final isCashGame = gameTypeStr == 'cash';

    if (isCashGame) {
      return '\$$smallBlind/\$$bigBlind';
    } else {
      return '$smallBlind/$bigBlind';
    }
  }

  Widget _getGameTypeIcon(String? gameType) {
    final gameTypeStr = gameType ?? 'cash';
    switch (gameTypeStr.toLowerCase()) {
      case 'tournament':
        return Image.asset('icons/podium.png', width: 24, height: 24);
      case 'cash':
        return Image.asset('icons/cash.png', width: 24, height: 24);
      default:
        return Icon(
          Icons.sports_esports,
          color: Colors.white,
          size: 24,
        );
    }
  }
}