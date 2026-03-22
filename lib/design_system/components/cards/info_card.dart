import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../../constants/typography.dart';

/// Dark card with empty state support
/// Used for sessions and events sections
class InfoCard extends StatelessWidget {
  final Widget? child;
  final bool isEmpty;
  final String emptyTitle;
  final String emptySubtitle;
  final String? iconPath;
  final Color? iconColor;  // Custom icon color (defaults to white)
  final VoidCallback? onEmptyTap;
  final bool useSessionLayout;  // Use left-aligned layout with icon in circle
  final String? buttonText;  // Optional button text for empty state

  const InfoCard({
    Key? key,
    this.child,
    this.isEmpty = false,
    this.emptyTitle = 'No recent sessions',
    this.emptySubtitle = 'Start your first poker session!',
    this.iconPath,
    this.iconColor,
    this.onEmptyTap,
    this.useSessionLayout = false,
    this.buttonText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.infoCardBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: isEmpty ? _buildEmptyState() : child,
    );
  }

  Widget _buildEmptyState() {
    if (useSessionLayout) {
      return _buildSessionEmptyState();
    }
    return _buildCenteredEmptyState();
  }

  /// Centered empty state (default)
  Widget _buildCenteredEmptyState() {
    return GestureDetector(
      onTap: buttonText == null ? onEmptyTap : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 20, left: 44, right: 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 24,
              height: 24,
              child: iconPath != null
                  ? Image.asset(
                      iconPath!,
                      width: 24,
                      height: 24,
                      color: iconColor ?? Colors.white,
                    )
                  : _buildPlaceholderIcon(),
            ),
            const SizedBox(height: 14),
            // Main text (centered)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                emptyTitle,
                style: AppTypography.infoCardText(),
                textAlign: TextAlign.center,
              ),
            ),
            // Subtitle (centered)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                emptySubtitle,
                style: AppTypography.infoCardAccent(),
                textAlign: TextAlign.center,
              ),
            ),
            // White button (Figma design)
            if (buttonText != null) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: onEmptyTap,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(110),
                  ),
                  child: Center(
                    child: Text(
                      buttonText!,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Session layout - icon in circle on left, text on right with arrow
  Widget _buildSessionEmptyState() {
    return GestureDetector(
      onTap: buttonText == null ? onEmptyTap : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Icon in circle
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.iconButtonBg,
                borderRadius: BorderRadius.circular(72),
              ),
              child: Center(
                child: iconPath != null
                    ? Image.asset(
                        iconPath!,
                        width: 20,
                        height: 20,
                        color: iconColor ?? Colors.white,
                      )
                    : Icon(Icons.style, color: iconColor ?? Colors.white, size: 20),
              ),
            ),
            const SizedBox(height: 14),
            // Bottom row: Text with arrow (hide arrow if button is shown)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          emptyTitle,
                          style: AppTypography.infoCardText(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          emptySubtitle,
                          style: AppTypography.infoCardAccent().copyWith(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                if (buttonText == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
              ],
            ),
            // White button (Figma design)
            if (buttonText != null) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: onEmptyTap,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(110),
                  ),
                  child: Center(
                    child: Text(
                      buttonText!,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: CustomPaint(
        painter: _DashedBorderPainter(),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(2),
      ));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
