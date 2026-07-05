import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/club.dart';
import '../../models/club_event.dart';
import '../../models/event_ranking.dart';
import '../../models/poker_table.dart';
import '../../services/event_service.dart';
import '../../services/websocket_service.dart';
import '../../models/dealer_session.dart';
import '../../services/dealer_service.dart';
import '../../services/seat_service.dart';
import '../../config/app_config.dart';
import '../public/public_leaderboard_screen.dart';
import '../../design_system/components/cards/error_state_card.dart';
import '../../l10n/app_localizations.dart';
import '../../design_system/constants/decorations.dart';

/// Live event dashboard with real-time rankings
class EventDashboardScreen extends StatefulWidget {
  final Club club;
  final ClubEvent event;
  final List<PokerTable> tables;

  const EventDashboardScreen({
    Key? key,
    required this.club,
    required this.event,
    required this.tables,
  }) : super(key: key);

  @override
  State<EventDashboardScreen> createState() => _EventDashboardScreenState();
}

class _EventDashboardScreenState extends State<EventDashboardScreen> {
  EventRankingsData? _rankingsData;
  bool _isLoading = true;
  String? _loadError;
  bool _isConnected = false;
  StreamSubscription? _rankingSubscription;
  Timer? _refreshTimer;
  final _numberFormat = NumberFormat('#,###');

  // Local fallback data when WebSocket is disconnected
  List<EventRanking>? _localRankings;
  int _localTotalChips = 0;
  bool _hasActiveSessions = true; // Assume active initially

  // Track busted players' finish positions (persists across data updates)
  final Map<String, int> _bustedPlayerPositions = {};

  // Refresh interval in seconds
  static const int _refreshIntervalSeconds = 30;

  @override
  void initState() {
    super.initState();
    _connectAndLoadRankings();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _rankingSubscription?.cancel();
    WebSocketService.instance.leaveEvent(widget.event.id);
    super.dispose();
  }

  Future<void> _connectAndLoadRankings() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      debugPrint('EventDashboard: Loading rankings for event ${widget.event.id}');
      debugPrint('EventDashboard: Club ID: ${widget.club.id}');
      debugPrint('EventDashboard: Tables: ${widget.tables.map((t) => '${t.id}(${t.name})').join(', ')}');

      // Sync players from tables FIRST (local data) - don't wait for WebSocket
      await _syncPlayersFromTables();

      // Connect to WebSocket if not already connected
      final wsService = WebSocketService.instance;
      if (!wsService.isConnected) {
        debugPrint('EventDashboard: Connecting to WebSocket at ${AppConfig.serverUrl}');
        wsService.connect(AppConfig.serverUrl);
        await Future.delayed(const Duration(seconds: 1));
      }

      // Only try to join event room if WebSocket connected
      if (wsService.isConnected) {
        // Join event room - pass event data so backend can create if needed
        final joinResult = await wsService.joinEvent(
          widget.event.id,
          clubId: widget.event.clubId,
          name: widget.event.name,
          tableIds: widget.event.tableIds,
          isPublic: widget.event.isPublic,
          accessCode: widget.event.accessCode,
          createdBy: widget.event.createdBy,
        );
        if (joinResult != null && joinResult['success'] == true) {
          setState(() => _isConnected = true);
          debugPrint('EventDashboard: WebSocket connected and joined event');

          // Initial rankings from join response
          if (joinResult['rankings'] != null) {
            setState(() {
              _rankingsData = EventRankingsData.fromMap(
                joinResult['rankings'] as Map<String, dynamic>,
              );
            });
          }
        } else {
          debugPrint('EventDashboard: Failed to join event room: $joinResult');
        }
      } else {
        debugPrint('EventDashboard: WebSocket not connected, using local data only');
      }

      // Subscribe to ranking updates
      _rankingSubscription = wsService.onRankingUpdate.listen((data) {
        final newRankings = EventRankingsData.fromMap(data);
        setState(() {
          _rankingsData = newRankings;
        });
      });

      // Start periodic refresh timer
      _startRefreshTimer();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _loadError = e.toString();
        _isLoading = false;
      });
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: _refreshIntervalSeconds),
      (_) => _syncPlayersFromTables(),
    );
    debugPrint('Started auto-refresh timer (every $_refreshIntervalSeconds seconds)');
  }

  Future<void> _syncPlayersFromTables() async {
    try {
      // Get current players from each table's active session or seat assignments
      final tablePlayers = <String, List<Map<String, dynamic>>>{};
      final allPlayers = <Map<String, dynamic>>[];
      bool hasAnyActiveSession = false;

      for (final table in widget.tables) {
        // First try to get players from DealerSession
        final session = await DealerService.getActiveSessionForTable(
          clubId: widget.club.id,
          tableId: table.id,
        );

        debugPrint('Table ${table.id} (${table.name}): session=${session != null}, activePlayers=${session?.activePlayers.length ?? 0}');

        if (session != null && session.activePlayers.isNotEmpty) {
          hasAnyActiveSession = true;
          final players = session.activePlayers.map((p) => {
                'player_id': 'seat_${table.id}_${p.seatNumber}',
                'real_player_id': p.playerId,
                'player_name': p.displayName,
                'current_stack': p.stack.toInt(),
                'starting_stack': p.stack.toInt(),
                'seat_number': p.seatNumber,
                'table_name': table.name,
              }).toList();

          tablePlayers[table.id] = players;
          allPlayers.addAll(players);
        } else {
          // Fallback: Get players from seat assignments
          final seatAssignments = await SeatService.getTableSeats(
            clubId: widget.club.id,
            tableId: table.id,
          );

          debugPrint('Table ${table.id}: seatAssignments=${seatAssignments.length}, occupied=${seatAssignments.values.where((s) => s.isOccupied).length}');

          final players = seatAssignments.entries
              .where((e) => e.value.isOccupied)
              .map((e) => {
                    'player_id': 'seat_${table.id}_${e.key}',
                    'real_player_id': e.value.playerId ?? '',
                    'player_name': e.value.playerName ?? 'Player ${e.key}',
                    'current_stack': (e.value.chipStack ?? 0).toInt(),
                    'starting_stack': (e.value.chipStack ?? 0).toInt(),
                    'seat_number': e.key,
                    'table_name': table.name,
                  })
              .toList();

          if (players.isNotEmpty) {
            tablePlayers[table.id] = players;
            allPlayers.addAll(players);
          }
        }
      }

      // Merge in players from ended dealer sessions (broken tables)
      // so they stay in rankings with their last known stack
      final seenPlayerIds = <String>{};
      for (final p in allPlayers) {
        final realId = p['real_player_id'] as String?;
        if (realId != null && realId.isNotEmpty) seenPlayerIds.add(realId);
      }
      try {
        final allSessions = await DealerService.getAllSessionsForEvent(widget.event.id);
        for (final session in allSessions) {
          if (session.status == DealerSessionStatus.ended) {
            for (final player in session.players.values) {
              if (player.playerId.isNotEmpty &&
                  !player.playerId.startsWith('manual_') &&
                  !seenPlayerIds.contains(player.playerId)) {
                seenPlayerIds.add(player.playerId);
                allPlayers.add({
                  'player_id': player.playerId,
                  'real_player_id': player.playerId,
                  'player_name': player.displayName,
                  'current_stack': player.stack.toInt(),
                  'starting_stack': player.stack.toInt(),
                  'seat_number': player.seatNumber,
                  'table_name': '(Reseating)',
                });
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error merging ended sessions: $e');
      }

      // Build local rankings as fallback (sorted by stack descending)
      allPlayers.sort((a, b) => (b['current_stack'] as int).compareTo(a['current_stack'] as int));

      // Count active players (non-busted) to calculate finish positions
      final activePlayerCount = allPlayers.where((p) => (p['current_stack'] as int) > 0).length;

      int totalChips = 0;
      final localRankings = <EventRanking>[];
      final now = DateTime.now();
      for (int i = 0; i < allPlayers.length; i++) {
        final p = allPlayers[i];
        final playerId = p['player_id'] as String;
        final stack = p['current_stack'] as int;
        totalChips += stack;

        // Determine player status
        PlayerRankingStatus status;
        if (stack <= 0) {
          status = PlayerRankingStatus.busted;
        } else if (!hasAnyActiveSession) {
          status = PlayerRankingStatus.onBreak;
        } else {
          status = PlayerRankingStatus.active;
        }

        // Track finish position for busted players
        int? finishPosition;
        if (status == PlayerRankingStatus.busted) {
          // Only assign finish position if not already tracked (first time busting)
          if (!_bustedPlayerPositions.containsKey(playerId)) {
            // Finish position = active players + 1 (they're out after all active players)
            _bustedPlayerPositions[playerId] = activePlayerCount + 1;
          }
          finishPosition = _bustedPlayerPositions[playerId];
        } else {
          // Player is active - if they were previously busted, they rebought
          // Clear their finish position so they can bust again later
          if (_bustedPlayerPositions.containsKey(playerId)) {
            _bustedPlayerPositions.remove(playerId);
          }
          finishPosition = null;
        }

        localRankings.add(EventRanking(
          eventId: widget.event.id,
          playerId: playerId,
          playerName: p['player_name'] as String,
          currentStack: stack,
          startingStack: p['starting_stack'] as int,
          tableId: '',
          tableName: p['table_name'] as String?,
          seatNumber: p['seat_number'] as int,
          rank: i + 1,
          lastUpdated: now,
          previousRank: null,
          previousStack: null,
          status: status,
          finishPosition: finishPosition,
        ));
      }

      // Update local fallback data
      setState(() {
        _localRankings = localRankings;
        _localTotalChips = totalChips;
        _hasActiveSessions = hasAnyActiveSession;
      });

      // Try to sync via WebSocket if connected
      if (WebSocketService.instance.isConnected) {
        final result = await WebSocketService.instance.syncEventPlayers(
          eventId: widget.event.id,
          tablePlayers: tablePlayers,
          clubId: widget.event.clubId,
          name: widget.event.name,
          tableIds: widget.event.tableIds,
          isPublic: widget.event.isPublic,
          createdBy: widget.event.createdBy,
        );

        if (result != null && result['rankings'] != null) {
          setState(() {
            _rankingsData = EventRankingsData.fromMap(
              result['rankings'] as Map<String, dynamic>,
            );
          });
        }
      }

      // Log for debugging
      debugPrint('Synced ${tablePlayers.length} tables with ${allPlayers.length} total players');
      for (final entry in tablePlayers.entries) {
        debugPrint('  Table ${entry.key}: ${entry.value.length} players');
      }
    } catch (e) {
      debugPrint('Error syncing players: $e');
    }
  }

  void _openFullscreenMode() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PublicLeaderboardScreen(
          eventId: widget.event.id,
          eventName: widget.event.name,
          isPublic: widget.event.isPublic,
          accessCode: widget.event.accessCode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen),
            tooltip: AppLocalizations.of(context).eventDashboardTvMode,
            onPressed: _openFullscreenMode,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _syncPlayersFromTables,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? ErrorStateCard(onRetry: _connectAndLoadRankings)
              : Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildRankingsTable()),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    // Use WebSocket data if available, otherwise use local fallback
    final rankings = _rankingsData?.rankings ?? _localRankings ?? [];
    final chipLeader = rankings.isNotEmpty ? rankings.first : null;
    final totalPlayers = _rankingsData?.totalPlayers ?? rankings.length;
    final totalChips = _rankingsData?.totalChips ?? _localTotalChips;
    final averageStack = totalPlayers > 0 ? totalChips ~/ totalPlayers : 0;

    // Check if tournament is on break (event active but no active sessions)
    final isOnBreak = widget.event.isOngoing &&
        !_hasActiveSessions &&
        (rankings.isNotEmpty);

    return Column(
      children: [
        // "On Break" banner
        if (isOnBreak)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            color: Colors.orange.shade700,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pause_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context).eventDashboardTournamentOnBreak,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Connection status
                  Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isConnected
                      ? Colors.green.withOpacity(0.1)
                      : (_localRankings?.isNotEmpty ?? false)
                          ? Colors.orange.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isConnected
                          ? Icons.wifi
                          : (_localRankings?.isNotEmpty ?? false)
                              ? Icons.sync
                              : Icons.wifi_off,
                      size: 14,
                      color: _isConnected
                          ? Colors.green
                          : (_localRankings?.isNotEmpty ?? false)
                              ? Colors.orange
                              : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isConnected
                          ? AppLocalizations.of(context).eventDashboardLiveLabel
                          : (_localRankings?.isNotEmpty ?? false)
                              ? AppLocalizations.of(context).eventDashboardLocalLabel
                              : AppLocalizations.of(context).eventDashboardDisconnectedLabel,
                      style: TextStyle(
                        color: _isConnected
                            ? Colors.green
                            : (_localRankings?.isNotEmpty ?? false)
                                ? Colors.orange
                                : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Event status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.event.status.displayName,
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                AppLocalizations.of(context).eventDashboardPlayersLabel,
                '$totalPlayers',
                Icons.people,
              ),
              _buildStatItem(
                AppLocalizations.of(context).eventDashboardTablesLabel,
                '${widget.tables.length}',
                Icons.table_restaurant,
              ),
              _buildStatItem(
                AppLocalizations.of(context).eventDashboardTotalChipsLabel,
                _numberFormat.format(totalChips),
                Icons.monetization_on,
              ),
              _buildStatItem(
                AppLocalizations.of(context).eventDashboardAvgStackLabel,
                _numberFormat.format(averageStack),
                Icons.equalizer,
              ),
            ],
          ),
          if (chipLeader != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.shade700,
                    Colors.amber.shade500,
                  ],
                ),
                borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).eventDashboardChipLeaderLabel,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          chipLeader.playerName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _numberFormat.format(chipLeader.currentStack),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildRankingsTable() {
    // Use WebSocket data if available, otherwise use local fallback
    final rankings = _rankingsData?.rankings ?? _localRankings ?? [];

    if (rankings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.leaderboard,
              size: 64,
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).eventDashboardNoRankingsYet,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).eventDashboardRankingsWillAppear,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rankings.length,
      itemBuilder: (context, index) {
        final ranking = rankings[index];
        // Use key with playerId + status to force rebuild when status changes
        return KeyedSubtree(
          key: ValueKey('${ranking.playerId}_${ranking.status.name}'),
          child: _buildRankingRow(ranking, index),
        );
      },
    );
  }

  /// Get ordinal suffix for a number (1st, 2nd, 3rd, 4th, etc.)
  String _getOrdinal(int number) {
    if (number >= 11 && number <= 13) {
      return '${number}th';
    }
    switch (number % 10) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
  }

  Widget _buildRankingRow(EventRanking ranking, int index) {
    final isBusted = ranking.status == PlayerRankingStatus.busted;
    final isOnBreak = ranking.status == PlayerRankingStatus.onBreak;
    final isTopThree = ranking.rank <= 3 && !isBusted;

    // Rank badge color - gray for busted, normal colors for others
    final rankColor = isBusted
        ? Colors.grey.shade600
        : switch (ranking.rank) {
            1 => Colors.amber,
            2 => Colors.grey.shade400,
            3 => Colors.orange.shade700,
            _ => null,
          };

    final stackChange = ranking.stackChange;
    final rankChange = ranking.rankChange;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isBusted
            ? Colors.grey.shade800.withOpacity(0.3)
            : isOnBreak
                ? Colors.orange.withOpacity(0.1)
                : isTopThree
                    ? rankColor?.withOpacity(0.1)
                    : null,
        borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
        border: isBusted
            ? Border.all(color: Colors.grey.shade600.withOpacity(0.3))
            : isTopThree
                ? Border.all(color: rankColor!.withOpacity(0.3))
                : null,
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: rankColor ?? Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: isBusted
              ? Builder(builder: (context) {
                  // Use ranking.finishPosition or fallback to tracked position
                  final finishPos = ranking.finishPosition ??
                      _bustedPlayerPositions[ranking.playerId];
                  return finishPos != null
                      ? Text(
                          '$finishPos',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        )
                      : const Icon(Icons.close, color: Colors.white, size: 20);
                })
              : Text(
                  '${ranking.rank}',
                  style: TextStyle(
                    color: rankColor != null ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                ranking.playerName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  decoration: isBusted ? TextDecoration.lineThrough : null,
                  color: isBusted ? Colors.grey : null,
                ),
              ),
            ),
            // Status labels
            if (isBusted)
              Builder(builder: (context) {
                // Use ranking.finishPosition or fallback to tracked position
                final finishPos = ranking.finishPosition ??
                    _bustedPlayerPositions[ranking.playerId];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    finishPos != null
                        ? _getOrdinal(finishPos)
                        : 'BUSTED',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }),
            if (isOnBreak)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange.shade700),
                ),
                child: Text(
                  AppLocalizations.of(context).eventDashboardOnBreakBadge,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (rankChange != null && rankChange != 0 && !isBusted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: rankChange > 0
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      rankChange > 0
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 12,
                      color: rankChange > 0 ? Colors.green : Colors.red,
                    ),
                    Text(
                      '${rankChange.abs()}',
                      style: TextStyle(
                        fontSize: 10,
                        color: rankChange > 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        subtitle: isBusted
            ? null  // Don't show table/seat for busted players
            : Text(
                '${ranking.tableName ?? 'Table'} - Seat ${ranking.seatNumber}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _numberFormat.format(ranking.currentStack),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ranking.isEliminated ? Colors.grey : null,
              ),
            ),
            if (stackChange != null && stackChange != 0)
              Text(
                '${stackChange > 0 ? '+' : ''}${_numberFormat.format(stackChange)}',
                style: TextStyle(
                  fontSize: 12,
                  color: stackChange > 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
