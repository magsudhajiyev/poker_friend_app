import 'package:flutter/material.dart';

import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';
import '../design_system/constants/typography.dart';

/// Shared playing-card face: white card, mono rank over suit glyph, red
/// hearts/diamonds. Used by Hand Details and the Daily Challenge results.
///
/// [card] is rank + suit glyph, e.g. `A♠`, `T♦`, `10♥`.
class PlayingCardFace extends StatelessWidget {
  final String card;

  /// Card width in logical pixels (height is `width * 1.3`). Use
  /// [responsiveWidth] to derive it from the screen + text scale.
  final double width;

  /// Explicit glyph sizes. When null they scale with [width].
  final double? rankSize;
  final double? suitSize;

  /// Ink colour of the red suits.
  final Color redColor;

  const PlayingCardFace(
    this.card, {
    super.key,
    required this.width,
    this.rankSize,
    this.suitSize,
    this.redColor = AppColors.cardFaceRed,
  });

  /// Screen-fraction width, clamped, and grown (up to 1.4x) with the user's
  /// text scale so the glyphs stay readable at large text sizes.
  static double responsiveWidth(
    BuildContext context, {
    double fraction = 0.085,
    double min = 30,
    double max = 42,
  }) {
    final base = (MediaQuery.sizeOf(context).width * fraction).clamp(min, max);
    final text = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.4);
    return base * text;
  }

  static bool isRed(String card) => card.endsWith('♥') || card.endsWith('♦');

  static const _ranks = {
    'A': 'Ace', 'K': 'King', 'Q': 'Queen', 'J': 'Jack', 'T': 'Ten',
    '10': 'Ten', '9': 'Nine', '8': 'Eight', '7': 'Seven', '6': 'Six',
    '5': 'Five', '4': 'Four', '3': 'Three', '2': 'Two',
  };
  static const _suits = {
    '♠': 'spades', '♥': 'hearts', '♦': 'diamonds', '♣': 'clubs',
  };

  /// "A♠" -> "Ace of spades". Falls back to the raw text for unknown input.
  static String semanticLabel(String card) {
    if (card.length < 2) return card;
    final rank = _ranks[card.substring(0, card.length - 1)];
    final suit = _suits[card.substring(card.length - 1)];
    return rank == null || suit == null ? card : '$rank of $suit';
  }

  @override
  Widget build(BuildContext context) {
    if (card.length < 2) return const SizedBox.shrink();
    final ink = isRed(card) ? redColor : AppColors.textInverse;
    return Semantics(
      label: semanticLabel(card),
      excludeSemantics: true,
      child: Container(
        width: width,
        height: width * 1.3,
        decoration: BoxDecoration(
          color: AppColors.bgInverse,
          borderRadius: BorderRadius.circular(AppDecorations.legendDotRadius),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                card.substring(0, card.length - 1),
                style: AppTypography.mono(
                  fontSize: rankSize ?? width * 0.5,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  color: ink,
                ),
              ),
              Text(
                card.substring(card.length - 1),
                style: TextStyle(
                  fontSize: suitSize ?? width * 0.42,
                  height: 1.0,
                  color: ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
