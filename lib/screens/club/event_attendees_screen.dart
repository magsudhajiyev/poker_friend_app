import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../l10n/app_localizations.dart';
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

      // "Going" list is ordered by RSVP time ascending so the first person
      // who said yes is #1. Admin and players can read their position in
      // line directly off the list.
      final going = List<EventAttendance>.from(results[0])
        ..sort((a, b) => a.respondedAt.compareTo(b.respondedAt));

      setState(() {
        _going = going;
        _maybe = results[1];
        _notGoing = results[2];
        _isLoading = false;
      });
    } catch (e) {
      // debugPrint('Error loading attendees: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Teal radial gradient background
          Positioned(
            top: -screenWidth * 0.5,
            right: -screenWidth * 0.2,
            child: Container(
              width: screenWidth * 1.2,
              height: screenWidth * 1.2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1A4A4A).withOpacity(0.6),
                    const Color(0xFF133538).withOpacity(0.6),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 8),
                _buildTabBar(),
                const SizedBox(height: 8),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF89F1EC),
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
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF101115),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).eventAttendeesTitle,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.event.name,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.5),
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
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF131616),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF89F1EC),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        labelColor: Colors.black,
        unselectedLabelColor: Colors.white.withOpacity(0.5),
        labelStyle: GoogleFonts.ibmPlexSans(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        unselectedLabelStyle: GoogleFonts.ibmPlexSans(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        dividerHeight: 0,
        tabs: [
          Tab(
            height: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 14),
                const SizedBox(width: 5),
                Text(AppLocalizations.of(context).eventAttendeesGoing(_going.length)),
              ],
            ),
          ),
          Tab(
            height: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.help_outline, size: 14),
                const SizedBox(width: 5),
                Text(AppLocalizations.of(context).eventAttendeesMaybe(_maybe.length)),
              ],
            ),
          ),
          Tab(
            height: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cancel_outlined, size: 14),
                const SizedBox(width: 5),
                Text(AppLocalizations.of(context).eventAttendeesNo(_notGoing.length)),
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
      color: const Color(0xFF89F1EC),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: attendees.length,
        itemBuilder: (context, index) {
          // Only the Going tab surfaces a position number — it's the one
          // list where "who was first" is meaningful to players/admins.
          final position = status == AttendanceStatus.going ? index + 1 : null;
          return _buildAttendeeCard(attendees[index], status, position: position);
        },
      ),
    );
  }

  Widget _buildEmptyState(AttendanceStatus status) {
    final l10n = AppLocalizations.of(context);
    String message;
    IconData icon;
    Color color;

    switch (status) {
      case AttendanceStatus.going:
        message = l10n.eventAttendeesNoConfirmed;
        icon = Icons.check_circle_outline;
        color = const Color(0xFF89F1EC);
        break;
      case AttendanceStatus.maybe:
        message = l10n.eventAttendeesNoMaybes;
        icon = Icons.help_outline;
        color = Colors.amber;
        break;
      case AttendanceStatus.notGoing:
        message = l10n.eventAttendeesNoDeclines;
        icon = Icons.cancel_outlined;
        color = const Color(0xFFFF4444);
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 28,
              color: color,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendeeCard(
    EventAttendance attendee,
    AttendanceStatus status, {
    int? position,
  }) {
    Color statusColor;
    switch (status) {
      case AttendanceStatus.going:
        statusColor = const Color(0xFF89F1EC);
        break;
      case AttendanceStatus.maybe:
        statusColor = Colors.amber;
        break;
      case AttendanceStatus.notGoing:
        statusColor = const Color(0xFFFF4444);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131616),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Position number (Going tab only) — "#1", "#2", …
          if (position != null) ...[
            SizedBox(
              width: 28,
              child: Text(
                '#$position',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF9A9B9E),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _getInitials(attendee.displayName),
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Text(
              attendee.displayName,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 15,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Calendar icon if added to calendar
          if (attendee.addedToCalendar)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF89F1EC).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.event_available,
                size: 16,
                color: Color(0xFF89F1EC),
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
