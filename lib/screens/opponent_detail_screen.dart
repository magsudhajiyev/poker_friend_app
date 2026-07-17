import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../models/opponent.dart';
import '../models/opponent_stats.dart';
import '../services/opponent_service.dart';
import '../services/local_storage_service.dart';
import '../services/firebase_service.dart';
import '../services/opponent_stats_service.dart';
import 'opponent_hands_screen.dart';
import '../design_system/components/buttons/back_button_circle.dart';
import '../design_system/components/buttons/close_circle_button.dart';
import '../design_system/components/buttons/primary_pill_button.dart';
import '../design_system/components/buttons/outlined_pill_button.dart';
import '../design_system/components/sheets/sheet_header.dart';
import '../design_system/components/drawer_dots.dart';
import '../design_system/components/modals/confirm_dialog.dart';
import '../l10n/app_localizations.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';
import '../utils/user_facing_error.dart';

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
  bool _wasEdited = false;

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
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Column(
        children: [
          // Header wrapped in Hero paired with the source card in
          // MyOpponentsScreen — tapping an opponent grows the card into
          // this header instead of a plain push.
          Hero(
            tag: 'opponentCard_${widget.opponent.id}',
            flightShuttleBuilder:
                (context, animation, direction, from, to) => Material(
              color: Colors.transparent,
              child: to.widget,
            ),
            child: _buildHeader(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatisticsSection(),
                  if (_opponent.notes != null && _opponent.notes!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildNotesSection(),
                  ],
                  const SizedBox(height: 64),
                  _buildViewHandHistoryButton(),
                ],
              ),
            ),
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
      color: AppColors.bgPrimary,
      padding: EdgeInsets.fromLTRB(16, topPad + 16, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          BackButtonCircle(onPressed: () => Navigator.pop(context, _wasEdited ? true : null)),
          const SizedBox(width: 12),
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accentPurple,
              borderRadius: BorderRadius.circular(AppDecorations.radius10),
            ),
            alignment: Alignment.center,
            child: Text(
              _getInitials(_opponent.name),
              style: AppTypography.ibm(
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
                  style: AppTypography.ibm(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 20 / 17,
                  ),
                ),
                Text(
                  handsText,
                  style: AppTypography.ibm(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: AppColors.accentSecondary,
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
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
            border: Border.all(color: AppColors.borderStrong),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Text(
            l10n.opponentDetailViewHandHistory,
            style: AppTypography.ibm(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
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
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
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
                      style: AppTypography.ibm(
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
                    style: AppTypography.ibm(
                      fontSize: 17,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      height: 1.44,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${OpponentHandsScreen.filteredHandCounts[_opponent.id] ?? _statistics?['totalHands'] ?? 0}',
                    style: AppTypography.ibm(
                      fontSize: 17,
                      color: AppColors.accentPrimary,
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
                        style: AppTypography.ibm(
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
                      style: AppTypography.ibm(
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
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        border: Border.all(color: Colors.black),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with icon, label, and edit button
          Row(
            children: [
              _buildIcon(
                'icons/figma_icons/notes.svg',
                18,
                const Color(0xFF808285),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.opponentDetailNotes,
                style: AppTypography.ibm(
                  fontSize: 13,
                  color: const Color(0xFF808285),
                  fontWeight: FontWeight.w500,
                  height: 1.44,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showEditNotesDialog,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: _buildIcon(
                    'icons/figma_icons/edit.svg',
                    16,
                    AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Notes content
          Text(
            _opponent.notes!,
            style: AppTypography.ibm(
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

  void _showEditNotesDialog() {
    final l10n = AppLocalizations.of(context);
    final notesController = TextEditingController(text: _opponent.notes ?? '');
    final notesFocusNode = FocusNode();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            notesFocusNode.addListener(() => setSheetState(() {}));
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              decoration: BoxDecoration(
                color: AppColors.bgPrimary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppDecorations.radiusXl),
                  topRight: Radius.circular(AppDecorations.radiusXl),
                ),
                border: Border.all(color: AppColors.borderStrong),
              ),
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SheetHeader(
                      title: l10n.opponentDetailNotes,
                      onClose: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                        border: Border.all(
                          color: notesFocusNode.hasFocus
                              ? AppColors.accentPrimary
                              : AppColors.borderStrong,
                          width: notesFocusNode.hasFocus ? 1.5 : 1.0,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: TextField(
                        controller: notesController,
                        focusNode: notesFocusNode,
                        autofocus: true,
                        style: AppTypography.ibm(
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: l10n.opponentsAddNotes,
                          hintStyle: AppTypography.ibm(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        maxLines: 5,
                        minLines: 3,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryPillButton(
                        label: l10n.commonSave,
                        onTap: () async {
                          final notes = notesController.text.trim();
                          try {
                            final updated = _opponent.copyWith(
                              notes: notes.isEmpty ? null : notes,
                              clearNotes: notes.isEmpty,
                            );
                            await OpponentService.saveOpponent(updated);
                            if (context.mounted) Navigator.pop(context);
                            _wasEdited = true;
                            setState(() => _opponent = updated);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(l10n.commonErrorGeneric(UserFacingError.message(e))),
                                backgroundColor: Colors.red,
                              ));
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      notesController.dispose();
      notesFocusNode.dispose();
    });
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
                  borderRadius: BorderRadius.circular(AppDecorations.radius18),
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
                                style: AppTypography.ibm(
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
                                style: AppTypography.ibm(
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
          color: AppColors.accentPrimary,
        ),
      );
    }

    if (_statistics == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
          l10n.opponentDetailNoStatisticsAvailable,
          style: AppTypography.ibm(
            color: AppColors.textSecondary,
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
          style: AppTypography.ibm(
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
          style: AppTypography.ibm(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
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
            style: AppTypography.ibm(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTypography.ibm(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.accentSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: AppColors.bgElevated,
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
                style: AppTypography.ibm(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDisabled,
                  height: 1.44,
                ),
              ),
              // Subtitle
              Text(
                l10n.opponentDetailViewAllHands,
                style: AppTypography.ibm(
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
              backgroundColor: AppColors.accentPrimary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(110),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 32),
              elevation: 0,
            ),
            child: Text(
              l10n.opponentDetailViewHandHistory,
              style: AppTypography.ibm(
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
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(AppDecorations.radiusXl),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row: spacer + glass X close
              Row(
                children: [
                  const Expanded(child: SizedBox()),
                  CloseCircleButton(onTap: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 24),
              // Title
              Text(
                l10n.opponentDetailNoHandsFound,
                textAlign: TextAlign.center,
                style: AppTypography.ibm(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 20 / 17,
                ),
              ),
              const SizedBox(height: 7),
              // Description
              Text(
                l10n.opponentDetailNoHandsMessage(_opponent.name),
                textAlign: TextAlign.center,
                style: AppTypography.ibm(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  height: 22 / 15,
                ),
              ),
              const SizedBox(height: 24),
              // Close button — matches View Hand History pill style.
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
                    border: Border.all(color: AppColors.borderStrong),
                  ),
                  child: Text(
                    l10n.commonClose,
                    textAlign: TextAlign.center,
                    style: AppTypography.ibm(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
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
      (OpponentColor.green,  AppColors.opponentGreen),
      (OpponentColor.orange, AppColors.accentTertiary),
      (OpponentColor.red,    AppColors.accentDanger),
      (OpponentColor.blue,   AppColors.accentInfo),
      (OpponentColor.purple, AppColors.opponentPurple),
      (OpponentColor.teal,   AppColors.opponentYellow),
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
        _wasEdited = true;
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
            content: Text(l10n.commonErrorGeneric(UserFacingError.message(e))),
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
              decoration: BoxDecoration(
                color: AppColors.bgPrimary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppDecorations.radiusXl),
                  topRight: Radius.circular(AppDecorations.radiusXl),
                ),
                border: Border.all(color: AppColors.borderStrong),
              ),
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    SheetHeader(
                      title: l10n.opponentDetailEditOpponent,
                      onClose: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 16),
                    // Name label
                    Text(
                      l10n.opponentsNameHint,
                      style: AppTypography.ibm(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: nameFocusNode.hasFocus
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.bgElevated,
                        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                        border: Border.all(
                          color: nameFocusNode.hasFocus
                              ? AppColors.accentPrimary
                              : AppColors.borderStrong,
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
                              style: AppTypography.ibm(
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: l10n.opponentsEnterName,
                                hintStyle: AppTypography.ibm(
                                  fontSize: 15,
                                  color: AppColors.textSecondary,
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
                              child: const Icon(Icons.cancel, color: AppColors.textSecondary, size: 16),
                            ),
                        ],
                      ),
                    ),
                    if (nameError != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        nameError!,
                        style: AppTypography.ibm(
                          fontSize: 12,
                          color: AppColors.accentDanger,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Notes label
                    Text(
                      'Notes (Optional)',
                      style: AppTypography.ibm(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: notesFocusNode.hasFocus
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.bgElevated,
                        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                        border: Border.all(
                          color: notesFocusNode.hasFocus
                              ? AppColors.accentPrimary
                              : AppColors.borderStrong,
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
                              style: AppTypography.ibm(
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: l10n.opponentsAddNotes,
                                hintStyle: AppTypography.ibm(
                                  fontSize: 15,
                                  color: AppColors.textSecondary,
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
                              child: const Icon(Icons.cancel, color: AppColors.textSecondary, size: 16),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Color picker label
                    Text(
                      l10n.opponentsPickColor,
                      style: AppTypography.ibm(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
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
                                  ? Border.all(color: AppColors.textPrimary, width: 2)
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
                          child: OutlinedPillButton(
                            label: 'Back',
                            onTap: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: PrimaryPillButton(
                            label: 'Save',
                            onTap: saveOpponent,
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
              content: Text(l10n.opponentDetailErrorDeleting(UserFacingError.message(e))),
              backgroundColor: Colors.red,
            ));
          }
        }
      },
    );
  }
}
