import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/opponent.dart';
import '../models/opponent_stats.dart';
import '../services/opponent_service.dart';
import '../services/local_storage_service.dart';
import '../services/firebase_service.dart';
import '../services/opponent_stats_service.dart';
import 'opponent_hands_screen.dart';
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
  OpponentStats? _opponentStats;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _opponent = widget.opponent;
    _loadStatistics();
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
          // Subtle teal gradient at top (same as home/opponents/session screens)
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
              children: [
                // Header Section with back button + opponent name
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
                      // Opponent name + playing style
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _opponent.name,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 24,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.5,
                                height: 1.2,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              _opponentStats?.playingStyle ?? 'Unknown Style',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 15,
                                color: _getStyleColor(_opponentStats?.playerType ?? PlayerType.unknown),
                                fontWeight: FontWeight.w400,
                                height: 1.2,
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBasicInfoCard(),
                        if (_opponent.notes != null && _opponent.notes!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildNotesSection(),
                        ],
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
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: GlobalBottomNavBar(currentScreen: 'opponent_detail'),
    );
  }

  Widget _buildBasicInfoCard() {
    final cardColor = _getColorForOpponent(_opponent.color);
    final dotsKey = GlobalKey();

    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF101115),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            // Top row: Profile circle + Name + dots menu
            Row(
              children: [
                // Profile circle (32px)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cardColor,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8),
                // Player name
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      _opponent.name,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 17,
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                        height: 1.44,
                      ),
                    ),
                  ),
                ),
                // Dots menu icon (24px container)
                GestureDetector(
                  key: dotsKey,
                  onTap: () => _showOpponentOptionsMenu(dotsKey),
                  child: _buildIcon(
                    'icons/figma_icons/dots.svg',
                    24,
                    Color(0xFF555555),
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // Separator line
            Container(
              height: 1,
              color: Color(0xFF1C1F21),
            ),

            SizedBox(height: 14),

            // Hands row: "Hands" label on left, count on right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Hands',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 17,
                      color: Color(0xFFB3B4B6),
                      fontWeight: FontWeight.w500,
                      height: 1.44,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${_statistics?['totalHands'] ?? 0}',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 17,
                      color: Color(0xFFD3FFFD),
                      fontWeight: FontWeight.w500,
                      height: 1.44,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 14),

            // Last seen row: eye icon + "Last Seen:" + date on right
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  _buildIcon(
                    'icons/figma_icons/eye.svg',
                    22,
                    Color(0xFF808285),
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Last Seen:',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 13,
                          color: Color(0xFF808285),
                          fontWeight: FontWeight.w500,
                          height: 1.44,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      DateFormat('MMM dd, h:mm a').format(_opponent.lastSeenAt),
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 13,
                        color: Color(0xFFE6E6E7),
                        fontWeight: FontWeight.w500,
                        height: 1.44,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Color(0xFF101115),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with icon and label
          Row(
            children: [
              _buildIcon(
                'icons/figma_icons/notes.svg',
                18,
                Color(0xFF808285),
              ),
              SizedBox(width: 8),
              Text(
                'Notes',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  color: Color(0xFF808285),
                  fontWeight: FontWeight.w500,
                  height: 1.44,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          // Notes content
          Text(
            _opponent.notes!,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              color: Colors.white,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showOpponentOptionsMenu(GlobalKey dotsKey) {
    // Get position of the dots icon
    final RenderBox renderBox = dotsKey.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          // Dismiss on tap outside
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.transparent),
            ),
          ),
          // Positioned popup menu
          Positioned(
            right: 16,
            top: offset.dy + size.height + 8,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 184,
                decoration: BoxDecoration(
                  color: Color(0xFF02050B),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.45),
                      blurRadius: 34,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Edit Opponent row
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _showEditOpponentDialog();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          _buildIcon(
                            'icons/figma_icons/edit.svg',
                            16,
                            Colors.white,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Edit Opponent',
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                  height: 1.44,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Separator
                    Container(
                      height: 1,
                      color: Color(0xFF1C1F21),
                    ),
                    // Delete Opponent row
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _showDeleteConfirmation();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          _buildIcon(
                            'icons/figma_icons/delete.svg',
                            16,
                            Color(0xFFD55A41),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Delete Opponent',
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                  height: 1.44,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection() {
    if (_isLoadingStats) {
      return Center(
        child: CircularProgressIndicator(
          color: Color(0xFF89F1EC),
        ),
      );
    }

    if (_statistics == null) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Color(0xFF131616),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'No statistics available',
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white.withOpacity(0.6),
            fontSize: 14,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF131616),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Text(
            'Statistics',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          SizedBox(height: 16),
          // List items with dividers
          _buildStatListItem('VPIP', '${_formatStat(_statistics!['vpip'])}%'),
          _buildDivider(),
          _buildStatListItem('PFR', '${_formatStat(_statistics!['pfr'])}%'),
          _buildDivider(),
          _buildStatListItem('Aggression', _formatAggression(_statistics!['aggression'])),
          _buildDivider(),
          _buildStatListItem('Fold %', '${_formatStat(_statistics!['foldPercentage'])}%'),
        ],
      ),
    );
  }

  Widget _buildActionDistributionSection() {
    if (_isLoadingStats || _statistics == null) {
      return SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF131616),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Text(
            'Action Distribution',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          SizedBox(height: 16),
          // List items with dividers
          _buildStatListItem('Call', '${_formatStat(_statistics!['callPercentage'])}%'),
          _buildDivider(),
          _buildStatListItem('Bet', '${_formatStat(_statistics!['betPercentage'])}%'),
          _buildDivider(),
          _buildStatListItem('Raise', '${_formatStat(_statistics!['raisePercentage'])}%'),
          _buildDivider(),
          _buildStatListItem('Check', '${_formatStat(_statistics!['checkPercentage'])}%'),
        ],
      ),
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
              color: Color(0xFF89F1EC),
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
        // Header section (matches CardHeader from Figma)
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'Hand History',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8C8C8C),
                  height: 1.44,
                ),
              ),
              // Subtitle
              Text(
                'View all hands played with this opponent',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8C8C8C),
                  height: 1.44,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 14),
        // Button (mint background per Figma)
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
              backgroundColor: Color(0xFF89F1EC),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(110),
              ),
              elevation: 0,
            ),
            child: Text(
              'View Hand History',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black,
                letterSpacing: -0.5,
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
          color: Color(0xFF131616),
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
                  child: _buildIcon(
                    'icons/figma_icons/close.svg',
                    24,
                    Colors.white,
                  ),
                ),
              ),
              SizedBox(height: 8),
              // Info icon
              _buildIcon(
                'icons/figma_icons/info.svg',
                44,
                Colors.white,
              ),
              SizedBox(height: 20),
              // Title
              Text(
                'No Hands Found',
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 12),
              // Description
              Text(
                'You haven\'t played any hands with "${_opponent.name}" yet',
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF89F1EC),
                  height: 1.5,
                ),
              ),
              SizedBox(height: 32),
              // Close button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(110),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Close',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
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
    final colorPickerKey = GlobalKey();

    // Color name mapping
    String getColorName(OpponentColor color) {
      switch (color) {
        case OpponentColor.red: return 'Red';
        case OpponentColor.blue: return 'Light Blue';
        case OpponentColor.green: return 'Green';
        case OpponentColor.orange: return 'Orange';
        case OpponentColor.purple: return 'Purple';
        case OpponentColor.teal: return 'Teal';
        case OpponentColor.pink: return 'Pink';
        case OpponentColor.indigo: return 'Indigo';
      }
    }

    void showColorPicker(StateSetter setSheetState) {
      final colors = OpponentColor.values;

      // Get the position of the color picker row
      final RenderBox renderBox = colorPickerKey.currentContext!.findRenderObject() as RenderBox;
      final Offset offset = renderBox.localToGlobal(Offset.zero);

      showDialog(
        context: context,
        barrierColor: Colors.transparent,
        builder: (context) {
          return Stack(
            children: [
              // Dismiss on tap outside
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(color: Colors.transparent),
                ),
              ),
              // Positioned dropdown
              Positioned(
                right: 32,
                top: offset.dy,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 184,
                    decoration: BoxDecoration(
                      color: Color(0xFF161619),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.45),
                          blurRadius: 34,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...colors.asMap().entries.map((entry) {
                          final index = entry.key;
                          final color = entry.value;
                          final isSelected = color == selectedColor;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                  setSheetState(() {
                                    selectedColor = color;
                                  });
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      if (isSelected) ...[
                                        Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                      ],
                                      Container(
                                        width: 16,
                                        height: 16,
                                        margin: EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: _getColorForOpponent(color),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Text(
                                        getColorName(color),
                                        style: GoogleFonts.ibmPlexSans(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (index < colors.length - 1)
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Container(
                                    height: 1,
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    Future<void> saveOpponent() async {
      final name = nameController.text.trim();
      if (name.isEmpty) return;

      try {
        final updatedOpponent = _opponent.copyWith(
          name: name,
          notes: notesController.text.trim().isEmpty
              ? null
              : notesController.text.trim(),
          clearNotes: notesController.text.trim().isEmpty,
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
            backgroundColor: Color(0xFF44D69B),
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
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
              border: Border.all(color: Color(0xFF262626)),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF2E5A59),
                  blurRadius: 64,
                  offset: Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header with X, title, checkmark
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: 68,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Close button
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Color(0xFF2C2C2E),
                              borderRadius: BorderRadius.circular(58),
                            ),
                            child: Center(
                              child: _buildIcon(
                                'icons/figma_icons/close.svg',
                                15,
                                Colors.white,
                              ),
                            ),
                          ),
                        ),
                        // Title
                        Text(
                          'Edit Opponent',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: -0.43,
                            height: 22 / 17,
                          ),
                        ),
                        // Save/Check button - green background
                        GestureDetector(
                          onTap: saveOpponent,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Color(0xFF54E98A),
                              borderRadius: BorderRadius.circular(58),
                            ),
                            child: Center(
                              child: _buildIcon(
                                'icons/figma_icons/check.svg',
                                18,
                                Color(0xFF1A4A4A),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 22),

                // Form card
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(0xFF131616),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Column(
                      children: [
                        // Opponent Name field
                        Padding(
                          padding: EdgeInsets.fromLTRB(10, 10, 8, 10),
                          child: TextField(
                            controller: nameController,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 17,
                              color: Colors.white,
                              fontWeight: FontWeight.w400,
                              height: 1.44,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Opponent Name',
                              hintStyle: GoogleFonts.ibmPlexSans(
                                fontSize: 17,
                                color: Colors.white,
                                fontWeight: FontWeight.w400,
                                height: 1.44,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                          ),
                        ),

                        // Separator
                        Container(
                          height: 21,
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          alignment: Alignment.center,
                          child: Container(
                            height: 1,
                            color: Color(0xFF3A3A3C),
                          ),
                        ),

                        // Notes field - text area for more visibility
                        Padding(
                          padding: EdgeInsets.all(10),
                          child: TextField(
                            controller: notesController,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 17,
                              color: Colors.white,
                              fontWeight: FontWeight.w400,
                              height: 1.44,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Notes (Optional)',
                              hintStyle: GoogleFonts.ibmPlexSans(
                                fontSize: 17,
                                color: Colors.white.withOpacity(0.5),
                                fontWeight: FontWeight.w400,
                                height: 1.44,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                            maxLines: 4,
                            minLines: 4,
                          ),
                        ),

                        // Separator
                        Container(
                          height: 21,
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          alignment: Alignment.center,
                          child: Container(
                            height: 1,
                            color: Color(0xFF3A3A3C),
                          ),
                        ),

                        // Pick a color row
                        GestureDetector(
                          key: colorPickerKey,
                          onTap: () => showColorPicker(setSheetState),
                          child: Padding(
                            padding: EdgeInsets.all(10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Pick a color',
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 17,
                                    color: Color(0xFFB9B9B9),
                                    fontWeight: FontWeight.w400,
                                    height: 1.44,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      getColorName(selectedColor),
                                      style: GoogleFonts.ibmPlexSans(
                                        fontSize: 17,
                                        color: Color(0xFFB9B9B9),
                                        fontWeight: FontWeight.w400,
                                        height: 1.44,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    _buildIcon(
                                      'icons/figma_icons/up_and_down.svg',
                                      20,
                                      Color(0xFFB9B9B9),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
                      style: GoogleFonts.ibmPlexSans(
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
                        style: GoogleFonts.ibmPlexSans(
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
                          style: GoogleFonts.ibmPlexSans(
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
                    style: GoogleFonts.ibmPlexSans(
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
