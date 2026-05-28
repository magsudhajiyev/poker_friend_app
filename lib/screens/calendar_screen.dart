import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/currency_service.dart';
import 'dart:ui' as ui;
import 'package:flutter_svg/flutter_svg.dart';
import '../services/calendar_event_service.dart';
import '../services/notification_service.dart';
import '../services/club_service.dart';
import '../services/event_service.dart';
import '../models/club.dart';
import '../models/club_event.dart';
import '../design_system/design_system.dart';
import '../design_system/components/drawer_dots.dart';
import '../widgets/global_bottom_nav_bar.dart';
import '../widgets/event_success_popup.dart';
import 'club/event_detail_screen.dart' as club_detail;
import 'event_detail_screen.dart';
import '../l10n/app_localizations.dart';

class CalendarScreen extends StatefulWidget {
  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime selectedDate = DateTime.now();
  DateTime currentMonth = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();
  List<PokerEvent> events = [];
  
  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final eventsData = await CalendarEventService.getUserEvents();

      setState(() {
        events = eventsData
            .map((data) => PokerEvent.fromJson(data))
            .toList();
      });
    } catch (e) {
      // Handle error silently or show user-friendly message
    }
  }

  // No longer needed - Firebase handles saves automatically
  // Kept for backward compatibility, but does nothing
  Future<void> _saveEvents() async {
    // Events are saved to Firebase when created, no action needed
  }

  List<PokerEvent> _getEventsForDate(DateTime date) {
    return events.where((event) {
      return event.date.year == date.year &&
          event.date.month == date.month &&
          event.date.day == date.day;
    }).toList();
  }

  void _showAddEventDialog() {
    final l10n = AppLocalizations.of(context);
    final outerContext = context;
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    final buyInController = TextEditingController();
    TimeOfDay dialogSelectedTime = TimeOfDay.now();
    DateTime dialogSelectedDate = selectedDate;
    String selectedType = 'Tournament';
    final eventTypeKey = GlobalKey();

    FormDrawer.show(
      context: context,
      title: l10n.calendarNewEvent,
      onSave: () async {
        if (titleController.text.isEmpty && locationController.text.isEmpty) {
          return;
        }
        final eventDate = DateTime(
          dialogSelectedDate.year,
          dialogSelectedDate.month,
          dialogSelectedDate.day,
          dialogSelectedTime.hour,
          dialogSelectedTime.minute,
        );

        try {
          final eventId = await CalendarEventService.createEvent(
            title: titleController.text.isEmpty ? selectedType : titleController.text,
            type: selectedType,
            location: locationController.text,
            date: eventDate,
            buyIn: double.tryParse(buyInController.text) ?? 0.0,
          );

          final newEvent = PokerEvent(
            id: eventId,
            title: titleController.text.isEmpty ? selectedType : titleController.text,
            type: selectedType,
            location: locationController.text,
            date: eventDate,
            buyIn: double.tryParse(buyInController.text) ?? 0.0,
          );

          setState(() {
            events.add(newEvent);
          });

          Navigator.pop(outerContext);

          if (!mounted) return;
          final action = await EventSuccessPopup.show(outerContext);

          if (action == 'add_another' && mounted) {
            _showAddEventDialog();
          }
        } catch (e) {
          ScaffoldMessenger.of(outerContext).showSnackBar(
            SnackBar(content: Text(l10n.calendarFailedToCreateEvent(e.toString()))),
          );
        }
      },
      body: StatefulBuilder(
        builder: (context, setSheetState) {
          return _buildEventFormContent(
            context: context,
            setSheetState: setSheetState,
            titleController: titleController,
            locationController: locationController,
            buyInController: buyInController,
            dialogSelectedDate: dialogSelectedDate,
            dialogSelectedTime: dialogSelectedTime,
            selectedType: selectedType,
            eventTypeKey: eventTypeKey,
            onDateChanged: (date) {
              setSheetState(() { dialogSelectedDate = date; });
            },
            onTimeChanged: (time) {
              setSheetState(() { dialogSelectedTime = time; });
            },
            onTypeChanged: (type) {
              setSheetState(() { selectedType = type; });
            },
          );
        },
      ),
    );
  }

  Widget _buildEventFormContent({
    required BuildContext context,
    required StateSetter setSheetState,
    required TextEditingController titleController,
    required TextEditingController locationController,
    required TextEditingController buyInController,
    required DateTime dialogSelectedDate,
    required TimeOfDay dialogSelectedTime,
    required String selectedType,
    required GlobalKey eventTypeKey,
    required ValueChanged<DateTime> onDateChanged,
    required ValueChanged<TimeOfDay> onTimeChanged,
    required ValueChanged<String> onTypeChanged,
  }) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        // Form Card 1 - Input Fields
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF101115),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                // Event Type Row
                GestureDetector(
                  onTap: () {
                    _showEventTypePicker(context, selectedType, (type) {
                      onTypeChanged(type);
                    }, eventTypeKey);
                  },
                  child: Container(
                    key: eventTypeKey,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.calendarEventType,
                          style: GoogleFonts.ibmPlexSans(
                            color: const Color(0xFFD3FFFD),
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            height: 1.44,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              selectedType,
                              style: GoogleFonts.ibmPlexSans(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                height: 1.44,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.unfold_more,
                              color: Colors.white,
                              size: 24,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                _buildSeparator(),
                // Title Input
                TextField(
                  controller: titleController,
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    height: 1.44,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.calendarEventTitle,
                    hintStyle: GoogleFonts.ibmPlexSans(
                      color: const Color(0xFF8C8C8C),
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      height: 1.44,
                    ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                _buildSeparator(),
                // Location Input
                TextField(
                  controller: locationController,
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    height: 1.44,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.calendarLocation,
                    hintStyle: GoogleFonts.ibmPlexSans(
                      color: const Color(0xFF8C8C8C),
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      height: 1.44,
                    ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                _buildSeparator(),
                // Buy In Input
                TextField(
                  controller: buyInController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    height: 1.44,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.calendarBuyInAmount,
                    hintStyle: GoogleFonts.ibmPlexSans(
                      color: const Color(0xFF8C8C8C),
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      height: 1.44,
                    ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Form Card 2 - Date/Time
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF101115),
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.calendarEventDateTime,
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.43,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 0.5,
                  color: const Color(0xFF545458),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      l10n.calendarStarts,
                      style: GoogleFonts.ibmPlexSans(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        height: 1.44,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () async {
                        final date = await _showCustomDatePicker(
                          context,
                          dialogSelectedDate,
                        );
                        if (date != null) {
                          onDateChanged(date);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B1E24),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Text(
                          DateFormat('d MMM yyyy').format(dialogSelectedDate),
                          style: GoogleFonts.ibmPlexSans(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: dialogSelectedTime,
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: Color(0xFF5CD9A4),
                                  surface: Color(0xFF1B1E24),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (time != null) {
                          onTimeChanged(time);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B1E24),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Text(
                          dialogSelectedTime.format(context),
                          style: GoogleFonts.ibmPlexSans(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ],
    );
  }

  Widget _buildSeparator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 1,
      color: const Color(0xFF1C1F21),
    );
  }

  void _showEventTypePicker(BuildContext context, String currentType, Function(String) onSelect, GlobalKey key) {
    final types = ['Tournament', 'Cash Game', 'Private Game', 'Online'];

    // Get the position of the Event Type row
    final RenderBox renderBox = key.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) {
        return Stack(
          children: [
            // Dismiss on tap outside
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(color: Colors.transparent),
              ),
            ),
            // Positioned dropdown
            Positioned(
              right: 32,
              top: offset.dy,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 184,
                  decoration: BoxDecoration(
                    color: const Color(0xFF161619),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.45),
                        blurRadius: 34,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...types.asMap().entries.map((entry) {
                        final index = entry.key;
                        final type = entry.value;
                        final isSelected = type == currentType;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                onSelect(type);
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    if (isSelected) ...[
                                      const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Text(
                                      type,
                                      style: const TextStyle(
                                        fontFamily: 'IBM Plex Sans',
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w400,
                                        height: 1.44,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Separator after all items except last
                            if (index < types.length - 1)
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                height: 0.5,
                                color: const Color(0xFF545458),
                              ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Custom date picker matching Figma design (node 1199:7011).
  ///
  /// Centered modal overlay with: "Select Date:" header, Clear + Today pills,
  /// Month/Year row with mint nav arrows, SUN-first 7-column day grid using
  /// the reusable [CalendarDayCell] component, and Cancel + Done footer
  /// buttons. All sizing is derived from [MediaQuery] so the picker stays
  /// readable on small phones and scales on tablets — no hardcoded pixels
  /// tuned to one device.
  Future<DateTime?> _showCustomDatePicker(BuildContext context, DateTime initialDate) async {
    final l10n = AppLocalizations.of(context);
    DateTime displayMonth = DateTime(initialDate.year, initialDate.month);
    DateTime? selectedDate = initialDate;

    return await showGeneralDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Date picker',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setPickerState) {
            // Responsive sizing — everything scales from screen width so the
            // picker looks right on iPhone SE, iPhone 16 Pro, and tablets.
            final mediaQuery = MediaQuery.of(context);
            final screenWidth = mediaQuery.size.width;

            // Card width: 92% of screen, clamped to a sane range. Figma
            // reference is ~370 on iPhone 16 Pro (430pt wide).
            final cardWidth = (screenWidth * 0.92).clamp(320.0, 420.0);

            // Internal horizontal padding of the card.
            final cardHorizontalPadding = AppSpacing.md; // 16

            // The card has a 1px border that consumes 2px of content width
            // (1px each side). Subtract it so the 7-column grid never
            // overflows by sub-pixel rounding.
            const cardBorderWidth = 1.0;

            // Usable width for the 7-column day grid. Floor the cell size
            // to guarantee `7 * cellSize <= gridWidth` regardless of device
            // pixel ratio or floating-point accumulation.
            final gridWidth =
                cardWidth - (cardHorizontalPadding * 2) - (cardBorderWidth * 2);
            final cellSize =
                (gridWidth / 7).floorToDouble().clamp(36.0, 48.0);

            // Font scaling — stay within readable bounds.
            final monthFontSize = (screenWidth * 0.042).clamp(15.0, 18.0);
            final dayHeaderFontSize = (cellSize * 0.3).clamp(11.0, 13.0);

            return Stack(
              children: [
                // Blurred backdrop — tap anywhere to dismiss.
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

                // Date picker card — centered.
                Center(
                  child: Material(
                    color: Colors.transparent,
                    child: GestureDetector(
                      // Swallow taps on the card so the backdrop dismiss
                      // doesn't fire when interacting with the picker.
                      onTap: () {},
                      // Horizontal swipes anywhere on the card navigate
                      // months — attached here (not the grid) so the
                      // gesture arena doesn't contend with per-cell taps.
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
                        padding: EdgeInsets.symmetric(
                          horizontal: cardHorizontalPadding,
                          vertical: AppSpacing.xl,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Title row: "Select Date:" + Reset + Today
                            Row(
                              children: [
                                Text(
                                  l10n.calendarSelectDate,
                                  style: AppTypography.subtitle(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                                const Spacer(),
                                // "Reset" (red) — reverts to the date the
                                // picker opened with. Named Reset not Clear
                                // because Done always returns a non-null date.
                                _pickerPillButton(
                                  icon: Icons.close,
                                  label: l10n.calendarReset,
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
                                SizedBox(width: AppSpacing.xs),
                                // "Today" — jumps to today's date.
                                _pickerPillButton(
                                  icon: Icons.today,
                                  label: l10n.commonToday,
                                  color: Colors.white,
                                  bordered: true,
                                  onTap: () {
                                    final today = DateTime.now();
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

                            SizedBox(height: AppSpacing.xl),

                            // ── Month/Year row with mint nav arrows
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
                                    SizedBox(width: AppSpacing.lg),
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

                            SizedBox(height: AppSpacing.md),

                            // ── Day-of-week header row (SUN-first)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [l10n.calendarSun, l10n.calendarMon, l10n.calendarTue, l10n.calendarWed, l10n.calendarThu, l10n.calendarFri, l10n.calendarSat]
                                  .map((day) {
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

                            SizedBox(height: AppSpacing.xs),

                            // ── Day grid (6 rows × 7 cols = 42 cells)
                            // Horizontal swipe handling lives on the card
                            // GestureDetector above so it doesn't compete
                            // with per-cell tap handlers in the arena.
                            _buildPickerDayGrid(
                              displayMonth: displayMonth,
                              selectedDate: selectedDate,
                              cellSize: cellSize,
                              onDayTap: (date) {
                                setPickerState(() {
                                  selectedDate = date;
                                });
                              },
                            ),

                            SizedBox(height: AppSpacing.xl),

                            // ── Footer buttons: Cancel + Done
                            Row(
                              children: [
                                Expanded(
                                  child: _pickerFooterButton(
                                    label: l10n.commonCancel,
                                    filled: false,
                                    onTap: () => Navigator.pop(dialogContext),
                                  ),
                                ),
                                SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: _pickerFooterButton(
                                    label: l10n.commonDone,
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

  /// Icon + label pill used in the date picker header (Reset / Today).
  ///
  /// Unified helper — the only variation between the two header buttons is
  /// the icon, label, text/icon color, and whether there's an outlined
  /// border. Keeping a single widget means the two pills stay visually
  /// consistent if the design changes.
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

  /// Mint chevron nav arrow used in the month/year row of the date picker.
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

  /// Cancel (outlined) / Done (filled mint) footer button for the date picker.
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
          color: filled ? AppColors.buttonPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(60),
          border: filled
              ? null
              : Border.all(color: AppColors.buttonPrimary, width: 1),
        ),
        child: Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            color: filled ? Colors.black : AppColors.buttonPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.43,
          ),
        ),
      ),
    );
  }

  /// 6×7 day grid for the custom date picker. Uses the reusable
  /// [CalendarDayCell] from the design system, sized directly via its
  /// [CalendarDayCell.size] parameter so the day numbers render at their
  /// native resolution on any device. Always renders 6 rows to keep the
  /// picker's height stable as the user navigates between months.
  Widget _buildPickerDayGrid({
    required DateTime displayMonth,
    required DateTime? selectedDate,
    required double cellSize,
    required ValueChanged<DateTime> onDayTap,
  }) {
    final firstDayOfMonth = DateTime(displayMonth.year, displayMonth.month, 1);
    // SUN=0, MON=1, …, SAT=6. DateTime.weekday is MON=1..SUN=7.
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

    // Always 6 rows — keeps the picker's overall height constant across
    // months so it doesn't visibly resize when the user navigates.
    for (int week = 0; week < 6; week++) {
      final cells = <Widget>[];

      for (int col = 0; col < 7; col++) {
        final cellIndex = week * 7 + col;

        Widget cell;
        if (cellIndex < startingWeekday) {
          // Trailing days from the previous month.
          final prevDay = daysInPrevMonth - startingWeekday + cellIndex + 1;
          cell = CalendarDayCell(
            day: prevDay,
            isDisabled: true,
            size: cellSize,
          );
        } else if (dayCounter <= daysInMonth) {
          // Current-month day.
          final dayNum = dayCounter;
          final date = DateTime(displayMonth.year, displayMonth.month, dayNum);
          final isSelected = selectedDate != null && sameDay(date, selectedDate);
          final isToday = sameDay(date, today);
          cell = CalendarDayCell(
            day: dayNum,
            isSelected: isSelected,
            isToday: isToday,
            size: cellSize,
            onTap: () => onDayTap(date),
          );
          dayCounter++;
        } else {
          // Leading days into the next month.
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
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxs / 2),
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

  @override
  Widget build(BuildContext context) {
    // Get dates that have events for the calendar
    final eventDates = events.map((e) => DateTime(e.date.year, e.date.month, e.date.day)).toSet();

    return Scaffold(
      backgroundColor: const Color(0xFF02050B),
      body: Stack(
        children: [
          // Top gradient blur
          Positioned(
            top: -162,
            left: 0,
            right: 0,
            child: Container(
              height: 217,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF4CDBFF).withOpacity(0.34),
                    const Color(0xFF2EB46A).withOpacity(0.34),
                    Colors.transparent,
                  ],
                  radius: 1.5,
                ),
              ),
            ),
          ),
          // Main content
          Column(
            children: [
              // Header
              CalendarHeader(
                title: AppLocalizations.of(context).calendarTitle,
                onBackPressed: () => Navigator.pop(context),
                onAddPressed: _showAddEventDialog,
              ),
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      // Calendar Picker
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: CalendarPicker(
                          selectedDate: selectedDate,
                          displayedMonth: currentMonth,
                          selectedTime: selectedTime,
                          eventDates: eventDates,
                          onDateSelected: (date) {
                            setState(() {
                              selectedDate = date;
                            });
                          },
                          onPreviousMonth: () {
                            setState(() {
                              currentMonth = DateTime(
                                currentMonth.year,
                                currentMonth.month - 1,
                              );
                            });
                          },
                          onNextMonth: () {
                            setState(() {
                              currentMonth = DateTime(
                                currentMonth.year,
                                currentMonth.month + 1,
                              );
                            });
                          },
                          onMonthYearTap: () async {
                            final year = await showDialog<int>(
                              context: context,
                              builder: (context) => _buildYearPicker(),
                            );
                            if (year != null) {
                              setState(() {
                                currentMonth = DateTime(year, currentMonth.month);
                              });
                            }
                          },
                          onTimeTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (time != null) {
                              setState(() {
                                selectedTime = time;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Events info card
                      _buildEventsForSelectedDate(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: GlobalBottomNavBar(currentScreen: 'calendar'),
    );
  }

  Widget _buildEventsForSelectedDate() {
    final l10n = AppLocalizations.of(context);
    final eventsForDate = _getEventsForDate(selectedDate);

    if (eventsForDate.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: const Color(0xFF101115),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black),
          ),
          child: Column(
            children: [
              // Calendar icon
              Icon(
                Icons.calendar_today_outlined,
                size: 24,
                color: const Color(0xFF89F1EC),
              ),
              const SizedBox(height: 6),
              // Title
              Text(
                l10n.calendarNoRecentEvents,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                  height: 1.44,
                ),
              ),
              const SizedBox(height: 4),
              // Subtitle
              Text(
                l10n.calendarAddFirstEvent,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFFD3FFFD),
                  height: 1.44,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Add New Event button
              GestureDetector(
                onTap: _showAddEventDialog,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF89F1EC),
                    borderRadius: BorderRadius.circular(110),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 24, color: Colors.black),
                      const SizedBox(width: 8),
                      Text(
                        l10n.calendarAddNewEvent,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                          letterSpacing: -0.5,
                          height: 24 / 17,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: eventsForDate.map((event) => _buildEventCard(event)).toList(),
    );
  }

  Widget _buildYearPicker() {
    final l10n = AppLocalizations.of(context);
    final currentYear = DateTime.now().year;
    final startYear = currentYear - 10;
    final endYear = currentYear + 10;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        height: 400,
        decoration: BoxDecoration(
          color: Color(0xFF000300),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Color(0x4CFFFFFF)),
        ),
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              l10n.calendarSelectYear,
              style: GoogleFonts.ibmPlexSans(
                color: Color(0xFFEBEBEB),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: endYear - startYear + 1,
                itemBuilder: (context, index) {
                  final year = startYear + index;
                  final isCurrentYear = year == currentMonth.year;

                  return GestureDetector(
                    onTap: () => Navigator.pop(context, year),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isCurrentYear ? Color(0xFFB6FF99) : Color(0xFF1F1F23),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          year.toString(),
                          style: GoogleFonts.ibmPlexSans(
                            color: isCurrentYear ? Colors.black : Color(0xFFEBEBEB),
                            fontSize: 14,
                            fontWeight: isCurrentYear ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(PokerEvent event) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: GestureDetector(
        onTap: () => _navigateToEventDetail(event),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF101115),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black),
          ),
          child: Column(
            children: [
              // Top row: Title + 3-dot menu
              SizedBox(
                height: 48,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                          height: 1.44,
                        ),
                      ),
                    ),
                    Builder(
                      builder: (ctx) => DrawerDots(
                        onTap: () {
                          final box = ctx.findRenderObject() as RenderBox;
                          final offset = box.localToGlobal(Offset.zero);
                          _showEventOptions(event, offset, box.size);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Separator
              Container(
                height: 1,
                color: const Color(0xFF1C1F21),
              ),
              // Bottom row: Date + Buy-in
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          DateFormat('MMM d, h:mm a').format(event.date).toLowerCase(),
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFB3B4B6),
                            height: 1.64,
                          ),
                        ),
                      ),
                    ),
                    if (event.buyIn > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          CurrencyService.formatCash(event.buyIn),
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFD3FFFD),
                            height: 1.44,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEventOptions(PokerEvent event, Offset iconOffset, Size iconSize) {
    final l10n = AppLocalizations.of(context);
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) {
        const tooltipWidth = 184.0;
        // Position: right-aligned to the icon, below it
        final left = iconOffset.dx + iconSize.width - tooltipWidth;
        final top = iconOffset.dy + iconSize.height + 8;

        return Stack(
          children: [
            // Dismiss on tap outside
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => entry.remove(),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: tooltipWidth,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF02050B),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x73000000),
                        blurRadius: 34,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Edit Event
                      GestureDetector(
                        onTap: () {
                          entry.remove();
                          _showEditEventDialog(event);
                        },
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              'icons/figma_icons/edit.svg',
                              width: 16,
                              height: 16,
                              colorFilter: const ColorFilter.mode(
                                Colors.white,
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  l10n.calendarEditEvent,
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                    height: 1.64,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Separator
                      Container(
                        height: 1,
                        color: const Color(0xFF1C1F21),
                      ),
                      // Delete Event
                      GestureDetector(
                        onTap: () {
                          entry.remove();
                          _deleteEvent(event);
                        },
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              'icons/figma_icons/delete.svg',
                              width: 16,
                              height: 16,
                              colorFilter: const ColorFilter.mode(
                                Color(0xFFD55A41),
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  l10n.calendarDeleteEvent,
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                    height: 1.64,
                                  ),
                                ),
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
          ],
        );
      },
    );

    overlay.insert(entry);
  }

  Future<void> _navigateToEventDetail(PokerEvent event) async {
    final l10n = AppLocalizations.of(context);
    // Club events -> club detail screen
    if (event.clubId != null && event.clubEventId != null) {
      try {
        final club = await ClubService.getClub(event.clubId!);
        if (club == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.calendarClubNotFound)),
          );
          return;
        }

        final clubEvent = await EventService.getEvent(event.clubId!, event.clubEventId!);
        if (clubEvent == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.calendarEventNotFound)),
          );
          return;
        }

        final isAdmin = await ClubService.canManageEvents(event.clubId!);
        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => club_detail.EventDetailScreen(
              club: club,
              event: clubEvent,
              isAdmin: isAdmin,
            ),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.calendarFailedToLoadEvent(e.toString()))),
        );
      }
      return;
    }

    // Local events -> new event detail screen
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(
          title: event.title,
          type: event.type,
          location: event.location,
          date: event.date,
          buyIn: event.buyIn,
          onDelete: () => _performDeleteEvent(event),
          onEdit: (updateDetail) {
            _showEditEventDialogFromDetail(event, updateDetail);
          },
        ),
      ),
    );

    // Reload events when returning (covers both delete and edit cases)
    _loadEvents();
  }

  void _showEditEventDialog(PokerEvent event) {
    final l10n = AppLocalizations.of(context);
    final titleController = TextEditingController(text: event.title);
    final locationController = TextEditingController(text: event.location);
    final buyInController = TextEditingController(
      text: event.buyIn > 0 ? event.buyIn.toStringAsFixed(0) : '',
    );
    TimeOfDay dialogSelectedTime = TimeOfDay.fromDateTime(event.date);
    DateTime dialogSelectedDate = event.date;
    String selectedType = event.type;
    final eventTypeKey = GlobalKey();

    FormDrawer.show(
      context: context,
      title: l10n.calendarEditEvent,
      onSave: () async {
        final eventDate = DateTime(
          dialogSelectedDate.year,
          dialogSelectedDate.month,
          dialogSelectedDate.day,
          dialogSelectedTime.hour,
          dialogSelectedTime.minute,
        );

        try {
          await CalendarEventService.updateEvent(
            eventId: event.id,
            title: titleController.text.isEmpty ? selectedType : titleController.text,
            type: selectedType,
            location: locationController.text,
            date: eventDate,
            buyIn: double.tryParse(buyInController.text) ?? 0.0,
          );

          Navigator.pop(context);
          _loadEvents();
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.calendarFailedToUpdateEvent(e.toString()))),
          );
        }
      },
      body: StatefulBuilder(
        builder: (context, setSheetState) {
          return _buildEventFormContent(
            context: context,
            setSheetState: setSheetState,
            titleController: titleController,
            locationController: locationController,
            buyInController: buyInController,
            dialogSelectedDate: dialogSelectedDate,
            dialogSelectedTime: dialogSelectedTime,
            selectedType: selectedType,
            eventTypeKey: eventTypeKey,
            onDateChanged: (date) {
              setSheetState(() { dialogSelectedDate = date; });
            },
            onTimeChanged: (time) {
              setSheetState(() { dialogSelectedTime = time; });
            },
            onTypeChanged: (type) {
              setSheetState(() { selectedType = type; });
            },
          );
        },
      ),
    );
  }

  /// Edit event from the detail screen — updates detail screen in-place after save
  void _showEditEventDialogFromDetail(
    PokerEvent event,
    void Function({
      required String title,
      required String type,
      required String location,
      required DateTime date,
      required double buyIn,
    }) updateDetail,
  ) {
    final l10n = AppLocalizations.of(context);
    final titleController = TextEditingController(text: event.title);
    final locationController = TextEditingController(text: event.location);
    final buyInController = TextEditingController(
      text: event.buyIn > 0 ? event.buyIn.toStringAsFixed(0) : '',
    );
    TimeOfDay dialogSelectedTime = TimeOfDay.fromDateTime(event.date);
    DateTime dialogSelectedDate = event.date;
    String selectedType = event.type;
    final eventTypeKey = GlobalKey();

    FormDrawer.show(
      context: context,
      title: l10n.calendarEditEvent,
      onSave: () async {
        final eventDate = DateTime(
          dialogSelectedDate.year,
          dialogSelectedDate.month,
          dialogSelectedDate.day,
          dialogSelectedTime.hour,
          dialogSelectedTime.minute,
        );
        final newTitle = titleController.text.isEmpty ? selectedType : titleController.text;
        final newBuyIn = double.tryParse(buyInController.text) ?? 0.0;

        try {
          await CalendarEventService.updateEvent(
            eventId: event.id,
            title: newTitle,
            type: selectedType,
            location: locationController.text,
            date: eventDate,
            buyIn: newBuyIn,
          );

          Navigator.pop(context);
          updateDetail(
            title: newTitle,
            type: selectedType,
            location: locationController.text,
            date: eventDate,
            buyIn: newBuyIn,
          );
          _loadEvents();
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.calendarFailedToUpdateEvent(e.toString()))),
          );
        }
      },
      body: StatefulBuilder(
        builder: (context, setSheetState) {
          return _buildEventFormContent(
            context: context,
            setSheetState: setSheetState,
            titleController: titleController,
            locationController: locationController,
            buyInController: buyInController,
            dialogSelectedDate: dialogSelectedDate,
            dialogSelectedTime: dialogSelectedTime,
            selectedType: selectedType,
            eventTypeKey: eventTypeKey,
            onDateChanged: (date) {
              setSheetState(() { dialogSelectedDate = date; });
            },
            onTimeChanged: (time) {
              setSheetState(() { dialogSelectedTime = time; });
            },
            onTypeChanged: (type) {
              setSheetState(() { selectedType = type; });
            },
          );
        },
      ),
    );
  }

  /// Delete with confirmation (used from tooltip menu)
  Future<void> _deleteEvent(PokerEvent event) async {
    final confirmed = await _showDeleteConfirmation(event.title);
    if (confirmed != true) return;
    await _performDeleteEvent(event);
  }

  /// Actual deletion (no confirmation)
  Future<void> _performDeleteEvent(PokerEvent event) async {
    try {
      await CalendarEventService.deleteEvent(event.id);
      setState(() {
        events.removeWhere((e) => e.id == event.id);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).calendarFailedToDeleteEvent)),
        );
      }
    }
  }

  Future<bool?> _showDeleteConfirmation(String eventTitle) {
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main card with title, description, and delete button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF101115),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    // Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        l10n.calendarDeleteConfirmTitle(eventTitle),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Description
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        l10n.calendarDeleteConfirmMessage(eventTitle),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Delete button
                    GestureDetector(
                      onTap: () => Navigator.pop(context, true),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                        child: Text(
                          l10n.commonDelete,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFDA5B5E),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Cancel button (separate card)
              GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF101115),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Center(
                    child: Text(
                      l10n.commonCancel,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getEventTypeColor(String type) {
    switch (type) {
      case 'Tournament':
        return Color(0xFF5B9CDF);
      case 'Cash Game':
        return Color(0xFF5AC95A);
      case 'Home Game':
      case 'Private Game':
        return Color(0xFFE67E22);
      case 'Online':
        return Color(0xFF8B5CF6);
      default:
        return Color(0xFF9A9A9A);
    }
  }
}

class PokerEvent {
  final String id;
  final String title;
  final String type;
  final String location;
  final DateTime date;
  final double buyIn;
  final String? clubId;
  final String? clubEventId;

  PokerEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.location,
    required this.date,
    required this.buyIn,
    this.clubId,
    this.clubEventId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'location': location,
      'date': date.toIso8601String(),
      'buyIn': buyIn,
      'clubId': clubId,
      'clubEventId': clubEventId,
    };
  }

  static PokerEvent fromJson(Map<String, dynamic> json) {
    return PokerEvent(
      id: json['id'],
      title: json['title'],
      type: json['type'],
      location: json['location'],
      date: DateTime.parse(json['date']),
      buyIn: json['buyIn'].toDouble(),
      clubId: json['clubId'],
      clubEventId: json['clubEventId'],
    );
  }
}