import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/dealer_session.dart';
import '../models/poker_table.dart';
import 'auth_service.dart';
import 'table_service.dart';
import 'seat_service.dart';
import 'event_service.dart';

/// Service for managing dealer sessions and hand logging
class DealerService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _dealerSessionsCollection = 'dealer_sessions';
  static const String _handsSubcollection = 'hands';

  /// Start a new dealer session at a table
  static Future<DealerSession> startSession({
    required String clubId,
    required String tableId,
    int smallBlind = 1,
    int bigBlind = 2,
    bool hasBBante = false,
    String gameType = 'cash',
    int buttonPosition = 1,
  }) async {
    final dealerId = AuthService.userId;
    if (dealerId == null) throw 'User not authenticated';

    // End any existing active sessions on this table first
    // This prevents multiple active sessions from coexisting
    await _endExistingActiveSessions(clubId, tableId);

    final now = DateTime.now();

    // Get current seated players
    final seatAssignments = await SeatService.getTableSeats(
      clubId: clubId,
      tableId: tableId,
    );

    // Convert seat assignments to seated players
    final players = <int, SeatedPlayer>{};
    for (final entry in seatAssignments.entries) {
      if (entry.value.isOccupied) {
        players[entry.key] = SeatedPlayer(
          playerId: entry.value.playerId!,
          displayName: entry.value.playerName ?? 'Player ${entry.key}',
          seatNumber: entry.key,
          stack: 0,  // Will be set when hand starts
          joinedAt: entry.value.assignedAt ?? now,
        );
      }
    }

    // Find active event that includes this table (for live rankings)
    final activeEvent = await EventService.getActiveEventForTable(clubId, tableId);
    final eventId = activeEvent?.id;

    // Use event's game type if available
    final effectiveGameType = activeEvent?.gameType ?? gameType;

    final session = DealerSession(
      id: '',
      clubId: clubId,
      tableId: tableId,
      dealerId: dealerId,
      dealerName: AuthService.userDisplayName,
      eventId: eventId,
      status: DealerSessionStatus.active,
      players: players,
      currentHandNumber: 0,
      currentHandId: null,
      buttonPosition: buttonPosition,
      smallBlind: smallBlind,
      bigBlind: bigBlind,
      hasBBante: hasBBante,
      gameType: effectiveGameType,
      startTime: now,
      endTime: null,
    );

    // Create session document
    final sessionRef = await _firestore
        .collection(_dealerSessionsCollection)
        .add(session.toFirestore());

    // Update table with session info
    await TableService.updateTable(
      clubId,
      tableId,
      status: TableStatus.active,
      dealerId: dealerId,
      currentSessionId: sessionRef.id,
    );

    return DealerSession(
      id: sessionRef.id,
      clubId: clubId,
      tableId: tableId,
      dealerId: dealerId,
      dealerName: AuthService.userDisplayName,
      eventId: eventId,
      status: DealerSessionStatus.active,
      players: players,
      currentHandNumber: 0,
      currentHandId: null,
      buttonPosition: buttonPosition,
      smallBlind: smallBlind,
      bigBlind: bigBlind,
      hasBBante: hasBBante,
      gameType: effectiveGameType,
      startTime: now,
      endTime: null,
    );
  }

  /// Pause a dealer session
  static Future<void> pauseSession(String sessionId) async {
    await _firestore
        .collection(_dealerSessionsCollection)
        .doc(sessionId)
        .update({
          'status': DealerSessionStatus.paused.value,
        });
  }

  /// Resume a paused session
  static Future<void> resumeSession(String sessionId) async {
    await _firestore
        .collection(_dealerSessionsCollection)
        .doc(sessionId)
        .update({
          'status': DealerSessionStatus.active.value,
        });
  }

  /// End a dealer session
  static Future<void> endSession(String sessionId) async {
    final sessionDoc = await _firestore
        .collection(_dealerSessionsCollection)
        .doc(sessionId)
        .get();

    if (!sessionDoc.exists) throw 'Session not found';

    final session = DealerSession.fromFirestore(sessionDoc);
    final endTime = DateTime.now();

    // Update session status
    await _firestore
        .collection(_dealerSessionsCollection)
        .doc(sessionId)
        .update({
          'status': DealerSessionStatus.ended.value,
          'endTime': FieldValue.serverTimestamp(),
        });

    // Create poker_sessions records for each player who participated
    // This allows players to see this session in their Session History
    for (final entry in session.players.entries) {
      final player = entry.value;
      // Only create records for real users (not manual/walk-up players)
      if (player.playerId.isNotEmpty && !player.playerId.startsWith('manual_')) {
        await _createPlayerSessionRecord(
          dealerSession: session,
          sessionId: sessionId,
          playerId: player.playerId,
          playerName: player.displayName,
          seatNumber: entry.key,
          endTime: endTime,
        );
      }
    }

    // Clear all seats at the table
    await SeatService.clearAllSeats(
      clubId: session.clubId,
      tableId: session.tableId,
    );

    // Clear table session info
    await TableService.clearTableSession(session.clubId, session.tableId);
  }

  /// End any existing active sessions on a table before starting a new one
  /// This prevents multiple active sessions from coexisting
  static Future<void> _endExistingActiveSessions(String clubId, String tableId) async {
    try {
      final existingSessions = await _firestore
          .collection(_dealerSessionsCollection)
          .where('clubId', isEqualTo: clubId)
          .where('tableId', isEqualTo: tableId)
          .where('status', isEqualTo: DealerSessionStatus.active.value)
          .get();

      for (final doc in existingSessions.docs) {
        try {
          await endSession(doc.id);
        } catch (e) {
          // Log but continue - don't block new session creation
          print('Error ending existing session ${doc.id}: $e');
          // At minimum, mark it as ended
          await _firestore
              .collection(_dealerSessionsCollection)
              .doc(doc.id)
              .update({'status': DealerSessionStatus.ended.value});
        }
      }
    } catch (e) {
      print('Error checking for existing sessions: $e');
    }
  }

  /// Create a poker_sessions record for a player who participated in a dealer session
  /// This links the player's participation to their session history
  static Future<void> _createPlayerSessionRecord({
    required DealerSession dealerSession,
    required String sessionId,
    required String playerId,
    required String playerName,
    required int seatNumber,
    required DateTime endTime,
  }) async {
    // Try to get event details for session name and game type
    String sessionName = 'Table Session';
    String gameType = dealerSession.gameType;

    if (dealerSession.eventId != null) {
      try {
        final event = await EventService.getEvent(
          dealerSession.clubId,
          dealerSession.eventId!,
        );
        if (event != null) {
          sessionName = event.name;
          gameType = event.gameType;
        }
      } catch (e) {
        print('Error fetching event for session name: $e');
      }
    }

    final sessionData = {
      'userId': playerId,
      'sessionName': sessionName,
      'smallBlind': dealerSession.smallBlind,
      'bigBlind': dealerSession.bigBlind,
      'hasBBante': dealerSession.hasBBante,
      'playerCount': dealerSession.playerCount,
      'ourSeatNumber': seatNumber,
      'gameType': gameType,
      'startTime': Timestamp.fromDate(dealerSession.startTime),
      'endTime': Timestamp.fromDate(endTime),
      'totalHands': dealerSession.currentHandNumber,
      'isIndividualSession': false,
      'isDealerSession': true,
      'dealerSessionId': sessionId,
      'clubId': dealerSession.clubId,
      'tableId': dealerSession.tableId,
      if (dealerSession.eventId != null) 'eventId': dealerSession.eventId,
    };

    await _firestore.collection('poker_sessions').add(sessionData);
  }

  /// Get a dealer session by ID
  static Future<DealerSession?> getSession(String sessionId) async {
    final doc = await _firestore
        .collection(_dealerSessionsCollection)
        .doc(sessionId)
        .get();

    if (doc.exists) {
      return DealerSession.fromFirestore(doc);
    }
    return null;
  }

  /// Start a new hand in the session
  static Future<String> startHand({
    required String sessionId,
    Map<int, double>? playerStacks,  // seat -> stack
    int? buttonPosition,  // Optional: pass from game state for accuracy
  }) async {
    final sessionRef = _firestore
        .collection(_dealerSessionsCollection)
        .doc(sessionId);

    final sessionDoc = await sessionRef.get();
    if (!sessionDoc.exists) throw 'Session not found';

    final session = DealerSession.fromFirestore(sessionDoc);
    final newHandNumber = session.currentHandNumber + 1;
    final effectiveButtonPosition = buttonPosition ?? session.buttonPosition;

    // Update session with current button position if provided
    if (buttonPosition != null && buttonPosition != session.buttonPosition) {
      await sessionRef.update({'buttonPosition': buttonPosition});
    }

    // Create hand document
    final handData = {
      'handNumber': newHandNumber,
      'buttonPosition': effectiveButtonPosition,
      'playerCount': session.playerCount,
      'smallBlind': session.smallBlind,
      'bigBlind': session.bigBlind,
      'hasBBante': session.hasBBante,
      'gameType': session.gameType,
      'startTime': FieldValue.serverTimestamp(),
      'endTime': null,
      'actions': [],
      'boardCards': null,
      'potAmount': 0.0,
      'winnerId': null,
      'status': 'active',
      'players': playerStacks?.map((k, v) => MapEntry(k.toString(), v)) ?? {},
    };

    final handRef = await sessionRef
        .collection(_handsSubcollection)
        .add(handData);

    // Update session with current hand info
    await sessionRef.update({
      'currentHandNumber': newHandNumber,
      'currentHandId': handRef.id,
    });

    return handRef.id;
  }

  /// Log an action in the current hand
  static Future<void> logAction({
    required String sessionId,
    required String handId,
    required int seatNumber,
    required String action,  // 'fold', 'check', 'call', 'bet', 'raise', 'all-in'
    required String street,  // 'preflop', 'flop', 'turn', 'river'
    double? amount,
    String? playerName,
    double? playerStack,  // Stack size at time of action
    String? playerPosition,  // Position name (BTN, SB, BB, UTG, etc.)
    String? transcript,  // Voice transcript for speech-logged actions
    double? confidence,  // Confidence score for speech recognition
  }) async {
    final handRef = _firestore
        .collection(_dealerSessionsCollection)
        .doc(sessionId)
        .collection(_handsSubcollection)
        .doc(handId);

    final actionData = {
      'player': seatNumber,
      'action': action,
      'street': street,
      'amount': amount,
      'playerName': playerName,
      'playerStack': playerStack,
      'playerPosition': playerPosition,
      'timestamp': DateTime.now().toIso8601String(),
      if (transcript != null) 'transcript': transcript,
      if (confidence != null) 'confidence': confidence,
    };

    await handRef.update({
      'actions': FieldValue.arrayUnion([actionData]),
    });
  }

  /// Set board cards for the current hand
  static Future<void> setBoardCards({
    required String sessionId,
    required String handId,
    List<String>? flop,
    String? turn,
    String? river,
  }) async {
    final handRef = _firestore
        .collection(_dealerSessionsCollection)
        .doc(sessionId)
        .collection(_handsSubcollection)
        .doc(handId);

    final boardCards = <String, dynamic>{};
    if (flop != null) boardCards['flop'] = flop;
    if (turn != null) boardCards['turn'] = turn;
    if (river != null) boardCards['river'] = river;

    if (boardCards.isNotEmpty) {
      await handRef.update({
        'boardCards': boardCards,
      });
    }
  }

  /// Complete a hand
  static Future<void> completeHand({
    required String sessionId,
    required String handId,
    required int winnerId,  // Seat number of winner
    double? potAmount,
    bool? isChoppedPot,
    List<int>? choppedWinners,
    Map<int, double>? individualShares,
  }) async {
    final sessionRef = _firestore
        .collection(_dealerSessionsCollection)
        .doc(sessionId);

    final handRef = sessionRef
        .collection(_handsSubcollection)
        .doc(handId);

    final updates = <String, dynamic>{
      'winnerId': winnerId,
      'status': 'completed',
      'endTime': FieldValue.serverTimestamp(),
    };

    if (potAmount != null) updates['potAmount'] = potAmount;
    if (isChoppedPot != null) updates['isChoppedPot'] = isChoppedPot;
    if (choppedWinners != null) updates['choppedWinners'] = choppedWinners;
    if (individualShares != null) {
      updates['individualShares'] = individualShares.map(
        (k, v) => MapEntry(k.toString(), v),
      );
    }

    await handRef.update(updates);

    // Clear current hand from session
    await sessionRef.update({
      'currentHandId': null,
    });

    // Advance button position
    final session = await getSession(sessionId);
    if (session != null) {
      final activeSeatNumbers = session.activePlayers
          .map((p) => p.seatNumber)
          .toList()
        ..sort();

      if (activeSeatNumbers.isNotEmpty) {
        final currentIdx = activeSeatNumbers.indexOf(session.buttonPosition);
        final nextIdx = (currentIdx + 1) % activeSeatNumbers.length;
        final newButtonPosition = activeSeatNumbers[nextIdx];

        await sessionRef.update({
          'buttonPosition': newButtonPosition,
        });
      }
    }
  }

  /// Update player stack in the session
  static Future<void> updatePlayerStack({
    required String sessionId,
    required int seatNumber,
    required double newStack,
  }) async {
    final sessionRef = _firestore
        .collection(_dealerSessionsCollection)
        .doc(sessionId);

    await sessionRef.update({
      'players.$seatNumber.stack': newStack,
    });
  }

  /// Update session blinds (for mid-session blind changes)
  static Future<void> updateSessionBlinds({
    required String sessionId,
    required int smallBlind,
    required int bigBlind,
  }) async {
    await _firestore
        .collection(_dealerSessionsCollection)
        .doc(sessionId)
        .update({
          'smallBlind': smallBlind,
          'bigBlind': bigBlind,
        });
  }

  /// Update session button position (for drag-drop button movement)
  static Future<void> updateSessionButtonPosition({
    required String sessionId,
    required int buttonPosition,
  }) async {
    await _firestore
        .collection(_dealerSessionsCollection)
        .doc(sessionId)
        .update({
          'buttonPosition': buttonPosition,
        });
  }

  /// Add a player to the session
  static Future<void> addPlayer({
    required String sessionId,
    required String odPlayerId,
    required String displayName,
    required int seatNumber,
    double initialStack = 0,
  }) async {
    final now = DateTime.now();
    final playerData = SeatedPlayer(
      playerId: odPlayerId,
      displayName: displayName,
      seatNumber: seatNumber,
      stack: initialStack,
      joinedAt: now,
    ).toMap();

    await _firestore
        .collection(_dealerSessionsCollection)
        .doc(sessionId)
        .update({
          'players.$seatNumber': playerData,
        });
  }

  /// Remove a player from the session
  static Future<void> removePlayer({
    required String sessionId,
    required int seatNumber,
  }) async {
    await _firestore
        .collection(_dealerSessionsCollection)
        .doc(sessionId)
        .update({
          'players.$seatNumber.isActive': false,
        });
  }

  /// Get all hands from a session
  static Future<List<Map<String, dynamic>>> getSessionHands(String sessionId) async {
    final snapshot = await _firestore
        .collection(_dealerSessionsCollection)
        .doc(sessionId)
        .collection(_handsSubcollection)
        .orderBy('handNumber')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      // Convert Timestamps to ISO strings (same format as FirebaseService.getSessionHands)
      return {
        'id': doc.id,
        'sessionId': sessionId,
        ...data,
        'startTime': (data['startTime'] as Timestamp?)?.toDate().toIso8601String() ?? DateTime.now().toIso8601String(),
        'endTime': (data['endTime'] as Timestamp?)?.toDate().toIso8601String(),
      };
    }).toList();
  }

  /// Watch session for real-time updates
  static Stream<DealerSession?> watchSession(String sessionId) {
    return _firestore
        .collection(_dealerSessionsCollection)
        .doc(sessionId)
        .snapshots()
        .map((doc) => doc.exists ? DealerSession.fromFirestore(doc) : null);
  }

  /// Watch current hand for real-time updates
  static Stream<Map<String, dynamic>?> watchCurrentHand(
    String sessionId,
    String handId,
  ) {
    return _firestore
        .collection(_dealerSessionsCollection)
        .doc(sessionId)
        .collection(_handsSubcollection)
        .doc(handId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          final data = doc.data()!;
          data['id'] = doc.id;
          return data;
        });
  }

  /// Get active sessions for a dealer
  static Future<List<DealerSession>> getDealerActiveSessions() async {
    final dealerId = AuthService.userId;
    if (dealerId == null) return [];

    final snapshot = await _firestore
        .collection(_dealerSessionsCollection)
        .where('dealerId', isEqualTo: dealerId)
        .where('status', isEqualTo: DealerSessionStatus.active.value)
        .get();

    return snapshot.docs
        .map((doc) => DealerSession.fromFirestore(doc))
        .toList();
  }

  /// Get active session for a table
  static Future<DealerSession?> getActiveSessionForTable({
    required String clubId,
    required String tableId,
  }) async {
    final snapshot = await _firestore
        .collection(_dealerSessionsCollection)
        .where('clubId', isEqualTo: clubId)
        .where('tableId', isEqualTo: tableId)
        .where('status', isEqualTo: DealerSessionStatus.active.value)
        .orderBy('startTime', descending: true)  // Get newest session first
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return DealerSession.fromFirestore(snapshot.docs.first);
    }
    return null;
  }

  /// Watch active session for a table (real-time)
  static Stream<DealerSession?> watchActiveSessionForTable({
    required String clubId,
    required String tableId,
  }) {
    return _firestore
        .collection(_dealerSessionsCollection)
        .where('clubId', isEqualTo: clubId)
        .where('tableId', isEqualTo: tableId)
        .where('status', isEqualTo: DealerSessionStatus.active.value)
        .orderBy('startTime', descending: true)  // Get newest session first
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            return DealerSession.fromFirestore(snapshot.docs.first);
          }
          return null;
        });
  }

  /// Watch the latest hand in a session (for players)
  static Stream<Map<String, dynamic>?> watchLatestHand(String sessionId) {
    return _firestore
        .collection(_dealerSessionsCollection)
        .doc(sessionId)
        .collection(_handsSubcollection)
        .orderBy('handNumber', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          final doc = snapshot.docs.first;
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        });
  }

  /// Save player-specific data for a hand (hole cards, notes, tags)
  static Future<void> savePlayerHandData({
    required String sessionId,
    required String handId,
    required String odPlayerId,
    String? card1,
    String? card2,
    String? notes,
    List<String>? tags,
  }) async {
    final playerDataRef = _firestore
        .collection(_dealerSessionsCollection)
        .doc(sessionId)
        .collection(_handsSubcollection)
        .doc(handId)
        .collection('player_data')
        .doc(odPlayerId);

    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (card1 != null && card2 != null) {
      data['holeCards'] = {'card1': card1, 'card2': card2};
    }
    if (notes != null) {
      data['notes'] = notes;
    }
    if (tags != null) {
      data['tags'] = tags;
    }

    await playerDataRef.set(data, SetOptions(merge: true));
  }

  /// Get player-specific data for a hand
  static Future<Map<String, dynamic>?> getPlayerHandData({
    required String sessionId,
    required String handId,
    required String odPlayerId,
  }) async {
    final doc = await _firestore
        .collection(_dealerSessionsCollection)
        .doc(sessionId)
        .collection(_handsSubcollection)
        .doc(handId)
        .collection('player_data')
        .doc(odPlayerId)
        .get();

    return doc.exists ? doc.data() : null;
  }

  /// Watch player-specific data for a hand
  static Stream<Map<String, dynamic>?> watchPlayerHandData({
    required String sessionId,
    required String handId,
    required String odPlayerId,
  }) {
    return _firestore
        .collection(_dealerSessionsCollection)
        .doc(sessionId)
        .collection(_handsSubcollection)
        .doc(handId)
        .collection('player_data')
        .doc(odPlayerId)
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }
}
