import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Poker-card suit icon rendered from the `assets/icons/card icons/` SVG
/// pack (`Property 1=Clubs`, `…=Spades`, `…=Hearts`, `…=Diamonds`).
///
/// Accepts either the unicode suit character (♥ ♠ ♦ ♣) or a named [Suit].
/// When `color` is `null` the SVG's baked fill is preserved — red for
/// hearts/diamonds, near-black for clubs/spades. Pass a `color` to override
/// (e.g. white when rendered on a dark surface).
class SuitIcon extends StatelessWidget {
  final String? suitChar;
  final Suit? suit;
  final double size;
  final Color? color;

  const SuitIcon({
    super.key,
    this.suitChar,
    this.suit,
    this.size = 20,
    this.color,
  }) : assert(suitChar != null || suit != null,
            'SuitIcon requires suitChar or suit');

  Suit get _suit {
    if (suit != null) return suit!;
    switch (suitChar) {
      case '♥':
        return Suit.hearts;
      case '♦':
        return Suit.diamonds;
      case '♠':
        return Suit.spades;
      case '♣':
      default:
        return Suit.clubs;
    }
  }

  static String assetPath(Suit s) {
    switch (s) {
      case Suit.clubs:
        return 'assets/icons/card icons/Property 1=Clubs.svg';
      case Suit.diamonds:
        return 'assets/icons/card icons/Property 1=Diamonds.svg';
      case Suit.hearts:
        return 'assets/icons/card icons/Property 1=Hearts.svg';
      case Suit.spades:
        return 'assets/icons/card icons/Property 1=Spades.svg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _suit;
    return SvgPicture.asset(
      assetPath(s),
      width: size,
      height: size,
      fit: BoxFit.contain,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
    );
  }
}

enum Suit { clubs, diamonds, hearts, spades }
