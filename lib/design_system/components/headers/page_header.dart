import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../constants/typography.dart';
import '../buttons/glassy_icon_button.dart';

/// Page header with title, subtitle, and optional action buttons
///
/// Displays a glassmorphic header with title, subtitle, and up to two
/// action buttons (e.g., back button, refresh button).
///
/// Usage:
/// ```dart
/// PageHeader(
///   title: 'Statistics',
///   subtitle: 'Advanced Analytics',
///   leftIcon: Icons.arrow_back,
///   onLeftPressed: () => Navigator.pop(context),
///   rightIcon: Icons.refresh,
///   onRightPressed: () => refreshData(),
/// )
/// ```
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? leftIcon;
  final VoidCallback? onLeftPressed;
  final IconData? rightIcon;
  final VoidCallback? onRightPressed;
  final EdgeInsets? padding;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leftIcon,
    this.onLeftPressed,
    this.rightIcon,
    this.onRightPressed,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0x03FFFFFF), // #ffffff03
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Title and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0,
                        height: 1.0,
                      ),
                    ),
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

              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leftIcon != null && onLeftPressed != null) ...[
                    GlassyIconButton(
                      icon: leftIcon!,
                      onPressed: onLeftPressed!,
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (rightIcon != null && onRightPressed != null)
                    GlassyIconButton(
                      icon: rightIcon!,
                      onPressed: onRightPressed!,
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
