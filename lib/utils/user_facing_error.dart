import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import '../l10n/app_localizations.dart';
import '../services/locale_service.dart';

/// Converts raw exceptions into short, localized, human-readable messages.
///
/// User-facing surfaces (snackbars, dialogs) must never show
/// `e.toString()` — stack traces, JSON bodies, and "Exception:" prefixes
/// mean nothing to players. Use `UserFacingError.message(e)` instead;
/// keep the raw error in debugPrint/LoggerService for diagnosis.
///
/// Context-free on purpose: resolves the active locale via LocaleService
/// (falling back to the platform locale) so it can be used in any catch
/// block without threading a BuildContext through.
class UserFacingError {
  UserFacingError._();

  static AppLocalizations get _l10n {
    try {
      final code = LocaleService.currentLocaleCode;
      final locale = code != null
          ? Locale(code)
          : WidgetsBinding.instance.platformDispatcher.locale;
      return lookupAppLocalizations(locale);
    } catch (_) {
      return lookupAppLocalizations(const Locale('en'));
    }
  }

  /// Short, human message for [error]. Never returns raw exception text.
  static String message(Object? error) {
    final l10n = _l10n;
    final raw = error?.toString() ?? '';
    final lower = raw.toLowerCase();

    // Connectivity
    if (error is SocketException ||
        lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('network-request-failed') ||
        lower.contains('unavailable')) {
      return l10n.errorNoConnection;
    }
    if (error is TimeoutException || lower.contains('timeoutexception')) {
      return l10n.errorTimeout;
    }

    // Permissions (Firestore rules, auth)
    if (lower.contains('permission-denied') ||
        lower.contains('permission denied') ||
        lower.contains('unauthenticated') ||
        lower.contains('requires-recent-login')) {
      return l10n.errorNotAuthorized;
    }

    // Backend HTTP failures wrapped as "Server returned <code>: <body>"
    final statusMatch = RegExp(r'(?:server returned|status(?: code)?)[ :]*(\d{3})')
        .firstMatch(lower);
    if (statusMatch != null) {
      final code = int.tryParse(statusMatch.group(1)!) ?? 0;
      if (code == 401 || code == 403) return l10n.errorNotAuthorized;
      if (code >= 400) return l10n.errorServer;
    }
    if (lower.contains('502') || lower.contains('bad gateway')) {
      return l10n.errorServer;
    }

    // A deliberately thrown human-readable String (AuthService pattern:
    // `throw 'No account found with this email'`) passes through untouched —
    // it IS the user-facing message. Technical payloads were mapped above.
    if (error is String &&
        error.trim().isNotEmpty &&
        error.length < 140 &&
        !lower.contains('exception') &&
        !lower.contains('stacktrace') &&
        !lower.contains('{')) {
      return error.trim();
    }

    return l10n.errorGeneric;
  }
}
