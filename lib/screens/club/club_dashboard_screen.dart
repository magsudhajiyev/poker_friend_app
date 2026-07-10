import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
import '../../services/app_data_cache.dart';
import '../../l10n/app_localizations.dart';
import '../../services/currency_service.dart';
import '../../widgets/global_bottom_nav_bar.dart';
import 'event_detail_screen.dart';
import 'create_event_screen.dart';
import 'club_settings_screen.dart';
import 'club_info_screen.dart';
import 'grouped_cash_game_screen.dart';
import '../../design_system/constants/typography.dart';
import '../../design_system/constants/decorations.dart';
import '../../utils/user_facing_error.dart';

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

  /// Cached grouped lane items for the Live tab. Recomputed only when
  /// `_liveEvents` changes (not on every player count update) so the Live tab
  /// doesn't re-sort/re-partition on every seat stream event.
  List<_LiveLaneItem> _liveLaneItems = const [];

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
    _restoreAdminStatus();
    _loadData();
    _setupEventsListener();
  }

  /// Restore admin status from SharedPreferences for instant UI (no flicker).
  Future<void> _restoreAdminStatus() async {
    final persisted = await AppDataCache.getPersistedAdminStatus(widget.club.id);
    if (persisted != null && mounted) {
      setState(() => _isAdmin = persisted);
    }
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
        _liveLaneItems = _groupLiveCashEventsByStakes(live);
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

    // Serve from cache if clean and populated (instant, no network)
    AppDataCache.setClubContext(widget.club.id);
    if (!AppDataCache.isClubDirty && AppDataCache.hasClubCacheData) {
      setState(() {
        _isAdmin = AppDataCache.cachedIsAdmin!;
        _memberCount = AppDataCache.cachedMemberCount!;
        _isLoading = false;
      });
      return;
    }

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
        _liveLaneItems = _groupLiveCashEventsByStakes(_liveEvents);
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

      // Write to cache (memory + disk)
      AppDataCache.cachedIsAdmin = isAdmin;
      AppDataCache.cachedMemberCount = results[0] as int;
      AppDataCache.clearClubDirty();
      AppDataCache.persistAdminStatus(widget.club.id, isAdmin);
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
      backgroundColor: AppColors.paper,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [

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
                          color: AppColors.accentPrimary,
                        ),
                      )
                    : _loadError != null
                        ? ErrorStateCard(onRetry: _loadData)
                        : TabBarView(
                        controller: _tabController!,
                        children: [
                          _buildEventList(_liveEvents, AppLocalizations.of(context).clubDashboardNoLiveEvents, 'live'),
                          _buildEventList(_upcomingEvents, AppLocalizations.of(context).clubDashboardNoUpcomingEvents, 'scheduled'),
                          _buildEventList(_pastEvents, AppLocalizations.of(context).clubDashboardNoPastEvents, 'past'),
                        ],
                      ),
              ),
            ],
          ),

          // Floating "Create Event" FAB — admin only, pinned to the same
          // bottom-right position across all 3 tabs (Live / Upcoming / Past)
          // so the admin never has to switch tabs to create an event. Matches
          // the Join Waitlist pill from grouped_cash_game_screen.dart.
          if (_isAdmin && !_isLoading && _loadError == null)
            Positioned(
              right: 20,
              bottom: MediaQuery.of(context).padding.bottom - 4,
              child: _buildCreateEventButton(),
            ),
        ],
      ),
      bottomNavigationBar: GlobalBottomNavBar(currentScreen: 'club'),
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
                    color: AppColors.surfaceDark,
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
                      style: AppTypography.ibm(
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
                          colorFilter: const ColorFilter.mode(AppColors.accentPrimary, BlendMode.srcIn),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          AppLocalizations.of(context).clubDashboardMemberCount(_memberCount),
                          style: AppTypography.ibm(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: AppColors.accentPrimary,
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
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(AppDecorations.radius20),
                    border: Border.all(
                      color: AppColors.accentPrimary,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star,
                        size: 14,
                        color: AppColors.accentPrimary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        AppLocalizations.of(context).clubDashboardAdmin,
                        style: AppTypography.ibm(
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
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(88),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      _isAdmin ? 'icons/figma_icons/gear.svg' : 'icons/figma_icons/info.svg',
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
    if (_isLoading) return; // Don't navigate until admin status is resolved
    if (_isAdmin) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ClubSettingsScreen(club: widget.club),
        ),
      ).then((_) { AppDataCache.markClubDirty(); _loadData(); });
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
    final tabs = [AppLocalizations.of(context).clubDashboardLive, AppLocalizations.of(context).clubDashboardUpcoming, AppLocalizations.of(context).clubDashboardPast];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(90),
          border: Border.all(
            color: AppColors.neutral700,
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
                          color: AppColors.accentPrimary,
                          borderRadius: BorderRadius.circular(AppDecorations.radius20),
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

                        final hasLiveIndicator = index == 0 && _liveEvents.isNotEmpty;
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
                                      style: AppTypography.ibm(
                                        fontSize: lerpDouble(17, 15, selected)!,
                                        fontWeight: selected > 0.5 ? FontWeight.w500 : FontWeight.w400,
                                        color: Color.lerp(
                                          AppColors.textDisabled,
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
                                          color: AppColors.lossRed,
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

    // Live tab: collapse multiple live cash events sharing the same stakes
    // into a single grouped card. Tournaments and solo cash events render
    // as regular event cards. Uses cached `_liveLaneItems` populated when
    // `_liveEvents` changes so we don't re-sort/re-partition on every seat
    // stream update.
    if (type == 'live') {
      final items = _liveLaneItems;
      return RefreshIndicator(
        onRefresh: () { AppDataCache.markClubDirty(); return _loadData(); },
        color: AppColors.accentPrimary,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return switch (item) {
              _SoloEventItem(:final event) => _buildEventCard(event, type),
              _StakesGroupItem() => _buildGroupedCashCard(item),
            };
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () { AppDataCache.markClubDirty(); return _loadData(); },
      color: AppColors.accentPrimary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        itemCount: events.length,
        itemBuilder: (context, index) => _buildEventCard(events[index], type),
      ),
    );
  }

  /// Partitions live events into a mix of solo event cards and stakes-group
  /// cards. ALL live cash events with stakes are routed through the grouped
  /// screen (even a single event) so the UX is consistent — players always
  /// see the same table-grid + waitlist flow for cash games. Tournaments and
  /// cash events with no stakes render as solo event cards.
  List<_LiveLaneItem> _groupLiveCashEventsByStakes(List<ClubEvent> live) {
    final groups = <String, List<ClubEvent>>{};
    final solo = <ClubEvent>[];

    for (final e in live) {
      final stakes = e.stakes?.trim();
      if (e.gameType == 'cash' && stakes != null && stakes.isNotEmpty) {
        groups.putIfAbsent(stakes.toLowerCase(), () => []).add(e);
      } else {
        solo.add(e);
      }
    }

    final items = <_LiveLaneItem>[];
    for (final entry in groups.entries) {
      // Preserve the first event's original casing for display.
      items.add(_StakesGroupItem(entry.value.first.stakes!.trim(), entry.value));
    }
    items.addAll(solo.map(_SoloEventItem.new));

    // Sort by freshest startTime first.
    items.sort((a, b) {
      final aTime = a is _SoloEventItem
          ? a.event.startTime
          : (a as _StakesGroupItem).events.first.startTime;
      final bTime = b is _SoloEventItem
          ? b.event.startTime
          : (b as _StakesGroupItem).events.first.startTime;
      return bTime.compareTo(aTime);
    });
    return items;
  }

  /// Collapsed "Cash Game $stakes" card shown on the Live tab when 2+ live
  /// cash events share the same stakes. Style matches `_buildEventCard` live
  /// variant but aggregates table/player counts across all events in the group.
  Widget _buildGroupedCashCard(_StakesGroupItem item) {
    final stakes = item.stakes;
    final events = item.events;
    final totalTables = events.fold<int>(0, (sum, e) => sum + e.tableIds.length);
    final totalPlaying = events.fold<int>(
      0,
      (sum, e) => sum + (_eventPlayerCounts[e.id] ?? 0),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        border: Border.all(
          color: AppColors.lossRed.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToGroupedCashGame(stakes, events),
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  // Top row: live dot + title + Cash pill
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.lossRed,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.lossRed.withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            AppLocalizations.of(context).clubDashboardCashGameStakes(stakes),
                            style: AppTypography.ibm(
                              fontSize: 17,
                              color: Colors.white,
                              fontWeight: FontWeight.w400,
                              height: 1.44,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.accentPrimary,
                          borderRadius: BorderRadius.circular(AppDecorations.radius10),
                        ),
                        child: Text(
                          AppLocalizations.of(context).clubDashboardCash,
                          style: AppTypography.ibm(
                            fontSize: 11,
                            color: AppColors.accentPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Container(height: 1, color: AppColors.separatorDark),
                  const SizedBox(height: 14),

                  // Tables row
                  _buildGroupedCashInfoRow(
                    AppLocalizations.of(context).clubDashboardTables,
                    '$totalTables table${totalTables == 1 ? '' : 's'}',
                  ),
                  const SizedBox(height: 6),
                  _buildGroupedCashInfoRow(AppLocalizations.of(context).clubDashboardStakes, stakes),

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
                              AppLocalizations.of(context).clubDashboardPlayingCount(totalPlaying),
                              style: AppTypography.ibm(
                                fontSize: 13,
                                color: const Color(0xFF808285),
                                fontWeight: FontWeight.w500,
                                height: 1.44,
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
      );
  }

  Widget _buildGroupedCashInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            label,
            style: AppTypography.ibm(
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
            value,
            style: AppTypography.ibm(
              fontSize: 17,
              color: AppColors.accentPrimary,
              fontWeight: FontWeight.w500,
              height: 1.44,
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToGroupedCashGame(String stakes, List<ClubEvent> events) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupedCashGameScreen(
          club: widget.club,
          stakes: stakes,
          events: events,
          isAdmin: _isAdmin,
        ),
      ),
    );
  }

  /// Empty state matching Figma (node 427:4377)
  Widget _buildEmptyState(String message, String type) {
    String subtitle;
    switch (type) {
      case 'scheduled':
        subtitle = _isAdmin
            ? AppLocalizations.of(context).clubDashboardCreateEventHint
            : AppLocalizations.of(context).clubDashboardCheckBackLater;
        break;
      case 'live':
        subtitle = AppLocalizations.of(context).clubDashboardEventsWillAppear;
        break;
      case 'past':
        subtitle = AppLocalizations.of(context).clubDashboardPastEventsWillAppear;
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
            color: AppColors.neutral800,
            borderRadius: BorderRadius.circular(AppDecorations.radius20),
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
          style: AppTypography.ibm(
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
          style: AppTypography.ibm(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: AppColors.textDisabled,
            height: 1.47,
          ),
        ),
        // Create Event button lives as a floating FAB in the outer Stack —
        // no longer inline in the empty state.
        const Spacer(flex: 4),
      ],
    );
  }

  /// Floating "Create Event" pill — visually matches the Join Waitlist FAB
  /// in grouped_cash_game_screen.dart (blurred dark surface, 1px white
  /// border, 58px radius, plus icon + white 14px w600 label).
  Widget _buildCreateEventButton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(58),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 37, sigmaY: 37),
        child: Material(
          color: AppColors.bgSurface.withValues(alpha: 0.85),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(58),
            side: const BorderSide(color: Colors.white, width: 1),
          ),
          child: InkWell(
            onTap: _navigateToCreateEvent,
            borderRadius: BorderRadius.circular(58),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context).eventManagementCreateEvent,
                    style: AppTypography.ibm(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: -0.5,
                      height: 1.0,
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
      buyInDisplay = CurrencyService.formatCash(event.buyInAmount!.toDouble());
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
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
          border: Border.all(
            color: isLive ? AppColors.lossRed.withValues(alpha: 0.5) : Colors.black,
            width: isLive ? 1.5 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _navigateToEventDetail(event),
            borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
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
                            color: AppColors.lossRed,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.lossRed.withValues(alpha: 0.5),
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
                            style: AppTypography.ibm(
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
                          color: AppColors.accentPrimary,
                          borderRadius: BorderRadius.circular(AppDecorations.radius10),
                        ),
                        child: Text(
                          event.gameType == 'cash' ? AppLocalizations.of(context).clubDashboardCash : AppLocalizations.of(context).setupTournament,
                          style: AppTypography.ibm(
                            fontSize: 11,
                            color: AppColors.accentPrimary,
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
                    color: AppColors.separatorDark,
                  ),

                  const SizedBox(height: 14),

                  // Date/time row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          AppLocalizations.of(context).clubDashboardDateLabel,
                          style: AppTypography.ibm(
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
                          style: AppTypography.ibm(
                            fontSize: 17,
                            color: AppColors.accentPrimary,
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
                            event.gameType == 'cash' ? AppLocalizations.of(context).eventDetailStakes : AppLocalizations.of(context).eventDetailBuyIn,
                            style: AppTypography.ibm(
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
                            style: AppTypography.ibm(
                              fontSize: 17,
                              color: AppColors.accentPrimary,
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
                              style: AppTypography.ibm(
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
                            style: AppTypography.ibm(
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
      onRefresh: () { AppDataCache.markClubDirty(); return _loadData(); },
      color: AppColors.accentPrimary,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_dealers.isNotEmpty) ...[
            _buildSectionTitle(AppLocalizations.of(context).clubDashboardActiveDealers, _dealers.length),
            const SizedBox(height: 12),
            ..._dealers.map(_buildDealerCard),
            const SizedBox(height: 24),
          ],
          if (_pendingInvitations.isNotEmpty) ...[
            _buildSectionTitle(AppLocalizations.of(context).clubDashboardPendingInvitations, _pendingInvitations.length),
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
          style: AppTypography.ibm(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.neutral800,
            borderRadius: BorderRadius.circular(AppDecorations.radius10),
          ),
          child: Text(
            '$count',
            style: AppTypography.ibm(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textDisabled,
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
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
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
              color: AppColors.accentPrimary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                (dealer.displayName ?? 'D')[0].toUpperCase(),
                style: AppTypography.ibm(
                  fontSize: 20,
                  color: AppColors.accentPrimary,
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
                  dealer.displayName ?? AppLocalizations.of(context).clubDashboardUnknownLabel,
                  style: AppTypography.ibm(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dealer.email ?? '',
                  style: AppTypography.ibm(
                    fontSize: 13,
                    color: AppColors.textDisabled,
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
                  : AppColors.neutral800,
              borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF54E98A) : AppColors.textDisabled,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isActive ? AppLocalizations.of(context).clubDashboardActiveLabel : AppLocalizations.of(context).clubDashboardIdleLabel,
                  style: AppTypography.ibm(
                    fontSize: 12,
                    color: isActive ? const Color(0xFF54E98A) : AppColors.textDisabled,
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
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
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
                  style: AppTypography.ibm(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppLocalizations.of(context).clubDashboardInvitedTimeAgo(_formatTimeAgo(invitation.createdAt)),
                  style: AppTypography.ibm(
                    fontSize: 12,
                    color: AppColors.textDisabled,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD60A).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
            ),
            child: Text(
              AppLocalizations.of(context).clubDashboardPendingLabel,
              style: AppTypography.ibm(
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
                borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
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
              color: AppColors.neutral800,
              borderRadius: BorderRadius.circular(AppDecorations.radius20),
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
            AppLocalizations.of(context).clubDashboardNoDealersYet,
            style: AppTypography.ibm(
              fontSize: 22,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).clubDashboardInviteDealersHint,
            style: AppTypography.ibm(
              fontSize: 15,
              color: AppColors.textDisabled,
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
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDecorations.radius20)),
        title: Text(
          AppLocalizations.of(context).clubDashboardInviteDealer,
          style: AppTypography.ibm(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).clubDashboardInviteDealerBody,
              style: AppTypography.ibm(
                color: AppColors.textDisabled,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              style: AppTypography.ibm(color: Colors.white),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).clubDashboardDealerEmailHint,
                hintStyle: AppTypography.ibm(color: AppColors.textDisabled),
                filled: true,
                fillColor: AppColors.neutral800,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textDisabled),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context).commonCancel,
              style: AppTypography.ibm(color: AppColors.textDisabled),
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
              backgroundColor: AppColors.accentPrimary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDecorations.radius10)),
            ),
            child: Text(
              AppLocalizations.of(context).clubDashboardSendInvitationBtn,
              style: AppTypography.ibm(fontWeight: FontWeight.w600),
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
            content: Text(AppLocalizations.of(context).clubDashboardInvitationSentTo(email)),
            backgroundColor: const Color(0xFF54E98A),
          ),
        );
      }

      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).clubDashboardFailedSendInvitationMsg(UserFacingError.message(e))),
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
        backgroundColor: AppColors.surfaceDark,
        title: Text(
          AppLocalizations.of(context).clubDashboardCancelInvitationTitle,
          style: AppTypography.ibm(color: Colors.white),
        ),
        content: Text(
          AppLocalizations.of(context).clubDashboardCancelInvitationBody(invitation.email),
          style: AppTypography.ibm(color: AppColors.textDisabled),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppLocalizations.of(context).clubDashboardKeepBtn,
              style: AppTypography.ibm(color: AppColors.textDisabled),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDA5B5E)),
            child: Text(
              AppLocalizations.of(context).clubDashboardCancelInvitationBtn,
              style: AppTypography.ibm(),
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
              content: Text(AppLocalizations.of(context).clubDashboardFailedCancelMsg(UserFacingError.message(e))),
              backgroundColor: const Color(0xFFDA5B5E),
            ),
          );
        }
      }
    }
  }
}

/// A render item in the Live tab: either a single event or a group of live
/// cash events sharing the same stakes.
sealed class _LiveLaneItem {
  const _LiveLaneItem();
}

class _SoloEventItem extends _LiveLaneItem {
  final ClubEvent event;
  const _SoloEventItem(this.event);
}

class _StakesGroupItem extends _LiveLaneItem {
  final String stakes;
  final List<ClubEvent> events;
  const _StakesGroupItem(this.stakes, this.events);
}
