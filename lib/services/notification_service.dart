import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Initialize the notification service
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize timezone data
      tz.initializeTimeZones();

      // Android initialization settings
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

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

      _initialized = true;
      print('✅ Notification service initialized');
    } catch (e) {
      print('❌ Error initializing notifications: $e');
    }
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    print('📲 Notification tapped: ${response.payload}');
    // You can handle navigation here based on payload
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
      print('❌ Error requesting permissions: $e');
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
        print('⚠️ Notification service not initialized, initializing now...');
        await initialize();
      }

      final now = DateTime.now();
      print('📅 Event: $eventTitle');
      print('📅 Event Date: $eventDate');
      print('⏰ Current Time: $now');

      // Calculate notification times
      final twentyFourHoursBefore = eventDate.subtract(Duration(hours: 24));
      final oneHourBefore = eventDate.subtract(Duration(hours: 1));

      print('⏰ 24h notification time: $twentyFourHoursBefore');
      print('⏰ 1h notification time: $oneHourBefore');

      // Schedule 24-hour notification if it's in the future
      if (twentyFourHoursBefore.isAfter(now)) {
        await _scheduleNotification(
          id: _get24HourNotificationId(eventId),
          title: '🃏 Poker Event Tomorrow',
          body: '$eventTitle starts in 24 hours',
          scheduledDate: twentyFourHoursBefore,
          payload: 'event_$eventId',
        );
        print('✅ Scheduled 24-hour notification for: $eventTitle at $twentyFourHoursBefore');
      } else {
        print('⏭️ Skipping 24-hour notification (time has passed)');
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
        print('✅ Scheduled 1-hour notification for: $eventTitle at $oneHourBefore');
      } else {
        print('⏭️ Skipping 1-hour notification (time has passed)');
      }

      // Log all pending notifications
      final pending = await getPendingNotifications();
      print('📋 Total pending notifications: ${pending.length}');
      for (final notif in pending) {
        print('  - ID: ${notif.id}, Title: ${notif.title}, Body: ${notif.body}');
      }
    } catch (e) {
      print('❌ Error scheduling event notifications: $e');
      print('Stack trace: ${StackTrace.current}');
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
            icon: '@mipmap/ic_launcher',
            largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            styleInformation: const BigTextStyleInformation(''),
            color: Color(0xFFcb5242), // App's red color for the small icon
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      print('❌ Error scheduling notification: $e');
      rethrow;
    }
  }

  /// Cancel all notifications for an event
  static Future<void> cancelEventNotifications(String eventId) async {
    try {
      await _notifications.cancel(_get24HourNotificationId(eventId));
      await _notifications.cancel(_get1HourNotificationId(eventId));
      print('✅ Cancelled notifications for event: $eventId');
    } catch (e) {
      print('❌ Error cancelling notifications: $e');
    }
  }

  /// Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      print('✅ Cancelled all notifications');
    } catch (e) {
      print('❌ Error cancelling all notifications: $e');
    }
  }

  /// Get pending notifications (for debugging)
  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _notifications.pendingNotificationRequests();
    } catch (e) {
      print('❌ Error getting pending notifications: $e');
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
      print('Error scheduling onboarding reminder: $e');
    }
  }

  /// Cancel the onboarding reminder
  static Future<void> cancelOnboardingReminder() async {
    try {
      await _notifications.cancel(_onboardingReminderId);
    } catch (e) {
      print('Error cancelling onboarding reminder: $e');
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
            icon: '@mipmap/ic_launcher',
            largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            styleInformation: const BigTextStyleInformation(''),
            color: Color(0xFFcb5242), // App's red color for the small icon
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
      print('✅ Test notification sent!');
    } catch (e) {
      print('❌ Error showing test notification: $e');
    }
  }
}
