import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/typography.dart';

/// Stacked all-in/raise/call/check/fold frequency bar with a legend.
/// Palette: raise orange, call light green, check teal, fold blue,
/// all-in dark purple.
class RangeFrequencyBar extends StatelessWidget {
  final int raiseCount;
  final int callCount;
  final int foldCount;
  final int checkCount;
  final int allInCount;

  const RangeFrequencyBar({
    super.key,
    required this.raiseCount,
    required this.callCount,
    required this.foldCount,
    required this.checkCount,
    this.allInCount = 0,
  });

  static const allInColor = AppColors.rangeAllIn;
  static const raiseColor = AppColors.rangeRaise;
  static const callColor = AppColors.rangeCall;
  static const checkColor = AppColors.accentPrimary;
  static const foldColor = AppColors.rangeFold;

  int get _total =>
      allInCount + raiseCount + callCount + foldCount + checkCount;

  @override
  Widget build(BuildContext context) {
    if (_total == 0) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

    final segments = <(int, Color)>[
      (allInCount, allInColor),
      (raiseCount, raiseColor),
      (callCount, callColor),
      (checkCount, checkColor),
      (foldCount, foldColor),
    ].where((s) => s.$1 > 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Animated bar fill
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final fullWidth = constraints.maxWidth;
                  return SizedBox(
                    height: 8,
                    width: fullWidth,
                    child: Stack(
                      children: [
                        Container(color: Colors.white.withValues(alpha: 0.06)),
                        Row(
                          children: [
                            for (int i = 0; i < segments.length; i++) ...[
                              if (i > 0) const SizedBox(width: 2),
                              Container(
                                width: (fullWidth - (segments.length - 1) * 2) *
                                    t *
                                    segments[i].$1 /
                                    _total,
                                color: segments[i].$2,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        // Legend
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            if (allInCount > 0) _legendItem(l10n.rangeAllIn, allInCount, allInColor),
            if (raiseCount > 0) _legendItem(l10n.rangeRaised, raiseCount, raiseColor),
            if (callCount > 0) _legendItem(l10n.rangeCalled, callCount, callColor),
            if (checkCount > 0) _legendItem(l10n.rangeChecked, checkCount, checkColor),
            if (foldCount > 0) _legendItem(l10n.rangeFolded, foldCount, foldColor),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$label $count',
          style: AppTypography.ibm(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
