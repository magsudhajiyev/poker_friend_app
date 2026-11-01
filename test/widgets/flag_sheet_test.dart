import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/design_system/components/buttons/app_button.dart';
import 'package:poker_logger/design_system/components/cards/suit_icon.dart';
import 'package:poker_logger/design_system/components/pickers/card_keyboard.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/models/hand_state_machine.dart' show HoleCards;
import 'package:poker_logger/widgets/easy_logging/flag_sheet.dart';

Widget _host(FlagSheetBody body) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SizedBox(height: 2400, child: body)),
    );

bool _saveEnabled(WidgetTester t) =>
    t.widget<AppButton>(find.byType(AppButton)).onTap != null;

Future<void> _pick(WidgetTester t, String rank, String suit) async {
  await t.tap(find.text(rank).first);
  await t.pump();
  await t.tap(find
      .byWidgetPredicate((w) => w is SuitIcon && w.suitChar == suit)
      .first);
  await t.pump();
}

void main() {
  testWidgets('FlagSheet.show: no Scrollable wraps the CardKeyboard',
      (t) async {
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () => FlagSheet.show(ctx, onSave: (a, b) async {}),
          child: const Text('open'),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(
      find.ancestor(
          of: find.byType(CardKeyboard), matching: find.byType(Scrollable)),
      findsNothing,
    );
  });

  testWidgets('Save is disabled until both cards are picked', (t) async {
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    HoleCards? saved;
    await t.pumpWidget(_host(FlagSheetBody(onSave: (tags, c) async {
      saved = c;
    })));
    expect(find.text('Pick your two cards to save this hand'), findsOneWidget);
    expect(_saveEnabled(t), isFalse);
    await _pick(t, 'A', '♠');
    expect(_saveEnabled(t), isFalse);
    await _pick(t, 'K', '♥');
    expect(_saveEnabled(t), isTrue);
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(saved!.card1, 'A♠');
    expect(saved!.card2, 'K♥');
  });

  testWidgets('pre-filled cards enable Save and are passed on', (t) async {
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    HoleCards? saved;
    await t.pumpWidget(_host(FlagSheetBody(
      initialCards: HoleCards(card1: 'Q♦', card2: 'J♣'),
      initialTags: const ['bluff'],
      onSave: (tags, c) async => saved = c,
    )));
    expect(_saveEnabled(t), isTrue);
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(saved!.card1, 'Q♦');
    expect(saved!.card2, 'J♣');
  });

  testWidgets('cards section comes before the tags', (t) async {
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_host(FlagSheetBody(onSave: (_, __) async {})));
    final cardsY =
        t.getTopLeft(find.text('Pick your two cards to save this hand')).dy;
    final tagsY = t.getTopLeft(find.text('Pick up to 3 tags')).dy;
    expect(cardsY, lessThan(tagsY));
  });
}
