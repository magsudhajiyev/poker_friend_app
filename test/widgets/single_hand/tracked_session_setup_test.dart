import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/models/blind_level.dart';
import 'package:poker_logger/models/game_types.dart';
import 'package:poker_logger/models/single_hand_setup.dart';
import 'package:poker_logger/screens/tracked_session_setup_screen.dart';
import 'package:poker_logger/widgets/single_hand/v2/game_pill_sheet.dart';

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  group('Track a session setup (D21)', () {
    testWidgets('Start needs a buy-in; no blinds, seats or players',
        (t) async {
      t.view.physicalSize = const Size(1170, 2532);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(_app(const TrackedSessionSetupScreen()));
      await t.pump();

      double startOpacity() => t
          .widget<Opacity>(find
              .ancestor(
                  of: find.text('Start Session'),
                  matching: find.byType(Opacity))
              .first)
          .opacity;

      expect(startOpacity(), lessThan(1)); // disabled
      expect(find.text('Starting Stack (optional)'), findsNothing); // cash
      expect(find.textContaining('Blind'), findsNothing);

      await t.enterText(find.byType(TextField).at(1), '0');
      await t.pump();
      expect(startOpacity(), lessThan(1)); // zero is not a buy-in

      await t.enterText(find.byType(TextField).at(1), '200,50'); // comma ok
      await t.pump();
      expect(startOpacity(), 1.0);
    });

    testWidgets('tournament adds an optional starting stack in chips',
        (t) async {
      t.view.physicalSize = const Size(1170, 2532);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(_app(const TrackedSessionSetupScreen()));
      await t.tap(find.text('Tournament'));
      await t.pumpAndSettle();
      expect(find.text('Starting Stack (optional)'), findsOneWidget);
    });
  });

  testWidgets('game pill sheet: the session locks Cash / Tournament',
      (t) async {
    final s = SingleHandSetup();
    GameType? picked;
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(Scaffold(
      body: GamePillSheet(
        setup: s,
        extraLevels: <BlindLevel>{},
        onGameType: (g) => picked = g,
        onBlinds: (_) {},
        onAnte: (_) {},
        onPlayers: (_) {},
        lockGameType: true,
      ),
    )));
    await t.pump();
    await t.tap(find.text(AppLocalizations.of(t.element(find.byType(GamePillSheet))).singleHandTourney), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(picked, isNull);
  });

  test('discard removes the session AND its hands in both stores', () {
    final src = File('lib/services/tracked_session_service.dart')
        .readAsStringSync();
    final i = src.indexOf('Future<void> discard(String id) async {\n    if');
    final body = src.substring(i);
    // Both helpers delete the poker_hands / hands rows before the session.
    expect(body, contains('FirebaseService.deleteSession(id)'));
    expect(body, contains('LocalStorageService.deleteSession(id)'));
    final fb = File('lib/services/firebase_service.dart').readAsStringSync();
    expect(fb, contains('Delete any hands in this session'));
    final ls = File('lib/services/local_storage_service.dart')
        .readAsStringSync();
    expect(ls, contains("db.delete('hands', where: 'sessionId = ?'"));
  });
}
