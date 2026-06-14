import 'drill_hand_strength.dart';

/// Explicit preflop RFI (raise-first-in) opening ranges per position group,
/// approximating standard ~100BB solver charts.
///
/// A formula/percentile cutoff can't reproduce GTO opening ranges — small
/// pairs and suited hands open well above their raw-strength rank, and late
/// position adds suited junk over "stronger" offsuit hands. So the baseline
/// is a curated set of 169-grid classes per position; everything else
/// (exploit widening/tightening) is expressed as a delta on top of it.
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
  /// Supports: '22+', 'A2s+', 'ATo+', and literals '76s' / 'KQo' / '55'.
  static Set<String> _expand(List<String> tokens) {
    final out = <String>{};
    for (final t in tokens) {
      final plus = t.endsWith('+');
      final body = plus ? t.substring(0, t.length - 1) : t;

      if (body.length == 2 && body[0] == body[1]) {
        // pair (with or without +)
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

      // suited/offsuit: high, low, suit flag
      final high = body[0];
      final low = body[1];
      final suit = body.length >= 3 ? body[2] : 's';
      if (plus) {
        // widen the low card up toward (high - 1)
        for (int li = _idx(low); li > _idx(high); li--) {
          out.add('$high${_rankOrder[li]}$suit');
        }
      } else {
        out.add('$high$low$suit');
      }
    }
    return out;
  }

  /// RFI ranges by position group (EP/MP/CO/BTN/SB). BB never opens unopened.
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

  static Set<String> openRange(String posGroup) =>
      rfi[posGroup] ?? rfi['MP']!;

  static bool isOpen(String posGroup, String handClass) =>
      openRange(posGroup).contains(handClass);

  /// Share of all 1326 combos covered by a set, as a percentage.
  static double coverageOf(Set<String> set) {
    var combos = 0;
    for (final hc in set) {
      combos += combosOf(hc);
    }
    return combos / 1326 * 100;
  }

  static double coverage(String posGroup) => coverageOf(openRange(posGroup));

  /// Widens [base] by roughly [byPercent] of combos, adding the strongest
  /// not-yet-included hands first (by the shared strength ordering). Used to
  /// model exploitative loosening (e.g. stealing vs nitty blinds).
  static Set<String> widen(Set<String> base, double byPercent) {
    if (byPercent <= 0) return base;
    final target = byPercent / 100 * 1326;
    final candidates = DrillHandStrength.allHandClasses
        .where((h) => !base.contains(h))
        .toList()
      ..sort((a, b) => DrillHandStrength.topPercent(a)
          .compareTo(DrillHandStrength.topPercent(b)));
    final result = {...base};
    var added = 0.0;
    for (final h in candidates) {
      if (added >= target) break;
      result.add(h);
      added += combosOf(h);
    }
    return result;
  }

  /// Tightens [base] by roughly [byPercent] of combos, removing the weakest
  /// included hands first. Used to model exploitative tightening.
  static Set<String> tighten(Set<String> base, double byPercent) {
    if (byPercent <= 0) return base;
    final target = byPercent / 100 * 1326;
    final inBase = base.toList()
      ..sort((a, b) => DrillHandStrength.topPercent(b)
          .compareTo(DrillHandStrength.topPercent(a))); // weakest first
    final result = {...base};
    var removed = 0.0;
    for (final h in inBase) {
      if (removed >= target) break;
      result.remove(h);
      removed += combosOf(h);
    }
    return result;
  }
}
