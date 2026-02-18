import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../buttons/glassy_icon_button.dart';

/// Main screen header with title, subtitle, username, and action buttons
///
/// Glassmorphic header designed for the main screen with support for
/// displaying username, title, subtitle, and up to two action buttons.
///
/// Usage:
/// ```dart
/// MainScreenHeader(
///   username: 'John Doe',
///   title: 'Statistics',
///   subtitle: 'Advanced Analytics',
///   leftIcon: Icons.arrow_back,
///   onLeftPressed: () => Navigator.pop(context),
///   rightIcon: Icons.refresh,
///   onRightPressed: () => refreshData(),
/// )
/// ```
class MainScreenHeader extends StatelessWidget {
  final String? username;
  final String title;
  final String? subtitle;
  final IconData? leftIcon;
  final String? leftImagePath;
  final VoidCallback? onLeftPressed;
  final IconData? rightIcon;
  final String? rightImagePath;
  final VoidCallback? onRightPressed;
  final bool showLeftIcon;
  final EdgeInsets? padding;
  final bool showRightBadge;

  const MainScreenHeader({
    super.key,
    this.username,
    required this.title,
    this.subtitle,
    this.leftIcon,
    this.leftImagePath,
    this.onLeftPressed,
    this.rightIcon,
    this.rightImagePath,
    this.onRightPressed,
    this.showLeftIcon = true,
    this.padding,
    this.showRightBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0x03FFFFFF), // #ffffff03
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left side: Title, subtitle, and username
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title (greeting with username or just title)
                          Text(
                            username != null ? 'Hey, $username' : title,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0,
                              height: 1.0,
                            ),
                          ),
                          // Subtitle
                          if (subtitle != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              subtitle!,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: Colors.white,
                                letterSpacing: 0,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Right side: Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showLeftIcon && (leftIcon != null || leftImagePath != null) && onLeftPressed != null) ...[
                    GlassyIconButton(
                      icon: leftIcon,
                      imagePath: leftImagePath,
                      onPressed: onLeftPressed!,
                    ),
                    const SizedBox(width: 4),
                  ],
                  if ((rightIcon != null || rightImagePath != null) && onRightPressed != null)
                    GlassyIconButton(
                      icon: rightIcon,
                      imagePath: rightImagePath,
                      onPressed: onRightPressed!,
                      showBadge: showRightBadge,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
