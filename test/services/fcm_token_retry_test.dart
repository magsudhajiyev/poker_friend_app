import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/fcm_service.dart';

void main() {
  const delays = [Duration(seconds: 2), Duration(seconds: 4)];

  test('returns first token without waiting', () async {
    final waits = <Duration>[];
    final t = await FCMService.retryForToken(() async => 'tok',
        delays: delays, wait: (d) async => waits.add(d));
    expect(t, 'tok');
    expect(waits, isEmpty);
  });

  test('retries until a token arrives', () async {
    var calls = 0;
    final waits = <Duration>[];
    final t = await FCMService.retryForToken(
        () async => ++calls == 3 ? 'tok' : null,
        delays: delays,
        wait: (d) async => waits.add(d));
    expect(t, 'tok');
    expect(waits, delays);
  });

  test('gives up with null and never throws', () async {
    final t = await FCMService.retryForToken(() async => null,
        delays: delays, wait: (_) async {});
    expect(t, isNull);
    final e = await FCMService.retryForToken(() async => throw 'x',
        delays: delays, wait: (_) async {});
    expect(e, isNull);
  });
}
