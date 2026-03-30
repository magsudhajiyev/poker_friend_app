import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../design_system/poker_friend_theme.dart';
import '../../models/club.dart';
import '../../models/club_event.dart';
import '../../models/final_standings.dart';
import '../../models/event_ranking.dart';
import '../../services/event_service.dart';

/// Screen to display final standings for a completed event
class FinalStandingsScreen extends StatefulWidget {
  final Club club;
  final ClubEvent event;

  const FinalStandingsScreen({
    Key? key,
    required this.club,
    required this.event,
  }) : super(key: key);

  @override
  State<FinalStandingsScreen> createState() => _FinalStandingsScreenState();
}

class _FinalStandingsScreenState extends State<FinalStandingsScreen> {
  FinalStandings? _standings;
  bool _isLoading = true;
  String? _error;
  final _numberFormat = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _loadFinalStandings();
  }

  Future<void> _loadFinalStandings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final standings = await EventService.getFinalStandings(
        widget.club.id,
        widget.event.id,
      );

      setState(() {
        _standings = standings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load standings: $e';
        _isLoading = false;
      });
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
            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No standings available',
                        style: TextStyle(
                          color: PokerFriendColors.dark9,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This event may not have recorded standings',
                        style: TextStyle(
                          color: PokerFriendColors.dark7,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_standings == null || _standings!.standings.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.emoji_events_outlined,
                        size: 48,
                        color: PokerFriendColors.dark7,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No standings recorded',
                        style: TextStyle(
                          color: PokerFriendColors.dark9,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              _buildStatsRow(),
              Expanded(child: _buildStandingsList()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: PokerFriendColors.dark2,
        border: Border(
          bottom: BorderSide(color: PokerFriendColors.dark4),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: PokerFriendColors.dark3,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back,
                color: PokerFriendColors.dark9,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Final Standings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: PokerFriendColors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.event.name,
                  style: TextStyle(
                    fontSize: 14,
                    color: PokerFriendColors.dark7,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Trophy icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.emoji_events,
              color: Colors.amber,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final standings = _standings!;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      color: PokerFriendColors.dark2,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Players',
            '${standings.totalPlayers}',
            Icons.people,
          ),
          _buildStatItem(
            'Completed',
            DateFormat('MMM d, yyyy').format(standings.completedAt),
            Icons.calendar_today,
          ),
          _buildStatItem(
            'Total Chips',
            _numberFormat.format(standings.totalChips),
            Icons.casino,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: PokerFriendColors.purple),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: PokerFriendColors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: PokerFriendColors.dark7,
          ),
        ),
      ],
    );
  }

  Widget _buildStandingsList() {
    final standings = _standings!.standings;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: standings.length,
      itemBuilder: (context, index) {
        final standing = standings[index];
        return _buildStandingRow(standing, index);
      },
    );
  }

  Widget _buildStandingRow(FinalPlayerStanding standing, int index) {
    final isBusted = standing.finalStatus == PlayerRankingStatus.busted;
    final isTopThree = standing.finalRank <= 3;

    // Colors for top 3
    final rankColor = switch (standing.finalRank) {
      1 => Colors.amber,
      2 => Colors.grey.shade400,
      3 => Colors.orange.shade700,
      _ => isBusted ? Colors.grey.shade600 : null,
    };

    // Determine row background
    Color? backgroundColor;
    if (isBusted) {
      backgroundColor = Colors.grey.shade800.withOpacity(0.2);
    } else if (isTopThree) {
      backgroundColor = rankColor?.withOpacity(0.1);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? PokerFriendColors.dark2,
        borderRadius: BorderRadius.circular(12),
        border: isTopThree && !isBusted
            ? Border.all(color: rankColor!.withOpacity(0.5))
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: rankColor ?? PokerFriendColors.dark4,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: isTopThree && !isBusted
              ? Icon(
                  Icons.emoji_events,
                  color: Colors.white,
                  size: 22,
                )
              : Text(
                  '${standing.finalRank}',
                  style: TextStyle(
                    color: rankColor != null ? Colors.white : PokerFriendColors.dark9,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                standing.playerName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isBusted ? Colors.grey : PokerFriendColors.white,
                  decoration: isBusted ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (isBusted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'BUSTED',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: standing.tableName != null
            ? Text(
                standing.tableName!,
                style: TextStyle(
                  color: PokerFriendColors.dark7,
                  fontSize: 12,
                ),
              )
            : null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _numberFormat.format(standing.finalStack),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isBusted ? Colors.grey : PokerFriendColors.white,
              ),
            ),
            if (standing.profitLoss != 0)
              Text(
                '${standing.profitLoss > 0 ? '+' : ''}${_numberFormat.format(standing.profitLoss)}',
                style: TextStyle(
                  fontSize: 12,
                  color: standing.profitLoss > 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
