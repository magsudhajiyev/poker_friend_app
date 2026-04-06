import 'dart:convert';
import 'dart:isolate';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/opponent_stats.dart';
import 'firebase_service.dart';
import 'local_storage_service.dart';
import 'stats_migration_service.dart';
import 'app_data_cache.dart';

/// Optimized service for managing opponent statistics using incremental updates
/// instead of recalculating from all hands every time
class OpponentStatsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  static CollectionReference get _statsCollection =>
      _firestore.collection('opponent_stats');

  // Local storage keys
  static const String _localStatsKey = 'poker_opponent_stats';

  /// Get current user ID
  static String? get _userId => _auth.currentUser?.uid;

  /// Get opponent stats (fast O(1) lookup from pre-computed data)
  static Future<OpponentStats?> getOpponentStats(String opponentId) async {
    try {
      // Try Firebase first
      final stats = await _getStatsFromFirebase(opponentId);
      if (stats != null) {
        // Also cache locally for offline access
        await _saveStatsToLocal(stats);
      }
      // Return Firebase result (even if null - means no stats exist)
      return stats;
    } catch (e) {
      print('⚠️ Firebase stats load failed, using local storage: $e');
      // Only fallback to local storage on actual errors
      return await _getStatsFromLocal(opponentId);
    }
  }

  /// Save or update opponent stats
  static Future<void> saveOpponentStats(OpponentStats stats) async {
    try {
      // Save to Firebase first
      await _saveStatsToFirebase(stats);
      print('✅ Stats saved to Firebase: ${stats.opponentId}');
    } catch (e) {
      print('⚠️ Firebase stats save failed, using local storage: $e');
    }

    // Always save to local storage as backup
    await _saveStatsToLocal(stats);
    print('✅ Stats saved locally: ${stats.opponentId}');
  }

  /// Update opponent stats incrementally (fast O(1) operation)
  /// This is the key optimization - instead of recalculating from 500+ hands,
  /// we just add deltas to existing counters
  static Future<void> updateStatsIncremental({
    required String opponentId,
    int handsDelta = 0,
    int sessionsDelta = 0,
    int vpipDelta = 0,
    int pfrDelta = 0,
    int aggressionDelta = 0,
    int passiveDelta = 0,
    int foldDelta = 0,
    int checkDelta = 0,
    int callDelta = 0,
    int betDelta = 0,
    int raiseDelta = 0,
    int threeBetDelta = 0,
    int cbetDelta = 0,
    int fold3betDelta = 0,
    // New opportunity counters
    int walksCountDelta = 0,
    int threeBetOpportunityDelta = 0,
    int facing3BetCountDelta = 0,
    int cbetOpportunityDelta = 0,
    int stealCountDelta = 0,
    int stealOpportunityDelta = 0,
    int checkRaiseFlopCountDelta = 0,
    int checkRaiseFlopOpportunityDelta = 0,
  }) async {
    // Get current stats (or create new if doesn't exist)
    OpponentStats currentStats = await getOpponentStats(opponentId) ??
        OpponentStats(opponentId: opponentId);

    // Apply incremental updates
    final updatedStats = currentStats.incrementWith(
      handsDelta: handsDelta,
      sessionsDelta: sessionsDelta,
      vpipDelta: vpipDelta,
      pfrDelta: pfrDelta,
      aggressionDelta: aggressionDelta,
      passiveDelta: passiveDelta,
      foldDelta: foldDelta,
      checkDelta: checkDelta,
      callDelta: callDelta,
      betDelta: betDelta,
      raiseDelta: raiseDelta,
      threeBetDelta: threeBetDelta,
      cbetDelta: cbetDelta,
      fold3betDelta: fold3betDelta,
      // New opportunity counters
      walksDelta: walksCountDelta,
      threeBetOpportunityDelta: threeBetOpportunityDelta,
      facing3BetDelta: facing3BetCountDelta,
      cbetOpportunityDelta: cbetOpportunityDelta,
      stealDelta: stealCountDelta,
      stealOpportunityDelta: stealOpportunityDelta,
      checkRaiseFlopDelta: checkRaiseFlopCountDelta,
      checkRaiseFlopOpportunityDelta: checkRaiseFlopOpportunityDelta,
    );

    // Save updated stats
    await saveOpponentStats(updatedStats);
  }

  /// Update stats using Firebase atomic operations (prevents race conditions)
  static Future<void> updateStatsAtomic({
    required String opponentId,
    int handsDelta = 0,
    int sessionsDelta = 0,
    int vpipDelta = 0,
    int pfrDelta = 0,
    int aggressionDelta = 0,
    int passiveDelta = 0,
    int foldDelta = 0,
    int checkDelta = 0,
    int callDelta = 0,
    int betDelta = 0,
    int raiseDelta = 0,
    int threeBetDelta = 0,
    int cbetDelta = 0,
    int fold3betDelta = 0,
    // New opportunity counters
    int walksCountDelta = 0,
    int threeBetOpportunityDelta = 0,
    int facing3BetCountDelta = 0,
    int cbetOpportunityDelta = 0,
    int stealCountDelta = 0,
    int stealOpportunityDelta = 0,
    int checkRaiseFlopCountDelta = 0,
    int checkRaiseFlopOpportunityDelta = 0,
  }) async {
    try {
      final docRef = _statsCollection.doc(opponentId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);

        if (snapshot.exists) {
          // Update existing stats
          transaction.update(docRef, {
            'handsPlayed': FieldValue.increment(handsDelta),
            'sessionsPlayed': FieldValue.increment(sessionsDelta),
            'vpipCount': FieldValue.increment(vpipDelta),
            'pfrCount': FieldValue.increment(pfrDelta),
            'aggressionActions': FieldValue.increment(aggressionDelta),
            'passiveActions': FieldValue.increment(passiveDelta),
            'foldCount': FieldValue.increment(foldDelta),
            'checkCount': FieldValue.increment(checkDelta),
            'callCount': FieldValue.increment(callDelta),
            'betCount': FieldValue.increment(betDelta),
            'raiseCount': FieldValue.increment(raiseDelta),
            'threeBetCount': FieldValue.increment(threeBetDelta),
            'cbetCount': FieldValue.increment(cbetDelta),
            'fold3betCount': FieldValue.increment(fold3betDelta),
            // New opportunity counters
            'walksCount': FieldValue.increment(walksCountDelta),
            'threeBetOpportunity': FieldValue.increment(threeBetOpportunityDelta),
            'facing3BetCount': FieldValue.increment(facing3BetCountDelta),
            'cbetOpportunity': FieldValue.increment(cbetOpportunityDelta),
            'stealCount': FieldValue.increment(stealCountDelta),
            'stealOpportunity': FieldValue.increment(stealOpportunityDelta),
            'checkRaiseFlopCount': FieldValue.increment(checkRaiseFlopCountDelta),
            'checkRaiseFlopOpportunity': FieldValue.increment(checkRaiseFlopOpportunityDelta),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          // Create new stats document
          final newStats = OpponentStats(
            opponentId: opponentId,
            handsPlayed: handsDelta,
            sessionsPlayed: sessionsDelta,
            vpipCount: vpipDelta,
            pfrCount: pfrDelta,
            aggressionActions: aggressionDelta,
            passiveActions: passiveDelta,
            foldCount: foldDelta,
            checkCount: checkDelta,
            callCount: callDelta,
            betCount: betDelta,
            raiseCount: raiseDelta,
            threeBetCount: threeBetDelta,
            cbetCount: cbetDelta,
            fold3betCount: fold3betDelta,
            // New opportunity counters
            walksCount: walksCountDelta,
            threeBetOpportunity: threeBetOpportunityDelta,
            facing3BetCount: facing3BetCountDelta,
            cbetOpportunity: cbetOpportunityDelta,
            stealCount: stealCountDelta,
            stealOpportunity: stealOpportunityDelta,
            checkRaiseFlopCount: checkRaiseFlopCountDelta,
            checkRaiseFlopOpportunity: checkRaiseFlopOpportunityDelta,
          );
          transaction.set(docRef, newStats.toFirestore());
        }
      });

      AppDataCache.markOpponentsDirty();
      AppDataCache.markOpponentHandsDirty();
      print('✅ Stats updated atomically for opponent: $opponentId');
    } catch (e) {
      print('⚠️ Atomic update failed, falling back to regular update: $e');
      await updateStatsIncremental(
        opponentId: opponentId,
        handsDelta: handsDelta,
        sessionsDelta: sessionsDelta,
        vpipDelta: vpipDelta,
        pfrDelta: pfrDelta,
        aggressionDelta: aggressionDelta,
        passiveDelta: passiveDelta,
        foldDelta: foldDelta,
        checkDelta: checkDelta,
        callDelta: callDelta,
        betDelta: betDelta,
        raiseDelta: raiseDelta,
        threeBetDelta: threeBetDelta,
        cbetDelta: cbetDelta,
        fold3betDelta: fold3betDelta,
        // New opportunity counters
        walksCountDelta: walksCountDelta,
        threeBetOpportunityDelta: threeBetOpportunityDelta,
        facing3BetCountDelta: facing3BetCountDelta,
        cbetOpportunityDelta: cbetOpportunityDelta,
        stealCountDelta: stealCountDelta,
        stealOpportunityDelta: stealOpportunityDelta,
        checkRaiseFlopCountDelta: checkRaiseFlopCountDelta,
        checkRaiseFlopOpportunityDelta: checkRaiseFlopOpportunityDelta,
      );
    }
  }

  /// Rebuild stats from scratch (for data integrity - run occasionally)
  /// This should be done in background using Isolate to avoid blocking UI
  static Future<void> rebuildStatsFromHands(String opponentId) async {
    try {
      // Use the migration service to rebuild stats
      await StatsMigrationService.rebuildOpponentStats(opponentId);
    } catch (e) {
      print('❌ Failed to rebuild stats for opponent $opponentId: $e');
    }
  }

  /// Get all opponent stats (for batch operations)
  static Future<List<OpponentStats>> getAllOpponentStats() async {
    try {
      // Try Firebase first
      final firebaseStats = await _getAllStatsFromFirebase();
      // Return Firebase result (even if empty - means no stats exist)
      return firebaseStats;
    } catch (e) {
      print('⚠️ Firebase bulk load failed, using local storage: $e');
      // Only fallback to local storage on actual errors
      return await _getAllStatsFromLocal();
    }
  }

  /// Process hand data and return appropriate deltas for stats update
  /// This analyzes a single hand and returns what counters should be incremented
  static Map<String, int> calculateStatsDeltas({
    required String opponentAction,
    required bool voluntarilyPutMoneyInPot,
    required bool wasPreFlopRaise,
    required bool wasFold,
    required bool wasCheck,
    required bool wasCall,
    required bool wasBet,
    required bool wasRaise,
    required bool was3Bet,
    required bool wasCBet,
    required bool foldedTo3Bet,
  }) {
    return {
      'handsDelta': 1,
      'vpipDelta': voluntarilyPutMoneyInPot ? 1 : 0,
      'pfrDelta': wasPreFlopRaise ? 1 : 0,
      'aggressionDelta': (wasBet || wasRaise) ? 1 : 0,
      'passiveDelta': wasCall ? 1 : 0,
      'foldDelta': wasFold ? 1 : 0,
      'checkDelta': wasCheck ? 1 : 0,
      'callDelta': wasCall ? 1 : 0,
      'betDelta': wasBet ? 1 : 0,
      'raiseDelta': wasRaise ? 1 : 0,
      'threeBetDelta': was3Bet ? 1 : 0,
      'cbetDelta': wasCBet ? 1 : 0,
      'fold3betDelta': foldedTo3Bet ? 1 : 0,
    };
  }

  // Private helper methods

  static Future<OpponentStats?> _getStatsFromFirebase(String opponentId) async {
    if (_userId == null) return null;

    final doc = await _statsCollection.doc(opponentId).get();
    if (doc.exists) {
      return OpponentStats.fromFirestore(doc);
    }
    return null;
  }

  static Future<void> _saveStatsToFirebase(OpponentStats stats) async {
    if (_userId == null) return;

    await _statsCollection.doc(stats.opponentId).set(stats.toFirestore());
  }

  static Future<List<OpponentStats>> _getAllStatsFromFirebase() async {
    if (_userId == null) return [];

    final snapshot = await _statsCollection.get();
    return snapshot.docs
        .map((doc) => OpponentStats.fromFirestore(doc))
        .toList();
  }

  static Future<OpponentStats?> _getStatsFromLocal(String opponentId) async {
    final prefs = await SharedPreferences.getInstance();
    final statsJson = prefs.getString('${_localStatsKey}_$opponentId');

    if (statsJson != null) {
      final statsMap = jsonDecode(statsJson) as Map<String, dynamic>;
      return OpponentStats.fromMap(statsMap);
    }
    return null;
  }

  static Future<void> _saveStatsToLocal(OpponentStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    final statsJson = jsonEncode(stats.toMap());
    await prefs.setString('${_localStatsKey}_${stats.opponentId}', statsJson);
  }

  static Future<List<OpponentStats>> _getAllStatsFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_localStatsKey));

    final List<OpponentStats> stats = [];
    for (final key in keys) {
      final statsJson = prefs.getString(key);
      if (statsJson != null) {
        final statsMap = jsonDecode(statsJson) as Map<String, dynamic>;
        stats.add(OpponentStats.fromMap(statsMap));
      }
    }

    return stats;
  }


  /// Delete opponent stats
  static Future<void> deleteOpponentStats(String opponentId) async {
    try {
      // Delete from Firebase
      await _statsCollection.doc(opponentId).delete();
      print('✅ Stats deleted from Firebase: $opponentId');
    } catch (e) {
      print('⚠️ Firebase deletion failed: $e');
    }

    // Delete from local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_localStatsKey}_$opponentId');
    print('✅ Stats deleted locally: $opponentId');
  }

  /// Clear all stats (for testing/reset purposes)
  static Future<void> clearAllStats() async {
    try {
      // Clear Firebase collection
      final batch = _firestore.batch();
      final snapshot = await _statsCollection.get();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print('✅ All stats cleared from Firebase');
    } catch (e) {
      print('⚠️ Firebase clear failed: $e');
    }

    // Clear local storage
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_localStatsKey));
    for (final key in keys) {
      await prefs.remove(key);
    }
    print('✅ All stats cleared from local storage');
  }

  /// Initialize stats optimization system
  /// Should be called on app startup to check for migration needs
  static Future<void> initializeStatsOptimization() async {
    try {
      // Check if migration is needed
      final migrationNeeded = await StatsMigrationService.isMigrationNeeded();

      if (migrationNeeded) {
        print('🚀 Stats optimization migration needed, starting background process...');

        // Run migration in background without blocking app startup
        _runMigrationInBackground();
      } else {
        print('✅ Stats optimization already active');
      }

    } catch (e) {
      print('⚠️ Error initializing stats optimization: $e');
      // Don't rethrow - app should continue working even if optimization fails
    }
  }

  /// Run migration in background
  static void _runMigrationInBackground() {
    // Use a microtask to run in background without blocking
    Future.microtask(() async {
      try {
        await StatsMigrationService.migrateInBackground();
        print('🎉 Background migration completed successfully');
      } catch (e) {
        print('❌ Background migration failed: $e');
      }
    });
  }

  /// Get system performance stats
  static Future<Map<String, dynamic>> getPerformanceStats() async {
    try {
      final migrationProgress = await StatsMigrationService.getMigrationProgress();

      final allStats = await getAllOpponentStats();
      final totalOptimizedHands = allStats.fold(0, (sum, stats) => sum + stats.handsPlayed);

      return {
        ...migrationProgress,
        'totalOptimizedHands': totalOptimizedHands,
        'totalOptimizedOpponents': allStats.length,
        'avgHandsPerOpponent': allStats.isNotEmpty ? (totalOptimizedHands / allStats.length).round() : 0,
        'optimizationActive': allStats.isNotEmpty,
      };

    } catch (e) {
      print('❌ Error getting performance stats: $e');
      return {
        'error': e.toString(),
        'optimizationActive': false,
      };
    }
  }

  /// Manual trigger for stats rebuild (admin function)
  static Future<void> rebuildAllStats() async {
    try {
      print('🔄 Starting manual stats rebuild...');
      await StatsMigrationService.migrateAllOpponentsToOptimizedStats();
      print('✅ Manual stats rebuild completed');
    } catch (e) {
      print('❌ Manual stats rebuild failed: $e');
      rethrow;
    }
  }
}