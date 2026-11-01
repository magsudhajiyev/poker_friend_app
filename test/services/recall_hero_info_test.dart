import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/hand_state_machine.dart';
import 'package:poker_logger/services/flag_resolution_loader.dart';
import 'package:poker_logger/services/hand_flag_service.dart';
import 'package:poker_logger/services/hand_promotion_service.dart';
import 'package:poker_logger/services/recall_finisher.dart';
import 'package:poker_logger/widgets/stack_growth_chart.dart';

HandRecord _bare() => HandRecord(
      handNumber: 7,
      buttonPosition: 1,
      playerCount: 6,
      startTime: DateTime.utc(2026, 11, 1),
    );

void main() {
  const ref = FlaggedHandRef(
    sessionId: 's',
    handNumber: 7,
    heroPositionName: 'CO',
    heroCards: {'card1': 'A♠', 'card2': 'K♦'},
  );

  test('backfill adds stub cards + position when the manager lost them', () {
    final h = _bare();
    RecallFinisher.backfillHeroInfo(h, ref);
    final f = HandPromotionService.promotionFields(h);
    expect(f['heroPositionName'], 'CO');
    expect((f['ourHoleCards'] as Map)['card1'], 'A♠');
  });

  test('backfill never overwrites recalled values', () {
    final h = _bare()
      ..heroPositionName = 'BTN'
      ..ourHoleCards = HoleCards(card1: 'Q♥', card2: 'Q♣');
    RecallFinisher.backfillHeroInfo(h, ref);
    expect(h.heroPositionName, 'BTN');
    expect(h.ourHoleCards!.card1, 'Q♥');
  });

  test('chart lookup finds a promoted doc when live list lacks the hand', () {
    final lookup = handLookupChain(
      handLookupFromRecords(const []),
      handLookupFromMaps([
        {
          'handNumber': 7,
          'heroPositionName': 'CO',
          'ourHoleCards': {'card1': 'A♠', 'card2': 'K♦'},
        }
      ]),
    );
    final info = lookup(7)!;
    expect(info.position, 'CO');
    expect(info.hasCards, isTrue);
    expect(lookup(8), isNull);
  });

  test('loadAll returns resolved hand docs only', () async {
    final history = [
      {'changeType': 'pending', 'flagId': 'a', 'handNumber': 7},
      {'changeType': 'pending', 'flagId': 'b', 'handNumber': 8},
    ];
    final r = await FlagResolutionLoader.loadAll('s', history, fetch: (s, id) async {
      return id == 'a'
          ? {
              'handNumber': 7,
              'ourHoleCards': {'card1': 'A♠', 'card2': 'K♦'},
              'flag': {'heroDelta': 5.0},
            }
          : {'handNumber': 8, 'flag': <String, dynamic>{}};
    });
    expect(r.resolvedHands.length, 1);
    expect(r.resolvedHands.first['handNumber'], 7);
  });
}
