import 'package:flutter/material.dart';

import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/sizes.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../services/leak_engine.dart';
import 'leak_format.dart';

/// Severity pill: icon + word on a status-tinted background, so severity is
/// never carried by colour alone.
class LeakStatusPill extends StatelessWidget {
  final LeakFinding finding;
  const LeakStatusPill({super.key, required this.finding});

  @override
  Widget build(BuildContext context) {
    final color = leakStatusColor(finding);
    final word = leakStatusWord(AppLocalizations.of(context), finding);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxs, vertical: AppSpacing.xxxs),
      decoration: BoxDecoration(
        color: AppColors.tintBg(color),
        borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(leakStatusIcon(finding), size: AppIconSize.sm, color: color),
          const SizedBox(width: AppSpacing.xxxs),
          Flexible(
            child: Text(word, style: AppTypography.caption(color: color)),
          ),
        ],
      ),
    );
  }
}
