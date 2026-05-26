import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/event_ranking.dart';
import '../../services/event_service.dart';
import '../../services/websocket_service.dart';
import '../../config/app_config.dart';
import '../../l10n/app_localizations.dart';

/// Full-screen leaderboard for TV display mode
/// Large fonts, high contrast, auto-updates
class PublicLeaderboardScreen extends StatefulWidget {
  final String eventId;
  final String eventName;
  final bool isPublic;
  final String? accessCode;

  const PublicLeaderboardScreen({
    Key? key,
    required this.eventId,
    required this.eventName,
    required this.isPublic,
    this.accessCode,
  }) : super(key: key);

  @override
  State<PublicLeaderboardScreen> createState() =>
      _PublicLeaderboardScreenState();
}

class _PublicLeaderboardScreenState extends State<PublicLeaderboardScreen> {
  EventRankingsData? _rankingsData;
  bool _isLoading = true;
  bool _isConnected = false;
  StreamSubscription? _rankingSubscription;
  final _numberFormat = NumberFormat('#,###');
  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;
  bool _autoScrollEnabled = true;

  @override
  void initState() {
    super.initState();
    // Force landscape orientation for TV display
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Hide system UI for full immersion
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _connectAndLoadRankings();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _rankingSubscription?.cancel();
    WebSocketService.instance.leaveEvent(widget.eventId);
    _scrollController.dispose();

    // Restore orientation and system UI
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_autoScrollEnabled || !_scrollController.hasClients) return;

      final rankings = _rankingsData?.rankings ?? [];
      if (rankings.length <= 10) return; // Don't scroll if all fit on screen

      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;

      if (currentScroll >= maxScroll - 10) {
        // At bottom, scroll back to top
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      } else {
        // Scroll down one page
        _scrollController.animateTo(
          currentScroll + 300,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _connectAndLoadRankings() async {
    setState(() => _isLoading = true);

    // Connect to WebSocket
    final wsService = WebSocketService.instance;
    if (!wsService.isConnected) {
      wsService.connect(AppConfig.serverUrl);
      await Future.delayed(const Duration(seconds: 1));
    }

    // Join event room
    final joinResult = await wsService.joinEvent(widget.eventId);
    if (joinResult != null && joinResult['success'] == true) {
      setState(() => _isConnected = true);

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

    // Fallback: Load via HTTP if WebSocket fails
    if (_rankingsData == null) {
      final rankings = widget.isPublic
          ? await EventService.getPublicRankings(
              widget.eventId,
              accessCode: widget.accessCode,
            )
          : await EventService.getRankings(widget.eventId);

      if (rankings != null) {
        setState(() {
          _rankingsData = rankings;
        });
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          // Toggle auto-scroll on tap
          setState(() => _autoScrollEnabled = !_autoScrollEnabled);
        },
        onDoubleTap: () {
          // Exit fullscreen on double tap
          Navigator.pop(context);
        },
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : Column(
                children: [
                  _buildHeader(),
                  Expanded(child: _buildRankingsTable()),
                  _buildFooter(),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade900,
            Colors.blue.shade700,
          ],
        ),
      ),
      child: Row(
        children: [
          // Event name
          Expanded(
            child: Text(
              widget.eventName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Stats
          _buildHeaderStat(
            AppLocalizations.of(context).leaderboardPlayers,
            '${_rankingsData?.totalPlayers ?? 0}',
          ),
          const SizedBox(width: 32),
          _buildHeaderStat(
            AppLocalizations.of(context).leaderboardTotalChips,
            _numberFormat.format(_rankingsData?.totalChips ?? 0),
          ),
          const SizedBox(width: 32),
          // Live indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isConnected ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: _isConnected
                        ? [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isConnected ? 'LIVE' : 'OFFLINE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildRankingsTable() {
    final rankings = _rankingsData?.rankings ?? [];

    if (rankings.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context).leaderboardWaiting,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 24,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      itemCount: rankings.length,
      itemBuilder: (context, index) {
        final ranking = rankings[index];
        return _buildRankingRow(ranking);
      },
    );
  }

  Widget _buildRankingRow(EventRanking ranking) {
    final isTopThree = ranking.rank <= 3;
    final rankColor = switch (ranking.rank) {
      1 => Colors.amber,
      2 => Colors.grey.shade400,
      3 => Colors.orange.shade700,
      _ => Colors.grey.shade800,
    };

    final stackChange = ranking.stackChange;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: isTopThree
            ? rankColor.withOpacity(0.2)
            : Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
        border: isTopThree
            ? Border.all(color: rankColor.withOpacity(0.5), width: 2)
            : null,
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: rankColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${ranking.rank}',
              style: TextStyle(
                color: isTopThree ? Colors.black87 : Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 24),
          // Player name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ranking.playerName,
                  style: TextStyle(
                    color: ranking.isEliminated ? Colors.grey : Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    decoration: ranking.isEliminated
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                Text(
                  ranking.tableName ?? 'Seat ${ranking.seatNumber}',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          // Chip count
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _numberFormat.format(ranking.currentStack),
                style: TextStyle(
                  color: ranking.isEliminated ? Colors.grey : Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (stackChange != null && stackChange != 0)
                Text(
                  '${stackChange > 0 ? '+' : ''}${_numberFormat.format(stackChange)}',
                  style: TextStyle(
                    color: stackChange > 0 ? Colors.green : Colors.red,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        border: Border(
          top: BorderSide(color: Colors.grey.shade800),
        ),
      ),
      child: Row(
        children: [
          // Chip leader highlight
          if (_rankingsData != null && _rankingsData!.rankings.isNotEmpty) ...[
            const Icon(
              Icons.emoji_events,
              color: Colors.amber,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context).leaderboardChipLeader(_rankingsData!.rankings.first.playerName),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${_numberFormat.format(_rankingsData!.rankings.first.currentStack)})',
              style: TextStyle(
                color: Colors.amber.shade400,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          const Spacer(),
          // Auto-scroll indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _autoScrollEnabled
                  ? Colors.green.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _autoScrollEnabled ? Icons.play_arrow : Icons.pause,
                  color: _autoScrollEnabled ? Colors.green : Colors.grey,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _autoScrollEnabled ? 'Auto-scroll' : 'Paused',
                  style: TextStyle(
                    color: _autoScrollEnabled ? Colors.green : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Time
          Text(
            DateFormat('HH:mm:ss').format(DateTime.now()),
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
