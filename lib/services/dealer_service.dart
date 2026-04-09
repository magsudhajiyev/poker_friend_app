import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/dealer_session.dart';
import '../models/poker_table.dart';
import 'app_data_cache.dart';
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

    // Find active event that includes this table (for live rankings and buy-in amount)
    final activeEvent = await EventService.getActiveEventForTable(clubId, tableId);
    final eventId = activeEvent?.id;
    // Use buyInAmount (actual dollars paid), NOT startingStack (chip count)
    final eventBuyIn = activeEvent?.buyInAmount ?? 0;

    // Convert seat assignments to seated players
    final players = <int, SeatedPlayer>{};
    for (final entry in seatAssignments.entries) {
      if (entry.value.isOccupied) {
        final chipStack = entry.value.chipStack ?? 0;
        players[entry.key] = SeatedPlayer(
          playerId: entry.value.playerId!,
          displayName: entry.value.playerName ?? 'Player ${entry.key}',
          seatNumber: entry.key,
          stack: chipStack,
          joinedAt: entry.value.assignedAt ?? now,
          // Analytics tracking
          initialStack: chipStack,
          buyInAmount: eventBuyIn > 0 ? eventBuyIn : chipStack,
          rebuyCount: 0,
          stackHistory: chipStack > 0 ? [{
            'timestamp': now.toIso8601String(),
            'stackSize': chipStack,
            'changeType': 'initial',
          }] : [],
        );
      }
    }

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

  /// Get paused session for a specific table (for dealer change)
  static Future<DealerSession?> getPausedSessionForTable({
    required String clubId,
    required String tableId,
  }) async {
    final snapshot = await _firestore
        .collection(_dealerSessionsCollection)
        .where('clubId', isEqualTo: clubId)
        .where('tableId', isEqualTo: tableId)
        .where('status', isEqualTo: DealerSessionStatus.paused.value)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return DealerSession.fromFirestore(snapshot.docs.first);
  }

  /// Resume session with new dealer (for dealer change handoff)
  static Future<void> resumeSessionWithNewDealer({
    required String sessionId,
    required String newDealerId,
    required String? newDealerName,
  }) async {
    await _firestore
        .collection(_dealerSessionsCollection)
        .doc(sessionId)
        .update({
          'dealerId': newDealerId,
          'dealerName': newDealerName,
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

    // Update session status
    await _firestore
        .collection(_dealerSessionsCollection)
        .doc(sessionId)
        .update({
          'status': DealerSessionStatus.ended.value,
          'endTime': FieldValue.serverTimestamp(),
        });

    // NOTE: Player session records are no longer created here to avoid duplicates.
    // They are created in EventService.completeEvent() for event sessions,
    // or via PokerSessionManager for non-event sessions.

    // Always clear seats when session ends — for event sessions, stack carry-over
    // is handled by getPlayerLastStack() which reads from the DealerSession document.
    await SeatService.clearAllSeats(
      clubId: session.clubId,
      tableId: session.tableId,
    );

    final isEventSession = session.eventId != null && session.eventId!.isNotEmpty;
    if (!isEventSession) {
      // Clear table session info (keep for event sessions so table stays linked)
      await TableService.clearTableSession(session.clubId, session.tableId);
    }
  }

  /// Look up a player's last chip stack from previous dealer sessions in the same event.
  /// Used during table breaks to auto-populate the stack when reseating a player.
  /// Returns null if the player was not found in any session for this event.
  static Future<double?> getPlayerLastStack({
    required String eventId,
    required String playerId,
  }) async {
    try {
      final sessions = await _firestore
          .collection(_dealerSessionsCollection)
          .where('eventId', isEqualTo: eventId)
          .get();

      double? lastStack;
      DateTime? latestTime;

      for (final doc in sessions.docs) {
        final session = DealerSession.fromFirestore(doc);
        for (final player in session.players.values) {
          if (player.playerId == playerId) {
            // Use the most recent session's stack
            if (latestTime == null || session.startTime.isAfter(latestTime)) {
              latestTime = session.startTime;
              lastStack = player.stack;
            }
          }
        }
      }

      return lastStack;
    } catch (e) {
      print('Error looking up player last stack: $e');
      return null;
    }
  }

  /// Get all dealer sessions (active + ended) for an event.
  /// Used to include broken-table players in live rankings.
  static Future<List<DealerSession>> getAllSessionsForEvent(String eventId) async {
    final snapshot = await _firestore
        .collection(_dealerSessionsCollection)
        .where('eventId', isEqualTo: eventId)
        .get();
    return snapshot.docs.map((d) => DealerSession.fromFirestore(d)).toList();
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

  /// Create a poker_sessions record for a player who participated in a dealer session.
  /// This links the player's participation to their session history.
  /// Called from EventService.completeEvent() to save sessions for all participants.
  static Future<void> createPlayerSessionRecord({
    required DealerSession dealerSession,
    required String sessionId,
    required String playerId,
    required String playerName,
    required int seatNumber,
    required DateTime endTime,
  }) async {
    // Get player data for analytics
    final player = dealerSession.players[seatNumber];
    if (player == null) return;

    // Try to get event details for session name and game type
    String sessionName = 'Table Session';
    String gameType = dealerSession.gameType;
    double eventBuyIn = player.buyInAmount;

    if (dealerSession.eventId != null) {
      try {
        final event = await EventService.getEvent(
          dealerSession.clubId,
          dealerSession.eventId!,
        );
        if (event != null) {
          sessionName = event.name;
          gameType = event.gameType;
          // Use event's buy-in amount (actual dollars), NOT startingStack (chips)
          if (event.buyInAmount != null && event.buyInAmount! > 0) {
            eventBuyIn = event.buyInAmount!;
          }
        }
      } catch (e) {
        print('Error fetching event for session name: $e');
      }
    }

    // Calculate total buy-in (initial + rebuys)
    final totalBuyIn = eventBuyIn * (1 + player.rebuyCount);

    // Build rebuys list from stack history
    final rebuys = <Map<String, dynamic>>[];
    for (final entry in player.stackHistory) {
      if (entry['changeType'] == 'rebuy') {
        rebuys.add({
          'timestamp': entry['timestamp'],
          'amount': entry['rebuyAmount'] ?? eventBuyIn,
        });
      }
    }

    // Check if a poker_sessions record already exists for this player
    // (created by PokerSessionManager on the dealer's device).
    // If so, update it with analytics fields instead of creating a duplicate.
    QuerySnapshot<Map<String, dynamic>>? existingQuery;
    try {
      existingQuery = await _firestore
          .collection('poker_sessions')
          .where('participantIds', arrayContains: playerId)
          .where('isLive', isEqualTo: true)
          .get();
    } catch (e) {
      print('Error checking existing sessions: $e');
    }

    // Find matching session by dealer session time overlap
    DocumentSnapshot<Map<String, dynamic>>? existingDoc;
    if (existingQuery != null) {
      for (final doc in existingQuery.docs) {
        final data = doc.data();
        // Match by dealerSessionId if stored, otherwise by time proximity
        if (data['dealerSessionId'] == sessionId) {
          existingDoc = doc;
          break;
        }
      }
    }

    final analyticsFields = {
      'isDealerSession': true,
      'dealerSessionId': sessionId,
      'buyInAmount': eventBuyIn,
      'totalBuyIn': totalBuyIn,
      'startingStack': player.initialStack,
      'currentStack': player.stack,
      'stackHistory': player.stackHistory,
      'rebuyCount': player.rebuyCount,
      'rebuys': rebuys,
      'clubId': dealerSession.clubId,
      'tableId': dealerSession.tableId,
      if (dealerSession.eventId != null) 'eventId': dealerSession.eventId,
    };

    if (existingDoc != null) {
      // Update existing session with analytics fields
      await existingDoc.reference.update(analyticsFields);
    } else {
      // Create new session record (player wasn't tracked by PokerSessionManager)
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
        'isLive': true,
        'participantIds': [playerId],
        ...analyticsFields,
      };

      await _firestore.collection('poker_sessions').add(sessionData);
    }
  }

  /// Merge all poker_sessions for a player in an event into one unified session.
  /// Called from completeEvent() to ensure each player has exactly one session.
  /// Handles: finding all sessions, merging poker_hands subcollections,
  /// building merged stackHistory, updating analytics, deleting duplicates.
  static Future<void> mergePlayerEventSessions({
    required String eventId,
    required String playerId,
    required String playerName,
    required List<DocumentSnapshot<Map<String, dynamic>>> allDealerSessionDocs,
    required DateTime endTime,
  }) async {
    // Parse dealer sessions sorted by startTime ascending
    final dealerSessions = allDealerSessionDocs
        .map((doc) => MapEntry(doc.id, DealerSession.fromFirestore(doc)))
        .toList()
      ..sort((a, b) => a.value.startTime.compareTo(b.value.startTime));

    // Collect all dealer session IDs for this event
    final allDealerSessionIds = dealerSessions.map((e) => e.key).toList();

    // Find ALL poker_sessions where this player participated
    final existingQuery = await _firestore
        .collection('poker_sessions')
        .where('participantIds', arrayContains: playerId)
        .where('isLive', isEqualTo: true)
        .get();

    // Filter to sessions belonging to this event (by eventId or dealerSessionId)
    final matchingSessions = <DocumentSnapshot<Map<String, dynamic>>>[];
    for (final doc in existingQuery.docs) {
      final data = doc.data();
      if (data['eventId'] == eventId) {
        matchingSessions.add(doc);
      } else if (allDealerSessionIds.contains(data['dealerSessionId'])) {
        matchingSessions.add(doc);
      }
    }

    if (matchingSessions.isEmpty) {
      // No existing session — create one via the latest dealer session
      final latestEntry = dealerSessions.last;
      final latestSession = latestEntry.value;
      final player = latestSession.players.values.firstWhere(
        (p) => p.playerId == playerId,
        orElse: () => latestSession.players.values.first,
      );
      await createPlayerSessionRecord(
        dealerSession: latestSession,
        sessionId: latestEntry.key,
        playerId: playerId,
        playerName: playerName,
        seatNumber: player.seatNumber,
        endTime: endTime,
      );
      // After creation, update with full dealerSessionIds list and eventId
      final createdQuery = await _firestore
          .collection('poker_sessions')
          .where('participantIds', arrayContains: playerId)
          .where('eventId', isEqualTo: eventId)
          .limit(1)
          .get();
      if (createdQuery.docs.isNotEmpty) {
        await createdQuery.docs.first.reference.update({
          'dealerSessionIds': allDealerSessionIds,
        });
      }
      return;
    }

    // Sort matching sessions by startTime ascending — earliest is primary
    matchingSessions.sort((a, b) {
      final aTime = (a.data()?['startTime'] as Timestamp?)?.toDate() ?? DateTime(2100);
      final bTime = (b.data()?['startTime'] as Timestamp?)?.toDate() ?? DateTime(2100);
      return aTime.compareTo(bTime);
    });

    final primaryDoc = matchingSessions.first;
    final secondarySessions = matchingSessions.skip(1).toList();

    // Determine hand number offset from primary session's existing hands
    int handOffset = 0;
    final primaryHandsSnapshot = await primaryDoc.reference
        .collection('poker_hands')
        .orderBy('handNumber', descending: true)
        .limit(1)
        .get();
    if (primaryHandsSnapshot.docs.isNotEmpty) {
      handOffset = (primaryHandsSnapshot.docs.first.data()['handNumber'] as int? ?? 0);
    }

    // Move hands from secondary sessions into primary, re-numbering
    for (final secondaryDoc in secondarySessions) {
      final secondaryHands = await secondaryDoc.reference
          .collection('poker_hands')
          .orderBy('handNumber')
          .get();

      for (final handDoc in secondaryHands.docs) {
        final handData = Map<String, dynamic>.from(handDoc.data());
        final originalHandNum = handData['handNumber'] as int? ?? 0;
        handData['handNumber'] = originalHandNum + handOffset;
        handData['_sourceSessionId'] = secondaryDoc.id; // track origin

        await primaryDoc.reference.collection('poker_hands').add(handData);
        await handDoc.reference.delete();
      }

      // Update offset for next secondary session
      if (secondaryHands.docs.isNotEmpty) {
        final lastHand = secondaryHands.docs.last.data();
        handOffset += (lastHand['handNumber'] as int? ?? 0);
      }

      // Delete secondary poker_sessions doc
      await secondaryDoc.reference.delete();
    }

    // Build merged stack history from all dealer sessions
    final mergedStackHistory = <Map<String, dynamic>>[];
    int stackHandOffset = 0;
    for (final entry in dealerSessions) {
      final session = entry.value;
      // Find the player in this dealer session
      final player = session.players.values.cast<SeatedPlayer?>().firstWhere(
        (p) => p!.playerId == playerId,
        orElse: () => null,
      );
      if (player == null) continue;

      for (final histEntry in player.stackHistory) {
        final adjusted = Map<String, dynamic>.from(histEntry);
        final originalHand = histEntry['handNumber'] as int? ?? 0;
        // Skip duplicate 'initial' entries after the first session —
        // previous session's last entry already has this stack value
        if (adjusted['changeType'] == 'initial' && mergedStackHistory.isNotEmpty) {
          continue;
        }
        adjusted['handNumber'] = originalHand + stackHandOffset;
        mergedStackHistory.add(adjusted);
      }
      stackHandOffset += session.currentHandNumber;
    }

    // Get event details for session name
    String sessionName = 'Tournament Session';
    double eventBuyIn = 0;
    if (dealerSessions.isNotEmpty) {
      final firstSession = dealerSessions.first.value;
      if (firstSession.eventId != null) {
        try {
          final event = await EventService.getEvent(
            firstSession.clubId,
            firstSession.eventId!,
          );
          if (event != null) {
            sessionName = event.name;
            if (event.buyInAmount != null && event.buyInAmount! > 0) {
              eventBuyIn = event.buyInAmount!;
            }
          }
        } catch (_) {}
      }
    }

    // Get first and last player data for analytics
    SeatedPlayer? firstPlayer;
    SeatedPlayer? lastPlayer;
    int totalRebuyCount = 0;
    for (final entry in dealerSessions) {
      final player = entry.value.players.values.cast<SeatedPlayer?>().firstWhere(
        (p) => p!.playerId == playerId,
        orElse: () => null,
      );
      if (player == null) continue;
      firstPlayer ??= player;
      lastPlayer = player;
      totalRebuyCount += player.rebuyCount;
    }

    final totalBuyIn = eventBuyIn > 0
        ? eventBuyIn * (1 + totalRebuyCount)
        : (firstPlayer?.initialStack ?? 0) * (1 + totalRebuyCount);

    // Count total hands across all dealer sessions for this player
    int totalHands = 0;
    for (final entry in dealerSessions) {
      final session = entry.value;
      if (session.players.values.any((p) => p.playerId == playerId)) {
        totalHands += session.currentHandNumber;
      }
    }

    // Build rebuys list from merged stack history
    final rebuys = <Map<String, dynamic>>[];
    for (final entry in mergedStackHistory) {
      if (entry['changeType'] == 'rebuy') {
        rebuys.add({
          'timestamp': entry['timestamp'],
          'amount': entry['rebuyAmount'] ?? eventBuyIn,
        });
      }
    }

    // Update primary session with merged data
    await primaryDoc.reference.update({
      'eventId': eventId,
      'isDealerSession': true,
      'dealerSessionId': dealerSessions.last.key, // latest for backward compat
      'dealerSessionIds': allDealerSessionIds,
      'sessionName': sessionName,
      'stackHistory': mergedStackHistory,
      'startingStack': firstPlayer?.initialStack ?? 0,
      'currentStack': lastPlayer?.stack ?? 0,
      'buyInAmount': eventBuyIn > 0 ? eventBuyIn : (firstPlayer?.buyInAmount ?? 0),
      'totalBuyIn': totalBuyIn,
      'rebuyCount': totalRebuyCount,
      'rebuys': rebuys,
      'totalHands': totalHands,
      'endTime': Timestamp.fromDate(endTime),
      'clubId': dealerSessions.first.value.clubId,
    });

    // Invalidate cache so session history and home screen show fresh data
    AppDataCache.markSessionsDirty();
    AppDataCache.markHomeDirty();
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

  /// Overwrite the entire actions array in Firestore (used after undo/rollback).
  /// This replaces the array atomically so player screens see the corrected state.
  static Future<void> syncActions({
    required String sessionId,
    required String handId,
    required List<Map<String, dynamic>> actions,
  }) async {
    final handRef = _firestore
        .collection(_dealerSessionsCollection)
        .doc(sessionId)
        .collection(_handsSubcollection)
        .doc(handId);

    await handRef.update({
      'actions': actions,
    });
  }

  /// Overwrite board cards in Firestore, including clearing removed cards.
  /// Unlike setBoardCards, this always writes all fields (even empty/null).
  static Future<void> clearBoardCards({
    required String sessionId,
    required String handId,
    required List<String> flop,
    String? turn,
    String? river,
  }) async {
    final handRef = _firestore
        .collection(_dealerSessionsCollection)
        .doc(sessionId)
        .collection(_handsSubcollection)
        .doc(handId);

    await handRef.update({
      'boardCards': {
        'flop': flop,
        'turn': turn,
        'river': river,
      },
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
    double? preflopPot,
    double? flopPot,
    double? turnPot,
    double? riverPot,
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
    if (preflopPot != null && preflopPot > 0) updates['preflopPot'] = preflopPot;
    if (flopPot != null && flopPot > 0) updates['flopPot'] = flopPot;
    if (turnPot != null && turnPot > 0) updates['turnPot'] = turnPot;
    if (riverPot != null && riverPot > 0) updates['riverPot'] = riverPot;
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
    double? buyInAmount,  // Override buy-in amount if different from initial stack
  }) async {
    final now = DateTime.now();

    // Get session to check for event buy-in amount
    double effectiveBuyIn = buyInAmount ?? initialStack;
    final session = await getSession(sessionId);
    if (session?.eventId != null) {
      try {
        final event = await EventService.getEvent(
          session!.clubId,
          session.eventId!,
        );
        if (event?.startingStack != null && event!.startingStack! > 0) {
          effectiveBuyIn = event.startingStack!.toDouble();
        }
      } catch (e) {
        // Use initial stack as fallback
      }
    }

    final playerData = SeatedPlayer(
      playerId: odPlayerId,
      displayName: displayName,
      seatNumber: seatNumber,
      stack: initialStack,
      joinedAt: now,
      initialStack: initialStack,
      buyInAmount: effectiveBuyIn,
      rebuyCount: 0,
      stackHistory: initialStack > 0 ? [{
        'timestamp': now.toIso8601String(),
        'stackSize': initialStack,
        'changeType': 'initial',
      }] : [],
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

  /// Add stack history entry for a player (call after each hand completes)
  static Future<void> addStackHistoryEntry({
    required String sessionId,
    required int seatNumber,
    required double stackSize,
    required String changeType,  // 'hand', 'rebuy', 'initial'
    int? handNumber,
  }) async {
    final entry = {
      'timestamp': DateTime.now().toIso8601String(),
      'stackSize': stackSize,
      'changeType': changeType,
      if (handNumber != null) 'handNumber': handNumber,
    };

    await _firestore
        .collection(_dealerSessionsCollection)
        .doc(sessionId)
        .update({
          'players.$seatNumber.stackHistory': FieldValue.arrayUnion([entry]),
        });
  }

  /// Record a rebuy for a player
  static Future<void> recordRebuy({
    required String sessionId,
    required int seatNumber,
    required double newStack,
    double? rebuyAmount,
  }) async {
    final now = DateTime.now();

    // Get session to calculate rebuy amount if not provided
    final session = await getSession(sessionId);
    double effectiveRebuyAmount = rebuyAmount ?? newStack;

    if (session != null) {
      final player = session.players[seatNumber];
      if (player != null && rebuyAmount == null) {
        // Rebuy amount is the new stack (since player busted to 0)
        effectiveRebuyAmount = newStack;
      }
    }

    await _firestore
        .collection(_dealerSessionsCollection)
        .doc(sessionId)
        .update({
          'players.$seatNumber.rebuyCount': FieldValue.increment(1),
          'players.$seatNumber.stack': newStack,
          'players.$seatNumber.isActive': true,
          'players.$seatNumber.stackHistory': FieldValue.arrayUnion([{
            'timestamp': now.toIso8601String(),
            'stackSize': newStack,
            'changeType': 'rebuy',
            'rebuyAmount': effectiveRebuyAmount,
          }]),
        });
  }

  /// Update all player stacks in bulk (call after hand completes)
  static Future<void> updateAllPlayerStacks({
    required String sessionId,
    required Map<int, double> playerStacks,  // seat -> stack
    required int handNumber,
  }) async {
    final updates = <String, dynamic>{};

    for (final entry in playerStacks.entries) {
      final seat = entry.key;
      final stack = entry.value;

      // Update stack
      updates['players.$seat.stack'] = stack;
    }

    if (updates.isNotEmpty) {
      await _firestore
          .collection(_dealerSessionsCollection)
          .doc(sessionId)
          .update(updates);

      // Add stack history entries for each player
      for (final entry in playerStacks.entries) {
        await addStackHistoryEntry(
          sessionId: sessionId,
          seatNumber: entry.key,
          stackSize: entry.value,
          changeType: 'hand',
          handNumber: handNumber,
        );
      }
    }
  }

  /// Get all hands from a session
  /// Includes player-specific data (hole cards, notes, tags) for the current user
  static Future<List<Map<String, dynamic>>> getSessionHands(String sessionId) async {
    final snapshot = await _firestore
        .collection(_dealerSessionsCollection)
        .doc(sessionId)
        .collection(_handsSubcollection)
        .orderBy('handNumber')
        .get();

    // Build playerNames map from dealer session's players
    Map<String, String> playerNamesMap = {};
    Map<String, String> playerIdsMap = {};
    try {
      final sessionDoc = await _firestore
          .collection(_dealerSessionsCollection)
          .doc(sessionId)
          .get();
      if (sessionDoc.exists) {
        final session = DealerSession.fromFirestore(sessionDoc);
        for (final entry in session.players.entries) {
          final seatStr = entry.key.toString();
          playerNamesMap[seatStr] = entry.value.displayName;
          if (entry.value.playerId.isNotEmpty) {
            playerIdsMap[seatStr] = entry.value.playerId;
          }
        }
      }
    } catch (e) {
      // Ignore - hands still valid without player names
    }

    final currentUserId = AuthService.userId;
    final hands = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();

      // Convert Timestamps to ISO strings (same format as FirebaseService.getSessionHands)
      // Handle both Timestamp and String formats for flexibility
      String? parseTimestamp(dynamic value) {
        if (value == null) return null;
        if (value is Timestamp) return value.toDate().toIso8601String();
        if (value is String) return value;
        return null;
      }

      final hand = {
        'id': doc.id,
        'sessionId': sessionId,
        ...data,
        'startTime': parseTimestamp(data['startTime']) ?? DateTime.now().toIso8601String(),
        'endTime': parseTimestamp(data['endTime']),
      };

      // Inject playerNames/playerIds from dealer session if not already present
      if (hand['playerNames'] == null && playerNamesMap.isNotEmpty) {
        hand['playerNames'] = playerNamesMap;
      }
      if (hand['playerIds'] == null && playerIdsMap.isNotEmpty) {
        hand['playerIds'] = playerIdsMap;
      }

      // Fetch player-specific data (hole cards, notes, tags) for current user
      if (currentUserId != null) {
        try {
          final playerData = await getPlayerHandData(
            sessionId: sessionId,
            handId: doc.id,
            odPlayerId: currentUserId,
          );

          if (playerData != null) {
            // Merge hole cards as 'ourHoleCards' (matches expected format)
            final holeCards = playerData['holeCards'] as Map<String, dynamic>?;
            if (holeCards != null) {
              hand['ourHoleCards'] = holeCards;
            }

            // Merge notes and tags
            if (playerData['notes'] != null) {
              hand['notes'] = playerData['notes'];
            }
            if (playerData['tags'] != null) {
              hand['tags'] = playerData['tags'];
            }
          }
        } catch (e) {
          // Ignore errors fetching player data - hand is still valid
        }
      }

      hands.add(hand);
    }

    return hands;
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

  /// Watch active or paused session for a table (real-time)
  /// Includes paused sessions so players stay connected during dealer handoff
  static Stream<DealerSession?> watchActiveSessionForTable({
    required String clubId,
    required String tableId,
  }) {
    return _firestore
        .collection(_dealerSessionsCollection)
        .where('clubId', isEqualTo: clubId)
        .where('tableId', isEqualTo: tableId)
        .where('status', whereIn: [
          DealerSessionStatus.active.value,
          DealerSessionStatus.paused.value,
        ])
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
