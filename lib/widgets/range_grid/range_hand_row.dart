import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/range_grid_service.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/typography.dart';
import '../../design_system/constants/decorations.dart';

/// Compact row for one logged hand behind a grid cell: relative date,
/// preflop line, result. Tappable to open that hand's details.
class RangeHandRow extends StatelessWidget {
  final RangeGridEntry entry;
  final VoidCallback? onTap;

  const RangeHandRow({super.key, required this.entry, this.onTap});

  String _relativeDate(AppLocalizations l10n) {
    final date = DateTime.fromMillisecondsSinceEpoch(entry.timestamp);
    final diff = DateTime.now().difference(date);
    if (diff.inDays < 1) return l10n.rangeToday;
    if (diff.inDays == 1) return l10n.rangeYesterday;
    if (diff.inDays < 7) return l10n.rangeDaysAgo(diff.inDays);
    if (diff.inDays < 30) return l10n.rangeWeeksAgo((diff.inDays / 7).floor());
    if (diff.inDays < 365) return l10n.rangeMonthsAgo((diff.inDays / 30).floor());
    return l10n.rangeYearsAgo((diff.inDays / 365).floor());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                _relativeDate(l10n),
                style: AppTypography.ibm(
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
                style: AppTypography.ibm(
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
                style: AppTypography.ibm(
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
                    ? AppColors.tealPrimary.withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
              ),
              child: Text(
                entry.won ? l10n.rangeWonBB(entry.potBB.round()) : l10n.rangeLostBB(entry.potBB.round()),
                style: AppTypography.ibm(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: entry.won
                      ? AppColors.tealPrimary
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
