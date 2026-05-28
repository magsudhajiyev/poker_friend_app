import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reusable top nav bar matching the Figma design system.
///
/// Variants via optional params:
/// - [subtitle]   — show/hide the secondary line below the title
/// - [onMenuTap]  — if provided, shows the DotsThreeOutline menu icon on the right;
///                  if null, a same-width spacer keeps the title truly centred
/// - [menuKey]    — optional GlobalKey to position menu overlays
class TopNavBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final VoidCallback? onMenuTap;
  final GlobalKey? menuKey;

  const TopNavBar({
    super.key,
    required this.title,
    this.subtitle,
    required this.onBack,
    this.onMenuTap,
    this.menuKey,
  });

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    return Container(
      color: const Color(0xFF161719),
      padding: EdgeInsets.only(top: statusBarHeight, bottom: 12),
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Back — CaretLeft, 44px touch target
              GestureDetector(
                onTap: onBack,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/icons/CaretLeft.svg',
                      width: 20,
                      height: 20,
                    ),
                  ),
                ),
              ),

              // Centre — title + optional subtitle
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 22 / 17,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFFB9B9B9),
                          height: 20 / 13,
                        ),
                      ),
                  ],
                ),
              ),

              // Right — DotsThreeOutline or spacer to keep title centred
              if (onMenuTap != null)
                GestureDetector(
                  key: menuKey,
                  onTap: onMenuTap,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/icons/DotsThreeOutline.svg',
                        width: 24,
                        height: 24,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 44),
            ],
          ),
        ),
      ),
    );
  }
}
