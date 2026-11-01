import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import 'logger_service.dart';
import 'stats_calculator.dart';

/// Bet-sizing situations we learn.
enum SizingKind { open, threeBet, cbet }

/// Minimum logged sizes before "your usual" is pre-selected.
const int kSizingMinSamples = 3;

/// What the raise UI may offer. Amounts are in chips for the CURRENT hand.
class SizingSuggestion {
  final double? preselect;
  final double? sameAsLast;

  const SizingSuggestion({this.preselect, this.sameAsLast});

  static const none = SizingSuggestion();

  bool get isEmpty => preselect == null && sameAsLast == null;
}

/// Pure classification of the spot the hero is about to size.
class SizingContext {
  SizingContext._();

  /// [actions] = map actions logged so far this hand, [street] = street of the
  /// pending bet/raise. Null when the spot is not tracked (4-bet+, raises over
  /// a postflop bet, non-c-bet postflop bets).
  static SizingKind? classify(
    List<Map<String, dynamic>> actions,
    String street, {
    required int heroSeat,
  }) {
    final s = street.toLowerCase();
    if (s == 'preflop') return _preflop(actions);
    if (s != 'flop') return null;
    return _flop(actions, heroSeat);
  }

  static SizingKind? _preflop(List<Map<String, dynamic>> actions) {
    var raises = 0;
    for (final a in actions) {
      if (a['street']?.toString().toLowerCase() != 'preflop') continue;
      if (StatsCalculator.isRaiseAction(a['action']?.toString() ?? '')) raises++;
    }
    return raises == 0 ? SizingKind.open : (raises == 1 ? SizingKind.threeBet : null);
  }

  static SizingKind? _flop(List<Map<String, dynamic>> actions, int hero) {
    if (!StatsCalculator.hadCbetOpportunity(actions, hero)) return null;
    final facing = actions.any((a) =>
        a['street']?.toString().toLowerCase() == 'flop' &&
        StatsCalculator.isAggressiveAction(a['action']?.toString() ?? ''));
    return facing ? null : SizingKind.cbet;
  }
}

/// Normalisation: preflop = BB multiple rounded to 0.5, c-bet = pot fraction
/// rounded to 0.05. Pure.
class SizingNorm {
  SizingNorm._();

  static double normalize(SizingKind k, double amount,
      {required double bigBlind, required double pot}) {
    if (k == SizingKind.cbet) {
      return pot <= 0 ? 0 : _round(amount / pot, 0.05);
    }
    return bigBlind <= 0 ? 0 : _round(amount / bigBlind, 0.5);
  }

  static double denormalize(SizingKind k, double v,
      {required double bigBlind, required double pot}) =>
      k == SizingKind.cbet ? v * pot : v * bigBlind;

  static double _round(double v, double step) =>
      (v / step).round() * step;

  /// Stakes bucket: power-of-two band of the big blind.
  static int bbBucket(double bigBlind) =>
      bigBlind <= 0 ? 0 : (math.log(bigBlind) / math.ln2).floor();
}

/// Persists counts of normalised sizes per gameType + bbBucket + kind.
/// Every IO call is guarded: failures fall back to "no suggestion".
class SizingHistoryStore {
  final Future<SharedPreferences> Function() _prefs;

  SizingHistoryStore({Future<SharedPreferences> Function()? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance;

  static String keyFor(String gameType, double bigBlind, SizingKind kind) =>
      'sizing_hist_v1_${gameType}_b${SizingNorm.bbBucket(bigBlind)}_${kind.name}';

  Future<void> record({
    required String gameType,
    required double bigBlind,
    required SizingKind kind,
    required double amount,
    required double pot,
  }) async {
    try {
      final v = SizingNorm.normalize(kind, amount, bigBlind: bigBlind, pot: pot);
      if (v <= 0) return;
      final p = await _prefs();
      final key = keyFor(gameType, bigBlind, kind);
      final data = _decode(p.getString(key));
      final counts = data.counts..update(_k(v), (c) => c + 1, ifAbsent: () => 1);
      await p.setString(
          key, jsonEncode({'counts': counts, 'last': v}));
    } catch (e) {
      LoggerService.log('[SizingHistory] record failed: $e',
          level: LogLevel.WARNING);
    }
  }

  /// Most used normalised size once n >= [kSizingMinSamples], else null.
  Future<double?> mostUsed(String gameType, double bigBlind, SizingKind kind) async =>
      (await _load(gameType, bigBlind, kind)).mostUsed;

  Future<double?> lastUsed(String gameType, double bigBlind, SizingKind kind) async =>
      (await _load(gameType, bigBlind, kind)).last;

  /// Suggestion in chips for the current hand.
  Future<SizingSuggestion> suggestionFor({
    required String gameType,
    required double bigBlind,
    required SizingKind kind,
    required double pot,
  }) async {
    final d = await _load(gameType, bigBlind, kind);
    double? chips(double? v) => v == null
        ? null
        : SizingNorm.denormalize(kind, v, bigBlind: bigBlind, pot: pot);
    return SizingSuggestion(
        preselect: chips(d.mostUsed), sameAsLast: chips(d.last));
  }

  Future<_Data> _load(String gameType, double bigBlind, SizingKind kind) async {
    try {
      final p = await _prefs();
      return _decode(p.getString(keyFor(gameType, bigBlind, kind)));
    } catch (e) {
      LoggerService.log('[SizingHistory] load failed: $e',
          level: LogLevel.WARNING);
      return _Data({}, null);
    }
  }

  static String _k(double v) => v.toStringAsFixed(2);

  static _Data _decode(String? raw) {
    if (raw == null) return _Data({}, null);
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final counts = <String, int>{
        for (final e in (m['counts'] as Map<String, dynamic>).entries)
          e.key: (e.value as num).toInt(),
      };
      return _Data(counts, (m['last'] as num?)?.toDouble());
    } catch (_) {
      return _Data({}, null);
    }
  }
}

class _Data {
  final Map<String, int> counts;
  final double? last;
  _Data(this.counts, this.last);

  double? get mostUsed {
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    if (total < kSizingMinSamples) return null;
    final best = counts.entries.reduce((a, b) {
      if (a.value != b.value) return a.value > b.value ? a : b;
      return double.parse(a.key) >= double.parse(b.key) ? a : b; // tie: larger
    });
    return double.tryParse(best.key);
  }
}
