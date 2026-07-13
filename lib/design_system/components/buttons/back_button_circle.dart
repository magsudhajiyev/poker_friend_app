import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/colors.dart';

/// Circular back button — Figma node 766:5417.
///
/// 38px circle, `bgElevated` (#2C2C2E) background, 24px white CaretLeft icon.
/// Defaults to popping the current route; pass [onPressed] to override.
///
/// Press animation (B+D combo, tuned for maximum obviousness):
/// 1. **Press down** — scale 1.0 → 1.2 in 150ms `Curves.easeOut`.
/// 2. **Hold** — after tap-up the scaled state is held for 120ms so the
///    effect is visible even on lightning-fast taps.
/// 3. **Release** — scale 1.2 → 1.0 in 350ms `Curves.elasticOut`, giving a
///    subtle iOS-style spring settle instead of a symmetric shrink.
class BackButtonCircle extends StatefulWidget {
  final VoidCallback? onPressed;
  final double size;

  const BackButtonCircle({
    Key? key,
    this.onPressed,
    this.size = 38,
  }) : super(key: key);

  @override
  State<BackButtonCircle> createState() => _BackButtonCircleState();
}

class _BackButtonCircleState extends State<BackButtonCircle>
    with SingleTickerProviderStateMixin {
  static const Duration _pressDuration = Duration(milliseconds: 150);
  static const Duration _holdDuration = Duration(milliseconds: 120);
  static const Duration _releaseDuration = Duration(milliseconds: 350);
  static const double _pressedScale = 1.2;

  late final AnimationController _controller;
  late final Animation<double> _scale;
  Timer? _releaseTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _pressDuration,
      reverseDuration: _releaseDuration,
    );
    _scale = Tween<double>(begin: 1.0, end: _pressedScale).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _releaseTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handlePressDown() {
    _releaseTimer?.cancel();
    _controller.forward();
  }

  void _handlePressUp() {
    _releaseTimer?.cancel();
    _releaseTimer = Timer(_holdDuration, () {
      if (!mounted) return;
      _controller.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed ?? () => Navigator.of(context).maybePop(),
      onTapDown: (_) => _handlePressDown(),
      onTapUp: (_) => _handlePressUp(),
      onTapCancel: _handlePressUp,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: const BoxDecoration(
            color: AppColors.bgElevated,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: SvgPicture.asset(
              'assets/icons/CaretLeft.svg',
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(
                AppColors.textPrimary,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
