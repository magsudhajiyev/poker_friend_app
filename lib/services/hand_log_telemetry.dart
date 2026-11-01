import 'analytics_service.dart';

/// How a hand ended up in the log.
enum HandLogMode {
  live('live'),
  foldTick('fold_tick'),
  flag('flag');

  final String wire;
  const HandLogMode(this.wire);
}

/// Per-hand accumulator behind the `hand_logged` extras. Pure: no I/O, the
/// clock is injectable. Create one at hand start, call [tap] per logging
/// interaction, then pass [toProps] to the single `hand_logged` site.
class HandLogTelemetry {
  final DateTime Function() _now;
  final DateTime _start;
  int taps = 0;
  String? streetReached;
  HandLogMode? mode;

  HandLogTelemetry({DateTime Function()? now})
      : _now = now ?? DateTime.now,
        _start = (now ?? DateTime.now)();

  void tap([int n = 1]) => taps += n;

  /// [completenessWire] is `HandCompleteness.wire` ('fold_tick', 'preflop',
  /// 'flagged', 'reconstructed', 'full'). `mode` is omitted when unset.
  Map<String, Object> toProps(String completenessWire) => {
        'completeness': completenessWire,
        'time_to_log_ms': _now().difference(_start).inMilliseconds,
        'taps': taps,
        if (streetReached != null) 'street_reached': streetReached!,
        if (mode != null) 'mode': mode!.wire,
      };

  // ── One-site event helpers (all fire-and-forget) ──────────────────────

  static void captureFoldTick() => AnalyticsService.capture('fold_tick');

  static void captureHandFlagged(List<String> tags) =>
      AnalyticsService.capture('hand_flagged', {'tags': tags});

  static void captureFlagCompleted(int lagMin) =>
      AnalyticsService.capture('flag_completed', {'lag_min': lagMin});

  static void captureAbandoned(String street) =>
      AnalyticsService.capture('hand_logging_abandoned', {'street': street});
}
