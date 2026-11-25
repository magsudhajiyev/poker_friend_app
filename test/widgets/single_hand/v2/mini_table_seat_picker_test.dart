import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/models/single_hand_setup.dart';
import 'package:poker_logger/widgets/single_hand/v2/mini_table_seat_picker.dart';

class _Host extends StatefulWidget {
  final int players;
  final String hero;
  final List<String> log;
  const _Host({required this.players, required this.hero, required this.log});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late String hero = widget.hero;
  @override
  Widget build(BuildContext context) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: MiniTableSeatPicker(
              positions: SingleHandSetup.positionsFor(widget.players),
              heroPosition: hero,
              onChanged: (p) {
                widget.log.add(p);
                setState(() => hero = p);
              },
            ),
          ),
        ),
      );
}

void main() {
  Future<void> pump(WidgetTester t, int n, String hero, List<String> log) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(_Host(players: n, hero: hero, log: log));
  }

  testWidgets('tap on a seat sits the hero there', (t) async {
    final log = <String>[];
    await pump(t, 6, 'BTN', log);
    await t.tap(find.text('CO'));
    await t.pumpAndSettle();
    expect(log, ['CO']);
    expect(find.text('You'), findsOneWidget);
  });

  testWidgets('tapping the hero seat does nothing', (t) async {
    final log = <String>[];
    await pump(t, 6, 'BTN', log);
    await t.tap(find.text('You'));
    await t.pumpAndSettle();
    expect(log, isEmpty);
  });

  testWidgets('table follows the finger: drag left brings the seat that was '
      'right of the hero to the bottom', (t) async {
    final log = <String>[];
    await pump(t, 6, 'BTN', log); // list: UTG HJ CO BTN SB BB
    final centerX = t.getCenter(find.byType(MiniTableSeatPicker)).dx;
    // CO sits right of the hero (BTN, bottom) before the drag.
    expect(t.getCenter(find.text('CO')).dx, greaterThan(centerX + 20));
    await t.drag(find.byType(MiniTableSeatPicker), const Offset(-90, 0));
    await t.pumpAndSettle();
    expect(log, ['CO']);
    expect(t.getCenter(find.text('You')).dx, closeTo(centerX, 2));
    await t.pump(const Duration(milliseconds: 400)); // past the tap guard
    await t.drag(find.byType(MiniTableSeatPicker), const Offset(90, 0));
    await t.pumpAndSettle();
    expect(log, ['CO', 'BTN']);
  });

  testWidgets('drag right brings the seat that was left of the hero down',
      (t) async {
    final log = <String>[];
    await pump(t, 6, 'BTN', log);
    final centerX = t.getCenter(find.byType(MiniTableSeatPicker)).dx;
    expect(t.getCenter(find.text('SB')).dx, lessThan(centerX - 20));
    await t.drag(find.byType(MiniTableSeatPicker), const Offset(90, 0));
    await t.pumpAndSettle();
    expect(log, ['SB']);
  });

  testWidgets('swipe wraps around the ring', (t) async {
    final log = <String>[];
    await pump(t, 3, 'BB', log); // BTN SB BB
    await t.drag(find.byType(MiniTableSeatPicker), const Offset(90, 0));
    await t.pumpAndSettle();
    expect(log, ['BTN']);
  });

  testWidgets('arrow buttons step one seat; heads-up has two seats',
      (t) async {
    final log = <String>[];
    await pump(t, 2, 'BTN', log);
    expect(find.text('BB'), findsOneWidget);
    await t.tap(find.byIcon(Icons.chevron_right));
    await t.pumpAndSettle();
    expect(log, ['BB']);
  });

  testWidgets('‹ spins left like a left drag, › like a right drag', (t) async {
    final log = <String>[];
    await pump(t, 6, 'BTN', log);
    await t.tap(find.byIcon(Icons.chevron_left));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.chevron_right));
    await t.pumpAndSettle();
    expect(log, ['CO', 'BTN']);
  });

  testWidgets('nine seats at 320 px and text scale 1.3 do not overflow',
      (t) async {
    t.view.physicalSize = const Size(960, 1704);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(MediaQuery(
      data: const MediaQueryData(
          size: Size(320, 568), textScaler: TextScaler.linear(1.3)),
      child: _Host(players: 9, hero: 'BTN', log: []),
    ));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('seats are buttons for screen readers', (t) async {
    final handle = t.ensureSemantics();
    await pump(t, 6, 'BTN', []);
    expect(find.bySemanticsLabel('Sit on CO'), findsOneWidget);
    expect(find.bySemanticsLabel('Your seat, BTN'), findsOneWidget);
    handle.dispose();
  });
}
