import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/daily_challenge_service.dart';
import 'package:poker_logger/services/daily_challenge_store.dart';
import 'package:poker_logger/services/leaderboard_service.dart';

/// Leaderboard pure logic: the score→int key used for ranking, and the
/// admin day-override guard that keeps test runs off the real board.
/// (Firestore reads/writes are covered by rules + the CF, not unit-tested
/// here — there is no Firebase in the VM host.)
void main() {
  setUp(() => DailyChallengeService.debugDayOffset = 0);
  tearDown(() => DailyChallengeService.debugDayOffset = 0);

  group('scoreKey', () {
    test('maps the 0..5 score to an int ×10 for stable ranking', () {
      expect(LeaderboardService.scoreKey(5.0), 50);
      expect(LeaderboardService.scoreKey(4.5), 45);
      expect(LeaderboardService.scoreKey(0.0), 0);
      expect(LeaderboardService.scoreKey(2.5), 25);
    });

    test('orders strictly by score (no float ties)', () {
      expect(LeaderboardService.scoreKey(4.5) >
          LeaderboardService.scoreKey(4.0), isTrue);
      expect(LeaderboardService.scoreKey(3.0) >
          LeaderboardService.scoreKey(2.5), isTrue);
    });
  });

  group('submit admin guard', () {
    test('never writes when debugDayOffset != 0 (returns without error)',
        () async {
      DailyChallengeService.debugDayOffset = 3; // admin previewing a future day
      const result = DailyChallengeResult(
        dayKey: '2026-10-18',
        seed: 1,
        verdicts: 'ccccc',
        spots: [],
      );
      const streaks = DailyChallengeStreaks(
          current: 2, best: 5, perfectDays: 1, totalPlayed: 3);
      // With the offset active this must short-circuit before touching
      // Firestore — so it completes without throwing even with no Firebase.
      await LeaderboardService.submit(
        result: result,
        streaks: streaks,
        username: 'tester',
      );
    });
  });
}
