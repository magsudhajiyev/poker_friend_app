import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/widgets/single_hand/v2/stack_drag_control.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _steps = [10.0, 20.0, 50.0, 100.0];

class _Host extends StatefulWidget {
  final double start;
  final String? hintKey;
  final List<double> log;
  const _Host({super.key, required this.start, required this.log, this.hintKey});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late double v = widget.start;
  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: StackDragControl(
              steps: _steps,
              value: v,
              mainLabel: (x) => '${x.toInt()} BB',
              subLabel: (x) => 'sub ${x.toInt()}',
              hintPrefsKey: widget.hintKey,
              semanticsLabel: 'Stack',
              increaseLabel: 'Up',
              decreaseLabel: 'Down',
              onChanged: (x) {
                widget.log.add(x);
                setState(() => v = x);
              },
            ),
          ),
        ),
      );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('drag up snaps one step per pixelsPerStep and clamps at the end',
      (t) async {
    final log = <double>[];
    await t.pumpWidget(_Host(start: 20, log: log));
    await t.drag(find.byKey(const ValueKey('stack-main')), const Offset(0, -60));
    await t.pump();
    // 60 px up minus touch slop -> at least one, never past the last step.
    expect(log.first, 50);
    await t.drag(find.byKey(const ValueKey('stack-main')), const Offset(0, -400));
    await t.pump();
    expect(log.last, 100);
    expect(find.text('100 BB'), findsOneWidget);
  });

  testWidgets('drag down steps to smaller values', (t) async {
    final log = <double>[];
    await t.pumpWidget(_Host(start: 50, log: log));
    await t.drag(find.byKey(const ValueKey('stack-main')), const Offset(0, 80));
    await t.pump();
    expect(log.first, 20);
  });

  testWidgets('arrow buttons move exactly one step and clamp', (t) async {
    final log = <double>[];
    await t.pumpWidget(_Host(start: 10, log: log));
    await t.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
    await t.pump();
    expect(log, [20]);
    await t.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await t.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await t.pump();
    expect(log, [20, 10]); // second down is a no-op at the lowest step
  });

  testWidgets('off-grid value: up goes to next step above, down below',
      (t) async {
    final log = <double>[];
    await t.pumpWidget(_Host(start: 35, log: log));
    await t.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
    await t.pump();
    expect(log.last, 50);
    final log2 = <double>[];
    await t.pumpWidget(_Host(start: 35, log: log2, key: UniqueKey()));
    await t.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await t.pump();
    expect(log2.last, 20);
  });

  testWidgets('semantics expose an adjustable control', (t) async {
    final handle = t.ensureSemantics();
    final log = <double>[];
    await t.pumpWidget(_Host(start: 20, log: log));
    SemanticsNode node() => t.getSemantics(find.bySemanticsLabel(RegExp('Stack')));
    final data = node().getSemanticsData();
    expect(data.hasAction(SemanticsAction.increase), isTrue);
    expect(data.hasAction(SemanticsAction.decrease), isTrue);
    expect(data.value, '20 BB');
    void act(SemanticsAction a) =>
        // ignore: invalid_use_of_protected_member
        SemanticsBinding.instance.performSemanticsAction(SemanticsActionEvent(
            type: a, viewId: t.view.viewId, nodeId: node().id));
    act(SemanticsAction.increase);
    await t.pump();
    expect(log, [50]);
    act(SemanticsAction.decrease);
    await t.pump();
    expect(log, [50, 20]);
    handle.dispose();
  });

  testWidgets('hint shows once and stops on first touch', (t) async {
    await t.pumpWidget(_Host(start: 20, log: [], hintKey: 'hint_k'));
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 300));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('hint_k'), isTrue);
    final ghost = find.byWidgetPredicate((w) =>
        w is Container && w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).shape == BoxShape.circle);
    expect(ghost, findsOneWidget);
    await t.tap(find.byKey(const ValueKey('stack-main')));
    await t.pump();
    expect(ghost, findsNothing);
  });

  testWidgets('hint does not show when already seen', (t) async {
    SharedPreferences.setMockInitialValues({'hint_k': true});
    await t.pumpWidget(_Host(start: 20, log: [], hintKey: 'hint_k'));
    await t.pump(const Duration(milliseconds: 400));
    final ghost = find.byWidgetPredicate((w) =>
        w is Container && w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).shape == BoxShape.circle);
    expect(ghost, findsNothing);
  });
}
