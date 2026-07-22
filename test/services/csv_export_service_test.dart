import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/csv_export_service.dart';
import 'package:poker_logger/models/game_types.dart';
import '../fixtures/mock_hand_actions.dart';

void main() {
  group('CSVExportService', () {
    late CSVExportService csvExportService;

    setUp(() {
      csvExportService = CSVExportService();
    });

    group('Single Hand Export', () {
      test('exports basic cash game hand correctly', () {
        final handData = {
          'handNumber': 1,
          'gameType': 'cash',
          'smallBlind': 1,
          'bigBlind': 2,
          'buttonPosition': 5,
          'playerCount': 6,
          'heroSeatNumber': 3,
          'heroPositionName': 'MP',
          'potAmount': 24.0,
          'preflopPot': 12.0,
          'flopPot': 18.0,
          'turnPot': 20.0,
          'riverPot': 24.0,
          'ourHoleCards': {'card1': 'A♠', 'card2': 'K♥'},
          'boardCards': {
            'flop': ['Q♦', 'J♠', '10♣'],
            'turn': '9♥',
            'river': '8♦'
          },
          'winnerId': 3,
          'reachedShowdown': true,
          'playerNames': {
            '1': 'Alice',
            '2': 'Bob',
            '3': 'Hero',
            '4': 'Dave',
            '5': 'Eve',
            '6': 'Frank'
          },
          'actions': [
            ...MockHandActions.blindsOnly(sbPlayer: 1, bbPlayer: 2),
            MockHandActions.raise(3, 6.0, street: 'preflop', position: 'MP'),
            MockHandActions.call(4, 6.0, street: 'preflop', position: 'CO'),
            MockHandActions.fold(5, street: 'preflop', position: 'BTN'),
            MockHandActions.fold(6, street: 'preflop', position: 'SB'),
            MockHandActions.fold(1, street: 'preflop', position: 'BB'),
            MockHandActions.bet(3, 8.0, street: 'flop', position: 'MP'),
            MockHandActions.call(4, 8.0, street: 'flop', position: 'CO'),
            MockHandActions.bet(3, 12.0, street: 'turn', position: 'MP'),
            MockHandActions.fold(4, street: 'turn', position: 'CO'),
          ]
        };

        final csv = csvExportService.exportHandToCsv(handData);
        final lines = csv.split('\n');

        // Check header
        expect(lines[0], 'Hand#,Street,Seat,Player,Action,Amount,Pot,Board,HoleCards');

        // Check some key data rows (blinds don't accumulate into the Pot
        // column; hole cards only appear on hero's rows)
        expect(lines[1], '1,preflop,1,Alice,small blind,1.0,0.0,,');
        expect(lines[2], '1,preflop,2,Bob,big blind,2.0,0.0,,');
        expect(lines[3], '1,preflop,3,Hero,raise,6.0,6.0,,A♠K♥');

        // Check flop with board cards
        expect(lines.any((line) => line.contains('flop') && line.contains('Q♦J♠10♣')), isTrue);

        // Check turn with additional board card
        expect(lines.any((line) => line.contains('turn') && line.contains('Q♦J♠10♣9♥')), isTrue);

        // Hand ends on the turn (fold), so no river rows are emitted
        expect(lines.any((line) => line.contains('river')), isFalse);
      });

      test('exports tournament hand correctly', () {
        final handData = {
          'handNumber': 25,
          'gameType': 'tournament',
          'smallBlind': 50,
          'bigBlind': 100,
          'buttonPosition': 2,
          'playerCount': 4,
          'heroSeatNumber': 1,
          'heroPositionName': 'SB',
          'potAmount': 400.0,
          'ourHoleCards': {'card1': 'Q♣', 'card2': 'Q♠'},
          'boardCards': {
            'flop': ['A♥', '7♦', '2♣'],
            'turn': 'K♠',
            'river': '5♥'
          },
          'winnerId': 3,
          'playerNames': {
            '1': 'Hero',
            '2': 'Player2',
            '3': 'Player3',
            '4': 'Player4'
          },
          'actions': [
            MockHandActions.smallBlind(1, 50.0),
            MockHandActions.bigBlind(2, 100.0),
            MockHandActions.raise(3, 300.0, street: 'preflop'),
            MockHandActions.fold(4, street: 'preflop'),
            MockHandActions.fold(1, street: 'preflop'),
            MockHandActions.call(2, 300.0, street: 'preflop'),
          ]
        };

        final csv = csvExportService.exportHandToCsv(handData);
        final lines = csv.split('\n');

        expect(lines[0], 'Hand#,Street,Seat,Player,Action,Amount,Pot,Board,HoleCards');
        expect(lines[1], '25,preflop,1,Hero,small blind,50.0,0.0,,Q♣Q♠');
        expect(lines[2], '25,preflop,2,Player2,big blind,100.0,0.0,,');
        expect(lines[3], '25,preflop,3,Player3,raise,300.0,300.0,,');
      });

      test('handles chopped pot correctly', () {
        final handData = {
          'handNumber': 10,
          'gameType': 'cash',
          'smallBlind': 2,
          'bigBlind': 5,
          'buttonPosition': 4,
          'playerCount': 3,
          'heroSeatNumber': 2,
          'potAmount': 100.0,
          'isChoppedPot': true,
          'choppedWinners': [2, 3],
          'sharePerWinner': 50.0,
          'individualShares': {2: 50.0, 3: 50.0},
          'ourHoleCards': {'card1': 'A♦', 'card2': 'A♣'},
          'boardCards': {
            'flop': ['K♥', 'Q♠', 'J♦'],
            'turn': '10♥',
            'river': '9♠'
          },
          'playerNames': {
            '1': 'Player1',
            '2': 'Hero',
            '3': 'Player3'
          },
          'actions': [
            MockHandActions.smallBlind(1, 2.0),
            MockHandActions.bigBlind(2, 5.0),
            MockHandActions.raise(3, 15.0, street: 'preflop'),
            MockHandActions.call(1, 15.0, street: 'preflop'),
            MockHandActions.call(2, 15.0, street: 'preflop'),
            MockHandActions.check(1, street: 'flop'),
            MockHandActions.bet(2, 25.0, street: 'flop'),
            MockHandActions.call(3, 25.0, street: 'flop'),
            MockHandActions.fold(1, street: 'flop'),
          ]
        };

        final csv = csvExportService.exportHandToCsv(handData);

        // Should include metadata about chopped pot
        expect(csv, contains('CHOPPED POT'));
        expect(csv, contains('Winners: Hero,Player3'));
        expect(csv, contains('Share per winner: \$50.00'));
      });

      test('handles missing data gracefully', () {
        final handData = {
          'handNumber': 5,
          'gameType': 'cash',
          'smallBlind': 1,
          'bigBlind': 2,
          'playerCount': 2,
          'heroSeatNumber': 1,
          'potAmount': 10.0,
          // Missing: buttonPosition, heroPositionName, boardCards, ourHoleCards
          'playerNames': {
            '1': 'Hero',
            '2': 'Opponent'
          },
          'actions': [
            MockHandActions.smallBlind(1, 1.0),
            MockHandActions.bigBlind(2, 2.0),
            MockHandActions.raise(1, 6.0, street: 'preflop'),
            MockHandActions.fold(2, street: 'preflop'),
          ]
        };

        final csv = csvExportService.exportHandToCsv(handData);
        final lines = csv.split('\n');

        expect(lines[0], 'Hand#,Street,Seat,Player,Action,Amount,Pot,Board,HoleCards');
        expect(lines[1], '5,preflop,1,Hero,small blind,1.0,0.0,,');
        expect(lines[2], '5,preflop,2,Opponent,big blind,2.0,0.0,,');
        expect(lines[3], '5,preflop,1,Hero,raise,6.0,6.0,,');
        expect(lines[4], '5,preflop,2,Opponent,fold,0.0,6.0,,');
      });

      test('handles all-in actions correctly', () {
        final handData = {
          'handNumber': 15,
          'gameType': 'tournament',
          'smallBlind': 100,
          'bigBlind': 200,
          'buttonPosition': 3,
          'playerCount': 3,
          'heroSeatNumber': 1,
          'potAmount': 1500.0,
          'ourHoleCards': {'card1': 'A♠', 'card2': 'A♥'},
          'boardCards': {
            'flop': ['8♣', '7♦', '2♠']
          },
          'playerNames': {
            '1': 'Hero',
            '2': 'Villain1',
            '3': 'Villain2'
          },
          'actions': [
            MockHandActions.smallBlind(1, 100.0),
            MockHandActions.bigBlind(2, 200.0),
            {'player': 3, 'action': 'all-in', 'street': 'preflop', 'amount': 1200.0, 'playerName': 'Villain2'},
            {'player': 1, 'action': 'all-in', 'street': 'preflop', 'amount': 800.0, 'playerName': 'Hero'},
            MockHandActions.fold(2, street: 'preflop'),
          ]
        };

        final csv = csvExportService.exportHandToCsv(handData);

        expect(csv, contains('all-in,1200.0'));
        expect(csv, contains('all-in,800.0'));
      });
    });

    group('Multiple Hands Export', () {
      test('exports multiple hands with session metadata', () {
        final sessionData = {
          'sessionName': 'Friday Night Poker',
          'gameType': GameType.cash,
          'smallBlind': 1,
          'bigBlind': 2,
          'startTime': '2024-01-15T20:00:00Z',
          'endTime': '2024-01-16T02:30:00Z',
          'totalHands': 3,
        };

        final hands = [
          {
            'handNumber': 1,
            'gameType': 'cash',
            'smallBlind': 1,
            'bigBlind': 2,
            'potAmount': 20.0,
            'playerNames': {'1': 'Hero', '2': 'Opponent'},
            'actions': [
              MockHandActions.smallBlind(1, 1.0),
              MockHandActions.bigBlind(2, 2.0),
              MockHandActions.raise(1, 6.0, street: 'preflop'),
              MockHandActions.fold(2, street: 'preflop'),
            ]
          },
          {
            'handNumber': 2,
            'gameType': 'cash',
            'smallBlind': 1,
            'bigBlind': 2,
            'potAmount': 15.0,
            'playerNames': {'1': 'Hero', '2': 'Opponent'},
            'actions': [
              MockHandActions.smallBlind(2, 1.0),
              MockHandActions.bigBlind(1, 2.0),
              MockHandActions.call(2, 2.0, street: 'preflop'),
              MockHandActions.check(1, street: 'preflop'),
            ]
          },
          {
            'handNumber': 3,
            'gameType': 'cash',
            'smallBlind': 1,
            'bigBlind': 2,
            'potAmount': 50.0,
            'isChoppedPot': true,
            'choppedWinners': [1, 2],
            'sharePerWinner': 25.0,
            'playerNames': {'1': 'Hero', '2': 'Opponent'},
            'actions': [
              MockHandActions.smallBlind(1, 1.0),
              MockHandActions.bigBlind(2, 2.0),
              MockHandActions.raise(1, 8.0, street: 'preflop'),
              MockHandActions.call(2, 8.0, street: 'preflop'),
            ]
          }
        ];

        final csv = csvExportService.exportSessionToCsv(sessionData, hands);
        final lines = csv.split('\n');

        // Check session metadata header
        expect(lines[0], contains('Friday Night Poker'));
        expect(lines[1], contains('Cash Game'));
        expect(lines[2], contains('Blinds: \$1/\$2'));
        expect(lines[3], contains('Start: 2024-01-15T20:00:00Z'));
        expect(lines[4], contains('End: 2024-01-16T02:30:00Z'));
        expect(lines[5], contains('3 hands'));

        // Check CSV header
        expect(lines.any((line) => line == 'Hand#,Street,Seat,Player,Action,Amount,Pot,Board,HoleCards'), isTrue);

        // Check all hands are included
        expect(csv, contains('1,preflop'));
        expect(csv, contains('2,preflop'));
        expect(csv, contains('3,preflop'));

        // Check chopped pot metadata
        expect(csv, contains('CHOPPED POT'));
      });

      test('handles empty hands list', () {
        final sessionData = {
          'sessionName': 'Empty Session',
          'gameType': GameType.cash,
          'totalHands': 0,
        };

        final csv = csvExportService.exportSessionToCsv(sessionData, []);

        expect(csv, contains('Empty Session'));
        expect(csv, contains('0 hands'));
        expect(csv, contains('Hand#,Street,Seat,Player,Action,Amount,Pot,Board,HoleCards'));
      });
    });

    group('Data Validation and Error Handling', () {
      test('handles null or missing action fields', () {
        final handData = {
          'handNumber': 1,
          'gameType': 'cash',
          'playerNames': {'1': 'Hero', '2': 'Opponent'},
          'actions': [
            {'player': 1, 'action': 'fold'}, // Missing street, amount, playerName
            {'player': 2, 'street': 'preflop'}, // Missing action
            null, // Null action
          ]
        };

        expect(() => csvExportService.exportHandToCsv(handData), isNot(throwsA(anything)));

        final csv = csvExportService.exportHandToCsv(handData);
        expect(csv, contains('Hand#,Street,Seat,Player,Action,Amount,Pot,Board,HoleCards'));
      });

      test('handles missing player names gracefully', () {
        final handData = {
          'handNumber': 1,
          'gameType': 'cash',
          'actions': [
            {'player': 1, 'action': 'fold', 'street': 'preflop'},
            {'player': 2, 'action': 'call', 'street': 'preflop', 'amount': 5.0},
          ]
          // Missing playerNames entirely
        };

        final csv = csvExportService.exportHandToCsv(handData);

        expect(csv, contains('Seat 1')); // Should use fallback naming
        expect(csv, contains('Seat 2'));
      });

      test('handles malformed board cards', () {
        final handData = {
          'handNumber': 1,
          'gameType': 'cash',
          'playerNames': {'1': 'Hero'},
          'boardCards': {
            'flop': 'not-a-list', // Invalid format
            'turn': null,
            'river': ['too', 'many', 'cards'] // Invalid river format
          },
          'actions': [
            MockHandActions.fold(1, street: 'flop'),
          ]
        };

        expect(() => csvExportService.exportHandToCsv(handData), isNot(throwsA(anything)));

        final csv = csvExportService.exportHandToCsv(handData);
        expect(csv, isNotEmpty);
        // Malformed board data degrades to an empty board column
        expect(csv, contains('1,flop,1,Hero,fold,0.0,0.0,,'));
      });

      test('handles very large pot amounts', () {
        final handData = {
          'handNumber': 1,
          'gameType': 'tournament',
          'playerNames': {'1': 'Hero', '2': 'Opponent'},
          'potAmount': 1234567890.50,
          'actions': [
            {'player': 1, 'action': 'bet', 'street': 'river', 'amount': 999999999.99, 'playerName': 'Hero'},
            MockHandActions.call(2, 999999999.99, street: 'river'),
          ]
        };

        final csv = csvExportService.exportHandToCsv(handData);

        expect(csv, contains('999999999.99'));
        expect(csv, contains('1999999999.98')); // Running pot after both actions
      });
    });

    group('Board Cards Formatting', () {
      test('formats complete board correctly', () {
        final handData = {
          'handNumber': 1,
          'boardCards': {
            'flop': ['A♠', 'K♥', 'Q♦'],
            'turn': 'J♣',
            'river': '10♠'
          },
          'playerNames': {'1': 'Hero'},
          'actions': [
            MockHandActions.check(1, street: 'preflop'),
            MockHandActions.check(1, street: 'flop'),
            MockHandActions.check(1, street: 'turn'),
            MockHandActions.check(1, street: 'river'),
          ]
        };

        final csv = csvExportService.exportHandToCsv(handData);

        expect(csv, contains('A♠K♥Q♦')); // Flop street
        expect(csv, contains('A♠K♥Q♦J♣')); // Turn street
        expect(csv, contains('A♠K♥Q♦J♣10♠')); // River street
      });

      test('handles partial board correctly', () {
        final handData = {
          'handNumber': 1,
          'boardCards': {
            'flop': ['2♣', '7♦', '9♥'],
            'turn': null,
            'river': null
          },
          'playerNames': {'1': 'Hero'},
          'actions': [
            MockHandActions.check(1, street: 'preflop'),
            MockHandActions.check(1, street: 'flop'),
          ]
        };

        final csv = csvExportService.exportHandToCsv(handData);

        expect(csv, contains('2♣7♦9♥')); // Only flop cards
        expect(csv, isNot(contains('null')));
      });

      test('handles missing board cards', () {
        final handData = {
          'handNumber': 1,
          'playerNames': {'1': 'Hero'},
          'actions': [
            MockHandActions.fold(1, street: 'preflop'),
          ]
          // No boardCards field
        };

        final csv = csvExportService.exportHandToCsv(handData);

        expect(csv, contains(',,'));  // Empty board column
      });
    });

    group('Hole Cards Formatting', () {
      test('formats hero hole cards correctly', () {
        final handData = {
          'handNumber': 1,
          'heroSeatNumber': 3,
          'ourHoleCards': {'card1': 'A♠', 'card2': 'A♥'},
          'playerNames': {'1': 'Player1', '2': 'Player2', '3': 'Hero'},
          'actions': [
            MockHandActions.fold(1, street: 'preflop'),
            MockHandActions.call(2, 5.0, street: 'preflop'),
            MockHandActions.raise(3, 15.0, street: 'preflop'),
          ]
        };

        final csv = csvExportService.exportHandToCsv(handData);

        // Hero's actions should show hole cards
        expect(csv, contains(',Hero,raise,15.0,20.0,,A♠A♥'));

        // Other players should not show hole cards
        expect(csv, contains(',Player1,fold,0.0,0.0,,'));
        expect(csv, contains(',Player2,call,5.0,5.0,,'));
      });

      test('handles missing hole cards', () {
        final handData = {
          'handNumber': 1,
          'heroSeatNumber': 1,
          'playerNames': {'1': 'Hero'},
          'actions': [
            MockHandActions.fold(1, street: 'preflop'),
          ]
          // No ourHoleCards field
        };

        final csv = csvExportService.exportHandToCsv(handData);

        expect(csv, contains(',Hero,fold,0.0,0.0,,'));
      });
    });

    group('Edge Cases', () {
      test('handles single player hand', () {
        final handData = {
          'handNumber': 1,
          'gameType': 'cash',
          'playerCount': 1,
          'heroSeatNumber': 1,
          'playerNames': {'1': 'Hero'},
          'actions': [], // No actions possible with one player
        };

        final csv = csvExportService.exportHandToCsv(handData);

        expect(csv, contains('Hand#,Street,Seat,Player,Action,Amount,Pot,Board,HoleCards'));
        // Should handle gracefully even with no actions
      });

      test('handles maximum player count', () {
        final playerNames = <String, String>{};
        final actions = <Map<String, dynamic>>[];

        for (int i = 1; i <= 9; i++) {
          playerNames[i.toString()] = 'Player$i';
          actions.add(MockHandActions.fold(i, street: 'preflop'));
        }

        final handData = {
          'handNumber': 1,
          'gameType': 'cash',
          'playerCount': 9,
          'heroSeatNumber': 5,
          'playerNames': playerNames,
          'actions': actions,
        };

        final csv = csvExportService.exportHandToCsv(handData);

        expect(csv.split('\n').length, greaterThan(10)); // Header + 9 actions + metadata
        expect(csv, contains('Player1'));
        expect(csv, contains('Player9'));
      });
    });
  });
}