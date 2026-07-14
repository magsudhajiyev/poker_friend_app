import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// Shimmer placeholder for content that's loading.
///
/// A rounded rectangle that pulses between two dark surface tones
/// (`bgSurface` ↔ `bgElevated`) over 1200ms. Compose multiple to sketch
/// the shape of the incoming UI — better perceived performance than a
/// bare spinner because the layout doesn't shift when data arrives.
///
/// Example:
/// ```dart
/// Column(children: [
///   Skeleton(width: 200, height: 20),
///   const SizedBox(height: 8),
///   Skeleton(width: 120, height: 14),
/// ]);
/// ```
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const Skeleton({
    super.key,
    this.width,
    required this.height,
    this.borderRadius,
  });

  /// Circular variant — for avatar tiles and icon placeholders.
  factory Skeleton.circle({Key? key, required double size}) => Skeleton(
        key: key,
        width: size,
        height: size,
        borderRadius: BorderRadius.circular(size / 2),
      );

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
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
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
              AppColors.bgSurface,
              AppColors.bgElevated,
              _controller.value,
            ),
            borderRadius: widget.borderRadius ?? BorderRadius.circular(4),
          ),
        );
      },
    );
  }
}
