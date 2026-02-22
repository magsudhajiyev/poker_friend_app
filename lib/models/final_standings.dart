import 'package:cloud_firestore/cloud_firestore.dart';
import 'event_ranking.dart';

/// Represents a player's final standing in a completed event
class FinalPlayerStanding {
  final String playerId;
  final String playerName;
  final int finalRank;
  final int finalStack;
  final int startingStack;
  final int profitLoss;
  final PlayerRankingStatus finalStatus;
  final DateTime? bustTime;
  final String? tableName;

  FinalPlayerStanding({
    required this.playerId,
    required this.playerName,
    required this.finalRank,
    required this.finalStack,
    required this.startingStack,
    required this.profitLoss,
    required this.finalStatus,
    this.bustTime,
    this.tableName,
  });

  factory FinalPlayerStanding.fromMap(Map<String, dynamic> map) {
    // Parse status from string
    PlayerRankingStatus status = PlayerRankingStatus.active;
    final statusStr = map['finalStatus'] ?? map['final_status'] as String?;
    if (statusStr != null) {
      switch (statusStr) {
        case 'busted':
          status = PlayerRankingStatus.busted;
          break;
        case 'onBreak':
        case 'on_break':
          status = PlayerRankingStatus.onBreak;
          break;
        default:
          status = PlayerRankingStatus.active;
      }
    }

    return FinalPlayerStanding(
      playerId: map['playerId'] ?? map['player_id'] ?? '',
      playerName: map['playerName'] ?? map['player_name'] ?? 'Unknown',
      finalRank: (map['finalRank'] ?? map['final_rank'] ?? 0).toInt(),
      finalStack: (map['finalStack'] ?? map['final_stack'] ?? 0).toInt(),
      startingStack: (map['startingStack'] ?? map['starting_stack'] ?? 0).toInt(),
      profitLoss: (map['profitLoss'] ?? map['profit_loss'] ?? 0).toInt(),
      finalStatus: status,
      bustTime: _parseDateTime(map['bustTime'] ?? map['bust_time']),
      tableName: map['tableName'] ?? map['table_name'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'finalRank': finalRank,
      'finalStack': finalStack,
      'startingStack': startingStack,
      'profitLoss': profitLoss,
      'finalStatus': finalStatus.name,
      'bustTime': bustTime?.toIso8601String(),
      'tableName': tableName,
    };
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Create from EventRanking (for snapshot at event completion)
  factory FinalPlayerStanding.fromEventRanking(EventRanking ranking, int finalRank) {
    return FinalPlayerStanding(
      playerId: ranking.playerId,
      playerName: ranking.playerName,
      finalRank: finalRank,
      finalStack: ranking.currentStack,
      startingStack: ranking.startingStack,
      profitLoss: ranking.profitLoss,
      finalStatus: ranking.status,
      tableName: ranking.tableName,
    );
  }
}

/// Container for final standings of a completed event
class FinalStandings {
  final String eventId;
  final String eventName;
  final List<FinalPlayerStanding> standings;
  final int totalPlayers;
  final int totalChips;
  final DateTime completedAt;
  final Map<String, dynamic>? eventMetadata;

  FinalStandings({
    required this.eventId,
    required this.eventName,
    required this.standings,
    required this.totalPlayers,
    required this.totalChips,
    required this.completedAt,
    this.eventMetadata,
  });

  /// Get the winner (1st place)
  FinalPlayerStanding? get winner =>
      standings.isNotEmpty ? standings.first : null;

  /// Get top 3 finishers
  List<FinalPlayerStanding> get podium =>
      standings.take(3).toList();

  /// Get busted players count
  int get bustedCount =>
      standings.where((s) => s.finalStatus == PlayerRankingStatus.busted).length;

  factory FinalStandings.fromMap(Map<String, dynamic> map) {
    final standingsList = (map['standings'] as List<dynamic>? ?? [])
        .map((s) => FinalPlayerStanding.fromMap(s as Map<String, dynamic>))
        .toList();

    return FinalStandings(
      eventId: map['eventId'] ?? map['event_id'] ?? '',
      eventName: map['eventName'] ?? map['event_name'] ?? '',
      standings: standingsList,
      totalPlayers: (map['totalPlayers'] ?? map['total_players'] ?? standingsList.length).toInt(),
      totalChips: (map['totalChips'] ?? map['total_chips'] ?? 0).toInt(),
      completedAt: _parseDateTime(map['completedAt'] ?? map['completed_at']) ?? DateTime.now(),
      eventMetadata: map['eventMetadata'] ?? map['event_metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'eventName': eventName,
      'standings': standings.map((s) => s.toMap()).toList(),
      'totalPlayers': totalPlayers,
      'totalChips': totalChips,
      'completedAt': completedAt.toIso8601String(),
      'eventMetadata': eventMetadata,
    };
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Create from current rankings at event completion
  factory FinalStandings.fromRankings({
    required String eventId,
    required String eventName,
    required List<EventRanking> rankings,
    Map<String, dynamic>? metadata,
  }) {
    // Sort by stack descending (active players first, then busted in order)
    final sortedRankings = List<EventRanking>.from(rankings);
    sortedRankings.sort((a, b) {
      // Active players (non-zero stack) first, sorted by stack descending
      if (a.currentStack > 0 && b.currentStack > 0) {
        return b.currentStack.compareTo(a.currentStack);
      }
      // Active players before busted
      if (a.currentStack > 0) return -1;
      if (b.currentStack > 0) return 1;
      // Both busted - use their finish position or rank
      return (a.finishPosition ?? a.rank).compareTo(b.finishPosition ?? b.rank);
    });

    // Assign final ranks
    final standings = <FinalPlayerStanding>[];
    for (int i = 0; i < sortedRankings.length; i++) {
      standings.add(FinalPlayerStanding.fromEventRanking(sortedRankings[i], i + 1));
    }

    return FinalStandings(
      eventId: eventId,
      eventName: eventName,
      standings: standings,
      totalPlayers: rankings.length,
      totalChips: rankings.fold(0, (sum, r) => sum + r.currentStack),
      completedAt: DateTime.now(),
      eventMetadata: metadata,
    );
  }
}
