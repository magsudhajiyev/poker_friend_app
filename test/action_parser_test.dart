import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/action_parser.dart';

void main() {
  String fmt(List<ParsedAction> actions) {
    return actions
        .map((a) =>
            'S${a.seatNumber}:${a.action}${a.amount != null ? '(${a.amount})' : ''}')
        .join(', ');
  }

  group('Seat-anchored parsing', () {
    test('seat prefix fold', () {
      final r = ActionParser.parse('seat 4 fold');
      expect(r.length, 1);
      expect(r[0].seatNumber, 4);
      expect(r[0].action, 'fold');
    });

    test('two seat folds in one utterance - no duplicates', () {
      final r = ActionParser.parse('seat 4 fold. seat 5 fold.');
      expect(r.length, 2, reason: 'Got: ${fmt(r)}');
      expect(r[0].seatNumber, 4);
      expect(r[1].seatNumber, 5);
    });

    test('call is NOT parsed as all-in', () {
      final r = ActionParser.parse('seat 6 call');
      expect(r.length, 1, reason: 'Got: ${fmt(r)}');
      expect(r[0].action, 'call', reason: 'Got: ${fmt(r)}');
      expect(r[0].seatNumber, 6);
    });

    test('call and raise in same utterance', () {
      final r = ActionParser.parse('seat 6 call. s7 raise 1,000.');
      expect(r.length, 2, reason: 'Got: ${fmt(r)}');
      expect(r[0].seatNumber, 6);
      expect(r[0].action, 'call');
      expect(r[1].seatNumber, 7);
      expect(r[1].action, 'raise');
      expect(r[1].amount, 1000.0);
    });

    test('bare digit prefix', () {
      final r = ActionParser.parse('4 fold');
      expect(r.length, 1);
      expect(r[0].seatNumber, 4);
      expect(r[0].action, 'fold');
    });

    test('all-in with seat prefix', () {
      final r = ActionParser.parse('seat 3 all in');
      expect(r.length, 1);
      expect(r[0].seatNumber, 3);
      expect(r[0].action, 'all-in');
    });

    test('raise with amount', () {
      final r = ActionParser.parse('seat 2 raise 2000');
      expect(r.length, 1);
      expect(r[0].seatNumber, 2);
      expect(r[0].action, 'raise');
      expect(r[0].amount, 2000.0);
    });

    test('s prefix shorthand', () {
      final r = ActionParser.parse('s5 check');
      expect(r.length, 1);
      expect(r[0].seatNumber, 5);
      expect(r[0].action, 'check');
    });

    test('pass maps to fold', () {
      final r = ActionParser.parse('seat 1 pass');
      expect(r.length, 1);
      expect(r[0].action, 'fold');
    });

    test('bet with k suffix amount', () {
      final r = ActionParser.parse('seat 8 bet 2.5k');
      expect(r.length, 1);
      expect(r[0].action, 'bet');
      expect(r[0].amount, 2500.0);
    });

    test('no actions from garbage text', () {
      final r = ActionParser.parse('table 1 dealer makes.');
      expect(r.length, 0);
    });

    test('fold without seat prefix returns no seat', () {
      // Bare "fold" without any seat number should not match
      final r = ActionParser.parse('fold');
      expect(r.length, 0);
    });

    // Soniox comma insertion tests
    test('s4, fold with comma', () {
      final r = ActionParser.parse('s4, fold.');
      expect(r.length, 1, reason: 'Got: ${fmt(r)}');
      expect(r[0].seatNumber, 4);
      expect(r[0].action, 'fold');
    });

    test('seat 6, call with comma', () {
      final r = ActionParser.parse('seat 6, call.');
      expect(r.length, 1, reason: 'Got: ${fmt(r)}');
      expect(r[0].seatNumber, 6);
      expect(r[0].action, 'call');
    });

    test('s4, fold. s5, fold. with commas', () {
      final r = ActionParser.parse('s4, fold. s5, fold.');
      expect(r.length, 2, reason: 'Got: ${fmt(r)}');
      expect(r[0].seatNumber, 4);
      expect(r[0].action, 'fold');
      expect(r[1].seatNumber, 5);
      expect(r[1].action, 'fold');
    });

    test('seat 4, pass with comma', () {
      final r = ActionParser.parse('seat 4, pass.');
      expect(r.length, 1, reason: 'Got: ${fmt(r)}');
      expect(r[0].seatNumber, 4);
      expect(r[0].action, 'fold');
    });

    // Amount with comma separator from Soniox
    test('s2, raise, 5000 with comma before amount', () {
      final r = ActionParser.parse('s2, raise, 5000.');
      expect(r.length, 1, reason: 'Got: ${fmt(r)}');
      expect(r[0].seatNumber, 2);
      expect(r[0].action, 'raise');
      expect(r[0].amount, 5000.0, reason: 'Got: ${fmt(r)}');
    });

    test('s8, bet. 1000 with period before amount', () {
      final r = ActionParser.parse('s8, bet. 1000.');
      expect(r.length, 1, reason: 'Got: ${fmt(r)}');
      expect(r[0].seatNumber, 8);
      expect(r[0].action, 'bet');
      expect(r[0].amount, 1000.0, reason: 'Got: ${fmt(r)}');
    });

    test('seat 2, re-raise, 5000 with comma', () {
      final r = ActionParser.parse('seat 2, re-raise, 5000.');
      expect(r.length, 1, reason: 'Got: ${fmt(r)}');
      expect(r[0].seatNumber, 2);
      expect(r[0].action, 'raise');
      expect(r[0].amount, 5000.0, reason: 'Got: ${fmt(r)}');
    });

    test('s1, all in. s2, raise without amount parsed', () {
      final r = ActionParser.parse('s1, all in. s2, raise.');
      expect(r.length, 2, reason: 'Got: ${fmt(r)}');
      expect(r[0].action, 'all-in');
      expect(r[1].action, 'raise');
      expect(r[1].amount, isNull, reason: 'Got: ${fmt(r)}');
    });
  });
}
