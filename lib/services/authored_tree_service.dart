import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/authored_tree.dart';
import 'daily_challenge_service.dart';
import 'logger_service.dart';

/// Loads authored game trees for the Daily Challenge.
///
/// Primary source: Firestore `authored_spots/{id}` (read-only to clients,
/// uploaded out of band by `tool/gto_export/build_tree.js`). Fallback: the
/// bundled asset copy (`assets/authored/{id}.json`) — keeps the challenge
/// playable offline and before the Firestore rules for `authored_spots` are
/// deployed.
///
/// DAY SCHEDULE: which hands (tree ids, in play order, up to
/// [maxHandsPerDay]) a calendar day serves. Primary: Firestore
/// `authored_days/{yyyy-MM-dd}` = `{hands: [id, ...]}` (written by
/// `tool/gto_export/schedule_day.js`). Fallback: bundled
/// `assets/authored/days.json`. A day with no schedule returns null → the
/// Daily Challenge plays the RNG preflop drill instead.
/// Where a day's schedule came from.
enum DaySource {
  /// Firestore day doc exists.
  firestore,

  /// Firestore answered "no doc"; bundled day / rotation used.
  bundledConfirmedMissing,

  /// Firestore failed or timed out; bundled answer used. UNRANKED.
  fallbackAfterError,

  /// Confirmed no authored schedule: RNG drill day.
  rng,
}

/// Hand ids for a day plus how they were found.
class DaySchedule {
  final List<String>? hands;
  final DaySource source;
  const DaySchedule(this.hands, this.source);

  /// A run on an errored/offline read must not count against others.
  bool get ranked => source != DaySource.fallbackAfterError;
}

/// Loaded trees plus source (see [AuthoredTreeService.loadDaySchedule]).
class DayPlan {
  final List<AuthoredTree>? trees;
  final DaySource source;
  const DayPlan(this.trees, this.source);
  bool get ranked => source != DaySource.fallbackAfterError;
}

/// One Firestore day-doc read: [data] null = no doc; [fromCache] = the SDK
/// answered from its local cache (not authoritative).
class DayDocRead {
  final Map<String, dynamic>? data;
  final bool fromCache;
  const DayDocRead(this.data, {this.fromCache = false});
}

class AuthoredTreeService {
  AuthoredTreeService._();

  static const int maxHandsPerDay = 5;

  static final Map<String, AuthoredTree> _cache = {};

  /// The trees [dayKey] serves, in order, or null when the day has no
  /// authored schedule (or none of its trees load). Ranking info is dropped;
  /// use [loadDaySchedule] when it matters.
  static Future<List<AuthoredTree>?> loadDay(String dayKey) async =>
      (await loadDaySchedule(dayKey)).trees;

  /// Like [loadDay] but tells WHERE the schedule came from, so the caller can
  /// run an offline/errored read UNRANKED (see [DaySource]).
  static Future<DayPlan> loadDaySchedule(String dayKey) async {
    Map<String, dynamic>? bundled;
    try {
      final raw = await rootBundle.loadString('assets/authored/days.json');
      bundled = json.decode(raw) as Map<String, dynamic>;
    } catch (e) {
      LoggerService.log('AuthoredTree: bundled days.json unreadable: $e',
          level: LogLevel.INFO);
    }
    final schedule = await resolveSchedule(
      dayKey: dayKey,
      fetchDoc: () async {
        // Source.server: offline THROWS instead of silently serving a cached
        // "no doc", which would wrongly count as "confirmed missing" (ranked).
        final snap = await FirebaseFirestore.instance
            .collection('authored_days')
            .doc(dayKey)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 4));
        return DayDocRead(snap.data(), fromCache: snap.metadata.isFromCache);
      },
      bundled: bundled,
    );
    final trees = <AuthoredTree>[];
    for (final id in (schedule.hands ?? const <String>[])
        .take(maxHandsPerDay)) {
      final t = await load(id);
      if (t != null) trees.add(t); // a missing tree is skipped, not fatal
    }
    return DayPlan(
        trees.isEmpty ? null : trees, schedule.source);
  }

  /// Pure source classification. [fetchDoc] returns the Firestore day doc
  /// (data null = server answered, no doc) or throws/times out. A read that
  /// reports [DayDocRead.fromCache] is not a server answer → treated as an
  /// error (unranked).
  static Future<DaySchedule> resolveSchedule({
    required String dayKey,
    required Future<DayDocRead> Function() fetchDoc,
    required Map<String, dynamic>? bundled,
  }) async {
    var failed = false;
    try {
      final read = await fetchDoc();
      if (read.fromCache) throw StateError('day doc served from cache');
      final ids = handIdsFrom(read.data);
      if (ids != null && ids.isNotEmpty) {
        return DaySchedule(ids, DaySource.firestore);
      }
    } catch (e) {
      failed = true;
      LoggerService.log(
          'AuthoredTree: day $dayKey Firestore read failed, bundled: $e',
          level: LogLevel.INFO);
    }
    final ids = bundled == null ? null : bundledHandIds(bundled, dayKey);
    final has = ids != null && ids.isNotEmpty;
    if (failed) {
      return DaySchedule(has ? ids : null, DaySource.fallbackAfterError);
    }
    return has
        ? DaySchedule(ids, DaySource.bundledConfirmedMissing)
        : const DaySchedule(null, DaySource.rng);
  }

  /// `{hands: [...]}` → ids (pure).
  static List<String>? handIdsFrom(Map<String, dynamic>? data) {
    final hands = data?['hands'];
    if (hands is! List) return null;
    return [for (final h in hands) if (h is String && h.isNotEmpty) h];
  }

  /// Bundled schedule lookup (pure): explicit `days[dayKey]` wins, else a
  /// deterministic [rotationPick] over `rotation`, else null (RNG day).
  static List<String>? bundledHandIds(
      Map<String, dynamic> schedule, String dayKey) {
    final days = schedule['days'];
    final day = days is Map ? days[dayKey] : null;
    final rotation = schedule['rotation'];
    final list = day is List
        ? day
        : rotation is List
            ? rotationPick(dayKey, [
                for (final h in rotation)
                  if (h is String && h.isNotEmpty) h
              ])
            : null;
    if (list == null) return null;
    return [for (final h in list) if (h is String && h.isNotEmpty) h];
  }

  /// Deterministic rotation (pure): up to [maxHandsPerDay] consecutive ids
  /// starting at `challengeNumber mod len`, wrapping. Same for every user.
  static List<String> rotationPick(String dayKey, List<String> rotation) {
    final date = DateTime.tryParse(dayKey);
    if (date == null || rotation.isEmpty) return const [];
    final n = DailyChallengeService.challengeNumber(date);
    final start = n % rotation.length;
    final count = rotation.length < maxHandsPerDay
        ? rotation.length
        : maxHandsPerDay;
    return [for (var i = 0; i < count; i++) rotation[(start + i) % rotation.length]];
  }

  static Future<AuthoredTree?> load(String id) async {
    final cached = _cache[id];
    if (cached != null) return cached;

    // 1) Firestore (short timeout — never hold the Play button hostage).
    try {
      final doc = await FirebaseFirestore.instance
          .collection('authored_spots')
          .doc(id)
          .get()
          .timeout(const Duration(seconds: 4));
      final data = doc.data();
      if (data != null) {
        // Large trees are stored as a single `treeJson` string (Firestore
        // auto-indexes map entries and a big inline tree exceeds the 20k
        // index-entries/doc limit). Parse that when present; otherwise the doc
        // is the inline tree shape (small spots, older uploads).
        final raw = data['treeJson'];
        final map = raw is String
            ? json.decode(raw) as Map<String, dynamic>
            : data;
        final tree = AuthoredTree.fromJson(map);
        _cache[id] = tree;
        return tree;
      }
    } catch (e) {
      LoggerService.log(
          'AuthoredTree: Firestore load failed for $id, asset fallback: $e',
          level: LogLevel.INFO);
    }

    // 2) Bundled asset fallback.
    try {
      final raw = await rootBundle.loadString('assets/authored/$id.json');
      final tree =
          AuthoredTree.fromJson(json.decode(raw) as Map<String, dynamic>);
      _cache[id] = tree;
      return tree;
    } catch (e) {
      LoggerService.log('AuthoredTree: asset load failed for $id: $e',
          level: LogLevel.ERROR);
      return null;
    }
  }
}
