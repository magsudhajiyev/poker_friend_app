import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/models/game_types.dart';
import 'package:poker_logger/models/hand_state_machine.dart';
import 'package:poker_logger/models/poker_game_state.dart';
import 'package:poker_logger/services/hand_flag_service.dart';
import 'package:poker_logger/services/hand_promotion_service.dart';
import 'package:poker_logger/services/recall_finisher.dart';
import 'package:poker_logger/widgets/easy_logging/stack_prompt_sheet.dart';

PokerSessionManager _sm() {
  final sm = PokerSessionManager(
      smallBlind: 1, bigBlind: 2, playerCount: 6, gameType: GameType.cash);
  sm.ourSeatNumber = 4;
  sm.activeSeats.addAll([1, 2, 3, 4, 5, 6]);
  sm.playerStacks[4] = 200;
  sm.persistOverride = (r) async {
    r.cloudHandId = 'cloud${r.handNumber}';
  };
  sm.startHand(1, 1, sbSeat: 2, bbSeat: 3);
  return sm;
}

class _Writer implements HandStatsWriter {
  @override
  Future<void> applyPromotedStats(HandRecord hand) async {}
  @override
  Future<void> incrementSessionTotalHands(String sessionId) async {}
}

class _Store implements PromotionStore {
  Map<String, dynamic>? fields;
  @override
  Future<bool> claim(
      {required String sessionId,
      required String cloudHandId,
      required Map<String, dynamic> fields}) async {
    this.fields = fields;
    return true;
  }

  @override
  Future<void> mirrorLocal(
      {required String localHandId,
      required Map<String, dynamic> fields}) async {}
  @override
  void markCachesDirty() {}
}

void main() {
  group('fold_run', () {
    test('consecutive ticks coalesce into one entry', () async {
      final sm = _sm();
      final t1 = sm.enqueueFoldTick();
      sm.noteFoldTickStack(t1, before: 200, after: 198);
      sm.startHand(2, 2, sbSeat: 3, bbSeat: 4);
      final t2 = sm.enqueueFoldTick();
      sm.noteFoldTickStack(t2, before: 198, after: 196);
      await sm.foldTickQueue.flushAll();

      final runs =
          sm.stackHistory.where((e) => e['changeType'] == 'fold_run').toList();
      expect(runs.length, 1);
      expect(runs.single['count'], 2);
      expect(runs.single['handNumber'], 2);
      expect(runs.single['stackSize'], 196.0);
      expect(runs.single['changeAmount'], 4.0);
    });

    test('a full hand between ticks starts a new run', () async {
      final sm = _sm();
      final t1 = sm.enqueueFoldTick();
      sm.noteFoldTickStack(t1, before: 200, after: 199);
      await sm.foldTickQueue.flushAll();
      sm.stackHistory.add({'changeType': 'win', 'stackSize': 210.0});
      final t2 = sm.enqueueFoldTick();
      sm.noteFoldTickStack(t2, before: 210, after: 208);
      await sm.foldTickQueue.flushAll();
      expect(sm.stackHistory.where((e) => e['changeType'] == 'fold_run').length, 2);
    });

    test('a tick without a stack writes no history', () async {
      final sm = _sm();
      sm.enqueueFoldTick();
      await sm.foldTickQueue.flushAll();
      expect(sm.stackHistory, isEmpty);
    });
  });

  group('pending', () {
    test('flag writes a pending entry from the table snapshot', () async {
      final sm = _sm();
      final rec = await sm.recordFlag(tableSnapshot: {
        'heroSeat': 4,
        'seats': [
          {'seat': 4, 'active': true, 'stack': 180}
        ],
      });
      final e = sm.stackHistory.single;
      expect(e['changeType'], 'pending');
      expect(e['handNumber'], rec.handNumber);
      expect(e['stackSize'], 180.0);
      expect(e['flagId'], 'cloud1');
      expect(e['bigBlind'], 2);
    });

    test('discard marks the pending entry', () async {
      final sm = _sm();
      await sm.recordFlag();
      await sm.markFlagDiscarded('cloud1');
      expect(sm.stackHistory.single['discarded'], isTrue);
    });
  });

  group('rebuy', () {
    test('flag off: legacy hand number, no stackBefore key', () {
      final sm = _sm();
      sm.addRebuy(amount: 100, stack: 150);
      final e = sm.stackHistory.last;
      expect(e['handNumber'], 1); // completedHands.length + 1
      expect(e.containsKey('stackBefore'), isFalse);
    });

    test('after non-full hands: real sequence and stackBefore', () async {
      final sm = _sm();
      sm.enqueueFoldTick();
      sm.startHand(2, 2, sbSeat: 3, bbSeat: 4);
      await sm.recordFlag();
      sm.startHand(3, 3, sbSeat: 4, bbSeat: 5);
      sm.addRebuy(amount: 100, stack: 150, stackBefore: 12);
      final e = sm.stackHistory.last;
      expect(e['handNumber'], sm.nextHandNumber);
      expect(e['stackBefore'], 12);
    });
  });

  test('lastHandNumber ignores a dealt hand with no action', () async {
    final sm = _sm();
    expect(sm.lastHandNumber, 0);
    sm.enqueueFoldTick();
    sm.startHand(2, 2, sbSeat: 3, bbSeat: 4);
    expect(sm.lastHandNumber, 1);
  });

  test('flag-off full hand writes exactly today\'s entries', () {
    final sm = _sm();
    sm.completeCurrentHand(potAmount: 10, winnerId: 4, currentStack: 205);
    expect(sm.stackHistory.map((e) => e['changeType']).toList(),
        ['initial']);
    expect(sm.stackHistory.single.keys.toSet(),
        {'timestamp', 'stackSize', 'changeType', 'changeAmount', 'handNumber'});
  });

  group('final anchor from the session-end sheet', () {
    test('rewrites the last final entry', () async {
      final sm = _sm();
      sm.stackHistory.add({'changeType': 'initial', 'stackSize': 200.0});
      sm.addFinalStackEntry(150); // live stack, ignores a flagged win
      await sm.applyFinalStackAnchor(320);
      final f = sm.stackHistory.last;
      expect(f['changeType'], 'final');
      expect(f['stackSize'], 320);
      expect(f['changeAmount'], 120);
      expect(sm.stackHistory.where((e) => e['changeType'] == 'final').length, 1);
    });

    test('adds a final entry when none was written', () async {
      final sm = _sm();
      sm.stackHistory.add({'changeType': 'initial', 'stackSize': 200.0});
      await sm.applyFinalStackAnchor(260);
      expect(sm.stackHistory.last['changeType'], 'final');
      expect(sm.stackHistory.last['stackSize'], 260);
    });

    test('flag off: addFinalStackEntry is unchanged', () {
      final sm = _sm();
      sm.stackHistory.add({'changeType': 'initial', 'stackSize': 200.0});
      sm.addFinalStackEntry(200);
      expect(sm.stackHistory.length, 1); // equal stack: no entry, as today
      sm.addFinalStackEntry(230);
      expect(sm.stackHistory.last['changeAmount'], 30);
    });
  });

  test('a local SQLite failure never blocks ending the session', () async {
    final sm = _sm()..sessionId = 'offline_s1';
    // No sqflite factory in tests: the local update throws internally.
    await sm.endSession();
    expect(sm.sessionState, SessionState.ended);
  });

  group('recall delta', () {
    test('heroDelta and source ride the promotion fields', () async {
      final store = _Store();
      final service = HandPromotionService(stats: _Writer(), store: store);
      final hand = HandRecord(
          handNumber: 3, buttonPosition: 1, playerCount: 6, startTime: DateTime.now());
      hand.actions.add(ActionRecord(
        player: 4,
        action: PlayerAction.raise,
        street: BettingRound.preflop,
        timestamp: DateTime.now(),
        buttonPosition: 1,
        isCurrentUser: true,
        amount: 6,
      ));
      final ref = FlaggedHandRef(
          sessionId: 's', handNumber: 3, cloudId: 'c3', flagMeta: {
        'flaggedAt': DateTime.now().toIso8601String(),
        'bigBlind': 2.0,
      });
      final r = await RecallFinisher.finish(
          ref: ref, hand: hand, service: service, heroDelta: -37.5);
      expect(r!.promoted, isTrue);
      final flag = store.fields!['flag'] as Map;
      expect(flag['heroDelta'], -37.5);
      expect(flag['heroDeltaSource'], 'recall');
      expect(flag['bigBlind'], 2.0);
    });
  });

  testWidgets('StackPromptBody returns the typed stack', (t) async {
    double? got;
    await t.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
          body: StackPromptBody(body: 'b', liveStack: 120, onSaved: (v) => got = v)),
    ));
    await t.enterText(find.byType(TextField), '95');
    await t.tap(find.text('Save'));
    expect(got, 95);
  });
}
