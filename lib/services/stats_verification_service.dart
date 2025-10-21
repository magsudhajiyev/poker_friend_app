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
      print('📁 Total Sessions Found: ${sessions.length}\n');

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
          final startTime = (session['startTime'] as Timestamp).toDate();
          final endTime = (session['endTime'] as Timestamp).toDate();
          final duration = endTime.difference(startTime).inMinutes;
          totalPlayTimeMinutes += duration;
          print('Duration: $duration minutes');
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

                // Check for 3-bet (need to count raises in the hand)
                if (actionLower == 'raise') {
                  int raiseCount = ourActions
                      .where((a) =>
                        a['street']?.toString().toLowerCase() == 'preflop' &&
                        (a['action']?.toString().toLowerCase() == 'raise' ||
                         a['action']?.toString().toLowerCase() == 'bet'))
                      .length;
                  if (raiseCount >= 2) {
                    didThreeBet = true;
                  }
                }
              }
            }
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
        print('     VPIP: $sessionVpip (${sessionHandsPlayed > 0 ? (sessionVpip / sessionHandsPlayed * 100).toStringAsFixed(1) : "0.0"}%)');
        print('     PFR: $sessionPfr (${sessionHandsPlayed > 0 ? (sessionPfr / sessionHandsPlayed * 100).toStringAsFixed(1) : "0.0"}%)');
        print('     3-Bet: $sessionThreeBet');
        print('');
      }

      print('='*80);
      print('🧮 CALCULATED STATS FROM RAW DATA:');
      print('='*80);
      print('Total Hands: $totalHandsCalc');
      print('Hands Played: $handsPlayedCalc');
      print('Won Hands: $wonHandsCalc');
      print('Win Rate: ${totalHandsCalc > 0 ? (wonHandsCalc / totalHandsCalc * 100).toStringAsFixed(1) : "0.0"}%');
      print('VPIP Count: $vpipCountCalc');
      print('VPIP %: ${handsPlayedCalc > 0 ? (vpipCountCalc / handsPlayedCalc * 100).toStringAsFixed(1) : "0.0"}%');
      print('PFR Count: $pfrCountCalc');
      print('PFR %: ${handsPlayedCalc > 0 ? (pfrCountCalc / handsPlayedCalc * 100).toStringAsFixed(1) : "0.0"}%');
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
        print('Win Rate: ${userStats.totalHands > 0 ? (userStats.wonHands / userStats.totalHands * 100).toStringAsFixed(1) : "0.0"}%');
        print('VPIP Count: ${userStats.vpipCount}');
        print('VPIP %: ${userStats.handsPlayed > 0 ? (userStats.vpipCount / userStats.handsPlayed * 100).toStringAsFixed(1) : "0.0"}%');
        print('PFR Count: ${userStats.pfrCount}');
        print('PFR %: ${userStats.handsPlayed > 0 ? (userStats.pfrCount / userStats.handsPlayed * 100).toStringAsFixed(1) : "0.0"}%');
        print('3-Bet Count: ${userStats.threeBetCount}');
        print('Total Play Time: ${userStats.totalPlayTimeMinutes} minutes (${(userStats.totalPlayTimeMinutes / 60).toStringAsFixed(1)} hours)');
        print('Total Sessions: ${userStats.totalSessions}');
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
    final snapshot = await _firestore
        .collection('poker_sessions')
        .doc(sessionId)
        .collection('hands')
        .orderBy('handNumber')
        .get();

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
}
