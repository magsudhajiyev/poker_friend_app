import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a club event
enum EventStatus {
  scheduled,  // Event created but not started
  active,     // Event is currently running
  paused,
  completed,
  cancelled,
}

extension EventStatusExtension on EventStatus {
  String get displayName {
    switch (this) {
      case EventStatus.scheduled:
        return 'Scheduled';
      case EventStatus.active:
        return 'Active';
      case EventStatus.paused:
        return 'Paused';
      case EventStatus.completed:
        return 'Completed';
      case EventStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get value {
    switch (this) {
      case EventStatus.scheduled:
        return 'scheduled';
      case EventStatus.active:
        return 'active';
      case EventStatus.paused:
        return 'paused';
      case EventStatus.completed:
        return 'completed';
      case EventStatus.cancelled:
        return 'cancelled';
    }
  }

  static EventStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'scheduled':
        return EventStatus.scheduled;
      case 'paused':
        return EventStatus.paused;
      case 'completed':
        return EventStatus.completed;
      case 'cancelled':
        return EventStatus.cancelled;
      case 'active':
      default:
        return EventStatus.active;
    }
  }

  /// Check if event can be viewed by spectators
  bool get isSpectatable => this == EventStatus.active;

  /// Check if event is over
  bool get isFinished => this == EventStatus.completed || this == EventStatus.cancelled;
}

/// Represents a club event that groups multiple tables for ranking
class ClubEvent {
  final String id;
  final String clubId;
  final String name;
  final List<String> tableIds; // Tables included in this event
  final DateTime startTime;
  final DateTime? endTime;
  final bool isPublic; // Anyone can view if true
  final String? accessCode; // Optional code for private events
  final EventStatus status;
  final String createdBy; // Admin userId who created this event

  // New fields for events system
  final String? description;      // Event description
  final String? location;         // Physical location
  final double? buyInAmount;      // Buy-in cost (tournament)
  final double? startingStack;    // Starting stack for tournament, min buy-in for cash
  final String? stakes;           // Stakes for cash games (e.g., "1/2", "5/5")
  final int? maxPlayers;          // Capacity limit
  final bool notifyMembers;       // Whether to send notifications
  final DateTime createdAt;       // Creation timestamp
  final String gameType;          // 'cash' or 'tournament'

  ClubEvent({
    required this.id,
    required this.clubId,
    required this.name,
    required this.tableIds,
    required this.startTime,
    this.endTime,
    this.isPublic = false,
    this.accessCode,
    this.status = EventStatus.scheduled,
    required this.createdBy,
    this.description,
    this.location,
    this.buyInAmount,
    this.startingStack,
    this.stakes,
    this.maxPlayers,
    this.notifyMembers = true,
    DateTime? createdAt,
    this.gameType = 'cash',
  }) : createdAt = createdAt ?? DateTime.now();

  /// Check if event is ongoing
  bool get isOngoing => status == EventStatus.active || status == EventStatus.paused;

  /// Check if event is upcoming
  bool get isUpcoming => status == EventStatus.scheduled && startTime.isAfter(DateTime.now());

  /// Check if event is live
  bool get isLive => status == EventStatus.active;

  /// Get table count
  int get tableCount => tableIds.length;

  /// Check if event has capacity
  bool get hasCapacity => maxPlayers != null;

  /// Check if event is free
  bool get isFree => buyInAmount == null || buyInAmount == 0;

  /// Factory constructor from Firestore document
  factory ClubEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClubEvent(
      id: doc.id,
      clubId: data['clubId'] ?? '',
      name: data['name'] ?? '',
      tableIds: List<String>.from(data['tableIds'] ?? []),
      startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (data['endTime'] as Timestamp?)?.toDate(),
      isPublic: data['isPublic'] ?? false,
      accessCode: data['accessCode'],
      status: EventStatusExtension.fromString(data['status']),
      createdBy: data['createdBy'] ?? '',
      description: data['description'],
      location: data['location'],
      buyInAmount: (data['buyInAmount'] as num?)?.toDouble(),
      startingStack: (data['startingStack'] as num?)?.toDouble(),
      stakes: data['stakes'],
      maxPlayers: data['maxPlayers'],
      notifyMembers: data['notifyMembers'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      gameType: data['gameType'] ?? 'cash',
    );
  }

  /// Factory constructor from map
  factory ClubEvent.fromMap(Map<String, dynamic> map) {
    return ClubEvent(
      id: map['id'] ?? '',
      clubId: map['clubId'] ?? '',
      name: map['name'] ?? '',
      tableIds: List<String>.from(map['tableIds'] ?? []),
      startTime: DateTime.tryParse(map['startTime'] ?? '') ?? DateTime.now(),
      endTime: map['endTime'] != null ? DateTime.tryParse(map['endTime']) : null,
      isPublic: map['isPublic'] ?? false,
      accessCode: map['accessCode'],
      status: EventStatusExtension.fromString(map['status']),
      createdBy: map['createdBy'] ?? '',
      description: map['description'],
      location: map['location'],
      buyInAmount: (map['buyInAmount'] as num?)?.toDouble(),
      startingStack: (map['startingStack'] as num?)?.toDouble(),
      stakes: map['stakes'],
      maxPlayers: map['maxPlayers'],
      notifyMembers: map['notifyMembers'] ?? true,
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt']) : null,
      gameType: map['gameType'] ?? 'cash',
    );
  }

  /// Convert to map for Firestore storage
  Map<String, dynamic> toFirestore() {
    return {
      'clubId': clubId,
      'name': name,
      'tableIds': tableIds,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'isPublic': isPublic,
      'accessCode': accessCode,
      'status': status.value,
      'createdBy': createdBy,
      'description': description,
      'location': location,
      'buyInAmount': buyInAmount,
      'startingStack': startingStack,
      'stakes': stakes,
      'maxPlayers': maxPlayers,
      'notifyMembers': notifyMembers,
      'createdAt': Timestamp.fromDate(createdAt),
      'gameType': gameType,
    };
  }

  /// Convert to map for local storage / API
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clubId': clubId,
      'name': name,
      'tableIds': tableIds,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'isPublic': isPublic,
      'accessCode': accessCode,
      'status': status.value,
      'createdBy': createdBy,
      'description': description,
      'location': location,
      'buyInAmount': buyInAmount,
      'startingStack': startingStack,
      'stakes': stakes,
      'maxPlayers': maxPlayers,
      'notifyMembers': notifyMembers,
      'createdAt': createdAt.toIso8601String(),
      'gameType': gameType,
    };
  }

  /// Create a copy with updated values
  ClubEvent copyWith({
    String? name,
    List<String>? tableIds,
    DateTime? startTime,
    DateTime? endTime,
    bool? isPublic,
    String? accessCode,
    EventStatus? status,
    String? description,
    String? location,
    double? buyInAmount,
    double? startingStack,
    String? stakes,
    int? maxPlayers,
    bool? notifyMembers,
    String? gameType,
  }) {
    return ClubEvent(
      id: id,
      clubId: clubId,
      name: name ?? this.name,
      tableIds: tableIds ?? this.tableIds,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isPublic: isPublic ?? this.isPublic,
      accessCode: accessCode ?? this.accessCode,
      status: status ?? this.status,
      createdBy: createdBy,
      description: description ?? this.description,
      location: location ?? this.location,
      buyInAmount: buyInAmount ?? this.buyInAmount,
      startingStack: startingStack ?? this.startingStack,
      stakes: stakes ?? this.stakes,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      notifyMembers: notifyMembers ?? this.notifyMembers,
      createdAt: createdAt,
      gameType: gameType ?? this.gameType,
    );
  }
}
