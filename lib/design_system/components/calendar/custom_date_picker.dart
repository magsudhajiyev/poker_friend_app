import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../constants/colors.dart';
import '../../constants/spacing.dart';
import '../../constants/typography.dart';
import 'calendar_day_cell.dart';

/// Shows the app's custom full-screen date picker dialog and returns the
/// selected date, or `null` if cancelled.
///
/// This is a shared extraction of the picker originally implemented on
/// `_CalendarScreenState`. It is used across screens that need to pick a
/// single calendar date (calendar screen, home screen, create event screen).
///
/// Responsive sizing — everything scales from screen width so the picker
/// looks right on iPhone SE, iPhone 16 Pro, and tablets.
Future<DateTime?> showCustomDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  DateTime displayMonth = DateTime(initialDate.year, initialDate.month);
  DateTime? selectedDate = initialDate;

  bool isOutOfRange(DateTime date) {
    if (firstDate != null &&
        DateTime(date.year, date.month, date.day)
            .isBefore(DateTime(firstDate.year, firstDate.month, firstDate.day))) {
      return true;
    }
    if (lastDate != null &&
        DateTime(date.year, date.month, date.day)
            .isAfter(DateTime(lastDate.year, lastDate.month, lastDate.day))) {
      return true;
    }
    return false;
  }

  return await showGeneralDialog<DateTime>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Date picker',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return StatefulBuilder(
        builder: (context, setPickerState) {
          final mediaQuery = MediaQuery.of(context);
          final screenWidth = mediaQuery.size.width;

          final cardWidth = (screenWidth * 0.92).clamp(320.0, 420.0);
          const cardHorizontalPadding = AppSpacing.md;
          const cardBorderWidth = 1.0;

          final gridWidth =
              cardWidth - (cardHorizontalPadding * 2) - (cardBorderWidth * 2);
          final cellSize =
              (gridWidth / 7).floorToDouble().clamp(36.0, 48.0);

          final monthFontSize = (screenWidth * 0.042).clamp(15.0, 18.0);
          final dayHeaderFontSize = (cellSize * 0.3).clamp(11.0, 13.0);

          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.pop(dialogContext),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
              Center(
                child: Material(
                  color: Colors.transparent,
                  child: GestureDetector(
                    onTap: () {},
                    onHorizontalDragEnd: (details) {
                      final velocity = details.primaryVelocity;
                      if (velocity == null) return;
                      if (velocity < -100) {
                        setPickerState(() {
                          displayMonth = DateTime(
                            displayMonth.year,
                            displayMonth.month + 1,
                          );
                        });
                      } else if (velocity > 100) {
                        setPickerState(() {
                          displayMonth = DateTime(
                            displayMonth.year,
                            displayMonth.month - 1,
                          );
                        });
                      }
                    },
                    child: Container(
                      width: cardWidth,
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.whiteBorder(opacity: 0.10),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: cardHorizontalPadding,
                        vertical: AppSpacing.xl,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Select Date:',
                                style: AppTypography.subtitle(
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                              const Spacer(),
                              _pickerPillButton(
                                icon: Icons.close,
                                label: 'Reset',
                                color: AppColors.errorRed,
                                bordered: false,
                                onTap: () {
                                  setPickerState(() {
                                    selectedDate = initialDate;
                                    displayMonth = DateTime(
                                      initialDate.year,
                                      initialDate.month,
                                    );
                                  });
                                },
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              _pickerPillButton(
                                icon: Icons.today,
                                label: 'Today',
                                color: Colors.white,
                                bordered: true,
                                onTap: () {
                                  final today = DateTime.now();
                                  if (isOutOfRange(today)) return;
                                  setPickerState(() {
                                    selectedDate = DateTime(
                                      today.year,
                                      today.month,
                                      today.day,
                                    );
                                    displayMonth = DateTime(
                                      today.year,
                                      today.month,
                                    );
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('MMMM yyyy').format(displayMonth),
                                style: GoogleFonts.ibmPlexSans(
                                  color: Colors.white,
                                  fontSize: monthFontSize,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.43,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _pickerNavArrow(
                                    char: '‹',
                                    onTap: () {
                                      setPickerState(() {
                                        displayMonth = DateTime(
                                          displayMonth.year,
                                          displayMonth.month - 1,
                                        );
                                      });
                                    },
                                  ),
                                  const SizedBox(width: AppSpacing.lg),
                                  _pickerNavArrow(
                                    char: '›',
                                    onTap: () {
                                      setPickerState(() {
                                        displayMonth = DateTime(
                                          displayMonth.year,
                                          displayMonth.month + 1,
                                        );
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              'SUN',
                              'MON',
                              'TUE',
                              'WED',
                              'THU',
                              'FRI',
                              'SAT'
                            ].map((day) {
                              return SizedBox(
                                width: cellSize,
                                child: Center(
                                  child: Text(
                                    day,
                                    style: GoogleFonts.ibmPlexSans(
                                      color: AppColors.labelTertiary,
                                      fontSize: dayHeaderFontSize,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          _buildPickerDayGrid(
                            displayMonth: displayMonth,
                            selectedDate: selectedDate,
                            cellSize: cellSize,
                            isDisabledDate: isOutOfRange,
                            onDayTap: (date) {
                              setPickerState(() {
                                selectedDate = date;
                              });
                            },
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Row(
                            children: [
                              Expanded(
                                child: _pickerFooterButton(
                                  label: 'Cancel',
                                  filled: false,
                                  onTap: () => Navigator.pop(dialogContext),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: _pickerFooterButton(
                                  label: 'Done',
                                  filled: true,
                                  onTap: () => Navigator.pop(
                                    dialogContext,
                                    selectedDate,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _pickerPillButton({
  required IconData icon,
  required String label,
  required Color color,
  required bool bordered,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.symmetric(
        horizontal: bordered ? AppSpacing.xs : AppSpacing.xxs,
        vertical: AppSpacing.xxxs,
      ),
      decoration: bordered
          ? BoxDecoration(
              border: Border.all(
                color: AppColors.whiteBorder(opacity: 0.3),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(60),
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _pickerNavArrow({required String char, required VoidCallback onTap}) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      child: Text(
        char,
        textAlign: TextAlign.center,
        style: GoogleFonts.ibmPlexSans(
          fontSize: 28,
          fontWeight: FontWeight.w500,
          color: AppColors.accentPrimary,
          height: 1.0,
        ),
      ),
    ),
  );
}

Widget _pickerFooterButton({
  required String label,
  required bool filled,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? AppColors.accentPrimary : Colors.transparent,
        borderRadius: BorderRadius.circular(60),
        border: filled
            ? null
            : Border.all(color: AppColors.accentPrimary, width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.ibmPlexSans(
          color: filled ? Colors.black : AppColors.accentPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.43,
        ),
      ),
    ),
  );
}

Widget _buildPickerDayGrid({
  required DateTime displayMonth,
  required DateTime? selectedDate,
  required double cellSize,
  required bool Function(DateTime) isDisabledDate,
  required ValueChanged<DateTime> onDayTap,
}) {
  final firstDayOfMonth = DateTime(displayMonth.year, displayMonth.month, 1);
  final startingWeekday = firstDayOfMonth.weekday % 7;
  final daysInMonth = DateTime(displayMonth.year, displayMonth.month + 1, 0).day;

  final prevMonth = DateTime(displayMonth.year, displayMonth.month - 1, 1);
  final daysInPrevMonth = DateTime(prevMonth.year, prevMonth.month + 1, 0).day;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  final weeks = <Widget>[];
  int dayCounter = 1;
  int nextMonthDay = 1;

  for (int week = 0; week < 6; week++) {
    final cells = <Widget>[];

    for (int col = 0; col < 7; col++) {
      final cellIndex = week * 7 + col;

      Widget cell;
      if (cellIndex < startingWeekday) {
        final prevDay = daysInPrevMonth - startingWeekday + cellIndex + 1;
        cell = CalendarDayCell(
          day: prevDay,
          isDisabled: true,
          size: cellSize,
        );
      } else if (dayCounter <= daysInMonth) {
        final dayNum = dayCounter;
        final date = DateTime(displayMonth.year, displayMonth.month, dayNum);
        final isSelected = selectedDate != null && sameDay(date, selectedDate);
        final isToday = sameDay(date, today);
        final disabled = isDisabledDate(date);
        cell = CalendarDayCell(
          day: dayNum,
          isSelected: isSelected,
          isToday: isToday,
          isDisabled: disabled,
          size: cellSize,
          onTap: disabled ? null : () => onDayTap(date),
        );
        dayCounter++;
      } else {
        cell = CalendarDayCell(
          day: nextMonthDay,
          isDisabled: true,
          size: cellSize,
        );
        nextMonthDay++;
      }

      cells.add(cell);
    }

    weeks.add(Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxs / 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: cells,
      ),
    ));
  }

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: weeks,
  );
}
