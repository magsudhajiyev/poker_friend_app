import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart' show BuildContext;

import 'hand_flag_service.dart';
import 'logger_service.dart';
import 'stack_timeline.dart';

/// Reads one hand doc of a session; null when it does not exist.
typedef FlagDocFetcher = Future<Map<String, dynamic>?> Function(
    String sessionId, String handId);

/// Resolutions per flag id plus the resolved hand docs (raw maps).
class FlagLoadResult {
  final Map<String, FlagResolution> resolutions;
  final List<Map<String, dynamic>> resolvedHands;
  const FlagLoadResult(this.resolutions, this.resolvedHands);
}

/// Loads how each flagged hand of a session was settled, for the stack chart.
///
/// Reads nothing for sessions whose history has no `pending` entry (flag
/// off / older sessions).
class FlagResolutionLoader {
  FlagResolutionLoader._();

  static const _timeout = Duration(seconds: 4);

  static List<String> pendingIds(List<Map<String, dynamic>> history) => [
        for (final e in history)
          if (e['changeType'] == 'pending' && e['flagId'] != null)
            e['flagId'].toString(),
      ];

  /// Resolution per flag id. A flag whose doc is gone (and that is not a
  /// local-only stub) counts as discarded. Read failures leave it unresolved.
  static Future<Map<String, FlagResolution>> load(
    String sessionId,
    List<Map<String, dynamic>> history, {
    FlagDocFetcher? fetch,
    FlagStore? store,
  }) async =>
      (await loadAll(sessionId, history, fetch: fetch, store: store))
          .resolutions;

  /// Like [load], and also returns the resolved hand docs (promoted stubs)
  /// so the chart tooltip can show hero cards + position for them.
  static Future<FlagLoadResult> loadAll(
    String sessionId,
    List<Map<String, dynamic>> history, {
    FlagDocFetcher? fetch,
    FlagStore? store,
  }) async {
    final ids = {
      for (final e in history)
        if (e['changeType'] == 'pending' &&
            e['flagId'] != null &&
            e['discarded'] != true)
          e['flagId'].toString(),
    };
    if (ids.isEmpty) return const FlagLoadResult({}, []);
    final docs = <Map<String, dynamic>>[];
    final fetcher = fetch ?? _fetchFromFirestore;
    Set<String>? localIds;
    final out = <String, FlagResolution>{};
    for (final id in ids) {
      try {
        final doc = await fetcher(sessionId, id);
        if (doc != null) {
          out[id] = _fromDoc(doc);
          if (out[id]!.isResolved) docs.add(doc);
          continue;
        }
        localIds ??= await _localIds(sessionId, store);
        if (!localIds.contains(id)) {
          out[id] = const FlagResolution(discarded: true);
        }
      } catch (e) {
        LoggerService.log('Flag resolution read failed for $id: $e');
      }
    }
    return FlagLoadResult(out, docs);
  }

  static FlagResolution _fromDoc(Map<String, dynamic> doc) {
    final meta = doc['flag'];
    return FlagResolution.fromFlagMeta(
        meta is Map ? Map<String, dynamic>.from(meta) : null);
  }

  static Future<Set<String>> _localIds(String sessionId, FlagStore? store) async {
    final rows = await (store ?? FirebaseFlagStore()).localPending(sessionId);
    return {
      for (final r in rows)
        if (r['id'] != null) r['id'].toString(),
    };
  }

  static Future<Map<String, dynamic>?> _fetchFromFirestore(
      String sessionId, String handId) async {
    final snap = await FirebaseFirestore.instance
        .collection('poker_sessions')
        .doc(sessionId)
        .collection('poker_hands')
        .doc(handId)
        .get()
        .timeout(_timeout);
    return snap.exists ? snap.data() : null;
  }

  /// Opens the finish screen for the first of [flagIds] that is still open.
  /// Returns true when a flag was completed.
  static Future<bool> finish(
    BuildContext context,
    String sessionId,
    List<String> flagIds, {
    FlagStore? store,
  }) async {
    final open = FlagFinishLauncher.open;
    if (open == null) return false;
    final service = HandFlagService(
        store: store ?? FirebaseFlagStore(), sessionId: sessionId);
    final pending = await service.pendingFor(sessionId);
    for (final ref in pending) {
      if (flagIds.contains(ref.cloudId) || flagIds.contains(ref.localId)) {
        if (!context.mounted) return false;
        return open(context, ref);
      }
    }
    return false;
  }
}
