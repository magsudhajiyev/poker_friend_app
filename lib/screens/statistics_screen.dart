import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
import '../services/auth_service.dart';
import '../services/user_stats_service.dart';
import '../widgets/global_loading_spinner.dart';
import '../widgets/global_bottom_nav_bar.dart';
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
  double fold3Bet = 0.0;
  double cbet = 0.0;
  double steal = 0.0;
  double checkRaise = 0.0;
  double winRate = 0.0;
  int totalSessions = 0;
  int totalPlayTime = 0;

  // Opportunity counts for N/A detection
  int threeBetOpportunity = 0;
  int facing3BetCount = 0;
  int cbetOpportunity = 0;
  int stealOpportunity = 0;
  int checkRaiseFlopOpportunity = 0;

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
    totalHands = 0;
    handsPlayed = 0;
    vpip = 0.0;
    pfr = 0.0;
    threeBet = 0.0;
    fold3Bet = 0.0;
    cbet = 0.0;
    steal = 0.0;
    checkRaise = 0.0;
    winRate = 0.0;
    totalSessions = 0;
    totalPlayTime = 0;

    threeBetOpportunity = 0;
    facing3BetCount = 0;
    cbetOpportunity = 0;
    stealOpportunity = 0;
    checkRaiseFlopOpportunity = 0;

    try {
      setState(() {
        loadingMessage = 'Fetching user stats...';
      });

      final userId = AuthService.userId;
      if (userId == null) return;

      final userStats = await UserStatsService.getUserStats(userId);
      if (userStats == null) return;

      totalHands = userStats.totalHands;
      handsPlayed = userStats.handsPlayed;
      totalSessions = userStats.totalSessions;
      totalPlayTime = userStats.totalPlayTimeMinutes;

      vpip = userStats.vpipPercentage;
      pfr = userStats.pfrPercentage;
      threeBet = userStats.threeBetPercentage;
      fold3Bet = userStats.fold3betPercentage;
      cbet = userStats.cbetPercentage;
      steal = userStats.stealPercentage;
      checkRaise = userStats.checkRaiseFlopPercentage;

      if (handsPlayed > 0) {
        winRate = (userStats.wonHands / handsPlayed) * 100;
      }

      threeBetOpportunity = userStats.threeBetOpportunity;
      facing3BetCount = userStats.facing3BetCount;
      cbetOpportunity = userStats.cbetOpportunity;
      stealOpportunity = userStats.stealOpportunity;
      checkRaiseFlopOpportunity = userStats.checkRaiseFlopOpportunity;

      setState(() {
        loadingMessage = 'Calculating positional stats...';
      });

      await _calculatePositionalStats();
    } catch (e) {
      print('Error calculating statistics: $e');
      throw e;
    }
  }

  Future<void> _calculatePositionalStats() async {
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

      final sessions = await FirebaseService.getAllSessions();
      final recentSessions = sessions.take(100).toList();

      for (final session in recentSessions) {
        final sessionId = session['id'] as String;
        final ourSeatNumber = session['ourSeatNumber'] as int?;
        if (ourSeatNumber == null) continue;

        List<Map<String, dynamic>> hands;
        try {
          hands = await FirebaseService.getSessionHands(sessionId);
        } catch (e) {
          continue;
        }

        for (final hand in hands) {
          final actions = hand['actions'] as List<dynamic>?;
          if (actions == null || actions.isEmpty) continue;

          String? ourPosition;
          bool playerVPIP = false;
          bool playerPFR = false;
          bool playerPlayed = false;

          for (final action in actions) {
            final actionMap = action as Map<String, dynamic>;
            if (actionMap['isCurrentUser'] != true) continue;

            ourPosition ??= actionMap['playerPosition'] as String?;
            playerPlayed = true;

            final street = actionMap['street'] as String?;
            if (street?.toLowerCase().trim() != 'preflop') continue;

            final actionType = actionMap['action']?.toString().toLowerCase();
            if (actionType == 'call' || actionType == 'bet' || actionType == 'raise') {
              playerVPIP = true;
            }
            if (actionType == 'raise' || actionType == 'bet') {
              playerPFR = true;
            }
          }

          if (ourPosition != null && positionalStats.containsKey(ourPosition)) {
            final stats = positionalStats[ourPosition]!;
            stats.totalHands++;
            if (playerPlayed) stats.playedHands++;
            if (playerVPIP) stats.vpipHands++;
            if (playerPFR) stats.pfrHands++;

            final winnerId = hand['winnerId'] as int?;
            if (winnerId == ourSeatNumber) {
              stats.wonHands++;
            }
          }
        }
      }
    } catch (e) {
      print('Error calculating positional stats: $e');
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
          // Teal radial gradient at top (matches opponent detail / home screens)
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
                      const Color(0xFF1A4A4A),
                      const Color(0xFF133538).withOpacity(0.7),
                      const Color(0xFF133538).withOpacity(0.3),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.3, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: LoadingWrapper(
              isLoading: isLoading,
              loadingMessage: loadingMessage,
              child: _buildContent(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: GlobalBottomNavBar(currentScreen: 'statistics'),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Header with back button on left, refresh on right
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Row(
            children: [
              // Back button (left side)
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3C3C43).withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statistics',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Advanced Analytics',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.6),
                        fontWeight: FontWeight.w400,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              // Refresh button (right side)
              GestureDetector(
                onTap: _loadStatistics,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3C3C43).withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverallStats(),
                const SizedBox(height: 32),
                _buildPositionalStats(),
                const SizedBox(height: 32),
                _buildSessionStats(),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverallStats() {
    String formatStat(double value, int opportunity) {
      if (opportunity == 0) return 'N/A';
      return '${value.toStringAsFixed(1)}%';
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131616),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistics',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          _buildStatListItem('Total Hands', totalHands.toString()),
          _buildDivider(),
          _buildStatListItem('Hands Played', handsPlayed.toString()),
          _buildDivider(),
          _buildStatListItem('VPIP', totalHands > 0 ? '${vpip.toStringAsFixed(1)}%' : 'N/A'),
          _buildDivider(),
          _buildStatListItem('PFR', totalHands > 0 ? '${pfr.toStringAsFixed(1)}%' : 'N/A'),
          _buildDivider(),
          _buildStatListItem('3-Bet', formatStat(threeBet, threeBetOpportunity)),
          _buildDivider(),
          _buildStatListItem('Fold to 3-Bet', formatStat(fold3Bet, facing3BetCount)),
          _buildDivider(),
          _buildStatListItem('C-Bet', formatStat(cbet, cbetOpportunity)),
          _buildDivider(),
          _buildStatListItem('Steal', formatStat(steal, stealOpportunity)),
          _buildDivider(),
          _buildStatListItem('Check/Raise', formatStat(checkRaise, checkRaiseFlopOpportunity)),
          _buildDivider(),
          _buildStatListItem('Win Rate', handsPlayed > 0 ? '${winRate.toStringAsFixed(1)}%' : 'N/A'),
        ],
      ),
    );
  }

  Widget _buildStatListItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.8),
              height: 1.0,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF89F1EC),
              height: 1.0,
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

  Widget _buildPositionalStats() {
    final hasData = positionalStats.values.any((stats) => stats.totalHands > 0);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131616),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Positional Statistics',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          if (!hasData)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Play sessions to see positional breakdowns',
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else ...[
            // Header row
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Position',
                      style: GoogleFonts.ibmPlexSans(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Hands',
                      style: GoogleFonts.ibmPlexSans(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'VPIP',
                      style: GoogleFonts.ibmPlexSans(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'PFR',
                      style: GoogleFonts.ibmPlexSans(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Win%',
                      style: GoogleFonts.ibmPlexSans(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            _buildDivider(),
            // Position rows
            ...['BTN', 'CO', 'HJ', 'LJ', 'UTG', 'SB', 'BB'].where((pos) {
              return positionalStats[pos]!.totalHands > 0;
            }).map((position) {
              final stats = positionalStats[position]!;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF89F1EC).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          position,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF89F1EC),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${stats.totalHands}',
                        style: GoogleFonts.ibmPlexSans(
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
                        style: GoogleFonts.ibmPlexSans(
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
                        style: GoogleFonts.ibmPlexSans(
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
                        style: GoogleFonts.ibmPlexSans(
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

  Widget _buildSessionStats() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131616),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session Statistics',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          if (totalSessions > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSessionStatItem('Sessions', totalSessions.toString()),
                Container(width: 1, height: 40, color: Colors.white.withOpacity(0.1)),
                _buildSessionStatItem('Total Time', '${(totalPlayTime / 60).toStringAsFixed(1)}h'),
                Container(width: 1, height: 40, color: Colors.white.withOpacity(0.1)),
                _buildSessionStatItem(
                  'Avg Session',
                  totalSessions > 0 ? '${(totalPlayTime / totalSessions).toStringAsFixed(0)}m' : '0m',
                ),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Play sessions to see time statistics',
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSessionStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF89F1EC),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white.withOpacity(0.4),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Color _getStatColor(double value, {bool isVPIP = false, bool isPFR = false, bool isWinRate = false}) {
    if (isWinRate) {
      if (value >= 50) return const Color(0xFF89F1EC);
      if (value >= 30) return Colors.white;
      return const Color(0xFFFF6B6B);
    }
    if (isVPIP) {
      if (value >= 15 && value <= 30) return const Color(0xFF89F1EC);
      if (value < 10 || value > 40) return const Color(0xFFFF6B6B);
      return Colors.white;
    }
    if (isPFR) {
      if (value >= 12 && value <= 25) return const Color(0xFF89F1EC);
      if (value < 8 || value > 35) return const Color(0xFFFF6B6B);
      return Colors.white;
    }
    return Colors.white;
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
