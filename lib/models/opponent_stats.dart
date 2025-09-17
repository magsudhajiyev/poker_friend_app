import 'package:cloud_firestore/cloud_firestore.dart';

/// Optimized opponent statistics model using incremental counters
/// instead of recalculating from all hands every time
class OpponentStats {
  final String opponentId;
  final DateTime lastUpdated;

  // Basic counters
  final int handsPlayed;
  final int sessionsPlayed;

  // VPIP and PFR counters
  final int vpipCount;        // Voluntarily Put $ In Pot
  final int pfrCount;         // Pre-Flop Raise

  // Aggression counters
  final int aggressionActions; // Bet + Raise actions
  final int passiveActions;    // Call actions

  // Action distribution counters
  final int foldCount;
  final int checkCount;
  final int callCount;
  final int betCount;
  final int raiseCount;

  // Additional poker-specific counters
  final int threeBetCount;
  final int cbetCount;
  final int fold3betCount;

  OpponentStats({
    required this.opponentId,
    DateTime? lastUpdated,
    this.handsPlayed = 0,
    this.sessionsPlayed = 0,
    this.vpipCount = 0,
    this.pfrCount = 0,
    this.aggressionActions = 0,
    this.passiveActions = 0,
    this.foldCount = 0,
    this.checkCount = 0,
    this.callCount = 0,
    this.betCount = 0,
    this.raiseCount = 0,
    this.threeBetCount = 0,
    this.cbetCount = 0,
    this.fold3betCount = 0,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  /// Factory constructor from Firestore document
  factory OpponentStats.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OpponentStats(
      opponentId: doc.id,
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      handsPlayed: data['handsPlayed'] ?? 0,
      sessionsPlayed: data['sessionsPlayed'] ?? 0,
      vpipCount: data['vpipCount'] ?? 0,
      pfrCount: data['pfrCount'] ?? 0,
      aggressionActions: data['aggressionActions'] ?? 0,
      passiveActions: data['passiveActions'] ?? 0,
      foldCount: data['foldCount'] ?? 0,
      checkCount: data['checkCount'] ?? 0,
      callCount: data['callCount'] ?? 0,
      betCount: data['betCount'] ?? 0,
      raiseCount: data['raiseCount'] ?? 0,
      threeBetCount: data['threeBetCount'] ?? 0,
      cbetCount: data['cbetCount'] ?? 0,
      fold3betCount: data['fold3betCount'] ?? 0,
    );
  }

  /// Factory constructor from local storage map
  factory OpponentStats.fromMap(Map<String, dynamic> map) {
    return OpponentStats(
      opponentId: map['opponentId'] ?? '',
      lastUpdated: DateTime.tryParse(map['lastUpdated'] ?? '') ?? DateTime.now(),
      handsPlayed: map['handsPlayed'] ?? 0,
      sessionsPlayed: map['sessionsPlayed'] ?? 0,
      vpipCount: map['vpipCount'] ?? 0,
      pfrCount: map['pfrCount'] ?? 0,
      aggressionActions: map['aggressionActions'] ?? 0,
      passiveActions: map['passiveActions'] ?? 0,
      foldCount: map['foldCount'] ?? 0,
      checkCount: map['checkCount'] ?? 0,
      callCount: map['callCount'] ?? 0,
      betCount: map['betCount'] ?? 0,
      raiseCount: map['raiseCount'] ?? 0,
      threeBetCount: map['threeBetCount'] ?? 0,
      cbetCount: map['cbetCount'] ?? 0,
      fold3betCount: map['fold3betCount'] ?? 0,
    );
  }

  /// Convert to map for Firestore storage
  Map<String, dynamic> toFirestore() {
    return {
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'handsPlayed': handsPlayed,
      'sessionsPlayed': sessionsPlayed,
      'vpipCount': vpipCount,
      'pfrCount': pfrCount,
      'aggressionActions': aggressionActions,
      'passiveActions': passiveActions,
      'foldCount': foldCount,
      'checkCount': checkCount,
      'callCount': callCount,
      'betCount': betCount,
      'raiseCount': raiseCount,
      'threeBetCount': threeBetCount,
      'cbetCount': cbetCount,
      'fold3betCount': fold3betCount,
    };
  }

  /// Convert to map for local storage
  Map<String, dynamic> toMap() {
    return {
      'opponentId': opponentId,
      'lastUpdated': lastUpdated.toIso8601String(),
      'handsPlayed': handsPlayed,
      'sessionsPlayed': sessionsPlayed,
      'vpipCount': vpipCount,
      'pfrCount': pfrCount,
      'aggressionActions': aggressionActions,
      'passiveActions': passiveActions,
      'foldCount': foldCount,
      'checkCount': checkCount,
      'callCount': callCount,
      'betCount': betCount,
      'raiseCount': raiseCount,
      'threeBetCount': threeBetCount,
      'cbetCount': cbetCount,
      'fold3betCount': fold3betCount,
    };
  }

  /// Create a copy with updated counters (for incremental updates)
  OpponentStats copyWith({
    int? handsPlayed,
    int? sessionsPlayed,
    int? vpipCount,
    int? pfrCount,
    int? aggressionActions,
    int? passiveActions,
    int? foldCount,
    int? checkCount,
    int? callCount,
    int? betCount,
    int? raiseCount,
    int? threeBetCount,
    int? cbetCount,
    int? fold3betCount,
    DateTime? lastUpdated,
  }) {
    return OpponentStats(
      opponentId: opponentId,
      handsPlayed: handsPlayed ?? this.handsPlayed,
      sessionsPlayed: sessionsPlayed ?? this.sessionsPlayed,
      vpipCount: vpipCount ?? this.vpipCount,
      pfrCount: pfrCount ?? this.pfrCount,
      aggressionActions: aggressionActions ?? this.aggressionActions,
      passiveActions: passiveActions ?? this.passiveActions,
      foldCount: foldCount ?? this.foldCount,
      checkCount: checkCount ?? this.checkCount,
      callCount: callCount ?? this.callCount,
      betCount: betCount ?? this.betCount,
      raiseCount: raiseCount ?? this.raiseCount,
      threeBetCount: threeBetCount ?? this.threeBetCount,
      cbetCount: cbetCount ?? this.cbetCount,
      fold3betCount: fold3betCount ?? this.fold3betCount,
      lastUpdated: lastUpdated ?? DateTime.now(),
    );
  }

  /// Create a copy with incremental updates (add deltas to existing counts)
  OpponentStats incrementWith({
    int handsDelta = 0,
    int sessionsDelta = 0,
    int vpipDelta = 0,
    int pfrDelta = 0,
    int aggressionDelta = 0,
    int passiveDelta = 0,
    int foldDelta = 0,
    int checkDelta = 0,
    int callDelta = 0,
    int betDelta = 0,
    int raiseDelta = 0,
    int threeBetDelta = 0,
    int cbetDelta = 0,
    int fold3betDelta = 0,
  }) {
    return OpponentStats(
      opponentId: opponentId,
      handsPlayed: handsPlayed + handsDelta,
      sessionsPlayed: sessionsPlayed + sessionsDelta,
      vpipCount: vpipCount + vpipDelta,
      pfrCount: pfrCount + pfrDelta,
      aggressionActions: aggressionActions + aggressionDelta,
      passiveActions: passiveActions + passiveDelta,
      foldCount: foldCount + foldDelta,
      checkCount: checkCount + checkDelta,
      callCount: callCount + callDelta,
      betCount: betCount + betDelta,
      raiseCount: raiseCount + raiseDelta,
      threeBetCount: threeBetCount + threeBetDelta,
      cbetCount: cbetCount + cbetDelta,
      fold3betCount: fold3betCount + fold3betDelta,
      lastUpdated: DateTime.now(),
    );
  }

  // Calculated properties (derived on read, not stored)

  /// VPIP percentage (Voluntarily Put $ In Pot)
  double get vpipPercentage => handsPlayed > 0 ? (vpipCount / handsPlayed * 100) : 0.0;

  /// PFR percentage (Pre-Flop Raise)
  double get pfrPercentage => handsPlayed > 0 ? (pfrCount / handsPlayed * 100) : 0.0;

  /// Aggression factor (0.0 - 1.0)
  double get aggressionFactor {
    final totalActions = aggressionActions + passiveActions;
    return totalActions > 0 ? (aggressionActions / totalActions) : 0.0;
  }

  /// Fold percentage
  double get foldPercentage => handsPlayed > 0 ? (foldCount / handsPlayed * 100) : 0.0;

  /// Check percentage
  double get checkPercentage => handsPlayed > 0 ? (checkCount / handsPlayed * 100) : 0.0;

  /// Call percentage
  double get callPercentage => handsPlayed > 0 ? (callCount / handsPlayed * 100) : 0.0;

  /// Bet percentage
  double get betPercentage => handsPlayed > 0 ? (betCount / handsPlayed * 100) : 0.0;

  /// Raise percentage
  double get raisePercentage => handsPlayed > 0 ? (raiseCount / handsPlayed * 100) : 0.0;

  /// 3-Bet percentage
  double get threeBetPercentage => handsPlayed > 0 ? (threeBetCount / handsPlayed * 100) : 0.0;

  /// C-Bet percentage
  double get cbetPercentage => handsPlayed > 0 ? (cbetCount / handsPlayed * 100) : 0.0;

  /// Fold to 3-Bet percentage
  double get fold3betPercentage => handsPlayed > 0 ? (fold3betCount / handsPlayed * 100) : 0.0;

  /// Check if stats have sufficient sample size for reliability
  bool get hasReliableStats => handsPlayed >= 50;

  /// Convert to legacy Opponent format for compatibility
  Map<String, dynamic> toLegacyStatsMap() {
    return {
      'totalHands': handsPlayed,
      'totalSessions': sessionsPlayed,
      'vpip': vpipPercentage,
      'pfr': pfrPercentage,
      'aggression': aggressionFactor,
      'foldPercentage': foldPercentage,
      'checkPercentage': checkPercentage,
      'callPercentage': callPercentage,
      'betPercentage': betPercentage,
      'raisePercentage': raisePercentage,
      'threeBetPercentage': threeBetPercentage,
      'cbetPercentage': cbetPercentage,
      'fold3betPercentage': fold3betPercentage,
    };
  }

  @override
  String toString() {
    return 'OpponentStats(id: $opponentId, hands: $handsPlayed, vpip: ${vpipPercentage.toStringAsFixed(1)}%, pfr: ${pfrPercentage.toStringAsFixed(1)}%)';
  }
}