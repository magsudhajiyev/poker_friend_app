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
