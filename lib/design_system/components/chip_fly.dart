import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// A single poker chip that flies from the bottom of its parent (hero's
/// seat area) to the center (the pot) when it mounts. Fades out at the
/// end and self-removes via [onComplete].
///
/// Meant to overlay the poker table via a `Positioned.fill`+`IgnorePointer`
/// wrapper so the animation floats above the felt without absorbing taps.
///
/// The [color] is typically brand-tinted by the action that triggered it
/// (green for bet/raise/all-in, cyan for call).
class ChipFly extends StatefulWidget {
  final Color color;
  final VoidCallback onComplete;

  /// Total animation duration = [travelDuration] + [fadeDuration].
  final Duration travelDuration;
  final Duration fadeDuration;

  const ChipFly({
    super.key,
    required this.color,
    required this.onComplete,
    this.travelDuration = const Duration(milliseconds: 320),
    this.fadeDuration = const Duration(milliseconds: 140),
  });

  @override
  State<ChipFly> createState() => _ChipFlyState();
}

class _ChipFlyState extends State<ChipFly> {
  Alignment _alignment = const Alignment(0, 0.8); // near bottom
  double _opacity = 1.0;
  double _scale = 0.6;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Kick off the travel — target the pot at the vertical center.
      setState(() {
        _alignment = Alignment.center;
        _scale = 1.0;
      });
      await Future.delayed(widget.travelDuration);
      if (!mounted) return;
      // Land + fade + shrink slightly.
      setState(() {
        _opacity = 0;
        _scale = 0.85;
      });
      await Future.delayed(widget.fadeDuration);
      if (mounted) widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedAlign(
      alignment: _alignment,
      duration: widget.travelDuration,
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: widget.fadeDuration,
        curve: Curves.easeIn,
        child: AnimatedScale(
          scale: _scale,
          duration: widget.travelDuration,
          curve: Curves.easeOut,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper — pick a chip color based on the action that triggered the fly.
Color chipFlyColorFor(String action) {
  final normalized = action.toLowerCase();
  if (normalized == 'bet' ||
      normalized == 'raise' ||
      normalized == 'all-in' ||
      normalized == 'allin') {
    return AppColors.accentSecondary;
  }
  if (normalized == 'call') {
    return AppColors.accentInfo;
  }
  return Colors.white;
}
