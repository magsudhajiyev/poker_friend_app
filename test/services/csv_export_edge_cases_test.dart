import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/csv_export_service.dart';
import '../fixtures/mock_hand_actions.dart';

void main() {
  group('CSV Export Edge Cases', () {
    late CSVExportService csvExportService;

    setUp(() {
      csvExportService = CSVExportService();
    });

    group('Data Corruption and Recovery', () {
      test('handles corrupted action data gracefully', () {
        final handData = {
          'handNumber': 1,
          'gameType': 'cash',
          'playerNames': {'1': 'Hero', '2': 'Opponent'},
          'actions': [
            // Valid action
            MockHandActions.smallBlind(1, 1.0),
            // Corrupted actions with various missing/invalid fields
            {'player': 'not_a_number', 'action': 'fold', 'street': 'preflop'},
            {'player': 2, 'action': null, 'street': 'preflop'},
            {'player': 2, 'action': 'invalid_action', 'street': 'preflop'},
            {'action': 'call', 'street': 'preflop'}, // Missing player
            {'player': 2, 'street': 'preflop'}, // Missing action
            {'player': 2, 'action': 'bet'}, // Missing street
            // Mixed valid/invalid amounts
            {'player': 2, 'action': 'bet', 'street': 'flop', 'amount': 'not_a_number'},
            {'player': 2, 'action': 'bet', 'street': 'flop', 'amount': -5.0},
            {'player': 2, 'action': 'bet', 'street': 'flop', 'amount': double.infinity},
            {'player': 2, 'action': 'bet', 'street': 'flop', 'amount': double.nan},
            // Valid action at end
            MockHandActions.fold(2, street: 'flop'),
          ]
        };

        // Should not throw exception
        expect(() => csvExportService.exportHandToCsv(handData), isNot(throwsA(anything)));

        final csv = csvExportService.exportHandToCsv(handData);

        // Should still produce valid CSV structure
        expect(csv, contains('Hand#,Street,Seat,Player,Action,Amount,Pot,Board,HoleCards'));
        // Fixture uses the app-canonical 'small blind' (space) spelling.
        expect(csv, contains('small blind'));
        expect(csv, contains('fold'));

        // Should handle invalid amounts gracefully
        expect(csv, isNot(contains('NaN')));
        expect(csv, isNot(contains('Infinity')));
        expect(csv, isNot(contains('-5.0')));
      });

      test('handles completely empty or null hand data', () {
        final emptyHandData = <String, dynamic>{};
        final nullHandData = null;

        expect(() => csvExportService.exportHandToCsv(emptyHandData), isNot(throwsA(anything)));
        expect(() => csvExportService.exportHandToCsv({}), isNot(throwsA(anything)));

        final emptyCsv = csvExportService.exportHandToCsv(emptyHandData);
        expect(emptyCsv, contains('Hand#,Street,Seat,Player,Action,Amount,Pot,Board,HoleCards'));
      });

      test('handles corrupted board cards data', () {
        final handData = {
          'handNumber': 1,
          'gameType': 'cash',
          'playerNames': {'1': 'Hero'},
          'boardCards': {
            // Various corrupted board card formats
            'flop': 'not_a_list',
            'turn': ['should', 'be', 'string'],
            'river': 42,
            'invalid_street': ['A♠', 'K♥'],
            null: ['null_key'],
          },
          'actions': [
            MockHandActions.check(1, street: 'preflop'),
            MockHandActions.check(1, street: 'flop'),
            MockHandActions.check(1, street: 'turn'),
            MockHandActions.check(1, street: 'river'),
          ]
        };

        final csv = csvExportService.exportHandToCsv(handData);

        expect(csv, isNotEmpty);
        expect(csv, contains('Hand#,Street,Seat,Player,Action,Amount,Pot,Board,HoleCards'));
        expect(csv, isNot(contains('not_a_list')));
        expect(csv, isNot(contains('null')));
      });

      test('handles corrupted hole cards data', () {
        final handData = {
          'handNumber': 1,
          'heroSeatNumber': 1,
          'playerNames': {'1': 'Hero'},
          'ourHoleCards': {
            // Various corrupted formats
            'card1': null,
            'card2': 42,
            'invalid_key': 'A♠',
            null: 'K♥',
          },
          'actions': [
            MockHandActions.fold(1, street: 'preflop'),
          ]
        };

        final csv = csvExportService.exportHandToCsv(handData);

        expect(csv, contains(',Hero,fold,0.0,0.0,,'));
        expect(csv, isNot(contains('null')));
        expect(csv, isNot(contains('42')));
      });
    });

    group('Extreme Values and Limits', () {
      test('handles extremely large pot and bet amounts', () {
        final handData = {
          'handNumber': 1,
          'gameType': 'tournament',
          'playerNames': {'1': 'Hero', '2': 'HighRoller'},
          'potAmount': 999999999999.99,
          'actions': [
            MockHandActions.smallBlind(1, 1000000.0),
            MockHandActions.bigBlind(2, 2000000.0),
            {'player': 1, 'action': 'raise', 'street': 'preflop', 'amount': 50000000.0, 'playerName': 'Hero'},
            {'player': 2, 'action': 'all-in', 'street': 'preflop', 'amount': 999999999999.99, 'playerName': 'HighRoller'},
          ]
        };

        final csv = csvExportService.exportHandToCsv(handData);

        expect(csv, contains('1000000.0'));
        expect(csv, contains('50000000.0'));
        expect(csv, contains('999999999999.99'));
      });

      test('handles maximum player count with complex actions', () {
        final playerNames = <String, String>{};
        final actions = <Map<String, dynamic>>[];

        // Create 9 players
        for (int i = 1; i <= 9; i++) {
          playerNames[i.toString()] = 'Player$i';
        }

        // Create complex preflop action with all players
        actions.addAll([
          MockHandActions.smallBlind(1, 5.0),
          MockHandActions.bigBlind(2, 10.0),
          MockHandActions.fold(3, street: 'preflop'),
          MockHandActions.call(4, 10.0, street: 'preflop'),
          MockHandActions.raise(5, 35.0, street: 'preflop'),
          MockHandActions.fold(6, street: 'preflop'),
          MockHandActions.call(7, 35.0, street: 'preflop'),
          MockHandActions.fold(8, street: 'preflop'),
          MockHandActions.call(9, 35.0, street: 'preflop'),
          MockHandActions.fold(1, street: 'preflop'),
          MockHandActions.call(2, 35.0, street: 'preflop'),
          MockHandActions.call(4, 35.0, street: 'preflop'),
        ]);

        // Add multi-street actions
        actions.addAll([
          MockHandActions.check(2, street: 'flop'),
          MockHandActions.bet(4, 50.0, street: 'flop'),
          MockHandActions.raise(5, 150.0, street: 'flop'),
          MockHandActions.fold(7, street: 'flop'),
          MockHandActions.fold(9, street: 'flop'),
          MockHandActions.fold(2, street: 'flop'),
          MockHandActions.call(4, 150.0, street: 'flop'),
        ]);

        final handData = {
          'handNumber': 1,
          'gameType': 'cash',
          'smallBlind': 5,
          'bigBlind': 10,
          'buttonPosition': 9,
          'playerCount': 9,
          'heroSeatNumber': 5,
          'playerNames': playerNames,
          'boardCards': {
            'flop': ['A♠', 'K♥', 'Q♦'],
            'turn': 'J♣',
            'river': '10♠'
          },
          'ourHoleCards': {'card1': '9♠', 'card2': '8♠'},
          'actions': actions,
        };

        final csv = csvExportService.exportHandToCsv(handData);

        // Verify all players are included
        for (int i = 1; i <= 9; i++) {
          expect(csv, contains('Player$i'));
        }

        // Verify hero hole cards shown
        expect(csv, contains('9♠8♠'));

        // Board strings appear on rows of their street — this hand has no
        // turn/river actions, so only the flop board is emitted.
        expect(csv, contains('A♠K♥Q♦')); // Flop
        expect(csv, isNot(contains('A♠K♥Q♦J♣'))); // no turn rows exist

        // Count total action lines
        final lines = csv.split('\n').where((line) =>
          !line.startsWith('#') &&
          !line.startsWith('Hand#') &&
          line.trim().isNotEmpty
        ).toList();

        expect(lines.length, actions.length);
      });

      test('handles very long session with hundreds of hands', () {
        final sessionData = {
          'sessionName': 'Ultra Marathon Poker Session - All Night Long',
          'gameType': 'cash',
          'smallBlind': 1,
          'bigBlind': 2,
          'totalHands': 1000,
          'startTime': '2024-01-15T18:00:00Z',
          'endTime': '2024-01-16T12:00:00Z',
        };

        // Generate 200 representative hands (testing with subset for performance)
        final hands = List.generate(200, (index) {
          final handNumber = index + 1;
          return {
            'handNumber': handNumber,
            'gameType': 'cash',
            'smallBlind': 1,
            'bigBlind': 2,
            'playerCount': 6,
            'heroSeatNumber': (handNumber % 6) + 1,
            'potAmount': 10.0 + (handNumber * 0.5),
            'playerNames': {
              '1': 'RegularReg',
              '2': 'NittyNancy',
              '3': 'Hero',
              '4': 'LAGLarry',
              '5': 'CallingCathy',
              '6': 'TiltedTom'
            },
            'actions': [
              MockHandActions.smallBlind(((handNumber - 1) % 6) + 1, 1.0),
              MockHandActions.bigBlind((handNumber % 6) + 1, 2.0),
              MockHandActions.fold((handNumber + 1) % 6 + 1, street: 'preflop'),
              MockHandActions.fold((handNumber + 2) % 6 + 1, street: 'preflop'),
              MockHandActions.call((handNumber + 3) % 6 + 1, 2.0, street: 'preflop'),
              MockHandActions.check((handNumber % 6) + 1, street: 'preflop'),
            ],
            if (handNumber % 10 == 0) 'isChoppedPot': true,
            if (handNumber % 10 == 0) 'choppedWinners': [1, 2],
            if (handNumber % 10 == 0) 'sharePerWinner': 15.0,
          };
        });

        final csv = csvExportService.exportSessionToCsv(sessionData, hands);

        // Verify session metadata
        expect(csv, contains('Ultra Marathon Poker Session - All Night Long'));
        // Metadata reports the session's totalHands field, not the subset size.
        expect(csv, contains('1000 hands'));
        expect(csv, contains('Cash Game'));

        // Verify CSV structure
        expect(csv, contains('Hand#,Street,Seat,Player,Action,Amount,Pot,Board,HoleCards'));

        // Verify chopped pots are marked
        expect(csv, contains('CHOPPED POT'));

        // Verify all hands are present
        expect(csv, matches(RegExp(r'^1,preflop,', multiLine: true)));
        expect(csv, matches(RegExp(r'^200,preflop,', multiLine: true)));

        // Should be substantial output (200 hands x 6 rows, compact format)
        expect(csv.length, greaterThan(40000));
      });
    });

    group('Unicode and Special Characters', () {
      test('handles unicode card symbols and player names', () {
        final handData = {
          'handNumber': 1,
          'gameType': 'cash',
          'heroSeatNumber': 2,
          'ourHoleCards': {'card1': 'A♠', 'card2': 'K♥'},
          'boardCards': {
            'flop': ['Q♦', 'J♣', '10♠'],
            'turn': '9♥',
            'river': '8♦'
          },
          'playerNames': {
            '1': '王小明', // Chinese name
            '2': 'José María', // Spanish name with accents
            '3': 'Владимир', // Cyrillic name
            '4': 'Ahmed محمد', // Arabic mixed with Latin
            '5': '🃏PokerPro🎰', // Emoji in name
          },
          'actions': [
            MockHandActions.smallBlind(1, 1.0),
            MockHandActions.bigBlind(2, 2.0),
            MockHandActions.call(3, 2.0, street: 'preflop'),
            MockHandActions.raise(4, 8.0, street: 'preflop'),
            MockHandActions.fold(5, street: 'preflop'),
          ]
        };

        final csv = csvExportService.exportHandToCsv(handData);

        // Should contain unicode names
        expect(csv, contains('王小明'));
        expect(csv, contains('José María'));
        expect(csv, contains('Владимир'));
        expect(csv, contains('Ahmed محمد'));
        expect(csv, contains('🃏PokerPro🎰'));

        // Should contain unicode card symbols (hero hole cards; all actions
        // are preflop so no board rows exist)
        expect(csv, contains('A♠K♥'));
      });

      test('handles player names with CSV-problematic characters', () {
        final handData = {
          'handNumber': 1,
          'gameType': 'cash',
          'playerNames': {
            '1': 'Player, with comma',
            '2': 'Player "with quotes"',
            '3': 'Player\nwith\nnewlines',
            '4': 'Player\twith\ttabs',
            '5': 'Player; with; semicolons',
          },
          'actions': [
            MockHandActions.fold(1, street: 'preflop'),
            MockHandActions.fold(2, street: 'preflop'),
            MockHandActions.fold(3, street: 'preflop'),
            MockHandActions.fold(4, street: 'preflop'),
            MockHandActions.fold(5, street: 'preflop'),
          ]
        };

        final csv = csvExportService.exportHandToCsv(handData);

        // Should be valid CSV even with problematic characters
        expect(csv, contains('Hand#,Street,Seat,Player,Action,Amount,Pot,Board,HoleCards'));
        expect(csv, isNot(contains('\n\n'))); // No double newlines
        expect(csv, isNot(contains('\t')));   // No tab characters
      });
    });

    group('Temporal Edge Cases', () {
      test('handles actions with same timestamp', () {
        final sameTimestamp = '2024-01-15T20:30:15.123Z';
        final handData = {
          'handNumber': 1,
          'gameType': 'cash',
          'playerNames': {'1': 'Player1', '2': 'Player2'},
          'actions': [
            {
              'player': 1,
              'action': 'small-blind',
              'street': 'preflop',
              'amount': 1.0,
              'timestamp': sameTimestamp,
              'playerName': 'Player1',
            },
            {
              'player': 2,
              'action': 'big-blind',
              'street': 'preflop',
              'amount': 2.0,
              'timestamp': sameTimestamp, // Same timestamp
              'playerName': 'Player2',
            },
          ]
        };

        final csv = csvExportService.exportHandToCsv(handData);

        expect(csv, contains('small-blind'));
        expect(csv, contains('big-blind'));
        expect(csv.split('\n').length, greaterThan(2));
      });

      test('handles missing or invalid timestamps', () {
        final handData = {
          'handNumber': 1,
          'gameType': 'cash',
          'playerNames': {'1': 'Player1', '2': 'Player2'},
          'actions': [
            {
              'player': 1,
              'action': 'fold',
              'street': 'preflop',
              'timestamp': null, // Null timestamp
              'playerName': 'Player1',
            },
            {
              'player': 2,
              'action': 'call',
              'street': 'preflop',
              'timestamp': 'invalid-date-string',
              'playerName': 'Player2',
            },
            {
              'player': 1,
              'action': 'bet',
              'street': 'flop',
              // Missing timestamp entirely
              'playerName': 'Player1',
            },
          ]
        };

        expect(() => csvExportService.exportHandToCsv(handData), isNot(throwsA(anything)));

        final csv = csvExportService.exportHandToCsv(handData);
        expect(csv, contains('fold'));
        expect(csv, contains('call'));
        expect(csv, contains('bet'));
      });
    });

    group('Memory and Resource Management', () {
      test('handles rapid repeated exports without memory leaks', () {
        final handData = {
          'handNumber': 1,
          'gameType': 'cash',
          'playerNames': {'1': 'Hero'},
          'actions': [MockHandActions.fold(1, street: 'preflop')],
        };

        // Perform many exports in succession
        for (int i = 0; i < 1000; i++) {
          final csv = csvExportService.exportHandToCsv(handData);
          expect(csv, isNotEmpty);

          // Clear reference to help with garbage collection
          csv.toString();
        }

        // Should complete without memory issues
        expect(true, isTrue);
      });

      test('handles very deep action nesting without stack overflow', () {
        final actions = <Map<String, dynamic>>[];

        // Create a hand with many back-and-forth raises
        for (int i = 0; i < 100; i++) {
          actions.add({
            'player': (i % 2) + 1,
            'action': i == 0 ? 'bet' : 'raise',
            'street': 'preflop',
            'amount': (i + 1) * 10.0,
            'playerName': 'Player${(i % 2) + 1}',
          });
        }

        final handData = {
          'handNumber': 1,
          'gameType': 'tournament',
          'playerNames': {'1': 'Player1', '2': 'Player2'},
          'actions': actions,
        };

        expect(() => csvExportService.exportHandToCsv(handData), isNot(throwsA(anything)));

        final csv = csvExportService.exportHandToCsv(handData);
        expect(csv.split('\n').length, greaterThan(100));
      });
    });
  });
}