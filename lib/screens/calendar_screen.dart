import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../services/calendar_event_service.dart';
import '../services/notification_service.dart';
import '../services/club_service.dart';
import '../services/event_service.dart';
import '../models/club.dart';
import '../models/club_event.dart';
import '../design_system/design_system.dart';
import '../widgets/global_bottom_nav_bar.dart';
import '../widgets/event_success_popup.dart';
import 'club/event_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime selectedDate = DateTime.now();
  DateTime currentMonth = DateTime.now();
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
    TimeOfDay selectedTime = TimeOfDay.now();
    DateTime dialogSelectedDate = selectedDate;
    String selectedType = 'Tournament';

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.transparent,
      transitionDuration: Duration(milliseconds: 200),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
            ),
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
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
            // Dialog content
            Center(
              child: StatefulBuilder(
                builder: (context, setDialogState) => Material(
                  color: Colors.transparent,
                  child: Container(
                    margin: EdgeInsets.all(16),
                    width: 361,
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.85,
                    ),
                    decoration: BoxDecoration(
                      color: Color(0xFF000300),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: EdgeInsets.fromLTRB(24, 32, 24, 32),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      // Title
                      Text(
                        'Add Poker Event',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 32),
                      // Event Type Selector
                      Container(
                        width: double.infinity,
                        height: 48,
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: Color(0x0AFFFFFF),
                          border: Border.all(color: Color(0xFF13321B)),
                          borderRadius: BorderRadius.circular(58),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedType,
                            dropdownColor: Color(0xFF000300),
                            icon: Icon(Icons.keyboard_arrow_down, color: Color(0x99EBFFEF), size: 18),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: Color(0x99EBFFEF),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              height: 1.2,
                            ),
                            items: ['Tournament', 'Cash Game', 'Home Game', 'Online']
                                .map((type) => DropdownMenuItem(
                                      value: type,
                                      child: Text(type),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedType = value!;
                              });
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Event Name Field
                      TextField(
                        controller: titleController,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Color(0x99EBFFEF),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Event Name (Optional)',
                          hintStyle: TextStyle(
                            fontFamily: 'Inter',
                            color: Color(0x99EBFFEF),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(58),
                            borderSide: BorderSide(color: Color(0xFF13321B)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(58),
                            borderSide: BorderSide(color: Color(0xFF13321B)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(58),
                            borderSide: BorderSide(color: Color(0xFF13321B)),
                          ),
                          filled: true,
                          fillColor: Color(0x0AFFFFFF),
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Location/Venue Field
                      TextField(
                        controller: locationController,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Color(0x99EBFFEF),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Location/Venue',
                          hintStyle: TextStyle(
                            fontFamily: 'Inter',
                            color: Color(0x99EBFFEF),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(58),
                            borderSide: BorderSide(color: Color(0xFF13321B)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(58),
                            borderSide: BorderSide(color: Color(0xFF13321B)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(58),
                            borderSide: BorderSide(color: Color(0xFF13321B)),
                          ),
                          filled: true,
                          fillColor: Color(0x0AFFFFFF),
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Buy-in Field
                      TextField(
                        controller: buyInController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Color(0x99EBFFEF),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Buy in amount',
                          hintStyle: TextStyle(
                            fontFamily: 'Inter',
                            color: Color(0x99EBFFEF),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(58),
                            borderSide: BorderSide(color: Color(0xFF13321B)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(58),
                            borderSide: BorderSide(color: Color(0xFF13321B)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(58),
                            borderSide: BorderSide(color: Color(0xFF13321B)),
                          ),
                          filled: true,
                          fillColor: Color(0x0AFFFFFF),
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Date Picker
                      GestureDetector(
                        onTap: () async {
                          final date = await _showCustomDatePicker(
                            context,
                            dialogSelectedDate,
                          );
                          if (date != null) {
                            setDialogState(() {
                              dialogSelectedDate = date;
                            });
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          height: 48,
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            color: Color(0xFF181D1B),
                            border: Border.all(color: Colors.transparent),
                            borderRadius: BorderRadius.circular(58),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: Color(0x99EBFFEF), size: 20),
                              SizedBox(width: 8),
                              Text(
                                DateFormat('MMM dd, yyyy').format(dialogSelectedDate),
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: Color(0x99EBFFEF),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              Spacer(),
                              Icon(Icons.keyboard_arrow_down, color: Color(0x99EBFFEF), size: 18),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Time Picker
                      GestureDetector(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.dark(
                                    primary: Color(0xFF5AC95A),
                                    surface: Color(0xFF000300),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (time != null) {
                            setDialogState(() {
                              selectedTime = time;
                            });
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          height: 48,
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            color: Color(0x0AFFFFFF),
                            border: Border.all(color: Color(0xFF13321B)),
                            borderRadius: BorderRadius.circular(58),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time, color: Color(0x99EBFFEF), size: 20),
                              SizedBox(width: 8),
                              Text(
                                selectedTime.format(context),
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: Color(0x99EBFFEF),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              Spacer(),
                              Icon(Icons.keyboard_arrow_down, color: Color(0x99EBFFEF), size: 18),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 32),
                      // Buttons
                      Row(
                        children: [
                          // Cancel Button
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.fromLTRB(32, 12, 8, 12),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                          // Add Event Button
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (titleController.text.isEmpty && locationController.text.isEmpty) {
                                  return;
                                }
                                final eventDate = DateTime(
                                  dialogSelectedDate.year,
                                  dialogSelectedDate.month,
                                  dialogSelectedDate.day,
                                  selectedTime.hour,
                                  selectedTime.minute,
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

                                  Navigator.pop(context); // Close add event dialog

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
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFBAFF9A),
                                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                'Add Event',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  height: 1.5,
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
                                  style: TextStyle(
                                    fontFamily: 'Inter',
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
                                          style: TextStyle(
                                            fontFamily: 'Inter',
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
                                          style: TextStyle(
                                            fontFamily: 'Inter',
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
                                            style: TextStyle(
                                              fontFamily: 'Inter',
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
                                          style: TextStyle(
                                            fontFamily: 'Inter',
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
                                                      style: TextStyle(
                                                        fontFamily: 'Inter',
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
                                            style: TextStyle(
                                              fontFamily: 'Inter',
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
                                            style: TextStyle(
                                              fontFamily: 'Inter',
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
                                        style: TextStyle(
                                          fontFamily: 'Inter',
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
                                          style: TextStyle(
                                            fontFamily: 'Inter',
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GradientBackground(),
          SafeArea(
            child: Column(
              children: [
                // Header
                MainScreenHeader(
                  title: 'Poker Calendar',
                  showLeftIcon: true,
                  leftIcon: Icons.arrow_back_rounded,
                  onLeftPressed: () => Navigator.pop(context),
                  rightIcon: Icons.add_rounded,
                  onRightPressed: _showAddEventDialog,
                ),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
            SizedBox(height: 24),

            // Date Selector
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 19),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // "Select date:" label
                  Text(
                    'Select date:',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Color(0xFFEBEBEB),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.14,
                    ),
                  ),

                  // Year and Month selectors
                  Row(
                    children: [
                      // Year selector
                      GestureDetector(
                        onTap: () async {
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
                        child: Container(
                          decoration: BoxDecoration(
                            color: Color(0x2EFFFFFF),
                            borderRadius: BorderRadius.circular(48),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${currentMonth.year}',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: Color(0xFFFAFAFA),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.keyboard_arrow_down, color: Color(0xFFFAFAFA), size: 16),
                            ],
                          ),
                        ),
                      ),

                      // Month navigation
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.chevron_left, color: Color(0xFFFAFAFA), size: 16),
                            onPressed: () {
                              setState(() {
                                currentMonth = DateTime(
                                  currentMonth.year,
                                  currentMonth.month - 1,
                                );
                              });
                            },
                            padding: EdgeInsets.all(8),
                            constraints: BoxConstraints(),
                          ),
                          Text(
                            DateFormat('MMMM').format(currentMonth),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: Color(0xFFFAFAFA),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.chevron_right, color: Color(0xFFFAFAFA), size: 16),
                            onPressed: () {
                              setState(() {
                                currentMonth = DateTime(
                                  currentMonth.year,
                                  currentMonth.month + 1,
                                );
                              });
                            },
                            padding: EdgeInsets.all(8),
                            constraints: BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Calendar Grid
            _buildCalendarGrid(),

            SizedBox(height: 32),

            // Add New Event Button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: _showAddEventDialog,
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Color(0xFFBAFF9A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  child: Center(
                    child: Text(
                      'Add New Event',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: 16),

            // Events for selected date
            _buildEventsForSelectedDate(),

            SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            ],
          ),
        ),
        ],
      ),
      bottomNavigationBar: GlobalBottomNavBar(currentScreen: 'calendar'),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
    final lastDayOfMonth = DateTime(currentMonth.year, currentMonth.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final startingDayOfWeek = firstDayOfMonth.weekday % 7;

    return Column(
      children: [
        // Weekday headers
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Color(0xFF191E1A),
              borderRadius: BorderRadius.circular(50),
            ),
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                  .map((day) => Expanded(
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 5.1),
                          child: Text(
                            day,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: Color(0xFFEBEBEB),
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
        SizedBox(height: 18),
        
        // Calendar days
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: List.generate(6, (rowIndex) {
              return Padding(
                padding: EdgeInsets.only(bottom: rowIndex < 5 ? 20 : 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (colIndex) {
                    final index = rowIndex * 7 + colIndex;

                    // Show previous month days
                    if (index < startingDayOfWeek) {
                      final prevMonth = DateTime(currentMonth.year, currentMonth.month - 1);
                      final daysInPrevMonth = DateTime(prevMonth.year, prevMonth.month + 1, 0).day;
                      final prevMonthDay = daysInPrevMonth - (startingDayOfWeek - index - 1);

                      return Container(
                        width: 30.62,
                        height: 30.62,
                        child: Center(
                          child: Text(
                            prevMonthDay.toString(),
                            style: TextStyle(
                              fontFamily: 'Roboto Mono',
                              color: Color(0x66EBEBEB), // Grayed out
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }

                    final dayNumber = index - startingDayOfWeek + 1;

                    if (dayNumber > daysInMonth) {
                      return Container(width: 30.62, height: 30.62);
                    }

                    final date = DateTime(currentMonth.year, currentMonth.month, dayNumber);
                    final isSelected = selectedDate.year == date.year &&
                        selectedDate.month == date.month &&
                        selectedDate.day == date.day;
                    final isToday = DateTime.now().year == date.year &&
                        DateTime.now().month == date.month &&
                        DateTime.now().day == date.day;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedDate = date;
                        });
                      },
                      child: Container(
                        width: 30.62,
                        height: 30.62,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Color(0xFFB6FF99)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(51.04),
                        ),
                        child: Center(
                          child: Text(
                            dayNumber.toString(),
                            style: TextStyle(
                              fontFamily: 'Roboto Mono',
                              color: isSelected ? Colors.black : Color(0xFFEBEBEB),
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildEventsForSelectedDate() {
    final eventsForDate = _getEventsForDate(selectedDate);

    if (eventsForDate.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Events on ${DateFormat('MMM d, yyyy').format(selectedDate)}',
              style: TextStyle(
                fontFamily: 'Inter',
                color: Color(0xFFEBEBEB),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF191E1A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'No events scheduled',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFF9A9A9A),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Events on ${DateFormat('MMM d, yyyy').format(selectedDate)}',
            style: TextStyle(
              fontFamily: 'Inter',
              color: Color(0xFFEBEBEB),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 12),
          ...eventsForDate.map((event) => _buildEventCard(event)).toList(),
        ],
      ),
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
              style: TextStyle(
                fontFamily: 'Inter',
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
                          style: TextStyle(
                            fontFamily: 'Inter',
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
    return GestureDetector(
      onTap: () => _navigateToEventDetail(event),
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFF1F1F23),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: _getEventTypeColor(event.type),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (event.location.isNotEmpty)
                    Text(
                      event.location,
                      style: TextStyle(
                        color: Color(0xFF9A9A9A),
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  DateFormat('HH:mm').format(event.date),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (event.buyIn > 0)
                  Text(
                    '\$${event.buyIn.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: Color(0xFF5AC95A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            // Show arrow if it's a club event
            if (event.clubId != null && event.clubEventId != null) ...[
              SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Color(0xFF9A9A9A),
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToEventDetail(PokerEvent event) async {
    // Only navigate if this is a club event
    if (event.clubId == null || event.clubEventId == null) {
      return;
    }

    try {
      // Fetch the club and event data
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

      // Check if user is admin
      final isAdmin = await ClubService.canManageEvents(event.clubId!);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EventDetailScreen(
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
  }

  Color _getEventTypeColor(String type) {
    switch (type) {
      case 'Tournament':
        return Color(0xFF5B9CDF);
      case 'Cash Game':
        return Color(0xFF5AC95A);
      case 'Home Game':
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