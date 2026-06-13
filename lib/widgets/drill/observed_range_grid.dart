import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/observed_range.dart';

/// Compact 13×13 grid highlighting the hand classes an opponent has actually
/// shown at showdown. Suited above the diagonal, pairs on it, offsuit below —
/// the standard range-chart layout. Cells are tinted by the dominant action
/// (raise = gold, call/limp = teal) with opacity scaled by sample count.
class ObservedRangeGrid extends StatelessWidget {
  final ObservedRange range;

  const ObservedRangeGrid({super.key, required this.range});

  static const _ranks = ['A', 'K', 'Q', 'J', 'T', '9', '8', '7', '6', '5', '4', '3', '2'];
  static const _raiseColor = Color(0xFFFFC857);
  static const _callColor = Color(0xFF89F1EC);

  /// handClass -> (total, raiseCount) drawn from the observed combos.
  Map<String, List<int>> _byClass() {
    final map = <String, List<int>>{};
    for (final c in range.combos) {
      final entry = map.putIfAbsent(c.handClass, () => [0, 0]);
      entry[0]++;
      if (c.primaryAction == 'raise') entry[1]++;
    }
    return map;
  }

  String _classFor(int r, int c) {
    if (r == c) return '${_ranks[r]}${_ranks[r]}';
    if (r < c) return '${_ranks[r]}${_ranks[c]}s';
    return '${_ranks[c]}${_ranks[r]}o';
  }

  @override
  Widget build(BuildContext context) {
    final byClass = _byClass();
    int maxCount = 1;
    for (final v in byClass.values) {
      if (v[0] > maxCount) maxCount = v[0];
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = constraints.maxWidth / 13;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int r = 0; r < 13; r++)
              Row(
                children: [
                  for (int c = 0; c < 13; c++)
                    _buildCell(_classFor(r, c), byClass, maxCount, cell),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _buildCell(
      String hc, Map<String, List<int>> byClass, int maxCount, double size) {
    final data = byClass[hc];
    final count = data?[0] ?? 0;
    final raises = data?[1] ?? 0;
    final shown = count > 0;
    final raiseDominant = raises * 2 >= count; // ties favour raise
    final base = raiseDominant ? _raiseColor : _callColor;
    // Opacity scales with sample count relative to the busiest cell
    final intensity = shown ? (0.25 + 0.55 * (count / maxCount)) : 0.0;

    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.all(0.5),
      decoration: BoxDecoration(
        color: shown
            ? base.withOpacity(intensity)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(1),
            child: Text(
              hc,
              style: GoogleFonts.robotoMono(
                color: shown
                    ? Colors.black.withOpacity(0.8)
                    : Colors.white.withOpacity(0.25),
                fontSize: 8,
                fontWeight: shown ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom-sheet scouting report: an opponent's observed range with shape,
/// summary, the 13×13 grid, and the showdown-bias caveat.
class ObservedRangeSheet extends StatelessWidget {
  final ObservedRange range;
  const ObservedRangeSheet({super.key, required this.range});

  static Future<void> show(BuildContext context, ObservedRange range) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131616),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ObservedRangeSheet(range: range),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${range.name} · Scouting report',
                      style: GoogleFonts.ibmPlexSans(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (range.isReliable)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF87ED81).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Text(range.shape.label,
                          style: GoogleFonts.ibmPlexSans(
                              color: const Color(0xFF87ED81),
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(range.summary,
                  style: GoogleFonts.ibmPlexSans(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      height: 1.4)),
              const SizedBox(height: 16),
              if (range.hasData) ...[
                _composition(),
                const SizedBox(height: 16),
                ObservedRangeGrid(range: range),
                const SizedBox(height: 12),
                _legend(),
                const SizedBox(height: 12),
                Text(
                  'Shown hands skew toward value and called-down hands — they '
                  'tell you what is in the range and its shape, not the full range.',
                  style: GoogleFonts.ibmPlexSans(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      height: 1.4),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Log a few hands to showdown with this opponent\'s cards '
                      'entered, and their range will start filling in here.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSans(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 14,
                          height: 1.4),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _composition() {
    Widget chip(String label, int count, Color color) {
      if (count == 0) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(40),
        ),
        child: Text('$label $count',
            style: GoogleFonts.ibmPlexSans(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('Premium', range.premiumCount, const Color(0xFF54E98A)),
        chip('Strong', range.strongCount, const Color(0xFF89F1EC)),
        chip('Medium', range.mediumCount, const Color(0xFFFFC857)),
        chip('Weak', range.wideCount, const Color(0xFFE85D5D)),
      ],
    );
  }

  Widget _legend() {
    Widget dot(String label, Color color) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, color: color.withOpacity(0.7)),
            const SizedBox(width: 5),
            Text(label,
                style: GoogleFonts.ibmPlexSans(
                    color: Colors.white.withOpacity(0.6), fontSize: 12)),
          ],
        );
    return Row(
      children: [
        dot('Raised', const Color(0xFFFFC857)),
        const SizedBox(width: 16),
        dot('Called / limped', const Color(0xFF89F1EC)),
      ],
    );
  }
}
