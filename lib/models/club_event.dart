import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a club event
enum EventStatus {
  active,
  paused,
  completed,
}

extension EventStatusExtension on EventStatus {
  String get displayName {
    switch (this) {
      case EventStatus.active:
        return 'Active';
      case EventStatus.paused:
        return 'Paused';
      case EventStatus.completed:
        return 'Completed';
    }
  }

  String get value {
    switch (this) {
      case EventStatus.active:
        return 'active';
      case EventStatus.paused:
        return 'paused';
      case EventStatus.completed:
        return 'completed';
    }
  }

  static EventStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'paused':
        return EventStatus.paused;
      case 'completed':
        return EventStatus.completed;
      case 'active':
      default:
        return EventStatus.active;
    }
  }
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

  ClubEvent({
    required this.id,
    required this.clubId,
    required this.name,
    required this.tableIds,
    required this.startTime,
    this.endTime,
    this.isPublic = false,
    this.accessCode,
    this.status = EventStatus.active,
    required this.createdBy,
  });

  /// Check if event is ongoing
  bool get isOngoing => status != EventStatus.completed;

  /// Get table count
  int get tableCount => tableIds.length;

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
    };
  }

  /// Create a copy with updated values
  ClubEvent copyWith({
    String? name,
    List<String>? tableIds,
    DateTime? endTime,
    bool? isPublic,
    String? accessCode,
    EventStatus? status,
  }) {
    return ClubEvent(
      id: id,
      clubId: clubId,
      name: name ?? this.name,
      tableIds: tableIds ?? this.tableIds,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      isPublic: isPublic ?? this.isPublic,
      accessCode: accessCode ?? this.accessCode,
      status: status ?? this.status,
      createdBy: createdBy,
    );
  }
}
