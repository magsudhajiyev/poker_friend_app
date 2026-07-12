import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';

/// Reusable dark-theme text input.
///
/// States
/// ──────
/// Default  — border `borderStrong` 1px, label `textSecondary`
/// Focused  — border `accentPrimary` 1.5px, label `textPrimary`
/// Filled   — border `borderStrong` 1px, text `textPrimary`
/// Error    — border `accentDanger` 1px, red message below
/// Disabled — bg `bgSurface`, text `textSecondary`
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.focusNode,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines = 1,
    this.enabled = true,
    this.errorText,
    this.onChanged,
    this.showClearButton = true,
    this.autofocus = false,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final int minLines;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool showClearButton;
  final bool autofocus;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final FocusNode _focusNode;
  bool _ownsNode = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _ownsNode = true;
    }
    _focusNode.addListener(_rebuild);
    widget.controller.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _focusNode.removeListener(_rebuild);
    widget.controller.removeListener(_rebuild);
    if (_ownsNode) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final isFocused = _focusNode.hasFocus;
    final isDisabled = !widget.enabled;
    final hasContent = widget.controller.text.isNotEmpty;

    final Color borderColor;
    final double borderWidth;
    if (hasError) {
      borderColor = AppColors.accentDanger;
      borderWidth = 1.0;
    } else if (isFocused) {
      borderColor = AppColors.accentPrimary;
      borderWidth = 1.5;
    } else {
      borderColor = AppColors.borderStrong;
      borderWidth = 1.0;
    }

    final labelColor = isFocused ? AppColors.textPrimary : AppColors.textSecondary;
    final bgColor = isDisabled ? AppColors.bgSurface : AppColors.bgElevated;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: widget.maxLines > 1
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  autofocus: widget.autofocus,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  maxLines: widget.maxLines,
                  minLines: widget.minLines,
                  enabled: widget.enabled,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    color: isDisabled
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: GoogleFonts.ibmPlexSans(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: widget.onChanged,
                ),
              ),
              if (widget.showClearButton && hasContent && !isDisabled)
                GestureDetector(
                  onTap: () {
                    widget.controller.clear();
                    widget.onChanged?.call('');
                  },
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.cancel, color: AppColors.textSecondary, size: 16),
                  ),
                ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Text(
            widget.errorText!,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12,
              color: AppColors.accentDanger,
            ),
          ),
        ],
      ],
    );
  }
}
