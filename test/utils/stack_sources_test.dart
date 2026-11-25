import 'package:flutter_test/flutter_test.dart';

import '../../lib/models/hand_state_machine.dart';
import '../../lib/services/ai_analyzer_service.dart';
import '../../lib/services/local_storage_service.dart';
import '../../lib/utils/stack_sources.dart';

Map<String, dynamic> _hand([Map<String, dynamic>? extra]) => {
      'handNumber': 1,
      'buttonPosition': 1,
      'playerCount': 3,
      'smallBlind': 1,
      'bigBlind': 2,
      'heroSeatNumber': 1,
      'heroPositionName': 'BTN',
      'gameType': 'cash',
      'actions': [
        for (final s in [1, 2, 3])
          {
            'player': s,
            'action': 'call',
            'street': 'preflop',
            'playerStack': 200.0,
            'playerPosition': ['BTN', 'SB', 'BB'][s - 1],
          },
      ],
      ...?extra,
    };

void main() {
  group('isAssumedStack', () {
    test('absent field = not assumed (old hands, full sessions)', () {
      expect(isAssumedStack({}, 2), isFalse);
      expect(isAssumedStack({'stackSources': null}, 2), isFalse);
    });

    test('only an explicit default is assumed', () {
      final h = {
        'stackSources': {'1': 'set', '2': 'default'}
      };
      expect(isAssumedStack(h, 1), isFalse);
      expect(isAssumedStack(h, 2), isTrue);
      expect(isAssumedStack(h, 3), isFalse);
    });

    test('accepts int keys and ignores junk values', () {
      expect(
          isAssumedStack({
            'stackSources': {2: 'default', 3: 'bogus'}
          }, 2),
          isTrue);
      expect(
          isAssumedStack({
            'stackSources': {3: 'bogus'}
          }, 3),
          isFalse);
      expect(isAssumedStack({'stackSources': 'nope'}, 2), isFalse);
    });
  });

  group('serialization', () {
    test('toMap uses string keys, empty -> null', () {
      expect(stackSourcesToMap({1: 'set', 2: 'default'}),
          {'1': 'set', '2': 'default'});
      expect(stackSourcesToMap({}), isNull);
      expect(stackSourcesToMap(null), isNull);
    });

    test('HandRecord round-trips the marker', () {
      final h = HandRecord(
          handNumber: 1,
          buttonPosition: 1,
          playerCount: 3,
          startTime: DateTime(2026, 11, 25))
        ..stackSources = {1: 'set', 2: 'default'};
      final m = h.toMap();
      expect(m['stackSources'], {'1': 'set', '2': 'default'});
      expect(HandRecord.fromMap(m).stackSources, {1: 'set', 2: 'default'});
    });

    test('HandRecord without the marker writes no key and reads null', () {
      final h = HandRecord(
          handNumber: 1,
          buttonPosition: 1,
          playerCount: 3,
          startTime: DateTime(2026, 11, 25));
      final m = h.toMap();
      expect(m.containsKey('stackSources'), isFalse);
      expect(HandRecord.fromMap(m).stackSources, isNull);
    });

    test('SQLite row re-home keeps the marker column', () {
      final row = LocalStorageService.rehomedHandRow(
          {'id': 'a', 'sessionId': 's1', 'handNumber': 4, 'stackSources': '{}'},
          newId: 'b',
          toSessionId: 's2',
          newHandNumber: 2);
      expect(row['id'], 'b');
      expect(row['sessionId'], 's2');
      expect(row['handNumber'], 2);
      expect(row['stackSources'], '{}');
    });
  });

  group('AI analysis payload', () {
    final marked = _hand({
      'stackSources': {'1': 'set', '2': 'default', '3': 'default'}
    });

    for (final (name, prep) in [
      ('simple', AIAnalyzerService.prepareHandDataForAnalysis),
      ('full', AIAnalyzerService.prepareFullHandData),
    ]) {
      test('$name: default seats are flagged as assumed, not fact', () {
        final out = prep(marked);
        final players = (out['activePlayers'] as List).cast<Map>();
        final by = {for (final p in players) p['seat']: p};
        expect(by[1]!.containsKey('stackAssumed'), isFalse);
        expect(by[2]!['stackAssumed'], isTrue);
        expect(by[2]!['stackNote'], AIAnalyzerService.assumedStackNote);
        expect(out['stackNotes'], contains('Seats 2, 3'));
        expect(out['stackNotes'], contains('assumed equal to the hero'));
      });

      test('$name: hands without the marker are unchanged', () {
        final out = prep(_hand());
        expect(out.containsKey('stackNotes'), isFalse);
        for (final p in (out['activePlayers'] as List).cast<Map>()) {
          expect(p.containsKey('stackAssumed'), isFalse);
          expect(p.containsKey('stackNote'), isFalse);
        }
      });
    }
  });
}
