import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/hand_state_machine.dart';

/// The `isScouted` flag marks a preflop-only scouting hand. It must survive the
/// toMap/fromMap round-trip (both Firestore and the local DB read hands back
/// through fromMap) and default to false for pre-existing records that never
/// had the field.
void main() {
  HandRecord baseHand() => HandRecord(
        handNumber: 1,
        buttonPosition: 3,
        playerCount: 6,
        startTime: DateTime.utc(2026, 1, 1),
      );

  group('HandRecord.isScouted', () {
    test('defaults to false', () {
      expect(baseHand().isScouted, isFalse);
    });

    test('round-trips through toMap/fromMap when true', () {
      final hand = baseHand()..isScouted = true;
      final restored = HandRecord.fromMap(hand.toMap());
      expect(restored.isScouted, isTrue);
    });

    test('round-trips through toMap/fromMap when false', () {
      final hand = baseHand()..isScouted = false;
      final restored = HandRecord.fromMap(hand.toMap());
      expect(restored.isScouted, isFalse);
    });

    test('reads back false for a legacy map missing the field', () {
      final map = baseHand().toMap()..remove('isScouted');
      final restored = HandRecord.fromMap(map);
      expect(restored.isScouted, isFalse);
    });
  });
}
