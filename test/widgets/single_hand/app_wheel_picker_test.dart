import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/design_system/components/pickers/app_wheel_picker.dart';

class _Host extends StatefulWidget {
  final List<String> initial;
  const _Host(this.initial);
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late List<String> items = widget.initial;
  String selected = 'BTN';

  void swap(List<String> next) => setState(() => items = next);

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: AppWheelPicker<String>(
            items: items,
            selected: selected,
            labelBuilder: (s) => s,
            onChanged: (v) => setState(() => selected = v),
          ),
        ),
      );
}

void main() {
  testWidgets('shows selected item and reports scroll changes', (tester) async {
    await tester.pumpWidget(const _Host(['UTG', 'CO', 'BTN', 'SB', 'BB']));
    await tester.pump();
    final state = tester.state<_HostState>(find.byType(_Host));
    expect(state.selected, 'BTN');
    await tester.fling(
        find.byType(AppWheelPicker<String>), const Offset(0, -150), 500);
    await tester.pumpAndSettle();
    expect(state.selected, isNot('BTN'));
  });

  testWidgets('item list change keeps selection when still present',
      (tester) async {
    await tester.pumpWidget(const _Host(['UTG', 'CO', 'BTN', 'SB', 'BB']));
    await tester.pump();
    final state = tester.state<_HostState>(find.byType(_Host));
    state.swap(['BTN', 'BB']);
    await tester.pumpAndSettle();
    expect(state.selected, 'BTN');
    expect(tester.takeException(), isNull);
  });

  testWidgets('falls back to BTN when selection disappears', (tester) async {
    await tester.pumpWidget(const _Host(['UTG', 'CO', 'BTN', 'SB', 'BB']));
    await tester.pump();
    final state = tester.state<_HostState>(find.byType(_Host));
    state.selected = 'UTG';
    state.swap(['SB', 'BTN', 'BB']);
    await tester.pumpAndSettle();
    expect(state.selected, 'BTN');
  });

  testWidgets('falls back to last item when no BTN', (tester) async {
    await tester.pumpWidget(const _Host(['A', 'B', 'BTN']));
    await tester.pump();
    final state = tester.state<_HostState>(find.byType(_Host));
    state.selected = 'A';
    state.swap(['X', 'Y']);
    await tester.pumpAndSettle();
    expect(state.selected, 'Y');
  });
}
