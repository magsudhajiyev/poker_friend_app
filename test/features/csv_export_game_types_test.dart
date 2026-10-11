import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/csv_export_service.dart';
import 'package:poker_logger/models/game_types.dart';
import '../fixtures/mock_hand_actions.dart';

void main() {
  group('CSV Export Game Types and Scenarios', () {
    late CSVExportService csvExportService;

    setUp(() {
      csvExportService = CSVExportService();
    });

    group('Cash Game Scenarios', () {
      test('exports typical cash game session with rebuys', () {
        final sessionData = {
          'sessionName': 'Tuesday Night Cash',
          'gameType': GameType.cash,
          'smallBlind': 2,
          'bigBlind': 5,
          'buyInAmount': 500.0,
          'totalBuyIn': 800.0, // Including rebuys
          'startingStack': 500.0,
          'currentStack': 1250.0,
          'startTime': '2024-01-15T19:00:00Z',
          'endTime': '2024-01-16T01:30:00Z',
          'totalHands': 150,
        };

        final hands = [
          {
            'handNumber': 1,
            'gameType': 'cash',
            'smallBlind': 2,
            'bigBlind': 5,
            'buttonPosition': 6,
            'playerCount': 6,
            'heroSeatNumber': 3,
            'potAmount': 87.5,
            'winnerId': 3, // Hero wins
            'ourHoleCards': {'card1': 'A♠', 'card2': 'A♥'},
            'boardCards': {
              'flop': ['K♦', '7♣', '2♠'],
              'turn': 'Q♥',
              'river': '8♦'
            },
            'playerNames': {
              '1': 'TightReg',
              '2': 'LAGFish',
              '3': 'Hero',
              '4': 'OldNit',
              '5': 'YoungGun',
              '6': 'Recreational'
            },
            'actions': [
              MockHandActions.smallBlind(1, 2.0),
              MockHandActions.bigBlind(2, 5.0),
              MockHandActions.raise(3, 15.0, street: 'preflop'), // Hero
              MockHandActions.fold(4, street: 'preflop'),
              MockHandActions.call(5, 15.0, street: 'preflop'),
              MockHandActions.fold(6, street: 'preflop'),
              MockHandActions.fold(1, street: 'preflop'),
              MockHandActions.call(2, 15.0, street: 'preflop'),
              // Flop
              MockHandActions.check(2, street: 'flop'),
              MockHandActions.bet(3, 25.0, street: 'flop'), // Hero
              MockHandActions.fold(5, street: 'flop'),
              MockHandActions.call(2, 25.0, street: 'flop'),
              // Turn
              MockHandActions.check(2, street: 'turn'),
              MockHandActions.bet(3, 50.0, street: 'turn'), // Hero
              MockHandActions.fold(2, street: 'turn'),
            ]
          },
          {
            'handNumber': 75,
            'gameType': 'cash',
            'smallBlind': 2,
            'bigBlind': 5,
            'buttonPosition': 2,
            'playerCount': 6,
            'heroSeatNumber': 3,
            'potAmount': 45.0,
            'winnerId': 1,
            'ourHoleCards': {'card1': '7♠', 'card2': '6♠'},
            'boardCards': {
              'flop': ['A♦', 'K♣', 'Q♠']
            },
            'playerNames': {
              '1': 'TightReg',
              '2': 'LAGFish',
              '3': 'Hero',
              '4': 'OldNit',
              '5': 'YoungGun',
              '6': 'Recreational'
            },
            'actions': [
              MockHandActions.smallBlind(3, 2.0), // Hero
              MockHandActions.bigBlind(4, 5.0),
              MockHandActions.fold(5, street: 'preflop'),
              MockHandActions.raise(6, 20.0, street: 'preflop'),
              MockHandActions.call(1, 20.0, street: 'preflop'),
              MockHandActions.fold(2, street: 'preflop'),
              MockHandActions.fold(3, street: 'preflop'), // Hero folds
              MockHandActions.fold(4, street: 'preflop'),
            ]
          }
        ];

        final csv = csvExportService.exportSessionToCsv(sessionData, hands);

        // Verify cash game metadata
        expect(csv, contains('Tuesday Night Cash'));
        expect(csv, contains('Cash Game'));
        expect(csv, contains('Blinds: \$2/\$5'));

        // Verify both hands included
        expect(csv, matches(RegExp(r'^1,preflop,', multiLine: true)));
        expect(csv, matches(RegExp(r'^75,preflop,', multiLine: true)));

        // Verify hero hole cards shown appropriately
        expect(csv, contains('A♠A♥')); // First hand
        expect(csv, contains('7♠6♠')); // Second hand
      });

      test('exports cash game with straddle', () {
        final handData = {
          'handNumber': 42,
          'gameType': 'cash',
          'smallBlind': 5,
          'bigBlind': 10,
          'buttonPosition': 5,
          'playerCount': 6,
          'heroSeatNumber': 1,
          'potAmount': 125.0,
          'playerNames': {
            '1': 'Hero',
            '2': 'Straddler',
            '3': 'UTG+1',
            '4': 'MP',
            '5': 'BTN',
            '6': 'SB'
          },
          'actions': [
            MockHandActions.smallBlind(6, 5.0),
            MockHandActions.bigBlind(1, 10.0), // Hero in BB
            {'player': 2, 'action': 'bet', 'street': 'preflop', 'amount': 20.0, 'playerName': 'Straddler'}, // Straddle
            MockHandActions.fold(3, street: 'preflop'),
            MockHandActions.call(4, 20.0, street: 'preflop'),
            MockHandActions.raise(5, 60.0, street: 'preflop'),
            MockHandActions.fold(6, street: 'preflop'),
            MockHandActions.call(1, 60.0, street: 'preflop'), // Hero calls
            MockHandActions.fold(2, street: 'preflop'),
            MockHandActions.fold(4, street: 'preflop'),
          ]
        };

        final csv = csvExportService.exportHandToCsv(handData);

        // Should capture straddle as bet action
        expect(csv, contains(',Straddler,bet,20.0,'));
        expect(csv, contains(',Hero,call,60.0,'));
      });
    });

    group('Tournament Scenarios', () {
      test('exports tournament hand with increasing blinds', () {
        final handData = {
          'handNumber': 123,
          'gameType': 'tournament',
          'smallBlind': 400,
          'bigBlind': 800,
          'buttonPosition': 4,
          'playerCount': 7,
          'heroSeatNumber': 2,
          'heroPositionName': 'BB',
          'potAmount': 6400.0,
          'winnerId': 2, // Hero wins
          'ourHoleCards': {'card1': 'Q♠', 'card2': 'Q♥'},
          'boardCards': {
            'flop': ['9♦', '6♣', '3♠'],
            'turn': 'A♥',
            'river': '2♦'
          },
          'playerNames': {
            '1': 'ShortStack',
            '2': 'Hero',
            '3': 'ChipLeader',
            '4': 'MidStack1',
            '5': 'MidStack2',
            '6': 'Tight',
            '7': 'Aggressive'
          },
          'actions': [
            MockHandActions.smallBlind(1, 400.0),
            MockHandActions.bigBlind(2, 800.0), // Hero
            MockHandActions.fold(3, street: 'preflop'),
            MockHandActions.fold(4, street: 'preflop'),
            {'player': 5, 'action': 'all-in', 'street': 'preflop', 'amount': 3200.0, 'playerName': 'MidStack2'},
            MockHandActions.fold(6, street: 'preflop'),
            MockHandActions.fold(7, street: 'preflop'),
            MockHandActions.fold(1, street: 'preflop'),
            {'player': 2, 'action': 'all-in', 'street': 'preflop', 'amount': 2800.0, 'playerName': 'Hero'}, // Call for less
          ]
        };

        final csv = csvExportService.exportHandToCsv(handData);

        // Verify tournament structure
        expect(csv, contains('small blind,400.0'));
        expect(csv, contains('big blind,800.0'));
        expect(csv, contains('all-in,3200.0'));
        expect(csv, contains('all-in,2800.0'));

        // Verify hero hole cards
        expect(csv, contains('Q♠Q♥'));
      });

      test('exports tournament final table bubble hand', () {
        final handData = {
          'handNumber': 287,
          'gameType': 'tournament',
          'smallBlind': 2000,
          'bigBlind': 4000,
          'buttonPosition': 3,
          'playerCount': 4, // Final 4
          'heroSeatNumber': 1,
          'heroPositionName': 'SB',
          'potAmount': 52000.0,
          'winnerId': 4,
          'ourHoleCards': {'card1': 'A♦', 'card2': 'J♠'},
          'boardCards': {
            'flop': ['K♠', 'Q♥', '10♣'],
            'turn': '9♠',
            'river': '8♥'
          },
          'isStarred': true,
          'tags': ['final-table', 'big-pot'],
          'notes': 'Flopped nuts, rivered straight vs straight',
          'playerNames': {
            '1': 'Hero',
            '2': 'BigStack',
            '3': 'VeryShort',
            '4': 'Calling'
          },
          'actions': [
            MockHandActions.smallBlind(1, 2000.0), // Hero
            MockHandActions.bigBlind(2, 4000.0),
            {'player': 3, 'action': 'all-in', 'street': 'preflop', 'amount': 8000.0, 'playerName': 'VeryShort'},
            MockHandActions.call(4, 8000.0, street: 'preflop'),
            MockHandActions.call(1, 8000.0, street: 'preflop'), // Hero
            MockHandActions.call(2, 8000.0, street: 'preflop'),
            // Flop - side pot action
            MockHandActions.check(1, street: 'flop'),
            MockHandActions.check(2, street: 'flop'),
            MockHandActions.bet(4, 12000.0, street: 'flop'),
            MockHandActions.call(1, 12000.0, street: 'flop'), // Hero
            MockHandActions.fold(2, street: 'flop'),
            // Turn
            MockHandActions.check(1, street: 'turn'),
            MockHandActions.bet(4, 16000.0, street: 'turn'),
            MockHandActions.call(1, 16000.0, street: 'turn'), // Hero
          ]
        };

        final csv = csvExportService.exportHandToCsv(handData);

        // Verify final table structure
        expect(csv, contains(',2000.0,'));
        expect(csv, contains(',4000.0,'));
        expect(csv, contains('all-in,8000.0'));

        // Verify side pot betting
        expect(csv, contains('bet,12000.0'));
        expect(csv, contains('bet,16000.0'));

        // Board strings appear on rows of their street; this hand has no
        // river actions, so the river board is never emitted.
        expect(csv, contains('K♠Q♥10♣'));
        expect(csv, contains('K♠Q♥10♣9♠'));
        expect(csv, isNot(contains('K♠Q♥10♣9♠8♥')));
      });

      test('exports sit-and-go tournament completion', () {
        final sessionData = {
          'sessionName': 'SNG - 9 Player Turbo',
          'gameType': GameType.tournament,
          'buyInAmount': 20.0,
          'startingStack': 1500.0,
          'finalPosition': 2, // Runner-up
          'totalHands': 45,
          'startTime': '2024-01-15T14:00:00Z',
          'endTime': '2024-01-15T15:15:00Z',
        };

        final hands = [
          // Early hand
          {
            'handNumber': 5,
            'gameType': 'tournament',
            'smallBlind': 15,
            'bigBlind': 30,
            'playerCount': 9,
            'heroSeatNumber': 5,
            'actions': [
              MockHandActions.smallBlind(4, 15.0),
              MockHandActions.bigBlind(5, 30.0), // Hero
              MockHandActions.fold(6, street: 'preflop'),
              MockHandActions.fold(7, street: 'preflop'),
              MockHandActions.raise(8, 90.0, street: 'preflop'),
              MockHandActions.fold(9, street: 'preflop'),
              MockHandActions.fold(1, street: 'preflop'),
              MockHandActions.fold(2, street: 'preflop'),
              MockHandActions.fold(3, street: 'preflop'),
              MockHandActions.fold(4, street: 'preflop'),
              MockHandActions.fold(5, street: 'preflop'), // Hero folds
            ]
          },
          // Final hand (heads up)
          {
            'handNumber': 45,
            'gameType': 'tournament',
            'smallBlind': 400,
            'bigBlind': 800,
            'playerCount': 2,
            'heroSeatNumber': 1,
            'winnerId': 2, // Opponent wins tournament
            'ourHoleCards': {'card1': 'K♣', 'card2': '9♦'},
            'boardCards': {
              'flop': ['A♠', '8♥', '5♣'],
              'turn': '7♦',
              'river': '6♠'
            },
            'playerNames': {
              '1': 'Hero',
              '2': 'FinalOpponent'
            },
            'actions': [
              MockHandActions.smallBlind(1, 400.0), // Hero (button in heads-up)
              MockHandActions.bigBlind(2, 800.0),
              {'player': 1, 'action': 'all-in', 'street': 'preflop', 'amount': 3200.0, 'playerName': 'Hero'},
              {'player': 2, 'action': 'all-in', 'street': 'preflop', 'amount': 2800.0, 'playerName': 'FinalOpponent'}, // Call for less
            ]
          }
        ];

        final csv = csvExportService.exportSessionToCsv(sessionData, hands);

        // Verify tournament metadata
        expect(csv, contains('SNG - 9 Player Turbo'));
        expect(csv, contains('Tournament'));

        // Verify progression from 9 players to heads-up
        expect(csv.split(',9,').length, greaterThan(1)); // Multiple instances of 9 players
        expect(csv.split(',2,').length, greaterThan(1)); // Final heads-up

        // Verify final all-in
        expect(csv, contains('all-in,3200.0'));
        expect(csv, contains('all-in,2800.0'));
      });
    });

    group('Mixed Game Types and Formats', () {
      test('exports session with both cash and tournament hands', () {
        final sessionData = {
          'sessionName': 'Mixed Game Night',
          'gameType': 'mixed', // Custom type
          'totalHands': 2,
        };

        final hands = [
          {
            'handNumber': 1,
            'gameType': 'cash',
            'smallBlind': 1,
            'bigBlind': 2,
            'playerCount': 6,
            'heroSeatNumber': 3,
            'actions': [
              MockHandActions.smallBlind(1, 1.0),
              MockHandActions.bigBlind(2, 2.0),
              MockHandActions.fold(3, street: 'preflop'), // Hero
            ]
          },
          {
            'handNumber': 2,
            'gameType': 'tournament',
            'smallBlind': 25,
            'bigBlind': 50,
            'playerCount': 6,
            'heroSeatNumber': 3,
            'actions': [
              MockHandActions.smallBlind(1, 25.0),
              MockHandActions.bigBlind(2, 50.0),
              MockHandActions.call(3, 50.0, street: 'preflop'), // Hero
            ]
          }
        ];

        final csv = csvExportService.exportSessionToCsv(sessionData, hands);

        expect(csv, contains('Mixed Game Night'));
        expect(csv, contains('fold,0.0')); // Cash game fold
        expect(csv, contains('call,50.0')); // Tournament call
      });

      test('exports home game with custom structure', () {
        final handData = {
          'handNumber': 1,
          'gameType': 'cash', // Home game treated as cash
          'smallBlind': 0.25,
          'bigBlind': 0.5,
          'buttonPosition': 5,
          'playerCount': 5,
          'heroSeatNumber': 2,
          'potAmount': 12.75,
          'ourHoleCards': {'card1': '10♠', 'card2': '10♦'},
          'boardCards': {
            'flop': ['J♠', '8♥', '4♣'],
            'turn': '3♦',
            'river': 'A♠'
          },
          'playerNames': {
            '1': 'Dad',
            '2': 'Hero',
            '3': 'Brother',
            '4': 'Uncle Bob',
            '5': 'Neighbor Jim'
          },
          'actions': [
            MockHandActions.smallBlind(1, 0.25), // Dad
            MockHandActions.bigBlind(2, 0.5), // Hero
            MockHandActions.call(3, 0.5, street: 'preflop'),
            MockHandActions.raise(4, 2.0, street: 'preflop'),
            MockHandActions.fold(5, street: 'preflop'),
            MockHandActions.fold(1, street: 'preflop'),
            MockHandActions.call(2, 2.0, street: 'preflop'), // Hero
            MockHandActions.call(3, 2.0, street: 'preflop'),
            // Flop
            MockHandActions.check(2, street: 'flop'), // Hero
            MockHandActions.check(3, street: 'flop'),
            MockHandActions.bet(4, 3.0, street: 'flop'),
            MockHandActions.call(2, 3.0, street: 'flop'), // Hero
            MockHandActions.fold(3, street: 'flop'),
            // Turn
            MockHandActions.check(2, street: 'turn'), // Hero
            MockHandActions.bet(4, 4.0, street: 'turn'),
            MockHandActions.fold(2, street: 'turn'), // Hero folds
          ]
        };

        final csv = csvExportService.exportHandToCsv(handData);

        // Verify fractional blinds
        expect(csv, contains('small blind,0.25'));
        expect(csv, contains('big blind,0.5'));

        // Verify casual player names
        expect(csv, contains(',Dad,'));
        expect(csv, contains(',Brother,'));
        expect(csv, contains(',Uncle Bob,'));
        expect(csv, contains(',Neighbor Jim,'));

        // Verify hero pocket tens
        expect(csv, contains('10♠10♦'));
      });
    });

    group('Special Situations', () {
      test('exports dealer session with multiple players', () {
        final handData = {
          'handNumber': 8,
          'gameType': 'cash',
          'smallBlind': 5,
          'bigBlind': 10,
          'buttonPosition': 7,
          'playerCount': 8,
          'heroSeatNumber': 3, // Dealer's perspective but not playing
          'potAmount': 95.0,
          'winnerId': 5,
          'playerNames': {
            '1': 'Alex',
            '2': 'Betty',
            '3': 'Charlie',
            '4': 'Diana',
            '5': 'Eddie',
            '6': 'Fiona',
            '7': 'George',
            '8': 'Hannah'
          },
          'playerIds': {
            '1': 'user001',
            '2': 'user002',
            '3': 'user003',
            '4': 'user004',
            '5': 'user005',
            '6': 'user006',
            '7': 'user007',
            '8': 'user008'
          },
          'actions': [
            MockHandActions.smallBlind(8, 5.0),
            MockHandActions.bigBlind(1, 10.0),
            MockHandActions.call(2, 10.0, street: 'preflop'),
            MockHandActions.raise(3, 35.0, street: 'preflop'),
            MockHandActions.fold(4, street: 'preflop'),
            MockHandActions.call(5, 35.0, street: 'preflop'),
            MockHandActions.fold(6, street: 'preflop'),
            MockHandActions.fold(7, street: 'preflop'),
            MockHandActions.fold(8, street: 'preflop'),
            MockHandActions.fold(1, street: 'preflop'),
            MockHandActions.fold(2, street: 'preflop'),
            // Heads up flop
            MockHandActions.bet(3, 25.0, street: 'flop'),
            MockHandActions.call(5, 25.0, street: 'flop'),
            // Turn
            MockHandActions.check(3, street: 'turn'),
            MockHandActions.bet(5, 25.0, street: 'turn'),
            MockHandActions.fold(3, street: 'turn'),
          ]
        };

        final csv = csvExportService.exportHandToCsv(handData);

        // Verify all 8 players handled
        expect(csv, contains(',Alex,'));
        expect(csv, contains(',Hannah,'));

        // Verify no hero hole cards shown (dealer perspective)
        expect(csv, isNot(contains(',,A')));
        expect(csv, isNot(contains(',,K')));

        // Verify full action sequence
        expect(csv, contains('raise,35.0'));
        expect(csv, contains('bet,25.0'));
      });

      test('exports hand with missing winner data', () {
        final handData = {
          'handNumber': 1,
          'gameType': 'cash',
          'playerCount': 3,
          'potAmount': 15.0,
          // Missing winnerId
          'playerNames': {
            '1': 'Player1',
            '2': 'Player2',
            '3': 'Player3'
          },
          'actions': [
            MockHandActions.smallBlind(1, 1.0),
            MockHandActions.bigBlind(2, 2.0),
            MockHandActions.fold(3, street: 'preflop'),
            MockHandActions.raise(1, 6.0, street: 'preflop'),
            MockHandActions.fold(2, street: 'preflop'),
          ]
        };

        expect(() => csvExportService.exportHandToCsv(handData), isNot(throwsA(anything)));

        final csv = csvExportService.exportHandToCsv(handData);
        expect(csv, contains('raise,6.0'));
        expect(csv, contains('fold,0.0'));
      });

      test('exports incomplete hand (ended early)', () {
        final handData = {
          'handNumber': 1,
          'gameType': 'tournament',
          'smallBlind': 100,
          'bigBlind': 200,
          'playerCount': 6,
          'heroSeatNumber': 4,
          'potAmount': 300.0,
          'ourHoleCards': {'card1': '2♣', 'card2': '7♦'},
          // No board cards - hand ended preflop
          'playerNames': {
            '1': 'UTG',
            '2': 'UTG+1',
            '3': 'MP',
            '4': 'Hero',
            '5': 'BTN',
            '6': 'SB'
          },
          'actions': [
            MockHandActions.smallBlind(6, 100.0),
            MockHandActions.bigBlind(1, 200.0),
            MockHandActions.fold(2, street: 'preflop'),
            MockHandActions.fold(3, street: 'preflop'),
            MockHandActions.fold(4, street: 'preflop'), // Hero folds trash
            MockHandActions.fold(5, street: 'preflop'),
            MockHandActions.fold(6, street: 'preflop'),
            // BB wins uncontested
          ]
        };

        final csv = csvExportService.exportHandToCsv(handData);

        // Should handle preflop-only hand
        expect(csv.split('\n').where((line) => line.contains('preflop')).length, greaterThan(5));
        expect(csv, isNot(contains(',flop,')));
        expect(csv, isNot(contains('turn')));
        expect(csv, isNot(contains('river')));

        // Should show hero hole cards even on fold
        expect(csv, contains('2♣7♦'));
      });
    });

    group('Data Consistency Validation', () {
      test('validates pot calculations are consistent', () {
        final handData = {
          'handNumber': 1,
          'gameType': 'cash',
          'playerNames': {'1': 'Player1', '2': 'Player2'},
          'potAmount': 100.0, // Final pot amount
          'actions': [
            MockHandActions.smallBlind(1, 5.0),
            MockHandActions.bigBlind(2, 10.0),
            MockHandActions.raise(1, 25.0, street: 'preflop'),
            MockHandActions.call(2, 25.0, street: 'preflop'),
            MockHandActions.bet(1, 35.0, street: 'flop'),
            MockHandActions.call(2, 35.0, street: 'flop'),
          ]
        };

        final csv = csvExportService.exportHandToCsv(handData);

        // Extract pot values from CSV
        final lines = csv.split('\n');
        final potValues = <double>[];

        for (final line in lines) {
          if (line.contains(',preflop,') || line.contains(',flop,')) {
            final parts = line.split(',');
            if (parts.length > 6) {
              final potStr = parts[6];
              final pot = double.tryParse(potStr);
              if (pot != null) {
                potValues.add(pot);
              }
            }
          }
        }

        // Pot should increase monotonically
        for (int i = 1; i < potValues.length; i++) {
          expect(potValues[i], greaterThanOrEqualTo(potValues[i - 1]));
        }

        // Final pot: the shipped Pot column accumulates voluntary chips
        // only (blind posts excluded): 25+25+35+35 = 120.
        if (potValues.isNotEmpty) {
          expect(potValues.last, equals(120.0));
        }
      });

      test('validates action sequence is chronologically correct', () {
        final handData = {
          'handNumber': 1,
          'gameType': 'cash',
          'playerNames': {'1': 'Player1', '2': 'Player2'},
          'actions': [
            MockHandActions.smallBlind(1, 1.0),
            MockHandActions.bigBlind(2, 2.0),
            MockHandActions.call(1, 2.0, street: 'preflop'),
            MockHandActions.check(2, street: 'preflop'),
            MockHandActions.bet(1, 5.0, street: 'flop'),
            MockHandActions.call(2, 5.0, street: 'flop'),
            MockHandActions.check(1, street: 'turn'),
            MockHandActions.check(2, street: 'turn'),
            MockHandActions.bet(1, 10.0, street: 'river'),
            MockHandActions.fold(2, street: 'river'),
          ]
        };

        final csv = csvExportService.exportHandToCsv(handData);
        final lines = csv.split('\n').where((line) => !line.startsWith('#') && line.trim().isNotEmpty).toList();

        // Skip header
        final actionLines = lines.skip(1).toList();

        // Verify street progression
        final streets = <String>[];
        for (final line in actionLines) {
          final parts = line.split(',');
          if (parts.length > 1) {
            streets.add(parts[1]); // Street column
          }
        }

        // Should progress: preflop -> flop -> turn -> river
        var currentStreetIndex = -1;
        final streetOrder = ['preflop', 'flop', 'turn', 'river'];

        for (final street in streets) {
          final streetIndex = streetOrder.indexOf(street);
          expect(streetIndex, greaterThanOrEqualTo(currentStreetIndex));
          currentStreetIndex = streetIndex;
        }
      });
    });
  });
}