/// Application configuration for Poker Logger
///
/// Contains configurable settings like server URLs that may differ
/// between development and production environments.
class AppConfig {
  // Private constructor to prevent instantiation
  AppConfig._();

  /// WebSocket server URL
  ///
  /// For development on real devices:
  /// - Use your machine's local network IP (e.g., 'http://192.168.1.100:8000')
  /// - Find your IP with: `ifconfig | grep inet` (macOS) or `ipconfig` (Windows)
  ///
  /// For production:
  /// - Use your deployed server URL (e.g., 'https://api.yourserver.com')
  ///
  /// Note: 'localhost' only works on simulators/emulators, not real devices
  static const String websocketServerUrl = String.fromEnvironment(
    'WEBSOCKET_URL',
    defaultValue: 'http://192.168.100.6:8000',
  );

  /// Whether to use the production server
  static const bool isProduction = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  ) == 'production';

  /// Get the appropriate WebSocket URL based on environment
  ///
  /// In development, you can override this by setting the WEBSOCKET_URL
  /// environment variable when running:
  /// ```
  /// flutter run --dart-define=WEBSOCKET_URL=http://192.168.1.100:8000
  /// ```
  static String get serverUrl {
    // You can add logic here to detect and use different URLs
    // For example, detecting if running on a real device vs simulator
    return websocketServerUrl;
  }

  /// Alternative development URLs for common scenarios
  /// Uncomment and modify as needed for your local network
  // static const String localNetworkUrl = 'http://192.168.1.XXX:8000';
  // static const String productionUrl = 'https://api.pokerfriend.com';
}
