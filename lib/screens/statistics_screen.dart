import 'package:flutter/material.dart';
import 'dart:ui' as ui;
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
import 'profile_screen.dart';
import 'logging_mode_selection_screen.dart';
import 'session_history_screen.dart';
import 'home_screen_experimental.dart';
import 'my_opponents_screen.dart';
import '../widgets/global_bottom_nav_bar.dart';
import '../widgets/global_top_header.dart';
import '../design_system/design_system.dart';

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

  // Positional statistics
  Map<String, PositionalStats> positionalStats = {};

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

    } catch (e) {
      print('❌ Error calculating statistics: $e');
      throw e;
    }
  }

  Future<void> _calculatePositionalStats() async {
    // Initialize stats for common positions
    positionalStats = {
      'UTG': PositionalStats(),
      'LJ': PositionalStats(),
      'HJ': PositionalStats(),
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
      backgroundColor: Colors.black,
      extendBody: true,
      body: Stack(
        children: [
          // Gradient background from design system
          GradientBackground(),
          SafeArea(
            child: LoadingWrapper(
              isLoading: isLoading,
              loadingMessage: loadingMessage,
              child: _buildOverviewTab(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: GlobalBottomNavBar(currentScreen: 'statistics'),
    );
  }

  Widget _buildTopHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Profile Picture
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfileScreen()),
            );
          },
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ),
        // Right side icons
        Row(
          children: [
            // Statistics Icon
            GestureDetector(
              onTap: () {
                // Already on statistics screen
              },
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.bar_chart_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Notification Bell Icon
            GestureDetector(
              onTap: () {
                // TODO: Navigate to notifications
              },
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.notifications,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildBottomNavigationBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(35),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Home Icon
          IconButton(
            icon: Icon(Icons.home, color: Colors.white, size: 28),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomeScreenExperimental()),
              );
            },
          ),
          // Opponents Icon
          IconButton(
            icon: Icon(Icons.group, color: Colors.white, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MyOpponentsScreen()),
              );
            },
          ),
          // Center Plus Button
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFA5EC44),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.add, color: Colors.black, size: 32),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoggingModeSelectionScreen()),
                );
              },
            ),
          ),
          // Game/Cards Icon
          IconButton(
            icon: Icon(Icons.style, color: Colors.white, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SessionHistoryScreen()),
              );
            },
          ),
          // Profile Icon
          IconButton(
            icon: Icon(Icons.person, color: Colors.white, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Screen Header with glassmorphic blur
          MainScreenHeader(
            title: 'Statistics',
            subtitle: 'Advanced Analytics',
            leftIcon: Icons.arrow_back_rounded,
            onLeftPressed: () => Navigator.pop(context),
            rightIcon: Icons.refresh_rounded,
            onRightPressed: _loadStatistics,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          ),
          const SizedBox(height: 28),
          // Content with padding
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverallStats(),
                SizedBox(height: 40),
                _buildPositionalStats(),
                SizedBox(height: 40),
                _buildSessionStats(),
                SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildOverallStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recent Activity title
        Text(
          'RECENT ACTIVITY',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.w400,
            letterSpacing: 1.0,
            height: 1.0,
          ),
        ),
        SizedBox(height: 24),
        // Stats cards with dividers
        Column(
          children: [
            _buildStatCard('Total Hands', totalHands.toString()),
            _buildDivider(),
            _buildStatCard('Hands Played', handsPlayed.toString()),
            _buildDivider(),
            _buildStatCard('VPIP', '${vpip.toStringAsFixed(1)}%'),
            _buildDivider(),
            _buildStatCard('PFR', '${pfr.toStringAsFixed(1)}%'),
            _buildDivider(),
            _buildStatCard('3-Bet', '${threeBet.toStringAsFixed(1)}%'),
            _buildDivider(),
            _buildStatCard('Win Rate', '${winRate.toStringAsFixed(1)}%'),
          ],
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: EdgeInsets.symmetric(vertical: 16),
      color: Color(0x1AFFFFFF), // #ffffff1a - matches Figma design
    );
  }

  Widget _buildStatCard(String label, String value, {String? iconPath}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildPositionalStats() {
    final hasData = positionalStats.values.any((stats) => stats.totalHands > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          'POSITIONAL STATISTICS',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
            height: 1.0,
          ),
        ),
        SizedBox(height: 16),
        // Content
        if (!hasData)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Color(0x4C2C3E2E), // #2c3e2e4c - matches Figma design
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 44),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.table_chart,
                  size: 24,
                  color: Color(0xFFF8FFF7), // #f8fff7 - matches Figma design
                ),
                const SizedBox(height: 14),
                Text(
                  'Start playing a session to record the data',
                  style: TextStyle(
                    color: Color(0xFFF8FFF7), // #f8fff7 - matches Figma design
                    fontSize: 12,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
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
            ...['BTN', 'CO', 'HJ', 'LJ', 'UTG', 'SB', 'BB'].map((position) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          'SESSION STATISTICS',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
            height: 1.0,
          ),
        ),
        SizedBox(height: 16),
        // Content
        if (totalSessions > 0)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Color(0xFF1d2a27),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSessionStatItem('Sessions', totalSessions.toString()),
                _buildSessionStatItem('Total Time', '${(totalPlayTime / 60).toStringAsFixed(1)}h'),
                _buildSessionStatItem('Avg Session', totalSessions > 0 ? '${(totalPlayTime / totalSessions).toStringAsFixed(0)}m' : '0m'),
              ],
            ),
          )
        else
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Color(0x4C2C3E2E), // #2c3e2e4c - matches Figma design
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 44),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.access_time,
                  size: 24,
                  color: Color(0xFFF8FFF7), // #f8fff7 - matches Figma design
                ),
                const SizedBox(height: 14),
                Text(
                  'Start playing a session to record the data',
                  style: TextStyle(
                    color: Color(0xFFF8FFF7), // #f8fff7 - matches Figma design
                    fontSize: 12,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      ],
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
