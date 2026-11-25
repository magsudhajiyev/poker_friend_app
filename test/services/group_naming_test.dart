import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lib/models/game_types.dart';
import '../../lib/models/hand_state_machine.dart';
import '../../lib/models/single_hand_group.dart';
import '../../lib/models/single_hand_setup.dart';
import '../../lib/services/single_hand_service.dart';

final _t0 = DateTime(2026, 11, 25, 22, 0);

SingleHandGroup _g(String id, String name, int hands, {int hoursAgo = 1}) =>
    SingleHandGroup(
      sessionId: id,
      name: name,
      gameType: GameType.cash,
      smallBlind: 1,
      bigBlind: 2,
      handCount: hands,
      lastHandAt: _t0.subtract(Duration(hours: hoursAgo)),
    );

class _Backend
    implements SingleHandBackend, SingleHandRenameBackend {
  final List<SingleHandGroup> groups;
  final calls = <String>[];
  _Backend(this.groups);

  @override
  Future<List<SingleHandGroup>> loadGroups() async => groups;
  @override
  Future<int> handCount(String groupId) async => 0;
  @override
  Future<void> createGroup(
          {required String groupId,
          required String name,
          required SingleHandSetup setup}) async =>
      calls.add('create:$groupId:$name');
  @override
  Future<(String?, String?)> writeHand(
      {required String groupId,
      required int handNumber,
      required HandRecord hand,
      required SingleHandSetup setup,
      required Map<int, String> playerNames,
      Map<int, String>? playerIds}) async {
    calls.add('write:$groupId:$handNumber');
    return ('c', 'l');
  }

  @override
  Future<void> touchGroup(String groupId, DateTime at) async =>
      calls.add('touch:$groupId');
  @override
  Future<void> renameGroup(String groupId, String name) async =>
      calls.add('rename:$groupId:$name');
}

HandRecord _hand() => HandRecord(
    handNumber: 1, buttonPosition: 1, playerCount: 6, startTime: _t0);

void main() {
  late _Backend b;
  void use(List<SingleHandGroup> groups) {
    b = _Backend(groups);
    SingleHandService.backend = b;
    SingleHandService.renameBackend = b;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SingleHandService.now = () => _t0;
    SingleHandService.canAddHand = (n) => n < 50;
    SingleHandService.newGroupId = () => 'new-id';
  });

  test('a hand that starts a group reports newGroup; a later hand does not',
      () async {
    use([]);
    final first = await SingleHandService.saveHand(
        hand: _hand(),
        setup: SingleHandSetup(),
        groupName: kUnnamedGroupName);
    expect(first.newGroup, isTrue);
    expect(first.group.name, kUnnamedGroupName);
    expect(first.group.needsName, isTrue);
    expect(b.calls.first, 'create:new-id:$kUnnamedGroupName');

    use([_g('g1', 'Friday', 2)]);
    final second = await SingleHandService.saveHand(
        hand: _hand(), setup: SingleHandSetup(), groupId: 'g1');
    expect(second.newGroup, isFalse);
  });

  test('earlier names: newest first, no duplicates, no unnamed groups',
      () async {
    use([
      _g('a', 'Friday', 3, hoursAgo: 30),
      _g('b', 'Casino', 2, hoursAgo: 10),
      _g('c', kUnnamedGroupName, 1, hoursAgo: 2),
      _g('d', 'friday', 4, hoursAgo: 50),
      _g('e', '  ', 1, hoursAgo: 3),
    ]);
    expect(await SingleHandService.recentGroupNames(), ['Casino', 'Friday']);
    expect(await SingleHandService.recentGroupNames(limit: 1), ['Casino']);
  });

  test('unnamed groups with hands are found again after an app kill',
      () async {
    use([
      _g('a', 'Friday', 3),
      _g('b', kUnnamedGroupName, 2, hoursAgo: 5),
      _g('c', kUnnamedGroupName, 1, hoursAgo: 2),
      _g('empty', kUnnamedGroupName, 0),
    ]);
    final unnamed = await SingleHandService.unnamedGroups();
    expect(unnamed.map((g) => g.sessionId), ['c', 'b']);
  });

  test('rename trims, writes through the backend, rejects empty names',
      () async {
    use([_g('a', kUnnamedGroupName, 1)]);
    await SingleHandService.renameGroup('a', '  Home game ');
    expect(b.calls, ['rename:a:Home game']);
    expect(() => SingleHandService.renameGroup('a', '   '),
        throwsArgumentError);
  });

  test('rename fixes the last-group cache so the suggestion keeps the name',
      () async {
    use([]);
    await SingleHandService.saveHand(
        hand: _hand(),
        setup: SingleHandSetup(),
        groupName: kUnnamedGroupName);
    await SingleHandService.renameGroup('new-id', 'Casino night');
    use([]); // offline: only the cache knows the group
    final suggested = await SingleHandService.suggestedGroup(SingleHandSetup());
    expect(suggested?.name, 'Casino night');
  });
}
