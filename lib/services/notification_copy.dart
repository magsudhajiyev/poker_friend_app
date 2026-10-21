/// Coach-voiced engagement notification copy — PURE (no IO, no Flutter).
///
/// Every engagement push maps to a "user moment" (see
/// docs/features/engagement-notifications-plan.md §3) and speaks in the
/// user's chosen coach persona, with a neutral fallback. Each (type × voice)
/// has 2–3 variants — the Duolingo variety lever: rotating variants fights
/// the novelty-decay effect without inventing new reasons to ping.
///
/// Rules encoded here:
/// - `reEngage` is ALWAYS neutral/empathetic — a lapsed user gets no coach
///   sass, no shame (store-trust guardrail from the research doc).
/// - Copy only names REAL things (a streak that dies tonight, a rank that
///   was lost, five fresh spots). No manufactured urgency.
/// - Coach ids mirror `coach_persona.dart` ('grinder' | 'professor' |
///   'nova'); anything else resolves to the neutral voice.
library;

/// The engagement "user moments", in priority order (1 = highest). The wire
/// id doubles as the `notification_events.type` value and the local
/// notification payload prefix.
enum EngagementNotifType {
  dcStreakRisk('dc_streak_risk'),
  lbMilestone('lb_milestone'),
  lbOvertaken('lb_overtaken'),
  dcTodayReady('dc_today_ready'),
  reEngage('re_engage');

  final String id;
  const EngagementNotifType(this.id);

  static EngagementNotifType? fromId(String? id) {
    for (final t in values) {
      if (t.id == id) return t;
    }
    return null;
  }
}

/// One rendered notification: what goes in the tray.
class NotifCopy {
  final String title;
  final String body;
  const NotifCopy(this.title, this.body);
}

class NotificationCopy {
  NotificationCopy._();

  static const neutralVoice = 'neutral';

  /// Copy for [type] in [coachId]'s voice. [variant] rotates the pool
  /// (any int — taken modulo the pool size), so callers can pass a day
  /// number or a counter and never repeat two days in a row.
  ///
  /// [streak] fills streak phrasing (dcStreakRisk / lbMilestone);
  /// [rank] fills rank phrasing (lbOvertaken / lbMilestone). Both are
  /// optional — templates degrade to generic wording when absent.
  static NotifCopy copyFor(
    EngagementNotifType type,
    String? coachId,
    int variant, {
    int? streak,
    int? rank,
  }) {
    // Lapsed users always get the gentle neutral voice.
    final voice = (type == EngagementNotifType.reEngage)
        ? neutralVoice
        : _normalizeVoice(coachId);
    final pool = _catalog[type]![voice] ?? _catalog[type]![neutralVoice]!;
    final t = pool[variant.abs() % pool.length];
    return NotifCopy(
      _fill(t.title, streak: streak, rank: rank),
      _fill(t.body, streak: streak, rank: rank),
    );
  }

  static String _normalizeVoice(String? coachId) => switch (coachId) {
        'grinder' || 'professor' || 'nova' => coachId!,
        _ => neutralVoice,
      };

  /// Placeholder fill. `{streakPhrase}` → "12-day streak" or "streak";
  /// `{rankPhrase}` → "#4" or "your spot"; `{streak}` → the bare number
  /// (only used in templates that also work without it via streakPhrase).
  static String _fill(String s, {int? streak, int? rank}) => s
      .replaceAll(
          '{streakPhrase}', streak != null ? '$streak-day streak' : 'streak')
      .replaceAll('{rankPhrase}', rank != null ? '#$rank' : 'your spot')
      .replaceAll('{streak}', streak?.toString() ?? '')
      .replaceAll('{rank}', rank?.toString() ?? '');

  // ── The catalog ─────────────────────────────────────────────────────
  // type → voice → variants. Keep every line SHORT (tray truncates ~2
  // lines) and matching the persona voice in coach_persona.dart.

  static const Map<EngagementNotifType, Map<String, List<NotifCopy>>>
      _catalog = {
    EngagementNotifType.dcStreakRisk: {
      'grinder': [
        NotifCopy('Duke here. Clock\'s ticking.',
            'Your {streakPhrase} dies at midnight, kid. Five hands. Move.'),
        NotifCopy('Don\'t make me come find you.',
            '{streakPhrase} on the line tonight. The old crew never missed a day.'),
        NotifCopy('Streak\'s about to bust.',
            'Forty years at the felt and I\'ve seen it all — don\'t let a {streakPhrase} die soft. Five hands.'),
      ],
      'professor': [
        NotifCopy('Prof. Vega. A deadline approaches.',
            'Your {streakPhrase} expires at midnight. Five decisions preserve it. The EV is obvious.'),
        NotifCopy('Deviation imminent.',
            'The data shows a {streakPhrase} ending tonight unless you act. Correct the line.'),
        NotifCopy('Equilibrium at risk.',
            'A {streakPhrase} is an asset. Letting it expire is an EV leak. Five hands remain.'),
      ],
      'nova': [
        NotifCopy('🔥 Your streak needs you!',
            'Don\'t let that {streakPhrase} go out — five quick hands and it lives!'),
        NotifCopy('Streak rescue time!',
            '{streakPhrase} on the line and I KNOW you\'ve got five hands in you. Let\'s go!'),
        NotifCopy('Midnight is coming!',
            'Protect the {streakPhrase}! Five spots, two minutes, hero status.'),
      ],
      'neutral': [
        NotifCopy('Your streak ends at midnight',
            'Five quick hands keep your {streakPhrase} alive.'),
        NotifCopy('Streak at risk',
            'Play today\'s five decisions before midnight to keep your {streakPhrase}.'),
      ],
    },
    EngagementNotifType.lbMilestone: {
      'grinder': [
        NotifCopy('Now that\'s poker.',
            'New personal best — a {streakPhrase}. The old crew would tip their hats.'),
        NotifCopy('Duke\'s impressed. Rare.',
            'You cracked the leaderboard. Keep your head down and keep playing.'),
      ],
      'professor': [
        NotifCopy('Statistically notable.',
            'A new best: {streakPhrase}. The trend line is favorable. Maintain it.'),
        NotifCopy('Milestone recorded.',
            'You have entered the rankings. Variance rewards the disciplined.'),
      ],
      'nova': [
        NotifCopy('🏆 NEW RECORD!',
            'A {streakPhrase} — that\'s your best EVER! Keep it rolling!'),
        NotifCopy('You\'re on the board!',
            'Leaderboard status: ACHIEVED. Tomorrow we climb higher!'),
      ],
      'neutral': [
        NotifCopy('New personal best',
            'You just set a new record: {streakPhrase}. Nice work.'),
        NotifCopy('Leaderboard milestone',
            'You\'re officially on the global leaderboard.'),
      ],
    },
    EngagementNotifType.lbOvertaken: {
      'grinder': [
        NotifCopy('Someone took your seat, kid.',
            'You slipped to {rankPhrase} on the board. In my day we took that personal.'),
        NotifCopy('Duke here. Bad news.',
            'You got passed on the leaderboard. Five hands gets it back.'),
      ],
      'professor': [
        NotifCopy('Ranking update: unfavorable.',
            'You have slipped to {rankPhrase}. The equilibrium is recoverable — five hands.'),
        NotifCopy('A rival advances.',
            'Your leaderboard position has been taken. The correct response is obvious.'),
      ],
      'nova': [
        NotifCopy('😱 You got passed!',
            'Someone took {rankPhrase} from you! Five hands and we take it BACK!'),
        NotifCopy('Leaderboard alert!',
            'You slipped to {rankPhrase} — today\'s five are your comeback!'),
      ],
      'neutral': [
        NotifCopy('You\'ve been overtaken',
            'You slipped to {rankPhrase} on the leaderboard. Today\'s challenge can win it back.'),
      ],
    },
    EngagementNotifType.dcTodayReady: {
      'grinder': [
        NotifCopy('Fresh five on the felt.',
            'Today\'s hands are dealt, kid. Show me you can still fold.'),
        NotifCopy('Duke\'s waiting.',
            'Five new spots. Same table, no excuses.'),
        NotifCopy('Cards are up.',
            'Today\'s challenge is live. Don\'t keep an old man waiting.'),
      ],
      'professor': [
        NotifCopy('Today\'s problem set is ready.',
            'Five fresh decisions await analysis. We proceed by equilibrium.'),
        NotifCopy('New data available.',
            'Today\'s five spots are live. Deviations will be noted.'),
      ],
      'nova': [
        NotifCopy('✨ Today\'s five are LIVE!',
            'Fresh challenge just dropped — let\'s make it a perfect day!'),
        NotifCopy('Challenge time!',
            'Five new spots, full focus — bring your A-game!'),
        NotifCopy('Your daily five await!',
            'Same spots as everyone, but YOUR run. Make it count!'),
      ],
      'neutral': [
        NotifCopy('Today\'s challenge is ready',
            'Five fresh decisions are waiting. Same spots as every player today.'),
        NotifCopy('New daily challenge',
            'Today\'s five spots just dropped. Take your shot.'),
      ],
    },
    EngagementNotifType.reEngage: {
      // ALWAYS neutral — empathetic, zero pressure, zero shame.
      'neutral': [
        NotifCopy('Your coaches are ready when you are',
            'Pick up where you left off — five quick decisions, no pressure.'),
        NotifCopy('The table\'s still here',
            'A fresh daily challenge is waiting whenever you feel like it.'),
        NotifCopy('No rush — just five hands',
            'Two minutes, five decisions, and your coach talks you through every one.'),
      ],
    },
  };

  /// Pool size for (type, voice) — lets callers rotate variants without
  /// repeating (e.g. pass the challenge day number as [variant]).
  static int variantCount(EngagementNotifType type, String? coachId) {
    final voice = (type == EngagementNotifType.reEngage)
        ? neutralVoice
        : _normalizeVoice(coachId);
    return (_catalog[type]![voice] ?? _catalog[type]![neutralVoice]!).length;
  }
}
