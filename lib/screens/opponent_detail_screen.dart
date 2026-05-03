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
import '../design_system/components/drawer_dots.dart';
import '../design_system/components/form_drawer.dart';
import '../l10n/app_localizations.dart';

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
      return _getEmptyStatsMap();
    }
  }

  Future<Map<String, dynamic>> _calculateLegacyOpponentStatistics(String opponentName) async {
    try {
      int totalHands = 0;
      int totalSessions = 0;
      int vpipHands = 0;
      int pfrHands = 0;
      // New stat counters
      int threeBetCount = 0;
      int threeBetOpportunity = 0;
      int fold3BetCount = 0;
      int facing3BetCount = 0;
      int cbetCount = 0;
      int cbetOpportunity = 0;
      int stealCount = 0;
      int stealOpportunity = 0;
      int checkRaiseFlopCount = 0;
      int checkRaiseFlopOpportunity = 0;
      int walksCount = 0;

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
          int? opponentSeat;
          for (final entry in playerNames.entries) {
            if (entry.value.toString().toLowerCase() == opponentName.toLowerCase()) {
              opponentInSession = true;
              opponentSeat = int.tryParse(entry.key);
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
                final actions = (hand['actions'] as List<dynamic>).cast<Map<String, dynamic>>();

                // Check each action for opponent participation
                for (final action in actions) {
                  final actionPlayerName = action['playerName'] as String?;
                  if (actionPlayerName != null &&
                      actionPlayerName.toLowerCase().contains(opponentName.toLowerCase())) {
                    opponentInThisHand = true;

                    final actionType = (action['action'] as String?)?.toLowerCase() ?? '';
                    final street = (action['street'] as String?)?.toLowerCase() ?? '';

                    // VPIP: voluntary money in preflop
                    if (street == 'preflop' && !vpipThisHand) {
                      if (actionType == 'call' || actionType == 'bet' || actionType == 'raise') {
                        vpipThisHand = true;
                      }
                    }

                    // PFR: preflop raise
                    if (street == 'preflop' && !pfrThisHand) {
                      if (actionType == 'bet' || actionType == 'raise') {
                        pfrThisHand = true;
                      }
                    }
                  }
                }

                if (opponentInThisHand && opponentSeat != null) {
                  // Advanced stat detection using helper methods similar to firebase_service
                  final result = _detectAdvancedStats(actions, opponentSeat, opponentName);
                  threeBetCount += result['threeBetCount'] as int;
                  threeBetOpportunity += result['threeBetOpportunity'] as int;
                  fold3BetCount += result['fold3BetCount'] as int;
                  facing3BetCount += result['facing3BetCount'] as int;
                  cbetCount += result['cbetCount'] as int;
                  cbetOpportunity += result['cbetOpportunity'] as int;
                  stealCount += result['stealCount'] as int;
                  stealOpportunity += result['stealOpportunity'] as int;
                  checkRaiseFlopCount += result['checkRaiseFlopCount'] as int;
                  checkRaiseFlopOpportunity += result['checkRaiseFlopOpportunity'] as int;
                  walksCount += result['walksCount'] as int;
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

      // Calculate percentages with proper denominators
      final eligibleHands = totalHands - walksCount;
      final vpip = eligibleHands > 0 ? (vpipHands / eligibleHands * 100).clamp(0.0, 100.0) : 0.0;
      final pfr = eligibleHands > 0 ? (pfrHands / eligibleHands * 100).clamp(0.0, 100.0) : 0.0;
      final threeBet = threeBetOpportunity > 0 ? (threeBetCount / threeBetOpportunity * 100).clamp(0.0, 100.0) : 0.0;
      final fold3Bet = facing3BetCount > 0 ? (fold3BetCount / facing3BetCount * 100).clamp(0.0, 100.0) : 0.0;
      final cbet = cbetOpportunity > 0 ? (cbetCount / cbetOpportunity * 100).clamp(0.0, 100.0) : 0.0;
      final steal = stealOpportunity > 0 ? (stealCount / stealOpportunity * 100).clamp(0.0, 100.0) : 0.0;
      final checkRaise = checkRaiseFlopOpportunity > 0 ? (checkRaiseFlopCount / checkRaiseFlopOpportunity * 100).clamp(0.0, 100.0) : 0.0;

      return {
        'totalHands': totalHands,
        'totalSessions': totalSessions,
        'aggressionFreq': 0.0, // Legacy path can't compute this accurately
        'showdown': 0.0, // Legacy path can't compute this
        'threeBet': threeBet,
        'fold3Bet': fold3Bet,
        'cbet': cbet,
        'steal': steal,
        'checkRaise': checkRaise,
        // Opportunity counts for N/A detection
        'aggressionTotal': 0,
        'showdownHands': totalHands,
        'threeBetOpportunity': threeBetOpportunity,
        'facing3BetCount': facing3BetCount,
        'cbetOpportunity': cbetOpportunity,
        'stealOpportunity': stealOpportunity,
        'checkRaiseFlopOpportunity': checkRaiseFlopOpportunity,
      };
    } catch (e) {
      print('❌ Error calculating legacy stats: $e');
      return _getEmptyStatsMap();
    }
  }

  /// Get empty stats map with all required fields
  Map<String, dynamic> _getEmptyStatsMap() {
    return {
      'totalHands': 0,
      'totalSessions': 0,
      'aggressionFreq': 0.0,
      'showdown': 0.0,
      'threeBet': 0.0,
      'fold3Bet': 0.0,
      'cbet': 0.0,
      'steal': 0.0,
      'checkRaise': 0.0,
      'aggressionTotal': 0,
      'showdownHands': 0,
      'threeBetOpportunity': 0,
      'facing3BetCount': 0,
      'cbetOpportunity': 0,
      'stealOpportunity': 0,
      'checkRaiseFlopOpportunity': 0,
    };
  }

  /// Detect advanced stats from hand actions
  Map<String, int> _detectAdvancedStats(List<Map<String, dynamic>> actions, int playerSeat, String opponentName) {
    int threeBetCount = 0;
    int threeBetOpportunity = 0;
    int fold3BetCount = 0;
    int facing3BetCount = 0;
    int cbetCount = 0;
    int cbetOpportunity = 0;
    int stealCount = 0;
    int stealOpportunity = 0;
    int checkRaiseFlopCount = 0;
    int checkRaiseFlopOpportunity = 0;
    int walksCount = 0;

    // 3-Bet detection
    bool sawOpponentRaise = false;
    bool playerRaised = false;
    bool facedReRaise = false;
    int? lastPreflopAggressor;
    String? playerPosition;
    bool potUnopenedWhenPlayerActs = true;
    bool playerCheckedFlop = false;
    bool facedBetAfterCheck = false;
    bool isWalk = true;

    for (int i = 0; i < actions.length; i++) {
      final action = actions[i];
      final street = (action['street'] as String?)?.toLowerCase() ?? '';
      final playerId = action['player'] as int?;
      final actionType = (action['action'] as String?)?.toLowerCase() ?? '';
      final position = (action['playerPosition'] as String?)?.toUpperCase() ?? '';

      // Track player position
      if (playerId == playerSeat && playerPosition == null) {
        playerPosition = position;
      }

      if (street == 'preflop') {
        // Skip blind actions for walk detection
        if (actionType != 'small blind' && actionType != 'big blind' && actionType != 'ante') {
          if (actionType != 'fold') {
            isWalk = false;
          }

          // 3-bet opportunity detection
          if (actionType == 'raise') {
            if (playerId != playerSeat) {
              sawOpponentRaise = true;
            } else if (sawOpponentRaise) {
              threeBetCount = 1;
            }

            // Track for fold to 3-bet
            if (playerId == playerSeat) {
              playerRaised = true;
            } else if (playerRaised) {
              facedReRaise = true;
            }
          }

          // Check if player acted after seeing a raise (3-bet opportunity)
          if (playerId == playerSeat && sawOpponentRaise) {
            threeBetOpportunity = 1;
          }

          // Fold to 3-bet
          if (actionType == 'fold' && playerId == playerSeat && facedReRaise) {
            fold3BetCount = 1;
          }

          // Facing 3-bet
          if (facedReRaise && facing3BetCount == 0) {
            facing3BetCount = 1;
          }

          // Steal opportunity check
          if (playerId == playerSeat && potUnopenedWhenPlayerActs) {
            if (position == 'CO' || position == 'BTN' || position == 'BU' || position == 'SB') {
              stealOpportunity = 1;
              if (actionType == 'raise') {
                stealCount = 1;
              }
            }
          }

          // Track if pot opened before player acts
          if (playerId != playerSeat) {
            if (actionType == 'raise' || actionType == 'bet' || actionType == 'call') {
              potUnopenedWhenPlayerActs = false;
            }
          }

          // Track last preflop aggressor
          if (actionType == 'bet' || actionType == 'raise') {
            lastPreflopAggressor = playerId;
          }
        }
      } else if (street == 'flop') {
        // C-bet opportunity (was last aggressor pre and saw flop)
        if (lastPreflopAggressor == playerSeat && cbetOpportunity == 0) {
          cbetOpportunity = 1;
        }

        // C-bet detection
        if (playerId == playerSeat && actionType == 'bet' && lastPreflopAggressor == playerSeat) {
          cbetCount = 1;
        }

        // Check/raise detection
        if (playerId == playerSeat && actionType == 'check') {
          playerCheckedFlop = true;
        }

        if (playerCheckedFlop && playerId != playerSeat && (actionType == 'bet' || actionType == 'raise')) {
          facedBetAfterCheck = true;
          checkRaiseFlopOpportunity = 1;
        }

        if (playerCheckedFlop && facedBetAfterCheck && playerId == playerSeat && actionType == 'raise') {
          checkRaiseFlopCount = 1;
        }
      }
    }

    // Walk detection (BB wins by default)
    if (isWalk && playerPosition == 'BB') {
      walksCount = 1;
    }

    return {
      'threeBetCount': threeBetCount,
      'threeBetOpportunity': threeBetOpportunity,
      'fold3BetCount': fold3BetCount,
      'facing3BetCount': facing3BetCount,
      'cbetCount': cbetCount,
      'cbetOpportunity': cbetOpportunity,
      'stealCount': stealCount,
      'stealOpportunity': stealOpportunity,
      'checkRaiseFlopCount': checkRaiseFlopCount,
      'checkRaiseFlopOpportunity': checkRaiseFlopOpportunity,
      'walksCount': walksCount,
    };
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
    final l10n = AppLocalizations.of(context);
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
                          decoration: const BoxDecoration(
                            color: Color(0xFF101115),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 22,
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
                              _opponentStats != null && _opponentStats!.handsPlayed > 0
                                  ? l10n.opponentDetailHandsTracked(_opponentStats!.handsPlayed)
                                  : l10n.opponentDetailNoDataYet,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 15,
                                color: Colors.grey,
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
    final l10n = AppLocalizations.of(context);
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
                // Dots menu icon
                SizedBox(
                  key: dotsKey,
                  child: DrawerDots(
                    onTap: () => _showOpponentOptionsMenu(dotsKey),
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
                    l10n.opponentDetailHands,
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
                    '${OpponentHandsScreen.filteredHandCounts[_opponent.id] ?? _statistics?['totalHands'] ?? 0}',
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
                        l10n.opponentDetailLastSeen,
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
    final l10n = AppLocalizations.of(context);
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
                l10n.opponentDetailNotes,
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
    final l10n = AppLocalizations.of(context);
    // Get position of the dots icon
    final RenderBox renderBox = dotsKey.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    final screenWidth = MediaQuery.of(context).size.width;
    final dotsRight = screenWidth - (offset.dx + size.width);
    final menuTop = offset.dy + size.height + 4;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      useSafeArea: false,
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
            right: dotsRight,
            top: menuTop,
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
                                l10n.opponentDetailEditOpponent,
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
                                l10n.opponentDetailDeleteOpponent,
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
    final l10n = AppLocalizations.of(context);
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
          l10n.opponentDetailNoStatisticsAvailable,
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
            l10n.opponentDetailStatistics,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          SizedBox(height: 16),
          // List items with dividers - 7 poker stats
          _buildStatListItem(l10n.opponentDetailAggressionFreq, _formatStatWithOpportunity(_statistics!['aggressionFreq'], _statistics!['aggressionTotal'])),
          _buildDivider(),
          _buildStatListItem(l10n.opponentDetailShowdownPercent, _formatStatWithOpportunity(_statistics!['showdown'], _statistics!['showdownHands'])),
          _buildDivider(),
          _buildStatListItem('3-Bet', _formatStatWithOpportunity(_statistics!['threeBet'], _statistics!['threeBetOpportunity'])),
          _buildDivider(),
          _buildStatListItem('Fold to 3-Bet', _formatStatWithOpportunity(_statistics!['fold3Bet'], _statistics!['facing3BetCount'])),
          _buildDivider(),
          _buildStatListItem('C-Bet', _formatStatWithOpportunity(_statistics!['cbet'], _statistics!['cbetOpportunity'])),
          _buildDivider(),
          _buildStatListItem('Steal', _formatStatWithOpportunity(_statistics!['steal'], _statistics!['stealOpportunity'])),
          _buildDivider(),
          _buildStatListItem('Check/Raise', _formatStatWithOpportunity(_statistics!['checkRaise'], _statistics!['checkRaiseFlopOpportunity'])),
        ],
      ),
    );
  }

  /// Format stat as percentage or 'N/A' if no opportunity data
  String _formatStatWithOpportunity(dynamic value, dynamic opportunity) {
    // Check if there's any opportunity data
    final opp = opportunity is num ? opportunity.toInt() : 0;
    if (opp <= 0) return 'N/A';

    if (value == null) return 'N/A';
    if (value is num && value.isNaN) return 'N/A';
    return '${_formatStat(value)}%';
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
    final l10n = AppLocalizations.of(context);
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
                l10n.opponentDetailHandHistory,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8C8C8C),
                  height: 1.44,
                ),
              ),
              // Subtitle
              Text(
                l10n.opponentDetailViewAllHands,
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
          child: ElevatedButton(
            onPressed: () {
              // Check if there are hands before navigating
              final totalHands = OpponentHandsScreen.filteredHandCounts[_opponent.id]
                  ?? _statistics?['totalHands'] ?? 0;
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
              backgroundColor: const Color(0xFF89F1EC),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(110),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 32),
              elevation: 0,
            ),
            child: Text(
              l10n.opponentDetailViewHandHistory,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black,
                letterSpacing: -0.5,
                height: 24 / 17,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showNoHandsFoundDialog() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF101115),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Close button at top right
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Center(
                      child: _buildIcon(
                        'icons/figma_icons/close.svg',
                        15,
                        Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 34),
              // Ghost icon
              _buildIcon(
                'icons/figma_icons/ghost.svg',
                24,
                const Color(0xFFB3B4B6),
              ),
              const SizedBox(height: 18),
              // Title
              Text(
                l10n.opponentDetailNoHandsFound,
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  height: 1.44,
                ),
              ),
              const SizedBox(height: 7),
              // Description
              Text(
                l10n.opponentDetailNoHandsMessage(_opponent.name),
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFCCCDCE),
                  height: 1.44,
                ),
              ),
              const SizedBox(height: 34),
              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4B9A96),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(110),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                    elevation: 0,
                  ),
                  child: Text(
                    l10n.commonClose,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      letterSpacing: -0.5,
                      height: 24 / 17,
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
  void _showEditOpponentDialog() {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(text: _opponent.name);
    final notesController = TextEditingController(text: _opponent.notes ?? '');
    OpponentColor selectedColor = _opponent.color;
    final colorPickerKey = GlobalKey();
    String? nameError;
    StateSetter? _setSheetState;

    // Color name mapping
    String getColorName(OpponentColor color) {
      switch (color) {
        case OpponentColor.red: return l10n.opponentDetailColorRed;
        case OpponentColor.blue: return l10n.opponentDetailColorLightBlue;
        case OpponentColor.green: return l10n.opponentDetailColorGreen;
        case OpponentColor.orange: return l10n.opponentDetailColorOrange;
        case OpponentColor.purple: return l10n.opponentDetailColorPurple;
        case OpponentColor.teal: return l10n.opponentDetailColorTeal;
        case OpponentColor.pink: return l10n.opponentDetailColorPink;
        case OpponentColor.indigo: return l10n.opponentDetailColorIndigo;
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

      // Block rename to an existing opponent's name
      if (name.toLowerCase() != _opponent.name.toLowerCase()) {
        final existing = await OpponentService.findOpponentByName(name);
        if (existing != null && existing.id != _opponent.id) {
          nameError = l10n.opponentAlreadyExists(name);
          _setSheetState?.call(() {});
          return;
        }
      }
      nameError = null;

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
            content: Text(l10n.opponentDetailUpdatedSuccessfully),
            backgroundColor: Color(0xFF44D69B),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.commonErrorGeneric(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    FormDrawer.show(
      context: context,
      title: l10n.opponentDetailEditOpponent,
      onSave: saveOpponent,
      body: StatefulBuilder(
        builder: (context, setSheetState) {
          _setSheetState = setSheetState;
          return Padding(
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
                        hintText: l10n.opponentDetailOpponentName,
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
                  if (nameError != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          nameError!,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 12,
                            color: const Color(0xFFE85A5A),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  // Separator
                  Container(
                    height: 21,
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.center,
                    child: Container(height: 1, color: Color(0xFF3A3A3C)),
                  ),
                  // Notes field
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
                        hintText: l10n.opponentDetailNotesOptional,
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
                    child: Container(height: 1, color: Color(0xFF3A3A3C)),
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
                            l10n.opponentDetailPickColor,
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
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation() {
    final l10n = AppLocalizations.of(context);
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
                      l10n.opponentDetailDeleteConfirmTitle,
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
                        l10n.opponentDetailDeleteConfirmMessage(_opponent.name),
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
                              content: Text(l10n.opponentDetailDeletedSuccessfully),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.opponentDetailErrorDeleting(e.toString())),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                        child: Text(
                          l10n.commonDelete,
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
                    l10n.commonCancel,
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
