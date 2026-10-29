import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'coach_level_resolver.dart';
import '../utils/coach_text.dart';
import 'daily_challenge_service.dart';

/// Reads the persona-driven AI coach lines for the Daily Challenge.
///
/// Lines are generated OUT OF BAND (a maintainer runs the batch tool
/// `tool/gto_export/generate_feedback.mjs` with the Claude API and writes
/// `daily_challenge_lines/{dayKey}`) — the app only READS them here. On a
/// miss the caller uses its built-in persona template reason, so the feature
/// never depends on generation being present.
///
/// TWO document shapes are supported, newest first:
///
/// 1. PER-ACTION (authored + RNG, current):
///      hands[spotKey][coachKey][actionWire] = [variant, variant]
///    where `spotKey` is the authored spot id (e.g. "bb-hj-8h5h3c-33") or
///    "rng:{index}" for an RNG day, `coachKey` is grinder|professor|nova and
///    `actionWire` is fold|check|call|raise|allin. Keyed on the action the
///    user ACTUALLY took, so the feedback matches the verdict for that action.
///    Every user of the day shares these variants; the client picks one
///    deterministically per user+day (so two users split across the two
///    variants, stable all day) and prepends a short per-coach session opener.
///
/// 2. PER-SPOT-INDEX (legacy RNG):
///      lines[spotIndex][coachId][level] = [variant, variant]
///    Kept so already-generated days keep working.
class DailyCoachLinesService {
  DailyCoachLinesService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final Random _rng = Random();

  /// One day's lines are cached in memory after the first read so every
  /// spot of the run does not re-fetch the same doc.
  /// Keyed by the REQUESTED day (not just today), so a replay of day A and
  /// today's run never see each other's doc. Only successful reads are cached.
  static final Map<String, Map<String, dynamic>> _cache = {};

  /// In-flight reads per day, so concurrent lookups share ONE Firestore read.
  /// An entry is dropped as soon as the read settles (value, null or error).
  static final Map<String, Future<Map<String, dynamic>?>> _inFlight = {};

  /// Negative cache: when a day had no lines doc, remember the miss for
  /// [missTtl] so every coach decision does not re-hit Firestore, while a doc
  /// generated later in the day is still picked up. Value = miss timestamp.
  static final Map<String, DateTime> _missedAt = {};

  /// How long a missing doc is remembered.
  static const Duration missTtl = Duration(seconds: 60);

  /// Test seam: replaces the Firestore read. Null in production.
  @visibleForTesting
  static Future<Map<String, dynamic>?> Function(String dayKey)? debugFetcher;

  /// Test seam: replaces the clock used for the negative-cache TTL.
  @visibleForTesting
  static DateTime Function()? debugNow;

  /// Test seam: clears the in-memory caches.
  @visibleForTesting
  static void debugResetCache() {
    _cache.clear();
    _inFlight.clear();
    _missedAt.clear();
  }

  /// Per-NODE, per-action, per-level lookup (shape 1). Navigates
  /// `hands[spotKey][nodeId][action][coachKey][level.id]`.
  ///
  /// [spotKey] is the authored spot id (or "rng:{index}"); [nodeId] is the
  /// tree node the hero just acted on (so a repeated action across streets
  /// never collides — see the 2026-10-28 overwrite bug); [action] is the wire
  /// string (fold/check/call/raise/allin); [coachKey] is the stored coach key
  /// (grinder/professor/nova); [level] is the player's experience tier.
  /// [spotNumber] (1-based) and [streak] feed the Nova session opener.
  ///
  /// [uid] drives a DETERMINISTIC per-user-per-day variant pick: the same user
  /// sees the same variant all day for a given decision, different users split
  /// across the two variants, and it reshuffles tomorrow (and stays stable on
  /// a replayed past day, because the hash keys on that day's [dayKeyOverride]).
  /// When [uid] is null/empty the pick falls back to random.
  ///
  /// Returns null when not generated yet — the caller then uses its template.
  static Future<String?> lineForAction({
    required String spotKey,
    required String nodeId,
    required String coachKey,
    required String action,
    required CoachLevel level,
    String? uid,
    int? spotNumber,
    int? streak,
    String? dayKeyOverride,
  }) async {
    try {
      final dayKey = dayKeyOverride ?? _todayKey();
      final data = await _dayData(dayKey);
      if (data == null) return null;

      final hands = data['hands'];
      if (hands is! Map) return null;
      final spot = hands[spotKey];
      if (spot is! Map) return null;
      final node = spot[nodeId];
      if (node is! Map) return null;
      final act = node[action];
      if (act is! Map) return null;
      final coach = act[coachKey];
      if (coach is! Map) return null;

      // Deterministic per-user-per-day pick, keyed on the FULL decision address
      // (uid, day, spot, node, action, level); random only when we have no uid.
      final variant = _pickVariantFor(
        coach[level.id],
        seed: (uid == null || uid.isEmpty)
            ? null
            : '$uid|$dayKey|$spotKey|$nodeId|$action|${level.id}',
      );
      if (variant == null) return null;

      final opener = _sessionOpener(coachKey, spotNumber, streak);
      return joinSentences([opener, normalizeCoachText(variant)]);
    } catch (_) {
      return null;
    }
  }

  /// Legacy per-spot-index lookup (shape 2). Kept for already-generated RNG
  /// days. Returns null when absent so the caller falls back to a template.
  static Future<String?> lineFor({
    required int spotIndex,
    required String coachId,
    required CoachLevel level,
  }) async {
    try {
      final data = await _dayData(_todayKey());
      if (data == null) return null;

      final lines = data['lines'];
      if (lines is! List || spotIndex >= lines.length) return null;
      final spot = lines[spotIndex];
      if (spot is! Map) return null;
      final coach = spot[coachId];
      if (coach is! Map) return null;
      return _pickVariant(coach[level.id]);
    } catch (_) {
      return null;
    }
  }

  /// Accept both the new list-of-variants shape and the legacy single string.
  /// When [seed] is non-null the variant is chosen deterministically from it
  /// (stable per user+day+spot+action); otherwise a random variant is picked.
  static String? _pickVariantFor(dynamic value, {String? seed}) {
    if (value is List) {
      final variants = value
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (variants.isEmpty) return null;
      final idx = seed == null
          ? _rng.nextInt(variants.length)
          : pickVariantIndex(seed, variants.length);
      return variants[idx];
    }
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  /// Legacy variant picker (always random) — used by the per-spot-index
  /// [lineFor] path. Kept separate so the authored per-action path's
  /// deterministic pick doesn't change legacy RNG-day behaviour.
  static String? _pickVariant(dynamic value) => _pickVariantFor(value);

  /// Pure, testable: a stable non-negative hash of [s] (FNV-1a, 32-bit).
  /// Unlike [String.hashCode] this is identical across runs, isolates and
  /// platforms — required so a user sees the same variant on every device.
  static int stableHash(String s) {
    // FNV-1a 32-bit. Mask to 32 bits after each step to stay in JS-safe range.
    var hash = 0x811c9dc5;
    for (var i = 0; i < s.length; i++) {
      hash ^= s.codeUnitAt(i) & 0xff;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }

  /// Pure, testable: which variant index [seed] maps to among [count] variants.
  static int pickVariantIndex(String seed, int count) {
    if (count <= 1) return 0;
    return stableHash(seed) % count;
  }

  /// A short, client-side session opener prepended to the AI line so the
  /// coach acknowledges the day's progress WITHOUT the LLM having to know it
  /// (the batch job is user-agnostic). Deterministic per (coach, spot, streak)
  /// so a given run reads consistently. Only coaches whose persona references
  /// progress (Nova) get one; the measured coaches (Duke, Vega) stay silent.
  static String? _sessionOpener(String coachKey, int? spotNumber, int? streak) {
    if (spotNumber == null || spotNumber < 1) return null;
    if (coachKey != 'nova') return null; // only Nova references momentum

    // A tiny per-position bank; pick by spot number so it rotates across the
    // five spots without repeating within a day.
    const banks = <String>[
      "Here we go.",
      "Two down.",
      "Three for three — stay sharp.",
      "Spot four, locked in.",
      "Last one, finish strong.",
    ];
    final idx = (spotNumber - 1).clamp(0, banks.length - 1);
    return banks[idx];
  }

  static Future<Map<String, dynamic>?> _dayData(String dayKey) {
    final hit = _cache[dayKey];
    if (hit != null) return Future.value(hit);
    final missed = _missedAt[dayKey];
    if (missed != null) {
      if (_now().difference(missed) < missTtl) return Future.value(null);
      _missedAt.remove(dayKey);
    }
    return _inFlight[dayKey] ??= _load(dayKey);
  }

  static Future<Map<String, dynamic>?> _load(String dayKey) async {
    try {
      final fetch = debugFetcher;
      final data = fetch != null
          ? await fetch(dayKey)
          : (await _db.collection('daily_challenge_lines').doc(dayKey).get())
              .data();
      if (data != null) {
        _cache[dayKey] = data;
      } else {
        _missedAt[dayKey] = _now();
      }
      return data;
    } finally {
      _inFlight.remove(dayKey);
    }
  }

  static DateTime _now() => (debugNow ?? DateTime.now)();

  static String _todayKey() => _dayKey(
      DailyChallengeService.configFor(DailyChallengeService.today()).day);

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
