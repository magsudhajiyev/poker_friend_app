import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

/// Log levels for categorizing messages
enum LogLevel {
  DEBUG,   // Detailed information for debugging
  INFO,    // General informational messages
  WARNING, // Warning messages for potential issues
  ERROR    // Error messages for actual problems
}

/// Comprehensive logging service for debugging poker app during live sessions
/// Logs to local file with timestamps and log levels for post-session analysis
class LoggerService {
  static const String LOG_FILE_NAME = 'poker_logger_session.log';
  static File? _logFile;
  static bool _initialized = false;

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
      await _writeToFile('═' * 80);
      await _writeToFile('POKER LOGGER SESSION STARTED');
      await _writeToFile('Timestamp: ${DateTime.now().toIso8601String()}');
      await _writeToFile('═' * 80);
    } catch (e) {
      debugPrint('❌ Failed to initialize LoggerService: $e');
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
      debugPrint('❌ Failed to write to log file: $e');
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
    final formattedMessage = _formatMessage(message, level);
    await _writeToFile(formattedMessage);

    // Also print to console for real-time debugging
    final emoji = _getEmojiForLevel(level);
    debugPrint('$emoji $formattedMessage');
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

  static Future<void> error(String message, [dynamic errorObject]) async {
    if (errorObject != null) {
      await log('$message | Error: $errorObject', level: LogLevel.ERROR);
    } else {
      await log(message, level: LogLevel.ERROR);
    }
  }

  /// Log hand action with context
  static Future<void> logHandAction(String action, Map<String, dynamic> context) async {
    await _writeToFile('─' * 80);
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
    await warning('BUTTON CHANGE: $oldPosition → $newPosition');
    await debug('  Reason: $reason');
  }

  /// Log stack update
  static Future<void> logStackUpdate(int player, double oldStack, double newStack, String reason) async {
    final change = newStack - oldStack;
    final changeStr = change >= 0 ? '+${change.toStringAsFixed(2)}' : change.toStringAsFixed(2);
    await info('STACK UPDATE: Player $player: ${oldStack.toStringAsFixed(2)} → ${newStack.toStringAsFixed(2)} ($changeStr)');
    await debug('  Reason: $reason');
  }

  /// Log position calculation (CRITICAL for debugging position bug)
  static Future<void> logPositionCalculation(Map<String, dynamic> context) async {
    await _writeToFile('━' * 80);
    await info('POSITION CALCULATION');
    for (final entry in context.entries) {
      await debug('  ${entry.key}: ${entry.value}');
    }
    await _writeToFile('━' * 80);
  }

  /// Log hand start
  static Future<void> logHandStart(int handNumber, Map<String, dynamic> context) async {
    await _writeToFile('');
    await _writeToFile('╔' + '═' * 78 + '╗');
    await info('HAND #$handNumber STARTED');
    for (final entry in context.entries) {
      await debug('  ${entry.key}: ${entry.value}');
    }
    await _writeToFile('╚' + '═' * 78 + '╝');
  }

  /// Log hand completion
  static Future<void> logHandComplete(int handNumber, Map<String, dynamic> context) async {
    await _writeToFile('╔' + '═' * 78 + '╗');
    await info('HAND #$handNumber COMPLETED');
    for (final entry in context.entries) {
      await debug('  ${entry.key}: ${entry.value}');
    }
    await _writeToFile('╚' + '═' * 78 + '╝');
    await _writeToFile('');
  }

  /// Log session start
  static Future<void> logSessionStart(String sessionId, Map<String, dynamic> context) async {
    await _writeToFile('');
    await _writeToFile('╔' + '═' * 78 + '╗');
    await _writeToFile('║' + ' SESSION STARTED '.padRight(78) + '║');
    await _writeToFile('╚' + '═' * 78 + '╝');
    await info('Session ID: $sessionId');
    for (final entry in context.entries) {
      await debug('  ${entry.key}: ${entry.value}');
    }
  }

  /// Log session end
  static Future<void> logSessionEnd(String sessionId, Map<String, dynamic> context) async {
    await _writeToFile('╔' + '═' * 78 + '╗');
    await _writeToFile('║' + ' SESSION ENDED '.padRight(78) + '║');
    await _writeToFile('╚' + '═' * 78 + '╝');
    await info('Session ID: $sessionId');
    for (final entry in context.entries) {
      await debug('  ${entry.key}: ${entry.value}');
    }
    await _writeToFile('');
  }

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
      debugPrint('❌ Failed to clear logs: $e');
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
      debugPrint('❌ Failed to get log file size: $e');
    }
    return 0.0;
  }
}
