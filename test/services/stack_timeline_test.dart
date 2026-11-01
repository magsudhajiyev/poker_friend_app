import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/stack_timeline.dart';

Map<String, dynamic> e(String type, double stack, {int hand = 0, Map<String, dynamic>? extra}) => {
      'changeType': type,
      'stackSize': stack,
      'changeAmount': 0.0,
      'handNumber': hand,
      ...?extra,
    };

Map<String, dynamic> pending(String id, double snapshot, int hand) =>
    e('pending', snapshot, hand: hand, extra: {'flagId': id});

List<double> ys(StackTimelineData d) => d.points.map((p) => p.y).toList();

void main() {
  group('no new kinds', () {
    test('series identical to the index-based series', () {
      final h = [
        e('initial', 1000),
        e('win', 1100, hand: 1),
        e('loss', 900, hand: 2),
        e('manual_increase', 1200),
        e('rebuy', 1500, hand: 3),
        e('final', 1400),
      ];
      final d = StackTimeline.build(h);
      expect(ys(d), [1000, 1100, 900, 1200, 1500, 1400]);
      expect(d.points.map((p) => p.x), [0, 1, 2, 3, 4, 5]);
      expect(d.segments.length, 1);
      expect(d.segments.single.dashed, isFalse);
      expect(d.usesNewKinds, isFalse);
    });

    test('single entry yields one point and one segment', () {
      final d = StackTimeline.build([e('initial', 500)]);
      expect(d.points.length, 1);
      expect(d.segments.length, 1);
    });

    test('empty history is empty', () {
      final d = StackTimeline.build([]);
      expect(d.points, isEmpty);
      expect(d.segments, isEmpty);
    });
  });

  group('fold_run', () {
    test('is not plotted and does not break the line', () {
      final h = [
        e('initial', 1000),
        e('fold_run', 990, hand: 3),
        e('win', 1090, hand: 4),
      ];
      final d = StackTimeline.build(h);
      expect(ys(d), [1000, 1090]);
      expect(d.hasDashed, isFalse);
    });
  });

  group('flags between hard anchors', () {
    test('0 unresolved, all resolved: flag plotted solid at its result', () {
      final h = [
        e('initial', 1000),
        e('win', 1100, hand: 1),
        pending('f1', 1100, 2),
        e('win', 1150, hand: 3), // live value ignores the flag
        e('manual_decrease', 850),
      ];
      final d = StackTimeline.build(
          h, {'f1': const FlagResolution(heroDelta: -300)});
      // flag point = 1100 - 300, later hand shifted by the flag.
      expect(ys(d), [1000, 1100, 800, 850, 850]);
      expect(d.hasDashed, isFalse);
      expect(d.points[2].kind, TimelinePointKind.real);
    });

    test('0 unresolved but anchor disagrees: hollow unlogged step', () {
      final h = [
        e('initial', 1000),
        e('win', 1100, hand: 1),
        pending('f1', 1100, 2),
        e('manual_decrease', 900),
      ];
      final d = StackTimeline.build(
          h, {'f1': const FlagResolution(heroDelta: -150)});
      // flag at 950, anchor 900 -> unlogged -50
      expect(ys(d), [1000, 1100, 950, 950, 900]);
      expect(d.points[3].kind, TimelinePointKind.unlogged);
      expect(d.points[3].gap, closeTo(-50, 1e-9));
      final dashed = d.segments.where((s) => s.dashed).single;
      expect(dashed.unloggedGap, closeTo(-50, 1e-9));
    });

    test('discarded flag falls into unlogged', () {
      final h = [
        e('initial', 1000),
        pending('f1', 1000, 1),
        e('final', 700),
      ];
      final d = StackTimeline.build(h, {'f1': const FlagResolution(discarded: true)});
      expect(ys(d), [1000, 1000, 700]);
      expect(d.points[1].kind, TimelinePointKind.unlogged);
      expect(d.points[1].gap, -300);
      expect(d.hasPending, isFalse);
    });

    test('1 unresolved: its result is estimated from the anchor, dashed in', () {
      final h = [
        e('initial', 1000),
        e('win', 1100, hand: 1),
        pending('f1', 1100, 2),
        e('win', 1150, hand: 3),
        e('manual_decrease', 850),
      ];
      final d = StackTimeline.build(h);
      // estimated delta = 850 - 1150 = -300
      expect(ys(d), [1000, 1100, 800, 850, 850]);
      final p = d.points[2];
      expect(p.kind, TimelinePointKind.pending);
      expect(p.dashedIn, isTrue);
      expect(p.gap, closeTo(-300, 1e-9));
      expect(p.flagIds, ['f1']);
      expect(d.hasPending, isTrue);
      final dashed = d.segments.where((s) => s.dashed).single;
      expect(dashed.pendingCount, 1);
      expect(dashed.flagIds, ['f1']);
    });

    test('k unresolved: exact up to the first, one dashed bar to the anchor', () {
      final h = [
        e('initial', 1000),
        e('win', 1100, hand: 1),
        pending('f1', 1100, 2),
        e('win', 1150, hand: 3),
        pending('f2', 1150, 4),
        e('final', 600),
      ];
      final d = StackTimeline.build(h);
      expect(ys(d), [1000, 1100, 600]);
      final dashed = d.segments.where((s) => s.dashed).single;
      expect(dashed.pendingCount, 2);
      expect(dashed.flagIds, ['f1', 'f2']);
      expect(d.points.last.dashedIn, isTrue);
    });

    test('resolved flag inside a pending segment is plotted solid', () {
      final h = [
        e('initial', 1000),
        pending('f1', 1000, 1),
        pending('f2', 1000, 2),
        pending('f3', 1000, 3),
        e('final', 1500),
      ];
      final d = StackTimeline.build(
          h, {'f1': const FlagResolution(heroDelta: 200)});
      // f1 resolved first: exact solid point, then dashed bar to the end for f2+f3.
      expect(ys(d), [1000, 1200, 1500]);
      expect(d.points[1].dashedIn, isFalse);
      final dashed = d.segments.where((s) => s.dashed).single;
      expect(dashed.pendingCount, 2);
    });

    test('trailing open flags: flat dashed to a hollow point', () {
      final h = [
        e('initial', 1000),
        e('win', 1100, hand: 1),
        pending('f1', 1100, 2),
      ];
      final d = StackTimeline.build(h);
      expect(ys(d), [1000, 1100, 1100]);
      expect(d.points.last.kind, TimelinePointKind.pending);
      expect(d.points.last.dashedIn, isTrue);
      expect(d.segments.last.dashed, isTrue);
      expect(d.segments.last.pendingCount, 1);
    });

    test('trailing: hands after an open flag continue dashed', () {
      final h = [
        e('initial', 1000),
        pending('f1', 1000, 1),
        e('win', 1050, hand: 2),
      ];
      final d = StackTimeline.build(h);
      expect(ys(d), [1000, 1000, 1050]);
      expect(d.points[2].dashedIn, isTrue);
    });
  });

  test('entry-level discarded:true falls into unlogged without a resolution', () {
    final h = [
      e('initial', 1000),
      e('pending', 1000, hand: 1, extra: {'flagId': 'f1', 'discarded': true}),
      e('final', 800),
    ];
    final d = StackTimeline.build(h);
    expect(ys(d), [1000, 1000, 800]);
    expect(d.points[1].kind, TimelinePointKind.unlogged);
    expect(d.hasPending, isFalse);
  });

  group('rebuy', () {
    test('stackBefore draws a vertical step at one x', () {
      final h = [
        e('initial', 1000),
        e('win', 400, hand: 1),
        e('rebuy', 1400, hand: 2, extra: {'stackBefore': 380.0}),
        e('final', 1300),
      ];
      final d = StackTimeline.build(h);
      expect(ys(d), [1000, 400, 380, 1400, 1300]);
      expect(d.points[2].kind, TimelinePointKind.rebuyStep);
      expect(d.points[2].x, d.points[3].x);
      expect(d.points[4].x, 3);
      expect(d.usesNewKinds, isTrue);
    });

    test('stackBefore anchors an open flag before it', () {
      final h = [
        e('initial', 1000),
        pending('f1', 1000, 1),
        e('rebuy', 1500, hand: 2, extra: {'stackBefore': 700.0}),
      ];
      final d = StackTimeline.build(h);
      // estimated flag result = 700 - 1000 = -300
      expect(ys(d), [1000, 700, 700, 1500]);
      expect(d.points[1].kind, TimelinePointKind.pending);
      expect(d.points[1].gap, -300);
    });
  });

  group('tournament big blinds', () {
    test('each point is converted with its own big blind', () {
      final h = [
        e('initial', 10000),
        e('win', 12000, hand: 1),
        e('loss', 9000, hand: 12),
      ];
      final d = StackTimeline.build(h).inBigBlinds(
          (n) => n >= 10 ? 1000.0 : 200.0);
      // initial uses the first known blind; hand 1 /200; hand 12 /1000.
      expect(ys(d), [50, 60, 9]);
    });

    test('a pending entry carries its own bigBlind', () {
      final h = [
        e('initial', 5000),
        e('pending', 5000, hand: 3, extra: {'flagId': 'f', 'bigBlind': 100.0}),
      ];
      final d = StackTimeline.build(h).inBigBlinds((_) => null);
      expect(d.points.last.y, 50);
    });
  });

  test('FlagResolution reads flagMeta', () {
    final r = FlagResolution.fromFlagMeta({'heroDelta': 12, 'discarded': false});
    expect(r.isResolved, isTrue);
    expect(r.heroDelta, 12.0);
    expect(FlagResolution.fromFlagMeta(null).isResolved, isFalse);
    expect(FlagResolution.fromFlagMeta({'discarded': true}).discarded, isTrue);
  });
}
