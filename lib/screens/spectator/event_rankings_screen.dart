import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/club_event.dart';
import '../../models/event_ranking.dart';
import '../../services/event_service.dart';
import '../../services/table_service.dart';
import '../../services/dealer_service.dart';
import '../../utils/number_formatter.dart';
import '../../l10n/app_localizations.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/typography.dart';
import '../../design_system/constants/decorations.dart';
import '../../utils/user_facing_error.dart';

/// Screen for spectators to view live rankings during an event
class EventRankingsScreen extends StatefulWidget {
  final ClubEvent event;
  final String? accessCode;

  const EventRankingsScreen({
    Key? key,
    required this.event,
    this.accessCode,
  }) : super(key: key);

  @override
  State<EventRankingsScreen> createState() => _EventRankingsScreenState();
}

class _EventRankingsScreenState extends State<EventRankingsScreen> {
  EventRankingsData? _rankingsData;
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;
  Map<String, String> _tableNames = {};
  double _bigBlind = 0.0;

  @override
  void initState() {
    super.initState();
    _loadTableNames();
    _loadBigBlind();
    _loadRankings();
    // Auto-refresh every 10 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadRankings(silent: true);
    });
  }

  Future<void> _loadTableNames() async {
    try {
      final tables = await TableService.getTables(widget.event.clubId);
      if (mounted) {
        setState(() {
          _tableNames = {for (var t in tables) t.id: t.name};
        });
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadBigBlind() async {
    try {
      // Get BB from the first active dealer session for this event's tables
      for (final tableId in widget.event.tableIds) {
        final session = await DealerService.getActiveSessionForTable(
          clubId: widget.event.clubId,
          tableId: tableId,
        );
        if (session != null && session.bigBlind > 0) {
          if (mounted) {
            setState(() => _bigBlind = session.bigBlind);
          }
          return;
        }
      }
    } catch (e) {
      // ignore — BB will show as 0 and we just won't display it
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRankings({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      // Load rankings directly from Firestore (seat assignments)
      final data = await EventService.getRankingsFromFirestore(
        widget.event.clubId,
        widget.event.id,
      );

      if (mounted) {
        setState(() {
          _rankingsData = data;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error loading rankings: ${UserFacingError.message(e)}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        children: [
          // Content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accentPrimary,
                          ),
                        )
                      : _error != null
                          ? _buildErrorState()
                          : _rankingsData == null || _rankingsData!.rankings.isEmpty
                              ? _buildEmptyState()
                              : _buildRankingsList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceDark,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).liveRankingsTitle,
                      style: AppTypography.ibm(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.event.name,
                      style: AppTypography.ibm(
                        fontSize: 13,
                        color: AppColors.accentPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _loadRankings(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceDark,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.refresh,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          if (_rankingsData != null) ...[
            const SizedBox(height: 12),
            _buildStatsRow(),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final l10n = AppLocalizations.of(context);
    final data = _rankingsData!;
    final activePlayers = data.rankings.where((r) => !r.isEliminated).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.infoCardBg,
        borderRadius: BorderRadius.circular(AppDecorations.radius14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            label: l10n.leaderboardPlayers,
            value: '$activePlayers / ${data.totalPlayers}',
            color: AppColors.accentPrimary,
          ),
          Container(width: 1, height: 32, color: Colors.white.withOpacity(0.06)),
          _buildStatItem(
            label: l10n.leaderboardTotalChips,
            value: formatCompactNumber(data.totalChips),
            color: AppColors.accentPrimary,
          ),
          if (_bigBlind > 0) ...[
            Container(width: 1, height: 32, color: Colors.white.withOpacity(0.06)),
            _buildStatItem(
              label: 'Avg BBs',
              value: '${data.averageStack ~/ _bigBlind}',
              color: Colors.amber,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.ibm(
            fontSize: 16,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.ibm(
            fontSize: 11,
            color: Colors.white.withOpacity(0.4),
          ),
        ),
      ],
    );
  }

  Widget _buildRankingsList() {
    final rankings = _rankingsData!.rankings;
    final averageStack = _rankingsData!.averageStack;

    // Split into active and eliminated
    final activePlayers = rankings.where((r) => !r.isEliminated).toList();
    final eliminatedPlayers = rankings.where((r) => r.isEliminated).toList();

    // Calculate finish positions for eliminated players
    final totalPlayers = rankings.length;
    final calculatedFinishPositions = <String, int>{};
    for (int i = 0; i < eliminatedPlayers.length; i++) {
      final player = eliminatedPlayers[i];
      if (player.finishPosition == null) {
        calculatedFinishPositions[player.playerId] = totalPlayers - i;
      }
    }

    // Find where to insert the average line among active players
    // It goes after the last player whose stack >= averageStack
    int avgLineIndex = activePlayers.length; // default: after all
    for (int i = 0; i < activePlayers.length; i++) {
      if (activePlayers[i].currentStack < averageStack) {
        avgLineIndex = i;
        break;
      }
    }

    // Build list items: active players + avg line + eliminated section
    final List<Widget> items = [];

    for (int i = 0; i < activePlayers.length; i++) {
      if (i == avgLineIndex) {
        items.add(_buildAverageStackDivider(averageStack));
      }
      items.add(_buildRankingCard(activePlayers[i], isChipLeader: i == 0));
    }
    // If avg line goes at the end (all players above average)
    if (avgLineIndex == activePlayers.length && activePlayers.isNotEmpty) {
      items.add(_buildAverageStackDivider(averageStack));
    }

    // Eliminated section
    if (eliminatedPlayers.isNotEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 10),
          child: Builder(
            builder: (context) => Text(
              AppLocalizations.of(context).liveRankingsEliminated,
              style: AppTypography.ibm(
                fontSize: 15,
                color: Colors.white.withOpacity(0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
      for (final player in eliminatedPlayers) {
        final finishPos = player.finishPosition ?? calculatedFinishPositions[player.playerId];
        items.add(_buildEliminatedCard(player, finishPos));
      }
    }

    return RefreshIndicator(
      onRefresh: () => _loadRankings(),
      color: AppColors.accentPrimary,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: items,
      ),
    );
  }

  Widget _buildAverageStackDivider(int averageStack) {
    final avgText = 'Average stack: ${formatCompactNumber(averageStack)}';
    final bbText = _bigBlind > 0 ? ' ${averageStack ~/ _bigBlind} BBs' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(height: 1, color: Colors.white.withOpacity(0.08)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '$avgText$bbText',
              style: AppTypography.ibm(
                fontSize: 12,
                color: Colors.white.withOpacity(0.45),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Container(height: 1, color: Colors.white.withOpacity(0.08)),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingCard(EventRanking ranking, {required bool isChipLeader}) {
    final bbCount = _bigBlind > 0 ? ranking.currentStack ~/ _bigBlind : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.infoCardBg,
        borderRadius: BorderRadius.circular(AppDecorations.radius14),
        border: isChipLeader
            ? Border.all(color: Colors.amber.withOpacity(0.4), width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          // Rank label (1st, 2nd, 3rd, 4th...)
          SizedBox(
            width: 32,
            child: Text(
              _ordinal(ranking.rank),
              style: AppTypography.ibm(
                fontSize: 13,
                color: isChipLeader ? Colors.amber : Colors.white.withOpacity(0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Player info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        ranking.playerName,
                        style: AppTypography.ibm(
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isChipLeader) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.emoji_events, color: Colors.amber, size: 15),
                    ],
                  ],
                ),
                if (ranking.tableId.isNotEmpty || ranking.seatNumber > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${_getTableDisplayName(ranking)} - Seat ${ranking.seatNumber}',
                    style: AppTypography.ibm(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.35),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Stack + BBs
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCompactNumber(ranking.currentStack),
                style: AppTypography.ibm(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_bigBlind > 0) ...[
                const SizedBox(height: 2),
                Text(
                  '$bbCount BBs',
                  style: AppTypography.ibm(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.4),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEliminatedCard(EventRanking ranking, int? finishPosition) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(AppDecorations.radius14),
      ),
      child: Row(
        children: [
          // Finish position
          SizedBox(
            width: 32,
            child: Text(
              finishPosition != null ? _ordinal(finishPosition) : '-',
              style: AppTypography.ibm(
                fontSize: 13,
                color: Colors.white.withOpacity(0.25),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Name
          Expanded(
            child: Text(
              ranking.playerName,
              style: AppTypography.ibm(
                fontSize: 15,
                color: Colors.white.withOpacity(0.3),
                fontWeight: FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accentPrimary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppDecorations.radius14),
            ),
            child: Icon(
              Icons.event_seat_outlined,
              size: 28,
              color: AppColors.accentPrimary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.liveRankingsWaiting,
            style: AppTypography.ibm(
              fontSize: 17,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              l10n.liveRankingsWaitingHint,
              textAlign: TextAlign.center,
              style: AppTypography.ibm(
                fontSize: 14,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.lossRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDecorations.radius14),
            ),
            child: const Icon(
              Icons.error_outline,
              size: 28,
              color: AppColors.lossRed,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.liveRankingsError,
            style: AppTypography.ibm(
              fontSize: 17,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: AppTypography.ibm(
                fontSize: 14,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _loadRankings,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.accentPrimary,
                borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
              ),
              child: Text(
                l10n.liveRankingsTryAgain,
                style: AppTypography.ibm(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1: return '${n}st';
      case 2: return '${n}nd';
      case 3: return '${n}rd';
      default: return '${n}th';
    }
  }

  String _getTableDisplayName(EventRanking ranking) {
    if (ranking.tableName != null && ranking.tableName!.isNotEmpty) {
      return ranking.tableName!;
    }
    if (_tableNames.containsKey(ranking.tableId)) {
      return _tableNames[ranking.tableId]!;
    }
    if (ranking.tableId.isEmpty) {
      return 'Table';
    }
    return 'Table ${ranking.tableId.length > 8 ? ranking.tableId.substring(0, 8) : ranking.tableId}';
  }
}
