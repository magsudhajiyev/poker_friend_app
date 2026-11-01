import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/flag_table_snapshot.dart';
import 'package:poker_logger/models/game_types.dart';
import 'package:poker_logger/models/hand_completeness.dart';
import 'package:poker_logger/models/hand_state_machine.dart';
import 'package:poker_logger/models/poker_game_state.dart';
import 'package:poker_logger/services/hand_flag_service.dart';
import 'package:poker_logger/services/hand_promotion_service.dart';
import 'package:poker_logger/services/recall_finisher.dart';

class _Writer implements HandStatsWriter {
  int applied = 0;
  int bumps = 0;
  @override
  Future<void> applyPromotedStats(HandRecord hand) async => applied++;
  @override
  Future<void> incrementSessionTotalHands(String sessionId) async => bumps++;
}

class _Store implements PromotionStore {
  bool claimed = false;
  @override
  Future<bool> claim(
      {required String sessionId,
      required String cloudHandId,
      required Map<String, dynamic> fields}) async {
    if (claimed) return false;
    claimed = true;
    return true;
  }

  @override
  Future<void> mirrorLocal(
      {required String localHandId,
      required Map<String, dynamic> fields}) async {}
  @override
  void markCachesDirty() {}
}

PokerGameState _game() {
  final g = PokerGameState(
      numberOfPlayers: 9,
      smallBlind: 1,
      bigBlind: 2,
      isCashGame: true,
      hasBBante: false);
  for (final s in [1, 2, 3, 4]) {
    g.setPlayerActive(s, true);
    g.setPlayerStack(s, 200);
  }
  g.buttonPosition = 1;
  g.finalizeInitialization();
  g.initializePot();
  return g;
}

PokerSessionManager _live(PokerGameState g) {
  final sm = PokerSessionManager(
      smallBlind: 1, bigBlind: 2, playerCount: 4, gameType: GameType.cash);
  sm.sessionId = 'live1';
  sm.ourSeatNumber = 4;
  sm.activeSeats.addAll([1, 2, 3, 4]);
  sm.setPlayerName(2, 'Villain');
  sm.playerIds[2] = 'opp-2';
  sm.startHand(7, 1, sbSeat: 2, bbSeat: 3);
  return sm;
}

void main() {
  group('FlagTableSnapshot', () {
    test('captures start-of-hand stacks, names, ids and positions', () {
      final g = _game();
      final sm = _live(g);
      final snap = FlagTableSnapshot.capture(sm, g);
      expect(snap.buttonPosition, 1);
      expect(snap.heroSeat, 4);
      expect(snap.bigBlind, 2);
      final sb = snap.seats[1]; // seat 2 posted the small blind
      expect(sb.active, isTrue);
      expect(sb.stack, 200); // blind added back
      expect(sb.name, 'Villain');
      expect(sb.playerId, 'opp-2');
      expect(sb.position, isNotNull);
      expect(snap.seats[8].active, isFalse);
    });

    test('round-trips through Firestore map and SQLite JSON', () {
      final g = _game();
      final sm = _live(g);
      final snap = FlagTableSnapshot.capture(sm, g);
      final rec = sm.buildFlagRecord(tableSnapshot: snap.toMap());

      // Firestore: HandRecord map in, map out.
      final fromCloud = HandRecord.fromMap(rec.toMap());
      expect(fromCloud.flagMeta!['table'], isA<Map>());

      // SQLite: flagMeta is stored as a JSON string.
      final sqlite = jsonDecode(jsonEncode(rec.flagMeta)) as Map<String, dynamic>;

      for (final meta in [fromCloud.flagMeta!, sqlite]) {
        final ref = FlaggedHandRef.fromMap('s', {'handNumber': 7, 'flag': meta});
        final back = ref.table!;
        expect(back.toMap(), snap.toMap());
        expect(back.seats[1].name, 'Villain');
      }
    });

    test('legacy stubs get a usable table', () {
      final t = FlagTableSnapshot.fromLegacyMeta({
        'stacks': {'1': 100.0, '4': 250.0},
        'bigBlind': 2.0,
        'smallBlind': 1.0,
        'gameType': 'cash',
      });
      expect(t.seats.where((s) => s.active).length, 2);
      expect(t.heroSeat, 1);
    });
  });

  group('recall save', () {
    test('promotes once and never touches the live session', () async {
      final g = _game();
      final live = _live(g);
      final liveHand = live.currentHand;
      final liveStackHistory = List.of(live.stackHistory);

      // Throw-away recall manager: no session id.
      final recall = PokerSessionManager(
          smallBlind: 1, bigBlind: 2, playerCount: 4, gameType: GameType.cash)
        ..isRecall = true
        ..ourSeatNumber = 4;
      recall.activeSeats.addAll([1, 2, 3, 4]);
      recall.startHand(12, 1, sbSeat: 2, bbSeat: 3);
      for (final (seat, act) in [(4, PlayerAction.raise), (1, PlayerAction.fold)]) {
        recall.currentHand!.actions.add(ActionRecord(
          player: seat,
          action: act,
          street: BettingRound.preflop,
          timestamp: DateTime.now(),
          buttonPosition: 1,
          isCurrentUser: seat == 4,
          amount: act == PlayerAction.raise ? 6 : null,
        ));
      }
      recall.completeCurrentHand(potAmount: 9, winnerId: 4);
      final hand = recall.lastFinishedHand!;
      expect(recall.sessionId, isNull);
      expect(hand.handNumber, 12);

      final writer = _Writer();
      final service = HandPromotionService(stats: writer, store: _Store());
      final ref = FlaggedHandRef(
          sessionId: 'live1',
          handNumber: 12,
          cloudId: 'c12',
          localId: 'l12',
          flagMeta: {
            'flaggedAt': DateTime.now().toIso8601String(),
            'bigBlind': 2.0,
            'gameType': 'cash',
          });

      final r1 = await RecallFinisher.finish(ref: ref, hand: hand, service: service);
      final r2 = await RecallFinisher.finish(ref: ref, hand: hand, service: service);

      expect(r1!.promoted, isTrue);
      expect(r2!.status, PromotionStatus.alreadyCounted);
      expect(writer.applied, 1);
      expect(hand.completeness, HandCompleteness.reconstructed);
      expect(hand.flagMeta!['bigBlind'], 2.0);

      // Live session: untouched.
      expect(identical(live.currentHand, liveHand), isTrue);
      expect(live.completedHands, isEmpty);
      expect(live.stackHistory, liveStackHistory);
      expect(live.skippedHands, 0);
      expect(live.foldTickCount, 0);
      expect(live.sessionId, 'live1');
      expect(live.nextHandNumber, 8);
    });

    test('nothing to promote without a hand or cloud id', () async {
      final ref = FlaggedHandRef(sessionId: 's', handNumber: 1);
      expect(await RecallFinisher.finish(ref: ref, hand: null), isNull);
    });
  });
}
