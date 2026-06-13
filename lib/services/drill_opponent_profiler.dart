import '../models/drill_models.dart';
import '../models/opponent_stats.dart';
import 'opponent_stats_service.dart';
import 'play_style_detector.dart';

/// Builds drill bot profiles from saved opponents' measured stats.
///
/// Observed frequencies are shrunk toward the generic-regular prior with a
/// per-stat sample-size weight, so a 12-hand read nudges the bot away from
/// baseline instead of defining it.
class DrillOpponentProfiler {
  DrillOpponentProfiler._();

  /// Shrinkage constant: observed data and prior carry equal weight at K
  /// samples. Per-stat sample counts are used (e.g. 3-bet uses opportunities,
  /// not hands). Kept low so real reads visibly change bot behaviour —
  /// fold-to-3-bet and 3-bet samples are small even for well-logged
  /// opponents, and a drill against clones that all play like the prior
  /// defeats the purpose.
  static const double _k = 12;

  static double _blend(double observed, double prior, int n) {
    if (n <= 0) return prior;
    return (observed * n + prior * _k) / (n + _k);
  }

  /// Profile for a saved opponent. Falls back to the generic prior (with the
  /// opponent's name) when stats can't be loaded.
  static Future<DrillVillainProfile> profileFor(
      String opponentId, String name) async {
    OpponentStats? stats;
    try {
      stats = await OpponentStatsService.getOpponentStats(opponentId);
    } catch (_) {
      stats = null;
    }
    if (stats == null) {
      return DrillVillainProfile(
        opponentId: opponentId,
        name: name,
        handsObserved: 0,
        vpip: DrillVillainProfile.prior.vpip,
        pfr: DrillVillainProfile.prior.pfr,
        threeBet: DrillVillainProfile.prior.threeBet,
        fold3bet: DrillVillainProfile.prior.fold3bet,
        aggression: DrillVillainProfile.prior.aggression,
        archetype: 'Unknown',
      );
    }
    return fromStats(opponentId: opponentId, name: name, stats: stats);
  }

  /// Pure profile construction from stats (testable without Firestore).
  static DrillVillainProfile fromStats({
    required String opponentId,
    required String name,
    required OpponentStats stats,
  }) {
    const prior = DrillVillainProfile.prior;

    final vpip =
        _blend(stats.vpipPercentage, prior.vpip, stats.eligibleHands);
    final pfr = _blend(stats.pfrPercentage, prior.pfr, stats.eligibleHands);
    final threeBet = _blend(
        stats.threeBetPercentage, prior.threeBet, stats.threeBetOpportunity);
    final fold3bet = _blend(
        stats.fold3betPercentage, prior.fold3bet, stats.facing3BetCount);
    final aggression = _blend(stats.aggressionFrequency, prior.aggression,
        stats.aggressionActions + stats.passiveActions);

    // PlayStyleDetector wants an aggression FACTOR (bets+raises)/calls,
    // not the stored frequency — approximate it from action counters.
    final af = stats.callCount > 0
        ? stats.aggressionActions / stats.callCount
        : (stats.aggressionActions > 0 ? 4.0 : 2.0);

    final style = PlayStyleDetector.detectPlayStyle(
      vpip: vpip,
      pfr: pfr,
      threeBet: threeBet,
      aggressionFactor: af,
      handsPlayed: stats.handsPlayed,
    )['style'];

    return DrillVillainProfile(
      opponentId: opponentId,
      name: name,
      handsObserved: stats.handsPlayed,
      vpip: vpip.clamp(0, 100).toDouble(),
      pfr: pfr.clamp(0, 100).toDouble(),
      threeBet: threeBet.clamp(0, 100).toDouble(),
      fold3bet: fold3bet.clamp(0, 100).toDouble(),
      aggression: aggression.clamp(0, 100).toDouble(),
      archetype: style ?? 'Unknown',
    );
  }
}
