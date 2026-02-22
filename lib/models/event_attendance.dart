import 'package:cloud_firestore/cloud_firestore.dart';

/// Attendance status for an event
enum AttendanceStatus {
  going,
  maybe,
  notGoing,
}

extension AttendanceStatusExtension on AttendanceStatus {
  String get displayName {
    switch (this) {
      case AttendanceStatus.going:
        return 'Going';
      case AttendanceStatus.maybe:
        return 'Maybe';
      case AttendanceStatus.notGoing:
        return 'Not Going';
    }
  }

  String get value {
    switch (this) {
      case AttendanceStatus.going:
        return 'going';
      case AttendanceStatus.maybe:
        return 'maybe';
      case AttendanceStatus.notGoing:
        return 'not_going';
    }
  }

  static AttendanceStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'going':
        return AttendanceStatus.going;
      case 'maybe':
        return AttendanceStatus.maybe;
      case 'not_going':
        return AttendanceStatus.notGoing;
      default:
        return AttendanceStatus.maybe;
    }
  }
}

/// Represents a user's RSVP to a club event
class EventAttendance {
  final String id;           // Document ID
  final String eventId;
  final String userId;
  final String displayName;
  final AttendanceStatus status;
  final DateTime respondedAt;
  final bool addedToCalendar;  // Track if user added to their calendar
  final String? calendarEventId;  // ID of the calendar event in poker_events

  EventAttendance({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.displayName,
    required this.status,
    required this.respondedAt,
    this.addedToCalendar = false,
    this.calendarEventId,
  });

  /// Factory constructor from Firestore document
  factory EventAttendance.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EventAttendance(
      id: doc.id,
      eventId: data['eventId'] ?? '',
      userId: data['userId'] ?? '',
      displayName: data['displayName'] ?? '',
      status: AttendanceStatusExtension.fromString(data['status']),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      addedToCalendar: data['addedToCalendar'] ?? false,
      calendarEventId: data['calendarEventId'],
    );
  }

  /// Factory constructor from map
  factory EventAttendance.fromMap(Map<String, dynamic> map) {
    return EventAttendance(
      id: map['id'] ?? '',
      eventId: map['eventId'] ?? '',
      userId: map['userId'] ?? '',
      displayName: map['displayName'] ?? '',
      status: AttendanceStatusExtension.fromString(map['status']),
      respondedAt: DateTime.tryParse(map['respondedAt'] ?? '') ?? DateTime.now(),
      addedToCalendar: map['addedToCalendar'] ?? false,
      calendarEventId: map['calendarEventId'],
    );
  }

  /// Convert to map for Firestore storage
  Map<String, dynamic> toFirestore() {
    return {
      'eventId': eventId,
      'userId': userId,
      'displayName': displayName,
      'status': status.value,
      'respondedAt': Timestamp.fromDate(respondedAt),
      'addedToCalendar': addedToCalendar,
      if (calendarEventId != null) 'calendarEventId': calendarEventId,
    };
  }

  /// Convert to map for local storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eventId': eventId,
      'userId': userId,
      'displayName': displayName,
      'status': status.value,
      'respondedAt': respondedAt.toIso8601String(),
      'addedToCalendar': addedToCalendar,
      'calendarEventId': calendarEventId,
    };
  }

  /// Create a copy with updated values
  EventAttendance copyWith({
    AttendanceStatus? status,
    bool? addedToCalendar,
    String? calendarEventId,
  }) {
    return EventAttendance(
      id: id,
      eventId: eventId,
      userId: userId,
      displayName: displayName,
      status: status ?? this.status,
      respondedAt: DateTime.now(), // Update responded time on any change
      addedToCalendar: addedToCalendar ?? this.addedToCalendar,
      calendarEventId: calendarEventId ?? this.calendarEventId,
    );
  }
}
