import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/range_grid_service.dart';

/// Compact row for one logged hand behind a grid cell: relative date,
/// preflop line, result. Tappable to open that hand's details.
class RangeHandRow extends StatelessWidget {
  final RangeGridEntry entry;
  final VoidCallback? onTap;

  const RangeHandRow({super.key, required this.entry, this.onTap});

  String _relativeDate() {
    final date = DateTime.fromMillisecondsSinceEpoch(entry.timestamp);
    final diff = DateTime.now().difference(date);
    if (diff.inDays < 1) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                _relativeDate(),
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Position chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                entry.position,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.preflopLine,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // Result: won/lost + pot size in BB
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: entry.won
                    ? const Color(0xFF62E3BC).withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${entry.won ? 'W' : '–'} ${entry.potBB.round()} BB',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: entry.won
                      ? const Color(0xFF62E3BC)
                      : Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right,
                  size: 16, color: Colors.white.withValues(alpha: 0.3)),
            ],
          ],
        ),
      ),
    );
  }
}
