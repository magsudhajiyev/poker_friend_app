import 'package:intl/intl.dart';
import '../services/currency_service.dart';

/// Format large numbers with K/M suffixes for compact display
/// - 1,100,000 → "1.1M"
/// - 240,000 → "240K"
/// - 1,000 → "1K"
/// - 500 → "500"
String formatCompactNumber(num number) {
  final absNum = number.abs();
  final sign = number < 0 ? '-' : '';

  if (absNum >= 1000000) {
    final val = absNum / 1000000;
    // Show decimal only if not a whole number
    final formatted = val % 1 == 0
        ? val.toInt().toString()
        : val.toStringAsFixed(1);
    return '$sign${formatted}M';
  } else if (absNum >= 1000) {
    final val = absNum / 1000;
    // Show decimal only if not a whole number
    final formatted = val % 1 == 0
        ? val.toInt().toString()
        : val.toStringAsFixed(1);
    return '$sign${formatted}K';
  }

  return NumberFormat('#,###').format(number);
}

/// Format with currency symbol for cash display
/// - 240,000 → "$240K" or "240Kzł"
/// - 1,100,000 → "$1.1M" or "1.1Mzł"
String formatCompactCurrency(num number) {
  return CurrencyService.formatCompact(number);
}
