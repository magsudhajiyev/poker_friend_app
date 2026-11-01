import 'package:flutter/material.dart';

import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/sizes.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../services/leak_engine.dart';
import '../../services/leak_focus_store.dart';
import 'band_gauge.dart';
import 'leak_format.dart';
import 'leak_section_header.dart';
import 'money_by_position.dart';

/// HEALTH tab ("how am I doing"): healthy checks, fixed-leak trophies and
/// the money view.
class HealthTab extends StatelessWidget {
  final LeakReport report;
  final List<FixedLeak> fixed;
  /// Null hides the per-spot drill buttons.
  final ValueChanged<SpotNet>? onDrill;
  final VoidCallback onMoneyInfo;

  const HealthTab({
    super.key,
    required this.report,
    required this.fixed,
    this.onDrill,
    required this.onMoneyInfo,
  });

  /// Two columns only when there is genuinely room and text is not large.
  static const double twoColumnMinWidth = 520;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final healthy = report.healthy;
    final hasMoney = report.positionNets.isNotEmpty;
    if (healthy.isEmpty && fixed.isEmpty && !hasMoney) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xl),
        child: Text(l10n.leakHealthEmpty,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmMedium(color: AppColors.textSecondary)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (healthy.isNotEmpty) ...[
          LeakSectionHeader(title: l10n.leakSectionHealthy),
          HealthyList(findings: healthy),
          const SizedBox(height: AppSpacing.xl),
        ],
        if (fixed.isNotEmpty) ...[
          LeakSectionHeader(title: l10n.leakSectionFixed),
          for (final fl in fixed) ...[
            FixedLeakTile(leak: fl),
            const SizedBox(height: AppSpacing.xxs),
          ],
          const SizedBox(height: AppSpacing.md),
        ],
        if (hasMoney) ...[
          LeakSectionHeader(
              title: l10n.leakSectionMoney,
              onInfo: onMoneyInfo,
              infoLabel: l10n.leakMoneyInfoTitle),
          MoneyByPosition(report: report, onDrill: onDrill),
        ],
      ],
    );
  }
}

/// Healthy detectors as rows: one column by default, two on wide screens.
class HealthyList extends StatelessWidget {
  final List<LeakFinding> findings;
  const HealthyList({super.key, required this.findings});

  @override
  Widget build(BuildContext context) {
    const gap = AppSpacing.xxs;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    return LayoutBuilder(builder: (context, c) {
      final twoCols = !largeText && c.maxWidth >= HealthTab.twoColumnMinWidth;
      final width = twoCols ? (c.maxWidth - gap) / 2 : c.maxWidth;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final f in findings)
            SizedBox(width: width, child: HealthyTile(finding: f)),
        ],
      );
    });
  }
}

class HealthyTile extends StatelessWidget {
  final LeakFinding finding;
  const HealthyTile({super.key, required this.finding});

  @override
  Widget build(BuildContext context) {
    final f = finding;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(f.title,
              style: AppTypography.bodySmMedium(
                  color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            children: [
              Text(leakPct(f.value), style: AppTypography.dataMono()),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: BandGauge(
                  title: f.title,
                  value: f.value,
                  bandLow: f.bandLow,
                  bandHigh: f.bandHigh,
                  markerColor: AppColors.accentPrimary,
                  compact: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Trophy row for a leak the player fixed.
class FixedLeakTile extends StatelessWidget {
  final FixedLeak leak;
  const FixedLeakTile({super.key, required this.leak});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final from = leakPct(leak.startValue);
    final to = leakPct(leak.fixedValue);
    final detail = leak.daysToFix < 1
        ? l10n.leakFixedInUnderDay(from, to)
        : l10n.leakFixedInDays(from, to, leak.daysToFix);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.tintBg(AppColors.accentTertiary),
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        border: Border.all(color: AppColors.tintBorder(AppColors.accentTertiary)),
      ),
      child: Row(
        children: [
          Container(
            width: AppSizes.iconBadge,
            height: AppSizes.iconBadge,
            decoration: BoxDecoration(
              color: AppColors.tintBg(AppColors.accentTertiary),
              borderRadius: BorderRadius.circular(AppDecorations.radius10),
            ),
            child: const Icon(Icons.emoji_events,
                size: AppIconSize.md, color: AppColors.accentTertiary),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(leak.title,
                    style: AppTypography.bodySmMedium(
                        color: AppColors.textPrimary)),
                Text(detail,
                    style: AppTypography.dataMonoSm(
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
