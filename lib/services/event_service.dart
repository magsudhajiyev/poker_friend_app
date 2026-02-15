import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/club_event.dart';
import '../models/event_ranking.dart';
import '../config/app_config.dart';
import 'auth_service.dart';

/// Service for managing club events and live rankings
class EventService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _clubsCollection = 'clubs';
  static const String _eventsSubcollection = 'events';

  /// Create a new event for a club
  static Future<ClubEvent> createEvent({
    required String clubId,
    required String name,
    required List<String> tableIds,
    bool isPublic = false,
    String? accessCode,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) throw 'User not authenticated';

    final now = DateTime.now();

    // Create in Firestore
    final eventRef = await _firestore
        .collection(_clubsCollection)
        .doc(clubId)
        .collection(_eventsSubcollection)
        .add({
      'clubId': clubId,
      'name': name,
      'tableIds': tableIds,
      'startTime': Timestamp.fromDate(now),
      'endTime': null,
      'isPublic': isPublic,
      'accessCode': accessCode,
      'status': 'active',
      'createdBy': userId,
    });

    final event = ClubEvent(
      id: eventRef.id,
      clubId: clubId,
      name: name,
      tableIds: tableIds,
      startTime: now,
      isPublic: isPublic,
      accessCode: accessCode,
      status: EventStatus.active,
      createdBy: userId,
    );

    // Also register with backend for real-time tracking
    await _registerEventWithBackend(event);

    return event;
  }

  /// Register event with backend for real-time ranking updates
  static Future<void> _registerEventWithBackend(ClubEvent event) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.serverUrl}/api/v1/clubs/${event.clubId}/events'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'event_id': event.id,  // Use Firestore ID so backend and Flutter match
          'club_id': event.clubId,
          'name': event.name,
          'table_ids': event.tableIds,
          'is_public': event.isPublic,
          'access_code': event.accessCode,
          'created_by': event.createdBy,
        }),
      );

      if (response.statusCode != 200) {
        // Log but don't fail - Firestore is the source of truth
        print('Failed to register event with backend: ${response.body}');
      }
    } catch (e) {
      print('Error registering event with backend: $e');
    }
  }

  /// Get all events for a club
  static Future<List<ClubEvent>> getClubEvents(String clubId) async {
    try {
      final snapshot = await _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_eventsSubcollection)
          .orderBy('startTime', descending: true)
          .get();

      return snapshot.docs.map((doc) => ClubEvent.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting club events: $e');
      return [];
    }
  }

  /// Get active events for a club
  static Future<List<ClubEvent>> getActiveEvents(String clubId) async {
    try {
      final snapshot = await _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_eventsSubcollection)
          .where('status', isEqualTo: 'active')
          .orderBy('startTime', descending: true)
          .get();

      return snapshot.docs.map((doc) => ClubEvent.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting active events: $e');
      return [];
    }
  }

  /// Get a specific event
  static Future<ClubEvent?> getEvent(String clubId, String eventId) async {
    try {
      final doc = await _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_eventsSubcollection)
          .doc(eventId)
          .get();

      if (doc.exists) {
        return ClubEvent.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting event: $e');
      return null;
    }
  }

  /// Update an event
  static Future<void> updateEvent(
    String clubId,
    String eventId, {
    String? name,
    List<String>? tableIds,
    bool? isPublic,
    String? accessCode,
    EventStatus? status,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (tableIds != null) updates['tableIds'] = tableIds;
    if (isPublic != null) updates['isPublic'] = isPublic;
    if (accessCode != null) updates['accessCode'] = accessCode;
    if (status != null) {
      updates['status'] = status.value;
      if (status == EventStatus.completed) {
        updates['endTime'] = Timestamp.now();
      }
    }

    if (updates.isNotEmpty) {
      await _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_eventsSubcollection)
          .doc(eventId)
          .update(updates);
    }

    // Also update backend
    await _updateEventOnBackend(eventId, updates);
  }

  /// Update event on backend
  static Future<void> _updateEventOnBackend(
    String eventId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final backendUpdates = <String, dynamic>{};
      if (updates.containsKey('name')) backendUpdates['name'] = updates['name'];
      if (updates.containsKey('tableIds')) {
        backendUpdates['table_ids'] = updates['tableIds'];
      }
      if (updates.containsKey('isPublic')) {
        backendUpdates['is_public'] = updates['isPublic'];
      }
      if (updates.containsKey('status')) {
        backendUpdates['status'] = updates['status'];
      }

      if (backendUpdates.isEmpty) return;

      await http.put(
        Uri.parse('${AppConfig.serverUrl}/api/v1/events/$eventId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(backendUpdates),
      );
    } catch (e) {
      print('Error updating event on backend: $e');
    }
  }

  /// Delete an event
  static Future<void> deleteEvent(String clubId, String eventId) async {
    await _firestore
        .collection(_clubsCollection)
        .doc(clubId)
        .collection(_eventsSubcollection)
        .doc(eventId)
        .delete();

    // Also delete from backend
    try {
      await http.delete(
        Uri.parse('${AppConfig.serverUrl}/api/v1/events/$eventId'),
      );
    } catch (e) {
      print('Error deleting event from backend: $e');
    }
  }

  /// Get current rankings from backend
  static Future<EventRankingsData?> getRankings(String eventId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.serverUrl}/api/v1/events/$eventId/rankings'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return EventRankingsData.fromMap(data);
      }
      return null;
    } catch (e) {
      print('Error getting rankings: $e');
      return null;
    }
  }

  /// Get public rankings (no auth required)
  static Future<EventRankingsData?> getPublicRankings(
    String eventId, {
    String? accessCode,
  }) async {
    try {
      var url = '${AppConfig.serverUrl}/api/v1/events/$eventId/public';
      if (accessCode != null) {
        url += '?access_code=$accessCode';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return EventRankingsData.fromMap(data);
      }
      return null;
    } catch (e) {
      print('Error getting public rankings: $e');
      return null;
    }
  }

  /// Sync players to an event (call when dashboard opens)
  static Future<EventRankingsData?> syncPlayers(
    String eventId,
    Map<String, List<Map<String, dynamic>>> tablePlayers,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.serverUrl}/api/v1/events/$eventId/sync-players'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'table_players': tablePlayers}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return EventRankingsData.fromMap(data);
      }
      return null;
    } catch (e) {
      print('Error syncing players: $e');
      return null;
    }
  }

  /// Update a player's stack (triggers ranking broadcast)
  static Future<bool> updatePlayerStack(
    String eventId,
    String playerId,
    int newStack,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('${AppConfig.serverUrl}/api/v1/events/$eventId/stacks'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'player_id': playerId,
          'new_stack': newStack,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating player stack: $e');
      return false;
    }
  }

  /// Listen to event updates in real-time
  static Stream<ClubEvent?> watchEvent(String clubId, String eventId) {
    return _firestore
        .collection(_clubsCollection)
        .doc(clubId)
        .collection(_eventsSubcollection)
        .doc(eventId)
        .snapshots()
        .map((doc) => doc.exists ? ClubEvent.fromFirestore(doc) : null);
  }

  /// Listen to all events for a club
  static Stream<List<ClubEvent>> watchClubEvents(String clubId) {
    return _firestore
        .collection(_clubsCollection)
        .doc(clubId)
        .collection(_eventsSubcollection)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ClubEvent.fromFirestore(doc)).toList());
  }

  /// Generate a public URL for an event
  static String getPublicUrl(String eventId, {String? accessCode}) {
    var url = '${AppConfig.serverUrl}/event/$eventId';
    if (accessCode != null) {
      url += '?code=$accessCode';
    }
    return url;
  }
}
