import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/opponent.dart';
import '../models/opponent_stats.dart';
import 'local_storage_service.dart';
import 'opponent_service.dart';
import 'opponent_stats_service.dart';

/// Service to seed test data for development and testing
/// Creates opponents with different play styles and a comprehensive session with 50 hands
class TestDataSeedService {
  static const _uuid = Uuid();
  static const _seedCompletedKey = 'test_data_seed_completed_v2';

  /// Check if test data has already been seeded
  static Future<bool> isSeeded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seedCompletedKey) ?? false;
  }

  /// Clean up test data from Firebase AND local SQLite
  static Future<void> cleanupTestData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user logged in, cannot cleanup test data');
      return;
    }

    final firestore = FirebaseFirestore.instance;
    final db = await LocalStorageService.database;
    print('Starting test data cleanup...');

    // Test opponent names to delete
    const testOpponentNames = ['FISH Mike', 'TAG Sarah', 'NIT Helen', 'LAG Carlos', 'MANIAC Jake'];

    // Delete test opponents and their stats from Firebase
    final opponents = await firestore
        .collection('opponents')
        .where('userId', isEqualTo: user.uid)
        .get();

    int deletedOpponents = 0;
    for (final doc in opponents.docs) {
      final name = doc.data()['name'] as String?;
      if (name != null && testOpponentNames.contains(name)) {
        // Delete opponent stats first
        try {
          await firestore.collection('opponent_stats').doc(doc.id).delete();
        } catch (e) {
          print('Could not delete stats for ${doc.id}: $e');
        }
        // Delete opponent
        await doc.reference.delete();
        deletedOpponents++;
        print('Deleted opponent: $name');
      }
    }

    // Delete test sessions from Firebase
    final sessions = await firestore
        .collection('poker_sessions')
        .where('userId', isEqualTo: user.uid)
        .get();

    int deletedSessions = 0;
    List<String> deletedSessionIds = [];
    for (final session in sessions.docs) {
      final sessionName = session.data()['sessionName'] as String?;
      if (sessionName == '50-Hand Test Session (All Scenarios)') {
        // Delete all hands in the session
        final hands = await session.reference.collection('poker_hands').get();
        for (final hand in hands.docs) {
          await hand.reference.delete();
        }
        print('Deleted ${hands.docs.length} hands from Firebase session');
        // Delete session
        await session.reference.delete();
        deletedSessionIds.add(session.id);
        deletedSessions++;
        print('Deleted Firebase session: $sessionName');
      }
    }

    // Delete from local SQLite as well
    try {
      // Delete hands from SQLite for all deleted sessions
      for (final sessionId in deletedSessionIds) {
        final deletedHands = await db.delete(
          'hands',
          where: 'sessionId = ?',
          whereArgs: [sessionId],
        );
        print('Deleted $deletedHands hands from SQLite for session $sessionId');
      }

      // Delete sessions from SQLite
      final deletedLocalSessions = await db.delete(
        'sessions',
        where: 'sessionName = ?',
        whereArgs: ['50-Hand Test Session (All Scenarios)'],
      );
      print('Deleted $deletedLocalSessions sessions from SQLite');

      // Delete opponents from SQLite
      for (final name in testOpponentNames) {
        await db.delete(
          'opponents',
          where: 'name = ?',
          whereArgs: [name],
        );
      }
      print('Deleted test opponents from SQLite');
    } catch (e) {
      print('Error cleaning up SQLite: $e');
    }

    // Reset seed flag
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seedCompletedKey, false);

    print('Cleanup complete: $deletedOpponents opponents, $deletedSessions sessions');
  }

  /// Seed all test data (opponents + session with 50 hands)
  static Future<void> seedTestData({bool force = false}) async {
    if (!force && await isSeeded()) {
      print('Test data already seeded. Use force=true to re-seed.');
      return;
    }

    print('Starting test data seed...');

    // Create opponents
    await _createTestOpponents();

    // Create session with 50 hands
    await _createTestSession();

    // Mark as seeded
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seedCompletedKey, true);

    print('Test data seed completed!');
  }

  /// Clear test data and reset seed flag
  static Future<void> clearTestData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_seedCompletedKey);
    print('Test data seed flag cleared.');
  }

  /// Create 5 opponents with different play styles
  static Future<Map<String, String>> _createTestOpponents() async {
    final opponents = <String, Map<String, dynamic>>{
      'FISH_Mike': {
        'name': 'FISH Mike',
        'notes': 'Loose-passive recreational player. Calls too much, rarely raises. Target for value betting.',
        'color': OpponentColor.green,
        'stats': OpponentStats(
          opponentId: '',
          handsPlayed: 150,
          sessionsPlayed: 5,
          vpipCount: 78, // 52% VPIP
          pfrCount: 12, // 8% PFR
          aggressionActions: 15,
          passiveActions: 85,
          foldCount: 60,
          checkCount: 40,
          callCount: 85,
          betCount: 8,
          raiseCount: 7,
          threeBetCount: 3, // 2% 3bet
          cbetCount: 5,
          fold3betCount: 12,
        ),
      },
      'TAG_Sarah': {
        'name': 'TAG Sarah',
        'notes': 'Solid tight-aggressive regular. Plays straightforward, respect her raises.',
        'color': OpponentColor.blue,
        'stats': OpponentStats(
          opponentId: '',
          handsPlayed: 200,
          sessionsPlayed: 8,
          vpipCount: 44, // 22% VPIP
          pfrCount: 36, // 18% PFR
          aggressionActions: 70,
          passiveActions: 30,
          foldCount: 140,
          checkCount: 20,
          callCount: 30,
          betCount: 35,
          raiseCount: 35,
          threeBetCount: 14, // 7% 3bet
          cbetCount: 30,
          fold3betCount: 8,
        ),
      },
      'LAG_Carlos': {
        'name': 'LAG Carlos',
        'notes': 'Loose-aggressive. Puts pressure with wide range. Be prepared to call down lighter.',
        'color': OpponentColor.orange,
        'stats': OpponentStats(
          opponentId: '',
          handsPlayed: 180,
          sessionsPlayed: 6,
          vpipCount: 63, // 35% VPIP
          pfrCount: 50, // 28% PFR
          aggressionActions: 90,
          passiveActions: 35,
          foldCount: 80,
          checkCount: 15,
          callCount: 35,
          betCount: 45,
          raiseCount: 45,
          threeBetCount: 22, // 12% 3bet
          cbetCount: 40,
          fold3betCount: 5,
        ),
      },
      'NIT_Helen': {
        'name': 'NIT Helen',
        'notes': 'Extremely tight. Only plays premium hands. Fold to her raises unless you have the nuts.',
        'color': OpponentColor.purple,
        'stats': OpponentStats(
          opponentId: '',
          handsPlayed: 120,
          sessionsPlayed: 4,
          vpipCount: 14, // 12% VPIP
          pfrCount: 12, // 10% PFR
          aggressionActions: 25,
          passiveActions: 10,
          foldCount: 100,
          checkCount: 8,
          callCount: 10,
          betCount: 12,
          raiseCount: 13,
          threeBetCount: 4, // 3% 3bet
          cbetCount: 10,
          fold3betCount: 2,
        ),
      },
      'MANIAC_Jake': {
        'name': 'MANIAC Jake',
        'notes': 'Hyper-aggressive maniac. Raises everything, bluffs constantly. Trap and let him hang himself.',
        'color': OpponentColor.red,
        'stats': OpponentStats(
          opponentId: '',
          handsPlayed: 100,
          sessionsPlayed: 3,
          vpipCount: 48, // 48% VPIP
          pfrCount: 42, // 42% PFR
          aggressionActions: 80,
          passiveActions: 15,
          foldCount: 40,
          checkCount: 5,
          callCount: 15,
          betCount: 38,
          raiseCount: 42,
          threeBetCount: 18, // 18% 3bet
          cbetCount: 35,
          fold3betCount: 2,
        ),
      },
    };

    final opponentIds = <String, String>{};

    for (final entry in opponents.entries) {
      final id = _uuid.v4();
      opponentIds[entry.key] = id;

      final opponent = Opponent(
        id: id,
        name: entry.value['name'] as String,
        notes: entry.value['notes'] as String,
        createdAt: DateTime.now().subtract(Duration(days: Random().nextInt(30) + 1)),
        lastSeenAt: DateTime.now().subtract(Duration(hours: Random().nextInt(48))),
        color: entry.value['color'] as OpponentColor,
      );

      await OpponentService.saveOpponent(opponent);
      print('Created opponent: ${opponent.name} (${id.substring(0, 8)})');

      // Save opponent stats
      final baseStats = entry.value['stats'] as OpponentStats;
      final stats = OpponentStats(
        opponentId: id,
        handsPlayed: baseStats.handsPlayed,
        sessionsPlayed: baseStats.sessionsPlayed,
        vpipCount: baseStats.vpipCount,
        pfrCount: baseStats.pfrCount,
        aggressionActions: baseStats.aggressionActions,
        passiveActions: baseStats.passiveActions,
        foldCount: baseStats.foldCount,
        checkCount: baseStats.checkCount,
        callCount: baseStats.callCount,
        betCount: baseStats.betCount,
        raiseCount: baseStats.raiseCount,
        threeBetCount: baseStats.threeBetCount,
        cbetCount: baseStats.cbetCount,
        fold3betCount: baseStats.fold3betCount,
      );

      await OpponentStatsService.saveOpponentStats(stats);
      print('  Stats: VPIP=${stats.vpipPercentage.toStringAsFixed(1)}%, PFR=${stats.pfrPercentage.toStringAsFixed(1)}%, Style=${stats.playingStyle}');
    }

    return opponentIds;
  }

  /// Create a session with 50 comprehensive hands
  static Future<void> _createTestSession() async {
    try {
      final db = await LocalStorageService.database;
      final firestore = FirebaseFirestore.instance;
      final now = DateTime.now();

      // Get current user info
      final currentUser = FirebaseAuth.instance.currentUser;
      final userId = currentUser?.uid ?? 'test_user_123';
      final userEmail = currentUser?.email ?? 'test@example.com';
      final userName = currentUser?.displayName ?? 'TestHero';

      print('Creating session for user: $userId ($userEmail)');

      // Get opponent IDs
      final opponents = await OpponentService.getAllOpponents();
      final opponentMap = {for (var o in opponents) o.name: o.id};
      print('Found ${opponents.length} opponents: ${opponentMap.keys.toList()}');

      // Create session in Firebase first
      final sessionRef = await firestore.collection('poker_sessions').add({
        'userId': userId,
        'userEmail': userEmail,
        'userName': userName,
        'smallBlind': 100,
        'bigBlind': 200,
        'playerCount': 9,
        'ourSeatNumber': 5,
        'totalHands': 50,
        'startTime': Timestamp.fromDate(now.subtract(const Duration(hours: 3))),
        'endTime': Timestamp.fromDate(now),
        'sessionName': '50-Hand Test Session (All Scenarios)',
        'gameType': 'tournament',
        'buyInAmount': 10000.0,
        'totalBuyIn': 10000.0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final sessionId = sessionRef.id;
      print('Created Firebase session: $sessionId');

      // Also save to local SQLite for offline access
      await db.insert('sessions', {
        'id': sessionId,
        'userId': userId,
        'smallBlind': 100,
        'bigBlind': 200,
        'playerCount': 9,
        'ourSeatNumber': 5,
        'totalHands': 50,
        'startTime': now.subtract(const Duration(hours: 3)).toIso8601String(),
        'endTime': now.toIso8601String(),
        'userEmail': userEmail,
        'userName': userName,
        'sessionName': '50-Hand Test Session (All Scenarios)',
        'updatedAt': now.toIso8601String(),
        'gameType': 'tournament',
        'stackHistory': jsonEncode([]),
        'buyInAmount': 10000.0,
        'totalBuyIn': 10000.0,
      });
      print('Created local SQLite session: $sessionId');

      // Generate 50 hands
      print('Generating test hands...');
      List<Map<String, dynamic>> hands;
      try {
        hands = _generateTestHands(sessionId, opponentMap);
        print('Generated ${hands.length} hands, now inserting into database...');
      } catch (e, stackTrace) {
        print('ERROR generating hands: $e');
        print('Stack trace: $stackTrace');
        rethrow;
      }

      int insertedCount = 0;
      final batch = firestore.batch();

      // Track opponent stats from hands
      final opponentStatsDeltas = <String, Map<String, int>>{};

      for (final hand in hands) {
        try {
          // Save to local SQLite
          await db.insert('hands', hand);

          // Prepare Firebase data (without JSON encoding, Firebase handles objects natively)
          final firebaseHand = _convertHandForFirebase(hand, now);

          // Save as subcollection under session (this is the correct structure!)
          final handId = '${sessionId}_hand_${hand['handNumber']}';
          final handRef = firestore
              .collection('poker_sessions')
              .doc(sessionId)
              .collection('poker_hands')
              .doc(handId);
          batch.set(handRef, firebaseHand);

          // Collect opponent stats from this hand
          _collectOpponentStatsFromHand(hand, opponentMap, opponentStatsDeltas);

          insertedCount++;
        } catch (e) {
          print('Error inserting hand ${hand['handNumber']}: $e');
        }
      }

      // Commit Firebase batch
      await batch.commit();
      print('Successfully inserted $insertedCount hands into both Firebase and SQLite');

      // Update opponent stats
      print('Updating opponent stats for ${opponentStatsDeltas.length} opponents...');
      for (final entry in opponentStatsDeltas.entries) {
        print('  Opponent ${entry.key}: ${entry.value}');
      }
      await _updateOpponentStatsFromDeltas(opponentStatsDeltas);
      print('Opponent stats updated!');
    } catch (e, stackTrace) {
      print('ERROR in _createTestSession: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Collect opponent stats deltas from a hand
  static void _collectOpponentStatsFromHand(
    Map<String, dynamic> hand,
    Map<String, String> opponentMap,
    Map<String, Map<String, int>> deltas,
  ) {
    final actionsJson = hand['actions'];
    if (actionsJson == null) return;

    final actions = jsonDecode(actionsJson) as List;

    // Track which opponents participated in this hand
    final opponentsInHand = <String>{};
    final opponentPreflopActions = <String, List<String>>{};

    for (final action in actions) {
      final playerName = action['playerName'] as String?;
      if (playerName == null || playerName == 'Hero') continue;

      // Check if this player name matches a saved opponent
      final opponentId = opponentMap[playerName];
      if (opponentId == null) {
        // Try to find by partial match (case-insensitive)
        final matchingName = opponentMap.keys.firstWhere(
          (name) => name.toLowerCase() == playerName.toLowerCase(),
          orElse: () => '',
        );
        if (matchingName.isEmpty) continue;
        // Use the matched opponent
        final matchedId = opponentMap[matchingName];
        if (matchedId == null) continue;
        opponentsInHand.add(matchedId);

        // Initialize deltas for this opponent if needed (sessions = 1 only once per opponent)
        deltas.putIfAbsent(matchedId, () => {
          'hands': 0,
          'vpip': 0,
          'pfr': 0,
          'aggression': 0,
          'passive': 0,
          'folds': 0,
          'checks': 0,
          'calls': 0,
          'bets': 0,
          'raises': 0,
          'threeBets': 0,
        });

        // Track preflop actions
        final actionType = action['action'] as String?;
        final street = action['street'] as String?;
        if (actionType != null && street == 'preflop') {
          opponentPreflopActions.putIfAbsent(matchedId, () => []);
          opponentPreflopActions[matchedId]!.add(actionType);
        }

        _countAction(deltas[matchedId]!, actionType);
        continue;
      }

      opponentsInHand.add(opponentId);

      // Initialize deltas for this opponent if needed (sessions = 1 only once per opponent)
      deltas.putIfAbsent(opponentId, () => {
        'hands': 0,
        'vpip': 0,
        'pfr': 0,
        'aggression': 0,
        'passive': 0,
        'folds': 0,
        'checks': 0,
        'calls': 0,
        'bets': 0,
        'raises': 0,
        'threeBets': 0,
      });

      final actionType = action['action'] as String?;
      final street = action['street'] as String?;

      if (actionType == null) continue;

      // Track preflop actions for VPIP/PFR calculation
      if (street == 'preflop') {
        opponentPreflopActions.putIfAbsent(opponentId, () => []);
        opponentPreflopActions[opponentId]!.add(actionType);
      }

      // Count action types
      switch (actionType.toLowerCase()) {
        case 'fold':
          deltas[opponentId]!['folds'] = (deltas[opponentId]!['folds'] ?? 0) + 1;
          break;
        case 'check':
          deltas[opponentId]!['checks'] = (deltas[opponentId]!['checks'] ?? 0) + 1;
          break;
        case 'call':
          deltas[opponentId]!['calls'] = (deltas[opponentId]!['calls'] ?? 0) + 1;
          deltas[opponentId]!['passive'] = (deltas[opponentId]!['passive'] ?? 0) + 1;
          break;
        case 'bet':
          deltas[opponentId]!['bets'] = (deltas[opponentId]!['bets'] ?? 0) + 1;
          deltas[opponentId]!['aggression'] = (deltas[opponentId]!['aggression'] ?? 0) + 1;
          break;
        case 'raise':
        case 'all_in':
          deltas[opponentId]!['raises'] = (deltas[opponentId]!['raises'] ?? 0) + 1;
          deltas[opponentId]!['aggression'] = (deltas[opponentId]!['aggression'] ?? 0) + 1;
          break;
      }
    }

    // Calculate VPIP and PFR for each opponent in this hand
    for (final opponentId in opponentsInHand) {
      deltas[opponentId]!['hands'] = (deltas[opponentId]!['hands'] ?? 0) + 1;

      final preflopActions = opponentPreflopActions[opponentId] ?? [];

      // VPIP: Voluntarily put money in pot (call or raise, not just posting blinds)
      final vpipActions = ['call', 'raise', 'all_in', 'bet'];
      if (preflopActions.any((a) => vpipActions.contains(a.toLowerCase()))) {
        deltas[opponentId]!['vpip'] = (deltas[opponentId]!['vpip'] ?? 0) + 1;
      }

      // PFR: Preflop raise
      final pfrActions = ['raise', 'all_in'];
      if (preflopActions.any((a) => pfrActions.contains(a.toLowerCase()))) {
        deltas[opponentId]!['pfr'] = (deltas[opponentId]!['pfr'] ?? 0) + 1;
      }
    }
  }

  /// Helper to count an action type
  static void _countAction(Map<String, int> stats, String? actionType) {
    if (actionType == null) return;

    switch (actionType.toLowerCase()) {
      case 'fold':
        stats['folds'] = (stats['folds'] ?? 0) + 1;
        break;
      case 'check':
        stats['checks'] = (stats['checks'] ?? 0) + 1;
        break;
      case 'call':
        stats['calls'] = (stats['calls'] ?? 0) + 1;
        stats['passive'] = (stats['passive'] ?? 0) + 1;
        break;
      case 'bet':
        stats['bets'] = (stats['bets'] ?? 0) + 1;
        stats['aggression'] = (stats['aggression'] ?? 0) + 1;
        break;
      case 'raise':
      case 'all_in':
        stats['raises'] = (stats['raises'] ?? 0) + 1;
        stats['aggression'] = (stats['aggression'] ?? 0) + 1;
        break;
    }
  }

  /// Update opponent stats from collected deltas
  static Future<void> _updateOpponentStatsFromDeltas(
    Map<String, Map<String, int>> deltas,
  ) async {
    for (final entry in deltas.entries) {
      final opponentId = entry.key;
      final stats = entry.value;

      try {
        await OpponentStatsService.updateStatsIncremental(
          opponentId: opponentId,
          handsDelta: stats['hands'] ?? 0,
          sessionsDelta: 1, // One session per opponent
          vpipDelta: stats['vpip'] ?? 0,
          pfrDelta: stats['pfr'] ?? 0,
          aggressionDelta: stats['aggression'] ?? 0,
          passiveDelta: stats['passive'] ?? 0,
          foldDelta: stats['folds'] ?? 0,
          checkDelta: stats['checks'] ?? 0,
          callDelta: stats['calls'] ?? 0,
          betDelta: stats['bets'] ?? 0,
          raiseDelta: stats['raises'] ?? 0,
          threeBetDelta: stats['threeBets'] ?? 0,
        );
        print('  Updated stats for opponent $opponentId: ${stats['hands']} hands, vpip=${stats['vpip']}, pfr=${stats['pfr']}');
      } catch (e) {
        print('  Error updating stats for opponent $opponentId: $e');
      }
    }
  }

  /// Convert a hand from SQLite format to Firebase format
  static Map<String, dynamic> _convertHandForFirebase(Map<String, dynamic> hand, DateTime now) {
    // Parse JSON strings back to objects for Firebase
    final actions = hand['actions'] != null ? jsonDecode(hand['actions']) : [];
    final boardCards = hand['boardCards'] != null ? jsonDecode(hand['boardCards']) : null;
    final ourHoleCards = hand['ourHoleCards'] != null ? jsonDecode(hand['ourHoleCards']) : null;
    final showdownData = hand['showdownData'] != null ? jsonDecode(hand['showdownData']) : null;
    final playerNames = hand['playerNames'] != null ? jsonDecode(hand['playerNames']) : null;

    return {
      'sessionId': hand['sessionId'],
      'handNumber': hand['handNumber'],
      'buttonPosition': hand['buttonPosition'],
      'playerCount': hand['playerCount'],
      'startTime': Timestamp.fromDate(now.subtract(Duration(minutes: 180 - (hand['handNumber'] as int) * 3))),
      'endTime': Timestamp.fromDate(now.subtract(Duration(minutes: 177 - (hand['handNumber'] as int) * 3))),
      'actions': actions,
      'boardCards': boardCards,
      'ourHoleCards': ourHoleCards,
      'showdownData': showdownData,
      'reachedShowdown': hand['reachedShowdown'] == 1,
      'potAmount': hand['potAmount'],
      'preflopPot': hand['preflopPot'],
      'flopPot': hand['flopPot'],
      'turnPot': hand['turnPot'],
      'riverPot': hand['riverPot'],
      'winnerId': hand['winnerId'],
      'heroPosition': hand['heroPosition'],
      'playerNames': playerNames,
      'handSmallBlind': hand['handSmallBlind'],
      'handBigBlind': hand['handBigBlind'],
      'handGameType': hand['handGameType'],
      'isChoppedPot': hand['isChoppedPot'] == 1,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Generate 50 test hands with various scenarios
  static List<Map<String, dynamic>> _generateTestHands(
    String sessionId,
    Map<String, String> opponentMap,
  ) {
    final hands = <Map<String, dynamic>>[];
    final random = Random(42); // Fixed seed for reproducibility
    var handNumber = 1;

    // Helper to get opponent ID
    String? getOpponentId(String? name) {
      if (name == null) return null;
      return opponentMap[name];
    }

    // Helper to create player names map - includes all 9 players
    Map<int, String> createPlayerNames(List<String?> names) {
      final map = <int, String>{};
      // Default player names for all 9 seats
      final defaultNames = [
        'Player 1', 'Player 2', 'Player 3', 'Player 4',
        'Hero', 'Player 6', 'Player 7', 'Player 8', 'Player 9'
      ];
      for (var i = 0; i < 9; i++) {
        // Use provided name if available, otherwise use default
        if (i < names.length && names[i] != null) {
          map[i + 1] = names[i]!;
        } else if (i == 4) {
          map[5] = 'Hero'; // Hero is always seat 5
        } else {
          map[i + 1] = defaultNames[i];
        }
      }
      return map;
    }

    // Standard full table player names for hands that need complete names
    final fullTableNames = <int, String>{
      1: 'Player 1',
      2: 'Player 2',
      3: 'FISH Mike',
      4: 'TAG Sarah',
      5: 'Hero',
      6: 'LAG Carlos',
      7: 'NIT Helen',
      8: 'MANIAC Jake',
      9: 'Player 9',
    };

    // ===== OPEN RAISING SCENARIOS (15 hands) =====

    // Hand 1: BTN open with AKo - everyone folds (correct play)
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 5, // Hero is BTN
      heroPosition: 5,
      heroCards: {'card1': 'A♠', 'card2': 'K♥'},
      playerNames: createPlayerNames(['FISH Mike', null, 'TAG Sarah', 'LAG Carlos', null, 'NIT Helen', null, null, null]),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'CO'),
        _action(5, 'raise', 'preflop', 'BTN', amount: 500, isHero: true),
        _action(6, 'fold', 'preflop', 'SB'),
        _action(7, 'fold', 'preflop', 'BB'),
      ],
      potAmount: 800,
      winnerId: 5,
    ));

    // Hand 2: CO open with QQ - 3bet by BB (TAG Sarah)
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 6,
      heroPosition: 5, // CO
      heroCards: {'card1': 'Q♠', 'card2': 'Q♣'},
      playerNames: createPlayerNames(['FISH Mike', null, 'TAG Sarah', 'LAG Carlos', null, 'NIT Helen', null, null, null]),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'HJ'),
        _action(5, 'raise', 'preflop', 'CO', amount: 500, isHero: true),
        _action(6, 'fold', 'preflop', 'BTN'),
        _action(7, 'fold', 'preflop', 'SB'),
        _action(8, 'raise', 'preflop', 'BB', amount: 1600, playerName: 'TAG Sarah'),
        _action(5, 'call', 'preflop', 'CO', amount: 1100, isHero: true),
      ],
      boardCards: {'flop': ['7♦', '4♣', '2♠'], 'turn': 'K♥', 'river': '9♦'},
      potAmount: 3500,
      preflopPot: 3500,
      flopPot: 3500,
      turnPot: 3500,
      riverPot: 3500,
      reachedShowdown: true,
      showdownData: {
        'playerCards': {
          5: {'card1': 'Q♠', 'card2': 'Q♣'},
          8: {'card1': 'A♥', 'card2': 'K♦'},
        },
        'winner': 8,
        'handDescription': 'Pair of Kings',
      },
      winnerId: 8,
    ));

    // Hand 3: BTN open with JTs suited - called by BB (FISH Mike)
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 5,
      heroPosition: 5,
      heroCards: {'card1': 'J♠', 'card2': 'T♠'},
      playerNames: createPlayerNames(['FISH Mike', null, 'TAG Sarah', 'LAG Carlos', null, null, null, null, null]),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'CO'),
        _action(5, 'raise', 'preflop', 'BTN', amount: 500, isHero: true),
        _action(6, 'fold', 'preflop', 'SB'),
        _action(7, 'call', 'preflop', 'BB', amount: 300, playerName: 'FISH Mike'),
        // Flop: Hero c-bets, FISH calls
        _action(7, 'check', 'flop', 'BB', playerName: 'FISH Mike'),
        _action(5, 'bet', 'flop', 'BTN', amount: 600, isHero: true),
        _action(7, 'call', 'flop', 'BB', amount: 600, playerName: 'FISH Mike'),
        // Turn: check-check
        _action(7, 'check', 'turn', 'BB', playerName: 'FISH Mike'),
        _action(5, 'check', 'turn', 'BTN', isHero: true),
        // River: FISH bets, hero folds
        _action(7, 'bet', 'river', 'BB', amount: 800, playerName: 'FISH Mike'),
        _action(5, 'fold', 'river', 'BTN', isHero: true),
      ],
      boardCards: {'flop': ['K♥', '8♦', '3♣'], 'turn': '2♠', 'river': 'A♥'},
      potAmount: 2200,
      preflopPot: 1000,
      flopPot: 2200,
      turnPot: 2200,
      riverPot: 3000,
      winnerId: 7,
    ));

    // Hand 4: SB open with AJo - BB (LAG Carlos) defends
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 4,
      heroPosition: 5, // SB
      heroCards: {'card1': 'A♣', 'card2': 'J♦'},
      playerNames: createPlayerNames(['FISH Mike', null, 'TAG Sarah', 'LAG Carlos', null, null, null, null, null]),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'BTN'),
        _action(5, 'raise', 'preflop', 'SB', amount: 600, isHero: true),
        _action(6, 'call', 'preflop', 'BB', amount: 400, playerName: 'LAG Carlos'),
        // Flop: Hero c-bets and takes it
        _action(5, 'bet', 'flop', 'SB', amount: 700, isHero: true),
        _action(6, 'fold', 'flop', 'BB', playerName: 'LAG Carlos'),
      ],
      boardCards: {'flop': ['9♦', '5♣', '2♥']},
      potAmount: 1200,
      preflopPot: 1200,
      flopPot: 1900,
      winnerId: 5,
    ));

    // Hand 5: CO open with 99 - everyone folds
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 6,
      heroPosition: 5,
      heroCards: {'card1': '9♥', 'card2': '9♦'},
      playerNames: createPlayerNames([null, 'NIT Helen', null, null, null, 'MANIAC Jake', null, null, null]),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1', playerName: 'NIT Helen'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'HJ'),
        _action(5, 'raise', 'preflop', 'CO', amount: 500, isHero: true),
        _action(6, 'fold', 'preflop', 'BTN', playerName: 'MANIAC Jake'),
        _action(7, 'fold', 'preflop', 'SB'),
        _action(8, 'fold', 'preflop', 'BB'),
      ],
      potAmount: 800,
      winnerId: 5,
    ));

    // Hand 6: UTG fold with 72o (correct play)
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 4,
      heroPosition: 5, // UTG
      heroCards: {'card1': '7♥', 'card2': '2♣'},
      playerNames: createPlayerNames([null, null, 'TAG Sarah', null, null, null, null, null, null]),
      actions: [
        _action(5, 'fold', 'preflop', 'UTG', isHero: true),
        _action(6, 'fold', 'preflop', 'UTG+1'),
        _action(7, 'fold', 'preflop', 'MP'),
        _action(8, 'raise', 'preflop', 'CO', amount: 500, playerName: 'TAG Sarah'),
        _action(1, 'fold', 'preflop', 'BTN'),
        _action(2, 'fold', 'preflop', 'SB'),
        _action(3, 'fold', 'preflop', 'BB'),
      ],
      potAmount: 800,
      winnerId: 8,
    ));

    // Hand 7: UTG fold with J4o (correct play)
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 3,
      heroPosition: 5,
      heroCards: {'card1': 'J♥', 'card2': '4♠'},
      playerNames: createPlayerNames([null, null, null, null, null, null, null, null, null]),
      actions: [
        _action(4, 'fold', 'preflop', 'UTG'),
        _action(5, 'fold', 'preflop', 'UTG+1', isHero: true),
        _action(6, 'raise', 'preflop', 'MP', amount: 500),
        _action(7, 'fold', 'preflop', 'HJ'),
        _action(8, 'fold', 'preflop', 'CO'),
        _action(1, 'fold', 'preflop', 'BTN'),
        _action(2, 'fold', 'preflop', 'SB'),
        _action(3, 'fold', 'preflop', 'BB'),
      ],
      potAmount: 800,
      winnerId: 6,
    ));

    // Hand 8: UTG+1 fold with Q8o (correct play)
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 3,
      heroPosition: 5,
      heroCards: {'card1': 'Q♣', 'card2': '8♦'},
      playerNames: createPlayerNames([null, null, null, null, null, null, null, null, null]),
      actions: [
        _action(4, 'fold', 'preflop', 'UTG'),
        _action(5, 'fold', 'preflop', 'UTG+1', isHero: true),
        _action(6, 'fold', 'preflop', 'MP'),
        _action(7, 'fold', 'preflop', 'HJ'),
        _action(8, 'fold', 'preflop', 'CO'),
        _action(1, 'raise', 'preflop', 'BTN', amount: 500),
        _action(2, 'fold', 'preflop', 'SB'),
        _action(3, 'fold', 'preflop', 'BB'),
      ],
      potAmount: 800,
      winnerId: 1,
    ));

    // Hand 9: MISTAKE - UTG open with T6s (too loose)
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 4,
      heroPosition: 5,
      heroCards: {'card1': 'T♠', 'card2': '6♠'},
      playerNames: createPlayerNames([null, null, 'TAG Sarah', null, null, null, null, null, null]),
      actions: [
        _action(5, 'raise', 'preflop', 'UTG', amount: 500, isHero: true),
        _action(6, 'fold', 'preflop', 'UTG+1'),
        _action(7, 'fold', 'preflop', 'MP'),
        _action(8, 'raise', 'preflop', 'CO', amount: 1600, playerName: 'TAG Sarah'),
        _action(1, 'fold', 'preflop', 'BTN'),
        _action(2, 'fold', 'preflop', 'SB'),
        _action(3, 'fold', 'preflop', 'BB'),
        _action(5, 'fold', 'preflop', 'UTG', isHero: true),
      ],
      potAmount: 800,
      winnerId: 8,
    ));

    // Hand 10: MISTAKE - UTG open with K3s (too loose)
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 4,
      heroPosition: 5,
      heroCards: {'card1': 'K♥', 'card2': '3♥'},
      playerNames: createPlayerNames([null, null, null, 'MANIAC Jake', null, null, null, null, null]),
      actions: [
        _action(5, 'raise', 'preflop', 'UTG', amount: 500, isHero: true),
        _action(6, 'fold', 'preflop', 'UTG+1'),
        _action(7, 'fold', 'preflop', 'MP'),
        _action(8, 'fold', 'preflop', 'HJ'),
        _action(9, 'raise', 'preflop', 'CO', amount: 1500, playerName: 'MANIAC Jake'),
        _action(1, 'fold', 'preflop', 'BTN'),
        _action(2, 'fold', 'preflop', 'SB'),
        _action(3, 'fold', 'preflop', 'BB'),
        _action(5, 'fold', 'preflop', 'UTG', isHero: true),
      ],
      potAmount: 800,
      winnerId: 9,
    ));

    // Hand 11: MISTAKE - BTN fold with AQo (should raise!)
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 5,
      heroPosition: 5,
      heroCards: {'card1': 'A♥', 'card2': 'Q♦'},
      playerNames: createPlayerNames([null, null, null, null, null, null, null, null, null]),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'CO'),
        _action(5, 'fold', 'preflop', 'BTN', isHero: true), // MISTAKE!
        _action(6, 'fold', 'preflop', 'SB'),
        _action(7, 'check', 'preflop', 'BB'),
      ],
      potAmount: 300,
      winnerId: 7,
    ));

    // Hand 12: MISTAKE - CO fold with KJs (should raise!)
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 6,
      heroPosition: 5,
      heroCards: {'card1': 'K♠', 'card2': 'J♠'},
      playerNames: createPlayerNames([null, null, null, null, null, null, null, null, null]),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'HJ'),
        _action(5, 'fold', 'preflop', 'CO', isHero: true), // MISTAKE!
        _action(6, 'raise', 'preflop', 'BTN', amount: 500),
        _action(7, 'fold', 'preflop', 'SB'),
        _action(8, 'fold', 'preflop', 'BB'),
      ],
      potAmount: 800,
      winnerId: 6,
    ));

    // Hand 13: Short stack shove BTN with A5s (12bb)
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 5,
      heroPosition: 5,
      heroCards: {'card1': 'A♣', 'card2': '5♣'},
      playerNames: createPlayerNames([null, null, null, null, null, 'NIT Helen', null, null, null]),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'CO'),
        _action(5, 'all_in', 'preflop', 'BTN', amount: 2400, isHero: true),
        _action(6, 'fold', 'preflop', 'SB', playerName: 'NIT Helen'),
        _action(7, 'fold', 'preflop', 'BB'),
      ],
      potAmount: 2700,
      winnerId: 5,
    ));

    // Hand 14: Short stack SB shove with KQs (15bb)
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 4,
      heroPosition: 5,
      heroCards: {'card1': 'K♦', 'card2': 'Q♠'},
      playerNames: createPlayerNames([null, null, null, null, null, 'FISH Mike', null, null, null]),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'BTN'),
        _action(5, 'all_in', 'preflop', 'SB', amount: 3000, isHero: true),
        _action(6, 'call', 'preflop', 'BB', amount: 2800, playerName: 'FISH Mike'),
      ],
      boardCards: {'flop': ['Q♥', '7♣', '3♦'], 'turn': '8♠', 'river': '2♣'},
      potAmount: 6000,
      reachedShowdown: true,
      showdownData: {
        'playerCards': {
          5: {'card1': 'K♦', 'card2': 'Q♠'},
          6: {'card1': 'J♥', 'card2': 'T♣'},
        },
        'winner': 5,
        'handDescription': 'Pair of Queens',
      },
      winnerId: 5,
    ));

    // Hand 15: Short stack BTN shove with 77 (18bb)
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 5,
      heroPosition: 5,
      heroCards: {'card1': '7♥', 'card2': '7♦'},
      playerNames: createPlayerNames([null, null, null, 'LAG Carlos', null, null, null, null, null]),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'raise', 'preflop', 'CO', amount: 500, playerName: 'LAG Carlos'),
        _action(5, 'all_in', 'preflop', 'BTN', amount: 3600, isHero: true),
        _action(6, 'fold', 'preflop', 'SB'),
        _action(7, 'fold', 'preflop', 'BB'),
        _action(4, 'fold', 'preflop', 'CO', playerName: 'LAG Carlos'),
      ],
      potAmount: 4400,
      winnerId: 5,
    ));

    // ===== VS OPEN SCENARIOS (15 hands) - Hands 16-30 =====

    // Hand 16: 3bet AA vs UTG open
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 5,
      heroPosition: 5,
      heroCards: {'card1': 'A♥', 'card2': 'A♦'},
      playerNames: createPlayerNames(['TAG Sarah', null, null, null, null, null, null, null, null]),
      actions: [
        _action(1, 'raise', 'preflop', 'UTG', amount: 500, playerName: 'TAG Sarah'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'CO'),
        _action(5, 'raise', 'preflop', 'BTN', amount: 1500, isHero: true),
        _action(6, 'fold', 'preflop', 'SB'),
        _action(7, 'fold', 'preflop', 'BB'),
        _action(1, 'call', 'preflop', 'UTG', amount: 1000, playerName: 'TAG Sarah'),
        // Flop
        _action(1, 'check', 'flop', 'UTG', playerName: 'TAG Sarah'),
        _action(5, 'bet', 'flop', 'BTN', amount: 1800, isHero: true),
        _action(1, 'call', 'flop', 'UTG', amount: 1800, playerName: 'TAG Sarah'),
        // Turn
        _action(1, 'check', 'turn', 'UTG', playerName: 'TAG Sarah'),
        _action(5, 'bet', 'turn', 'BTN', amount: 4000, isHero: true),
        _action(1, 'fold', 'turn', 'UTG', playerName: 'TAG Sarah'),
      ],
      boardCards: {'flop': ['K♣', '9♦', '4♠'], 'turn': '2♥'},
      potAmount: 6900,
      preflopPot: 3300,
      flopPot: 6900,
      turnPot: 6900,
      winnerId: 5,
    ));

    // Hand 17: 3bet KK in BB vs CO open (FISH Mike)
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 1,
      heroPosition: 5, // BB
      heroCards: {'card1': 'K♠', 'card2': 'K♣'},
      playerNames: createPlayerNames([null, null, 'FISH Mike', null, null, null, null, null, null]),
      actions: [
        _action(2, 'fold', 'preflop', 'UTG'),
        _action(3, 'raise', 'preflop', 'UTG+1', amount: 500, playerName: 'FISH Mike'),
        _action(4, 'fold', 'preflop', 'MP'),
        _action(5, 'raise', 'preflop', 'BB', amount: 1600, isHero: true),
        _action(3, 'call', 'preflop', 'UTG+1', amount: 1100, playerName: 'FISH Mike'),
        // Flop: All-in
        _action(5, 'all_in', 'flop', 'BB', amount: 8000, isHero: true),
        _action(3, 'call', 'flop', 'UTG+1', amount: 8000, playerName: 'FISH Mike'),
      ],
      boardCards: {'flop': ['7♥', '4♣', '2♦'], 'turn': 'J♠', 'river': '5♣'},
      potAmount: 19200,
      preflopPot: 3200,
      flopPot: 19200,
      reachedShowdown: true,
      showdownData: {
        'playerCards': {
          5: {'card1': 'K♠', 'card2': 'K♣'},
          3: {'card1': 'Q♥', 'card2': 'J♥'},
        },
        'winner': 5,
        'handDescription': 'Pair of Kings',
      },
      winnerId: 5,
    ));

    // Hand 18: 3bet AKs in SB vs BTN open (LAG Carlos)
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 4,
      heroPosition: 5, // SB
      heroCards: {'card1': 'A♠', 'card2': 'K♠'},
      playerNames: createPlayerNames([null, null, null, 'LAG Carlos', null, null, null, null, null]),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'raise', 'preflop', 'BTN', amount: 500, playerName: 'LAG Carlos'),
        _action(5, 'raise', 'preflop', 'SB', amount: 1700, isHero: true),
        _action(6, 'fold', 'preflop', 'BB'),
        _action(4, 'fold', 'preflop', 'BTN', playerName: 'LAG Carlos'),
      ],
      potAmount: 2500,
      winnerId: 5,
    ));

    // Hand 19: Flat call J9s on BTN vs CO open (TAG Sarah)
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 5,
      heroPosition: 5,
      heroCards: {'card1': 'J♥', 'card2': '9♥'},
      playerNames: createPlayerNames([null, null, null, 'TAG Sarah', null, null, null, null, null]),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'raise', 'preflop', 'CO', amount: 500, playerName: 'TAG Sarah'),
        _action(5, 'call', 'preflop', 'BTN', amount: 500, isHero: true),
        _action(6, 'fold', 'preflop', 'SB'),
        _action(7, 'fold', 'preflop', 'BB'),
        // Flop: hit flush draw
        _action(4, 'bet', 'flop', 'CO', amount: 600, playerName: 'TAG Sarah'),
        _action(5, 'call', 'flop', 'BTN', amount: 600, isHero: true),
        // Turn: make flush
        _action(4, 'check', 'turn', 'CO', playerName: 'TAG Sarah'),
        _action(5, 'bet', 'turn', 'BTN', amount: 1200, isHero: true),
        _action(4, 'call', 'turn', 'CO', amount: 1200, playerName: 'TAG Sarah'),
        // River
        _action(4, 'check', 'river', 'CO', playerName: 'TAG Sarah'),
        _action(5, 'bet', 'river', 'BTN', amount: 2500, isHero: true),
        _action(4, 'fold', 'river', 'CO', playerName: 'TAG Sarah'),
      ],
      boardCards: {'flop': ['T♥', '4♥', '2♣'], 'turn': '7♥', 'river': 'K♠'},
      potAmount: 5900,
      reachedShowdown: false,
      winnerId: 5,
    ));

    // Hand 20: Flat call T8s in BB vs BTN open (FISH Mike)
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 4,
      heroPosition: 5, // BB
      heroCards: {'card1': 'T♣', 'card2': '8♣'},
      playerNames: createPlayerNames([null, null, null, 'FISH Mike', null, null, null, null, null]),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'raise', 'preflop', 'BTN', amount: 500, playerName: 'FISH Mike'),
        _action(5, 'call', 'preflop', 'BB', amount: 300, isHero: true),
        // Flop
        _action(5, 'check', 'flop', 'BB', isHero: true),
        _action(4, 'bet', 'flop', 'BTN', amount: 500, playerName: 'FISH Mike'),
        _action(5, 'call', 'flop', 'BB', amount: 500, isHero: true),
        // Turn
        _action(5, 'check', 'turn', 'BB', isHero: true),
        _action(4, 'check', 'turn', 'BTN', playerName: 'FISH Mike'),
        // River
        _action(5, 'bet', 'river', 'BB', amount: 1000, isHero: true),
        _action(4, 'call', 'river', 'BTN', amount: 1000, playerName: 'FISH Mike'),
      ],
      boardCards: {'flop': ['T♦', '6♥', '3♠'], 'turn': '2♦', 'river': '9♣'},
      potAmount: 4000,
      reachedShowdown: true,
      showdownData: {
        'playerCards': {
          5: {'card1': 'T♣', 'card2': '8♣'},
          4: {'card1': 'A♠', 'card2': '7♦'},
        },
        'winner': 5,
        'handDescription': 'Pair of Tens',
      },
      winnerId: 5,
    ));

    // Generate remaining hands (21-50) with varied scenarios
    final remainingHands = _generateRemainingHands(sessionId, handNumber, opponentMap);
    hands.addAll(remainingHands);

    return hands;
  }

  static List<Map<String, dynamic>> _generateRemainingHands(
    String sessionId,
    int startHandNumber,
    Map<String, String> opponentMap,
  ) {
    final hands = <Map<String, dynamic>>[];
    var handNumber = startHandNumber;

    // Standard full table with all 9 players named
    Map<int, String> fullTable({
      String? seat1,
      String? seat2,
      String? seat3,
      String? seat4,
      String? seat6,
      String? seat7,
      String? seat8,
      String? seat9,
    }) {
      return {
        1: seat1 ?? 'Player 1',
        2: seat2 ?? 'Player 2',
        3: seat3 ?? 'FISH Mike',
        4: seat4 ?? 'TAG Sarah',
        5: 'Hero',
        6: seat6 ?? 'LAG Carlos',
        7: seat7 ?? 'NIT Helen',
        8: seat8 ?? 'MANIAC Jake',
        9: seat9 ?? 'Player 9',
      };
    }

    // Hand 21: Flat 66 in CO vs MP open (NIT Helen)
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 6,
      heroPosition: 5,
      heroCards: {'card1': '6♥', 'card2': '6♦'},
      playerNames: fullTable(seat3: 'NIT Helen'),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'raise', 'preflop', 'MP', amount: 500, playerName: 'NIT Helen'),
        _action(4, 'fold', 'preflop', 'HJ'),
        _action(5, 'call', 'preflop', 'CO', amount: 500, isHero: true),
        _action(6, 'fold', 'preflop', 'BTN'),
        _action(7, 'fold', 'preflop', 'SB'),
        _action(8, 'fold', 'preflop', 'BB'),
        _action(3, 'bet', 'flop', 'MP', amount: 700, playerName: 'NIT Helen'),
        _action(5, 'fold', 'flop', 'CO', isHero: true),
      ],
      boardCards: {'flop': ['A♣', 'K♦', '9♠']},
      potAmount: 1300,
      winnerId: 3,
    ));

    // Hand 22: Fold K4s vs UTG open (NIT Helen)
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 5,
      heroPosition: 5,
      heroCards: {'card1': 'K♥', 'card2': '4♠'},
      playerNames: fullTable(seat1: 'NIT Helen'),
      actions: [
        _action(1, 'raise', 'preflop', 'UTG', amount: 500, playerName: 'NIT Helen'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'CO'),
        _action(5, 'fold', 'preflop', 'BTN', isHero: true),
        _action(6, 'fold', 'preflop', 'SB'),
        _action(7, 'fold', 'preflop', 'BB'),
      ],
      potAmount: 800,
      winnerId: 1,
    ));

    // Hand 23: Fold Q7o vs UTG open (TAG Sarah)
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 6,
      heroPosition: 5,
      heroCards: {'card1': 'Q♣', 'card2': '7♦'},
      playerNames: fullTable(seat1: 'TAG Sarah'),
      actions: [
        _action(1, 'raise', 'preflop', 'UTG', amount: 500, playerName: 'TAG Sarah'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'HJ'),
        _action(5, 'fold', 'preflop', 'CO', isHero: true),
        _action(6, 'fold', 'preflop', 'BTN'),
        _action(7, 'fold', 'preflop', 'SB'),
        _action(8, 'fold', 'preflop', 'BB'),
      ],
      potAmount: 800,
      winnerId: 1,
    ));

    // Hand 24: Fold 95o in BB vs CO open (TAG Sarah)
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 1,
      heroPosition: 5,
      heroCards: {'card1': '9♥', 'card2': '5♠'},
      playerNames: fullTable(seat4: 'TAG Sarah'),
      actions: [
        _action(2, 'fold', 'preflop', 'UTG'),
        _action(3, 'fold', 'preflop', 'UTG+1'),
        _action(4, 'raise', 'preflop', 'CO', amount: 500, playerName: 'TAG Sarah'),
        _action(1, 'fold', 'preflop', 'BTN'),
        _action(5, 'fold', 'preflop', 'BB', isHero: true),
      ],
      potAmount: 800,
      winnerId: 4,
    ));

    // Hand 25: MISTAKE - Fold AKo vs UTG open from FISH
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 5,
      heroPosition: 5,
      heroCards: {'card1': 'A♣', 'card2': 'K♥'},
      playerNames: fullTable(seat1: 'FISH Mike'),
      actions: [
        _action(1, 'raise', 'preflop', 'UTG', amount: 500, playerName: 'FISH Mike'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'CO'),
        _action(5, 'fold', 'preflop', 'BTN', isHero: true), // MISTAKE!
        _action(6, 'fold', 'preflop', 'SB'),
        _action(7, 'fold', 'preflop', 'BB'),
      ],
      potAmount: 800,
      winnerId: 1,
    ));

    // Hand 26: MISTAKE - Call 83o in BB vs UTG open (NIT Helen)
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 1,
      heroPosition: 5,
      heroCards: {'card1': '8♥', 'card2': '3♦'},
      playerNames: fullTable(seat2: 'NIT Helen'),
      actions: [
        _action(2, 'raise', 'preflop', 'UTG', amount: 500, playerName: 'NIT Helen'),
        _action(3, 'fold', 'preflop', 'UTG+1'),
        _action(4, 'fold', 'preflop', 'MP'),
        _action(1, 'fold', 'preflop', 'BTN'),
        _action(5, 'call', 'preflop', 'BB', amount: 300, isHero: true), // MISTAKE!
        _action(2, 'bet', 'flop', 'UTG', amount: 700, playerName: 'NIT Helen'),
        _action(5, 'fold', 'flop', 'BB', isHero: true),
      ],
      boardCards: {'flop': ['K♠', 'Q♦', 'J♣']},
      potAmount: 1300,
      winnerId: 2,
    ));

    // Hand 27: 3bet with 55 vs UTG open from NIT
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 5,
      heroPosition: 5,
      heroCards: {'card1': '5♠', 'card2': '5♣'},
      playerNames: fullTable(seat1: 'NIT Helen'),
      actions: [
        _action(1, 'raise', 'preflop', 'UTG', amount: 500, playerName: 'NIT Helen'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'CO'),
        _action(5, 'raise', 'preflop', 'BTN', amount: 1500, isHero: true),
        _action(6, 'fold', 'preflop', 'SB'),
        _action(7, 'fold', 'preflop', 'BB'),
        _action(1, 'fold', 'preflop', 'UTG', playerName: 'NIT Helen'),
      ],
      potAmount: 2300,
      winnerId: 5,
    ));

    // Hand 28: Short stack reshove AQo vs BTN open
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 4,
      heroPosition: 5,
      heroCards: {'card1': 'A♠', 'card2': 'Q♦'},
      playerNames: fullTable(seat4: 'LAG Carlos'),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'raise', 'preflop', 'BTN', amount: 500, playerName: 'LAG Carlos'),
        _action(5, 'all_in', 'preflop', 'SB', amount: 3000, isHero: true),
        _action(6, 'fold', 'preflop', 'BB'),
        _action(4, 'fold', 'preflop', 'BTN', playerName: 'LAG Carlos'),
      ],
      potAmount: 3800,
      winnerId: 5,
    ));

    // Hand 29: Defend BB with J8s vs BTN open from MANIAC
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 4,
      heroPosition: 5,
      heroCards: {'card1': 'J♠', 'card2': '8♠'},
      playerNames: fullTable(seat4: 'MANIAC Jake'),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'raise', 'preflop', 'BTN', amount: 600, playerName: 'MANIAC Jake'),
        _action(5, 'call', 'preflop', 'BB', amount: 400, isHero: true),
        // Flop
        _action(5, 'check', 'flop', 'BB', isHero: true),
        _action(4, 'bet', 'flop', 'BTN', amount: 800, playerName: 'MANIAC Jake'),
        _action(5, 'call', 'flop', 'BB', amount: 800, isHero: true),
        // Turn
        _action(5, 'check', 'turn', 'BB', isHero: true),
        _action(4, 'check', 'turn', 'BTN', playerName: 'MANIAC Jake'),
        // River
        _action(5, 'bet', 'river', 'BB', amount: 1200, isHero: true),
        _action(4, 'fold', 'river', 'BTN', playerName: 'MANIAC Jake'),
      ],
      boardCards: {'flop': ['J♦', '7♣', '2♥'], 'turn': '4♠', 'river': 'K♣'},
      potAmount: 4000,
      winnerId: 5,
    ));

    // Hand 30: Flat T9s in CO vs MP open from FISH
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 6,
      heroPosition: 5,
      heroCards: {'card1': 'T♦', 'card2': '9♦'},
      playerNames: fullTable(seat3: 'FISH Mike'),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'raise', 'preflop', 'MP', amount: 500, playerName: 'FISH Mike'),
        _action(4, 'fold', 'preflop', 'HJ'),
        _action(5, 'call', 'preflop', 'CO', amount: 500, isHero: true),
        _action(6, 'fold', 'preflop', 'BTN'),
        _action(7, 'fold', 'preflop', 'SB'),
        _action(8, 'fold', 'preflop', 'BB'),
        // Flop - hit straight draw
        _action(3, 'bet', 'flop', 'MP', amount: 700, playerName: 'FISH Mike'),
        _action(5, 'call', 'flop', 'CO', amount: 700, isHero: true),
        // Turn - hit straight
        _action(3, 'bet', 'turn', 'MP', amount: 1200, playerName: 'FISH Mike'),
        _action(5, 'raise', 'turn', 'CO', amount: 3000, isHero: true),
        _action(3, 'call', 'turn', 'MP', amount: 1800, playerName: 'FISH Mike'),
        // River
        _action(3, 'check', 'river', 'MP', playerName: 'FISH Mike'),
        _action(5, 'bet', 'river', 'CO', amount: 4000, isHero: true),
        _action(3, 'call', 'river', 'MP', amount: 4000, playerName: 'FISH Mike'),
      ],
      boardCards: {'flop': ['8♣', '7♥', '2♠'], 'turn': '6♦', 'river': 'K♣'},
      potAmount: 17400,
      reachedShowdown: true,
      showdownData: {
        'playerCards': {
          5: {'card1': 'T♦', 'card2': '9♦'},
          3: {'card1': 'A♣', 'card2': 'K♠'},
        },
        'winner': 5,
        'handDescription': 'Straight T-6',
      },
      winnerId: 5,
    ));

    // Hand 31: 4bet AA vs 3bet from TAG Sarah
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 6,
      heroPosition: 5,
      heroCards: {'card1': 'A♥', 'card2': 'A♠'},
      playerNames: fullTable(seat7: 'TAG Sarah'),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'HJ'),
        _action(5, 'raise', 'preflop', 'CO', amount: 500, isHero: true),
        _action(6, 'fold', 'preflop', 'BTN'),
        _action(7, 'raise', 'preflop', 'SB', amount: 1800, playerName: 'TAG Sarah'),
        _action(8, 'fold', 'preflop', 'BB'),
        _action(5, 'raise', 'preflop', 'CO', amount: 4500, isHero: true),
        _action(7, 'call', 'preflop', 'SB', amount: 2700, playerName: 'TAG Sarah'),
        // Flop
        _action(7, 'check', 'flop', 'SB', playerName: 'TAG Sarah'),
        _action(5, 'bet', 'flop', 'CO', amount: 3000, isHero: true),
        _action(7, 'fold', 'flop', 'SB', playerName: 'TAG Sarah'),
      ],
      boardCards: {'flop': ['K♣', '8♦', '3♠']},
      potAmount: 12000,
      winnerId: 5,
    ));

    // Hand 32: 4bet KK vs 3bet from LAG Carlos
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 5,
      heroPosition: 5,
      heroCards: {'card1': 'K♣', 'card2': 'K♦'},
      playerNames: fullTable(seat7: 'LAG Carlos'),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'CO'),
        _action(5, 'raise', 'preflop', 'BTN', amount: 500, isHero: true),
        _action(6, 'fold', 'preflop', 'SB'),
        _action(7, 'raise', 'preflop', 'BB', amount: 1600, playerName: 'LAG Carlos'),
        _action(5, 'raise', 'preflop', 'BTN', amount: 4000, isHero: true),
        _action(7, 'all_in', 'preflop', 'BB', amount: 10000, playerName: 'LAG Carlos'),
        _action(5, 'call', 'preflop', 'BTN', amount: 6000, isHero: true),
      ],
      boardCards: {'flop': ['9♥', '7♣', '2♦'], 'turn': '4♠', 'river': '3♣'},
      potAmount: 20300,
      reachedShowdown: true,
      showdownData: {
        'playerCards': {
          5: {'card1': 'K♣', 'card2': 'K♦'},
          7: {'card1': 'A♣', 'card2': 'J♠'},
        },
        'winner': 5,
        'handDescription': 'Pair of Kings',
      },
      winnerId: 5,
    ));

    // Hand 33: Call 3bet with QQ vs MANIAC Jake
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 5,
      heroPosition: 5,
      heroCards: {'card1': 'Q♥', 'card2': 'Q♣'},
      playerNames: fullTable(seat6: 'MANIAC Jake'),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'CO'),
        _action(5, 'raise', 'preflop', 'BTN', amount: 500, isHero: true),
        _action(6, 'raise', 'preflop', 'SB', amount: 1800, playerName: 'MANIAC Jake'),
        _action(7, 'fold', 'preflop', 'BB'),
        _action(5, 'call', 'preflop', 'BTN', amount: 1300, isHero: true),
        // Flop
        _action(6, 'bet', 'flop', 'SB', amount: 2000, playerName: 'MANIAC Jake'),
        _action(5, 'call', 'flop', 'BTN', amount: 2000, isHero: true),
        // Turn
        _action(6, 'check', 'turn', 'SB', playerName: 'MANIAC Jake'),
        _action(5, 'bet', 'turn', 'BTN', amount: 3500, isHero: true),
        _action(6, 'fold', 'turn', 'SB', playerName: 'MANIAC Jake'),
      ],
      boardCards: {'flop': ['J♦', '8♣', '4♠'], 'turn': '2♥'},
      potAmount: 11100,
      winnerId: 5,
    ));

    // Hand 34: Call 3bet with AKo from TAG Sarah
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 6,
      heroPosition: 5,
      heroCards: {'card1': 'A♥', 'card2': 'K♦'},
      playerNames: fullTable(seat6: 'TAG Sarah'),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'HJ'),
        _action(5, 'raise', 'preflop', 'CO', amount: 500, isHero: true),
        _action(6, 'raise', 'preflop', 'BTN', amount: 1500, playerName: 'TAG Sarah'),
        _action(7, 'fold', 'preflop', 'SB'),
        _action(8, 'fold', 'preflop', 'BB'),
        _action(5, 'call', 'preflop', 'CO', amount: 1000, isHero: true),
        // Flop - hit top pair
        _action(5, 'check', 'flop', 'CO', isHero: true),
        _action(6, 'bet', 'flop', 'BTN', amount: 2000, playerName: 'TAG Sarah'),
        _action(5, 'call', 'flop', 'CO', amount: 2000, isHero: true),
        // Turn
        _action(5, 'check', 'turn', 'CO', isHero: true),
        _action(6, 'check', 'turn', 'BTN', playerName: 'TAG Sarah'),
        // River
        _action(5, 'bet', 'river', 'CO', amount: 2500, isHero: true),
        _action(6, 'call', 'river', 'BTN', amount: 2500, playerName: 'TAG Sarah'),
      ],
      boardCards: {'flop': ['A♣', '9♦', '5♠'], 'turn': '7♥', 'river': '2♣'},
      potAmount: 12000,
      reachedShowdown: true,
      showdownData: {
        'playerCards': {
          5: {'card1': 'A♥', 'card2': 'K♦'},
          6: {'card1': 'Q♠', 'card2': 'Q♣'},
        },
        'winner': 5,
        'handDescription': 'Pair of Aces',
      },
      winnerId: 5,
    ));

    // Hand 35: Fold A9s to 3bet from NIT Helen
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 6,
      heroPosition: 5,
      heroCards: {'card1': 'A♠', 'card2': '9♠'},
      playerNames: fullTable(seat7: 'NIT Helen'),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'HJ'),
        _action(5, 'raise', 'preflop', 'CO', amount: 500, isHero: true),
        _action(6, 'fold', 'preflop', 'BTN'),
        _action(7, 'raise', 'preflop', 'SB', amount: 1800, playerName: 'NIT Helen'),
        _action(8, 'fold', 'preflop', 'BB'),
        _action(5, 'fold', 'preflop', 'CO', isHero: true),
      ],
      potAmount: 2100,
      winnerId: 7,
    ));

    // Hand 36: Fold K8s to 3bet from TAG Sarah
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 5,
      heroPosition: 5,
      heroCards: {'card1': 'K♥', 'card2': '8♥'},
      playerNames: fullTable(seat6: 'TAG Sarah'),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'CO'),
        _action(5, 'raise', 'preflop', 'BTN', amount: 500, isHero: true),
        _action(6, 'raise', 'preflop', 'SB', amount: 1700, playerName: 'TAG Sarah'),
        _action(7, 'fold', 'preflop', 'BB'),
        _action(5, 'fold', 'preflop', 'BTN', isHero: true),
      ],
      potAmount: 2000,
      winnerId: 6,
    ));

    // Hand 37: MISTAKE - Fold JJ to 3bet from FISH Mike
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 6,
      heroPosition: 5,
      heroCards: {'card1': 'J♥', 'card2': 'J♣'},
      playerNames: fullTable(seat6: 'FISH Mike'),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'HJ'),
        _action(5, 'raise', 'preflop', 'CO', amount: 500, isHero: true),
        _action(6, 'raise', 'preflop', 'BTN', amount: 1500, playerName: 'FISH Mike'),
        _action(7, 'fold', 'preflop', 'SB'),
        _action(8, 'fold', 'preflop', 'BB'),
        _action(5, 'fold', 'preflop', 'CO', isHero: true), // MISTAKE - should call or 4bet vs FISH
      ],
      potAmount: 1800,
      winnerId: 6,
    ));

    // Hand 38: MISTAKE - Call 99 short (should shove or fold)
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 6,
      heroPosition: 5,
      heroCards: {'card1': '9♣', 'card2': '9♦'},
      playerNames: fullTable(seat7: 'NIT Helen'),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'HJ'),
        _action(5, 'raise', 'preflop', 'CO', amount: 500, isHero: true),
        _action(6, 'fold', 'preflop', 'BTN'),
        _action(7, 'raise', 'preflop', 'SB', amount: 1600, playerName: 'NIT Helen'),
        _action(8, 'fold', 'preflop', 'BB'),
        _action(5, 'call', 'preflop', 'CO', amount: 1100, isHero: true), // MISTAKE - should fold or 4bet shove
        // Flop
        _action(7, 'bet', 'flop', 'SB', amount: 2000, playerName: 'NIT Helen'),
        _action(5, 'fold', 'flop', 'CO', isHero: true),
      ],
      boardCards: {'flop': ['K♠', 'Q♦', 'T♣']},
      potAmount: 3400,
      winnerId: 7,
    ));

    // Hand 39: MISTAKE - Fold AQs to 3bet from MANIAC
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 5,
      heroPosition: 5,
      heroCards: {'card1': 'A♣', 'card2': 'Q♣'},
      playerNames: fullTable(seat6: 'MANIAC Jake'),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'CO'),
        _action(5, 'raise', 'preflop', 'BTN', amount: 500, isHero: true),
        _action(6, 'raise', 'preflop', 'SB', amount: 1800, playerName: 'MANIAC Jake'),
        _action(7, 'fold', 'preflop', 'BB'),
        _action(5, 'fold', 'preflop', 'BTN', isHero: true), // MISTAKE - should 4bet vs MANIAC
      ],
      potAmount: 2100,
      winnerId: 6,
    ));

    // Hand 40: 4bet bluff with 77 vs NIT (ambitious but they fold)
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 6,
      heroPosition: 5,
      heroCards: {'card1': '7♠', 'card2': '7♦'},
      playerNames: fullTable(seat7: 'NIT Helen'),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'HJ'),
        _action(5, 'raise', 'preflop', 'CO', amount: 500, isHero: true),
        _action(6, 'fold', 'preflop', 'BTN'),
        _action(7, 'raise', 'preflop', 'SB', amount: 1700, playerName: 'NIT Helen'),
        _action(8, 'fold', 'preflop', 'BB'),
        _action(5, 'raise', 'preflop', 'CO', amount: 4200, isHero: true),
        _action(7, 'fold', 'preflop', 'SB', playerName: 'NIT Helen'),
      ],
      potAmount: 4900,
      winnerId: 5,
    ));

    // Hand 41: SB open K7s, BB folds
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 4,
      heroPosition: 5,
      heroCards: {'card1': 'K♥', 'card2': '7♠'},
      playerNames: fullTable(seat6: 'FISH Mike'),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'BTN'),
        _action(5, 'raise', 'preflop', 'SB', amount: 600, isHero: true),
        _action(6, 'fold', 'preflop', 'BB', playerName: 'FISH Mike'),
      ],
      potAmount: 800,
      winnerId: 5,
    ));

    // Hand 42: SB open Q9o, BB defends
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 4,
      heroPosition: 5,
      heroCards: {'card1': 'Q♣', 'card2': '9♦'},
      playerNames: fullTable(seat6: 'TAG Sarah'),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'BTN'),
        _action(5, 'raise', 'preflop', 'SB', amount: 600, isHero: true),
        _action(6, 'call', 'preflop', 'BB', amount: 400, playerName: 'TAG Sarah'),
        // Flop
        _action(5, 'bet', 'flop', 'SB', amount: 700, isHero: true),
        _action(6, 'fold', 'flop', 'BB', playerName: 'TAG Sarah'),
      ],
      boardCards: {'flop': ['K♦', '8♣', '3♠']},
      potAmount: 1200,
      winnerId: 5,
    ));

    // Hand 43: BB 3bet A4s vs SB open from FISH
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 4,
      heroPosition: 5,
      heroCards: {'card1': 'A♣', 'card2': '4♠'},
      playerNames: fullTable(seat4: 'FISH Mike'),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'raise', 'preflop', 'BTN', amount: 500, playerName: 'FISH Mike'),
        _action(5, 'raise', 'preflop', 'BB', amount: 1600, isHero: true),
        _action(4, 'call', 'preflop', 'BTN', amount: 1100, playerName: 'FISH Mike'),
        // Flop
        _action(5, 'bet', 'flop', 'BB', amount: 1500, isHero: true),
        _action(4, 'fold', 'flop', 'BTN', playerName: 'FISH Mike'),
      ],
      boardCards: {'flop': ['7♥', '5♣', '2♦']},
      potAmount: 3500,
      winnerId: 5,
    ));

    // Hand 44: BB call J7s vs SB raise from TAG Sarah
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 4,
      heroPosition: 5,
      heroCards: {'card1': 'J♥', 'card2': '7♥'},
      playerNames: fullTable(seat4: 'TAG Sarah'),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'raise', 'preflop', 'BTN', amount: 500, playerName: 'TAG Sarah'),
        _action(5, 'call', 'preflop', 'BB', amount: 300, isHero: true),
        // Flop
        _action(5, 'check', 'flop', 'BB', isHero: true),
        _action(4, 'bet', 'flop', 'BTN', amount: 600, playerName: 'TAG Sarah'),
        _action(5, 'fold', 'flop', 'BB', isHero: true),
      ],
      boardCards: {'flop': ['A♠', 'K♦', '9♣']},
      potAmount: 1000,
      winnerId: 4,
    ));

    // Hand 45: SB fold 53s (conservative)
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 4,
      heroPosition: 5,
      heroCards: {'card1': '5♦', 'card2': '3♦'},
      playerNames: fullTable(seat6: 'LAG Carlos'),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'BTN'),
        _action(5, 'fold', 'preflop', 'SB', isHero: true),
        _action(6, 'check', 'preflop', 'BB', playerName: 'LAG Carlos'),
      ],
      potAmount: 300,
      winnerId: 6,
    ));

    // Hand 46: BTN open 66, everyone folds
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 5,
      heroPosition: 5,
      heroCards: {'card1': '6♠', 'card2': '6♣'},
      playerNames: fullTable(seat6: 'NIT Helen', seat7: 'FISH Mike'),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'CO'),
        _action(5, 'raise', 'preflop', 'BTN', amount: 500, isHero: true),
        _action(6, 'fold', 'preflop', 'SB', playerName: 'NIT Helen'),
        _action(7, 'fold', 'preflop', 'BB', playerName: 'FISH Mike'),
      ],
      potAmount: 800,
      winnerId: 5,
    ));

    // Hand 47: CO open AJh, take blinds
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 6,
      heroPosition: 5,
      heroCards: {'card1': 'A♥', 'card2': 'J♥'},
      playerNames: fullTable(seat7: 'TAG Sarah', seat8: 'LAG Carlos'),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'HJ'),
        _action(5, 'raise', 'preflop', 'CO', amount: 500, isHero: true),
        _action(6, 'fold', 'preflop', 'BTN'),
        _action(7, 'fold', 'preflop', 'SB', playerName: 'TAG Sarah'),
        _action(8, 'fold', 'preflop', 'BB', playerName: 'LAG Carlos'),
      ],
      potAmount: 800,
      winnerId: 5,
    ));

    // Hand 48: BB call T9s vs BTN from LAG Carlos
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 4,
      heroPosition: 5,
      heroCards: {'card1': 'T♠', 'card2': '9♠'},
      playerNames: fullTable(seat4: 'LAG Carlos'),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'raise', 'preflop', 'BTN', amount: 600, playerName: 'LAG Carlos'),
        _action(5, 'call', 'preflop', 'BB', amount: 400, isHero: true),
        // Flop - hit two pair
        _action(5, 'check', 'flop', 'BB', isHero: true),
        _action(4, 'bet', 'flop', 'BTN', amount: 800, playerName: 'LAG Carlos'),
        _action(5, 'raise', 'flop', 'BB', amount: 2200, isHero: true),
        _action(4, 'call', 'flop', 'BTN', amount: 1400, playerName: 'LAG Carlos'),
        // Turn
        _action(5, 'bet', 'turn', 'BB', amount: 3500, isHero: true),
        _action(4, 'fold', 'turn', 'BTN', playerName: 'LAG Carlos'),
      ],
      boardCards: {'flop': ['T♦', '9♣', '3♥'], 'turn': 'K♠'},
      potAmount: 9000,
      winnerId: 5,
    ));

    // Hand 49: BTN 3bet KQs vs CO from FISH
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 5,
      heroPosition: 5,
      heroCards: {'card1': 'K♦', 'card2': 'Q♦'},
      playerNames: fullTable(seat4: 'FISH Mike'),
      actions: [
        _action(1, 'fold', 'preflop', 'UTG'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'raise', 'preflop', 'CO', amount: 500, playerName: 'FISH Mike'),
        _action(5, 'raise', 'preflop', 'BTN', amount: 1500, isHero: true),
        _action(6, 'fold', 'preflop', 'SB'),
        _action(7, 'fold', 'preflop', 'BB'),
        _action(4, 'call', 'preflop', 'CO', amount: 1000, playerName: 'FISH Mike'),
        // Flop
        _action(4, 'check', 'flop', 'CO', playerName: 'FISH Mike'),
        _action(5, 'bet', 'flop', 'BTN', amount: 1800, isHero: true),
        _action(4, 'call', 'flop', 'CO', amount: 1800, playerName: 'FISH Mike'),
        // Turn
        _action(4, 'check', 'turn', 'CO', playerName: 'FISH Mike'),
        _action(5, 'bet', 'turn', 'BTN', amount: 3500, isHero: true),
        _action(4, 'fold', 'turn', 'CO', playerName: 'FISH Mike'),
      ],
      boardCards: {'flop': ['Q♣', '8♦', '4♠'], 'turn': '2♥'},
      potAmount: 9100,
      winnerId: 5,
    ));

    // Hand 50: CO call vs UTG from TAG Sarah
    hands.add(_createHand(
      sessionId: sessionId,
      handNumber: handNumber++,
      buttonPosition: 6,
      heroPosition: 5,
      heroCards: {'card1': '8♥', 'card2': '8♣'},
      playerNames: fullTable(seat1: 'TAG Sarah'),
      actions: [
        _action(1, 'raise', 'preflop', 'UTG', amount: 500, playerName: 'TAG Sarah'),
        _action(2, 'fold', 'preflop', 'UTG+1'),
        _action(3, 'fold', 'preflop', 'MP'),
        _action(4, 'fold', 'preflop', 'HJ'),
        _action(5, 'call', 'preflop', 'CO', amount: 500, isHero: true),
        _action(6, 'fold', 'preflop', 'BTN'),
        _action(7, 'fold', 'preflop', 'SB'),
        _action(8, 'fold', 'preflop', 'BB'),
        // Flop - hit set!
        _action(1, 'bet', 'flop', 'UTG', amount: 700, playerName: 'TAG Sarah'),
        _action(5, 'call', 'flop', 'CO', amount: 700, isHero: true),
        // Turn
        _action(1, 'bet', 'turn', 'UTG', amount: 1500, playerName: 'TAG Sarah'),
        _action(5, 'raise', 'turn', 'CO', amount: 4000, isHero: true),
        _action(1, 'call', 'turn', 'UTG', amount: 2500, playerName: 'TAG Sarah'),
        // River
        _action(1, 'check', 'river', 'UTG', playerName: 'TAG Sarah'),
        _action(5, 'bet', 'river', 'CO', amount: 6000, isHero: true),
        _action(1, 'call', 'river', 'UTG', amount: 6000, playerName: 'TAG Sarah'),
      ],
      boardCards: {'flop': ['8♦', '5♣', '2♠'], 'turn': 'K♥', 'river': '9♣'},
      potAmount: 23400,
      reachedShowdown: true,
      showdownData: {
        'playerCards': {
          5: {'card1': '8♥', 'card2': '8♣'},
          1: {'card1': 'A♠', 'card2': 'A♥'},
        },
        'winner': 5,
        'handDescription': 'Set of Eights',
      },
      winnerId: 5,
    ));

    return hands;
  }

  /// Convert showdownData to have string keys for JSON encoding
  static Map<String, dynamic> _convertShowdownData(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);
    if (result.containsKey('playerCards') && result['playerCards'] is Map) {
      final playerCards = result['playerCards'] as Map;
      result['playerCards'] = playerCards.map((k, v) => MapEntry(k.toString(), v));
    }
    return result;
  }

  static Map<String, dynamic> _createHand({
    required String sessionId,
    required int handNumber,
    required int buttonPosition,
    required int heroPosition,
    required Map<String, String> heroCards,
    required Map<int, String> playerNames,
    required List<Map<String, dynamic>> actions,
    double potAmount = 0,
    double preflopPot = 0,
    double flopPot = 0,
    double turnPot = 0,
    double riverPot = 0,
    Map<String, dynamic>? boardCards,
    Map<String, dynamic>? showdownData,
    bool reachedShowdown = false,
    int? winnerId,
  }) {
    final now = DateTime.now();
    // Convert int keys to string keys for JSON encoding
    final playerNamesStringKeys = playerNames.map((k, v) => MapEntry(k.toString(), v));

    return {
      'id': _uuid.v4(),
      'sessionId': sessionId,
      'handNumber': handNumber,
      'buttonPosition': buttonPosition,
      'playerCount': 9,
      'startTime': now.subtract(Duration(minutes: 180 - handNumber * 3)).toIso8601String(),
      'endTime': now.subtract(Duration(minutes: 177 - handNumber * 3)).toIso8601String(),
      'actions': jsonEncode(actions),
      'boardCards': boardCards != null ? jsonEncode(boardCards) : null,
      'ourHoleCards': jsonEncode(heroCards),
      'showdownData': showdownData != null ? jsonEncode(_convertShowdownData(showdownData)) : null,
      'reachedShowdown': reachedShowdown ? 1 : 0,
      'potAmount': potAmount,
      'preflopPot': preflopPot > 0 ? preflopPot : potAmount,
      'flopPot': flopPot,
      'turnPot': turnPot,
      'riverPot': riverPot,
      'winnerId': winnerId,
      'heroPosition': heroPosition,
      'playerNames': jsonEncode(playerNamesStringKeys),
      'handSmallBlind': 100,
      'handBigBlind': 200,
      'handGameType': 'tournament',
      'isChoppedPot': 0,
      'choppedWinners': null,
      'individualShares': null,
      'sharePerWinner': null,
    };
  }

  static Map<String, dynamic> _action(
    int player,
    String action,
    String street,
    String position, {
    double? amount,
    String? playerName,
    bool isHero = false,
  }) {
    return {
      'player': player,
      'action': action,
      'street': street,
      'timestamp': DateTime.now().toIso8601String(),
      'buttonPosition': 5,
      'playerName': isHero ? 'Hero' : (playerName ?? 'Player $player'),
      'playerId': isHero ? 'hero_id' : 'player_$player',
      'isCurrentUser': isHero,
      'playerPosition': position,
      'playerStack': 10000.0,
      if (amount != null) 'amount': amount,
    };
  }
}
