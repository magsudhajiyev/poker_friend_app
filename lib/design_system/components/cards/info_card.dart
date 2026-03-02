import 'package:flutter/material.dart';
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
  final VoidCallback? onEmptyTap;

  const InfoCard({
    Key? key,
    this.child,
    this.isEmpty = false,
    this.emptyTitle = 'No recent sessions',
    this.emptySubtitle = 'Start your first poker session!',
    this.iconPath,
    this.onEmptyTap,
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
    return GestureDetector(
      onTap: onEmptyTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 20, left: 16, right: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
                      color: Colors.white,
                    )
                  : _buildPlaceholderIcon(),
            ),
            const SizedBox(height: 14),
            // Main text row with arrow
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  emptyTitle,
                  style: AppTypography.infoCardText(),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Subtitle
            Text(
              emptySubtitle,
              style: AppTypography.infoCardAccent(),
            ),
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
