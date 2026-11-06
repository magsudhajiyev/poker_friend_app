import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/pokerstars_export_service.dart';

/// Hands saved with the real blinds (bbSeat / sbSeat / smallBlindDead) export
/// exactly those blinds, even in dead SB / dead button hands. Hands without the
/// fields use the old label / button fallbacks, unchanged.
void main() {
  Map<String, dynamic> session() => {
        'sessionName': 'Cash',
        'gameType': 'cash',
        'smallBlind': 1.0,
        'bigBlind': 2.0,
        'hasBBante': false,
        'startTime': '2026-11-06T20:00:00.000',
      };

  Map<String, dynamic> act(int p, String a, [String? pos, double? amount]) => {
        'player': p,
        'action': a,
        'street': 'preflop',
        if (pos != null) 'playerPosition': pos,
        if (amount != null) 'amount': amount,
      };

  Map<String, dynamic> hand({
    required int button,
    required List<int> seats,
    required List<Map<String, dynamic>> actions,
    Map<String, dynamic> extra = const {},
  }) =>
      {
        'handNumber': 2,
        'buttonPosition': button,
        'playerCount': 6,
        'heroSeatNumber': 1,
        'smallBlind': 1.0,
        'bigBlind': 2.0,
        'gameType': 'cash',
        'winnerId': seats.last,
        'potAmount': 3.0,
        'playerNames': {for (final s in seats) '$s': 'P$s'},
        'boardCards': {'flop': [], 'turn': null, 'river': null},
        'actions': actions,
        ...extra,
      };

  List<String> posts(String text) =>
      text.split('\n').where((l) => l.contains('posts')).toList();

  test('(a) dead button + dead SB (BTN2 empty, SB3 empty, BB4)', () {
    final h = hand(
      button: 2,
      seats: [1, 4, 5, 6],
      actions: [act(5, 'fold'), act(6, 'fold'), act(1, 'fold'), act(4, 'check')],
      extra: {'bbSeat': 4, 'smallBlindDead': true},
    );
    final text = PokerStarsExportService.exportSession(session(), [h]);
    expect(posts(text), ['P4: posts big blind 2']);
    expect(text, contains('Seat #2 is the button'));
  });

  test('(b) dead-SB walk: BB never acts, nobody posts the SB', () {
    final h = hand(
      button: 2,
      seats: [1, 2, 4, 5, 6],
      actions: [act(5, 'fold'), act(6, 'fold'), act(1, 'fold'), act(2, 'fold')],
      extra: {'bbSeat': 4, 'smallBlindDead': true},
    );
    final text = PokerStarsExportService.exportSession(session(), [h]);
    expect(posts(text), ['P4: posts big blind 2']);
  });

  test('dead button, live SB: both post, empty seat is the button', () {
    final h = hand(
      button: 3,
      seats: [1, 2, 4, 5, 6],
      actions: [act(6, 'fold'), act(1, 'fold'), act(2, 'fold'), act(4, 'fold')],
      extra: {'bbSeat': 5, 'sbSeat': 4},
    );
    final text = PokerStarsExportService.exportSession(session(), [h]);
    expect(posts(text),
        ['P4: posts small blind 1', 'P5: posts big blind 2']);
    expect(text, contains('Seat #3 is the button'));
    expect(text, isNot(contains('Seat 3:')));
  });

  test('old hand without the fields exports as before (label / button paths)',
      () {
    final labelled = hand(
      button: 2,
      seats: [1, 2, 3, 4, 5, 6],
      actions: [
        act(4, 'fold', 'UTG'),
        act(5, 'fold', 'HJ'),
        act(6, 'fold', 'CO'),
        act(1, 'fold', 'BTN'),
        act(2, 'fold', 'SB'),
        act(3, 'check', 'BB'),
      ],
    );
    final withFields = {
      ...labelled,
      'bbSeat': 3,
      'sbSeat': 2,
    };
    final old = PokerStarsExportService.exportSession(session(), [labelled]);
    expect(posts(old), ['P2: posts small blind 1', 'P3: posts big blind 2']);
    // New-style fields that say the same thing give the same history.
    expect(PokerStarsExportService.exportSession(session(), [withFields]), old);

    final noLabels = hand(
      button: 3,
      seats: [1, 2, 4, 5, 6],
      actions: [{'player': 6, 'action': 'fold', 'street': 'preflop'}],
    );
    final t = PokerStarsExportService.exportSession(session(), [noLabels]);
    expect(posts(t), ['P4: posts small blind 1', 'P5: posts big blind 2']);
  });
}
