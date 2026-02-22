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
  final bool showBadge;
  final int? badgeCount;  // Optional count to display in badge
  final Color? badgeColor;

  const GlassyIconButton({
    super.key,
    this.icon,
    this.imagePath,
    required this.onPressed,
    this.size,
    this.iconSize,
    this.backgroundColor,
    this.iconColor,
    this.showBadge = false,
    this.badgeCount,
    this.badgeColor,
  }) : assert(icon != null || imagePath != null, 'Either icon or imagePath must be provided');

  @override
  Widget build(BuildContext context) {
    final buttonSize = size ?? 38.0;
    final buttonIconSize = iconSize ?? 24.0;

    final button = ClipOval(
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
              splashColor: Colors.white.withValues(alpha: 0.1),
              highlightColor: Colors.white.withValues(alpha: 0.05),
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

    if (!showBadge) return button;

    // Wrap with Stack to show badge
    final bool hasCount = badgeCount != null && badgeCount! > 0;
    final String badgeText = hasCount
        ? (badgeCount! > 9 ? '9+' : '$badgeCount')
        : '';

    return SizedBox(
      width: buttonSize,
      height: buttonSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              constraints: BoxConstraints(
                minWidth: hasCount ? 18 : 10,
                minHeight: hasCount ? 18 : 10,
              ),
              padding: hasCount ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2) : EdgeInsets.zero,
              decoration: BoxDecoration(
                color: badgeColor ?? const Color(0xFFFF3B30),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF0D1117),
                  width: 1.5,
                ),
              ),
              child: hasCount
                  ? Center(
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
