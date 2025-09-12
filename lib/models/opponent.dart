import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an opponent player with their stats and playing style
class Opponent {
  final String id;
  final String name;
  final String? notes;
  final DateTime createdAt;
  final DateTime lastSeenAt;
  
  // Basic statistics
  final int handsPlayed;
  final int sessionsPlayed;
  
  // Playing style stats (percentages)
  final double vpip; // Voluntarily Put $ In Pot
  final double pfr; // Preflop Raise
  final double threeBet; // 3-Bet frequency
  final double cbet; // Continuation Bet
  final double fold3bet; // Fold to 3-Bet
  final double aggression; // Aggression factor
  
  // Tendencies (calculated)
  final PlayerType playerType;
  final String playingStyle; // "Tight-Aggressive", "Loose-Passive", etc.
  
  // Color coding for quick identification
  final OpponentColor color;

  Opponent({
    required this.id,
    required this.name,
    this.notes,
    required this.createdAt,
    required this.lastSeenAt,
    this.handsPlayed = 0,
    this.sessionsPlayed = 0,
    this.vpip = 0.0,
    this.pfr = 0.0,
    this.threeBet = 0.0,
    this.cbet = 0.0,
    this.fold3bet = 0.0,
    this.aggression = 0.0,
    PlayerType? playerType,
    String? playingStyle,
    this.color = OpponentColor.blue,
  }) : playerType = playerType ?? _calculatePlayerType(vpip, pfr, threeBet, aggression),
       playingStyle = playingStyle ?? _calculatePlayingStyle(vpip, pfr, threeBet, aggression);

  /// Factory constructor from Firestore document
  factory Opponent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Opponent(
      id: doc.id,
      name: data['name'] ?? '',
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSeenAt: (data['lastSeenAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      handsPlayed: data['handsPlayed'] ?? 0,
      sessionsPlayed: data['sessionsPlayed'] ?? 0,
      vpip: (data['vpip'] ?? 0.0).toDouble(),
      pfr: (data['pfr'] ?? 0.0).toDouble(),
      threeBet: (data['threeBet'] ?? 0.0).toDouble(),
      cbet: (data['cbet'] ?? 0.0).toDouble(),
      fold3bet: (data['fold3bet'] ?? 0.0).toDouble(),
      aggression: (data['aggression'] ?? 0.0).toDouble(),
      playerType: PlayerType.values.firstWhere(
        (e) => e.name == data['playerType'], 
        orElse: () => PlayerType.unknown
      ),
      playingStyle: data['playingStyle'],
      color: OpponentColor.values.firstWhere(
        (e) => e.name == data['color'], 
        orElse: () => OpponentColor.blue
      ),
    );
  }

  /// Factory constructor from local storage map
  factory Opponent.fromMap(Map<String, dynamic> map) {
    return Opponent(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      notes: map['notes'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      lastSeenAt: DateTime.tryParse(map['lastSeenAt'] ?? '') ?? DateTime.now(),
      handsPlayed: map['handsPlayed'] ?? 0,
      sessionsPlayed: map['sessionsPlayed'] ?? 0,
      vpip: (map['vpip'] ?? 0.0).toDouble(),
      pfr: (map['pfr'] ?? 0.0).toDouble(),
      threeBet: (map['threeBet'] ?? 0.0).toDouble(),
      cbet: (map['cbet'] ?? 0.0).toDouble(),
      fold3bet: (map['fold3bet'] ?? 0.0).toDouble(),
      aggression: (map['aggression'] ?? 0.0).toDouble(),
      playerType: PlayerType.values.firstWhere(
        (e) => e.name == map['playerType'], 
        orElse: () => PlayerType.unknown
      ),
      playingStyle: map['playingStyle'],
      color: OpponentColor.values.firstWhere(
        (e) => e.name == map['color'], 
        orElse: () => OpponentColor.blue
      ),
    );
  }

  /// Convert to map for Firestore storage
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastSeenAt': Timestamp.fromDate(lastSeenAt),
      'handsPlayed': handsPlayed,
      'sessionsPlayed': sessionsPlayed,
      'vpip': vpip,
      'pfr': pfr,
      'threeBet': threeBet,
      'cbet': cbet,
      'fold3bet': fold3bet,
      'aggression': aggression,
      'playerType': playerType.name,
      'playingStyle': playingStyle,
      'color': color.name,
    };
  }

  /// Convert to map for local storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'lastSeenAt': lastSeenAt.toIso8601String(),
      'handsPlayed': handsPlayed,
      'sessionsPlayed': sessionsPlayed,
      'vpip': vpip,
      'pfr': pfr,
      'threeBet': threeBet,
      'cbet': cbet,
      'fold3bet': fold3bet,
      'aggression': aggression,
      'playerType': playerType.name,
      'playingStyle': playingStyle,
      'color': color.name,
    };
  }

  /// Create a copy with updated values
  Opponent copyWith({
    String? name,
    String? notes,
    DateTime? lastSeenAt,
    int? handsPlayed,
    int? sessionsPlayed,
    double? vpip,
    double? pfr,
    double? threeBet,
    double? cbet,
    double? fold3bet,
    double? aggression,
    PlayerType? playerType,
    String? playingStyle,
    OpponentColor? color,
  }) {
    return Opponent(
      id: id,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      handsPlayed: handsPlayed ?? this.handsPlayed,
      sessionsPlayed: sessionsPlayed ?? this.sessionsPlayed,
      vpip: vpip ?? this.vpip,
      pfr: pfr ?? this.pfr,
      threeBet: threeBet ?? this.threeBet,
      cbet: cbet ?? this.cbet,
      fold3bet: fold3bet ?? this.fold3bet,
      aggression: aggression ?? this.aggression,
      playerType: playerType ?? this.playerType,
      playingStyle: playingStyle ?? this.playingStyle,
      color: color ?? this.color,
    );
  }

  /// Calculate player type based on stats
  static PlayerType _calculatePlayerType(double vpip, double pfr, double threeBet, double aggression) {
    if (vpip < 15 && pfr < 12) {
      return aggression > 2.5 ? PlayerType.tightAggressive : PlayerType.tightPassive;
    } else if (vpip > 25 && pfr > 20) {
      return aggression > 2.5 ? PlayerType.looseAggressive : PlayerType.loosePassive;
    } else if (vpip < 20 && pfr > 15) {
      return PlayerType.tightAggressive;
    } else if (vpip > 30) {
      return PlayerType.loosePassive;
    } else {
      return PlayerType.tagRegular; // Tight-Aggressive-Good (regular)
    }
  }

  /// Calculate playing style description
  static String _calculatePlayingStyle(double vpip, double pfr, double threeBet, double aggression) {
    final type = _calculatePlayerType(vpip, pfr, threeBet, aggression);
    switch (type) {
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
        return 'Unknown';
    }
  }

  /// Get readable stats summary
  String get statsSummary {
    if (handsPlayed < 10) return 'Not enough hands';
    return 'VPIP: ${vpip.toInt()}% | PFR: ${pfr.toInt()}% | 3B: ${threeBet.toInt()}%';
  }

  /// Check if opponent has sufficient sample size for reliable stats
  bool get hasReliableStats => handsPlayed >= 50;
}

/// Player type classification
enum PlayerType {
  tightAggressive,
  tightPassive,
  looseAggressive,
  loosePassive,
  tagRegular,
  maniac,
  calling_station,
  unknown,
}

/// Color coding for opponents
enum OpponentColor {
  red,
  blue,
  green,
  orange,
  purple,
  teal,
  pink,
  indigo,
}

extension OpponentColorExtension on OpponentColor {
  String get displayName {
    switch (this) {
      case OpponentColor.red:
        return 'Red';
      case OpponentColor.blue:
        return 'Blue';
      case OpponentColor.green:
        return 'Green';
      case OpponentColor.orange:
        return 'Orange';
      case OpponentColor.purple:
        return 'Purple';
      case OpponentColor.teal:
        return 'Teal';
      case OpponentColor.pink:
        return 'Pink';
      case OpponentColor.indigo:
        return 'Indigo';
    }
  }
}