import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D22: hands of a tracked session never reach HAND stats (VPIP/PFR, opponent
/// stats, range grid, Leak Detector, recalculation). The readers hit Firebase,
/// so this guard scans the source: every file that reads the hands of ALL
/// sessions must skip tracked sessions, or be listed here with the reason it
/// may not.
void main() {
  // Files that read session hands but are NOT "all hands" stats readers.
  const allowed = <String, String>{
    'lib/services/firebase_service.dart': 'defines the readers',
    'lib/screens/session_hands_screen.dart': 'one session\'s hand list',
    'lib/screens/session_analytics_screen.dart': 'one session\'s analytics',
    'lib/screens/opponent_hands_screen.dart':
        'opponent hand LIST (browsing, no stats); groups are listed too',
    'lib/screens/debug_hand_viewer.dart': 'debug tool',
    'lib/services/session_leak_check.dart':
        'chip for the full session that just ended; tracked never calls it',
    'lib/screens/session_details_screen.dart':
        'lists the hands of the running tracked session itself',
    'lib/screens/player/player_session_screen.dart': 'dealer sessions',
    'lib/screens/club/event_dashboard_screen.dart': 'dealer sessions',
    'lib/services/event_service.dart': 'dealer sessions',
    'lib/services/dealer_service.dart': 'dealer sessions',
    'lib/services/local_storage_service.dart':
        'defines the SQL query (checked by its own test below)',
    'lib/services/range_grid_service.dart':
        'uses getHandsForRangeBackfill, whose SQL excludes tracked hands',
  };

  List<File> dartFiles() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.contains('/l10n/'))
      .toList();

  test('every all-sessions hand reader skips tracked sessions', () {
    final readers = RegExp(
        r'FirebaseService\.getSessionHands(Prefetched)?\(|getHandsForRangeBackfill\(');
    final offenders = <String>[];
    for (final f in dartFiles()) {
      final path = f.path;
      if (allowed.containsKey(path)) continue;
      final src = f.readAsStringSync();
      if (!readers.hasMatch(src)) continue;
      if (!src.contains('isTrackedSession(') &&
          !src.contains('skipsHandStats(')) {
        offenders.add(path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'These files read session hands without skipping tracked '
            'sessions: $offenders');
  });

  test('the Leak Detector skips tracked sessions in its own query', () {
    final src = File('lib/services/leak_report_service.dart').readAsStringSync();
    expect(src, contains('skipsHandStats(data)'));
  });

  test('the local range-grid backfill query leaves tracked hands out', () {
    final src =
        File('lib/services/local_storage_service.dart').readAsStringSync();
    final i = src.indexOf('getHandsForRangeBackfill');
    final q = src.substring(i, i + 1200);
    expect(q, contains("'hand_group', 'tracked'"));
  });

  test('stats recalculation keeps tracked sessions for count/time only', () {
    final src = File('lib/services/user_stats_service.dart').readAsStringSync();
    // Both recalculation paths skip the hand loop for tracked sessions.
    expect('isTrackedSession(session)'.allMatches(src).length, 2);
    expect(src, contains('totalSessions = sessions.length'));
  });

  test('hand saves from a tracked session never update stats', () {
    final src =
        File('lib/services/single_hand_service.dart').readAsStringSync();
    // The one cloud write path used by groups AND tracked sessions.
    expect(src, contains('skipStats: true'));
  });
}
