import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_attendance.dart';
import 'auth_service.dart';

/// Service for managing event attendance/RSVP
class EventAttendanceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _clubsCollection = 'clubs';
  static const String _eventsSubcollection = 'events';
  static const String _attendanceSubcollection = 'attendance';

  /// Update current user's attendance for an event
  static Future<void> updateAttendance({
    required String clubId,
    required String eventId,
    required AttendanceStatus status,
  }) async {
    final userId = AuthService.userId;
    final displayName = AuthService.userDisplayName;
    print('📝 updateAttendance: userId=$userId, displayName=$displayName, status=${status.value}');
    print('📝 updateAttendance: clubId=$clubId, eventId=$eventId');
    if (userId == null) throw 'User not authenticated';

    final attendanceRef = _firestore
        .collection(_clubsCollection)
        .doc(clubId)
        .collection(_eventsSubcollection)
        .doc(eventId)
        .collection(_attendanceSubcollection)
        .doc(userId);

    final existing = await attendanceRef.get();
    print('📝 updateAttendance: existing=${existing.exists}');

    if (existing.exists) {
      // Update existing attendance
      print('📝 updateAttendance: Updating existing record');
      await attendanceRef.update({
        'status': status.value,
        'respondedAt': Timestamp.now(),
      });
    } else {
      // Create new attendance record
      print('📝 updateAttendance: Creating new record');
      final attendance = EventAttendance(
        id: userId,
        eventId: eventId,
        userId: userId,
        displayName: displayName,
        status: status,
        respondedAt: DateTime.now(),
      );
      await attendanceRef.set(attendance.toFirestore());
    }
    print('📝 updateAttendance: Done');
  }

  /// Get all attendance records for an event
  static Future<List<EventAttendance>> getEventAttendance(
    String clubId,
    String eventId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_eventsSubcollection)
          .doc(eventId)
          .collection(_attendanceSubcollection)
          .orderBy('respondedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => EventAttendance.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting event attendance: $e');
      return [];
    }
  }

  /// Get attendance filtered by status
  static Future<List<EventAttendance>> getEventAttendanceByStatus(
    String clubId,
    String eventId,
    AttendanceStatus status,
  ) async {
    print('📋 getEventAttendanceByStatus: clubId=$clubId, eventId=$eventId, status=${status.value}');
    try {
      // Avoid composite index by not using orderBy - sort locally instead
      final snapshot = await _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_eventsSubcollection)
          .doc(eventId)
          .collection(_attendanceSubcollection)
          .where('status', isEqualTo: status.value)
          .get();

      print('📋 getEventAttendanceByStatus: Found ${snapshot.docs.length} documents');
      for (final doc in snapshot.docs) {
        print('📋 getEventAttendanceByStatus: Doc ${doc.id} = ${doc.data()}');
      }

      final attendance = snapshot.docs
          .map((doc) => EventAttendance.fromFirestore(doc))
          .toList();
      // Sort locally by respondedAt descending
      attendance.sort((a, b) => b.respondedAt.compareTo(a.respondedAt));
      return attendance;
    } catch (e) {
      print('Error getting event attendance by status: $e');
      return [];
    }
  }

  /// Get attendance counts for an event
  static Future<Map<AttendanceStatus, int>> getAttendanceCounts(
    String clubId,
    String eventId,
  ) async {
    final counts = <AttendanceStatus, int>{
      AttendanceStatus.going: 0,
      AttendanceStatus.maybe: 0,
      AttendanceStatus.notGoing: 0,
    };

    try {
      final snapshot = await _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_eventsSubcollection)
          .doc(eventId)
          .collection(_attendanceSubcollection)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final status = AttendanceStatusExtension.fromString(data['status']);
        counts[status] = (counts[status] ?? 0) + 1;
      }
    } catch (e) {
      print('Error getting attendance counts: $e');
    }

    return counts;
  }

  /// Get current user's attendance for an event
  static Future<EventAttendance?> getCurrentUserAttendance(
    String clubId,
    String eventId,
  ) async {
    final userId = AuthService.userId;
    if (userId == null) return null;

    try {
      final doc = await _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_eventsSubcollection)
          .doc(eventId)
          .collection(_attendanceSubcollection)
          .doc(userId)
          .get();

      if (doc.exists) {
        return EventAttendance.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting current user attendance: $e');
      return null;
    }
  }

  /// Watch attendance for an event in real-time
  static Stream<List<EventAttendance>> watchEventAttendance(
    String clubId,
    String eventId,
  ) {
    return _firestore
        .collection(_clubsCollection)
        .doc(clubId)
        .collection(_eventsSubcollection)
        .doc(eventId)
        .collection(_attendanceSubcollection)
        .orderBy('respondedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => EventAttendance.fromFirestore(doc)).toList());
  }

  /// Watch current user's attendance in real-time
  static Stream<EventAttendance?> watchCurrentUserAttendance(
    String clubId,
    String eventId,
  ) {
    final userId = AuthService.userId;
    if (userId == null) {
      return Stream.value(null);
    }

    return _firestore
        .collection(_clubsCollection)
        .doc(clubId)
        .collection(_eventsSubcollection)
        .doc(eventId)
        .collection(_attendanceSubcollection)
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? EventAttendance.fromFirestore(doc) : null);
  }

  /// Mark that user added event to calendar
  static Future<void> markAddedToCalendar({
    required String clubId,
    required String eventId,
    required String calendarEventId,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) throw 'User not authenticated';

    final attendanceRef = _firestore
        .collection(_clubsCollection)
        .doc(clubId)
        .collection(_eventsSubcollection)
        .doc(eventId)
        .collection(_attendanceSubcollection)
        .doc(userId);

    final existing = await attendanceRef.get();

    if (existing.exists) {
      await attendanceRef.update({
        'addedToCalendar': true,
        'calendarEventId': calendarEventId,
      });
    } else {
      // If no attendance record exists, create one with "maybe" status
      final attendance = EventAttendance(
        id: userId,
        eventId: eventId,
        userId: userId,
        displayName: AuthService.userDisplayName,
        status: AttendanceStatus.maybe,
        respondedAt: DateTime.now(),
        addedToCalendar: true,
        calendarEventId: calendarEventId,
      );
      await attendanceRef.set(attendance.toFirestore());
    }
  }

  /// Remove calendar event and update attendance record
  static Future<void> removeFromCalendar({
    required String clubId,
    required String eventId,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) throw 'User not authenticated';

    final attendanceRef = _firestore
        .collection(_clubsCollection)
        .doc(clubId)
        .collection(_eventsSubcollection)
        .doc(eventId)
        .collection(_attendanceSubcollection)
        .doc(userId);

    final existing = await attendanceRef.get();

    if (existing.exists) {
      await attendanceRef.update({
        'addedToCalendar': false,
        'calendarEventId': FieldValue.delete(),
      });
    }
  }

  /// Delete user's attendance (remove RSVP)
  static Future<void> removeAttendance({
    required String clubId,
    required String eventId,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) throw 'User not authenticated';

    await _firestore
        .collection(_clubsCollection)
        .doc(clubId)
        .collection(_eventsSubcollection)
        .doc(eventId)
        .collection(_attendanceSubcollection)
        .doc(userId)
        .delete();
  }

  /// Get list of users who are going (for notifications)
  static Future<List<String>> getGoingUserIds(
    String clubId,
    String eventId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_eventsSubcollection)
          .doc(eventId)
          .collection(_attendanceSubcollection)
          .where('status', isEqualTo: AttendanceStatus.going.value)
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('Error getting going user IDs: $e');
      return [];
    }
  }
}
