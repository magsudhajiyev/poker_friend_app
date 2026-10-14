import 'package:flutter/material.dart';

import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../services/drill_range_lookup.dart';

/// Read-only 13×13 baseline-chart grid for the drill "Show range" sheet:
/// raise-layer cells (open/3-bet/4-bet/jam) in the range-grid raise color,
/// call-layer cells in the call color, everything else dim (= fold). The
/// hero's dealt hand gets a bright ring so "where am I on this chart" is
/// one glance. Single CustomPaint + cached labels (LeakShapeMiniGrid
/// pattern) so it builds instantly inside a sheet.
class DrillRangeChartGrid extends StatelessWidget {
  final DrillRangeChart chart;
  final String? highlightHand; // 169-class, e.g. 'A5s'

  const DrillRangeChartGrid({
    super.key,
    required this.chart,
    this.highlightHand,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final side = constraints.maxWidth;
      return RepaintBoundary(
        child: CustomPaint(
          size: Size(side, side),
          painter: _ChartGridPainter(
              chart: chart, highlightHand: highlightHand),
        ),
      );
    });
  }
}

class _ChartGridPainter extends CustomPainter {
  final DrillRangeChart chart;
  final String? highlightHand;

  _ChartGridPainter({required this.chart, required this.highlightHand});

  static const _ranks = 'AKQJT98765432';
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
            color: strongFill
                ? Colors.black.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.3),
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
    final cell = stride - 1;
    final fontSize = cell >= 20 ? 8.0 : (cell * 0.38).clamp(5.0, 8.0);
    final paintBox = Paint();

    Rect? highlightRect;

    for (var r = 0; r < 13; r++) {
      for (var c = 0; c < 13; c++) {
        final handClass = _classFor(r, c);

        DrillRangeLayerKind? kind;
        for (final layer in chart.layers) {
          if (layer.hands.contains(handClass)) kind = layer.kind;
        }
        final (color, strongFill) = switch (kind) {
          DrillRangeLayerKind.raise => (AppColors.rangeRaise, true),
          DrillRangeLayerKind.call => (AppColors.rangeCall, true),
          null => (Colors.white.withValues(alpha: 0.05), false),
        };

        final left = c * stride + 0.5;
        final top = r * stride + 0.5;
        final rect = Rect.fromLTWH(left, top, cell, cell);
        canvas.drawRect(rect, paintBox..color = color);
        if (handClass == highlightHand) highlightRect = rect;

        final tp = _label(handClass, strongFill, fontSize);
        tp.paint(
            canvas,
            Offset(left + (cell - tp.width) / 2,
                top + (cell - tp.height) / 2));
      }
    }

    // Hero's dealt hand: bright ring painted last so it sits above
    // neighbouring cells.
    if (highlightRect != null) {
      canvas.drawRect(
        highlightRect.inflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.accentPrimary,
      );
    }
  }

  @override
  bool shouldRepaint(_ChartGridPainter old) =>
      old.chart != chart || old.highlightHand != highlightHand;
}
