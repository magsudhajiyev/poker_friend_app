import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/models/game_types.dart';
import 'package:poker_logger/models/hand_state_machine.dart';
import 'package:poker_logger/models/single_hand_group.dart';
import 'package:poker_logger/models/single_hand_setup.dart';
import 'package:poker_logger/services/single_hand_service.dart';
import 'package:poker_logger/widgets/single_hand/single_hand_result_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _t0 = DateTime(2026, 11, 25, 22);

SingleHandGroup _g(String id, String name, int hands) => SingleHandGroup(
      sessionId: id,
      name: name,
      gameType: GameType.cash,
      smallBlind: 1,
      bigBlind: 2,
      handCount: hands,
      lastHandAt: _t0,
    );

class _Backend implements SingleHandBackend, SingleHandMoveBackend {
  final List<SingleHandGroup> groups;
  final Map<String, int> counts;
  final calls = <String>[];
  _Backend(this.groups, this.counts);

  @override
  Future<List<SingleHandGroup>> loadGroups() async => groups;
  @override
  Future<int> handCount(String groupId) async => counts[groupId] ?? 0;
  @override
  Future<void> createGroup(
          {required String groupId,
          required String name,
          required SingleHandSetup setup}) async =>
      calls.add('create:$groupId:$name');
  @override
  Future<(String?, String?)> writeHand({
    required String groupId,
    required int handNumber,
    required HandRecord hand,
    required SingleHandSetup setup,
    required Map<int, String> playerNames,
    Map<int, String>? playerIds,
  }) async =>
      ('c', 'l');
  @override
  Future<void> touchGroup(String groupId, DateTime at) async =>
      calls.add('touch:$groupId');
  @override
  Future<(String?, String?)> moveHand({
    required String fromGroupId,
    required String toGroupId,
    required String handId,
    required int handNumber,
    required int newHandNumber,
  }) async {
    calls.add('move:$fromGroupId>$toGroupId:$handNumber>$newHandNumber');
    return ('moved$newHandNumber', null);
  }
}

Future<List<SingleHandMoveResult>> _pump(
    WidgetTester t, _Backend b, {bool v2 = true}) async {
  SingleHandService.backend = b;
  SingleHandService.moveBackend = b;
  SingleHandService.now = () => _t0;
  SingleHandService.newGroupId = () => 'new-id';
  SingleHandService.canAddHand = (n) => n < 50;
  final moved = <SingleHandMoveResult>[];
  t.view.physicalSize = const Size(1170, 2532);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  final hand = HandRecord(
      handNumber: 1, buttonPosition: 1, playerCount: 6, startTime: _t0);
  await t.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleHandResultSheet(
        hand: hand,
        saved: SingleHandSaveResult(
          sessionId: 'g1',
          handId: 'hand_1',
          handNumber: 3,
          group: _g('g1', 'Nov 25 · 1/2 Cash', 3),
        ),
        showGroupChange: v2,
        setup: SingleHandSetup(),
        newGroupName: 'Nov 25 · 1/2 Cash',
        onMoved: moved.add,
      ),
    ),
  ));
  await t.pump();
  return moved;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('v1 sheet shows no group line', (t) async {
    await _pump(t, _Backend([], {}), v2: false);
    expect(find.byKey(const ValueKey('saved-to')), findsNothing);
  });

  testWidgets('shows the group, Change moves the hand and updates the label',
      (t) async {
    final b = _Backend(
        [_g('g1', 'Nov 25 · 1/2 Cash', 3), _g('g2', 'Friday game', 4)],
        {'g2': 4});
    final moved = await _pump(t, b);
    expect(find.text('Saved to Nov 25 · 1/2 Cash · 3 hands'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('saved-to-change')));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.text('New group'), findsOneWidget);
    expect(find.text('Nov 25 · 1/2 Cash'), findsNothing); // current group not offered
    await t.tap(find.text('Friday game'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(b.calls, ['move:g1>g2:3>5', 'touch:g2']);
    expect(find.text('Saved to Friday game · 5 hands'), findsOneWidget);
    expect(moved.single.sessionId, 'g2');
    expect(moved.single.handNumber, 5);
    expect(moved.single.handId, 'moved5');
    expect(moved.single.group.name, 'Friday game');
  });

  testWidgets('New group creates it and moves the hand there', (t) async {
    final b = _Backend([_g('g1', 'Nov 25 · 1/2 Cash', 3)], {});
    final moved = await _pump(t, b);
    await t.tap(find.byKey(const ValueKey('saved-to-change')));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.text('New group'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(b.calls.first, 'create:new-id:Nov 25 · 1/2 Cash');
    expect(find.text('Saved to Nov 25 · 1/2 Cash · 1 hand'), findsOneWidget);
    expect(moved.single.sessionId, 'new-id');
  });

  testWidgets('a full target group leaves the label unchanged', (t) async {
    final b = _Backend(
        [_g('g1', 'Nov 25 · 1/2 Cash', 3), _g('g2', 'Full one', 50)],
        {'g2': 50});
    final moved = await _pump(t, b);
    await t.tap(find.byKey(const ValueKey('saved-to-change')));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.text('Full one'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(moved, isEmpty);
    expect(b.calls, isEmpty);
    expect(find.text('Saved to Nov 25 · 1/2 Cash · 3 hands'), findsOneWidget);
  });
}
