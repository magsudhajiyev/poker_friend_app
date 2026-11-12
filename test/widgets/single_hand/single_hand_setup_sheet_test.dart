import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/design_system/components/pickers/app_wheel_picker.dart';
import 'package:poker_logger/design_system/components/tabs/animated_segmented_tabs.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/models/blind_level.dart';
import 'package:poker_logger/models/game_types.dart';
import 'package:poker_logger/models/hand_state_machine.dart';
import 'package:poker_logger/models/single_hand_group.dart';
import 'package:poker_logger/models/single_hand_setup.dart';
import 'package:poker_logger/screens/logging_mode_selection_screen.dart';
import 'package:poker_logger/services/single_hand_service.dart';
import 'package:poker_logger/widgets/single_hand/single_hand_setup_sheet.dart';
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

Widget _host(SingleHandSetup setup) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleHandSetupSheet(setup: setup)),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SingleHandService.backend = _EmptyBackend();
  });

  Future<void> pumpHost(WidgetTester t, SingleHandSetup setup) async {
    t.view.physicalSize = const Size(1170, 2532); // iPhone 13, 3x
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(_host(setup));
    await t.pump();
  }

  testWidgets('position wheel lists only positions for the player count',
      (tester) async {
    await pumpHost(tester, SingleHandSetup());
    final w = tester
        .widget<AppWheelPicker<String>>(find.byType(AppWheelPicker<String>));
    expect(w.items, SingleHandSetup.positionsFor(6));
    expect(w.items, isNot(contains('UTG+2')));
  });

  testWidgets('heads-up shows BTN and BB', (tester) async {
    final setup = SingleHandSetup(playerCount: 2, heroPosition: 'BTN');
    await pumpHost(tester, setup);
    final w = tester
        .widget<AppWheelPicker<String>>(find.byType(AppWheelPicker<String>));
    expect(w.items, ['BTN', 'BB']);
  });

  testWidgets('hero position stays valid when the count shrinks',
      (tester) async {
    final setup = SingleHandSetup(playerCount: 9, heroPosition: 'UTG');
    await pumpHost(tester, setup);
    await tester.fling(
        find.byType(AppWheelPicker<int>), const Offset(0, 600), 3000);
    await tester.pumpAndSettle();
    expect(setup.playerCount, lessThan(9));
    expect(SingleHandSetup.positionsFor(setup.playerCount),
        contains(setup.heroPosition));
  });

  testWidgets('hero position kept when still valid', (tester) async {
    final setup = SingleHandSetup(playerCount: 9, heroPosition: 'BTN');
    await pumpHost(tester, setup);
    await tester.fling(
        find.byType(AppWheelPicker<int>), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();
    expect(setup.heroPosition, 'BTN');
  });

  Future<void> narrow(WidgetTester t, double w, SingleHandSetup s) async {
    t.view.physicalSize = Size(w * 3, 2532);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(_host(s));
    await t.pump();
  }

  for (final w in [320.0, 390.0]) {
    testWidgets('three wheels fit in one row at ${w.toInt()} pt',
        (tester) async {
      await narrow(
          tester,
          w,
          SingleHandSetup(
              gameType: GameType.tournament,
              smallBlind: 10000,
              bigBlind: 20000));
      expect(tester.takeException(), isNull);
      expect(find.text('Similar'), findsOneWidget);
      expect(find.byType(AppWheelPicker<BlindLevel>), findsOneWidget);
      expect(find.byType(AppWheelPicker<int>), findsOneWidget);
      expect(find.byType(AppWheelPicker<String>), findsOneWidget);
    });
  }

  testWidgets('blinds wheel: cash list ends with Custom, odd blinds inserted',
      (tester) async {
    await pumpHost(tester, SingleHandSetup(smallBlind: 3, bigBlind: 7));
    final w = tester.widget<AppWheelPicker<BlindLevel>>(
        find.byType(AppWheelPicker<BlindLevel>));
    expect(w.items.last.isCustom, isTrue);
    expect(w.items, contains(const BlindLevel(3, 7)));
    expect(w.selected, const BlindLevel(3, 7));
    // sorted by big blind
    final bbs = w.items.where((l) => !l.isCustom).map((l) => l.bb).toList();
    expect(bbs, [...bbs]..sort());
  });

  testWidgets('switching to Tournament moves to the tournament list',
      (tester) async {
    final setup = SingleHandSetup();
    await pumpHost(tester, setup);
    await tester.tap(find.text('Tourney'));
    await tester.pumpAndSettle();
    expect(setup.gameType, GameType.tournament);
    expect(setup.bigBlind, 200);
    expect(setup.smallBlind, 100);
    await tester.tap(find.text('Cash'));
    await tester.pumpAndSettle();
    expect(setup.bigBlind, 2);
  });

  testWidgets('spread selector updates the setup', (tester) async {
    final setup = SingleHandSetup();
    await pumpHost(tester, setup);
    await tester.tap(find.text('Near'));
    await tester.pumpAndSettle();
    expect(setup.stackSpread, StackSpread.near);
  });

  Finder stackField() => find.byType(TextField).first;

  testWidgets('tournament: chips are the default unit, converted to BB',
      (tester) async {
    final setup = SingleHandSetup(
        gameType: GameType.tournament,
        smallBlind: 100,
        bigBlind: 200,
        stackBB: 50);
    await pumpHost(tester, setup);
    expect(setup.stackUnit, StackUnit.amount);
    // 50 BB at 100/200 shows as 10000 chips.
    expect(tester.widget<TextField>(stackField()).controller!.text, '10000');
    await tester.enterText(stackField(), '52000');
    await tester.pump();
    expect(find.text('= 260 BB'), findsOneWidget);
    expect(find.textContaining('Did you mean'), findsNothing);
  });

  testWidgets('cash: BB default, money converts to BB', (tester) async {
    final setup = SingleHandSetup();
    await pumpHost(tester, setup);
    expect(setup.stackUnit, StackUnit.bb);
    await tester.enterText(stackField(), '100');
    await tester.pump();
    expect(find.textContaining('200'), findsWidgets); // "= $ 200.00"
    await tester.tap(find.text('\$'));
    await tester.pumpAndSettle();
    expect(setup.cashStackUnit, StackUnit.amount);
    expect(find.text('= 50 BB'), findsOneWidget); // $100 at 1/2
  });

  testWidgets('guard: 52,000 BB warns and "Use chips" converts to 260 BB',
      (tester) async {
    final setup = SingleHandSetup(
        gameType: GameType.tournament,
        smallBlind: 100,
        bigBlind: 200,
        tournamentStackUnit: StackUnit.bb);
    await pumpHost(tester, setup);
    await tester.enterText(stackField(), '52000');
    await tester.pump();
    expect(find.textContaining('52,000 BB'), findsWidgets);
    expect(find.text('Use chips'), findsOneWidget);
    await tester.ensureVisible(find.text('Use chips'));
    await tester.pump();
    await tester.tap(find.text('Use chips'));
    await tester.pumpAndSettle();
    expect(setup.tournamentStackUnit, StackUnit.amount);
    expect(find.text('= 260 BB'), findsOneWidget);
    expect(find.text('Use chips'), findsNothing);
  });

  testWidgets('guard: below 1 BB warns', (tester) async {
    await pumpHost(tester, SingleHandSetup());
    await tester.enterText(stackField(), '0.5');
    await tester.pump();
    expect(find.textContaining('Less than 1 BB'), findsOneWidget);
  });

  testWidgets('unit is remembered per game type', (tester) async {
    final setup = SingleHandSetup();
    await pumpHost(tester, setup);
    await tester.tap(find.text('Tourney'));
    await tester.pumpAndSettle();
    expect(setup.stackUnit, StackUnit.amount); // tournament default: chips
    await tester.tap(find.descendant(
        of: find.byType(AnimatedSegmentedTabs).at(1),
        matching: find.text('BB')));
    await tester.pumpAndSettle();
    expect(setup.tournamentStackUnit, StackUnit.bb);
    await tester.tap(find.text('Cash'));
    await tester.pumpAndSettle();
    expect(setup.stackUnit, StackUnit.bb);
    await tester.tap(find.text('Tourney'));
    await tester.pumpAndSettle();
    expect(setup.stackUnit, StackUnit.bb); // remembered
  });

  for (final w in [320.0, 390.0]) {
    for (final (sb, bb, label) in [
      (10000.0, 20000.0, '10K/20K'),
      (25000.0, 50000.0, '25K/50K'),
      (0.25, 0.5, '0.25/0.5'),
    ]) {
      testWidgets('blinds $label readable at ${w.toInt()} pt', (tester) async {
        await narrow(
            tester,
            w,
            SingleHandSetup(
                gameType: sb >= 1 ? GameType.tournament : GameType.cash,
                smallBlind: sb,
                bigBlind: bb));
        expect(tester.takeException(), isNull);
        expect(find.text(label), findsWidgets);
      });
    }
  }

  testWidgets('short phone (320x568) does not overflow and scrolls',
      (tester) async {
    tester.view.physicalSize = const Size(960, 1704);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(SingleHandSetup()));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Start hand'), findsOneWidget); // pinned footer
  });

  testWidgets('Custom blinds editor opens empty with current as hint',
      (tester) async {
    final setup = SingleHandSetup(smallBlind: 1, bigBlind: 2);
    await pumpHost(tester, setup);
    await tester.fling(
        find.byType(AppWheelPicker<BlindLevel>), const Offset(0, -2000), 8000);
    await tester.pumpAndSettle();
    expect(find.text('Small blind'), findsOneWidget);
    final fields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();
    // [0] stack field of the sheet; editor fields are the last two.
    final sb = fields[fields.length - 2];
    final bb = fields.last;
    expect(sb.controller!.text, isEmpty);
    expect(bb.controller!.text, isEmpty);
    // The wheel reports only where it stops, so the hints are the blinds
    // the player had before the fling, not the levels it passed.
    expect(sb.decoration!.hintText, '1');
    expect(bb.decoration!.hintText, '2');
    expect(sb.focusNode?.hasFocus ?? sb.autofocus, isTrue);
    // Cancel keeps the current blinds.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(setup.bigBlind, 2);
  });

  test('Log a hand card needs the flag and no running tour', () {
    bool v(bool f, bool t) => LoggingModeSelectionScreen.singleHandCardVisible(
        flagOn: f, tourActive: t);
    expect(v(true, false), isTrue);
    expect(v(false, false), isFalse);
    expect(v(true, true), isFalse);
  });
}
