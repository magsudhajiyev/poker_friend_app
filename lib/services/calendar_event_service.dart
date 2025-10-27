import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

class CalendarEventService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _eventsCollection = 'poker_events';

  // Create a new event
  static Future<String> createEvent({
    required String title,
    required String type,
    required String location,
    required DateTime date,
    required double buyIn,
  }) async {
    try {
      final userId = AuthService.userId;
      if (userId == null) throw 'User not authenticated';

      final eventData = {
        'userId': userId,
        'userEmail': AuthService.currentUser?.email,
        'title': title,
        'type': type,
        'location': location,
        'date': Timestamp.fromDate(date),
        'buyIn': buyIn,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final eventRef = await _firestore.collection(_eventsCollection).add(eventData);
      print('Event created with ID: ${eventRef.id}');
      return eventRef.id;
    } catch (e) {
      print('Error creating event: $e');
      rethrow;
    }
  }

  // Get all events for current user
  static Future<List<Map<String, dynamic>>> getUserEvents() async {
    try {
      final userId = AuthService.userId;
      if (userId == null) throw 'User not authenticated';

      final querySnapshot = await _firestore
          .collection(_eventsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: false)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        final dateTimestamp = data['date'] as Timestamp?;
        return {
          'id': doc.id,
          'title': data['title'],
          'type': data['type'],
          'location': data['location'],
          'date': dateTimestamp?.toDate().toIso8601String() ?? DateTime.now().toIso8601String(),
          'buyIn': data['buyIn'],
        };
      }).toList();
    } catch (e) {
      print('Error getting user events: $e');
      return [];
    }
  }

  // Get upcoming events (from today onwards)
  static Future<List<Map<String, dynamic>>> getUpcomingEvents() async {
    try {
      final userId = AuthService.userId;
      if (userId == null) throw 'User not authenticated';

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final querySnapshot = await _firestore
          .collection(_eventsCollection)
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .orderBy('date', descending: false)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        final dateTimestamp = data['date'] as Timestamp?;
        return {
          'id': doc.id,
          'title': data['title'],
          'type': data['type'],
          'location': data['location'],
          'date': dateTimestamp?.toDate().toIso8601String() ?? DateTime.now().toIso8601String(),
          'buyIn': data['buyIn'],
        };
      }).toList();
    } catch (e) {
      print('Error getting upcoming events: $e');
      return [];
    }
  }

  // Update an event
  static Future<void> updateEvent({
    required String eventId,
    required String title,
    required String type,
    required String location,
    required DateTime date,
    required double buyIn,
  }) async {
    try {
      final userId = AuthService.userId;
      if (userId == null) throw 'User not authenticated';

      await _firestore.collection(_eventsCollection).doc(eventId).update({
        'title': title,
        'type': type,
        'location': location,
        'date': Timestamp.fromDate(date),
        'buyIn': buyIn,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('Event updated: $eventId');
    } catch (e) {
      print('Error updating event: $e');
      rethrow;
    }
  }

  // Delete an event
  static Future<void> deleteEvent(String eventId) async {
    try {
      final userId = AuthService.userId;
      if (userId == null) throw 'User not authenticated';

      await _firestore.collection(_eventsCollection).doc(eventId).delete();
      print('Event deleted: $eventId');
    } catch (e) {
      print('Error deleting event: $e');
      rethrow;
    }
  }
}
