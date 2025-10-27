import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/calendar_event_service.dart';

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
      print('Error loading events: $e');
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
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    final buyInController = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();
    String selectedType = 'Tournament';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Color(0xFF1F1F23),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Add Poker Event',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Container(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                // Event Type Selector
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFF2A2A2E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedType,
                      dropdownColor: Color(0xFF2A2A2E),
                      style: TextStyle(color: Colors.white, fontSize: 16),
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
                
                // Title Field
                TextField(
                  controller: titleController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Event title',
                    hintStyle: TextStyle(color: Color(0xFF9A9A9A)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF2A2A2E)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF2A2A2E)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF5AC95A)),
                    ),
                    filled: true,
                    fillColor: Color(0xFF2A2A2E),
                  ),
                ),
                SizedBox(height: 16),
                
                // Location Field
                TextField(
                  controller: locationController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Location/Venue',
                    hintStyle: TextStyle(color: Color(0xFF9A9A9A)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF2A2A2E)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF2A2A2E)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF5AC95A)),
                    ),
                    filled: true,
                    fillColor: Color(0xFF2A2A2E),
                  ),
                ),
                SizedBox(height: 16),
                
                // Buy-in Field
                TextField(
                  controller: buyInController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Buy-in amount',
                    hintStyle: TextStyle(color: Color(0xFF9A9A9A)),
                    prefixText: '\$ ',
                    prefixStyle: TextStyle(color: Color(0xFF5AC95A)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF2A2A2E)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF2A2A2E)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF5AC95A)),
                    ),
                    filled: true,
                    fillColor: Color(0xFF2A2A2E),
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
                              surface: Color(0xFF1F1F23),
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
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF2A2A2E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, color: Color(0xFF5AC95A)),
                        SizedBox(width: 12),
                        Text(
                          selectedTime.format(context),
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        Spacer(),
                        Icon(Icons.arrow_drop_down, color: Color(0xFF9A9A9A)),
                      ],
                    ),
                  ),
                ),
              ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF9A9A9A)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty) {
                  final eventDate = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );

                  try {
                    // Save to Firebase
                    final eventId = await CalendarEventService.createEvent(
                      title: titleController.text,
                      type: selectedType,
                      location: locationController.text,
                      date: eventDate,
                      buyIn: double.tryParse(buyInController.text) ?? 0.0,
                    );

                    // Add to local list with Firebase ID
                    final newEvent = PokerEvent(
                      id: eventId,
                      title: titleController.text,
                      type: selectedType,
                      location: locationController.text,
                      date: eventDate,
                      buyIn: double.tryParse(buyInController.text) ?? 0.0,
                    );

                    setState(() {
                      events.add(newEvent);
                    });

                    Navigator.pop(context);
                  } catch (e) {
                    print('Error creating event: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to create event: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF5AC95A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Add Event',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF161618),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  SizedBox(width: 16),
                  Text(
                    'Poker Calendar',
                    style: TextStyle(
                      fontSize: 32,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Color(0xFF5AC95A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    onPressed: _showAddEventDialog,
                  ),
                ],
              ),
            ),
            
            // Calendar Month Navigation
            Padding(
              padding: EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left, color: Colors.white, size: 28),
                    onPressed: () {
                      setState(() {
                        currentMonth = DateTime(
                          currentMonth.year,
                          currentMonth.month - 1,
                        );
                      });
                    },
                  ),
                  Text(
                    DateFormat('MMMM yyyy').format(currentMonth),
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right, color: Colors.white, size: 28),
                    onPressed: () {
                      setState(() {
                        currentMonth = DateTime(
                          currentMonth.year,
                          currentMonth.month + 1,
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
            
            // Calendar Grid
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 24),
                child: _buildCalendarGrid(),
              ),
            ),
            
            // Events List for Selected Date
            if (_getEventsForDate(selectedDate).isNotEmpty)
              Container(
                height: 200,
                margin: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Events for ${DateFormat('MMM dd').format(selectedDate)}',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _getEventsForDate(selectedDate).length,
                        itemBuilder: (context, index) {
                          final event = _getEventsForDate(selectedDate)[index];
                          return _buildEventCard(event);
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
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
        Container(
          child: Row(
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: TextStyle(
                            color: Color(0xFF9A9A9A),
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        SizedBox(height: 16),
        
        // Calendar days
        Expanded(
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: 42, // 6 rows × 7 days
            itemBuilder: (context, index) {
              final dayNumber = index - startingDayOfWeek + 1;
              
              if (index < startingDayOfWeek || dayNumber > daysInMonth) {
                return Container(); // Empty cell
              }
              
              final date = DateTime(currentMonth.year, currentMonth.month, dayNumber);
              final isSelected = selectedDate.year == date.year &&
                  selectedDate.month == date.month &&
                  selectedDate.day == date.day;
              final hasEvents = _getEventsForDate(date).isNotEmpty;
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
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Color(0xFF5AC95A)
                        : (isToday ? Color(0xFF2A2A2E) : Colors.transparent),
                    borderRadius: BorderRadius.circular(8),
                    border: hasEvents 
                        ? Border.all(color: Color(0xFF8B5CF6), width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      dayNumber.toString(),
                      style: TextStyle(
                        color: isSelected 
                            ? Colors.white
                            : Colors.white,
                        fontWeight: isSelected || isToday 
                            ? FontWeight.bold 
                            : FontWeight.normal,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(PokerEvent event) {
    return Container(
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
        ],
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

  PokerEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.location,
    required this.date,
    required this.buyIn,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'location': location,
      'date': date.toIso8601String(),
      'buyIn': buyIn,
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
    );
  }
}