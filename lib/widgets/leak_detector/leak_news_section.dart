import 'package:flutter/material.dart';

import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/sizes.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../services/leak_snapshot_store.dart';
import 'leak_format.dart';

/// "What changed since your last visit". One line by default; expands in
/// place to the first few changes. Good news can jump to the Health tab.
class LeakNewsSection extends StatefulWidget {
  final LeakSnapshotDiff diff;
  final VoidCallback onJumpToHealth;

  /// Changes listed when expanded.
  static const maxShown = 4;

  const LeakNewsSection({
    super.key,
    required this.diff,
    required this.onJumpToHealth,
  });

  @override
  State<LeakNewsSection> createState() => _LeakNewsSectionState();
}

class _LeakNewsSectionState extends State<LeakNewsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final diff = widget.diff;
    final summary = [
      l10n.leakNewsCount(diff.changes.length),
      if (diff.handsDelta > 0) l10n.leakNewsHands(diff.handsDelta),
    ].join(' · ');
    return Container(
      decoration: BoxDecoration(
        color: AppColors.tintBg(AppColors.accentSecondary),
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        border:
            Border.all(color: AppColors.tintBorder(AppColors.accentSecondary)),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              expanded: _expanded,
              excludeSemantics: true,
              label: summary,
              onTap: _toggle,
              child: InkWell(
                onTap: _toggle,
                borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(minHeight: AppSizes.listRowMin),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.xxs),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome,
                            size: AppIconSize.sm,
                            color: AppColors.accentSecondary),
                        const SizedBox(width: AppSpacing.xxs),
                        Expanded(
                          child: Text(summary,
                              style: AppTypography.bodySmMedium(
                                  color: AppColors.textPrimary)),
                        ),
                        Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: AppIconSize.lg,
                            color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_expanded) _changes(context, l10n),
          ],
        ),
      ),
    );
  }

  void _toggle() => setState(() => _expanded = !_expanded);

  Widget _changes(BuildContext context, AppLocalizations l10n) {
    final all = widget.diff.changes;
    final shown = all.take(LeakNewsSection.maxShown).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in shown) _line(l10n, c),
          if (all.length > shown.length)
            Text(l10n.leakNewsMore(all.length - shown.length),
                style: AppTypography.caption()),
        ],
      ),
    );
  }

  Widget _line(AppLocalizations l10n, LeakChange c) {
    final (icon, color, text) = _describe(l10n, c);
    final jumps = c.kind == LeakChangeKind.becameHealthy;
    return InkWell(
      onTap: jumps ? widget.onJumpToHealth : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.listRowMin),
        child: Row(
          children: [
            Icon(icon, size: AppIconSize.sm, color: color),
            const SizedBox(width: AppSpacing.xxs),
            Expanded(
              child: Text(text,
                  style: AppTypography.bodySmMedium(
                      color: AppColors.textPrimary)),
            ),
            if (jumps)
              const Icon(Icons.chevron_right,
                  size: AppIconSize.md, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  (IconData, Color, String) _describe(AppLocalizations l10n, LeakChange c) {
    final from = leakPct(c.previousValue ?? 0);
    final to = leakPct(c.currentValue);
    return switch (c.kind) {
      LeakChangeKind.becameHealthy => (
          Icons.check_circle_outline,
          AppColors.accentPrimary,
          l10n.leakChangeHealthy(c.title)
        ),
      LeakChangeKind.unlocked => (
          Icons.lock_open_rounded,
          AppColors.accentSecondary,
          l10n.leakChangeUnlocked(c.title)
        ),
      LeakChangeKind.improved => (
          Icons.trending_flat,
          AppColors.accentPrimary,
          l10n.leakChangeImproved(c.title, from, to)
        ),
      LeakChangeKind.becameLeak => (
          Icons.warning_amber_rounded,
          AppColors.accentDanger,
          l10n.leakChangeBecameLeak(c.title)
        ),
      LeakChangeKind.worsened => (
          Icons.trending_up,
          AppColors.accentDanger,
          l10n.leakChangeWorsened(c.title, from, to)
        ),
    };
  }
}
