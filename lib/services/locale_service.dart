import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService {
  static const _key = 'app_locale';
  static final ValueNotifier<Locale?> localeNotifier = ValueNotifier(null);

  /// Load saved locale on app startup. null = use system locale.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code != null) {
      localeNotifier.value = Locale(code);
    }
  }

  /// Set locale and persist. Pass null to revert to system default.
  static Future<void> setLocale(Locale? locale) async {
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
    localeNotifier.value = locale;
  }

  /// Current locale code or null for system default.
  static String? get currentLocaleCode => localeNotifier.value?.languageCode;
}
