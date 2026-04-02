import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../design_system/poker_friend_theme.dart';
import '../../design_system/constants/colors.dart';
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
import '../../services/seat_service.dart';
import '../../design_system/components/cards/error_state_card.dart';
import '../../widgets/global_bottom_nav_bar.dart';
import 'event_detail_screen.dart';
import 'create_event_screen.dart';
import 'club_settings_screen.dart';
import 'club_info_screen.dart';

/// Club dashboard showing events with segmented tabs for Upcoming, Live, Past, Dealers
/// Matches Figma node 357:3862
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
  String? _loadError;
  int _memberCount = 0;

  List<ClubEvent> _upcomingEvents = [];
  List<ClubEvent> _liveEvents = [];
  List<ClubEvent> _pastEvents = [];

  // Dealers tab data
  List<ClubMember> _dealers = [];
  List<ClubInvitation> _pendingInvitations = [];
  Map<String, String?> _dealerTableAssignments = {};

  // Player counts for event cards
  Map<String, int> _eventPlayerCounts = {};

  // Real-time subscription for all events
  StreamSubscription<List<ClubEvent>>? _eventsSubscription;

  // Real-time subscriptions for seat changes (cash games)
  Map<String, StreamSubscription> _seatSubscriptions = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController!.addListener(() {
      if (!_tabController!.indexIsChanging) {
        setState(() {});
      }
    });
    _loadData();
    _setupEventsListener();
  }

  /// Setup real-time listener for all events (upcoming, live, past)
  void _setupEventsListener() {
    _eventsSubscription = EventService.watchClubEvents(widget.club.id)
        .listen((allEvents) {
      if (!mounted) return;

      final upcoming = allEvents
          .where((e) => e.status == EventStatus.scheduled)
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

      final live = allEvents
          .where((e) => e.status == EventStatus.active || e.status == EventStatus.paused)
          .toList()
        ..sort((a, b) => b.startTime.compareTo(a.startTime));

      final past = allEvents
          .where((e) => e.status == EventStatus.completed || e.status == EventStatus.cancelled)
          .toList()
        ..sort((a, b) => b.startTime.compareTo(a.startTime));

      setState(() {
        _upcomingEvents = upcoming;
        _liveEvents = live;
        _pastEvents = past;
      });

      _loadPlayerCounts(allEvents);
      _setupSeatListeners(live);
    });
  }

  /// Setup real-time listeners for seat changes in live cash games
  void _setupSeatListeners(List<ClubEvent> liveEvents) {
    final currentKeys = <String>{};
    for (final event in liveEvents) {
      if (event.gameType == 'cash') {
        for (final tableId in event.tableIds) {
          currentKeys.add('${event.id}_$tableId');
        }
      }
    }

    final keysToRemove = _seatSubscriptions.keys
        .where((key) => !currentKeys.contains(key))
        .toList();
    for (final key in keysToRemove) {
      _seatSubscriptions[key]?.cancel();
      _seatSubscriptions.remove(key);
    }

    for (final event in liveEvents) {
      if (event.gameType != 'cash') continue;

      for (final tableId in event.tableIds) {
        final key = '${event.id}_$tableId';
        if (_seatSubscriptions.containsKey(key)) continue;

        _seatSubscriptions[key] = SeatService.watchTableSeats(
          clubId: widget.club.id,
          tableId: tableId,
        ).listen((seats) {
          if (!mounted) return;
          _updateCashGamePlayerCount(event);
        });
      }
    }
  }

  Future<void> _updateCashGamePlayerCount(ClubEvent event) async {
    int count = 0;
    for (final tableId in event.tableIds) {
      final seats = await SeatService.getTableSeats(
        clubId: widget.club.id,
        tableId: tableId,
      );
      count += seats.values.where((s) => s.isOccupied).length;
    }

    if (mounted && _eventPlayerCounts[event.id] != count) {
      setState(() {
        _eventPlayerCounts[event.id] = count;
      });
    }
  }

  Future<void> _loadPlayerCounts(List<ClubEvent> events) async {
    final counts = <String, int>{};

    for (final event in events) {
      try {
        int count = 0;

        if (event.status == EventStatus.scheduled) {
          final attendanceCounts = await EventAttendanceService.getAttendanceCounts(
            widget.club.id,
            event.id,
          );
          count = attendanceCounts[AttendanceStatus.going] ?? 0;
        } else if (event.status == EventStatus.active || event.status == EventStatus.paused) {
          if (event.gameType == 'cash') {
            for (final tableId in event.tableIds) {
              final seats = await SeatService.getTableSeats(
                clubId: widget.club.id,
                tableId: tableId,
              );
              count += seats.values.where((s) => s.isOccupied).length;
            }
          } else {
            final rankings = await EventService.getRankingsFromFirestore(
              widget.club.id,
              event.id,
            );
            if (rankings != null) {
              count = rankings.rankings
                  .where((r) => r.status == PlayerRankingStatus.active)
                  .length;
            }
          }
        } else if (event.status == EventStatus.completed) {
          final finalStandings = await EventService.getFinalStandings(
            widget.club.id,
            event.id,
          );
          if (finalStandings != null) {
            count = finalStandings.totalPlayers;
          } else {
            final rankings = await EventService.getRankingsFromFirestore(
              widget.club.id,
              event.id,
            );
            count = rankings?.totalPlayers ?? 0;
          }
        }

        counts[event.id] = count;
      } catch (e) {
        counts[event.id] = 0;
      }
    }

    if (mounted) {
      setState(() {
        _eventPlayerCounts = counts;
      });
    }
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    for (final sub in _seatSubscriptions.values) {
      sub.cancel();
    }
    _seatSubscriptions.clear();
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final isAdmin = await ClubService.canManageEvents(widget.club.id);
      if (!mounted) return;

      final results = await Future.wait([
        ClubService.getMemberCount(widget.club.id),
        EventService.getUpcomingEvents(widget.club.id),
        EventService.getActiveEvents(widget.club.id),
        EventService.getPastEvents(widget.club.id),
        if (isAdmin) ClubService.getMembers(widget.club.id),
        if (isAdmin) InvitationService.getClubInvitations(widget.club.id, status: InvitationStatus.pending),
      ]);
      if (!mounted) return;

      Map<String, String?> dealerTableAssignments = {};
      if (isAdmin) {
        final members = results[4] as List<ClubMember>;
        final dealers = members.where((m) => m.role == ClubRole.dealer).toList();
        for (final dealer in dealers) {
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
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = e.toString();
        });
      }
    }
  }

  void _navigateToCreateEvent() async {
    final result = await showCreateEventDrawer(context, club: widget.club);

    if (result == true) {
      _loadData();
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
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFF02050B),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Cyan ellipse glow at top
          Positioned(
            top: -162,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 412,
                height: 217,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.0,
                    colors: [
                      const Color(0xFF4CDBFF).withValues(alpha: 0.25),
                      const Color(0xFF2EB46A).withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Main content
          Column(
            children: [
              SizedBox(height: statusBarHeight),
              _buildHeader(),
              const SizedBox(height: 10),
              if (_tabController != null) _buildSegmentedControl(),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading || _tabController == null
                    ? Center(
                        child: CircularProgressIndicator(
                          color: AppColors.tealAccent,
                        ),
                      )
                    : _loadError != null
                        ? ErrorStateCard(onRetry: _loadData)
                        : TabBarView(
                        controller: _tabController!,
                        children: [
                          _buildEventList(_upcomingEvents, 'No upcoming events', 'scheduled'),
                          _buildEventList(_liveEvents, 'No live events', 'live'),
                          _buildEventList(_pastEvents, 'No past events', 'past'),
                        ],
                      ),
              ),
            ],
          ),

          // (Create Event button is now inline in empty state)
        ],
      ),
      bottomNavigationBar: GlobalBottomNavBar(currentScreen: 'home'),
    );
  }

  /// Header matching Figma design (node 357:3911)
  Widget _buildHeader() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 84,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF101115),
                    borderRadius: BorderRadius.circular(88),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      'icons/figma_icons/back.svg',
                      width: 18,
                      height: 15,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Club name and member count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.club.name,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 27,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        height: 1.0,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        SvgPicture.asset(
                          'icons/figma_icons/opponents.svg',
                          width: 18,
                          height: 18,
                          colorFilter: const ColorFilter.mode(Color(0xFFD3FFFD), BlendMode.srcIn),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$_memberCount member${_memberCount == 1 ? '' : 's'}',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFFD3FFFD),
                            height: 1.47,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Admin badge (only if admin)
              if (_isAdmin) ...[
                Container(
                  height: 25,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFF02050B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF89F1EC),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star,
                        size: 14,
                        color: Color(0xFF89F1EC),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Admin',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.47,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Settings button
              GestureDetector(
                onTap: _navigateToSettingsOrInfo,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF101115),
                    borderRadius: BorderRadius.circular(88),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      'icons/figma_icons/gear.svg',
                      width: 24,
                      height: 24,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
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

  void _navigateToSettingsOrInfo() {
    if (_isAdmin) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ClubSettingsScreen(club: widget.club),
        ),
      ).then((_) => _loadData());
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ClubInfoScreen(club: widget.club),
        ),
      );
    }
  }

  /// Segmented control matching Figma (node 416:4363)
  /// Uses AnimatedBuilder to smoothly slide the indicator during swipe
  Widget _buildSegmentedControl() {
    final tabs = ['Upcoming', 'Live', 'Past'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: const Color(0xFF101115),
          borderRadius: BorderRadius.circular(90),
          border: Border.all(
            color: const Color(0xFF35373C),
            width: 1,
          ),
        ),
        child: AnimatedBuilder(
          animation: _tabController!.animation!,
          builder: (context, _) {
            final animValue = _tabController!.animation!.value;

            return LayoutBuilder(
              builder: (context, constraints) {
                final tabWidth = constraints.maxWidth / tabs.length;

                return Stack(
                  children: [
                    // Sliding indicator
                    Positioned(
                      left: animValue * tabWidth,
                      child: Container(
                        width: tabWidth,
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color(0xFF89F1EC),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    // Tab labels
                    Row(
                      children: tabs.asMap().entries.map((entry) {
                        final index = entry.key;
                        final label = entry.value;
                        // Compute how "selected" this tab is (1.0 = fully selected)
                        final distance = (animValue - index).abs();
                        final selected = (1.0 - distance).clamp(0.0, 1.0);

                        final hasLiveIndicator = index == 1 && _liveEvents.isNotEmpty;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => _tabController!.animateTo(index),
                            child: Container(
                              height: 30,
                              color: Colors.transparent,
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      label,
                                      style: GoogleFonts.ibmPlexSans(
                                        fontSize: lerpDouble(17, 15, selected)!,
                                        fontWeight: selected > 0.5 ? FontWeight.w500 : FontWeight.w400,
                                        color: Color.lerp(
                                          const Color(0xFF8C8C8C),
                                          Colors.black,
                                          selected,
                                        ),
                                      ),
                                    ),
                                    if (hasLiveIndicator) ...[
                                      const SizedBox(width: 5),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFF4444),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEventList(List<ClubEvent> events, String emptyMessage, String type) {
    if (events.isEmpty) {
      return _buildEmptyState(emptyMessage, type);
    }

    final showButton = _isAdmin && type == 'scheduled';
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.tealAccent,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        itemCount: events.length + (showButton ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == events.length && showButton) {
            return Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: Center(child: _buildCreateEventButton()),
            );
          }
          return _buildEventCard(events[index], type);
        },
      ),
    );
  }

  /// Empty state matching Figma (node 427:4377)
  Widget _buildEmptyState(String message, String type) {
    String subtitle;
    switch (type) {
      case 'scheduled':
        subtitle = _isAdmin
            ? 'Tap the button below to create one'
            : 'Check back later for new events';
        break;
      case 'live':
        subtitle = 'Events will appear here when they start';
        break;
      case 'past':
        subtitle = 'Completed events will appear here';
        break;
      default:
        subtitle = '';
    }

    return Column(
      children: [
        // Push content up from center — roughly 40% from top of available space
        const Spacer(flex: 3),
        // Icon container: 72x72, #1B1E24 bg, 20px radius
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF1B1E24),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: SvgPicture.asset(
              'icons/figma_icons/calendar.svg',
              width: 34,
              height: 34,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Heading: 22px w600 white
        Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: -0.3,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        // Subtitle: 15px w400 #8C8C8C
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF8C8C8C),
            height: 1.47,
          ),
        ),
        // Create Event button (admin only, upcoming tab only)
        if (_isAdmin && type == 'scheduled') ...[
          const Spacer(flex: 3),
          _buildCreateEventButton(),
        ],
        // Gap between button and navbar
        const Spacer(flex: 1),
      ],
    );
  }

  /// Create Event button matching Figma (node 416:4374)
  /// Auto-width, centered, pinned near bottom
  Widget _buildCreateEventButton() {
    return GestureDetector(
      onTap: _navigateToCreateEvent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF89F1EC),
          borderRadius: BorderRadius.circular(110),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'icons/figma_icons/plus.svg',
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
            ),
            const SizedBox(width: 8),
            Text(
              'Create Event',
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
    );
  }

  Widget _buildEventCard(ClubEvent event, String type) {
    final isLive = type == 'live';
    final playerCount = _eventPlayerCounts[event.id] ?? 0;

    // Format date/time
    final dateStr = DateFormat('MMM d, h:mm a').format(event.startTime).toLowerCase();

    // Build buy-in display
    String? buyInDisplay;
    if (event.gameType == 'cash' && event.stakes != null && event.stakes!.isNotEmpty) {
      buyInDisplay = event.stakes!;
    } else if (event.buyInAmount != null && event.buyInAmount! > 0) {
      buyInDisplay = '\$${event.buyInAmount!.toStringAsFixed(0)}';
    }

    // Player count label
    String playerLabel;
    switch (type) {
      case 'live':
        playerLabel = '$playerCount playing';
        break;
      case 'past':
        playerLabel = '$playerCount players';
        break;
      default:
        playerLabel = '$playerCount going';
    }

    return GestureDetector(
      onTap: () => _navigateToEventDetail(event),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF101115),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLive ? const Color(0xFFFF4444).withValues(alpha: 0.5) : Colors.black,
            width: isLive ? 1.5 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _navigateToEventDetail(event),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  // Top row: Event name + live badge or dots
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Live indicator dot
                      if (isLive) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4444),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF4444).withValues(alpha: 0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            event.name,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 17,
                              color: Colors.white,
                              fontWeight: FontWeight.w400,
                              height: 1.44,
                            ),
                          ),
                        ),
                      ),
                      // Game type pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B4341),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          event.gameType == 'cash' ? 'Cash' : 'Tournament',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 11,
                            color: const Color(0xFF89F1EC),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Separator
                  Container(
                    height: 1,
                    color: const Color(0xFF1C1F21),
                  ),

                  const SizedBox(height: 14),

                  // Date/time row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'Date',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 17,
                            color: const Color(0xFFB3B4B6),
                            fontWeight: FontWeight.w500,
                            height: 1.44,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          dateStr,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 17,
                            color: const Color(0xFFD3FFFD),
                            fontWeight: FontWeight.w500,
                            height: 1.44,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Buy-in row
                  if (buyInDisplay != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            event.gameType == 'cash' ? 'Stakes' : 'Buy-in',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 17,
                              color: const Color(0xFFB3B4B6),
                              fontWeight: FontWeight.w500,
                              height: 1.44,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            buyInDisplay,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 17,
                              color: const Color(0xFFD3FFFD),
                              fontWeight: FontWeight.w500,
                              height: 1.44,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Bottom row: player count
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 18,
                          color: const Color(0xFF808285),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              playerLabel,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 13,
                                color: const Color(0xFF808285),
                                fontWeight: FontWeight.w500,
                                height: 1.44,
                              ),
                            ),
                          ),
                        ),
                        // Location if available
                        if (event.location != null && event.location!.isNotEmpty) ...[
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: const Color(0xFF808285),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            event.location!,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 13,
                              color: const Color(0xFF808285),
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
      color: AppColors.tealAccent,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_dealers.isNotEmpty) ...[
            _buildSectionTitle('Active Dealers', _dealers.length),
            const SizedBox(height: 12),
            ..._dealers.map(_buildDealerCard),
            const SizedBox(height: 24),
          ],
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
          style: GoogleFonts.ibmPlexSans(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1E24),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF8C8C8C),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDealerCard(ClubMember dealer) {
    final isActive = _dealerTableAssignments.containsKey(dealer.userId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101115),
        borderRadius: BorderRadius.circular(16),
        border: isActive
            ? Border.all(color: const Color(0xFF54E98A).withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF89F1EC).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                (dealer.displayName ?? 'D')[0].toUpperCase(),
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 20,
                  color: const Color(0xFF89F1EC),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dealer.displayName ?? 'Unknown',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dealer.email ?? '',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    color: const Color(0xFF8C8C8C),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF54E98A).withValues(alpha: 0.15)
                  : const Color(0xFF1B1E24),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF54E98A) : const Color(0xFF8C8C8C),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isActive ? 'Active' : 'Idle',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 12,
                    color: isActive ? const Color(0xFF54E98A) : const Color(0xFF8C8C8C),
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
        color: const Color(0xFF101115),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD60A).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD60A).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mail_outline,
              color: Color(0xFFFFD60A),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invitation.email,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Invited ${_formatTimeAgo(invitation.createdAt)}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 12,
                    color: const Color(0xFF8C8C8C),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD60A).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Pending',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                color: const Color(0xFFFFD60A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _cancelInvitation(invitation),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFDA5B5E).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.close,
                color: Color(0xFFDA5B5E),
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
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF1B1E24),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Icon(
                Icons.person_outline,
                size: 34,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No dealers yet',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 22,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Invite dealers to help manage your tables',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              color: const Color(0xFF8C8C8C),
              fontWeight: FontWeight.w400,
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
        backgroundColor: const Color(0xFF101115),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Invite Dealer',
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the email address of the dealer you want to invite.',
              style: GoogleFonts.ibmPlexSans(
                color: const Color(0xFF8C8C8C),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.ibmPlexSans(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'dealer@example.com',
                hintStyle: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C)),
                filled: true,
                fillColor: const Color(0xFF1B1E24),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF8C8C8C)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C)),
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
              backgroundColor: const Color(0xFF89F1EC),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Send Invitation',
              style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600),
            ),
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
            backgroundColor: const Color(0xFF54E98A),
          ),
        );
      }

      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send invitation: $e'),
            backgroundColor: const Color(0xFFDA5B5E),
          ),
        );
      }
    }
  }

  Future<void> _cancelInvitation(ClubInvitation invitation) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF101115),
        title: Text(
          'Cancel Invitation?',
          style: GoogleFonts.ibmPlexSans(color: Colors.white),
        ),
        content: Text(
          'Cancel the invitation to ${invitation.email}?',
          style: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Keep',
              style: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDA5B5E)),
            child: Text(
              'Cancel Invitation',
              style: GoogleFonts.ibmPlexSans(),
            ),
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
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cancel invitation: $e'),
              backgroundColor: const Color(0xFFDA5B5E),
            ),
          );
        }
      }
    }
  }
}
