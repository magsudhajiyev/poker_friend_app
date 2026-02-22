import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a dealer session
enum DealerSessionStatus {
  active,
  paused,
  ended,
}

extension DealerSessionStatusExtension on DealerSessionStatus {
  String get displayName {
    switch (this) {
      case DealerSessionStatus.active:
        return 'Active';
      case DealerSessionStatus.paused:
        return 'Paused';
      case DealerSessionStatus.ended:
        return 'Ended';
    }
  }

  String get value {
    switch (this) {
      case DealerSessionStatus.active:
        return 'active';
      case DealerSessionStatus.paused:
        return 'paused';
      case DealerSessionStatus.ended:
        return 'ended';
    }
  }

  static DealerSessionStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'paused':
        return DealerSessionStatus.paused;
      case 'ended':
        return DealerSessionStatus.ended;
      case 'active':
      default:
        return DealerSessionStatus.active;
    }
  }
}

/// Information about a player seated at a table during a dealer session
class SeatedPlayer {
  final String playerId;  // User ID of the player
  final String displayName;
  final int seatNumber;
  final double stack;
  final DateTime joinedAt;
  final bool isActive;  // Still at the table

  SeatedPlayer({
    required this.playerId,
    required this.displayName,
    required this.seatNumber,
    required this.stack,
    required this.joinedAt,
    this.isActive = true,
  });

  factory SeatedPlayer.fromMap(Map<String, dynamic> map) {
    return SeatedPlayer(
      playerId: map['playerId'] ?? '',
      displayName: map['displayName'] ?? 'Player',
      seatNumber: map['seatNumber'] ?? 0,
      stack: (map['stack'] ?? 0).toDouble(),
      joinedAt: DateTime.tryParse(map['joinedAt'] ?? '') ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'playerId': playerId,
      'displayName': displayName,
      'seatNumber': seatNumber,
      'stack': stack,
      'joinedAt': joinedAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  SeatedPlayer copyWith({
    double? stack,
    bool? isActive,
  }) {
    return SeatedPlayer(
      playerId: playerId,
      displayName: displayName,
      seatNumber: seatNumber,
      stack: stack ?? this.stack,
      joinedAt: joinedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Represents a dealer session at a table
class DealerSession {
  final String id;
  final String clubId;
  final String tableId;
  final String dealerId;
  final String? dealerName;
  final String? eventId;  // Link to active event (for live rankings)
  final DealerSessionStatus status;
  final Map<int, SeatedPlayer> players;  // seat number -> player
  final int currentHandNumber;
  final String? currentHandId;
  final int buttonPosition;
  final int smallBlind;
  final int bigBlind;
  final bool hasBBante;
  final String gameType;
  final DateTime startTime;
  final DateTime? endTime;

  DealerSession({
    required this.id,
    required this.clubId,
    required this.tableId,
    required this.dealerId,
    this.dealerName,
    this.eventId,
    this.status = DealerSessionStatus.active,
    this.players = const {},
    this.currentHandNumber = 0,
    this.currentHandId,
    this.buttonPosition = 1,
    this.smallBlind = 1,
    this.bigBlind = 2,
    this.hasBBante = false,
    this.gameType = 'cash',
    required this.startTime,
    this.endTime,
  });

  /// Get list of active players
  List<SeatedPlayer> get activePlayers =>
      players.values.where((p) => p.isActive).toList();

  /// Get player count
  int get playerCount => activePlayers.length;

  /// Check if session is ongoing
  bool get isOngoing => status != DealerSessionStatus.ended;

  /// Factory constructor from Firestore document
  factory DealerSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DealerSession(
      id: doc.id,
      clubId: data['clubId'] ?? '',
      tableId: data['tableId'] ?? '',
      dealerId: data['dealerId'] ?? '',
      dealerName: data['dealerName'],
      eventId: data['eventId'],
      status: DealerSessionStatusExtension.fromString(data['status']),
      players: _parsePlayers(data['players']),
      currentHandNumber: data['currentHandNumber'] ?? 0,
      currentHandId: data['currentHandId'],
      buttonPosition: data['buttonPosition'] ?? 1,
      smallBlind: data['smallBlind'] ?? 1,
      bigBlind: data['bigBlind'] ?? 2,
      hasBBante: data['hasBBante'] ?? false,
      gameType: data['gameType'] ?? 'cash',
      startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (data['endTime'] as Timestamp?)?.toDate(),
    );
  }

  /// Factory constructor from map
  factory DealerSession.fromMap(Map<String, dynamic> map) {
    return DealerSession(
      id: map['id'] ?? '',
      clubId: map['clubId'] ?? '',
      tableId: map['tableId'] ?? '',
      dealerId: map['dealerId'] ?? '',
      dealerName: map['dealerName'],
      eventId: map['eventId'],
      status: DealerSessionStatusExtension.fromString(map['status']),
      players: _parsePlayers(map['players']),
      currentHandNumber: map['currentHandNumber'] ?? 0,
      currentHandId: map['currentHandId'],
      buttonPosition: map['buttonPosition'] ?? 1,
      smallBlind: map['smallBlind'] ?? 1,
      bigBlind: map['bigBlind'] ?? 2,
      hasBBante: map['hasBBante'] ?? false,
      gameType: map['gameType'] ?? 'cash',
      startTime: DateTime.tryParse(map['startTime'] ?? '') ?? DateTime.now(),
      endTime: map['endTime'] != null ? DateTime.tryParse(map['endTime']) : null,
    );
  }

  static Map<int, SeatedPlayer> _parsePlayers(dynamic playersData) {
    if (playersData == null) return {};
    if (playersData is Map) {
      return playersData.map((key, value) => MapEntry(
        int.tryParse(key.toString()) ?? 0,
        SeatedPlayer.fromMap(value as Map<String, dynamic>),
      ));
    }
    return {};
  }

  /// Convert to map for Firestore storage
  Map<String, dynamic> toFirestore() {
    return {
      'clubId': clubId,
      'tableId': tableId,
      'dealerId': dealerId,
      'dealerName': dealerName,
      'eventId': eventId,
      'status': status.value,
      'players': players.map((key, value) =>
          MapEntry(key.toString(), value.toMap())),
      'currentHandNumber': currentHandNumber,
      'currentHandId': currentHandId,
      'buttonPosition': buttonPosition,
      'smallBlind': smallBlind,
      'bigBlind': bigBlind,
      'hasBBante': hasBBante,
      'gameType': gameType,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
    };
  }

  /// Convert to map for local storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clubId': clubId,
      'tableId': tableId,
      'dealerId': dealerId,
      'dealerName': dealerName,
      'eventId': eventId,
      'status': status.value,
      'players': players.map((key, value) =>
          MapEntry(key.toString(), value.toMap())),
      'currentHandNumber': currentHandNumber,
      'currentHandId': currentHandId,
      'buttonPosition': buttonPosition,
      'smallBlind': smallBlind,
      'bigBlind': bigBlind,
      'hasBBante': hasBBante,
      'gameType': gameType,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
    };
  }

  /// Create a copy with updated values
  DealerSession copyWith({
    DealerSessionStatus? status,
    String? eventId,
    Map<int, SeatedPlayer>? players,
    int? currentHandNumber,
    String? currentHandId,
    int? buttonPosition,
    DateTime? endTime,
  }) {
    return DealerSession(
      id: id,
      clubId: clubId,
      tableId: tableId,
      dealerId: dealerId,
      dealerName: dealerName,
      eventId: eventId ?? this.eventId,
      status: status ?? this.status,
      players: players ?? this.players,
      currentHandNumber: currentHandNumber ?? this.currentHandNumber,
      currentHandId: currentHandId ?? this.currentHandId,
      buttonPosition: buttonPosition ?? this.buttonPosition,
      smallBlind: smallBlind,
      bigBlind: bigBlind,
      hasBBante: hasBBante,
      gameType: gameType,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}
