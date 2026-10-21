import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../design_system/constants/colors.dart';
import '../screens/paywall_screen.dart';
import '../screens/training/daily_challenge_screen.dart';
import 'auth_service.dart';
import 'coach_icon_service.dart';
import 'streak_saver_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Root navigator key, injected from main.dart before [initialize] so
  /// notification taps can route (e.g. promo expiry → paywall).
  static GlobalKey<NavigatorState>? navigatorKey;

  static const _promoPayloads = {'promo_expiry_warning', 'promo_expired'};

  /// Initialize the notification service
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize timezone data
      tz.initializeTimeZones();

      // Android initialization settings (default small icon: white logo
      // silhouette — full-colour launcher icons render as a blank blob in
      // the status bar because Android only uses the alpha channel there)
      const androidSettings =
          AndroidInitializationSettings('@drawable/ic_notification');

      // iOS initialization settings
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Cold start from a notification tap: the tap callback doesn't fire
      // when the app was terminated — the payload arrives in launch details.
      final launchDetails =
          await _notifications.getNotificationAppLaunchDetails();
      final launchPayload =
          launchDetails?.notificationResponse?.payload;
      debugPrint('📲 Notif init: launchedByNotification='
          '${launchDetails?.didNotificationLaunchApp} payload=$launchPayload');
      if (launchDetails?.didNotificationLaunchApp == true &&
          _promoPayloads.contains(launchPayload)) {
        _openPaywallWhenReady();
      }
      if (launchDetails?.didNotificationLaunchApp == true &&
          (launchPayload?.startsWith(StreakSaverService.payloadPrefix) ??
              false)) {
        _handleEngagementTap(launchPayload!);
      }

      _initialized = true;
      debugPrint('✅ Notification service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing notifications: $e');
    }
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('📲 Notification tapped: ${response.payload}');
    if (_promoPayloads.contains(response.payload)) {
      _openPaywallWhenReady();
    }
    final payload = response.payload;
    if (payload != null &&
        payload.startsWith(StreakSaverService.payloadPrefix)) {
      _handleEngagementTap(payload);
    }
  }

  /// Engagement push tapped → stamp the open on its event doc and route to
  /// the Daily Challenge. Same waits/guards as the promo→paywall route.
  static bool _engagementRoutingInFlight = false;

  static Future<void> _handleEngagementTap(String payload) async {
    StreakSaverService.onTapped(payload); // fire-and-forget open stamp
    if (_engagementRoutingInFlight) return;
    _engagementRoutingInFlight = true;
    try {
      for (int i = 0; i < 30; i++) {
        if (navigatorKey?.currentState != null &&
            AuthService.currentUser != null) {
          break;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
      final nav = navigatorKey?.currentState;
      if (nav == null || AuthService.currentUser == null) return;
      // Let the startup gate finish routing before pushing on top of it.
      await Future.delayed(const Duration(milliseconds: 800));
      await nav.push(
        MaterialPageRoute(builder: (_) => const DailyChallengeScreen()),
      );
    } finally {
      _engagementRoutingInFlight = false;
    }
  }

  /// Promo expiry notification tapped → paywall (Pro pre-selected). Waits
  /// for the navigator + a signed-in user, since a cold start is still on
  /// the splash/auth gate when the launch payload is read.
  /// Reentrancy guard (audit H3): held while a promo paywall push is in
  /// flight OR the pushed paywall is still open, so tapping the second tray
  /// notification (warn + ended coexist after expiry) can't stack paywalls.
  static bool _promoRoutingInFlight = false;

  static Future<void> _openPaywallWhenReady() async {
    if (_promoRoutingInFlight) {
      debugPrint('📲 Promo tap: ignored (already routing/showing)');
      return;
    }
    _promoRoutingInFlight = true;
    debugPrint('📲 Promo tap: routing requested '
        '(navigator=${navigatorKey?.currentState != null}, '
        'user=${AuthService.currentUser != null})');
    try {
      await _openPaywallWhenReadyInner();
    } finally {
      _promoRoutingInFlight = false;
    }
  }

  static Future<void> _openPaywallWhenReadyInner() async {
    for (int i = 0; i < 30; i++) {
      if (navigatorKey?.currentState != null &&
          AuthService.currentUser != null) {
        break;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
    final nav = navigatorKey?.currentState;
    if (nav == null || AuthService.currentUser == null) {
      debugPrint(
          '📲 Promo tap: cannot route (navigator=${nav != null}, user=${AuthService.currentUser != null})');
      return;
    }
    // Let the startup gate finish routing before pushing on top of it.
    await Future.delayed(const Duration(milliseconds: 800));
    debugPrint('📲 Promo tap: pushing paywall');
    // Awaited so the reentrancy guard stays held while the paywall is open.
    await nav.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const PaywallScreen(showSkip: true, preselectedTier: 0),
      ),
    );
  }

  /// Request notification permissions (especially for iOS)
  static Future<bool> requestPermissions() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final bool? result = await _notifications
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
        return result ?? false;
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            _notifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        final bool? granted = await androidImplementation?.requestNotificationsPermission();
        return granted ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
      return false;
    }
  }

  /// Schedule notifications for an event (24 hours and 1 hour before)
  static Future<void> scheduleEventNotifications({
    required String eventId,
    required String eventTitle,
    required String eventType,
    required DateTime eventDate,
  }) async {
    try {
      if (!_initialized) {
        debugPrint('⚠️ Notification service not initialized, initializing now...');
        await initialize();
      }

      final now = DateTime.now();
      debugPrint('📅 Event: $eventTitle');
      debugPrint('📅 Event Date: $eventDate');
      debugPrint('⏰ Current Time: $now');

      // Calculate notification times
      final twentyFourHoursBefore = eventDate.subtract(Duration(hours: 24));
      final oneHourBefore = eventDate.subtract(Duration(hours: 1));

      debugPrint('⏰ 24h notification time: $twentyFourHoursBefore');
      debugPrint('⏰ 1h notification time: $oneHourBefore');

      // Schedule 24-hour notification if it's in the future
      if (twentyFourHoursBefore.isAfter(now)) {
        await _scheduleNotification(
          id: _get24HourNotificationId(eventId),
          title: '🃏 Poker Event Tomorrow',
          body: '$eventTitle starts in 24 hours',
          scheduledDate: twentyFourHoursBefore,
          payload: 'event_$eventId',
        );
        debugPrint('✅ Scheduled 24-hour notification for: $eventTitle at $twentyFourHoursBefore');
      } else {
        debugPrint('⏭️ Skipping 24-hour notification (time has passed)');
      }

      // Schedule 1-hour notification if it's in the future
      if (oneHourBefore.isAfter(now)) {
        await _scheduleNotification(
          id: _get1HourNotificationId(eventId),
          title: '🃏 Poker Event Starting Soon',
          body: '$eventTitle starts in 1 hour',
          scheduledDate: oneHourBefore,
          payload: 'event_$eventId',
        );
        debugPrint('✅ Scheduled 1-hour notification for: $eventTitle at $oneHourBefore');
      } else {
        debugPrint('⏭️ Skipping 1-hour notification (time has passed)');
      }

      // Log all pending notifications
      final pending = await getPendingNotifications();
      debugPrint('📋 Total pending notifications: ${pending.length}');
      for (final notif in pending) {
        debugPrint('  - ID: ${notif.id}, Title: ${notif.title}, Body: ${notif.body}');
      }
    } catch (e) {
      debugPrint('❌ Error scheduling event notifications: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    }
  }

  /// Schedule a single notification
  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'poker_events',
            'Poker Events',
            channelDescription: 'Notifications for upcoming poker events',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
            largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            styleInformation: const BigTextStyleInformation(''),
            color: AppColors.accentPrimary, // brand teal tint for the small icon
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      debugPrint('❌ Error scheduling notification: $e');
      rethrow;
    }
  }

  /// Cancel all notifications for an event
  static Future<void> cancelEventNotifications(String eventId) async {
    try {
      await _notifications.cancel(_get24HourNotificationId(eventId));
      await _notifications.cancel(_get1HourNotificationId(eventId));
      debugPrint('✅ Cancelled notifications for event: $eventId');
    } catch (e) {
      debugPrint('❌ Error cancelling notifications: $e');
    }
  }

  /// Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      debugPrint('✅ Cancelled all notifications');
    } catch (e) {
      debugPrint('❌ Error cancelling all notifications: $e');
    }
  }

  /// Get pending notifications (for debugging)
  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _notifications.pendingNotificationRequests();
    } catch (e) {
      debugPrint('❌ Error getting pending notifications: $e');
      return [];
    }
  }

  /// Generate unique notification ID for 24-hour reminder
  static int _get24HourNotificationId(String eventId) {
    // Use event ID hashcode with offset to ensure uniqueness
    return eventId.hashCode;
  }

  /// Generate unique notification ID for 1-hour reminder
  static int _get1HourNotificationId(String eventId) {
    // Use event ID hashcode with different offset
    return eventId.hashCode + 1000000;
  }

  static const int _onboardingReminderId = 888888;

  /// Schedule an onboarding reminder 2 hours after registration
  static Future<void> scheduleOnboardingReminder() async {
    try {
      if (!_initialized) await initialize();

      final scheduledDate = DateTime.now().add(const Duration(hours: 2));
      await _scheduleNotification(
        id: _onboardingReminderId,
        title: 'Welcome to Final Table!',
        body: 'Ready to explore? Take a quick tour to learn how to track your hands.',
        scheduledDate: scheduledDate,
        payload: 'onboarding_reminder',
      );
    } catch (e) {
      debugPrint('Error scheduling onboarding reminder: $e');
    }
  }

  /// Cancel the onboarding reminder
  static Future<void> cancelOnboardingReminder() async {
    try {
      await _notifications.cancel(_onboardingReminderId);
    } catch (e) {
      debugPrint('Error cancelling onboarding reminder: $e');
    }
  }

  static const int _engagementReminderId = 777001;

  /// Build the notification details for an engagement push, showing the
  /// coach mascot as the large (emoji-sized) icon when [coachId] resolves to
  /// one. Falls back to the app launcher icon for the neutral voice.
  static Future<NotificationDetails> _engagementDetails(String? coachId) async {
    final coachPath = await CoachIconService.largeIconPath(coachId);
    final AndroidBitmap<Object> largeIcon = coachPath != null
        ? FilePathAndroidBitmap(coachPath)
        : const DrawableResourceAndroidBitmap('@mipmap/ic_launcher');
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'poker_events',
        'Poker Events',
        channelDescription: 'Notifications for upcoming poker events',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/ic_notification',
        largeIcon: largeIcon,
        styleInformation: const BigTextStyleInformation(''),
        color: AppColors.accentPrimary,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  /// Schedule the single engagement reminder (streak-saver). Fixed id =
  /// idempotent: re-scheduling replaces any queued one. [payload] carries
  /// `engagement:{type}:{eventId}` for tap routing + the open stamp.
  /// [coachId] renders the coach mascot as the large icon.
  static Future<void> scheduleEngagementReminder({
    required String title,
    required String body,
    required DateTime at,
    required String payload,
    String? coachId,
  }) async {
    try {
      if (!_initialized) await initialize();
      await requestPermissions();
      await _notifications.zonedSchedule(
        _engagementReminderId,
        title,
        body,
        tz.TZDateTime.from(at, tz.local),
        await _engagementDetails(coachId),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint('✅ Engagement reminder scheduled for $at');
    } catch (e) {
      debugPrint('❌ Error scheduling engagement reminder: $e');
    }
  }

  /// Cancel the queued engagement reminder (user played / muted the type).
  static Future<void> cancelEngagementReminder() async {
    try {
      await _notifications.cancel(_engagementReminderId);
    } catch (e) {
      debugPrint('Error cancelling engagement reminder: $e');
    }
  }

  /// Show an engagement push IMMEDIATELY (tester). Scheduling a seconds-away
  /// notification is unreliable — Android batches inexact alarms — so the
  /// tester uses show() to exercise the real tap→route→open-stamp path now.
  static Future<void> showEngagementNow({
    required String title,
    required String body,
    required String payload,
    String? coachId,
  }) async {
    try {
      if (!_initialized) await initialize();
      await requestPermissions();
      await _notifications.show(
        _engagementReminderId,
        title,
        body,
        await _engagementDetails(coachId),
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing engagement notification: $e');
    }
  }

  static const int _promoExpiryWarningId = 888890;
  static const int _promoExpiredId = 888891;

  /// Courtesy reminders for the launch-promo free Pro month ("1 day left"
  /// + "has ended"). The entitlement itself expires server-side in RevenueCat
  /// regardless of these. Strings are passed in so the call site can localize.
  /// Idempotent: fixed ids are cancelled first, so re-syncing on every app
  /// open never duplicates notifications.
  static Future<void> schedulePromoExpiryReminders({
    required DateTime expiresAt,
    required String warnTitle,
    required String warnBody,
    required String endedTitle,
    required String endedBody,
  }) async {
    try {
      if (!_initialized) await initialize();
      await requestPermissions();
      await cancelPromoExpiryReminders();

      final now = DateTime.now();
      final warnAt = expiresAt.subtract(const Duration(days: 1));
      if (warnAt.isAfter(now)) {
        await _scheduleNotification(
          id: _promoExpiryWarningId,
          title: warnTitle,
          body: warnBody,
          scheduledDate: warnAt,
          payload: 'promo_expiry_warning',
        );
      }
      if (expiresAt.isAfter(now)) {
        await _scheduleNotification(
          id: _promoExpiredId,
          title: endedTitle,
          body: endedBody,
          scheduledDate: expiresAt,
          payload: 'promo_expired',
        );
      }
    } catch (e) {
      debugPrint('Error scheduling promo expiry reminders: $e');
    }
  }

  /// Debug-only: fire the promo expiry warning IMMEDIATELY so the
  /// tap→paywall route can be tested. Scheduling is deliberately not used
  /// here — Android batches inexact alarms, so a seconds-away scheduled
  /// notification can be delayed by minutes and looks broken.
  static Future<void> debugFirePromoWarnNow({
    required String title,
    required String body,
  }) async {
    if (kReleaseMode) return;
    if (!_initialized) await initialize();
    final granted = await requestPermissions();
    debugPrint('🧪 Promo test: permission granted=$granted');
    try {
      await _notifications.show(
        _promoExpiryWarningId,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'poker_events',
            'Poker Events',
            channelDescription: 'Notifications for upcoming poker events',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'promo_expiry_warning',
      );
      debugPrint('🧪 Promo test: shown immediately, tap it to test routing');
    } catch (e) {
      debugPrint('🧪 Promo test: SHOW FAILED: $e');
    }
  }

  /// Cancel the promo expiry reminders.
  static Future<void> cancelPromoExpiryReminders() async {
    try {
      await _notifications.cancel(_promoExpiryWarningId);
      await _notifications.cancel(_promoExpiredId);
    } catch (e) {
      debugPrint('Error cancelling promo expiry reminders: $e');
    }
  }

  /// Show a test notification immediately (for debugging)
  static Future<void> showTestNotification() async {
    try {
      if (!_initialized) {
        await initialize();
      }

      await _notifications.show(
        999999, // Test notification ID
        '🧪 Test Notification',
        'If you see this, notifications are working!',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'poker_events',
            'Poker Events',
            channelDescription: 'Notifications for upcoming poker events',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
            largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            styleInformation: const BigTextStyleInformation(''),
            color: AppColors.accentPrimary, // brand teal tint for the small icon
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
      debugPrint('✅ Test notification sent!');
    } catch (e) {
      debugPrint('❌ Error showing test notification: $e');
    }
  }
}
