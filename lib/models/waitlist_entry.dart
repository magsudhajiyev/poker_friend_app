import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a waitlist entry
enum WaitlistStatus {
  waiting,   // In queue waiting for seat
  notified,  // Received seat-available notification (first in line)
  seated,    // Admin seated them
  removed,   // Left waitlist voluntarily or expired
}

/// Represents a player's entry in the waitlist for a cash game event
class WaitlistEntry {
  final String id;
  final String eventId;
  final String clubId;
  final String userId;
  final String userDisplayName;
  final DateTime joinedAt;  // Used for FIFO ordering
  final WaitlistStatus status;
  final DateTime? notifiedAt;  // When seat-available notification was sent
  final String? seatedTableId;  // Which table they were seated at
  final int? seatedSeatNumber;  // Which seat they got

  WaitlistEntry({
    required this.id,
    required this.eventId,
    required this.clubId,
    required this.userId,
    required this.userDisplayName,
    required this.joinedAt,
    required this.status,
    this.notifiedAt,
    this.seatedTableId,
    this.seatedSeatNumber,
  });

  /// Create from Firestore document
  factory WaitlistEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WaitlistEntry(
      id: doc.id,
      eventId: data['eventId'] ?? '',
      clubId: data['clubId'] ?? '',
      userId: data['userId'] ?? '',
      userDisplayName: data['userDisplayName'] ?? '',
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: _parseStatus(data['status']),
      notifiedAt: (data['notifiedAt'] as Timestamp?)?.toDate(),
      seatedTableId: data['seatedTableId'],
      seatedSeatNumber: data['seatedSeatNumber'],
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'eventId': eventId,
      'clubId': clubId,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'status': status.name,
      'notifiedAt': notifiedAt != null ? Timestamp.fromDate(notifiedAt!) : null,
      'seatedTableId': seatedTableId,
      'seatedSeatNumber': seatedSeatNumber,
    };
  }

  /// Parse status string to enum
  static WaitlistStatus _parseStatus(String? status) {
    switch (status) {
      case 'waiting':
        return WaitlistStatus.waiting;
      case 'notified':
        return WaitlistStatus.notified;
      case 'seated':
        return WaitlistStatus.seated;
      case 'removed':
        return WaitlistStatus.removed;
      default:
        return WaitlistStatus.waiting;
    }
  }

  /// Create a copy with updated fields
  WaitlistEntry copyWith({
    String? id,
    String? eventId,
    String? clubId,
    String? userId,
    String? userDisplayName,
    DateTime? joinedAt,
    WaitlistStatus? status,
    DateTime? notifiedAt,
    String? seatedTableId,
    int? seatedSeatNumber,
  }) {
    return WaitlistEntry(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      clubId: clubId ?? this.clubId,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      joinedAt: joinedAt ?? this.joinedAt,
      status: status ?? this.status,
      notifiedAt: notifiedAt ?? this.notifiedAt,
      seatedTableId: seatedTableId ?? this.seatedTableId,
      seatedSeatNumber: seatedSeatNumber ?? this.seatedSeatNumber,
    );
  }

  /// Check if entry is active (waiting or notified)
  bool get isActive => status == WaitlistStatus.waiting || status == WaitlistStatus.notified;

  /// Check if entry is waiting for a seat
  bool get isWaiting => status == WaitlistStatus.waiting;

  /// Check if entry was notified
  bool get wasNotified => status == WaitlistStatus.notified;

  /// Check if entry was seated
  bool get wasSeated => status == WaitlistStatus.seated;
}
