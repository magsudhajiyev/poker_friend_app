import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
import '../services/auth_service.dart';
import '../services/opponent_service.dart';
import '../services/opponent_stats_service.dart';
import '../services/user_stats_service.dart';
import '../widgets/global_loading_spinner.dart';

class StatisticsScreen extends StatefulWidget {
  @override
  _StatisticsScreenState createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool isLoading = true;
  String? error;

  // Basic statistics
  int totalHands = 0;
  int handsPlayed = 0;
  double vpip = 0.0;
  double pfr = 0.0;
  double threeBet = 0.0;
  double winRate = 0.0;
  int totalSessions = 0;
  int totalPlayTime = 0;

  // Chart data
  List<SessionChartData> sessionChartData = [];

  // Loading state details
  String loadingMessage = 'Loading statistics...';

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      await _calculateFromDatabase();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load statistics: $e';
        isLoading = false;
      });
    }
  }


  Future<void> _calculateFromDatabase() async {
    // Reset all values
    totalHands = 0;
    handsPlayed = 0;
    vpip = 0.0;
    pfr = 0.0;
    threeBet = 0.0;
    winRate = 0.0;
    totalSessions = 0;
    totalPlayTime = 0;
    sessionChartData.clear();

    try {
      setState(() {
        loadingMessage = 'Fetching user stats...';
      });

      // Get user stats from UserStatsService (single source of truth)
      final userId = AuthService.userId;
      if (userId == null) {
        return;
      }

      final userStats = await UserStatsService.getUserStats(userId);
      if (userStats == null) {
        return;
      }

      // Use stats directly from the database
      totalHands = userStats.totalHands;
      handsPlayed = userStats.handsPlayed;
      totalSessions = userStats.totalSessions;
      totalPlayTime = userStats.totalPlayTimeMinutes;

      // Calculate percentages from database stats
      if (totalHands > 0) {
        vpip = (userStats.vpipCount / totalHands) * 100;
        pfr = (userStats.pfrCount / totalHands) * 100;
        threeBet = (userStats.threeBetCount / totalHands) * 100;
      }
      // Win rate uses handsPlayed (only count hands you actually played)
      if (handsPlayed > 0) {
        winRate = (userStats.wonHands / handsPlayed) * 100;
      }

      setState(() {
        loadingMessage = 'Loading session chart data...';
      });

      // Get sessions for chart data only
      final sessions = await FirebaseService.getAllSessions();
      for (int i = 0; i < sessions.length; i++) {
        final session = sessions[i];
        if (session['startTime'] != null) {
          sessionChartData.add(SessionChartData(
            date: DateTime.parse(session['startTime']),
            sessionNumber: i + 1,
            totalHands: session['totalHands'] ?? 0,
            gameType: session['gameType'] ?? 'cash',
          ));
        }
      }

      print('📊 Stats from UserStatsService: Total Hands: $totalHands, Hands Played: $handsPlayed, Won: ${userStats.wonHands}, Win Rate: ${winRate.toStringAsFixed(1)}%');

    } catch (e) {
      print('❌ Error calculating statistics: $e');
      throw e;
    }
  }

  Future<Map<String, dynamic>> _processSingleSession(Map<String, dynamic> session, int sessionIndex) async {
    int sessionTotalHands = 0;
    int sessionHandsPlayed = 0;
    int sessionVpipHands = 0;
    int sessionPfrHands = 0;
    int sessionThreeBetHands = 0;
    int sessionWonHands = 0;
    SessionChartData? chartData;

    try {
      // Calculate play time
      if (session['endTime'] != null && session['startTime'] != null) {
        final start = DateTime.parse(session['startTime']);
        final end = DateTime.parse(session['endTime']);
        totalPlayTime += end.difference(start).inMinutes;
      }

      // Add to chart data
      chartData = SessionChartData(
        date: DateTime.parse(session['startTime']),
        sessionNumber: sessionIndex + 1,
        totalHands: session['totalHands'] ?? 0,
        gameType: session['gameType'] ?? 'cash',
      );

      // Get hands for this session
      final sessionId = session['id'] as String;
      List<Map<String, dynamic>> hands;
      try {
        hands = await FirebaseService.getSessionHands(sessionId);
      } catch (e) {
        hands = await LocalStorageService.getSessionHands(sessionId);
      }

      sessionTotalHands = hands.length;

      // Get our seat number for win detection
      final ourSeatNumber = session['ourSeatNumber'] as int?;

      // Process hands for player statistics
      for (final hand in hands) {
        if (hand['actions'] != null) {
          final handResult = _processHandStatistics(hand, ourSeatNumber);
          if (handResult['playerInHand']) {
            sessionHandsPlayed++;
            if (handResult['playerVPIP']) sessionVpipHands++;
            if (handResult['playerPFR']) sessionPfrHands++;
            if (handResult['player3Bet']) sessionThreeBetHands++;
          }
          // Check wins separately - can win even without being in hand
          if (handResult['playerWon']) sessionWonHands++;
        }
      }
    } catch (e) {
      final sessionId = session['id'] ?? 'unknown';
      print('❌ Error processing session $sessionId: $e');
    }

    return {
      'totalHands': sessionTotalHands,
      'handsPlayed': sessionHandsPlayed,
      'vpipHands': sessionVpipHands,
      'pfrHands': sessionPfrHands,
      'threeBetHands': sessionThreeBetHands,
      'wonHands': sessionWonHands,
      'chartData': chartData,
    };
  }

  Map<String, dynamic> _processHandStatistics(Map<String, dynamic> hand, int? ourSeatNumber) {
    final actions = hand['actions'] as List<dynamic>;
    bool playerInHand = false;
    bool playerVPIP = false;
    bool playerPFR = false;
    bool player3Bet = false;
    bool playerWon = false;

    // Track betting sequence for 3-bet detection
    int preflopRaiseCount = 0;

    // Get current user's ID for matching with new action format
    final currentUserId = AuthService.currentUser?.uid;

    // For backward compatibility: Get current user's display name
    final currentUserName = AuthService.currentUser?.displayName ??
                           AuthService.currentUser?.email?.split('@')[0] ??
                           'User';

    // Check if any actions have the new isCurrentUser field
    bool hasNewFormat = false;
    for (final action in actions) {
      final actionMap = action as Map<String, dynamic>;
      if (actionMap.containsKey('isCurrentUser')) {
        hasNewFormat = true;
        break;
      }
    }

    print('📊 Processing hand with ${hasNewFormat ? 'NEW' : 'OLD'} format (userId: ${currentUserId?.substring(0, 8)}...)');

    // Second pass: analyze actions
    for (final action in actions) {
      final actionMap = action as Map<String, dynamic>;
      final actionType = actionMap['action'] as String?;
      final street = actionMap['street'] as String?;

      // Normalize street name
      final streetLower = street?.toLowerCase().trim() ?? '';

      // Track raises/bets by ANY player for sequence counting (ONLY preflop)
      if (streetLower == 'preflop' &&
          (actionType?.toLowerCase() == 'raise' || actionType?.toLowerCase() == 'bet')) {
        preflopRaiseCount++;
      }

      // Check if this action is by our player using new or old format
      bool isCurrentPlayerAction = false;

      if (hasNewFormat) {
        // Use new isCurrentUser field
        isCurrentPlayerAction = actionMap['isCurrentUser'] == true;
      } else {
        // Fallback to old name-based matching for backward compatibility
        final playerName = actionMap['playerName'] as String?;
        if (playerName != null &&
            (playerName.toLowerCase().contains('you') ||
             playerName.toLowerCase() == 'hero' ||
             playerName == currentUserName ||
             playerName.toLowerCase() == currentUserName.toLowerCase() ||
             playerName == 'Mike' || // Temporary fallback for old data
             playerName.toLowerCase().startsWith('player') && !playerName.contains(' '))) {
          isCurrentPlayerAction = true;
        }
      }

      if (isCurrentPlayerAction) {
        playerInHand = true;

        // Debug: print action details for our player
        print('🎯 Player action: street=$streetLower, action=${actionType?.toLowerCase()}');

        // ONLY process PREFLOP actions for VPIP, PFR, 3-bet
        if (streetLower == 'preflop') {
          // VPIP: Voluntarily put money in pot preflop
          // Includes: call (including limps), raise, bet
          // Excludes: fold, check
          if (actionType?.toLowerCase() == 'call' ||
              actionType?.toLowerCase() == 'bet' ||
              actionType?.toLowerCase() == 'raise') {
            playerVPIP = true;
            print('✅ VPIP counted for ${actionType}');
          }

          // PFR: Preflop Raise - ONLY count 'raise' or opening 'bet'
          // 'call' is NEVER a raise (even if it's first action/limp)
          // 'bet' counts as PFR only if it's truly an opening bet, not a limp
          if (actionType?.toLowerCase() == 'raise') {
            playerPFR = true;
            print('✅ PFR counted for RAISE');
          } else if (actionType?.toLowerCase() == 'bet') {
            // Only count 'bet' as PFR if there were no previous actions
            // (opening the pot counts as raise)
            // For now, count 'bet' as PFR since limps are logged as 'call'
            playerPFR = true;
            print('✅ PFR counted for BET');
          }

          // 3-Bet: Player raises when it's at least the 3rd aggressive action preflop
          // Must be a raise AND there must have been at least 1 raise before this one
          if (actionType?.toLowerCase() == 'raise' && preflopRaiseCount >= 2) {
            player3Bet = true;
            print('✅ 3-Bet counted');
          }
        }
      }
    }

    // Check if player won by comparing winnerId with ourSeatNumber
    // This is the single source of truth for win detection
    final winnerId = hand['winnerId'] as int?;
    if (winnerId != null && ourSeatNumber != null && winnerId == ourSeatNumber) {
      playerWon = true;
    }

    return {
      'playerInHand': playerInHand,
      'playerVPIP': playerVPIP,
      'playerPFR': playerPFR,
      'player3Bet': player3Bet,
      'playerWon': playerWon,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF161618),
      body: LoadingWrapper(
        isLoading: isLoading,
        loadingMessage: loadingMessage,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section - matching home screen style
                  Padding(
                    padding: EdgeInsets.fromLTRB(0, 32, 0, 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Statistics',
                              style: TextStyle(
                                fontSize: 32,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Overall performance',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF9A9A9A),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              margin: EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: Color(0xFF1F1F23),
                                borderRadius: BorderRadius.circular(14),
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
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Color(0xFF1F1F23),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: IconButton(
                                onPressed: isLoading ? null : _loadStatistics,
                                icon: Icon(
                                  Icons.refresh,
                                  color: isLoading ? Colors.grey : Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildBody(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              SizedBox(height: 16),
              Text(
                'Error loading statistics',
                style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                error!,
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadStatistics,
                icon: Icon(Icons.refresh),
                label: Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF5AC95A),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOverallStats(),
        SizedBox(height: 24),
        if (sessionChartData.isNotEmpty) ...[
          _buildSessionChart(),
          SizedBox(height: 24),
        ] else ...[
          _buildEmptySessionChart(),
          SizedBox(height: 24),
        ],
        _buildPositionalStats(),
        SizedBox(height: 24),
        _buildSessionStats(),
        SizedBox(height: 100),
      ],
    );
  }

  Widget _buildOverallStats() {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _buildStatCard('Total Hands', totalHands.toString(), iconPath: 'icons/hole_cards.png'),
        _buildStatCard('Hands Played', handsPlayed.toString(), iconPath: 'icons/hands_played.png'),
        _buildStatCard('VPIP', '${vpip.toStringAsFixed(1)}%', iconPath: 'icons/vpip.png'),
        _buildStatCard('PFR', '${pfr.toStringAsFixed(1)}%', iconPath: 'icons/bet.png'),
        _buildStatCard('3-Bet', '${threeBet.toStringAsFixed(1)}%', iconPath: 'icons/3bet.png'),
        _buildStatCard('Win Rate', '${winRate.toStringAsFixed(1)}%', iconPath: 'icons/throphy.png'),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, {String? iconPath}) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (iconPath != null)
                Image.asset(
                  iconPath,
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(0xFF5AC95A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.analytics,
                        color: Color(0xFF5AC95A),
                        size: 20,
                      ),
                    );
                  },
                ),
            ],
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySessionChart() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(0xFF5AC95A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Image.asset(
                  'icons/progress.png',
                  width: 20,
                  height: 20,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.trending_up,
                      color: Color(0xFF5AC95A),
                      size: 20,
                    );
                  },
                ),
              ),
              SizedBox(width: 16),
              Text(
                'Session Progress',
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
            height: 150,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    color: Color(0xFF9A9A9A),
                    size: 48,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Start playing a session to record the data',
                    style: TextStyle(
                      color: Color(0xFF9A9A9A),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionChart() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(0xFF5AC95A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Image.asset(
                  'icons/progress.png',
                  width: 20,
                  height: 20,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.trending_up,
                      color: Color(0xFF5AC95A),
                      size: 20,
                    );
                  },
                ),
              ),
              SizedBox(width: 16),
              Text(
                'Session Progress',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Text(
            'Chart would be implemented here with real data',
            style: TextStyle(
              color: Color(0xFF9A9A9A),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionalStats() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(0xFF5AC95A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Image.asset(
                  'icons/stats.png',
                  width: 20,
                  height: 20,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.table_chart,
                      color: Color(0xFF5AC95A),
                      size: 20,
                    );
                  },
                ),
              ),
              SizedBox(width: 16),
              Text(
                'Positional Statistics',
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
            height: 100,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.table_rows_outlined,
                    color: Color(0xFF9A9A9A),
                    size: 32,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Start playing a session to record the data',
                    style: TextStyle(
                      color: Color(0xFF9A9A9A),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionStats() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(0xFF5AC95A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Image.asset(
                  'icons/clock.png',
                  width: 20,
                  height: 20,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.access_time,
                      color: Color(0xFF5AC95A),
                      size: 20,
                    );
                  },
                ),
              ),
              SizedBox(width: 16),
              Text(
                'Session Statistics',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          if (totalSessions > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSessionStatItem('Sessions', totalSessions.toString()),
                _buildSessionStatItem('Total Time', '${(totalPlayTime / 60).toStringAsFixed(1)}h'),
                _buildSessionStatItem('Avg Session', totalSessions > 0 ? '${(totalPlayTime / totalSessions).toStringAsFixed(0)}m' : '0m'),
              ],
            ),
          ] else ...[
            Container(
              height: 80,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      color: Color(0xFF9A9A9A),
                      size: 24,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Start playing a session to record the data',
                      style: TextStyle(
                        color: Color(0xFF9A9A9A),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5AC95A),
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Color(0xFF9A9A9A),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

}

class SessionChartData {
  final DateTime date;
  final int sessionNumber;
  final int totalHands;
  final String gameType;

  SessionChartData({
    required this.date,
    required this.sessionNumber,
    required this.totalHands,
    required this.gameType,
  });
}

