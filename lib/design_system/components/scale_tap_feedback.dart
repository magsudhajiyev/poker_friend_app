import 'package:flutter/material.dart';

/// Wraps a tappable child with a subtle press-in scale animation.
///
/// On `onTapDown` the child scales to [pressedScale] (default 0.98) over
/// [duration]. Releases back to 1.0 on tap up or cancel. Owns the tap
/// handling — pass [onTap] / [onLongPress] via this widget rather than
/// on the child.
///
/// Use to make full-width rows (session cards, opponent cards, hand
/// list rows) feel responsive without adding a decoration change.
class ScaleTapFeedback extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final GestureLongPressStartCallback? onLongPressStart;
  final HitTestBehavior behavior;
  final double pressedScale;
  final Duration duration;
  final Curve curve;

  const ScaleTapFeedback({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onLongPressStart,
    this.behavior = HitTestBehavior.opaque,
    this.pressedScale = 0.98,
    this.duration = const Duration(milliseconds: 120),
    this.curve = Curves.easeOut,
  });

  @override
  State<ScaleTapFeedback> createState() => _ScaleTapFeedbackState();
}

class _ScaleTapFeedbackState extends State<ScaleTapFeedback> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onLongPressStart: widget.onLongPressStart,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      behavior: widget.behavior,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: widget.duration,
        curve: widget.curve,
        child: widget.child,
      ),
    );
  }
}
