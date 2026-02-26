import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/auth_wrapper.dart';
import 'screens/player/player_session_screen.dart';
import 'services/notification_service.dart';
import 'services/fcm_service.dart';
import 'services/auth_service.dart';
import 'services/logger_service.dart';
import 'services/deep_link_service.dart';
import 'services/club_service.dart';
import 'services/event_service.dart';
import 'config/env_config.dart';
import 'design_system/poker_friend_theme.dart';
import 'screens/club/event_detail_screen.dart';
import 'screens/club/club_dashboard_screen.dart';
import 'screens/admin/club_requests_screen.dart';

/// Global navigator key for deep linking
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment configuration
  try {
    await EnvConfig.load();
  } catch (e) {
    print('Environment config load failed: $e');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');
  } catch (e) {
    print('Firebase initialization failed: $e');
    // Continue without Firebase for now
  }

  // Initialize local notification service
  try {
    await NotificationService.initialize();
    await NotificationService.requestPermissions();
    print('Local notification service initialized successfully');
  } catch (e) {
    print('Local notification initialization failed: $e');
    // Continue without local notifications for now
  }

  // Initialize FCM push notification service
  try {
    // Set callbacks BEFORE initialize() to handle getInitialMessage() for terminated app state
    FCMService.onForegroundMessage = (RemoteMessage message) {
      // Don't show UI - the in-app notification system handles foreground notifications
    };

    FCMService.onNotificationTap = (Map<String, dynamic> data) {
      _handleNotificationNavigation(data);
    };

    await FCMService.initialize();

    // If user is already logged in, ensure FCM token is stored and clubs subscribed
    // Fire-and-forget - don't block app startup
    if (AuthService.isSignedIn) {
      unawaited(_setupFcmForLoggedInUser());
    }
  } catch (e) {
    // Continue without FCM
  }

  // Initialize logger service for debugging
  try {
    await LoggerService.initialize();
    await LoggerService.info('App started - Logger initialized');
    print('Logger service initialized successfully');
  } catch (e) {
    print('Logger initialization failed: $e');
    // Continue without logger
  }

  // Initialize deep link service for email invitation handling
  try {
    await DeepLinkService.initialize(
      navigatorKey: navigatorKey,
      onInvitationAccepted: (clubId, clubName) {
        _showInvitationAcceptedNotification(clubName);
      },
    );
    print('Deep link service initialized successfully');
  } catch (e) {
    print('Deep link initialization failed: $e');
    // Continue without deep linking
  }

  runApp(PokerTrackerApp());

  // Process any pending notification that opened the app (from terminated state)
  // This must happen after runApp() so the navigation context is available
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Add a small delay to ensure the app is fully loaded and navigated to home
    Future.delayed(const Duration(seconds: 1), () {
      FCMService.processPendingInitialMessage();
    });
  });
}

/// Show a notification when an invitation is accepted via deep link
void _showInvitationAcceptedNotification(String clubName) {
  final context = navigatorKey.currentContext;
  if (context == null) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('You are now a dealer on $clubName'),
      backgroundColor: PokerFriendColors.green,
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// Setup FCM for already logged-in user (fire-and-forget, runs in background)
Future<void> _setupFcmForLoggedInUser() async {
  try {
    final token = await FCMService.getToken();
    if (token != null) {
      await FCMService.storeToken(token);
    }
    await FCMService.subscribeToUserClubs();
  } catch (e) {
    // Silent failure - FCM is non-critical for app functionality
  }
}

/// Handle navigation when a notification is tapped (from background or terminated state)
Future<void> _handleNotificationNavigation(Map<String, dynamic> data) async {
  final action = data['action'] as String?;
  final clubId = data['clubId'] as String?;
  final eventId = data['eventId'] as String?;
  final type = data['type'] as String?;

  // Need either action or type to determine navigation
  if (action == null && type == null) return;

  final context = navigatorKey.currentContext;
  if (context == null) return;

  // Wait for navigation to be ready (especially for terminated app state)
  await Future.delayed(const Duration(milliseconds: 500));

  // Determine effective action from explicit action or notification type
  final effectiveAction = action ?? _actionFromType(type);

  switch (effectiveAction) {
    case 'view_event':
    case 'spectate_event':
      if (clubId != null && eventId != null) {
        await _navigateToEvent(context, clubId, eventId);
      }
      break;
    case 'view_club':
      if (clubId != null) {
        await _navigateToClub(context, clubId);
      }
      break;
    case 'view_club_requests':
      _navigateToClubRequests(context);
      break;
  }
}

/// Map notification type to navigation action
String? _actionFromType(String? type) {
  switch (type) {
    case 'eventCreated':
    case 'eventUpdated':
    case 'eventStarting':
    case 'eventStarted':
    case 'eventCancelled':
      return 'view_event';
    case 'clubApproved':
    case 'invitationAccepted':
      return 'view_club';
    case 'new_club_request':
      return 'view_club_requests';
    default:
      return null;
  }
}

/// Navigate to event detail screen by fetching club and event data
Future<void> _navigateToEvent(BuildContext context, String clubId, String eventId) async {
  try {
    final club = await ClubService.getClub(clubId);
    final event = await EventService.getEvent(clubId, eventId);

    if (club == null || event == null) return;

    final isAdmin = await ClubService.canManageEvents(clubId);

    if (!context.mounted) return;

    // Pop back to root first, then push event screen
    // This ensures clean navigation even if already viewing another event
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => EventDetailScreen(
          club: club,
          event: event,
          isAdmin: isAdmin,
        ),
      ),
      (route) => route.isFirst,
    );
  } catch (e) {
    // Silently fail - user can navigate manually
  }
}

/// Navigate to club dashboard by fetching club data
Future<void> _navigateToClub(BuildContext context, String clubId) async {
  try {
    final club = await ClubService.getClub(clubId);
    if (club == null) return;

    if (!context.mounted) return;

    // Pop back to root first, then push club screen
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => ClubDashboardScreen(club: club),
      ),
      (route) => route.isFirst,
    );
  } catch (e) {
    // Silently fail - user can navigate manually
  }
}

/// Navigate to club requests screen (for app admins)
void _navigateToClubRequests(BuildContext context) {
  if (!context.mounted) return;

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (context) => const ClubRequestsScreen(),
    ),
    (route) => route.isFirst,
  );
}

class PokerTrackerApp extends StatelessWidget {
  const PokerTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Poker Hand Tracker',
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => AuthWrapper(),
      },
      onGenerateRoute: (settings) {
        // Handle player session route with arguments
        if (settings.name == '/player_session') {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args != null) {
            return MaterialPageRoute(
              builder: (context) => PlayerSessionScreen(
                clubId: args['clubId'] as String,
                tableId: args['tableId'] as String,
                seatNumber: args['seatNumber'] as int,
              ),
            );
          }
        }
        return null;
      },
      debugShowCheckedModeBanner: false,
    );
  }
}