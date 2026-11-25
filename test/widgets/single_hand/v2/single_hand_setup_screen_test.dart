import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/models/game_types.dart';
import 'package:poker_logger/models/hand_state_machine.dart';
import 'package:poker_logger/models/single_hand_group.dart';
import 'package:poker_logger/models/single_hand_setup.dart';
import 'package:poker_logger/screens/single_hand_setup_screen.dart';
import 'package:poker_logger/services/single_hand_service.dart';
import 'package:poker_logger/widgets/single_hand/single_hand_setup_sheet.dart'
    show SingleHandStart;
import 'package:shared_preferences/shared_preferences.dart';

class _EmptyBackend implements SingleHandBackend {
  @override
  Future<List<SingleHandGroup>> loadGroups() async => [];
  @override
  Future<int> handCount(String groupId) async => 0;
  @override
  Future<void> createGroup(
      {required String groupId,
      required String name,
      required SingleHandSetup setup}) async {}
  @override
  Future<(String?, String?)> writeHand(
          {required String groupId,
          required int handNumber,
          required HandRecord hand,
          required SingleHandSetup setup,
          required Map<int, String> playerNames,
          Map<int, String>? playerIds}) async =>
      (null, null);
  @override
  Future<void> touchGroup(String groupId, DateTime at) async {}
}

void main() {
  SingleHandStart? result;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SingleHandService.backend = _EmptyBackend();
    result = null;
  });

  Future<void> open(WidgetTester t, SingleHandSetup setup) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () async =>
              result = await SingleHandSetupScreen.show(c, setup: setup),
          child: const Text('open'),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
  }

  testWidgets('cash: seat + one stack step + Start returns the setup',
      (t) async {
    await open(t, SingleHandSetup()); // cash 1/2, 100 BB, BTN
    expect(find.text('1/2 Cash · 6 players'), findsOneWidget);
    expect(find.text(r'$ 200'), findsOneWidget);
    await t.tap(find.text('CO'));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
    await t.pumpAndSettle(); // lets the one-time hint finish too
    await t.tap(find.text('Start hand'));
    await t.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.setup.heroPosition, 'CO');
    expect(result!.setup.stackBB, 125); // next cash step above 100
    expect(result!.setup.card1, isNull);
    expect(result!.setup.card2, isNull);
  });

  testWidgets('tournament: stack steps in BB with chips under the number',
      (t) async {
    await open(
        t,
        SingleHandSetup(
            gameType: GameType.tournament,
            smallBlind: 100,
            bigBlind: 200,
            stackBB: 30));
    expect(find.text('30 BB'), findsOneWidget);
    expect(find.text('= 6,000 chips'), findsOneWidget);
    await t.tap(find.byIcon(Icons.keyboard_arrow_down_rounded).last);
    await t.pumpAndSettle();
    await t.tap(find.text('Start hand'));
    await t.pumpAndSettle();
    expect(result!.setup.stackBB, 25);
    expect(result!.setup.gameType, GameType.tournament);
  });

  testWidgets('tap on the number opens exact entry in money for cash',
      (t) async {
    await open(t, SingleHandSetup());
    await t.tap(find.text(r'$ 200'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '500');
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    await t.tap(find.text('Start hand'));
    await t.pumpAndSettle();
    expect(result!.setup.stackBB, 250); // $500 at BB $2
  });

  testWidgets('no overflow at 320x568 with text scale 1.3 (cash and tournament)',
      (t) async {
    for (final setup in [
      SingleHandSetup(),
      SingleHandSetup(
          gameType: GameType.tournament,
          smallBlind: 5000,
          bigBlind: 10000,
          stackBB: 300,
          playerCount: 9),
    ]) {
      t.view.physicalSize = const Size(960, 1704);
      t.view.devicePixelRatio = 3;
      await t.pumpWidget(MaterialApp(
        builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SingleHandSetupScreen(setup: setup),
      ));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byKey(const ValueKey('stack-main')), findsOneWidget);
    }
    addTearDown(t.view.reset);
  });

  testWidgets('close returns null', (t) async {
    await open(t, SingleHandSetup());
    await t.tap(find.byIcon(Icons.close));
    await t.pumpAndSettle();
    expect(result, isNull);
    expect(find.text('open'), findsOneWidget);
  });
}
