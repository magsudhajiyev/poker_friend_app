#!/usr/bin/env python3
"""Converts compute_nash.dart JSON output into lib/services/drill_nash_pushfold.dart."""
import json, sys, re

src = open(sys.argv[1]).read()
m = re.search(r'#RESULT_JSON_BEGIN\n(.*?)\n#RESULT_JSON_END', src, re.S)
assert m, 'no result json found'
data = json.loads(m.group(1))

stacks = sorted(int(k) for k in data['hu'].keys())

def dart_set(hands):
    hands = sorted(hands)
    return '{' + ', '.join(f"'{h}'" for h in hands) + '}'

def table_for(getter):
    lines = []
    for s in stacks:
        lines.append(f"    {s}: {dart_set(getter(s))},")
    return '\n'.join(lines)

hu = data['hu']
pos = data['position']

out = f'''// GENERATED FILE — do not edit by hand.
// Produced by scratchpad/nash/compute_nash.dart ({data['samplesPerPair']}
// Monte Carlo samples per class pair) + generate_dart.py.
// Self-computed Nash push/fold equilibrium: SB-vs-BB is solved exactly
// (damped best-response iteration to convergence); earlier positions use
// the standard fold-through approximation (each player behind calls with
// the Nash calling range; multiway overcalls ignored).

/// Self-computed Nash push/fold tables for short-stack (≤20BB) play.
class DrillNashPushfold {{
  DrillNashPushfold._();

  static const List<int> stacks = {stacks};

  static double nearestStack(double stackBB) {{
    var best = stacks.first;
    var bestD = (stackBB - best).abs();
    for (final s in stacks) {{
      final d = (stackBB - s).abs();
      if (d < bestD) {{
        best = s;
        bestD = d;
      }}
    }}
    return best.toDouble();
  }}

  /// Jam (push) range for an unopened pot. SB is the exact HU solution;
  /// BTN/CO/MP/EP use the fold-through approximation. BB never faces an
  /// unopened jam decision (it holds the option) — falls back to SB.
  static Set<String> jamRange(String posGroup, double stackBB) {{
    final s = nearestStack(stackBB).toInt();
    switch (posGroup) {{
      case 'SB':
      case 'BB':
        return _sbJam[s] ?? const {{}};
      case 'BTN':
        return _btnJam[s] ?? const {{}};
      case 'CO':
        return _coJam[s] ?? const {{}};
      case 'MP':
        return _hjJam[s] ?? const {{}};
      default: // EP
        return _utgJam[s] ?? const {{}};
    }}
  }}

  /// Calling range facing a jam (exact for BB vs SB; used as the reference
  /// for other seats — noted in the decision trace).
  static Set<String> callVsJamRange(double stackBB) {{
    final s = nearestStack(stackBB).toInt();
    return _bbCall[s] ?? const {{}};
  }}

  /// Whether the table for this seat is the exact equilibrium (true) or the
  /// fold-through approximation (false).
  static bool isExact(String posGroup) => posGroup == 'SB' || posGroup == 'BB';

  static const Map<int, Set<String>> _sbJam = {{
{table_for(lambda s: hu[str(s)]['sbJam'])}
  }};

  static const Map<int, Set<String>> _bbCall = {{
{table_for(lambda s: hu[str(s)]['bbCall'])}
  }};

  static const Map<int, Set<String>> _btnJam = {{
{table_for(lambda s: pos['BTN'][str(s)]['jam'])}
  }};

  static const Map<int, Set<String>> _coJam = {{
{table_for(lambda s: pos['CO'][str(s)]['jam'])}
  }};

  static const Map<int, Set<String>> _hjJam = {{
{table_for(lambda s: pos['HJ'][str(s)]['jam'])}
  }};

  static const Map<int, Set<String>> _utgJam = {{
{table_for(lambda s: pos['UTG'][str(s)]['jam'])}
  }};
}}
'''
open(sys.argv[2], 'w').write(out)
# summary for review
print('stacks:', stacks)
for s in [5, 10, 15, 20]:
    if str(s) in hu:
        print(f"S={s}: SB jam {hu[str(s)]['sbJamPct']:.1f}%  BB call {hu[str(s)]['bbCallPct']:.1f}%  "
              f"BTN jam {pos['BTN'][str(s)]['jamPct']:.1f}%  UTG jam {pos['UTG'][str(s)]['jamPct']:.1f}%")
