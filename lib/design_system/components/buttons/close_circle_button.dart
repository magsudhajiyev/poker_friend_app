import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../constants/colors.dart';

/// Canonical circular X close button used inside dialog & sheet headers.
///
/// 38×38 glassy circle (BackdropFilter blur + semi-transparent white fill +
/// subtle white 15% border), containing a 16×16 white X icon
/// (`assets/icons/X.svg`).
class CloseCircleButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: size,
            height: size,
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
                width: iconSize,
                height: iconSize,
                colorFilter: const ColorFilter.mode(
                  AppColors.textPrimary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
