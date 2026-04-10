import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';

/// Individual day cell for the calendar grid
/// Supports normal, selected, today, and disabled states.
///
/// [size] controls the cell diameter (default 44). The day-number font
/// scales proportionally so the cell remains legible on small phones.
class CalendarDayCell extends StatelessWidget {
  final int day;
  final bool isSelected;
  final bool isToday;
  final bool isDisabled;
  final bool hasEvent;
  final VoidCallback? onTap;
  final double size;

  const CalendarDayCell({
    Key? key,
    required this.day,
    this.isSelected = false,
    this.isToday = false,
    this.isDisabled = false,
    this.hasEvent = false,
    this.onTap,
    this.size = 44.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Day-number font scales with cell size so small devices still render
    // legibly. Ratios match the original 44px spec (20/44 normal, 24/44 selected).
    final normalFontSize = size * (20.0 / 44.0);
    final selectedFontSize = size * (24.0 / 44.0);
    final dotSize = (size * (4.0 / 44.0)).clamp(3.0, 5.0);
    final dotTopMargin = (size * (2.0 / 44.0)).clamp(1.5, 3.0);

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(
                  color: const Color(0xFF89F1EC).withValues(alpha: 0.5),
                  width: 1.5,
                )
              : null,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                day.toString(),
                style: GoogleFonts.ibmPlexSans(
                  fontSize: isSelected ? selectedFontSize : normalFontSize,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  color: _getTextColor(),
                  letterSpacing: isSelected ? 0 : -0.45,
                ),
              ),
              if (hasEvent && !isSelected)
                Container(
                  margin: EdgeInsets.only(top: dotTopMargin),
                  width: dotSize,
                  height: dotSize,
                  decoration: const BoxDecoration(
                    color: Color(0xFF89F1EC),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTextColor() {
    if (isDisabled) {
      return AppColors.calendarDayDisabled;
    }
    if (isSelected || isToday) {
      return const Color(0xFF89F1EC);
    }
    return AppColors.calendarDayText;
  }
}
