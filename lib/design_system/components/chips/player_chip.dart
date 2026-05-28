import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Player name + position badge chip matching Figma v2 spec (Player Chip).
///
/// Container: `#161719` bg, radius 8px, p4, gap 4.
/// Name: IBM Plex Sans Medium 13px white.
/// Position badge: `#0C0C0C` bg, 38px wide, radius 4.
///   CO badge: `#A3FF78` text; others: `#B9B9B9` text.
class PlayerChip extends StatelessWidget {
  final String name;
  final String? position;

  const PlayerChip({
    super.key,
    required this.name,
    this.position,
  });

  static const _accentPositions = {'CO'};

  @override
  Widget build(BuildContext context) {
    final posColor = (position != null && _accentPositions.contains(position))
        ? const Color(0xFFA3FF78)
        : const Color(0xFFB9B9B9);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF161719),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 20 / 13,
            ),
          ),
          if (position != null) ...[
            const SizedBox(width: 4),
            Container(
              width: 38,
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0C0C),
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: Text(
                position!,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: posColor,
                  height: 16 / 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
