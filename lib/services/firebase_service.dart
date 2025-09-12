import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/poker_game_state.dart';
import '../models/game_types.dart';
import 'auth_service.dart';
import 'local_storage_service.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collection references
  static const String _sessionsCollection = 'poker_sessions';
  static const String _handsCollection = 'poker_hands';

  // Create a new poker session
  static Future<String> createSession({
    required int smallBlind,
    required int bigBlind,
    required int playerCount,
    int? ourSeatNumber,
    GameType gameType = GameType.cash,
  }) async {
    try {
      final userId = AuthService.userId;
      if (userId == null) throw 'User not authenticated';
      
      final sessionRef = await _firestore.collection(_sessionsCollection).add({
        'userId': userId,
        'userEmail': AuthService.currentUser?.email,
        'userName': AuthService.userDisplayName,
        'smallBlind': smallBlind,
        'bigBlind': bigBlind,
        'playerCount': playerCount,
        'ourSeatNumber': ourSeatNumber,
        'gameType': gameType.value,
        'startTime': FieldValue.serverTimestamp(),
        'endTime': null,
        'totalHands': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      print('Session created with ID: ${sessionRef.id} for user: $userId');
      return sessionRef.id;
    } catch (e) {
      print('Error creating session: $e');
      rethrow;
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
      
      // Save to session's subcollection instead of top-level collection
      await _firestore
          .collection(_sessionsCollection)
          .doc(sessionId)
          .collection(_handsCollection)
          .doc(handNumber.toString())
          .set(handData);
      
      // Update session total hands count
      await _firestore.collection(_sessionsCollection).doc(sessionId).update({
        'totalHands': FieldValue.increment(1),
      });
      
      print('Hand $handNumber saved successfully to session $sessionId');
    } catch (e) {
      print('Error saving hand: $e');
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
      
      print('Action saved: Player $player $action on $street');
    } catch (e) {
      print('Error saving action: $e');
      // Don't rethrow - action logging shouldn't break the game
    }
  }

  // End a session
  static Future<void> endSession(String sessionId) async {
    try {
      await _firestore.collection(_sessionsCollection).doc(sessionId).update({
        'endTime': FieldValue.serverTimestamp(),
      });
      
      print('Session $sessionId ended');
    } catch (e) {
      print('Error ending session: $e');
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
      print('Error getting session: $e');
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
          ...data,
          'startTime': data['startTime']?.toDate()?.toIso8601String() ?? DateTime.now().toIso8601String(),
          'endTime': data['endTime']?.toDate()?.toIso8601String(),
        };
      }).toList();
    } catch (e) {
      print('Error getting session hands from Firebase: $e');
      return [];
    }
  }

  // Mock hand data for offline testing  
  static List<Map<String, dynamic>> _getMockHandData() {
    print('Returning mock offline hand data');
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
      print('Error getting recent sessions: $e');
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
      
      print('Firebase connection test successful');
      return true;
    } catch (e) {
      print('Firebase connection test failed: $e');
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
  static Future<List<Map<String, dynamic>>> getAllSessions() async {
    try {
      final userId = AuthService.userId;
      if (userId == null) throw 'User not authenticated';
      
      final sessionsSnapshot = await _firestore
          .collection(_sessionsCollection)
          .where('userId', isEqualTo: userId)
          .get();
      
      // Sort in memory to avoid needing Firebase index
      final docs = sessionsSnapshot.docs.toList();
      docs.sort((a, b) {
        final aTime = a.data()['startTime'] as Timestamp?;
        final bTime = b.data()['startTime'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime); // Descending order
      });

      return docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'startTime': data['startTime']?.toDate()?.toIso8601String() ?? DateTime.now().toIso8601String(),
          'endTime': data['endTime']?.toDate()?.toIso8601String(),
        };
      }).toList();
    } catch (e) {
      print('Error getting user sessions from Firebase: $e');
      print('Falling back to local storage...');
      
      // Fallback to local storage
      try {
        return await LocalStorageService.getUserSessions();
      } catch (localError) {
        print('Error getting sessions from local storage: $localError');
        return _getMockOfflineData();
      }
    }
  }

  // Mock data for offline testing
  static List<Map<String, dynamic>> _getMockOfflineData() {
    print('Returning mock offline session data');
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
      print('Error getting player stats: $e');
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
      
      print('Session name updated: $sessionId -> $sessionName');
    } catch (e) {
      print('Error updating session name: $e');
      rethrow;
    }
  }

  // Update session with progress data
  static Future<void> updateSession({
    required String sessionId,
    int? totalHands,
  }) async {
    try {
      final userId = AuthService.userId;
      if (userId == null) throw 'User not authenticated';
      
      Map<String, dynamic> updateData = {
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (totalHands != null) {
        updateData['totalHands'] = totalHands;
      }
      
      await _firestore.collection(_sessionsCollection).doc(sessionId).update(updateData);
      
      print('Session updated: $sessionId (totalHands: $totalHands)');
    } catch (e) {
      print('Error updating session: $e');
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
      
      print('🗑️ DEBUG: All user sessions cleared from Firebase');
    } catch (e) {
      print('🗑️ DEBUG: Error clearing user sessions from Firebase: $e');
      rethrow;
    }
  }
}