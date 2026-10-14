import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'leak_engine.dart';

/// Persisted snapshot of one leak-report run, used to show what changed
/// since the player's last visit (deltas, unlocks, status flips).
///
/// Deliberately tiny — per detector we keep only what the diff needs
/// (value, sample count, verdict). The full report is always recomputed
/// from raw hands (read-time aggregation rule); this is just memory of
/// the previous verdicts.
class LeakSnapshotEntry {
  final String id;
  final String title;
  final double value;
  final int sampleCount;
  final LeakVerdict verdict;
  final double bandLow;
  final double bandHigh;

  const LeakSnapshotEntry({
    required this.id,
    required this.title,
    required this.value,
    required this.sampleCount,
    required this.verdict,
    required this.bandLow,
    required this.bandHigh,
  });

  bool get isLeak =>
      verdict == LeakVerdict.emerging || verdict == LeakVerdict.confirmed;

  /// Distance outside the healthy band (0 when inside it).
  double get bandDistance =>
      value < bandLow ? bandLow - value : (value > bandHigh ? value - bandHigh : 0);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'value': value,
        'n': sampleCount,
        'verdict': verdict.name,
        'low': bandLow,
        'high': bandHigh,
      };

  static LeakSnapshotEntry? fromJson(dynamic json) {
    if (json is! Map) return null;
    final verdict = LeakVerdict.values
        .where((v) => v.name == json['verdict'])
        .firstOrNull;
    final id = json['id'];
    final value = json['value'];
    if (verdict == null || id is! String || value is! num) return null;
    return LeakSnapshotEntry(
      id: id,
      title: json['title'] as String? ?? id,
      value: value.toDouble(),
      sampleCount: (json['n'] as num?)?.toInt() ?? 0,
      verdict: verdict,
      bandLow: (json['low'] as num?)?.toDouble() ?? 0,
      bandHigh: (json['high'] as num?)?.toDouble() ?? 1,
    );
  }
}

class LeakSnapshot {
  final DateTime takenAt;
  final int handsAnalyzed;

  /// Top-level detectors only (no `parent@slice` children — slice verdicts
  /// come and go with small n and would make the diff noisy).
  final Map<String, LeakSnapshotEntry> entries;

  const LeakSnapshot({
    required this.takenAt,
    required this.handsAnalyzed,
    required this.entries,
  });

  factory LeakSnapshot.fromReport(LeakReport report, DateTime takenAt) {
    final entries = <String, LeakSnapshotEntry>{};
    for (final f in report.findings) {
      if (f.id.contains('@')) continue; // slice children excluded
      entries[f.id] = LeakSnapshotEntry(
        id: f.id,
        title: f.title,
        value: f.value,
        sampleCount: f.sampleCount,
        verdict: f.verdict,
        bandLow: f.bandLow,
        bandHigh: f.bandHigh,
      );
    }
    return LeakSnapshot(
        takenAt: takenAt, handsAnalyzed: report.handsAnalyzed, entries: entries);
  }

  Map<String, dynamic> toJson() => {
        'takenAt': takenAt.toIso8601String(),
        'hands': handsAnalyzed,
        'entries': [for (final e in entries.values) e.toJson()],
      };

  static LeakSnapshot? fromJson(dynamic json) {
    if (json is! Map) return null;
    final takenAt = DateTime.tryParse(json['takenAt'] as String? ?? '');
    if (takenAt == null) return null;
    final entries = <String, LeakSnapshotEntry>{};
    for (final raw in (json['entries'] as List? ?? const [])) {
      final e = LeakSnapshotEntry.fromJson(raw);
      if (e != null) entries[e.id] = e;
    }
    return LeakSnapshot(
      takenAt: takenAt,
      handsAnalyzed: (json['hands'] as num?)?.toInt() ?? 0,
      entries: entries,
    );
  }
}

/// What happened to one detector between two visits.
enum LeakChangeKind {
  /// insufficient → got a verdict (any) — a detector came online.
  unlocked,

  /// leak → healthy. The best news on the screen.
  becameHealthy,

  /// healthy → leak.
  becameLeak,

  /// Still a leak, but measurably closer to the band.
  improved,

  /// Still a leak and measurably further from the band.
  worsened,
}

class LeakChange {
  final String id;
  final String title;
  final LeakChangeKind kind;
  final double? previousValue;
  final double currentValue;

  const LeakChange({
    required this.id,
    required this.title,
    required this.kind,
    required this.currentValue,
    this.previousValue,
  });

  bool get isPositive =>
      kind == LeakChangeKind.unlocked ||
      kind == LeakChangeKind.becameHealthy ||
      kind == LeakChangeKind.improved;
}

/// Diff between the previous visit's snapshot and the fresh report.
class LeakSnapshotDiff {
  final DateTime previousAt;
  final int handsDelta;
  final List<LeakChange> changes;
  final Map<String, LeakSnapshotEntry> _previousEntries;

  const LeakSnapshotDiff({
    required this.previousAt,
    required this.handsDelta,
    required this.changes,
    required Map<String, LeakSnapshotEntry> previousEntries,
  }) : _previousEntries = previousEntries;

  /// Previous entry for a detector (null when it wasn't tracked last time).
  LeakSnapshotEntry? previousOf(String id) => _previousEntries[id];

  bool get hasNews => changes.isNotEmpty || handsDelta > 0;

  /// Movement below this (in frequency points) is treated as noise.
  static const double _minMove = 0.02;

  static LeakSnapshotDiff compute(LeakSnapshot previous, LeakSnapshot current) {
    final changes = <LeakChange>[];

    for (final cur in current.entries.values) {
      final prev = previous.entries[cur.id];
      if (prev == null) continue;

      final prevHasVerdict = prev.verdict != LeakVerdict.insufficientData;
      final curHasVerdict = cur.verdict != LeakVerdict.insufficientData;

      LeakChangeKind? kind;
      if (!prevHasVerdict && curHasVerdict) {
        kind = LeakChangeKind.unlocked;
      } else if (prevHasVerdict && curHasVerdict) {
        if (prev.isLeak && !cur.isLeak) {
          kind = LeakChangeKind.becameHealthy;
        } else if (!prev.isLeak && cur.isLeak) {
          kind = LeakChangeKind.becameLeak;
        } else if (cur.isLeak) {
          final moved = prev.bandDistance - cur.bandDistance;
          if (moved >= _minMove) kind = LeakChangeKind.improved;
          if (moved <= -_minMove) kind = LeakChangeKind.worsened;
        }
      }

      if (kind != null) {
        changes.add(LeakChange(
          id: cur.id,
          title: cur.title,
          kind: kind,
          currentValue: cur.value,
          previousValue: prev.value,
        ));
      }
    }

    // Best news first: healthy flips, unlocks, improvements, then the bad.
    const order = [
      LeakChangeKind.becameHealthy,
      LeakChangeKind.unlocked,
      LeakChangeKind.improved,
      LeakChangeKind.becameLeak,
      LeakChangeKind.worsened,
    ];
    changes.sort(
        (a, b) => order.indexOf(a.kind).compareTo(order.indexOf(b.kind)));

    return LeakSnapshotDiff(
      previousAt: previous.takenAt,
      handsDelta: current.handsAnalyzed - previous.handsAnalyzed,
      changes: changes,
      previousEntries: previous.entries,
    );
  }
}

class LeakSnapshotStore {
  LeakSnapshotStore._();

  static const String _key = 'leak_report_snapshot_v1';

  static Future<LeakSnapshot?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      return LeakSnapshot.fromJson(jsonDecode(raw));
    } catch (_) {
      return null; // a corrupt snapshot must never break the report
    }
  }

  static Future<void> save(LeakSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(snapshot.toJson()));
    } catch (_) {}
  }
}
