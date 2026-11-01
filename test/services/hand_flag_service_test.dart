import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/game_types.dart';
import 'package:poker_logger/models/hand_completeness.dart';
import 'package:poker_logger/models/hand_state_machine.dart';
import 'package:poker_logger/services/hand_flag_service.dart';

class _FakeStore implements FlagStore {
  List<Map<String, dynamic>> cloud = [];
  List<Map<String, dynamic>> local = [];
  bool cloudFails = false;
  bool refuseCloudDelete = false;
  final List<String> deletedCloud = [];
  final List<String> deletedLocal = [];

  @override
  Future<List<Map<String, dynamic>>> cloudPending(String sessionId) async {
    if (cloudFails) throw StateError('offline');
    return cloud;
  }

  @override
  Future<List<Map<String, dynamic>>> localPending(String sessionId) async =>
      local;

  @override
  Future<bool> deleteCloud(String sessionId, String id) async {
    if (refuseCloudDelete) return false;
    deletedCloud.add(id);
    return true;
  }

  @override
  Future<void> deleteLocal(String id) async => deletedLocal.add(id);
}

PokerSessionManager _manager() => PokerSessionManager(
      smallBlind: 1,
      bigBlind: 2,
      playerCount: 6,
      ourSeatNumber: 4,
      gameType: GameType.cash,
    )
      ..sessionId = 's1'
      ..activeSeats = {1, 2, 3, 4, 5, 6}
      ..playerStacks = {4: 200}
      ..buttonPosition = 2;

Map<String, dynamic> _stub(int n, {String? id}) => {
      if (id != null) 'id': id,
      'handNumber': n,
      'startTime': '2026-10-31T20:00:00.000',
      'completeness': 'flagged',
      'heroPositionName': 'BTN',
      'flag': {
        'tags': ['cooler'],
        'flaggedAt': '2026-10-31T20:01:00.000',
        'heroStackBB': 100.0,
      },
    };

void main() {
  group('tags', () {
    test('toggle adds, removes and rejects the 4th', () {
      var t = <String>[];
      t = HandFlagService.toggleTag(t, 'cooler');
      t = HandFlagService.toggleTag(t, 'bluff');
      t = HandFlagService.toggleTag(t, 'review');
      expect(t, ['cooler', 'bluff', 'review']);
      expect(HandFlagService.toggleTag(t, 'mistake'), t);
      expect(HandFlagService.toggleTag(t, 'bluff'), ['cooler', 'review']);
    });
    test('sanitize drops unknown and duplicates, caps at 3', () {
      expect(
        HandFlagService.sanitizeTags(
            ['cooler', 'cooler', 'nope', 'bluff', 'review', 'mistake']),
        ['cooler', 'bluff', 'review'],
      );
    });
  });

  group('createStub', () {
    test('stub has time, blinds, stacks, position, cards and <= 3 tags',
        () async {
      final m = _manager();
      final saved = <HandRecord>[];
      m.persistOverride = (h) async => saved.add(h);
      final svc = HandFlagService.forSession(m, store: _FakeStore());
      final ref = await svc.createStub(
        tags: ['cooler', 'bluff', 'review', 'mistake'],
        heroCards: HoleCards(card1: 'A♠', card2: 'K♠'),
        stackDeltaBB: 35,
      );
      expect(ref, isNotNull);
      final r = saved.single;
      expect(r.completeness, HandCompleteness.flagged);
      expect(r.actions, isEmpty);
      expect(r.statsApplied, isFalse);
      expect(r.ourHoleCards!.card1, 'A♠');
      final meta = r.flagMeta!;
      expect((meta['tags'] as List).length, 3);
      expect(meta['bigBlind'], 2);
      expect(meta['smallBlind'], 1);
      expect(meta['stacks'], isNotEmpty);
      expect(meta['flaggedAt'], isNotNull);
      expect(meta['stackDeltaBB'], 35);
      expect(ref!.tags.length, 3);
      expect(ref.stackDeltaBB, 35);
      expect(ref.sessionId, 's1');
    });

    test('hero cards survive record -> store map -> FlaggedHandRef', () {
      final rec = _manager().buildFlagRecord(
          tags: const ['cooler'],
          heroCards: HoleCards(card1: 'A♠', card2: 'K♥'));
      final cloudMap = rec.toMap();
      // SQLite stores the cards as JSON text and decodes them on read.
      final localMap = Map<String, dynamic>.from(cloudMap)
        ..['ourHoleCards'] = jsonDecode(jsonEncode(cloudMap['ourHoleCards']));
      for (final m in [cloudMap, localMap]) {
        final ref = FlaggedHandRef.fromMap('s1', m);
        expect(ref.heroCards, {'card1': 'A♠', 'card2': 'K♥'});
      }
    });

    test('flag from stack delta carries big_pot and stackDeltaBB', () async {
      final m = _manager();
      m.persistOverride = (h) async {};
      final svc = HandFlagService.forSession(m, store: _FakeStore());
      final ref = await svc.createStub(
          tags: const ['big_pot'], source: 'stack_delta', stackDeltaBB: -42);
      expect(ref!.tags, ['big_pot']);
      expect(ref.stackDeltaBB, -42);
      expect(ref.flagMeta['source'], 'stack_delta');
    });
  });

  group('pending', () {
    test('merges cloud and local by hand number, oldest first', () async {
      final store = _FakeStore()
        ..cloud = [_stub(7, id: 'c7'), _stub(3, id: 'c3')]
        ..local = [_stub(3, id: 'l3'), _stub(9, id: 'l9')];
      final list =
          await HandFlagService(store: store, sessionId: 's1').pendingFor('s1');
      expect(list.map((e) => e.handNumber), [3, 7, 9]);
      expect(list[0].cloudId, 'c3');
      expect(list[0].localId, 'l3');
      expect(list[1].localId, isNull);
      expect(list[2].cloudId, isNull);
      expect(list[0].heroPositionName, 'BTN');
    });

    test('falls back to SQLite when the cloud read fails', () async {
      final store = _FakeStore()
        ..cloudFails = true
        ..local = [_stub(4, id: 'l4')];
      final list =
          await HandFlagService(store: store, sessionId: 's1').pendingFor('s1');
      expect(list.single.localId, 'l4');
    });
  });

  group('discard', () {
    test('deletes both copies and resolves the open count, no stats', () async {
      final m = _manager();
      m.persistOverride = (h) async {};
      final store = _FakeStore();
      final svc = HandFlagService.forSession(m, store: store);
      await svc.createStub(tags: const ['cooler']);
      expect(m.flagsOpenCount, 1);
      final ok = await svc.discard(const FlaggedHandRef(
          sessionId: 's1', handNumber: 1, cloudId: 'c1', localId: 'l1'));
      expect(ok, isTrue);
      expect(store.deletedCloud, ['c1']);
      expect(store.deletedLocal, ['l1']);
      expect(m.flagsOpenCount, 0);
      // The store seam has no stats method at all: discard cannot count.
      expect(m.skippedHands, 0);
    });

    test('never deletes a stub that was already counted', () async {
      final store = _FakeStore()..refuseCloudDelete = true;
      final svc = HandFlagService(store: store, sessionId: 's1');
      final ok = await svc.discard(const FlaggedHandRef(
          sessionId: 's1', handNumber: 1, cloudId: 'c1', localId: 'l1'));
      expect(ok, isFalse);
      expect(store.deletedLocal, isEmpty);
    });
  });
}
