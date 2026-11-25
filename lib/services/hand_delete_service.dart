import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/single_hand_group.dart';
import '../models/tracked_session.dart';
import 'app_data_cache.dart';
import 'firebase_service.dart';
import 'local_storage_service.dart';
import 'logger_service.dart';

/// Storage side of a hand delete. A fake replaces it in tests.
abstract class HandDeleteBackend {
  /// The session doc (Firestore, else SQLite) or null when unknown.
  Future<Map<String, dynamic>?> loadSession(String sessionId);

  /// Removes the hand from both stores and lowers the session counters.
  /// [touchEndTime]: hand groups move `endTime` to the latest remaining hand.
  Future<void> deleteHand({
    required String sessionId,
    required String? handId,
    required int? handNumber,
    required bool touchEndTime,
  });
}

/// Deleting a logged hand from its details screen.
///
/// Only hands that NEVER touched stats can go: hand-group hands and
/// tracked-session hands ([skipsHandStats]). A hand of a full logging session
/// fed user/opponent stats, the range grid and the Leak Detector, and the app
/// has no stats rollback, so it is not deletable. Deleting works while the
/// session runs.
class HandDeleteService {
  HandDeleteService._();

  @visibleForTesting
  static HandDeleteBackend backend = FirebaseHandDeleteBackend();

  /// Bumped after every delete: list screens that cannot rely on a `pop`
  /// result (e.g. a tracked-session hub) listen to this and reload.
  static final ValueNotifier<int> deletions = ValueNotifier(0);

  /// Pure rule: [session] is a hand group or a tracked session.
  static bool isDeletableSession(Map<String, dynamic>? session) =>
      session != null && skipsHandStats(session);

  static Future<bool> canDelete(String? sessionId) async {
    if (sessionId == null || sessionId.isEmpty) return false;
    try {
      return isDeletableSession(await backend.loadSession(sessionId));
    } catch (_) {
      return false;
    }
  }

  /// Throws [StateError] for a hand of a full session (never offered, this is
  /// the second guard) and [Exception]s from storage as they come.
  static Future<void> delete({
    required String sessionId,
    String? handId,
    int? handNumber,
  }) async {
    final session = await backend.loadSession(sessionId);
    if (!isDeletableSession(session)) {
      throw StateError('Hand cannot be deleted: it counted for stats');
    }
    await backend.deleteHand(
      sessionId: sessionId,
      handId: handId,
      handNumber: handNumber,
      touchEndTime: isHandGroupSession(session!),
    );
    AppDataCache.markSessionsDirty();
    AppDataCache.markHomeDirty();
    FirebaseService.invalidateSessionsCache();
    deletions.value++;
  }
}

class FirebaseHandDeleteBackend implements HandDeleteBackend {
  static const Duration _cloudWait = Duration(seconds: 4);

  @override
  Future<Map<String, dynamic>?> loadSession(String sessionId) async {
    final cloud = await FirebaseService.getSession(sessionId);
    return cloud ?? await LocalStorageService.getSession(sessionId);
  }

  @override
  Future<void> deleteHand({
    required String sessionId,
    required String? handId,
    required int? handNumber,
    required bool touchEndTime,
  }) async {
    final local = await LocalStorageService.deleteHandCounted(
      sessionId: sessionId,
      handId: handId,
      handNumber: handNumber,
      touchEndTime: touchEndTime,
    );
    var cloud = false;
    try {
      cloud = await _deleteCloud(sessionId, handId, handNumber, touchEndTime)
          .timeout(_cloudWait);
    } on TimeoutException {
      cloud = true; // queued offline: Firestore applies it when back online
      await LoggerService.info('Hand delete: cloud write queued (offline?)');
    } catch (e) {
      await LoggerService.error(
          'Hand delete: cloud delete failed', e, StackTrace.current);
    }
    if (!local && !cloud) throw StateError('Hand to delete was not found');
  }

  Future<bool> _deleteCloud(String sessionId, String? handId,
      int? handNumber, bool touchEndTime) async {
    final db = FirebaseFirestore.instance;
    final session = db.collection('poker_sessions').doc(sessionId);
    final hands = session.collection('poker_hands');
    DocumentSnapshot<Map<String, dynamic>>? target;
    if (handId != null) {
      final d = await hands.doc(handId).get();
      if (d.exists) target = d;
    }
    if (target == null && handNumber != null) {
      final q = await hands
          .where('handNumber', isEqualTo: handNumber)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) target = q.docs.first;
    }
    if (target == null) return false;
    final sessionDoc = await session.get();
    final batch = db.batch()..delete(target.reference);
    final counters = <String, Object?>{
      'totalHands': FieldValue.increment(-1),
      if (sessionDoc.data()?.containsKey('handsLogged') == true)
        'handsLogged': FieldValue.increment(-1),
    };
    batch.update(session, counters);
    await batch.commit();
    if (touchEndTime) await _moveEndTime(session, hands);
    return true;
  }

  /// Hand group: `endTime` follows the latest remaining hand.
  Future<void> _moveEndTime(DocumentReference<Map<String, dynamic>> session,
      CollectionReference<Map<String, dynamic>> hands) async {
    try {
      final last =
          await hands.orderBy('startTime', descending: true).limit(1).get();
      if (last.docs.isEmpty) return;
      final d = last.docs.first.data();
      final t = d['endTime'] ?? d['startTime'];
      if (t != null) await session.update({'endTime': t});
    } catch (e) {
      await LoggerService.warning('Hand delete: endTime update failed: $e');
    }
  }
}
