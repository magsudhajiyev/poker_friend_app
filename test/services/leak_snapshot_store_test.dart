import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/leak_engine.dart';
import 'package:poker_logger/services/leak_snapshot_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Snapshot + diff logic behind the Leak Detector's "since your last
/// visit" banner, delta chips and unlock celebrations.
void main() {
  LeakFinding finding(
    String id, {
    double value = 0.5,
    LeakVerdict verdict = LeakVerdict.healthy,
    int n = 30,
    double low = 0.30,
    double high = 0.62,
  }) =>
      LeakFinding(
        id: id,
        title: id,
        value: value,
        bandLow: low,
        bandHigh: high,
        sampleCount: n,
        minSample: 12,
        verdict: verdict,
        aboveBand: value > high,
        meaning: 'm',
        cost: 'c',
        fix: 'f',
      );

  LeakSnapshot snap(List<LeakFinding> findings,
          {int hands = 100, DateTime? at}) =>
      LeakSnapshot.fromReport(
        LeakReport(findings: findings, handsAnalyzed: hands),
        at ?? DateTime(2026, 10, 1),
      );

  group('LeakSnapshot.fromReport', () {
    test('captures top-level detectors, excludes slice children', () {
      final s = snap([
        finding('fold_river'),
        finding('fold_river@BTN'), // slice child — excluded
      ]);
      expect(s.entries.keys.toList(), ['fold_river']);
      expect(s.entries['fold_river']!.verdict, LeakVerdict.healthy);
    });

    test('JSON round-trip preserves everything', () {
      final s = snap([
        finding('a', value: 0.25, verdict: LeakVerdict.confirmed, n: 40),
      ], hands: 282);
      final restored = LeakSnapshot.fromJson(s.toJson())!;
      expect(restored.takenAt, s.takenAt);
      expect(restored.handsAnalyzed, 282);
      final e = restored.entries['a']!;
      expect(e.value, 0.25);
      expect(e.sampleCount, 40);
      expect(e.verdict, LeakVerdict.confirmed);
      expect(e.bandLow, 0.30);
    });

    test('fromJson tolerates garbage', () {
      expect(LeakSnapshot.fromJson(null), isNull);
      expect(LeakSnapshot.fromJson({'takenAt': 'nope'}), isNull);
      final s = LeakSnapshot.fromJson({
        'takenAt': '2026-10-01T00:00:00.000',
        'hands': 5,
        'entries': [
          {'bad': 'entry'},
          null,
        ],
      });
      expect(s, isNotNull);
      expect(s!.entries, isEmpty);
    });
  });

  group('LeakSnapshotDiff.compute', () {
    test('insufficient → verdict = unlocked', () {
      final prev = snap([
        finding('bb_vs_steal', verdict: LeakVerdict.insufficientData, n: 8),
      ]);
      final cur = snap([
        finding('bb_vs_steal', verdict: LeakVerdict.healthy, n: 14),
      ], hands: 130);
      final diff = LeakSnapshotDiff.compute(prev, cur);
      expect(diff.handsDelta, 30);
      expect(diff.changes.single.kind, LeakChangeKind.unlocked);
    });

    test('leak → healthy and healthy → leak flips', () {
      final prev = snap([
        finding('a', value: 0.20, verdict: LeakVerdict.emerging),
        finding('b', value: 0.50, verdict: LeakVerdict.healthy),
      ]);
      final cur = snap([
        finding('a', value: 0.35, verdict: LeakVerdict.healthy),
        finding('b', value: 0.70, verdict: LeakVerdict.confirmed),
      ]);
      final diff = LeakSnapshotDiff.compute(prev, cur);
      final kinds = {for (final c in diff.changes) c.id: c.kind};
      expect(kinds['a'], LeakChangeKind.becameHealthy);
      expect(kinds['b'], LeakChangeKind.becameLeak);
      // Good news sorts first.
      expect(diff.changes.first.kind, LeakChangeKind.becameHealthy);
    });

    test('still-a-leak movement toward/away from the band', () {
      final prev = snap([
        finding('imp', value: 0.15, verdict: LeakVerdict.confirmed),
        finding('wor', value: 0.70, verdict: LeakVerdict.confirmed),
      ]);
      final cur = snap([
        finding('imp', value: 0.24, verdict: LeakVerdict.confirmed),
        finding('wor', value: 0.78, verdict: LeakVerdict.confirmed),
      ]);
      final diff = LeakSnapshotDiff.compute(prev, cur);
      final kinds = {for (final c in diff.changes) c.id: c.kind};
      expect(kinds['imp'], LeakChangeKind.improved);
      expect(kinds['wor'], LeakChangeKind.worsened);
    });

    test('sub-noise movement and healthy↔healthy produce no change', () {
      final prev = snap([
        finding('tiny', value: 0.25, verdict: LeakVerdict.emerging),
        finding('ok', value: 0.45, verdict: LeakVerdict.healthy),
      ]);
      final cur = snap([
        finding('tiny', value: 0.26, verdict: LeakVerdict.emerging),
        finding('ok', value: 0.55, verdict: LeakVerdict.healthy),
      ]);
      expect(LeakSnapshotDiff.compute(prev, cur).changes, isEmpty);
    });

    test('detectors absent from the previous snapshot are ignored', () {
      final prev = snap([finding('old')]);
      final cur = snap([finding('old'), finding('brand_new')]);
      expect(LeakSnapshotDiff.compute(prev, cur).changes, isEmpty);
    });

    test('previousOf exposes last-visit values for delta chips', () {
      final prev = snap([finding('a', value: 0.40)]);
      final cur = snap([finding('a', value: 0.46)]);
      final diff = LeakSnapshotDiff.compute(prev, cur);
      expect(diff.previousOf('a')!.value, 0.40);
      expect(diff.previousOf('missing'), isNull);
    });
  });

  group('LeakSnapshotStore', () {
    test('save/load round-trip via SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final s = snap([finding('a', value: 0.33)], hands: 42);
      await LeakSnapshotStore.save(s);
      final loaded = await LeakSnapshotStore.load();
      expect(loaded, isNotNull);
      expect(loaded!.handsAnalyzed, 42);
      expect(loaded.entries['a']!.value, 0.33);
    });

    test('load returns null on empty or corrupt storage', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await LeakSnapshotStore.load(), isNull);
      SharedPreferences.setMockInitialValues(
          {'leak_report_snapshot_v1': 'not json'});
      expect(await LeakSnapshotStore.load(), isNull);
    });
  });
}
