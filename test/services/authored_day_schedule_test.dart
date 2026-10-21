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

  test('bundled schedule: exact day wins, else default, else null', () {
    final schedule = {
      'days': {
        '2026-10-22': ['x', 'y']
      },
      'default': ['d'],
    };
    expect(AuthoredTreeService.bundledHandIds(schedule, '2026-10-22'),
        ['x', 'y']);
    expect(AuthoredTreeService.bundledHandIds(schedule, '2026-10-23'), ['d']);
    expect(
        AuthoredTreeService.bundledHandIds({'days': {}}, '2026-10-23'), isNull);
  });
}
