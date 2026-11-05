import 'package:cloud_firestore/cloud_firestore.dart';

import 'analytics_service.dart';
import 'auth_service.dart';
import 'logger_service.dart';
import 'notification_copy.dart';

/// The engagement-notification event log — one `notification_events` doc per
/// push, the pipeline the admin dashboard visualizes and the reward table a
/// future bandit trains on (see engagement-notifications-plan.md §2b).
///
/// Lifecycle of a device-scheduled push:
///   logScheduled (sentAt = the scheduled fire time, status implied by
///   timestamps) → either markCancelled (user played before it fired) or, if
///   it fired: markOpened (tap) and/or markPlayed (next challenge completion
///   stamps playedAt + convertedWithin2h, the Duolingo 2-hour reward).
///
/// Every method is best-effort/no-throw (the FeedPublisher/FCM contract) and
/// mirrors to PostHog so funnels exist in both stores.
class NotificationEventsService {
  NotificationEventsService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String collection = 'notification_events';

  /// The Duolingo reward window: a play within 2h of the push counts as
  /// converted-by-the-notification; later plays are treated as organic.
  static const Duration rewardWindow = Duration(hours: 2);

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Record a scheduled push. [sentAt] is the local fire time the device
  /// scheduled (for server sends it would be the actual send time). Returns
  /// the event id, or null on failure / signed-out. [category] tags offer
  /// pushes (`'offer'`) so the server scheduler / reward reconcile can tell
  /// them from streak and leaderboard pushes.
  static Future<String?> logScheduled({
    required EngagementNotifType type,
    required String coach,
    required int variantId,
    required DateTime sentAt,
    String? category,
  }) async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return null;
    try {
      final ref = await _db.collection(collection).add({
        'uid': uid,
        'type': type.id,
        'coach': coach,
        'variantId': variantId,
        'sentAt': Timestamp.fromDate(sentAt),
        'scheduledHourLocal': sentAt.hour,
        'dayKey': _dayKey(sentAt),
        'source': 'device',
        if (category != null) 'category': category,
        'createdAt': FieldValue.serverTimestamp(),
      });
      AnalyticsService.capture('notif_scheduled', {
        'type': type.id,
        'coach': coach,
        'variant': variantId,
        'hour': sentAt.hour,
      });
      return ref.id;
    } catch (e) {
      LoggerService.warning('NotifEvents: logScheduled failed: $e');
      return null;
    }
  }

  /// The push never fired — the user played first (or prefs changed).
  static Future<void> markCancelled(String eventId) async {
    try {
      await _db.collection(collection).doc(eventId).set({
        'cancelled': true,
        'cancelledAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      LoggerService.warning('NotifEvents: markCancelled failed: $e');
    }
  }

  /// The user tapped the notification.
  static Future<void> markOpened(String eventId, {String? type}) async {
    try {
      await _db.collection(collection).doc(eventId).set({
        'openedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      AnalyticsService.capture('notif_opened', {if (type != null) 'type': type});
    } catch (e) {
      LoggerService.warning('NotifEvents: markOpened failed: $e');
    }
  }

  /// The user completed a challenge after the push fired — stamp the play
  /// and the 2-hour reward. [sentAt] comes from the caller's persisted
  /// pending-event record, so no query or index is needed.
  static Future<void> markPlayed(String eventId,
      {required DateTime sentAt, String? type}) async {
    try {
      final now = DateTime.now();
      final converted = now.difference(sentAt) <= rewardWindow;
      await _db.collection(collection).doc(eventId).set({
        'playedAt': FieldValue.serverTimestamp(),
        'convertedWithin2h': converted,
      }, SetOptions(merge: true));
      if (converted) {
        AnalyticsService.capture('notif_converted', {
          if (type != null) 'type': type,
          'minutes_to_play': now.difference(sentAt).inMinutes,
        });
      }
    } catch (e) {
      LoggerService.warning('NotifEvents: markPlayed failed: $e');
    }
  }
}
