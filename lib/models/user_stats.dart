/// Model for storing user's own poker statistics
class UserStats {
  final String userId;
  final int handsPlayed;
  final int totalHands; // Total hands dealt, including folded preflop
  final int vpipCount;
  final int pfrCount;
  final int threeBetCount;
  final int wonHands;
  final int totalSessions;
  final int totalPlayTimeMinutes;
  final DateTime lastUpdated;

  // Position-specific counters
  final Map<String, int> positionHandsPlayed;
  final Map<String, int> positionVpipCount;
  final Map<String, int> positionPfrCount;
  final Map<String, int> positionThreeBetCount;

  UserStats({
    required this.userId,
    this.handsPlayed = 0,
    this.totalHands = 0,
    this.vpipCount = 0,
    this.pfrCount = 0,
    this.threeBetCount = 0,
    this.wonHands = 0,
    this.totalSessions = 0,
    this.totalPlayTimeMinutes = 0,
    DateTime? lastUpdated,
    Map<String, int>? positionHandsPlayed,
    Map<String, int>? positionVpipCount,
    Map<String, int>? positionPfrCount,
    Map<String, int>? positionThreeBetCount,
  }) : lastUpdated = lastUpdated ?? DateTime.now(),
       positionHandsPlayed = positionHandsPlayed ?? {},
       positionVpipCount = positionVpipCount ?? {},
       positionPfrCount = positionPfrCount ?? {},
       positionThreeBetCount = positionThreeBetCount ?? {};

  /// Calculate percentages from counters
  double get vpipPercentage => handsPlayed > 0 ? (vpipCount / handsPlayed * 100) : 0.0;
  double get pfrPercentage => handsPlayed > 0 ? (pfrCount / handsPlayed * 100) : 0.0;
  double get threeBetPercentage => handsPlayed > 0 ? (threeBetCount / handsPlayed * 100) : 0.0;
  double get winRate => handsPlayed > 0 ? (wonHands / handsPlayed * 100) : 0.0;

  /// Calculate average session duration
  double get avgSessionMinutes => totalSessions > 0 ? (totalPlayTimeMinutes / totalSessions) : 0.0;

  /// Factory constructor from Firestore document
  factory UserStats.fromFirestore(Map<String, dynamic> data) {
    return UserStats(
      userId: data['userId'] ?? '',
      handsPlayed: data['handsPlayed'] ?? 0,
      totalHands: data['totalHands'] ?? 0,
      vpipCount: data['vpipCount'] ?? 0,
      pfrCount: data['pfrCount'] ?? 0,
      threeBetCount: data['threeBetCount'] ?? 0,
      wonHands: data['wonHands'] ?? 0,
      totalSessions: data['totalSessions'] ?? 0,
      totalPlayTimeMinutes: data['totalPlayTimeMinutes'] ?? 0,
      lastUpdated: data['lastUpdated']?.toDate() ?? DateTime.now(),
      positionHandsPlayed: Map<String, int>.from(data['positionHandsPlayed'] ?? {}),
      positionVpipCount: Map<String, int>.from(data['positionVpipCount'] ?? {}),
      positionPfrCount: Map<String, int>.from(data['positionPfrCount'] ?? {}),
      positionThreeBetCount: Map<String, int>.from(data['positionThreeBetCount'] ?? {}),
    );
  }

  /// Convert to map for Firestore storage
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'handsPlayed': handsPlayed,
      'totalHands': totalHands,
      'vpipCount': vpipCount,
      'pfrCount': pfrCount,
      'threeBetCount': threeBetCount,
      'wonHands': wonHands,
      'totalSessions': totalSessions,
      'totalPlayTimeMinutes': totalPlayTimeMinutes,
      'lastUpdated': lastUpdated,
      'positionHandsPlayed': positionHandsPlayed,
      'positionVpipCount': positionVpipCount,
      'positionPfrCount': positionPfrCount,
      'positionThreeBetCount': positionThreeBetCount,
    };
  }

  /// Get position-specific stats
  PositionStats getPositionStats(String position) {
    final played = positionHandsPlayed[position] ?? 0;
    final vpip = positionVpipCount[position] ?? 0;
    final pfr = positionPfrCount[position] ?? 0;
    final threeBet = positionThreeBetCount[position] ?? 0;

    return PositionStats(
      handsPlayed: played,
      vpip: played > 0 ? (vpip / played * 100) : 0,
      pfr: played > 0 ? (pfr / played * 100) : 0,
      threeBet: played > 0 ? (threeBet / played * 100) : 0,
    );
  }

  /// Get all positions with stats
  Map<String, PositionStats> getAllPositionStats() {
    final positions = <String, PositionStats>{};

    for (final position in positionHandsPlayed.keys) {
      positions[position] = getPositionStats(position);
    }

    return positions;
  }
}

class PositionStats {
  final int handsPlayed;
  final double vpip;
  final double pfr;
  final double threeBet;

  PositionStats({
    required this.handsPlayed,
    required this.vpip,
    required this.pfr,
    required this.threeBet,
  });
}