import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../services/user_stats_service.dart';

/// Service to verify stats calculations by logging all data to console
class StatsVerificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Verify all stats and print detailed breakdown
  static Future<void> verifyAllStats() async {
    print('\n' + '='*80);
    print('📊 STATS VERIFICATION REPORT');
    print('='*80 + '\n');

    try {
      final userId = AuthService.userId;
      if (userId == null) {
        print('❌ Error: User not logged in');
        return;
      }

      // Fetch all sessions
      final sessions = await FirebaseService.getAllSessions();
      print('📁 Total Sessions Found: ${sessions.length}');
      print('📁 Session IDs: ${sessions.map((s) => s['id']).join(', ')}\n');

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

        print('─'*80);
        print('Session ${i + 1}: ${session['sessionName'] ?? 'Unnamed'}');
        print('─'*80);
        print('Session ID: $sessionId');
        print('Game Type: ${session['gameType']}');
        print('Our Seat: ${session['ourSeatNumber']}');
        print('Player Count: ${session['playerCount']}');

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
            print('Duration: $duration minutes');
          } catch (e) {
            print('⚠️  Error parsing session times: $e');
          }
        }

        // Fetch hands for this session
        final hands = await _getHandsForSession(sessionId);
        print('Total Hands: ${hands.length}');

        if (hands.isEmpty) {
          print('⚠️  No hands found for this session\n');
          continue;
        }

        final ourSeat = session['ourSeatNumber'] as int?;
        if (ourSeat == null) {
          print('⚠️  Our seat number not found\n');
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

          print('\n  🃏 Hand #$handNumber:');
          print('     Winner: Seat $winnerId ${winnerId == ourSeat ? "✅ (WE WON!)" : ""}');

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

          print('     Our Actions:');
          final ourActions = actions.where((a) => a['player'] == ourSeat).toList();

          if (ourActions.isEmpty) {
            print('       - None (folded or sat out)');
          } else {
            for (var action in ourActions) {
              final actionType = action['action']?.toString() ?? 'unknown';
              final street = action['street']?.toString() ?? 'unknown';
              final amount = action['amount'];

              print('       - $actionType on $street${amount != null ? " (\$$amount)" : ""}');

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

          // Check for 3-bet using correct logic:
          // 3-bet = hero raised AFTER seeing an opponent's raise
          if (didPlay) {
            didThreeBet = _didPlayerThreeBet(actions, ourSeat);
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
            print('     ✓ Counted as: ${[
              if (didVpip) 'VPIP',
              if (didPfr) 'PFR',
              if (didThreeBet) '3-Bet',
            ].join(', ')}');
          }

          // Show opponent actions for context
          final opponentActions = actions.where((a) => a['player'] != ourSeat).toList();
          if (opponentActions.isNotEmpty) {
            print('     Opponent Actions:');
            for (var action in opponentActions) {
              print('       - Seat ${action['player']}: ${action['action']} on ${action['street']}');
            }
          }
        }

        // Session summary
        print('\n  📈 Session Summary:');
        print('     Hands: ${hands.length}');
        print('     Hands Played: $sessionHandsPlayed');
        print('     Hands Won: $sessionHandsWon (${hands.length > 0 ? (sessionHandsWon / hands.length * 100).toStringAsFixed(1) : "0.0"}%)');
        print('     VPIP: $sessionVpip (${hands.length > 0 ? (sessionVpip / hands.length * 100).toStringAsFixed(1) : "0.0"}%)');
        print('     PFR: $sessionPfr (${hands.length > 0 ? (sessionPfr / hands.length * 100).toStringAsFixed(1) : "0.0"}%)');
        print('     3-Bet: $sessionThreeBet');
        print('');
      }

      print('='*80);
      print('🧮 CALCULATED STATS FROM RAW DATA:');
      print('='*80);
      print('Total Hands: $totalHandsCalc');
      print('Hands Played: $handsPlayedCalc');
      print('Won Hands: $wonHandsCalc');
      print('Win Rate: ${handsPlayedCalc > 0 ? (wonHandsCalc / handsPlayedCalc * 100).toStringAsFixed(1) : "0.0"}%');
      print('VPIP Count: $vpipCountCalc');
      print('VPIP %: ${totalHandsCalc > 0 ? (vpipCountCalc / totalHandsCalc * 100).toStringAsFixed(1) : "0.0"}%');
      print('PFR Count: $pfrCountCalc');
      print('PFR %: ${totalHandsCalc > 0 ? (pfrCountCalc / totalHandsCalc * 100).toStringAsFixed(1) : "0.0"}%');
      print('3-Bet Count: $threeBetCountCalc');
      print('Total Play Time: $totalPlayTimeMinutes minutes (${(totalPlayTimeMinutes / 60).toStringAsFixed(1)} hours)');
      print('');

      // Fetch database stats
      final userStats = await UserStatsService.getUserStats(userId);
      if (userStats != null) {
        print('='*80);
        print('💾 DATABASE STATS (from user_stats collection):');
        print('='*80);
        print('Total Hands: ${userStats.totalHands}');
        print('Hands Played: ${userStats.handsPlayed}');
        print('Won Hands: ${userStats.wonHands}');
        print('Win Rate: ${userStats.handsPlayed > 0 ? (userStats.wonHands / userStats.handsPlayed * 100).toStringAsFixed(1) : "0.0"}%');
        print('VPIP Count: ${userStats.vpipCount}');
        print('VPIP %: ${userStats.totalHands > 0 ? (userStats.vpipCount / userStats.totalHands * 100).toStringAsFixed(1) : "0.0"}%');
        print('PFR Count: ${userStats.pfrCount}');
        print('PFR %: ${userStats.totalHands > 0 ? (userStats.pfrCount / userStats.totalHands * 100).toStringAsFixed(1) : "0.0"}%');
        print('3-Bet Count: ${userStats.threeBetCount}');
        print('Total Play Time: ${userStats.totalPlayTimeMinutes} minutes (${(userStats.totalPlayTimeMinutes / 60).toStringAsFixed(1)} hours)');
        print('Total Sessions: ${userStats.totalSessions} ⚠️  (Database shows ${userStats.totalSessions} but we found ${sessions.length} sessions in poker_sessions collection)');
        print('');

        // Compare
        print('='*80);
        print('⚖️  COMPARISON (Calculated vs Database):');
        print('='*80);
        _compareValues('Total Hands', totalHandsCalc, userStats.totalHands);
        _compareValues('Hands Played', handsPlayedCalc, userStats.handsPlayed);
        _compareValues('Won Hands', wonHandsCalc, userStats.wonHands);
        _compareValues('VPIP Count', vpipCountCalc, userStats.vpipCount);
        _compareValues('PFR Count', pfrCountCalc, userStats.pfrCount);
        _compareValues('3-Bet Count', threeBetCountCalc, userStats.threeBetCount);
        _compareValues('Play Time (min)', totalPlayTimeMinutes, userStats.totalPlayTimeMinutes);
        print('');

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

      print('='*80);
      print('✅ VERIFICATION COMPLETE');
      print('='*80 + '\n');
    } catch (e, stackTrace) {
      print('❌ Error during verification: $e');
      print('Stack trace: $stackTrace');
    }
  }

  static Future<List<Map<String, dynamic>>> _getHandsForSession(String sessionId) async {
    print('     🔍 Fetching hands from: poker_sessions/$sessionId/poker_hands');

    final snapshot = await _firestore
        .collection('poker_sessions')
        .doc(sessionId)
        .collection('poker_hands')
        .orderBy('handNumber')
        .get();

    print('     🔍 Found ${snapshot.docs.length} hand documents');

    if (snapshot.docs.isNotEmpty) {
      print('     🔍 Hand document IDs: ${snapshot.docs.map((d) => d.id).join(', ')}');
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
    print('$icon $label: Calculated=$calculated, Database=$database ${match ? "" : "⚠️ MISMATCH!"}');
  }

  /// Detect if player made a 3-bet (re-raised AFTER seeing an opponent's raise)
  static bool _didPlayerThreeBet(List<dynamic> actions, int playerSeatNumber) {
    bool sawOpponentRaise = false;

    for (final action in actions) {
      final street = action['street']?.toString().toLowerCase() ?? '';
      if (street != 'preflop') continue;

      final playerId = action['player'] as int?;
      final actionType = action['action']?.toString().toLowerCase() ?? '';

      // Only look at raise actions
      if (actionType != 'raise') continue;

      if (playerId != playerSeatNumber) {
        // Opponent raised
        sawOpponentRaise = true;
      } else if (sawOpponentRaise) {
        // Hero raised AFTER seeing an opponent raise = 3-bet
        return true;
      }
    }
    return false;
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
    print('');
    print('='*80);
    print('🔍 DOUBLE-COUNTING DETECTION:');
    print('='*80);

    if (totalHandsCalc == 0) {
      print('⚠️  Cannot check for double-counting: no hands calculated');
      return;
    }

    // Calculate ratios
    final totalHandsRatio = totalHandsCalc > 0 ? dbTotalHands / totalHandsCalc : 0.0;
    final handsPlayedRatio = handsPlayedCalc > 0 ? dbHandsPlayed / handsPlayedCalc : 0.0;
    final vpipRatio = vpipCountCalc > 0 ? dbVpipCount / vpipCountCalc : 0.0;
    final pfrRatio = pfrCountCalc > 0 ? dbPfrCount / pfrCountCalc : 0.0;

    print('Ratio Analysis (DB / Calculated):');
    print('   Total Hands: ${totalHandsRatio.toStringAsFixed(2)}x');
    print('   Hands Played: ${handsPlayedRatio.toStringAsFixed(2)}x');
    print('   VPIP Count: ${vpipRatio.toStringAsFixed(2)}x');
    print('   PFR Count: ${pfrRatio.toStringAsFixed(2)}x');
    print('');

    // Check for consistent ~2x inflation (within 10% of 2.0)
    final ratios = [totalHandsRatio, handsPlayedRatio, vpipRatio, pfrRatio]
        .where((r) => r > 0)
        .toList();

    if (ratios.isEmpty) {
      print('✅ No ratios to analyze');
      return;
    }

    final avgRatio = ratios.reduce((a, b) => a + b) / ratios.length;
    final isDoubleCount = avgRatio >= 1.8 && avgRatio <= 2.2;

    if (isDoubleCount) {
      print('⚠️  WARNING: DOUBLE-COUNTING DETECTED!');
      print('   Average ratio: ${avgRatio.toStringAsFixed(2)}x (close to 2x)');
      print('');
      print('   This indicates stats were being incremented twice per hand.');
      print('   Common causes:');
      print('   1. FirebaseService._updateUserStatsFromHand() AND');
      print('   2. PokerSessionManager._updateOptimizedStats() both updating');
      print('');
      print('   FIX: Run UserStatsService.recalculateUserStats(userId) to repair');
    } else if (avgRatio > 1.1) {
      print('⚠️  WARNING: Stats appear inflated (${avgRatio.toStringAsFixed(2)}x)');
      print('   Consider running recalculation to repair');
    } else {
      print('✅ No double-counting pattern detected');
      print('   Average ratio: ${avgRatio.toStringAsFixed(2)}x (expected: 1.0x)');
    }
    print('');
  }
}
