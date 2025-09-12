import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/opponent.dart';

/// Service for managing opponent data in both Firebase and local storage
class OpponentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  static CollectionReference get _opponentsCollection =>
      _firestore.collection('opponents');

  // Local storage keys
  static const String _localOpponentsKey = 'poker_opponents';

  /// Get current user ID
  static String? get _userId => _auth.currentUser?.uid;

  /// Save or update opponent in both Firebase and local storage
  static Future<void> saveOpponent(Opponent opponent) async {
    try {
      // Save to Firebase first
      await _saveOpponentToFirebase(opponent);
      print('✅ Opponent saved to Firebase: ${opponent.name}');
    } catch (e) {
      print('⚠️ Firebase save failed, using local storage: $e');
    }
    
    // Always save to local storage as backup
    await _saveOpponentToLocal(opponent);
    print('✅ Opponent saved locally: ${opponent.name}');
  }

  /// Get all opponents from Firebase with fallback to local storage
  static Future<List<Opponent>> getAllOpponents() async {
    try {
      // Try Firebase first
      final firebaseOpponents = await _getOpponentsFromFirebase();
      print('📊 Loaded ${firebaseOpponents.length} opponents from Firebase');
      return firebaseOpponents;
    } catch (e) {
      print('⚠️ Firebase load failed, using local storage: $e');
      // Fallback to local storage
      final localOpponents = await _getOpponentsFromLocal();
      print('📊 Loaded ${localOpponents.length} opponents from local storage');
      return localOpponents;
    }
  }

  /// Delete opponent from both Firebase and local storage
  static Future<void> deleteOpponent(String opponentId) async {
    try {
      // Delete from Firebase
      await _deleteOpponentFromFirebase(opponentId);
      print('🗑️ Opponent deleted from Firebase: $opponentId');
    } catch (e) {
      print('⚠️ Firebase delete failed: $e');
    }
    
    // Delete from local storage
    await _deleteOpponentFromLocal(opponentId);
    print('🗑️ Opponent deleted locally: $opponentId');
  }

  /// Find opponent by name (case insensitive)
  static Future<Opponent?> findOpponentByName(String name) async {
    final opponents = await getAllOpponents();
    try {
      return opponents.firstWhere(
        (opponent) => opponent.name.toLowerCase() == name.toLowerCase()
      );
    } catch (e) {
      return null; // Not found
    }
  }

  /// Update opponent statistics
  static Future<void> updateOpponentStats(String opponentId, {
    int? additionalHands,
    int? additionalSessions,
    double? vpip,
    double? pfr,
    double? threeBet,
    double? cbet,
    double? fold3bet,
    double? aggression,
  }) async {
    final opponents = await getAllOpponents();
    final opponent = opponents.cast<Opponent?>().firstWhere(
      (o) => o?.id == opponentId,
      orElse: () => null,
    );

    if (opponent != null) {
      final updatedOpponent = opponent.copyWith(
        handsPlayed: additionalHands != null 
            ? opponent.handsPlayed + additionalHands 
            : opponent.handsPlayed,
        sessionsPlayed: additionalSessions != null
            ? opponent.sessionsPlayed + additionalSessions
            : opponent.sessionsPlayed,
        vpip: vpip ?? opponent.vpip,
        pfr: pfr ?? opponent.pfr,
        threeBet: threeBet ?? opponent.threeBet,
        cbet: cbet ?? opponent.cbet,
        fold3bet: fold3bet ?? opponent.fold3bet,
        aggression: aggression ?? opponent.aggression,
        lastSeenAt: DateTime.now(),
      );

      await saveOpponent(updatedOpponent);
    }
  }

  /// Clear all opponents (for settings/debugging)
  static Future<void> clearAllOpponents() async {
    try {
      // Clear Firebase
      final userId = _userId;
      if (userId != null) {
        final batch = _firestore.batch();
        final snapshot = await _opponentsCollection
            .where('userId', isEqualTo: userId)
            .get();
        
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        print('🗑️ All opponents cleared from Firebase');
      }
    } catch (e) {
      print('⚠️ Error clearing Firebase opponents: $e');
    }

    // Clear local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localOpponentsKey);
    print('🗑️ All opponents cleared from local storage');
  }

  // === Firebase Operations ===

  static Future<void> _saveOpponentToFirebase(Opponent opponent) async {
    final userId = _userId;
    if (userId == null) throw Exception('User not authenticated');

    final data = opponent.toFirestore();
    data['userId'] = userId; // Add user ID for querying

    if (opponent.id.isNotEmpty && !opponent.id.startsWith('local_')) {
      // Update existing Firebase document
      await _opponentsCollection.doc(opponent.id).set(data, SetOptions(merge: true));
    } else {
      // Create new Firebase document (for both empty IDs and local IDs)
      final docRef = await _opponentsCollection.add(data);
      // Note: The local storage will keep the local ID, Firebase gets its own ID
      // This is intentional - they can have different IDs as they serve different purposes
    }
  }

  static Future<List<Opponent>> _getOpponentsFromFirebase() async {
    final userId = _userId;
    if (userId == null) throw Exception('User not authenticated');

    final snapshot = await _opponentsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('lastSeenAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Opponent.fromFirestore(doc))
        .toList();
  }

  static Future<void> _deleteOpponentFromFirebase(String opponentId) async {
    await _opponentsCollection.doc(opponentId).delete();
  }

  // === Local Storage Operations ===

  static Future<void> _saveOpponentToLocal(Opponent opponent) async {
    final prefs = await SharedPreferences.getInstance();
    final opponentsJson = prefs.getString(_localOpponentsKey);
    
    List<Map<String, dynamic>> opponents = [];
    if (opponentsJson != null) {
      final decoded = jsonDecode(opponentsJson) as List;
      opponents = decoded.cast<Map<String, dynamic>>();
    }

    // Remove existing opponent with same ID if updating
    opponents.removeWhere((o) => o['id'] == opponent.id);
    
    // Add the opponent
    opponents.add(opponent.toMap());

    // Save back to local storage
    await prefs.setString(_localOpponentsKey, jsonEncode(opponents));
  }

  static Future<List<Opponent>> _getOpponentsFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final opponentsJson = prefs.getString(_localOpponentsKey);
    
    if (opponentsJson == null) return [];

    final decoded = jsonDecode(opponentsJson) as List;
    return decoded
        .cast<Map<String, dynamic>>()
        .map((data) => Opponent.fromMap(data))
        .toList()
      ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt)); // Sort by last seen
  }

  static Future<void> _deleteOpponentFromLocal(String opponentId) async {
    final prefs = await SharedPreferences.getInstance();
    final opponentsJson = prefs.getString(_localOpponentsKey);
    
    if (opponentsJson == null) return;

    final decoded = jsonDecode(opponentsJson) as List;
    final opponents = decoded.cast<Map<String, dynamic>>();
    
    // Remove opponent
    opponents.removeWhere((o) => o['id'] == opponentId);

    // Save back
    await prefs.setString(_localOpponentsKey, jsonEncode(opponents));
  }

  /// Create a new opponent with basic info
  static Opponent createNewOpponent({
    required String name,
    String? notes,
    OpponentColor color = OpponentColor.blue,
  }) {
    // Generate a unique ID for local storage
    final uniqueId = 'local_${DateTime.now().millisecondsSinceEpoch}_${name.hashCode}';
    
    return Opponent(
      id: uniqueId, // Generate unique ID for local storage
      name: name,
      notes: notes,
      createdAt: DateTime.now(),
      lastSeenAt: DateTime.now(),
      color: color,
    );
  }

  /// Get opponent statistics summary for analysis
  static Future<Map<String, dynamic>> getOpponentAnalytics() async {
    final opponents = await getAllOpponents();
    
    if (opponents.isEmpty) {
      return {
        'totalOpponents': 0,
        'averageHands': 0,
        'mostPlayedAgainst': null,
        'playerTypeDistribution': <String, int>{},
      };
    }

    // Calculate analytics
    final totalHands = opponents.fold<int>(0, (sum, o) => sum + o.handsPlayed);
    final averageHands = totalHands / opponents.length;
    
    final mostPlayed = opponents.reduce((a, b) => 
        a.handsPlayed > b.handsPlayed ? a : b);
    
    final typeDistribution = <String, int>{};
    for (final opponent in opponents) {
      final type = opponent.playingStyle;
      typeDistribution[type] = (typeDistribution[type] ?? 0) + 1;
    }

    return {
      'totalOpponents': opponents.length,
      'averageHands': averageHands.round(),
      'mostPlayedAgainst': mostPlayed.name,
      'playerTypeDistribution': typeDistribution,
      'totalHandsTracked': totalHands,
    };
  }
}