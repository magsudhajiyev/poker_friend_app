import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppButtonVariant {
  primaryLarge,
  primarySmall,
  secondaryLarge,
  secondarySmall,
  destructive,
  ghost,
  black,
  white,
}

/// Multi-variant button matching Figma v2 spec (Button component).
///
/// All variants use radius 999px (pill shape).
/// Use [AppButtonVariant] to select the visual style.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final AppButtonVariant variant;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.label,
    this.onTap,
    this.variant = AppButtonVariant.primaryLarge,
    this.leadingIcon,
    this.trailingIcon,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final spec = _specFor(variant);

    Widget content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leadingIcon != null) ...[leadingIcon!, const SizedBox(width: 8)],
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            fontSize: spec.fontSize,
            fontWeight: FontWeight.w600,
            color: spec.textColor,
            height: 20 / spec.fontSize,
            letterSpacing: -0.5,
          ),
        ),
        if (trailingIcon != null) ...[const SizedBox(width: 8), trailingIcon!],
      ],
    );

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1.0,
        child: Container(
          width: fullWidth ? double.infinity : null,
          padding: spec.padding,
          decoration: BoxDecoration(
            color: spec.bgColor,
            borderRadius: BorderRadius.circular(999),
            border: spec.borderColor != null
                ? Border.all(color: spec.borderColor!, width: 1)
                : null,
          ),
          child: content,
        ),
      ),
    );
  }

  _ButtonSpec _specFor(AppButtonVariant v) {
    switch (v) {
      case AppButtonVariant.primaryLarge:
        return _ButtonSpec(
          bgColor: const Color(0xFF4CDE78),
          textColor: const Color(0xFF0C0C0C),
          fontSize: 15,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        );
      case AppButtonVariant.primarySmall:
        return _ButtonSpec(
          bgColor: const Color(0xFF4CDE78),
          textColor: const Color(0xFF0C0C0C),
          fontSize: 13,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        );
      case AppButtonVariant.secondaryLarge:
        return _ButtonSpec(
          bgColor: Colors.transparent,
          textColor: Colors.white,
          fontSize: 15,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          borderColor: const Color(0xFF3A3A3C),
        );
      case AppButtonVariant.secondarySmall:
        return _ButtonSpec(
          bgColor: Colors.transparent,
          textColor: Colors.white,
          fontSize: 13,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          borderColor: const Color(0xFF3A3A3C),
        );
      case AppButtonVariant.destructive:
        return _ButtonSpec(
          bgColor: const Color(0xFFFF3B30),
          textColor: Colors.white,
          fontSize: 15,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        );
      case AppButtonVariant.ghost:
        return _ButtonSpec(
          bgColor: Colors.transparent,
          textColor: const Color(0xFF4CDE78),
          fontSize: 15,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        );
      case AppButtonVariant.black:
        return _ButtonSpec(
          bgColor: const Color(0xFF0C0C0C),
          textColor: Colors.white,
          fontSize: 15,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        );
      case AppButtonVariant.white:
        return _ButtonSpec(
          bgColor: Colors.white,
          textColor: const Color(0xFF0C0C0C),
          fontSize: 15,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        );
    }
  }
}

class _ButtonSpec {
  final Color bgColor;
  final Color textColor;
  final double fontSize;
  final EdgeInsets padding;
  final Color? borderColor;

  const _ButtonSpec({
    required this.bgColor,
    required this.textColor,
    required this.fontSize,
    required this.padding,
    this.borderColor,
  });
}
