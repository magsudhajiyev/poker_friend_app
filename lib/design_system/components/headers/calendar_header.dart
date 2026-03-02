import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';

/// Calendar page header with back button, title, and subtitle
/// Has backdrop blur effect matching the Figma design
class CalendarHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onBackPressed;

  const CalendarHeader({
    Key? key,
    this.title = 'Poker Calendar',
    this.subtitle = 'Track your events',
    this.onBackPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 27, sigmaY: 27),
        child: Container(
          color: Colors.white.withOpacity(0.01),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: GestureDetector(
                      onTap: onBackPressed,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.iconButtonBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  // Title and subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: -1,
                            height: 1.36,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: AppColors.labelSecondary,
                            height: 1.44,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
