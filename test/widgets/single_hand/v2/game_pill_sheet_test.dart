import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/design_system/components/app_toggle.dart';
import 'package:poker_logger/design_system/components/pickers/app_wheel_picker.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/models/blind_level.dart';
import 'package:poker_logger/models/game_types.dart';
import 'package:poker_logger/models/single_hand_setup.dart';
import 'package:poker_logger/widgets/single_hand/v2/game_pill_sheet.dart';

void main() {
  late SingleHandSetup s;
  late List<String> log;

  Future<void> pump(WidgetTester t,
      {Size size = const Size(390, 844), double textScale = 1}) async {
    t.view.physicalSize = size * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (c) => TextButton(
            onPressed: () => GamePillSheet.show(
              c,
              setup: s,
              extraLevels: {BlindLevel(s.smallBlind, s.bigBlind)},
              onGameType: (g) {
                log.add('game:${g.name}');
                s.gameType = g;
                final d = BlindLevel.defaultFor(g);
                s.smallBlind = d.sb;
                s.bigBlind = d.bb;
              },
              onBlinds: (l) {
                log.add('blinds:${l.sb}/${l.bb}');
                s.smallBlind = l.sb;
                s.bigBlind = l.bb;
              },
              onAnte: (v) {
                log.add('ante:$v');
                s.hasBBante = v;
              },
              onPlayers: (n) {
                log.add('players:$n');
                s.playerCount = n;
              },
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
  }

  setUp(() {
    s = SingleHandSetup();
    log = [];
  });

  Finder playersWheel() => find.byType(AppWheelPicker<int>);
  Finder blindsWheel() => find.byType(AppWheelPicker<BlindLevel>);

  testWidgets('scrolling each wheel applies a new value, no save button',
      (t) async {
    await pump(t);
    await t.fling(playersWheel(), const Offset(0, -150), 600);
    await t.pumpAndSettle();
    expect(log.last, startsWith('players:'));
    expect(s.playerCount, isNot(6));
    await t.fling(blindsWheel(), const Offset(0, -150), 600);
    await t.pumpAndSettle();
    expect(log.any((e) => e.startsWith('blinds:')), isTrue);
    expect(s.bigBlind, isNot(2));
    expect(find.text('Done'), findsNothing);
  });

  testWidgets('BB ante switch only exists for tournaments', (t) async {
    await pump(t);
    expect(find.text('BB ante'), findsNothing);
    await t.tap(find.text('Tourney'));
    await t.pumpAndSettle();
    expect(log, ['game:tournament']);
    expect(s.gameType, GameType.tournament);
    expect(find.text('BB ante'), findsOneWidget);
    await t.tap(find.byType(AppToggle));
    await t.pump();
    expect(log.last, 'ante:true');
  });

  for (final size in const [Size(360, 640), Size(320, 568)]) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets('wheels take vertical drags at $size, text x$scale',
          (t) async {
        await pump(t, size: size, textScale: scale);
        await t.tap(find.text('Tourney')); // tallest variant (ante row)
        await t.pumpAndSettle();
        expect(find.text('BB ante'), findsOneWidget);
        await t.fling(playersWheel(), const Offset(0, -150), 600);
        await t.pumpAndSettle();
        expect(log.last, startsWith('players:'));
        final before = log.length;
        await t.fling(blindsWheel(), const Offset(0, 150), 600);
        await t.pumpAndSettle();
        expect(log.length, greaterThan(before));
        expect(log.last, startsWith('blinds:'));
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('Custom opens the form; cancel snaps the wheel back',
      (t) async {
    await pump(t);
    await t.fling(blindsWheel(), const Offset(0, -3000), 4000);
    await t.pumpAndSettle();
    expect(find.text('Small blind'), findsOneWidget);
    expect(log.where((e) => e.startsWith('blinds:')), isEmpty);
    await t.tapAt(const Offset(10, 10)); // tap the barrier: cancel
    await t.pumpAndSettle();
    expect(find.text('Small blind'), findsNothing);
    expect(find.text('Custom…'), findsNothing); // wheel is back on 1/2
    expect(log.where((e) => e.startsWith('blinds:')), isEmpty);
  });

  testWidgets('Custom blinds typed in the form apply', (t) async {
    await pump(t);
    await t.fling(blindsWheel(), const Offset(0, -3000), 4000);
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, '3');
    await t.enterText(find.byType(TextField).last, '6');
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    expect(log.last, 'blinds:3.0/6.0');
  });

  test('pill text shows blinds, game and players', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(gamePillText(l10n, SingleHandSetup()), '1/2 Cash · 6 players');
  });
}
