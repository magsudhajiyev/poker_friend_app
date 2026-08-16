import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'design_system/app_scroll_behavior.dart';
import 'screens/auth_wrapper.dart';
import 'screens/splash_screen.dart';
import 'screens/player/player_session_screen.dart';
import 'services/notification_service.dart';
import 'services/fcm_service.dart';
import 'services/auth_service.dart';
import 'services/feature_flag_service.dart';
import 'services/logger_service.dart';
import 'services/deep_link_service.dart';
import 'services/club_service.dart';
import 'services/event_service.dart';
import 'services/subscription_service.dart';
import 'services/app_data_cache.dart';
import 'services/locale_service.dart';
import 'services/currency_service.dart';
import 'services/skip_hand_scouting_service.dart';
import 'services/opponent_service.dart';
import 'config/env_config.dart';
import 'services/analytics_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'design_system/poker_friend_theme.dart';
import 'screens/club/event_detail_screen.dart';
import 'screens/club/club_dashboard_screen.dart';
import 'screens/admin/club_requests_screen.dart';
import 'design_system/constants/decorations.dart';
import 'widgets/looping_splash_logo.dart';

/// Global navigator key for deep linking
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Global subscription for handling subscription status changes
StreamSubscription<bool>? _subscriptionStatusListener;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Audit M1: debugPrint is NOT a no-op in release builds, and the codebase
  // logs emails/uids through it. Silence it in release — LoggerService and
  // Crashlytics remain the production logging paths.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // Lock to portrait globally. Individual chart screens (earnings, stack,
  // public leaderboard) opt into landscape and restore this lock on dispose.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Load environment configuration
  try {
    await EnvConfig.load();
  } catch (e) {
    debugPrint('Environment config load failed: $e');
  }

  // Firebase must init before runApp (AuthWrapper depends on it)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    debugPrint('Firestore offline persistence enabled');
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  // PostHog product analytics — after EnvConfig (key) and Firebase (auth
  // stream drives identify/reset). Fire-and-forget; no-op without a key.
  unawaited(AnalyticsService.init());

  // Start loading the splash video in parallel with everything else so
  // it's ready by the time SplashScreen mounts (avoids blank frames).
  unawaited(LoopingSplashLogo.warmUp());

  // Lightweight SharedPreferences reads + feature flags — independent of each
  // other, so run them all in parallel instead of sequentially.
  await Future.wait([
    LocaleService.init().catchError(
        (e) => debugPrint('Locale service init failed: $e')),
    CurrencyService.init().catchError(
        (e) => debugPrint('Currency service init failed: $e')),
    SkipHandScoutingService.init().catchError(
        (e) => debugPrint('Skip hand scouting service init failed: $e')),
    FeatureFlagService.init().catchError(
        (e) => debugPrint('Feature flag service init failed: $e')),
  ]);

  // Install global error handlers for Crashlytics
  FlutterError.onError = (details) {
    if (kDebugMode) FlutterError.dumpErrorToConsole(details);
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Launch app FIRST, then init services in background.
  // This prevents a black screen if any service hangs when offline.
  runApp(const PokerTrackerApp());
  debugPrint('📍 MAIN: runApp() called');

  // Initialize remaining services in background (non-blocking)
  unawaited(_initServicesInBackground());
}

/// Initialize non-critical services in background after app is already visible.
/// Each service is wrapped in try/catch so failures don't affect the app.
Future<void> _initServicesInBackground() async {
  // Local notifications
  try {
    NotificationService.navigatorKey = navigatorKey;
    await NotificationService.initialize();
    await NotificationService.requestPermissions();
    debugPrint('Local notification service initialized successfully');
  } catch (e) {
    debugPrint('Local notification initialization failed: $e');
  }

  // FCM push notifications
  try {
    FCMService.onForegroundMessage = (RemoteMessage message) {};
    FCMService.onNotificationTap = (Map<String, dynamic> data) {
      _handleNotificationNavigation(data);
    };
    await FCMService.initialize();
    if (AuthService.isSignedIn) {
      unawaited(_setupFcmForLoggedInUser());
      unawaited(OpponentService.syncTempOpponents());
    }
  } catch (e) {
    debugPrint('FCM initialization failed: $e');
  }

  // Logger
  try {
    await LoggerService.initialize();
    await LoggerService.info('App started - Logger initialized');
    unawaited(LoggerService.logEvent('app_open'));
    debugPrint('Logger service initialized successfully');
  } catch (e) {
    debugPrint('Logger initialization failed: $e');
  }

  // RevenueCat subscriptions
  try {
    await SubscriptionService.initialize();
    debugPrint('Subscription service initialized successfully');

    // Setup subscription status change listener for cache invalidation
    _setupSubscriptionStatusListener();
  } catch (e) {
    debugPrint('Subscription service initialization failed: $e');
  }

  // Deep links
  try {
    await DeepLinkService.initialize(
      navigatorKey: navigatorKey,
      onInvitationAccepted: (clubId, clubName) {
        _showInvitationAcceptedNotification(clubName);
      },
    );
    debugPrint('Deep link service initialized successfully');
  } catch (e) {
    debugPrint('Deep link initialization failed: $e');
  }

  // Process pending notification after services are ready
  WidgetsBinding.instance.addPostFrameCallback((_) {
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
      content: Text(AppLocalizations.of(context).mainDealerOnClub(clubName)),
      backgroundColor: PokerFriendColors.green,
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDecorations.radiusMd)),
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

/// Setup subscription status change listener to invalidate relevant caches
/// when user upgrades from free to premium or downgrades
void _setupSubscriptionStatusListener() {
  try {
    _subscriptionStatusListener = SubscriptionService.premiumStatusStream.listen((isPremium) {
      // Invalidate caches that depend on subscription status
      // Sessions cache needs refresh because premium users see all sessions
      // while free users only see last 30 days
      AppDataCache.markSessionsDirty();

      // Mark home dirty to refresh recent sessions display
      AppDataCache.markHomeDirty();

      debugPrint('Subscription status changed to ${isPremium ? 'Premium' : 'Free'} - cache invalidated');
    });
    debugPrint('Subscription status listener setup successfully');
  } catch (e) {
    debugPrint('Failed to setup subscription status listener: $e');
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

class PokerTrackerApp extends StatefulWidget {
  const PokerTrackerApp({super.key});

  @override
  State<PokerTrackerApp> createState() => _PokerTrackerAppState();
}

class _PokerTrackerAppState extends State<PokerTrackerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Called whenever the app returns to the foreground.
  /// Forces a fresh CustomerInfo fetch from RevenueCat so cancellations
  /// made in iOS/Android Settings are reflected immediately.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SubscriptionService.refreshOnResume();
      unawaited(LoggerService.logEvent('app_resume'));
    } else if (state == AppLifecycleState.paused) {
      unawaited(LoggerService.logEvent('app_background'));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-assert on every build (not just startup) so the notification tap
    // router always has the key — startup-only injection breaks under hot
    // reload, where main() doesn't re-run.
    NotificationService.navigatorKey = navigatorKey;
    return ValueListenableBuilder<Locale?>(
      valueListenable: LocaleService.localeNotifier,
      builder: (context, locale, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Final Table',
          theme: AppTheme.lightTheme,
          scrollBehavior: const AppScrollBehavior(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
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
          builder: (context, child) {
            // Global tap-to-dismiss keyboard on any screen
            return GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: child,
            );
          },
        );
      },
    );
  }
}