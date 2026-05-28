import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Segmented tab selector matching Figma v2 spec (Cash Game / Tournament tab).
///
/// White outer pill (radius 999), `#161719` active pill, 2px inner padding.
/// Text: IBM Plex Sans Medium 15px, tracking -0.5, lh 24.
class AppTabSelector extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;

  const AppTabSelector({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(tabs.length, (i) {
          final isSelected = i == selectedIndex;
          return GestureDetector(
            onTap: () => onTabChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF161719) : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                tabs[i],
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF0C0C0C),
                  letterSpacing: -0.5,
                  height: 24 / 15,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
