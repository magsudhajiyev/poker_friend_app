import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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
    final outerContext = context; // Capture outer context for success popup
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    final buyInController = TextEditingController();
    TimeOfDay dialogSelectedTime = TimeOfDay.now();
    DateTime dialogSelectedDate = selectedDate;
    String selectedType = 'Tournament';
    final eventTypeKey = GlobalKey();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                border: Border.all(color: const Color(0xFF262626), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E5A59),
                    blurRadius: 64,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Header - Overlay Header style
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 15, 16, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Close button
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF35373C),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                            // Title
                            Text(
                              'New Event',
                              style: GoogleFonts.ibmPlexSans(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.43,
                              ),
                            ),
                            // Confirm button
                            GestureDetector(
                              onTap: () async {
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
                                  // Save to Firebase
                                  final eventId = await CalendarEventService.createEvent(
                                    title: titleController.text.isEmpty ? selectedType : titleController.text,
                                    type: selectedType,
                                    location: locationController.text,
                                    date: eventDate,
                                    buyIn: double.tryParse(buyInController.text) ?? 0.0,
                                  );

                                  // Add to local list with Firebase ID
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

                                  Navigator.pop(context); // Close bottom sheet

                                  // Show success popup
                                  if (!mounted) return;
                                  final action = await EventSuccessPopup.show(outerContext);

                                  if (action == 'add_another' && mounted) {
                                    _showAddEventDialog();
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to create event: $e')),
                                  );
                                }
                              },
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF54E98A),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.check,
                                    color: Colors.black,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
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
                                    setSheetState(() {
                                      selectedType = type;
                                    });
                                  }, eventTypeKey);
                                },
                                child: Container(
                                  key: eventTypeKey,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Event Type',
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
                                  hintText: 'Title',
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
                                  hintText: 'Location',
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
                                  hintText: 'Buy-in amount',
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
                              // Header
                              Text(
                                'Event Date and Time',
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
                              // Starts Row
                              Row(
                                children: [
                                  Text(
                                    'Starts',
                                    style: GoogleFonts.ibmPlexSans(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w400,
                                      height: 1.44,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Date Pill
                                  GestureDetector(
                                    onTap: () async {
                                      final date = await _showCustomDatePicker(
                                        context,
                                        dialogSelectedDate,
                                      );
                                      if (date != null) {
                                        setSheetState(() {
                                          dialogSelectedDate = date;
                                        });
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
                                  // Time Pill
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
                                        setSheetState(() {
                                          dialogSelectedTime = time;
                                        });
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
                      // Safe area bottom padding
                      SizedBox(height: MediaQuery.of(context).padding.bottom),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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

  Future<DateTime?> _showCustomDatePicker(BuildContext context, DateTime initialDate) async {
    DateTime displayMonth = DateTime(initialDate.year, initialDate.month);
    DateTime? selectedDate = initialDate;

    return await showGeneralDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.transparent,
      transitionDuration: Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setPickerState) {
            // Calculate calendar data
            final daysInMonth = DateTime(displayMonth.year, displayMonth.month + 1, 0).day;
            final firstDayOfMonth = DateTime(displayMonth.year, displayMonth.month, 1);
            final startingWeekday = firstDayOfMonth.weekday % 7; // 0 = Sunday

            return Stack(
              children: [
                // Blurred backdrop
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                      child: Container(
                        color: Colors.black.withOpacity(0.0),
                      ),
                    ),
                  ),
                ),
                // Date picker content
                Center(
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: 312,
                      margin: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Color(0xFF000300),
                        border: Border.all(color: Color(0x4CFFFFFF)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.all(8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Padding(
                            padding: EdgeInsets.all(8),
                            child: Row(
                              children: [
                                Text(
                                  'Select date:',
                                  style: GoogleFonts.ibmPlexSans(
                                    color: Color(0xFFBDBDBD),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Spacer(),
                                // Clear button
                                GestureDetector(
                                  onTap: () {
                                    setPickerState(() {
                                      selectedDate = DateTime.now();
                                      displayMonth = DateTime(selectedDate!.year, selectedDate!.month);
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.close, color: Color(0xFFD55A41), size: 12),
                                        SizedBox(width: 4),
                                        Text(
                                          'Clear',
                                          style: GoogleFonts.ibmPlexSans(
                                            color: Color(0xFFD55A41),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                // Today button
                                GestureDetector(
                                  onTap: () {
                                    final today = DateTime.now();
                                    setPickerState(() {
                                      selectedDate = DateTime(today.year, today.month, today.day);
                                      displayMonth = DateTime(today.year, today.month);
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Color(0xFFFFFFFF).withOpacity(0.3)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.today, color: Color(0xFFFAFAFA), size: 12),
                                        SizedBox(width: 4),
                                        Text(
                                          'Today',
                                          style: GoogleFonts.ibmPlexSans(
                                            color: Color(0xFFFAFAFA),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                // Close button
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Icon(Icons.close, color: Color(0xFFFAFAFA), size: 16),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 4),

                          // Calendar body
                          Container(
                            width: 296,
                            decoration: BoxDecoration(
                              color: Color(0xFF171C19),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.all(8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Year/Month selector
                                SizedBox(
                                  width: 280,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                    // Year button
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${displayMonth.year}',
                                            style: GoogleFonts.ibmPlexSans(
                                              color: Color(0xFFFAFAFA),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          SizedBox(width: 4),
                                          Icon(Icons.keyboard_arrow_down, color: Color(0xFFFAFAFA), size: 16),
                                        ],
                                      ),
                                    ),
                                    // Month navigation
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.chevron_left, color: Color(0xFFFAFAFA), size: 16),
                                          onPressed: () {
                                            setPickerState(() {
                                              displayMonth = DateTime(displayMonth.year, displayMonth.month - 1);
                                            });
                                          },
                                          padding: EdgeInsets.all(8),
                                          constraints: BoxConstraints(),
                                        ),
                                        Text(
                                          DateFormat('MMMM').format(displayMonth),
                                          style: GoogleFonts.ibmPlexSans(
                                            color: Color(0xFFFAFAFA),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.chevron_right, color: Color(0xFFFAFAFA), size: 16),
                                          onPressed: () {
                                            setPickerState(() {
                                              displayMonth = DateTime(displayMonth.year, displayMonth.month + 1);
                                            });
                                          },
                                          padding: EdgeInsets.all(8),
                                          constraints: BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ],
                                  ),
                                ),

                                SizedBox(height: 2),

                                // Week day labels
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Color(0xFF191F1B),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                                          .map((day) => Expanded(
                                                child: Container(
                                                  height: 24,
                                                  decoration: BoxDecoration(
                                                    color: Color(0x0DFFFFFF),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      day,
                                                      style: GoogleFonts.ibmPlexSans(
                                                        color: Color(0xFFBDBDBD),
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w400,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                  ),
                                ),

                                SizedBox(height: 2),

                                // Calendar grid
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 7,
                                    childAspectRatio: 1.0,
                                    crossAxisSpacing: 0,
                                    mainAxisSpacing: 0,
                                  ),
                                  itemCount: 42,
                                  itemBuilder: (context, index) {
                                    // Show previous month days
                                    if (index < startingWeekday) {
                                      final prevMonth = DateTime(displayMonth.year, displayMonth.month - 1);
                                      final daysInPrevMonth = DateTime(prevMonth.year, prevMonth.month + 1, 0).day;
                                      final prevMonthDay = daysInPrevMonth - (startingWeekday - index - 1);

                                      return Container(
                                        child: Center(
                                          child: Text(
                                            prevMonthDay.toString(),
                                            style: GoogleFonts.ibmPlexSans(
                                              color: Color(0x66FAFAFA), // Grayed out
                                              fontSize: 12,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    final dayNumber = index - startingWeekday + 1;
                                    if (dayNumber > daysInMonth) {
                                      return Container(); // Empty cell
                                    }

                                    final date = DateTime(displayMonth.year, displayMonth.month, dayNumber);
                                    final isSelected = selectedDate != null &&
                                        selectedDate!.year == date.year &&
                                        selectedDate!.month == date.month &&
                                        selectedDate!.day == date.day;
                                    final isToday = DateTime.now().year == date.year &&
                                        DateTime.now().month == date.month &&
                                        DateTime.now().day == date.day;

                                    return GestureDetector(
                                      onTap: () {
                                        setPickerState(() {
                                          selectedDate = date;
                                        });
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Color(0xFF5AC95A)
                                              : (isToday ? Color(0xFF2A2A2E) : Colors.transparent),
                                          borderRadius: BorderRadius.circular(8),
                                          border: isToday && !isSelected
                                              ? Border.all(color: Color(0xFF5AC95A), width: 1)
                                              : null,
                                        ),
                                        child: Center(
                                          child: Text(
                                            dayNumber.toString(),
                                            style: GoogleFonts.ibmPlexSans(
                                              color: isSelected ? Colors.black : Color(0xFFFAFAFA),
                                              fontSize: 12,
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 8),

                          // Footer buttons
                          Padding(
                            padding: EdgeInsets.all(8),
                            child: Row(
                              children: [
                                // Cancel button
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    width: 88,
                                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Color(0xFFFFFFFF).withOpacity(0.3)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Cancel',
                                        style: GoogleFonts.ibmPlexSans(
                                          color: Color(0xFFFAFAFA),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                // Done button
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => Navigator.pop(context, selectedDate),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Color(0xFFBAFF9A),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Done',
                                          style: GoogleFonts.ibmPlexSans(
                                            color: Colors.black,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
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
      },
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
                title: 'Poker Calendar',
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
                'No recent events',
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
                'Add your first poker event!',
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
                        'Add New Event',
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
              'Select Year',
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
                          '\$ ${event.buyIn.toStringAsFixed(0)}',
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
                                  'Edit Event',
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
                                  'Delete Event',
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
    // Club events -> club detail screen
    if (event.clubId != null && event.clubEventId != null) {
      try {
        final club = await ClubService.getClub(event.clubId!);
        if (club == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Club not found')),
          );
          return;
        }

        final clubEvent = await EventService.getEvent(event.clubId!, event.clubEventId!);
        if (clubEvent == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event not found')),
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
          SnackBar(content: Text('Failed to load event: $e')),
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
    final titleController = TextEditingController(text: event.title);
    final locationController = TextEditingController(text: event.location);
    final buyInController = TextEditingController(
      text: event.buyIn > 0 ? event.buyIn.toStringAsFixed(0) : '',
    );
    TimeOfDay dialogSelectedTime = TimeOfDay.fromDateTime(event.date);
    DateTime dialogSelectedDate = event.date;
    String selectedType = event.type;
    final eventTypeKey = GlobalKey();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                border: Border.all(color: const Color(0xFF262626), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E5A59),
                    blurRadius: 64,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 15, 16, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Close button
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF35373C),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                            // Title
                            Text(
                              'Edit Event',
                              style: GoogleFonts.ibmPlexSans(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.43,
                              ),
                            ),
                            // Confirm button
                            GestureDetector(
                              onTap: () async {
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
                                  _loadEvents(); // Reload to reflect changes
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to update event: $e')),
                                  );
                                }
                              },
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF54E98A),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.check,
                                    color: Colors.black,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
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
                                    setSheetState(() {
                                      selectedType = type;
                                    });
                                  }, eventTypeKey);
                                },
                                child: Container(
                                  key: eventTypeKey,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Event Type',
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
                                  hintText: 'Title',
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
                                  hintText: 'Location',
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
                                  hintText: 'Buy-in amount',
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
                                'Event Date and Time',
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
                                    'Starts',
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
                                        setSheetState(() {
                                          dialogSelectedDate = date;
                                        });
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
                                        setSheetState(() {
                                          dialogSelectedTime = time;
                                        });
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
                  ),
                ),
              ),
            );
          },
        );
      },
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
    final titleController = TextEditingController(text: event.title);
    final locationController = TextEditingController(text: event.location);
    final buyInController = TextEditingController(
      text: event.buyIn > 0 ? event.buyIn.toStringAsFixed(0) : '',
    );
    TimeOfDay dialogSelectedTime = TimeOfDay.fromDateTime(event.date);
    DateTime dialogSelectedDate = event.date;
    String selectedType = event.type;
    final eventTypeKey = GlobalKey();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                border: Border.all(color: const Color(0xFF262626), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E5A59),
                    blurRadius: 64,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 15, 16, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Close button
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF35373C),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                            // Title
                            Text(
                              'Edit Event',
                              style: GoogleFonts.ibmPlexSans(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.43,
                              ),
                            ),
                            // Confirm button
                            GestureDetector(
                              onTap: () async {
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
                                  // Update the detail screen in-place
                                  updateDetail(
                                    title: newTitle,
                                    type: selectedType,
                                    location: locationController.text,
                                    date: eventDate,
                                    buyIn: newBuyIn,
                                  );
                                  // Also update local event list
                                  _loadEvents();
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to update event: $e')),
                                  );
                                }
                              },
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF54E98A),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.check,
                                    color: Colors.black,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
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
                                    setSheetState(() {
                                      selectedType = type;
                                    });
                                  }, eventTypeKey);
                                },
                                child: Container(
                                  key: eventTypeKey,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Event Type',
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
                                  hintText: 'Title',
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
                                  hintText: 'Location',
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
                                  hintText: 'Buy-in amount',
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
                                'Event Date and Time',
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
                                    'Starts',
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
                                        setSheetState(() {
                                          dialogSelectedDate = date;
                                        });
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1B1E24),
                                        borderRadius: BorderRadius.circular(40),
                                      ),
                                      child: Text(
                                        DateFormat('dd/MM/yyyy').format(dialogSelectedDate),
                                        style: GoogleFonts.ibmPlexSans(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () async {
                                      final time = await showTimePicker(
                                        context: context,
                                        initialTime: dialogSelectedTime,
                                        builder: (context, child) {
                                          return Theme(
                                            data: Theme.of(context).copyWith(
                                              timePickerTheme: TimePickerThemeData(
                                                backgroundColor: const Color(0xFF101115),
                                                hourMinuteTextColor: Colors.white,
                                                dialHandColor: const Color(0xFF54E98A),
                                                dialBackgroundColor: const Color(0xFF1B1E24),
                                                dialTextColor: Colors.white,
                                                entryModeIconColor: Colors.white,
                                                helpTextStyle: GoogleFonts.ibmPlexSans(
                                                  color: Colors.white,
                                                ),
                                              ),
                                              textButtonTheme: TextButtonThemeData(
                                                style: TextButton.styleFrom(
                                                  foregroundColor: const Color(0xFF54E98A),
                                                ),
                                              ),
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );
                                      if (time != null) {
                                        setSheetState(() {
                                          dialogSelectedTime = time;
                                        });
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
                  ),
                ),
              ),
            );
          },
        );
      },
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
          const SnackBar(content: Text('Failed to delete event')),
        );
      }
    }
  }

  Future<bool?> _showDeleteConfirmation(String eventTitle) {
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
                        'Delete $eventTitle?',
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
                        'Are you sure you want to delete "$eventTitle"?\nThis action cannot be undone.',
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
                          'Delete',
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
                      'Cancel',
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