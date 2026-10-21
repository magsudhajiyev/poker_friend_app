import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/authored_tree.dart';
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
class AuthoredTreeService {
  AuthoredTreeService._();

  static const int maxHandsPerDay = 5;

  static final Map<String, AuthoredTree> _cache = {};

  /// The trees [dayKey] serves, in order, or null when the day has no
  /// authored schedule (or none of its trees load).
  static Future<List<AuthoredTree>?> loadDay(String dayKey) async {
    List<String>? ids;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('authored_days')
          .doc(dayKey)
          .get()
          .timeout(const Duration(seconds: 4));
      ids = handIdsFrom(doc.data());
    } catch (e) {
      LoggerService.log(
          'AuthoredTree: day $dayKey Firestore read failed, bundled: $e',
          level: LogLevel.INFO);
    }
    if (ids == null || ids.isEmpty) {
      try {
        final raw = await rootBundle.loadString('assets/authored/days.json');
        ids = bundledHandIds(
            json.decode(raw) as Map<String, dynamic>, dayKey);
      } catch (e) {
        LoggerService.log('AuthoredTree: bundled days.json unreadable: $e',
            level: LogLevel.INFO);
      }
    }
    if (ids == null || ids.isEmpty) return null;
    final trees = <AuthoredTree>[];
    for (final id in ids.take(maxHandsPerDay)) {
      final t = await load(id);
      if (t != null) trees.add(t); // a missing tree is skipped, not fatal
    }
    return trees.isEmpty ? null : trees;
  }

  /// `{hands: [...]}` → ids (pure).
  static List<String>? handIdsFrom(Map<String, dynamic>? data) {
    final hands = data?['hands'];
    if (hands is! List) return null;
    return [for (final h in hands) if (h is String && h.isNotEmpty) h];
  }

  /// Bundled schedule lookup (pure): `days[dayKey]`, else `default`.
  /// `default` is a TESTING bridge (serves a tree every day until real days
  /// are scheduled) — remove it before shipping so unscheduled days fall
  /// back to the RNG challenge.
  static List<String>? bundledHandIds(
      Map<String, dynamic> schedule, String dayKey) {
    final days = schedule['days'];
    final day = days is Map ? days[dayKey] : null;
    final list = day is List ? day : schedule['default'];
    if (list is! List) return null;
    return [for (final h in list) if (h is String && h.isNotEmpty) h];
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
        final tree = AuthoredTree.fromJson(data);
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
