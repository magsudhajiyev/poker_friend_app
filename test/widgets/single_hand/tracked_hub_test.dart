import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/models/game_types.dart';
import 'package:poker_logger/screens/tracked_session_hub.dart';
import 'package:poker_logger/services/tracked_session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'hub works with no seat, blind or session manager data: Log a hand is '
      'always the main button', (t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final session = TrackedSession(
        id: 's1',
        name: 'Casino',
        gameType: GameType.cash,
        buyIn: 200,
        startingStack: 200,
        startTime: DateTime.now().subtract(const Duration(minutes: 5)));
    await t.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TrackedSessionHub.screenFor(session),
    ));
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull);
    expect(find.text('Casino'), findsOneWidget);
    expect(find.text('Log a Hand'), findsOneWidget); // main button
    expect(find.text('Go Back to Hand'), findsNothing);
    expect(find.textContaining('Blinds'), findsNothing);
    expect(find.byKey(const ValueKey('tracked-back')), findsOneWidget);
    // Stack from the buy-in, rebuys/add-ons via the menu as in any session.
    expect(find.textContaining('200'), findsWidgets);
  });
}
