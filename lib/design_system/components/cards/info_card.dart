import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
        color: AppColors.backgroundSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 1),
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
                  ? _buildIcon(24)
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
            // Mint button (Figma design)
            if (buttonText != null) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: onEmptyTap,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.buttonPrimary,
                    borderRadius: BorderRadius.circular(110),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add,
                        color: Colors.black,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        buttonText!,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
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
                    ? _buildIcon(20)
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
            // Mint button (Figma design)
            if (buttonText != null) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: onEmptyTap,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.buttonPrimary,
                    borderRadius: BorderRadius.circular(110),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add,
                        color: Colors.black,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        buttonText!,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build icon supporting both SVG and PNG formats
  Widget _buildIcon(double size) {
    final color = iconColor ?? Colors.white;
    if (iconPath!.endsWith('.svg')) {
      return SvgPicture.asset(
        iconPath!,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    } else {
      return Image.asset(
        iconPath!,
        width: size,
        height: size,
        color: color,
      );
    }
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
