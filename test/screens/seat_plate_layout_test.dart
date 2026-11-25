import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/models/single_hand_setup.dart';
import 'package:poker_logger/screens/poker_hand_screen.dart';
import 'package:poker_logger/utils/seat_plate_scale.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<List<Rect>> _plates(WidgetTester t, Size logical) async {
  t.view.physicalSize = logical * 3;
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 10));
  });
  final s = SingleHandSetup(playerCount: 9, heroPosition: 'BTN');
  await t.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: PokerHandScreen(
      smallBlind: 1,
      bigBlind: 2,
      numberOfPlayers: 9,
      gameType: s.gameType,
      hasBBante: false,
      singleHand: s,
    ),
  ));
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
  return [
    for (var i = 1; i <= 9; i++)
      if (find.byKey(ValueKey('seat-plate-$i')).evaluate().isNotEmpty)
        t.getRect(find.byKey(ValueKey('seat-plate-$i')))
  ];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('plate scale is 1.0 at 390 and clamped for small and large screens', () {
    expect(seatPlateScale(390), 1.0);
    expect(seatPlateScale(320), 0.92);
    expect(seatPlateScale(1000), 1.1);
  });

  for (final size in const [Size(320, 640), Size(360, 780), Size(430, 932)]) {
    testWidgets('9-handed plates stay on screen and never overlap at $size',
        (t) async {
      final rects = await _plates(t, size);
      expect(rects.length, 9);
      for (final r in rects) {
        expect(r.left, greaterThanOrEqualTo(0));
        expect(r.right, lessThanOrEqualTo(size.width));
      }
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          expect(rects[i].overlaps(rects[j]), isFalse,
              reason: 'plates $i and $j overlap: ${rects[i]} ${rects[j]}');
        }
      }
    });
  }

  testWidgets('plate text is bigger than the old 10/9 pt', (t) async {
    await _plates(t, const Size(390, 844));
    final plate = find.byKey(const ValueKey('seat-plate-1'));
    final sizes = t
        .widgetList<Text>(
            find.descendant(of: plate, matching: find.byType(Text)))
        .map((e) => e.style?.fontSize ?? 0)
        .toList();
    expect(sizes.first, greaterThan(10));
    expect(sizes.last, greaterThan(9));
  });
}
