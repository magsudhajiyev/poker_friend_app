import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
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

class _StatisticsScreenState extends State<StatisticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
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

  // Positional statistics
  Map<String, PositionalStats> positionalStats = {};

  // Time analysis data
  Map<String, TimeAnalysisStats> dayOfWeekStats = {};
  Map<String, TimeAnalysisStats> timeOfDayStats = {};

  // Trends data
  List<SessionTrend> sessionTrends = [];
  int currentStreak = 0;
  bool isWinningStreak = false;
  int longestWinStreak = 0;
  int longestLossStreak = 0;

  // Loading state details
  String loadingMessage = 'Loading statistics...';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStatistics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

      print('📊 Stats from UserStatsService: Total Hands: $totalHands, Hands Played: $handsPlayed, Won: ${userStats.wonHands}, Win Rate: ${winRate.toStringAsFixed(1)}%');

      setState(() {
        loadingMessage = 'Calculating positional stats...';
      });

      // Calculate positional statistics
      await _calculatePositionalStats();

      setState(() {
        loadingMessage = 'Analyzing time patterns...';
      });

      // Calculate time analysis
      await _calculateTimeAnalysis();

      setState(() {
        loadingMessage = 'Calculating trends...';
      });

      // Calculate trends and streaks
      await _calculateTrends();

    } catch (e) {
      print('❌ Error calculating statistics: $e');
      throw e;
    }
  }

  Future<void> _calculatePositionalStats() async {
    // Initialize stats for common positions
    positionalStats = {
      'UTG': PositionalStats(),
      'MP': PositionalStats(),
      'CO': PositionalStats(),
      'BTN': PositionalStats(),
      'SB': PositionalStats(),
      'BB': PositionalStats(),
    };

    try {
      final userId = AuthService.userId;
      if (userId == null) return;

      // Get recent sessions only (limit to 100 for performance)
      final sessions = await FirebaseService.getAllSessions();
      final recentSessions = sessions.take(100).toList();

      // Process sessions in batches for better performance
      for (final session in recentSessions) {
        final sessionId = session['id'] as String;
        final ourSeatNumber = session['ourSeatNumber'] as int?;
        if (ourSeatNumber == null) continue;

        // Get hands for this session
        List<Map<String, dynamic>> hands;
        try {
          hands = await FirebaseService.getSessionHands(sessionId);
        } catch (e) {
          continue; // Skip this session if we can't load hands
        }

        // Process each hand
        for (final hand in hands) {
          final actions = hand['actions'] as List<dynamic>?;
          if (actions == null || actions.isEmpty) continue;

          // Quick scan to find our position and stats
          String? ourPosition;
          bool playerVPIP = false;
          bool playerPFR = false;
          bool playerPlayed = false;

          // Single pass through actions
          for (final action in actions) {
            final actionMap = action as Map<String, dynamic>;

            // Check if this is our action
            if (actionMap['isCurrentUser'] != true) continue;

            // Get position from first action
            ourPosition ??= actionMap['playerPosition'] as String?;

            playerPlayed = true;

            // Only process preflop actions for VPIP/PFR
            final street = actionMap['street'] as String?;
            if (street?.toLowerCase().trim() != 'preflop') continue;

            final actionType = actionMap['action']?.toString().toLowerCase();

            // VPIP check
            if (actionType == 'call' || actionType == 'bet' || actionType == 'raise') {
              playerVPIP = true;
            }

            // PFR check
            if (actionType == 'raise' || actionType == 'bet') {
              playerPFR = true;
            }
          }

          // Update stats if we found our position
          if (ourPosition != null && positionalStats.containsKey(ourPosition)) {
            final stats = positionalStats[ourPosition]!;
            stats.totalHands++;

            if (playerPlayed) stats.playedHands++;
            if (playerVPIP) stats.vpipHands++;
            if (playerPFR) stats.pfrHands++;

            // Check if we won
            final winnerId = hand['winnerId'] as int?;
            if (winnerId == ourSeatNumber) {
              stats.wonHands++;
            }
          }
        }
      }

      print('📊 Positional Stats (${recentSessions.length} sessions):');
      positionalStats.forEach((position, stats) {
        if (stats.totalHands > 0) {
          print('  $position: ${stats.totalHands} hands, VPIP: ${stats.vpipPercentage.toStringAsFixed(1)}%, PFR: ${stats.pfrPercentage.toStringAsFixed(1)}%, Win: ${stats.winRate.toStringAsFixed(1)}%');
        }
      });

    } catch (e) {
      print('❌ Error calculating positional stats: $e');
    }
  }

  Future<void> _calculateTimeAnalysis() async {
    // Initialize day of week stats
    dayOfWeekStats = {
      'Monday': TimeAnalysisStats(),
      'Tuesday': TimeAnalysisStats(),
      'Wednesday': TimeAnalysisStats(),
      'Thursday': TimeAnalysisStats(),
      'Friday': TimeAnalysisStats(),
      'Saturday': TimeAnalysisStats(),
      'Sunday': TimeAnalysisStats(),
    };

    // Initialize time of day stats
    timeOfDayStats = {
      'Morning': TimeAnalysisStats(),    // 6am-12pm
      'Afternoon': TimeAnalysisStats(),  // 12pm-6pm
      'Evening': TimeAnalysisStats(),    // 6pm-12am
      'Night': TimeAnalysisStats(),      // 12am-6am
    };

    try {
      final sessions = await FirebaseService.getAllSessions();

      for (final session in sessions) {
        final startTimeStr = session['startTime'];
        if (startTimeStr == null) continue;

        final startTime = startTimeStr is Timestamp
            ? startTimeStr.toDate()
            : DateTime.parse(startTimeStr);

        // Calculate profit for this session
        final profit = _calculateSessionProfit(session);

        // Day of week analysis
        final dayOfWeek = DateFormat('EEEE').format(startTime);
        if (dayOfWeekStats.containsKey(dayOfWeek)) {
          dayOfWeekStats[dayOfWeek]!.addSession(profit);
        }

        // Time of day analysis
        final hour = startTime.hour;
        String timeOfDay;
        if (hour >= 6 && hour < 12) {
          timeOfDay = 'Morning';
        } else if (hour >= 12 && hour < 18) {
          timeOfDay = 'Afternoon';
        } else if (hour >= 18 && hour < 24) {
          timeOfDay = 'Evening';
        } else {
          timeOfDay = 'Night';
        }
        timeOfDayStats[timeOfDay]!.addSession(profit);
      }

      print('📊 Time Analysis calculated');
    } catch (e) {
      print('❌ Error calculating time analysis: $e');
    }
  }

  Future<void> _calculateTrends() async {
    sessionTrends.clear();
    currentStreak = 0;
    isWinningStreak = false;
    longestWinStreak = 0;
    longestLossStreak = 0;

    try {
      final sessions = await FirebaseService.getAllSessions();

      // Sort by start time
      sessions.sort((a, b) {
        final aTime = a['startTime'];
        final bTime = b['startTime'];
        if (aTime == null || bTime == null) return 0;

        final aDate = aTime is Timestamp ? aTime.toDate() : DateTime.parse(aTime);
        final bDate = bTime is Timestamp ? bTime.toDate() : DateTime.parse(bTime);
        return aDate.compareTo(bDate);
      });

      int tempWinStreak = 0;
      int tempLossStreak = 0;

      for (final session in sessions) {
        final profit = _calculateSessionProfit(session);
        final startTimeStr = session['startTime'];

        DateTime? date;
        if (startTimeStr != null) {
          date = startTimeStr is Timestamp
              ? startTimeStr.toDate()
              : DateTime.parse(startTimeStr);
        }

        sessionTrends.add(SessionTrend(
          date: date ?? DateTime.now(),
          profit: profit,
          sessionName: session['sessionName'] ?? 'Session',
        ));

        // Track streaks
        if (profit > 0) {
          tempWinStreak++;
          tempLossStreak = 0;
          currentStreak = tempWinStreak;
          isWinningStreak = true;
          if (tempWinStreak > longestWinStreak) {
            longestWinStreak = tempWinStreak;
          }
        } else if (profit < 0) {
          tempLossStreak++;
          tempWinStreak = 0;
          currentStreak = tempLossStreak;
          isWinningStreak = false;
          if (tempLossStreak > longestLossStreak) {
            longestLossStreak = tempLossStreak;
          }
        }
      }

      print('📊 Trends calculated: ${sessionTrends.length} sessions');
    } catch (e) {
      print('❌ Error calculating trends: $e');
    }
  }

  double _calculateSessionProfit(Map<String, dynamic> session) {
    // For individual sessions or cash games
    if (session['currentStack'] != null && session['totalBuyIn'] != null) {
      final currentStack = (session['currentStack'] as num).toDouble();
      final totalBuyIn = (session['totalBuyIn'] as num).toDouble();
      return currentStack - totalBuyIn;
    }

    // Default to 0 if we can't calculate
    return 0.0;
  }

  Future<Map<String, dynamic>> _processSingleSession(Map<String, dynamic> session, int sessionIndex) async {
    int sessionTotalHands = 0;
    int sessionHandsPlayed = 0;
    int sessionVpipHands = 0;
    int sessionPfrHands = 0;
    int sessionThreeBetHands = 0;
    int sessionWonHands = 0;

    try {
      // Calculate play time
      if (session['endTime'] != null && session['startTime'] != null) {
        final start = DateTime.parse(session['startTime']);
        final end = DateTime.parse(session['endTime']);
        totalPlayTime += end.difference(start).inMinutes;
      }

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
          child: Column(
            children: [
              // Header Section
              Padding(
                padding: EdgeInsets.fromLTRB(24, 32, 24, 16),
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
                          'Advanced Analytics',
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
              // Tabs
              Container(
                margin: EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Color(0xFF1F1F23),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: Color(0xFF5AC95A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Color(0xFF9A9A9A),
                  labelStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: [
                    Tab(text: 'Overview'),
                    Tab(text: 'Time'),
                    Tab(text: 'Trends'),
                  ],
                ),
              ),
              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildTimeAnalysisTab(),
                    _buildTrendsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOverallStats(),
          SizedBox(height: 24),
          _buildPositionalStats(),
          SizedBox(height: 24),
          _buildSessionStats(),
          SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildTimeAnalysisTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          _buildDayOfWeekStats(),
          SizedBox(height: 24),
          _buildTimeOfDayStats(),
          SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildTrendsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          _buildStreakStats(),
          SizedBox(height: 24),
          _buildProfitChart(),
          SizedBox(height: 100),
        ],
      ),
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


  Widget _buildPositionalStats() {
    final hasData = positionalStats.values.any((stats) => stats.totalHands > 0);

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
          if (!hasData)
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
            )
          else ...[
            // Header row
            Container(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: Color(0xFF161618),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Position',
                      style: TextStyle(
                        color: Color(0xFF9A9A9A),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Hands',
                      style: TextStyle(
                        color: Color(0xFF9A9A9A),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'VPIP',
                      style: TextStyle(
                        color: Color(0xFF9A9A9A),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'PFR',
                      style: TextStyle(
                        color: Color(0xFF9A9A9A),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Win%',
                      style: TextStyle(
                        color: Color(0xFF9A9A9A),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            // Position rows
            ...['BTN', 'CO', 'MP', 'UTG', 'SB', 'BB'].map((position) {
              final stats = positionalStats[position]!;
              if (stats.totalHands == 0) return SizedBox.shrink();

              return Container(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                margin: EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Color(0xFF161618).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Color(0xFF5AC95A).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          position,
                          style: TextStyle(
                            color: Color(0xFF5AC95A),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${stats.totalHands}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${stats.vpipPercentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: _getStatColor(stats.vpipPercentage, isVPIP: true),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${stats.pfrPercentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: _getStatColor(stats.pfrPercentage, isPFR: true),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${stats.winRate.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: _getStatColor(stats.winRate, isWinRate: true),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  Color _getStatColor(double value, {bool isVPIP = false, bool isPFR = false, bool isWinRate = false}) {
    if (isWinRate) {
      if (value >= 50) return Color(0xFF5AC95A); // Green for good win rate
      if (value >= 30) return Colors.white; // White for okay
      return Color(0xFFFF6B6B); // Red for low win rate
    }

    if (isVPIP) {
      if (value >= 15 && value <= 30) return Color(0xFF5AC95A); // Green for solid VPIP
      if (value < 10 || value > 40) return Color(0xFFFF6B6B); // Red for too tight or loose
      return Colors.white; // White for acceptable
    }

    if (isPFR) {
      if (value >= 12 && value <= 25) return Color(0xFF5AC95A); // Green for good PFR
      if (value < 8 || value > 35) return Color(0xFFFF6B6B); // Red for too passive or aggressive
      return Colors.white; // White for acceptable
    }

    return Colors.white;
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

  Widget _buildDayOfWeekStats() {
    final hasData = dayOfWeekStats.values.any((stats) => stats.sessions > 0);

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
                child: Icon(
                  Icons.calendar_today,
                  color: Color(0xFF5AC95A),
                  size: 20,
                ),
              ),
              SizedBox(width: 16),
              Text(
                'Performance by Day',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          if (!hasData)
            Container(
              height: 100,
              child: Center(
                child: Text(
                  'Start playing sessions to see patterns',
                  style: TextStyle(
                    color: Color(0xFF9A9A9A),
                    fontSize: 16,
                  ),
                ),
              ),
            )
          else ...[
            // Header row
            Container(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: Color(0xFF161618),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Day',
                      style: TextStyle(
                        color: Color(0xFF9A9A9A),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Sessions',
                      style: TextStyle(
                        color: Color(0xFF9A9A9A),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Profit',
                      style: TextStyle(
                        color: Color(0xFF9A9A9A),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Win%',
                      style: TextStyle(
                        color: Color(0xFF9A9A9A),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            // Day rows
            ...['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
                .map((day) {
              final stats = dayOfWeekStats[day]!;
              if (stats.sessions == 0) return SizedBox.shrink();

              return Container(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                margin: EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Color(0xFF161618).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        day.substring(0, 3),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${stats.sessions}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '\$${stats.totalProfit.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: stats.totalProfit >= 0
                              ? Color(0xFF5AC95A)
                              : Color(0xFFFF6B6B),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${stats.winRate.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: _getStatColor(stats.winRate, isWinRate: true),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeOfDayStats() {
    final hasData = timeOfDayStats.values.any((stats) => stats.sessions > 0);

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
                child: Icon(
                  Icons.access_time,
                  color: Color(0xFF5AC95A),
                  size: 20,
                ),
              ),
              SizedBox(width: 16),
              Text(
                'Performance by Time',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          if (!hasData)
            Container(
              height: 100,
              child: Center(
                child: Text(
                  'Start playing sessions to see patterns',
                  style: TextStyle(
                    color: Color(0xFF9A9A9A),
                    fontSize: 16,
                  ),
                ),
              ),
            )
          else
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _buildTimeOfDayCard('Morning', '6am-12pm', timeOfDayStats['Morning']!),
                _buildTimeOfDayCard('Afternoon', '12pm-6pm', timeOfDayStats['Afternoon']!),
                _buildTimeOfDayCard('Evening', '6pm-12am', timeOfDayStats['Evening']!),
                _buildTimeOfDayCard('Night', '12am-6am', timeOfDayStats['Night']!),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTimeOfDayCard(String period, String timeRange, TimeAnalysisStats stats) {
    if (stats.sessions == 0) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFF161618).withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              period,
              style: TextStyle(
                color: Color(0xFF9A9A9A),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'No data',
              style: TextStyle(
                color: Color(0xFF9A9A9A),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: stats.totalProfit >= 0
              ? Color(0xFF5AC95A).withOpacity(0.3)
              : Color(0xFFFF6B6B).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                period,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                timeRange,
                style: TextStyle(
                  color: Color(0xFF9A9A9A),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '\$${stats.totalProfit.toStringAsFixed(0)}',
                style: TextStyle(
                  color: stats.totalProfit >= 0
                      ? Color(0xFF5AC95A)
                      : Color(0xFFFF6B6B),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${stats.sessions} sessions • ${stats.winRate.toStringAsFixed(0)}% win',
                style: TextStyle(
                  color: Color(0xFF9A9A9A),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreakStats() {
    final hasData = sessionTrends.isNotEmpty;

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
                child: Icon(
                  Icons.trending_up,
                  color: Color(0xFF5AC95A),
                  size: 20,
                ),
              ),
              SizedBox(width: 16),
              Text(
                'Streaks',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          if (!hasData)
            Container(
              height: 100,
              child: Center(
                child: Text(
                  'Start playing sessions to track streaks',
                  style: TextStyle(
                    color: Color(0xFF9A9A9A),
                    fontSize: 16,
                  ),
                ),
              ),
            )
          else
            Column(
              children: [
                // Current Streak
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFF161618),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Streak',
                            style: TextStyle(
                              color: Color(0xFF9A9A9A),
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                isWinningStreak
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                color: isWinningStreak
                                    ? Color(0xFF5AC95A)
                                    : Color(0xFFFF6B6B),
                                size: 28,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '$currentStreak',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            isWinningStreak ? 'Winning sessions' : 'Losing sessions',
                            style: TextStyle(
                              color: isWinningStreak
                                  ? Color(0xFF5AC95A)
                                  : Color(0xFFFF6B6B),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                // Best Streaks
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Color(0xFF161618),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.local_fire_department,
                                  color: Color(0xFF5AC95A),
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Best Win',
                                  style: TextStyle(
                                    color: Color(0xFF9A9A9A),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              '$longestWinStreak',
                              style: TextStyle(
                                color: Color(0xFF5AC95A),
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'sessions',
                              style: TextStyle(
                                color: Color(0xFF9A9A9A),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Color(0xFF161618),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.trending_down,
                                  color: Color(0xFFFF6B6B),
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Worst Loss',
                                  style: TextStyle(
                                    color: Color(0xFF9A9A9A),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              '$longestLossStreak',
                              style: TextStyle(
                                color: Color(0xFFFF6B6B),
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'sessions',
                              style: TextStyle(
                                color: Color(0xFF9A9A9A),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildProfitChart() {
    if (sessionTrends.isEmpty) {
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
                  child: Icon(
                    Icons.show_chart,
                    color: Color(0xFF5AC95A),
                    size: 20,
                  ),
                ),
                SizedBox(width: 16),
                Text(
                  'Profit Trend',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 40),
            Center(
              child: Text(
                'Start playing sessions to see your profit trend',
                style: TextStyle(
                  color: Color(0xFF9A9A9A),
                  fontSize: 16,
                ),
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      );
    }

    // Calculate cumulative profit for chart
    List<FlSpot> spots = [];
    double cumulativeProfit = 0;
    for (int i = 0; i < sessionTrends.length; i++) {
      cumulativeProfit += sessionTrends[i].profit;
      spots.add(FlSpot(i.toDouble(), cumulativeProfit));
    }

    // Find min and max for chart scaling
    double minProfit = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    double maxProfit = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    // Add padding to min/max
    double range = maxProfit - minProfit;

    // Ensure minimum range to avoid zero interval error
    if (range < 0.01) {
      // If all values are the same, create a range around that value
      final centerValue = minProfit;
      final minRange = 100.0; // Minimum range of $100
      minProfit = centerValue - (minRange / 2);
      maxProfit = centerValue + (minRange / 2);
      range = minRange;
    } else {
      // Add 10% padding to min/max
      minProfit = minProfit - (range * 0.1);
      maxProfit = maxProfit + (range * 0.1);
      range = maxProfit - minProfit;
    }

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    child: Icon(
                      Icons.show_chart,
                      color: Color(0xFF5AC95A),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 16),
                  Text(
                    'Profit Trend',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                '\$${cumulativeProfit.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 20,
                  color: cumulativeProfit >= 0
                      ? Color(0xFF5AC95A)
                      : Color(0xFFFF6B6B),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          Container(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: range / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Color(0xFF9A9A9A).withOpacity(0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: spots.length > 10 ? spots.length / 5 : 1,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < sessionTrends.length) {
                          final date = sessionTrends[value.toInt()].date;
                          return Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('M/d').format(date),
                              style: TextStyle(
                                color: Color(0xFF9A9A9A),
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: range / 4,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '\$${value.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: Color(0xFF9A9A9A),
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: spots.length - 1.0,
                minY: minProfit,
                maxY: maxProfit,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: cumulativeProfit >= 0
                        ? Color(0xFF5AC95A)
                        : Color(0xFFFF6B6B),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: spots.length <= 20,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: cumulativeProfit >= 0
                              ? Color(0xFF5AC95A)
                              : Color(0xFFFF6B6B),
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: (cumulativeProfit >= 0
                              ? Color(0xFF5AC95A)
                              : Color(0xFFFF6B6B))
                          .withOpacity(0.1),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => Color(0xFF161618),
                    tooltipRoundedRadius: 8,
                    tooltipPadding: EdgeInsets.all(8),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((LineBarSpot touchedSpot) {
                        final index = touchedSpot.x.toInt();
                        if (index >= 0 && index < sessionTrends.length) {
                          final trend = sessionTrends[index];
                          return LineTooltipItem(
                            '${DateFormat('MMM d').format(trend.date)}\n\$${touchedSpot.y.toStringAsFixed(0)}',
                            TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }
                        return null;
                      }).toList();
                    },
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

class PositionalStats {
  int totalHands = 0;
  int vpipHands = 0;
  int pfrHands = 0;
  int wonHands = 0;
  int playedHands = 0;

  double get vpipPercentage => totalHands > 0 ? (vpipHands / totalHands) * 100 : 0.0;
  double get pfrPercentage => totalHands > 0 ? (pfrHands / totalHands) * 100 : 0.0;
  double get winRate => playedHands > 0 ? (wonHands / playedHands) * 100 : 0.0;
}

class TimeAnalysisStats {
  int sessions = 0;
  double totalProfit = 0.0;
  int winCount = 0;

  void addSession(double profit) {
    sessions++;
    totalProfit += profit;
    if (profit > 0) winCount++;
  }

  double get winRate => sessions > 0 ? (winCount / sessions) * 100 : 0.0;
}

class SessionTrend {
  final DateTime date;
  final double profit;
  final String sessionName;

  SessionTrend({
    required this.date,
    required this.profit,
    required this.sessionName,
  });
}

