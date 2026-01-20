import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../models/opponent.dart';
import '../models/opponent_stats.dart';
import '../services/opponent_service.dart';
import '../services/local_storage_service.dart';
import '../services/firebase_service.dart';
import '../services/opponent_stats_service.dart';
import 'opponent_hands_screen.dart';
import '../widgets/global_top_header.dart';
import '../widgets/global_bottom_nav_bar.dart';

class OpponentDetailScreen extends StatefulWidget {
  final Opponent opponent;

  const OpponentDetailScreen({
    Key? key,
    required this.opponent,
  }) : super(key: key);

  @override
  State<OpponentDetailScreen> createState() => _OpponentDetailScreenState();
}

class _OpponentDetailScreenState extends State<OpponentDetailScreen> {
  late Opponent _opponent;
  Map<String, dynamic>? _statistics;
  OpponentStats? _opponentStats; // Store the actual OpponentStats object
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _opponent = widget.opponent;
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      // Load stats from optimized structure - no recalculation needed!
      final stats = await _calculateOpponentStatistics(_opponent.name);
      final opponentStats = await OpponentStatsService.getOpponentStats(_opponent.name);
      setState(() {
        _statistics = stats;
        _opponentStats = opponentStats;
        _isLoadingStats = false;
      });
    } catch (e) {
      print('Error loading statistics: $e');
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  Future<Map<String, dynamic>> _calculateOpponentStatistics(String opponentName) async {
    try {
      // 🚀 OPTIMIZED: Fast O(1) stats lookup from dedicated table
      final optimizedStats = await OpponentStatsService.getOpponentStats(opponentName);

      if (optimizedStats != null) {
        print('✅ Using optimized stats for $opponentName (${optimizedStats.handsPlayed} hands)');
        final legacyMap = optimizedStats.toLegacyStatsMap();
        print('🔍 DEBUG: Legacy map for $opponentName: totalHands=${legacyMap['totalHands']}, totalSessions=${legacyMap['totalSessions']}');
        return legacyMap;
      } else {
        print('⚠️ No optimized stats found for $opponentName - calculating from hand data');
        // Fall back to legacy calculation method
        return await _calculateLegacyOpponentStatistics(opponentName);
      }
    } catch (e) {
      print('❌ Error loading optimized stats: $e');
      return {
        'handsPlayed': 0,
        'vpip': 0.0,
        'pfr': 0.0,
        'aggression': 0.0,
        'actions': {
          'preflop': {'fold': 0, 'call': 0, 'bet': 0, 'raise': 0},
          'flop': {'fold': 0, 'call': 0, 'bet': 0, 'raise': 0},
          'turn': {'fold': 0, 'call': 0, 'bet': 0, 'raise': 0},
          'river': {'fold': 0, 'call': 0, 'bet': 0, 'raise': 0},
        },
      };
    }
  }

  /// Legacy calculation method used as fallback when optimized stats not available
  Future<Map<String, dynamic>> _calculateLegacyOpponentStatistics(String opponentName) async {
    try {
      // Initialize counters
      int totalHands = 0;
      int totalSessions = 0;
      int vpipHands = 0;
      int pfrHands = 0;
      int foldCount = 0;
      int callCount = 0;
      int betCount = 0;
      int raiseCount = 0;
      int checkCount = 0;
      int aggressiveActions = 0;
      int passiveActions = 0;

      Set<String> sessionsPlayed = <String>{};

      // Get all sessions
      List<Map<String, dynamic>> sessions;
      try {
        sessions = await FirebaseService.getAllSessions();
        print('🔍 DEBUG: Found ${sessions.length} sessions from Firebase');
      } catch (e) {
        sessions = await LocalStorageService.getUserSessions();
        print('🔍 DEBUG: Found ${sessions.length} sessions from local storage');
      }

      // Process each session
      for (final session in sessions) {
        final sessionId = session['id'] as String;
        final playerNames = session['playerNames'] as Map<String, dynamic>?;

        if (playerNames != null) {
          // Check if opponent played in this session
          bool opponentInSession = false;
          print('🔍 DEBUG: Session $sessionId has players: ${playerNames.values.toList()}');
          for (final playerName in playerNames.values) {
            print('🔍 DEBUG: Comparing "${playerName.toString().toLowerCase()}" with "${opponentName.toLowerCase()}"');
            if (playerName.toString().toLowerCase() == opponentName.toLowerCase()) {
              opponentInSession = true;
              print('✅ DEBUG: Found $opponentName in session $sessionId');
              break;
            }
          }

          if (opponentInSession) {
            sessionsPlayed.add(sessionId);

            // Get hands for this session
            List<Map<String, dynamic>> hands;
            try {
              hands = await FirebaseService.getSessionHands(sessionId);
              print('🔍 DEBUG: Found ${hands.length} hands in Firebase for session $sessionId');
            } catch (e) {
              hands = await LocalStorageService.getSessionHands(sessionId);
              print('🔍 DEBUG: Found ${hands.length} hands in local storage for session $sessionId');
            }

            // Process each hand
            for (final hand in hands) {
              bool opponentInThisHand = false;
              bool vpipThisHand = false;
              bool pfrThisHand = false;

              // Process actions if available
              if (hand['actions'] != null) {
                final actions = hand['actions'] as List<dynamic>;
                String currentStreet = 'preflop';

                for (final action in actions) {
                  final actionMap = action as Map<String, dynamic>;
                  final actionPlayerName = actionMap['playerName'] as String?;
                  final actionType = actionMap['action'] as String?;
                  final street = actionMap['street'] as String?;

                  if (street != null) {
                    currentStreet = street.toLowerCase();
                  }

                  if (actionPlayerName != null && actionType != null &&
                      actionPlayerName.toLowerCase().contains(opponentName.toLowerCase())) {

                    opponentInThisHand = true;
                    final actionKey = actionType.toLowerCase();

                    // Count action types
                    switch (actionKey) {
                      case 'fold':
                        foldCount++;
                        break;
                      case 'call':
                        callCount++;
                        passiveActions++;
                        if (currentStreet == 'preflop' && !vpipThisHand) {
                          vpipThisHand = true;
                        }
                        break;
                      case 'bet':
                        betCount++;
                        aggressiveActions++;
                        if (currentStreet == 'preflop') {
                          if (!vpipThisHand) vpipThisHand = true;
                          if (!pfrThisHand) pfrThisHand = true;
                        }
                        break;
                      case 'raise':
                        raiseCount++;
                        aggressiveActions++;
                        if (currentStreet == 'preflop') {
                          if (!vpipThisHand) vpipThisHand = true;
                          if (!pfrThisHand) pfrThisHand = true;
                        }
                        break;
                      case 'check':
                        checkCount++;
                        passiveActions++;
                        break;
                    }
                  }
                }
              }

              // Only count the hand if opponent participated
              if (opponentInThisHand) {
                totalHands++;
                if (vpipThisHand) vpipHands++;
                if (pfrThisHand) pfrHands++;
              }
            }
          }
        }
      }

      totalSessions = sessionsPlayed.length;

      // Calculate percentages
      final vpip = totalHands > 0 ? (vpipHands / totalHands * 100) : 0.0;
      final pfr = totalHands > 0 ? (pfrHands / totalHands * 100) : 0.0;
      final foldPercentage = totalHands > 0 ? (foldCount / totalHands * 100) : 0.0;
      final callPercentage = totalHands > 0 ? (callCount / totalHands * 100) : 0.0;
      final betPercentage = totalHands > 0 ? (betCount / totalHands * 100) : 0.0;
      final raisePercentage = totalHands > 0 ? (raiseCount / totalHands * 100) : 0.0;
      final checkPercentage = totalHands > 0 ? (checkCount / totalHands * 100) : 0.0;

      final totalActions = aggressiveActions + passiveActions;
      final aggression = totalActions > 0 ? (aggressiveActions / totalActions) : 0.0;

      print('📊 Calculated legacy stats for $opponentName: $totalHands hands, VPIP: ${vpip.toStringAsFixed(1)}%, PFR: ${pfr.toStringAsFixed(1)}%');

      return {
        'totalHands': totalHands,
        'totalSessions': totalSessions,
        'vpip': vpip,
        'pfr': pfr,
        'aggression': aggression,
        'foldPercentage': foldPercentage,
        'callPercentage': callPercentage,
        'betPercentage': betPercentage,
        'raisePercentage': raisePercentage,
        'checkPercentage': checkPercentage,
        'actions': {
          'preflop': {'fold': foldCount, 'call': callCount, 'bet': betCount, 'raise': raiseCount},
          'flop': {'fold': 0, 'call': 0, 'bet': 0, 'raise': 0},
          'turn': {'fold': 0, 'call': 0, 'bet': 0, 'raise': 0},
          'river': {'fold': 0, 'call': 0, 'bet': 0, 'raise': 0},
        },
      };
    } catch (e) {
      print('❌ Error calculating legacy stats: $e');
      return {
        'totalHands': 0,
        'totalSessions': 0,
        'vpip': 0.0,
        'pfr': 0.0,
        'aggression': 0.0,
        'foldPercentage': 0.0,
        'callPercentage': 0.0,
        'betPercentage': 0.0,
        'raisePercentage': 0.0,
        'checkPercentage': 0.0,
        'actions': {
          'preflop': {'fold': 0, 'call': 0, 'bet': 0, 'raise': 0},
          'flop': {'fold': 0, 'call': 0, 'bet': 0, 'raise': 0},
          'turn': {'fold': 0, 'call': 0, 'bet': 0, 'raise': 0},
          'river': {'fold': 0, 'call': 0, 'bet': 0, 'raise': 0},
        },
      };
    }
  }


  Color _getColorForOpponent(OpponentColor color) {
    switch (color) {
      case OpponentColor.red:
        return Colors.red;
      case OpponentColor.blue:
        return Colors.blue;
      case OpponentColor.green:
        return Colors.green;
      case OpponentColor.orange:
        return Colors.orange;
      case OpponentColor.purple:
        return Colors.purple;
      case OpponentColor.teal:
        return Colors.teal;
      case OpponentColor.pink:
        return Colors.pink;
      case OpponentColor.indigo:
        return Colors.indigo;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Green gradient background overlay at top
          Positioned(
            left: -98,
            top: -148,
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 132, sigmaY: 132),
                child: Container(
                  width: 595,
                  height: 727,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFFABFFB4).withOpacity(0.6),
                        const Color(0xFF006434).withOpacity(0.6),
                        const Color(0xFF000000).withOpacity(0.6),
                      ],
                      stops: [0.0, 0.32, 1.0],
                    ),
                    borderRadius: BorderRadius.all(Radius.elliptical(297.5, 363.5)),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
            // Global Top Header
            Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: GlobalTopHeader(currentScreen: 'opponent_detail'),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBasicInfoCard(),
                    const SizedBox(height: 16),
                    _buildStatisticsCard(),
                    const SizedBox(height: 16),
                    _buildActionDistributionCard(),
                    const SizedBox(height: 16),
                    _buildHandsButton(),
                    const SizedBox(height: 20), // Bottom padding for nav bar
                  ],
                ),
              ),
            ),

            // Global Bottom Navigation Bar
            GlobalBottomNavBar(currentScreen: 'opponent_detail'),
          ],
        ),
      ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    final cardColor = _getColorForOpponent(_opponent.color);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 45, sigmaY: 45),
        child: Container(
          decoration: BoxDecoration(
            color: Color(0xFF546165).withOpacity(0.74),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top section: User info + hands count
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: CardIcon + Name/Style
                    Row(
                      children: [
                        // Color indicator avatar
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: cardColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(55),
                          ),
                          child: Center(
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: cardColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        // Name and playing style column
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _opponent.name,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 18,
                                color: Color(0xFFFFFFFF).withOpacity(0.84),
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0,
                                height: 1.4,
                              ),
                            ),
                            Text(
                              _opponentStats?.playingStyle ?? 'No Data',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: Color(0xFFFFFFFF).withOpacity(0.84),
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Right: Hands count
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_statistics?['totalHands'] ?? 0}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0,
                            height: 1.4,
                          ),
                        ),
                        Text(
                          'Hands',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                SizedBox(height: 24),

                // Bottom section: Last seen
                Row(
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      size: 18,
                      color: Color(0xFFFFFFFF).withOpacity(0.84),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Last Seen: ${_opponent.lastSeenAt.toString().split(' ')[0]}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Color(0xFFFFFFFF).withOpacity(0.84),
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),

                // Additional info rows
                if (_opponent.notes != null && _opponent.notes!.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.notes,
                        size: 18,
                        color: Color(0xFFFFFFFF).withOpacity(0.84),
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _opponent.notes!,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Color(0xFFFFFFFF).withOpacity(0.84),
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildStatisticsCard() {
    if (_isLoadingStats) {
      return Center(
        child: CircularProgressIndicator(
          color: Color(0xFFA5EC44),
        ),
      );
    }

    if (_statistics == null) {
      return Container(
        padding: EdgeInsets.all(20),
        child: Text(
          'No statistics available',
          style: TextStyle(
            color: Color(0xFF9A9A9A),
            fontSize: 14,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          'STATISTICS',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            height: 1.4,
          ),
        ),
        SizedBox(height: 8),
        // Grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.2,
          children: [
            _buildStatCard('Hands Played', '${_statistics!['totalHands']}', 'icons/hands_played.png'),
            _buildStatCard('Sessions', '${_statistics!['totalSessions']}', 'icons/session.png'),
            _buildStatCard('VPIP', '${_formatStat(_statistics!['vpip'])}%', 'icons/vpip.png'),
            _buildStatCard('PFR', '${_formatStat(_statistics!['pfr'])}%', 'icons/bet.png'),
            _buildStatCard('Aggression', _formatAggression(_statistics!['aggression']), 'icons/aggression.png'),
            _buildStatCard('Fold %', '${_formatStat(_statistics!['foldPercentage'])}%', 'icons/fold.png'),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, String iconPath) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF1d2a27),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + Label section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                iconPath,
                width: 32,
                height: 32,
              ),
              SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: Color(0xFFFFFFFF).withOpacity(0.84),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                  height: 1.4,
                ),
              ),
            ],
          ),
          Spacer(),
          // Value section
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildActionDistributionCard() {
    if (_isLoadingStats) {
      return SizedBox.shrink();
    }

    if (_statistics == null) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          'ACTION DISTRIBUTION',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            height: 1.4,
          ),
        ),
        SizedBox(height: 8),
        // Grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.2,
          children: [
            _buildStatCard('Call', '${_formatStat(_statistics!['callPercentage'])}%', 'icons/play_style/calling_station.png'),
            _buildStatCard('Bet', '${_formatStat(_statistics!['betPercentage'])}%', 'icons/bet_with_chips.png'),
            _buildStatCard('Raise', '${_formatStat(_statistics!['raisePercentage'])}%', 'icons/bet.png'),
            _buildStatCard('Check', '${_formatStat(_statistics!['checkPercentage'])}%', 'icons/check.png'),
            _buildStatCard('Fold', '${_formatStat(_statistics!['foldPercentage'])}%', 'icons/fold.png'),
            _buildStatCard('Aggression', _formatAggression(_statistics!['aggression']), 'icons/aggression.png'),
          ],
        ),
      ],
    );
  }

  /// Helper function to safely format statistics with null safety
  String _formatStat(dynamic value, {int decimals = 1}) {
    if (value == null) return '-';
    if (value is num) {
      return value.toStringAsFixed(decimals);
    }
    return '-';
  }

  /// Helper function to format aggression factor with infinity handling
  String _formatAggression(dynamic value) {
    if (value == null) return '-';
    if (value is num) {
      if (value >= 999) return '∞';
      return value.toStringAsFixed(2);
    }
    return '-';
  }

  // REMOVED: _updateOpponentStoredStats() is no longer needed
  // Stats are stored in OpponentStats only, not in Opponent model

  Widget _buildHandsButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          'HAND HISTORY',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            height: 1.4,
          ),
        ),
        SizedBox(height: 7),
        // Description
        Text(
          'View all hands played with this opponent',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            color: Color(0xFFFFFFFF).withOpacity(0.8),
            fontWeight: FontWeight.w400,
            letterSpacing: -0.32,
            height: 1.0,
          ),
        ),
        SizedBox(height: 32),
        // Button
        SizedBox(
          width: double.infinity,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(100),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OpponentHandsScreen(
                        opponent: _opponent,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'View Hand History',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRowWithCustomIcon(String iconPath, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Image.asset(iconPath, width: 32, height: 32),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFF9A9A9A),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}