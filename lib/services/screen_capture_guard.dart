import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Blocks screenshots / screen recording while a screen with live-session
/// hands is visible (fair play). Android: FLAG_SECURE on the window. iOS: no
/// API stops screenshots, so the native side covers the app with a privacy
/// view while the screen is being recorded or mirrored.
///
/// Reference counted: a pager can hold several hand screens at once, and the
/// flag is cleared only when the last one lets go.
class ScreenCaptureGuard {
  ScreenCaptureGuard._();

  static const MethodChannel channel =
      MethodChannel('com.finaltable.app/screen_capture');

  static int _holders = 0;

  @visibleForTesting
  static int get holders => _holders;

  static Future<void> acquire() async {
    _holders++;
    if (_holders == 1) await _set(true);
  }

  static Future<void> release() async {
    if (_holders == 0) return;
    _holders--;
    if (_holders == 0) await _set(false);
  }

  @visibleForTesting
  static void resetForTest() => _holders = 0;

  /// Best effort: a missing native side (tests, desktop, web) is not an error.
  static Future<void> _set(bool secure) async {
    try {
      await channel.invokeMethod<void>('setSecure', {'secure': secure});
    } on MissingPluginException {
      // No native implementation on this platform.
    } on PlatformException {
      // Leave the screen usable.
    }
  }
}

/// One screen's hold on [ScreenCaptureGuard]: [update] acquires or releases
/// only on a change, [dispose] always lets go. Owns exactly one count.
class CaptureHold {
  bool _held = false;

  bool get held => _held;

  void update(bool locked) {
    if (locked == _held) return;
    _held = locked;
    if (locked) {
      ScreenCaptureGuard.acquire();
    } else {
      ScreenCaptureGuard.release();
    }
  }

  void dispose() => update(false);
}
