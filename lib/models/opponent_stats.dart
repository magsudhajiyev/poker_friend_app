import 'package:cloud_firestore/cloud_firestore.dart';
import 'opponent.dart'; // For PlayerType enum

/// Optimized opponent statistics model using incremental counters
/// instead of recalculating from all hands every time
class OpponentStats {
  final String opponentId;
  final DateTime lastUpdated;

  // Basic counters
  final int handsPlayed;
  final int sessionsPlayed;
  final int walksCount;         // Hands where everyone folded to BB (excluded from VPIP/PFR denominator)

  // VPIP and PFR counters
  final int vpipCount;          // Voluntarily Put $ In Pot
  final int pfrCount;           // Pre-Flop Raise

  // 3-Bet tracking
  final int threeBetCount;       // Times player 3-bet
  final int threeBetOpportunity; // Times player could 3-bet (faced a raise)

  // Fold to 3-Bet tracking
  final int fold3betCount;       // Times player folded to 3-bet
  final int facing3BetCount;     // Times player faced a 3-bet after raising

  // C-Bet tracking
  final int cbetCount;           // Times player c-bet on flop
  final int cbetOpportunity;     // Times player was last aggressor pre and saw flop

  // Steal tracking
  final int stealCount;          // Times player raised from steal position
  final int stealOpportunity;    // Times in steal position (CO/BTN/SB) with unopened pot

  // Check/Raise tracking (flop only, when OOP)
  final int checkRaiseFlopCount;      // Times player check-raised on flop
  final int checkRaiseFlopOpportunity; // Times player checked OOP and faced bet on flop

  // Legacy counters (kept for backward compatibility, but not used in new stats)
  final int aggressionActions;
  final int passiveActions;
  final int foldCount;
  final int checkCount;
  final int callCount;
  final int betCount;
  final int raiseCount;

  OpponentStats({
    required this.opponentId,
    DateTime? lastUpdated,
    this.handsPlayed = 0,
    this.sessionsPlayed = 0,
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
    // Legacy counters (backward compatibility)
    this.aggressionActions = 0,
    this.passiveActions = 0,
    this.foldCount = 0,
    this.checkCount = 0,
    this.callCount = 0,
    this.betCount = 0,
    this.raiseCount = 0,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  /// Factory constructor from Firestore document
  factory OpponentStats.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OpponentStats(
      opponentId: doc.id,
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      handsPlayed: data['handsPlayed'] ?? 0,
      sessionsPlayed: data['sessionsPlayed'] ?? 0,
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
      // Legacy counters
      aggressionActions: data['aggressionActions'] ?? 0,
      passiveActions: data['passiveActions'] ?? 0,
      foldCount: data['foldCount'] ?? 0,
      checkCount: data['checkCount'] ?? 0,
      callCount: data['callCount'] ?? 0,
      betCount: data['betCount'] ?? 0,
      raiseCount: data['raiseCount'] ?? 0,
    );
  }

  /// Factory constructor from local storage map
  factory OpponentStats.fromMap(Map<String, dynamic> map) {
    return OpponentStats(
      opponentId: map['opponentId'] ?? '',
      lastUpdated: DateTime.tryParse(map['lastUpdated'] ?? '') ?? DateTime.now(),
      handsPlayed: map['handsPlayed'] ?? 0,
      sessionsPlayed: map['sessionsPlayed'] ?? 0,
      walksCount: map['walksCount'] ?? 0,
      vpipCount: map['vpipCount'] ?? 0,
      pfrCount: map['pfrCount'] ?? 0,
      threeBetCount: map['threeBetCount'] ?? 0,
      threeBetOpportunity: map['threeBetOpportunity'] ?? 0,
      fold3betCount: map['fold3betCount'] ?? 0,
      facing3BetCount: map['facing3BetCount'] ?? 0,
      cbetCount: map['cbetCount'] ?? 0,
      cbetOpportunity: map['cbetOpportunity'] ?? 0,
      stealCount: map['stealCount'] ?? 0,
      stealOpportunity: map['stealOpportunity'] ?? 0,
      checkRaiseFlopCount: map['checkRaiseFlopCount'] ?? 0,
      checkRaiseFlopOpportunity: map['checkRaiseFlopOpportunity'] ?? 0,
      // Legacy counters
      aggressionActions: map['aggressionActions'] ?? 0,
      passiveActions: map['passiveActions'] ?? 0,
      foldCount: map['foldCount'] ?? 0,
      checkCount: map['checkCount'] ?? 0,
      callCount: map['callCount'] ?? 0,
      betCount: map['betCount'] ?? 0,
      raiseCount: map['raiseCount'] ?? 0,
    );
  }

  /// Convert to map for Firestore storage
  Map<String, dynamic> toFirestore() {
    return {
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'handsPlayed': handsPlayed,
      'sessionsPlayed': sessionsPlayed,
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
      // Legacy counters (backward compatibility)
      'aggressionActions': aggressionActions,
      'passiveActions': passiveActions,
      'foldCount': foldCount,
      'checkCount': checkCount,
      'callCount': callCount,
      'betCount': betCount,
      'raiseCount': raiseCount,
    };
  }

  /// Convert to map for local storage
  Map<String, dynamic> toMap() {
    return {
      'opponentId': opponentId,
      'lastUpdated': lastUpdated.toIso8601String(),
      'handsPlayed': handsPlayed,
      'sessionsPlayed': sessionsPlayed,
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
      // Legacy counters (backward compatibility)
      'aggressionActions': aggressionActions,
      'passiveActions': passiveActions,
      'foldCount': foldCount,
      'checkCount': checkCount,
      'callCount': callCount,
      'betCount': betCount,
      'raiseCount': raiseCount,
    };
  }

  /// Create a copy with updated counters (for incremental updates)
  OpponentStats copyWith({
    int? handsPlayed,
    int? sessionsPlayed,
    int? walksCount,
    int? vpipCount,
    int? pfrCount,
    int? threeBetCount,
    int? threeBetOpportunity,
    int? fold3betCount,
    int? facing3BetCount,
    int? cbetCount,
    int? cbetOpportunity,
    int? stealCount,
    int? stealOpportunity,
    int? checkRaiseFlopCount,
    int? checkRaiseFlopOpportunity,
    int? aggressionActions,
    int? passiveActions,
    int? foldCount,
    int? checkCount,
    int? callCount,
    int? betCount,
    int? raiseCount,
    DateTime? lastUpdated,
  }) {
    return OpponentStats(
      opponentId: opponentId,
      handsPlayed: handsPlayed ?? this.handsPlayed,
      sessionsPlayed: sessionsPlayed ?? this.sessionsPlayed,
      walksCount: walksCount ?? this.walksCount,
      vpipCount: vpipCount ?? this.vpipCount,
      pfrCount: pfrCount ?? this.pfrCount,
      threeBetCount: threeBetCount ?? this.threeBetCount,
      threeBetOpportunity: threeBetOpportunity ?? this.threeBetOpportunity,
      fold3betCount: fold3betCount ?? this.fold3betCount,
      facing3BetCount: facing3BetCount ?? this.facing3BetCount,
      cbetCount: cbetCount ?? this.cbetCount,
      cbetOpportunity: cbetOpportunity ?? this.cbetOpportunity,
      stealCount: stealCount ?? this.stealCount,
      stealOpportunity: stealOpportunity ?? this.stealOpportunity,
      checkRaiseFlopCount: checkRaiseFlopCount ?? this.checkRaiseFlopCount,
      checkRaiseFlopOpportunity: checkRaiseFlopOpportunity ?? this.checkRaiseFlopOpportunity,
      aggressionActions: aggressionActions ?? this.aggressionActions,
      passiveActions: passiveActions ?? this.passiveActions,
      foldCount: foldCount ?? this.foldCount,
      checkCount: checkCount ?? this.checkCount,
      callCount: callCount ?? this.callCount,
      betCount: betCount ?? this.betCount,
      raiseCount: raiseCount ?? this.raiseCount,
      lastUpdated: lastUpdated ?? DateTime.now(),
    );
  }

  /// Create a copy with incremental updates (add deltas to existing counts)
  OpponentStats incrementWith({
    int handsDelta = 0,
    int sessionsDelta = 0,
    int walksDelta = 0,
    int vpipDelta = 0,
    int pfrDelta = 0,
    int threeBetDelta = 0,
    int threeBetOpportunityDelta = 0,
    int fold3betDelta = 0,
    int facing3BetDelta = 0,
    int cbetDelta = 0,
    int cbetOpportunityDelta = 0,
    int stealDelta = 0,
    int stealOpportunityDelta = 0,
    int checkRaiseFlopDelta = 0,
    int checkRaiseFlopOpportunityDelta = 0,
    // Legacy deltas (backward compatibility)
    int aggressionDelta = 0,
    int passiveDelta = 0,
    int foldDelta = 0,
    int checkDelta = 0,
    int callDelta = 0,
    int betDelta = 0,
    int raiseDelta = 0,
  }) {
    return OpponentStats(
      opponentId: opponentId,
      handsPlayed: handsPlayed + handsDelta,
      sessionsPlayed: sessionsPlayed + sessionsDelta,
      walksCount: walksCount + walksDelta,
      vpipCount: vpipCount + vpipDelta,
      pfrCount: pfrCount + pfrDelta,
      threeBetCount: threeBetCount + threeBetDelta,
      threeBetOpportunity: threeBetOpportunity + threeBetOpportunityDelta,
      fold3betCount: fold3betCount + fold3betDelta,
      facing3BetCount: facing3BetCount + facing3BetDelta,
      cbetCount: cbetCount + cbetDelta,
      cbetOpportunity: cbetOpportunity + cbetOpportunityDelta,
      stealCount: stealCount + stealDelta,
      stealOpportunity: stealOpportunity + stealOpportunityDelta,
      checkRaiseFlopCount: checkRaiseFlopCount + checkRaiseFlopDelta,
      checkRaiseFlopOpportunity: checkRaiseFlopOpportunity + checkRaiseFlopOpportunityDelta,
      aggressionActions: aggressionActions + aggressionDelta,
      passiveActions: passiveActions + passiveDelta,
      foldCount: foldCount + foldDelta,
      checkCount: checkCount + checkDelta,
      callCount: callCount + callDelta,
      betCount: betCount + betDelta,
      raiseCount: raiseCount + raiseDelta,
      lastUpdated: DateTime.now(),
    );
  }

  // Calculated properties (derived on read, not stored)
  // ALL percentages are guaranteed to be between 0 and 100

  /// Eligible hands for VPIP/PFR calculation (excludes walks)
  int get eligibleHands => handsPlayed - walksCount;

  /// VPIP percentage (Voluntarily Put $ In Pot)
  /// Denominator: handsPlayed - walks
  double get vpipPercentage => eligibleHands > 0
      ? (vpipCount / eligibleHands * 100).clamp(0.0, 100.0) : 0.0;

  /// PFR percentage (Pre-Flop Raise)
  /// Denominator: handsPlayed - walks
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
      default:
        return false;
    }
  }

  /// Check if stats have sufficient sample size for reliability
  bool get hasReliableStats => (handsPlayed ?? 0) >= 50;

  /// Calculate player type based on VPIP and PFR stats
  /// Uses PFR/VPIP ratio as aggression proxy (higher = more aggressive)
  PlayerType get playerType {
    final vpip = vpipPercentage;
    final pfr = pfrPercentage;

    // Return unknown if not enough hands
    if (eligibleHands < 10) {
      return PlayerType.unknown;
    }

    // PFR/VPIP ratio indicates aggression (higher = more aggressive)
    // 0.6+ is aggressive, below is passive
    final pfrVpipRatio = vpip > 0 ? pfr / vpip : 0.0;
    final isAggressive = pfrVpipRatio >= 0.6;

    // Tight: VPIP < 22%, Loose: VPIP > 28%
    if (vpip < 22) {
      // Tight player
      return isAggressive ? PlayerType.tightAggressive : PlayerType.tightPassive;
    } else if (vpip > 28) {
      // Loose player
      if (isAggressive) {
        return pfr > 25 ? PlayerType.maniac : PlayerType.looseAggressive;
      } else {
        return pfr < 10 ? PlayerType.calling_station : PlayerType.loosePassive;
      }
    } else {
      // Middle range VPIP (22-28%)
      return isAggressive ? PlayerType.tagRegular : PlayerType.loosePassive;
    }
  }

  /// Calculate playing style description (same logic as Opponent model)
  String get playingStyle {
    switch (playerType) {
      case PlayerType.tightAggressive:
        return 'Tight-Aggressive (TAG)';
      case PlayerType.tightPassive:
        return 'Tight-Passive (Rock)';
      case PlayerType.looseAggressive:
        return 'Loose-Aggressive (LAG)';
      case PlayerType.loosePassive:
        return 'Loose-Passive (Fish)';
      case PlayerType.tagRegular:
        return 'TAG Regular';
      case PlayerType.maniac:
        return 'Maniac';
      case PlayerType.calling_station:
        return 'Calling Station';
      case PlayerType.unknown:
        return 'No Data';
    }
  }

  /// Convert to stats map for UI display
  Map<String, dynamic> toLegacyStatsMap() {
    return {
      'totalHands': handsPlayed,
      'totalSessions': sessionsPlayed,
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

  @override
  String toString() {
    return 'OpponentStats(id: $opponentId, hands: $handsPlayed, vpip: ${vpipPercentage.toStringAsFixed(1)}%, pfr: ${pfrPercentage.toStringAsFixed(1)}%)';
  }
}