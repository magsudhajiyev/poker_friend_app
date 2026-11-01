import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/models/hand_state_machine.dart';
import 'package:poker_logger/widgets/easy_logging/board_add_later_bar.dart';
import 'package:poker_logger/widgets/easy_logging/undo_toast.dart';

Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('UndoToast', () {
    testWidgets('Undo fires once and never expires afterwards', (t) async {
      var undo = 0, expire = 0;
      await t.pumpWidget(_host(UndoToast(
        message: 'Hand counted. Next hand ready.',
        onUndo: () => undo++,
        onExpire: () => expire++,
      )));
      await t.tap(find.text('Undo'));
      await t.pump(const Duration(seconds: 5));
      expect(undo, 1);
      expect(expire, 0);
    });

    testWidgets('expires after the window if not undone', (t) async {
      var undo = 0, expire = 0;
      await t.pumpWidget(_host(UndoToast(
        message: 'x',
        onUndo: () => undo++,
        onExpire: () => expire++,
      )));
      await t.pump(const Duration(seconds: 3));
      expect(expire, 0);
      await t.pump(const Duration(seconds: 2));
      expect(expire, 1);
      expect(undo, 0);
    });
  });

  testWidgets('BoardAddLaterBar calls back', (t) async {
    var n = 0;
    await t.pumpWidget(_host(BoardAddLaterBar(onAddNow: () => n++)));
    await t.tap(find.text('Add board'));
    expect(n, 1);
  });
}
