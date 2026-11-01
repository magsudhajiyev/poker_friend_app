import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guard: the post-hand hole-card flow must be identical with easy logging on
/// and off. `_showHoleCardsDialog` and the showdown opponent-card chain may
/// not branch on the easy-logging snapshot.
void main() {
  final src = File('lib/screens/poker_hand_screen.dart').readAsStringSync();

  String body(String signature) {
    final start = src.indexOf(signature);
    expect(start, greaterThan(-1), reason: signature);
    final next = src.indexOf('\n  Future<', start + signature.length);
    return src.substring(start, next == -1 ? src.length : next);
  }

  test('hole cards dialog does not depend on _easy', () {
    final b = body('Future<bool> _showHoleCardsDialog(');
    expect(b.contains('_easy'), isFalse);
    expect(b.contains('HandReviewDialog'), isTrue);
  });

  test('showdown opponent-card chain is not skipped under _easy', () {
    expect(src.contains('? false // easy logging'), isFalse);
    expect(RegExp(r'_easy\s*\?\s*false').hasMatch(src), isFalse);
  });

  test('no easy-mode review skipping helper remains', () {
    expect(src.contains('shouldSkipReview'), isFalse);
  });
}
