import 'package:flutter/material.dart';

/// Stagger-in helper for onboarding step content.
///
/// Wraps a list of [children] and reveals them in order with a fade +
/// slight upward slide as the containing step becomes visible. Because
/// each onboarding step lives inside a PageView that lazily builds its
/// current child, `initState` fires when the step is first shown — the
/// animation runs then and doesn't re-run on back-navigation
/// (steps use `AutomaticKeepAliveClientMixin`).
///
/// Usage inside a step's `child:` column:
///
/// ```dart
/// StepReveal(
///   children: [
///     Title(...),
///     Subtitle(...),
///     Row(...pills...),
///   ],
/// )
/// ```
///
/// Non-animated siblings (fixed top spacer, footer CTAs) should stay
/// outside the reveal — those are laid out by `OnboardingScaffold`.
class StepReveal extends StatefulWidget {
  final List<Widget> children;

  /// Time each child takes to fade + slide in.
  final Duration itemDuration;

  /// Gap between successive children's start times.
  final Duration stagger;

  /// Delay before the first child starts revealing. Small pause so the
  /// step transition finishes settling first.
  final Duration initialDelay;

  /// Vertical translation (px) each child rises from.
  final double translateY;

  const StepReveal({
    super.key,
    required this.children,
    this.itemDuration = const Duration(milliseconds: 420),
    this.stagger = const Duration(milliseconds: 70),
    this.initialDelay = const Duration(milliseconds: 180),
    this.translateY = 16,
  });

  @override
  State<StepReveal> createState() => _StepRevealState();
}

class _StepRevealState extends State<StepReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final int _totalMs;

  @override
  void initState() {
    super.initState();
    _totalMs = widget.itemDuration.inMilliseconds +
        widget.stagger.inMilliseconds * widget.children.length;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _totalMs),
    );
    Future.delayed(widget.initialDelay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < widget.children.length; i++)
          _RevealItem(
            controller: _controller,
            totalMs: _totalMs,
            startMs: widget.stagger.inMilliseconds * i,
            durationMs: widget.itemDuration.inMilliseconds,
            translateY: widget.translateY,
            child: widget.children[i],
          ),
      ],
    );
  }
}

class _RevealItem extends StatelessWidget {
  final AnimationController controller;
  final int totalMs;
  final int startMs;
  final int durationMs;
  final double translateY;
  final Widget child;

  const _RevealItem({
    required this.controller,
    required this.totalMs,
    required this.startMs,
    required this.durationMs,
    required this.translateY,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final anim = CurvedAnimation(
      parent: controller,
      curve: Interval(
        startMs / totalMs,
        (startMs + durationMs) / totalMs,
        curve: Curves.easeOutCubic,
      ),
    );
    return AnimatedBuilder(
      animation: anim,
      child: child,
      builder: (context, child) {
        final t = anim.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, translateY * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}
