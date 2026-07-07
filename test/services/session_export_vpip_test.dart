import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/session_export_service.dart';

/// Session export VPIP/PFR must count hands the hero folded preflop and
/// SKIPPED (no hand record) — via the session's skippedHands counter.
/// Repro: 27 logged hands, all played → export claimed VPIP 100%.
void main() {
  Map<String, dynamic> session({int skipped = 0}) => {
        'sessionName': 'Poczekalnia Monday',
        'gameType': 'tournament',
        'smallBlind': 600.0,
        'bigBlind': 1200.0,
        'startTime': '2026-07-06T19:00:00.000',
        'endTime': '2026-07-06T21:33:00.000',
        'startingStack': 50000.0,
        'currentStack': 151950.0,
        'totalBuyIn': 50000.0,
        if (skipped > 0) 'skippedHands': skipped,
      };

  Map<String, dynamic> hand({
    required int number,
    required String heroPreflopAction,
    int heroSeat = 4,
    int winnerId = 1,
  }) =>
      {
        'handNumber': number,
        'heroSeatNumber': heroSeat,
        'winnerId': winnerId,
        'potAmount': 10000.0,
        'actions': [
          {
            'player': heroSeat,
            'action': heroPreflopAction,
            'street': 'preflop',
            'amount': heroPreflopAction == 'fold' ? null : 3000.0,
          },
        ],
      };

  test('skipped hands widen the VPIP/PFR denominator', () {
    final hands = [
      hand(number: 1, heroPreflopAction: 'call'),
      hand(number: 2, heroPreflopAction: 'raise'),
      hand(number: 3, heroPreflopAction: 'fold'),
    ];
    final text = SessionExportService.generateStatsSummary(
        session(skipped: 7), hands);

    // 2 VPIP hands over 10 dealt (3 logged + 7 skipped) = 20%; PFR 1/10.
    expect(text, contains('VPIP: 20.0% | PFR: 10.0%'));
    expect(text, contains('Hands Dealt: 10 (3 logged, 7 folded & skipped)'));
  });

  test('without skips, denominator is logged hands (fold still counts)', () {
    final hands = [
      hand(number: 1, heroPreflopAction: 'call'),
      hand(number: 2, heroPreflopAction: 'raise'),
      hand(number: 3, heroPreflopAction: 'fold'),
    ];
    final text = SessionExportService.generateStatsSummary(session(), hands);

    expect(text, contains('VPIP: 66.7% | PFR: 33.3%'));
    expect(text, contains('Hands Played: 3'));
    expect(text, isNot(contains('Hands Dealt:')));
  });

  test('the reported session shape: all logged hands played + skips', () {
    // 27 logged hands where hero always entered the pot, 14 skipped folds:
    // old output said VPIP 100%; with the counter it's 27/41 = 65.9%.
    final hands = List.generate(
        27, (i) => hand(number: i + 1, heroPreflopAction: 'raise'));
    final text = SessionExportService.generateStatsSummary(
        session(skipped: 14), hands);

    expect(text, contains('VPIP: 65.9%'));
    expect(text, isNot(contains('VPIP: 100.0%')));
  });
}
