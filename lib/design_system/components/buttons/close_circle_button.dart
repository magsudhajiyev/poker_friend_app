import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../constants/colors.dart';

/// Canonical circular X close button used inside dialog & sheet headers.
///
/// 38×38 glassy circle (BackdropFilter blur + semi-transparent white fill +
/// subtle white 15% border), containing a 16×16 white X icon
/// (`assets/icons/X.svg`).
///
/// Subtle press animation (lighter cousin of [BackButtonCircle]'s):
/// 1. **Press down** — scale 1.0 → 1.15 in 130ms `Curves.easeOut`.
/// 2. **Hold** — 100ms after tap-up so the effect stays visible on quick taps.
/// 3. **Release** — scale 1.15 → 1.0 in 260ms `Curves.easeOutBack` for a
///    gentle overshoot instead of a hard shrink.
class CloseCircleButton extends StatefulWidget {
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  const CloseCircleButton({
    super.key,
    required this.onTap,
    this.size = 38,
    this.iconSize = 16,
  });

  @override
  State<CloseCircleButton> createState() => _CloseCircleButtonState();
}

class _CloseCircleButtonState extends State<CloseCircleButton>
    with SingleTickerProviderStateMixin {
  static const Duration _pressDuration = Duration(milliseconds: 130);
  static const Duration _holdDuration = Duration(milliseconds: 100);
  static const Duration _releaseDuration = Duration(milliseconds: 260);
  static const double _pressedScale = 1.15;

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
        reverseCurve: Curves.easeOutBack,
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
      onTap: widget.onTap,
      onTapDown: (_) => _handlePressDown(),
      onTapUp: (_) => _handlePressUp(),
      onTapCancel: _handlePressUp,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scale,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Center(
                child: SvgPicture.asset(
                  'assets/icons/X.svg',
                  width: widget.iconSize,
                  height: widget.iconSize,
                  colorFilter: const ColorFilter.mode(
                    AppColors.textPrimary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
