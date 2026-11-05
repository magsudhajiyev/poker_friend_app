import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/paywall_screen.dart';
import '../screens/training/daily_challenge_calendar_screen.dart';
import '../screens/training/daily_challenge_screen.dart';
import '../screens/training/daily_replay_screen.dart';
import 'analytics_service.dart';
import 'app_l10n_lookup.dart';
import 'authored_tree_service.dart';
import 'auth_service.dart';
import 'coach_persona.dart';
import 'daily_challenge_service.dart';
import 'daily_challenge_store.dart';
import 'daily_replay_limits.dart';
import 'feature_flag_service.dart';
import 'logger_service.dart';
import 'notification_copy.dart';
import 'notification_events_service.dart';
import 'notification_prefs_service.dart';
import 'notification_service.dart';
import 'paid_nudge_copy.dart';
import 'paid_nudge_logic.dart';
import 'personal_hour_service.dart';
import 'spot_quiz_logic.dart';
import 'streak_saver_service.dart';
import 'subscription_logic.dart';
import 'subscription_service.dart';
import 'user_stats_service.dart';

/// Opt-in paid nudges (flag `paid_nudges`, consent `notif.offers`):
///
/// - `trial_recap`: one push a day before the existing trial-charge reminder,
///   stating REAL numbers only (hands logged, challenges played, accuracy).
///   Re-synced on every app open / entitlement change so the numbers are as
///   fresh as the last open. Never replaces or delays the charge reminder.
/// - `missed_day`: after a completed challenge, `runDay + 2` at the personal
///   hour; cancelled and re-queued on the next completion. Tap → replay of
///   the missed day (unranked; tier limits apply).
/// - `spot_quiz`: a real past authored hand (1-3 days old) asked as a
///   question with up to 3 action buttons; a button or the body opens the
///   unranked replay of that hand, the tapped action pre-applied. Lowest
///   priority: it only fills gaps in the caps and yields to the other offers.
/// - `paywall_return`: a non-subscriber who opened the paywall without
///   starting a trial gets ONE push ~24h later (max 2 per lifetime),
///   cancelled on purchase. Tap → paywall.
///
/// Device-scheduled (the client knows the true tier via [SubscriptionService];
/// the server's mirrored tier is empty). All WHEN/WHETHER rules are pure in
/// [PaidNudgeLogic]; this layer only does IO and never throws. Tap routing
/// rides the shared `engagement:{type}:{eventId}` payload.
///
/// Each push is logged to `notification_events` with `category: 'offer'`.
class PaidNudgeService {
  PaidNudgeService._();

  // Per-account keys (suffix `_{uid}`): a new account on this device starts
  // with no queued/sent history and its own paywall-return count.
  static const _kRecordsBase = 'paid_nudge_records';
  static const _kPaywallReturnsBase = 'paid_nudge_paywall_returns';
  static const _kMissedTarget = 'paid_nudge_missed_target_';
  static const _kQuizTarget = 'paid_nudge_quiz_target_';
  static const String category = 'offer';

  static StreamSubscription<Object?>? _sub;
  static bool _flagListening = false;

  static String get _recordsKey =>
      '${_kRecordsBase}_${AuthService.currentUser?.uid ?? 'none'}';
  static String get _paywallKey =>
      '${_kPaywallReturnsBase}_${AuthService.currentUser?.uid ?? 'none'}';

  static bool get _flagOn =>
      FeatureFlagService.isEnabled(FeatureFlagService.paidNudges);

  static int _slot(EngagementNotifType t) => switch (t) {
        EngagementNotifType.trialRecap =>
          NotificationService.engagementSlotTrialRecap,
        EngagementNotifType.missedDay =>
          NotificationService.engagementSlotMissedDay,
        EngagementNotifType.spotQuiz =>
          NotificationService.engagementSlotSpotQuiz,
        _ => NotificationService.engagementSlotPaywallReturn,
      };

  /// Start listening (idempotent). Call once after SubscriptionService init.
  static void start() {
    _sub ??=
        SubscriptionService.entitlementsStream.listen((_) => unawaited(sync()));
    if (!_flagListening) {
      _flagListening = true;
      FeatureFlagService.revision.addListener(() => unawaited(sync()));
    }
    unawaited(sync());
  }

  /// Bring all queued nudges in line with flag, consent, tier and trial.
  /// Cheap when the flag is off. Never throws.
  static Future<void> sync() async {
    try {
      switch (PaidNudgeLogic.syncGate(
        stateKnown: FeatureFlagService.stateKnown,
        signedIn: AuthService.currentUser != null,
        flagOn: _flagOn,
      )) {
        case NudgeSyncGate.wait:
          return; // cold start: flag/admin state not settled yet
        case NudgeSyncGate.cancelAll:
          await _cancelAll();
          return;
        case NudgeSyncGate.run:
          break;
      }
      final prefs = await NotificationPrefsService.ensureLoaded();
      if (!prefs.categoryEnabled(NotifCategory.offers)) {
        await _cancelAll();
        return;
      }
      if (SubscriptionService.isPremium) {
        await _settle(EngagementNotifType.paywallReturn);
      }
      await _syncTrialRecap(prefs);
      await _syncSpotQuiz(prefs, replace: false);
    } catch (e) {
      LoggerService.warning('PaidNudge: sync failed: $e');
    }
  }

  /// Sign-out cleanup (best-effort, called BEFORE the auth sign-out): cancel
  /// every queued nudge notification, clear this account's records and
  /// mark the pending events cancelled — so none of this account's pushes
  /// can fire for the next one. Never throws; the event-doc writes are
  /// bounded so an offline device cannot stall sign-out.
  static Future<void> onSignOut() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final pending = [
        for (final r in await _records(sp))
          if (r.at.isAfter(DateTime.now())) r.eventId,
      ];
      for (final t in _nudgeTypes) {
        await NotificationService.cancelEngagementPush(_slot(t));
      }
      await sp.remove(_recordsKey);
      for (final id in pending) {
        await NotificationEventsService.markCancelled(id)
            .timeout(const Duration(milliseconds: 800), onTimeout: () {});
      }
    } catch (e) {
      LoggerService.warning('PaidNudge: sign-out cleanup failed: $e');
    }
  }

  static const _nudgeTypes = [
    EngagementNotifType.trialRecap,
    EngagementNotifType.missedDay,
    EngagementNotifType.paywallReturn,
    EngagementNotifType.spotQuiz,
  ];

  /// The user turned offers off (or the flag/master did): drop every queued
  /// nudge. Called by Settings.
  static Future<void> onOffersChanged() => sync();

  // ── Triggers ──────────────────────────────────────────────────────────

  /// A ranked Daily Challenge was just completed on [runDay].
  static Future<void> onChallengeCompleted({
    required DateTime runDay,
    required String coachId,
  }) async {
    try {
      if (DailyChallengeService.debugDayOffset != 0) return;
      final prefs = await _allowedPrefs();
      if (prefs == null) return;
      // Replaces any queued missed-day push (cancel-on-next-completion).
      await _settle(EngagementNotifType.missedDay);
      final hour = PaidNudgeLogic.outOfQuietHours(
          await PersonalHourService.localHour(), prefs);
      final at = PaidNudgeLogic.missedDayTime(runDay, DateTime.now(), hour);
      if (at != null) {
        final target = PaidNudgeLogic.missedDayTarget(runDay);
        await _schedule(
          type: EngagementNotifType.missedDay,
          at: at,
          coachId: coachId,
          prefs: prefs,
          targetDayKey: DailyChallengeStore.dayKey(target),
        );
      }
      await _syncSpotQuiz(prefs, replace: true, coachId: coachId);
    } catch (e) {
      LoggerService.warning('PaidNudge: onChallengeCompleted failed: $e');
    }
  }

  /// The paywall was opened by a user who may leave without subscribing.
  static Future<void> onPaywallOpened() async {
    try {
      if (SubscriptionService.isPremium) return;
      final prefs = await _allowedPrefs();
      if (prefs == null) return;
      final sp = await SharedPreferences.getInstance();
      final pending =
          _pending(await _records(sp), EngagementNotifType.paywallReturn);
      // A push already queued stays; a NEW one counts against the lifetime cap.
      if (pending == null &&
          (sp.getInt(_paywallKey) ?? 0) >=
              PaidNudgeLogic.maxPaywallReturnsLifetime) {
        return;
      }
      final hour = PaidNudgeLogic.outOfQuietHours(
          await PersonalHourService.localHour(), prefs);
      final at = PaidNudgeLogic.paywallReturnTime(DateTime.now(), hour);
      final coach = await CoachPersonas.load();
      final scheduled = await _schedule(
        type: EngagementNotifType.paywallReturn,
        at: at,
        coachId: coach.id,
        prefs: prefs,
      );
      if (scheduled && pending == null) {
        await sp.setInt(
            _paywallKey, (sp.getInt(_paywallKey) ?? 0) + 1);
      }
    } catch (e) {
      LoggerService.warning('PaidNudge: onPaywallOpened failed: $e');
    }
  }

  // ── Trial recap ───────────────────────────────────────────────────────

  static Future<void> _syncTrialRecap(NotificationPrefs prefs) async {
    final hour = PaidNudgeLogic.outOfQuietHours(
        await PersonalHourService.localHour(), prefs);
    final at = PaidNudgeLogic.trialRecapTime(
        SubscriptionService.trialStatus, DateTime.now(), hour);
    if (at == null) {
      await _settle(EngagementNotifType.trialRecap);
      return;
    }
    final coach = await CoachPersonas.load();
    final stats = await _loadStats();
    final scheduled = await _schedule(
      type: EngagementNotifType.trialRecap,
      at: at,
      coachId: coach.id,
      prefs: prefs,
      stats: stats,
    );
    if (!scheduled) await _settle(EngagementNotifType.trialRecap);
  }

  static Future<TrialRecapStats> _loadStats() async {
    try {
      final uid = AuthService.currentUser?.uid;
      final hands = uid == null
          ? 0
          : (await UserStatsService.getUserStats(uid)
                      .timeout(const Duration(seconds: 4)))
                  ?.totalHands ??
              0;
      final results = (await DailyChallengeStore.allResults()).values.toList();
      final acc = results.isEmpty
          ? null
          : results.map((r) => r.score).reduce((a, b) => a + b) /
              results.length;
      return TrialRecapStats(
          hands: hands, challenges: results.length, accuracyPct: acc);
    } catch (e) {
      LoggerService.warning('PaidNudge: stats failed: $e');
      return const TrialRecapStats();
    }
  }

  // ── Spot quiz ─────────────────────────────────────────────────────────

  /// Queue (or keep) the spot-quiz push. [replace] (a completed challenge)
  /// drops the queued one and picks again; a plain sync keeps a queued one.
  /// Schedules nothing when no real authored past hand can be asked.
  static Future<void> _syncSpotQuiz(NotificationPrefs prefs,
      {required bool replace, String? coachId}) async {
    if (DailyChallengeService.debugDayOffset != 0) return;
    final uid = AuthService.currentUser?.uid;
    if (uid == null || !DailyReplayLimits.canReplayAny) {
      await _settle(EngagementNotifType.spotQuiz);
      return;
    }
    final sp = await SharedPreferences.getInstance();
    var records = await _records(sp);
    if (!replace && _pending(records, EngagementNotifType.spotQuiz) != null) {
      return;
    }
    final now = DateTime.now();
    final hour = PaidNudgeLogic.outOfQuietHours(
        await PersonalHourService.localHour(), prefs);
    final streakAt = await StreakSaverService.pendingReminderAt();
    final others = [
      for (final r in records)
        if (r.type != EngagementNotifType.spotQuiz) r.at,
      if (streakAt != null) streakAt,
    ];
    final at = SpotQuizLogic.fireTime(now, hour, others);
    if (at == null) {
      await _settle(EngagementNotifType.spotQuiz);
      return;
    }
    final picked = await _pickSpot(uid, at);
    if (picked == null) {
      await _settle(EngagementNotifType.spotQuiz);
      return;
    }
    final coach = coachId ?? (await CoachPersonas.load()).id;
    final (copy, target) = (
      PaidNudgeCopy.spotQuiz(AppL10nLookup.current(), picked.spot),
      SpotQuizLogic.encodeTarget(picked.dayKey, picked.spot.treeId),
    );
    final scheduled = await _schedule(
      type: EngagementNotifType.spotQuiz,
      at: at,
      coachId: coach,
      prefs: prefs,
      copyOverride: copy,
      buttons: picked.spot.buttons,
      quizTarget: target,
    );
    if (!scheduled) await _settle(EngagementNotifType.spotQuiz);
  }

  /// The past authored hand to ask about for a push firing at [at]: a
  /// replayable day 1-3 days before it that has a REAL schedule (Firestore
  /// day doc, or the bundled one when the server confirmed none) — never an
  /// RNG day, never an errored read. Deterministic per uid and fire day.
  static Future<({SpotQuizSpot spot, String dayKey})?> _pickSpot(
      String uid, DateTime at) async {
    final today = DailyChallengeService.today();
    final days = SpotQuizLogic.candidateDays(at);
    final fireKey = DailyChallengeStore.dayKey(at);
    final start = SpotQuizLogic.pickStart(uid, fireKey, 'day', days.length);
    for (var i = 0; i < days.length; i++) {
      final day = days[(start + i) % days.length];
      if (!DailyReplayLimits.isReplayable(day, today)) continue;
      final key = DailyChallengeStore.dayKey(day);
      final plan = await AuthoredTreeService.loadDaySchedule(key);
      final trees = plan.trees;
      if (trees == null ||
          (plan.source != DaySource.firestore &&
              plan.source != DaySource.bundledConfirmedMissing)) {
        continue;
      }
      final first = SpotQuizLogic.pickStart(uid, key, 'hand', trees.length);
      for (var j = 0; j < trees.length; j++) {
        final spot = SpotQuizLogic.spotFor(trees[(first + j) % trees.length]);
        if (spot != null) return (spot: spot, dayKey: key);
      }
    }
    return null;
  }

  // ── Scheduling core ───────────────────────────────────────────────────

  /// Flag + sign-in + consent gate. Returns the prefs when nudges are allowed.
  static Future<NotificationPrefs?> _allowedPrefs() async {
    if (!_flagOn || AuthService.currentUser == null) return null;
    final prefs = await NotificationPrefsService.ensureLoaded();
    return prefs.categoryEnabled(NotifCategory.offers) ? prefs : null;
  }

  /// Queue [type] at [at], enforcing every cap. Replaces this type's queued
  /// push (same event doc when the time is unchanged, so repeated syncs don't
  /// spam `notification_events`). Returns whether a push is now queued.
  static Future<bool> _schedule({
    required EngagementNotifType type,
    required DateTime at,
    required String coachId,
    required NotificationPrefs prefs,
    TrialRecapStats stats = const TrialRecapStats(),
    String? targetDayKey,
    (String, String)? copyOverride,
    List<SpotQuizAction> buttons = const [],
    String? quizTarget,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final now = DateTime.now();
    // An offer is never queued for the current local day (a server push may
    // already have gone out today and is invisible here).
    if (at.isBefore(PaidNudgeLogic.earliestOfferTime(now))) return false;
    var records = await _records(sp);
    final existing = _pending(records, type);

    final l10n = AppL10nLookup.current();
    final coach = CoachPersonas.byId(coachId);
    final copy = copyOverride ??
        PaidNudgeCopy.build(l10n, type,
            coachName: coach.name,
            stats: stats,
            trialAvailable: _trialAvailable());
    if (copy == null) return false; // nothing real to say

    final others = records.where((r) => r != existing).toList();
    final streakAt = await StreakSaverService.pendingReminderAt();
    bool blockedBy(Iterable<_NudgeRecord> rs) {
      final times = rs.map((r) => r.at).toList();
      return !PaidNudgeLogic.withinOfferCap(times, at) ||
          !PaidNudgeLogic.dayIsFree(
              [...times, if (streakAt != null) streakAt], at);
    }

    var blocked = blockedBy(others);
    // Priority: every other offer outranks a queued spot quiz — it is dropped
    // when (and only when) it is what stands in the way.
    final quiz = type == EngagementNotifType.spotQuiz
        ? null
        : _pending(others, EngagementNotifType.spotQuiz);
    if (blocked && quiz != null && !blockedBy(others.where((r) => r != quiz))) {
      await _settle(EngagementNotifType.spotQuiz);
      blocked = false;
    }
    if (blocked || PaidNudgeLogic.tooInactive(now, at)) return false;

    String? eventId;
    final sameQuiz = quizTarget == null ||
        (existing != null &&
            sp.getString('$_kQuizTarget${existing.eventId}') == quizTarget);
    if (existing != null && existing.at == at && sameQuiz) {
      eventId = existing.eventId; // same moment: refresh the text only
    } else {
      await _settle(type);
      eventId = await NotificationEventsService.logScheduled(
        type: type,
        coach: coachId,
        variantId: 0,
        sentAt: at,
        category: category,
      );
      if (eventId == null) return false; // signed out / offline — skip quietly
    }
    await NotificationService.scheduleEngagementPush(
      id: _slot(type),
      title: copy.$1,
      body: copy.$2,
      at: at,
      payload: '${StreakSaverService.payloadPrefix}${type.id}:$eventId',
      coachId: coachId,
      buttons: buttons,
    );
    if (targetDayKey != null) {
      await sp.setString('$_kMissedTarget$eventId', targetDayKey);
    }
    if (quizTarget != null) {
      await sp.setString('$_kQuizTarget$eventId', quizTarget);
    }
    records = await _records(sp); // _settle may have rewritten the list
    records.removeWhere((r) => r.eventId == eventId);
    records.add(_NudgeRecord(type, eventId, at));
    await _saveRecords(sp, records);
    return true;
  }

  /// Whether the store currently offers ANY free trial (read from the store;
  /// no length or price is ever hardcoded). Wording stays length-free.
  static bool _trialAvailable() {
    const ids = [
      kPkgProMonthly,
      kPkgProAnnual,
      kPkgEliteMonthly,
      kPkgEliteAnnual,
      kPkgClubMonthly,
      kPkgClubAnnual,
    ];
    return ids.any((id) => SubscriptionService.trialFor(id) != null);
  }

  /// Drop the queued push of [type]: cancel the notification and mark its
  /// event cancelled — unless it already fired (then it was really sent).
  static Future<void> _settle(EngagementNotifType type) async {
    final sp = await SharedPreferences.getInstance();
    final records = await _records(sp);
    final pending = _pending(records, type);
    if (pending == null) return;
    await NotificationService.cancelEngagementPush(_slot(type));
    await NotificationEventsService.markCancelled(pending.eventId);
    records.remove(pending);
    await _saveRecords(sp, records);
  }

  static Future<void> _cancelAll() async {
    final sp = await SharedPreferences.getInstance();
    if ((await _records(sp)).isEmpty) return;
    for (final t in _nudgeTypes) {
      await _settle(t);
    }
  }

  // ── Records ───────────────────────────────────────────────────────────

  static _NudgeRecord? _pending(
      List<_NudgeRecord> records, EngagementNotifType type) {
    final now = DateTime.now();
    for (final r in records) {
      if (r.type == type && r.at.isAfter(now)) return r;
    }
    return null;
  }

  /// Every offer push scheduled in the last 8 days (sent or still queued) —
  /// the history the rolling caps need.
  static Future<List<_NudgeRecord>> _records(SharedPreferences sp) async {
    try {
      final raw = sp.getString(_recordsKey);
      if (raw == null) return [];
      final cutoff = DateTime.now().subtract(const Duration(days: 8));
      return [
        for (final m in (jsonDecode(raw) as List))
          if (_NudgeRecord.tryParse(m) case final r? when r.at.isAfter(cutoff))
            r,
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveRecords(
          SharedPreferences sp, List<_NudgeRecord> records) =>
      sp.setString(
          _recordsKey, jsonEncode(records.map((r) => r.toJson()).toList()));

  // ── Tap routing ───────────────────────────────────────────────────────

  /// Open the destination of a tapped paid-nudge push on [nav]. Returns false
  /// for any other type so the caller falls back to the Daily Challenge.
  static Future<bool> open(
      NavigatorState nav, EngagementNotifType type, String eventId,
      {String? action}) async {
    try {
      switch (type) {
        case EngagementNotifType.spotQuiz:
          final sp = await SharedPreferences.getInstance();
          final target =
              SpotQuizLogic.decodeTarget(sp.getString('$_kQuizTarget$eventId'));
          final day = target == null ? null : DateTime.tryParse(target.dayKey);
          final button = SpotQuizAction.fromId(action);
          // The ONE site of the answered event (a button, not a body tap).
          if (button != null) {
            AnalyticsService.capture(
                'spot_quiz_answered', {'action': button.id});
          }
          // Same gate as missed_day: the calendar applies the tier limits
          // (and the upsell) whenever this tier may not replay the day.
          final direct = day != null &&
              DailyReplayLimits.isReplayable(
                  day, DailyChallengeService.today());
          await nav.push(MaterialPageRoute(
              builder: (_) => direct
                  ? DailyReplayScreen(
                      day: day,
                      focusTreeId: target!.treeId,
                      autoAction: button?.action)
                  : const DailyChallengeCalendarScreen()));
          return true;
        case EngagementNotifType.missedDay:
          final sp = await SharedPreferences.getInstance();
          final key = sp.getString('$_kMissedTarget$eventId');
          final day = key == null ? null : DateTime.tryParse(key);
          // The calendar applies the tier limits (and upsells beyond them);
          // open the day directly only when this tier may replay it.
          final direct = day != null &&
              DailyReplayLimits.isReplayable(
                  day, DailyChallengeService.today());
          await nav.push(MaterialPageRoute(
              builder: (_) => direct
                  ? DailyReplayScreen(day: day)
                  : const DailyChallengeCalendarScreen()));
          return true;
        case EngagementNotifType.trialRecap:
          await nav.push(
              MaterialPageRoute(builder: (_) => const DailyChallengeScreen()));
          return true;
        case EngagementNotifType.paywallReturn:
          if (SubscriptionService.isPremium) {
            await nav.push(MaterialPageRoute(
                builder: (_) => const DailyChallengeScreen()));
          } else {
            await PaywallScreen.show(nav.context,
                featureName: 'paywall_return_push');
          }
          return true;
        default:
          return false;
      }
    } catch (e) {
      LoggerService.warning('PaidNudge: open failed: $e');
      return false;
    }
  }
}

class _NudgeRecord {
  final EngagementNotifType type;
  final String eventId;
  final DateTime at;
  const _NudgeRecord(this.type, this.eventId, this.at);

  Map<String, dynamic> toJson() =>
      {'t': type.id, 'e': eventId, 'ms': at.millisecondsSinceEpoch};

  static _NudgeRecord? tryParse(dynamic m) {
    if (m is! Map) return null;
    final type = EngagementNotifType.fromId(m['t']?.toString());
    final id = m['e']?.toString();
    final ms = (m['ms'] as num?)?.toInt();
    if (type == null || id == null || ms == null) return null;
    return _NudgeRecord(type, id, DateTime.fromMillisecondsSinceEpoch(ms));
  }
}
