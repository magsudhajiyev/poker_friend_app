import 'package:flutter/material.dart';
import 'dart:ui' as ui;

/// Glassy icon button with iOS-style glassmorphism effect
///
/// Creates a circular button with frosted glass effect, perfect for
/// notification bells, profile icons, and other header actions.
///
/// Usage:
/// ```dart
/// GlassyIconButton(
///   icon: Icons.notifications,
///   onPressed: () => showNotifications(),
/// )
/// ```
/// Or with image asset:
/// ```dart
/// GlassyIconButton(
///   imagePath: 'icons/flat_icons/bell.png',
///   onPressed: () => showNotifications(),
/// )
/// ```
class GlassyIconButton extends StatelessWidget {
  final IconData? icon;
  final String? imagePath;
  final VoidCallback onPressed;
  final double? size;
  final double? iconSize;
  final Color? backgroundColor;
  final Color? iconColor;

  const GlassyIconButton({
    super.key,
    this.icon,
    this.imagePath,
    required this.onPressed,
    this.size,
    this.iconSize,
    this.backgroundColor,
    this.iconColor,
  }) : assert(icon != null || imagePath != null, 'Either icon or imagePath must be provided');

  @override
  Widget build(BuildContext context) {
    final buttonSize = size ?? 38.0;
    final buttonIconSize = iconSize ?? 24.0;

    return ClipOval(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            color: backgroundColor ?? const Color(0x1AFFFFFF), // #ffffff1a
            shape: BoxShape.circle,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              splashColor: Colors.white.withOpacity(0.1),
              highlightColor: Colors.white.withOpacity(0.05),
              child: Center(
                child: imagePath != null
                    ? Image.asset(
                        imagePath!,
                        width: buttonIconSize,
                        height: buttonIconSize,
                        color: iconColor ?? Colors.white,
                      )
                    : Icon(
                        icon,
                        size: buttonIconSize,
                        color: iconColor ?? Colors.white,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
