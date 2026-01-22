import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../constants/colors.dart';
import '../../constants/decorations.dart';

/// Glassy card with frosted glass effect using backdrop filter
///
/// This creates a semi-transparent card with blur effect and white border,
/// commonly used for sessions, events, and other content cards.
///
/// Usage:
/// ```dart
/// GlassyCard(
///   child: Text('Content'),
///   padding: EdgeInsets.all(16),
/// )
/// ```
class GlassyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? borderRadius;
  final Color? backgroundColor;
  final double? backgroundOpacity;

  const GlassyCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.backgroundColor,
    this.backgroundOpacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          borderRadius ?? AppDecorations.cardRadius,
        ),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: AppDecorations.blurLight,
            sigmaY: AppDecorations.blurLight,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor != null
                  ? backgroundColor!.withOpacity(
                      backgroundOpacity ?? 0.74,
                    )
                  : AppColors.glassyCardColor(),
              borderRadius: BorderRadius.circular(
                borderRadius ?? AppDecorations.cardRadius,
              ),
              border: Border.all(
                color: AppColors.whiteBorder(),
                width: AppDecorations.borderThin,
              ),
            ),
            padding: padding ?? const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
