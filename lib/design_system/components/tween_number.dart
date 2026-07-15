import 'package:flutter/material.dart';

/// Text widget that animates its numeric value.
///
/// Two modes:
/// - By default, first mount renders [value] immediately. Subsequent
///   [value] changes tween from the previous value → new value over
///   [duration]. Use for numbers that shift as a result of user action
///   (bankroll after a bet, current stack, session P/L).
/// - Set [animateOnMount] to `true` to make the widget count up from
///   [mountFrom] (default 0) → [value] on its first appearance. Use for
///   hero numbers on load — bankroll on Home, stats percentages, session
///   counts — where the animation is the first thing the user sees.
///
/// The [format] callback converts the animated `double` back to display
/// text (e.g. `CurrencyService.formatCash`, `(v) => v.toStringAsFixed(0)`).
class TweenNumber extends StatefulWidget {
  final double value;
  final String Function(double) format;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final TextAlign? textAlign;

  /// When true, the initial mount animates from [mountFrom] → [value]
  /// instead of rendering [value] instantly. Ideal for hero stats.
  final bool animateOnMount;

  /// Starting value for the mount animation. Only used when
  /// [animateOnMount] is true. Defaults to 0.
  final double mountFrom;

  const TweenNumber({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeOutCubic,
    this.textAlign,
    this.animateOnMount = false,
    this.mountFrom = 0,
  });

  @override
  State<TweenNumber> createState() => _TweenNumberState();
}

class _TweenNumberState extends State<TweenNumber> {
  late double _previousValue;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.animateOnMount ? widget.mountFrom : widget.value;
  }

  @override
  void didUpdateWidget(TweenNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _previousValue, end: widget.value),
      duration: widget.duration,
      curve: widget.curve,
      builder: (_, v, __) => Text(
        widget.format(v),
        style: widget.style,
        textAlign: widget.textAlign,
      ),
    );
  }
}
