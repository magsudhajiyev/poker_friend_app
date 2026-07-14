import 'package:flutter/material.dart';

/// Wraps a chart (or any widget) and animates a left-to-right reveal on
/// first mount by animating a right-side clip from 0 to full width.
///
/// The child paints normally — this widget just crops what's visible via
/// a [ClipRect] whose right edge sweeps across the width over [duration].
/// Composes cleanly with `fl_chart`'s `LineChart` — no need to touch
/// chart data or the library's own animations.
class ChartRevealClip extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Curve curve;

  const ChartRevealClip({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 900),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<ChartRevealClip> createState() => _ChartRevealClipState();
}

class _ChartRevealClipState extends State<ChartRevealClip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _progress = CurvedAnimation(parent: _controller, curve: widget.curve);
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) => ClipRect(
        clipper: _RevealClipper(_progress.value),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _RevealClipper extends CustomClipper<Rect> {
  final double progress;
  const _RevealClipper(this.progress);

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, 0, size.width * progress, size.height);

  @override
  bool shouldReclip(covariant _RevealClipper old) => old.progress != progress;
}
