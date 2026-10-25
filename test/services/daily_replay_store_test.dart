import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/daily_challenge_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The replay store persists unranked replay results in a SEPARATE namespace
/// from the ranked store, so streaks/leaderboard (which read the ranked store)
/// are never perturbed by a replay.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DailyChallengeResult result(String dayKey, String verdicts) =>
      DailyChallengeResult(dayKey: dayKey, seed: 0, verdicts: verdicts, spots: const []);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('replay save → allResults round-trips', () async {
    await DailyReplayStore.save(result('2026-10-20', 'c|c|c|c|c'));
    final all = await DailyReplayStore.allResults();
    expect(all.keys, contains('2026-10-20'));
    expect(all['2026-10-20']!.verdicts, 'c|c|c|c|c');
  });

  test('latest replay overwrites (latest wins)', () async {
    await DailyReplayStore.save(result('2026-10-20', 'm|m|m|m|m'));
    await DailyReplayStore.save(result('2026-10-20', 'c|c|c|c|c'));
    final all = await DailyReplayStore.allResults();
    expect(all['2026-10-20']!.verdicts, 'c|c|c|c|c');
  });

  test('replay store is SEPARATE from the ranked store (no cross-write)',
      () async {
    await DailyReplayStore.save(result('2026-10-20', 'c|c|c|c|c'));
    // The ranked store must NOT see the replay (else streaks would change).
    final ranked = await DailyChallengeStore.allResults();
    expect(ranked.containsKey('2026-10-20'), isFalse);
    // And a ranked save must not appear in the replay store.
    await DailyChallengeStore.save(result('2026-10-21', 'o|o|o|o|o'));
    final replays = await DailyReplayStore.allResults();
    expect(replays.containsKey('2026-10-21'), isFalse);
  });

  test('empty replay store returns {}', () async {
    expect(await DailyReplayStore.allResults(), isEmpty);
  });
}
