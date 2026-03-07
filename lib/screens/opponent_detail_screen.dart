import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/opponent.dart';
import '../models/opponent_stats.dart';
import '../services/opponent_service.dart';
import '../services/local_storage_service.dart';
import '../services/firebase_service.dart';
import '../services/opponent_stats_service.dart';
import 'opponent_hands_screen.dart';
import '../widgets/global_bottom_nav_bar.dart';
import '../design_system/design_system.dart';

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
  OpponentStats? _opponentStats;
  bool _isLoadingStats = true;
  int _totalOpponents = 0;

  @override
  void initState() {
    super.initState();
    _opponent = widget.opponent;
    _loadStatistics();
    _loadTotalOpponents();
  }

  Future<void> _loadTotalOpponents() async {
    try {
      final opponents = await OpponentService.getAllOpponents();
      setState(() {
        _totalOpponents = opponents.length;
      });
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final stats = await _calculateOpponentStatistics(_opponent.name);
      final opponentStats = await OpponentStatsService.getOpponentStats(_opponent.id);
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
      final optimizedStats = await OpponentStatsService.getOpponentStats(_opponent.id);

      if (optimizedStats != null) {
        print('✅ Using optimized stats for $opponentName (${optimizedStats.handsPlayed} hands)');
        final legacyMap = optimizedStats.toLegacyStatsMap();
        return legacyMap;
      } else {
        print('⚠️ No optimized stats found for $opponentName - calculating from hand data');
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

  Future<Map<String, dynamic>> _calculateLegacyOpponentStatistics(String opponentName) async {
    try {
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

      List<Map<String, dynamic>> sessions;
      try {
        sessions = await FirebaseService.getAllSessions();
      } catch (e) {
        sessions = await LocalStorageService.getUserSessions();
      }

      for (final session in sessions) {
        final sessionId = session['id'] as String;
        final playerNames = session['playerNames'] as Map<String, dynamic>?;

        if (playerNames != null) {
          bool opponentInSession = false;
          for (final playerName in playerNames.values) {
            if (playerName.toString().toLowerCase() == opponentName.toLowerCase()) {
              opponentInSession = true;
              break;
            }
          }

          if (opponentInSession) {
            sessionsPlayed.add(sessionId);

            List<Map<String, dynamic>> hands;
            try {
              hands = await FirebaseService.getSessionHands(sessionId);
            } catch (e) {
              hands = await LocalStorageService.getSessionHands(sessionId);
            }

            for (final hand in hands) {
              bool opponentInThisHand = false;
              bool vpipThisHand = false;
              bool pfrThisHand = false;

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

      final vpip = totalHands > 0 ? (vpipHands / totalHands * 100) : 0.0;
      final pfr = totalHands > 0 ? (pfrHands / totalHands * 100) : 0.0;
      final foldPercentage = totalHands > 0 ? (foldCount / totalHands * 100) : 0.0;
      final callPercentage = totalHands > 0 ? (callCount / totalHands * 100) : 0.0;
      final betPercentage = totalHands > 0 ? (betCount / totalHands * 100) : 0.0;
      final raisePercentage = totalHands > 0 ? (raiseCount / totalHands * 100) : 0.0;
      final checkPercentage = totalHands > 0 ? (checkCount / totalHands * 100) : 0.0;

      final totalActions = aggressiveActions + passiveActions;
      final aggression = totalActions > 0 ? (aggressiveActions / totalActions) : 0.0;

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

  Color _getStyleColor(PlayerType playerType) {
    switch (playerType) {
      case PlayerType.tightAggressive:
      case PlayerType.tagRegular:
        return Colors.green;
      case PlayerType.looseAggressive:
        return Colors.orange;
      case PlayerType.tightPassive:
        return Colors.blue;
      case PlayerType.loosePassive:
      case PlayerType.calling_station:
        return Colors.red;
      case PlayerType.maniac:
        return Colors.purple;
      case PlayerType.unknown:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GradientBackground(),
          SafeArea(
            child: Column(
              children: [
                // Header Section (same as Opponents screen)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left: Title + subtitle
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Opponents',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 24,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.48,
                              height: 1.0,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '$_totalOpponents tracked players',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Color(0xFFFFFFFF).withOpacity(0.8),
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.24,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                      // Right: Back button only
                      GlassyIconButton(
                        imagePath: 'icons/flat_icons/back.png',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBasicInfoCard(),
                        const SizedBox(height: 32),
                        _buildStatisticsSection(),
                        const SizedBox(height: 32),
                        _buildActionDistributionSection(),
                        const SizedBox(height: 32),
                        _buildHandHistorySection(),
                        const SizedBox(height: 100), // Bottom padding for nav bar
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

    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF1A2925),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        child: Column(
          children: [
            // Top section: User info + hands count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left: CardIcon + Name/Style
                Row(
                  children: [
                    // Color indicator avatar (28px solid circle)
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: cardColor,
                        shape: BoxShape.circle,
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
                            color: Color(0xFFFFFFFF),
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
                            color: _getStyleColor(_opponentStats?.playerType ?? PlayerType.unknown),
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
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            SizedBox(height: 24),

            // Bottom section: Last seen + action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left: Last seen
                Row(
                  children: [
                    Image.asset(
                      'icons/flat_icons/eye.png',
                      width: 18,
                      height: 18,
                      color: Color(0xFFFFFFFF).withOpacity(0.8),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Last Seen: ${DateFormat('MMM dd').format(_opponent.lastSeenAt)}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        color: Color(0xFFFFFFFF).withOpacity(0.8),
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
                // Right: Action buttons
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showEditOpponentDialog(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(0xFF1A291A), // --primary-90
                          borderRadius: BorderRadius.circular(70),
                        ),
                        child: Center(
                          child: Image.asset(
                            'icons/flat_icons/edit.png',
                            width: 20,
                            height: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showDeleteConfirmation(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(0xFFB63131),
                          borderRadius: BorderRadius.circular(70),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Image.asset(
                            'icons/flat_icons/bin.png',
                            width: 20,
                            height: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Notes section (if available)
            if (_opponent.notes != null && _opponent.notes!.isNotEmpty) ...[
              SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.notes_outlined,
                      size: 16,
                      color: Color(0xFFFFFFFF).withOpacity(0.6),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _opponent.notes!,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFFFFFFFF).withOpacity(0.8),
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    if (_isLoadingStats) {
      return Center(
        child: CircularProgressIndicator(
          color: Color(0xFFBAFF9A),
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
        // Section header
        Text(
          'Statistics',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Color(0xFFBAFF9A), // --secondary-100
            letterSpacing: 1.0,
            height: 1.0,
          ),
        ),
        SizedBox(height: 12),
        // List items with dividers
        _buildStatListItem('Hands Played', '${_statistics!['totalHands']}'),
        _buildDivider(),
        _buildStatListItem('Sessions', '${_statistics!['totalSessions']}'),
        _buildDivider(),
        _buildStatListItem('VPIP', '${_formatStat(_statistics!['vpip'])}%'),
        _buildDivider(),
        _buildStatListItem('PFR', '${_formatStat(_statistics!['pfr'])}%'),
        _buildDivider(),
        _buildStatListItem('Aggression', _formatAggression(_statistics!['aggression'])),
        _buildDivider(),
        _buildStatListItem('Fold', '${_formatStat(_statistics!['foldPercentage'])}%'),
      ],
    );
  }

  Widget _buildActionDistributionSection() {
    if (_isLoadingStats || _statistics == null) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Text(
          'Action Distribution',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Color(0xFFBAFF9A), // --secondary-100
            letterSpacing: 1.0,
            height: 1.0,
          ),
        ),
        SizedBox(height: 12),
        // List items with dividers
        _buildStatListItem('Call', '${_formatStat(_statistics!['callPercentage'])}%'),
        _buildDivider(),
        _buildStatListItem('Bet', '${_formatStat(_statistics!['betPercentage'])}%'),
        _buildDivider(),
        _buildStatListItem('Raise', '${_formatStat(_statistics!['raisePercentage'])}%'),
        _buildDivider(),
        _buildStatListItem('Check', '${_formatStat(_statistics!['checkPercentage'])}%'),
        _buildDivider(),
        _buildStatListItem('Fold', '${_formatStat(_statistics!['foldPercentage'])}%'),
        _buildDivider(),
        _buildStatListItem('Aggression', _formatAggression(_statistics!['aggression'])),
      ],
    );
  }

  Widget _buildStatListItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.white,
              height: 1.0,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFFBAFF9A), // --secondary-100
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

  Widget _buildHandHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          'Hand History',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.5,
          ),
        ),
        SizedBox(height: 4),
        // Description
        Text(
          'View all hands played with this opponent',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Color(0xFFF8FFF7),
          ),
        ),
        SizedBox(height: 24),
        // Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              // Check if there are hands before navigating
              final totalHands = _statistics?['totalHands'] ?? 0;
              if (totalHands == 0) {
                _showNoHandsFoundDialog();
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OpponentHandsScreen(
                      opponent: _opponent,
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFBAFF9A), // --secondary-100
              foregroundColor: Color(0xFF011100), // --primary-100
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text(
              'View Hand History',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF011100), // --primary-100
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showNoHandsFoundDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Color(0xFF131613), // --background
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Close button at top right
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Image.asset(
                    'icons/flat_icons/close.png',
                    width: 24,
                    height: 24,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: 8),
              // Sad face icon
              Image.asset(
                'icons/flat_icons/sad_face.png',
                width: 44,
                height: 44,
                color: Colors.white,
              ),
              SizedBox(height: 20),
              // Title
              Text(
                'No Hands Found',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 12),
              // Description
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 62),
                child: Text(
                  'You haven\'t played any hands with "${_opponent.name}" yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFFF8FFF7),
                    height: 1.5,
                  ),
                ),
              ),
              SizedBox(height: 50),
              // Close button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFBAFF9A), // --secondary-100
                    foregroundColor: Color(0xFF011100), // --primary-100
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF011100), // --primary-100
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

  void _showEditOpponentDialog() {
    final nameController = TextEditingController(text: _opponent.name);
    final notesController = TextEditingController(text: _opponent.notes ?? '');
    OpponentColor selectedColor = _opponent.color;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            decoration: BoxDecoration(
              color: Color(0xFF1a2925),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle line
                    Container(
                      width: 80,
                      height: 2,
                      margin: EdgeInsets.only(top: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),

                    SizedBox(height: 38),

                    // Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Edit Opponent',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    // Input fields
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          // Opponent Name field
                          Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: TextField(
                              controller: nameController,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Opponent Name',
                                hintStyle: TextStyle(
                                  fontFamily: 'Inter',
                                  color: Colors.white.withOpacity(0.5),
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: 18),

                          // Notes field
                          Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: TextField(
                              controller: notesController,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Notes (Optional)',
                                hintStyle: TextStyle(
                                  fontFamily: 'Inter',
                                  color: Colors.white.withOpacity(0.5),
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.all(16),
                              ),
                              maxLines: 6,
                              maxLength: null,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // Color picker section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pick a color:',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.28,
                            ),
                          ),
                          SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: OpponentColor.values.map((color) {
                              final isSelected = selectedColor == color;
                              return GestureDetector(
                                onTap: () {
                                  setSheetState(() {
                                    selectedColor = color;
                                  });
                                },
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: _getColorForOpponent(color),
                                    shape: BoxShape.circle,
                                    border: isSelected
                                        ? Border.all(
                                            color: Colors.white,
                                            width: 3,
                                          )
                                        : null,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 56),

                    // Update button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () async {
                            final name = nameController.text.trim();
                            if (name.isEmpty) return;

                            try {
                              final updatedOpponent = _opponent.copyWith(
                                name: name,
                                notes: notesController.text.trim().isEmpty
                                    ? null
                                    : notesController.text.trim(),
                                color: selectedColor,
                              );

                              await OpponentService.saveOpponent(updatedOpponent);
                              Navigator.pop(context);

                              setState(() {
                                _opponent = updatedOpponent;
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Opponent updated successfully'),
                                  backgroundColor: Color(0xFFA5EC44),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFA5EC44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Update',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Cancel button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main card with title, description, and delete button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Color(0xFF131613), // --background
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    SizedBox(height: 24),
                    // Title
                    Text(
                      'Delete opponent?',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 24),
                    // Description
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Are you sure you want to delete "${_opponent.name}"?\nThis action can not be undone',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          letterSpacing: 0.24,
                          height: 1.7,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    // Divider line
                    Container(
                      height: 1,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    // Delete button
                    GestureDetector(
                      onTap: () async {
                        try {
                          await OpponentService.deleteOpponent(_opponent.id);
                          Navigator.pop(context); // Close dialog
                          Navigator.pop(context, true); // Go back with result
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Opponent deleted successfully'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error deleting opponent: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                        child: Text(
                          'Delete',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD55A41), // --error
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              // Cancel button (separate card)
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  decoration: BoxDecoration(
                    color: Color(0xFF131613), // --background
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    'Cancel',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
