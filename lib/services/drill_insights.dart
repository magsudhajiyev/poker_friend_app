import '../models/drill_models.dart';

/// Varies the drill feedback so repeated spots teach DIFFERENT things
/// instead of repeating one template. Two mechanisms:
///
/// 1. Verdict leads rotate between phrasings per grade.
/// 2. When there is no opponent read (the boilerplate case), the reason is
///    an INSIGHT selected from pools tagged by hand type + action — blocker
///    logic for suited aces, set-mining math for small pairs, domination
///    risk for offsuit broadways, range-composition context, etc.
///
/// Rotation is deterministic: a session counter plus a hand-class hash pick
/// the variant, so the same spot seen twice in a session gets a different
/// line, while unit tests stay reproducible via [resetRotation].
class DrillInsights {
  DrillInsights._();

  /// Per-spot counters: the same salt cycles through its pool in order, so a
  /// repeated identical spot is GUARANTEED a different line until the pool is
  /// exhausted. The hash offset varies which variant each spot starts on.
  static final Map<String, int> _spotSeq = {};

  /// Test hook: makes variant selection reproducible.
  static void resetRotation() => _spotSeq.clear();

  static T _pick<T>(List<T> pool, String salt) {
    final n = _spotSeq.update(salt, (v) => v + 1, ifAbsent: () => 0);
    return pool[(salt.hashCode.abs() + n) % pool.length];
  }

  // ── Verdict leads ───────────────────────────────────────────────────

  static String lead(DrillGrade grade, String action) {
    final verb = _actionWord(action);
    switch (grade) {
      case DrillGrade.correct:
        return _pick([
          '$verb is the exploitative play.',
          'Correct — $verb is exactly right here.',
          'Well played: $verb is the move against this lineup.',
          '$verb — right on the money.',
        ], action);
      case DrillGrade.ok:
        return _pick([
          'Close — ${verb.toLowerCase()} is slightly better against this lineup.',
          'Defensible, but ${verb.toLowerCase()} edges it out here.',
          'A borderline spot — ${verb.toLowerCase()} is the finer choice.',
        ], action);
      case DrillGrade.mistake:
        return _pick([
          '$verb was the exploitative play.',
          'This one should be ${verb.toLowerCase().replaceFirst('ing', '')}ed — here\'s why.',
          '$verb was the better line.',
        ], action);
    }
  }

  // ── Hand-type tags ──────────────────────────────────────────────────

  static const _order = 'AKQJT98765432';

  static List<String> tagsFor(String hc) {
    final tags = <String>[];
    final isPair = hc.length == 2;
    final suited = hc.endsWith('s');
    if (isPair) {
      final r = _order.indexOf(hc[0]);
      tags.add(r <= 3 ? 'bigPair' : (r <= 7 ? 'midPair' : 'smallPair'));
    } else {
      final hi = _order.indexOf(hc[0]);
      final lo = _order.indexOf(hc[1]);
      final gap = lo - hi;
      if (hc[0] == 'A') tags.add(suited ? 'suitedAce' : 'offsuitAce');
      if (hi <= 4 && lo <= 4) tags.add(suited ? 'suitedBroadway' : 'offsuitBroadway');
      if (suited && gap == 1) tags.add('suitedConnector');
      if (suited && gap == 2) tags.add('suitedGapper');
      if (!suited && hi > 4) tags.add('offsuitJunky');
    }
    return tags.isEmpty ? ['generic'] : tags;
  }

  // ── Insight pools ───────────────────────────────────────────────────
  // Placeholders: {hand}, {pos}, {rangePct}

  static const Map<String, Map<String, List<String>>> _pools = {
    // tag → action → insights
    'suitedAce': {
      'raise': [
        '{hand} makes a great aggressive hand: the ace blocks the strongest '
            'hands they can continue with, and the suit adds nut-flush equity.',
        'Suited aces like {hand} are premier bluff-raisers — when called you '
            'still have live cards and the nut-flush draw to lean on.',
        'The blocker is the point: holding an ace makes it measurably less '
            'likely they hold AA/AK, so {hand} raises where the offsuit '
            'version folds.',
      ],
      'fold': [
        'Even suited, the weak kicker on {hand} is trouble here — flopping '
            'the ace and losing to a better kicker is the expensive outcome.',
      ],
      'call': [
        '{hand} plays fine as a call: nut-flush potential plus a blocker, '
            'without bloating the pot out of position.',
      ],
    },
    'smallPair': {
      'raise': [
        'Small pairs like {hand} open profitably from every seat — they '
            'flop a set one time in eight, and sets get paid.',
        '{hand} is an open, not a limp: taking initiative wins the pots '
            'where nobody connects, and the set-mining upside stays intact.',
      ],
      'fold': [
        'Set-mining math: {hand} flops a set ~12% of the time, so calling '
            'here needs ~15:1 implied odds you aren\'t getting.',
        '{hand} without the right price is just two low cards — the times '
            'you miss the set (7 of 8) you can\'t continue.',
      ],
      'call': [
        '{hand} calls for set value — the stack depths give you the '
            'implied odds to go mining.',
      ],
    },
    'midPair': {
      'raise': [
        '{hand} is comfortably ahead of the range you\'re up against — '
            'play it for value.',
      ],
      'call': [
        '{hand} is strong enough to continue but plays awkwardly as a '
            'raise — flatting keeps their worse hands in.',
      ],
      'fold': [
        '{hand} looks pretty but shrivels against this range — you\'re '
            'either flipping or crushed.',
      ],
    },
    'bigPair': {
      'raise': [
        '{hand} is the top of your range — build the pot now.',
        'With {hand}, the only mistake is playing it slow.',
      ],
      'call': [
        '{hand} traps well here — the raise-first line folds out everything '
            'you beat.',
      ],
    },
    'suitedConnector': {
      'raise': [
        'Suited connectors like {hand} make ideal range-fillers: they hit '
            'boards your premiums miss and keep your raises unpredictable.',
        '{hand} plays beautifully post-flop — straights, flushes, and '
            'disguised two-pairs nobody sees coming.',
      ],
      'call': [
        '{hand} wants a multiway pot and a cheap flop — exactly what '
            'calling gets you.',
      ],
      'fold': [
        'Pretty but unprofitable: {hand} needs position and deep stacks to '
            'pay off, and this spot offers neither.',
      ],
    },
    'offsuitBroadway': {
      'fold': [
        'Offsuit broadways like {hand} are domination traps — when you hit '
            'top pair, the hands that pay you off often have you outkicked.',
        '{hand} is the classic reverse-implied-odds hand: it wins small '
            'pots and loses big ones.',
      ],
      'raise': [
        '{hand} plays fine as the aggressor — top-pair hands want initiative '
            'so worse kickers pay you off.',
      ],
      'call': [
        '{hand} can peel one here, but proceed carefully — kicker trouble '
            'is this hand\'s whole story.',
      ],
    },
    'offsuitAce': {
      'fold': [
        '{hand} offsuit is a fold where the suited version plays — without '
            'the flush half of its equity, the weak kicker is all that\'s left.',
        'The suit IS the decision: A-x suited 3-bets and flats in spots '
            'where {hand} just folds.',
      ],
      'raise': [
        '{hand} works as aggression here — the ace blocker does the heavy '
            'lifting even without the suit.',
      ],
    },
    'generic': {
      'raise': [
        'From {pos} you get to play {rangePct} in this spot — {hand} makes '
            'the cut, so play it with conviction.',
        'GTO plays {rangePct} here from {pos} — {hand} qualifies, so take '
            'the aggressive line.',
      ],
      'fold': [
        'Only {rangePct} continue here, and {hand} doesn\'t make the cut — '
            'folding the bottom keeps the rest of your hands profitable.',
        'Discipline spot: {hand} is below the cutoff, and the hands just '
            'above it are the ones that make money.',
        'Every range has a floor — {hand} is under it from {pos}.',
      ],
      'call': [
        '{hand} continues but doesn\'t re-raise: strong enough to see a '
            'flop, not strong enough to build a big pot yet.',
        'Flat-call territory: {hand} keeps the pot controlled and their '
            'bluffs alive.',
      ],
      'check': [
        'Free flops with {hand} are pure profit — take them.',
        '{hand} isn\'t worth building a pot with, but never fold what you '
            'can check.',
      ],
    },
  };

  /// Renders a range share as natural language, keeping the exact number
  /// for correctness. Player-facing copy uses this instead of raw
  /// "top X%" / "widen +3%" range arithmetic.
  static String naturalShare(double pct) {
    final exact = '(${pct.toStringAsFixed(0)}%)';
    if (pct < 6) return 'only your very strongest hands $exact';
    if (pct < 13) return 'about one hand in ten $exact';
    if (pct < 21) return 'about one hand in six $exact';
    if (pct < 29) return 'about a quarter of hands $exact';
    if (pct < 40) return 'about a third of hands $exact';
    if (pct < 55) return 'about half of all hands $exact';
    if (pct < 72) return 'about two-thirds of hands $exact';
    return 'almost everything playable $exact';
  }

  /// An insight line for spots WITHOUT an opponent read. Rotates between
  /// hand-type and generic pools so repeated spots teach different angles.
  static String insight(DrillDecisionContext ctx, String action,
      double rangePct, List<String> trace) {
    final candidates = <String>[];
    for (final tag in tagsFor(ctx.handClass)) {
      candidates.addAll(_pools[tag]?[action] ?? const []);
    }
    candidates.addAll(_pools['generic']![action] ?? const []);
    if (candidates.isEmpty) {
      return 'In this spot GTO plays ${naturalShare(rangePct)}.';
    }
    final line = _pick(candidates, '${ctx.handClass}|$action');
    trace.add('insight: variant ${candidates.indexOf(line) + 1}/'
        '${candidates.length} (tags: ${tagsFor(ctx.handClass).join(',')})');
    return line
        .replaceAll('{hand}', ctx.handClass)
        .replaceAll('{pos}', _posName(ctx.positionGroup))
        .replaceAll('{rangePct}', naturalShare(rangePct));
  }

  static String _posName(String group) {
    switch (group) {
      case 'EP':
        return 'early position';
      case 'MP':
        return 'middle position';
      case 'CO':
        return 'the cutoff';
      case 'BTN':
        return 'the button';
      case 'SB':
        return 'the small blind';
      case 'BB':
        return 'the big blind';
      default:
        return group;
    }
  }

  static String _actionWord(String action) {
    switch (action) {
      case 'raise':
        return 'Raising';
      case 'call':
        return 'Calling';
      case 'check':
        return 'Checking';
      case 'fold':
        return 'Folding';
      default:
        return action;
    }
  }
}
