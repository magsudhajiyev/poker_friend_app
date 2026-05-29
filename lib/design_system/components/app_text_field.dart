import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reusable light-theme text input.
///
/// States
/// ──────
/// Default  — border #EFEFEF 1px, label #B9B9B9
/// Focused  — border #4CDE78 1.5px, label #0C0C0C
/// Filled   — border #EFEFEF 1px, text #0C0C0C
/// Error    — border #E85A5A 1px, red message below
/// Disabled — bg #F5F5F5, text #B9B9B9
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
      borderColor = const Color(0xFFE85A5A);
      borderWidth = 1.0;
    } else if (isFocused) {
      borderColor = const Color(0xFF4CDE78);
      borderWidth = 1.5;
    } else {
      borderColor = const Color(0xFFEFEFEF);
      borderWidth = 1.0;
    }

    final labelColor = isFocused ? const Color(0xFF0C0C0C) : const Color(0xFFB9B9B9);
    final bgColor = isDisabled ? const Color(0xFFF5F5F5) : const Color(0xFFFDFDFD);

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
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  maxLines: widget.maxLines,
                  minLines: widget.minLines,
                  enabled: widget.enabled,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    color: isDisabled
                        ? const Color(0xFFB9B9B9)
                        : const Color(0xFF0C0C0C),
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: GoogleFonts.ibmPlexSans(
                      fontSize: 15,
                      color: const Color(0xFFB9B9B9),
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
                    child: Icon(Icons.cancel, color: Color(0xFFB9B9B9), size: 16),
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
              color: const Color(0xFFE85A5A),
            ),
          ),
        ],
      ],
    );
  }
}
