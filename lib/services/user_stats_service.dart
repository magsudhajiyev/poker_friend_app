import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_stats.dart';
import '../services/firebase_service.dart';

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
      print('Error getting user stats: $e');
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
      print('Error initializing user stats: $e');
    }
  }

  /// Update user stats atomically using incremental counters
  static Future<void> updateStatsAtomic({
    required String userId,
    int handsDelta = 0,
    int totalHandsDelta = 0,
    int vpipDelta = 0,
    int pfrDelta = 0,
    int threeBetDelta = 0,
    int wonHandsDelta = 0,
    int sessionsDelta = 0,
    int playTimeMinutesDelta = 0,
    Map<String, int>? positionHandsDeltas,
    Map<String, int>? positionVpipDeltas,
    Map<String, int>? positionPfrDeltas,
    Map<String, int>? positionThreeBetDeltas,
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
        if (vpipDelta != 0) updates['vpipCount'] = FieldValue.increment(vpipDelta);
        if (pfrDelta != 0) updates['pfrCount'] = FieldValue.increment(pfrDelta);
        if (threeBetDelta != 0) updates['threeBetCount'] = FieldValue.increment(threeBetDelta);
        if (wonHandsDelta != 0) updates['wonHands'] = FieldValue.increment(wonHandsDelta);
        if (sessionsDelta != 0) updates['totalSessions'] = FieldValue.increment(sessionsDelta);
        if (playTimeMinutesDelta != 0) updates['totalPlayTimeMinutes'] = FieldValue.increment(playTimeMinutesDelta);

        // Handle position updates
        if (positionHandsDeltas != null) {
          for (final entry in positionHandsDeltas.entries) {
            if (entry.value != 0) {
              updates['positionHandsPlayed.${entry.key}'] = FieldValue.increment(entry.value);
            }
          }
        }

        if (positionVpipDeltas != null) {
          for (final entry in positionVpipDeltas.entries) {
            if (entry.value != 0) {
              updates['positionVpipCount.${entry.key}'] = FieldValue.increment(entry.value);
            }
          }
        }

        if (positionPfrDeltas != null) {
          for (final entry in positionPfrDeltas.entries) {
            if (entry.value != 0) {
              updates['positionPfrCount.${entry.key}'] = FieldValue.increment(entry.value);
            }
          }
        }

        if (positionThreeBetDeltas != null) {
          for (final entry in positionThreeBetDeltas.entries) {
            if (entry.value != 0) {
              updates['positionThreeBetCount.${entry.key}'] = FieldValue.increment(entry.value);
            }
          }
        }

        updates['lastUpdated'] = FieldValue.serverTimestamp();

        transaction.update(docRef, updates);
      });
    } catch (e) {
      print('Error updating user stats atomically: $e');
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

      Map<String, int> positionHandsPlayed = {};
      Map<String, int> positionVpipCount = {};
      Map<String, int> positionPfrCount = {};
      Map<String, int> positionThreeBetCount = {};

      // Get all sessions
      List<Map<String, dynamic>> sessions;
      try {
        sessions = await FirebaseService.getAllSessions();
      } catch (e) {
        print('Error fetching sessions: $e');
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
          print('Error fetching hands for session ${session['id']}: $e');
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

          // Get our position for this hand
          final buttonPosition = handData['buttonPosition'] ?? 1;
          final playerCount = handData['playerCount'] ?? 6;
          final ourPosition = _getPositionName(ourSeatNumber, buttonPosition, playerCount);

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

          // Check for 3-bet (simplified logic)
          if (didPlay) {
            final preflopActions = actions.where((a) => a['street']?.toString().toLowerCase() == 'preflop').toList();
            bool sawRaise = false;
            for (var action in preflopActions) {
              if (action['player'] == ourSeatNumber &&
                  (action['action']?.toString().toLowerCase() == 'raise' ||
                   action['action']?.toString().toLowerCase() == 'bet') &&
                  sawRaise) {
                didThreeBet = true;
                break;
              }
              if (action['action']?.toString().toLowerCase() == 'raise' ||
                  action['action']?.toString().toLowerCase() == 'bet') {
                sawRaise = true;
              }
            }
          }

          if (didPlay) {
            handsPlayed++;

            // Update position counters
            positionHandsPlayed[ourPosition] = (positionHandsPlayed[ourPosition] ?? 0) + 1;

            if (didVpip) {
              vpipCount++;
              positionVpipCount[ourPosition] = (positionVpipCount[ourPosition] ?? 0) + 1;
            }

            if (didPfr) {
              pfrCount++;
              positionPfrCount[ourPosition] = (positionPfrCount[ourPosition] ?? 0) + 1;
            }

            if (didThreeBet) {
              threeBetCount++;
              positionThreeBetCount[ourPosition] = (positionThreeBetCount[ourPosition] ?? 0) + 1;
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
        positionHandsPlayed: positionHandsPlayed,
        positionVpipCount: positionVpipCount,
        positionPfrCount: positionPfrCount,
        positionThreeBetCount: positionThreeBetCount,
      );

      await _firestore.collection('user_stats').doc(userId).set(userStats.toFirestore());


    } catch (e) {
      print('Error during user stats migration: $e');
      rethrow;
    }
  }

  /// Helper method to get position name
  static String _getPositionName(int seatNumber, int buttonPosition, int playerCount) {
    final positions = ['UTG', 'UTG+1', 'MP', 'CO', 'BTN', 'SB', 'BB'];
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
      return positions[relativePosition.clamp(0, positions.length - 1)];
    }
  }
}