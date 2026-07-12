import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/colors.dart';
import 'sheets/app_sheet.dart';

/// Reusable bottom sheet drawer with a standardized header (close, title,
/// checkmark save).
///
/// Public API preserved; internally delegates to [AppSheet]. The legacy
/// [backgroundColor] and [borderRadius] parameters are accepted but ignored —
/// [AppSheet] applies the canonical [AppColors.bgPrimary] surface and
/// [AppDecorations.radiusXl] top corners so every drawer looks the same.
class FormDrawer extends StatelessWidget {
  final String title;
  final VoidCallback onSave;
  final VoidCallback? onClose;
  final Widget body;
  final double heightFraction;
  final Color backgroundColor;
  final double borderRadius;
  final bool showBorderDecoration;
  final bool scrollable;
  final Key? saveButtonKey;

  const FormDrawer({
    super.key,
    required this.title,
    required this.onSave,
    required this.body,
    this.onClose,
    this.heightFraction = 0.9,
    this.backgroundColor = Colors.black,
    this.borderRadius = 32,
    this.showBorderDecoration = true,
    this.scrollable = true,
    this.saveButtonKey,
  });

  /// Show the FormDrawer as a modal bottom sheet.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required VoidCallback onSave,
    required Widget body,
    VoidCallback? onClose,
    double heightFraction = 0.9,
    Color backgroundColor = Colors.black,
    double borderRadius = 32,
    bool showBorderDecoration = true,
    bool isDismissible = true,
    bool enableDrag = true,
    bool scrollable = true,
    Key? saveButtonKey,
  }) {
    return AppSheet.show<T>(
      context: context,
      title: title,
      body: body,
      trailing: _SaveCheckButton(onTap: onSave, buttonKey: saveButtonKey),
      onClose: onClose,
      heightFraction: heightFraction,
      scrollable: scrollable,
      showTopBorder: showBorderDecoration,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: title,
      body: body,
      trailing: _SaveCheckButton(onTap: onSave, buttonKey: saveButtonKey),
      onClose: onClose,
      heightFraction: heightFraction,
      scrollable: scrollable,
      showTopBorder: showBorderDecoration,
    );
  }
}

class _SaveCheckButton extends StatelessWidget {
  final VoidCallback onTap;
  final Key? buttonKey;

  const _SaveCheckButton({required this.onTap, this.buttonKey});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: buttonKey,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: AppColors.accentPrimary,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: SvgPicture.asset(
            'icons/figma_icons/check.svg',
            width: 20,
            height: 20,
            colorFilter: const ColorFilter.mode(
              AppColors.textInverse,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}
