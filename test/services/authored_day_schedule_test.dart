import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/authored_tree_service.dart';

void main() {
  test('Firestore day doc → hand ids in order, junk dropped', () {
    expect(
        AuthoredTreeService.handIdsFrom({
          'hands': ['a', '', 7, 'b']
        }),
        ['a', 'b']);
    expect(AuthoredTreeService.handIdsFrom(null), isNull);
    expect(AuthoredTreeService.handIdsFrom({'hands': 'a'}), isNull);
  });

  test('bundled schedule: exact day wins, else rotation, else null', () {
    final schedule = {
      'days': {
        '2026-10-22': ['x', 'y']
      },
      'rotation': ['a', 'b', 'c'],
    };
    expect(AuthoredTreeService.bundledHandIds(schedule, '2026-10-22'),
        ['x', 'y']);
    expect(AuthoredTreeService.bundledHandIds(schedule, '2026-10-23'),
        hasLength(3));
    expect(
        AuthoredTreeService.bundledHandIds({'days': {}}, '2026-10-23'), isNull);
  });

  group('rotationPick', () {
    final six = ['a', 'b', 'c', 'd', 'e', 'f'];
    test('deterministic, <=5, consecutive, wraps, changes daily', () {
      final d1 = AuthoredTreeService.rotationPick('2026-10-23', six);
      expect(AuthoredTreeService.rotationPick('2026-10-23', six), d1);
      expect(d1, hasLength(5));
      final d2 = AuthoredTreeService.rotationPick('2026-10-24', six);
      expect(d2, isNot(d1));
      // consecutive modulo len
      for (var i = 1; i < d1.length; i++) {
        expect(six.indexOf(d1[i]), (six.indexOf(d1[i - 1]) + 1) % 6);
      }
      expect(six.indexOf(d2.first), (six.indexOf(d1.first) + 1) % 6);
    });
    test('short list serves all, empty/bad key serves none', () {
      expect(AuthoredTreeService.rotationPick('2026-10-23', ['a', 'b']),
          hasLength(2));
      expect(AuthoredTreeService.rotationPick('2026-10-23', []), isEmpty);
      expect(AuthoredTreeService.rotationPick('nope', six), isEmpty);
    });
  });

  group('resolveSchedule source', () {
    final bundled = {
      'days': {
        '2026-10-22': ['x']
      },
      'rotation': ['a'],
    };
    Future<DaySchedule> run(Future<Map<String, dynamic>?> Function() f,
            {Map<String, dynamic>? b, String day = '2026-10-22'}) =>
        AuthoredTreeService.resolveSchedule(
            dayKey: day,
            fetchDoc: () async => DayDocRead(await f()),
            bundled: b ?? bundled);

    test('doc → firestore, ranked', () async {
      final r = await run(() async => {'hands': ['f']});
      expect(r.source, DaySource.firestore);
      expect(r.hands, ['f']);
      expect(r.ranked, isTrue);
    });
    test('no doc → bundled, ranked', () async {
      final r = await run(() async => null);
      expect(r.source, DaySource.bundledConfirmedMissing);
      expect(r.hands, ['x']);
      expect(r.ranked, isTrue);
    });
    test('throw / timeout → fallback, unranked', () async {
      final r = await run(() async => throw Exception('offline'));
      expect(r.source, DaySource.fallbackAfterError);
      expect(r.hands, ['x']);
      expect(r.ranked, isFalse);
      final t = await run(() async => throw TimeoutException('t'));
      expect(t.ranked, isFalse);
    });
    test('cached "no doc" → fallback, unranked (offline defence)', () async {
      final r = await AuthoredTreeService.resolveSchedule(
          dayKey: '2026-10-22',
          fetchDoc: () async => const DayDocRead(null, fromCache: true),
          bundled: bundled);
      expect(r.source, DaySource.fallbackAfterError);
      expect(r.hands, ['x']);
      expect(r.ranked, isFalse);
    });
    test('error with nothing bundled stays unranked', () async {
      final r = await run(() async => throw Exception('x'), b: {'days': {}});
      expect(r.hands, isNull);
      expect(r.ranked, isFalse);
    });
    test('no doc, nothing bundled → rng', () async {
      final r = await run(() async => null, b: {'days': {}});
      expect(r.source, DaySource.rng);
      expect(r.hands, isNull);
    });
  });
}
