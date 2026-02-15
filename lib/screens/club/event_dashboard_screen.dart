import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/club.dart';
import '../../models/club_event.dart';
import '../../models/event_ranking.dart';
import '../../models/poker_table.dart';
import '../../services/event_service.dart';
import '../../services/websocket_service.dart';
import '../../services/dealer_service.dart';
import '../../services/seat_service.dart';
import '../../config/app_config.dart';
import '../public/public_leaderboard_screen.dart';

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
  bool _isConnected = false;
  StreamSubscription? _rankingSubscription;
  Timer? _refreshTimer;
  final _numberFormat = NumberFormat('#,###');

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
    setState(() => _isLoading = true);

    // Connect to WebSocket if not already connected
    final wsService = WebSocketService.instance;
    if (!wsService.isConnected) {
      wsService.connect(AppConfig.serverUrl);
      await Future.delayed(const Duration(seconds: 1));
    }

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

      // Initial rankings from join response
      if (joinResult['rankings'] != null) {
        setState(() {
          _rankingsData = EventRankingsData.fromMap(
            joinResult['rankings'] as Map<String, dynamic>,
          );
        });
      }
    }

    // Subscribe to ranking updates
    _rankingSubscription = wsService.onRankingUpdate.listen((data) {
      setState(() {
        _rankingsData = EventRankingsData.fromMap(data);
      });
    });

    // Sync players from tables
    await _syncPlayersFromTables();

    // Start periodic refresh timer
    _startRefreshTimer();

    setState(() => _isLoading = false);
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

      for (final table in widget.tables) {
        // First try to get players from DealerSession
        final session = await DealerService.getActiveSessionForTable(
          clubId: widget.club.id,
          tableId: table.id,
        );

        if (session != null && session.activePlayers.isNotEmpty) {
          final players = session.activePlayers.map((p) => {
                // Use seat-based ID for consistency with dealer stack updates
                'player_id': 'seat_${table.id}_${p.seatNumber}',
                'player_name': p.displayName,
                'current_stack': p.stack.toInt(),
                'starting_stack': p.stack.toInt(),
                'seat_number': p.seatNumber,
              }).toList();

          tablePlayers[table.id] = players;
        } else {
          // Fallback: Get players from seat assignments
          final seatAssignments = await SeatService.getTableSeats(
            clubId: widget.club.id,
            tableId: table.id,
          );

          final players = seatAssignments.entries
              .where((e) => e.value.isOccupied)
              .map((e) => {
                    // Use seat-based ID for consistency with dealer stack updates
                    'player_id': 'seat_${table.id}_${e.key}',
                    'player_name': e.value.playerName ?? 'Player ${e.key}',
                    'current_stack': (e.value.chipStack ?? 0).toInt(),
                    'starting_stack': (e.value.chipStack ?? 0).toInt(),
                    'seat_number': e.key,
                  })
              .toList();

          if (players.isNotEmpty) {
            tablePlayers[table.id] = players;
          }
        }
      }

      // Always sync, even if empty - this ensures the event is created on backend
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

      // Log for debugging
      debugPrint('Synced ${tablePlayers.length} tables with players');
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
            tooltip: 'TV Display Mode',
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
          : Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildRankingsTable()),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    final rankings = _rankingsData?.rankings ?? [];
    final chipLeader = rankings.isNotEmpty ? rankings.first : null;

    return Container(
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
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isConnected ? Icons.wifi : Icons.wifi_off,
                      size: 14,
                      color: _isConnected ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isConnected ? 'Live' : 'Disconnected',
                      style: TextStyle(
                        color: _isConnected ? Colors.green : Colors.red,
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
                'Players',
                '${_rankingsData?.totalPlayers ?? 0}',
                Icons.people,
              ),
              _buildStatItem(
                'Tables',
                '${widget.tables.length}',
                Icons.table_restaurant,
              ),
              _buildStatItem(
                'Total Chips',
                _numberFormat.format(_rankingsData?.totalChips ?? 0),
                Icons.monetization_on,
              ),
              _buildStatItem(
                'Avg Stack',
                _numberFormat.format(_rankingsData?.averageStack ?? 0),
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
                borderRadius: BorderRadius.circular(8),
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
                        const Text(
                          'Chip Leader',
                          style: TextStyle(
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
    final rankings = _rankingsData?.rankings ?? [];

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
              'No Rankings Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Rankings will appear as players join tables',
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
        return _buildRankingRow(ranking, index);
      },
    );
  }

  Widget _buildRankingRow(EventRanking ranking, int index) {
    final isTopThree = ranking.rank <= 3;
    final rankColor = switch (ranking.rank) {
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
        color: ranking.isEliminated
            ? Colors.grey.shade200.withOpacity(0.5)
            : isTopThree
                ? rankColor?.withOpacity(0.1)
                : null,
        borderRadius: BorderRadius.circular(8),
        border: isTopThree
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
          child: Text(
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
                  decoration: ranking.isEliminated
                      ? TextDecoration.lineThrough
                      : null,
                  color: ranking.isEliminated ? Colors.grey : null,
                ),
              ),
            ),
            if (rankChange != null && rankChange != 0)
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
        subtitle: Text(
          ranking.tableName ?? 'Table ${ranking.seatNumber}',
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
