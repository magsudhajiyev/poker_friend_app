import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/auth_wrapper.dart';
import 'services/notification_service.dart';
import 'services/logger_service.dart';
import 'config/env_config.dart';

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

  runApp(PokerTrackerApp());
}

class PokerTrackerApp extends StatelessWidget {
  const PokerTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Poker Hand Tracker',
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => AuthWrapper(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}