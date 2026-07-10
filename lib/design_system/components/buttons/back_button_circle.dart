import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/colors.dart';

/// Circular back button — Figma node 766:5417.
/// 44px circle, bgElevated (#2C2C2E) background, 24px white CaretLeft icon.
/// Defaults to popping the current route; pass [onPressed] to override.
class BackButtonCircle extends StatelessWidget {
  final VoidCallback? onPressed;
  final double size;

  const BackButtonCircle({
    Key? key,
    this.onPressed,
    this.size = 44,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed ?? () => Navigator.of(context).maybePop(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
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
    );
  }
}
