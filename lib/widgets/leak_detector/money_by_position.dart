import 'package:flutter/material.dart';

import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/sizes.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../services/leak_engine.dart';

/// Money view: BB net per position as diverging bars, plus the worst
/// drill-targetable spots. High-variance data, so presented as directional
/// (the caller wires the explainer sheet).
class MoneyByPosition extends StatelessWidget {
  final LeakReport report;
  final ValueChanged<SpotNet> onDrill;

  const MoneyByPosition({
    super.key,
    required this.report,
    required this.onDrill,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final maxAbs = report.positionNets
        .map((p) => p.netBBTotal.abs())
        .fold<double>(1, (m, v) => v > m ? v : m);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in report.positionNets) PositionBarRow(net: p, maxAbs: maxAbs),
          if (report.worstSpots.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(l10n.leakSectionWorstSpots.toUpperCase(),
                style: AppTypography.sectionHeader(
                    color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.xxs),
            for (final sp in report.worstSpots)
              _SpotRow(spot: sp, onDrill: () => onDrill(sp)),
          ],
        ],
      ),
    );
  }
}

String _signed(double v) => '${v >= 0 ? '+' : '-'}';

/// Position label + value on one line (both flexible), bar underneath at
/// full width: no fixed columns, so nothing overflows at large text.
class PositionBarRow extends StatelessWidget {
  final PositionNet net;
  final double maxAbs;
  const PositionBarRow({super.key, required this.net, required this.maxAbs});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final positive = net.netBBTotal >= 0;
    final bb = net.netBBTotal.abs().toStringAsFixed(0);
    final frac = (net.netBBTotal.abs() / maxAbs).clamp(0.02, 1.0);
    final color = positive ? AppColors.accentPrimary : AppColors.accentDanger;
    final sign = _signed(net.netBBTotal);
    return Semantics(
      excludeSemantics: true,
      label: l10n.leakMoneySemantics(net.pos, sign, bb, net.hands),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(net.pos,
                    style: AppTypography.dataMonoSm(
                        color: AppColors.textSecondary)),
                const SizedBox(width: AppSpacing.xxs),
                Expanded(
                  child: Text(
                    l10n.leakMoneyValue(sign, bb, net.hands),
                    textAlign: TextAlign.end,
                    style: AppTypography.dataMonoSm(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxxs),
            _DivergingBar(fraction: frac, positive: positive, color: color),
          ],
        ),
      ),
    );
  }
}

/// Zero line in the middle; losses grow left (red), profit right (brand).
class _DivergingBar extends StatelessWidget {
  final double fraction;
  final bool positive;
  final Color color;
  const _DivergingBar({
    required this.fraction,
    required this.positive,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.barHeight,
      child: LayoutBuilder(builder: (context, c) {
        final half = c.maxWidth / 2;
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: half * fraction),
          duration: AppMotion.of(context, AppMotion.slow),
          curve: Curves.easeOutCubic,
          builder: (context, w, _) => Stack(
            children: [
              Positioned(
                left: half - AppSizes.hairline / 2,
                top: 0,
                bottom: 0,
                width: AppSizes.hairline,
                child: const ColoredBox(color: AppColors.borderSubtle),
              ),
              Positioned(
                left: positive ? half : half - w,
                top: 0,
                bottom: 0,
                width: w,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(
                          positive ? 0 : AppSizes.barHeight / 2),
                      right: Radius.circular(
                          positive ? AppSizes.barHeight / 2 : 0),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _SpotRow extends StatelessWidget {
  final SpotNet spot;
  final VoidCallback onDrill;
  const _SpotRow({required this.spot, required this.onDrill});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(spot.label,
                    style: AppTypography.bodySmMedium(
                        color: AppColors.textPrimary)),
                Text(
                  l10n.leakMoneyValue(
                      _signed(spot.netBBTotal),
                      spot.netBBTotal.abs().toStringAsFixed(0),
                      spot.hands),
                  style:
                      AppTypography.dataMonoSm(color: AppColors.accentDanger),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onDrill,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentPrimary,
              minimumSize:
                  const Size(AppSizes.minTapTarget, AppSizes.minTapTarget),
            ),
            child: Text(l10n.leakDrill,
                style:
                    AppTypography.bodySmMedium(color: AppColors.accentPrimary)),
          ),
        ],
      ),
    );
  }
}
