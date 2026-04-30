import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';

/// A snap point for the raise slider.
class SnapPoint {
  final String label;
  final double amount;

  const SnapPoint({required this.label, required this.amount});
}

/// Overlay shown during swipe-up raise gesture.
/// Displays a vertical slider with snap points (min, 2.5x, 3x, pot, all-in etc.)
/// User drags up to increase, releases to confirm. Tap amount to open numpad.
class RaiseSnapOverlay extends StatelessWidget {
  final List<SnapPoint> snapPoints;
  final double currentAmount;
  final int activeSnapIndex;
  final double dragProgress; // 0.0 (min) to 1.0 (all-in)
  final String actionLabel; // "BET" or "RAISE"
  final String formattedAmount;
  final bool isCashGame;
  final VoidCallback? onTapAmount; // Open numpad for custom

  const RaiseSnapOverlay({
    Key? key,
    required this.snapPoints,
    required this.currentAmount,
    required this.activeSnapIndex,
    required this.dragProgress,
    required this.actionLabel,
    required this.formattedAmount,
    required this.isCashGame,
    this.onTapAmount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Fill the parent Stack entirely — no overflow
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final overlayHeight = constraints.maxHeight;
          final trackHeight = (overlayHeight - 80).clamp(60.0, double.infinity);

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.95),
                  Colors.black.withValues(alpha: 0.7),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
            ),
            child: Stack(
              children: [
                // Snap point labels along right side
                Positioned(
                  right: 24,
                  top: 20,
                  bottom: 60,
                  child: _buildSnapPointTrack(trackHeight),
                ),

                // Current amount display — centered
                Positioned(
                  left: 0,
                  right: 80,
                  bottom: 20,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actionLabel,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formattedAmount,
                        style: GoogleFonts.robotoMono(
                          fontSize: 32,
                          color: const Color(0xFF89F1EC),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.raiseSnapReleaseToType,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.3),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSnapPointTrack(double trackHeight) {
    if (snapPoints.isEmpty) return const SizedBox.shrink();

    // Track grows thicker as user drags up: 2px → 6px
    final clampedProgress = dragProgress.clamp(0.0, 1.0);
    final baseWidth = 2.0;
    final progressWidth = baseWidth + (clampedProgress * 4.0);

    return SizedBox(
      width: 80,
      height: trackHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Track line (background) — spans from bottom (Min) to top (All-In) dot
          // Offset by 5px from top/bottom to align with dot centers
          Positioned(
            right: 4,
            top: 5,
            bottom: 5,
            child: Container(
              width: baseWidth,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),

          // Progress fill (thickens with drag) — centered on same axis
          if (clampedProgress > 0)
            Positioned(
              right: 5 - (progressWidth / 2),
              bottom: 0,
              child: Container(
                width: progressWidth,
                height: trackHeight * clampedProgress,
                decoration: BoxDecoration(
                  color: const Color(0xFF89F1EC),
                  borderRadius: BorderRadius.circular(progressWidth / 2),
                ),
              ),
            ),

          // Snap point markers
          ...List.generate(snapPoints.length, (index) {
            final progress = snapPoints.length > 1
                ? index / (snapPoints.length - 1)
                : 0.0;
            // Bottom = 0 (min), Top = 1 (all-in)
            final yPos = trackHeight * (1.0 - progress);
            final isActive = index == activeSnapIndex;
            final isPassed = index <= activeSnapIndex;

            // Key labels (x multipliers, %, Pot, All-In, Min) get bold treatment;
            // round-number labels (plain numbers like 800, 1.6K) are smaller/lighter
            final label = snapPoints[index].label;
            final isKeyPoint = label.contains('x') ||
                label.contains('%') ||
                label == 'Pot' ||
                label == 'All-In' ||
                label == 'Min';

            return Positioned(
              right: 0,
              top: (yPos - 8).clamp(0.0, trackHeight - 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Label
                  Text(
                    label,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: isActive ? 15 : (isKeyPoint ? 13 : 11),
                      color: isActive
                          ? const Color(0xFF89F1EC)
                          : isPassed
                              ? Colors.white.withValues(alpha: isKeyPoint ? 0.7 : 0.45)
                              : Colors.white.withValues(alpha: isKeyPoint ? 0.4 : 0.25),
                      fontWeight: isActive ? FontWeight.w700 : (isKeyPoint ? FontWeight.w600 : FontWeight.w400),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Dot
                  Container(
                    width: isActive ? 10 : (isKeyPoint ? 6 : 4),
                    height: isActive ? 10 : (isKeyPoint ? 6 : 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? const Color(0xFF89F1EC)
                          : isPassed
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.2),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: const Color(0xFF89F1EC).withValues(alpha: 0.5),
                                blurRadius: 8,
                              )
                            ]
                          : null,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Generate snap points for preflop raises.
  /// [lastBet] is the current bet to face (e.g. a previous raise amount).
  /// When lastBet > bigBlind, multipliers are based on lastBet instead of BB.
  static List<SnapPoint> preflopSnapPoints({
    required double minRaise,
    required double bigBlind,
    required double potAmount,
    required double maxBet,
    required bool isCashGame,
    double lastBet = 0,
  }) {
    final points = <SnapPoint>[];

    points.add(SnapPoint(label: 'Min', amount: minRaise));

    // Use lastBet as base when facing a raise, otherwise use BB
    final base = (lastBet > bigBlind) ? lastBet : bigBlind;

    final x22 = base * 2.2;
    if (x22 > minRaise && x22 < maxBet) {
      points.add(SnapPoint(label: '2.2x', amount: x22));
    }

    final x25 = base * 2.5;
    if (x25 > minRaise && x25 < maxBet) {
      points.add(SnapPoint(label: '2.5x', amount: x25));
    }

    final x3 = base * 3;
    if (x3 > minRaise && x3 < maxBet) {
      points.add(SnapPoint(label: '3x', amount: x3));
    }

    final x4 = base * 4;
    if (x4 > minRaise && x4 < maxBet) {
      points.add(SnapPoint(label: '4x', amount: x4));
    }

    if (potAmount > minRaise && potAmount < maxBet) {
      points.add(SnapPoint(label: 'Pot', amount: potAmount));
    }

    points.add(SnapPoint(label: 'All-In', amount: maxBet));

    return _insertRoundNumbers(points, bigBlind);
  }

  /// Generate snap points for postflop bets/raises.
  /// [lastBet] is the current bet to face. When > 0, shows raise multipliers
  /// (2x, 2.5x, 3x of lastBet) instead of pot percentages.
  static List<SnapPoint> postflopSnapPoints({
    required double minBet,
    required double potAmount,
    required double maxBet,
    required bool isCashGame,
    double bigBlind = 0,
    double lastBet = 0,
  }) {
    final points = <SnapPoint>[];

    points.add(SnapPoint(label: 'Min', amount: minBet));

    if (lastBet > 0) {
      // Facing a bet/raise — show multipliers of the last bet
      final x2 = lastBet * 2;
      if (x2 > minBet && x2 < maxBet) {
        points.add(SnapPoint(label: '2x', amount: x2));
      }

      final x25 = lastBet * 2.5;
      if (x25 > minBet && x25 < maxBet) {
        points.add(SnapPoint(label: '2.5x', amount: x25));
      }

      final x3 = lastBet * 3;
      if (x3 > minBet && x3 < maxBet) {
        points.add(SnapPoint(label: '3x', amount: x3));
      }

      if (potAmount > minBet && potAmount < maxBet) {
        points.add(SnapPoint(label: 'Pot', amount: potAmount));
      }
    } else if (potAmount > 0) {
      // Open bet — show pot percentages
      final p33 = potAmount * 0.33;
      if (p33 > minBet && p33 < maxBet) {
        points.add(SnapPoint(label: '33%', amount: p33));
      }

      final p50 = potAmount * 0.50;
      if (p50 > minBet && p50 < maxBet) {
        points.add(SnapPoint(label: '50%', amount: p50));
      }

      final p75 = potAmount * 0.75;
      if (p75 > minBet && p75 < maxBet) {
        points.add(SnapPoint(label: '75%', amount: p75));
      }

      if (potAmount > minBet && potAmount < maxBet) {
        points.add(SnapPoint(label: 'Pot', amount: potAmount));
      }
    }

    points.add(SnapPoint(label: 'All-In', amount: maxBet));

    final bb = bigBlind > 0 ? bigBlind : (maxBet > 0 ? maxBet / 100.0 : 100.0);
    return _insertRoundNumbers(points, bb);
  }

  /// Insert round-number snap points between consecutive key points.
  /// At most 2 round numbers per gap to keep the track clean.
  static List<SnapPoint> _insertRoundNumbers(List<SnapPoint> keyPoints, double bigBlind) {
    if (keyPoints.length < 2) return keyPoints;

    final result = <SnapPoint>[];

    for (int i = 0; i < keyPoints.length; i++) {
      result.add(keyPoints[i]);

      if (i < keyPoints.length - 1) {
        final lo = keyPoints[i].amount;
        final hi = keyPoints[i + 1].amount;
        final gap = hi - lo;

        // Skip tiny gaps (less than 2 BB)
        if (gap < bigBlind * 2) continue;

        // Pick a step that yields 1-3 intermediates in this gap
        final step = _stepForGap(gap, bigBlind);
        if (step <= 0) continue;

        final inserted = <SnapPoint>[];
        final firstRound = (lo / step).ceil() * step;
        for (double v = firstRound.toDouble(); v < hi; v += step) {
          // Skip if too close to endpoints (within 30% of gap from either end)
          if ((v - lo) < gap * 0.15) continue;
          if ((hi - v) < gap * 0.15) continue;
          inserted.add(SnapPoint(label: _formatRoundLabel(v), amount: v));
        }

        // Cap at 2 intermediates per gap — pick evenly spaced ones
        if (inserted.length > 2) {
          final mid = inserted.length ~/ 2;
          result.add(inserted[mid ~/ 2 == 0 ? 0 : mid - 1]);
          result.add(inserted[mid]);
        } else {
          result.addAll(inserted);
        }
      }
    }

    return result;
  }

  /// Pick a round step size that gives 1-3 points in a gap.
  static double _stepForGap(double gap, double bigBlind) {
    // Target ~2 intermediates: step ≈ gap / 3
    final target = gap / 3;

    // Round to a nice number
    final candidates = [
      1.0, 2.0, 5.0, 10.0, 25.0, 50.0, 100.0, 200.0, 250.0, 500.0,
      1000.0, 2500.0, 5000.0, 10000.0, 25000.0, 50000.0, 100000.0,
    ];

    // Find the candidate closest to target
    double best = candidates.first;
    double bestDist = (candidates.first - target).abs();
    for (final c in candidates) {
      final dist = (c - target).abs();
      if (dist < bestDist) {
        bestDist = dist;
        best = c;
      }
    }
    return best;
  }

  /// Format a round number as a compact label.
  static String _formatRoundLabel(double amount) {
    if (amount >= 1000000) {
      final m = amount / 1000000;
      return m == m.roundToDouble() ? '${m.toInt()}M' : '${m.toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      final k = amount / 1000;
      return k == k.roundToDouble() ? '${k.toInt()}K' : '${k.toStringAsFixed(1)}K';
    }
    return amount == amount.roundToDouble()
        ? amount.toInt().toString()
        : amount.toStringAsFixed(1);
  }

  /// Find the closest snap point index for a given drag progress (0-1).
  static int findClosestSnap(List<SnapPoint> points, double progress) {
    if (points.isEmpty) return 0;
    if (points.length == 1) return 0;

    // Map progress to snap index
    final exactIndex = progress * (points.length - 1);
    return exactIndex.round().clamp(0, points.length - 1);
  }
}
