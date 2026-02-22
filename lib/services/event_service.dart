import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/club_event.dart';
import '../models/dealer_session.dart';
import '../models/event_ranking.dart';
import '../config/app_config.dart';
import 'auth_service.dart';
import 'club_notification_service.dart';
import 'dealer_service.dart';

/// Service for managing club events and live rankings
class EventService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _clubsCollection = 'clubs';
  static const String _eventsSubcollection = 'events';

  /// Create a new event for a club (legacy method for compatibility)
  static Future<ClubEvent> createEvent({
    required String clubId,
    required String name,
    required List<String> tableIds,
    bool isPublic = false,
    String? accessCode,
  }) async {
    return createEventWithDetails(
      clubId: clubId,
      name: name,
      startTime: DateTime.now(),
      tableIds: tableIds,
      isPublic: isPublic,
      accessCode: accessCode,
      notifyMembers: false,  // Legacy behavior - no notification
    );
  }

  /// Create a new event with full details and optional member notification
  static Future<ClubEvent> createEventWithDetails({
    required String clubId,
    required String name,
    required DateTime startTime,
    List<String> tableIds = const [],
    String? description,
    String? location,
    DateTime? endTime,
    double? buyInAmount,
    double? startingStack,
    int? maxPlayers,
    bool isPublic = false,
    String? accessCode,
    bool notifyMembers = true,
    String gameType = 'cash',
  }) async {
    final userId = AuthService.userId;
    if (userId == null) throw 'User not authenticated';

    final now = DateTime.now();

    final eventData = ClubEvent(
      id: '',
      clubId: clubId,
      name: name,
      tableIds: tableIds,
      startTime: startTime,
      endTime: endTime,
      isPublic: isPublic,
      accessCode: accessCode,
      status: EventStatus.scheduled,
      createdBy: userId,
      description: description,
      location: location,
      buyInAmount: buyInAmount,
      startingStack: startingStack,
      maxPlayers: maxPlayers,
      notifyMembers: notifyMembers,
      createdAt: now,
      gameType: gameType,
    );

    // Create in Firestore
    final eventRef = await _firestore
        .collection(_clubsCollection)
        .doc(clubId)
        .collection(_eventsSubcollection)
        .add(eventData.toFirestore());

    final event = ClubEvent(
      id: eventRef.id,
      clubId: clubId,
      name: name,
      tableIds: tableIds,
      startTime: startTime,
      endTime: endTime,
      isPublic: isPublic,
      accessCode: accessCode,
      status: EventStatus.scheduled,
      createdBy: userId,
      description: description,
      location: location,
      buyInAmount: buyInAmount,
      startingStack: startingStack,
      maxPlayers: maxPlayers,
      notifyMembers: notifyMembers,
      createdAt: now,
      gameType: gameType,
    );

    // Send notification to club members if enabled
    if (notifyMembers) {
      await ClubNotificationService.notifyEventCreated(
        clubId: clubId,
        event: event,
      );
    }

    // Also register with backend for real-time tracking if it has tables
    if (tableIds.isNotEmpty) {
      await _registerEventWithBackend(event);
    }

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

  /// Get active (live) events for a club
  static Future<List<ClubEvent>> getActiveEvents(String clubId) async {
    try {
      // Fetch all active events (avoid composite index requirement)
      final snapshot = await _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_eventsSubcollection)
          .where('status', isEqualTo: 'active')
          .get();

      // Sort locally by start time
      final events = snapshot.docs
          .map((doc) => ClubEvent.fromFirestore(doc))
          .toList();
      events.sort((a, b) => b.startTime.compareTo(a.startTime));

      return events;
    } catch (e) {
      print('Error getting active events: $e');
      return [];
    }
  }

  /// Get active event that includes a specific table
  /// Returns the first active event that contains the given tableId
  static Future<ClubEvent?> getActiveEventForTable(String clubId, String tableId) async {
    try {
      // Get all active events for the club
      final activeEvents = await getActiveEvents(clubId);

      // Find the first event that includes this table
      for (final event in activeEvents) {
        if (event.tableIds.contains(tableId)) {
          return event;
        }
      }

      return null;
    } catch (e) {
      print('Error getting active event for table: $e');
      return null;
    }
  }

  /// Get upcoming (scheduled) events for a club
  static Future<List<ClubEvent>> getUpcomingEvents(String clubId) async {
    try {
      // Fetch all scheduled events (avoid composite index requirement)
      final snapshot = await _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_eventsSubcollection)
          .where('status', isEqualTo: 'scheduled')
          .get();

      // Sort locally to avoid composite index
      final events = snapshot.docs
          .map((doc) => ClubEvent.fromFirestore(doc))
          .toList();

      // Sort by start time (soonest first)
      events.sort((a, b) => a.startTime.compareTo(b.startTime));

      return events;
    } catch (e) {
      print('Error getting upcoming events: $e');
      return [];
    }
  }

  /// Get past (completed) events for a club
  static Future<List<ClubEvent>> getPastEvents(String clubId, {int limit = 20}) async {
    try {
      // Fetch all events and filter locally (avoid composite index)
      final snapshot = await _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_eventsSubcollection)
          .get();

      // Filter for completed/cancelled and sort locally
      final events = snapshot.docs
          .map((doc) => ClubEvent.fromFirestore(doc))
          .where((e) => e.status == EventStatus.completed || e.status == EventStatus.cancelled)
          .toList();

      // Sort by start time (most recent first)
      events.sort((a, b) => b.startTime.compareTo(a.startTime));

      // Apply limit
      return events.take(limit).toList();
    } catch (e) {
      print('Error getting past events: $e');
      return [];
    }
  }

  /// Start an event (change status from scheduled to active)
  static Future<void> startEvent(String clubId, String eventId) async {
    await updateEvent(clubId, eventId, status: EventStatus.active);

    // Send notification that event has started
    final event = await getEvent(clubId, eventId);
    if (event != null && event.notifyMembers) {
      await ClubNotificationService.notifyEventStarted(
        clubId: clubId,
        event: event,
      );
    }
  }

  /// Cancel an event
  static Future<void> cancelEvent(String clubId, String eventId) async {
    final event = await getEvent(clubId, eventId);

    // End all active dealer sessions for this event first
    await _endEventDealerSessions(eventId);

    await updateEvent(clubId, eventId, status: EventStatus.cancelled);

    // Send notification that event was cancelled
    if (event != null && event.notifyMembers) {
      await ClubNotificationService.notifyEventCancelled(
        clubId: clubId,
        event: event,
      );
    }
  }

  /// Complete an event (finish a live event)
  static Future<void> completeEvent(String clubId, String eventId) async {
    // End all active dealer sessions for this event first
    await _endEventDealerSessions(eventId);

    await updateEvent(clubId, eventId, status: EventStatus.completed);
  }

  /// End all active dealer sessions associated with an event
  static Future<void> _endEventDealerSessions(String eventId) async {
    try {
      // Query all active AND paused dealer sessions with this eventId
      final sessions = await _firestore
          .collection('dealer_sessions')
          .where('eventId', isEqualTo: eventId)
          .where('status', whereIn: [
            DealerSessionStatus.active.value,
            DealerSessionStatus.paused.value,
          ])
          .get();

      // End each session (this also clears seats and table state)
      for (final doc in sessions.docs) {
        try {
          final session = DealerSession.fromFirestore(doc);

          // If there's an active hand, mark it as cancelled
          if (session.currentHandId != null) {
            try {
              await _firestore
                  .collection('dealer_sessions')
                  .doc(doc.id)
                  .collection('hands')
                  .doc(session.currentHandId)
                  .update({
                    'status': 'cancelled',
                    'endTime': FieldValue.serverTimestamp(),
                    'note': 'Event ended mid-hand',
                  });
            } catch (e) {
              // Hand may not exist or already completed
            }
          }

          await DealerService.endSession(doc.id);
        } catch (e) {
          // Force status update even if full cleanup fails
          await _firestore
              .collection('dealer_sessions')
              .doc(doc.id)
              .update({
                'status': DealerSessionStatus.ended.value,
                'endTime': FieldValue.serverTimestamp(),
              });
        }
      }
    } catch (e) {
      print('Error ending event dealer sessions: $e');
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
