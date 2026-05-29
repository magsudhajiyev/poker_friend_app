import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reusable top nav bar matching the Figma design system.
///
/// Variants via optional params:
/// - [subtitle]               — secondary line below the title
/// - [onMenuTap]              — shows the DotsThreeOutline icon on the right
/// - [menuKey]                — optional GlobalKey to position menu overlays
/// - [rightAction]            — arbitrary widget on the right (takes precedence over [onMenuTap])
/// - [backgroundColor]        — defaults to [Color(0xFF161719)]
/// - [includeStatusBarPadding]— when false the caller's SafeArea handles insets (default true)
class TopNavBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final VoidCallback? onMenuTap;
  final GlobalKey? menuKey;
  final Widget? rightAction;
  final Color backgroundColor;
  final bool includeStatusBarPadding;

  const TopNavBar({
    super.key,
    required this.title,
    this.subtitle,
    required this.onBack,
    this.onMenuTap,
    this.menuKey,
    this.rightAction,
    this.backgroundColor = const Color(0xFF161719),
    this.includeStatusBarPadding = true,
  });

  @override
  Widget build(BuildContext context) {
    final statusBarHeight =
        includeStatusBarPadding ? MediaQuery.of(context).padding.top : 0.0;

    return Container(
      color: backgroundColor,
      padding: EdgeInsets.only(top: statusBarHeight, bottom: 12),
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Centre — title + optional subtitle (truly centred on canvas)
              Column(
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

              // Left — back chevron
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: onBack,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SvgPicture.asset(
                        'assets/icons/CaretLeft.svg',
                        width: 20,
                        height: 20,
                      ),
                    ),
                  ),
                ),
              ),

              // Right — custom widget, DotsThreeOutline, or symmetry spacer
              Align(
                alignment: Alignment.centerRight,
                child: rightAction != null
                    ? IntrinsicWidth(child: rightAction!)
                    : onMenuTap != null
                        ? GestureDetector(
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
                        : const SizedBox(width: 44),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
