import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration loaded from .env file
///
/// Initialize in main.dart before runApp:
/// ```dart
/// await EnvConfig.load();
/// ```
class EnvConfig {
  EnvConfig._();

  /// Load environment variables from .env file
  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }

  // ==================== API Keys ====================

  /// Soniox API key for speech-to-text
  static String get sonioxApiKey =>
      dotenv.env['SONIOX_API_KEY'] ?? '';

  /// RevenueCat iOS API key for subscriptions
  static String get revenueCatIosApiKey =>
      dotenv.env['REVENUECAT_IOS_API_KEY'] ?? '';

  /// RevenueCat Android API key for subscriptions
  static String get revenueCatAndroidApiKey =>
      dotenv.env['REVENUECAT_ANDROID_API_KEY'] ?? '';

  /// Resend API key for email sending
  static String get resendApiKey =>
      dotenv.env['RESEND_API_KEY'] ?? '';

  /// AI hand analysis API key
  static String get aiApiKey =>
      dotenv.env['AI_API_KEY'] ?? '';

  /// PostHog project API key (public token, safe to ship)
  static String get posthogApiKey =>
      dotenv.env['POSTHOG_API_KEY'] ?? '';

  // ==================== Server URLs ====================

  /// WebSocket server URL for real-time communication
  static String get websocketServerUrl =>
      dotenv.env['WEBSOCKET_SERVER_URL'] ?? 'https://poker-friend-engine.onrender.com';

  /// API server URL for REST endpoints
  static String get apiServerUrl =>
      dotenv.env['API_SERVER_URL'] ?? 'https://poker-friend-engine.onrender.com';

  // ==================== Environment ====================

  /// Current environment (development, staging, production)
  static String get environment =>
      dotenv.env['ENVIRONMENT'] ?? 'development';

  /// Whether running in production
  static bool get isProduction => environment == 'production';

  /// Whether running in development
  static bool get isDevelopment => environment == 'development';

  // ==================== Debug Settings ====================

  /// Enable debug mode for subscriptions (simulates states without actual purchases)
  static bool get debugSubscriptionMode =>
      dotenv.env['DEBUG_SUBSCRIPTION_MODE']?.toLowerCase() == 'true';

  /// Debug subscription state (free, monthly, annual, lifetime)
  static String get debugSubscriptionState =>
      dotenv.env['DEBUG_SUBSCRIPTION_STATE'] ?? 'free';

  // ==================== Feature Flags ====================

  /// Enable voice recognition feature
  static bool get enableVoiceRecognition =>
      dotenv.env['ENABLE_VOICE_RECOGNITION']?.toLowerCase() != 'false';

  /// Enable dealer mode feature
  static bool get enableDealerMode =>
      dotenv.env['ENABLE_DEALER_MODE']?.toLowerCase() != 'false';

  // ==================== Validation ====================

  /// Check if required API keys are configured
  static bool get hasRequiredConfig {
    return sonioxApiKey.isNotEmpty;
  }

  /// Get list of missing required configurations
  static List<String> get missingConfigs {
    final missing = <String>[];
    if (sonioxApiKey.isEmpty) missing.add('SONIOX_API_KEY');
    return missing;
  }
}
