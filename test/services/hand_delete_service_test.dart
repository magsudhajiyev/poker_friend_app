import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/hand_delete_service.dart';

class _Backend implements HandDeleteBackend {
  final Map<String, Map<String, dynamic>> sessions;
  final calls = <String>[];
  _Backend(this.sessions);

  @override
  Future<Map<String, dynamic>?> loadSession(String id) async => sessions[id];

  @override
  Future<void> deleteHand({
    required String sessionId,
    required String? handId,
    required int? handNumber,
    required bool touchEndTime,
  }) async =>
      calls.add('$sessionId:$handId:$handNumber:end=$touchEndTime');
}

void main() {
  late _Backend b;
  setUp(() {
    b = _Backend({
      'group': {'sessionType': 'hand_group'},
      'tracked': {'sessionType': 'tracked'},
      'full': {'totalHands': 12},
    });
    HandDeleteService.backend = b;
  });

  test('only hand groups and tracked sessions are deletable', () async {
    expect(await HandDeleteService.canDelete('group'), isTrue);
    expect(await HandDeleteService.canDelete('tracked'), isTrue);
    expect(await HandDeleteService.canDelete('full'), isFalse);
    expect(await HandDeleteService.canDelete('unknown'), isFalse);
    expect(await HandDeleteService.canDelete(null), isFalse);
  });

  test('group: deletes, moves the end time, bumps the notifier', () async {
    final before = HandDeleteService.deletions.value;
    await HandDeleteService.delete(
        sessionId: 'group', handId: 'h1', handNumber: 2);
    expect(b.calls, ['group:h1:2:end=true']);
    expect(HandDeleteService.deletions.value, before + 1);
  });

  test('tracked session: deletes but keeps its own end time', () async {
    await HandDeleteService.delete(
        sessionId: 'tracked', handId: 'h1', handNumber: 4);
    expect(b.calls, ['tracked:h1:4:end=false']);
  });

  test('a full-session hand is refused and nothing is touched', () async {
    final before = HandDeleteService.deletions.value;
    await expectLater(
        HandDeleteService.delete(sessionId: 'full', handId: 'h', handNumber: 1),
        throwsStateError);
    expect(b.calls, isEmpty);
    expect(HandDeleteService.deletions.value, before);
  });
}
