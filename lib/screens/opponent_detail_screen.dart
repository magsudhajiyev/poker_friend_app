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
import '../design_system/components/modals/confirm_dialog.dart';
import '../l10n/app_localizations.dart';
import '../design_system/constants/colors.dart';

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
      debugPrint('Error loading statistics: $e');
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  Future<Map<String, dynamic>> _calculateOpponentStatistics(String opponentName) async {
    try {
      final optimizedStats = await OpponentStatsService.getOpponentStats(_opponent.id);

      if (optimizedStats != null) {
        debugPrint('✅ Using optimized stats for $opponentName (${optimizedStats.handsPlayed} hands)');
        final legacyMap = optimizedStats.toLegacyStatsMap();
        return legacyMap;
      } else {
        debugPrint('⚠️ No optimized stats found for $opponentName - calculating from hand data');
        return await _calculateLegacyOpponentStatistics(opponentName);
      }
    } catch (e) {
      debugPrint('❌ Error loading optimized stats: $e');
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
      debugPrint('❌ Error calculating legacy stats: $e');
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
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 100 + bottomPad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatisticsSection(),
                      const SizedBox(height: 64),
                      _buildViewHandHistoryButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.take(2).map((p) => p.isNotEmpty ? p[0].toUpperCase() : '').join();
    return initials;
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context);
    final topPad = MediaQuery.of(context).padding.top;
    final handsCount = _opponentStats?.handsPlayed ?? (_statistics?['totalHands'] as int? ?? 0);
    final handsText = handsCount > 0
        ? l10n.opponentDetailHandsTracked(handsCount)
        : l10n.opponentDetailNoDataYet;

    return Container(
      color: const Color(0xFF161719),
      padding: EdgeInsets.fromLTRB(16, topPad + 16, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF763EED),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              _getInitials(_opponent.name),
              style: GoogleFonts.ibmPlexSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + hand count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _opponent.name,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 20 / 17,
                  ),
                ),
                Text(
                  handsText,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFFA3FF78),
                    height: 22 / 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPad),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: SvgPicture.asset(
                'assets/icons/CaretLeft.svg',
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
              ),
            ),
          ),
          // Action pill (Edit + Delete)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161719),
              border: Border.all(color: const Color(0xFF3A3A3C)),
              borderRadius: BorderRadius.circular(999),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Edit group
                GestureDetector(
                  onTap: _showEditOpponentDialog,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF8A54),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: _buildIcon('icons/figma_icons/edit.svg', 16, Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Edit',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Delete group
                GestureDetector(
                  onTap: _showDeleteConfirmation,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF3B30),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: _buildIcon('icons/figma_icons/delete.svg', 16, Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Delete',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewHandHistoryButton() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: GestureDetector(
        onTap: () {
          final totalHands = OpponentHandsScreen.filteredHandCounts[_opponent.id]
              ?? _statistics?['totalHands'] ?? 0;
          if (totalHands == 0) {
            _showNoHandsFoundDialog();
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OpponentHandsScreen(opponent: _opponent),
              ),
            );
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Text(
            l10n.opponentDetailViewHandHistory,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0C0C0C),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    final l10n = AppLocalizations.of(context);
    final cardColor = _getColorForOpponent(_opponent.color);
    final dotsKey = GlobalKey();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
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
              color: AppColors.separatorDark,
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
                      color: AppColors.textMint,
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
                      DateFormat('MMM dd, yyyy').format(_opponent.lastSeenAt),
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
        color: AppColors.surfaceDark,
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
                  color: AppColors.paper,
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
                      color: AppColors.separatorDark,
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
                            AppColors.errorRed,
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
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.buttonPrimary,
        ),
      );
    }

    if (_statistics == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
          l10n.opponentDetailNoStatisticsAvailable,
          style: GoogleFonts.ibmPlexSans(
            color: const Color(0xFFB9B9B9),
            fontSize: 15,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Text(
          l10n.opponentDetailStatistics,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            height: 20 / 17,
          ),
        ),
        const SizedBox(height: 8),
        // Disclaimer
        Text(
          l10n.opponentDetailStatsDisclaimer,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: const Color(0xFFB9B9B9),
            height: 22 / 15,
          ),
        ),
        const SizedBox(height: 24),
        // 7 stat rows with dividers, 8px padding top and bottom of the list
        const SizedBox(height: 8),
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
        const SizedBox(height: 8),
      ],
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: const Color(0xFFB9B9B9),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFA3FF78),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: const Color(0xFF2C2C2E),
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
                  color: AppColors.textDisabled,
                  height: 1.44,
                ),
              ),
              // Subtitle
              Text(
                l10n.opponentDetailViewAllHands,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDisabled,
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
              backgroundColor: AppColors.buttonPrimary,
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
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row: spacer + X close
              Row(
                children: [
                  const Expanded(child: SizedBox()),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: SvgPicture.asset(
                        'assets/icons/X.svg',
                        width: 18,
                        height: 18,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFFB9B9B9),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Icon holder
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFEFEF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'icons/figma_icons/search.svg',
                    width: 24,
                    height: 24,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF0C0C0C),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Title
              Text(
                l10n.opponentDetailNoHandsFound,
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0C0C0C),
                  height: 20 / 17,
                ),
              ),
              const SizedBox(height: 7),
              // Description
              Text(
                l10n.opponentDetailNoHandsMessage(_opponent.name),
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFFB9B9B9),
                  height: 22 / 15,
                ),
              ),
              const SizedBox(height: 24),
              // Close button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C0C0C),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    l10n.commonClose,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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
    final nameFocusNode = FocusNode();
    final notesFocusNode = FocusNode();
    OpponentColor selectedColor = _opponent.color;
    String? nameError;
    StateSetter? sheetSetState;

    const colorSwatches = [
      (OpponentColor.green,  Color(0xFF39FF14)),
      (OpponentColor.orange, Color(0xFFFF8A54)),
      (OpponentColor.red,    Color(0xFFFF3B30)),
      (OpponentColor.blue,   Color(0xFF007AFF)),
      (OpponentColor.purple, Color(0xFFBF5AF2)),
      (OpponentColor.teal,   Color(0xFFFFD60A)),
    ];

    void refreshSheet() => sheetSetState?.call(() {});
    nameFocusNode.addListener(refreshSheet);
    notesFocusNode.addListener(refreshSheet);
    nameController.addListener(refreshSheet);
    notesController.addListener(refreshSheet);

    Future<void> saveOpponent() async {
      final name = nameController.text.trim();
      if (name.isEmpty) return;

      if (name.toLowerCase() != _opponent.name.toLowerCase()) {
        final existing = await OpponentService.findOpponentByName(name);
        if (existing != null && existing.id != _opponent.id) {
          nameError = l10n.opponentAlreadyExists(name);
          sheetSetState?.call(() {});
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
        if (context.mounted) Navigator.pop(context);
        setState(() { _opponent = updatedOpponent; });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.opponentDetailUpdatedSuccessfully),
            backgroundColor: const Color(0xFF44D69B),
          ));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.commonErrorGeneric(e.toString())),
            backgroundColor: Colors.red,
          ));
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            sheetSetState = setSheetState;
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    SizedBox(
                      height: 20,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            l10n.opponentDetailEditOpponent,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0C0C0C),
                              height: 20 / 15,
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Icon(Icons.close, color: Color(0xFFB9B9B9), size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Name label
                    Text(
                      l10n.opponentsNameHint,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: nameFocusNode.hasFocus
                            ? const Color(0xFF0C0C0C)
                            : const Color(0xFFB9B9B9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDFDFD),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: nameFocusNode.hasFocus
                              ? const Color(0xFF4CDE78)
                              : const Color(0xFFEFEFEF),
                          width: nameFocusNode.hasFocus ? 1.5 : 1.0,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: nameController,
                              focusNode: nameFocusNode,
                              textInputAction: TextInputAction.next,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 15,
                                color: const Color(0xFF0C0C0C),
                              ),
                              decoration: InputDecoration(
                                hintText: l10n.opponentsEnterName,
                                hintStyle: GoogleFonts.ibmPlexSans(
                                  fontSize: 15,
                                  color: const Color(0xFFB9B9B9),
                                ),
                                filled: true,
                                fillColor: Colors.transparent,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (nameController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () => nameController.clear(),
                              child: const Icon(Icons.cancel, color: Color(0xFFB9B9B9), size: 16),
                            ),
                        ],
                      ),
                    ),
                    if (nameError != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        nameError!,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 12,
                          color: const Color(0xFFE85A5A),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Notes label
                    Text(
                      'Notes (Optional)',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: notesFocusNode.hasFocus
                            ? const Color(0xFF0C0C0C)
                            : const Color(0xFFB9B9B9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDFDFD),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: notesFocusNode.hasFocus
                              ? const Color(0xFF4CDE78)
                              : const Color(0xFFEFEFEF),
                          width: notesFocusNode.hasFocus ? 1.5 : 1.0,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: notesController,
                              focusNode: notesFocusNode,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 15,
                                color: const Color(0xFF0C0C0C),
                              ),
                              decoration: InputDecoration(
                                hintText: l10n.opponentsAddNotes,
                                hintStyle: GoogleFonts.ibmPlexSans(
                                  fontSize: 15,
                                  color: const Color(0xFFB9B9B9),
                                ),
                                filled: true,
                                fillColor: Colors.transparent,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              maxLines: 2,
                              minLines: 1,
                            ),
                          ),
                          if (notesController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () => notesController.clear(),
                              child: const Icon(Icons.cancel, color: Color(0xFFB9B9B9), size: 16),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Color picker label
                    Text(
                      l10n.opponentsPickColor,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFB9B9B9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Color swatches
                    Row(
                      children: colorSwatches.map((entry) {
                        final (color, swatchColor) = entry;
                        final isSelected = color == selectedColor;
                        return GestureDetector(
                          onTap: () => setSheetState(() => selectedColor = color),
                          child: Container(
                            width: 36,
                            height: 36,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: const Color(0xFF0C0C0C), width: 2)
                                  : null,
                            ),
                            child: Center(
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: swatchColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                    // Back + Save buttons
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: const Color(0xFFB9B9B9)),
                              ),
                              child: Text(
                                'Back',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0C0C0C),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: saveOpponent,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0C0C0C),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Save',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      nameFocusNode.dispose();
      notesFocusNode.dispose();
      nameController.dispose();
      notesController.dispose();
    });
  }

  void _showDeleteConfirmation() {
    final l10n = AppLocalizations.of(context);
    ConfirmDialog.show(
      context,
      title: l10n.opponentDetailDeleteConfirmTitle,
      message: l10n.opponentDetailDeleteConfirmMessage(_opponent.name),
      confirmLabel: l10n.commonConfirm,
      onConfirm: () async {
        try {
          await OpponentService.deleteOpponent(_opponent.id);
          if (context.mounted) Navigator.pop(context, true);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(l10n.opponentDetailErrorDeleting(e.toString())),
              backgroundColor: Colors.red,
            ));
          }
        }
      },
    );
  }
}
