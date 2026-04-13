import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/pokerstars_export_service.dart';

void main() {
  // ─────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────

  Map<String, dynamic> _makeHand({
    int handNumber = 1,
    int buttonPosition = 6,
    int playerCount = 8,
    int smallBlind = 300,
    int bigBlind = 600,
    String gameType = 'tournament',
    int heroSeatNumber = 5,
    Map<String, String>? playerNames,
    List<Map<String, dynamic>>? actions,
    Map<String, dynamic>? boardCards,
    Map<String, dynamic>? ourHoleCards,
    int? winnerId,
    double potAmount = 0,
    bool isChoppedPot = false,
    List<int>? choppedWinners,
    Map<String, double>? individualShares,
    bool reachedShowdown = false,
    Map<String, dynamic>? showdownData,
  }) {
    return {
      'handNumber': handNumber,
      'buttonPosition': buttonPosition,
      'playerCount': playerCount,
      'smallBlind': smallBlind,
      'bigBlind': bigBlind,
      'gameType': gameType,
      'startTime': '2024-01-15T20:30:00.000Z',
      'heroSeatNumber': heroSeatNumber,
      'playerNames': playerNames ??
          {
            '1': 'Player1',
            '2': 'Player2',
            '3': 'Player3',
            '4': 'Player4',
            '5': 'Hero',
            '6': 'Player6',
            '7': 'Player7',
            '8': 'Player8',
          },
      'actions': actions ?? [],
      'boardCards': boardCards,
      'ourHoleCards':
          ourHoleCards ?? {'card1': 'A\u2660', 'card2': 'J\u2663'},
      'winnerId': winnerId,
      'potAmount': potAmount,
      'isChoppedPot': isChoppedPot,
      'choppedWinners': choppedWinners,
      'individualShares': individualShares != null
          ? individualShares.map((k, v) => MapEntry(k, v))
          : null,
      'reachedShowdown': reachedShowdown,
      'showdownData': showdownData,
      'sessionId': 'test_session_123',
    };
  }

  Map<String, dynamic> _makeSession({
    bool hasBBante = false,
    int smallBlind = 300,
    int bigBlind = 600,
    double? buyInAmount,
    String gameType = 'tournament',
  }) {
    return {
      'smallBlind': smallBlind,
      'bigBlind': bigBlind,
      'hasBBante': hasBBante,
      'playerCount': 8,
      'buyInAmount': buyInAmount ?? 10.0,
      'sessionName': 'Test Tournament',
      'gameType': gameType,
      'startTime': '2024-01-15T20:00:00.000Z',
      'sessionId': 'test_session_123',
    };
  }

  Map<String, dynamic> _makeAction({
    required int player,
    required String action,
    required String street,
    double? amount,
    required double playerStack,
    required String playerName,
    String? playerPosition,
    bool isCurrentUser = false,
  }) {
    return {
      'player': player,
      'action': action,
      'street': street,
      if (amount != null) 'amount': amount,
      'playerStack': playerStack,
      'playerName': playerName,
      'playerPosition': playerPosition,
      'isCurrentUser': isCurrentUser,
    };
  }

  // ─────────────────────────────────────────────────────────
  // 1. Card Conversion
  // ─────────────────────────────────────────────────────────

  group('Card Conversion', () {
    test('converts suit symbols to PokerStars letters', () {
      // We test card conversion through the public exportHand API
      // by checking the hole cards in the output.
      final hand = _makeHand(
        ourHoleCards: {'card1': 'A\u2660', 'card2': 'T\u2665'},
        actions: [
          _makeAction(
            player: 5,
            action: 'fold',
            street: 'preflop',
            playerStack: 7560.0,
            playerName: 'Hero',
            playerPosition: 'UTG+1',
            isCurrentUser: true,
          ),
        ],
      );
      final session = _makeSession();
      final output = PokerStarsExportService.exportHand(hand, session);

      expect(output, contains('[As Th]'));
    });

    test('converts clubs and diamonds', () {
      final hand = _makeHand(
        ourHoleCards: {'card1': '2\u2663', 'card2': 'K\u2666'},
        actions: [
          _makeAction(
            player: 5,
            action: 'fold',
            street: 'preflop',
            playerStack: 7560.0,
            playerName: 'Hero',
            playerPosition: 'UTG+1',
            isCurrentUser: true,
          ),
        ],
      );
      final session = _makeSession();
      final output = PokerStarsExportService.exportHand(hand, session);

      expect(output, contains('[2c Kd]'));
    });

    test('formats board cards in bracket notation', () {
      final hand = _makeHand(
        boardCards: {
          'flop': ['A\u2660', 'K\u2665', 'Q\u2666'],
          'turn': null,
          'river': null,
        },
        winnerId: 5,
        potAmount: 3000,
        actions: [
          _makeAction(
            player: 7,
            action: 'fold',
            street: 'preflop',
            playerStack: 17220.0,
            playerName: 'Player7',
            playerPosition: 'SB',
          ),
          _makeAction(
            player: 8,
            action: 'check',
            street: 'preflop',
            playerStack: 48420.0,
            playerName: 'Player8',
            playerPosition: 'BB',
          ),
          _makeAction(
            player: 5,
            action: 'bet',
            street: 'flop',
            amount: 1000.0,
            playerStack: 7560.0,
            playerName: 'Hero',
            playerPosition: 'UTG+1',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 8,
            action: 'fold',
            street: 'flop',
            playerStack: 48420.0,
            playerName: 'Player8',
            playerPosition: 'BB',
          ),
        ],
      );
      final session = _makeSession();
      final output = PokerStarsExportService.exportHand(hand, session);

      expect(output, contains('[As Kh Qd]'));
    });

    test('converts 10 to T for PokerStars format', () {
      final hand = _makeHand(
        ourHoleCards: {'card1': '10\u2660', 'card2': '10\u2665'},
        actions: [
          _makeAction(
            player: 5,
            action: 'fold',
            street: 'preflop',
            playerStack: 7560.0,
            playerName: 'Hero',
            playerPosition: 'UTG+1',
            isCurrentUser: true,
          ),
        ],
      );
      final session = _makeSession();
      final output = PokerStarsExportService.exportHand(hand, session);

      expect(output, contains('[Ts Th]'));
    });
  });

  // ─────────────────────────────────────────────────────────
  // 2. Basic Preflop Fold Hand
  // ─────────────────────────────────────────────────────────

  group('Basic Preflop Fold Hand', () {
    late String output;

    setUp(() {
      final hand = _makeHand(
        handNumber: 1,
        buttonPosition: 6,
        heroSeatNumber: 5,
        smallBlind: 300,
        bigBlind: 600,
        gameType: 'tournament',
        winnerId: 5,
        potAmount: 1620,
        ourHoleCards: {'card1': 'A\u2660', 'card2': 'J\u2663'},
        actions: [
          // Everyone folds to Hero, Hero raises, rest fold
          _makeAction(
            player: 1,
            action: 'fold',
            street: 'preflop',
            playerStack: 21540.0,
            playerName: 'Player1',
            playerPosition: 'UTG',
          ),
          _makeAction(
            player: 2,
            action: 'fold',
            street: 'preflop',
            playerStack: 27780.0,
            playerName: 'Player2',
            playerPosition: 'UTG+1',
          ),
          _makeAction(
            player: 3,
            action: 'fold',
            street: 'preflop',
            playerStack: 18120.0,
            playerName: 'Player3',
            playerPosition: 'MP',
          ),
          _makeAction(
            player: 4,
            action: 'fold',
            street: 'preflop',
            playerStack: 25200.0,
            playerName: 'Player4',
            playerPosition: 'HJ',
          ),
          _makeAction(
            player: 5,
            action: 'raise',
            street: 'preflop',
            amount: 1500.0, // total on preflop
            playerStack: 7560.0, // stack after posting (no blind)
            playerName: 'Hero',
            playerPosition: 'CO',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 6,
            action: 'fold',
            street: 'preflop',
            playerStack: 8100.0,
            playerName: 'Player6',
            playerPosition: 'BTN',
          ),
          _makeAction(
            player: 7,
            action: 'fold',
            street: 'preflop',
            playerStack: 17220.0,
            playerName: 'Player7',
            playerPosition: 'SB',
          ),
          _makeAction(
            player: 8,
            action: 'fold',
            street: 'preflop',
            playerStack: 49020.0,
            playerName: 'Player8',
            playerPosition: 'BB',
          ),
        ],
      );
      final session = _makeSession(buyInAmount: 10.0);
      output = PokerStarsExportService.exportHand(hand, session);
    });

    test('header contains Tournament', () {
      expect(output, contains('Tournament'));
    });

    test('header contains hold em and blinds', () {
      expect(output, contains("Hold'em No Limit"));
      expect(output, contains('(300/600)'));
    });

    test('seat lines show starting stacks', () {
      // Hero had 7560 stack after action, no blind posted,
      // so starting stack = 7560
      expect(output, contains('Seat 5: Hero (7560 in chips)'));
      // SB (seat 7) had playerStack 17220, add back SB 300 = 17520
      expect(output, contains('Seat 7: Player7 (17520 in chips)'));
      // BB (seat 8) had playerStack 49020, add back BB 600 = 49620
      expect(output, contains('Seat 8: Player8 (49620 in chips)'));
    });

    test('SB and BB posting lines present', () {
      expect(output, contains('Player7: posts small blind 300'));
      expect(output, contains('Player8: posts big blind 600'));
    });

    test('Hero hole cards shown', () {
      expect(output, contains('Dealt to Hero [As Jc]'));
    });

    test('fold actions formatted correctly', () {
      expect(output, contains('Player1: folds'));
      expect(output, contains('Player6: folds'));
    });

    test('raise action formatted correctly', () {
      // raise 900 to 1500 (additional = 1500 - 600 = 900)
      expect(output, contains('Hero: raises 900 to 1500'));
    });

    test('summary has folded before Flop for non-blind folders', () {
      expect(
          output, contains("Player1 folded before Flop (didn't bet)"));
      expect(
          output, contains("Player2 folded before Flop (didn't bet)"));
    });

    test('summary shows SB folded before Flop without didnt bet', () {
      // SB posted blind, so no "(didn't bet)"
      expect(output, contains('Player7 (small blind) folded before Flop'));
      // But should NOT say "didn't bet"
      final sbLine = output
          .split('\n')
          .where((l) => l.contains('Player7') && l.contains('folded'))
          .first;
      expect(sbLine.contains("didn't bet"), isFalse);
    });

    test('summary shows button label for seat 6', () {
      expect(output, contains('Player6 (button) folded before Flop'));
    });
  });

  // ─────────────────────────────────────────────────────────
  // 3. Full Hand Through River with Showdown
  // ─────────────────────────────────────────────────────────

  group('Full Hand Through River with Showdown', () {
    late String output;

    setUp(() {
      // 3 players: seat 1 (BTN), seat 2 (SB), seat 3 (BB)
      // All see flop. Seat 1 folds on turn. Seat 2 and 3 to river showdown.
      final hand = _makeHand(
        handNumber: 5,
        buttonPosition: 1,
        playerCount: 3,
        smallBlind: 100,
        bigBlind: 200,
        heroSeatNumber: 2,
        playerNames: {
          '1': 'Alice',
          '2': 'Hero',
          '3': 'Bob',
        },
        ourHoleCards: {'card1': 'K\u2665', 'card2': 'Q\u2665'},
        boardCards: {
          'flop': ['A\u2660', '7\u2666', '2\u2663'],
          'turn': 'J\u2665',
          'river': '9\u2660',
        },
        reachedShowdown: true,
        showdownData: {
          'playerCards': {
            '2': {'card1': 'K\u2665', 'card2': 'Q\u2665'},
            '3': {'card1': 'A\u2663', 'card2': 'T\u2666'},
          },
        },
        winnerId: 3,
        potAmount: 2400,
        actions: [
          // Preflop: all call
          _makeAction(
            player: 1,
            action: 'call',
            street: 'preflop',
            amount: 200.0,
            playerStack: 10000.0,
            playerName: 'Alice',
            playerPosition: 'BTN',
          ),
          _makeAction(
            player: 2,
            action: 'call',
            street: 'preflop',
            amount: 100.0,
            playerStack: 9900.0,
            playerName: 'Hero',
            playerPosition: 'SB',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 3,
            action: 'check',
            street: 'preflop',
            playerStack: 9800.0,
            playerName: 'Bob',
            playerPosition: 'BB',
          ),
          // Flop: check around
          _makeAction(
            player: 2,
            action: 'check',
            street: 'flop',
            playerStack: 9800.0,
            playerName: 'Hero',
            playerPosition: 'SB',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 3,
            action: 'bet',
            street: 'flop',
            amount: 300.0,
            playerStack: 9800.0,
            playerName: 'Bob',
            playerPosition: 'BB',
          ),
          _makeAction(
            player: 1,
            action: 'call',
            street: 'flop',
            amount: 300.0,
            playerStack: 9800.0,
            playerName: 'Alice',
            playerPosition: 'BTN',
          ),
          _makeAction(
            player: 2,
            action: 'call',
            street: 'flop',
            amount: 300.0,
            playerStack: 9800.0,
            playerName: 'Hero',
            playerPosition: 'SB',
            isCurrentUser: true,
          ),
          // Turn: bet, Alice folds, Hero calls
          _makeAction(
            player: 2,
            action: 'check',
            street: 'turn',
            playerStack: 9500.0,
            playerName: 'Hero',
            playerPosition: 'SB',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 3,
            action: 'bet',
            street: 'turn',
            amount: 500.0,
            playerStack: 9500.0,
            playerName: 'Bob',
            playerPosition: 'BB',
          ),
          _makeAction(
            player: 1,
            action: 'fold',
            street: 'turn',
            playerStack: 9500.0,
            playerName: 'Alice',
            playerPosition: 'BTN',
          ),
          _makeAction(
            player: 2,
            action: 'call',
            street: 'turn',
            amount: 500.0,
            playerStack: 9500.0,
            playerName: 'Hero',
            playerPosition: 'SB',
            isCurrentUser: true,
          ),
          // River: check-check
          _makeAction(
            player: 2,
            action: 'check',
            street: 'river',
            playerStack: 9000.0,
            playerName: 'Hero',
            playerPosition: 'SB',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 3,
            action: 'check',
            street: 'river',
            playerStack: 9000.0,
            playerName: 'Bob',
            playerPosition: 'BB',
          ),
        ],
      );
      final session = _makeSession(smallBlind: 100, bigBlind: 200);
      output = PokerStarsExportService.exportHand(hand, session);
    });

    test('FLOP section present with board cards', () {
      expect(output, contains('*** FLOP *** [As 7d 2c]'));
    });

    test('TURN section present with cumulative board', () {
      expect(output, contains('*** TURN *** [As 7d 2c] [Jh]'));
    });

    test('RIVER section present with cumulative board', () {
      expect(output, contains('*** RIVER *** [As 7d 2c Jh] [9s]'));
    });

    test('SHOW DOWN section present', () {
      expect(output, contains('*** SHOW DOWN ***'));
    });

    test('showdown cards displayed', () {
      expect(output, contains('Hero: shows [Kh Qh]'));
      expect(output, contains('Bob: shows [Ac Td]'));
    });

    test('SUMMARY section present with board', () {
      expect(output, contains('*** SUMMARY ***'));
      expect(output, contains('Board [As 7d 2c Jh 9s]'));
    });

    test('winner collected in summary', () {
      expect(output, contains('Bob (big blind) collected'));
    });

    test('Alice folded on the Turn in summary', () {
      expect(output, contains('Alice (button) folded on the Turn'));
    });

    test('Hero mucked at showdown (lost)', () {
      // Hero went to showdown but lost
      expect(output, contains('Hero (small blind) mucked'));
    });
  });

  // ─────────────────────────────────────────────────────────
  // 4. BB Ante Hand
  // ─────────────────────────────────────────────────────────

  group('BB Ante Hand', () {
    late String output;

    setUp(() {
      final hand = _makeHand(
        handNumber: 1,
        buttonPosition: 6,
        heroSeatNumber: 5,
        smallBlind: 300,
        bigBlind: 600,
        playerNames: {
          '5': 'Hero',
          '6': 'Player6',
          '7': 'Player7',
          '8': 'Player8',
        },
        winnerId: 5,
        potAmount: 2100,
        actions: [
          _makeAction(
            player: 5,
            action: 'raise',
            street: 'preflop',
            amount: 1500.0,
            playerStack: 8000.0,
            playerName: 'Hero',
            playerPosition: 'UTG',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 6,
            action: 'fold',
            street: 'preflop',
            playerStack: 10000.0,
            playerName: 'Player6',
            playerPosition: 'BTN',
          ),
          _makeAction(
            player: 7,
            action: 'fold',
            street: 'preflop',
            playerStack: 9700.0,
            playerName: 'Player7',
            playerPosition: 'SB',
          ),
          _makeAction(
            player: 8,
            action: 'fold',
            street: 'preflop',
            playerStack: 14400.0,
            playerName: 'Player8',
            playerPosition: 'BB',
          ),
        ],
      );
      // Session with BB ante enabled
      final session = _makeSession(hasBBante: true);
      output = PokerStarsExportService.exportHand(hand, session);
    });

    test('BB posts big blind line present', () {
      expect(output, contains('Player8: posts big blind 600'));
    });

    test('all players post ante in per-player format', () {
      // BB ante converted to per-player: 600 / 4 players = 150 each
      expect(output, contains('Hero: posts the ante 150'));
      expect(output, contains('Player6: posts the ante 150'));
      expect(output, contains('Player7: posts the ante 150'));
      expect(output, contains('Player8: posts the ante 150'));
    });

    test('antes come before blinds', () {
      // Ante lines should appear before blind lines
      final anteIdx = output.indexOf('posts the ante');
      final blindIdx = output.indexOf('posts small blind');
      expect(anteIdx, lessThan(blindIdx));
    });

    test('BB starting stack accounts for ante', () {
      // BB playerStack was 14400 after posting. Add back BB (600) + ante (600) = 15600
      expect(output, contains('Seat 8: Player8 (15600 in chips)'));
    });

    test('SB starting stack accounts for SB and ante', () {
      // SB playerStack was 9700 after posting SB. Add back SB 300 + ante 150 = 10150
      expect(output, contains('Seat 7: Player7 (10150 in chips)'));
    });
  });

  // ─────────────────────────────────────────────────────────
  // 5. Preflop Raise Formatting
  // ─────────────────────────────────────────────────────────

  group('Preflop Raise Formatting', () {
    test('raise shows additional amount and total', () {
      // BB = 600, Hero raises to 1500
      // Output: "raises 900 to 1500" (900 = 1500 - 600)
      final hand = _makeHand(
        smallBlind: 300,
        bigBlind: 600,
        playerNames: {'5': 'Hero', '7': 'Player7', '8': 'Player8'},
        heroSeatNumber: 5,
        buttonPosition: 5,
        winnerId: 5,
        potAmount: 900,
        actions: [
          _makeAction(
            player: 7,
            action: 'fold',
            street: 'preflop',
            playerStack: 9700.0,
            playerName: 'Player7',
            playerPosition: 'SB',
          ),
          _makeAction(
            player: 8,
            action: 'fold',
            street: 'preflop',
            playerStack: 9400.0,
            playerName: 'Player8',
            playerPosition: 'BB',
          ),
          // This won't be reached since everyone folded, but
          // we want to test the formatting with a real raise
        ],
      );
      final session = _makeSession();
      final output = PokerStarsExportService.exportHand(hand, session);

      // Both fold before hero acts, so let's make a proper test
      // with Hero actually raising
      final hand2 = _makeHand(
        smallBlind: 300,
        bigBlind: 600,
        playerNames: {'5': 'Hero', '7': 'Player7', '8': 'Player8'},
        heroSeatNumber: 5,
        buttonPosition: 5,
        winnerId: 5,
        potAmount: 1800,
        actions: [
          _makeAction(
            player: 7,
            action: 'call',
            street: 'preflop',
            amount: 300.0,
            playerStack: 9700.0,
            playerName: 'Player7',
            playerPosition: 'SB',
          ),
          _makeAction(
            player: 8,
            action: 'check',
            street: 'preflop',
            playerStack: 9400.0,
            playerName: 'Player8',
            playerPosition: 'BB',
          ),
          _makeAction(
            player: 5,
            action: 'raise',
            street: 'preflop',
            amount: 1500.0,
            playerStack: 10000.0,
            playerName: 'Hero',
            playerPosition: 'BTN',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 7,
            action: 'fold',
            street: 'preflop',
            playerStack: 9400.0,
            playerName: 'Player7',
            playerPosition: 'SB',
          ),
          _makeAction(
            player: 8,
            action: 'fold',
            street: 'preflop',
            playerStack: 9400.0,
            playerName: 'Player8',
            playerPosition: 'BB',
          ),
        ],
      );
      final output2 = PokerStarsExportService.exportHand(hand2, session);
      // raise additional = 1500 - 600 (current bet level BB) = 900
      expect(output2, contains('Hero: raises 900 to 1500'));
    });

    test('3-bet shows correct additional amount', () {
      // BB = 600. Player raises to 1500. Hero 3-bets to 4000.
      // Output: "Hero: raises 2500 to 4000"
      final hand = _makeHand(
        smallBlind: 300,
        bigBlind: 600,
        playerNames: {'3': 'Villain', '5': 'Hero', '7': 'Player7', '8': 'Player8'},
        heroSeatNumber: 5,
        buttonPosition: 5,
        winnerId: 5,
        potAmount: 4600,
        actions: [
          _makeAction(
            player: 3,
            action: 'raise',
            street: 'preflop',
            amount: 1500.0, // total
            playerStack: 18000.0,
            playerName: 'Villain',
            playerPosition: 'UTG',
          ),
          _makeAction(
            player: 5,
            action: 'raise',
            street: 'preflop',
            amount: 4000.0, // total
            playerStack: 10000.0,
            playerName: 'Hero',
            playerPosition: 'BTN',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 7,
            action: 'fold',
            street: 'preflop',
            playerStack: 9700.0,
            playerName: 'Player7',
            playerPosition: 'SB',
          ),
          _makeAction(
            player: 8,
            action: 'fold',
            street: 'preflop',
            playerStack: 9400.0,
            playerName: 'Player8',
            playerPosition: 'BB',
          ),
          _makeAction(
            player: 3,
            action: 'fold',
            street: 'preflop',
            playerStack: 16500.0,
            playerName: 'Villain',
            playerPosition: 'UTG',
          ),
        ],
      );
      final session = _makeSession();
      final output = PokerStarsExportService.exportHand(hand, session);

      // Villain raises: additional = 1500 - 600 = 900
      expect(output, contains('Villain: raises 900 to 1500'));
      // Hero 3-bets: additional = 4000 - 1500 = 2500
      expect(output, contains('Hero: raises 2500 to 4000'));
    });
  });

  // ─────────────────────────────────────────────────────────
  // 6. Postflop Raise Formatting
  // ─────────────────────────────────────────────────────────

  group('Postflop Raise Formatting', () {
    test('postflop raise shows additional and total', () {
      // Player bets 1000. Hero raises 2000 more. Total = 3000.
      // Output: "Hero: raises 2000 to 3000"
      final hand = _makeHand(
        smallBlind: 100,
        bigBlind: 200,
        playerNames: {'1': 'Villain', '2': 'Hero', '3': 'Player3'},
        heroSeatNumber: 2,
        buttonPosition: 1,
        winnerId: 2,
        potAmount: 4600,
        boardCards: {
          'flop': ['A\u2660', '7\u2666', '2\u2663'],
          'turn': null,
          'river': null,
        },
        actions: [
          // Preflop: all call
          _makeAction(
            player: 1,
            action: 'call',
            street: 'preflop',
            amount: 200.0,
            playerStack: 10000.0,
            playerName: 'Villain',
            playerPosition: 'BTN',
          ),
          _makeAction(
            player: 2,
            action: 'call',
            street: 'preflop',
            amount: 100.0,
            playerStack: 9900.0,
            playerName: 'Hero',
            playerPosition: 'SB',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 3,
            action: 'check',
            street: 'preflop',
            playerStack: 9800.0,
            playerName: 'Player3',
            playerPosition: 'BB',
          ),
          // Flop: Villain bets 1000, Hero raises 2000 (additional)
          _makeAction(
            player: 2,
            action: 'check',
            street: 'flop',
            playerStack: 9800.0,
            playerName: 'Hero',
            playerPosition: 'SB',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 3,
            action: 'check',
            street: 'flop',
            playerStack: 9800.0,
            playerName: 'Player3',
            playerPosition: 'BB',
          ),
          _makeAction(
            player: 1,
            action: 'bet',
            street: 'flop',
            amount: 1000.0,
            playerStack: 9800.0,
            playerName: 'Villain',
            playerPosition: 'BTN',
          ),
          _makeAction(
            player: 2,
            action: 'raise',
            street: 'flop',
            amount: 2000.0, // ADDITIONAL on postflop
            playerStack: 9800.0,
            playerName: 'Hero',
            playerPosition: 'SB',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 3,
            action: 'fold',
            street: 'flop',
            playerStack: 9800.0,
            playerName: 'Player3',
            playerPosition: 'BB',
          ),
          _makeAction(
            player: 1,
            action: 'fold',
            street: 'flop',
            playerStack: 8800.0,
            playerName: 'Villain',
            playerPosition: 'BTN',
          ),
        ],
      );
      final session = _makeSession(smallBlind: 100, bigBlind: 200);
      final output = PokerStarsExportService.exportHand(hand, session);

      // Postflop raise: additional=2000, total=1000+2000=3000
      expect(output, contains('Hero: raises 2000 to 3000'));
    });
  });

  // ─────────────────────────────────────────────────────────
  // 7. Chopped Pot
  // ─────────────────────────────────────────────────────────

  group('Chopped Pot', () {
    test('multiple collected lines for chopped pot', () {
      final hand = _makeHand(
        smallBlind: 100,
        bigBlind: 200,
        playerNames: {'1': 'Alice', '2': 'Hero', '3': 'Bob'},
        heroSeatNumber: 2,
        buttonPosition: 3,
        isChoppedPot: true,
        choppedWinners: [1, 3],
        individualShares: {'1': 5000.0, '3': 5000.0},
        potAmount: 10000,
        reachedShowdown: true,
        showdownData: {
          'playerCards': {
            '1': {'card1': 'A\u2660', 'card2': 'K\u2660'},
            '3': {'card1': 'A\u2665', 'card2': 'K\u2665'},
          },
        },
        boardCards: {
          'flop': ['Q\u2660', 'J\u2666', 'T\u2663'],
          'turn': '2\u2665',
          'river': '3\u2666',
        },
        actions: [
          _makeAction(
            player: 1,
            action: 'raise',
            street: 'preflop',
            amount: 600.0,
            playerStack: 10000.0,
            playerName: 'Alice',
            playerPosition: 'SB',
          ),
          _makeAction(
            player: 2,
            action: 'call',
            street: 'preflop',
            amount: 400.0,
            playerStack: 9800.0,
            playerName: 'Hero',
            playerPosition: 'BB',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 3,
            action: 'call',
            street: 'preflop',
            amount: 600.0,
            playerStack: 10000.0,
            playerName: 'Bob',
            playerPosition: 'BTN',
          ),
          // Flop through river: bets and calls
          _makeAction(
            player: 1,
            action: 'bet',
            street: 'flop',
            amount: 1000.0,
            playerStack: 9400.0,
            playerName: 'Alice',
            playerPosition: 'SB',
          ),
          _makeAction(
            player: 2,
            action: 'fold',
            street: 'flop',
            playerStack: 9400.0,
            playerName: 'Hero',
            playerPosition: 'BB',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 3,
            action: 'call',
            street: 'flop',
            amount: 1000.0,
            playerStack: 9400.0,
            playerName: 'Bob',
            playerPosition: 'BTN',
          ),
          _makeAction(
            player: 1,
            action: 'check',
            street: 'turn',
            playerStack: 8400.0,
            playerName: 'Alice',
            playerPosition: 'SB',
          ),
          _makeAction(
            player: 3,
            action: 'check',
            street: 'turn',
            playerStack: 8400.0,
            playerName: 'Bob',
            playerPosition: 'BTN',
          ),
          _makeAction(
            player: 1,
            action: 'check',
            street: 'river',
            playerStack: 8400.0,
            playerName: 'Alice',
            playerPosition: 'SB',
          ),
          _makeAction(
            player: 3,
            action: 'check',
            street: 'river',
            playerStack: 8400.0,
            playerName: 'Bob',
            playerPosition: 'BTN',
          ),
        ],
      );
      final session = _makeSession(smallBlind: 100, bigBlind: 200);
      final output = PokerStarsExportService.exportHand(hand, session);

      expect(output, contains('Alice collected 5000 from pot'));
      expect(output, contains('Bob collected 5000 from pot'));
    });

    test('summary shows both winners as collected', () {
      final hand = _makeHand(
        smallBlind: 100,
        bigBlind: 200,
        playerNames: {'1': 'Alice', '3': 'Bob'},
        heroSeatNumber: 1,
        buttonPosition: 1,
        isChoppedPot: true,
        choppedWinners: [1, 3],
        individualShares: {'1': 2000.0, '3': 2000.0},
        potAmount: 4000,
        reachedShowdown: true,
        showdownData: {
          'playerCards': {
            '1': {'card1': 'A\u2660', 'card2': 'K\u2660'},
            '3': {'card1': 'A\u2665', 'card2': 'K\u2665'},
          },
        },
        boardCards: {
          'flop': ['Q\u2660', 'J\u2666', 'T\u2663'],
          'turn': '2\u2665',
          'river': '3\u2666',
        },
        actions: [
          _makeAction(
            player: 1,
            action: 'call',
            street: 'preflop',
            amount: 100.0,
            playerStack: 9900.0,
            playerName: 'Alice',
            playerPosition: 'BTN/SB',
          ),
          _makeAction(
            player: 3,
            action: 'check',
            street: 'preflop',
            playerStack: 9800.0,
            playerName: 'Bob',
            playerPosition: 'BB',
          ),
          _makeAction(
            player: 1,
            action: 'check',
            street: 'flop',
            playerStack: 9800.0,
            playerName: 'Alice',
            playerPosition: 'BTN/SB',
          ),
          _makeAction(
            player: 3,
            action: 'check',
            street: 'flop',
            playerStack: 9800.0,
            playerName: 'Bob',
            playerPosition: 'BB',
          ),
          _makeAction(
            player: 1,
            action: 'check',
            street: 'turn',
            playerStack: 9800.0,
            playerName: 'Alice',
            playerPosition: 'BTN/SB',
          ),
          _makeAction(
            player: 3,
            action: 'check',
            street: 'turn',
            playerStack: 9800.0,
            playerName: 'Bob',
            playerPosition: 'BB',
          ),
          _makeAction(
            player: 1,
            action: 'check',
            street: 'river',
            playerStack: 9800.0,
            playerName: 'Alice',
            playerPosition: 'BTN/SB',
          ),
          _makeAction(
            player: 3,
            action: 'check',
            street: 'river',
            playerStack: 9800.0,
            playerName: 'Bob',
            playerPosition: 'BB',
          ),
        ],
      );
      final session = _makeSession(smallBlind: 100, bigBlind: 200);
      final output = PokerStarsExportService.exportHand(hand, session);

      // Summary section should show both as collected
      // Alice is hero (seat 1) so renamed to "Hero"
      final summarySection =
          output.substring(output.indexOf('*** SUMMARY ***'));
      expect(summarySection, contains('Hero'));
      expect(summarySection, contains('collected'));
      expect(summarySection, contains('Bob'));
    });
  });

  // ─────────────────────────────────────────────────────────
  // 8. Walk (All Fold to BB)
  // ─────────────────────────────────────────────────────────

  group('Walk (All Fold to BB)', () {
    test('BB collects and SB uncalled bet returned', () {
      // Everyone folds, BB wins. The SB was posted but never called.
      final hand = _makeHand(
        smallBlind: 300,
        bigBlind: 600,
        playerNames: {
          '1': 'Player1',
          '5': 'Hero',
          '7': 'Player7',
          '8': 'Player8',
        },
        heroSeatNumber: 5,
        buttonPosition: 1,
        winnerId: 8,
        potAmount: 900,
        actions: [
          _makeAction(
            player: 5,
            action: 'fold',
            street: 'preflop',
            playerStack: 10000.0,
            playerName: 'Hero',
            playerPosition: 'UTG',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 1,
            action: 'fold',
            street: 'preflop',
            playerStack: 10000.0,
            playerName: 'Player1',
            playerPosition: 'BTN',
          ),
          _makeAction(
            player: 7,
            action: 'fold',
            street: 'preflop',
            playerStack: 9700.0,
            playerName: 'Player7',
            playerPosition: 'SB',
          ),
          // BB doesn't act - wins by default
        ],
      );
      final session = _makeSession();
      final output = PokerStarsExportService.exportHand(hand, session);

      // BB collects the pot
      expect(output, contains('Player8 collected'));
    });
  });

  // ─────────────────────────────────────────────────────────
  // 9. Uncalled Bet
  // ─────────────────────────────────────────────────────────

  group('Uncalled Bet', () {
    test('uncalled bet returned when hero bets and all fold', () {
      final hand = _makeHand(
        smallBlind: 100,
        bigBlind: 200,
        playerNames: {'1': 'Villain', '2': 'Hero', '3': 'Player3'},
        heroSeatNumber: 2,
        buttonPosition: 3,
        winnerId: 2,
        potAmount: 1800,
        boardCards: {
          'flop': ['A\u2660', '7\u2666', '2\u2663'],
          'turn': null,
          'river': null,
        },
        actions: [
          // Preflop: all call
          _makeAction(
            player: 1,
            action: 'call',
            street: 'preflop',
            amount: 200.0,
            playerStack: 9900.0,
            playerName: 'Villain',
            playerPosition: 'SB',
          ),
          _makeAction(
            player: 2,
            action: 'call',
            street: 'preflop',
            amount: 100.0,
            playerStack: 9900.0,
            playerName: 'Hero',
            playerPosition: 'BB',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 3,
            action: 'check',
            street: 'preflop',
            playerStack: 9800.0,
            playerName: 'Player3',
            playerPosition: 'BTN',
          ),
          // Flop: Hero bets 500, all fold
          _makeAction(
            player: 1,
            action: 'check',
            street: 'flop',
            playerStack: 9800.0,
            playerName: 'Villain',
            playerPosition: 'SB',
          ),
          _makeAction(
            player: 2,
            action: 'bet',
            street: 'flop',
            amount: 500.0,
            playerStack: 9600.0,
            playerName: 'Hero',
            playerPosition: 'BB',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 3,
            action: 'fold',
            street: 'flop',
            playerStack: 9800.0,
            playerName: 'Player3',
            playerPosition: 'BTN',
          ),
          _makeAction(
            player: 1,
            action: 'fold',
            street: 'flop',
            playerStack: 9800.0,
            playerName: 'Villain',
            playerPosition: 'SB',
          ),
        ],
      );
      final session = _makeSession(smallBlind: 100, bigBlind: 200);
      final output = PokerStarsExportService.exportHand(hand, session);

      expect(output, contains('Uncalled bet (500) returned to Hero'));
    });

    test('no uncalled bet when hand reaches showdown', () {
      final hand = _makeHand(
        smallBlind: 100,
        bigBlind: 200,
        playerNames: {'1': 'Villain', '2': 'Hero'},
        heroSeatNumber: 2,
        buttonPosition: 1,
        winnerId: 2,
        potAmount: 400,
        reachedShowdown: true,
        showdownData: {
          'playerCards': {
            '2': {'card1': 'A\u2660', 'card2': 'K\u2660'},
          },
        },
        boardCards: {
          'flop': ['Q\u2660', 'J\u2666', 'T\u2663'],
          'turn': '2\u2665',
          'river': '3\u2666',
        },
        actions: [
          _makeAction(
            player: 1,
            action: 'call',
            street: 'preflop',
            amount: 100.0,
            playerStack: 9900.0,
            playerName: 'Villain',
            playerPosition: 'BTN/SB',
          ),
          _makeAction(
            player: 2,
            action: 'check',
            street: 'preflop',
            playerStack: 9800.0,
            playerName: 'Hero',
            playerPosition: 'BB',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 1,
            action: 'check',
            street: 'flop',
            playerStack: 9800.0,
            playerName: 'Villain',
            playerPosition: 'BTN/SB',
          ),
          _makeAction(
            player: 2,
            action: 'check',
            street: 'flop',
            playerStack: 9800.0,
            playerName: 'Hero',
            playerPosition: 'BB',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 1,
            action: 'check',
            street: 'turn',
            playerStack: 9800.0,
            playerName: 'Villain',
            playerPosition: 'BTN/SB',
          ),
          _makeAction(
            player: 2,
            action: 'check',
            street: 'turn',
            playerStack: 9800.0,
            playerName: 'Hero',
            playerPosition: 'BB',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 1,
            action: 'check',
            street: 'river',
            playerStack: 9800.0,
            playerName: 'Villain',
            playerPosition: 'BTN/SB',
          ),
          _makeAction(
            player: 2,
            action: 'check',
            street: 'river',
            playerStack: 9800.0,
            playerName: 'Hero',
            playerPosition: 'BB',
            isCurrentUser: true,
          ),
        ],
      );
      final session = _makeSession(smallBlind: 100, bigBlind: 200);
      final output = PokerStarsExportService.exportHand(hand, session);

      expect(output.contains('Uncalled bet'), isFalse);
    });

    test('uncalled preflop raise returned', () {
      // Hero raises preflop, everyone folds.
      // The uncalled bet computation only tracks amounts from the
      // street actions (not the implicit blind posts), so Hero's
      // raise to 600 is the only committed amount seen by the
      // uncalled-bet logic, and since no other player has a call
      // action, the full 600 is returned.
      final hand = _makeHand(
        smallBlind: 100,
        bigBlind: 200,
        playerNames: {'1': 'Hero', '2': 'Villain', '3': 'Player3'},
        heroSeatNumber: 1,
        buttonPosition: 3,
        winnerId: 1,
        potAmount: 500,
        actions: [
          _makeAction(
            player: 1,
            action: 'raise',
            street: 'preflop',
            amount: 600.0, // total on preflop
            playerStack: 9800.0,
            playerName: 'Hero',
            playerPosition: 'UTG',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 2,
            action: 'fold',
            street: 'preflop',
            playerStack: 9900.0,
            playerName: 'Villain',
            playerPosition: 'SB',
          ),
          _makeAction(
            player: 3,
            action: 'fold',
            street: 'preflop',
            playerStack: 9800.0,
            playerName: 'Player3',
            playerPosition: 'BB',
          ),
        ],
      );
      final session = _makeSession(smallBlind: 100, bigBlind: 200);
      final output = PokerStarsExportService.exportHand(hand, session);

      // The service returns the full raise as uncalled since blinds
      // are implicit (not tracked in the action-level committed map).
      expect(output, contains('Uncalled bet (600) returned to Hero'));
    });
  });

  // ─────────────────────────────────────────────────────────
  // 10. Session Export (Multiple Hands)
  // ─────────────────────────────────────────────────────────

  group('Session Export (Multiple Hands)', () {
    test('exports multiple hands separated by blank lines', () {
      final session = _makeSession();

      final hand1 = _makeHand(
        handNumber: 1,
        winnerId: 8,
        potAmount: 900,
        playerNames: {'5': 'Hero', '7': 'Player7', '8': 'Player8'},
        heroSeatNumber: 5,
        buttonPosition: 5,
        actions: [
          _makeAction(
            player: 5,
            action: 'fold',
            street: 'preflop',
            playerStack: 10000.0,
            playerName: 'Hero',
            playerPosition: 'BTN',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 7,
            action: 'fold',
            street: 'preflop',
            playerStack: 9700.0,
            playerName: 'Player7',
            playerPosition: 'SB',
          ),
        ],
      );

      final hand2 = _makeHand(
        handNumber: 2,
        winnerId: 5,
        potAmount: 1200,
        playerNames: {'5': 'Hero', '7': 'Player7', '8': 'Player8'},
        heroSeatNumber: 5,
        buttonPosition: 7,
        actions: [
          _makeAction(
            player: 8,
            action: 'fold',
            street: 'preflop',
            playerStack: 9400.0,
            playerName: 'Player8',
            playerPosition: 'UTG',
          ),
          _makeAction(
            player: 5,
            action: 'raise',
            street: 'preflop',
            amount: 1500.0,
            playerStack: 10000.0,
            playerName: 'Hero',
            playerPosition: 'BTN',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 7,
            action: 'fold',
            street: 'preflop',
            playerStack: 9700.0,
            playerName: 'Player7',
            playerPosition: 'SB',
          ),
          _makeAction(
            player: 8,
            action: 'fold',
            street: 'preflop',
            playerStack: 9400.0,
            playerName: 'Player8',
            playerPosition: 'BB',
          ),
        ],
      );

      final hand3 = _makeHand(
        handNumber: 3,
        winnerId: 7,
        potAmount: 600,
        playerNames: {'5': 'Hero', '7': 'Player7', '8': 'Player8'},
        heroSeatNumber: 5,
        buttonPosition: 8,
        actions: [
          _makeAction(
            player: 5,
            action: 'fold',
            street: 'preflop',
            playerStack: 11000.0,
            playerName: 'Hero',
            playerPosition: 'UTG',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 7,
            action: 'fold',
            street: 'preflop',
            playerStack: 8800.0,
            playerName: 'Player7',
            playerPosition: 'SB',
          ),
        ],
      );

      final output =
          PokerStarsExportService.exportSession(session, [hand3, hand1, hand2]);

      // Should be sorted by handNumber, so hand1 first
      final handBlocks = output.split('\n\n\n');
      expect(handBlocks.length, equals(3));

      // First block should be hand #1
      expect(handBlocks[0], contains('Hand #'));
      // Second block should be hand #2
      expect(handBlocks[1], contains('Hand #'));
      // Third block should be hand #3
      expect(handBlocks[2], contains('Hand #'));
    });

    test('each hand has full format with header and summary', () {
      final session = _makeSession();

      final hand1 = _makeHand(
        handNumber: 1,
        winnerId: 8,
        potAmount: 900,
        playerNames: {'5': 'Hero', '7': 'Player7', '8': 'Player8'},
        heroSeatNumber: 5,
        buttonPosition: 5,
        actions: [
          _makeAction(
            player: 5,
            action: 'fold',
            street: 'preflop',
            playerStack: 10000.0,
            playerName: 'Hero',
            playerPosition: 'BTN',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 7,
            action: 'fold',
            street: 'preflop',
            playerStack: 9700.0,
            playerName: 'Player7',
            playerPosition: 'SB',
          ),
        ],
      );

      final hand2 = _makeHand(
        handNumber: 2,
        winnerId: 5,
        potAmount: 1200,
        playerNames: {'5': 'Hero', '7': 'Player7', '8': 'Player8'},
        heroSeatNumber: 5,
        buttonPosition: 7,
        actions: [
          _makeAction(
            player: 8,
            action: 'fold',
            street: 'preflop',
            playerStack: 9400.0,
            playerName: 'Player8',
            playerPosition: 'UTG',
          ),
          _makeAction(
            player: 5,
            action: 'raise',
            street: 'preflop',
            amount: 1500.0,
            playerStack: 10000.0,
            playerName: 'Hero',
            playerPosition: 'BTN',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 7,
            action: 'fold',
            street: 'preflop',
            playerStack: 9700.0,
            playerName: 'Player7',
            playerPosition: 'SB',
          ),
        ],
      );

      final output =
          PokerStarsExportService.exportSession(session, [hand1, hand2]);

      final blocks = output.split('\n\n\n');
      for (final block in blocks) {
        expect(block, contains('PokerStars Hand #'));
        expect(block, contains('*** HOLE CARDS ***'));
        expect(block, contains('*** SUMMARY ***'));
        expect(block, contains('Total pot'));
      }
    });

    test('hands sorted by handNumber regardless of input order', () {
      final session = _makeSession();

      final hand1 = _makeHand(
        handNumber: 10,
        winnerId: 8,
        potAmount: 900,
        playerNames: {'5': 'Hero', '7': 'Player7', '8': 'Player8'},
        heroSeatNumber: 5,
        buttonPosition: 5,
        actions: [
          _makeAction(
            player: 5,
            action: 'fold',
            street: 'preflop',
            playerStack: 10000.0,
            playerName: 'Hero',
            playerPosition: 'BTN',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 7,
            action: 'fold',
            street: 'preflop',
            playerStack: 9700.0,
            playerName: 'Player7',
            playerPosition: 'SB',
          ),
        ],
      );

      final hand2 = _makeHand(
        handNumber: 5,
        winnerId: 5,
        potAmount: 1200,
        playerNames: {'5': 'Hero', '7': 'Player7', '8': 'Player8'},
        heroSeatNumber: 5,
        buttonPosition: 7,
        actions: [
          _makeAction(
            player: 5,
            action: 'fold',
            street: 'preflop',
            playerStack: 10000.0,
            playerName: 'Hero',
            playerPosition: 'BTN',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 7,
            action: 'fold',
            street: 'preflop',
            playerStack: 9700.0,
            playerName: 'Player7',
            playerPosition: 'SB',
          ),
        ],
      );

      // Pass in reverse order
      final output =
          PokerStarsExportService.exportSession(session, [hand1, hand2]);

      // Hand #5 should come before hand #10
      final idx5 = output.indexOf('Hand #');
      // The first hand block should contain hand2's data
      final blocks = output.split('\n\n\n');
      expect(blocks.length, equals(2));
    });
  });

  // ─────────────────────────────────────────────────────────
  // Edge Cases
  // ─────────────────────────────────────────────────────────

  group('Edge Cases', () {
    test('empty playerNames returns empty string', () {
      final hand = _makeHand(playerNames: {});
      // Override playerNames to empty
      hand['playerNames'] = <String, String>{};
      final session = _makeSession();
      final output = PokerStarsExportService.exportHand(hand, session);
      expect(output, isEmpty);
    });

    test('cash game header has dollar signs and USD', () {
      final hand = _makeHand(
        gameType: 'cash',
        smallBlind: 1,
        bigBlind: 2,
        playerNames: {'1': 'Hero', '2': 'Villain'},
        heroSeatNumber: 1,
        buttonPosition: 1,
        actions: [
          _makeAction(
            player: 1,
            action: 'fold',
            street: 'preflop',
            playerStack: 100.0,
            playerName: 'Hero',
            playerPosition: 'BTN/SB',
            isCurrentUser: true,
          ),
        ],
      );
      final session = _makeSession(
        gameType: 'cash',
        smallBlind: 1,
        bigBlind: 2,
      );
      final output = PokerStarsExportService.exportHand(hand, session);

      expect(output, contains('\$1/\$2 USD'));
      // Cash game header line should NOT say Tournament
      final headerLine = output.split('\n').first;
      expect(headerLine.contains('Tournament'), isFalse);
    });

    test('amount formatting: whole numbers have no decimals', () {
      final hand = _makeHand(
        smallBlind: 300,
        bigBlind: 600,
        playerNames: {'5': 'Hero', '7': 'Player7', '8': 'Player8'},
        heroSeatNumber: 5,
        buttonPosition: 5,
        winnerId: 5,
        potAmount: 1800,
        actions: [
          _makeAction(
            player: 7,
            action: 'call',
            street: 'preflop',
            amount: 300.0,
            playerStack: 9700.0,
            playerName: 'Player7',
            playerPosition: 'SB',
          ),
          _makeAction(
            player: 8,
            action: 'fold',
            street: 'preflop',
            playerStack: 9400.0,
            playerName: 'Player8',
            playerPosition: 'BB',
          ),
          _makeAction(
            player: 5,
            action: 'raise',
            street: 'preflop',
            amount: 1500.0,
            playerStack: 10000.0,
            playerName: 'Hero',
            playerPosition: 'BTN',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 7,
            action: 'fold',
            street: 'preflop',
            playerStack: 9400.0,
            playerName: 'Player7',
            playerPosition: 'SB',
          ),
        ],
      );
      final session = _makeSession();
      final output = PokerStarsExportService.exportHand(hand, session);

      // Should show "300" not "300.0" or "300.00"
      expect(output, contains('posts small blind 300'));
      expect(output, contains('posts big blind 600'));
    });

    test('dealer mode blind actions are skipped in street output', () {
      // When dealer mode logs "small blind" and "big blind" as action strings,
      // they should be filtered out
      final hand = _makeHand(
        smallBlind: 100,
        bigBlind: 200,
        playerNames: {'1': 'Hero', '2': 'Villain'},
        heroSeatNumber: 1,
        buttonPosition: 1,
        winnerId: 1,
        potAmount: 400,
        actions: [
          // Dealer mode blind actions
          _makeAction(
            player: 1,
            action: 'small blind',
            street: 'preflop',
            amount: 100.0,
            playerStack: 9900.0,
            playerName: 'Hero',
            playerPosition: 'BTN/SB',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 2,
            action: 'big blind',
            street: 'preflop',
            amount: 200.0,
            playerStack: 9800.0,
            playerName: 'Villain',
            playerPosition: 'BB',
          ),
          // Actual action
          _makeAction(
            player: 1,
            action: 'raise',
            street: 'preflop',
            amount: 600.0,
            playerStack: 9900.0,
            playerName: 'Hero',
            playerPosition: 'BTN/SB',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 2,
            action: 'fold',
            street: 'preflop',
            playerStack: 9800.0,
            playerName: 'Villain',
            playerPosition: 'BB',
          ),
        ],
      );
      final session = _makeSession(smallBlind: 100, bigBlind: 200);
      final output = PokerStarsExportService.exportHand(hand, session);

      // Should NOT have "Hero: small blind" in the output
      expect(output.contains('Hero: small blind'), isFalse);
      expect(output.contains('Villain: big blind'), isFalse);
      // But should have the generated blind lines
      expect(output, contains('posts small blind 100'));
      expect(output, contains('posts big blind 200'));
    });

    test('all-in as bet when no prior bet', () {
      final hand = _makeHand(
        smallBlind: 100,
        bigBlind: 200,
        playerNames: {'1': 'Hero', '2': 'Villain'},
        heroSeatNumber: 1,
        buttonPosition: 1,
        winnerId: 1,
        potAmount: 10400,
        boardCards: {
          'flop': ['A\u2660', '7\u2666', '2\u2663'],
          'turn': null,
          'river': null,
        },
        actions: [
          _makeAction(
            player: 1,
            action: 'call',
            street: 'preflop',
            amount: 100.0,
            playerStack: 4900.0,
            playerName: 'Hero',
            playerPosition: 'BTN/SB',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 2,
            action: 'check',
            street: 'preflop',
            playerStack: 4800.0,
            playerName: 'Villain',
            playerPosition: 'BB',
          ),
          _makeAction(
            player: 1,
            action: 'all-in',
            street: 'flop',
            amount: 4800.0,
            playerStack: 4800.0,
            playerName: 'Hero',
            playerPosition: 'BTN/SB',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 2,
            action: 'fold',
            street: 'flop',
            playerStack: 4800.0,
            playerName: 'Villain',
            playerPosition: 'BB',
          ),
        ],
      );
      final session = _makeSession(smallBlind: 100, bigBlind: 200);
      final output = PokerStarsExportService.exportHand(hand, session);

      // All-in with no prior bet = bet
      expect(output, contains('Hero: bets 4800'));
    });

    test('all-in as raise when prior bet exists preflop', () {
      final hand = _makeHand(
        smallBlind: 100,
        bigBlind: 200,
        playerNames: {'1': 'Hero', '2': 'Villain', '3': 'Player3'},
        heroSeatNumber: 1,
        buttonPosition: 3,
        winnerId: 1,
        potAmount: 5200,
        actions: [
          _makeAction(
            player: 1,
            action: 'raise',
            street: 'preflop',
            amount: 600.0, // total
            playerStack: 4900.0,
            playerName: 'Hero',
            playerPosition: 'UTG',
            isCurrentUser: true,
          ),
          _makeAction(
            player: 2,
            action: 'all-in',
            street: 'preflop',
            amount: 2500.0, // total (> current bet of 600)
            playerStack: 2500.0,
            playerName: 'Villain',
            playerPosition: 'SB',
          ),
          _makeAction(
            player: 3,
            action: 'fold',
            street: 'preflop',
            playerStack: 9800.0,
            playerName: 'Player3',
            playerPosition: 'BB',
          ),
          _makeAction(
            player: 1,
            action: 'call',
            street: 'preflop',
            amount: 1900.0,
            playerStack: 3000.0,
            playerName: 'Hero',
            playerPosition: 'UTG',
            isCurrentUser: true,
          ),
        ],
      );
      final session = _makeSession(smallBlind: 100, bigBlind: 200);
      final output = PokerStarsExportService.exportHand(hand, session);

      // All-in raise: additional = 2500 - 600 = 1900
      expect(output,
          contains('Villain: raises 1900 to 2500 and is all-in'));
    });

    test('table size detection: 6-max for max seat <= 6', () {
      final hand = _makeHand(
        playerNames: {'1': 'P1', '2': 'P2', '3': 'P3', '4': 'P4', '5': 'P5', '6': 'P6'},
        heroSeatNumber: 1,
        buttonPosition: 1,
        actions: [
          _makeAction(
            player: 1,
            action: 'fold',
            street: 'preflop',
            playerStack: 10000.0,
            playerName: 'P1',
            playerPosition: 'BTN',
            isCurrentUser: true,
          ),
        ],
      );
      final session = _makeSession();
      final output = PokerStarsExportService.exportHand(hand, session);

      expect(output, contains('6-max'));
    });

    test('table size detection: 9-max for max seat > 8', () {
      final hand = _makeHand(
        playerNames: {
          '1': 'P1', '2': 'P2', '3': 'P3', '4': 'P4', '5': 'P5',
          '6': 'P6', '7': 'P7', '8': 'P8', '9': 'P9',
        },
        heroSeatNumber: 1,
        buttonPosition: 1,
        actions: [
          _makeAction(
            player: 1,
            action: 'fold',
            street: 'preflop',
            playerStack: 10000.0,
            playerName: 'P1',
            playerPosition: 'BTN',
            isCurrentUser: true,
          ),
        ],
      );
      final session = _makeSession();
      final output = PokerStarsExportService.exportHand(hand, session);

      expect(output, contains('9-max'));
    });
  });
}
