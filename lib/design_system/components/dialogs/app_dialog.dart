import 'dart:ui';

import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../constants/decorations.dart';
import '../../constants/spacing.dart';
import 'dialog_header.dart';

/// Canonical dark-mode dialog scaffold.
///
/// Renders a blurred + dimmed backdrop, and a centred [AppColors.bgSurface]
/// card (radius [AppDecorations.radiusXl]) hosting an optional [DialogHeader],
/// a required [body], and an optional [actions] row (typically a
/// [DialogActionBar]).
///
/// Use [AppDialog.show] for standard presentation.
class AppDialog extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget body;
  final Widget? actions;
  final VoidCallback? onClose;
  final double maxWidth;
  final EdgeInsets padding;
  final bool showCloseButton;
  final bool barrierDismissible;

  const AppDialog({
    super.key,
    this.title,
    this.subtitle,
    required this.body,
    this.actions,
    this.onClose,
    this.maxWidth = 400,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.showCloseButton = true,
    this.barrierDismissible = true,
  });

  static Future<T?> show<T>(
    BuildContext context, {
    String? title,
    String? subtitle,
    required Widget body,
    Widget? actions,
    VoidCallback? onClose,
    double maxWidth = 400,
    EdgeInsets padding = const EdgeInsets.all(AppSpacing.xl),
    bool showCloseButton = true,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: title ?? 'Dialog',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (_, animation, __, child) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      pageBuilder: (_, __, ___) => AppDialog(
        title: title,
        subtitle: subtitle,
        body: body,
        actions: actions,
        onClose: onClose,
        maxWidth: maxWidth,
        padding: padding,
        showCloseButton: showCloseButton,
        barrierDismissible: barrierDismissible,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasHeader = title != null;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: barrierDismissible ? () => Navigator.pop(context) : null,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.zero,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius:
                        BorderRadius.circular(AppDecorations.radiusXl),
                  ),
                  padding: padding,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasHeader) ...[
                        DialogHeader(
                          title: title!,
                          subtitle: subtitle,
                          onClose: showCloseButton
                              ? (onClose ?? () => Navigator.pop(context))
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      body,
                      if (actions != null) ...[
                        const SizedBox(height: AppSpacing.xxxl),
                        actions!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
