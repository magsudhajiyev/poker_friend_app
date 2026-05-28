import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import 'calendar_day_cell.dart';
import 'time_picker_row.dart';

/// Calendar picker card with month navigation, day grid, and time picker
/// Matches the Figma design with glassy frosted effect
class CalendarPicker extends StatelessWidget {
  final DateTime selectedDate;
  final DateTime displayedMonth;
  final TimeOfDay selectedTime;
  final Set<DateTime>? eventDates;
  final ValueChanged<DateTime>? onDateSelected;
  final VoidCallback? onPreviousMonth;
  final VoidCallback? onNextMonth;
  final VoidCallback? onMonthYearTap;
  final VoidCallback? onTimeTap;
  final bool showTimePicker;

  const CalendarPicker({
    Key? key,
    required this.selectedDate,
    required this.displayedMonth,
    required this.selectedTime,
    this.eventDates,
    this.onDateSelected,
    this.onPreviousMonth,
    this.onNextMonth,
    this.onMonthYearTap,
    this.onTimeTap,
    this.showTimePicker = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              _buildDayHeaders(),
              _buildCalendarGrid(),
              _buildSeparator(),
              if (showTimePicker)
                TimePickerRow(
                  time: selectedTime,
                  onTap: onTimeTap,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final monthName = _getMonthName(displayedMonth.month);
    final year = displayedMonth.year;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Month and Year with dropdown arrow
          GestureDetector(
            onTap: onMonthYearTap,
            child: Row(
              children: [
                Text(
                  '$monthName $year',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.43,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '›',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentPrimary,
                    letterSpacing: -0.5,
                    height: 18 / 15,
                  ),
                ),
              ],
            ),
          ),
          // Navigation arrows
          Row(
            children: [
              GestureDetector(
                onTap: onPreviousMonth,
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  child: Text(
                    '‹',
                    style: TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: AppColors.accentPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: onNextMonth,
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  child: Text(
                    '›',
                    style: TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: AppColors.accentPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeaders() {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: days.map((day) {
          return SizedBox(
            width: 32,
            child: Text(
              day,
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.labelTertiary,
                letterSpacing: 0,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateTime(displayedMonth.year, displayedMonth.month + 1, 0).day;
    final firstDayOfMonth = DateTime(displayedMonth.year, displayedMonth.month, 1);
    final startingWeekday = firstDayOfMonth.weekday - 1; // Monday = 0, Sunday = 6

    // Previous month days
    final prevMonth = DateTime(displayedMonth.year, displayedMonth.month - 1, 1);
    final daysInPrevMonth = DateTime(prevMonth.year, prevMonth.month + 1, 0).day;

    List<Widget> weeks = [];
    int dayCounter = 1;
    int nextMonthDay = 1;

    for (int week = 0; week < 5; week++) {
      List<Widget> days = [];

      for (int day = 0; day < 7; day++) {
        final cellIndex = week * 7 + day;

        if (cellIndex < startingWeekday) {
          // Previous month days
          final prevDay = daysInPrevMonth - startingWeekday + cellIndex + 1;
          days.add(CalendarDayCell(
            day: prevDay,
            isDisabled: true,
          ));
        } else if (dayCounter <= daysInMonth) {
          // Current month days
          final currentDay = dayCounter;
          final date = DateTime(displayedMonth.year, displayedMonth.month, currentDay);
          final isSelected = _isSameDay(date, selectedDate);
          final isToday = _isSameDay(date, DateTime.now());
          final hasEvent = eventDates?.any((e) => _isSameDay(e, date)) ?? false;

          days.add(CalendarDayCell(
            day: currentDay,
            isSelected: isSelected,
            isToday: isToday,
            hasEvent: hasEvent,
            onTap: () => onDateSelected?.call(date),
          ));
          dayCounter++;
        } else {
          // Next month days
          days.add(CalendarDayCell(
            day: nextMonthDay,
            isDisabled: true,
          ));
          nextMonthDay++;
        }
      }

      weeks.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3.5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days,
          ),
        ),
      );
    }

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -100) {
          // Swipe left → next month
          onNextMonth?.call();
        } else if (details.primaryVelocity! > 100) {
          // Swipe right → previous month
          onPreviousMonth?.call();
        }
      },
      child: Column(
        children: weeks,
      ),
    );
  }

  Widget _buildSeparator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 11,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.labelTertiary.withOpacity(0.16),
            width: 0.5,
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}
