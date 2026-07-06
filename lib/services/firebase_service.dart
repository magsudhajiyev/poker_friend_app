import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/poker_game_state.dart';
import '../models/game_types.dart';
import 'auth_service.dart';
import 'display_identity_service.dart';
import 'local_storage_service.dart';
import 'logger_service.dart';
import 'opponent_service.dart';
import 'opponent_stats_service.dart';
import 'stats_calculator.dart';
import 'user_stats_service.dart';
import 'app_data_cache.dart';
import 'subscription_service.dart';
import 'free_tier_limits.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collection references
  static const String _sessionsCollection = 'poker_sessions';
  static const String _handsCollection = 'poker_hands';

  // Create a new poker session
  static Future<String> createSession({
    required double smallBlind,
    required double bigBlind,
    required int playerCount,
    int? ourSeatNumber,
    GameType gameType = GameType.cash,
    bool isIndividualSession = false,
    String? sessionName,
    double? startingStack,
    bool hasBBante = false,
    double? totalBuyIn,
    bool isLive = false,  // True for dealer/live sessions
    String? dealerSessionId, // Links to dealer_sessions for hole card lookup
    String? eventId, // Links to club event for tournament session grouping
  }) async {
    try {
      final userId = AuthService.userId;
      if (userId == null) throw 'User not authenticated';
      
      final sessionData = {
        'userId': userId,
        'userEmail': AuthService.currentUser?.email,
        'userName': DisplayIdentityService.cachedDisplayIdentity,
        'smallBlind': smallBlind,
        'bigBlind': bigBlind,
        'hasBBante': hasBBante,
        'playerCount': playerCount,
        'ourSeatNumber': ourSeatNumber,
        'gameType': gameType.value,
        'startTime': FieldValue.serverTimestamp(),
        'endTime': null,
        'totalHands': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'isIndividualSession': isIndividualSession,
        'isLive': isLive,  // True for dealer/live sessions
        'sessionName': sessionName ?? (isIndividualSession ? 'Individual Session' : ''), // Always set sessionName
      };

      // For live sessions, initialize participant tracking
      if (isLive) {
        sessionData['participantIds'] = <String>[]; // Will be populated when players join
        sessionData['participationPeriods'] = <String, dynamic>{}; // Will track join/leave periods
        if (dealerSessionId != null) {
          sessionData['dealerSessionId'] = dealerSessionId;
        }
        if (eventId != null) {
          sessionData['eventId'] = eventId;
        }
      }

      // Add individual session specific fields
      if (isIndividualSession) {
        sessionData.addAll({
          'startingStack': startingStack ?? 0.0,
          'currentStack': startingStack ?? 0.0,
          'buyInAmount': totalBuyIn ?? 0.0, // Money paid for buy-in
          'totalBuyIn': totalBuyIn ?? 0.0, // Total money invested (starts with buy-in)
          'handsLogged': 0,
          'biggestPot': 0.0,
          'sessionStatus': 'active',
        });
      } else {
        // For full hand logging sessions, save buy-in amount and total invested (NOT chip count)
        if (totalBuyIn != null && totalBuyIn > 0) {
          sessionData.addAll({
            'buyInAmount': totalBuyIn, // Money paid for buy-in
            'totalBuyIn': totalBuyIn,  // Total money invested (starts with buy-in)
          });
        }
        // Also save starting stack if provided (for reference, but not used in total invested)
        if (startingStack != null && startingStack > 0) {
          sessionData['startingStack'] = startingStack;
        }
      }

      final sessionRef = await _firestore.collection(_sessionsCollection).add(sessionData);
      AppDataCache.markHomeDirty();
      AppDataCache.markSessionsDirty();
      AppDataCache.markStatsDirty();
      return sessionRef.id;
    } catch (e) {
      await LoggerService.error('Error creating session', e, StackTrace.current);
      rethrow;
    }
  }

  // Delete a session (used when navigating away without logging any hands)
  static Future<void> deleteSession(String sessionId) async {
    try {
      final userId = AuthService.userId;
      if (userId == null) return;

      final sessionRef = _firestore.collection(_sessionsCollection).doc(sessionId);

      // Verify the session belongs to this user before deleting
      final sessionDoc = await sessionRef.get();
      if (!sessionDoc.exists) return;

      final sessionData = sessionDoc.data();
      if (sessionData?['userId'] != userId) return;

      // Delete any hands in this session
      final handsSnapshot = await sessionRef.collection(_handsCollection).get();
      for (final handDoc in handsSnapshot.docs) {
        await handDoc.reference.delete();
      }

      // Delete the session
      await sessionRef.delete();
    } catch (e) {
      // Silently fail - deletion errors are not critical
    }
  }

  // Save a completed poker hand
  static Future<void> saveHand({
    required String sessionId,
    required int handNumber,
    required int buttonPosition,
    required List<Map<String, dynamic>> actions,
    required int playerCount,
    Map<String, dynamic>? boardCards,
    Map<String, dynamic>? ourHoleCards,
    Map<String, dynamic>? showdownData,
    bool? reachedShowdown,
    double? potAmount,
    double? preflopPot,
    double? flopPot,
    double? turnPot,
    double? riverPot,
    int? winnerId,
    String? heroPositionName,
    int? heroSeatNumber, // Seat number for stats comparison
    Map<int, String>? playerNames,
    double? smallBlind,
    double? bigBlind,
    String? gameType,
    // Chopped pot fields
    bool? isChoppedPot,
    List<int>? choppedWinners,
    Map<int, double>? individualShares,
    double? sharePerWinner,
    // Hand annotations
    bool? isStarred,
    List<String>? tags,
    String? notes,
    // Dealer mode: map of seat → Firebase userId for all players
    Map<int, String>? playerIds,
  }) async {
    try {
      final handData = {
        'handNumber': handNumber,
        'buttonPosition': buttonPosition,
        'playerCount': playerCount,
        'actions': actions,
        'startTime': FieldValue.serverTimestamp(),
        'endTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      if (boardCards != null) {
        handData['boardCards'] = boardCards;
      }
      
      if (ourHoleCards != null) {
        handData['ourHoleCards'] = ourHoleCards;
      }
      
      if (showdownData != null) {
        handData['showdownData'] = showdownData;
      }
      
      if (reachedShowdown != null) {
        handData['reachedShowdown'] = reachedShowdown;
      }
      
      // Add pot tracking data
      if (potAmount != null) {
        handData['potAmount'] = potAmount;
      }
      
      if (preflopPot != null) {
        handData['preflopPot'] = preflopPot;
      }
      
      if (flopPot != null) {
        handData['flopPot'] = flopPot;
      }
      
      if (turnPot != null) {
        handData['turnPot'] = turnPot;
      }
      
      if (riverPot != null) {
        handData['riverPot'] = riverPot;
      }
      
      // Add other missing fields
      if (winnerId != null) {
        handData['winnerId'] = winnerId;
      }
      
      if (heroPositionName != null) {
        handData['heroPositionName'] = heroPositionName;
      }

      if (heroSeatNumber != null) {
        handData['heroSeatNumber'] = heroSeatNumber;
      }
      
      if (playerNames != null) {
        handData['playerNames'] = playerNames.map((key, value) => MapEntry(key.toString(), value));
      }
      
      if (smallBlind != null) {
        handData['smallBlind'] = smallBlind;
      }
      
      if (bigBlind != null) {
        handData['bigBlind'] = bigBlind;
      }
      
      if (gameType != null) {
        handData['gameType'] = gameType;
      }

      // Add chopped pot fields
      if (isChoppedPot != null) {
        handData['isChoppedPot'] = isChoppedPot;
      }

      if (choppedWinners != null) {
        handData['choppedWinners'] = choppedWinners;
      }

      if (individualShares != null) {
        handData['individualShares'] = individualShares.map((key, value) => MapEntry(key.toString(), value));
      }

      if (sharePerWinner != null) {
        handData['sharePerWinner'] = sharePerWinner;
      }

      // Add hand annotations
      if (isStarred != null) {
        handData['isStarred'] = isStarred;
      }

      if (tags != null && tags.isNotEmpty) {
        handData['tags'] = tags;
      }

      if (notes != null && notes.isNotEmpty) {
        handData['notes'] = notes;
      }

      // Store playerIds for dealer mode (seat → Firebase userId)
      if (playerIds != null && playerIds.isNotEmpty) {
        handData['playerIds'] = playerIds.map((k, v) => MapEntry(k.toString(), v));
      }

      // Save to session's subcollection instead of top-level collection
      // Use timestamp to ensure unique document ID even if handNumber repeats
      final handDocId = 'hand_${handNumber}_${DateTime.now().millisecondsSinceEpoch}';

      await _firestore
          .collection(_sessionsCollection)
          .doc(sessionId)
          .collection(_handsCollection)
          .doc(handDocId)
          .set(handData);

      // Update session total hands count
      await _firestore.collection(_sessionsCollection).doc(sessionId).update({
        'totalHands': FieldValue.increment(1),
      });

      // Check if this is dealer-assisted mode (playerIds present)
      final isDealerMode = playerIds != null && playerIds.isNotEmpty;

      if (isDealerMode) {
        // Dealer mode: update stats for ALL seated players (including dealer if playing)
        final activeSeats = playerNames?.keys.toList() ?? [];
        await _updateAllPlayerStatsFromHand(
          actions: actions,
          playerIds: playerIds,
          buttonPosition: buttonPosition,
          activeSeats: activeSeats,
          winnerId: winnerId,
          choppedWinners: choppedWinners,
        );
      } else {
        // Normal mode: update stats for hero only
        await _updateUserStatsFromHand(
          actions: actions,
          heroPositionName: heroPositionName,
          heroSeatNumber: heroSeatNumber,
          winnerId: winnerId,
          playerNames: playerNames,
          choppedWinners: choppedWinners,
        );
      }

      // Update opponent statistics incrementally (both modes)
      await _updateOpponentStatsFromHand(
        actions: actions,
        playerNames: playerNames,
        reachedShowdown: reachedShowdown,
      );

      unawaited(LoggerService.logEvent('hand_saved', parameters: {
        'session_id': sessionId,
        'hand_number': handNumber,
      }));

      AppDataCache.markHomeDirty();
      AppDataCache.markSessionsDirty();
      AppDataCache.markStatsDirty();
      AppDataCache.markOpponentsDirty();
      AppDataCache.markOpponentHandsDirty();
    } catch (e) {
      await LoggerService.error('Error saving hand', e, StackTrace.current);
      rethrow;
    }
  }

  // Update hand annotations (star, tags, notes)
  static Future<void> updateHandAnnotations({
    required String sessionId,
    required String handId,
    bool? isStarred,
    List<String>? tags,
    String? notes,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (isStarred != null) {
        updateData['isStarred'] = isStarred;
      }

      if (tags != null) {
        updateData['tags'] = tags;
      }

      if (notes != null) {
        updateData['notes'] = notes;
      }

      if (updateData.isEmpty) return;

      await _firestore
          .collection(_sessionsCollection)
          .doc(sessionId)
          .collection(_handsCollection)
          .doc(handId)
          .update(updateData);

    } catch (e) {
      await LoggerService.error('Error updating hand annotations', e, StackTrace.current);
      rethrow;
    }
  }

  // Save an action during a hand (real-time updates)
  static Future<void> saveAction({
    required String sessionId,
    required int handNumber,
    required int player,
    required String action,
    required String street,
    required int buttonPosition,
  }) async {
    try {
      await _firestore.collection('live_actions').add({
        'sessionId': sessionId,
        'handNumber': handNumber,
        'player': player,
        'action': action,
        'street': street,
        'buttonPosition': buttonPosition,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
    } catch (e) {
      await LoggerService.error('Error saving action', e, StackTrace.current);
      // Don't rethrow - action logging shouldn't break the game
    }
  }

  // End a session
  static Future<void> endSession(String sessionId) async {
    try {
      // Get session data to calculate duration
      final sessionDoc = await _firestore.collection(_sessionsCollection).doc(sessionId).get();

      await _firestore.collection(_sessionsCollection).doc(sessionId).update({
        'endTime': FieldValue.serverTimestamp(),
      });

      // Update user stats with session count and duration (only if user actually participated)
      if (sessionDoc.exists) {
        final sessionData = sessionDoc.data()!;
        final startTime = sessionData['startTime'] as Timestamp?;
        final userId = AuthService.userId;

        if (startTime != null && userId != null) {
          // Check if user actually participated in the session
          final ourSeatNumber = sessionData['ourSeatNumber'] as int?;
          final participantIds = (sessionData['participantIds'] as List<dynamic>?)?.cast<String>() ?? [];
          final totalHands = sessionData['totalHands'] as int? ?? 0;

          // User participated if:
          // 1. They had a seat assigned (regular sessions), OR
          // 2. They are in participantIds (live/dealer sessions), OR
          // 3. They logged at least one hand
          final userParticipated = ourSeatNumber != null ||
              participantIds.contains(userId) ||
              totalHands > 0;

          if (userParticipated) {
            final duration = DateTime.now().difference(startTime.toDate()).inMinutes;
            await UserStatsService.updateStatsAtomic(
              userId: userId,
              sessionsDelta: 1,
              playTimeMinutesDelta: duration,
            );
          }
        }
      }

      AppDataCache.markHomeDirty();
      AppDataCache.markSessionsDirty();
      AppDataCache.markStatsDirty();
    } catch (e) {
      await LoggerService.error('Error ending session', e, StackTrace.current);
      rethrow;
    }
  }

  // Get session details
  static Future<Map<String, dynamic>?> getSession(String sessionId) async {
    try {
      final doc = await _firestore.collection(_sessionsCollection).doc(sessionId).get();
      if (doc.exists) {
        return {'id': doc.id, ...doc.data()!};
      }
      return null;
    } catch (e) {
      await LoggerService.error('Error getting session', e, StackTrace.current);
      return null;
    }
  }

  // Get all hands for a session
  static Future<List<Map<String, dynamic>>> getSessionHands(String sessionId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_sessionsCollection)
          .doc(sessionId)
          .collection(_handsCollection)
          .orderBy('handNumber', descending: false)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'sessionId': sessionId, // Include sessionId for updates
          ...data,
          'startTime': _parseTimestamp(data['startTime']) ?? DateTime.now().toIso8601String(),
          'endTime': _parseTimestamp(data['endTime']),
        };
      }).toList();
    } catch (e) {
      await LoggerService.error('Error getting session hands from Firebase', e, StackTrace.current);
      return [];
    }
  }

  /// Helper to parse timestamp from either Firestore Timestamp or String format
  static String? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    } else if (value is String) {
      return value; // Already a string
    }
    return null;
  }

  // Mock hand data for offline testing  
  static List<Map<String, dynamic>> _getMockHandData() {
    return [
      {
        'id': 'hand_1',
        'handNumber': 1,
        'buttonPosition': 1,
        'playerCount': 6,
        'startTime': DateTime.now().subtract(Duration(minutes: 25)).toIso8601String(),
        'endTime': DateTime.now().subtract(Duration(minutes: 23)).toIso8601String(),
        'actions': [
          {'player': 3, 'action': 'bet', 'street': 'preflop', 'timestamp': DateTime.now().subtract(Duration(minutes: 25)).toIso8601String()},
          {'player': 4, 'action': 'call', 'street': 'preflop', 'timestamp': DateTime.now().subtract(Duration(minutes: 24)).toIso8601String()},
          {'player': 1, 'action': 'fold', 'street': 'preflop', 'timestamp': DateTime.now().subtract(Duration(minutes: 24)).toIso8601String()},
          {'player': 3, 'action': 'bet', 'street': 'flop', 'timestamp': DateTime.now().subtract(Duration(minutes: 23)).toIso8601String()},
          {'player': 4, 'action': 'fold', 'street': 'flop', 'timestamp': DateTime.now().subtract(Duration(minutes: 23)).toIso8601String()},
        ],
      },
      {
        'id': 'hand_2',
        'handNumber': 2,
        'buttonPosition': 2,
        'playerCount': 6,
        'startTime': DateTime.now().subtract(Duration(minutes: 20)).toIso8601String(),
        'endTime': DateTime.now().subtract(Duration(minutes: 18)).toIso8601String(),
        'actions': [
          {'player': 4, 'action': 'bet', 'street': 'preflop', 'timestamp': DateTime.now().subtract(Duration(minutes: 20)).toIso8601String()},
          {'player': 5, 'action': 'raise', 'street': 'preflop', 'timestamp': DateTime.now().subtract(Duration(minutes: 19)).toIso8601String()},
          {'player': 1, 'action': 'call', 'street': 'preflop', 'timestamp': DateTime.now().subtract(Duration(minutes: 19)).toIso8601String()},
          {'player': 4, 'action': 'fold', 'street': 'preflop', 'timestamp': DateTime.now().subtract(Duration(minutes: 19)).toIso8601String()},
          {'player': 1, 'action': 'bet', 'street': 'flop', 'timestamp': DateTime.now().subtract(Duration(minutes: 18)).toIso8601String()},
          {'player': 5, 'action': 'call', 'street': 'flop', 'timestamp': DateTime.now().subtract(Duration(minutes: 18)).toIso8601String()},
        ],
      }
    ];
  }

  // Get recent sessions
  static Future<List<Map<String, dynamic>>> getRecentSessions({int limit = 10}) async {
    try {
      final querySnapshot = await _firestore
          .collection(_sessionsCollection)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      
      return querySnapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      await LoggerService.error('Error getting recent sessions', e, StackTrace.current);
      return [];
    }
  }

  // Test Firebase connection
  static Future<bool> testConnection() async {
    try {
      await _firestore.collection('test').doc('connection').set({
        'timestamp': FieldValue.serverTimestamp(),
        'message': 'Firebase connection test successful',
      });
      
      return true;
    } catch (e) {
      return false;
    }
  }

  // Convert game state to saveable actions list
  static List<Map<String, dynamic>> convertGameStateToActions(PokerGameState gameState) {
    // This will be implemented based on how you want to structure the action log
    // For now, return empty list
    return [];
  }

  // Get all sessions for current user (for session history)
  // Includes both owned sessions and sessions where user participated (dealer events)
  static Future<List<Map<String, dynamic>>> getAllSessions() async {
    try {
      final userId = AuthService.userId;
      if (userId == null) throw 'User not authenticated';

      // Query 1: Sessions the user owns (manual logging, individual sessions)
      final ownedSnapshot = await _firestore
          .collection(_sessionsCollection)
          .where('userId', isEqualTo: userId)
          .get();

      // Query 2: Sessions the user participated in (dealer events)
      final participatedSnapshot = await _firestore
          .collection(_sessionsCollection)
          .where('participantIds', arrayContains: userId)
          .get();

      // Combine and deduplicate (use Map to avoid duplicates)
      final allDocs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

      // For owned sessions, filter out live/dealer sessions where user didn't play
      for (final doc in ownedSnapshot.docs) {
        final data = doc.data();
        final isLive = data['isLive'] as bool? ?? false;
        final participantIds = (data['participantIds'] as List<dynamic>?)?.cast<String>() ?? [];

        // Include if:
        // 1. Not a live session (regular manual logging), OR
        // 2. Live session AND user is in participantIds (dealer played)
        if (!isLive || participantIds.contains(userId)) {
          allDocs[doc.id] = doc;
        }
      }

      // Always include sessions where user participated
      for (final doc in participatedSnapshot.docs) {
        allDocs[doc.id] = doc;
      }

      // Sort in memory to avoid needing Firebase index
      final docs = allDocs.values.toList();
      docs.sort((a, b) {
        final aTimeRaw = a.data()['startTime'];
        final bTimeRaw = b.data()['startTime'];
        DateTime? aTime;
        DateTime? bTime;

        // Handle both Timestamp and String formats
        if (aTimeRaw is Timestamp) {
          aTime = aTimeRaw.toDate();
        } else if (aTimeRaw is String) {
          aTime = DateTime.tryParse(aTimeRaw);
        }
        if (bTimeRaw is Timestamp) {
          bTime = bTimeRaw.toDate();
        } else if (bTimeRaw is String) {
          bTime = DateTime.tryParse(bTimeRaw);
        }

        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime); // Descending order
      });

      // Convert documents to session data
      var sessions = docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'startTime': _parseTimestamp(data['startTime']) ?? DateTime.now().toIso8601String(),
          'endTime': _parseTimestamp(data['endTime']),
        };
      }).toList();

      // Apply session history filtering based on subscription tier
      final cutoff = FreeTierLimits.sessionHistoryCutoff();
      if (cutoff != null) {
        sessions = sessions.where((session) {
          final startTimeStr = session['startTime'] as String?;
          if (startTimeStr == null) return false;

          final startTime = DateTime.tryParse(startTimeStr);
          return startTime != null && startTime.isAfter(cutoff);
        }).toList();
      }

      return sessions;
    } catch (e) {
      await LoggerService.error('Error getting user sessions from Firebase', e, StackTrace.current);
      debugPrint('Falling back to local storage...');

      // Fallback to local storage
      try {
        var localSessions = await LocalStorageService.getUserSessions();

        // Apply session history filtering to local storage fallback
        final cutoff = FreeTierLimits.sessionHistoryCutoff();
        if (cutoff != null) {
          localSessions = localSessions.where((session) {
            final startTimeStr = session['startTime'] as String?;
            if (startTimeStr == null) return false;

            final startTime = DateTime.tryParse(startTimeStr);
            return startTime != null && startTime.isAfter(cutoff);
          }).toList();
        }

        return localSessions;
      } catch (localError) {
        await LoggerService.error('Error getting sessions from local storage', localError, StackTrace.current);
        return _getMockOfflineData();
      }
    }
  }

  /// Add a participant to a session (for dealer events)
  /// Called when a player joins the table
  static Future<void> addSessionParticipant({
    required String sessionId,
    required String participantId,
    required int joinedAtHand,
  }) async {
    try {
      // First, add to participantIds array
      await _firestore.collection(_sessionsCollection).doc(sessionId).update({
        'participantIds': FieldValue.arrayUnion([participantId]),
      });

      // Then, add the participation period
      // Firestore doesn't support arrayUnion on nested fields, so we need to read and update
      final doc = await _firestore.collection(_sessionsCollection).doc(sessionId).get();
      final data = doc.data() ?? {};
      final participationPeriods = Map<String, dynamic>.from(data['participationPeriods'] ?? {});

      // Get existing periods for this participant or create new list
      final existingPeriods = List<Map<String, dynamic>>.from(
        participationPeriods[participantId] ?? []
      );

      // Add new participation period
      existingPeriods.add({
        'joinedAtHand': joinedAtHand,
        'leftAtHand': null, // Still playing
      });

      participationPeriods[participantId] = existingPeriods;

      await doc.reference.update({
        'participationPeriods': participationPeriods,
      });
    } catch (e) {
      await LoggerService.error('Error adding session participant', e, StackTrace.current);
      // Don't rethrow - this is a non-critical operation
    }
  }

  /// Mark a participant as having left the session (bust/removed)
  /// Called when a player busts or is removed from the table
  static Future<void> markParticipantLeft({
    required String sessionId,
    required String participantId,
    required int leftAtHand,
  }) async {
    try {
      final doc = await _firestore.collection(_sessionsCollection).doc(sessionId).get();
      final data = doc.data() ?? {};
      final participationPeriods = Map<String, dynamic>.from(data['participationPeriods'] ?? {});

      final periods = List<Map<String, dynamic>>.from(
        participationPeriods[participantId] ?? []
      );

      // Update the last period's leftAtHand (if it's still null)
      if (periods.isNotEmpty && periods.last['leftAtHand'] == null) {
        periods.last['leftAtHand'] = leftAtHand;
        participationPeriods[participantId] = periods;

        await doc.reference.update({
          'participationPeriods': participationPeriods,
        });
      }
    } catch (e) {
      await LoggerService.error('Error marking participant left', e, StackTrace.current);
      // Don't rethrow - this is a non-critical operation
    }
  }

  // Mock data for offline testing
  static List<Map<String, dynamic>> _getMockOfflineData() {
    return [
      {
        'id': 'offline_demo_1',
        'smallBlind': 1,
        'bigBlind': 2,
        'playerCount': 6,
        'totalHands': 0,
        'startTime': DateTime.now().subtract(Duration(minutes: 30)).toIso8601String(),
        'endTime': null,
      }
    ];
  }

  // Analytics - get player statistics
  static Future<Map<String, dynamic>> getPlayerStats(String sessionId, int playerId) async {
    try {
      final hands = await getSessionHands(sessionId);
      int handsPlayed = 0;
      int folds = 0;
      int bets = 0;
      int calls = 0;
      int raises = 0;
      int checks = 0;

      for (var hand in hands) {
        List<dynamic> actions = hand['actions'] ?? [];
        bool playerActed = false;
        
        for (var action in actions) {
          if (action['player'] == playerId) {
            playerActed = true;
            String actionType = action['action'];
            switch (actionType) {
              case 'fold': folds++; break;
              case 'bet': bets++; break;
              case 'call': calls++; break;
              case 'raise': raises++; break;
              case 'check': checks++; break;
            }
          }
        }
        
        if (playerActed) handsPlayed++;
      }

      return {
        'playerId': playerId,
        'handsPlayed': handsPlayed,
        'folds': folds,
        'bets': bets,
        'calls': calls,
        'raises': raises,
        'checks': checks,
        'totalActions': folds + bets + calls + raises + checks,
      };
    } catch (e) {
      await LoggerService.error('Error getting player stats', e, StackTrace.current);
      return {};
    }
  }

  // Update session name
  static Future<void> updateSessionName(String sessionId, String sessionName) async {
    try {
      final userId = AuthService.userId;
      if (userId == null) throw 'User not authenticated';
      
      await _firestore.collection(_sessionsCollection).doc(sessionId).update({
        'sessionName': sessionName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
    } catch (e) {
      await LoggerService.error('Error updating session name', e, StackTrace.current);
      rethrow;
    }
  }

  // Update session with progress data
  static Future<void> updateSession({
    required String sessionId,
    int? handsLogged,
    double? biggestPot,
    List<Map<String, dynamic>>? stackHistory,
    double? totalBuyIn,
    double? averageGrowth,
  }) async {
    try {
      final userId = AuthService.userId;
      if (userId == null) throw 'User not authenticated';

      Map<String, dynamic> updateData = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (handsLogged != null) {
        updateData['handsLogged'] = handsLogged;
      }

      if (biggestPot != null) {
        updateData['biggestPot'] = biggestPot;
      }

      if (stackHistory != null) {
        updateData['stackHistory'] = stackHistory;
      }

      if (totalBuyIn != null) {
        updateData['totalBuyIn'] = totalBuyIn;
      }

      if (averageGrowth != null) {
        updateData['averageGrowth'] = averageGrowth;
      }

      await _firestore.collection(_sessionsCollection).doc(sessionId).update(updateData);

    } catch (e) {
      await LoggerService.error('Error updating session', e, StackTrace.current);
      rethrow;
    }
  }

  // Update individual session data
  static Future<void> updateIndividualSession({
    required String sessionId,
    double? currentStack,
    int? handsLogged,
    double? biggestPot,
    String? sessionStatus,
    double? smallBlind,
    double? bigBlind,
    bool? hasBBante,
    List<Map<String, dynamic>>? rebuys,
    double? totalBuyIn,
    List<Map<String, dynamic>>? stackHistory,
    double? averageGrowth,
    int? finishedPlace,
    int? fieldSize,
    double? prizeWon,
  }) async {
    try {
      final userId = AuthService.userId;
      if (userId == null) throw 'User not authenticated';

      Map<String, dynamic> updateData = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (currentStack != null) {
        updateData['currentStack'] = currentStack;
      }
      if (handsLogged != null) {
        updateData['handsLogged'] = handsLogged;
      }
      if (biggestPot != null) {
        updateData['biggestPot'] = biggestPot;
      }
      if (sessionStatus != null) {
        updateData['sessionStatus'] = sessionStatus;
      }
      if (smallBlind != null) {
        updateData['smallBlind'] = smallBlind;
      }
      if (bigBlind != null) {
        updateData['bigBlind'] = bigBlind;
      }
      if (hasBBante != null) {
        updateData['hasBBante'] = hasBBante;
      }
      if (rebuys != null) {
        updateData['rebuys'] = rebuys;
      }
      if (totalBuyIn != null) {
        updateData['totalBuyIn'] = totalBuyIn;
      }
      if (stackHistory != null) {
        updateData['stackHistory'] = stackHistory;
      }
      if (averageGrowth != null) {
        updateData['averageGrowth'] = averageGrowth;
      }
      if (finishedPlace != null) {
        updateData['finishedPlace'] = finishedPlace;
      }
      if (fieldSize != null) {
        updateData['fieldSize'] = fieldSize;
      }
      if (prizeWon != null) {
        updateData['prizeWon'] = prizeWon;
      }

      await _firestore.collection(_sessionsCollection).doc(sessionId).update(updateData);

    } catch (e) {
      await LoggerService.error('Error updating individual session', e, StackTrace.current);
      rethrow;
    }
  }

  // Add rebuy record to session
  static Future<void> addRebuyToSession({
    required String sessionId,
    required double rebuyAmount,
    required double newStackSize,
    required double newTotalBuyIn,
  }) async {
    try {
      final userId = AuthService.userId;
      if (userId == null) throw 'User not authenticated';

      // Create rebuy record
      final now = DateTime.now();
      final rebuyRecord = {
        'timestamp': now.millisecondsSinceEpoch,
        'amount': rebuyAmount,
        'stackSize': newStackSize,
        'createdAt': now.toIso8601String(),
      };

      // Create stack history entry
      final stackHistoryEntry = {
        'timestamp': now.millisecondsSinceEpoch,
        'stackSize': newStackSize,
        'changeType': 'rebuy',
        'changeAmount': rebuyAmount,
        'createdAt': now.toIso8601String(),
      };

      // Get current document to check if arrays exist
      final docRef = _firestore.collection(_sessionsCollection).doc(sessionId);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        throw 'Session document not found';
      }

      final data = docSnap.data() as Map<String, dynamic>;

      // Initialize arrays if they don't exist, otherwise append to existing
      final currentRebuys = data['rebuys'] as List<dynamic>? ?? [];
      final currentStackHistory = data['stackHistory'] as List<dynamic>? ?? [];

      currentRebuys.add(rebuyRecord);
      currentStackHistory.add(stackHistoryEntry);

      // Update session with rebuy data
      await docRef.update({
        'rebuys': currentRebuys,
        'stackHistory': currentStackHistory,
        'currentStack': newStackSize,
        'totalBuyIn': newTotalBuyIn,
        'updatedAt': FieldValue.serverTimestamp(),
      });

    } catch (e) {
      await LoggerService.error('Error adding rebuy to session', e, StackTrace.current);
      rethrow;
    }
  }

  // Clear all session data for current user
  static Future<void> clearUserSessions() async {
    try {
      final userId = AuthService.userId;
      if (userId == null) throw 'User not authenticated';
      
      // Get all sessions for this user
      final sessionsSnapshot = await _firestore
          .collection(_sessionsCollection)
          .where('userId', isEqualTo: userId)
          .get();
      
      // Delete all hands for each session and then delete the session
      for (final sessionDoc in sessionsSnapshot.docs) {
        final sessionId = sessionDoc.id;
        
        // Delete all hands in this session
        final handsSnapshot = await _firestore
            .collection(_sessionsCollection)
            .doc(sessionId)
            .collection(_handsCollection)
            .get();
        
        for (final handDoc in handsSnapshot.docs) {
          await handDoc.reference.delete();
        }
        
        // Delete the session itself
        await sessionDoc.reference.delete();
      }
    } catch (e) {
      await LoggerService.error('Error clearing user sessions from Firebase', e, StackTrace.current);
      rethrow;
    }
  }

  /// Process hand actions and update opponent stats incrementally
  /// This is the key optimization - O(1) updates instead of O(n) recalculation
  static Future<void> _updateOpponentStatsFromHand({
    required List<Map<String, dynamic>> actions,
    required Map<int, String>? playerNames,
    bool? reachedShowdown,
  }) async {
    if (playerNames == null || actions.isEmpty) return;

    try {
      // Get all saved opponents first (only track stats for saved opponents)
      final savedOpponents = await OpponentService.getAllOpponents();
      final savedOpponentNames = savedOpponents.map((o) => o.name).toSet();

      // Group actions by opponent ID to batch updates
      Map<String, Map<String, int>> opponentDeltas = {};
      Set<String> handParticipants = {}; // Track which opponents participated in this hand
      // Per-hand boolean flags for VPIP/PFR (must be 0 or 1 per hand, not per action)
      Map<String, bool> opponentDidVpip = {};
      Map<String, bool> opponentDidPfr = {};

      // Process each action to determine stat deltas
      for (final action in actions) {
        final playerId = action['player'] as int?;
        final actionType = action['action'] as String?;
        final street = action['street'] as String?;

        if (playerId == null || actionType == null || street == null) continue;

        final playerName = playerNames[playerId];
        if (playerName == null || playerName.isEmpty) continue;

        // Only track stats for saved opponents (not positions like UTG, CO, BTN)
        if (!savedOpponentNames.contains(playerName)) continue;

        // Find the opponent ID for this name
        final opponent = savedOpponents.firstWhere((o) => o.name == playerName);
        final opponentId = opponent.id;

        // Track hand participants (count each opponent only once per hand)
        handParticipants.add(opponentId);

        // Initialize deltas for this opponent if not exists
        opponentDeltas[opponentId] ??= {
          'handsDelta': 0,
          'vpipDelta': 0,
          'pfrDelta': 0,
          'aggressionDelta': 0,
          'passiveDelta': 0,
          'foldDelta': 0,
          'checkDelta': 0,
          'callDelta': 0,
          'betDelta': 0,
          'raiseDelta': 0,
          'threeBetDelta': 0,
          'cbetDelta': 0,
          'fold3betDelta': 0,
          // New opportunity counters
          'walksCountDelta': 0,
          'threeBetOpportunityDelta': 0,
          'facing3BetCountDelta': 0,
          'cbetOpportunityDelta': 0,
          'stealCountDelta': 0,
          'stealOpportunityDelta': 0,
          'checkRaiseFlopCountDelta': 0,
          'checkRaiseFlopOpportunityDelta': 0,
          'showdownDelta': 0,
        };

        final deltas = opponentDeltas[opponentId]!;

        // Analyze action and update appropriate counters
        final actionLower = actionType.toLowerCase();
        final isPreflop = street.toLowerCase() == 'preflop';

        // Analyze specific actions
        switch (actionLower) {
          case 'fold':
            deltas['foldDelta'] = (deltas['foldDelta'] ?? 0) + 1;
            break;
          case 'check':
            deltas['checkDelta'] = (deltas['checkDelta'] ?? 0) + 1;
            break;
          case 'call':
            deltas['callDelta'] = (deltas['callDelta'] ?? 0) + 1;
            deltas['passiveDelta'] = (deltas['passiveDelta'] ?? 0) + 1;
            // VPIP: only preflop voluntary actions, once per hand
            if (isPreflop && !StatsCalculator.isBlindAction(action)) {
              opponentDidVpip[opponentId] = true;
            }
            break;
          case 'bet':
            deltas['betDelta'] = (deltas['betDelta'] ?? 0) + 1;
            deltas['aggressionDelta'] = (deltas['aggressionDelta'] ?? 0) + 1;
            // VPIP: only preflop, once per hand
            if (isPreflop) {
              opponentDidVpip[opponentId] = true;
              opponentDidPfr[opponentId] = true;
            }
            break;
          case 'raise':
          case 'all-in':
            deltas['raiseDelta'] = (deltas['raiseDelta'] ?? 0) + 1;
            deltas['aggressionDelta'] = (deltas['aggressionDelta'] ?? 0) + 1;
            // VPIP + PFR: only preflop, once per hand
            if (isPreflop) {
              opponentDidVpip[opponentId] = true;
              opponentDidPfr[opponentId] = true;
            }
            break;
        }

        // Note: 3-bet detection is done per-hand, not per-action
        // We'll check this after processing all actions for this opponent
      }

      // Apply per-hand VPIP/PFR flags to deltas (0 or 1 per hand)
      for (final opponentId in handParticipants) {
        if (opponentDeltas.containsKey(opponentId)) {
          if (opponentDidVpip[opponentId] == true) {
            opponentDeltas[opponentId]!['vpipDelta'] = 1;
          }
          if (opponentDidPfr[opponentId] == true) {
            opponentDeltas[opponentId]!['pfrDelta'] = 1;
          }
        }
      }

      // Set hand delta to 1 for each opponent that participated in this hand
      // Also check for advanced stats using proper detection logic
      for (final opponentId in handParticipants) {
        if (opponentDeltas.containsKey(opponentId)) {
          opponentDeltas[opponentId]!['handsDelta'] = 1;

          // Find the opponent's seat number for stat detection
          // Use defensive programming: handle case where opponent might not be found
          final opponent = savedOpponents.where((o) => o.id == opponentId).firstOrNull;

          if (opponent == null) {
            debugPrint('Warning: Opponent with ID $opponentId not found in savedOpponents, skipping advanced stat detection');
            continue;
          }

          final opponentSeat = playerNames.entries
              .where((e) => e.value == opponent.name)
              .map((e) => e.key)
              .firstOrNull;

          if (opponentSeat == null) continue;

          // 3-Bet Detection
          if (StatsCalculator.didPlayerThreeBet(actions, opponentSeat)) {
            opponentDeltas[opponentId]!['threeBetDelta'] = 1;
          }

          // 3-Bet Opportunity: Player faced a raise pre-flop (could have 3-bet)
          if (StatsCalculator.hadThreeBetOpportunity(actions, opponentSeat)) {
            opponentDeltas[opponentId]!['threeBetOpportunityDelta'] = 1;
          }

          // Fold to 3-Bet: Player raised pre-flop, faced 3-bet, and folded
          if (StatsCalculator.didFoldTo3Bet(actions, opponentSeat)) {
            opponentDeltas[opponentId]!['fold3betDelta'] =
                (opponentDeltas[opponentId]!['fold3betDelta'] ?? 0) + 1;
          }

          // Facing 3-Bet: Player raised pre-flop and faced a re-raise
          if (StatsCalculator.facedThreeBet(actions, opponentSeat)) {
            opponentDeltas[opponentId]!['facing3BetCountDelta'] = 1;
          }

          // C-Bet Opportunity: Was last aggressor pre-flop and saw flop
          if (StatsCalculator.hadCbetOpportunity(actions, opponentSeat)) {
            opponentDeltas[opponentId]!['cbetOpportunityDelta'] = 1;

            // C-Bet: Actually bet on flop as last aggressor
            if (StatsCalculator.didCbet(actions, opponentSeat)) {
              opponentDeltas[opponentId]!['cbetDelta'] =
                  (opponentDeltas[opponentId]!['cbetDelta'] ?? 0) + 1;
            }
          }

          // Steal Opportunity: In CO/BTN/SB with unopened pot
          if (StatsCalculator.hadStealOpportunity(actions, opponentSeat)) {
            opponentDeltas[opponentId]!['stealOpportunityDelta'] = 1;

            // Steal: Raised from steal position
            if (StatsCalculator.didSteal(actions, opponentSeat)) {
              opponentDeltas[opponentId]!['stealCountDelta'] = 1;
            }
          }

          // Check/Raise on Flop: Checked, faced bet, then raised (when OOP)
          if (StatsCalculator.hadCheckRaiseFlopOpportunity(actions, opponentSeat)) {
            opponentDeltas[opponentId]!['checkRaiseFlopOpportunityDelta'] = 1;

            if (StatsCalculator.didCheckRaiseFlop(actions, opponentSeat)) {
              opponentDeltas[opponentId]!['checkRaiseFlopCountDelta'] = 1;
            }
          }

          // Showdown: opponent didn't fold and hand reached showdown
          if (reachedShowdown == true) {
            final didFold = actions.any((a) =>
                a['player'] == opponentSeat &&
                (a['action'] as String?)?.toLowerCase() == 'fold');
            if (!didFold) {
              opponentDeltas[opponentId]!['showdownDelta'] = 1;
            }
          }
        }
      }

      // Walk Detection: Everyone folded to BB
      // In walks, the BB may not have any actions recorded (hand ends before
      // they act), so we use findBigBlindSeat to identify them from blind posts.
      final isWalk = StatsCalculator.isWalkHand(actions);
      if (isWalk) {
        final bbSeat = StatsCalculator.findBigBlindSeat(actions);
        if (bbSeat != null) {
          // Find opponent at BB seat
          final bbName = playerNames[bbSeat];
          if (bbName != null && savedOpponentNames.contains(bbName)) {
            final bbOpponent = savedOpponents.firstWhere((o) => o.name == bbName);
            final bbId = bbOpponent.id;

            // Ensure opponent has deltas initialized and is in handParticipants
            // (BB may not appear in actions in a walk hand)
            if (!handParticipants.contains(bbId)) {
              handParticipants.add(bbId);
              opponentDeltas[bbId] ??= {
                'handsDelta': 0, 'vpipDelta': 0, 'pfrDelta': 0,
                'aggressionDelta': 0, 'passiveDelta': 0,
                'foldDelta': 0, 'checkDelta': 0, 'callDelta': 0,
                'betDelta': 0, 'raiseDelta': 0,
                'threeBetDelta': 0, 'cbetDelta': 0, 'fold3betDelta': 0,
                'walksCountDelta': 0, 'threeBetOpportunityDelta': 0,
                'facing3BetCountDelta': 0, 'cbetOpportunityDelta': 0,
                'stealCountDelta': 0, 'stealOpportunityDelta': 0,
                'checkRaiseFlopCountDelta': 0, 'checkRaiseFlopOpportunityDelta': 0,
                'showdownDelta': 0,
              };
              opponentDeltas[bbId]!['handsDelta'] = 1;
            }
            opponentDeltas[bbId]!['walksCountDelta'] = 1;
          }
        }
      }

      // Apply updates for each opponent
      for (final entry in opponentDeltas.entries) {
        final opponentId = entry.key;
        final deltas = entry.value;

        await OpponentStatsService.updateStatsAtomic(
          opponentId: opponentId,
          handsDelta: deltas['handsDelta'] ?? 0,
          vpipDelta: deltas['vpipDelta'] ?? 0,
          pfrDelta: deltas['pfrDelta'] ?? 0,
          aggressionDelta: deltas['aggressionDelta'] ?? 0,
          passiveDelta: deltas['passiveDelta'] ?? 0,
          foldDelta: deltas['foldDelta'] ?? 0,
          checkDelta: deltas['checkDelta'] ?? 0,
          callDelta: deltas['callDelta'] ?? 0,
          betDelta: deltas['betDelta'] ?? 0,
          raiseDelta: deltas['raiseDelta'] ?? 0,
          threeBetDelta: deltas['threeBetDelta'] ?? 0,
          cbetDelta: deltas['cbetDelta'] ?? 0,
          fold3betDelta: deltas['fold3betDelta'] ?? 0,
          // New opportunity counters
          walksCountDelta: deltas['walksCountDelta'] ?? 0,
          threeBetOpportunityDelta: deltas['threeBetOpportunityDelta'] ?? 0,
          facing3BetCountDelta: deltas['facing3BetCountDelta'] ?? 0,
          cbetOpportunityDelta: deltas['cbetOpportunityDelta'] ?? 0,
          stealCountDelta: deltas['stealCountDelta'] ?? 0,
          stealOpportunityDelta: deltas['stealOpportunityDelta'] ?? 0,
          checkRaiseFlopCountDelta: deltas['checkRaiseFlopCountDelta'] ?? 0,
          checkRaiseFlopOpportunityDelta: deltas['checkRaiseFlopOpportunityDelta'] ?? 0,
          showdownDelta: deltas['showdownDelta'] ?? 0,
        );

      }

    } catch (e) {
      await LoggerService.error('Error updating opponent stats', e, StackTrace.current);
      // Don't rethrow - stats update failure shouldn't break hand saving
    }
  }

  /// Update user statistics from hand data incrementally
  /// Updated to support full 7-metric parity with opponent stats
  static Future<void> _updateUserStatsFromHand({
    required List<Map<String, dynamic>> actions,
    required String? heroPositionName,
    required int? heroSeatNumber,
    required int? winnerId,
    required Map<int, String>? playerNames,
    List<int>? choppedWinners,
  }) async {
    final userId = AuthService.userId;
    if (userId == null || heroPositionName == null || heroSeatNumber == null) return;

    try {
      // Initialize user stats if they don't exist
      await UserStatsService.initializeUserStats(userId);

      // Analyze user's actions in this hand
      bool didPlay = false;
      bool didVpip = false;
      bool didPfr = false;
      bool didThreeBet = false;
      bool didWin = false;

      // Check if user won this hand (compare seat numbers, including chopped pots)
      if ((winnerId != null && winnerId == heroSeatNumber) ||
          (choppedWinners?.contains(heroSeatNumber) ?? false)) {
        didWin = true;
      }

      // Analyze user's actions
      for (final action in actions) {
        final playerId = action['player'] as int?;
        final actionType = action['action']?.toString().toLowerCase() ?? '';
        final street = action['street']?.toString().toLowerCase() ?? '';

        if (playerId != heroSeatNumber) continue;

        // didPlay = any voluntary action (not just blind posts)
        // This includes: call, bet, raise, all-in, check on any street
        if (actionType == 'call' || actionType == 'bet' || actionType == 'raise' || actionType == 'all-in' || actionType == 'check') {
          didPlay = true;
        }

        // VPIP and PFR only apply to preflop
        if (street == 'preflop') {
          if (actionType == 'bet' || actionType == 'call' || actionType == 'raise' || actionType == 'all-in') {
            // VPIP = voluntarily put money in (excludes blind posts)
            if (!StatsCalculator.isBlindAction(action)) {
              didVpip = true;
            }
            // PFR = preflop raise
            if (actionType == 'bet' || actionType == 'raise' || actionType == 'all-in') {
              didPfr = true;
            }
          }
        }
      }

      // Check for 3-bet (re-raise after seeing opponent's raise)
      if (didPlay) {
        didThreeBet = StatsCalculator.didPlayerThreeBet(actions, heroSeatNumber);
      }

      // === Advanced stat detection using helper methods (7-metric parity) ===

      // Walk detection: Everyone folded to BB
      final isWalk = StatsCalculator.isWalkHand(actions);
      final isBBAndWalk = isWalk && StatsCalculator.isBigBlind(actions, heroSeatNumber);

      // 3-Bet opportunity: Hero faced a raise pre-flop
      final had3BetOpportunity = StatsCalculator.hadThreeBetOpportunity(actions, heroSeatNumber);

      // Fold to 3-Bet: Hero raised, faced 3-bet, and folded
      final didFoldTo3Bet = StatsCalculator.didFoldTo3Bet(actions, heroSeatNumber);
      final facedA3Bet = StatsCalculator.facedThreeBet(actions, heroSeatNumber);

      // C-Bet: Hero was last aggressor pre-flop and saw flop
      final hadCbetOpp = StatsCalculator.hadCbetOpportunity(actions, heroSeatNumber);
      final didCbet = hadCbetOpp && StatsCalculator.didCbet(actions, heroSeatNumber);

      // Steal: Hero in CO/BTN/SB with unopened pot
      final hadStealOpp = StatsCalculator.hadStealOpportunity(actions, heroSeatNumber);
      final didSteal = hadStealOpp && StatsCalculator.didSteal(actions, heroSeatNumber);

      // Check/Raise on flop: Hero checked, faced bet, raised
      final hadCRFlopOpp = StatsCalculator.hadCheckRaiseFlopOpportunity(actions, heroSeatNumber);
      final didCRFlop = hadCRFlopOpp && StatsCalculator.didCheckRaiseFlop(actions, heroSeatNumber);

      // Update user stats atomically with all 7 metrics
      await UserStatsService.updateStatsAtomic(
        userId: userId,
        totalHandsDelta: 1, // Always increment total hands
        walksDelta: isBBAndWalk ? 1 : 0,
        handsDelta: didPlay ? 1 : 0,
        vpipDelta: didVpip ? 1 : 0,
        pfrDelta: didPfr ? 1 : 0,
        threeBetDelta: didThreeBet ? 1 : 0,
        threeBetOpportunityDelta: had3BetOpportunity ? 1 : 0,
        fold3betDelta: didFoldTo3Bet ? 1 : 0,
        facing3BetDelta: facedA3Bet ? 1 : 0,
        cbetDelta: didCbet ? 1 : 0,
        cbetOpportunityDelta: hadCbetOpp ? 1 : 0,
        stealDelta: didSteal ? 1 : 0,
        stealOpportunityDelta: hadStealOpp ? 1 : 0,
        checkRaiseFlopDelta: didCRFlop ? 1 : 0,
        checkRaiseFlopOpportunityDelta: hadCRFlopOpp ? 1 : 0,
        wonHandsDelta: (didWin && didPlay) ? 1 : 0,
        position: heroPositionName,
      );


    } catch (e) {
      await LoggerService.error('Error updating user stats', e, StackTrace.current);
      // Don't rethrow - stats update failure shouldn't break hand saving
    }
  }

  /// Update statistics for ALL players in dealer-assisted mode
  /// This updates stats for each player in the playerIds map (seat → Firebase userId)
  static Future<void> _updateAllPlayerStatsFromHand({
    required List<Map<String, dynamic>> actions,
    required Map<int, String> playerIds,
    required int buttonPosition,
    required List<int> activeSeats,
    required int? winnerId,
    required List<int>? choppedWinners,
  }) async {
    for (final entry in playerIds.entries) {
      final seatNumber = entry.key;
      final odUserId = entry.value;

      // Skip manual players (no Firebase account)
      if (odUserId.startsWith('manual_')) continue;

      try {
        // Initialize user stats if they don't exist
        await UserStatsService.initializeUserStats(odUserId);

        // Analyze player's actions in this hand
        bool didPlay = false;
        bool didVpip = false;
        bool didPfr = false;
        bool didThreeBet = false;
        bool didWin = (winnerId == seatNumber) ||
            (choppedWinners?.contains(seatNumber) ?? false);

        // Analyze player's actions
        for (final action in actions) {
          final playerId = action['player'] as int?;
          final actionType = action['action']?.toString().toLowerCase() ?? '';
          final street = action['street']?.toString().toLowerCase() ?? '';

          if (playerId != seatNumber) continue;

          // didPlay = any voluntary action
          if (actionType == 'call' ||
              actionType == 'bet' ||
              actionType == 'raise' ||
              actionType == 'check') {
            didPlay = true;
          }

          // VPIP and PFR only apply to preflop
          if (street == 'preflop') {
            if (actionType == 'bet' ||
                actionType == 'call' ||
                actionType == 'raise') {
              // VPIP = voluntarily put money in (excludes blind posts)
              if (!StatsCalculator.isBlindAction(action)) {
                didVpip = true;
              }
              // PFR = preflop raise
              if (actionType == 'bet' || actionType == 'raise') {
                didPfr = true;
              }
            }
          }
        }

        // Check for 3-bet (re-raise after seeing opponent's raise)
        if (didPlay) {
          didThreeBet = StatsCalculator.didPlayerThreeBet(actions, seatNumber);
        }

        // Update this player's stats atomically
        await UserStatsService.updateStatsAtomic(
          userId: odUserId,
          totalHandsDelta: 1, // Always increment total hands
          handsDelta: didPlay ? 1 : 0,
          vpipDelta: didVpip ? 1 : 0,
          pfrDelta: didPfr ? 1 : 0,
          threeBetDelta: didThreeBet ? 1 : 0,
          wonHandsDelta: (didWin && didPlay) ? 1 : 0,
        );
      } catch (e) {
        await LoggerService.error('Error updating stats for player $odUserId at seat $seatNumber', e, StackTrace.current);
        // Continue with other players
      }
    }
  }


  /// Set migration completion flag in Firebase
  static Future<void> setMigrationFlag({required bool completed}) async {
    final userId = AuthService.userId;
    if (userId == null) throw 'User not authenticated';

    await _firestore.collection('migration_status').doc(userId).set({
      'completed': completed,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Check if migration has been completed in Firebase
  static Future<bool> isMigrationCompleted() async {
    final userId = AuthService.userId;
    if (userId == null) return false;

    final doc = await _firestore.collection('migration_status').doc(userId).get();
    return doc.exists && (doc.data()?['completed'] == true);
  }

  // Force sync local sessions to Firebase
  static Future<Map<String, dynamic>> syncLocalSessionsToFirebase() async {
    final userId = AuthService.userId;
    if (userId == null) {
      return {'success': false, 'message': 'User not authenticated'};
    }

    try {
      debugPrint('🔄 Starting sync of local sessions to Firebase...');

      // Get all local sessions
      final localSessions = await LocalStorageService.getUserSessions();
      debugPrint('📊 Found ${localSessions.length} local sessions');

      // Get existing Firebase sessions to avoid duplicates
      final firebaseSessions = await getAllSessions();
      final firebaseSessionIds = firebaseSessions.map((s) => s['id'] as String).toSet();
      debugPrint('📊 Found ${firebaseSessions.length} existing Firebase sessions');

      int syncedCount = 0;
      int skippedCount = 0;
      List<String> errors = [];

      for (final session in localSessions) {
        final sessionId = session['id'] as String?;
        if (sessionId == null) continue;

        try {
          // Skip if already in Firebase
          if (firebaseSessionIds.contains(sessionId)) {
            skippedCount++;
            continue;
          }

          // Prepare session data for Firebase
          final sessionData = Map<String, dynamic>.from(session);
          sessionData['userId'] = userId;

          // Ensure timestamps are proper
          if (sessionData['startTime'] == null) {
            sessionData['startTime'] = FieldValue.serverTimestamp();
          }
          if (sessionData['createdAt'] == null) {
            sessionData['createdAt'] = FieldValue.serverTimestamp();
          }

          // Upload to Firebase
          await _firestore.collection(_sessionsCollection).doc(sessionId).set(
            sessionData,
            SetOptions(merge: true),
          );

          // Also sync associated hands if any
          final localHands = await LocalStorageService.getSessionHands(sessionId);
          if (localHands.isNotEmpty) {
            for (final hand in localHands) {
              final handId = '${sessionId}_hand_${hand['handNumber']}';
              await _firestore
                  .collection(_sessionsCollection)
                  .doc(sessionId)
                  .collection(_handsCollection)
                  .doc(handId)
                  .set(hand, SetOptions(merge: true));
            }
            debugPrint('✅ Synced session $sessionId with ${localHands.length} hands');
          } else {
            debugPrint('✅ Synced session $sessionId (no hands)');
          }

          syncedCount++;
        } catch (e) {
          errors.add('Session $sessionId: $e');
          await LoggerService.error('Failed to sync session $sessionId', e, StackTrace.current);
        }
      }

      final message = 'Sync complete: $syncedCount synced, $skippedCount already in cloud${errors.isNotEmpty ? ', ${errors.length} errors' : ''}';
      debugPrint('🎉 $message');

      return {
        'success': true,
        'message': message,
        'synced': syncedCount,
        'skipped': skippedCount,
        'errors': errors,
      };
    } catch (e) {
      await LoggerService.error('Sync failed', e, StackTrace.current);
      return {
        'success': false,
        'message': 'Sync failed: $e',
      };
    }
  }
}