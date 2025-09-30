import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/poker_game_state.dart';
import '../models/game_types.dart';
import 'auth_service.dart';
import 'local_storage_service.dart';
import 'opponent_service.dart';
import 'opponent_stats_service.dart';
import 'user_stats_service.dart';

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
    bool isIndividualSession = false,
    String? sessionName,
    double? startingStack,
    bool hasBBante = false,
  }) async {
    try {
      final userId = AuthService.userId;
      if (userId == null) throw 'User not authenticated';
      
      final sessionData = {
        'userId': userId,
        'userEmail': AuthService.currentUser?.email,
        'userName': AuthService.userDisplayName,
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
        'sessionName': sessionName ?? (isIndividualSession ? 'Individual Session' : ''), // Always set sessionName
      };

      // Add individual session specific fields
      if (isIndividualSession) {
        sessionData.addAll({
          'startingStack': startingStack ?? 0.0,
          'currentStack': startingStack ?? 0.0,
          'handsLogged': 0,
          'biggestPot': 0.0,
          'sessionStatus': 'active',
        });
      } else {
        // For full hand logging sessions, save starting stack as buyInAmount
        if (startingStack != null && startingStack > 0) {
          sessionData.addAll({
            'buyInAmount': startingStack,
            'totalBuyIn': startingStack,
          });
        }
      }

      final sessionRef = await _firestore.collection(_sessionsCollection).add(sessionData);
      
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
    double? potAmount,
    double? preflopPot,
    double? flopPot,
    double? turnPot,
    double? riverPot,
    int? winnerId,
    int? heroPosition,
    Map<int, String>? playerNames,
    int? smallBlind,
    int? bigBlind,
    String? gameType,
    // Chopped pot fields
    bool? isChoppedPot,
    List<int>? choppedWinners,
    Map<int, double>? individualShares,
    double? sharePerWinner,
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
      
      if (heroPosition != null) {
        handData['heroPosition'] = heroPosition;
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

      // Update opponent statistics incrementally (performance optimization)
      await _updateOpponentStatsFromHand(
        actions: actions,
        playerNames: playerNames,
      );

      // Update user statistics incrementally (performance optimization)
      await _updateUserStatsFromHand(
        actions: actions,
        heroPosition: heroPosition,
        buttonPosition: buttonPosition,
        playerCount: playerCount,
        winnerId: winnerId,
        playerNames: playerNames,
      );

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
      // Get session data to calculate duration
      final sessionDoc = await _firestore.collection(_sessionsCollection).doc(sessionId).get();

      await _firestore.collection(_sessionsCollection).doc(sessionId).update({
        'endTime': FieldValue.serverTimestamp(),
      });

      // Update user stats with session count and duration
      if (sessionDoc.exists) {
        final sessionData = sessionDoc.data()!;
        final startTime = sessionData['startTime'] as Timestamp?;

        if (startTime != null) {
          final duration = DateTime.now().difference(startTime.toDate()).inMinutes;

          final userId = AuthService.userId;
          if (userId != null) {
            await UserStatsService.updateStatsAtomic(
              userId: userId,
              sessionsDelta: 1,
              playTimeMinutesDelta: duration,
            );
          }
        }
      }

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
    List<Map<String, dynamic>>? stackHistory,
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

      if (stackHistory != null) {
        updateData['stackHistory'] = stackHistory;
      }

      await _firestore.collection(_sessionsCollection).doc(sessionId).update(updateData);

      print('Session updated: $sessionId (totalHands: $totalHands, stackHistory entries: ${stackHistory?.length ?? 0})');
    } catch (e) {
      print('Error updating session: $e');
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
    int? smallBlind,
    int? bigBlind,
    bool? hasBBante,
    List<Map<String, dynamic>>? rebuys,
    double? totalBuyIn,
    List<Map<String, dynamic>>? stackHistory,
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

      await _firestore.collection(_sessionsCollection).doc(sessionId).update(updateData);

    } catch (e) {
      print('Error updating individual session: $e');
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
      print('Error adding rebuy to session: $e');
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

  /// Process hand actions and update opponent stats incrementally
  /// This is the key optimization - O(1) updates instead of O(n) recalculation
  static Future<void> _updateOpponentStatsFromHand({
    required List<Map<String, dynamic>> actions,
    required Map<int, String>? playerNames,
  }) async {
    if (playerNames == null || actions.isEmpty) return;

    try {
      // Get all saved opponents first (only track stats for saved opponents)
      final savedOpponents = await OpponentService.getAllOpponents();
      final savedOpponentNames = savedOpponents.map((o) => o.name).toSet();

      // Group actions by opponent ID to batch updates
      Map<String, Map<String, int>> opponentDeltas = {};
      Set<String> handParticipants = {}; // Track which opponents participated in this hand

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
            // VPIP if putting money in voluntarily (not blind)
            if (!_isBlindAction(action)) {
              deltas['vpipDelta'] = (deltas['vpipDelta'] ?? 0) + 1;
            }
            break;
          case 'bet':
            deltas['betDelta'] = (deltas['betDelta'] ?? 0) + 1;
            deltas['aggressionDelta'] = (deltas['aggressionDelta'] ?? 0) + 1;
            deltas['vpipDelta'] = (deltas['vpipDelta'] ?? 0) + 1;
            break;
          case 'raise':
            deltas['raiseDelta'] = (deltas['raiseDelta'] ?? 0) + 1;
            deltas['aggressionDelta'] = (deltas['aggressionDelta'] ?? 0) + 1;
            deltas['vpipDelta'] = (deltas['vpipDelta'] ?? 0) + 1;
            // PFR if preflop raise
            if (isPreflop) {
              deltas['pfrDelta'] = (deltas['pfrDelta'] ?? 0) + 1;
            }
            break;
        }

        // Detect 3-bet (simplified logic - can be enhanced)
        if (actionLower == 'raise' && isPreflop) {
          final raiseCount = _countPreflopRaises(actions, playerId);
          if (raiseCount >= 2) {
            deltas['threeBetDelta'] = (deltas['threeBetDelta'] ?? 0) + 1;
          }
        }
      }

      // Set hand delta to 1 for each opponent that participated in this hand
      for (final opponentId in handParticipants) {
        if (opponentDeltas.containsKey(opponentId)) {
          opponentDeltas[opponentId]!['handsDelta'] = 1;
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
        );

      }

    } catch (e) {
      print('⚠️ Error updating opponent stats: $e');
      // Don't rethrow - stats update failure shouldn't break hand saving
    }
  }

  /// Helper to detect if an action is a blind (not voluntary)
  static bool _isBlindAction(Map<String, dynamic> action) {
    final actionType = (action['action'] as String?)?.toLowerCase();
    return actionType == 'small blind' ||
           actionType == 'big blind' ||
           actionType == 'ante';
  }

  /// Helper to count preflop raises for 3-bet detection
  static int _countPreflopRaises(List<Map<String, dynamic>> actions, int playerId) {
    int count = 0;
    for (final action in actions) {
      if (action['player'] == playerId &&
          action['street']?.toLowerCase() == 'preflop' &&
          action['action']?.toLowerCase() == 'raise') {
        count++;
      }
    }
    return count;
  }

  /// Update user statistics from hand data incrementally
  static Future<void> _updateUserStatsFromHand({
    required List<Map<String, dynamic>> actions,
    required int? heroPosition,
    required int buttonPosition,
    required int playerCount,
    required int? winnerId,
    required Map<int, String>? playerNames,
  }) async {
    final userId = AuthService.userId;
    if (userId == null || heroPosition == null) return;

    try {
      // Initialize user stats if they don't exist
      await UserStatsService.initializeUserStats(userId);

      // Analyze user's actions in this hand
      bool didPlay = false;
      bool didVpip = false;
      bool didPfr = false;
      bool didThreeBet = false;
      bool didWin = false;

      // Get position name for this hand
      final positionName = _getPositionName(heroPosition, buttonPosition, playerCount);

      // Check if user won this hand
      if (winnerId != null && winnerId == heroPosition) {
        didWin = true;
      }

      // Analyze user's actions
      for (final action in actions) {
        final playerId = action['player'] as int?;
        final actionType = action['action']?.toString().toLowerCase() ?? '';
        final street = action['street']?.toString().toLowerCase() ?? '';

        if (playerId != heroPosition) continue;

        if (street == 'preflop') {
          if (actionType == 'bet' || actionType == 'call' || actionType == 'raise') {
            didPlay = true;
            if (!_isBlindAction(action)) {
              didVpip = true;
            }
            if (actionType == 'bet' || actionType == 'raise') {
              didPfr = true;
            }
          }
        }
      }

      // Check for 3-bet
      if (didPlay) {
        final raiseCount = _countPreflopRaises(actions, heroPosition);
        if (raiseCount >= 2) {
          didThreeBet = true;
        }
      }

      // Prepare deltas for atomic update
      final Map<String, int> positionHandsDeltas = {};
      final Map<String, int> positionVpipDeltas = {};
      final Map<String, int> positionPfrDeltas = {};
      final Map<String, int> positionThreeBetDeltas = {};

      if (didPlay) {
        positionHandsDeltas[positionName] = 1;
        if (didVpip) positionVpipDeltas[positionName] = 1;
        if (didPfr) positionPfrDeltas[positionName] = 1;
        if (didThreeBet) positionThreeBetDeltas[positionName] = 1;
      }

      // Update user stats atomically
      await UserStatsService.updateStatsAtomic(
        userId: userId,
        totalHandsDelta: 1, // Always increment total hands
        handsDelta: didPlay ? 1 : 0,
        vpipDelta: didVpip ? 1 : 0,
        pfrDelta: didPfr ? 1 : 0,
        threeBetDelta: didThreeBet ? 1 : 0,
        wonHandsDelta: didWin ? 1 : 0,
        positionHandsDeltas: positionHandsDeltas.isNotEmpty ? positionHandsDeltas : null,
        positionVpipDeltas: positionVpipDeltas.isNotEmpty ? positionVpipDeltas : null,
        positionPfrDeltas: positionPfrDeltas.isNotEmpty ? positionPfrDeltas : null,
        positionThreeBetDeltas: positionThreeBetDeltas.isNotEmpty ? positionThreeBetDeltas : null,
      );


    } catch (e) {
      print('⚠️ Error updating user stats: $e');
      // Don't rethrow - stats update failure shouldn't break hand saving
    }
  }

  /// Helper to get position name for user stats
  static String _getPositionName(int seatNumber, int buttonPosition, int playerCount) {
    final buttonIndex = (buttonPosition - 1) % playerCount;
    final seatIndex = (seatNumber - 1) % playerCount;
    final relativePosition = (seatIndex - buttonIndex) % playerCount;

    if (playerCount == 6) {
      switch (relativePosition) {
        case 0: return 'BTN';
        case 1: return 'SB';
        case 2: return 'BB';
        case 3: return 'UTG';
        case 4: return 'MP';
        case 5: return 'CO';
        default: return 'UNK';
      }
    } else {
      final positions = ['UTG', 'UTG+1', 'MP', 'CO', 'BTN', 'SB', 'BB'];
      return positions[relativePosition.clamp(0, positions.length - 1)];
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
}