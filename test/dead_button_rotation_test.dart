import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/utils/blind_rotation.dart';

/// Dead button / dead small blind (TDA Rule 34), pure rotation function.
/// See POKER_SEATING_RULES.md. Each vector below is hand-derived from the rule.
void main() {
  const table = 9;

  /// Plays hands in order. [lives] is the live-seat set for each hand;
  /// hand 1 uses [firstButton] as the baseline.
  List<BlindAssignment> play(int firstButton, List<List<int>> lives) {
    final out = <BlindAssignment>[];
    BlindAssignment? prev;
    for (final live in lives) {
      final a = prev == null
          ? BlindRotation.fromButton(
              live: live, tableSize: table, button: firstButton)!
          : BlindRotation.next(
              live: live,
              tableSize: table,
              lastBB: prev.bbSeat,
              lastSB: prev.sbSeat)!;
      out.add(a);
      prev = a;
    }
    return out;
  }

  /// "btn/sb/bb" with '-' for a dead SB, 'x' marking a dead button.
  String fmt(BlindAssignment a) =>
      '${a.buttonDead ? 'x' : ''}${a.buttonSeat}/${a.sbDead ? '-' : a.sbSeat}/${a.bbSeat}';

  const six = [1, 2, 3, 4, 5, 6];
  List<int> without(List<int> l, List<int> gone) =>
      l.where((s) => !gone.contains(s)).toList();

  group('first hand from button', () {
    test('6 live, button 1', () {
      expect(fmt(play(1, [six])[0]), '1/2/3');
    });
    test('heads-up: button is SB', () {
      expect(fmt(play(4, [[4, 7]])[0]), '4/4/7');
    });
    test('button on empty seat with 2 live snaps to next live', () {
      expect(fmt(play(2, [[4, 7]])[0]), '4/4/7');
    });
    test('button on empty seat with 4 live is a dead button', () {
      expect(fmt(play(2, [[1, 3, 4, 6]])[0]), 'x2/3/4');
    });
    test('fewer than 2 live returns null', () {
      expect(
          BlindRotation.fromButton(live: [3], tableSize: table, button: 3),
          isNull);
    });
  });

  group('TDA vectors (6 live, hand 1 BTN1 SB2 BB3)', () {
    test('seat 3 busts', () {
      final r = play(1, [six, ...List.filled(3, without(six, [3]))]);
      expect(r.map(fmt).toList(), ['1/2/3', '2/-/4', 'x3/4/5', '4/5/6']);
    });
    test('seat 2 busts', () {
      final r = play(1, [six, ...List.filled(2, without(six, [2]))]);
      expect(r.map(fmt).toList(), ['1/2/3', 'x2/3/4', '3/4/5']);
    });
    test('seat 1 busts: normal', () {
      final r = play(1, [six, ...List.filled(2, without(six, [1]))]);
      expect(r.map(fmt).toList(), ['1/2/3', '2/3/4', '3/4/5']);
    });
    test('seat 5 busts: never a dead blind or button', () {
      final r = play(1, [six, ...List.filled(4, without(six, [5]))]);
      expect(r.map(fmt).toList(),
          ['1/2/3', '2/3/4', '3/4/6', '4/6/1', '6/1/2']);
    });
    test('seats 2 and 3 bust', () {
      final live = without(six, [2, 3]);
      final r = play(1, [six, live, live, live]);
      expect(r.map(fmt).toList(),
          ['1/2/3', 'x2/-/4', 'x3/4/5', '4/5/6']);
    });
    test('seats 3 and 4 bust', () {
      final live = without(six, [3, 4]);
      final r = play(1, [six, live, live]);
      expect(r.map(fmt).toList(), ['1/2/3', '2/-/5', 'x3/5/6']);
    });
    test('seats 1 and 2 bust', () {
      final live = without(six, [1, 2]);
      final r = play(1, [six, live, live]);
      expect(r.map(fmt).toList(), ['1/2/3', 'x2/3/4', '3/4/5']);
    });
  });

  group('shrinking to heads-up', () {
    const three = [1, 2, 3];
    test('A busts', () {
      final r = play(1, [three, [2, 3], [2, 3]]);
      expect(r.map(fmt).toList(), ['1/2/3', '3/3/2', '2/2/3']);
    });
    test('B busts', () {
      final r = play(1, [three, [1, 3], [1, 3]]);
      expect(r.map(fmt).toList(), ['1/2/3', '3/3/1', '1/1/3']);
    });
    test('C busts', () {
      final r = play(1, [three, [1, 2], [1, 2]]);
      expect(r.map(fmt).toList(), ['1/2/3', '2/2/1', '1/1/2']);
    });
    test('nobody pays BB twice in a row going to heads-up', () {
      final r = play(1, [three, [1, 2]]);
      expect(r[1].bbSeat, isNot(r[0].bbSeat));
    });
  });

  group('4 live A1 B2 C3 D4', () {
    const four = [1, 2, 3, 4];
    test('BB (C) busts', () {
      final live = [1, 2, 4];
      final r = play(1, [
        [1, 2, 3, 4], // hand N: BTN1 SB2 BB3
        live,
        live,
        live,
      ]);
      expect(r.map(fmt).toList(),
          ['1/2/3', '2/-/4', 'x3/4/1', '4/1/2']);
    });
    test('SB (B) busts', () {
      final live = [1, 3, 4];
      final r = play(1, [four, live, live]);
      expect(r.map(fmt).toList(), ['1/2/3', 'x2/3/4', '3/4/1']);
    });
  });

  group('regression: no seat changes equals plain rotation', () {
    for (var n = 2; n <= 9; n++) {
      test('$n players over two orbits', () {
        final live = [for (var s = 1; s <= n; s++) s];
        final r = play(1, List.filled(n * 2, live));
        for (var i = 0; i < r.length; i++) {
          final btn = (i % n) + 1;
          if (n == 2) {
            expect(r[i].buttonSeat, r[i].sbSeat);
            expect(r[i].bbSeat, btn == 1 ? 2 : 1);
            continue;
          }
          expect(r[i].buttonSeat, btn, reason: 'hand ${i + 1}');
          expect(r[i].sbSeat, (btn % n) + 1);
          expect(r[i].bbSeat, ((btn + 1) % n) + 1);
          expect(r[i].sbDead || r[i].buttonDead, isFalse);
        }
      });
    }
    test('sparse table [1,3,5,7,9]', () {
      final live = [1, 3, 5, 7, 9];
      final r = play(1, List.filled(6, live));
      expect(r.map(fmt).toList(),
          ['1/3/5', '3/5/7', '5/7/9', '7/9/1', '9/1/3', '1/3/5']);
    });
    test('2 live back to 3 live: no double BB, no BTN == BB', () {
      final r = play(1, [
        [1, 2, 3],
        [1, 2],
        [1, 2, 3],
      ]);
      expect(r.map(fmt).toList(), ['1/2/3', '2/2/1', '3/1/2']);
      expect(r[2].bbSeat, isNot(r[1].bbSeat));
      expect(r[2].buttonSeat, isNot(r[2].bbSeat));
    });
  });

  group('liveness helpers', () {
    test('flags only when the seat is not live', () {
      final a = BlindRotation.next(
          live: [1, 2, 4], tableSize: table, lastBB: 3, lastSB: 2)!;
      expect(a.sbDead, isTrue);
      expect(a.buttonDead, isFalse);
    });
  });
}
