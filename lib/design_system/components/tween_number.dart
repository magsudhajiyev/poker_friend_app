import 'package:flutter/material.dart';

/// Text widget that animates its numeric value when it changes.
///
/// On first mount it renders the value immediately (no intro animation).
/// On subsequent rebuilds with a different [value], it tweens from the
/// previous value to the new one over [duration]. Use for bankroll,
/// current stack, pot amount, session P/L — anywhere a number shifts as
/// a result of user action.
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

  const TweenNumber({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeOutCubic,
    this.textAlign,
  });

  @override
  State<TweenNumber> createState() => _TweenNumberState();
}

class _TweenNumberState extends State<TweenNumber> {
  late double _previousValue;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
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
