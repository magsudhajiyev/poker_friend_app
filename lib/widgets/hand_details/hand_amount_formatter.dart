import '../../services/currency_service.dart';
import '../../utils/number_formatter.dart';

/// How an action's amount is worded on a row.
enum AmountStyle {
  /// No amount to show (fold / check / zero).
  none,

  /// A plain amount: "1.2K".
  plain,

  /// A total the player raised to: "to 1.2K".
  raiseTo,
}

/// Pure formatting helpers for the Hand Details screen.
///
/// Holds the display mode (big-blind toggle, cash vs tournament) so every
/// widget formats amounts the same way. No Flutter dependency.
class HandAmountFormatter {
  final bool showBB;
  final double bigBlind;
  final bool isCash;

  const HandAmountFormatter({
    required this.showBB,
    required this.bigBlind,
    required this.isCash,
  });

  /// Lenient numeric read: Firestore may return `int` or `double` for the
  /// same field. Returns null for null / non-numeric values.
  static double? toDouble(dynamic value) =>
      value is num ? value.toDouble() : null;

  /// "12BB" / "12.5BB".
  String bb(double value) {
    final bbValue = value / (bigBlind <= 0 ? 2.0 : bigBlind);
    if (bbValue == bbValue.roundToDouble()) return '${bbValue.toInt()}BB';
    return '${bbValue.toStringAsFixed(1)}BB';
  }

  String _money(double v) =>
      isCash ? formatCompactCurrency(v) : formatCompactNumber(v);

  /// Stack at the time of an action; '-' when missing or non-positive.
  String stack(dynamic stack) {
    final v = toDouble(stack);
    if (v == null || v <= 0) return '-';
    return showBB ? bb(v) : _money(v);
  }

  /// Amount of an action; '-' when missing or non-positive.
  String amount(dynamic amount) {
    final v = toDouble(amount);
    if (v == null || v <= 0) return '-';
    return showBB ? bb(v) : _money(v);
  }

  /// Pot value for the summary card (compact).
  String summaryPot(dynamic pot) {
    final v = toDouble(pot) ?? 0;
    return showBB ? bb(v) : _money(v);
  }

  /// Pot value for a street header; null when absent or not positive.
  String? streetPot(dynamic pot) {
    final v = toDouble(pot);
    if (v == null || v <= 0) return null;
    if (showBB) return bb(v);
    return isCash ? CurrencyService.formatCash(v) : '${v.toInt()}';
  }

  /// Preflop raises store the TOTAL ("raise to"); every other amount is the
  /// chips put in on that action.
  static AmountStyle amountStyle({
    required String action,
    required String street,
    required dynamic amount,
  }) {
    final v = toDouble(amount);
    if (v == null || v <= 0) return AmountStyle.none;
    final a = action.toLowerCase();
    final isRaise = a == 'raise' || a == 'all-in' || a == 'allin';
    return street == 'preflop' && isRaise
        ? AmountStyle.raiseTo
        : AmountStyle.plain;
  }
}
