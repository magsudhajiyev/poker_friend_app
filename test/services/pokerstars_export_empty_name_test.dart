import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/pokerstars_export_service.dart';

/// A seat stored with an EMPTY name must export as "Player {seat}".
/// Repro of hand #101785449031: seat 3 had name '' which produced
/// ": raises 3000 to 5000" and "Seat 3:  (49200 in chips)" — lines that
/// the solver's hand-history parser rejects.
void main() {
  Map<String, dynamic> session() => {
        'sessionName': 'Test MTT',
        'gameType': 'tournament',
        'smallBlind': 1000.0,
        'bigBlind': 2000.0,
        'hasBBante': false,
        'startTime': '2026-07-06T22:28:03.000',
      };

  Map<String, dynamic> hand() => {
        'handNumber': 2,
        'buttonPosition': 6,
        'playerCount': 8,
        'heroSeatNumber': 4,
        'heroPositionName': 'LJ',
        'smallBlind': 1000.0,
        'bigBlind': 2000.0,
        'gameType': 'tournament',
        'winnerId': 6,
        'potAmount': 33000.0,
        'playerNames': {
          '1': 'Jarpo',
          '2': 'Player 2',
          '3': '', // ← the unnamed player
          '4': 'Me',
          '5': 'Player 5',
          '6': 'Finesilver',
          '7': 'Player 7',
          '8': 'Minion',
        },
        'boardCards': {'flop': [], 'turn': null, 'river': null},
        'actions': [
          {'player': 1, 'action': 'fold', 'street': 'preflop', 'playerStack': 49500.0, 'playerPosition': 'UTG'},
          {'player': 2, 'action': 'fold', 'street': 'preflop', 'playerStack': 39600.0, 'playerPosition': 'UTG+1'},
          {'player': 3, 'action': 'raise', 'street': 'preflop', 'amount': 5000.0, 'playerStack': 49200.0, 'playerPosition': 'UTG+2'},
          {'player': 4, 'action': 'call', 'street': 'preflop', 'amount': 5000.0, 'playerStack': 149000.0, 'playerPosition': 'LJ'},
          {'player': 5, 'action': 'fold', 'street': 'preflop', 'playerStack': 233400.0, 'playerPosition': 'HJ'},
          {'player': 6, 'action': 'raise', 'street': 'preflop', 'amount': 18000.0, 'playerStack': 31300.0, 'playerPosition': 'BTN'},
          {'player': 7, 'action': 'fold', 'street': 'preflop', 'playerStack': 132900.0, 'playerPosition': 'SB'},
          {'player': 8, 'action': 'fold', 'street': 'preflop', 'playerStack': 57000.0, 'playerPosition': 'BB'},
          {'player': 3, 'action': 'fold', 'street': 'preflop', 'playerStack': 44200.0, 'playerPosition': 'UTG+2'},
          {'player': 4, 'action': 'fold', 'street': 'preflop', 'playerStack': 144000.0, 'playerPosition': 'LJ'},
        ],
      };

  test('empty player name exports as Player {seat} everywhere', () {
    final text = PokerStarsExportService.exportSession(session(), [hand()]);

    // Seat line carries the placeholder, not a blank.
    expect(text, contains('Seat 3: Player 3 ('));
    expect(text, isNot(contains('Seat 3:  (')));

    // Action lines carry the placeholder.
    expect(text, contains('Player 3: raises'));
    expect(text, contains('Player 3: folds'));

    // No line may start with a bare colon (the the solver rejection).
    for (final line in text.split('\n')) {
      expect(line.trimLeft().startsWith(':'), isFalse,
          reason: 'empty-name action line leaked: "$line"');
    }
  });

  test('whitespace-only and colon-only names also get the placeholder', () {
    final h = hand();
    (h['playerNames'] as Map<String, dynamic>)['3'] = '   ';
    (h['playerNames'] as Map<String, dynamic>)['5'] = ':::';
    final text = PokerStarsExportService.exportSession(session(), [h]);
    expect(text, contains('Seat 3: Player 3 ('));
    expect(text, contains('Seat 5: Player 5 ('));
    for (final line in text.split('\n')) {
      expect(line.trimLeft().startsWith(':'), isFalse);
    }
  });

  test('named players are untouched', () {
    final text = PokerStarsExportService.exportSession(session(), [hand()]);
    expect(text, contains('Seat 6: Finesilver ('));
    expect(text, contains('Seat 4: Hero (')); // hero renamed as always
  });
}
