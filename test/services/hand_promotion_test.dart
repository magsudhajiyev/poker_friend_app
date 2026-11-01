import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/game_types.dart';
import 'package:poker_logger/models/hand_completeness.dart';
import 'package:poker_logger/models/hand_state_machine.dart';
import 'package:poker_logger/models/poker_game_state.dart';
import 'package:poker_logger/services/hand_promotion_service.dart';
import 'package:poker_logger/services/hand_stats_plan.dart';

class _FakeWriter implements HandStatsWriter {
  final List<HandRecord> promoted = [];
  final List<String> sessionBumps = [];
  bool fail = false;

  @override
  Future<void> applyPromotedStats(HandRecord hand) async {
    if (fail) throw StateError('stats down');
    promoted.add(hand);
  }

  @override
  Future<void> incrementSessionTotalHands(String sessionId) async =>
      sessionBumps.add(sessionId);
}

/// Mimics the Firestore transaction on `statsApplied`.
class _FakeStore implements PromotionStore {
  bool statsApplied = false;
  int claimWrites = 0;
  final List<String> mirrored = [];
  int dirtyMarks = 0;
  bool throwOnClaim = false;

  @override
  Future<bool> claim({
    required String sessionId,
    required String cloudHandId,
    required Map<String, dynamic> fields,
  }) async {
    if (throwOnClaim) throw StateError('offline');
    if (statsApplied) return false;
    statsApplied = true;
    claimWrites++;
    return true;
  }

  @override
  Future<void> mirrorLocal({
    required String localHandId,
    required Map<String, dynamic> fields,
  }) async =>
      mirrored.add(localHandId);

  @override
  void markCachesDirty() => dirtyMarks++;
}

HandRecord _completed({
  HandCompleteness c = HandCompleteness.reconstructed,
  bool withActions = true,
}) {
  final h = HandRecord(
    handNumber: 12,
    buttonPosition: 1,
    playerCount: 6,
    startTime: DateTime.utc(2026, 10, 31, 20),
    heroSeatNumber: 4,
    heroPositionName: 'BTN',
  )..completeness = c;
  h.flagMeta = {'flaggedAt': DateTime.utc(2026, 10, 31, 20).toIso8601String()};
  if (withActions) {
    h.actions.add(ActionRecord(
      player: 4,
      action: PlayerAction.raise,
      street: BettingRound.preflop,
      timestamp: DateTime.utc(2026, 10, 31, 20, 1),
      buttonPosition: 1,
      isCurrentUser: true,
      amount: 5,
    ));
  }
  return h;
}

void main() {
  late _FakeWriter writer;
  late _FakeStore store;
  late HandPromotionService service;

  setUp(() {
    writer = _FakeWriter();
    store = _FakeStore();
    service = HandPromotionService(
      stats: writer,
      store: store,
      now: () => DateTime.utc(2026, 10, 31, 20, 30),
    );
  });

  test('promotes once: stats applied exactly once, lag reported', () async {
    final r = await service.promote(
        sessionId: 's1', cloudHandId: 'h1', localHandId: 'l1', completed: _completed());
    expect(r.status, PromotionStatus.promoted);
    expect(r.lag, const Duration(minutes: 30));
    expect(writer.promoted.length, 1);
    expect(writer.sessionBumps, ['s1']);
    expect(store.mirrored, ['l1']);
    expect(store.dirtyMarks, 1);
  });

  test('second promote returns alreadyCounted and writes nothing', () async {
    await service.promote(sessionId: 's1', cloudHandId: 'h1', completed: _completed());
    final again = await service.promote(
        sessionId: 's1', cloudHandId: 'h1', completed: _completed());
    expect(again.status, PromotionStatus.alreadyCounted);
    expect(writer.promoted.length, 1, reason: 'stats must not run twice');
    expect(writer.sessionBumps.length, 1);
    expect(store.claimWrites, 1);
  });

  test('concurrent double tap still counts once', () async {
    final results = await Future.wait([
      service.promote(sessionId: 's', cloudHandId: 'h', completed: _completed()),
      service.promote(sessionId: 's', cloudHandId: 'h', completed: _completed()),
    ]);
    expect(results.where((r) => r.promoted).length, 1);
    expect(writer.promoted.length, 1);
  });

  test('invalid targets never touch storage or stats', () async {
    for (final h in [
      _completed(withActions: false),
      _completed(c: HandCompleteness.flagged),
      _completed(c: HandCompleteness.foldTick),
      _completed(c: HandCompleteness.preflop),
    ]) {
      final r = await service.promote(sessionId: 's', cloudHandId: 'h', completed: h);
      expect(r.status, PromotionStatus.invalid);
    }
    expect(store.claimWrites, 0);
    expect(writer.promoted, isEmpty);
  });

  test('claim failure -> failed, no stats', () async {
    store.throwOnClaim = true;
    final r = await service.promote(
        sessionId: 's', cloudHandId: 'h', completed: _completed());
    expect(r.status, PromotionStatus.failed);
    expect(writer.promoted, isEmpty);
  });

  test('stats failure under-counts but never double counts', () async {
    writer.fail = true;
    final r = await service.promote(
        sessionId: 's', cloudHandId: 'h', completed: _completed());
    expect(r.promoted, isTrue);
    expect(store.statsApplied, isTrue, reason: 'flag flipped before stats');
    writer.fail = false;
    final retry = await service.promote(
        sessionId: 's', cloudHandId: 'h', completed: _completed());
    expect(retry.status, PromotionStatus.alreadyCounted);
    expect(writer.promoted, isEmpty);
  });

  test('promotion fields carry actions and cards, not completeness', () {
    final f = HandPromotionService.promotionFields(_completed());
    expect(f['actions'], isNotEmpty);
    expect(f.containsKey('completeness'), isFalse);
    expect(f['heroSeatNumber'], 4);
  });

  group('stub creation and stat modes (no Firebase)', () {
    PokerSessionManager manager() => PokerSessionManager(
          smallBlind: 1,
          bigBlind: 2,
          playerCount: 6,
          ourSeatNumber: 4,
          gameType: GameType.cash,
        )
          ..sessionId = 's1'
          ..activeSeats = {1, 2, 3, 4, 5, 6}
          ..playerStacks = {4: 200}
          ..buttonPosition = 2;

    test('flag stub: no actions, statsApplied false, zero stat modes', () {
      final m = manager();
      final stub = m.buildFlagRecord(tags: ['cooler', 'bluff', 'review', 'mistake']);
      expect(stub.completeness, HandCompleteness.flagged);
      expect(stub.statsApplied, isFalse);
      expect(stub.actions, isEmpty);
      expect((stub.flagMeta!['tags'] as List).length, 3);
      expect(stub.flagMeta!['heroStackBB'], 100.0);
      expect(heroModeFor(stub.completeness), HeroStatsMode.none);
    });

    test('flag via recordFlag persists once, counts open flags', () async {
      final m = manager();
      final saved = <HandRecord>[];
      m.persistOverride = (h) async => saved.add(h);
      await m.recordFlag(tags: ['cooler']);
      expect(saved.single.completeness, HandCompleteness.flagged);
      expect(m.flagsOpenCount, 1);
      m.flagResolved();
      expect(m.flagsOpenCount, 0);
      m.flagResolved();
      expect(m.flagsOpenCount, 0);
    });

    test('fold tick: totalsOnly mode, synthetic hero fold, real numbers', () async {
      final m = manager();
      final saved = <HandRecord>[];
      m.persistOverride = (h) async => saved.add(h);
      m.startHand(5, 2);
      final a = await m.recordFoldTick();
      final b = await m.recordFoldTick(); // no hand in progress now
      expect(a.handNumber, 5);
      expect(b.handNumber, 6, reason: 'ticks take real incremented numbers');
      expect(a.completeness, HandCompleteness.foldTick);
      expect(a.actions.single.synthetic, isTrue);
      expect(a.actions.single.isCurrentUser, isTrue);
      expect(m.skippedHands, 2);
      expect(m.foldTickCount, 2);
      expect(m.completedHands, isEmpty);
      expect(heroModeFor(a.completeness), HeroStatsMode.totalsOnly);
      expect(HeroHandDelta.foldTick.totalHands, 1);
    });

    test('enqueue + undo: nothing persisted, counters untouched', () async {
      final m = manager();
      final saved = <HandRecord>[];
      m.persistOverride = (h) async => saved.add(h);
      m.startHand(9, 2);
      m.enqueueFoldTick();
      expect(m.currentHand, isNull);
      expect(m.undoLastFoldTick(), isTrue);
      expect(m.currentHand?.handNumber, 9);
      await m.foldTickQueue.flushAll();
      expect(saved, isEmpty);
      expect(m.skippedHands, 0);
      expect(m.foldTickCount, 0);
    });

    test('enqueue then flush commits once with the frozen hand number', () async {
      final m = manager();
      final saved = <HandRecord>[];
      m.persistOverride = (h) async => saved.add(h);
      m.startHand(9, 2);
      m.enqueueFoldTick();
      m.startHand(10, 3); // screen advanced immediately
      await m.foldTickQueue.flushAll();
      expect(saved.single.handNumber, 9);
      expect(m.skippedHands, 1);
      expect(m.currentHand?.handNumber, 10);
    });

    test('nextHandNumber covers current, ticks, stubs and completed hands', () async {
      final m = manager();
      m.persistOverride = (h) async {};
      expect(m.nextHandNumber, 1);
      m.startHand(4, 2);
      expect(m.nextHandNumber, 5);
      await m.recordFoldTick(); // hand 4 consumed
      expect(m.nextHandNumber, 5);
      await m.recordFlag(); // no hand in progress -> takes 5
      expect(m.nextHandNumber, 6);
      m.startHand(6, 3);
      expect(m.nextHandNumber, 7);
    });

    test('reconstructed goes through full stats mode, opponents off', () async {
      final m = manager();
      final saved = <HandRecord>[];
      m.persistOverride = (h) async => saved.add(h);
      final built = _completed(c: HandCompleteness.full);
      await m.recordReconstructed(built);
      expect(saved.single.completeness, HandCompleteness.reconstructed);
      expect(heroModeFor(saved.single.completeness), HeroStatsMode.full);
      expect(opponentsFeedFor(saved.single.completeness),
          kReconstructedFeedsOpponents);
    });
  });
}
