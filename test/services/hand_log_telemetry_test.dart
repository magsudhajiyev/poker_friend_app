import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/hand_log_telemetry.dart';

void main() {
  test('props shape with all fields', () {
    var t = DateTime(2026, 1, 1, 12);
    final tel = HandLogTelemetry(now: () => t)
      ..tap(3)
      ..streetReached = 'flop'
      ..mode = HandLogMode.flag;
    t = t.add(const Duration(seconds: 4));
    expect(tel.toProps('flagged'), {
      'completeness': 'flagged',
      'time_to_log_ms': 4000,
      'taps': 3,
      'street_reached': 'flop',
      'mode': 'flag',
    });
  });

  test('no extra keys when mode / street missing', () {
    final tel = HandLogTelemetry(now: () => DateTime(2026));
    expect(tel.toProps('full').keys,
        unorderedEquals(['completeness', 'time_to_log_ms', 'taps']));
  });

  test('mode wires', () {
    expect(HandLogMode.values.map((m) => m.wire),
        ['live', 'fold_tick', 'flag']);
  });

  test('capture helpers never throw (analytics disabled)', () {
    HandLogTelemetry.captureFoldTick();
    HandLogTelemetry.captureHandFlagged(['big_pot']);
    HandLogTelemetry.captureFlagCompleted(12);
    HandLogTelemetry.captureAbandoned('turn');
  });
}
