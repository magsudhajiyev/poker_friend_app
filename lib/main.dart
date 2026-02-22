import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/auth_wrapper.dart';
import 'screens/player/player_session_screen.dart';
import 'services/notification_service.dart';
import 'services/logger_service.dart';
import 'services/deep_link_service.dart';
import 'config/env_config.dart';
import 'design_system/poker_friend_theme.dart';

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

  // Initialize notification service
  try {
    await NotificationService.initialize();
    await NotificationService.requestPermissions();
    print('Notification service initialized successfully');
  } catch (e) {
    print('Notification initialization failed: $e');
    // Continue without notifications for now
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