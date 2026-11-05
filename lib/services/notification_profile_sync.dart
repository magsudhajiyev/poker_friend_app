import 'dart:async';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import 'locale_service.dart';
import 'logger_service.dart';

/// Keeps `users/{uid}.notif.tzOffsetMinutes` and `notif.locale` fresh for the
/// SERVER notification scheduler: written on sign-in (incl. the persisted
/// session restore at cold start), on app foreground (travel / DST), and when
/// the user changes the app language — but only when the pair actually
/// changed since the last write on this device.
///
/// Same reliability contract as [ActivityHeartbeatService]: fire-and-forget,
/// never throws, never blocks startup. Uses `update()` (not `set`) so it can
/// never CREATE a bare `users/{uid}` doc and trip the signup trigger.
class NotificationProfileSync {
  NotificationProfileSync._();

  static const _prefsKeyPrefix = 'notif_profile_sync_';
  static StreamSubscription<User?>? _authSub;

  /// Call once at startup. Idempotent.
  static void init() {
    _authSub?.cancel();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) unawaited(sync());
    });
    LocaleService.localeNotifier.removeListener(_onLocaleChanged);
    LocaleService.localeNotifier.addListener(_onLocaleChanged);
  }

  static void _onLocaleChanged() => unawaited(sync());

  /// The app's EFFECTIVE language code: the Settings choice, else the
  /// device's, else English — restricted to [supported] (pure, unit-tested).
  static String effectiveLocaleCode(
    Locale? chosen,
    Locale device,
    Iterable<String> supported,
  ) {
    final ok = supported.toSet();
    for (final l in [chosen, device]) {
      if (l != null && ok.contains(l.languageCode)) return l.languageCode;
    }
    return 'en';
  }

  /// Pure: whether the (tz, locale) pair differs from what this device last
  /// wrote. `null` last = never written.
  static bool needsWrite(
          String? last, int tzOffsetMinutes, String localeCode) =>
      last != '$tzOffsetMinutes|$localeCode';

  /// Write tz + locale if changed. Safe to call from any hook.
  static Future<void> sync() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final tz = DateTime.now().timeZoneOffset.inMinutes;
      final code = effectiveLocaleCode(
        LocaleService.localeNotifier.value,
        PlatformDispatcher.instance.locale,
        AppLocalizations.supportedLocales.map((l) => l.languageCode),
      );
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefsKeyPrefix$uid';
      if (!needsWrite(prefs.getString(key), tz, code)) return;
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'notif.tzOffsetMinutes': tz,
        'notif.locale': code,
      });
      await prefs.setString(key, '$tz|$code');
    } catch (e) {
      unawaited(LoggerService.debug('Notif profile sync failed: $e'));
    }
  }
}
