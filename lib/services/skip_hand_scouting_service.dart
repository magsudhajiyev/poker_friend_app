import 'package:shared_preferences/shared_preferences.dart';

/// Persists the "Skip Hand Scouting" preference.
///
/// When enabled, folding preflop enters live **scouting mode** in the hand
/// logger (see `poker_hand_screen.dart` `_scoutingMode` / `_finishScoutedHand`):
/// the hero keeps logging the opponents' real preflop action (type-only, no bet
/// sizes) and the hand is finished early as a preflop-only `isScouted` record
/// that feeds opponent stats. This service only owns the on/off toggle.
class SkipHandScoutingService {
  static const _key = 'skip_hand_scouting_enabled';
  static bool _enabled = false;

  /// Load preference on app startup.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_key) ?? false;
  }

  /// Whether scouting mode is enabled.
  static bool get isEnabled => _enabled;

  /// Persist the toggle.
  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
