import 'board_texture.dart';
import 'flop_strength.dart';
import 'leak_extractor.dart';

/// LEAK DETECTOR (phase 2) — frequency detectors + coach layer.
///
/// Design rules (docs/features/leak-detector.md):
/// - A leak is a deviation from a healthy BAND, not a raw number. Bands are
///   documented conventional-wisdom priors — see the doc for each band's
///   rationale and the plan to replace them with chart-derived baselines.
/// - Every detector has minimum samples; below them we say "not enough
///   data", never a verdict. Emerging < confirmed by sample size.
/// - Coach voice: every leak explains meaning (what we saw), cost (why it
///   matters), and fix (what to do about it) — plus example hands from the
///   player's own history, because being shown YOUR hands is what makes a
///   report feel like coaching instead of accusation.
enum LeakVerdict { insufficientData, healthy, emerging, confirmed }

/// One sub-population of a finding (e.g. flop folds on wet boards only).
class LeakSlice {
  final String label;
  final double value;
  final int sampleCount;

  /// True when this slice itself sits outside the parent's band with a
  /// workable sample — it is then also emitted as its own child finding.
  final bool flagged;
  const LeakSlice(this.label, this.value, this.sampleCount,
      {this.flagged = false});
}

/// One real hand of the player's where the leaky action happened.
class LeakExample {
  final String ref; // '{sessionId}:{handNumber}'
  final String? posGroup;
  final String? textureLabel;
  final String? holeCards;

  /// Hero flop strength label ('air', 'top pair+', ...), when computable.
  final String? strengthLabel;
  const LeakExample(this.ref,
      {this.posGroup, this.textureLabel, this.holeCards, this.strengthLabel});

  String get handNumber => ref.split(':').last;
}

/// BB-normalized net for one position (money view). Totals, not rates —
/// impact ranking must weight frequency, and per-hand rates on tiny n
/// mislead.
class PositionNet {
  final String pos; // EP/MP/CO/BTN/SB/BB
  final double netBBTotal;
  final int hands;
  const PositionNet(this.pos, this.netBBTotal, this.hands);

  double get netBBPerHand => hands == 0 ? 0 : netBBTotal / hands;
}

/// One drill-targetable losing spot (position × villain-position or
/// position × stack-depth), ranked by TOTAL BB lost.
class SpotNet {
  final String label;
  final double netBBTotal;
  final int hands;

  /// Nearest drill stack preset for "practice this spot".
  final double presetStackBB;
  const SpotNet(this.label, this.netBBTotal, this.hands, this.presetStackBB);
}

class LeakFinding {
  final String id;
  final String title;
  final double value;
  final double bandLow;
  final double bandHigh;
  final int sampleCount;
  final int minSample;
  final LeakVerdict verdict;
  final bool aboveBand;

  /// Coach copy. [meaning]: what the number says about the player's game.
  /// [cost]: how opponents exploit it. [fix]: the concrete adjustment,
  /// referencing app features (drills, range grid) where one applies.
  final String meaning;
  final String cost;
  final String fix;

  /// Optional drill pointer ("Practice: Training Drills → …"). Kept apart
  /// from [fix] so the UI shows it only when the drills feature is on.
  final String practiceHint;

  /// Up to [maxExamples] of the player's own hands where the leaky action
  /// happened, with display context for the report UI.
  final List<LeakExample> examples;

  /// Optional sub-population breakdown (e.g. by board texture), shown even
  /// when the top-line number is healthy — a healthy average can hide a
  /// texture-specific leak.
  final List<LeakSlice> slices;

  static const maxExamples = 6;

  const LeakFinding({
    required this.id,
    required this.title,
    required this.value,
    required this.bandLow,
    required this.bandHigh,
    required this.sampleCount,
    required this.minSample,
    required this.verdict,
    required this.aboveBand,
    required this.meaning,
    required this.cost,
    required this.fix,
    this.practiceHint = '',
    this.examples = const [],
    this.slices = const [],
  });

  bool get isLeak =>
      verdict == LeakVerdict.emerging || verdict == LeakVerdict.confirmed;

  double get severity {
    if (!isLeak) return 0;
    final dist = aboveBand ? value - bandHigh : bandLow - value;
    return (dist / 0.25).clamp(0.0, 1.0);
  }
}

class LeakReport {
  final List<LeakFinding> findings;
  final int handsAnalyzed;

  /// Templated coach paragraph: top leak + strengths, plain language.
  final String coachSummary;

  /// Money view: per-position BB nets (fixed EP→BB order) and the
  /// worst drill-targetable spots. High-variance — the UI must present
  /// these as directional, never as verdicts.
  final List<PositionNet> positionNets;
  final List<SpotNet> worstSpots;

  const LeakReport({
    required this.findings,
    required this.handsAnalyzed,
    this.coachSummary = '',
    this.positionNets = const [],
    this.worstSpots = const [],
  });

  List<LeakFinding> get leaks =>
      findings.where((f) => f.isLeak).toList()
        ..sort((a, b) => b.severity.compareTo(a.severity));
  List<LeakFinding> get healthy =>
      findings.where((f) => f.verdict == LeakVerdict.healthy).toList();
  List<LeakFinding> get insufficient => findings
      .where((f) => f.verdict == LeakVerdict.insufficientData)
      .toList();
}

/// Internal: everything one frequency detector needs.
class _Detector {
  final String id;
  final String title;
  final bool Function(LeakHandFacts) opportunity;
  final bool Function(LeakHandFacts) hit;
  final double bandLow;
  final double bandHigh;
  final int minSample;
  final int confirmedSample;
  final String meaningHigh, costHigh, fixHigh;
  final String meaningLow, costLow, fixLow;
  final String practiceHigh, practiceLow;
  /// Slice dimensions: 'texture' and/or 'position'.
  final List<String> sliceBy;

  const _Detector({
    required this.id,
    required this.title,
    required this.opportunity,
    required this.hit,
    required this.bandLow,
    required this.bandHigh,
    required this.minSample,
    required this.confirmedSample,
    this.meaningHigh = '',
    this.costHigh = '',
    this.fixHigh = '',
    this.meaningLow = '',
    this.costLow = '',
    this.fixLow = '',
    this.practiceHigh = '',
    this.practiceLow = '',
    this.sliceBy = const [],
  });
}

class LeakEngine {
  LeakEngine._();

  /// Minimum sample for a SLICE to get its own verdict (child finding).
  static const sliceMinSample = 10;

  static String? _sliceKey(LeakHandFacts f, String dimension) {
    switch (dimension) {
      case 'texture':
        return f.flopTexture == null
            ? null
            : '${BoardTextureClassifier.label(f.flopTexture!)} boards';
      case 'position':
        return f.posGroup;
      default:
        return null;
    }
  }

  static List<_Detector> _detectors() => [
        _Detector(
          id: 'river_overfold',
          title: 'Folding vs river bets',
          opportunity: (f) => f.riverFacingResponse != null,
          hit: (f) => f.riverFacingResponse == 'fold',
          bandLow: 0.30,
          bandHigh: 0.62,
          minSample: 12,
          confirmedSample: 30,
          meaningHigh:
              'When the last bet goes in on the river, you release your '
              'hand most of the time.',
          costHigh:
              'The river is where bluffs get paid — anyone who notices can '
              'bet any two cards at you and show a profit.',
          fixHigh:
              'Before folding a river, ask what worse hands could be '
              'betting. Pick your best bluff-catchers — top pairs, strong '
              'seconds — and defend with them, especially against players '
              'who bet every river.',
          meaningLow: 'You call river bets with almost everything.',
          costLow:
              'River bets in live games are value-heavy — automatic calls '
              'pay off exactly the hands that beat you.',
          fixLow:
              'Make river calls a decision, not a reflex: name the worse '
              'hands you beat before the chips go in.',
          sliceBy: const ['texture', 'position'],
        ),
        _Detector(
          id: 'turn_overfold',
          title: 'Folding vs turn bets',
          opportunity: (f) => f.turnFacingResponse != null,
          hit: (f) => f.turnFacingResponse == 'fold',
          bandLow: 0.25,
          bandHigh: 0.58,
          minSample: 15,
          confirmedSample: 35,
          meaningHigh: 'Second barrels move you off most of your range.',
          costHigh:
              'Opponents get to c-bet flop, barrel turn, and pick up the '
              'pot cheaply whenever you miss — which is most of the time.',
          fixHigh:
              'Continue more on turns with draws, pairs and good overcards. '
              'If a hand was worth a flop call, ask what turn card actually '
              'changed things before giving it up.',
          meaningLow: 'You barely fold on turns.',
          costLow:
              'Peeling this wide builds big pots you often surrender later.',
          fixLow:
              'Turn calls need river plans — decide what you do on bricks '
              'and scare cards before you call.',
          sliceBy: const ['texture', 'position'],
        ),
        _Detector(
          id: 'flop_overfold',
          title: 'Folding vs flop bets',
          opportunity: (f) => f.flopFacingResponse != null,
          hit: (f) => f.flopFacingResponse == 'fold',
          bandLow: 0.25,
          bandHigh: 0.55,
          minSample: 20,
          confirmedSample: 45,
          meaningHigh: 'A single c-bet takes the pot off you too often.',
          costHigh:
              'Preflop callers who fold most flops are the most profitable '
              'opponents at the table — you pay to see flops, then hand '
              'the pot over.',
          fixHigh:
              'Defend more with backdoor draws, overcards and position. '
              'Check the board-type breakdown below — the leak often lives '
              'on one texture, not everywhere.',
          meaningLow: 'You continue against nearly every flop bet.',
          costLow:
              'Floating this often only works with a plan for later '
              'streets; otherwise it just makes the pots you lose bigger.',
          fixLow:
              'Fold the hands with no pair, no draw and no backdoors — '
              'they rarely turn into winners by the river.',
          sliceBy: const ['texture', 'position'],
        ),
        _Detector(
          id: 'fold_to_3bet',
          title: 'Folding to 3-bets after opening',
          opportunity: (f) => f.facedThreeBetAfterOpen,
          hit: (f) => f.foldedToThreeBet,
          bandLow: 0.35,
          bandHigh: 0.68,
          minSample: 10,
          confirmedSample: 25,
          meaningHigh:
              'When your open gets 3-bet, you give the hand up almost '
              'every time.',
          costHigh:
              'Observant players will 3-bet you relentlessly — your opens '
              'become free money for anyone willing to re-raise.',
          fixHigh:
              'Defend your strongest opens: call in position with suited '
              'broadways and pairs, and 4-bet your premiums.',
          practiceHigh: 'Practice: Training Drills → 3-bet spots.',
          meaningLow:
              'When your open gets 3-bet, you almost always continue.',
          costLow:
              'Calling 3-bets this wide — often out of position — puts you '
              'in big pots with dominated hands. This bleeds stack even '
              'when no single hand looks like a disaster.',
          fixLow:
              'Tighten your continues: fold the weakest opens to 3-bets '
              '(offsuit broadways, weak suited hands), keep calls for '
              'pairs and strong suited hands, 4-bet premiums.',
          practiceLow: 'Practice: Training Drills → 3-bet spots.',
          sliceBy: const ['position'],
        ),
        _Detector(
          id: 'bb_vs_steal',
          title: 'BB folds vs steals',
          opportunity: (f) => f.bbFacedSteal,
          hit: (f) => f.bbFoldedToSteal,
          bandLow: 0.40,
          bandHigh: 0.72,
          minSample: 12,
          confirmedSample: 30,
          meaningHigh:
              'Late-position raises take your big blind without a fight.',
          costHigh:
              'You are getting a discount to continue — surrendering it '
              'every orbit adds up to a steady bleed.',
          fixHigh:
              'Defend wider vs CO/BTN/SB raises: suited hands, connectors, '
              'any pair.',
          practiceHigh: 'Practice: Training Drills → blind defense.',
          meaningLow: 'You defend your big blind against nearly every steal.',
          costLow:
              'Defending everything means playing lots of postflop pots '
              'out of position with weak holdings.',
          fixLow:
              'Keep the wide defense only if your postflop game backs it '
              'up — drop the worst offsuit junk.',
          practiceLow: 'Practice: Training Drills → blind defense.',
        ),
        _Detector(
          id: 'limp_habit',
          title: 'Open-limping',
          opportunity: (f) => true,
          hit: (f) => f.limped,
          bandLow: 0.0,
          bandHigh: 0.12,
          minSample: 40,
          confirmedSample: 80,
          meaningHigh: 'You enter a meaningful share of pots by limping.',
          costHigh:
              'Limping plays your hand face-down: no initiative, no fold '
              'equity, and the big pots get built by someone else on their '
              'terms.',
          fixHigh:
              'If a hand is worth playing, it is usually worth raising. '
              'Compare your limped hands in the Range Grid against '
              'standard open-raise charts.',
          practiceHigh: 'Practice: open-raise charts in Training Drills.',
        ),
        _Detector(
          id: 'wtsd',
          title: 'Going to showdown',
          opportunity: (f) => f.sawFlop,
          hit: (f) => f.wentToShowdown,
          bandLow: 0.20,
          bandHigh: 0.34,
          minSample: 30,
          confirmedSample: 60,
          meaningHigh:
              'Once you see a flop, you ride the hand to showdown a lot.',
          costHigh:
              'High showdown rates usually mean calling down too loose — '
              'or missing chances to win pots with well-timed aggression.',
          fixHigh:
              'Review your showdown losses in Session History: how many '
              'of those calls only beat bluffs?',
          meaningLow: 'You rarely see a showdown once you take a flop.',
          costLow:
              'Giving up early and often means opponents never need a hand '
              'to beat you — pressure alone does it.',
          fixLow:
              'Pick more spots to see the hand through — especially in '
              'small pots where one bet takes it away from you.',
        ),
        _Detector(
          id: 'wsd',
          title: 'Winning at showdown',
          opportunity: (f) => f.wentToShowdown,
          hit: (f) => f.wonAtShowdown,
          bandLow: 0.46,
          bandHigh: 0.62,
          minSample: 15,
          confirmedSample: 35,
          meaningHigh: 'You win showdowns at a very high rate.',
          costHigh:
              'Counter-intuitively, winning almost every showdown means '
              'you only get there with the goods — the pots you folded on '
              'the way were the expensive ones.',
          fixHigh:
              'Pair this with your fold-vs-bet numbers above: the leak is '
              'usually earlier in the hand, not at showdown.',
          meaningLow: 'You lose most of the showdowns you reach.',
          costLow:
              'Reaching showdown with hands that can only beat bluffs is '
              'paying to confirm bad news.',
          fixLow:
              'Tighten your call-downs: by the river, your hand should '
              'beat some of the value hands in their range, not only the '
              'bluffs.',
        ),
      ];

  static LeakReport analyze(List<LeakHandFacts> facts) {
    final hands = facts.where((f) => !f.isWalk).toList();
    final findings = <LeakFinding>[];
    for (final d in _detectors()) {
      findings.addAll(_evaluate(d, hands));
    }

    return LeakReport(
      findings: findings,
      handsAnalyzed: hands.length,
      coachSummary: _summarize(findings, hands.length),
      positionNets: _positionNets(hands),
      worstSpots: _worstSpots(hands),
    );
  }

  // ── Money view ─────────────────────────────────────────────────────

  static const _posOrder = ['EP', 'MP', 'CO', 'BTN', 'SB', 'BB'];

  /// Minimum hands for a spot cell to be rankable.
  static const spotMinHands = 6;

  static List<PositionNet> _positionNets(List<LeakHandFacts> hands) {
    final totals = <String, double>{};
    final counts = <String, int>{};
    for (final f in hands) {
      final pos = f.posGroup;
      final net = f.netBB;
      if (pos == null || net == null) continue;
      totals[pos] = (totals[pos] ?? 0) + net;
      counts[pos] = (counts[pos] ?? 0) + 1;
    }
    return [
      for (final pos in _posOrder)
        if (counts.containsKey(pos))
          PositionNet(pos, totals[pos]!, counts[pos]!),
    ];
  }

  /// Coarse stack buckets keep cell samples workable and map cleanly onto
  /// the drill stack presets (20/40/100).
  static (String, double)? _stackBucket(double? stackBB) {
    if (stackBB == null) return null;
    if (stackBB <= 20) return ('short ≤20bb', 20);
    if (stackBB <= 50) return ('mid 21-50bb', 40);
    return ('deep 50bb+', 100);
  }

  static List<SpotNet> _worstSpots(List<LeakHandFacts> hands) {
    final totals = <String, double>{};
    final counts = <String, int>{};
    final presets = <String, double>{};

    void add(String key, double net, double preset) {
      totals[key] = (totals[key] ?? 0) + net;
      counts[key] = (counts[key] ?? 0) + 1;
      presets[key] = preset;
    }

    for (final f in hands) {
      final net = f.netBB;
      if (net == null || f.posGroup == null) continue;
      final bucket = _stackBucket(f.stackBB);
      // Position × stack depth (all dealt hands — position economics).
      if (bucket != null) {
        add('${f.posGroup} · ${bucket.$1}', net, bucket.$2);
      }
      // Position vs villain position (contested pots only).
      if (f.heroVpip && f.openerPosGroup != null) {
        add('${f.posGroup} vs ${f.openerPosGroup} open', net,
            bucket?.$2 ?? 40);
      }
    }

    final spots = [
      for (final key in totals.keys)
        if (counts[key]! >= spotMinHands && totals[key]! < 0)
          SpotNet(key, totals[key]!, counts[key]!, presets[key]!),
    ]..sort((a, b) => a.netBBTotal.compareTo(b.netBBTotal));
    return spots.take(4).toList();
  }

  /// Evaluate one detector: parent finding first, then any flagged slice
  /// child findings (same band, slice sub-population, own examples).
  static List<LeakFinding> _evaluate(_Detector d, List<LeakHandFacts> hands) {
    final results = <LeakFinding>[];
    final parentSlices = <LeakSlice>[];
    final children = <LeakFinding>[];

    for (final dim in d.sliceBy) {
      final byKey = <String, List<LeakHandFacts>>{};
      for (final f in hands.where(d.opportunity)) {
        final key = _sliceKey(f, dim);
        if (key != null) byKey.putIfAbsent(key, () => []).add(f);
      }
      for (final entry in byKey.entries) {
        final child = _score(d, entry.value,
            idSuffix: '@${entry.key}', titleSuffix: ' — ${entry.key}',
            minSample: sliceMinSample, confirmedSample: sliceMinSample * 3);
        final flagged = child.isLeak;
        parentSlices.add(LeakSlice(
            entry.key, child.value, child.sampleCount,
            flagged: flagged));
        if (flagged) children.add(child);
      }
    }

    final parent = _score(d, hands,
        minSample: d.minSample,
        confirmedSample: d.confirmedSample,
        slices: parentSlices..sort((a, b) => b.sampleCount.compareTo(a.sampleCount)));
    results.add(parent);
    // Child findings only add signal when the parent alone would miss or
    // dilute them; suppress children that just restate a leaky parent on
    // its dominant slice.
    for (final c in children) {
      if (!parent.isLeak || (c.aboveBand != parent.aboveBand)) {
        results.add(c);
      } else if ((c.value - parent.value).abs() > 0.12) {
        results.add(c);
      }
    }
    return results;
  }

  static bool _isPostflopFacing(String detectorId) =>
      detectorId == 'flop_overfold' ||
      detectorId == 'turn_overfold' ||
      detectorId == 'river_overfold';

  /// Strong hands rank low (0) .. air ranks high (4).
  static int _strengthRank(LeakHandFacts f) {
    switch (f.flopStrength) {
      case FlopStrength.strong:
        return 0;
      case FlopStrength.draw:
        return 1;
      case FlopStrength.weakPair:
        return 2;
      case FlopStrength.overcards:
        return 3;
      case FlopStrength.air:
      case null:
        return 4;
    }
  }

  static LeakFinding _score(_Detector d, List<LeakHandFacts> hands,
      {String idSuffix = '',
      String titleSuffix = '',
      required int minSample,
      required int confirmedSample,
      List<LeakSlice> slices = const []}) {
    final opportunities = hands.where(d.opportunity).toList();
    final hits = opportunities.where(d.hit).toList();
    final n = opportunities.length;
    final value = n == 0 ? 0.0 : hits.length / n;
    final above = value > d.bandHigh;
    final below = value < d.bandLow;
    final oneSidedHealthy =
        (above && d.meaningHigh.isEmpty) || (below && d.meaningLow.isEmpty);

    final LeakVerdict verdict;
    if (n < minSample) {
      verdict = LeakVerdict.insufficientData;
    } else if ((!above && !below) || oneSidedHealthy) {
      verdict = LeakVerdict.healthy;
    } else {
      verdict =
          n >= confirmedSample ? LeakVerdict.confirmed : LeakVerdict.emerging;
    }

    final examples = <LeakExample>[];
    if (verdict == LeakVerdict.emerging || verdict == LeakVerdict.confirmed) {
      var pool =
          (above ? hits : opportunities.where((f) => !d.hit(f))).toList();
      // Postflop facing-bet leaks: curate by hand strength so examples show
      // MISTAKE-shaped hands, not correct plays (an under-folding finding
      // must never present a top-pair call as evidence).
      if (_isPostflopFacing(d.id)) {
        if (above) {
          // Overfolding: the interesting folds are the ones WITH equity.
          pool.sort((a, b) => _strengthRank(a).compareTo(_strengthRank(b)));
        } else {
          // Under-folding: show weak continues; drop strong hands entirely.
          pool = pool
              .where((f) => f.flopStrength != FlopStrength.strong)
              .toList()
            ..sort((a, b) => _strengthRank(b).compareTo(_strengthRank(a)));
        }
      }
      for (final f in pool) {
        if (f.ref == null) continue;
        examples.add(LeakExample(
          f.ref!,
          posGroup: f.posGroup,
          textureLabel: f.flopTexture == null
              ? null
              : BoardTextureClassifier.label(f.flopTexture!),
          holeCards: f.holeCards,
          strengthLabel: f.flopStrength == null
              ? null
              : FlopStrengthClassifier.label(f.flopStrength!),
        ));
        if (examples.length >= LeakFinding.maxExamples) break;
      }
    }

    return LeakFinding(
      id: '${d.id}$idSuffix',
      title: '${d.title}$titleSuffix',
      value: value,
      bandLow: d.bandLow,
      bandHigh: d.bandHigh,
      sampleCount: n,
      minSample: minSample,
      verdict: verdict,
      aboveBand: above,
      meaning: above ? d.meaningHigh : d.meaningLow,
      cost: above ? d.costHigh : d.costLow,
      fix: above ? d.fixHigh : d.fixLow,
      practiceHint: above ? d.practiceHigh : d.practiceLow,
      examples: examples,
      slices: slices,
    );
  }

  static String _summarize(List<LeakFinding> findings, int hands) {
    if (hands == 0) return '';
    final leaks = findings.where((f) => f.isLeak).toList()
      ..sort((a, b) => b.severity.compareTo(a.severity));
    final healthy =
        findings.where((f) => f.verdict == LeakVerdict.healthy).toList();

    final b = StringBuffer();
    if (leaks.isEmpty) {
      b.write('Across $hands hands, nothing sits outside healthy ranges. ');
      if (healthy.isNotEmpty) {
        b.write('Your ${healthy.first.title.toLowerCase()} and '
            '${healthy.length - 1} other checks look solid. ');
      }
      b.write('Keep logging — more hands sharpen every verdict.');
      return b.toString();
    }
    final top = leaks.first;
    b.write('Across $hands hands, your clearest improvement area is '
        '${top.title.toLowerCase()}. ${top.meaning} ');
    if (healthy.length >= 2) {
      b.write('The good news: ${healthy[0].title.toLowerCase()} and '
          '${healthy[1].title.toLowerCase()} are in healthy ranges — this '
          'is one fixable habit, not a broken game.');
    }
    return b.toString();
  }
}
