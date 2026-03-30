import 'env_config.dart';

/// Application configuration for Final Table
///
/// Provides access to environment-specific settings.
/// All values are loaded from .env file via EnvConfig.
class AppConfig {
  AppConfig._();

  /// WebSocket server URL for real-time communication
  static String get websocketServerUrl => EnvConfig.websocketServerUrl;

  /// API server URL for REST endpoints
  static String get apiServerUrl => EnvConfig.apiServerUrl;

  /// Whether running in production environment
  static bool get isProduction => EnvConfig.isProduction;

  /// Whether running in development environment
  static bool get isDevelopment => EnvConfig.isDevelopment;

  /// Current environment name
  static String get environment => EnvConfig.environment;

  /// Server URL (alias for websocketServerUrl)
  static String get serverUrl => websocketServerUrl;
}
