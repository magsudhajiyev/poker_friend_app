import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Log levels for categorizing messages
enum LogLevel {
  DEBUG,   // Detailed information for debugging
  INFO,    // General informational messages
  WARNING, // Warning messages for potential issues
  ERROR    // Error messages for actual problems
}

/// Comprehensive logging service for debugging poker app during live sessions.
/// Logs to local file, console, Crashlytics breadcrumbs, and Analytics events.
/// Remote Config controls log level and targeted verbose debugging per userId.
class LoggerService {
  static const String LOG_FILE_NAME = 'poker_logger_session.log';
  static File? _logFile;
  static bool _initialized = false;

  // Firebase observability instances
  static FirebaseCrashlytics? _crashlytics;
  static FirebaseAnalytics? _analytics;
  static FirebaseRemoteConfig? _remoteConfig;

  // Remote Config-driven settings
  static LogLevel _minimumLevel = LogLevel.INFO;
  static bool _analyticsEnabled = true;
  static Set<String> _verboseUserIds = {};
  static String? _currentUserId;
  static String? _currentScreen;

  /// Initialize the logger (call this at app startup)
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/$LOG_FILE_NAME');

      // Create file if it doesn't exist
      if (!await _logFile!.exists()) {
        await _logFile!.create(recursive: true);
      }

      _initialized = true;

      // Log initialization
      await _writeToFile('=' * 80);
      await _writeToFile('POKER LOGGER SESSION STARTED');
      await _writeToFile('Timestamp: ${DateTime.now().toIso8601String()}');
      await _writeToFile('=' * 80);
    } catch (e) {
      debugPrint('Failed to initialize LoggerService file logging: $e');
    }

    // Initialize Firebase observability (non-blocking — failures won't break logging)
    try {
      _crashlytics = FirebaseCrashlytics.instance;
      // Explicitly enable collection (helps on restrictive devices like MIUI)
      await _crashlytics!.setCrashlyticsCollectionEnabled(true);
      _analytics = FirebaseAnalytics.instance;
      await _initRemoteConfig();
    } catch (e) {
      debugPrint('Firebase observability init failed (non-fatal): $e');
    }

    // In debug mode, always use DEBUG level regardless of Remote Config
    if (kDebugMode) {
      _minimumLevel = LogLevel.DEBUG;
    }
  }

  /// Initialize Remote Config with defaults, fetch, and real-time listener
  static Future<void> _initRemoteConfig() async {
    try {
      _remoteConfig = FirebaseRemoteConfig.instance;

      await _remoteConfig!.setDefaults({
        'log_level': 'info',
        'analytics_enabled': true,
        'verbose_user_ids': '',
      });

      await _remoteConfig!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: kDebugMode
            ? const Duration(minutes: 5)
            : const Duration(hours: 12),
      ));

      await _remoteConfig!.fetchAndActivate();
      _applyRemoteConfig();

      // Listen for real-time Remote Config updates
      _remoteConfig!.onConfigUpdated.listen((event) async {
        await _remoteConfig!.activate();
        _applyRemoteConfig();
      });
    } catch (e) {
      // Non-fatal — use defaults
      debugPrint('Remote Config init failed (using defaults): $e');
    }
  }

  /// Apply Remote Config values to local settings
  static void _applyRemoteConfig() {
    if (_remoteConfig == null) return;

    // Parse log_level
    final levelStr = _remoteConfig!.getString('log_level').toUpperCase();
    switch (levelStr) {
      case 'DEBUG':
        _minimumLevel = LogLevel.DEBUG;
      case 'INFO':
        _minimumLevel = LogLevel.INFO;
      case 'WARNING':
        _minimumLevel = LogLevel.WARNING;
      case 'ERROR':
        _minimumLevel = LogLevel.ERROR;
      default:
        _minimumLevel = LogLevel.INFO;
    }

    // In debug mode, always force DEBUG
    if (kDebugMode) {
      _minimumLevel = LogLevel.DEBUG;
    }

    _analyticsEnabled = _remoteConfig!.getBool('analytics_enabled');

    // Parse verbose_user_ids CSV
    final verboseStr = _remoteConfig!.getString('verbose_user_ids');
    _verboseUserIds = verboseStr
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();

    // If current user is in verbose set, override to DEBUG
    if (_currentUserId != null && _verboseUserIds.contains(_currentUserId)) {
      _minimumLevel = LogLevel.DEBUG;
    }
  }

  /// Write a message to the log file
  static Future<void> _writeToFile(String message) async {
    if (_logFile == null) {
      await initialize();
    }

    try {
      await _logFile!.writeAsString('$message\n', mode: FileMode.append);
    } catch (e) {
      debugPrint('Failed to write to log file: $e');
    }
  }

  /// Format a log message with timestamp and level
  static String _formatMessage(String message, LogLevel level) {
    final timestamp = DateFormat('HH:mm:ss.SSS').format(DateTime.now());
    final levelStr = level.name.padRight(7);
    return '[$timestamp] [$levelStr] $message';
  }

  /// Generic log method with level
  static Future<void> log(String message, {LogLevel level = LogLevel.INFO}) async {
    // Gate on minimum level
    if (level.index < _minimumLevel.index) return;

    final formattedMessage = _formatMessage(message, level);
    await _writeToFile(formattedMessage);

    // Console print in debug mode only
    if (kDebugMode) {
      final emoji = _getEmojiForLevel(level);
      debugPrint('$emoji $formattedMessage');
    }

    // WARNING+ messages go to Crashlytics as breadcrumbs
    if (level.index >= LogLevel.WARNING.index) {
      try {
        _crashlytics?.log(formattedMessage);
      } catch (_) {}
    }
  }

  /// Get emoji for log level (for console visibility)
  static String _getEmojiForLevel(LogLevel level) {
    switch (level) {
      case LogLevel.DEBUG:
        return '🔍';
      case LogLevel.INFO:
        return 'ℹ️';
      case LogLevel.WARNING:
        return '⚠️';
      case LogLevel.ERROR:
        return '❌';
    }
  }

  /// Convenience methods for different log levels
  static Future<void> debug(String message) async {
    await log(message, level: LogLevel.DEBUG);
  }

  static Future<void> info(String message) async {
    await log(message, level: LogLevel.INFO);
  }

  static Future<void> warning(String message) async {
    await log(message, level: LogLevel.WARNING);
  }

  /// Log an error with optional error object and stack trace.
  /// Errors are recorded in Crashlytics for remote tracking.
  static Future<void> error(String message, [dynamic errorObject, StackTrace? stackTrace]) async {
    if (errorObject != null) {
      await log('$message | Error: $errorObject', level: LogLevel.ERROR);
    } else {
      await log(message, level: LogLevel.ERROR);
    }

    // Record in Crashlytics
    try {
      if (errorObject != null) {
        _crashlytics?.recordError(
          errorObject is Exception ? errorObject : Exception(errorObject.toString()),
          stackTrace ?? StackTrace.current,
          reason: message,
        );
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Analytics event logging
  // ---------------------------------------------------------------------------

  /// Log a structured Analytics event.
  /// All events are automatically enriched with current_screen.
  static Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    if (!_analyticsEnabled || _analytics == null) return;

    try {
      final enrichedParams = <String, Object>{
        if (_currentScreen != null) 'current_screen': _currentScreen!,
        ...?parameters,
      };

      await _analytics!.logEvent(name: name, parameters: enrichedParams);
    } catch (_) {}
  }

  /// Log a screen view event and update the current screen context.
  static Future<void> logScreenView(String screenName) async {
    _currentScreen = screenName;

    // Set Crashlytics key for context
    try {
      _crashlytics?.setCustomKey('current_screen', screenName);
    } catch (_) {}

    await logEvent('screen_view', parameters: {'screen_name': screenName});
  }

  // ---------------------------------------------------------------------------
  // User identification
  // ---------------------------------------------------------------------------

  /// Set the current user ID for Crashlytics and Analytics.
  /// Call after successful sign-in.
  static Future<void> setUserId(String userId) async {
    _currentUserId = userId;

    try {
      _crashlytics?.setUserIdentifier(userId);
    } catch (_) {}

    try {
      await _analytics?.setUserId(id: userId);
    } catch (_) {}

    // Re-check verbose override for this user
    if (_verboseUserIds.contains(userId)) {
      _minimumLevel = LogLevel.DEBUG;
    }
  }

  /// Set user properties for Analytics segmentation.
  static Future<void> setUserProperties({
    String? tier,
    int? totalSessions,
    int? totalHands,
    String? appVersion,
  }) async {
    if (_analytics == null) return;

    try {
      if (tier != null) {
        await _analytics!.setUserProperty(name: 'subscription_tier', value: tier);
      }
      if (totalSessions != null) {
        await _analytics!.setUserProperty(
          name: 'total_sessions',
          value: totalSessions.toString(),
        );
      }
      if (totalHands != null) {
        await _analytics!.setUserProperty(
          name: 'total_hands',
          value: totalHands.toString(),
        );
      }
      if (appVersion != null) {
        await _analytics!.setUserProperty(name: 'app_version', value: appVersion);
      }
    } catch (_) {}
  }

  /// Set a custom Crashlytics key for breadcrumb context.
  static void setCrashlyticsKey(String key, dynamic value) {
    try {
      if (value is String) {
        _crashlytics?.setCustomKey(key, value);
      } else if (value is int) {
        _crashlytics?.setCustomKey(key, value);
      } else if (value is double) {
        _crashlytics?.setCustomKey(key, value);
      } else if (value is bool) {
        _crashlytics?.setCustomKey(key, value);
      } else {
        _crashlytics?.setCustomKey(key, value.toString());
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Existing domain-specific logging methods (unchanged)
  // ---------------------------------------------------------------------------

  /// Log hand action with context
  static Future<void> logHandAction(String action, Map<String, dynamic> context) async {
    await _writeToFile('-' * 80);
    await info('HAND ACTION: $action');
    for (final entry in context.entries) {
      await debug('  ${entry.key}: ${entry.value}');
    }
  }

  /// Log database write operation
  static Future<void> logDBWrite(String collection, String operation, Map<String, dynamic> data) async {
    await info('DB WRITE: $collection.$operation');
    debug('  Data: ${data.toString().substring(0, data.toString().length > 200 ? 200 : data.toString().length)}...');
  }

  /// Log button position change
  static Future<void> logButtonChange(int oldPosition, int newPosition, String reason) async {
    await warning('BUTTON CHANGE: $oldPosition -> $newPosition');
    await debug('  Reason: $reason');
  }

  /// Log stack update
  static Future<void> logStackUpdate(int player, double oldStack, double newStack, String reason) async {
    final change = newStack - oldStack;
    final changeStr = change >= 0 ? '+${change.toStringAsFixed(2)}' : change.toStringAsFixed(2);
    await info('STACK UPDATE: Player $player: ${oldStack.toStringAsFixed(2)} -> ${newStack.toStringAsFixed(2)} ($changeStr)');
    await debug('  Reason: $reason');
  }

  /// Log position calculation (CRITICAL for debugging position bug)
  static Future<void> logPositionCalculation(Map<String, dynamic> context) async {
    await _writeToFile('=' * 80);
    await info('POSITION CALCULATION');
    for (final entry in context.entries) {
      await debug('  ${entry.key}: ${entry.value}');
    }
    await _writeToFile('=' * 80);
  }

  /// Log hand start
  static Future<void> logHandStart(int handNumber, Map<String, dynamic> context) async {
    await _writeToFile('');
    await _writeToFile('=== HAND #$handNumber STARTED ===');
    await info('HAND #$handNumber STARTED');
    for (final entry in context.entries) {
      await debug('  ${entry.key}: ${entry.value}');
    }
    await _writeToFile('=== END HAND START ===');
  }

  /// Log hand completion
  static Future<void> logHandComplete(int handNumber, Map<String, dynamic> context) async {
    await _writeToFile('=== HAND #$handNumber COMPLETED ===');
    await info('HAND #$handNumber COMPLETED');
    for (final entry in context.entries) {
      await debug('  ${entry.key}: ${entry.value}');
    }
    await _writeToFile('=== END HAND COMPLETE ===');
    await _writeToFile('');
  }

  /// Log session start
  static Future<void> logSessionStart(String sessionId, Map<String, dynamic> context) async {
    await _writeToFile('');
    await _writeToFile('=== SESSION STARTED ===');
    await info('Session ID: $sessionId');
    for (final entry in context.entries) {
      await debug('  ${entry.key}: ${entry.value}');
    }

    // Analytics event
    await logEvent('session_start', parameters: {
      'session_id': sessionId,
      if (context['gameType'] != null) 'game_type': context['gameType'].toString(),
    });
  }

  /// Log session end
  static Future<void> logSessionEnd(String sessionId, Map<String, dynamic> context) async {
    await _writeToFile('=== SESSION ENDED ===');
    await info('Session ID: $sessionId');
    for (final entry in context.entries) {
      await debug('  ${entry.key}: ${entry.value}');
    }
    await _writeToFile('');

    // Analytics event
    await logEvent('session_end', parameters: {
      'session_id': sessionId,
      if (context['totalHands'] != null) 'total_hands': context['totalHands'] as Object,
      if (context['durationMinutes'] != null) 'duration_minutes': context['durationMinutes'] as Object,
    });
  }

  // ---------------------------------------------------------------------------
  // File management (unchanged)
  // ---------------------------------------------------------------------------

  /// Get log file path
  static Future<String?> getLogFilePath() async {
    if (_logFile == null) {
      await initialize();
    }
    return _logFile?.path;
  }

  /// Get log file content
  static Future<String> exportLogs() async {
    if (_logFile == null) {
      await initialize();
    }

    try {
      if (await _logFile!.exists()) {
        return await _logFile!.readAsString();
      } else {
        return 'No log file found';
      }
    } catch (e) {
      return 'Error reading log file: $e';
    }
  }

  /// Clear all logs
  static Future<void> clearLogs() async {
    if (_logFile == null) {
      await initialize();
    }

    try {
      if (await _logFile!.exists()) {
        await _logFile!.writeAsString('');
        await initialize(); // Re-write header
        await info('Logs cleared');
      }
    } catch (e) {
      debugPrint('Failed to clear logs: $e');
    }
  }

  /// Get log file size in MB
  static Future<double> getLogFileSize() async {
    if (_logFile == null) {
      await initialize();
    }

    try {
      if (await _logFile!.exists()) {
        final size = await _logFile!.length();
        return size / (1024 * 1024); // Convert to MB
      }
    } catch (e) {
      debugPrint('Failed to get log file size: $e');
    }
    return 0.0;
  }
}
