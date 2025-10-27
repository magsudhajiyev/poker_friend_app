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
      if (userId == null) {
        print('❌ User not authenticated');
        throw 'User not authenticated';
      }

      print('📅 Loading all events for user: $userId');

      final querySnapshot = await _firestore
          .collection(_eventsCollection)
          .where('userId', isEqualTo: userId)
          .get();

      print('📊 Found ${querySnapshot.docs.length} events in database');

      final events = querySnapshot.docs.map((doc) {
        final data = doc.data();
        final dateTimestamp = data['date'] as Timestamp?;
        print('  - Event: ${data['title']} | Date: ${dateTimestamp?.toDate()}');
        return {
          'id': doc.id,
          'title': data['title'],
          'type': data['type'],
          'location': data['location'],
          'date': dateTimestamp?.toDate().toIso8601String() ?? DateTime.now().toIso8601String(),
          'buyIn': data['buyIn'],
        };
      }).toList();

      // Sort by date
      events.sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));

      print('📅 Returning ${events.length} events');
      return events;
    } catch (e) {
      print('❌ Error getting user events: $e');
      return [];
    }
  }

  // Get upcoming events (from today onwards)
  static Future<List<Map<String, dynamic>>> getUpcomingEvents() async {
    try {
      final userId = AuthService.userId;
      if (userId == null) {
        print('❌ User not authenticated');
        throw 'User not authenticated';
      }

      print('📅 Loading upcoming events for user: $userId');

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Get all user events first (to avoid composite index requirement)
      final querySnapshot = await _firestore
          .collection(_eventsCollection)
          .where('userId', isEqualTo: userId)
          .get();

      print('📊 Found ${querySnapshot.docs.length} total events');

      // Filter and sort in memory
      final events = querySnapshot.docs
          .map((doc) {
            final data = doc.data();
            final dateTimestamp = data['date'] as Timestamp?;
            final eventDate = dateTimestamp?.toDate();

            if (eventDate == null) return null;

            final eventDateOnly = DateTime(eventDate.year, eventDate.month, eventDate.day);

            // Only include today or future events
            if (eventDateOnly.isBefore(today)) {
              print('⏭️ Skipping past event: ${data['title']} on $eventDateOnly');
              return null;
            }

            print('✅ Including event: ${data['title']} on $eventDateOnly');

            return {
              'id': doc.id,
              'title': data['title'],
              'type': data['type'],
              'location': data['location'],
              'date': eventDate.toIso8601String(),
              'buyIn': data['buyIn'],
            };
          })
          .where((event) => event != null)
          .cast<Map<String, dynamic>>()
          .toList();

      // Sort by date
      events.sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));

      print('📅 Returning ${events.length} upcoming events');
      return events;
    } catch (e) {
      print('❌ Error getting upcoming events: $e');
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
