import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../design_system/poker_friend_theme.dart';
import '../../models/club.dart';
import '../../models/club_event.dart';
import '../../models/event_attendance.dart';
import '../../services/event_attendance_service.dart';

/// Screen showing all attendees for an event
class EventAttendeesScreen extends StatefulWidget {
  final Club club;
  final ClubEvent event;

  const EventAttendeesScreen({
    Key? key,
    required this.club,
    required this.event,
  }) : super(key: key);

  @override
  State<EventAttendeesScreen> createState() => _EventAttendeesScreenState();
}

class _EventAttendeesScreenState extends State<EventAttendeesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  List<EventAttendance> _going = [];
  List<EventAttendance> _maybe = [];
  List<EventAttendance> _notGoing = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        EventAttendanceService.getEventAttendanceByStatus(
          widget.club.id,
          widget.event.id,
          AttendanceStatus.going,
        ),
        EventAttendanceService.getEventAttendanceByStatus(
          widget.club.id,
          widget.event.id,
          AttendanceStatus.maybe,
        ),
        EventAttendanceService.getEventAttendanceByStatus(
          widget.club.id,
          widget.event.id,
          AttendanceStatus.notGoing,
        ),
      ]);

      setState(() {
        _going = results[0];
        _maybe = results[1];
        _notGoing = results[2];
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading attendees: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PokerFriendColors.dark1,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: PokerFriendColors.purple,
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildAttendeeList(_going, AttendanceStatus.going),
                        _buildAttendeeList(_maybe, AttendanceStatus.maybe),
                        _buildAttendeeList(_notGoing, AttendanceStatus.notGoing),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: PokerFriendColors.dark3,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Attendees',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.event.name,
                  style: TextStyle(
                    fontSize: 14,
                    color: PokerFriendColors.dark9,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: PokerFriendColors.dark3,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: PokerFriendColors.purple,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        labelColor: Colors.white,
        unselectedLabelColor: PokerFriendColors.dark9,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 16),
                const SizedBox(width: 6),
                Text('Going (${_going.length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.help_outline, size: 16),
                const SizedBox(width: 6),
                Text('Maybe (${_maybe.length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cancel_outlined, size: 16),
                const SizedBox(width: 6),
                Text('No (${_notGoing.length})'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendeeList(List<EventAttendance> attendees, AttendanceStatus status) {
    if (attendees.isEmpty) {
      return _buildEmptyState(status);
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: PokerFriendColors.purple,
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: attendees.length,
        itemBuilder: (context, index) {
          return _buildAttendeeCard(attendees[index], status);
        },
      ),
    );
  }

  Widget _buildEmptyState(AttendanceStatus status) {
    String message;
    IconData icon;
    Color color;

    switch (status) {
      case AttendanceStatus.going:
        message = 'No one confirmed yet';
        icon = Icons.check_circle_outline;
        color = PokerFriendColors.green;
        break;
      case AttendanceStatus.maybe:
        message = 'No maybes';
        icon = Icons.help_outline;
        color = PokerFriendColors.yellow;
        break;
      case AttendanceStatus.notGoing:
        message = 'No declines';
        icon = Icons.cancel_outlined;
        color = PokerFriendColors.red;
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 32,
              color: color,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: PokerFriendColors.dark9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendeeCard(EventAttendance attendee, AttendanceStatus status) {
    Color statusColor;
    switch (status) {
      case AttendanceStatus.going:
        statusColor = PokerFriendColors.green;
        break;
      case AttendanceStatus.maybe:
        statusColor = PokerFriendColors.yellow;
        break;
      case AttendanceStatus.notGoing:
        statusColor = PokerFriendColors.red;
        break;
    }

    final timeFormat = DateFormat('MMM d, h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PokerFriendColors.dark3,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                _getInitials(attendee.displayName),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Name and time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attendee.displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Responded ${timeFormat.format(attendee.respondedAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: PokerFriendColors.dark9,
                  ),
                ),
              ],
            ),
          ),
          // Calendar icon if added to calendar
          if (attendee.addedToCalendar)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: PokerFriendColors.purple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.event_available,
                size: 16,
                color: PokerFriendColors.purple,
              ),
            ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
