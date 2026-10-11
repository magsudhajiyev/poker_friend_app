import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'logger_service.dart';

/// Background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background messages
  // Note: This runs in a separate isolate, so we can't access app state
  if (kDebugMode) {
    debugPrint('FCM: Background message received: ${message.messageId}');
    debugPrint('FCM: Title: ${message.notification?.title}');
    debugPrint('FCM: Body: ${message.notification?.body}');
    debugPrint('FCM: Data: ${message.data}');
  }
}

/// Service for managing Firebase Cloud Messaging (FCM) push notifications
class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _tokensCollection = 'fcm_tokens';

  /// Timeout for FCM operations to prevent blocking when service is unavailable
  static const _fcmTimeout = Duration(seconds: 5);

  static String? _currentToken;
  static bool _isInitialized = false;

  /// Pending initial message data (from getInitialMessage) to be processed after app loads
  static Map<String, dynamic>? pendingInitialMessage;

  /// Callback for handling notification taps (deep linking)
  static void Function(Map<String, dynamic> data)? onNotificationTap;

  /// Callback for handling foreground notifications
  static void Function(RemoteMessage message)? onForegroundMessage;

  /// Initialize FCM service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request permissions
      await requestPermissions();

      // Get and store FCM token
      await _getAndStoreToken();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen(_onTokenRefresh);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification tap when app is in background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from a notification (terminated state)
      // Store the data to be processed after app has fully loaded
      final initialMessage = await _messaging.getInitialMessage()
          .timeout(_fcmTimeout, onTimeout: () => null);
      if (initialMessage != null) {
        pendingInitialMessage = initialMessage.data;
      }

      _isInitialized = true;
      unawaited(LoggerService.debug('FCM: Service initialized successfully'));
    } catch (e) {
      unawaited(LoggerService.error('FCM: Initialization failed', e));
    }
  }

  /// Request notification permissions
  static Future<bool> requestPermissions() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      ).timeout(_fcmTimeout, onTimeout: () {
        unawaited(LoggerService.warning('FCM: Permission request timed out'));
        throw TimeoutException('Permission request timed out');
      });

      final isAuthorized = settings.authorizationStatus == AuthorizationStatus.authorized ||
                           settings.authorizationStatus == AuthorizationStatus.provisional;

      unawaited(LoggerService.debug('FCM: Permission status: ${settings.authorizationStatus}'));
      return isAuthorized;
    } catch (e) {
      unawaited(LoggerService.error('FCM: Permission request failed', e));
      return false;
    }
  }

  /// Get current FCM token
  static Future<String?> getToken() async {
    try {
      // For iOS, get APNs token first (required for FCM)
      if (Platform.isIOS) {
        final apnsToken = await _messaging.getAPNSToken()
            .timeout(_fcmTimeout, onTimeout: () => null);
        if (apnsToken == null) {
          unawaited(LoggerService.debug('FCM: APNs token not available yet'));
          return null;
        }
      }

      _currentToken = await _messaging.getToken()
          .timeout(_fcmTimeout, onTimeout: () => null);
      if (_currentToken != null) {
        unawaited(LoggerService.debug('FCM: Token retrieved: ${_currentToken?.substring(0, 20)}...'));
      } else {
        unawaited(LoggerService.warning('FCM: getToken timed out or returned null'));
      }
      return _currentToken;
    } catch (e) {
      unawaited(LoggerService.error('FCM: Failed to get token', e));
      return null;
    }
  }

  /// Get and store FCM token for current user
  static Future<void> _getAndStoreToken() async {
    final token = await getToken();
    if (token != null) {
      await storeToken(token);
    }
  }

  /// Handle token refresh
  static void _onTokenRefresh(String token) {
    unawaited(LoggerService.debug('FCM: Token refreshed'));
    _currentToken = token;
    storeToken(token);
  }

  /// Store FCM token in Firestore for the current user
  static Future<void> storeToken(String token) async {
    final userId = AuthService.userId;
    if (userId == null) {
      unawaited(LoggerService.debug('FCM: Cannot store token - no user logged in'));
      return;
    }

    try {
      final deviceInfo = _getDeviceInfo();

      // Use token as document ID to avoid duplicates
      await _firestore
          .collection(_tokensCollection)
          .doc(token)
          .set({
        'userId': userId,
        'token': token,
        'platform': Platform.operatingSystem,
        'deviceInfo': deviceInfo,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      unawaited(LoggerService.debug('FCM: Token stored for user $userId'));
    } catch (e) {
      unawaited(LoggerService.error('FCM: Failed to store token', e));
    }
  }

  /// Remove FCM token (call on logout)
  static Future<void> removeToken() async {
    if (_currentToken == null) return;

    try {
      await _firestore
          .collection(_tokensCollection)
          .doc(_currentToken)
          .delete();

      unawaited(LoggerService.debug('FCM: Token removed'));
      _currentToken = null;
    } catch (e) {
      unawaited(LoggerService.error('FCM: Failed to remove token', e));
    }
  }

  /// Get all FCM tokens for a user
  static Future<List<String>> getTokensForUser(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_tokensCollection)
          .where('userId', isEqualTo: userId)
          .get();

      return snapshot.docs.map((doc) => doc['token'] as String).toList();
    } catch (e) {
      unawaited(LoggerService.error('FCM: Failed to get tokens for user', e));
      return [];
    }
  }

  /// Get FCM tokens for multiple users
  static Future<List<String>> getTokensForUsers(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    try {
      // Firestore 'whereIn' has a limit of 10 items
      final List<String> allTokens = [];

      for (int i = 0; i < userIds.length; i += 10) {
        final batch = userIds.skip(i).take(10).toList();
        final snapshot = await _firestore
            .collection(_tokensCollection)
            .where('userId', whereIn: batch)
            .get();

        allTokens.addAll(
          snapshot.docs.map((doc) => doc['token'] as String)
        );
      }

      return allTokens;
    } catch (e) {
      unawaited(LoggerService.error('FCM: Failed to get tokens for users', e));
      return [];
    }
  }

  /// Handle foreground message
  static void _handleForegroundMessage(RemoteMessage message) {
    unawaited(LoggerService.debug('FCM: Foreground message received'));
    unawaited(LoggerService.debug('FCM: Title: ${message.notification?.title}'));
    unawaited(LoggerService.debug('FCM: Body: ${message.notification?.body}'));
    unawaited(LoggerService.debug('FCM: Data: ${message.data}'));

    // Call the foreground message callback if set
    onForegroundMessage?.call(message);
  }

  /// Handle notification tap (deep linking)
  static void _handleNotificationTap(RemoteMessage message) {
    unawaited(LoggerService.debug('FCM: Notification tapped'));
    unawaited(LoggerService.debug('FCM: Data: ${message.data}'));

    // Call the notification tap callback if set
    onNotificationTap?.call(message.data);
  }

  /// Process pending initial message (call this after app has fully loaded)
  /// Process pending initial message (call this after app has fully loaded)
  static void processPendingInitialMessage() {
    if (pendingInitialMessage != null) {
      onNotificationTap?.call(pendingInitialMessage!);
      pendingInitialMessage = null;
    }
  }

  /// Get device info for token storage
  static Map<String, dynamic> _getDeviceInfo() {
    return {
      'platform': Platform.operatingSystem,
      'platformVersion': Platform.operatingSystemVersion,
      'isPhysicalDevice': !kIsWeb,
    };
  }

  /// Subscribe to a topic (e.g., club notifications)
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic)
          .timeout(_fcmTimeout, onTimeout: () {
        unawaited(LoggerService.warning('FCM: Subscribe to $topic timed out'));
      });
      unawaited(LoggerService.debug('FCM: Subscribed to topic: $topic'));
    } catch (e) {
      unawaited(LoggerService.error('FCM: Failed to subscribe to topic', e));
    }
  }

  /// Unsubscribe from a topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic)
          .timeout(_fcmTimeout, onTimeout: () {
        unawaited(LoggerService.warning('FCM: Unsubscribe from $topic timed out'));
      });
      unawaited(LoggerService.debug('FCM: Unsubscribed from topic: $topic'));
    } catch (e) {
      unawaited(LoggerService.error('FCM: Failed to unsubscribe from topic', e));
    }
  }

  /// Subscribe to club topic (for club-wide notifications)
  static Future<void> subscribeToClub(String clubId) async {
    await subscribeToTopic('club_$clubId');
  }

  /// Unsubscribe from club topic
  static Future<void> unsubscribeFromClub(String clubId) async {
    await unsubscribeFromTopic('club_$clubId');
  }

  /// Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
           settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Subscribe to all clubs the current user is a member of
  /// Call this on login to ensure user receives notifications for all their clubs
  static Future<void> subscribeToUserClubs() async {
    final userId = AuthService.userId;
    if (userId == null) return;

    try {
      // Get user's club IDs from dealers document (with timeout)
      final dealerDoc = await _firestore.collection('dealers').doc(userId).get()
          .timeout(_fcmTimeout, onTimeout: () {
        throw TimeoutException('Firestore timeout getting dealer doc');
      });
      if (!dealerDoc.exists) return;

      final clubIds = (dealerDoc.data()?['clubIds'] as List<dynamic>?)?.cast<String>() ?? [];

      // Subscribe in parallel instead of sequentially (with overall timeout)
      await Future.wait(
        clubIds.map((clubId) => subscribeToClub(clubId)),
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        unawaited(LoggerService.warning('FCM: Bulk subscribe timed out'));
        return [];
      });

      unawaited(LoggerService.debug('FCM: Subscribed to ${clubIds.length} club topics'));
    } catch (e) {
      unawaited(LoggerService.error('FCM: Failed to subscribe to user clubs', e));
    }
  }

  /// Unsubscribe from all clubs (call on logout)
  static Future<void> unsubscribeFromAllClubs() async {
    final userId = AuthService.userId;
    if (userId == null) return;

    try {
      // Get user's club IDs from dealers document (with timeout)
      final dealerDoc = await _firestore.collection('dealers').doc(userId).get()
          .timeout(_fcmTimeout, onTimeout: () {
        throw TimeoutException('Firestore timeout getting dealer doc');
      });
      if (!dealerDoc.exists) return;

      final clubIds = (dealerDoc.data()?['clubIds'] as List<dynamic>?)?.cast<String>() ?? [];

      // Unsubscribe in parallel instead of sequentially (with overall timeout)
      await Future.wait(
        clubIds.map((clubId) => unsubscribeFromClub(clubId)),
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        unawaited(LoggerService.warning('FCM: Bulk unsubscribe timed out'));
        return [];
      });

      unawaited(LoggerService.debug('FCM: Unsubscribed from ${clubIds.length} club topics'));
    } catch (e) {
      unawaited(LoggerService.error('FCM: Failed to unsubscribe from clubs', e));
    }
  }
}
