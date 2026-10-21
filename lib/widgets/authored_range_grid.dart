import 'package:flutter/material.dart';

import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../models/authored_spot.dart';

/// 13×13 range grid that renders the solver's MIXED strategy per hand — each
/// cell is split into horizontal colored segments proportional to the per-
/// action frequencies (like solver range viewers), not a single flat color.
///
/// Colors: raise=orange, all-in=purple, call=green, check=teal, fold=blue.
/// When [filter] is set, only that action's share is drawn (the rest of the
/// cell is dim), so "show me just the 4-bets" reads at a glance.
class AuthoredRangeGrid extends StatelessWidget {
  /// hand class (e.g. 'AKo') → action → frequency (0..1), summing ~1.
  final Map<String, Map<AuthoredAction, double>> mix;
  final String? highlightHand;

  /// When non-null, only this action's share is shown filled.
  final AuthoredAction? filter;

  const AuthoredRangeGrid({
    super.key,
    required this.mix,
    this.highlightHand,
    this.filter,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final side = constraints.maxWidth;
      return RepaintBoundary(
        child: CustomPaint(
          size: Size(side, side),
          painter: _MixPainter(
              mix: mix, highlightHand: highlightHand, filter: filter),
        ),
      );
    });
  }
}

class _MixPainter extends CustomPainter {
  final Map<String, Map<AuthoredAction, double>> mix;
  final String? highlightHand;
  final AuthoredAction? filter;

  _MixPainter({required this.mix, this.highlightHand, this.filter});

  static const _ranks = 'AKQJT98765432';

  // Draw order within a cell: raise → all-in → call → check → fold (matches
  // the legend order), so a mixed cell reads consistently left→right.
  static const _order = [
    AuthoredAction.raise,
    AuthoredAction.allin,
    AuthoredAction.call,
    AuthoredAction.check,
    AuthoredAction.fold,
  ];

  static Color _colorFor(AuthoredAction a) => switch (a) {
        AuthoredAction.raise => AppColors.rangeRaise,
        AuthoredAction.allin => AppColors.rangeAllIn,
        AuthoredAction.call => AppColors.rangeCall,
        AuthoredAction.check => AppColors.accentPrimary,
        AuthoredAction.fold => AppColors.rangeFold,
      };

  String _classFor(int r, int c) {
    if (r == c) return '${_ranks[r]}${_ranks[r]}';
    if (r < c) return '${_ranks[r]}${_ranks[c]}s';
    return '${_ranks[c]}${_ranks[r]}o';
  }

  @override
  void paint(Canvas canvas, Size size) {
    final stride = size.width / 13;
    final cell = stride - 1;
    final fontSize = cell >= 20 ? 8.0 : (cell * 0.38).clamp(5.0, 8.0);
    final paint = Paint();
    final dim = Colors.white.withValues(alpha: 0.05);

    Rect? highlightRect;

    for (var r = 0; r < 13; r++) {
      for (var c = 0; c < 13; c++) {
        final handClass = _classFor(r, c);
        final left = c * stride + 0.5;
        final top = r * stride + 0.5;
        final rect = Rect.fromLTWH(left, top, cell, cell);
        if (handClass == highlightHand) highlightRect = rect;

        final split = mix[handClass];
        // Base: dim background (the "not in range" / unfilled portion).
        canvas.drawRect(rect, paint..color = dim);

        var hasFill = false;
        if (split != null) {
          if (filter != null) {
            // Show only the filtered action's share as a left-anchored fill.
            final f = split[filter] ?? 0.0;
            if (f > 0) {
              hasFill = true;
              final w = cell * f;
              canvas.drawRect(
                Rect.fromLTWH(left, top, w, cell),
                paint..color = _colorFor(filter!),
              );
            }
          } else {
            // Full mix: stack each action's share across the cell width.
            var x = left;
            for (final a in _order) {
              final f = split[a] ?? 0.0;
              if (f <= 0) continue;
              hasFill = true;
              final w = cell * f;
              canvas.drawRect(
                Rect.fromLTWH(x, top, w, cell),
                paint..color = _colorFor(a),
              );
              x += w;
            }
          }
        }

        // Label: dark bold on a filled cell, faint on an empty one.
        final tp = _label(handClass, hasFill, fontSize);
        tp.paint(
            canvas,
            Offset(left + (cell - tp.width) / 2,
                top + (cell - tp.height) / 2));
      }
    }

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

  static final Map<String, TextPainter> _labelCache = {};

  /// Label is ALWAYS white (bold when the hand is in this view, faint grey
  /// when not) with a dark shadow, so it stays readable over BOTH the coloured
  /// bars AND the dark cell background — the bar width no longer affects
  /// legibility. Fixes unreadable partial-fill cells when filtered.
  TextPainter _label(String handClass, bool filled, double fontSize) {
    final key = '$handClass|$filled|${fontSize.toStringAsFixed(1)}';
    return _labelCache.putIfAbsent(key, () {
      return TextPainter(
        text: TextSpan(
          text: handClass,
          style: AppTypography.mono(
            fontSize: fontSize,
            fontWeight: filled ? FontWeight.w700 : FontWeight.w400,
            color: filled
                ? Colors.white
                : Colors.white.withValues(alpha: 0.28),
          ).copyWith(
            shadows: filled
                ? const [
                    Shadow(
                        color: Colors.black,
                        blurRadius: 2,
                        offset: Offset(0, 0.5)),
                  ]
                : null,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  @override
  bool shouldRepaint(_MixPainter old) =>
      old.mix != mix ||
      old.highlightHand != highlightHand ||
      old.filter != filter;
}
