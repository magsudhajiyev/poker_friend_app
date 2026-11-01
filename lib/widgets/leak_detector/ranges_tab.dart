import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/components/buttons/app_button.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/sizes.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../services/range_shape_service.dart';
import '../leak_shape_mini_grid.dart';
import 'leak_format.dart';
import 'leak_section_header.dart';

/// RANGES tab ("with which hands"): your opening range vs the baseline
/// chart, one position at a time.
class RangesTab extends StatelessWidget {
  /// Null while the shape is still loading.
  final RangeShapeReport? shape;
  final String? selectedPos;
  final ValueChanged<String> onSelectPos;
  final ValueChanged<PositionShape> onOpenGrid;
  /// Null hides the practice button.
  final ValueChanged<PositionShape>? onPractice;
  final VoidCallback onInfo;

  const RangesTab({
    super.key,
    required this.shape,
    required this.selectedPos,
    required this.onSelectPos,
    required this.onOpenGrid,
    this.onPractice,
    required this.onInfo,
  });

  static String _progress(RangeShapeReport s) => s.insufficient
      .where((p) => p.sampledSpots > 0)
      .map((p) =>
          '${p.posGroup} ${p.sampledSpots}/${RangeShapeService.minPositionSpots}')
      .join(' · ');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = shape;
    if (s == null) return _loading(l10n);
    final header = LeakSectionHeader(
        title: l10n.leakSectionRangeShape,
        onInfo: onInfo,
        infoLabel: l10n.leakShapeInfoTitle);
    final progress = _progress(s);
    if (s.sufficient.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          Text(l10n.leakShapeLocked(RangeShapeService.minPositionSpots),
              style: AppTypography.bodyMd(color: AppColors.textSecondary)),
          if (progress.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.leakShapeProgress(progress),
                style: AppTypography.dataMonoSm(color: AppColors.textSecondary)),
          ],
        ],
      );
    }
    final selected = s.sufficient
            .where((p) => p.posGroup == selectedPos)
            .firstOrNull ??
        s.sufficient.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        PositionChips(
            shape: s, selected: selected.posGroup, onSelect: onSelectPos),
        const SizedBox(height: AppSpacing.xs),
        ShapeCard(
          key: ValueKey(selected.posGroup),
          position: selected,
          onOpenGrid: () => onOpenGrid(selected),
          onPractice:
              onPractice == null ? null : () => onPractice!(selected),
        ),
        if (progress.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.leakShapeMoreUnlock(progress),
              style: AppTypography.caption()),
        ],
      ],
    );
  }

  Widget _loading(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: AppSizes.spinner,
            height: AppSizes.spinner,
            child: CircularProgressIndicator(
                strokeWidth: AppSizes.spinnerStroke,
                color: AppColors.accentPrimary),
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(l10n.leakShapeLoading,
                style: AppTypography.bodySmMedium(
                    color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

/// EP / MP / CO / BTN / SB chips. Sufficient positions are selectable;
/// locked ones show progress. Wraps to extra rows (equal widths) when the
/// screen is narrow or text is large.
class PositionChips extends StatelessWidget {
  final RangeShapeReport shape;
  final String selected;
  final ValueChanged<String> onSelect;

  const PositionChips({
    super.key,
    required this.shape,
    required this.selected,
    required this.onSelect,
  });

  /// Narrowest a chip may get before the row wraps.
  static const double minChipWidth = 64;

  @override
  Widget build(BuildContext context) {
    const gap = AppSpacing.xxs;
    final items = shape.positions;
    return LayoutBuilder(builder: (context, c) {
      final perRow = ((c.maxWidth + gap) / (minChipWidth + gap))
          .floor()
          .clamp(1, items.length);
      final width = (c.maxWidth - gap * (perRow - 1)) / perRow;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final p in items)
            SizedBox(
              width: width,
              child: _chip(context, p),
            ),
        ],
      );
    });
  }

  Widget _chip(BuildContext context, PositionShape p) {
    final l10n = AppLocalizations.of(context);
    final isSel = p.posGroup == selected;
    final locked = !p.sufficient;
    final fg = locked
        ? AppColors.textDisabled
        : (isSel ? AppColors.accentPrimary : AppColors.textPrimary);
    final progress =
        '${p.sampledSpots}/${RangeShapeService.minPositionSpots}';
    return Semantics(
      button: true,
      selected: isSel,
      enabled: !locked,
      excludeSemantics: true,
      label: locked
          ? l10n.leakPositionLocked(p.posGroup, p.sampledSpots,
              RangeShapeService.minPositionSpots)
          : p.posGroup,
      child: Material(
        color: isSel ? AppColors.tintBg(AppColors.accentPrimary) : AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
          onTap: locked
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onSelect(p.posGroup);
                },
          child: Container(
            constraints:
                const BoxConstraints(minHeight: AppSizes.minTapTarget),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
              border: Border.all(
                  color: isSel
                      ? AppColors.accentPrimary
                      : AppColors.borderStrong),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(p.posGroup, style: AppTypography.dataMonoSm(color: fg)),
                if (locked)
                  Text(progress,
                      style: AppTypography.caption(color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Deviation {
  final ShapeCellDeviation cell;
  final bool missed;
  const _Deviation(this.cell, this.missed);
}

/// One position: summary line, the 13x13 heat map, the most significant
/// deviations (top [topCount], rest behind "Show all") and two actions.
class ShapeCard extends StatefulWidget {
  final PositionShape position;
  final VoidCallback onOpenGrid;
  final VoidCallback? onPractice;

  static const topCount = 5;

  const ShapeCard({
    super.key,
    required this.position,
    required this.onOpenGrid,
    this.onPractice,
  });

  @override
  State<ShapeCard> createState() => _ShapeCardState();
}

class _ShapeCardState extends State<ShapeCard> {
  bool _showAll = false;

  PositionShape get _p => widget.position;

  List<_Deviation> get _deviations => [
        for (final d in _p.missedOpens) _Deviation(d, true),
        for (final d in _p.looseOpens) _Deviation(d, false),
      ]..sort((a, b) => b.cell.offActions.compareTo(a.cell.offActions));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        border: Border.all(
          color: _p.hasDeviations
              ? AppColors.tintBorder(AppColors.accentTertiary)
              : AppColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summary(l10n),
          const SizedBox(height: AppSpacing.xs),
          LeakShapeMiniGrid(
              posGroup: _p.posGroup, aggregates: _p.aggregates),
          if (_p.hasDeviations) ...[
            const SizedBox(height: AppSpacing.xs),
            _chips(l10n),
          ],
          const SizedBox(height: AppSpacing.md),
          _actions(context, l10n),
        ],
      ),
    );
  }

  Widget _summary(AppLocalizations l10n) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xxxs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxs, vertical: AppSpacing.xxxs),
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
          ),
          child: Text(_p.posGroup, style: AppTypography.dataMonoSm()),
        ),
        Text(
          l10n.leakShapeSummary(
              leakPct(_p.playerOpenFreq), leakPct(_p.chartOpenPct)),
          style: AppTypography.caption(),
        ),
        Text(l10n.leakSpotsCount(_p.sampledSpots),
            style: AppTypography.caption()),
      ],
    );
  }

  Widget _chips(AppLocalizations l10n) {
    final all = _deviations;
    final shown = _showAll ? all : all.take(ShapeCard.topCount).toList();
    final hidden = all.length - ShapeCard.topCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.xxs,
          runSpacing: AppSpacing.xxs,
          children: [for (final d in shown) _chip(l10n, d)],
        ),
        if (hidden > 0)
          TextButton(
            onPressed: () => setState(() => _showAll = !_showAll),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentSecondary,
              minimumSize: const Size(0, AppSizes.minTapTarget),
            ),
            child: Text(
              _showAll ? l10n.leakShowLess : l10n.leakShapeShowAll(all.length),
              style:
                  AppTypography.bodySmMedium(color: AppColors.accentSecondary),
            ),
          ),
      ],
    );
  }

  Widget _chip(AppLocalizations l10n, _Deviation d) {
    final color = d.missed ? AppColors.accentTertiary : AppColors.accentDanger;
    final text = d.missed
        ? l10n.leakShapeFolded(d.cell.handClass, d.cell.offActions)
        : l10n.leakShapeOpened(d.cell.handClass, d.cell.offActions);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxs, vertical: AppSpacing.xxxs),
      decoration: BoxDecoration(
        color: AppColors.tintBg(color),
        borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
        border: Border.all(color: AppColors.tintBorder(color)),
      ),
      child: Text(text, style: AppTypography.caption(color: AppColors.textPrimary)),
    );
  }

  Widget _actions(BuildContext context, AppLocalizations l10n) {
    final grid = AppButton(
      label: l10n.leakShapeOpenGrid,
      variant: AppButtonVariant.secondaryLarge,
      fullWidth: true,
      onTap: widget.onOpenGrid,
      leadingIcon: const Icon(Icons.grid_on,
          size: AppIconSize.sm, color: AppColors.textPrimary),
    );
    if (widget.onPractice == null) return grid;
    final practice = AppButton(
      label: l10n.leakShapePracticeOpens,
      fullWidth: true,
      onTap: widget.onPractice,
      leadingIcon: const Icon(Icons.fitness_center,
          size: AppIconSize.sm, color: AppColors.textInverse),
    );
    return LayoutBuilder(builder: (context, c) {
      final stack = c.maxWidth < 360 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.2;
      if (stack) {
        return Column(children: [
          practice,
          const SizedBox(height: AppSpacing.xxs),
          grid,
        ]);
      }
      return Row(children: [
        Expanded(child: grid),
        const SizedBox(width: AppSpacing.xxs),
        Expanded(child: practice),
      ]);
    });
  }
}
