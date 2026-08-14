import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/colors.dart';
import '../../constants/decorations.dart';
import '../../constants/spacing.dart';
import '../../constants/typography.dart';

/// Standard filled text-input row used inside modals.
///
/// Renders a small [AppColors.textSecondary] label above an
/// [AppColors.bgSurface] filled TextField. Uses the same token as the modal
/// card so the input reads as flush with the surface, not a raised chip.
/// Matches the Figma `Input / Dark` component (State=Filled).
class AppFormField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hintText;
  final String? prefixText;
  final String? suffixText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final int? maxLines;
  final ValueChanged<String>? onChanged;

  const AppFormField({
    super.key,
    this.controller,
    required this.label,
    this.hintText,
    this.prefixText,
    this.suffixText,
    this.keyboardType,
    this.inputFormatters,
    this.autofocus = false,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.ibm(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxxs),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          autofocus: autofocus,
          maxLines: maxLines,
          onChanged: onChanged,
          style: AppTypography.ibm(
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTypography.ibm(color: AppColors.textSecondary),
            prefixText: prefixText,
            suffixText: suffixText,
            prefixStyle: AppTypography.ibm(
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
            suffixStyle: AppTypography.ibm(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
            filled: true,
            fillColor: AppColors.bgSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
          ),
        ),
      ],
    );
  }
}

/// Stack of [AppFormField]s used as an [AppDialog] / [AppSheet] body.
///
/// Simply lays out its children in a vertical column with consistent
/// spacing. Use with 2–5 [AppFormField]s.
class FormFields extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const FormFields({
    super.key,
    required this.children,
    this.spacing = AppSpacing.md,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(SizedBox(height: spacing));
      rows.add(children[i]);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }
}
