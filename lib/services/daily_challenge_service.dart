import 'dart:math';

import '../models/drill_models.dart';
import 'daily_scoring.dart';
import 'drill_engine.dart';

/// DAILY CHALLENGE — the chess.com-style daily ritual: every calendar day,
/// one short set of preflop decisions ([spotsPerDay]) that is IDENTICAL for
/// every user (the drill engine is seeded from the date), graded move-by-move
/// by the coach. Completing days builds a streak.
///
/// This layer is pure: date → config/seed/engine, verdict mapping, share
/// text. Persistence lives in `daily_challenge_store.dart`; presentation in
/// `daily_challenge_screen.dart` + the challenge mode of DrillTableScreen.
///
/// Determinism contract: everything the challenge shows must derive from
/// `Random(seedFor(day))` and generic bots. Never seat the user's real
/// opponents here — that would both break "same challenge for everyone" and
/// leak personal reads into a shared puzzle.
class DailyChallengeConfig {
  final DateTime day; // date-only (local)
  final int seed;
  final String theme; // e.g. 'Short Stack Friday'
  final String formatLabel; // e.g. '25BB · 8-max · MTT'
  final double stackBB;
  final bool anteMode;
  final int players;

  const DailyChallengeConfig({
    required this.day,
    required this.seed,
    required this.theme,
    required this.formatLabel,
    required this.stackBB,
    required this.anteMode,
    required this.players,
  });
}

class DailyChallengeService {
  DailyChallengeService._();

  /// One challenge = this many graded hero decisions.
  static const int spotsPerDay = 5;

  /// Challenge #1 — the day the feature ships. Keeps the shareable
  /// "Daily #N" stable forever; never change after release.
  static final DateTime epoch = DateTime(2026, 10, 14);

  /// Deterministic bot names so the daily table feels like a lineup, not
  /// "Bot/Bot/Bot" — same for every user (part of the shared puzzle).
  static const List<String> _botNames = [
    'Vik', 'Dana', 'Moss', 'Lena', 'Rudy', 'Kata', 'Bo', 'Ira',
  ];

  /// Debug/admin day shift (in days). 0 = real today. Lets a tester jump
  /// to a future challenge day without changing the device clock. Set by
  /// the admin "Challenge Day" tool; in-memory, not persisted.
  static int debugDayOffset = 0;

  /// The challenge "today" — real now plus [debugDayOffset]. EVERY date
  /// read in the challenge flow goes through this, so the override covers
  /// the intro, the home card, the lines lookup, streaks, and share.
  static DateTime today() {
    // Calendar arithmetic (not Duration) so a DST change can't shift the
    // wall-clock time or the date.
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day + debugDayOffset, n.hour, n.minute,
        n.second, n.millisecond, n.microsecond);
  }

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static int seedFor(DateTime day) =>
      day.year * 10000 + day.month * 100 + day.day;

  /// Days since [epoch] + 1 → the shareable "Daily #N".
  static int challengeNumber(DateTime day) =>
      DateTime.utc(day.year, day.month, day.day)
          .difference(DateTime.utc(epoch.year, epoch.month, epoch.day))
          .inDays +
      1;

  /// Weekday-themed formats. Depth drives the grader's regime too:
  /// ≤20BB days grade on Nash push-fold, deep days on the open charts.
  static DailyChallengeConfig configFor(DateTime date) {
    final day = dateOnly(date);
    final (theme, stackBB, anteMode, players) = switch (day.weekday) {
      DateTime.monday => ('Deep Stack Monday', 100.0, false, 6),
      DateTime.tuesday => ('Full Ring Tuesday', 100.0, false, 9),
      DateTime.wednesday => ('Mid-Stack Wednesday', 40.0, true, 8),
      DateTime.thursday => ('Six-Max Thursday', 60.0, false, 6),
      DateTime.friday => ('Short Stack Friday', 25.0, true, 8),
      DateTime.saturday => ('Push-Fold Saturday', 15.0, true, 9),
      _ => ('Sunday Deep', 100.0, false, 9),
    };
    return DailyChallengeConfig(
      day: day,
      seed: seedFor(day),
      theme: theme,
      formatLabel:
          '${stackBB.round()}BB · $players-max · ${anteMode ? 'MTT' : 'cash'}',
      stackBB: stackBB,
      anteMode: anteMode,
      players: players,
    );
  }

  /// Hero on seat 1 + generic-prior bots with deterministic names.
  static List<DrillSeat> seatsFor(DailyChallengeConfig config) {
    final prior = DrillVillainProfile.prior(anteMode: config.anteMode);
    return [
      const DrillSeat(seatNumber: 1, isHero: true),
      for (var i = 0; i < config.players - 1; i++)
        DrillSeat(
          seatNumber: i + 2,
          isHero: false,
          profile: DrillVillainProfile(
            opponentId: null,
            name: _botNames[i % _botNames.length],
            handsObserved: prior.handsObserved,
            threeBet: prior.threeBet,
            fold3bet: prior.fold3bet,
            aggression: prior.aggression,
            steal: prior.steal,
            cbet: prior.cbet,
            blindDefend: prior.blindDefend,
            showdown: prior.showdown,
            checkRaiseFlop: prior.checkRaiseFlop,
            archetype: prior.archetype,
          ),
        ),
    ];
  }

  /// Legacy single-engine builder. Kept for compatibility, but the daily
  /// challenge now uses [buildSpotEngine] per spot so the hero's action in
  /// one spot can NEVER change another spot (the single-engine version
  /// shared one RNG across villains AND the next deal, so play drifted the
  /// later spots — bug 2026-10-14).
  static DrillEngine buildEngine(DailyChallengeConfig config) => DrillEngine(
        seats: seatsFor(config),
        stackBB: config.stackBB,
        anteMode: config.anteMode,
        rng: Random(config.seed),
      );

  /// Per-spot seed: the day seed mixed with the spot index. Independent
  /// streams → spot N is identical for everyone regardless of how they
  /// played spots 0..N-1.
  static int spotSeed(DailyChallengeConfig config, int spotIndex) =>
      config.seed * 100 + spotIndex;

  /// A fresh engine for one spot, already advanced to the hero's decision
  /// point. Each spot is a self-contained one-decision hand on its own
  /// seed; if a seed deals a walk (hero gets no decision), the seed is
  /// bumped deterministically until the hero must act, so every client
  /// lands on the same spot. Returns (engine, update-at-hero-turn).
  static (DrillEngine, DrillHandUpdate) buildSpotEngine(
      DailyChallengeConfig config, int spotIndex) {
    final base = spotSeed(config, spotIndex);
    for (var bump = 0; bump < 50; bump++) {
      final engine = DrillEngine(
        seats: seatsFor(config),
        stackBB: config.stackBB,
        anteMode: config.anteMode,
        rng: Random(base + bump),
      );
      final update = engine.startHand();
      if (update.awaitingHero) return (engine, update);
      // Walk (everyone folded to the BB) — no decision; try the next seed.
    }
    // Extremely unlikely fallback: return whatever the base seed gave.
    final engine = DrillEngine(
      seats: seatsFor(config),
      stackBB: config.stackBB,
      anteMode: config.anteMode,
      rng: Random(base),
    );
    return (engine, engine.startHand());
  }

  // ── Verdicts ──────────────────────────────────────────────────────────

  /// Chess.com-style verdict letters stored per decision:
  /// 'c' correct ("Best"), 'o' ok ("Good"), 'm' mistake ("Leak").
  static String verdictLetter(DrillGrade g) => switch (g) {
        DrillGrade.correct => 'c',
        DrillGrade.ok => 'o',
        DrillGrade.mistake => 'm',
      };

  /// Day score = accuracy % (0..100) — see [DailyScoring].
  static double scoreOf(String verdicts, [List<double>? weights]) =>
      DailyScoring.accuracy(verdicts, weights);

  static bool isPerfect(String verdicts) => DailyScoring.isPerfect(verdicts);

  /// Wordle-style share text — verdicts as emoji, no hand details
  /// (spoiler-safe: everyone plays the same spots). One-decision hands (RNG
  /// days) share a single row; authored hands get one row each.
  static String shareText({
    required DateTime day,
    required String verdicts,
    List<double>? weights,
    required int streak,
  }) {
    String emoji(String letters) => letters
        .split('')
        .map((v) => switch (v) { 'c' => '🟢', 'o' => '🟡', _ => '🔴' })
        .join();
    final hands = DailyScoring.handsOf(verdicts);
    final multi = hands.any((h) => h.length > 1);
    final rows = multi
        ? [for (var i = 0; i < hands.length; i++) 'H${i + 1} ${emoji(hands[i])}']
        : [emoji(hands.join())];
    final pct = DailyScoring.formatPct(scoreOf(verdicts, weights));
    return 'Final Table Daily #${challengeNumber(day)} · $pct%\n'
        '${rows.join('\n')}'
        '${streak > 1 ? '\n🔥$streak day streak' : ''}';
  }
}
