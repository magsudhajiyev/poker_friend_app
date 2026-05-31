import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Standard confirmation dialog used for destructive actions (delete, remove, etc.).
///
/// Style: blurred backdrop, white rounded card (radius 24), grey body text,
/// outlined Cancel pill on the left, solid-colour action pill on the right.
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
///
/// For non-destructive confirmations pass a different [confirmColor].
class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final Color confirmTextColor;
  final VoidCallback? onConfirm;

  const ConfirmDialog._({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    required this.confirmTextColor,
    this.onConfirm,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    Color confirmColor = const Color(0xFFFF3B30),
    Color confirmTextColor = Colors.white,
    VoidCallback? onConfirm,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: title,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (_, animation, __, child) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      pageBuilder: (dialogContext, _, __) => ConfirmDialog._(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        confirmColor: confirmColor,
        confirmTextColor: confirmTextColor,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Blurred backdrop — tap to dismiss
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.zero,
              child: Container(
                width: 370,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: title + X
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0C0C0C),
                              height: 20 / 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close, size: 18, color: Color(0xFFB9B9B9)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Body
                    Text(
                      message,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFFB9B9B9),
                        height: 22 / 15,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: const Color(0xFFB9B9B9)),
                              ),
                              child: Text(
                                'Cancel',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0C0C0C),
                                  height: 20 / 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              onConfirm?.call();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: confirmColor,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                confirmLabel,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: confirmTextColor,
                                  height: 20 / 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
