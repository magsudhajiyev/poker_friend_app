import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';
import 'play_style_detector.dart';
import 'user_stats_service.dart';

/// The three coaching tiers. Each coach keeps its character but changes
/// tone + depth per tier: beginner = warm/simple, advanced = blunt/technical.
enum CoachLevel { beginner, intermediate, advanced }

extension CoachLevelId on CoachLevel {
  /// Stable wire id for Firestore keys and the Claude prompt.
  String get id => switch (this) {
        CoachLevel.beginner => 'beginner',
        CoachLevel.intermediate => 'intermediate',
        CoachLevel.advanced => 'advanced',
      };

  static CoachLevel fromId(String? id) => switch (id) {
        'advanced' => CoachLevel.advanced,
        'intermediate' => CoachLevel.intermediate,
        _ => CoachLevel.beginner,
      };
}

/// Resolves a player's coaching tier from two signals:
///  - PRIMARY: real play once they have a meaningful sample
///    ([_minHandsForStats]) — measured, self-correcting.
///  - SEED: the onboarding "poker journey" self-report, used while the
///    stats sample is thin (new users).
///
/// Pure functions (unit-tested); the IO wrapper that reads Firestore lives
/// in the caller / Cloud Function.
class CoachLevelResolver {
  CoachLevelResolver._();

  /// Below this hand count, stats are not trusted — fall back to the
  /// self-report. Matches the detector's own reliability gate (50) with
  /// headroom so the classification is firmly in its confident band.
  static const int minHandsForStats = 150;

  /// Onboarding `pokerJourney` ('beginner'|'fun'|'regular'|'pro') → tier.
  /// Missing/unknown → beginner (the safe, welcoming default).
  static CoachLevel fromJourney(String? pokerJourney) => switch (pokerJourney) {
        'pro' => CoachLevel.advanced,
        'regular' => CoachLevel.intermediate,
        'beginner' => CoachLevel.beginner,
        'fun' => CoachLevel.beginner,
        _ => CoachLevel.beginner,
      };

  /// PlayStyleDetector style → tier. A clearly-formed solid profile reads
  /// as advanced; developing/passive profiles as intermediate; only a
  /// zeroed/unknown profile as beginner.
  static CoachLevel fromPlayStyle(String style) => switch (style) {
        'TAG' || 'LAG' || 'Maniac' || 'Balanced' => CoachLevel.advanced,
        'Nit' ||
        'Calling Station' ||
        'Tight-Passive' ||
        'Loose-Passive' =>
          CoachLevel.intermediate,
        _ => CoachLevel.beginner, // 'Unknown' or anything unexpected
      };

  /// The full resolution. Uses stats once the sample is big enough,
  /// otherwise the journey seed. All inputs are plain values so this is
  /// trivially testable and reusable server-side.
  ///
  /// [aggressionFactor] = pfr / (vpip - pfr), computed by the caller since
  /// UserStats does not carry it; pass 0 when vpip<=pfr.
  static CoachLevel resolve({
    required String? pokerJourney,
    required int handsPlayed,
    required double vpip,
    required double pfr,
    required double threeBet,
    required double aggressionFactor,
  }) {
    if (handsPlayed >= minHandsForStats) {
      final style = PlayStyleDetector.detectPlayStyle(
        vpip: vpip,
        pfr: pfr,
        threeBet: threeBet,
        aggressionFactor: aggressionFactor,
        handsPlayed: handsPlayed,
      )['style']!;
      return fromPlayStyle(style);
    }
    return fromJourney(pokerJourney);
  }

  /// Aggression factor from VPIP/PFR percentages (pure helper). 0 when
  /// the player raises as often as they play (avoids divide-by-zero).
  static double aggressionFactorFrom(double vpip, double pfr) {
    final passive = vpip - pfr;
    if (passive <= 0) return 0;
    return pfr / passive;
  }

  // ── IO wrapper (current user) ───────────────────────────────────────

  /// Debug/admin override: when set, [resolveForCurrentUser] returns this
  /// instead of the real resolution, so the tester can mimic each tier.
  /// Null = normal resolution. Admin-only screen sets it; not persisted.
  static CoachLevel? debugOverride;

  /// Resolves the signed-in player's tier from Firestore. Reads
  /// `user_stats/{uid}` + `users/{uid}.onboardingData.pokerJourney`.
  /// Never throws — on any error returns [CoachLevel.beginner] (the
  /// welcoming default). Not cached; call once per challenge.
  static Future<CoachLevel> resolveForCurrentUser() async {
    if (debugOverride != null) return debugOverride!;
    try {
      final uid = AuthService.currentUser?.uid;
      if (uid == null) return CoachLevel.beginner;

      final journey = await _fetchJourney(uid);
      final stats = await UserStatsService.getUserStats(uid);
      if (stats == null) return fromJourney(journey);

      return resolve(
        pokerJourney: journey,
        handsPlayed: stats.handsPlayed,
        vpip: stats.vpipPercentage,
        pfr: stats.pfrPercentage,
        threeBet: stats.threeBetPercentage,
        aggressionFactor: aggressionFactorFrom(
            stats.vpipPercentage, stats.pfrPercentage),
      );
    } catch (_) {
      return CoachLevel.beginner;
    }
  }

  static Future<String?> _fetchJourney(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final onboarding = doc.data()?['onboardingData'];
      if (onboarding is Map) return onboarding['pokerJourney'] as String?;
      return null;
    } catch (_) {
      return null;
    }
  }
}
