import 'package:cloud_firestore/cloud_firestore.dart';

/// Seat assignment status
enum SeatStatus {
  /// Player has scanned QR but waiting for dealer approval
  pending,
  /// Dealer has approved and player is actively seated
  joined,
  /// Player has left the seat
  left,
}

/// Represents a player's seat assignment at a table
/// Stored in the seat_assignments collection
class SeatAssignment {
  final String id;  // QR code ID
  final String clubId;
  final String tableId;
  final int seatNumber;
  final String? playerId;  // Current player at this seat (null if empty)
  final String? playerName;
  final SeatStatus status;  // pending, joined, or left
  final double? chipStack;  // Chip stack set by dealer
  final DateTime? assignedAt;
  final DateTime updatedAt;

  SeatAssignment({
    required this.id,
    required this.clubId,
    required this.tableId,
    required this.seatNumber,
    this.playerId,
    this.playerName,
    this.status = SeatStatus.left,
    this.chipStack,
    this.assignedAt,
    required this.updatedAt,
  });

  /// Check if seat is occupied (player has joined and not left)
  /// For backwards compatibility: if playerId is set and status is joined (or left for legacy)
  bool get isOccupied => playerId != null && status == SeatStatus.joined;

  /// Check if seat is empty (no player or player has left)
  bool get isEmpty => playerId == null || status == SeatStatus.left;

  /// Check if seat has a pending join request
  bool get isPending => playerId != null && status == SeatStatus.pending;

  /// Parse status string to enum with backwards compatibility
  /// For legacy documents without status field, infer from playerId
  static SeatStatus _parseStatusWithPlayerId(String? statusStr, String? playerId) {
    if (statusStr != null) {
      switch (statusStr) {
        case 'pending':
          return SeatStatus.pending;
        case 'joined':
          return SeatStatus.joined;
        case 'left':
          return SeatStatus.left;
      }
    }
    // Backwards compatibility: if no status but has playerId, treat as joined
    if (playerId != null) {
      return SeatStatus.joined;
    }
    return SeatStatus.left;
  }

  /// Convert status enum to string
  static String _statusToString(SeatStatus status) {
    switch (status) {
      case SeatStatus.pending:
        return 'pending';
      case SeatStatus.joined:
        return 'joined';
      case SeatStatus.left:
        return 'left';
    }
  }

  /// Factory constructor from Firestore document
  factory SeatAssignment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final playerId = data['playerId'] as String?;
    return SeatAssignment(
      id: doc.id,
      clubId: data['clubId'] ?? '',
      tableId: data['tableId'] ?? '',
      seatNumber: data['seatNumber'] ?? 0,
      playerId: playerId,
      playerName: data['playerName'] as String?,
      status: _parseStatusWithPlayerId(data['status'] as String?, playerId),
      chipStack: (data['chipStack'] as num?)?.toDouble(),
      assignedAt: (data['assignedAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Factory constructor from map
  factory SeatAssignment.fromMap(Map<String, dynamic> map) {
    final playerId = map['playerId'] as String?;
    return SeatAssignment(
      id: map['id'] ?? '',
      clubId: map['clubId'] ?? '',
      tableId: map['tableId'] ?? '',
      seatNumber: map['seatNumber'] ?? 0,
      playerId: playerId,
      playerName: map['playerName'] as String?,
      status: _parseStatusWithPlayerId(map['status'] as String?, playerId),
      chipStack: (map['chipStack'] as num?)?.toDouble(),
      assignedAt: map['assignedAt'] != null
          ? DateTime.tryParse(map['assignedAt'])
          : null,
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  /// Convert to map for Firestore storage
  Map<String, dynamic> toFirestore() {
    return {
      'clubId': clubId,
      'tableId': tableId,
      'seatNumber': seatNumber,
      'playerId': playerId,
      'playerName': playerName,
      'status': _statusToString(status),
      'chipStack': chipStack,
      'assignedAt': assignedAt != null ? Timestamp.fromDate(assignedAt!) : null,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Convert to map for local storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clubId': clubId,
      'tableId': tableId,
      'seatNumber': seatNumber,
      'playerId': playerId,
      'playerName': playerName,
      'status': _statusToString(status),
      'chipStack': chipStack,
      'assignedAt': assignedAt?.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create a copy with updated values
  SeatAssignment copyWith({
    String? playerId,
    String? playerName,
    SeatStatus? status,
    double? chipStack,
    DateTime? assignedAt,
    DateTime? updatedAt,
  }) {
    return SeatAssignment(
      id: id,
      clubId: clubId,
      tableId: tableId,
      seatNumber: seatNumber,
      playerId: playerId ?? this.playerId,
      playerName: playerName ?? this.playerName,
      status: status ?? this.status,
      chipStack: chipStack ?? this.chipStack,
      assignedAt: assignedAt ?? this.assignedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Create an empty seat assignment (for clearing a seat)
  SeatAssignment clear() {
    return SeatAssignment(
      id: id,
      clubId: clubId,
      tableId: tableId,
      seatNumber: seatNumber,
      playerId: null,
      playerName: null,
      status: SeatStatus.left,
      chipStack: null,
      assignedAt: null,
      updatedAt: DateTime.now(),
    );
  }
}
