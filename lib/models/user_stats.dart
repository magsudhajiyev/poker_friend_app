/// Model for storing user's own poker statistics
/// Updated to support full 7-metric parity with opponent stats
class UserStats {
  final String userId;
  final int handsPlayed;
  final int totalHands; // Total hands dealt, including folded preflop
  final int walksCount; // Hands where everyone folded to BB (excluded from VPIP/PFR denominator)

  // VPIP and PFR counters
  final int vpipCount;
  final int pfrCount;

  // 3-Bet tracking
  final int threeBetCount;
  final int threeBetOpportunity; // Times faced a raise pre-flop

  // Fold to 3-Bet tracking
  final int fold3betCount;
  final int facing3BetCount; // Times faced a 3-bet after raising

  // C-Bet tracking
  final int cbetCount;
  final int cbetOpportunity; // Times was last aggressor pre and saw flop

  // Steal tracking
  final int stealCount;
  final int stealOpportunity; // Times in steal position (CO/BTN/SB) with unopened pot

  // Check/Raise tracking (flop only, when OOP)
  final int checkRaiseFlopCount;
  final int checkRaiseFlopOpportunity; // Times checked OOP and faced bet on flop

  // Blind Defend tracking
  final int blindDefendCount;          // Times player defended from blinds (called/raised vs raise)
  final int blindDefendOpportunity;    // Times player was in BB/SB and faced a raise

  final int wonHands;
  final int totalSessions;
  final int totalPlayTimeMinutes;

  // Position breakdowns (key: position name 'BTN', 'CO', 'MP', ...).
  // positionHandsPlayed counts hands DEALT at the position (denominator);
  // the others mirror their global counters per position.
  final Map<String, int> positionHandsPlayed;
  final Map<String, int> positionVpipCount;
  final Map<String, int> positionPfrCount;
  final Map<String, int> positionThreeBetCount;
  final DateTime lastUpdated;

  UserStats({
    required this.userId,
    this.handsPlayed = 0,
    this.totalHands = 0,
    this.walksCount = 0,
    this.vpipCount = 0,
    this.pfrCount = 0,
    this.threeBetCount = 0,
    this.threeBetOpportunity = 0,
    this.fold3betCount = 0,
    this.facing3BetCount = 0,
    this.cbetCount = 0,
    this.cbetOpportunity = 0,
    this.stealCount = 0,
    this.stealOpportunity = 0,
    this.checkRaiseFlopCount = 0,
    this.checkRaiseFlopOpportunity = 0,
    this.blindDefendCount = 0,
    this.blindDefendOpportunity = 0,
    this.wonHands = 0,
    this.totalSessions = 0,
    this.totalPlayTimeMinutes = 0,
    DateTime? lastUpdated,
    Map<String, int>? positionHandsPlayed,
    Map<String, int>? positionVpipCount,
    Map<String, int>? positionPfrCount,
    Map<String, int>? positionThreeBetCount,
  })  : positionHandsPlayed = positionHandsPlayed ?? const {},
        positionVpipCount = positionVpipCount ?? const {},
        positionPfrCount = positionPfrCount ?? const {},
        positionThreeBetCount = positionThreeBetCount ?? const {},
        lastUpdated = lastUpdated ?? DateTime.now();

  /// Eligible hands for VPIP/PFR calculation (excludes walks)
  int get eligibleHands => totalHands - walksCount;

  /// Calculate percentages from counters using opportunity-based denominators
  /// All percentages are guaranteed to be between 0 and 100

  /// VPIP percentage (Voluntarily Put $ In Pot)
  /// Denominator: totalHands - walks
  double get vpipPercentage => eligibleHands > 0
      ? (vpipCount / eligibleHands * 100).clamp(0.0, 100.0) : 0.0;

  /// PFR percentage (Pre-Flop Raise)
  /// Denominator: totalHands - walks
  double get pfrPercentage => eligibleHands > 0
      ? (pfrCount / eligibleHands * 100).clamp(0.0, 100.0) : 0.0;

  /// 3-Bet percentage
  /// Denominator: Opportunities to 3-bet (times faced a raise pre-flop)
  double get threeBetPercentage => threeBetOpportunity > 0
      ? (threeBetCount / threeBetOpportunity * 100).clamp(0.0, 100.0) : 0.0;

  /// Fold to 3-Bet percentage
  /// Denominator: Times faced a 3-bet after raising
  double get fold3betPercentage => facing3BetCount > 0
      ? (fold3betCount / facing3BetCount * 100).clamp(0.0, 100.0) : 0.0;

  /// C-Bet percentage (Continuation Bet on flop when last aggressor pre-flop)
  /// Denominator: Times was last aggressor pre-flop and saw flop
  double get cbetPercentage => cbetOpportunity > 0
      ? (cbetCount / cbetOpportunity * 100).clamp(0.0, 100.0) : 0.0;

  /// Steal percentage (Raise from CO/BTN/SB with unopened pot)
  /// Denominator: Times in steal position with unopened pot
  double get stealPercentage => stealOpportunity > 0
      ? (stealCount / stealOpportunity * 100).clamp(0.0, 100.0) : 0.0;

  /// Check/Raise percentage on flop (when OOP)
  /// Denominator: Times checked OOP then faced bet on flop
  double get checkRaiseFlopPercentage => checkRaiseFlopOpportunity > 0
      ? (checkRaiseFlopCount / checkRaiseFlopOpportunity * 100).clamp(0.0, 100.0) : 0.0;

  /// Blind Defend percentage (called/raised from BB/SB when facing a raise)
  /// Denominator: Times in BB/SB and faced a raise preflop
  double get blindDefendPercentage => blindDefendOpportunity > 0
      ? (blindDefendCount / blindDefendOpportunity * 100).clamp(0.0, 100.0) : 0.0;

  double get winRate => handsPlayed > 0 ? (wonHands / handsPlayed * 100).clamp(0.0, 100.0) : 0.0;

  /// Check if a stat has enough data to display (opportunity > 0)
  bool hasDataFor(String stat) {
    switch (stat) {
      case 'vpip':
      case 'pfr':
        return eligibleHands > 0;
      case 'threeBet':
        return threeBetOpportunity > 0;
      case 'fold3bet':
        return facing3BetCount > 0;
      case 'cbet':
        return cbetOpportunity > 0;
      case 'steal':
        return stealOpportunity > 0;
      case 'checkRaise':
        return checkRaiseFlopOpportunity > 0;
      case 'blindDefend':
        return blindDefendOpportunity > 0;
      default:
        return false;
    }
  }

  /// Calculate average session duration
  double get avgSessionMinutes => totalSessions > 0 ? (totalPlayTimeMinutes / totalSessions) : 0.0;

  /// Factory constructor from Firestore document
  static Map<String, int> _parsePositionMap(dynamic raw) {
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0));
    }
    return const {};
  }

  factory UserStats.fromFirestore(Map<String, dynamic> data) {
    return UserStats(
      userId: data['userId'] ?? '',
      handsPlayed: data['handsPlayed'] ?? 0,
      totalHands: data['totalHands'] ?? 0,
      walksCount: data['walksCount'] ?? 0,
      vpipCount: data['vpipCount'] ?? 0,
      pfrCount: data['pfrCount'] ?? 0,
      threeBetCount: data['threeBetCount'] ?? 0,
      threeBetOpportunity: data['threeBetOpportunity'] ?? 0,
      fold3betCount: data['fold3betCount'] ?? 0,
      facing3BetCount: data['facing3BetCount'] ?? 0,
      cbetCount: data['cbetCount'] ?? 0,
      cbetOpportunity: data['cbetOpportunity'] ?? 0,
      stealCount: data['stealCount'] ?? 0,
      stealOpportunity: data['stealOpportunity'] ?? 0,
      checkRaiseFlopCount: data['checkRaiseFlopCount'] ?? 0,
      checkRaiseFlopOpportunity: data['checkRaiseFlopOpportunity'] ?? 0,
      blindDefendCount: data['blindDefendCount'] ?? 0,
      blindDefendOpportunity: data['blindDefendOpportunity'] ?? 0,
      wonHands: data['wonHands'] ?? 0,
      totalSessions: data['totalSessions'] ?? 0,
      positionHandsPlayed: _parsePositionMap(data['positionHandsPlayed']),
      positionVpipCount: _parsePositionMap(data['positionVpipCount']),
      positionPfrCount: _parsePositionMap(data['positionPfrCount']),
      positionThreeBetCount: _parsePositionMap(data['positionThreeBetCount']),
      totalPlayTimeMinutes: data['totalPlayTimeMinutes'] ?? 0,
      lastUpdated: data['lastUpdated']?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to map for Firestore storage
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'handsPlayed': handsPlayed,
      'totalHands': totalHands,
      'walksCount': walksCount,
      'vpipCount': vpipCount,
      'pfrCount': pfrCount,
      'threeBetCount': threeBetCount,
      'threeBetOpportunity': threeBetOpportunity,
      'fold3betCount': fold3betCount,
      'facing3BetCount': facing3BetCount,
      'cbetCount': cbetCount,
      'cbetOpportunity': cbetOpportunity,
      'stealCount': stealCount,
      'stealOpportunity': stealOpportunity,
      'checkRaiseFlopCount': checkRaiseFlopCount,
      'checkRaiseFlopOpportunity': checkRaiseFlopOpportunity,
      'blindDefendCount': blindDefendCount,
      'blindDefendOpportunity': blindDefendOpportunity,
      'wonHands': wonHands,
      'totalSessions': totalSessions,
      'positionHandsPlayed': positionHandsPlayed,
      'positionVpipCount': positionVpipCount,
      'positionPfrCount': positionPfrCount,
      'positionThreeBetCount': positionThreeBetCount,
      'totalPlayTimeMinutes': totalPlayTimeMinutes,
      'lastUpdated': lastUpdated,
    };
  }

  /// Convert to stats map for UI display (matches OpponentStats.toLegacyStatsMap)
  Map<String, dynamic> toLegacyStatsMap() {
    return {
      'totalHands': totalHands,
      'totalSessions': totalSessions,
      'positionHandsPlayed': positionHandsPlayed,
      'positionVpipCount': positionVpipCount,
      'positionPfrCount': positionPfrCount,
      'positionThreeBetCount': positionThreeBetCount,
      // Core poker stats (proper opportunity-based percentages)
      'vpip': vpipPercentage,
      'pfr': pfrPercentage,
      'threeBet': threeBetPercentage,
      'fold3Bet': fold3betPercentage,
      'cbet': cbetPercentage,
      'steal': stealPercentage,
      'checkRaise': checkRaiseFlopPercentage,
      // Opportunity counts for N/A detection
      'threeBetOpportunity': threeBetOpportunity,
      'facing3BetCount': facing3BetCount,
      'cbetOpportunity': cbetOpportunity,
      'stealOpportunity': stealOpportunity,
      'checkRaiseFlopOpportunity': checkRaiseFlopOpportunity,
      'eligibleHands': eligibleHands,
    };
  }

}