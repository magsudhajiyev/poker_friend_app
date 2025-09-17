import 'dart:isolate';
import '../models/opponent_stats.dart';
import 'firebase_service.dart';
import 'local_storage_service.dart';
import 'opponent_stats_service.dart';
import 'opponent_service.dart';

/// Service for migrating existing hand data to optimized stats format
/// This is a one-time operation that processes all existing hands
class StatsMigrationService {

  /// Migrate all existing opponents to optimized stats format
  /// This is a one-time operation that should be run after deployment
  static Future<void> migrateAllOpponentsToOptimizedStats() async {
    print('🚀 Starting one-time migration to optimized opponent stats...');

    try {
      // Get all unique opponent names from existing sessions
      final opponentNames = await _getAllUniqueOpponentNames();
      final opponentList = opponentNames.toList();
      print('📊 Found ${opponentList.length} unique opponents to migrate');

      int successCount = 0;
      int errorCount = 0;

      // Process each opponent
      for (int i = 0; i < opponentList.length; i++) {
        final opponentName = opponentList[i];

        try {
          print('🔄 Migrating opponent ${i + 1}/${opponentList.length}: $opponentName');

          // Calculate stats from all hands involving this opponent
          final stats = await _calculateOpponentStatsFromAllHands(opponentName);

          if (stats != null) {
            await OpponentStatsService.saveOpponentStats(stats);
            successCount++;
            print('✅ Migrated $opponentName: ${stats.handsPlayed} hands, ${stats.vpipPercentage.toStringAsFixed(1)}% VPIP');
          } else {
            print('⚠️ No hands found for $opponentName');
          }

        } catch (e) {
          errorCount++;
          print('❌ Failed to migrate $opponentName: $e');
        }
      }

      print('🎉 Migration completed: $successCount successful, $errorCount errors');

      // Set migration completion flag
      await _setMigrationCompleted();

    } catch (e) {
      print('❌ Migration failed: $e');
      rethrow;
    }
  }

  /// Rebuild stats for a specific opponent from all their hands
  static Future<void> rebuildOpponentStats(String opponentName) async {
    print('🔄 Rebuilding stats for opponent: $opponentName');

    try {
      final stats = await _calculateOpponentStatsFromAllHands(opponentName);

      if (stats != null) {
        await OpponentStatsService.saveOpponentStats(stats);
        print('✅ Rebuilt stats for $opponentName: ${stats.handsPlayed} hands');
      } else {
        print('⚠️ No hands found for $opponentName');
      }

    } catch (e) {
      print('❌ Failed to rebuild stats for $opponentName: $e');
      rethrow;
    }
  }

  /// Migrate stats for just one specific opponent (like Gringo)
  static Future<void> migrateSingleOpponent(String opponentName) async {
    print('🚀 Starting single opponent migration for: $opponentName');

    try {
      // Calculate stats from all hands involving this opponent
      final stats = await _calculateOpponentStatsFromAllHands(opponentName);

      if (stats != null) {
        await OpponentStatsService.saveOpponentStats(stats);
        print('✅ Migrated $opponentName: ${stats.handsPlayed} hands, ${stats.vpipPercentage.toStringAsFixed(1)}% VPIP');
      } else {
        print('⚠️ No hands found for $opponentName');
      }

      print('🎉 Single opponent migration completed!');

    } catch (e) {
      print('❌ Failed to migrate $opponentName: $e');
      rethrow;
    }
  }

  /// Run migration in background isolate to avoid blocking UI
  static Future<void> migrateInBackground() async {
    try {
      await Isolate.run(() => migrateAllOpponentsToOptimizedStats());
    } catch (e) {
      print('❌ Background migration failed: $e');
      rethrow;
    }
  }

  /// Check if migration has been completed
  static Future<bool> isMigrationNeeded() async {
    try {
      // Check if migration completion flag exists
      final isCompleted = await _isMigrationCompleted();
      return !isCompleted;
    } catch (e) {
      print('⚠️ Error checking migration status: $e');
      return true; // Assume migration needed on error
    }
  }

  /// Get migration progress information
  static Future<Map<String, dynamic>> getMigrationProgress() async {
    try {
      final allOpponents = await _getAllUniqueOpponentNames();
      int migratedCount = 0;

      // Check how many already have optimized stats
      for (final opponentName in allOpponents) {
        final stats = await OpponentStatsService.getOpponentStats(opponentName);
        if (stats != null && stats.handsPlayed > 0) {
          migratedCount++;
        }
      }

      return {
        'totalOpponents': allOpponents.length,
        'migratedOpponents': migratedCount,
        'remainingOpponents': allOpponents.length - migratedCount,
        'percentageComplete': allOpponents.length > 0
          ? (migratedCount / allOpponents.length * 100).round()
          : 100,
        'isComplete': migratedCount == allOpponents.length,
      };

    } catch (e) {
      print('❌ Error getting migration progress: $e');
      return {
        'totalOpponents': 0,
        'migratedOpponents': 0,
        'remainingOpponents': 0,
        'percentageComplete': 0,
        'isComplete': false,
        'error': e.toString(),
      };
    }
  }

  // Private helper methods

  /// Get all saved opponent names from the opponents collection
  /// This ensures we only migrate actual saved opponents, not positional names like BTN, SB, BB
  static Future<Set<String>> _getAllUniqueOpponentNames() async {
    final opponents = <String>{};

    try {
      // Get all saved opponents using OpponentService
      final savedOpponents = await OpponentService.getAllOpponents();
      for (final opponent in savedOpponents) {
        if (opponent.name.isNotEmpty) {
          opponents.add(opponent.name);
        }
      }
      print('📊 Found ${opponents.length} saved opponents: ${opponents.join(', ')}');
    } catch (e) {
      print('⚠️ Error getting saved opponents: $e');
    }

    return opponents;
  }

  /// Get a sample of opponent names for migration checking
  static Future<List<String>> _getSampleOpponentNames(int sampleSize) async {
    final allOpponents = await _getAllUniqueOpponentNames();
    final opponentList = allOpponents.toList();

    if (opponentList.length <= sampleSize) {
      return opponentList;
    }

    // Return random sample
    opponentList.shuffle();
    return opponentList.take(sampleSize).toList();
  }

  /// Calculate opponent stats from all hands (heavy operation)
  /// This replicates the old logic but builds optimized counters instead
  static Future<OpponentStats?> _calculateOpponentStatsFromAllHands(String opponentName) async {
    try {
      print('📊 Calculating stats from all hands for: $opponentName');

      // Initialize counters
      int handsPlayed = 0;
      int sessionsPlayed = 0;
      int vpipCount = 0;
      int pfrCount = 0;
      int aggressionActions = 0;
      int passiveActions = 0;
      int foldCount = 0;
      int checkCount = 0;
      int callCount = 0;
      int betCount = 0;
      int raiseCount = 0;
      int threeBetCount = 0;

      final processedSessions = <String>{};

      // Get all sessions and process hands
      List<Map<String, dynamic>> sessions;
      try {
        sessions = await FirebaseService.getAllSessions();
      } catch (e) {
        sessions = await LocalStorageService.getUserSessions();
      }

      for (final session in sessions) {
        bool foundInSession = false;
        List<Map<String, dynamic>> hands;

        try {
          hands = await FirebaseService.getSessionHands(session['id']);
        } catch (e) {
          hands = (session['hands'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
        }

        for (final hand in hands) {
          final playerNames = hand['playerNames'] as Map<String, dynamic>?;
          if (playerNames == null) continue;

          // Check if opponent is in this hand
          bool opponentInHand = false;
          int? opponentPlayerId;

          for (final entry in playerNames.entries) {
            if (entry.value.toLowerCase().contains(opponentName.toLowerCase()) ||
                opponentName.toLowerCase().contains(entry.value.toLowerCase())) {
              opponentInHand = true;
              opponentPlayerId = int.tryParse(entry.key);
              break;
            }
          }

          if (!opponentInHand || opponentPlayerId == null) continue;

          // Count this hand
          handsPlayed++;
          foundInSession = true;

          // Process actions for this opponent
          final actions = hand['actions'] as List<dynamic>? ?? [];
          bool hasVPIP = false;
          bool hasPFR = false;
          int preflopRaises = 0;

          for (final action in actions) {
            final actionMap = action as Map<String, dynamic>;
            final playerId = actionMap['player'] as int?;
            final actionType = actionMap['action'] as String?;
            final street = actionMap['street'] as String?;

            if (playerId != opponentPlayerId || actionType == null || street == null) continue;

            final actionLower = actionType.toLowerCase();
            final isPreflop = street.toLowerCase() == 'preflop';

            // Count actions
            switch (actionLower) {
              case 'fold':
                foldCount++;
                break;
              case 'check':
                checkCount++;
                break;
              case 'call':
                callCount++;
                passiveActions++;
                if (!_isBlindAction(actionMap)) {
                  hasVPIP = true;
                }
                break;
              case 'bet':
                betCount++;
                aggressionActions++;
                hasVPIP = true;
                break;
              case 'raise':
                raiseCount++;
                aggressionActions++;
                hasVPIP = true;
                if (isPreflop) {
                  preflopRaises++;
                }
                break;
            }
          }

          // Update hand-level stats
          if (hasVPIP) vpipCount++;
          if (preflopRaises > 0) pfrCount++;
          if (preflopRaises >= 2) threeBetCount++;
        }

        if (foundInSession) {
          sessionsPlayed++;
          processedSessions.add(session['id']);
        }
      }

      if (handsPlayed == 0) {
        print('⚠️ No hands found for opponent: $opponentName');
        return null;
      }

      final stats = OpponentStats(
        opponentId: opponentName,
        handsPlayed: handsPlayed,
        sessionsPlayed: sessionsPlayed,
        vpipCount: vpipCount,
        pfrCount: pfrCount,
        aggressionActions: aggressionActions,
        passiveActions: passiveActions,
        foldCount: foldCount,
        checkCount: checkCount,
        callCount: callCount,
        betCount: betCount,
        raiseCount: raiseCount,
        threeBetCount: threeBetCount,
      );

      print('✅ Calculated stats for $opponentName: ${stats.handsPlayed} hands, ${stats.vpipPercentage.toStringAsFixed(1)}% VPIP, ${stats.pfrPercentage.toStringAsFixed(1)}% PFR');

      return stats;

    } catch (e) {
      print('❌ Error calculating stats for $opponentName: $e');
      return null;
    }
  }

  /// Helper to detect blind actions (not voluntary)
  static bool _isBlindAction(Map<String, dynamic> action) {
    final actionType = (action['action'] as String?)?.toLowerCase();
    return actionType == 'small blind' ||
           actionType == 'big blind' ||
           actionType == 'ante';
  }

  /// Set migration completion flag
  static Future<void> _setMigrationCompleted() async {
    try {
      // Store flag in Firebase
      await FirebaseService.setMigrationFlag(completed: true);
    } catch (e) {
      print('⚠️ Failed to set Firebase migration flag, using local storage: $e');
    }

    // Always store locally as backup
    await LocalStorageService.setMigrationCompleted();
  }

  /// Check if migration has been completed
  static Future<bool> _isMigrationCompleted() async {
    try {
      // Check Firebase first
      final firebaseCompleted = await FirebaseService.isMigrationCompleted();
      if (firebaseCompleted) return true;
    } catch (e) {
      print('⚠️ Firebase migration check failed, using local storage: $e');
    }

    // Fallback to local storage
    return await LocalStorageService.isMigrationCompleted();
  }
}