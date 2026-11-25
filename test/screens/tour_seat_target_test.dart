import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/models/single_hand_setup.dart';
import 'package:poker_logger/onboarding/onboarding_tour.dart';
import 'package:poker_logger/screens/poker_hand_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The guided hand's seat spotlights (add-opponent, stack ring) use the seat
/// anchor key. With the bigger seat plates the anchor must still wrap the
/// whole seat (avatar + plate) and the spotlight rect must match it.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in const [Size(320, 568), Size(430, 932)]) {
    testWidgets('seat anchors wrap avatar + plate and match the spotlight rect '
        'at $size', (t) async {
      t.view.physicalSize = size * 3;
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

      var checked = 0;
      for (var seat = 1; seat <= 9; seat++) {
        final plate = find.byKey(ValueKey('seat-plate-$seat'));
        if (plate.evaluate().isEmpty) continue;
        final anchor = find
            .ancestor(
                of: plate,
                matching: find.byWidgetPredicate(
                    (w) => w is RotatedBox && w.key is GlobalKey))
            .first;
        final key = t.widget<RotatedBox>(anchor).key! as GlobalKey;
        final pos = transformedTargetPosition(key)!;
        final spotlight = pos.offset & pos.size;
        // The tour spotlights exactly the on-screen anchor rect...
        final rect = t.getRect(anchor);
        expect((spotlight.left - rect.left).abs(), lessThan(0.5));
        expect((spotlight.top - rect.top).abs(), lessThan(0.5));
        expect((spotlight.width - rect.width).abs(), lessThan(0.5));
        expect((spotlight.height - rect.height).abs(), lessThan(0.5));
        // ...which holds the whole plate, and stays on screen.
        final plateRect = t.getRect(plate);
        expect(spotlight.inflate(0.5).contains(plateRect.topLeft), isTrue,
            reason: 'seat $seat plate top-left outside anchor');
        expect(spotlight.inflate(0.5).contains(plateRect.bottomRight), isTrue,
            reason: 'seat $seat plate bottom-right outside anchor');
        expect(spotlight.left, greaterThanOrEqualTo(-0.5));
        expect(spotlight.right, lessThanOrEqualTo(size.width + 0.5));
        checked++;
      }
      expect(checked, 9);
    });
  }
}
