import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Micro-animation building blocks for the hand logging screen.
///
/// Kept UI-framework-only (no game state imports) so they can be reused by
/// other screens (dealer table, player session) later.

// ─────────────────────────────────────────────────────────────────────────
// AnimatedAmountText — rolling number for pot / stack values
// ─────────────────────────────────────────────────────────────────────────

/// Text widget that rolls between numeric values instead of jumping.
/// Optionally pulses (brief scale-up) when the value increases.
class AnimatedAmountText extends StatefulWidget {
  final double value;
  final String Function(double) formatter;
  final TextStyle style;
  final Duration duration;
  final bool pulseOnIncrease;

  const AnimatedAmountText({
    super.key,
    required this.value,
    required this.formatter,
    required this.style,
    this.duration = const Duration(milliseconds: 450),
    this.pulseOnIncrease = false,
  });

  @override
  State<AnimatedAmountText> createState() => _AnimatedAmountTextState();
}

class _AnimatedAmountTextState extends State<AnimatedAmountText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late double _fromValue;
  late double _toValue;
  bool _pulse = false;

  @override
  void initState() {
    super.initState();
    _fromValue = widget.value;
    _toValue = widget.value;
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didUpdateWidget(AnimatedAmountText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _toValue) {
      _fromValue = _currentValue;
      _pulse = widget.pulseOnIncrease && widget.value > _toValue;
      _toValue = widget.value;
      _controller
        ..duration = widget.duration
        ..forward(from: 0.0);
    }
  }

  double get _currentValue {
    final t = Curves.easeOutCubic.transform(_controller.value);
    return _fromValue + (_toValue - _fromValue) * t;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Pulse: quick scale up in the first 40%, ease back down after
        double scale = 1.0;
        if (_pulse) {
          final t = _controller.value;
          scale = t < 0.4
              ? 1.0 + 0.12 * Curves.easeOut.transform(t / 0.4)
              : 1.0 + 0.12 * (1 - Curves.easeIn.transform((t - 0.4) / 0.6));
        }
        return Transform.scale(
          scale: scale,
          child: Text(widget.formatter(_currentValue), style: widget.style),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// PopIn — entrance pop (scale + fade) for pills/badges
// ─────────────────────────────────────────────────────────────────────────

/// Plays a scale 0.7→1.0 (easeOutBack) + fade entrance when first built,
/// and replays it whenever [triggerKey] changes. An optional [delay] holds
/// the child invisible before the entrance — used to stagger a batch of
/// pills so actions ripple around the table instead of appearing at once.
class PopIn extends StatefulWidget {
  final Widget child;
  final Object? triggerKey;
  final Duration duration;
  final Duration delay;

  const PopIn({
    super.key,
    required this.child,
    this.triggerKey,
    this.duration = const Duration(milliseconds: 240),
    this.delay = Duration.zero,
  });

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _play();
  }

  void _play() {
    _delayTimer?.cancel();
    if (widget.delay == Duration.zero) {
      _controller.forward(from: 0.0);
    } else {
      _controller.value = 0.0; // invisible until its turn in the ripple
      _delayTimer = Timer(widget.delay, () {
        if (mounted) _controller.forward(from: 0.0);
      });
    }
  }

  @override
  void didUpdateWidget(PopIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.triggerKey != oldWidget.triggerKey) {
      _play();
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// PulseGlow — breathing glow ring for "it's your turn" emphasis
// ─────────────────────────────────────────────────────────────────────────

/// Wraps [child] in a softly pulsing box-shadow glow while [enabled].
/// The controller only runs while enabled, so idle seats cost nothing.
class PulseGlow extends StatefulWidget {
  final Widget child;
  final Color color;
  final BorderRadius borderRadius;
  final bool enabled;

  const PulseGlow({
    super.key,
    required this.child,
    required this.color,
    required this.borderRadius,
    this.enabled = true,
  });

  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PulseGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      _controller.repeat(reverse: true);
    } else if (!widget.enabled && oldWidget.enabled) {
      _controller.stop();
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.18 + 0.24 * t),
                blurRadius: 10 + 8 * t,
                spreadRadius: 1 + 1.5 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Chip flight — chips arcing from a seat to the pot (or pot to winner)
// ─────────────────────────────────────────────────────────────────────────

/// A single in-flight chip animation frame, in the overlay's local
/// coordinate space. The owner drives [progress] from its own controller.
class ChipFlightFrame {
  final Offset start;
  final Offset end;
  final Color color;
  final double progress; // 0.0 → 1.0
  final int seed;
  final int chipCount;

  const ChipFlightFrame({
    required this.start,
    required this.end,
    required this.color,
    required this.progress,
    required this.seed,
    this.chipCount = 4,
  });
}

/// Paints chips travelling along a slight arc with per-chip stagger,
/// scale-in at launch and fade-out on arrival.
class ChipFlightPainter extends CustomPainter {
  final List<ChipFlightFrame> flights;

  ChipFlightPainter({required this.flights});

  @override
  void paint(Canvas canvas, Size size) {
    for (final flight in flights) {
      _paintFlight(canvas, flight);
    }
  }

  void _paintFlight(Canvas canvas, ChipFlightFrame flight) {
    final rnd = math.Random(flight.seed);
    final delta = flight.end - flight.start;
    final distance = delta.distance;
    if (distance < 1) return;

    // Perpendicular unit vector for the arc's control point
    final perp = Offset(-delta.dy, delta.dx) / distance;
    final arcSign = rnd.nextBool() ? 1.0 : -1.0;

    for (int i = 0; i < flight.chipCount; i++) {
      // Stagger each chip's launch
      final delay = i * 0.10;
      final span = 1.0 - (flight.chipCount - 1) * 0.10;
      final t = ((flight.progress - delay) / span).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final eased = Curves.easeInOutCubic.transform(t);

      // Quadratic bezier: start → control (arched midpoint) → end
      final arcHeight =
          distance * (0.12 + rnd.nextDouble() * 0.10) * arcSign;
      final jitter = Offset(
        (rnd.nextDouble() - 0.5) * 10,
        (rnd.nextDouble() - 0.5) * 10,
      );
      final control =
          flight.start + delta / 2 + perp * arcHeight + jitter;

      final oneMinus = 1 - eased;
      final pos = flight.start * (oneMinus * oneMinus) +
          control * (2 * oneMinus * eased) +
          flight.end * (eased * eased);

      // Scale in quickly at launch, fade out on arrival
      final launchScale = (t / 0.15).clamp(0.0, 1.0);
      final arrivalFade = t > 0.82 ? ((1 - t) / 0.18).clamp(0.0, 1.0) : 1.0;
      final radius = 5.0 * Curves.easeOut.transform(launchScale);
      if (radius <= 0 || arrivalFade <= 0) continue;

      _drawChip(canvas, pos, radius, flight.color, arrivalFade);
    }
  }

  void _drawChip(
      Canvas canvas, Offset center, double radius, Color color, double alpha) {
    // Body
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = color.withValues(alpha: alpha),
    );
    // Edge ring (chip rim)
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    // Inner dot
    canvas.drawCircle(
      center,
      radius * 0.4,
      Paint()..color = Colors.black.withValues(alpha: 0.25 * alpha),
    );
  }

  @override
  bool shouldRepaint(ChipFlightPainter oldDelegate) => true;
}
