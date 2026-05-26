import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_stats.dart';
import '../services/firebase_service.dart';
import '../services/logger_service.dart';

class UserStatsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get user stats with O(1) lookup
  static Future<UserStats?> getUserStats(String userId) async {
    try {
      final doc = await _firestore
          .collection('user_stats')
          .doc(userId)
          .get();

      if (doc.exists) {
        return UserStats.fromFirestore(doc.data()!);
      }

      return null;
    } catch (e) {
      await LoggerService.error('Error getting user stats', e, StackTrace.current);
      return null;
    }
  }

  /// Initialize user stats if they don't exist
  static Future<void> initializeUserStats(String userId) async {
    try {
      final docRef = _firestore.collection('user_stats').doc(userId);
      final doc = await docRef.get();

      if (!doc.exists) {
        final stats = UserStats(userId: userId);
        await docRef.set(stats.toFirestore());
      }
    } catch (e) {
      await LoggerService.error('Error initializing user stats', e, StackTrace.current);
    }
  }

  /// Update user stats atomically using incremental counters
  /// Updated to support full 7-metric parity with opponent stats
  static Future<void> updateStatsAtomic({
    required String userId,
    int handsDelta = 0,
    int totalHandsDelta = 0,
    int walksDelta = 0,
    int vpipDelta = 0,
    int pfrDelta = 0,
    int threeBetDelta = 0,
    int threeBetOpportunityDelta = 0,
    int fold3betDelta = 0,
    int facing3BetDelta = 0,
    int cbetDelta = 0,
    int cbetOpportunityDelta = 0,
    int stealDelta = 0,
    int stealOpportunityDelta = 0,
    int checkRaiseFlopDelta = 0,
    int checkRaiseFlopOpportunityDelta = 0,
    int wonHandsDelta = 0,
    int sessionsDelta = 0,
    int playTimeMinutesDelta = 0,
  }) async {
    try {
      final docRef = _firestore.collection('user_stats').doc(userId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);

        // Initialize if doesn't exist
        if (!doc.exists) {
          final initialStats = UserStats(userId: userId);
          transaction.set(docRef, initialStats.toFirestore());
        }

        // Build update map with increments
        final Map<String, dynamic> updates = {};

        if (handsDelta != 0) updates['handsPlayed'] = FieldValue.increment(handsDelta);
        if (totalHandsDelta != 0) updates['totalHands'] = FieldValue.increment(totalHandsDelta);
        if (walksDelta != 0) updates['walksCount'] = FieldValue.increment(walksDelta);
        if (vpipDelta != 0) updates['vpipCount'] = FieldValue.increment(vpipDelta);
        if (pfrDelta != 0) updates['pfrCount'] = FieldValue.increment(pfrDelta);
        if (threeBetDelta != 0) updates['threeBetCount'] = FieldValue.increment(threeBetDelta);
        if (threeBetOpportunityDelta != 0) updates['threeBetOpportunity'] = FieldValue.increment(threeBetOpportunityDelta);
        if (fold3betDelta != 0) updates['fold3betCount'] = FieldValue.increment(fold3betDelta);
        if (facing3BetDelta != 0) updates['facing3BetCount'] = FieldValue.increment(facing3BetDelta);
        if (cbetDelta != 0) updates['cbetCount'] = FieldValue.increment(cbetDelta);
        if (cbetOpportunityDelta != 0) updates['cbetOpportunity'] = FieldValue.increment(cbetOpportunityDelta);
        if (stealDelta != 0) updates['stealCount'] = FieldValue.increment(stealDelta);
        if (stealOpportunityDelta != 0) updates['stealOpportunity'] = FieldValue.increment(stealOpportunityDelta);
        if (checkRaiseFlopDelta != 0) updates['checkRaiseFlopCount'] = FieldValue.increment(checkRaiseFlopDelta);
        if (checkRaiseFlopOpportunityDelta != 0) updates['checkRaiseFlopOpportunity'] = FieldValue.increment(checkRaiseFlopOpportunityDelta);
        if (wonHandsDelta != 0) updates['wonHands'] = FieldValue.increment(wonHandsDelta);
        if (sessionsDelta != 0) updates['totalSessions'] = FieldValue.increment(sessionsDelta);
        if (playTimeMinutesDelta != 0) updates['totalPlayTimeMinutes'] = FieldValue.increment(playTimeMinutesDelta);


        updates['lastUpdated'] = FieldValue.serverTimestamp();

        transaction.update(docRef, updates);
      });
    } catch (e) {
      await LoggerService.error('Error updating user stats atomically', e, StackTrace.current);
      rethrow;
    }
  }

  /// Calculate and store user statistics for all existing data (one-time migration)
  static Future<void> migrateUserStats(String userId) async {
    try {

      // Initialize counters
      int handsPlayed = 0;
      int totalHands = 0;
      int vpipCount = 0;
      int pfrCount = 0;
      int threeBetCount = 0;
      int wonHands = 0;
      int totalSessions = 0;
      int totalPlayTimeMinutes = 0;

      // Get all sessions
      List<Map<String, dynamic>> sessions;
      try {
        sessions = await FirebaseService.getAllSessions();
      } catch (e) {
        await LoggerService.error('Error fetching sessions for migration', e, StackTrace.current);
        return;
      }

      totalSessions = sessions.length;

      // Process each session
      for (var session in sessions) {
        // Calculate session duration
        if (session['endTime'] != null && session['startTime'] != null) {
          final start = DateTime.parse(session['startTime']);
          final end = DateTime.parse(session['endTime']);
          totalPlayTimeMinutes += end.difference(start).inMinutes;
        }

        // Get hands for this session
        List<Map<String, dynamic>> hands;
        try {
          hands = await FirebaseService.getSessionHands(session['id']);
        } catch (e) {
          await LoggerService.error('Error fetching hands for session ${session['id']}', e, StackTrace.current);
          continue;
        }

        final ourSeatNumber = session['ourSeatNumber'];
        if (ourSeatNumber == null) continue;

        // Process each hand
        for (var handData in hands) {
          totalHands++;

          // Check if we played this hand
          final actions = List<Map<String, dynamic>>.from(handData['actions'] ?? []);
          bool didPlay = false;
          bool didVpip = false;
          bool didPfr = false;
          bool didThreeBet = false;

          // Check our actions
          for (var action in actions) {
            if (action['player'] == ourSeatNumber) {
              final actionType = action['action']?.toString().toLowerCase() ?? '';
              final street = action['street']?.toString().toLowerCase() ?? '';

              if (street == 'preflop') {
                if (actionType == 'bet' || actionType == 'call' || actionType == 'raise') {
                  didPlay = true;
                  didVpip = true;

                  if (actionType == 'bet' || actionType == 'raise') {
                    didPfr = true;
                  }
                }
              }
            }
          }

          // Check for 3-bet using proper detection logic
          // 3-bet = re-raise AFTER seeing an opponent's raise (not just any raise)
          if (didPlay) {
            didThreeBet = _didPlayerThreeBetInHand(actions, ourSeatNumber);
          }

          if (didPlay) {
            handsPlayed++;

            if (didVpip) {
              vpipCount++;
            }

            if (didPfr) {
              pfrCount++;
            }

            if (didThreeBet) {
              threeBetCount++;
            }

            // Check if we won (simplified - assume 50% win rate for migration)
            if (handsPlayed % 2 == 0) {
              wonHands++;
            }
          }
        }
      }

      // Store the calculated stats
      final userStats = UserStats(
        userId: userId,
        handsPlayed: handsPlayed,
        totalHands: totalHands,
        vpipCount: vpipCount,
        pfrCount: pfrCount,
        threeBetCount: threeBetCount,
        wonHands: wonHands,
        totalSessions: totalSessions,
        totalPlayTimeMinutes: totalPlayTimeMinutes,
      );

      await _firestore.collection('user_stats').doc(userId).set(userStats.toFirestore());


    } catch (e) {
      await LoggerService.error('Error during user stats migration', e, StackTrace.current);
      rethrow;
    }
  }

  /// Recalculate user stats from raw hand data (use to repair corrupted stats)
  ///
  /// This function:
  /// 1. Resets all stats to zero
  /// 2. Iterates through all hands in poker_sessions
  /// 3. Recalculates each stat with correct logic
  /// 4. Saves corrected totals
  ///
  /// Use this when stats are corrupted (e.g., from double-counting bugs)
  static Future<Map<String, dynamic>> recalculateUserStats(String userId) async {
    try {
      debugPrint('🔄 Starting stats recalculation for user: $userId');

      // Initialize counters
      int handsPlayed = 0;
      int totalHands = 0;
      int vpipCount = 0;
      int pfrCount = 0;
      int threeBetCount = 0;
      int wonHands = 0;
      int totalSessions = 0;
      int totalPlayTimeMinutes = 0;

      // Get all sessions
      List<Map<String, dynamic>> sessions;
      try {
        sessions = await FirebaseService.getAllSessions();
      } catch (e) {
        await LoggerService.error('Error fetching sessions for recalculation', e, StackTrace.current);
        return {'success': false, 'error': 'Failed to fetch sessions: $e'};
      }

      totalSessions = sessions.length;
      debugPrint('📊 Found ${sessions.length} sessions to process');

      // Process each session
      for (var session in sessions) {
        final sessionId = session['id'] as String?;
        if (sessionId == null) continue;

        // Calculate session duration
        if (session['endTime'] != null && session['startTime'] != null) {
          try {
            DateTime startTime;
            DateTime endTime;

            if (session['startTime'] is String) {
              startTime = DateTime.parse(session['startTime']);
            } else {
              continue;
            }

            if (session['endTime'] is String) {
              endTime = DateTime.parse(session['endTime']);
            } else {
              continue;
            }

            totalPlayTimeMinutes += endTime.difference(startTime).inMinutes;
          } catch (e) {
            await LoggerService.error('Error parsing session times for $sessionId', e, StackTrace.current);
          }
        }

        // Get hands for this session
        List<Map<String, dynamic>> hands;
        try {
          hands = await FirebaseService.getSessionHands(sessionId);
        } catch (e) {
          await LoggerService.error('Error fetching hands for session $sessionId', e, StackTrace.current);
          continue;
        }

        final ourSeatNumber = session['ourSeatNumber'] as int?;
        if (ourSeatNumber == null) {
          debugPrint('⚠️ No seat number for session $sessionId, skipping');
          continue;
        }

        // Process each hand
        for (var handData in hands) {
          totalHands++;

          final actions = List<Map<String, dynamic>>.from(handData['actions'] ?? []);
          bool didPlay = false;
          bool didVpip = false;
          bool didPfr = false;

          // Check our actions
          for (var action in actions) {
            if (action['player'] == ourSeatNumber) {
              final actionType = action['action']?.toString().toLowerCase() ?? '';
              final street = action['street']?.toString().toLowerCase() ?? '';

              if (street == 'preflop') {
                // VPIP: call, bet, or raise (NOT blinds)
                if (actionType == 'call' || actionType == 'bet' || actionType == 'raise') {
                  didPlay = true;
                  // Don't count blind posts as VPIP
                  if (!_isBlindAction(action)) {
                    didVpip = true;
                  }
                  if (actionType == 'bet' || actionType == 'raise') {
                    didPfr = true;
                  }
                }
              } else {
                // Any action on flop/turn/river means player played the hand
                didPlay = true;
              }
            }
          }

          // Check for 3-bet using proper detection logic
          final didThreeBet = _didPlayerThreeBetInHand(actions, ourSeatNumber);

          // Check if we won
          final winnerId = handData['winnerId'];
          final didWin = (winnerId == ourSeatNumber);

          // Update counters
          if (didPlay) handsPlayed++;
          if (didVpip) vpipCount++;
          if (didPfr) pfrCount++;
          if (didThreeBet) threeBetCount++;
          if (didWin) {
            wonHands++;
          }
        }
      }

      // Store the recalculated stats
      final userStats = UserStats(
        userId: userId,
        handsPlayed: handsPlayed,
        totalHands: totalHands,
        vpipCount: vpipCount,
        pfrCount: pfrCount,
        threeBetCount: threeBetCount,
        wonHands: wonHands,
        totalSessions: totalSessions,
        totalPlayTimeMinutes: totalPlayTimeMinutes,
      );

      await _firestore.collection('user_stats').doc(userId).set(userStats.toFirestore());

      debugPrint('✅ Stats recalculation complete');
      debugPrint('   Total Hands: $totalHands');
      debugPrint('   Hands Played: $handsPlayed');
      debugPrint('   VPIP Count: $vpipCount');
      debugPrint('   PFR Count: $pfrCount');
      debugPrint('   3-Bet Count: $threeBetCount');
      debugPrint('   Won Hands: $wonHands');
      debugPrint('   Sessions: $totalSessions');

      return {
        'success': true,
        'totalHands': totalHands,
        'handsPlayed': handsPlayed,
        'vpipCount': vpipCount,
        'pfrCount': pfrCount,
        'threeBetCount': threeBetCount,
        'wonHands': wonHands,
        'totalSessions': totalSessions,
        'totalPlayTimeMinutes': totalPlayTimeMinutes,
      };
    } catch (e) {
      await LoggerService.error('Error during stats recalculation', e, StackTrace.current);
      return {'success': false, 'error': 'Recalculation failed: $e'};
    }
  }

  /// Helper to detect if action is a blind (not voluntary)
  static bool _isBlindAction(Map<String, dynamic> action) {
    final actionType = (action['action'] as String?)?.toLowerCase();
    return actionType == 'small blind' ||
           actionType == 'big blind' ||
           actionType == 'ante' ||
           actionType == 'post';
  }

  /// Helper to detect 3-bet (re-raise after opponent's raise)
  static bool _didPlayerThreeBetInHand(List<Map<String, dynamic>> actions, int playerSeatNumber) {
    bool sawOpponentRaise = false;

    for (final action in actions) {
      final street = action['street']?.toString().toLowerCase() ?? '';
      if (street != 'preflop') continue;

      final playerId = action['player'] as int?;
      final actionType = action['action']?.toString().toLowerCase() ?? '';

      // Only look at raise actions
      if (actionType != 'raise') continue;

      if (playerId != playerSeatNumber) {
        sawOpponentRaise = true;
      } else if (sawOpponentRaise) {
        return true; // Hero raised AFTER opponent = 3-bet
      }
    }
    return false;
  }

}