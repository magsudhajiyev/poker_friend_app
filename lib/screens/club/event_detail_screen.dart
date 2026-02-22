import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../design_system/poker_friend_theme.dart';
import '../../models/club.dart';
import '../../models/club_event.dart';
import '../../models/club_member.dart';
import '../../models/event_attendance.dart';
import '../../services/event_service.dart';
import '../../services/event_attendance_service.dart';
import '../../services/calendar_event_service.dart';
import '../../services/club_notification_service.dart';
import '../../services/club_service.dart';
import '../../services/auth_service.dart';
import 'event_attendees_screen.dart';
import 'club_dashboard_screen.dart';
import '../dealer/dealer_qr_scan_screen.dart';
import '../spectator/event_rankings_screen.dart';

/// Event detail screen with RSVP functionality
class EventDetailScreen extends StatefulWidget {
  final Club club;
  final ClubEvent event;
  final bool isAdmin;

  const EventDetailScreen({
    Key? key,
    required this.club,
    required this.event,
    required this.isAdmin,
  }) : super(key: key);

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _isLoading = true;
  EventAttendance? _userAttendance;
  Map<AttendanceStatus, int> _attendanceCounts = {};
  List<EventAttendance> _goingMembers = [];
  late ClubEvent _event;
  bool _addedToCalendar = false;
  String? _calendarEventId;
  bool _isDealer = false;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _loadData();
    _checkDealerStatus();
  }

  Future<void> _checkDealerStatus() async {
    try {
      final members = await ClubService.getMembers(widget.club.id);
      final userId = AuthService.userId;
      final member = members.where((m) => m.userId == userId).firstOrNull;
      if (mounted) {
        setState(() {
          _isDealer = member?.role == ClubRole.dealer ||
                      member?.role == ClubRole.admin ||
                      member?.role == ClubRole.owner;
        });
      }
    } catch (e) {
      print('Error checking dealer status: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        EventAttendanceService.getCurrentUserAttendance(
          widget.club.id,
          _event.id,
        ),
        EventAttendanceService.getAttendanceCounts(
          widget.club.id,
          _event.id,
        ),
        EventAttendanceService.getEventAttendanceByStatus(
          widget.club.id,
          _event.id,
          AttendanceStatus.going,
        ),
      ]);

      final attendance = results[0] as EventAttendance?;
      setState(() {
        _userAttendance = attendance;
        _attendanceCounts = results[1] as Map<AttendanceStatus, int>;
        _goingMembers = results[2] as List<EventAttendance>;
        _addedToCalendar = attendance?.addedToCalendar ?? false;
        _calendarEventId = attendance?.calendarEventId;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading event data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateAttendance(AttendanceStatus status) async {
    try {
      await EventAttendanceService.updateAttendance(
        clubId: widget.club.id,
        eventId: _event.id,
        status: status,
      );

      // If changing to "Can't go" and user had added to calendar, remove the event
      if (status == AttendanceStatus.notGoing && _addedToCalendar && _calendarEventId != null) {
        await CalendarEventService.deleteEventById(_calendarEventId!);
        await EventAttendanceService.removeFromCalendar(
          clubId: widget.club.id,
          eventId: _event.id,
        );
        setState(() {
          _addedToCalendar = false;
          _calendarEventId = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Event removed from your calendar'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // Notify admin about the RSVP
      final memberName = AuthService.userDisplayName ?? 'A member';
      String rsvpStatusText;
      switch (status) {
        case AttendanceStatus.going:
          rsvpStatusText = 'Going';
          break;
        case AttendanceStatus.maybe:
          rsvpStatusText = 'Maybe';
          break;
        case AttendanceStatus.notGoing:
          rsvpStatusText = "Can't go";
          break;
      }

      await ClubNotificationService.notifyAdminRSVP(
        clubId: widget.club.id,
        event: _event,
        memberName: memberName,
        rsvpStatus: rsvpStatusText,
      );

      _loadData(); // Refresh
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update RSVP: $e')),
      );
    }
  }

  Future<void> _startEvent() async {
    try {
      await EventService.startEvent(widget.club.id, _event.id);
      // Refresh event data
      final updatedEvent = await EventService.getEvent(widget.club.id, _event.id);
      if (updatedEvent != null) {
        setState(() => _event = updatedEvent);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event started!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start event: $e')),
      );
    }
  }

  Future<void> _cancelOrFinishEvent() async {
    // Determine if this is a live event (active or paused) or a scheduled event
    final isLive = _event.status == EventStatus.active ||
        _event.status == EventStatus.paused;

    final dialogTitle = isLive ? 'Finish Event?' : 'Cancel Event?';
    final dialogContent = isLive
        ? 'This will end all active tables and save all player data.'
        : 'This will notify all members. This action cannot be undone.';
    final confirmButtonText = isLive ? 'Finish Event' : 'Cancel Event';
    final keepButtonText = 'Keep Event';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PokerFriendColors.dark3,
        title: Text(
          dialogTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          dialogContent,
          style: const TextStyle(color: PokerFriendColors.dark11),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(keepButtonText),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: isLive ? PokerFriendColors.green : PokerFriendColors.red,
            ),
            child: Text(confirmButtonText),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (isLive) {
          // Finish the event (ends dealer sessions, clears tables)
          await EventService.completeEvent(widget.club.id, _event.id);
        } else {
          // Cancel the event
          await EventService.cancelEvent(widget.club.id, _event.id);
        }
        Navigator.pop(context, true); // Return to refresh list
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to ${isLive ? "finish" : "cancel"} event: $e')),
        );
      }
    }
  }

  void _navigateToAttendees() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventAttendeesScreen(
          club: widget.club,
          event: _event,
        ),
      ),
    );
  }

  Future<void> _addEventToCalendar() async {
    try {
      // Determine event type based on buyIn
      String eventType = 'Tournament';
      if (_event.buyInAmount == null || _event.buyInAmount == 0) {
        eventType = 'Home Game';
      }

      final calendarEventId = await CalendarEventService.createEvent(
        title: _event.name,
        type: eventType,
        location: _event.location ?? widget.club.name,
        date: _event.startTime,
        buyIn: _event.buyInAmount ?? 0.0,
        clubId: widget.club.id,
        clubEventId: _event.id,
      );

      setState(() {
        _addedToCalendar = true;
        _calendarEventId = calendarEventId;
      });

      // Update attendance record to track calendar addition
      await EventAttendanceService.markAddedToCalendar(
        clubId: widget.club.id,
        eventId: _event.id,
        calendarEventId: calendarEventId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event added to your calendar!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to calendar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateBackToClub() {
    // Navigate to club dashboard, replacing current route stack
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => ClubDashboardScreen(club: widget.club),
      ),
      (route) => route.isFirst, // Keep only the home screen at the bottom
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _navigateBackToClub();
        }
      },
      child: Scaffold(
        backgroundColor: PokerFriendColors.dark1,
        body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: PokerFriendColors.purple,
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Event status badge
                          _buildStatusBadge(),
                          const SizedBox(height: 16),

                          // Event name
                          Text(
                            _event.name,
                            style: const TextStyle(
                              fontSize: 28,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Date and time card
                          _buildInfoCard(
                            icon: Icons.calendar_today,
                            title: 'Date & Time',
                            content: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateFormat.format(_event.startTime),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  timeFormat.format(_event.startTime),
                                  style: TextStyle(
                                    color: PokerFriendColors.dark11,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Location card
                          if (_event.location != null && _event.location!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildInfoCard(
                              icon: Icons.location_on,
                              title: 'Location',
                              content: Text(
                                _event.location!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],

                          // Buy-in card
                          if (!_event.isFree) ...[
                            const SizedBox(height: 12),
                            _buildInfoCard(
                              icon: Icons.attach_money,
                              title: 'Buy-in',
                              content: Text(
                                '\$${_event.buyInAmount?.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: PokerFriendColors.green,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],

                          // Description
                          if (_event.description != null && _event.description!.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const Text(
                              'About',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _event.description!,
                              style: TextStyle(
                                fontSize: 15,
                                color: PokerFriendColors.dark11,
                                height: 1.5,
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // RSVP section
                          if (_event.status == EventStatus.scheduled)
                            _buildRSVPSection(),

                          // Start Dealing button (for dealers during live events)
                          if (_isDealer && _event.isLive) ...[
                            const SizedBox(height: 16),
                            _buildStartDealingButton(),
                          ],

                          // View Rankings button (for everyone during live events)
                          if (_event.isLive) ...[
                            const SizedBox(height: 12),
                            _buildViewRankingsButton(),
                          ],

                          // Add to Calendar button
                          const SizedBox(height: 16),
                          _buildAddToCalendarButton(),

                          const SizedBox(height: 24),

                          // Attendance preview
                          _buildAttendancePreview(),

                          // Admin actions
                          if (widget.isAdmin) ...[
                            const SizedBox(height: 32),
                            _buildAdminActions(),
                          ],

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
            ),
          ],
        ),
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
            onTap: _navigateBackToClub,
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
          const Spacer(),
          Text(
            widget.club.name,
            style: TextStyle(
              fontSize: 16,
              color: PokerFriendColors.dark9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color bgColor;
    Color textColor;
    String text;

    if (_event.isLive) {
      bgColor = PokerFriendColors.red;
      textColor = Colors.white;
      text = 'LIVE NOW';
    } else if (_event.status == EventStatus.cancelled) {
      bgColor = PokerFriendColors.dark5;
      textColor = PokerFriendColors.dark9;
      text = 'CANCELLED';
    } else if (_event.status == EventStatus.completed) {
      bgColor = PokerFriendColors.dark5;
      textColor = PokerFriendColors.dark11;
      text = 'COMPLETED';
    } else {
      bgColor = PokerFriendColors.green.withOpacity(0.2);
      textColor = PokerFriendColors.green;
      text = 'UPCOMING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_event.isLive) ...[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: textColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required Widget content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PokerFriendColors.dark3,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: PokerFriendColors.purple.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: PokerFriendColors.purple,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: PokerFriendColors.dark9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                content,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRSVPSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Are you going?',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildRSVPButton(
                status: AttendanceStatus.going,
                icon: Icons.check_circle,
                label: 'Going',
                color: PokerFriendColors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildRSVPButton(
                status: AttendanceStatus.maybe,
                icon: Icons.help_outline,
                label: 'Maybe',
                color: PokerFriendColors.yellow,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildRSVPButton(
                status: AttendanceStatus.notGoing,
                icon: Icons.cancel_outlined,
                label: "Can't go",
                color: PokerFriendColors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRSVPButton({
    required AttendanceStatus status,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isSelected = _userAttendance?.status == status;

    return GestureDetector(
      onTap: () => _updateAttendance(status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : PokerFriendColors.dark3,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : PokerFriendColors.dark9,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? color : PokerFriendColors.dark11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddToCalendarButton() {
    // Only show for upcoming events (not completed/cancelled)
    if (_event.status == EventStatus.completed ||
        _event.status == EventStatus.cancelled) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: _addedToCalendar ? null : _addEventToCalendar,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _addedToCalendar
              ? PokerFriendColors.dark5
              : PokerFriendColors.purple,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _addedToCalendar ? Icons.check : Icons.calendar_today,
              color: _addedToCalendar ? PokerFriendColors.dark9 : Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              _addedToCalendar ? 'Added to Calendar' : 'Add to Calendar',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _addedToCalendar ? PokerFriendColors.dark9 : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendancePreview() {
    final goingCount = _attendanceCounts[AttendanceStatus.going] ?? 0;
    final maybeCount = _attendanceCounts[AttendanceStatus.maybe] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PokerFriendColors.dark3,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Who\'s Coming',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _navigateToAttendees,
                child: Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 14,
                    color: PokerFriendColors.purple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildAttendanceCount(
                count: goingCount,
                label: 'Going',
                color: PokerFriendColors.green,
              ),
              const SizedBox(width: 24),
              _buildAttendanceCount(
                count: maybeCount,
                label: 'Maybe',
                color: PokerFriendColors.yellow,
              ),
            ],
          ),
          if (_goingMembers.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: PokerFriendColors.dark5),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _goingMembers.take(5).map((member) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: PokerFriendColors.dark5,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    member.displayName,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_goingMembers.length > 5) ...[
              const SizedBox(height: 8),
              Text(
                '+${_goingMembers.length - 5} more',
                style: TextStyle(
                  fontSize: 13,
                  color: PokerFriendColors.dark9,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildAttendanceCount({
    required int count,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 20,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: PokerFriendColors.dark9,
          ),
        ),
      ],
    );
  }

  Widget _buildStartDealingButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DealerQRScanScreen(
              event: _event,
              club: widget.club,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              PokerFriendColors.green,
              PokerFriendColors.green.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: PokerFriendColors.green.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_scanner,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              'Start Dealing',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewRankingsButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventRankingsScreen(
              event: _event,
              accessCode: _event.accessCode,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: PokerFriendColors.dark3,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: PokerFriendColors.purple.withOpacity(0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.leaderboard,
              color: PokerFriendColors.purple,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              'View Live Rankings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: PokerFriendColors.purple,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Admin Actions',
          style: TextStyle(
            fontSize: 16,
            color: PokerFriendColors.dark9,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (_event.status == EventStatus.scheduled)
              Expanded(
                child: _buildAdminButton(
                  onTap: _startEvent,
                  icon: Icons.play_arrow,
                  label: 'Start Event',
                  color: PokerFriendColors.green,
                ),
              ),
            if (_event.status == EventStatus.scheduled)
              const SizedBox(width: 12),
            if (_event.status == EventStatus.scheduled ||
                _event.status == EventStatus.active ||
                _event.status == EventStatus.paused)
              Expanded(
                child: _buildAdminButton(
                  onTap: _cancelOrFinishEvent,
                  icon: (_event.status == EventStatus.active ||
                          _event.status == EventStatus.paused)
                      ? Icons.check_circle
                      : Icons.cancel,
                  label: (_event.status == EventStatus.active ||
                          _event.status == EventStatus.paused)
                      ? 'Finish'
                      : 'Cancel',
                  color: (_event.status == EventStatus.active ||
                          _event.status == EventStatus.paused)
                      ? PokerFriendColors.green
                      : PokerFriendColors.red,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdminButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
