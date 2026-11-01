import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/fold_tick_queue.dart';

/// Manual timer so the 4 s window is deterministic.
class _FakeTimer implements Timer {
  final void Function() cb;
  bool cancelled = false;
  bool fired = false;
  _FakeTimer(this.cb);

  void fire() {
    if (cancelled || fired) return;
    fired = true;
    cb();
  }

  @override
  void cancel() => cancelled = true;
  @override
  bool get isActive => !cancelled && !fired;
  @override
  int get tick => fired ? 1 : 0;
}

void main() {
  late List<_FakeTimer> timers;
  late List<int> committed;
  late FoldTickQueue queue;

  setUp(() {
    timers = [];
    committed = [];
    queue = FoldTickQueue(
      commit: (t) async => committed.add(t.id),
      timerFactory: (d, cb) {
        expect(d, const Duration(seconds: 4));
        final t = _FakeTimer(cb);
        timers.add(t);
        return t;
      },
    );
  });

  test('commits after the window', () async {
    final tick = queue.enqueue();
    expect(queue.pendingCount, 1);
    expect(committed, isEmpty);
    timers.single.fire();
    await queue.flushAll();
    expect(committed, [tick.id]);
    expect(queue.pendingCount, 0);
    expect(queue.committedCount, 1);
  });

  test('undo before the window = no commit', () async {
    queue.enqueue();
    expect(queue.undoLast(), isTrue);
    timers.single.fire(); // cancelled timer must not fire a commit
    await queue.flushAll();
    expect(committed, isEmpty);
    expect(queue.pendingCount, 0);
  });

  test('undo with nothing pending returns false', () {
    expect(queue.undoLast(), isFalse);
  });

  test('undo after commit is impossible', () async {
    queue.enqueue();
    timers.single.fire();
    await queue.flushAll();
    expect(queue.undoLast(), isFalse);
    expect(committed.length, 1);
  });

  test('two ticks: undo cancels only the newest', () async {
    final first = queue.enqueue();
    queue.enqueue();
    expect(queue.undoLast(), isTrue);
    for (final t in timers) {
      t.fire();
    }
    await queue.flushAll();
    expect(committed, [first.id]);
  });

  test('flushAll commits everything exactly once', () async {
    final a = queue.enqueue();
    final b = queue.enqueue();
    await queue.flushAll();
    expect(committed, [a.id, b.id]);
    // late timer fire and a second flush must not commit again
    for (final t in timers) {
      t.fire();
    }
    await queue.flushAll();
    expect(committed.length, 2);
    expect(queue.committedCount, 2);
  });

  test('lifecycle pause flush commits a tick inside the window', () async {
    final tick = queue.enqueue();
    // simulate AppLifecycleState.paused -> flushAll
    await queue.flushAll();
    expect(committed, [tick.id]);
  });

  test('a failing commit never throws and does not count', () async {
    final failing = FoldTickQueue(
      commit: (t) async => throw StateError('boom'),
      timerFactory: (d, cb) => _FakeTimer(cb),
    );
    failing.enqueue();
    await failing.flushAll();
    expect(failing.committedCount, 0);
    expect(failing.pendingCount, 0);
  });

  test('payload and hero cards travel with the tick', () {
    final tick = queue.enqueue(payload: 'p');
    expect(tick.payload, 'p');
    expect(tick.heroCards, isNull);
  });
}
