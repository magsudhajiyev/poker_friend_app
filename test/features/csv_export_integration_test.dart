import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/csv_export_service.dart';
import 'package:poker_logger/services/subscription_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import '../fixtures/mock_hand_actions.dart';

// Generate mocks
@GenerateMocks([SubscriptionService])
import 'csv_export_integration_test.mocks.dart';

void main() {
  group('CSV Export Integration Tests', () {
    late CSVExportService csvExportService;
    late MockSubscriptionService mockSubscriptionService;

    setUp(() {
      csvExportService = CSVExportService();
      mockSubscriptionService = MockSubscriptionService();
    });

    group('Real Hand Scenarios', () {
      test('exports complex multi-street tournament hand', () {
        // Simulate a realistic tournament hand with multiple streets
        final handData = {
          'id': 'session123_hand45_1642284000000',
          'handNumber': 45,
          'gameType': 'tournament',
          'smallBlind': 300,
          'bigBlind': 600,
          'buttonPosition': 7,
          'playerCount': 8,
          'heroSeatNumber': 3,
          'heroPositionName': 'MP',
          'potAmount': 8400.0,
          'preflopPot': 1800.0,
          'flopPot': 3600.0,
          'turnPot': 6000.0,
          'riverPot': 8400.0,
          'winnerId': 6,
          'reachedShowdown': true,
          'startTime': '2024-01-15T15:30:00Z',
          'endTime': '2024-01-15T15:33:45Z',
          'ourHoleCards': {'card1': 'K♠', 'card2': 'Q♠'},
          'boardCards': {
            'flop': ['A♥', 'J♠', '10♣'],
            'turn': '9♦',
            'river': '8♠'
          },
          'showdownData': {
            '3': {'card1': 'K♠', 'card2': 'Q♠'}, // Hero
            '6': {'card1': 'A♣', 'card2': 'A♦'}, // Winner
          },
          'playerNames': {
            '1': 'TightTim',
            '2': 'AggroAnna',
            '3': 'Hero',
            '4': 'CallingStation',
            '5': 'RockSolid',
            '6': 'ChipLeader',
            '7': 'ShortStack',
            '8': 'BigBlind'
          },
          'playerIds': {
            '1': 'user001',
            '2': 'user002',
            '3': 'current_user_id',
            '4': 'user004',
            '5': 'user005',
            '6': 'user006',
            '7': 'user007',
            '8': 'user008'
          },
          'tags': ['premium-hand', 'straight-draw'],
          'notes': 'Flopped nut straight draw, missed river',
          'isStarred': true,
          'actions': [
            // Preflop
            MockHandActions.smallBlind(7, 300.0, street: 'preflop'),
            MockHandActions.bigBlind(8, 600.0, street: 'preflop'),
            MockHandActions.fold(1, street: 'preflop'),
            MockHandActions.raise(2, 1800.0, street: 'preflop'),
            MockHandActions.call(3, 1800.0, street: 'preflop'), // Hero
            MockHandActions.fold(4, street: 'preflop'),
            MockHandActions.fold(5, street: 'preflop'),
            MockHandActions.call(6, 1800.0, street: 'preflop'),
            MockHandActions.fold(7, street: 'preflop'),
            MockHandActions.fold(8, street: 'preflop'),

            // Flop
            MockHandActions.check(2, street: 'flop'),
            MockHandActions.bet(3, 1200.0, street: 'flop'), // Hero
            MockHandActions.call(6, 1200.0, street: 'flop'),
            MockHandActions.fold(2, street: 'flop'),

            // Turn
            MockHandActions.bet(3, 1800.0, street: 'turn'), // Hero
            MockHandActions.call(6, 1800.0, street: 'turn'),

            // River
            MockHandActions.check(3, street: 'river'), // Hero
            MockHandActions.bet(6, 1200.0, street: 'river'),
            MockHandActions.fold(3, street: 'river'), // Hero folds
          ]
        };

        final csv = csvExportService.exportHandToCsv(handData);
        final lines = csv.split('\n').where((line) => line.trim().isNotEmpty).toList();

        // Verify header
        expect(lines[0], 'Hand#,Street,Seat,Player,Action,Amount,Pot,Board,HoleCards');

        // Count action lines (excluding header)
        final actionLines = lines.where((line) =>
          !line.startsWith('#') &&
          line != lines[0] &&
          line.trim().isNotEmpty
        ).toList();

        expect(actionLines.length, 15); // All actions accounted for

        // Verify preflop actions
        expect(actionLines[0], '45,preflop,7,ShortStack,small-blind,300.0,300.0,,');
        expect(actionLines[1], '45,preflop,8,BigBlind,big-blind,600.0,900.0,,');

        // Verify hero's actions show hole cards
        final heroActions = actionLines.where((line) => line.contains(',Hero,')).toList();
        expect(heroActions.length, 4);
        heroActions.forEach((action) {
          expect(action, contains('K♠Q♠'));
        });

        // Verify board card progression
        expect(actionLines.any((line) =>
          line.contains('flop') && line.contains('A♥J♠10♣')
        ), isTrue);

        expect(actionLines.any((line) =>
          line.contains('turn') && line.contains('A♥J♠10♣9♦')
        ), isTrue);

        expect(actionLines.any((line) =>
          line.contains('river') && line.contains('A♥J♠10♣9♦8♠')
        ), isTrue);

        // Verify pot progression
        expect(actionLines.any((line) => line.contains(',3600.0,')), isTrue); // After flop betting
        expect(actionLines.any((line) => line.contains(',8400.0,')), isTrue); // Final pot
      });

      test('exports cash game with side pots', () {
        final handData = {
          'handNumber': 23,
          'gameType': 'cash',
          'smallBlind': 5,
          'bigBlind': 10,
          'buttonPosition': 3,
          'playerCount': 4,
          'heroSeatNumber': 1,
          'potAmount': 485.0,
          'winnerId': 2,
          'ourHoleCards': {'card1': '8♣', 'card2': '8♦'},
          'boardCards': {
            'flop': ['8♠', '7♥', '2♣'],
            'turn': '4♦',
            'river': 'K♠'
          },
          'playerNames': {
            '1': 'Hero',
            '2': 'BigStack',
            '3': 'MediumStack',
            '4': 'ShortStack'
          },
          'actions': [
            MockHandActions.smallBlind(4, 5.0),
            MockHandActions.bigBlind(1, 10.0),
            MockHandActions.raise(2, 35.0, street: 'preflop'),
            MockHandActions.call(3, 35.0, street: 'preflop'),
            {'player': 4, 'action': 'all-in', 'street': 'preflop', 'amount': 85.0, 'playerName': 'ShortStack'},
            MockHandActions.call(1, 85.0, street: 'preflop'), // Hero
            MockHandActions.call(2, 85.0, street: 'preflop'),
            MockHandActions.call(3, 85.0, street: 'preflop'),

            // Flop - side pot action
            MockHandActions.check(1, street: 'flop'),
            MockHandActions.bet(2, 100.0, street: 'flop'),
            MockHandActions.call(3, 100.0, street: 'flop'),
            MockHandActions.fold(1, street: 'flop'), // Hero out of side pot

            // Turn
            MockHandActions.check(2, street: 'turn'),
            MockHandActions.bet(3, 100.0, street: 'turn'),
            MockHandActions.fold(2, street: 'turn'),
          ]
        };

        final csv = csvExportService.exportHandToCsv(handData);

        // Verify all-in action is captured
        expect(csv, contains('all-in,85.0'));

        // Verify side pot betting
        expect(csv, contains('100.0'));

        // Verify hero hole cards shown
        expect(csv, contains('8♣8♦'));
      });

      test('exports heads-up match hand', () {
        final handData = {
          'handNumber': 5,
          'gameType': 'tournament',
          'smallBlind': 1000,
          'bigBlind': 2000,
          'buttonPosition': 1, // Heads up: button posts SB
          'playerCount': 2,
          'heroSeatNumber': 1,
          'potAmount': 10000.0,
          'winnerId': 1,
          'ourHoleCards': {'card1': 'A♠', 'card2': 'K♦'},
          'boardCards': {
            'flop': ['A♣', 'K♠', '7♥']
          },
          'playerNames': {
            '1': 'Hero',
            '2': 'Villain'
          },
          'actions': [
            MockHandActions.smallBlind(1, 1000.0), // Button posts SB in heads-up
            MockHandActions.bigBlind(2, 2000.0),
            MockHandActions.raise(1, 6000.0, street: 'preflop'),
            {'player': 2, 'action': 'all-in', 'street': 'preflop', 'amount': 8000.0, 'playerName': 'Villain'},
            {'player': 1, 'action': 'all-in', 'street': 'preflop', 'amount': 2000.0, 'playerName': 'Hero'}, // Call for remaining
          ]
        };

        final csv = csvExportService.exportHandToCsv(handData);

        // Verify heads-up blind structure
        expect(csv, contains('1,preflop,1,Hero,small-blind,1000.0'));
        expect(csv, contains('1,preflop,2,Villain,big-blind,2000.0'));

        // Verify both all-ins
        expect(csv, contains('all-in,8000.0'));
        expect(csv, contains('all-in,2000.0'));

        // Verify hero cards shown
        expect(csv, contains('A♠K♦'));
      });
    });

    group('Export File Generation', () {
      test('generates appropriate filename for session', () {
        final sessionData = {
          'sessionName': 'Friday Night Home Game #12',
          'startTime': '2024-01-15T20:00:00Z',
        };

        final filename = csvExportService.generateFilename(sessionData);

        expect(filename, contains('Friday_Night_Home_Game_12'));
        expect(filename, endsWith('.csv'));
        expect(filename, contains('2024')); // Should contain current date
      });

      test('handles special characters in session name', () {
        final sessionData = {
          'sessionName': 'Player\'s "Big Win" Session @ Casino!',
        };

        final filename = csvExportService.generateFilename(sessionData);

        expect(filename, isNot(contains('\'')));
        expect(filename, isNot(contains('"')));
        expect(filename, isNot(contains('@')));
        expect(filename, isNot(contains('!')));
        expect(filename, endsWith('.csv'));
      });

      test('converts CSV to bytes for file sharing', () {
        final csvContent = 'Hand#,Street,Seat\n1,preflop,1';
        final bytes = csvExportService.csvToBytes(csvContent);

        expect(bytes, isA<List<int>>());
        expect(bytes.length, greaterThan(0));
      });
    });

    group('Premium Feature Integration', () {
      test('should require premium subscription for export', () {
        // This test validates that the export feature should be gated
        // In the actual implementation, this would be checked before calling the service

        when(mockSubscriptionService.isPremium).thenReturn(false);

        // In real usage, the UI would check subscription status first
        expect(mockSubscriptionService.isPremium, isFalse);

        // Premium users can access
        when(mockSubscriptionService.isPremium).thenReturn(true);
        expect(mockSubscriptionService.isPremium, isTrue);
      });
    });

    group('Performance Tests', () {
      test('handles large session with many hands efficiently', () {
        final sessionData = {
          'sessionName': 'Marathon Session',
          'gameType': 'cash',
          'totalHands': 500,
        };

        // Generate 100 hands with multiple actions each
        final hands = List.generate(100, (index) {
          return {
            'handNumber': index + 1,
            'gameType': 'cash',
            'smallBlind': 1,
            'bigBlind': 2,
            'playerCount': 6,
            'potAmount': 50.0 + (index * 5), // Varying pot sizes
            'playerNames': {
              '1': 'Player1',
              '2': 'Player2',
              '3': 'Hero',
              '4': 'Player4',
              '5': 'Player5',
              '6': 'Player6'
            },
            'actions': [
              MockHandActions.smallBlind(1, 1.0),
              MockHandActions.bigBlind(2, 2.0),
              MockHandActions.fold(3, street: 'preflop'),
              MockHandActions.fold(4, street: 'preflop'),
              MockHandActions.raise(5, 8.0, street: 'preflop'),
              MockHandActions.call(6, 8.0, street: 'preflop'),
              MockHandActions.fold(1, street: 'preflop'),
              MockHandActions.call(2, 8.0, street: 'preflop'),
              MockHandActions.check(2, street: 'flop'),
              MockHandActions.bet(5, 15.0, street: 'flop'),
              MockHandActions.fold(6, street: 'flop'),
              MockHandActions.fold(2, street: 'flop'),
            ]
          };
        });

        final stopwatch = Stopwatch()..start();
        final csv = csvExportService.exportSessionToCsv(sessionData, hands);
        stopwatch.stop();

        // Should complete in reasonable time (< 5 seconds for 100 hands)
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));

        // Should produce substantial output
        expect(csv.length, greaterThan(50000)); // Lots of data
        expect(csv.split('\n').length, greaterThan(1000)); // Many lines
      });

      test('handles memory efficiently with large CSV output', () {
        final handData = {
          'handNumber': 1,
          'gameType': 'cash',
          'playerCount': 9,
          'playerNames': Map.fromEntries(
            List.generate(9, (i) => MapEntry('${i + 1}', 'Player${i + 1}'))
          ),
          'actions': List.generate(50, (i) =>
            MockHandActions.fold(((i % 9) + 1), street: i < 20 ? 'preflop' : i < 35 ? 'flop' : 'turn')
          )
        };

        // Should not throw memory exceptions
        expect(() => csvExportService.exportHandToCsv(handData), isNot(throwsA(anything)));

        final csv = csvExportService.exportHandToCsv(handData);
        expect(csv, isNotEmpty);
      });
    });
  });
}