import 'package:shared_preferences/shared_preferences.dart';

/// "Don't show again" for the note on the hand-saved dialog that says AI
/// analysis and sharing unlock when the session ends. Also a Settings toggle
/// (the setting shows the note, so "hidden" is its inverse).
class SessionHandInfoPref {
  SessionHandInfoPref._();

  static const String key = 'single_hand_session_info_hidden';

  static Future<bool> hidden() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setHidden(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }
}
