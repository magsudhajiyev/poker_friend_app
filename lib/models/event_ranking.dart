/// Represents a player's ranking in a club event
class EventRanking {
  final String eventId;
  final String playerId;
  final String playerName;
  final int currentStack;
  final int startingStack;
  final int rank;
  final String tableId;
  final String? tableName;
  final int seatNumber;
  final DateTime lastUpdated;
  final int? previousRank; // For showing rank changes
  final int? previousStack; // For showing stack changes

  EventRanking({
    required this.eventId,
    required this.playerId,
    required this.playerName,
    required this.currentStack,
    required this.startingStack,
    required this.rank,
    required this.tableId,
    this.tableName,
    required this.seatNumber,
    required this.lastUpdated,
    this.previousRank,
    this.previousStack,
  });

  /// Calculate profit/loss from starting stack
  int get profitLoss => currentStack - startingStack;

  /// Calculate profit/loss percentage
  double get profitLossPercent {
    if (startingStack == 0) return 0;
    return (profitLoss / startingStack) * 100;
  }

  /// Check if player is eliminated (0 chips)
  bool get isEliminated => currentStack <= 0;

  /// Get rank change from previous update
  int? get rankChange {
    if (previousRank == null) return null;
    return previousRank! - rank; // Positive = moved up, Negative = moved down
  }

  /// Get stack change from previous update
  int? get stackChange {
    if (previousStack == null) return null;
    return currentStack - previousStack!;
  }

  /// Factory constructor from map / API response
  factory EventRanking.fromMap(Map<String, dynamic> map) {
    return EventRanking(
      eventId: map['eventId'] ?? map['event_id'] ?? '',
      playerId: map['playerId'] ?? map['player_id'] ?? '',
      playerName: map['playerName'] ?? map['player_name'] ?? 'Unknown',
      currentStack: (map['currentStack'] ?? map['current_stack'] ?? 0).toInt(),
      startingStack: (map['startingStack'] ?? map['starting_stack'] ?? 0).toInt(),
      rank: (map['rank'] ?? 0).toInt(),
      tableId: map['tableId'] ?? map['table_id'] ?? '',
      tableName: map['tableName'] ?? map['table_name'],
      seatNumber: (map['seatNumber'] ?? map['seat_number'] ?? 0).toInt(),
      lastUpdated: DateTime.tryParse(
              map['lastUpdated'] ?? map['last_updated'] ?? '') ??
          DateTime.now(),
      previousRank: map['previousRank'] ?? map['previous_rank'],
      previousStack: map['previousStack'] ?? map['previous_stack'],
    );
  }

  /// Convert to map
  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'playerId': playerId,
      'playerName': playerName,
      'currentStack': currentStack,
      'startingStack': startingStack,
      'rank': rank,
      'tableId': tableId,
      'tableName': tableName,
      'seatNumber': seatNumber,
      'lastUpdated': lastUpdated.toIso8601String(),
      'previousRank': previousRank,
      'previousStack': previousStack,
    };
  }

  /// Create a copy with updated values
  EventRanking copyWith({
    int? currentStack,
    int? rank,
    DateTime? lastUpdated,
    int? previousRank,
    int? previousStack,
  }) {
    return EventRanking(
      eventId: eventId,
      playerId: playerId,
      playerName: playerName,
      currentStack: currentStack ?? this.currentStack,
      startingStack: startingStack,
      rank: rank ?? this.rank,
      tableId: tableId,
      tableName: tableName,
      seatNumber: seatNumber,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      previousRank: previousRank ?? this.previousRank,
      previousStack: previousStack ?? this.previousStack,
    );
  }
}

/// Container for event rankings with metadata
class EventRankingsData {
  final String eventId;
  final String eventName;
  final List<EventRanking> rankings;
  final int totalPlayers;
  final int totalChips;
  final DateTime lastUpdated;

  EventRankingsData({
    required this.eventId,
    required this.eventName,
    required this.rankings,
    required this.totalPlayers,
    required this.totalChips,
    required this.lastUpdated,
  });

  /// Get chip leader
  EventRanking? get chipLeader => rankings.isNotEmpty ? rankings.first : null;

  /// Get average stack
  int get averageStack => totalPlayers > 0 ? totalChips ~/ totalPlayers : 0;

  factory EventRankingsData.fromMap(Map<String, dynamic> map) {
    final rankingsList = (map['rankings'] as List<dynamic>? ?? [])
        .map((r) => EventRanking.fromMap(r as Map<String, dynamic>))
        .toList();

    return EventRankingsData(
      eventId: map['eventId'] ?? map['event_id'] ?? '',
      eventName: map['eventName'] ?? map['event_name'] ?? '',
      rankings: rankingsList,
      totalPlayers: (map['totalPlayers'] ?? map['total_players'] ?? rankingsList.length).toInt(),
      totalChips: (map['totalChips'] ?? map['total_chips'] ?? 0).toInt(),
      lastUpdated: DateTime.tryParse(
              map['lastUpdated'] ?? map['last_updated'] ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'eventName': eventName,
      'rankings': rankings.map((r) => r.toMap()).toList(),
      'totalPlayers': totalPlayers,
      'totalChips': totalChips,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}
