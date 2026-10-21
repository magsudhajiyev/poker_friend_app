import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:poker_logger/models/drill_models.dart';
import 'package:poker_logger/services/daily_challenge_service.dart';
import 'package:poker_logger/services/daily_challenge_store.dart';
import 'package:poker_logger/services/drill_engine.dart';

/// Daily Challenge: the shared-puzzle contract (same date → identical spots
/// for every user), verdict/score mapping, share text, and streak math.
void main() {
  group('DailyChallengeService config', () {
    test('config is a pure function of the date', () {
      final a = DailyChallengeService.configFor(DateTime(2026, 10, 16, 9));
      final b = DailyChallengeService.configFor(DateTime(2026, 10, 16, 23));
      expect(a.seed, b.seed);
      expect(a.theme, b.theme);
      expect(a.stackBB, b.stackBB);
      expect(a.players, b.players);
    });

    test('weekday rotation covers all 7 days with sane depths', () {
      final seen = <String>{};
      for (var i = 0; i < 7; i++) {
        final c =
            DailyChallengeService.configFor(DateTime(2026, 10, 12 + i));
        seen.add(c.theme);
        expect(c.stackBB, greaterThanOrEqualTo(10));
        expect(c.players, inInclusiveRange(2, 9));
        expect(c.formatLabel, contains('${c.stackBB.round()}BB'));
      }
      expect(seen.length, 7, reason: 'each weekday has its own theme');
    });

    test('push-fold day sits in the Nash regime (≤20BB)', () {
      // 2026-10-17 is a Saturday.
      final sat = DailyChallengeService.configFor(DateTime(2026, 10, 17));
      expect(sat.day.weekday, DateTime.saturday);
      expect(sat.stackBB, lessThanOrEqualTo(20));
    });

    test('challenge number counts days from the epoch', () {
      expect(DailyChallengeService.challengeNumber(DateTime(2026, 10, 14)),
          1);
      expect(DailyChallengeService.challengeNumber(DateTime(2026, 10, 20)),
          7);
    });
  });

  group('DailyChallengeService determinism (the shared puzzle)', () {
    /// Plays [n] hero decisions with a fixed policy and returns a transcript.
    String transcript(DrillEngine engine, int n) {
      final lines = <String>[];
      var update = engine.startHand();
      var decisions = 0;
      var guard = 0;
      while (decisions < n && guard++ < 200) {
        for (final e in update.newEvents) {
          lines.add('${e.seat}:${e.action}:${e.toAmountBB ?? ''}');
        }
        if (update.awaitingHero) {
          lines.add('HERO ${engine.heroHandClass}@${engine.heroPosition}');
          decisions++;
          // Fixed policy: always fold (keeps the walk deterministic too).
          update = engine.applyHeroAction('fold');
        } else if (update.handComplete) {
          update = engine.startHand();
        }
      }
      return lines.join('\n');
    }

    test('same date → two engines produce identical hands and events', () {
      final config = DailyChallengeService.configFor(DateTime(2026, 10, 16));
      final a = transcript(DailyChallengeService.buildEngine(config), 5);
      final b = transcript(DailyChallengeService.buildEngine(config), 5);
      expect(a, b);
      expect(a, contains('HERO'));
    });

    test('different dates → different spot sequences', () {
      final mon = DailyChallengeService.configFor(DateTime(2026, 10, 19));
      final nextMon =
          DailyChallengeService.configFor(DateTime(2026, 10, 26));
      // Same weekday theme, different seed → different cards.
      expect(mon.theme, nextMon.theme);
      final a = transcript(DailyChallengeService.buildEngine(mon), 5);
      final b = transcript(DailyChallengeService.buildEngine(nextMon), 5);
      expect(a, isNot(b));
    });

    test('seats are generic bots only — never personal opponents', () {
      final seats = DailyChallengeService.seatsFor(
          DailyChallengeService.configFor(DateTime(2026, 10, 16)));
      expect(seats.where((s) => s.isHero).length, 1);
      for (final s in seats.where((s) => !s.isHero)) {
        expect(s.profile!.opponentId, isNull);
      }
    });
  });

  group('verdicts / score / share', () {
    test('grade → letter mapping', () {
      expect(DailyChallengeService.verdictLetter(DrillGrade.correct), 'c');
      expect(DailyChallengeService.verdictLetter(DrillGrade.ok), 'o');
      expect(DailyChallengeService.verdictLetter(DrillGrade.mistake), 'm');
    });

    test('score = accuracy %: correct=1, ok=0.5, mistake=0', () {
      expect(DailyChallengeService.scoreOf('c|c|c|c|c'), 100.0);
      expect(DailyChallengeService.scoreOf('c|c|o|m|m'), 50.0);
      expect(DailyChallengeService.scoreOf('ccomm'), 50.0); // legacy
      expect(DailyChallengeService.isPerfect('ccccc'), isTrue);
      expect(DailyChallengeService.isPerfect('ccocc'), isFalse);
    });

    test('share text: emoji row, score, streak — no hand spoilers', () {
      final text = DailyChallengeService.shareText(
          day: DateTime(2026, 10, 20), verdicts: 'c|c|o|m|c', streak: 4);
      expect(text, contains('Final Table Daily #7 · 70%'));
      expect(text, contains('🟢🟢🟡🔴🟢'));
      expect(text, contains('🔥4 day streak'));
      expect(text.contains(RegExp('[AKQJT2-9]{2}')), isFalse,
          reason: 'no hand classes leak into the share');
    });

    test('share text: authored hands get one row each, pot-weighted %', () {
      final text = DailyChallengeService.shareText(
          day: DateTime(2026, 10, 20),
          verdicts: 'ccom|cc',
          weights: const [2.5, 12, 19, 26, 2.5, 12],
          streak: 0);
      // hand 1 = 40.3%, hand 2 = 100% → day 70.2% (mean of hand accuracies)
      expect(text, contains('· 70.2%'));
      expect(text, contains('H1 🟢🟢🟡🔴'));
      expect(text, contains('H2 🟢🟢'));
    });

    test('share text: streak of 1 omits the flame', () {
      final text = DailyChallengeService.shareText(
          day: DateTime(2026, 10, 14), verdicts: 'c|c|c|c|c', streak: 1);
      expect(text, contains('100%'));
      expect(text.contains('🔥'), isFalse);
    });
  });

  group('DailyChallengeStore.computeStreaks', () {
    DailyChallengeResult day(String key, {String v = 'ccccc'}) =>
        DailyChallengeResult(dayKey: key, seed: 0, verdicts: v, spots: const []);

    test('empty history', () {
      final s =
          DailyChallengeStore.computeStreaks({}, DateTime(2026, 10, 20));
      expect(s.current, 0);
      expect(s.best, 0);
      expect(s.totalPlayed, 0);
    });

    test('consecutive days ending today', () {
      final s = DailyChallengeStore.computeStreaks({
        '2026-10-18': day('2026-10-18'),
        '2026-10-19': day('2026-10-19'),
        '2026-10-20': day('2026-10-20'),
      }, DateTime(2026, 10, 20));
      expect(s.current, 3);
      expect(s.best, 3);
    });

    test('today not yet played — streak stays alive via yesterday', () {
      final s = DailyChallengeStore.computeStreaks({
        '2026-10-18': day('2026-10-18'),
        '2026-10-19': day('2026-10-19'),
      }, DateTime(2026, 10, 20));
      expect(s.current, 2, reason: 'today is still pending, not missed');
    });

    test('a fully missed day breaks the current streak', () {
      final s = DailyChallengeStore.computeStreaks({
        '2026-10-16': day('2026-10-16'),
        '2026-10-17': day('2026-10-17'),
        '2026-10-19': day('2026-10-19'),
      }, DateTime(2026, 10, 20));
      expect(s.current, 1, reason: 'run restarted on the 19th');
      expect(s.best, 2, reason: 'the 16th–17th run is the best');
    });

    test('perfect days counted from verdict letters', () {
      final s = DailyChallengeStore.computeStreaks({
        '2026-10-18': day('2026-10-18', v: 'ccccc'),
        '2026-10-19': day('2026-10-19', v: 'ccomc'),
      }, DateTime(2026, 10, 19));
      expect(s.perfectDays, 1);
      expect(s.totalPlayed, 2);
    });

    test('month boundary runs are consecutive', () {
      final s = DailyChallengeStore.computeStreaks({
        '2026-10-31': day('2026-10-31'),
        '2026-11-01': day('2026-11-01'),
      }, DateTime(2026, 11, 1));
      expect(s.current, 2);
      expect(s.best, 2);
    });
  });

  group('DailyChallengeStore persistence (mock prefs)', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('save → resultFor → delete ("Reset today") → playable again',
        () async {
      SharedPreferences.setMockInitialValues({});
      final day = DateTime(2026, 10, 14);
      final result = DailyChallengeResult(
        dayKey: DailyChallengeStore.dayKey(day),
        seed: 20261014,
        verdicts: 'ccccc',
        spots: const [],
      );
      await DailyChallengeStore.save(result);
      expect((await DailyChallengeStore.resultFor(day))?.verdicts, 'ccccc');
      expect((await DailyChallengeStore.streaks(day)).current, 1);

      await DailyChallengeStore.delete(day);
      expect(await DailyChallengeStore.resultFor(day), isNull);
      expect((await DailyChallengeStore.streaks(day)).current, 0,
          reason: 'streaks recompute from the remaining days');
    });

    test('delete of an unplayed day is a no-op', () async {
      SharedPreferences.setMockInitialValues({});
      await DailyChallengeStore.delete(DateTime(2026, 10, 14));
      expect(await DailyChallengeStore.resultFor(DateTime(2026, 10, 14)),
          isNull);
    });
  });

  group('DailyChallengeResult round-trip', () {
    test('toJson/fromJson preserves verdicts and spot summaries', () {
      final result = DailyChallengeResult(
        dayKey: '2026-10-20',
        seed: 20261020,
        verdicts: 'ccomc',
        spots: const [
          DailySpotSummary(
              handClass: 'AKo',
              position: 'BTN',
              heroAction: 'raise',
              recommendedAction: 'raise',
              verdict: 'c'),
          DailySpotSummary(
              handClass: '72o',
              position: 'EP',
              heroAction: 'call',
              recommendedAction: 'fold',
              verdict: 'm'),
        ],
      );
      final back = DailyChallengeResult.fromJson(
          result.dayKey, result.toJson().cast<String, dynamic>());
      expect(back.verdicts, 'ccomc');
      expect(back.score, 70.0);
      expect(back.spots.length, 2);
      expect(back.spots[1].handClass, '72o');
      expect(back.spots[1].recommendedAction, 'fold');
    });
  });

  test('spot summary keeps hand index + street through toJson/fromJson', () {
    const spot = DailySpotSummary(
        handClass: '99',
        position: 'LJ',
        heroAction: 'raise',
        recommendedAction: 'raise',
        verdict: 'c',
        hand: 3,
        street: 'Turn');
    final back = DailySpotSummary.fromJson(spot.toJson());
    expect(back.hand, 3);
    expect(back.street, 'Turn');
    // RNG spots carry no street (the row then shows the holding).
    expect(DailySpotSummary.fromJson(const {'g': 'c'}).street, '');
  });
}
