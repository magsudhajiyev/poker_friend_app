import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';

/// Individual day cell for the calendar grid
/// Supports normal, selected, today, and disabled states
class CalendarDayCell extends StatelessWidget {
  final int day;
  final bool isSelected;
  final bool isToday;
  final bool isDisabled;
  final bool hasEvent;
  final VoidCallback? onTap;

  const CalendarDayCell({
    Key? key,
    required this.day,
    this.isSelected = false,
    this.isToday = false,
    this.isDisabled = false,
    this.hasEvent = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Container(
        width: 44,
        height: 44,
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
                  fontSize: isSelected ? 24 : 20,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  color: _getTextColor(),
                  letterSpacing: isSelected ? 0 : -0.45,
                ),
              ),
              if (hasEvent && !isSelected)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 4,
                  height: 4,
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
