import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../services/user_stats_service.dart';
import '../services/stats_calculator.dart';

/// Service to verify stats calculations by logging all data to console
class StatsVerificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Verify all stats and print detailed breakdown
  static Future<void> verifyAllStats() async {
    debugPrint('\n' + '='*80);
    debugPrint('📊 STATS VERIFICATION REPORT');
    debugPrint('='*80 + '\n');

    try {
      final userId = AuthService.userId;
      if (userId == null) {
        debugPrint('❌ Error: User not logged in');
        return;
      }

      // Fetch all sessions
      final sessions = await FirebaseService.getAllSessions();
      debugPrint('📁 Total Sessions Found: ${sessions.length}');
      debugPrint('📁 Session IDs: ${sessions.map((s) => s['id']).join(', ')}\n');

      // Variables to track calculated stats
      int totalHandsCalc = 0;
      int handsPlayedCalc = 0;
      int wonHandsCalc = 0;
      int vpipCountCalc = 0;
      int pfrCountCalc = 0;
      int threeBetCountCalc = 0;
      int totalPlayTimeMinutes = 0;

      // Process each session
      for (int i = 0; i < sessions.length; i++) {
        final session = sessions[i];
        final sessionId = session['id'] as String?;
        if (sessionId == null) continue;

        debugPrint('─'*80);
        debugPrint('Session ${i + 1}: ${session['sessionName'] ?? 'Unnamed'}');
        debugPrint('─'*80);
        debugPrint('Session ID: $sessionId');
        debugPrint('Game Type: ${session['gameType']}');
        debugPrint('Our Seat: ${session['ourSeatNumber']}');
        debugPrint('Player Count: ${session['playerCount']}');

        // Calculate session duration
        if (session['startTime'] != null && session['endTime'] != null) {
          try {
            DateTime startTime;
            DateTime endTime;

            // Handle both Timestamp and String formats
            if (session['startTime'] is Timestamp) {
              startTime = (session['startTime'] as Timestamp).toDate();
            } else if (session['startTime'] is String) {
              startTime = DateTime.parse(session['startTime']);
            } else {
              throw Exception('Unknown startTime type: ${session['startTime'].runtimeType}');
            }

            if (session['endTime'] is Timestamp) {
              endTime = (session['endTime'] as Timestamp).toDate();
            } else if (session['endTime'] is String) {
              endTime = DateTime.parse(session['endTime']);
            } else {
              throw Exception('Unknown endTime type: ${session['endTime'].runtimeType}');
            }

            final duration = endTime.difference(startTime).inMinutes;
            totalPlayTimeMinutes += duration;
            debugPrint('Duration: $duration minutes');
          } catch (e) {
            debugPrint('⚠️  Error parsing session times: $e');
          }
        }

        // Fetch hands for this session
        final hands = await _getHandsForSession(sessionId);
        debugPrint('Total Hands: ${hands.length}');

        if (hands.isEmpty) {
          debugPrint('⚠️  No hands found for this session\n');
          continue;
        }

        final ourSeat = session['ourSeatNumber'] as int?;
        if (ourSeat == null) {
          debugPrint('⚠️  Our seat number not found\n');
          continue;
        }

        int sessionHandsWon = 0;
        int sessionVpip = 0;
        int sessionPfr = 0;
        int sessionThreeBet = 0;
        int sessionHandsPlayed = 0;

        // Analyze each hand
        for (var hand in hands) {
          totalHandsCalc++;
          final handNumber = hand['handNumber'] ?? '?';
          final winnerId = hand['winnerId'];
          final actions = hand['actions'] as List<dynamic>? ?? [];

          debugPrint('\n  🃏 Hand #$handNumber:');
          debugPrint('     Winner: Seat $winnerId ${winnerId == ourSeat ? "✅ (WE WON!)" : ""}');

          // Check if we won
          if (winnerId == ourSeat) {
            wonHandsCalc++;
            sessionHandsWon++;
          }

          // Analyze our actions in this hand
          bool didPlay = false;
          bool didVpip = false;
          bool didPfr = false;
          bool didThreeBet = false;

          debugPrint('     Our Actions:');
          final ourActions = actions.where((a) => a['player'] == ourSeat).toList();

          if (ourActions.isEmpty) {
            debugPrint('       - None (folded or sat out)');
          } else {
            for (var action in ourActions) {
              final actionType = action['action']?.toString() ?? 'unknown';
              final street = action['street']?.toString() ?? 'unknown';
              final amount = action['amount'];

              debugPrint('       - $actionType on $street${amount != null ? " (\$$amount)" : ""}');

              if (street.toLowerCase() == 'preflop') {
                final actionLower = actionType.toLowerCase();

                if (actionLower == 'call' || actionLower == 'bet' || actionLower == 'raise') {
                  didPlay = true;
                  didVpip = true;

                  if (actionLower == 'bet' || actionLower == 'raise') {
                    didPfr = true;
                  }
                }

                // 3-bet detection is done after processing all actions
              }
            }
          }

          // Check for 3-bet (2nd voluntary raise preflop) via the canonical
          // detector so audit values match the live stats path.
          if (didPlay) {
            didThreeBet = StatsCalculator.didPlayerThreeBet(
                List<Map<String, dynamic>>.from(actions), ourSeat);
          }

          // Update counters
          if (didPlay) {
            handsPlayedCalc++;
            sessionHandsPlayed++;
          }
          if (didVpip) {
            vpipCountCalc++;
            sessionVpip++;
          }
          if (didPfr) {
            pfrCountCalc++;
            sessionPfr++;
          }
          if (didThreeBet) {
            threeBetCountCalc++;
            sessionThreeBet++;
          }

          // Log what we counted for this hand
          if (didPlay) {
            debugPrint('     ✓ Counted as: ${[
              if (didVpip) 'VPIP',
              if (didPfr) 'PFR',
              if (didThreeBet) '3-Bet',
            ].join(', ')}');
          }

          // Show opponent actions for context
          final opponentActions = actions.where((a) => a['player'] != ourSeat).toList();
          if (opponentActions.isNotEmpty) {
            debugPrint('     Opponent Actions:');
            for (var action in opponentActions) {
              debugPrint('       - Seat ${action['player']}: ${action['action']} on ${action['street']}');
            }
          }
        }

        // Session summary
        debugPrint('\n  📈 Session Summary:');
        debugPrint('     Hands: ${hands.length}');
        debugPrint('     Hands Played: $sessionHandsPlayed');
        debugPrint('     Hands Won: $sessionHandsWon (${hands.length > 0 ? (sessionHandsWon / hands.length * 100).toStringAsFixed(1) : "0.0"}%)');
        debugPrint('     VPIP: $sessionVpip (${hands.length > 0 ? (sessionVpip / hands.length * 100).toStringAsFixed(1) : "0.0"}%)');
        debugPrint('     PFR: $sessionPfr (${hands.length > 0 ? (sessionPfr / hands.length * 100).toStringAsFixed(1) : "0.0"}%)');
        debugPrint('     3-Bet: $sessionThreeBet');
        debugPrint('');
      }

      debugPrint('='*80);
      debugPrint('🧮 CALCULATED STATS FROM RAW DATA:');
      debugPrint('='*80);
      debugPrint('Total Hands: $totalHandsCalc');
      debugPrint('Hands Played: $handsPlayedCalc');
      debugPrint('Won Hands: $wonHandsCalc');
      debugPrint('Win Rate: ${handsPlayedCalc > 0 ? (wonHandsCalc / handsPlayedCalc * 100).toStringAsFixed(1) : "0.0"}%');
      debugPrint('VPIP Count: $vpipCountCalc');
      debugPrint('VPIP %: ${totalHandsCalc > 0 ? (vpipCountCalc / totalHandsCalc * 100).toStringAsFixed(1) : "0.0"}%');
      debugPrint('PFR Count: $pfrCountCalc');
      debugPrint('PFR %: ${totalHandsCalc > 0 ? (pfrCountCalc / totalHandsCalc * 100).toStringAsFixed(1) : "0.0"}%');
      debugPrint('3-Bet Count: $threeBetCountCalc');
      debugPrint('Total Play Time: $totalPlayTimeMinutes minutes (${(totalPlayTimeMinutes / 60).toStringAsFixed(1)} hours)');
      debugPrint('');

      // Fetch database stats
      final userStats = await UserStatsService.getUserStats(userId);
      if (userStats != null) {
        debugPrint('='*80);
        debugPrint('💾 DATABASE STATS (from user_stats collection):');
        debugPrint('='*80);
        debugPrint('Total Hands: ${userStats.totalHands}');
        debugPrint('Hands Played: ${userStats.handsPlayed}');
        debugPrint('Won Hands: ${userStats.wonHands}');
        debugPrint('Win Rate: ${userStats.handsPlayed > 0 ? (userStats.wonHands / userStats.handsPlayed * 100).toStringAsFixed(1) : "0.0"}%');
        debugPrint('VPIP Count: ${userStats.vpipCount}');
        debugPrint('VPIP %: ${userStats.totalHands > 0 ? (userStats.vpipCount / userStats.totalHands * 100).toStringAsFixed(1) : "0.0"}%');
        debugPrint('PFR Count: ${userStats.pfrCount}');
        debugPrint('PFR %: ${userStats.totalHands > 0 ? (userStats.pfrCount / userStats.totalHands * 100).toStringAsFixed(1) : "0.0"}%');
        debugPrint('3-Bet Count: ${userStats.threeBetCount}');
        debugPrint('Total Play Time: ${userStats.totalPlayTimeMinutes} minutes (${(userStats.totalPlayTimeMinutes / 60).toStringAsFixed(1)} hours)');
        debugPrint('Total Sessions: ${userStats.totalSessions} ⚠️  (Database shows ${userStats.totalSessions} but we found ${sessions.length} sessions in poker_sessions collection)');
        debugPrint('');

        // Compare
        debugPrint('='*80);
        debugPrint('⚖️  COMPARISON (Calculated vs Database):');
        debugPrint('='*80);
        _compareValues('Total Hands', totalHandsCalc, userStats.totalHands);
        _compareValues('Hands Played', handsPlayedCalc, userStats.handsPlayed);
        _compareValues('Won Hands', wonHandsCalc, userStats.wonHands);
        _compareValues('VPIP Count', vpipCountCalc, userStats.vpipCount);
        _compareValues('PFR Count', pfrCountCalc, userStats.pfrCount);
        _compareValues('3-Bet Count', threeBetCountCalc, userStats.threeBetCount);
        _compareValues('Play Time (min)', totalPlayTimeMinutes, userStats.totalPlayTimeMinutes);
        debugPrint('');

        // Check for double-counting pattern
        _checkDoubleCountingPattern(
          totalHandsCalc: totalHandsCalc,
          handsPlayedCalc: handsPlayedCalc,
          vpipCountCalc: vpipCountCalc,
          pfrCountCalc: pfrCountCalc,
          dbTotalHands: userStats.totalHands,
          dbHandsPlayed: userStats.handsPlayed,
          dbVpipCount: userStats.vpipCount,
          dbPfrCount: userStats.pfrCount,
        );
      }

      debugPrint('='*80);
      debugPrint('✅ VERIFICATION COMPLETE');
      debugPrint('='*80 + '\n');
    } catch (e, stackTrace) {
      debugPrint('❌ Error during verification: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  static Future<List<Map<String, dynamic>>> _getHandsForSession(String sessionId) async {
    debugPrint('     🔍 Fetching hands from: poker_sessions/$sessionId/poker_hands');

    final snapshot = await _firestore
        .collection('poker_sessions')
        .doc(sessionId)
        .collection('poker_hands')
        .orderBy('handNumber')
        .get();

    debugPrint('     🔍 Found ${snapshot.docs.length} hand documents');

    if (snapshot.docs.isNotEmpty) {
      debugPrint('     🔍 Hand document IDs: ${snapshot.docs.map((d) => d.id).join(', ')}');
    }

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  static void _compareValues(String label, int calculated, int database) {
    final match = calculated == database;
    final icon = match ? '✅' : '❌';
    debugPrint('$icon $label: Calculated=$calculated, Database=$database ${match ? "" : "⚠️ MISMATCH!"}');
  }

  /// Check if database values show a double-counting pattern
  ///
  /// Double-counting typically shows as:
  /// - Database values ≈ 2x calculated values
  /// - All stats inflated by similar ratio
  static void _checkDoubleCountingPattern({
    required int totalHandsCalc,
    required int handsPlayedCalc,
    required int vpipCountCalc,
    required int pfrCountCalc,
    required int dbTotalHands,
    required int dbHandsPlayed,
    required int dbVpipCount,
    required int dbPfrCount,
  }) {
    debugPrint('');
    debugPrint('='*80);
    debugPrint('🔍 DOUBLE-COUNTING DETECTION:');
    debugPrint('='*80);

    if (totalHandsCalc == 0) {
      debugPrint('⚠️  Cannot check for double-counting: no hands calculated');
      return;
    }

    // Calculate ratios
    final totalHandsRatio = totalHandsCalc > 0 ? dbTotalHands / totalHandsCalc : 0.0;
    final handsPlayedRatio = handsPlayedCalc > 0 ? dbHandsPlayed / handsPlayedCalc : 0.0;
    final vpipRatio = vpipCountCalc > 0 ? dbVpipCount / vpipCountCalc : 0.0;
    final pfrRatio = pfrCountCalc > 0 ? dbPfrCount / pfrCountCalc : 0.0;

    debugPrint('Ratio Analysis (DB / Calculated):');
    debugPrint('   Total Hands: ${totalHandsRatio.toStringAsFixed(2)}x');
    debugPrint('   Hands Played: ${handsPlayedRatio.toStringAsFixed(2)}x');
    debugPrint('   VPIP Count: ${vpipRatio.toStringAsFixed(2)}x');
    debugPrint('   PFR Count: ${pfrRatio.toStringAsFixed(2)}x');
    debugPrint('');

    // Check for consistent ~2x inflation (within 10% of 2.0)
    final ratios = [totalHandsRatio, handsPlayedRatio, vpipRatio, pfrRatio]
        .where((r) => r > 0)
        .toList();

    if (ratios.isEmpty) {
      debugPrint('✅ No ratios to analyze');
      return;
    }

    final avgRatio = ratios.reduce((a, b) => a + b) / ratios.length;
    final isDoubleCount = avgRatio >= 1.8 && avgRatio <= 2.2;

    if (isDoubleCount) {
      debugPrint('⚠️  WARNING: DOUBLE-COUNTING DETECTED!');
      debugPrint('   Average ratio: ${avgRatio.toStringAsFixed(2)}x (close to 2x)');
      debugPrint('');
      debugPrint('   This indicates stats were being incremented twice per hand.');
      debugPrint('   Common causes:');
      debugPrint('   1. FirebaseService._updateUserStatsFromHand() AND');
      debugPrint('   2. PokerSessionManager._updateOptimizedStats() both updating');
      debugPrint('');
      debugPrint('   FIX: Run UserStatsService.recalculateUserStats(userId) to repair');
    } else if (avgRatio > 1.1) {
      debugPrint('⚠️  WARNING: Stats appear inflated (${avgRatio.toStringAsFixed(2)}x)');
      debugPrint('   Consider running recalculation to repair');
    } else {
      debugPrint('✅ No double-counting pattern detected');
      debugPrint('   Average ratio: ${avgRatio.toStringAsFixed(2)}x (expected: 1.0x)');
    }
    debugPrint('');
  }
}
