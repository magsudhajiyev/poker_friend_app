import 'notification_prefs_service.dart';
import 'subscription_logic.dart'
    show TrialReminderAction, TrialStatus, decideTrialReminder;

/// What [PaidNudgeLogic.syncGate] allows a sync to do.
enum NudgeSyncGate { wait, cancelAll, run }

/// Pure decisions for the paid nudges (trial recap, missed day, paywall
/// return) — no IO, no Flutter, fully unit-tested. [PaidNudgeService] does
/// the scheduling; every rule about WHEN and WHETHER lives here.
class PaidNudgeLogic {
  PaidNudgeLogic._();

  /// Pure: what [PaidNudgeService.sync] may do. Until the flag AND admin
  /// state are known (cold start) it must do nothing — a transient "flag
  /// off" would cancel queued nudges and reschedule them with new event docs.
  /// Signed out is handled by the explicit sign-out cleanup, not by sync.
  static NudgeSyncGate syncGate({
    required bool stateKnown,
    required bool signedIn,
    required bool flagOn,
  }) {
    if (!stateKnown || !signedIn) return NudgeSyncGate.wait;
    return flagOn ? NudgeSyncGate.run : NudgeSyncGate.cancelAll;
  }

  /// At most this many offer pushes inside any rolling [offerWindow].
  static const int maxOffersPerWindow = 2;
  static const Duration offerWindow = Duration(days: 7);

  /// Nothing is scheduled to fire this long after the last app open.
  static const Duration inactivityLimit = Duration(days: 14);

  /// A user who keeps leaving the paywall gets at most this many returns.
  static const int maxPaywallReturnsLifetime = 2;

  /// A scheduled time must be at least this far ahead to be worth queuing.
  static const Duration minLead = Duration(minutes: 30);

  static bool sameLocalDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Pure: [hour] moved out of the user's quiet window (to its end hour).
  /// Offers are NOT quiet-hours exempt.
  static int outOfQuietHours(int hour, NotificationPrefs prefs) =>
      prefs.isQuietHour(hour) ? prefs.quietEndLocal : hour;

  /// Pure: whether adding [candidate] keeps every rolling 7-day window at
  /// ≤ [maxOffersPerWindow] offer pushes, given the already-scheduled
  /// [existing] ones.
  static bool withinOfferCap(List<DateTime> existing, DateTime candidate) {
    final all = [...existing, candidate]..sort();
    for (var i = 0; i + maxOffersPerWindow < all.length; i++) {
      if (all[i + maxOffersPerWindow].difference(all[i]) < offerWindow) {
        return false;
      }
    }
    return true;
  }

  /// Pure: one engagement push per local day — true when [candidate]'s day
  /// is free of every time in [others] (streak reminder + other nudges).
  static bool dayIsFree(List<DateTime> others, DateTime candidate) =>
      !others.any((o) => sameLocalDay(o, candidate));

  /// Pure: [fireAt] lies 14+ days after the user last opened the app.
  static bool tooInactive(DateTime lastActive, DateTime fireAt) =>
      fireAt.difference(lastActive) >= inactivityLimit;

  /// Pure: the first moment an offer may be queued for: tomorrow 00:00. The
  /// device cannot see a server push already sent today, so an offer is never
  /// queued for the current local day.
  static DateTime earliestOfferTime(DateTime now) =>
      DateTime(now.year, now.month, now.day + 1);

  /// Pure: [at] moved to the next day (same clock time) when it falls on or
  /// before today; unchanged otherwise.
  static DateTime notBeforeTomorrow(DateTime at, DateTime now) {
    final earliest = earliestOfferTime(now);
    return at.isBefore(earliest)
        ? DateTime(
            earliest.year, earliest.month, earliest.day, at.hour, at.minute)
        : at;
  }

  /// Pure: `runDay + 2` at [hour] — "you missed yesterday" for a user who
  /// completed on [runDay]. Null when that moment is not far enough ahead.
  static DateTime? missedDayTime(DateTime runDay, DateTime now, int hour) {
    final at = DateTime(runDay.year, runDay.month, runDay.day + 2, hour);
    if (at.isBefore(earliestOfferTime(now))) return null;
    return at.isAfter(now.add(minLead)) ? at : null;
  }

  /// Pure: the calendar day the missed-day push is about (the day after the
  /// completed [runDay]).
  static DateTime missedDayTarget(DateTime runDay) =>
      DateTime(runDay.year, runDay.month, runDay.day + 1);

  /// Pure: roughly 24h from [now], landing on [hour] local — the first such
  /// hour at least 20h ahead (so 20–44h).
  static DateTime paywallReturnTime(DateTime now, int hour) {
    var at = DateTime(now.year, now.month, now.day + 1, hour);
    if (at.difference(now) < const Duration(hours: 20)) {
      at = DateTime(at.year, at.month, at.day + 1, hour);
    }
    return notBeforeTomorrow(at, now);
  }

  /// Pure: when the recap fires for [trial] — one day before the existing
  /// charge reminder, at [hour] local. Null when the trial will not renew,
  /// the charge reminder is not a future schedule, or the recap moment would
  /// not be at least [minLead] ahead / would land after the charge reminder.
  static DateTime? trialRecapTime(TrialStatus? trial, DateTime now, int hour) {
    final decision = decideTrialReminder(trial, now);
    if (decision.action != TrialReminderAction.schedule) return null;
    final reminder = decision.at!;
    final day = reminder.subtract(const Duration(hours: 24));
    // Never today: shift to tomorrow (still must precede the reminder).
    final at =
        notBeforeTomorrow(DateTime(day.year, day.month, day.day, hour), now);
    if (!at.isAfter(now.add(minLead))) return null;
    // Never later than the charge reminder it precedes.
    return at.isBefore(reminder) ? at : null;
  }
}

/// The real numbers a trial recap may state. Zero values are omitted; when
/// nothing is left there is nothing to send.
class TrialRecapStats {
  final int hands;
  final int challenges;

  /// Mean day accuracy 0..100 over played challenges, or null if none.
  final double? accuracyPct;

  const TrialRecapStats({
    this.hands = 0,
    this.challenges = 0,
    this.accuracyPct,
  });

  int? get accuracyRounded => accuracyPct == null || accuracyPct!.round() <= 0
      ? null
      : accuracyPct!.round();

  bool get hasAnything =>
      hands > 0 || challenges > 0 || accuracyRounded != null;
}
