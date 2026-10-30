import 'package:shared_preferences/shared_preferences.dart';

/// Persisted "show amounts in BB" preference for the Hand Details screen.
///
/// The value is cached in a static after the first load, so a hand screen
/// built by a swipe reads it synchronously on its first frame (no flicker).
class HandDisplayPrefs {
  HandDisplayPrefs._();

  static const String key = 'hand_details_show_bb';
  static bool _showBB = false;
  static bool _loaded = false;

  /// Current value. Defaults to false until [load] has completed.
  static bool get showBB => _showBB;

  /// Reads the stored value once; later calls are no-ops.
  static Future<bool> load() async {
    if (_loaded) return _showBB;
    try {
      final prefs = await SharedPreferences.getInstance();
      _showBB = prefs.getBool(key) ?? false;
      _loaded = true;
    } catch (_) {}
    return _showBB;
  }

  /// Updates the cache at once, then persists (best effort).
  static Future<void> setShowBB(bool value) async {
    _showBB = value;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }

  /// Test hook: forget the cache so the next [load] reads storage again.
  static void debugReset() {
    _showBB = false;
    _loaded = false;
  }
}
