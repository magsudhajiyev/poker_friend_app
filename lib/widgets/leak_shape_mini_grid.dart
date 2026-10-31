import 'package:flutter/material.dart';

import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../services/drill_gto_charts.dart';
import '../services/range_grid_service.dart';
import '../services/range_shape_service.dart';

/// Read-only 13×13 "your range vs the chart" heatmap for one position's
/// RFI spot (RANGE SHAPE cards on the Leak Detector).
///
/// Color language:
/// - faint teal tint        = the chart's open range (the target shape)
/// - solid teal             = you open it and the chart agrees
/// - amber                  = MISSED open (chart opens it, you fold it)
/// - red                    = LOOSE open (chart folds it, you open it)
/// - dim                    = you fold it and the chart agrees
/// Standard layout: suited above the diagonal, pairs on it, offsuit below
/// (mirrors ObservedRangeGrid / RangeGridView).
///
/// Rendered as a single CustomPaint (not 169 widgets) so building this
/// mid tab-swipe stays within frame budget; labels are cached TextPainters.
class LeakShapeMiniGrid extends StatelessWidget {
  final String posGroup;
  final Map<String, RangeCellAggregate> aggregates;

  const LeakShapeMiniGrid({
    super.key,
    required this.posGroup,
    required this.aggregates,
  });

  @override
  Widget build(BuildContext context) {
    final chart = DrillGtoCharts.openRange(posGroup);
    return LayoutBuilder(builder: (context, constraints) {
      final side = constraints.maxWidth;
      return RepaintBoundary(
        child: CustomPaint(
          size: Size(side, side),
          painter: _ShapeGridPainter(chart: chart, aggregates: aggregates),
        ),
      );
    });
  }
}

class _ShapeGridPainter extends CustomPainter {
  final Set<String> chart;
  final Map<String, RangeCellAggregate> aggregates;

  _ShapeGridPainter({required this.chart, required this.aggregates});

  static const _ranks = 'AKQJT98765432';

  /// Label layouts are shared across repaints and positions — same 169
  /// classes everywhere, two weights, keyed by rounded font size.
  static final Map<String, TextPainter> _labelCache = {};

  String _classFor(int r, int c) {
    if (r == c) return '${_ranks[r]}${_ranks[r]}';
    if (r < c) return '${_ranks[r]}${_ranks[c]}s';
    return '${_ranks[c]}${_ranks[r]}o';
  }

  TextPainter _label(String handClass, bool strongFill, double fontSize) {
    final key = '$handClass|$strongFill|${fontSize.toStringAsFixed(1)}';
    return _labelCache.putIfAbsent(key, () {
      final tp = TextPainter(
        text: TextSpan(
          text: handClass,
          style: AppTypography.mono(
            fontSize: fontSize,
            fontWeight: strongFill ? FontWeight.w700 : FontWeight.w400,
            // Dark ink on solid fills, textSecondary (>= 4.5:1) on quiet ones.
            color: strongFill ? AppColors.textInverse : AppColors.textSecondary,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return tp;
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final stride = size.width / 13;
    final cell = stride - 1; // 1px gutter, same footprint as before
    // DOCUMENTED EXCEPTION to the 12px type floor: 169 cell labels are
    // painted into ~20px cells, so they cannot be larger. 8px mono fits
    // 3-char labels down to ~20px cells; shrink below that.
    final fontSize = cell >= 20 ? 8.0 : (cell * 0.38).clamp(5.0, 8.0);
    final paintBox = Paint();

    for (var r = 0; r < 13; r++) {
      for (var c = 0; c < 13; c++) {
        final handClass = _classFor(r, c);
        final inChart = chart.contains(handClass);
        final kind = RangeShapeService.classifyCell(
            inChart: inChart, agg: aggregates[handClass]);

        final Color color;
        final bool strongFill; // dark label on strong fills, dim otherwise
        switch (kind) {
          case 'alignedOpen':
            color = AppColors.accentPrimary;
            strongFill = true;
            break;
          case 'missed':
            color = AppColors.accentTertiary;
            strongFill = true;
            break;
          case 'loose':
            color = AppColors.accentDanger;
            strongFill = true;
            break;
          case 'alignedFold':
            color = AppColors.borderSubtle;
            strongFill = false;
            break;
          default: // noData — the chart's target shape as a faint tint
            color = inChart
                ? AppColors.tintBg(AppColors.accentPrimary)
                : AppColors.fillSubtle;
            strongFill = false;
        }

        final left = c * stride + 0.5;
        final top = r * stride + 0.5;
        canvas.drawRect(
            Rect.fromLTWH(left, top, cell, cell), paintBox..color = color);

        final tp = _label(handClass, strongFill, fontSize);
        tp.paint(
            canvas,
            Offset(left + (cell - tp.width) / 2,
                top + (cell - tp.height) / 2));
      }
    }
  }

  @override
  bool shouldRepaint(_ShapeGridPainter old) =>
      old.chart != chart || old.aggregates != aggregates;
}
