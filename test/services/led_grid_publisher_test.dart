import 'package:flutter_test/flutter_test.dart';

import '../../lib/services/led_grid_publisher.dart';
import '../../lib/services/range_grid_service.dart';

// The encoded payload is the wire contract with the ESP32 firmware
// (hardware/led-range-board/led_range_board.ino). v2 layout, 3 bytes/cell:
//   byte0 = raise<<4 | call, byte1 = check<<4 | fold  (shares sum to 15)
//   byte2 = min(255, sample size)
void main() {
  group('LedGridPublisher.encodeGrid (payload v2)', () {
    test('empty aggregates -> 1014 zero chars', () {
      final hex = LedGridPublisher.encodeGrid({});
      expect(hex.length, 1014);
      expect(hex, '0' * 1014);
    });

    test('pure raise cell -> full share to raise nibble', () {
      final hex = LedGridPublisher.encodeGrid({
        'AA': const RangeCellAggregate(handClass: 'AA', raiseCount: 10),
      });
      // AA = cell 0 -> chars 0..6: raise=15,call=0 -> f0; check/fold 00; n=10
      expect(hex.substring(0, 6), 'f0000a');
    });

    test('50/50 raise-call splits 8/7 by largest remainder', () {
      final hex = LedGridPublisher.encodeGrid({
        'AA': const RangeCellAggregate(
            handClass: 'AA', raiseCount: 5, callCount: 5),
      });
      // 7.5/7.5 -> floors 7/7, leftover 1 to first largest remainder
      expect(hex.substring(0, 6), '87000a');
    });

    test('shares always sum to 15 for non-empty cells', () {
      final hex = LedGridPublisher.encodeGrid({
        'AA': const RangeCellAggregate(
            handClass: 'AA',
            raiseCount: 1,
            callCount: 1,
            checkCount: 1,
            foldCount: 4),
      });
      final b0 = int.parse(hex.substring(0, 2), radix: 16);
      final b1 = int.parse(hex.substring(2, 4), radix: 16);
      final sum = (b0 >> 4) + (b0 & 0xF) + (b1 >> 4) + (b1 & 0xF);
      expect(sum, 15);
    });

    test('cell placement: A4s at cell 10, A3s at cell 11', () {
      final hex = LedGridPublisher.encodeGrid({
        'A4s': const RangeCellAggregate(handClass: 'A4s', raiseCount: 3),
        'A3s': const RangeCellAggregate(
            handClass: 'A3s', raiseCount: 2, callCount: 2),
      });
      // cell 10 -> chars 60..66, cell 11 -> chars 66..72
      expect(hex.substring(60, 66), 'f00003');
      expect(hex.substring(66, 72), '870004');
    });

    test('all-in jams fold into the raise share (wire spec stays 4-action)', () {
      final hex = LedGridPublisher.encodeGrid({
        'AA': const RangeCellAggregate(
            handClass: 'AA', raiseCount: 5, allInCount: 5),
      });
      // 10 aggressive hands of 10 total -> raise nibble 15, sample 10
      expect(hex.substring(0, 6), 'f0000a');
    });

    test('intensity caps at 255', () {
      final hex = LedGridPublisher.encodeGrid({
        'AA': const RangeCellAggregate(handClass: 'AA', raiseCount: 999),
      });
      expect(hex.substring(4, 6), 'ff');
    });
  });
}
