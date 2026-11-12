import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lib/models/game_types.dart';
import '../../lib/models/hand_state_machine.dart';
import '../../lib/models/single_hand_group.dart';
import '../../lib/models/single_hand_setup.dart';
import '../../lib/services/single_hand_service.dart';

final _t0 = DateTime(2026, 11, 12, 22, 0);

SingleHandGroup _group({
  String id = 'g1',
  GameType type = GameType.cash,
  double sb = 1,
  double bb = 2,
  int hands = 3,
  Duration age = const Duration(hours: 1),
}) =>
    SingleHandGroup(
      sessionId: id,
      name: 'Tonight',
      gameType: type,
      smallBlind: sb,
      bigBlind: bb,
      handCount: hands,
      lastHandAt: _t0.subtract(age),
    );

bool _cap50(int n) => n < 50;

class _FakeBackend implements SingleHandBackend {
  final List<SingleHandGroup> groups;
  final Map<String, int> counts;
  final calls = <String>[];
  int? lastHandNumber;
  Map<int, String>? lastNames;
  Map<int, String>? lastIds;

  _FakeBackend({this.groups = const [], this.counts = const {}});

  @override
  Future<List<SingleHandGroup>> loadGroups() async => groups;

  @override
  Future<int> handCount(String groupId) async => counts[groupId] ?? 0;

  @override
  Future<void> createGroup({
    required String groupId,
    required String name,
    required SingleHandSetup setup,
  }) async =>
      calls.add('create:$groupId:$name');

  @override
  Future<(String?, String?)> writeHand({
    required String groupId,
    required int handNumber,
    required HandRecord hand,
    required SingleHandSetup setup,
    required Map<int, String> playerNames,
    Map<int, String>? playerIds,
  }) async {
    lastNames = playerNames;
    lastIds = playerIds;
    calls.add('write:$groupId:$handNumber');
    lastHandNumber = handNumber;
    return ('cloud$handNumber', 'local$handNumber');
  }

  @override
  Future<void> touchGroup(String groupId, DateTime at) async =>
      calls.add('touch:$groupId');
}

HandRecord _hand() => HandRecord(
    handNumber: 1, buttonPosition: 1, playerCount: 6, startTime: _t0);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SingleHandService.now = () => _t0;
    SingleHandService.canAddHand = _cap50;
    SingleHandService.newGroupId = () => 'new-id';
  });

  group('pickSuggested (grouping rule)', () {
    final cash = SingleHandSetup();

    SingleHandGroup? pick(List<SingleHandGroup> g, [SingleHandSetup? s]) =>
        SingleHandService.pickSuggested(g, s ?? cash, _t0, _cap50);

    test('no groups -> new group', () => expect(pick([]), isNull));

    test('recent matching cash group is the default', () {
      expect(pick([_group()])?.sessionId, 'g1');
    });

    test('older than 12 hours -> new group', () {
      expect(pick([_group(age: const Duration(hours: 12))]), isNull);
      expect(pick([_group(age: const Duration(hours: 11, minutes: 59))]),
          isNotNull);
    });

    test('different game type -> new group', () {
      expect(pick([_group(type: GameType.tournament)]), isNull);
    });

    test('cash with different blinds -> new group', () {
      expect(pick([_group(bb: 5, sb: 2)]), isNull);
      expect(pick([_group(sb: 0.5, bb: 2)]), isNull);
    });

    test('tournament ignores blinds', () {
      final t = SingleHandSetup(
          gameType: GameType.tournament, smallBlind: 400, bigBlind: 800);
      final g = _group(type: GameType.tournament, sb: 100, bb: 200);
      expect(pick([g], t)?.sessionId, 'g1');
    });

    test('group at the tier hand cap -> new group', () {
      expect(pick([_group(hands: 50)]), isNull);
      expect(pick([_group(hands: 49)]), isNotNull);
    });

    test('only the MOST recent group is considered', () {
      final newest = _group(id: 'new', bb: 5, sb: 2);
      final older = _group(id: 'old', age: const Duration(hours: 3));
      expect(pick([newest, older]), isNull);
    });
  });

  group('service reads', () {
    test('suggestedGroup sorts newest first and applies the rule', () async {
      SingleHandService.backend = _FakeBackend(groups: [
        _group(id: 'old', age: const Duration(hours: 5)),
        _group(id: 'newest', age: const Duration(minutes: 10)),
      ]);
      final g = await SingleHandService.suggestedGroup(SingleHandSetup());
      expect(g?.sessionId, 'newest');
    });

    test('recentGroups limits to 5 newest first', () async {
      SingleHandService.backend = _FakeBackend(groups: [
        for (var i = 0; i < 8; i++)
          _group(id: 'g$i', age: Duration(hours: i + 1)),
      ]);
      final r = await SingleHandService.recentGroups();
      expect(r.map((g) => g.sessionId), ['g0', 'g1', 'g2', 'g3', 'g4']);
    });
  });

  group('saveHand', () {
    test('null groupId creates a group, hand number 1', () async {
      final b = _FakeBackend();
      SingleHandService.backend = b;
      final r = await SingleHandService.saveHand(
          hand: _hand(), setup: SingleHandSetup());
      expect(r.sessionId, 'new-id');
      expect(r.handNumber, 1);
      expect(r.handId, 'cloud1');
      expect(r.group.handCount, 1);
      expect(b.calls.first, startsWith('create:new-id:'));
      expect(b.calls, ['${b.calls.first}', 'write:new-id:1', 'touch:new-id']);
    });

    test('existing group: no create, handNumber = hands + 1', () async {
      final b = _FakeBackend(counts: {'g1': 3});
      SingleHandService.backend = b;
      final r = await SingleHandService.saveHand(
          hand: _hand(), setup: SingleHandSetup(), groupId: 'g1');
      expect(r.sessionId, 'g1');
      expect(r.handNumber, 4);
      expect(b.calls, ['write:g1:4', 'touch:g1']);
    });

    test('full group starts a new one automatically', () async {
      final b = _FakeBackend(counts: {'g1': 50});
      SingleHandService.backend = b;
      final r = await SingleHandService.saveHand(
          hand: _hand(), setup: SingleHandSetup(), groupId: 'g1');
      expect(r.sessionId, 'new-id');
      expect(r.handNumber, 1);
      expect(b.calls.any((c) => c.startsWith('create:new-id')), true);
    });

    test('a saved opponent on seat 3 is saved with name and id', () async {
      final b = _FakeBackend();
      SingleHandService.backend = b;
      final setup = SingleHandSetup(playerCount: 6, heroPosition: 'BTN');
      final r = await SingleHandService.saveHand(
        hand: _hand(),
        setup: setup,
        playerNames: {1: 'magsud', 3: 'Vlad', 4: 'Player 4', 5: 'UTG'},
        playerIds: {3: 'uid-vlad', 4: ''},
      );
      expect(b.lastNames![3], 'Vlad');
      expect(b.lastNames![1], 'magsud');
      expect(b.lastIds, {3: 'uid-vlad'});
      expect(r.playerNames[3], 'Vlad');
      // placeholders fall back to the position default
      expect(b.lastNames![4], SingleHandService.seatNames(setup)[4]);
      expect(b.lastNames![5], SingleHandService.seatNames(setup)[5]);
    });

    test('no live names: defaults and no ids', () async {
      final b = _FakeBackend();
      SingleHandService.backend = b;
      final setup = SingleHandSetup();
      await SingleHandService.saveHand(hand: _hand(), setup: setup);
      expect(b.lastNames, SingleHandService.seatNames(setup));
      expect(b.lastIds, isNull);
    });

    test('mergeNames: Player N, empty and position labels never win', () {
      final setup = SingleHandSetup(playerCount: 4, heroPosition: 'BTN');
      final d = SingleHandService.seatNames(setup);
      final m = SingleHandService.mergeNames(
          setup, {1: ' ', 2: 'Player 2', 3: 'CO', 4: 'Anna'});
      expect(m[1], d[1]);
      expect(m[2], d[2]);
      expect(m[3], d[3]);
      expect(m[4], 'Anna');
    });

    test('opponent hand lists include hand-group sessions', () {
      for (final f in [
        'lib/screens/opponent_hands_screen.dart',
        'lib/services/opponent_range_service.dart',
      ]) {
        final src = File(f).readAsStringSync();
        expect(src, contains('getAllSessions(includeHandGroups: true)'),
            reason: f);
      }
    });

    test('default name is date, blinds and game type', () {
      final name = SingleHandService.defaultGroupName(SingleHandSetup(), _t0);
      expect(name, 'Nov 12 · 1/2 Cash');
      expect(
          SingleHandService.defaultGroupName(
              SingleHandSetup(
                  gameType: GameType.tournament, smallBlind: 25, bigBlind: 50),
              _t0),
          'Nov 12 · 25/50 Tournament');
    });
  });
}
