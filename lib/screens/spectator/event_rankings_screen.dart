import 'dart:async';
import 'package:flutter/material.dart';
import '../../design_system/poker_friend_theme.dart';
import '../../models/club_event.dart';
import '../../models/event_ranking.dart';
import '../../services/event_service.dart';
import '../../services/table_service.dart';
import '../../utils/number_formatter.dart';

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
  Map<String, String> _tableNames = {}; // tableId -> tableName

  @override
  void initState() {
    super.initState();
    _loadTableNames();
    _loadRankings();
    // Auto-refresh every 10 seconds
    _refreshTimer = Timer.periodic(Duration(seconds: 10), (_) {
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
      print('Error loading table names: $e');
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
      // Try backend API first
      var data = widget.event.isPublic
          ? await EventService.getPublicRankings(
              widget.event.id,
              accessCode: widget.accessCode,
            )
          : await EventService.getRankings(widget.event.id);

      // Fallback to Firestore if backend returns empty
      if (data == null || data.rankings.isEmpty) {
        data = await EventService.getRankingsFromFirestore(
          widget.event.clubId,
          widget.event.id,
        );
      }

      if (mounted) {
        setState(() {
          _rankingsData = data;
          _isLoading = false;
          _error = data == null ? 'Unable to load rankings' : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error loading rankings: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PokerFriendColors.dark1,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: PokerFriendColors.purple,
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
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 16),
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
                  decoration: BoxDecoration(
                    color: PokerFriendColors.dark3,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Rankings',
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.event.name,
                      style: TextStyle(
                        fontSize: 14,
                        color: PokerFriendColors.purple,
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
                  decoration: BoxDecoration(
                    color: PokerFriendColors.dark3,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.refresh,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          if (_rankingsData != null) ...[
            SizedBox(height: 16),
            _buildStatsRow(),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final data = _rankingsData!;
    final activePlayers = data.rankings.where((r) => !r.isEliminated).length;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PokerFriendColors.dark3,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            label: 'Players',
            value: '$activePlayers / ${data.totalPlayers}',
            color: PokerFriendColors.purple,
          ),
          Container(
            width: 1,
            height: 40,
            color: PokerFriendColors.dark5,
          ),
          _buildStatItem(
            label: 'Total Chips',
            value: formatCompactNumber(data.totalChips),
            color: PokerFriendColors.green,
          ),
          Container(
            width: 1,
            height: 40,
            color: PokerFriendColors.dark5,
          ),
          _buildStatItem(
            label: 'Avg Stack',
            value: formatCompactNumber(data.averageStack),
            color: PokerFriendColors.yellow,
          ),
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
          style: TextStyle(
            fontSize: 18,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: PokerFriendColors.dark9,
          ),
        ),
      ],
    );
  }

  Widget _buildRankingsList() {
    final rankings = _rankingsData!.rankings;
    final averageStack = _rankingsData!.averageStack;

    // Calculate finish positions for eliminated players who don't have one
    final totalPlayers = rankings.length;
    final eliminatedPlayers = rankings.where((r) => r.isEliminated).toList();

    // Create a map of calculated finish positions
    // Eliminated players get positions from totalPlayers down
    // (last eliminated = totalPlayers, second to last = totalPlayers-1, etc.)
    final calculatedFinishPositions = <String, int>{};
    for (int i = 0; i < eliminatedPlayers.length; i++) {
      final player = eliminatedPlayers[i];
      if (player.finishPosition == null) {
        // Assign finish position: total - index of elimination
        // Since we don't know order of elimination, use total - i
        calculatedFinishPositions[player.playerId] = totalPlayers - i;
      }
    }

    return RefreshIndicator(
      onRefresh: () => _loadRankings(),
      color: PokerFriendColors.purple,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 24),
        itemCount: rankings.length,
        itemBuilder: (context, index) {
          final ranking = rankings[index];
          final calculatedFinish = calculatedFinishPositions[ranking.playerId];
          return _buildRankingCard(ranking, index, calculatedFinish, averageStack);
        },
      ),
    );
  }

  Widget _buildRankingCard(EventRanking ranking, int index, int? calculatedFinishPosition, int averageStack) {
    final isChipLeader = index == 0 && !ranking.isEliminated;
    final isEliminated = ranking.isEliminated;
    // Use ranking's finishPosition if available, otherwise use calculated
    final finishPosition = ranking.finishPosition ?? calculatedFinishPosition;
    // Get color based on stack vs average
    final stackColor = _getStackColor(ranking.currentStack, averageStack, isEliminated);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEliminated
            ? PokerFriendColors.dark3.withOpacity(0.5)
            : PokerFriendColors.dark3,
        borderRadius: BorderRadius.circular(16),
        border: isChipLeader
            ? Border.all(color: PokerFriendColors.yellow, width: 2)
            : null,
      ),
      child: Row(
        children: [
          // Rank badge - shows finish position for eliminated, rank for active
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isChipLeader
                  ? PokerFriendColors.yellow
                  : isEliminated
                      ? PokerFriendColors.dark5
                      : PokerFriendColors.purple.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: isEliminated
                  ? Text(
                      '${finishPosition ?? "X"}',
                      style: TextStyle(
                        fontSize: 16,
                        color: PokerFriendColors.dark9,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : Text(
                      '${ranking.rank}',
                      style: TextStyle(
                        fontSize: 16,
                        color: isChipLeader
                            ? PokerFriendColors.dark1
                            : PokerFriendColors.purple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          SizedBox(width: 16),

          // Player info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      ranking.playerName,
                      style: TextStyle(
                        fontSize: 16,
                        color: isEliminated
                            ? PokerFriendColors.dark9
                            : Colors.white,
                        fontWeight: FontWeight.w600,
                        // No strikethrough - just gray color for eliminated
                      ),
                    ),
                    if (isChipLeader) ...[
                      SizedBox(width: 8),
                      Icon(
                        Icons.emoji_events,
                        color: PokerFriendColors.yellow,
                        size: 16,
                      ),
                    ],
                  ],
                ),
                // Only show table/seat for active (non-eliminated) players
                if (!isEliminated && (ranking.tableId.isNotEmpty || ranking.seatNumber > 0)) ...[
                  SizedBox(height: 2),
                  Text(
                    '${_getTableDisplayName(ranking)} - Seat ${ranking.seatNumber}',
                    style: TextStyle(
                      fontSize: 12,
                      color: PokerFriendColors.dark9,
                    ),
                  ),
                ],
                // Show "BUSTED" label for eliminated players
                if (isEliminated) ...[
                  SizedBox(height: 2),
                  Text(
                    'BUSTED',
                    style: TextStyle(
                      fontSize: 12,
                      color: PokerFriendColors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Stack and profit/loss
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCompactNumber(ranking.currentStack),
                style: TextStyle(
                  fontSize: 18,
                  color: stackColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!isEliminated) ...[
                SizedBox(height: 2),
                Text(
                  '${ranking.profitLoss >= 0 ? '+' : ''}${formatCompactNumber(ranking.profitLoss)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: ranking.profitLoss >= 0
                        ? PokerFriendColors.green
                        : PokerFriendColors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.leaderboard_outlined,
            size: 64,
            color: PokerFriendColors.dark5,
          ),
          SizedBox(height: 16),
          Text(
            'No Rankings Yet',
            style: TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Rankings will appear once players are seated',
            style: TextStyle(
              fontSize: 14,
              color: PokerFriendColors.dark9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: PokerFriendColors.red,
          ),
          SizedBox(height: 16),
          Text(
            'Error Loading Rankings',
            style: TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: PokerFriendColors.dark9,
              ),
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadRankings,
            style: ElevatedButton.styleFrom(
              backgroundColor: PokerFriendColors.purple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Try Again',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Get color for stack based on comparison to average
  /// Green: > avg + 10%, Orange: within ±10%, Red: < avg - 10%
  Color _getStackColor(int stack, int averageStack, bool isEliminated) {
    if (isEliminated) return PokerFriendColors.dark9;
    if (averageStack == 0) return PokerFriendColors.yellow; // Edge case

    final upperBound = averageStack * 1.10; // +10%
    final lowerBound = averageStack * 0.90; // -10%

    if (stack > upperBound) {
      return PokerFriendColors.green; // Above average
    } else if (stack < lowerBound) {
      return PokerFriendColors.red; // Below average
    } else {
      return PokerFriendColors.yellow; // Within ±10% of average
    }
  }

  String _getTableDisplayName(EventRanking ranking) {
    // First check if ranking already has a table name
    if (ranking.tableName != null && ranking.tableName!.isNotEmpty) {
      return ranking.tableName!;
    }
    // Look up from our local table names map
    if (_tableNames.containsKey(ranking.tableId)) {
      return _tableNames[ranking.tableId]!;
    }
    // Fallback to a shortened version of the ID or generic name
    if (ranking.tableId.isEmpty) {
      return 'Table';
    }
    // Show first 8 chars of ID as fallback
    return 'Table ${ranking.tableId.length > 8 ? ranking.tableId.substring(0, 8) : ranking.tableId}';
  }
}
