import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/opponent.dart';
import 'firebase_service.dart';
import 'local_storage_service.dart';
import 'opponent_stats_service.dart';
import 'app_data_cache.dart';

/// Thrown when a manual "add opponent" would collide with an existing
/// opponent of the same (normalized) name for the current user.
class DuplicateOpponentException implements Exception {
  final Opponent existing;
  DuplicateOpponentException(this.existing);
  @override
  String toString() => 'DuplicateOpponentException(${existing.name})';
}

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

  // Short-lived in-memory copy of the opponent list, used ONLY by the name
  // lookup helpers (findOpponentByName / updateLastSeen / saveOpponent's
  // duplicate pre-check). Without it, every hand completion and every seat
  // save paid several full-collection reads. getAllOpponents() stays
  // uncached so screens always see fresh data; it refreshes this copy.
  static const Duration _lookupCacheTtl = Duration(seconds: 60);
  static List<Opponent>? _lookupCache;
  static DateTime? _lookupCacheAt;
  static String? _lookupCacheUid;

  /// Drop the lookup cache (call after any external opponent mutation).
  static void invalidateLookupCache() {
    _lookupCache = null;
    _lookupCacheAt = null;
    _lookupCacheUid = null;
  }

  static void _storeLookupCache(List<Opponent> list) {
    _lookupCache = List<Opponent>.of(list);
    _lookupCacheAt = DateTime.now();
    _lookupCacheUid = _userId;
  }

  static bool get _lookupCacheValid =>
      _lookupCache != null &&
      _lookupCacheAt != null &&
      _lookupCacheUid == _userId &&
      DateTime.now().difference(_lookupCacheAt!) < _lookupCacheTtl;

  /// Opponent list for name lookups: cache when fresh, else a full load.
  static Future<List<Opponent>> _opponentsForLookup() async {
    if (_lookupCacheValid) return _lookupCache!;
    return getAllOpponents();
  }

  /// Keep a valid cache in step with a save (replace by id, else add).
  static void _patchLookupCache(Opponent saved, {String? replacedId}) {
    if (!_lookupCacheValid) return;
    _lookupCache!.removeWhere((o) => o.id == saved.id || o.id == replacedId);
    _lookupCache!.add(saved);
  }

  /// Save or update opponent in both Firebase and local storage.
  ///
  /// Names are normalized (trimmed, internal whitespace collapsed) and
  /// uniqueness is enforced **per user** two ways:
  ///  1. A pre-check reuses an existing same-name opponent.
  ///  2. New opponents are written to a **deterministic** document ID derived
  ///     from `userId + normalizedName`, so two racing saves of the same name
  ///     land on the same doc (idempotent upsert) instead of creating dups.
  ///
  /// [throwOnDuplicate] — when true (manual "Add opponent" flows), a same-name
  /// collision throws [DuplicateOpponentException] so the UI can show an error
  /// instead of silently reusing. Inline/seat flows leave it false and reuse.
  ///
  /// Returns the saved opponent (may be an existing one if duplicate detected
  /// and [throwOnDuplicate] is false).
  static Future<Opponent> saveOpponent(
    Opponent opponent, {
    bool throwOnDuplicate = false,
  }) async {
    // Normalize the display name before anything touches storage.
    opponent = opponent.copyWith(name: _normalizeName(opponent.name));

    // Duplicate check: case-insensitive name match (skip if same ID = update).
    // Offline, findOpponentByName falls back to the local list and may miss a
    // Firestore-only opponent — but the deterministic doc id below still makes
    // the eventual sync merge onto the same doc, so no duplicate is created.
    final originalId = opponent.id;
    final existing = await findOpponentByName(opponent.name);
    if (existing != null && existing.id != opponent.id) {
      if (throwOnDuplicate) {
        throw DuplicateOpponentException(existing);
      }
      return existing; // Silently return existing opponent
    }

    try {
      final newId = await _saveOpponentToFirebase(opponent);
      // If ID changed (was temp), clean up old local entry and update ID
      if (newId != opponent.id) {
        await _deleteOpponentFromLocal(opponent.id);
        opponent = opponent.copyWith(id: newId);
      }
    } catch (e) {
      debugPrint('⚠️ Firebase save failed, using local storage: $e');
    }

    await _saveOpponentToLocal(opponent);
    _patchLookupCache(opponent, replacedId: originalId);
    AppDataCache.markOpponentsDirty();
    return opponent;
  }

  /// Normalize an opponent name for storage and comparison: trim ends and
  /// collapse any internal whitespace runs to a single space. Keeps original
  /// casing for display (comparison lower-cases separately).
  static String _normalizeName(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// Deterministic per-user document ID for a new opponent. Same user + same
  /// normalized name (any casing/spacing) always maps to the same ID, so a
  /// racing double-create becomes an idempotent merge instead of a duplicate.
  static String _deterministicDocId(String userId, String name) {
    final key = '${userId}_${_normalizeName(name).toLowerCase()}';
    final digest = sha1.convert(utf8.encode(key));
    // Prefix must NOT be one that _isTempId treats as temporary, otherwise a
    // later save (rename / updateLastSeen / sync) would re-route through the
    // create branch and orphan the existing doc.
    return 'oppid_$digest';
  }

  /// Get all opponents from Firebase with fallback to local storage
  static Future<List<Opponent>> getAllOpponents() async {
    try {
      // Try Firebase first
      final firebaseOpponents = await _getOpponentsFromFirebase();
      debugPrint('📊 Loaded ${firebaseOpponents.length} opponents from Firebase');
      _storeLookupCache(firebaseOpponents);
      return firebaseOpponents;
    } catch (e) {
      debugPrint('⚠️ Firebase load failed, using local storage: $e');
      // Fallback to local storage
      final localOpponents = await _getOpponentsFromLocal();
      debugPrint('📊 Loaded ${localOpponents.length} opponents from local storage');
      // Offline fallback list is not cached: retry the cloud next time.
      invalidateLookupCache();
      return localOpponents;
    }
  }

  /// Delete opponent from both Firebase and local storage
  static Future<void> deleteOpponent(String opponentId) async {
    try {
      // Delete from Firebase
      await _deleteOpponentFromFirebase(opponentId);
      debugPrint('🗑️ Opponent deleted from Firebase: $opponentId');
    } catch (e) {
      debugPrint('⚠️ Firebase delete failed: $e');
    }
    
    // Delete from local storage
    await _deleteOpponentFromLocal(opponentId);
    invalidateLookupCache();
    AppDataCache.markOpponentsDirty();
    debugPrint('🗑️ Opponent deleted locally: $opponentId');
  }

  /// Find opponent by name (case insensitive)
  static Future<Opponent?> findOpponentByName(String name) async {
    final opponents = await _opponentsForLookup();
    try {
      return opponents.firstWhere(
        (opponent) => opponent.name.toLowerCase() == name.toLowerCase()
      );
    } catch (e) {
      return null; // Not found
    }
  }

  /// Update opponent's lastSeenAt timestamp
  static Future<void> updateLastSeen(String opponentId) async {
    final opponents = await _opponentsForLookup();
    final opponent = opponents.cast<Opponent?>().firstWhere(
      (o) => o?.id == opponentId,
      orElse: () => null,
    );

    if (opponent != null) {
      final updatedOpponent = opponent.copyWith(
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
        debugPrint('🗑️ All opponents cleared from Firebase');
      }
    } catch (e) {
      debugPrint('⚠️ Error clearing Firebase opponents: $e');
    }

    invalidateLookupCache();
    // Clear local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localOpponentsKey);
    debugPrint('🗑️ All opponents cleared from local storage');
  }

  // === Firebase Operations ===

  /// Returns the Firestore document ID (may differ from opponent.id for temp IDs).
  static Future<String> _saveOpponentToFirebase(Opponent opponent) async {
    final userId = _userId;
    if (userId == null) throw Exception('User not authenticated');

    final data = opponent.toFirestore();
    data['userId'] = userId;

    if (opponent.id.isNotEmpty && !_isTempId(opponent.id)) {
      // Update existing Firebase document
      await _opponentsCollection.doc(opponent.id).set(data, SetOptions(merge: true));
      return opponent.id;
    } else {
      // Create new opponent at a DETERMINISTIC per-user id derived from the
      // name. Using set(merge:true) instead of add() makes creation idempotent:
      // two racing saves of the same name write to the same doc rather than
      // producing duplicate auto-id documents.
      final docId = _deterministicDocId(userId, opponent.name);
      await _opponentsCollection.doc(docId).set(data, SetOptions(merge: true));
      return docId;
    }
  }

  /// Check if an ID is a temporary local ID.
  static bool _isTempId(String id) =>
      id.startsWith('local_') || id.startsWith('opp_');

  /// Sync any locally-stored opponents with temp IDs to Firestore.
  /// Call on app startup after auth is confirmed (fire-and-forget).
  static Future<void> syncTempOpponents() async {
    try {
      final locals = await _getOpponentsFromLocal();
      for (final opp in locals) {
        if (_isTempId(opp.id)) {
          await saveOpponent(opp);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Temp opponent sync failed: $e');
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

    // Load stats for all opponents from OpponentStats
    int totalHands = 0;
    String? mostPlayedName;
    int mostPlayedHands = 0;
    final typeDistribution = <String, int>{};

    for (final opponent in opponents) {
      final stats = await OpponentStatsService.getOpponentStats(opponent.id);
      if (stats != null) {
        final hands = stats.handsPlayed;
        totalHands += hands;

        if (hands > mostPlayedHands) {
          mostPlayedHands = hands;
          mostPlayedName = opponent.name;
        }

        final type = stats.playingStyle;
        typeDistribution[type] = (typeDistribution[type] ?? 0) + 1;
      }
    }

    final averageHands = opponents.isNotEmpty ? totalHands / opponents.length : 0;

    return {
      'totalOpponents': opponents.length,
      'averageHands': averageHands.round(),
      'mostPlayedAgainst': mostPlayedName,
      'playerTypeDistribution': typeDistribution,
      'totalHandsTracked': totalHands,
    };
  }

  /// DEPRECATED: This method is no longer needed.
  /// Statistics are now stored and updated incrementally in OpponentStats collection
  /// via OpponentStatsService.updateStatsIncremental() after each hand.
  @Deprecated('Use OpponentStatsService for all statistical operations')
  static Future<void> recalculateOpponentStats() async {
    debugPrint('⚠️ recalculateOpponentStats is deprecated. Stats are now managed by OpponentStatsService.');
  }

}