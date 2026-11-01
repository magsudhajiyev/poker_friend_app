import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/flag_resolution_loader.dart';
import 'package:poker_logger/services/hand_flag_service.dart';

class _Store implements FlagStore {
  final List<Map<String, dynamic>> local;
  _Store([this.local = const []]);
  @override
  Future<List<Map<String, dynamic>>> cloudPending(String s) async => [];
  @override
  Future<List<Map<String, dynamic>>> localPending(String s) async => local;
  @override
  Future<bool> deleteCloud(String s, String id) async => true;
  @override
  Future<void> deleteLocal(String id) async {}
}

Map<String, dynamic> pend(String id) =>
    {'changeType': 'pending', 'flagId': id, 'stackSize': 100.0};

void main() {
  test('no pending entries: nothing is read', () async {
    var reads = 0;
    final r = await FlagResolutionLoader.load('s', [
      {'changeType': 'initial', 'stackSize': 1.0}
    ], fetch: (_, __) async {
      reads++;
      return null;
    });
    expect(r, isEmpty);
    expect(reads, 0);
  });

  test('maps heroDelta, discarded, missing doc and read errors', () async {
    final docs = <String, Map<String, dynamic>?>{
      'a': {'flag': {'heroDelta': -40, 'heroDeltaSource': 'recall'}},
      'b': {'flag': {'discarded': true}},
      'c': null, // gone, not local -> discarded
      'd': null, // gone but local-only stub -> unresolved
      'e': {'flag': {'tags': []}}, // open stub
    };
    final r = await FlagResolutionLoader.load(
      's',
      [for (final id in ['a', 'b', 'c', 'd', 'e', 'x']) pend(id)],
      fetch: (_, id) async {
        if (id == 'x') throw Exception('offline');
        return docs[id];
      },
      store: _Store([
        {'id': 'd'}
      ]),
    );
    expect(r['a']!.heroDelta, -40);
    expect(r['b']!.discarded, isTrue);
    expect(r['c']!.discarded, isTrue);
    expect(r.containsKey('d'), isFalse);
    expect(r['e']!.isResolved, isFalse);
    expect(r.containsKey('x'), isFalse);
  });
}
