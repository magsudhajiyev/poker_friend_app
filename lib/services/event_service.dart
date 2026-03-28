import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/club_event.dart';
import '../models/dealer_session.dart';
import '../models/event_ranking.dart';
import '../models/final_standings.dart';
import '../config/app_config.dart';
import 'auth_service.dart';
import 'club_notification_service.dart';
import 'dealer_service.dart';
import 'seat_service.dart';
import 'waitlist_service.dart';

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
    String? stakes,
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
      stakes: stakes,
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

    // Clear all seats on newly assigned tables (ensure clean slate for new event)
    for (final tableId in tableIds) {
      await SeatService.clearAllSeats(clubId: clubId, tableId: tableId);
    }

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
      stakes: stakes,
      maxPlayers: maxPlayers,
      notifyMembers: notifyMembers,
      createdAt: now,
      gameType: gameType,
    );

    // Send notification to club members in background — don't block event creation
    if (notifyMembers) {
      ClubNotificationService.notifyEventCreated(
        clubId: clubId,
        event: event,
      ).catchError((_) {});
    }

    // Register with backend in background — Firestore is the source of truth
    if (tableIds.isNotEmpty) {
      _registerEventWithBackend(event);
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

    // Explicitly clear all seats on all tables (defensive cleanup)
    if (event != null) {
      for (final tableId in event.tableIds) {
        await SeatService.clearAllSeats(clubId: clubId, tableId: tableId);
      }
    }

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
    // Get event details before completion
    final event = await getEvent(clubId, eventId);

    // Get current rankings before ending sessions (they'll be cleared after)
    List<EventRanking>? currentRankings;
    try {
      currentRankings = await _getCurrentRankingsFromTables(clubId, eventId);
    } catch (e) {
      print('Error getting rankings for final standings: $e');
    }

    // End all active dealer sessions for this event
    await _endEventDealerSessions(eventId);

    // Explicitly clear all seats on all tables (defensive cleanup)
    if (event != null) {
      for (final tableId in event.tableIds) {
        await SeatService.clearAllSeats(clubId: clubId, tableId: tableId);
      }
    }

    // Save final standings snapshot if we have rankings
    if (currentRankings != null && currentRankings.isNotEmpty && event != null) {
      await saveFinalStandings(
        clubId: clubId,
        eventId: eventId,
        rankings: currentRankings,
        event: event,
      );
    }

    await updateEvent(clubId, eventId, status: EventStatus.completed);
  }

  /// Get current rankings from all tables in an event (for final standings snapshot)
  static Future<List<EventRanking>> _getCurrentRankingsFromTables(
    String clubId,
    String eventId,
  ) async {
    final event = await getEvent(clubId, eventId);
    if (event == null) return [];

    final List<EventRanking> allRankings = [];

    for (final tableId in event.tableIds) {
      try {
        // Get seated players from this table
        final seats = await SeatService.getTableSeats(clubId: clubId, tableId: tableId);

        for (final entry in seats.entries) {
          final seat = entry.value;
          if (seat.playerId != null && seat.playerId!.isNotEmpty) {
            final stack = seat.chipStack?.toInt() ?? 0;
            allRankings.add(EventRanking(
              eventId: eventId,
              playerId: seat.playerId!,
              playerName: seat.playerName ?? 'Player ${entry.key}',
              currentStack: stack,
              startingStack: event.startingStack?.toInt() ?? stack,
              rank: 0, // Will be calculated when sorting
              tableId: tableId,
              tableName: 'Table ${entry.key}',
              seatNumber: entry.key,
              lastUpdated: DateTime.now(),
              status: stack <= 0 ? PlayerRankingStatus.busted : PlayerRankingStatus.active,
            ));
          }
        }
      } catch (e) {
        print('Error getting seats for table $tableId: $e');
      }
    }

    // Sort by stack descending and assign ranks
    allRankings.sort((a, b) => b.currentStack.compareTo(a.currentStack));
    for (int i = 0; i < allRankings.length; i++) {
      // Create new ranking with updated rank (since rank is final)
      final r = allRankings[i];
      allRankings[i] = EventRanking(
        eventId: r.eventId,
        playerId: r.playerId,
        playerName: r.playerName,
        currentStack: r.currentStack,
        startingStack: r.startingStack,
        rank: i + 1,
        tableId: r.tableId,
        tableName: r.tableName,
        seatNumber: r.seatNumber,
        lastUpdated: r.lastUpdated,
        status: r.status,
        finishPosition: r.status == PlayerRankingStatus.busted ? i + 1 : null,
      );
    }

    return allRankings;
  }

  /// Save final standings when event completes
  static Future<void> saveFinalStandings({
    required String clubId,
    required String eventId,
    required List<EventRanking> rankings,
    required ClubEvent event,
  }) async {
    try {
      final finalStandings = FinalStandings.fromRankings(
        eventId: eventId,
        eventName: event.name,
        rankings: rankings,
        metadata: {
          'buyInAmount': event.buyInAmount,
          'startingStack': event.startingStack,
          'gameType': event.gameType,
        },
      );

      // Save to Firestore subcollection
      await _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_eventsSubcollection)
          .doc(eventId)
          .collection('final_standings')
          .doc('results')
          .set(finalStandings.toMap());
    } catch (e) {
      print('Error saving final standings: $e');
    }
  }

  /// Get final standings for a completed event
  static Future<FinalStandings?> getFinalStandings(String clubId, String eventId) async {
    try {
      final doc = await _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_eventsSubcollection)
          .doc(eventId)
          .collection('final_standings')
          .doc('results')
          .get();

      if (doc.exists && doc.data() != null) {
        return FinalStandings.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting final standings: $e');
      return null;
    }
  }

  /// Check if event has any active dealer sessions
  static Future<bool> hasActiveSessions(String eventId) async {
    try {
      final snapshot = await _firestore
          .collection('dealer_sessions')
          .where('eventId', isEqualTo: eventId)
          .where('status', isEqualTo: DealerSessionStatus.active.value)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking active sessions: $e');
      return false;
    }
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
    DateTime? startTime,
    String? description,
    String? location,
    double? buyInAmount,
    double? startingStack,
    String? stakes,
    int? maxPlayers,
    String? gameType,
    bool? notifyMembers,
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
    if (startTime != null) updates['startTime'] = Timestamp.fromDate(startTime);
    if (description != null) updates['description'] = description;
    if (location != null) updates['location'] = location;
    if (buyInAmount != null) updates['buyInAmount'] = buyInAmount;
    if (startingStack != null) updates['startingStack'] = startingStack;
    if (stakes != null) updates['stakes'] = stakes;
    if (maxPlayers != null) updates['maxPlayers'] = maxPlayers;
    if (gameType != null) updates['gameType'] = gameType;
    if (notifyMembers != null) updates['notifyMembers'] = notifyMembers;

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

  /// Add a table to a running event
  static Future<void> addTableToEvent({
    required String clubId,
    required String eventId,
    required String tableId,
  }) async {
    final event = await getEvent(clubId, eventId);
    if (event == null) throw 'Event not found';

    // Check if table is already in event
    if (event.tableIds.contains(tableId)) {
      throw 'Table is already assigned to this event';
    }

    // Add table to event
    final newTableIds = [...event.tableIds, tableId];
    await updateEvent(clubId, eventId, tableIds: newTableIds);

    // Clear seats on the newly added table (ensure clean slate)
    await SeatService.clearAllSeats(clubId: clubId, tableId: tableId);
  }

  /// Remove a table from a running event
  /// Moves all seated players to the waitlist before removing
  static Future<int> removeTableFromEvent({
    required String clubId,
    required String eventId,
    required String tableId,
  }) async {
    final event = await getEvent(clubId, eventId);
    if (event == null) throw 'Event not found';

    // Check if table is in event
    if (!event.tableIds.contains(tableId)) {
      throw 'Table is not assigned to this event';
    }

    // Get all seated players from this table
    final seats = await SeatService.getTableSeats(
      clubId: clubId,
      tableId: tableId,
    );

    int movedCount = 0;

    // Move seated players to waitlist
    for (final entry in seats.entries) {
      final seat = entry.value;
      if (seat.isOccupied && seat.playerId != null) {
        // Add to waitlist
        await WaitlistService.addPlayerToWaitlist(
          clubId: clubId,
          eventId: eventId,
          userId: seat.playerId!,
          displayName: seat.playerName ?? 'Player',
        );
        movedCount++;
      }
    }

    // Clear all seats on this table
    await SeatService.clearAllSeats(
      clubId: clubId,
      tableId: tableId,
    );

    // Remove table from event
    final newTableIds = event.tableIds.where((id) => id != tableId).toList();
    await updateEvent(clubId, eventId, tableIds: newTableIds);

    return movedCount;
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

  /// Get rankings directly from Firestore seat data (fallback when backend is empty)
  static Future<EventRankingsData?> getRankingsFromFirestore(
    String clubId,
    String eventId,
  ) async {
    try {
      final event = await getEvent(clubId, eventId);
      if (event == null) return null;

      final List<EventRanking> rankings = [];
      int totalChips = 0;

      for (final tableId in event.tableIds) {
        final seats = await SeatService.getTableSeats(
          clubId: clubId,
          tableId: tableId,
        );

        for (final entry in seats.entries) {
          final seat = entry.value;
          if (seat.playerId != null && seat.playerId!.isNotEmpty) {
            final stack = seat.chipStack?.toInt() ?? 0;
            totalChips += stack;
            rankings.add(EventRanking(
              eventId: eventId,
              playerId: seat.playerId!,
              playerName: seat.playerName ?? 'Player ${entry.key}',
              currentStack: stack,
              startingStack: event.startingStack?.toInt() ?? stack,
              rank: 0,
              tableId: tableId,
              seatNumber: entry.key,
              lastUpdated: DateTime.now(),
              status: stack <= 0
                  ? PlayerRankingStatus.busted
                  : PlayerRankingStatus.active,
            ));
          }
        }
      }

      if (rankings.isEmpty) return null;

      // Sort by stack and assign ranks
      rankings.sort((a, b) => b.currentStack.compareTo(a.currentStack));
      for (int i = 0; i < rankings.length; i++) {
        rankings[i] = rankings[i].copyWith(rank: i + 1);
      }

      return EventRankingsData(
        eventId: eventId,
        eventName: event.name,
        rankings: rankings,
        totalPlayers: rankings.length,
        totalChips: totalChips,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      print('Error getting rankings from Firestore: $e');
      return null;
    }
  }
}
