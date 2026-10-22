import 'dart:async';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart' show PackageType;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import 'auth_service.dart';
import 'locale_service.dart';
import 'notification_service.dart';
import 'subscription_logic.dart';
import 'subscription_service.dart';

/// "Your free trial ends tomorrow" — the on-device reminder before a store
/// free trial converts to a paid subscription (hard paywall step 4).
///
/// Re-syncs on EVERY RevenueCat entitlement snapshot (start, purchase,
/// cancel, resume), so a cancelled or converted trial removes the reminder
/// and a new trial schedules one. Timing + decision are pure
/// ([decideTrialReminder]); this layer only does IO.
///
/// Dedupe with the server backup push (`sendTrialReminders` CF): when the
/// device has scheduled (or shown) the reminder for a trial end, it stamps
/// `users/{uid}.trialReminderScheduledForMs` = that end; the server skips
/// users with a matching stamp, so nobody gets two reminders.
class TrialReminderService {
  TrialReminderService._();

  /// The trial end (ms) this device already scheduled or showed.
  static const _handledKey = 'trial_reminder_handled_ends_ms';

  static StreamSubscription<Object?>? _sub;

  /// Start listening (idempotent). Call once after SubscriptionService init.
  static void start() {
    _sub ??= SubscriptionService.entitlementsStream
        .listen((_) => unawaited(sync()));
    unawaited(sync());
  }

  /// Bring the queued reminder in line with the current trial. Never throws.
  static Future<void> sync() async {
    try {
      final decision =
          decideTrialReminder(SubscriptionService.trialStatus, DateTime.now());
      final prefs = await SharedPreferences.getInstance();
      final handled = prefs.getInt(_handledKey);

      switch (decision.action) {
        case TrialReminderAction.cancel:
          await NotificationService.cancelTrialReminder();
          if (handled != null) {
            await prefs.remove(_handledKey);
            await _stampScheduledFor(null);
          }
        case TrialReminderAction.schedule:
          final (title, body) = _copy();
          // Re-scheduled on every sync (fixed id) so the price stays current.
          await NotificationService.scheduleTrialReminder(
              at: decision.at!, title: title, body: body);
          if (handled != decision.endsAtMs) {
            await prefs.setInt(_handledKey, decision.endsAtMs!);
            await _stampScheduledFor(decision.endsAtMs);
          }
        case TrialReminderAction.showNow:
          // Fire ONCE per trial end — not on every app open.
          if (handled == decision.endsAtMs) return;
          final (title, body) = _copy();
          await NotificationService.showTrialReminderNow(
              title: title, body: body);
          await prefs.setInt(_handledKey, decision.endsAtMs!);
          await _stampScheduledFor(decision.endsAtMs);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Trial reminder sync failed: $e');
    }
  }

  /// Debug-only: show the reminder now with the real copy (sandbox trials
  /// last minutes, so the real 24 h timing can't be waited for).
  static Future<void> debugShowNow() async {
    if (kReleaseMode) return;
    final (title, body) = _copy();
    await NotificationService.showTrialReminderNow(title: title, body: body);
  }

  static (String, String) _copy() {
    final package = SubscriptionService.trialPackage;
    return buildCopy(
      _l10n(),
      tier: SubscriptionService.currentTier,
      priceString: package?.storeProduct.priceString,
      isAnnual: package?.packageType == PackageType.annual,
    );
  }

  /// Notification title + body (pure, unit-tested). [tier] is
  /// 'pro' | 'elite' | 'club'; without a known price the body omits it.
  @visibleForTesting
  static (String, String) buildCopy(
    AppLocalizations l10n, {
    required String tier,
    required String? priceString,
    required bool isAnnual,
  }) {
    final plan = switch (tier) {
      'elite' => 'Elite',
      'club' => 'Club',
      _ => 'Pro',
    };
    final body = priceString == null
        ? l10n.trialReminderBodyNoPrice(plan)
        : l10n.trialReminderBody(
            plan,
            isAnnual
                ? l10n.paywallPriceYearly(priceString)
                : l10n.paywallPriceMonthly(priceString));
    return (l10n.trialReminderTitle, body);
  }

  /// The user's app language (Settings choice, else the device's), falling
  /// back to English for anything unsupported.
  static AppLocalizations _l10n() {
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

  static Future<void> _stampScheduledFor(int? endsAtMs) async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'trialReminderScheduledForMs': endsAtMs ?? FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Best effort — worst case the server sends its backup push too.
    }
  }
}
