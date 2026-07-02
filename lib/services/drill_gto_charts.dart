import 'drill_hand_strength.dart';

/// A defend chart facing an open: the 3-bet range and the flat-call range.
class DefendChart {
  final Set<String> threeBet;
  final Set<String> call;
  const DefendChart({required this.threeBet, required this.call});

  /// Hands that continue at all (call or 3-bet).
  Set<String> get continueRange => {...threeBet, ...call};
}

/// A response chart when the hero's open gets 3-bet.
class Vs3BetChart {
  final Set<String> fourBet;
  final Set<String> call;
  const Vs3BetChart({required this.fourBet, required this.call});
  Set<String> get continueRange => {...fourBet, ...call};
}

/// Explicit preflop baseline charts approximating standard ~100BB solver
/// play, plus a ~40BB tightening transform. All ranges are ORIGINAL curated
/// data (authored for this app, validated against the public consensus of
/// solver-derived play — no licensed chart pack is copied).
///
/// Sourcing policy (see docs in repo): the underlying strategy is
/// uncopyrightable mathematics; these tables are our own expression of it.
/// ≤20BB spots use the self-computed Nash push/fold tables instead
/// (drill_nash_pushfold.dart) — those are exact, not curated.
///
/// A formula/percentile cutoff can't reproduce GTO ranges — small pairs and
/// suited hands play far above their raw-strength rank — so membership in
/// these explicit sets is the baseline, and exploit adjustments are
/// expressed as widen/tighten walks along the chart-derived playability
/// ordering (NOT the Chen formula).
class DrillGtoCharts {
  DrillGtoCharts._();

  static const _rankOrder = 'AKQJT98765432';
  static int _idx(String r) => _rankOrder.indexOf(r);

  /// Combos a 169-grid class represents: pair 6, suited 4, offsuit 12.
  static int combosOf(String hc) {
    if (hc.length == 2) return 6;
    return hc.endsWith('s') ? 4 : 12;
  }

  /// Expands range shorthand into explicit hand classes.
  /// Supports: '22+', 'A2s+', 'ATo+' (this-and-better), 'A5s-'
  /// (this-and-worse, down to the 2), and literals '76s' / 'KQo' / '55'.
  static Set<String> _expand(List<String> tokens) {
    final out = <String>{};
    for (final t in tokens) {
      if (t.endsWith('-')) {
        final body = t.substring(0, t.length - 1);
        final high = body[0];
        final suit = body.length >= 3 ? body[2] : 's';
        for (int li = _idx(body[1]); li < _rankOrder.length; li++) {
          if (_rankOrder[li] == high) continue;
          out.add('$high${_rankOrder[li]}$suit');
        }
        continue;
      }
      final plus = t.endsWith('+');
      final body = plus ? t.substring(0, t.length - 1) : t;

      if (body.length == 2 && body[0] == body[1]) {
        final from = _idx(body[0]);
        if (plus) {
          for (int i = from; i >= 0; i--) {
            out.add('${_rankOrder[i]}${_rankOrder[i]}');
          }
        } else {
          out.add(body);
        }
        continue;
      }

      final high = body[0];
      final low = body[1];
      final suit = body.length >= 3 ? body[2] : 's';
      if (plus) {
        for (int li = _idx(low); li > _idx(high); li--) {
          out.add('$high${_rankOrder[li]}$suit');
        }
      } else {
        out.add('$high$low$suit');
      }
    }
    return out;
  }

  // ── RFI (open) ranges, ~100BB ───────────────────────────────────────

  static final Map<String, Set<String>> rfi = {
    'EP': _expand([
      '22+',
      'A2s+', 'K9s+', 'Q9s+', 'J9s+', 'T8s+', '98s', '87s', '76s', '65s',
      'ATo+', 'KQo',
    ]),
    'MP': _expand([
      '22+',
      'A2s+', 'K7s+', 'Q8s+', 'J8s+', 'T8s+', '97s+', '87s', '76s', '65s',
      '54s', 'AJo+', 'KQo', 'KJo', 'QJo',
    ]),
    'CO': _expand([
      '22+',
      'A2s+', 'K5s+', 'Q7s+', 'J7s+', 'T7s+', '96s+', '86s+', '75s+', '64s+',
      '54s', 'A8o+', 'KTo+', 'QTo+', 'JTo',
    ]),
    'BTN': _expand([
      '22+',
      'A2s+', 'K2s+', 'Q4s+', 'J6s+', 'T6s+', '95s+', '85s+', '74s+', '64s+',
      '53s+', '43s', 'A2o+', 'K7o+', 'Q9o+', 'J9o+', 'T8o+', '98o',
    ]),
    'SB': _expand([
      '22+',
      'A2s+', 'K3s+', 'Q5s+', 'J7s+', 'T6s+', '96s+', '85s+', '75s+', '64s+',
      '54s', 'A4o+', 'K8o+', 'Q9o+', 'J9o+', 'T9o',
    ]),
  };

  static Set<String> openRange(String posGroup) => rfi[posGroup] ?? rfi['MP']!;
  static bool isOpen(String posGroup, String handClass) =>
      openRange(posGroup).contains(handClass);

  // ── Defend charts vs an open, ~100BB: hero group → opener group ─────
  // Only combinations that can occur are listed; lookups fall back to the
  // nearest EARLIER opener group (tighter opener = tighter defend), which
  // is the conservative direction.

  static final Map<String, Map<String, DefendChart>> vsOpen = {
    'MP': {
      'EP': DefendChart(
        threeBet: _expand(['QQ+', 'AKs', 'AKo', 'A5s']),
        call: _expand(['66+', 'AQs', 'AJs', 'ATs', 'KQs', 'QJs', 'JTs', 'T9s'])
          ..removeAll(_expand(['QQ+'])),
      ),
    },
    'CO': {
      'EP': DefendChart(
        threeBet: _expand(['QQ+', 'AKs', 'AKo', 'A5s', 'A4s']),
        call: _expand(['55+', 'ATs+', 'KQs', 'KJs', 'QJs', 'JTs', 'T9s', '98s', 'AQo'])
          ..removeAll(_expand(['QQ+', 'AKs', 'AKo'])),
      ),
      'MP': DefendChart(
        threeBet: _expand(['JJ+', 'AQs+', 'AKo', 'A5s', 'A4s', 'KQs']),
        call: _expand(['44+', 'ATs+', 'KTs+', 'QTs+', 'JTs', 'T9s', '98s', '87s', 'AQo'])
          ..removeAll(_expand(['JJ+', 'AQs+', 'AKo', 'KQs'])),
      ),
    },
    'BTN': {
      'EP': DefendChart(
        threeBet: _expand(['QQ+', 'AKs', 'AKo', 'A5s', 'A4s']),
        call: _expand([
          '22+', 'ATs+', 'KTs+', 'QTs+', 'JTs', 'T9s', '98s', '87s', '76s',
          '65s', 'AQo', 'KQo'
        ])
          ..removeAll(_expand(['QQ+', 'AKs', 'AKo'])),
      ),
      'MP': DefendChart(
        threeBet: _expand(['JJ+', 'AQs+', 'AKo', 'A5s', 'A4s', 'KQs']),
        call: _expand([
          '22+', 'ATs+', 'KTs+', 'QTs+', 'JTs', 'T9s', '98s', '87s', '76s',
          '65s', '54s', 'AQo', 'KQo'
        ])
          ..removeAll(_expand(['JJ+', 'AQs+', 'AKo', 'KQs'])),
      ),
      'CO': DefendChart(
        threeBet: _expand(['TT+', 'AQs+', 'AQo+', 'A5s', 'A4s', 'A3s', 'KQs', '76s']),
        call: _expand([
          '22+', 'A9s+', 'A5s-', 'KTs+', 'QTs+', 'JTs', 'T9s', '98s', '87s',
          '65s', '54s', 'AJo+', 'KQo'
        ])
          ..removeAll(_expand(['TT+', 'AQs+', 'AQo+', 'KQs'])),
      ),
    },
    'SB': {
      'EP': DefendChart(
        threeBet: _expand(['TT+', 'AQs+', 'AKo', 'A5s', 'A4s']),
        call: <String>{}, // SB plays 3-bet-or-fold vs early opens
      ),
      'MP': DefendChart(
        threeBet: _expand(['TT+', 'AQs+', 'AQo+', 'A5s', 'A4s', 'KQs']),
        call: <String>{},
      ),
      'CO': DefendChart(
        threeBet: _expand(['99+', 'ATs+', 'AJo+', 'KQs', 'KJs', 'A5s-', 'KQo']),
        call: <String>{},
      ),
      'BTN': DefendChart(
        threeBet: _expand([
          '77+', 'A9s+', 'A5s-', 'ATo+', 'KTs+', 'KQo', 'QTs+', 'JTs', 'T9s'
        ]),
        call: <String>{},
      ),
    },
    'BB': {
      'EP': DefendChart(
        threeBet: _expand(['QQ+', 'AKs', 'AKo', 'A5s']),
        call: _expand([
          '22+', 'A2s+', 'K9s+', 'Q9s+', 'J9s+', 'T8s+', '97s+', '87s', '76s',
          '65s', '54s', 'ATo+', 'KJo+', 'QJo'
        ])
          ..removeAll(_expand(['QQ+', 'AKs', 'AKo'])),
      ),
      'MP': DefendChart(
        threeBet: _expand(['JJ+', 'AQs+', 'AKo', 'A5s', 'A4s']),
        call: _expand([
          '22+', 'A2s+', 'K8s+', 'Q9s+', 'J8s+', 'T8s+', '97s+', '86s+', '76s',
          '65s', '54s', 'ATo+', 'KJo+', 'QJo', 'JTo'
        ])
          ..removeAll(_expand(['JJ+', 'AQs+', 'AKo'])),
      ),
      'CO': DefendChart(
        threeBet: _expand(['TT+', 'AQs+', 'AQo+', 'A5s', 'A4s', 'K9s', '87s', '76s']),
        call: _expand([
          '22+', 'A2s+', 'K5s+', 'Q8s+', 'J8s+', 'T7s+', '96s+', '86s+', '75s+',
          '65s', '54s', 'A9o+', 'KTo+', 'QTo+', 'JTo'
        ])
          ..removeAll(_expand(['TT+', 'AQs+', 'AQo+'])),
      ),
      'BTN': DefendChart(
        threeBet: _expand([
          '99+', 'ATs+', 'AJo+', 'KQs', 'KJs', 'A5s-', 'K9s', 'Q9s', 'J9s', '76s', '65s'
        ]),
        call: _expand([
          '22+', 'A2s+', 'K2s+', 'Q4s+', 'J6s+', 'T6s+', '95s+', '85s+', '74s+',
          '64s+', '53s+', 'A2o+', 'K9o+', 'Q9o+', 'J9o+', 'T8o+', '98o', '87o'
        ])
          ..removeAll(_expand(['99+', 'ATs+', 'AJo+', 'KQs', 'KJs'])),
      ),
      'SB': DefendChart(
        threeBet: _expand([
          '77+', 'A9s+', 'ATo+', 'KTs+', 'KJo+', 'QTs+', 'JTs', 'T9s', 'A5s-'
        ]),
        call: _expand([
          '22+', 'A2s+', 'K2s+', 'Q2s+', 'J4s+', 'T6s+', '95s+', '84s+', '74s+',
          '63s+', '53s+', '43s', 'A2o+', 'K7o+', 'Q8o+', 'J8o+', 'T8o+', '97o+', '87o'
        ])
          ..removeAll(_expand(['77+', 'A9s+', 'ATo+', 'KTs+', 'KJo+'])),
      ),
    },
  };

  /// Opener-group fallback order: nearest EARLIER (tighter) group.
  static const _openerFallback = {
    'EP': ['EP'],
    'MP': ['MP', 'EP'],
    'CO': ['CO', 'MP', 'EP'],
    'BTN': ['BTN', 'CO', 'MP', 'EP'],
    'SB': ['SB', 'BTN', 'CO', 'MP', 'EP'],
  };

  /// Defend chart for [heroGroup] facing an open from [openerGroup].
  /// Returns null only when the hero group has no defend charts at all.
  /// The [resolved] opener group actually used is reported for tracing.
  static (DefendChart, String)? defendFor(
      String heroGroup, String openerGroup) {
    final table = vsOpen[heroGroup];
    if (table == null) return null;
    for (final g in _openerFallback[openerGroup] ?? ['EP']) {
      final chart = table[g];
      if (chart != null) return (chart, g);
    }
    // last resort: any chart the hero group has
    final first = table.entries.first;
    return (first.value, first.key);
  }

  // ── Vs 3-bet charts (hero opened, got 3-bet), keyed by hero open pos ─

  static final Map<String, Vs3BetChart> vs3bet = {
    'EP': Vs3BetChart(
      fourBet: _expand(['KK+', 'AKs']),
      call: _expand(['99+', 'AQs+', 'AKo'])..removeAll(_expand(['KK+', 'AKs'])),
    ),
    'MP': Vs3BetChart(
      fourBet: _expand(['QQ+', 'AKs']),
      call: _expand(['88+', 'AQs+', 'AKo', 'KQs', 'AJs'])
        ..removeAll(_expand(['QQ+', 'AKs'])),
    ),
    'CO': Vs3BetChart(
      fourBet: _expand(['QQ+', 'AKs', 'AKo', 'A5s']),
      call: _expand(['77+', 'ATs+', 'KQs', 'QJs', 'JTs'])
        ..removeAll(_expand(['QQ+', 'AKs'])),
    ),
    'BTN': Vs3BetChart(
      fourBet: _expand(['QQ+', 'AKs', 'AKo', 'A5s', 'A4s']),
      call: _expand(['66+', 'ATs+', 'KQs', 'KJs', 'QJs', 'JTs', 'T9s', '98s', 'AQo'])
        ..removeAll(_expand(['QQ+', 'AKs'])),
    ),
    'SB': Vs3BetChart(
      fourBet: _expand(['QQ+', 'AKs', 'AKo', 'A5s']),
      call: _expand(['88+', 'AQs+', 'KQs'])..removeAll(_expand(['QQ+', 'AKs'])),
    ),
  };

  static Vs3BetChart vs3betFor(String heroGroup) =>
      vs3bet[heroGroup] ?? vs3bet['MP']!;

  // ── Cold vs 3-bet (hero hasn't invested) — one tight chart ──────────

  static final Set<String> coldVs3betContinue = _expand(['QQ+', 'AKs', 'AKo']);
  static final Set<String> coldVs3betRaise = _expand(['KK+']);

  // ── Chart-derived playability ordering ──────────────────────────────
  // Rank the 169 hands by how many chart ranges include them: RFI opens,
  // defend continues, and vs-3bet continues. Hands GTO plays everywhere
  // rank top; hands appearing only in the widest charts sit at the
  // widening frontier. Chen score is only the tiebreaker. This ordering —
  // NOT the Chen formula — drives exploit widen/tighten walks.

  static final Map<String, double> _playabilityPercent = _buildPlayability();

  static Map<String, double> _buildPlayability() {
    final score = <String, double>{};
    for (final hc in DrillHandStrength.allHandClasses) {
      var s = 0.0;
      for (final range in rfi.values) {
        if (range.contains(hc)) s += 1;
      }
      for (final table in vsOpen.values) {
        for (final chart in table.values) {
          if (chart.continueRange.contains(hc)) s += 1;
          if (chart.threeBet.contains(hc)) s += 0.5; // 3-bettable = extra
        }
      }
      for (final chart in vs3bet.values) {
        if (chart.continueRange.contains(hc)) s += 2; // survives 3-bets
      }
      score[hc] = s;
    }
    final ordered = DrillHandStrength.allHandClasses.toList()
      ..sort((a, b) {
        final byScore = score[b]!.compareTo(score[a]!);
        if (byScore != 0) return byScore;
        return DrillHandStrength.chenScore(b)
            .compareTo(DrillHandStrength.chenScore(a));
      });
    final out = <String, double>{};
    var cum = 0;
    for (final hc in ordered) {
      cum += combosOf(hc);
      out[hc] = cum / 1326 * 100;
    }
    return out;
  }

  /// Combo-weighted percentile of [hc] in the chart-derived playability
  /// ordering (lower = more playable). 100 for unknown input.
  static double playabilityPercent(String hc) =>
      _playabilityPercent[hc] ?? 100.0;

  /// Share of all 1326 combos covered by a set, as a percentage.
  static double coverageOf(Set<String> set) {
    var combos = 0;
    for (final hc in set) {
      combos += combosOf(hc);
    }
    return combos / 1326 * 100;
  }

  static double coverage(String posGroup) => coverageOf(openRange(posGroup));

  /// Widens [base] by roughly [byPercent] of combos, adding the most
  /// playable not-yet-included hands first (chart-derived ordering).
  static Set<String> widen(Set<String> base, double byPercent) {
    if (byPercent <= 0) return base;
    final target = byPercent / 100 * 1326;
    final candidates = DrillHandStrength.allHandClasses
        .where((h) => !base.contains(h))
        .toList()
      ..sort((a, b) => playabilityPercent(a).compareTo(playabilityPercent(b)));
    final result = {...base};
    var added = 0.0;
    for (final h in candidates) {
      if (added >= target) break;
      result.add(h);
      added += combosOf(h);
    }
    return result;
  }

  /// Tightens [base] by roughly [byPercent] of combos, removing the least
  /// playable included hands first (chart-derived ordering).
  static Set<String> tighten(Set<String> base, double byPercent) {
    if (byPercent <= 0) return base;
    final target = byPercent / 100 * 1326;
    final inBase = base.toList()
      ..sort((a, b) =>
          playabilityPercent(b).compareTo(playabilityPercent(a))); // worst 1st
    final result = {...base};
    var removed = 0.0;
    for (final h in inBase) {
      if (removed >= target) break;
      result.remove(h);
      removed += combosOf(h);
    }
    return result;
  }

  // ── Stack-depth profiles ────────────────────────────────────────────

  /// Which baseline applies at this depth. 'nash' = self-computed exact
  /// push/fold tables; '40bb' = 100BB charts tightened toward jam-or-fold;
  /// '100bb' = charts as authored.
  static String profileFor(double stackBB) {
    if (stackBB <= 20) return 'nash';
    if (stackBB <= 60) return '40bb';
    return '100bb';
  }

  /// ~40BB transform: flat-calling ranges shrink (a third of the widest
  /// calls become 3-bet-or-fold); 3-bet and open ranges hold. Documented
  /// approximation — labeled in the decision trace.
  static DefendChart defendAt40bb(DefendChart chart) => DefendChart(
        threeBet: chart.threeBet,
        call: tighten(chart.call, coverageOf(chart.call) * 0.35),
      );
}
