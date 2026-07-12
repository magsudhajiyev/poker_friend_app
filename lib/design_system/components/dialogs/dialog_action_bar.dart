import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../constants/decorations.dart';
import '../../constants/spacing.dart';
import '../../constants/typography.dart';

/// Standard action bar for [AppDialog].
///
/// Renders an outlined Cancel pill on the left and a solid Confirm pill on the
/// right. Confirm colour defaults to [AppColors.accentPrimary]; pass
/// [AppColors.accentDanger] for destructive actions.
class DialogActionBar extends StatelessWidget {
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final Color confirmColor;
  final Color confirmTextColor;
  final bool enabled;

  /// When `true` (default), tapping confirm/cancel dismisses the dialog before
  /// invoking the callback. Set `false` for form dialogs where the callback
  /// needs to `Navigator.pop(context, value)` itself.
  final bool autoDismiss;

  const DialogActionBar({
    super.key,
    this.cancelLabel = 'Cancel',
    required this.confirmLabel,
    this.onCancel,
    this.onConfirm,
    this.confirmColor = AppColors.accentPrimary,
    this.confirmTextColor = AppColors.textInverse,
    this.enabled = true,
    this.autoDismiss = true,
  });

  /// Single-button variant — just an outlined dismiss pill spanning the row.
  const DialogActionBar.single({
    super.key,
    this.cancelLabel = 'Close',
    this.onCancel,
  })  : confirmLabel = '',
        onConfirm = null,
        confirmColor = AppColors.accentPrimary,
        confirmTextColor = AppColors.textInverse,
        enabled = true,
        autoDismiss = true;

  bool get _isSingle => confirmLabel.isEmpty;

  VoidCallback _wrap(BuildContext context, VoidCallback? cb) {
    if (cb == null) return () => Navigator.pop(context);
    if (!autoDismiss) return cb;
    return () {
      Navigator.pop(context);
      cb();
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isSingle) {
      return _OutlinedPill(
        label: cancelLabel,
        onTap: _wrap(context, onCancel),
      );
    }
    return Row(
      children: [
        Expanded(
          child: _OutlinedPill(
            label: cancelLabel,
            onTap: _wrap(context, onCancel),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _SolidPill(
            label: confirmLabel,
            color: confirmColor,
            textColor: confirmTextColor,
            enabled: enabled,
            onTap: enabled ? _wrap(context, onConfirm) : null,
          ),
        ),
      ],
    );
  }
}

class _OutlinedPill extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _OutlinedPill({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space5,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.ibm(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            height: 20 / 15,
          ),
        ),
      ),
    );
  }
}

class _SolidPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final bool enabled;
  final VoidCallback? onTap;

  const _SolidPill({
    required this.label,
    required this.color,
    required this.textColor,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space5,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.ibm(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textColor,
              height: 20 / 15,
            ),
          ),
        ),
      ),
    );
  }
}
