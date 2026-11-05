import 'dart:ui' show Locale, PlatformDispatcher;

import '../l10n/app_localizations.dart';
import 'locale_service.dart';

/// [AppLocalizations] without a BuildContext — for notification text built in
/// services (no widget tree). Uses the same language the UI uses: the
/// Settings choice, else the device language, else English for anything
/// unsupported.
class AppL10nLookup {
  AppL10nLookup._();

  static AppLocalizations current() {
    final chosen = LocaleService.localeNotifier.value;
    final device = PlatformDispatcher.instance.locale;
    for (final l in [chosen, device]) {
      if (l == null) continue;
      try {
        return lookupAppLocalizations(Locale(l.languageCode));
      } catch (_) {}
    }
    return lookupAppLocalizations(const Locale('en'));
  }
}
