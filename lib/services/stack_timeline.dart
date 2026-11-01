/// Pure read-side model of a session's stack history.
///
/// The chart is a DERIVED view of `stackHistory` plus per-flag resolutions
/// (see the stack timeline design). Nothing here touches Flutter or IO.
///
/// Entry kinds in `stackHistory`:
/// * hard anchors: `initial`, `manual_increase`, `manual_decrease`, `final`
///   and `rebuy` that carries `stackBefore`. Their value is the truth.
/// * live entries: `win`, `loss`, `rebuy` without `stackBefore`. The live
///   stack ignores the real result of a flagged hand, so after an open flag
///   these values sit off by the flag's unknown result.
/// * markers: `fold_run` (not plotted) and `pending` (a flagged hand).
///
/// Sessions with no `pending` entry and no `stackBefore` produce exactly the
/// old index-based series (every entry except `fold_run`, x = index).
library;

/// How a flagged hand was settled. Stored on the stub as
/// `flagMeta.heroDelta` / `flagMeta.discarded`.
class FlagResolution {
  /// Signed hero result of the flagged hand, or null when unknown.
  final double? heroDelta;
  final bool discarded;

  const FlagResolution({this.heroDelta, this.discarded = false});

  bool get isResolved => !discarded && heroDelta != null;

  /// Reads a hand doc's `flag` map (a.k.a. flagMeta). Null map -> unresolved.
  factory FlagResolution.fromFlagMeta(Map<String, dynamic>? meta) {
    if (meta == null) return const FlagResolution();
    return FlagResolution(
      heroDelta: (meta['heroDelta'] as num?)?.toDouble(),
      discarded: meta['discarded'] == true,
    );
  }
}

enum TimelinePointKind {
  /// A known value (hard anchor, live entry, or a resolved flag).
  real,

  /// A flagged hand still open. Drawn hollow.
  pending,

  /// Where the line stops being explained. Drawn hollow.
  unlogged,

  /// The "before" end of a rebuy step. Not drawn as a dot.
  rebuyStep,
}

class TimelinePoint {
  /// Chart x. Integer slots; a [TimelinePointKind.rebuyStep] shares the x of
  /// the rebuy that follows it (vertical step).
  final double x;
  final double y;
  final TimelinePointKind kind;

  /// True when the line INTO this point is dashed.
  final bool dashedIn;

  /// Source history entry, null for synthesized points.
  final Map<String, dynamic>? entry;
  final int? handNumber;

  /// Open flag ids this point stands for (pending) or that a dashed run into
  /// this point is waiting on.
  final List<String> flagIds;

  /// pending: estimated hero result of the flag. unlogged: the unexplained
  /// amount.
  final double? gap;

  const TimelinePoint({
    required this.x,
    required this.y,
    this.kind = TimelinePointKind.real,
    this.dashedIn = false,
    this.entry,
    this.handNumber,
    this.flagIds = const [],
    this.gap,
  });

  bool get isHollow =>
      kind == TimelinePointKind.pending || kind == TimelinePointKind.unlogged;

  String get changeType => (entry?['changeType'] as String?) ?? '';

  TimelinePoint copyWith({double? y}) => TimelinePoint(
        x: x,
        y: y ?? this.y,
        kind: kind,
        dashedIn: dashedIn,
        entry: entry,
        handNumber: handNumber,
        flagIds: flagIds,
        gap: gap,
      );
}

/// A maximal run of same-style edges; points[start..end] inclusive.
class TimelineSegment {
  final int start;
  final int end;
  final bool dashed;

  /// Open flags this dashed run is waiting on.
  final List<String> flagIds;

  /// Unexplained amount when the dashed run ends an unlogged step.
  final double? unloggedGap;

  const TimelineSegment({
    required this.start,
    required this.end,
    required this.dashed,
    this.flagIds = const [],
    this.unloggedGap,
  });

  int get pendingCount => flagIds.length;
}

class StackTimelineData {
  final List<TimelinePoint> points;
  final List<TimelineSegment> segments;

  const StackTimelineData(this.points, this.segments);

  bool get hasPending => points.any((p) => p.kind == TimelinePointKind.pending);

  bool get hasDashed => segments.any((s) => s.dashed);

  /// True when a session carries data written by the easy-logging flag.
  bool get usesNewKinds =>
      hasDashed ||
      points.any((p) => p.kind != TimelinePointKind.real) ||
      points.any((p) => p.entry?['stackBefore'] != null);

  /// Points that count as real data (for the show-card gate).
  int get realPointCount =>
      points.where((p) => p.kind == TimelinePointKind.real).length;

  /// Index in [points] of the plotted point at integer slot [x], or null.
  int? indexAtSlot(int x) {
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      if (p.kind != TimelinePointKind.rebuyStep && p.x == x.toDouble()) {
        return i;
      }
    }
    return null;
  }

  /// Same shape with every y divided by that point's big blind.
  /// [bbForHand] looks a hand's big blind up by hand number; an entry's own
  /// `bigBlind` wins, then the lookup, then the last known blind. Points
  /// before the first known blind use that first blind. With no blind known
  /// at all, [fallback] (if any) is used; otherwise the data stays in chips.
  StackTimelineData inBigBlinds(
    double? Function(int handNumber) bbForHand, {
    double? fallback,
  }) {
    final bbs = <double?>[];
    double? last;
    for (final p in points) {
      final own = (p.entry?['bigBlind'] as num?)?.toDouble();
      final n = p.handNumber;
      final bb = own ?? (n != null && n > 0 ? bbForHand(n) : null) ?? last;
      if (bb != null && bb > 0) last = bb;
      bbs.add(bb != null && bb > 0 ? bb : null);
    }
    final first = bbs.firstWhere((b) => b != null, orElse: () => null) ??
        ((fallback ?? 0) > 0 ? fallback : null);
    return StackTimelineData([
      for (var i = 0; i < points.length; i++)
        (bbs[i] ?? first) != null
            ? points[i].copyWith(y: points[i].y / (bbs[i] ?? first)!)
            : points[i],
    ], segments);
  }
}

class StackTimeline {
  StackTimeline._();

  static const _eps = 1e-9;

  /// Builds the plotted series. [resolutions] is keyed by flag id (the
  /// `flagId` of `pending` entries).
  static StackTimelineData build(
    List<Map<String, dynamic>> history, [
    Map<String, FlagResolution> resolutions = const {},
  ]) {
    final b = _Builder(resolutions);
    final span = <Map<String, dynamic>>[];
    for (final e in history) {
      if (_isHard(e)) {
        b.closeSpan(span, e);
        span.clear();
      } else {
        span.add(e);
      }
    }
    b.closeSpan(span, null);
    return b.finish();
  }

  static bool _isHard(Map<String, dynamic> e) {
    switch (e['changeType']) {
      case 'initial':
      case 'manual_increase':
      case 'manual_decrease':
      case 'final':
        return true;
      case 'rebuy':
        return e['stackBefore'] != null;
      default:
        return false;
    }
  }

  static double _y(Map<String, dynamic> e) =>
      (e['stackSize'] as num?)?.toDouble() ?? 0.0;
}

class _Builder {
  final Map<String, FlagResolution> res;
  final points = <TimelinePoint>[];
  int _slot = 0;

  _Builder(this.res);

  TimelinePoint? get _last => points.isEmpty ? null : points.last;

  void _add(
    double y,
    Map<String, dynamic>? entry, {
    TimelinePointKind kind = TimelinePointKind.real,
    bool dashed = false,
    int? hand,
    List<String> flagIds = const [],
    double? gap,
    bool step = false,
  }) {
    final x = step ? _slot.toDouble() : (_slot++).toDouble();
    points.add(TimelinePoint(
      x: x,
      y: y,
      kind: kind,
      dashedIn: dashed,
      entry: entry,
      handNumber: hand ?? (entry?['handNumber'] as num?)?.toInt(),
      flagIds: flagIds,
      gap: gap,
    ));
  }

  /// Emits a hard anchor ([z]); a rebuy with `stackBefore` is a vertical step.
  /// [dashedIn] marks the line into it as dashed.
  void _emitHard(Map<String, dynamic> z, {bool dashed = false}) {
    final before = (z['stackBefore'] as num?)?.toDouble();
    if (z['changeType'] == 'rebuy' && before != null) {
      _add(before, z,
          kind: TimelinePointKind.rebuyStep, dashed: dashed, step: true);
      _add(StackTimeline._y(z), z);
    } else {
      _add(StackTimeline._y(z), z, dashed: dashed);
    }
  }

  /// The value the hard anchor [z] asserts just before its own change.
  double _zPre(Map<String, dynamic> z) =>
      (z['stackBefore'] as num?)?.toDouble() ?? StackTimeline._y(z);

  void closeSpan(List<Map<String, dynamic>> span, Map<String, dynamic>? z) {
    final hasPending = span.any((e) => e['changeType'] == 'pending');
    final start = _last;
    if (!hasPending || start == null) {
      _plain(span, z);
      return;
    }
    _withFlags(span, z, start);
  }

  void _plain(List<Map<String, dynamic>> span, Map<String, dynamic>? z) {
    for (final e in span) {
      if (e['changeType'] == 'fold_run' || e['changeType'] == 'pending') {
        continue;
      }
      _add(StackTimeline._y(e), e);
    }
    if (z != null) _emitHard(z);
  }

  FlagResolution _res(Map<String, dynamic> e) {
    // The entry itself carries `discarded: true` once the stub is discarded.
    if (e['discarded'] == true) return const FlagResolution(discarded: true);
    return res[e['flagId']?.toString()] ?? const FlagResolution();
  }

  void _withFlags(
    List<Map<String, dynamic>> span,
    Map<String, dynamic>? z,
    TimelinePoint a,
  ) {
    final unresolved = [
      for (final e in span)
        if (e['changeType'] == 'pending' &&
            !_res(e).discarded &&
            !_res(e).isResolved)
          e,
    ];
    final resolvedTotal = [
      for (final e in span)
        if (e['changeType'] == 'pending' && _res(e).isResolved)
          _res(e).heroDelta!,
    ].fold<double>(0, (s, d) => s + d);
    var lastLive = a.y;
    for (final e in span) {
      lastLive = StackTimeline._y(e);
    }
    // Estimated result of the single open flag (closed spans only).
    final u = z == null
        ? 0.0
        : _zPre(z) - lastLive - resolvedTotal;
    if (z != null && unresolved.length > 1) {
      _multi(span, z, unresolved);
      return;
    }
    _walk(span, trailing: z == null, u: u);
    if (z == null) return;
    if (unresolved.isEmpty) {
      _unlogged(z, u);
    } else {
      _emitHard(z);
    }
  }

  /// Walks a span shifting live values by the flags settled so far.
  void _walk(List<Map<String, dynamic>> span,
      {required bool trailing, required double u}) {
    var shift = 0.0;
    var uncertain = false; // trailing span after the first open flag
    for (final e in span) {
      final type = e['changeType'];
      if (type == 'fold_run') continue;
      if (type != 'pending') {
        _add(StackTimeline._y(e) + shift, e, dashed: uncertain);
        continue;
      }
      final r = _res(e);
      final y0 = StackTimeline._y(e) + shift;
      if (r.discarded) continue;
      if (r.isResolved) {
        shift += r.heroDelta!;
        _add(y0 + r.heroDelta!, e,
            dashed: uncertain, hand: (e['handNumber'] as num?)?.toInt());
        continue;
      }
      final id = e['flagId']?.toString() ?? '';
      if (trailing) {
        // Result unknown and nothing closes it yet: stay flat, dashed.
        _add(y0, e,
            kind: TimelinePointKind.pending,
            dashed: true,
            flagIds: [id],
            gap: 0);
        uncertain = true;
      } else {
        shift += u;
        _add(y0 + u, e,
            kind: TimelinePointKind.pending,
            dashed: true,
            flagIds: [id],
            gap: u);
      }
    }
  }

  /// Zero open flags but the span does not add up: hollow marker, then a
  /// dashed step to the anchor.
  void _unlogged(Map<String, dynamic> z, double gap) {
    if (gap.abs() < StackTimeline._eps) {
      _emitHard(z);
      return;
    }
    _add(_zPre(z) - gap, null,
        kind: TimelinePointKind.unlogged, gap: gap, hand: _last?.handNumber);
    // The dashed edge ends at the first point the anchor emits.
    _unloggedAt[points.length] = gap;
    _emitHard(z, dashed: true);
  }

  final _unloggedAt = <int, double>{};

  /// Two or more open flags before a hard anchor: exact up to the first open
  /// one, then one dashed bar to the anchor.
  void _multi(List<Map<String, dynamic>> span, Map<String, dynamic> z,
      List<Map<String, dynamic>> unresolved) {
    final cut = span.indexOf(unresolved.first);
    _walk(span.sublist(0, cut), trailing: false, u: 0);
    final ids = [for (final e in unresolved) e['flagId']?.toString() ?? ''];
    final before = (z['stackBefore'] as num?)?.toDouble();
    if (z['changeType'] == 'rebuy' && before != null) {
      _add(before, z,
          kind: TimelinePointKind.rebuyStep,
          dashed: true,
          step: true,
          flagIds: ids);
      _add(StackTimeline._y(z), z);
    } else {
      _add(StackTimeline._y(z), z, dashed: true, flagIds: ids);
    }
  }

  StackTimelineData finish() {
    final segs = <TimelineSegment>[];
    if (points.length < 2) {
      if (points.isNotEmpty) {
        segs.add(const TimelineSegment(start: 0, end: 0, dashed: false));
      }
      return StackTimelineData(points, segs);
    }
    var start = 0;
    for (var i = 1; i < points.length; i++) {
      final dashed = points[i].dashedIn;
      final next = i + 1 < points.length ? points[i + 1].dashedIn : !dashed;
      if (next == dashed) continue;
      segs.add(_segment(start, i, dashed));
      start = i;
    }
    return StackTimelineData(points, segs);
  }

  TimelineSegment _segment(int start, int end, bool dashed) {
    if (!dashed) {
      return TimelineSegment(start: start, end: end, dashed: false);
    }
    final ids = <String>[];
    double? gap;
    for (var i = start + 1; i <= end; i++) {
      for (final id in points[i].flagIds) {
        if (!ids.contains(id)) ids.add(id);
      }
      gap ??= _unloggedAt[i];
    }
    return TimelineSegment(
        start: start, end: end, dashed: true, flagIds: ids, unloggedGap: gap);
  }
}
