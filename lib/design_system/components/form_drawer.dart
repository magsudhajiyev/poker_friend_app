import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reusable bottom sheet drawer with standardized header (close, title, save).
///
/// Use [FormDrawer.show] to display as a modal bottom sheet.
/// Pass your form content as [body] — it will be scrollable with keyboard inset handling.
class FormDrawer extends StatelessWidget {
  final String title;
  final VoidCallback onSave;
  final VoidCallback? onClose;
  final Widget body;
  final double heightFraction;
  final Color backgroundColor;
  final double borderRadius;
  final bool showBorderDecoration;
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
    Key? saveButtonKey,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      builder: (context) => FormDrawer(
        title: title,
        onSave: onSave,
        onClose: onClose,
        body: body,
        heightFraction: heightFraction,
        backgroundColor: backgroundColor,
        borderRadius: borderRadius,
        showBorderDecoration: showBorderDecoration,
        saveButtonKey: saveButtonKey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * heightFraction,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(borderRadius),
            topRight: Radius.circular(borderRadius),
          ),
          border: showBorderDecoration
              ? Border.all(color: const Color(0xFF262626))
              : null,
          boxShadow: showBorderDecoration
              ? const [
                  BoxShadow(
                    color: Color(0xFF2E5A59),
                    blurRadius: 64,
                    offset: Offset(0, -6),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 0),
              child: SizedBox(
                height: 68,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Close (X) button
                  GestureDetector(
                    onTap: onClose ?? () => Navigator.pop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2C2C2E),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          'icons/figma_icons/close.svg',
                          width: 15,
                          height: 15,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Title
                  Text(
                    title,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: -0.43,
                      height: 22 / 17,
                    ),
                  ),
                  // Save (checkmark) button
                  GestureDetector(
                    key: saveButtonKey,
                    onTap: onSave,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Color(0xFF89F1EC),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          'icons/figma_icons/check.svg',
                          width: 24,
                          height: 24,
                          colorFilter: const ColorFilter.mode(
                            Color(0xFF1A4A4A),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Scrollable body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 22),
              child: body,
            ),
          ),
        ],
      ),
      ),
    );
  }
}
