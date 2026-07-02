/// Self-computed Nash push/fold tables.
///
/// Pipeline:
///  1. 7-card hand evaluator (rank category + kickers packed into an int).
///  2. 169x169 class-vs-class all-in equity matrix via Monte Carlo.
///  3. Fixed-point (damped fictitious-play) iteration of jam/call Nash
///     equilibrium for HU SB-vs-BB, per effective stack.
///  4. Fold-through approximation for earlier-position jam ranges
///     (each player behind calls with their Nash calling range; multiway
///     overcalls ignored — standard first-order approximation).
///
/// Output: JSON to stdout with equity spot-checks and all ranges.
import 'dart:convert';
import 'dart:math';

// ── Cards & classes ───────────────────────────────────────────────────
// card = rank*4 + suit, rank 0..12 (2..A), suit 0..3

const ranksStr = '23456789TJQKA';

class HandClass {
  final int hi, lo; // rank indices, hi >= lo
  final bool suited;
  HandClass(this.hi, this.lo, this.suited);
  String get name => hi == lo
      ? '${ranksStr[hi]}${ranksStr[lo]}'
      : '${ranksStr[hi]}${ranksStr[lo]}${suited ? 's' : 'o'}';
  int get combos => hi == lo ? 6 : (suited ? 4 : 12);

  /// All concrete 2-card combos for this class.
  List<List<int>> allCombos() {
    final out = <List<int>>[];
    if (hi == lo) {
      for (var s1 = 0; s1 < 4; s1++) {
        for (var s2 = s1 + 1; s2 < 4; s2++) {
          out.add([hi * 4 + s1, lo * 4 + s2]);
        }
      }
    } else if (suited) {
      for (var s = 0; s < 4; s++) {
        out.add([hi * 4 + s, lo * 4 + s]);
      }
    } else {
      for (var s1 = 0; s1 < 4; s1++) {
        for (var s2 = 0; s2 < 4; s2++) {
          if (s1 != s2) out.add([hi * 4 + s1, lo * 4 + s2]);
        }
      }
    }
    return out;
  }
}

final List<HandClass> classes = () {
  final out = <HandClass>[];
  for (var hi = 12; hi >= 0; hi--) {
    out.add(HandClass(hi, hi, false));
    for (var lo = hi - 1; lo >= 0; lo--) {
      out.add(HandClass(hi, lo, true));
      out.add(HandClass(hi, lo, false));
    }
  }
  return out; // 169 entries
}();

final Map<String, int> classIndex = {
  for (var i = 0; i < classes.length; i++) classes[i].name: i
};

// ── 7-card evaluator ──────────────────────────────────────────────────
// Returns comparable int: category*2^24 + tiebreak. Higher = better.
// Categories: 8 SF, 7 quads, 6 boat, 5 flush, 4 straight, 3 trips,
//             2 two pair, 1 pair, 0 high card.

int evaluate7(List<int> cards) {
  final rankCount = List<int>.filled(13, 0);
  final suitCount = List<int>.filled(4, 0);
  final suitRanksMask = List<int>.filled(4, 0);
  var ranksMask = 0;
  for (final c in cards) {
    final r = c >> 2, s = c & 3;
    rankCount[r]++;
    suitCount[s]++;
    suitRanksMask[s] |= 1 << r;
    ranksMask |= 1 << r;
  }

  int straightHigh(int mask) {
    // lowest non-wheel straight is 6-high (bits 4..0); wheel handled below
    for (var hi = 12; hi >= 4; hi--) {
      var ok = true;
      for (var k = 0; k < 5; k++) {
        if ((mask >> (hi - k)) & 1 == 0) {
          ok = false;
          break;
        }
      }
      if (ok) return hi;
    }
    // wheel A-2-3-4-5
    const wheel = (1 << 12) | 1 | 2 | 4 | 8; // A,2,3,4,5 → bits 12,0,1,2,3
    if ((mask & wheel) == wheel) return 3; // 5-high
    return -1;
  }

  // flush / straight flush
  for (var s = 0; s < 4; s++) {
    if (suitCount[s] >= 5) {
      final sf = straightHigh(suitRanksMask[s]);
      if (sf >= 0) return (8 << 24) | sf;
      // top 5 flush ranks
      var tb = 0, taken = 0;
      for (var r = 12; r >= 0 && taken < 5; r--) {
        if ((suitRanksMask[s] >> r) & 1 == 1) {
          tb = (tb << 4) | r;
          taken++;
        }
      }
      return (5 << 24) | tb;
    }
  }

  // rank multiplicities
  var quad = -1, trip = -1, trip2 = -1;
  final pairs = <int>[];
  for (var r = 12; r >= 0; r--) {
    switch (rankCount[r]) {
      case 4:
        quad = r;
      case 3:
        if (trip == -1) {
          trip = r;
        } else if (trip2 == -1) {
          trip2 = r;
        }
      case 2:
        pairs.add(r);
    }
  }

  int kickers(int n, List<int> exclude) {
    var tb = 0, taken = 0;
    for (var r = 12; r >= 0 && taken < n; r--) {
      if (rankCount[r] > 0 && !exclude.contains(r)) {
        tb = (tb << 4) | r;
        taken++;
      }
    }
    return tb;
  }

  if (quad >= 0) return (7 << 24) | (quad << 4) | (kickers(1, [quad]));
  if (trip >= 0 && (pairs.isNotEmpty || trip2 >= 0)) {
    final pairRank = trip2 >= 0
        ? (pairs.isNotEmpty ? max(trip2, pairs.first) : trip2)
        : pairs.first;
    return (6 << 24) | (trip << 4) | pairRank;
  }
  final st = straightHigh(ranksMask);
  if (st >= 0) return (4 << 24) | st;
  if (trip >= 0) return (3 << 24) | (trip << 8) | kickers(2, [trip]);
  if (pairs.length >= 2) {
    return (2 << 24) |
        (pairs[0] << 8) |
        (pairs[1] << 4) |
        kickers(1, [pairs[0], pairs[1]]);
  }
  if (pairs.length == 1) {
    return (1 << 24) | (pairs[0] << 12) | kickers(3, [pairs[0]]);
  }
  return kickers(5, []);
}

// ── Equity matrix (Monte Carlo) ───────────────────────────────────────

final rng = Random(20260704);

/// equity[i][j] = P(class i beats class j all-in) + 0.5*P(tie)
late List<List<double>> equity;

void computeEquityMatrix(int samplesPerPair) {
  final n = classes.length;
  equity = List.generate(n, (_) => List.filled(n, 0.0));
  final deck = List<int>.generate(52, (i) => i);

  for (var i = 0; i < n; i++) {
    final combosI = classes[i].allCombos();
    for (var j = i; j < n; j++) {
      final combosJ = classes[j].allCombos();
      var winI = 0.0;
      var valid = 0;
      var attempts = 0;
      while (valid < samplesPerPair && attempts < samplesPerPair * 3) {
        attempts++;
        final a = combosI[rng.nextInt(combosI.length)];
        final b = combosJ[rng.nextInt(combosJ.length)];
        if (a[0] == b[0] || a[0] == b[1] || a[1] == b[0] || a[1] == b[1]) {
          continue; // card conflict — resample (weights classes correctly)
        }
        // sample 5 board cards from remaining 48 (partial Fisher-Yates)
        var deckLen = 52;
        // move used cards to the end conceptually via swap-removal
        // simpler: rejection sample 5 distinct not-in-hand cards
        final used = <int>{a[0], a[1], b[0], b[1]};
        final board = <int>[];
        while (board.length < 5) {
          final c = rng.nextInt(52);
          if (!used.contains(c)) {
            used.add(c);
            board.add(c);
          }
        }
        final ra = evaluate7([a[0], a[1], ...board]);
        final rb = evaluate7([b[0], b[1], ...board]);
        if (ra > rb) {
          winI += 1;
        } else if (ra == rb) {
          winI += 0.5;
        }
        valid++;
        deckLen; // silence
      }
      final eq = winI / valid;
      equity[i][j] = eq;
      equity[j][i] = 1 - eq;
    }
    if (i % 20 == 0) {
      // progress marker on stderr-like line
      print('#progress equity row $i/169');
    }
  }
}

/// Class-vs-class matchup probability weight including card removal:
/// number of non-conflicting combo pairs.
late List<List<double>> matchupWeight;
void computeMatchupWeights() {
  final n = classes.length;
  matchupWeight = List.generate(n, (_) => List.filled(n, 0.0));
  for (var i = 0; i < n; i++) {
    for (var j = 0; j < n; j++) {
      var cnt = 0;
      for (final a in classes[i].allCombos()) {
        for (final b in classes[j].allCombos()) {
          if (a[0] != b[0] && a[0] != b[1] && a[1] != b[0] && a[1] != b[1]) {
            cnt++;
          }
        }
      }
      matchupWeight[i][j] = cnt.toDouble();
    }
  }
}

// ── Nash HU SB-vs-BB jam/fold ─────────────────────────────────────────
// Effective stack S (in bb). SB posts 0.5, BB posts 1.
// SB net EV (relative to start of hand):
//   fold: -0.5
//   jam, BB folds: +1
//   jam, BB calls: 2S*eq - S
// BB net EV vs a jam:
//   fold: -1
//   call: 2S*eq - S

class NashResult {
  final List<double> jam; // probability per class (0..1)
  final List<double> call;
  NashResult(this.jam, this.call);
}

NashResult solveHU(double S, {int iters = 400}) {
  final n = classes.length;
  var jam = List<double>.filled(n, 1.0); // start jamming everything
  var call = List<double>.filled(n, 1.0);

  for (var it = 0; it < iters; it++) {
    // BB best response to current jam range
    final newCall = List<double>.filled(n, 0.0);
    for (var b = 0; b < n; b++) {
      // E[eq | SB jams] weighted by jam prob and card-removal weights
      var wSum = 0.0, eqSum = 0.0;
      for (var s = 0; s < n; s++) {
        final w = jam[s] * matchupWeight[s][b];
        if (w <= 0) continue;
        wSum += w;
        eqSum += w * equity[b][s];
      }
      if (wSum <= 0) {
        newCall[b] = 0;
        continue;
      }
      final eq = eqSum / wSum;
      final evCall = 2 * S * eq - S;
      newCall[b] = evCall > -1 ? 1.0 : 0.0;
    }

    // SB best response to current call range
    final newJam = List<double>.filled(n, 0.0);
    for (var s = 0; s < n; s++) {
      var wCall = 0.0, wTotal = 0.0, eqSum = 0.0;
      for (var b = 0; b < n; b++) {
        final w = matchupWeight[s][b];
        wTotal += w;
        final wc = w * call[b];
        wCall += wc;
        eqSum += wc * equity[s][b];
      }
      final pCall = wTotal > 0 ? wCall / wTotal : 0.0;
      final eqIfCalled = wCall > 0 ? eqSum / wCall : 0.5;
      final evJam =
          (1 - pCall) * 1.0 + pCall * (2 * S * eqIfCalled - S);
      newJam[s] = evJam > -0.5 ? 1.0 : 0.0;
    }

    // damped update (fictitious-play flavour) for convergence
    final alpha = 2.0 / (it + 3);
    for (var k = 0; k < n; k++) {
      jam[k] = jam[k] * (1 - alpha) + newJam[k] * alpha;
      call[k] = call[k] * (1 - alpha) + newCall[k] * alpha;
    }
  }
  return NashResult(jam, call);
}

// ── Earlier-position jam ranges (fold-through approximation) ─────────
// Jammer with [behindCalls] = list of calling ranges of players still to
// act (each a prob vector). Blinds in pot = 1.5. Overcalls ignored:
// EV(jam) = P(all fold)*1.5*? ... For the JAMMER seat not in blinds:
//   fold: 0
//   jam, all fold: +1.5
//   jam, exactly player k calls (others fold): 2S*eq_k - S
// Call threshold for behind players: their HU-call EV vs this jam range
// with dead blinds: call EV = 2S*eq - S + (folded blinds ignored — they
// use the same -1/-S structure as BB for simplicity; approximation).

List<double> solvePositionJam(double S, List<List<double>> behindCalls,
    {int iters = 300}) {
  final n = classes.length;
  var jam = List<double>.filled(n, 1.0);

  for (var it = 0; it < iters; it++) {
    final newJam = List<double>.filled(n, 0.0);
    for (var s = 0; s < n; s++) {
      // per-behind-player: prob they call & conditional equity
      var pAllFold = 1.0;
      var evShowdown = 0.0;
      for (final callRange in behindCalls) {
        var wCall = 0.0, wTotal = 0.0, eqSum = 0.0;
        for (var b = 0; b < n; b++) {
          final w = matchupWeight[s][b];
          wTotal += w;
          final wc = w * callRange[b];
          wCall += wc;
          eqSum += wc * equity[s][b];
        }
        final pCall = wTotal > 0 ? wCall / wTotal : 0.0;
        final eqIfCalled = wCall > 0 ? eqSum / wCall : 0.5;
        // exactly-this-player-calls weight uses pAllFold-so-far
        evShowdown += pAllFold * pCall * (2 * S * eqIfCalled - S + 1.5);
        pAllFold *= (1 - pCall);
      }
      final evJam = pAllFold * 1.5 + evShowdown;
      newJam[s] = evJam > 0 ? 1.0 : 0.0;
    }
    final alpha = 2.0 / (it + 3);
    for (var k = 0; k < n; k++) {
      jam[k] = jam[k] * (1 - alpha) + newJam[k] * alpha;
    }
  }
  return jam;
}

Set<String> rangeOf(List<double> probs, {double threshold = 0.5}) => {
      for (var i = 0; i < probs.length; i++)
        if (probs[i] >= threshold) classes[i].name
    };

double pctOf(List<double> probs) {
  var c = 0.0;
  for (var i = 0; i < probs.length; i++) {
    c += probs[i] * classes[i].combos;
  }
  return c / 1326 * 100;
}

void main(List<String> args) {
  final samples = args.isNotEmpty ? int.parse(args[0]) : 30000;

  // evaluator self-tests
  int evalOf(String cs) {
    // cs like "AhAs KdQc..." — 7 cards, 2-char each: rank + suit(h/d/c/s)
    const suits = 'cdhs';
    final cards = <int>[];
    for (final tok in cs.split(' ')) {
      cards.add(ranksStr.indexOf(tok[0]) * 4 + suits.indexOf(tok[1]));
    }
    return evaluate7(cards);
  }

  assert(evalOf('Ah Kh Qh Jh Th 2c 3d') >> 24 == 8, 'royal = SF');
  assert(evalOf('Ah Ad Ac As Kh 2c 3d') >> 24 == 7, 'quads');
  assert(evalOf('Ah Ad Ac Ks Kh 2c 3d') >> 24 == 6, 'boat');
  assert(evalOf('Ah 9h 5h 3h Th 2c 3d') >> 24 == 5, 'flush');
  assert(evalOf('Ah 2d 3c 4s 5h Tc Jd') >> 24 == 4, 'wheel straight');
  assert(evalOf('Ah Ad 3c 4s 5h Tc Jd') >> 24 == 1, 'one pair');
  print('#selftest evaluator OK');

  final sw = Stopwatch()..start();
  computeMatchupWeights();
  computeEquityMatrix(samples);
  print('#progress equity done in ${sw.elapsed}');

  // equity spot checks (known values)
  double eq(String a, String b) => equity[classIndex[a]!][classIndex[b]!];
  final spotChecks = {
    'AA_vs_KK': [eq('AA', 'KK'), 0.815],
    'AKs_vs_QQ': [eq('AKs', 'QQ'), 0.46],
    'AKo_vs_22': [eq('AKo', '22'), 0.47],
    '72o_vs_AA': [eq('72o', 'AA'), 0.115],
    'A5s_vs_KQo': [eq('A5s', 'KQo'), 0.578],
  };
  spotChecks.forEach((k, v) {
    final diff = (v[0] - v[1]).abs();
    print('#spotcheck $k computed=${v[0].toStringAsFixed(3)} '
        'reference=${v[1]} diff=${diff.toStringAsFixed(3)} '
        '${diff < 0.02 ? "OK" : "SUSPECT"}');
  });

  // HU SB-vs-BB Nash per stack
  final stacks = [2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 12.0, 15.0, 20.0];
  final out = <String, dynamic>{'samplesPerPair': samples, 'hu': {}, 'position': {}};
  final huCallRanges = <double, List<double>>{};
  for (final S in stacks) {
    final r = solveHU(S);
    huCallRanges[S] = r.call;
    out['hu']['${S.toInt()}'] = {
      'sbJam': rangeOf(r.jam).toList(),
      'sbJamPct': pctOf(r.jam),
      'bbCall': rangeOf(r.call).toList(),
      'bbCallPct': pctOf(r.call),
    };
    print('#progress HU S=$S jam=${pctOf(r.jam).toStringAsFixed(1)}% '
        'call=${pctOf(r.call).toStringAsFixed(1)}%');
  }

  // Position jams: N players behind, each approximated by the HU call
  // range for that stack (fold-through model).
  final positionsBehind = {'BTN': 2, 'CO': 3, 'HJ': 4, 'UTG': 5};
  for (final S in stacks) {
    final callVec = huCallRanges[S]!;
    for (final e in positionsBehind.entries) {
      final jam = solvePositionJam(S, List.filled(e.value, callVec));
      (out['position']['${e.key}'] ??= <String, dynamic>{})['${S.toInt()}'] = {
        'jam': rangeOf(jam).toList(),
        'jamPct': pctOf(jam),
      };
    }
    print('#progress position jams S=$S done');
  }

  print('#RESULT_JSON_BEGIN');
  print(jsonEncode(out));
  print('#RESULT_JSON_END');
  print('#done total ${sw.elapsed}');
}
