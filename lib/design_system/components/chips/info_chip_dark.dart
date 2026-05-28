import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum InfoChipVariant {
  /// Default: `#2C2C2E` filled, icon on left.
  filled,
  /// Border only: transparent bg + `#2C2C2E` border.
  outlined,
  /// Icon on right side instead of left.
  iconRight,
  /// Light mode: `#EBEBF0` bg, `#0C0C0C` text.
  light,
}

/// Info chip matching Figma v2 spec (Info Chip Dark / Light variants).
///
/// Default: `#2C2C2E` bg, radius 999px, px8 py4.
/// Text: IBM Plex Sans Medium 11px, `#B9B9B9`.
/// Optional 12px icon on left (or right for iconRight variant).
class InfoChipDark extends StatelessWidget {
  final String label;
  final Widget? icon;
  final InfoChipVariant variant;

  const InfoChipDark({
    super.key,
    required this.label,
    this.icon,
    this.variant = InfoChipVariant.filled,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = variant == InfoChipVariant.light;
    final isOutlined = variant == InfoChipVariant.outlined;
    final iconOnRight = variant == InfoChipVariant.iconRight;

    final bgColor = isLight
        ? const Color(0xFFEBEBF0)
        : isOutlined
            ? Colors.transparent
            : const Color(0xFF2C2C2E);

    final textColor = isLight ? const Color(0xFF0C0C0C) : const Color(0xFFB9B9B9);

    final resolvedIcon = icon != null
        ? SizedBox(width: 12, height: 12, child: icon)
        : null;

    final textWidget = Text(
      label,
      style: GoogleFonts.ibmPlexSans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: textColor,
        height: 16 / 11,
      ),
    );

    final children = <Widget>[
      if (resolvedIcon != null && !iconOnRight) ...[resolvedIcon, const SizedBox(width: 4)],
      textWidget,
      if (resolvedIcon != null && iconOnRight) ...[const SizedBox(width: 4), resolvedIcon],
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: isOutlined
            ? Border.all(color: const Color(0xFF2C2C2E), width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}
