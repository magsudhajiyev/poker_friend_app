import 'dart:async';

import '../models/hand_state_machine.dart';

/// One uncommitted fold tick waiting out the undo window.
class PendingFoldTick {
  final int id;
  final DateTime queuedAt;
  final HoleCards? heroCards;
  final Object? payload;
  bool _committed = false;
  bool _cancelled = false;
  Timer? _timer;

  PendingFoldTick._(this.id, this.queuedAt, this.heroCards, this.payload);

  bool get committed => _committed;
  bool get cancelled => _cancelled;
}

typedef FoldTickCommit = Future<void> Function(PendingFoldTick tick);
typedef FoldTickTimerFactory = Timer Function(Duration d, void Function() cb);

/// Deferred commit for fold ticks (4 s undo window). Pure: the commit action,
/// the window and the timer factory are injected.
///
/// A tick commits after [window], on [flushAll] (app pause, dispose, session
/// end, next full hand), and never twice. [undoLast] cancels the newest
/// uncommitted tick — no stats reversal is ever needed because nothing was
/// written yet.
class FoldTickQueue {
  final FoldTickCommit commit;
  final Duration window;
  final FoldTickTimerFactory _timerFactory;
  final DateTime Function() _now;
  final List<PendingFoldTick> _pending = [];
  final List<Future<void>> _inFlight = [];
  int _nextId = 1;
  int _committedCount = 0;

  FoldTickQueue({
    required this.commit,
    this.window = const Duration(seconds: 4),
    FoldTickTimerFactory? timerFactory,
    DateTime Function()? now,
  })  : _timerFactory = timerFactory ?? ((d, cb) => Timer(d, cb)),
        _now = now ?? DateTime.now;

  /// Newest uncommitted tick (null when none). Used by the session manager to
  /// read the payload of a tick before undoing it.
  PendingFoldTick? get newestPending => _pending.isEmpty ? null : _pending.last;

  /// Uncommitted ticks (inside the undo window).
  int get pendingCount => _pending.length;

  /// Ticks already committed through [commit].
  int get committedCount => _committedCount;

  PendingFoldTick enqueue({HoleCards? heroCards, Object? payload}) {
    final tick = PendingFoldTick._(_nextId++, _now(), heroCards, payload);
    tick._timer = _timerFactory(window, () => _commit(tick));
    _pending.add(tick);
    return tick;
  }

  /// True if the newest uncommitted tick was cancelled.
  bool undoLast() {
    if (_pending.isEmpty) return false;
    final tick = _pending.removeLast();
    tick._timer?.cancel();
    tick._cancelled = true;
    return true;
  }

  /// Commits every pending tick now and waits for all commits to finish.
  Future<void> flushAll() async {
    for (final tick in List<PendingFoldTick>.of(_pending)) {
      tick._timer?.cancel();
      _commit(tick);
    }
    await Future.wait(List<Future<void>>.of(_inFlight));
  }

  /// Cancels timers without committing (use after [flushAll]).
  void dispose() {
    for (final tick in _pending) {
      tick._timer?.cancel();
    }
    _pending.clear();
  }

  void _commit(PendingFoldTick tick) {
    if (tick._committed || tick._cancelled) return;
    tick._committed = true;
    _pending.remove(tick);
    final run = () async {
      try {
        await commit(tick);
        _committedCount++;
      } catch (_) {
        // Commit failures are logged by the commit callback; never rethrow
        // into the timer zone.
      }
    }();
    _inFlight.add(run);
    run.whenComplete(() => _inFlight.remove(run));
  }
}
