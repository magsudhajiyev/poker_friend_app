import '../l10n/app_localizations.dart';
import 'notification_copy.dart';
import 'paid_nudge_logic.dart';
import 'spot_quiz_logic.dart';

/// Localized, honest copy for the paid nudges — PURE (the caller passes the
/// [AppLocalizations]; see `AppL10nLookup` for the no-BuildContext lookup).
/// The coach voice is the coach NAME in the title plus the mascot icon; the
/// body text itself is neutral, with no false urgency, invented discount or
/// shaming.
class PaidNudgeCopy {
  PaidNudgeCopy._();

  /// Title + body for [type]. [stats] is used by the recap only (zero values
  /// omitted); [trialAvailable] switches the paywall-return body. Returns
  /// null when there is nothing honest to say (a recap with no real numbers).
  static (String, String)? build(
    AppLocalizations l10n,
    EngagementNotifType type, {
    required String coachName,
    TrialRecapStats stats = const TrialRecapStats(),
    bool trialAvailable = false,
  }) {
    switch (type) {
      case EngagementNotifType.trialRecap:
        final summary = recapSummary(l10n, stats);
        if (summary == null) return null;
        return (
          l10n.nudgeTitleWithCoach(coachName, l10n.nudgeRecapTitle),
          l10n.nudgeRecapBody(summary),
        );
      case EngagementNotifType.missedDay:
        return (
          l10n.nudgeTitleWithCoach(coachName, l10n.nudgeMissedTitle),
          l10n.nudgeMissedBody,
        );
      case EngagementNotifType.paywallReturn:
        return (
          l10n.nudgeTitleWithCoach(coachName, l10n.nudgePaywallTitle),
          trialAvailable
              ? l10n.nudgePaywallBodyTrial
              : l10n.nudgePaywallBody,
        );
      default:
        return null;
    }
  }

  /// "47 hands logged, 3 daily challenges played, 82% average accuracy" with
  /// zero values left out; null when nothing remains.
  static String? recapSummary(AppLocalizations l10n, TrialRecapStats s) {
    final parts = [
      if (s.hands > 0) l10n.nudgeRecapHands(s.hands),
      if (s.challenges > 0) l10n.nudgeRecapChallenges(s.challenges),
      if (s.accuracyRounded != null)
        l10n.nudgeRecapAccuracy(s.accuracyRounded!),
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// Spot-quiz push text from the REAL facts of [spot]: hole cards, hero
  /// position and what the villain did. Reveals no answer or frequency.
  static (String, String) spotQuiz(AppLocalizations l10n, SpotQuizSpot spot) {
    final pos = spot.villainPosition;
    final situation = switch (spot.villainMove) {
      null => l10n.spotQuizActionOnYou,
      SpotQuizVillainMove.opened => l10n.spotQuizVillainOpened(pos),
      SpotQuizVillainMove.raised => l10n.spotQuizVillainRaised(pos),
      SpotQuizVillainMove.bet => l10n.spotQuizVillainBet(pos),
      SpotQuizVillainMove.called => l10n.spotQuizVillainCalled(pos),
      SpotQuizVillainMove.checked => l10n.spotQuizVillainChecked(pos),
      SpotQuizVillainMove.allIn => l10n.spotQuizVillainAllIn(pos),
    };
    return (
      l10n.spotQuizTitle,
      l10n.spotQuizBody(spot.heroCards, spot.heroPosition, situation),
    );
  }
}
