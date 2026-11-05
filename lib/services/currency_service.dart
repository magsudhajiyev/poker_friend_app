import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/currency.dart';
import '../utils/number_formatter.dart';

class CurrencyService {
  static const _key = 'currency_code';
  static final ValueNotifier<Currency> currencyNotifier =
      ValueNotifier(Currency.all.first);

  /// Load saved currency on app startup. Defaults to USD.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code != null) {
      currencyNotifier.value = Currency.fromCode(code);
    }
  }

  /// Set currency and persist.
  static Future<void> setCurrency(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
    currencyNotifier.value = Currency.fromCode(code);
    unawaited(mirrorToProfile(code));
  }

  /// Pure: the `users/{uid}` payload that mirrors the effective currency
  /// code. The app is the single source of truth for the web dashboard, so
  /// the default (USD) is mirrored too. Unknown codes fall back to USD.
  static Map<String, dynamic> mirrorPayload(String? code) {
    final known = Currency.all.any((c) => c.code == code);
    return {'currency': known ? code : Currency.all.first.code};
  }

  /// Mirror the EFFECTIVE currency to `users/{uid}.currency` so the web
  /// dashboard formats money the same way. Fire-and-forget: never throws.
  /// Rules already allow owner writes to non-tier fields on users/{uid}.
  static Future<void> mirrorToProfile([String? code]) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(mirrorPayload(code ?? CurrencyService.code),
              SetOptions(merge: true))
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Currency mirror failed: $e');
    }
  }

  /// On every sign-in (incl. session restore) mirror the effective currency,
  /// which also backfills existing users. Call once at startup.
  static void initMirror() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) unawaited(mirrorToProfile());
    });
  }

  /// Reset to default currency (USD). Called on logout so the next user
  /// starts with the default instead of inheriting the previous user's choice.
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    currencyNotifier.value = Currency.all.first; // USD
  }

  // --- Convenience getters ---

  static Currency get current => currencyNotifier.value;
  static String get symbol => current.symbol;
  static String get code => current.code;

  /// Symbol for input field prefix (null if suffix currency).
  static String? get prefixText =>
      current.position == SymbolPosition.prefix ? '${current.symbol} ' : null;

  /// Symbol for input field suffix (null if prefix currency).
  static String? get suffixText =>
      current.position == SymbolPosition.suffix ? ' ${current.symbol}' : null;

  // --- Formatting ---

  /// Format cash amount with symbol: "$25.50" or "25.50 zł"
  static String formatCash(double amount) {
    final decimal = current.decimalPlaces;
    final formatted = amount.toStringAsFixed(decimal);
    if (current.position == SymbolPosition.prefix) {
      return '${current.symbol} $formatted';
    }
    return '$formatted ${current.symbol}';
  }

  /// Format cash amount with no decimals: "$25" or "25zł"
  static String formatCashRounded(double amount) {
    final formatted = amount.toStringAsFixed(0);
    if (current.position == SymbolPosition.prefix) {
      return '${current.symbol} $formatted';
    }
    return '$formatted ${current.symbol}';
  }

  /// Format tournament chips — no symbol, no decimals: "1500"
  static String formatChips(double amount) {
    return '${amount.toInt()}';
  }

  /// Format bankroll display: compact (K/M) for values > 9999, rounded otherwise.
  /// Always includes space between number and symbol.
  static String formatBankroll(double amount) {
    final num = amount.abs() > 9999
        ? formatCompactNumber(amount)
        : amount.toStringAsFixed(0);
    if (current.position == SymbolPosition.prefix) {
      return '${current.symbol} $num';
    }
    return '$num ${current.symbol}';
  }

  /// Format compact with symbol: "$ 240K" or "240K zł"
  static String formatCompact(num amount) {
    final compact = formatCompactNumber(amount);
    if (current.position == SymbolPosition.prefix) {
      return '${current.symbol} $compact';
    }
    return '$compact ${current.symbol}';
  }
}
