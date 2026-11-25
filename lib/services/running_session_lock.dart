import 'package:flutter/foundation.dart';

import 'live_session_logic.dart';
import 'live_session_notification_service.dart';

/// Fair play while a session runs: hands of the session that is still RUNNING
/// (tracked or full) can't be analysed by AI, shared, exported or captured
/// until it ends. The source of truth is the live-session record, the same
/// one Home's bar and the notification use; hand groups never have one, so
/// they are never locked. The lock lifts by itself when the record clears.
class RunningSessionLock {
  RunningSessionLock._();

  /// Fires when the running session starts or ends.
  static ValueListenable<LiveSessionRecord?> get changes =>
      LiveSessionNotificationService.running;

  static bool isRunning(String? sessionId) {
    if (sessionId == null || sessionId.isEmpty) return false;
    return changes.value?.sessionId == sessionId;
  }

  /// [hand] is a hand map carrying its `sessionId`.
  static bool lockedHand(Map<String, dynamic> hand) =>
      isRunning(hand['sessionId'] as String?);

  /// Tests force the iOS behaviour with true / the Android one with false.
  @visibleForTesting
  static bool? debugForceIos;

  /// iOS cannot block screenshots, so the action section of a running-session
  /// hand is blurred there. Android uses FLAG_SECURE and needs no blur.
  static bool get blursActions =>
      debugForceIos ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);
}
