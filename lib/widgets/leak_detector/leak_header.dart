import 'package:flutter/material.dart';

import '../../design_system/constants/colors.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../services/leak_engine.dart';

/// Two lines that say what matters before anything else: a verdict
/// ("1 leak to fix · 4 solid") and one quiet meta line ("Based on 120
/// hands · Updated just now"). Both are plain wrapping text.
class LeakHeader extends StatelessWidget {
  final LeakReport report;

  /// Optional "Last visit 3d ago" fragment appended to the meta line.
  final String? lastVisit;

  const LeakHeader({super.key, required this.report, this.lastVisit});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final leaks = report.leaks.length;
    final head = leaks == 0
        ? l10n.leakVerdictNone
        : l10n.leakVerdictLeaks(leaks);
    final verdict = '$head · ${l10n.leakVerdictSolid(report.healthy.length)}';
    final meta = [
      l10n.leakMetaBased(report.handsAnalyzed),
      if (lastVisit != null) l10n.leakMetaLastVisit(lastVisit!),
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(verdict,
              style: AppTypography.titleBase(color: AppColors.textPrimary)),
        ),
        const SizedBox(height: AppSpacing.xxxs),
        Text(meta, style: AppTypography.caption()),
      ],
    );
  }
}
