import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../bodies/message_body.dart';
import '../dialogs/app_dialog.dart';
import '../dialogs/dialog_action_bar.dart';

/// Standard confirmation dialog used for destructive actions (delete, remove, etc.).
///
/// Public API preserved; renders on the shared [AppDialog] scaffold.
///
/// Usage:
/// ```dart
/// ConfirmDialog.show(
///   context,
///   title: 'Delete Account',
///   message: 'This action cannot be undone.',
///   confirmLabel: 'Delete',
///   onConfirm: () async => await _deleteAccount(),
/// );
/// ```
class ConfirmDialog {
  ConfirmDialog._();

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    Color confirmColor = AppColors.accentDanger,
    Color confirmTextColor = AppColors.textPrimary,
    VoidCallback? onConfirm,
  }) {
    return AppDialog.show<void>(
      context,
      title: title,
      body: MessageBody(message),
      actions: DialogActionBar(
        confirmLabel: confirmLabel,
        confirmColor: confirmColor,
        confirmTextColor: confirmTextColor,
        onConfirm: onConfirm,
      ),
    );
  }

  /// Await-friendly variant that resolves to `true` if the user confirmed and
  /// `false` if they cancelled or dismissed by tapping the backdrop.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    Color confirmColor = AppColors.accentDanger,
    Color confirmTextColor = AppColors.textPrimary,
  }) async {
    bool confirmed = false;
    await AppDialog.show<void>(
      context,
      title: title,
      body: MessageBody(message),
      actions: DialogActionBar(
        confirmLabel: confirmLabel,
        confirmColor: confirmColor,
        confirmTextColor: confirmTextColor,
        onConfirm: () => confirmed = true,
      ),
    );
    return confirmed;
  }
}
