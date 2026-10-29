import 'package:shared_preferences/shared_preferences.dart';

import 'coach_persona.dart';
import 'daily_challenge_service.dart';
import 'daily_challenge_store.dart';
import 'feature_flag_service.dart';
import 'logger_service.dart';
import 'notification_copy.dart';
import 'notification_events_service.dart';
import 'notification_prefs_service.dart';
import 'notification_service.dart';

/// Device-scheduled streak-saver — Phase 1 of the engagement plan.
///
/// On every completed Daily Challenge this (1) settles the previous pending
/// reminder (cancel it if it never fired, or stamp playedAt/converted if it
/// did — the exact-id handoff via SharedPreferences means no Firestore query
/// or index), then (2) schedules tomorrow's reminder at the user's reminder
/// hour, in TRUE local time via the existing zonedSchedule path. Works
/// offline; no server timezone needed (plan §4 Phase A).
///
/// Guardrails honored here: feature flag, the streak prefs category,
/// `debugDayOffset == 0` (admin test runs never schedule or log), and
/// streak ≥ 1 (no streak → nothing real at stake → no push). Quiet hours do
/// NOT apply — the streak-saver is the one policy-exempt late push.
class StreakSaverService {
  StreakSaverService._();

  /// Until the Phase-2 send-time job computes a per-user hour, remind at
  /// 19:00 local — early enough to act, late enough to be "tonight".
  static const int defaultReminderHour = 19;

  static const String payloadPrefix = 'engagement:';

  // Pending-event handoff (per device, which matches device scheduling).
  static const String _kEventId = 'streak_saver_event_id';
  static const String _kSentAtMs = 'streak_saver_sent_at_ms';

  /// Pure: tomorrow at [hour] local. The reminder always targets the NEXT
  /// day — today's challenge was just completed, so today is safe.
  static DateTime nextReminderTime(DateTime now, {int hour = defaultReminderHour}) {
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, hour);
  }

  /// Pure: the reminder time for a run of [runDay] completed at [now].
  /// Targets (runDay + 1 calendar day) at [hour] so a run that started before
  /// midnight and ended after it still protects the next unplayed day. Never
  /// in the past: if that time already passed, falls back to
  /// [nextReminderTime] (tomorrow relative to [now]).
  static DateTime reminderTimeForRun(DateTime runDay, DateTime now,
      {int hour = defaultReminderHour}) {
    final at = DateTime(runDay.year, runDay.month, runDay.day + 1, hour);
    return at.isAfter(now) ? at : nextReminderTime(now, hour: hour);
  }

  /// Pure: parse an `engagement:{type}:{eventId}` payload.
  static ({EngagementNotifType type, String eventId})? parsePayload(
      String? payload) {
    if (payload == null || !payload.startsWith(payloadPrefix)) return null;
    final parts = payload.substring(payloadPrefix.length).split(':');
    if (parts.length != 2) return null;
    final type = EngagementNotifType.fromId(parts[0]);
    if (type == null || parts[1].isEmpty) return null;
    return (type: type, eventId: parts[1]);
  }

  /// Call on every completed Daily Challenge. Settles the previous pending
  /// reminder, then schedules tomorrow's. Best-effort throughout.
  static Future<void> onChallengeCompleted({
    required int currentStreak,
    required String coachId,
    required int challengeNumber,
    required DateTime runDay,
  }) async {
    try {
      // Admin day-override runs never touch the real pipeline (same guard
      // as the leaderboard): no settle, no schedule, no log.
      if (DailyChallengeService.debugDayOffset != 0) return;

      await _settlePending(played: true);

      if (!FeatureFlagService.isEnabled(
          FeatureFlagService.engagementNotifications)) {
        return;
      }
      final prefs = await NotificationPrefsService.load();
      if (!prefs.categoryEnabled(NotifCategory.streak)) return;
      if (currentStreak < 1) return;

      final at = reminderTimeForRun(runDay, DateTime.now());
      final copy = NotificationCopy.copyFor(
        EngagementNotifType.dcStreakRisk,
        coachId,
        challengeNumber, // day number rotates the variant pool
        streak: currentStreak,
      );
      final eventId = await NotificationEventsService.logScheduled(
        type: EngagementNotifType.dcStreakRisk,
        coach: coachId,
        variantId: challengeNumber %
            NotificationCopy.variantCount(
                EngagementNotifType.dcStreakRisk, coachId),
        sentAt: at,
      );
      if (eventId == null) return; // signed out / offline — skip quietly

      await NotificationService.scheduleEngagementReminder(
        title: copy.title,
        body: copy.body,
        at: at,
        payload: '$payloadPrefix${EngagementNotifType.dcStreakRisk.id}:$eventId',
        coachId: coachId,
      );

      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kEventId, eventId);
      await sp.setInt(_kSentAtMs, at.millisecondsSinceEpoch);
    } catch (e) {
      LoggerService.warning('StreakSaver: scheduling failed: $e');
    }
  }

  /// Call when the user disables the streak category / master toggle so a
  /// queued reminder doesn't fire against their wishes.
  static Future<void> cancelPending() => _settlePending(played: false);

  /// Settle the persisted pending event, if any. When [played] and the
  /// reminder already fired, stamp playedAt + the 2h reward; when it hasn't
  /// fired yet (or [played] is false), cancel the local notification and
  /// mark the event cancelled.
  static Future<void> _settlePending({required bool played}) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final eventId = sp.getString(_kEventId);
      if (eventId == null) return;
      final sentAtMs = sp.getInt(_kSentAtMs) ?? 0;
      final sentAt = DateTime.fromMillisecondsSinceEpoch(sentAtMs);
      final fired = DateTime.now().isAfter(sentAt);

      if (fired && played) {
        await NotificationEventsService.markPlayed(eventId,
            sentAt: sentAt, type: EngagementNotifType.dcStreakRisk.id);
      } else {
        await NotificationService.cancelEngagementReminder();
        await NotificationEventsService.markCancelled(eventId);
      }
      await sp.remove(_kEventId);
      await sp.remove(_kSentAtMs);
    } catch (e) {
      LoggerService.warning('StreakSaver: settle failed: $e');
    }
  }

  /// Tap handler — called by NotificationService for `engagement:` payloads.
  static Future<void> onTapped(String payload) async {
    final parsed = parsePayload(payload);
    if (parsed == null) return;
    await NotificationEventsService.markOpened(parsed.eventId,
        type: parsed.type.id);
  }

  /// DEBUG — fire the streak-saver NOW instead of scheduling it for tomorrow,
  /// so the whole pipeline (event doc → tray notification → tap → open stamp →
  /// play reconcile) can be tested in one sitting. Logs a real
  /// `notification_events` doc with `source: 'debug'` and SHOWS the push
  /// immediately. Ignores quiet hours / flag / streak gating (it's a tester).
  static Future<void> debugFireNow({
    EngagementNotifType type = EngagementNotifType.dcStreakRisk,
    int streak = 7,
    int rank = 4,
  }) async {
    try {
      final coachId = (await CoachPersonas.load()).id;
      final day = DailyChallengeService.challengeNumber(DateTime.now());
      final copy = NotificationCopy.copyFor(type, coachId, day,
          streak: streak, rank: rank);
      final now = DateTime.now();
      final eventId = await NotificationEventsService.logScheduled(
        type: type,
        coach: coachId,
        variantId: day % NotificationCopy.variantCount(type, coachId),
        sentAt: now,
      );
      await NotificationService.showEngagementNow(
        title: copy.title,
        body: copy.body,
        payload: eventId == null
            ? 'engagement:${type.id}:debug'
            : 'engagement:${type.id}:$eventId',
        coachId: coachId,
      );
      // Persist as the pending event so completing a challenge reconciles it
      // into a conversion (the reward path).
      if (eventId != null) {
        final sp = await SharedPreferences.getInstance();
        await sp.setString(_kEventId, eventId);
        await sp.setInt(_kSentAtMs, now.millisecondsSinceEpoch);
      }
    } catch (e) {
      LoggerService.warning('StreakSaver: debugFireNow failed: $e');
    }
  }

  /// DEBUG — read back today's streak from local history so the tester can
  /// show a real streak number.
  static Future<int> debugCurrentStreak() async {
    final s = await DailyChallengeStore.streaks(DailyChallengeService.today());
    return s.current;
  }
}
