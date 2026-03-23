import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
import '../utils/poker_positions.dart';
import '../widgets/loading_screen.dart';
import '../widgets/global_bottom_nav_bar.dart';
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
      setState(() {
        isLoading = true;
        error = null;
      });

      List<Map<String, dynamic>> loadedSessions;
      try {
        // Try Firebase first
        loadedSessions = await FirebaseService.getAllSessions();
      } catch (e) {
        // Fallback to local storage
        loadedSessions = await LocalStorageService.getUserSessions();
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
    // Wait a bit for the UI to render
    Future.delayed(Duration(milliseconds: 300), () {
      final targetIndex = sessions.indexWhere((session) => session['id'] == sessionId);

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
        }
      }
    });
  }

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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: Stack(
        children: [
          // Subtle teal gradient at top (same as home/opponents screens)
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section with back arrow + title
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Row(
                    children: [
                      // Back button
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
                      SizedBox(width: 12),
                      // Title
                      Text(
                        'Session History',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                // Tab Bar
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(80),
                    border: Border.all(
                      color: Color(0xFF2C2C2E),
                      width: 1,
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(60),
                      gradient: LinearGradient(
                        colors: [Color(0xFF1E3B49), Color(0xFF4A887E)],
                      ),
                      border: Border.all(
                        color: Color(0x4DEBEBF5),
                        width: 1,
                      ),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: EdgeInsets.all(0),
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white,
                    labelStyle: GoogleFonts.ibmPlexSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.43,
                    ),
                    unselectedLabelStyle: GoogleFonts.ibmPlexSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.43,
                    ),
                    tabs: [
                      Tab(text: 'Cash'),
                      Tab(text: 'Tournament'),
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
        ],
      ),
      bottomNavigationBar: GlobalBottomNavBar(currentScreen: 'sessions'),
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
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Color(0xFF131616),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon - dollar for Cash, clubs for Tournament
                _buildIcon(
                  gameType == 'Cash'
                      ? 'icons/figma_icons/dollar.svg'
                      : 'icons/figma_icons/clubs.svg',
                  24,
                  Colors.white,
                ),
                SizedBox(height: 14),
                // Title
                Text(
                  'No $gameType Sessions',
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    height: 1.44,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
                // Description - teal
                Text(
                  'Play some $gameType Poker hands \nto see the results',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.ibmPlexSans(
                    color: Color(0xFF89F1EC),
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    height: 1.44,
                  ),
                ),
              ],
            ),
          ),
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

    final isDealerSession = session['isDealerSession'] == true;

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
        title: Row(
          children: [
            Expanded(
              child: Text(
                session['sessionName'] != null && session['sessionName'].isNotEmpty
                    ? session['sessionName']
                    : 'Session ${session['id'].substring(0, 8)}...',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (isDealerSession) ...[
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Color(0xFF4CAF50).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Live',
                  style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
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
                'Duration: ${_formatDuration(duration)}',
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

  void _showHandDetails(Map<String, dynamic> hand, {int? ourSeat}) {
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
                  
                  // Check if this is the hero's action
                  final isHero = ourSeat != null && playerSeat == ourSeat;

                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontFamily: 'monospace', color: Colors.white),
                        children: [
                          TextSpan(text: '${_getActionIcon(action['action'])} '),
                          TextSpan(
                            text: displayName,
                            style: TextStyle(
                              color: isHero ? Color(0xFF5AC95A) : Colors.white,
                              fontWeight: isHero ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          TextSpan(text: ' ${_formatAction(action['action'])} (${_formatStreet(action['street'])})'),
                        ],
                      ),
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

  Future<void> _syncLocalToFirebase() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1F1F23),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.blue),
            SizedBox(height: 16),
            Text('Syncing to cloud...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    try {
      // Perform sync
      final result = await FirebaseService.syncLocalSessionsToFirebase();

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show result
      if (mounted) {
        final success = result['success'] == true;
        final message = result['message'] ?? 'Sync completed';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: Duration(seconds: 4),
          ),
        );

        // Reload sessions if successful
        if (success) {
          await _loadSessions();
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

      // Clear from Firebase first
      try {
        await FirebaseService.clearUserSessions();
      } catch (e) {
        // Continue with local clearing even if Firebase fails
      }

      // Clear from local storage
      try {
        await LocalStorageService.clearUserSessions();
      } catch (e) {
        // Ignore error
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


  String _formatDuration(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '${hours}h ${remainingMinutes}min';
    } else {
      return '$minutes min';
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
        return _buildIcon('icons/figma_icons/clubs.svg', 24, Colors.white);
      case 'cash':
        return _buildIcon('icons/figma_icons/dollar.svg', 24, Colors.white);
      default:
        return Icon(
          Icons.sports_esports,
          color: Colors.white,
          size: 24,
        );
    }
  }
}