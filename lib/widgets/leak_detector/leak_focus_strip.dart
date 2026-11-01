import 'package:flutter/material.dart';

import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/sizes.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../services/leak_engine.dart';
import '../../services/leak_focus_store.dart';
import 'leak_format.dart';

/// Goal strip on the emphasised leak card.
///
/// - [focus] set: progress since the player committed (days, spots added,
///   start -> now, points to the band) plus a clear button.
/// - [focus] null and [onSetFocus] set: a quiet "Work on this" prompt.
/// Honest counting only: the celebration waits for the verdict flip.
class LeakFocusStrip extends StatelessWidget {
  final LeakFinding finding;
  final LeakFocusGoal? focus;
  final VoidCallback? onSetFocus;
  final VoidCallback? onClearFocus;
  final DateTime? now;

  const LeakFocusStrip({
    super.key,
    required this.finding,
    this.focus,
    this.onSetFocus,
    this.onClearFocus,
    this.now,
  });

  @override
  Widget build(BuildContext context) {
    final goal = focus;
    if (goal == null && onSetFocus == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.tintBg(AppColors.accentPrimary),
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
      ),
      child: goal != null ? _progress(context, goal) : _prompt(context),
    );
  }

  Widget _progress(BuildContext context, LeakFocusGoal goal) {
    final l10n = AppLocalizations.of(context);
    final f = finding;
    final days = (now ?? DateTime.now()).difference(goal.startedAt).inDays;
    final spotsAdded = (f.sampleCount - goal.startSampleCount).clamp(0, 1 << 30);
    final toBand = f.aboveBand ? f.value - f.bandHigh : f.bandLow - f.value;
    final ptsToGo = (toBand * 100).ceil().clamp(0, 100);
    return Row(
      children: [
        const Icon(Icons.flag,
            size: AppIconSize.sm, color: AppColors.accentPrimary),
        const SizedBox(width: AppSpacing.xxs),
        Expanded(
          child: Text(
            l10n.leakFocusProgress(days + 1, spotsAdded, leakPct(goal.startValue),
                leakPct(f.value), ptsToGo),
            style: AppTypography.dataMonoSm(),
          ),
        ),
        IconButton(
          onPressed: onClearFocus,
          tooltip: l10n.leakFocusClear,
          constraints: const BoxConstraints(
              minWidth: AppSizes.minTapTarget,
              minHeight: AppSizes.minTapTarget),
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.close,
              size: AppIconSize.sm, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _prompt(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Wrap, not Row: at large text the button drops under the hint.
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xxs),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.xxs,
        children: [
          Text(l10n.leakFocusHint, style: AppTypography.caption()),
          TextButton.icon(
            onPressed: onSetFocus,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentPrimary,
              minimumSize: const Size(0, AppSizes.minTapTarget),
            ),
            icon: const Icon(Icons.flag_outlined, size: AppIconSize.sm),
            label: Text(l10n.leakWorkOnThis,
                style:
                    AppTypography.bodySmMedium(color: AppColors.accentPrimary)),
          ),
        ],
      ),
    );
  }
}
