import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;

import '../models/flag_table_snapshot.dart';
import '../models/hand_completeness.dart';
import '../models/hand_state_machine.dart';
import 'app_data_cache.dart';
import 'local_storage_service.dart';
import 'logger_service.dart';

/// Tags a flag can carry (the sheet shows the first six; `played` is a legacy
/// tag from removed pocket-mode flags). A flag holds at most [kMaxFlagTags].
const List<String> kFlagTags = [
  'cooler',
  'bluff',
  'hero_call',
  'big_pot',
  'mistake',
  'review',
];
const String kPlayedTag = 'played';
const int kMaxFlagTags = 3;

/// A flagged stub waiting to be finished.
///
/// The finish screen takes this object and
/// pre-fills time, blinds, positions, stacks and cards from it. Promote via
/// `HandPromotionService.promote(sessionId: ref.sessionId,
/// cloudHandId: ref.cloudId!, localHandId: ref.localId, …)`.
class FlaggedHandRef {
  final String sessionId;

  /// Firestore doc id (null when only the local mirror exists).
  final String? cloudId;

  /// SQLite row id (null when only the cloud doc exists).
  final String? localId;
  final int handNumber;
  final DateTime? flaggedAt;
  final String? heroPositionName;
  final List<String> tags;
  final double? heroStackBB;
  final double? stackDeltaBB;

  /// `ourHoleCards` map (`card1`/`card2`) or null.
  final Map<String, dynamic>? heroCards;

  /// Stub meta as stored: blinds, stacks, gameType, source, …
  final Map<String, dynamic> flagMeta;
  final DateTime? startTime;

  /// The table when the hand was flagged (null for older stubs).
  FlagTableSnapshot? get table => FlagTableSnapshot.fromMap(flagMeta['table']);

  const FlaggedHandRef({
    required this.sessionId,
    required this.handNumber,
    this.cloudId,
    this.localId,
    this.flaggedAt,
    this.heroPositionName,
    this.tags = const [],
    this.heroStackBB,
    this.stackDeltaBB,
    this.heroCards,
    this.flagMeta = const {},
    this.startTime,
  });

  /// Builds a ref from a stored stub map (cloud doc or decoded SQLite row).
  factory FlaggedHandRef.fromMap(
    String sessionId,
    Map<String, dynamic> m, {
    String? cloudId,
    String? localId,
  }) {
    final meta = m['flag'] is Map
        ? Map<String, dynamic>.from(m['flag'] as Map)
        : <String, dynamic>{};
    final cards = m['ourHoleCards'];
    return FlaggedHandRef(
      sessionId: sessionId,
      cloudId: cloudId,
      localId: localId,
      handNumber: (m['handNumber'] as num?)?.toInt() ?? 0,
      flaggedAt: _date(meta['flaggedAt']),
      startTime: _date(m['startTime']),
      heroPositionName: m['heroPositionName'] as String?,
      tags: ((meta['tags'] as List?) ?? const []).whereType<String>().toList(),
      heroStackBB: (meta['heroStackBB'] as num?)?.toDouble(),
      stackDeltaBB: (meta['stackDeltaBB'] as num?)?.toDouble(),
      heroCards: cards is Map ? Map<String, dynamic>.from(cards) : null,
      flagMeta: meta,
    );
  }

  /// Ref for a record that was just saved by `PokerSessionManager.recordFlag`.
  factory FlaggedHandRef.fromRecord(String sessionId, HandRecord r) {
    return FlaggedHandRef.fromMap(
      sessionId,
      {
        'handNumber': r.handNumber,
        'flag': r.flagMeta,
        'startTime': r.startTime.toIso8601String(),
        'heroPositionName': r.heroPositionName,
        'ourHoleCards': r.ourHoleCards?.toMap(),
      },
      cloudId: r.cloudHandId,
      localId: r.localHandId,
    );
  }

  static DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;
}

/// Storage seam for flags (Firestore + SQLite in production, fake in tests).
abstract class FlagStore {
  /// Flagged stubs from the cloud, each map carries its doc id under `id`.
  Future<List<Map<String, dynamic>>> cloudPending(String sessionId);

  /// Flagged stubs from SQLite (decoded), each map carries its row id.
  Future<List<Map<String, dynamic>>> localPending(String sessionId);

  /// Deletes the cloud stub. Refuses (returns false) when the doc is no
  /// longer a not-yet-counted stub, so a promoted hand can never be deleted.
  Future<bool> deleteCloud(String sessionId, String id);

  Future<void> deleteLocal(String id);
}

class FirebaseFlagStore implements FlagStore {
  static const _timeout = Duration(seconds: 4);

  CollectionReference<Map<String, dynamic>> _hands(String sessionId) =>
      FirebaseFirestore.instance
          .collection('poker_sessions')
          .doc(sessionId)
          .collection('poker_hands');

  @override
  Future<List<Map<String, dynamic>>> cloudPending(String sessionId) async {
    final snap = await _hands(sessionId)
        .where('completeness', isEqualTo: HandCompleteness.flagged.wire)
        .get()
        .timeout(_timeout);
    return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> localPending(String sessionId) async {
    final rows = await LocalStorageService.getPendingFlags(sessionId);
    return rows;
  }

  @override
  Future<bool> deleteCloud(String sessionId, String id) {
    final ref = _hands(sessionId).doc(id);
    return FirebaseFirestore.instance.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (!snap.exists || data == null) return true; // already gone
      final stillStub = HandCompletenessX.parse(data['completeness']) ==
              HandCompleteness.flagged &&
          data['statsApplied'] != true;
      if (!stillStub) return false;
      tx.delete(ref);
      return true;
    });
  }

  @override
  Future<void> deleteLocal(String id) async {
    final db = await LocalStorageService.database;
    await db.delete(
      'hands',
      where: "id = ? AND completeness = 'flagged'",
      whereArgs: [id],
    );
  }
}

/// Records one flagged stub; production binding is
/// [PokerSessionManager.recordFlag].
typedef FlagRecorder = Future<HandRecord?> Function({
  required List<String> tags,
  required String source,
  HoleCards? heroCards,
  double? stackDeltaBB,
});

/// Flag-now, finish-later: create, list and discard stubs.
///
/// Creating or discarding a flag NEVER touches user or opponent stats; the
/// stats are applied exactly once, at promotion (`HandPromotionService`).
class HandFlagService {
  final FlagStore store;
  final FlagRecorder? _record;
  final String? sessionId;
  final VoidCallback? _onResolved;
  final void Function(String? flagId)? _onDiscarded;

  HandFlagService({
    required this.store,
    FlagRecorder? recorder,
    this.sessionId,
    VoidCallback? onResolved,
    void Function(String? flagId)? onDiscarded,
  })  : _record = recorder,
        _onResolved = onResolved,
        _onDiscarded = onDiscarded;

  /// Production service bound to a live session.
  factory HandFlagService.forSession(PokerSessionManager sm, {FlagStore? store}) {
    return HandFlagService(
      store: store ?? FirebaseFlagStore(),
      sessionId: sm.sessionId,
      onResolved: sm.flagResolved,
      onDiscarded: (id) => sm.markFlagDiscarded(id),
      recorder: ({required tags, required source, heroCards, stackDeltaBB}) =>
          sm.recordFlag(
        tags: tags,
        source: source,
        heroCards: heroCards,
        stackDeltaBB: stackDeltaBB,
      ),
    );
  }

  /// Pure: tag list after tapping [tag]. Removes it when selected, adds it
  /// when there is room, otherwise returns [current] unchanged.
  static List<String> toggleTag(List<String> current, String tag) {
    if (current.contains(tag)) return current.where((t) => t != tag).toList();
    if (current.length >= kMaxFlagTags) return current;
    return [...current, tag];
  }

  /// Pure: known tags only, no duplicates, at most [kMaxFlagTags].
  static List<String> sanitizeTags(Iterable<String> tags) {
    final ok = <String>[];
    for (final t in tags) {
      final known = kFlagTags.contains(t) || t == kPlayedTag;
      if (known && !ok.contains(t) && ok.length < kMaxFlagTags) ok.add(t);
    }
    return ok;
  }

  /// Saves a flagged stub. Returns null when it could not be recorded.
  Future<FlaggedHandRef?> createStub({
    List<String> tags = const [],
    HoleCards? heroCards,
    String source = 'flag',
    double? stackDeltaBB,
  }) async {
    final record = _record;
    final sid = sessionId;
    if (record == null || sid == null) return null;
    try {
      final r = await record(
        tags: sanitizeTags(tags),
        source: source,
        heroCards: heroCards,
        stackDeltaBB: stackDeltaBB,
      );
      return r == null ? null : FlaggedHandRef.fromRecord(sid, r);
    } catch (e, st) {
      await LoggerService.error('Flag stub failed', e, st);
      return null;
    }
  }

  /// Open flags of [sid]: cloud list merged with the SQLite mirror by hand
  /// number. Falls back to SQLite alone when the cloud read fails. Oldest
  /// first.
  Future<List<FlaggedHandRef>> pendingFor(String sid) async {
    List<Map<String, dynamic>> cloud = const [];
    try {
      cloud = await store.cloudPending(sid);
    } catch (e) {
      unawaited(LoggerService.log(
          'HandFlagService: cloud pending read failed, using local: $e'));
    }
    List<Map<String, dynamic>> local = const [];
    try {
      local = await store.localPending(sid);
    } catch (_) {}
    return mergePending(sid, cloud, local);
  }

  /// Pure merge, exposed for tests.
  @visibleForTesting
  static List<FlaggedHandRef> mergePending(
    String sid,
    List<Map<String, dynamic>> cloud,
    List<Map<String, dynamic>> local,
  ) {
    final localByNumber = {
      for (final m in local) (m['handNumber'] as num?)?.toInt(): m,
    };
    final out = <FlaggedHandRef>[];
    final seen = <int?>{};
    for (final c in cloud) {
      final n = (c['handNumber'] as num?)?.toInt();
      seen.add(n);
      out.add(FlaggedHandRef.fromMap(sid, c,
          cloudId: c['id'] as String?,
          localId: localByNumber[n]?['id'] as String?));
    }
    for (final l in local) {
      final n = (l['handNumber'] as num?)?.toInt();
      if (seen.contains(n)) continue;
      out.add(FlaggedHandRef.fromMap(sid, l, localId: l['id'] as String?));
    }
    out.sort((a, b) => a.handNumber.compareTo(b.handNumber));
    return out;
  }

  /// Deletes a stub. No stats change: none were applied. Returns false when
  /// the cloud doc was already counted (nothing is deleted then).
  Future<bool> discard(FlaggedHandRef ref) async {
    try {
      final cloudId = ref.cloudId;
      if (cloudId != null) {
        final ok = await store.deleteCloud(ref.sessionId, cloudId);
        if (!ok) return false;
      }
      final localId = ref.localId;
      if (localId != null) await store.deleteLocal(localId);
      _onDiscarded?.call(cloudId ?? localId);
      _onResolved?.call();
      AppDataCache.markSessionsDirty();
      return true;
    } catch (e, st) {
      await LoggerService.error('Flag discard failed', e, st);
      return false;
    }
  }
}

/// Hook that opens the "finish this flag" screen (registered once
/// at app start by the owner of that screen; until then Finish only logs).
class FlagFinishLauncher {
  FlagFinishLauncher._();

  /// Returns true when the flag was completed (promoted).
  static Future<bool> Function(BuildContext context, FlaggedHandRef ref)? open;
}
