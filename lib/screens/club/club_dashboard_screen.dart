import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../design_system/poker_friend_theme.dart';
import '../../models/club.dart';
import '../../models/club_event.dart';
import '../../models/club_member.dart';
import '../../models/club_invitation.dart';
import '../../models/event_attendance.dart';
import '../../models/event_ranking.dart';
import '../../services/club_service.dart';
import '../../services/event_service.dart';
import '../../services/event_attendance_service.dart';
import '../../services/invitation_service.dart';
import '../../services/dealer_service.dart';
import 'event_detail_screen.dart';
import 'create_event_screen.dart';
import 'club_settings_screen.dart';
import 'club_info_screen.dart';

/// Club dashboard showing events with tabs for Upcoming, Live, and Past
class ClubDashboardScreen extends StatefulWidget {
  final Club club;

  const ClubDashboardScreen({
    Key? key,
    required this.club,
  }) : super(key: key);

  @override
  State<ClubDashboardScreen> createState() => _ClubDashboardScreenState();
}

class _ClubDashboardScreenState extends State<ClubDashboardScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  bool _isAdmin = false;
  bool _isLoading = true;
  int _memberCount = 0;

  List<ClubEvent> _upcomingEvents = [];
  List<ClubEvent> _liveEvents = [];
  List<ClubEvent> _pastEvents = [];

  // Dealers tab data
  List<ClubMember> _dealers = [];
  List<ClubInvitation> _pendingInvitations = [];
  Map<String, String?> _dealerTableAssignments = {}; // dealerId -> tableId

  // Player counts for event cards
  Map<String, int> _eventPlayerCounts = {}; // eventId -> player count

  // Real-time subscription for all events
  StreamSubscription<List<ClubEvent>>? _eventsSubscription;

  @override
  void initState() {
    super.initState();
    _initTabController(); // Initialize immediately to avoid hot reload issues
    _loadData();
    _setupEventsListener();
  }

  /// Setup real-time listener for all events (upcoming, live, past)
  void _setupEventsListener() {
    _eventsSubscription = EventService.watchClubEvents(widget.club.id)
        .listen((allEvents) {
      if (!mounted) return;

      // Upcoming: scheduled events, sorted by start time (soonest first)
      final upcoming = allEvents
          .where((e) => e.status == EventStatus.scheduled)
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

      // Live: active or paused events, sorted by start time (most recent first)
      final live = allEvents
          .where((e) => e.status == EventStatus.active || e.status == EventStatus.paused)
          .toList()
        ..sort((a, b) => b.startTime.compareTo(a.startTime));

      // Past: completed or cancelled events, sorted by start time (most recent first)
      final past = allEvents
          .where((e) => e.status == EventStatus.completed || e.status == EventStatus.cancelled)
          .toList()
        ..sort((a, b) => b.startTime.compareTo(a.startTime));

      setState(() {
        _upcomingEvents = upcoming;
        _liveEvents = live;
        _pastEvents = past;
      });

      // Load player counts for all events
      _loadPlayerCounts(allEvents);
    });
  }

  /// Load player counts for events based on their status
  Future<void> _loadPlayerCounts(List<ClubEvent> events) async {
    final counts = <String, int>{};

    for (final event in events) {
      try {
        int count = 0;

        if (event.status == EventStatus.scheduled) {
          // For upcoming events: get "going" RSVP count
          final attendanceCounts = await EventAttendanceService.getAttendanceCounts(
            widget.club.id,
            event.id,
          );
          count = attendanceCounts[AttendanceStatus.going] ?? 0;
        } else if (event.status == EventStatus.active || event.status == EventStatus.paused) {
          // For live events: get active (non-busted) player count
          final rankings = await EventService.getRankingsFromFirestore(
            widget.club.id,
            event.id,
          );
          if (rankings != null) {
            count = rankings.rankings
                .where((r) => r.status == PlayerRankingStatus.active)
                .length;
          }
        } else if (event.status == EventStatus.completed) {
          // For completed events: get total players from final standings
          final finalStandings = await EventService.getFinalStandings(
            widget.club.id,
            event.id,
          );
          if (finalStandings != null) {
            count = finalStandings.totalPlayers;
          } else {
            // Fallback to rankings if final standings not available
            final rankings = await EventService.getRankingsFromFirestore(
              widget.club.id,
              event.id,
            );
            count = rankings?.totalPlayers ?? 0;
          }
        }

        counts[event.id] = count;
      } catch (e) {
        // Silently ignore errors for individual event counts
        counts[event.id] = 0;
      }
    }

    if (mounted) {
      setState(() {
        _eventPlayerCounts = counts;
      });
    }
  }

  void _initTabController() {
    const tabCount = 3; // Upcoming, Live, Past (Dealers removed - available in Settings)
    if (_tabController == null || _tabController!.length != tabCount) {
      // Preserve current index if valid, otherwise default to 0
      final currentIndex = _tabController?.index ?? 0;
      final newIndex = currentIndex.clamp(0, tabCount - 1);
      final oldController = _tabController;
      _tabController = TabController(length: tabCount, vsync: this, initialIndex: newIndex);
      oldController?.dispose();
    }
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // First check if user is admin (needed for tab count)
      final isAdmin = await ClubService.canManageEvents(widget.club.id);
      if (!mounted) return;

      // Load all data in parallel
      final results = await Future.wait([
        ClubService.getMemberCount(widget.club.id),
        EventService.getUpcomingEvents(widget.club.id),
        EventService.getActiveEvents(widget.club.id),
        EventService.getPastEvents(widget.club.id),
        if (isAdmin) ClubService.getMembers(widget.club.id),
        if (isAdmin) InvitationService.getClubInvitations(widget.club.id, status: InvitationStatus.pending),
      ]);
      if (!mounted) return;

      // Get active dealer sessions to show dealer status
      Map<String, String?> dealerTableAssignments = {};
      if (isAdmin) {
        final members = results[4] as List<ClubMember>;
        final dealers = members.where((m) => m.role == ClubRole.dealer).toList();
        for (final dealer in dealers) {
          // Check if dealer has active session
          final sessions = await DealerService.getDealerActiveSessions();
          if (!mounted) return;
          final activeSession = sessions.where((s) => s.dealerId == dealer.userId && s.clubId == widget.club.id).firstOrNull;
          if (activeSession != null) {
            dealerTableAssignments[dealer.userId] = activeSession.tableId;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _isAdmin = isAdmin;
        _memberCount = results[0] as int;
        _upcomingEvents = results[1] as List<ClubEvent>;
        _liveEvents = results[2] as List<ClubEvent>;
        _pastEvents = results[3] as List<ClubEvent>;
        if (isAdmin) {
          final members = results[4] as List<ClubMember>;
          _dealers = members.where((m) => m.role == ClubRole.dealer).toList();
          _pendingInvitations = (results[5] as List<ClubInvitation>)
              .where((inv) => inv.role == ClubRole.dealer)
              .toList();
          _dealerTableAssignments = dealerTableAssignments;
        }
        _initTabController();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading club data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToCreateEvent() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEventScreen(club: widget.club),
      ),
    );

    if (result == true) {
      _loadData(); // Refresh events
    }
  }

  void _navigateToEventDetail(ClubEvent event) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailScreen(
          club: widget.club,
          event: event,
          isAdmin: _isAdmin,
        ),
      ),
    );

    if (result == true) {
      _loadData(); // Refresh events
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
            if (_tabController != null) _buildTabBar(),
            Expanded(
              child: _isLoading || _tabController == null
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: PokerFriendColors.purple,
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildEventList(_upcomingEvents, 'No upcoming events', 'scheduled'),
                        _buildEventList(_liveEvents, 'No live events', 'live'),
                        _buildEventList(_pastEvents, 'No past events', 'past'),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget? _buildFloatingActionButton() {
    if (!_isAdmin || _tabController == null) return null;

    // Show Create Event button for admins
    return FloatingActionButton.extended(
      onPressed: _navigateToCreateEvent,
      backgroundColor: PokerFriendColors.purple,
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text(
        'Create Event',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        children: [
          // Back button
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
          // Club info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.club.name,
                  style: const TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.people,
                      size: 14,
                      color: PokerFriendColors.dark9,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_memberCount members',
                      style: TextStyle(
                        fontSize: 14,
                        color: PokerFriendColors.dark9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Admin badge
          if (_isAdmin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: PokerFriendColors.purple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    size: 14,
                    color: PokerFriendColors.purple,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Admin',
                    style: TextStyle(
                      fontSize: 12,
                      color: PokerFriendColors.purple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 12),
          // Settings/Info button
          GestureDetector(
            onTap: _navigateToSettingsOrInfo,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: PokerFriendColors.dark3,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _isAdmin ? Icons.settings : Icons.info_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToSettingsOrInfo() {
    if (_isAdmin) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ClubSettingsScreen(club: widget.club),
        ),
      ).then((_) => _loadData()); // Refresh data when returning
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ClubInfoScreen(club: widget.club),
        ),
      );
    }
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
          fontSize: 13,
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Upcoming'),
                if (_upcomingEvents.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _buildBadge(_upcomingEvents.length),
                ],
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Live'),
                if (_liveEvents.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _buildLiveBadge(_liveEvents.length),
                ],
              ],
            ),
          ),
          const Tab(text: 'Past'),
        ],
        onTap: (_) {
          // Force rebuild to update FAB
          setState(() {});
        },
      ),
    );
  }

  Widget _buildBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: PokerFriendColors.dark5,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildLiveBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: PokerFriendColors.red,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildEventList(List<ClubEvent> events, String emptyMessage, String type) {
    if (events.isEmpty) {
      return _buildEmptyState(emptyMessage, type);
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: PokerFriendColors.purple,
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: events.length,
        itemBuilder: (context, index) {
          return _buildEventCard(events[index], type);
        },
      ),
    );
  }

  Widget _buildEmptyState(String message, String type) {
    IconData icon;
    String subtitle;

    switch (type) {
      case 'scheduled':
        icon = Icons.event;
        subtitle = _isAdmin
            ? 'Tap the button below to create one'
            : 'Check back later for new events';
        break;
      case 'live':
        icon = Icons.play_circle_outline;
        subtitle = 'Events will appear here when they start';
        break;
      case 'past':
        icon = Icons.history;
        subtitle = 'Completed events will appear here';
        break;
      default:
        icon = Icons.event;
        subtitle = '';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: PokerFriendColors.dark3,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              size: 40,
              color: PokerFriendColors.dark9,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: PokerFriendColors.dark9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(ClubEvent event, String type) {
    final dateFormat = DateFormat('EEE, MMM d');
    final timeFormat = DateFormat('h:mm a');

    return GestureDetector(
      onTap: () => _navigateToEventDetail(event),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: PokerFriendColors.dark3,
          borderRadius: BorderRadius.circular(20),
          border: type == 'live'
              ? Border.all(color: PokerFriendColors.red.withOpacity(0.5), width: 2)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row with status
            Row(
              children: [
                if (type == 'live')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: PokerFriendColors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: PokerFriendColors.dark5,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      event.status.displayName,
                      style: TextStyle(
                        fontSize: 11,
                        color: PokerFriendColors.dark11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const Spacer(),
                Icon(
                  Icons.chevron_right,
                  color: PokerFriendColors.dark9,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Event name
            Text(
              event.name,
              style: const TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Date and time
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: PokerFriendColors.dark9,
                ),
                const SizedBox(width: 6),
                Text(
                  dateFormat.format(event.startTime),
                  style: TextStyle(
                    fontSize: 14,
                    color: PokerFriendColors.dark11,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: PokerFriendColors.dark9,
                ),
                const SizedBox(width: 6),
                Text(
                  timeFormat.format(event.startTime),
                  style: TextStyle(
                    fontSize: 14,
                    color: PokerFriendColors.dark11,
                  ),
                ),
              ],
            ),

            // Location if available
            if (event.location != null && event.location!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: PokerFriendColors.dark9,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    event.location!,
                    style: TextStyle(
                      fontSize: 14,
                      color: PokerFriendColors.dark11,
                    ),
                  ),
                ],
              ),
            ],

            // Buy-in and player count row
            const SizedBox(height: 12),
            Row(
              children: [
                if (!event.isFree) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: PokerFriendColors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.attach_money,
                          size: 14,
                          color: PokerFriendColors.green,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${event.buyInAmount?.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: PokerFriendColors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // Player count badge
                _buildPlayerCountBadge(event, type),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerCountBadge(ClubEvent event, String type) {
    final count = _eventPlayerCounts[event.id] ?? 0;

    // Determine label based on event type
    String label;
    Color color;

    switch (type) {
      case 'scheduled':
        label = '$count going';
        color = PokerFriendColors.purple;
        break;
      case 'live':
        label = '$count playing';
        color = PokerFriendColors.blue;
        break;
      case 'past':
        label = '$count players';
        color = PokerFriendColors.dark9;
        break;
      default:
        label = '$count';
        color = PokerFriendColors.dark9;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ========== Dealers Tab Methods ==========

  Widget _buildDealersTab() {
    if (_dealers.isEmpty && _pendingInvitations.isEmpty) {
      return _buildEmptyDealersState();
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: PokerFriendColors.purple,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Active dealers section
          if (_dealers.isNotEmpty) ...[
            _buildSectionTitle('Active Dealers', _dealers.length),
            const SizedBox(height: 12),
            ..._dealers.map(_buildDealerCard),
            const SizedBox(height: 24),
          ],
          // Pending invitations section
          if (_pendingInvitations.isNotEmpty) ...[
            _buildSectionTitle('Pending Invitations', _pendingInvitations.length),
            const SizedBox(height: 12),
            ..._pendingInvitations.map(_buildPendingInvitationCard),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: PokerFriendColors.dark5,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              color: PokerFriendColors.dark11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDealerCard(ClubMember dealer) {
    final isActive = _dealerTableAssignments.containsKey(dealer.userId);
    // tableId can be used later to show which table the dealer is at
    // final tableId = _dealerTableAssignments[dealer.userId];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PokerFriendColors.dark3,
        borderRadius: BorderRadius.circular(16),
        border: isActive
            ? Border.all(color: PokerFriendColors.green.withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: PokerFriendColors.purple.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                (dealer.displayName ?? 'D')[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 20,
                  color: PokerFriendColors.purple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dealer.displayName ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dealer.email ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: PokerFriendColors.dark9,
                  ),
                ),
              ],
            ),
          ),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isActive
                  ? PokerFriendColors.green.withValues(alpha: 0.15)
                  : PokerFriendColors.dark5,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive ? PokerFriendColors.green : PokerFriendColors.dark9,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isActive ? 'Active' : 'Idle',
                  style: TextStyle(
                    fontSize: 12,
                    color: isActive ? PokerFriendColors.green : PokerFriendColors.dark9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingInvitationCard(ClubInvitation invitation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PokerFriendColors.dark3,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PokerFriendColors.yellow.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Avatar placeholder
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: PokerFriendColors.yellow.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mail_outline,
              color: PokerFriendColors.yellow,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invitation.email,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Invited ${_formatTimeAgo(invitation.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: PokerFriendColors.dark9,
                  ),
                ),
              ],
            ),
          ),
          // Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: PokerFriendColors.yellow.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Pending',
              style: TextStyle(
                fontSize: 12,
                color: PokerFriendColors.yellow,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Cancel button
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _cancelInvitation(invitation),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: PokerFriendColors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.close,
                color: PokerFriendColors.red,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDealersState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: PokerFriendColors.dark3,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.person_outline,
              size: 40,
              color: PokerFriendColors.dark9,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No dealers yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Invite dealers to help manage your tables',
            style: TextStyle(
              fontSize: 14,
              color: PokerFriendColors.dark9,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }

  Future<void> _showInviteDealerDialog() async {
    final emailController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PokerFriendColors.dark3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Invite Dealer',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the email address of the dealer you want to invite.',
              style: TextStyle(color: PokerFriendColors.dark9, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'dealer@example.com',
                hintStyle: TextStyle(color: PokerFriendColors.dark7),
                filled: true,
                fillColor: PokerFriendColors.dark5,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.email_outlined, color: PokerFriendColors.dark9),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: PokerFriendColors.dark9),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final email = emailController.text.trim();
              if (email.isNotEmpty && email.contains('@')) {
                Navigator.pop(context, email);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: PokerFriendColors.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Send Invitation'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _inviteDealer(result);
    }
  }

  Future<void> _inviteDealer(String email) async {
    try {
      await InvitationService.createInvitation(
        clubId: widget.club.id,
        email: email,
        role: ClubRole.dealer,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invitation sent to $email'),
            backgroundColor: PokerFriendColors.green,
          ),
        );
      }

      _loadData(); // Refresh to show new invitation
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send invitation: $e'),
            backgroundColor: PokerFriendColors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelInvitation(ClubInvitation invitation) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PokerFriendColors.dark3,
        title: const Text(
          'Cancel Invitation?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Cancel the invitation to ${invitation.email}?',
          style: TextStyle(color: PokerFriendColors.dark11),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: PokerFriendColors.red),
            child: const Text('Cancel Invitation'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await InvitationService.cancelInvitation(
          clubId: widget.club.id,
          invitationId: invitation.id,
        );
        _loadData(); // Refresh
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cancel invitation: $e'),
              backgroundColor: PokerFriendColors.red,
            ),
          );
        }
      }
    }
  }
}
