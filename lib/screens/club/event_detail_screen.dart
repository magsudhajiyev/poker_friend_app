import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
import '../../services/seat_service.dart';
import '../../services/dealer_service.dart';
import '../../models/seat_assignment.dart';
import 'event_attendees_screen.dart';
import 'club_dashboard_screen.dart';
import 'create_event_screen.dart';
import 'admin_table_management_screen.dart';
import 'admin_event_tables_screen.dart';
import 'member_table_view_screen.dart';
import 'member_event_tables_screen.dart';
import '../dealer/dealer_qr_scan_screen.dart';
import '../spectator/event_rankings_screen.dart';
import '../player/player_session_screen.dart';
import 'final_standings_screen.dart';
import '../../design_system/components/cards/error_state_card.dart';
import '../../l10n/app_localizations.dart';
import '../../services/currency_service.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/typography.dart';
import '../../design_system/constants/decorations.dart';
import '../../utils/user_facing_error.dart';

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
  String? _loadError;
  EventAttendance? _userAttendance;
  Map<AttendanceStatus, int> _attendanceCounts = {};
  List<EventAttendance> _goingMembers = [];
  late ClubEvent _event;
  bool _addedToCalendar = false;
  String? _calendarEventId;
  bool _isDealer = false;
  bool _isSeatedPlayer = false;
  bool _hasActiveSession = false;
  SeatAssignment? _currentSeat;
  StreamSubscription<List<EventAttendance>>? _attendanceSubscription;
  StreamSubscription<ClubEvent?>? _eventSubscription;
  StreamSubscription<List<SeatAssignment>>? _seatSubscription;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _loadData();
    _checkDealerStatus();
    _setupAttendanceListener();
    _setupEventListener();
    _setupSeatListener();
  }

  @override
  void dispose() {
    _attendanceSubscription?.cancel();
    _eventSubscription?.cancel();
    _seatSubscription?.cancel();
    super.dispose();
  }

  /// Setup real-time listener for user's seat status
  void _setupSeatListener() {
    _seatSubscription = SeatService.watchCurrentUserSeats().listen((seats) {
      if (!mounted) return;

      // Check if user has a joined seat in this event's tables
      final eventTableIds = _event.tableIds.toSet();
      final seatInEvent = seats.where((s) =>
          eventTableIds.contains(s.tableId) &&
          s.status == SeatStatus.joined
      ).firstOrNull;

      final isSeated = seatInEvent != null;
      final tableId = seatInEvent?.tableId;

      setState(() {
        _isSeatedPlayer = isSeated;
        _currentSeat = seatInEvent;
      });

      // Check if there's an active dealer session at the player's table
      if (isSeated && tableId != null) {
        _checkActiveSession(tableId);
      } else {
        setState(() => _hasActiveSession = false);
      }
    });
  }

  Future<void> _checkActiveSession(String tableId) async {
    try {
      final session = await DealerService.getActiveSessionForTable(
        clubId: widget.club.id,
        tableId: tableId,
      );
      if (mounted) {
        setState(() => _hasActiveSession = session != null);
      }
    } catch (_) {
      if (mounted) setState(() => _hasActiveSession = false);
    }
  }

  /// Setup real-time event listener for status changes
  void _setupEventListener() {
    _eventSubscription = EventService.watchEvent(
      widget.club.id,
      _event.id,
    ).listen((updatedEvent) {
      if (!mounted || updatedEvent == null) return;

      // Check if status changed
      final oldStatus = _event.status;
      final newStatus = updatedEvent.status;

      if (oldStatus != newStatus) {
        // Show notification for status change
        String message;
        Color bgColor;

        final l10n = AppLocalizations.of(context);
        if (newStatus == EventStatus.active) {
          message = l10n.eventDetailLiveNow;
          bgColor = AppColors.buttonPrimary;
        } else if (newStatus == EventStatus.completed) {
          message = l10n.eventDetailEnded;
          bgColor = Colors.white.withOpacity(0.3);
        } else if (newStatus == EventStatus.cancelled) {
          message = l10n.eventDetailCancelled;
          bgColor = AppColors.lossRed;
        } else if (newStatus == EventStatus.paused) {
          message = l10n.eventDetailPaused;
          bgColor = Colors.amber;
        } else {
          message = l10n.eventDetailStatusUpdated;
          bgColor = Colors.white.withOpacity(0.2);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: bgColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      setState(() {
        _event = updatedEvent;
      });
    });
  }

  /// Setup real-time attendance listener
  void _setupAttendanceListener() {
    _attendanceSubscription = EventAttendanceService.watchEventAttendance(
      widget.club.id,
      _event.id,
    ).listen((attendances) {
      if (!mounted) return;

      // Calculate counts
      final counts = <AttendanceStatus, int>{
        AttendanceStatus.going: 0,
        AttendanceStatus.maybe: 0,
        AttendanceStatus.notGoing: 0,
      };
      for (final a in attendances) {
        counts[a.status] = (counts[a.status] ?? 0) + 1;
      }

      // Get going members
      final goingMembers = attendances
          .where((a) => a.status == AttendanceStatus.going)
          .toList();

      // Find current user's attendance
      final userId = AuthService.userId;
      final userAttendance = userId != null
          ? attendances.where((a) => a.userId == userId).firstOrNull
          : null;

      setState(() {
        _attendanceCounts = counts;
        _goingMembers = goingMembers;
        if (userAttendance != null) {
          _userAttendance = userAttendance;
          _addedToCalendar = userAttendance.addedToCalendar;
          _calendarEventId = userAttendance.calendarEventId;
        }
      });
    });
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
      // debugPrint('Error checking dealer status: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

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
      // debugPrint('Error loading event data: $e');
      setState(() {
        _loadError = e.toString();
        _isLoading = false;
      });
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
            SnackBar(
              content: Text(AppLocalizations.of(context).eventDetailRemovedFromCalendar),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // Notify admin about the RSVP
      final memberName = AuthService.userDisplayName ?? 'A member';
      final l10n = AppLocalizations.of(context);
      String rsvpStatusText;
      switch (status) {
        case AttendanceStatus.going:
          rsvpStatusText = l10n.eventDetailRsvpGoing;
          break;
        case AttendanceStatus.maybe:
          rsvpStatusText = l10n.eventDetailRsvpMaybe;
          break;
        case AttendanceStatus.notGoing:
          rsvpStatusText = l10n.eventDetailRsvpCantGo;
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
        SnackBar(content: Text(AppLocalizations.of(context).eventDetailRsvpFailed('${UserFacingError.message(e)}'))),
      );
    }
  }

  Future<void> _startEvent() async {
    // Block if no tables assigned
    if (_event.tableIds.isEmpty) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.neutral800,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDecorations.radius18),
          ),
          title: Text(
            AppLocalizations.of(context).eventDetailCantStartTitle,
            style: AppTypography.ibm(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            AppLocalizations.of(context).eventDetailCantStartBody,
            style: AppTypography.ibm(
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.buttonPrimary,
              ),
              child: Text(
                AppLocalizations.of(context).commonOk,
                style: AppTypography.ibm(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

    try {
      await EventService.startEvent(widget.club.id, _event.id);
      // Refresh event data
      final updatedEvent = await EventService.getEvent(widget.club.id, _event.id);
      if (updatedEvent != null) {
        setState(() => _event = updatedEvent);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).eventDetailStarted)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).eventDetailStartFailed('${UserFacingError.message(e)}'))),
      );
    }
  }

  Future<void> _cancelOrFinishEvent() async {
    // Determine if this is a live event (active or paused) or a scheduled event
    final isLive = _event.status == EventStatus.active ||
        _event.status == EventStatus.paused;

    final l10n = AppLocalizations.of(context);
    final dialogTitle = isLive ? l10n.eventDetailFinishTitle : l10n.eventDetailCancelTitle;
    final dialogContent = isLive
        ? l10n.eventDetailFinishBody
        : l10n.eventDetailCancelBody;
    final confirmButtonText = isLive ? l10n.eventDetailFinishButton : l10n.eventDetailCancelButton;
    final keepButtonText = l10n.eventDetailKeepEvent;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radius18),
        ),
        title: Text(
          dialogTitle,
          style: AppTypography.ibm(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          dialogContent,
          style: AppTypography.ibm(
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              keepButtonText,
              style: AppTypography.ibm(
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: isLive ? AppColors.buttonPrimary : AppColors.lossRed,
            ),
            child: Text(
              confirmButtonText,
              style: AppTypography.ibm(
                fontWeight: FontWeight.w600,
              ),
            ),
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
          SnackBar(content: Text(AppLocalizations.of(context).eventDetailFailedFinishCancel(isLive ? "finish" : "cancel", UserFacingError.message(e)))),
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
          SnackBar(
            content: Text(AppLocalizations.of(context).eventDetailAddedToCalendar),
            backgroundColor: AppColors.buttonPrimary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).eventDetailCalendarFailed('${UserFacingError.message(e)}')),
            backgroundColor: AppColors.lossRed,
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
    final screenWidth = MediaQuery.of(context).size.width;
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
        backgroundColor: AppColors.paper,
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
                      AppColors.headerGradientTeal.withOpacity(0.6),
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
                  Expanded(
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: AppColors.buttonPrimary,
                            ),
                          )
                        : _loadError != null
                            ? ErrorStateCard(onRetry: _loadData)
                            : SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Event status badge
                                _buildStatusBadge(),
                                const SizedBox(height: 10),

                                // Event name
                                Text(
                                  _event.name,
                                  style: AppTypography.ibm(
                                    fontSize: 24,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Combined notification + date/time card (for seated live events)
                                // or standalone date/time card
                                _buildEventInfoCard(dateFormat, timeFormat),

                                // Location card
                                if (_event.location != null && _event.location!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoCard(
                                    icon: Icons.location_on_outlined,
                                    title: AppLocalizations.of(context).eventDetailLocation,
                                    content: Text(
                                      _event.location!,
                                      style: AppTypography.ibm(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],

                                // Buy-in card
                                if (!_event.isFree) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoCard(
                                    icon: Icons.attach_money,
                                    title: AppLocalizations.of(context).eventDetailBuyIn,
                                    content: Text(
                                      CurrencyService.formatCash((_event.buyInAmount ?? 0).toDouble()),
                                      style: AppTypography.ibm(
                                        color: AppColors.buttonPrimary,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],

                                // Stakes card (cash games)
                                if (_event.gameType == 'cash' && _event.stakes != null && _event.stakes!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoCard(
                                    icon: Icons.casino_outlined,
                                    title: AppLocalizations.of(context).eventDetailStakes,
                                    content: Text(
                                      _event.stakes!,
                                      style: AppTypography.ibm(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],

                                // Starting stack card (tournaments)
                                if (_event.gameType == 'tournament' && _event.startingStack != null && _event.startingStack! > 0) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoCard(
                                    icon: Icons.layers_outlined,
                                    title: AppLocalizations.of(context).eventDetailStartingStack,
                                    content: Text(
                                      '${_event.startingStack!.toStringAsFixed(0)}',
                                      style: AppTypography.ibm(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],

                                // Description
                                if (_event.description != null && _event.description!.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    AppLocalizations.of(context).eventDetailAbout,
                                    style: AppTypography.ibm(
                                      fontSize: 12,
                                      color: AppColors.limeGreen,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _event.description!,
                                    style: AppTypography.ibm(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.7),
                                      height: 1.4,
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 16),

                                // RSVP section
                                if (_event.status == EventStatus.scheduled)
                                  _buildRSVPSection(),

                                // Start Dealing button (for dealers during live tournament events)
                                if (_isDealer && _event.isLive && _event.gameType == 'tournament') ...[
                                  const SizedBox(height: 10),
                                  _buildStartDealingButton(),
                                ],

                                // View Rankings button (for everyone during live tournament events)
                                if (_event.isLive && _event.gameType == 'tournament') ...[
                                  const SizedBox(height: 8),
                                  _buildViewRankingsButton(),
                                ],

                                // Manage Tables button (for admins on live cash games)
                                if (widget.isAdmin && _event.isLive && _event.gameType == 'cash') ...[
                                  const SizedBox(height: 8),
                                  _buildManageTablesButton(),
                                ],

                                // For cash games (non-admins only): Show "You're Seated" if seated, otherwise "See Availability"
                                if (_event.isLive && _event.gameType == 'cash' && !widget.isAdmin) ...[
                                  const SizedBox(height: 8),
                                  if (_isSeatedPlayer)
                                    _buildYouAreSeatedIndicator()
                                  else
                                    _buildSeeAvailabilityButton(),
                                ],

                                // Return to my seat button (ONLY for tournaments, not cash games)
                                if (_event.isLive && _isSeatedPlayer && _hasActiveSession && _event.gameType == 'tournament') ...[
                                  const SizedBox(height: 8),
                                  _buildReturnToSeatButton(),
                                ],

                                // View Final Standings button (for completed tournaments only)
                                if (_event.status == EventStatus.completed && _event.gameType == 'tournament') ...[
                                  const SizedBox(height: 8),
                                  _buildViewFinalStandingsButton(),
                                ],

                                // Add to Calendar button
                                const SizedBox(height: 12),
                                _buildAddToCalendarButton(),

                                const SizedBox(height: 16),

                                // Attendance preview
                                _buildAttendancePreview(),

                                // Admin actions
                                if (widget.isAdmin) ...[
                                  const SizedBox(height: 20),
                                  _buildAdminActions(),
                                ],

                                const SizedBox(height: 24),
                              ],
                            ),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: _navigateBackToClub,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.surfaceDark,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Club name
          Expanded(
            child: Text(
              widget.club.name,
              style: AppTypography.ibm(
                fontSize: 27,
                color: Colors.white,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Edit button - only for admins on scheduled events
          if (widget.isAdmin && _event.status == EventStatus.scheduled)
            GestureDetector(
              onTap: _editEvent,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceDark,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit,
                  color: AppColors.buttonPrimary,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _editEvent() async {
    final result = await showCreateEventDrawer(
      context,
      club: widget.club,
      event: _event,
    );

    // Refresh data if event was edited
    if (result == true && mounted) {
      _loadData();
    }
  }

  Widget _buildStatusBadge() {
    Color bgColor;
    Color textColor;
    String text;

    final l10n = AppLocalizations.of(context);
    if (_event.isLive) {
      bgColor = const Color(0xFFEE3E1A);
      textColor = Colors.white;
      text = l10n.eventDetailLiveBadge;
    } else if (_event.status == EventStatus.cancelled) {
      bgColor = Colors.white.withOpacity(0.1);
      textColor = Colors.white.withOpacity(0.5);
      text = l10n.eventDetailCancelledBadge;
    } else if (_event.status == EventStatus.completed) {
      bgColor = Colors.white.withOpacity(0.1);
      textColor = Colors.white.withOpacity(0.7);
      text = l10n.eventDetailCompletedBadge;
    } else {
      bgColor = AppColors.buttonPrimary.withOpacity(0.2);
      textColor = AppColors.buttonPrimary;
      text = l10n.eventDetailUpcomingBadge;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(140),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_event.isLive) ...[
            Container(
              width: 3,
              height: 3,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 2),
          ],
          Text(
            text,
            style: AppTypography.ibm(
              fontSize: 10,
              color: textColor,
              fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.buttonPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDecorations.radius10),
            ),
            child: Icon(
              icon,
              color: AppColors.buttonPrimary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.ibm(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
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

  Widget _buildEventInfoCard(DateFormat dateFormat, DateFormat timeFormat) {
    final showSeatedNotification = _isSeatedPlayer && _event.isLive;
    final endTimeText = _event.endTime != null
        ? ' - ${timeFormat.format(_event.endTime!)}'
        : '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 27, sigmaY: 27),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          decoration: BoxDecoration(
            color: const Color(0xFF292F33),
            borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 44,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Seated notification (if applicable)
              if (showSeatedNotification) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.mint800,
                        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
                      ),
                      child: const Icon(
                        Icons.event_seat,
                        color: AppColors.buttonPrimary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).eventDetailYoureSeatedGoodLuck,
                          style: AppTypography.ibm(
                            fontSize: 15,
                            color: Colors.white,
                            fontWeight: FontWeight.w400,
                            height: 1.64,
                          ),
                        ),
                        Text(
                          _getSeatedTableInfo(),
                          style: AppTypography.ibm(
                            fontSize: 13,
                            color: const Color(0xFFE6E6E7),
                            fontWeight: FontWeight.w500,
                            height: 1.44,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.neutral800, height: 1),
                const SizedBox(height: 16),
              ],

              // Date & Time section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).eventDetailDateAndTime,
                    style: AppTypography.ibm(
                      fontSize: 13,
                      color: const Color(0xFFB3B4B6),
                      fontWeight: FontWeight.w400,
                      height: 24 / 13,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFormat.format(_event.startTime),
                    style: AppTypography.ibm(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      height: 24 / 17,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    '${timeFormat.format(_event.startTime)}$endTimeText',
                    style: AppTypography.ibm(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getSeatedTableInfo() {
    if (_currentSeat != null) {
      final tableIndex = _event.tableIds.indexOf(_currentSeat!.tableId);
      final tableNum = tableIndex >= 0 ? tableIndex + 1 : 1;
      return AppLocalizations.of(context).eventDetailTableSeatInfo(tableNum.toString(), _currentSeat!.seatNumber);
    }
    return AppLocalizations.of(context).eventDetailSeated;
  }

  Widget _buildRSVPSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).eventDetailAreYouGoing,
          style: AppTypography.ibm(
            fontSize: 12,
            color: AppColors.limeGreen,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildRSVPButton(
                status: AttendanceStatus.going,
                icon: Icons.check_circle,
                label: AppLocalizations.of(context).eventDetailRsvpGoing,
                color: AppColors.buttonPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildRSVPButton(
                status: AttendanceStatus.maybe,
                icon: Icons.help_outline,
                label: AppLocalizations.of(context).eventDetailRsvpMaybe,
                color: Colors.amber,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildRSVPButton(
                status: AttendanceStatus.notGoing,
                icon: Icons.cancel_outlined,
                label: AppLocalizations.of(context).eventDetailRsvpCantGo,
                color: AppColors.lossRed,
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppDecorations.radius14),
          border: Border.all(
            color: isSelected ? color : Colors.white.withOpacity(0.06),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.white.withOpacity(0.4),
              size: 22,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTypography.ibm(
                fontSize: 13,
                color: isSelected ? color : Colors.white.withOpacity(0.5),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddToCalendarButton() {
    // Only show for upcoming/scheduled events (not live, completed, or cancelled)
    if (_event.status != EventStatus.scheduled) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: _addedToCalendar ? null : _addEventToCalendar,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _addedToCalendar
              ? Colors.white.withOpacity(0.05)
              : AppColors.buttonPrimary,
          borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _addedToCalendar ? Icons.check : Icons.calendar_today_outlined,
              color: _addedToCalendar ? Colors.white.withOpacity(0.4) : Colors.black,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              _addedToCalendar ? AppLocalizations.of(context).eventDetailAddedToCalendarBtn : AppLocalizations.of(context).eventDetailAddToCalendarBtn,
              style: AppTypography.ibm(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _addedToCalendar ? Colors.white.withOpacity(0.4) : Colors.black,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context).eventDetailWhosGoing,
                style: AppTypography.ibm(
                  fontSize: 17,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 24 / 17,
                  letterSpacing: -0.5,
                ),
              ),
              GestureDetector(
                onTap: _navigateToAttendees,
                child: Text(
                  AppLocalizations.of(context).eventDetailSeeAll,
                  style: AppTypography.ibm(
                    fontSize: 17,
                    color: AppColors.textMint,
                    fontWeight: FontWeight.w500,
                    height: 1.44,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: AppColors.separatorDark, height: 1),
          const SizedBox(height: 10),

          // Going row
          _buildAttendanceRow(
            label: AppLocalizations.of(context).eventDetailRsvpGoing,
            count: goingCount,
            countColor: AppColors.buttonPrimary,
          ),
          const SizedBox(height: 20),

          // Maybe row
          _buildAttendanceRow(
            label: AppLocalizations.of(context).eventDetailRsvpMaybe,
            count: maybeCount,
            countColor: const Color(0xFFE3FF68),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceRow({
    required String label,
    required int count,
    required Color countColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.ibm(
            fontSize: 17,
            color: const Color(0xFF9A9B9E),
            fontWeight: FontWeight.w500,
            height: 24 / 17,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          '$count',
          style: AppTypography.ibm(
            fontSize: 17,
            color: countColor,
            fontWeight: FontWeight.w500,
            height: 1.44,
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.buttonPrimary,
          borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.qr_code_scanner,
              color: Colors.black,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              AppLocalizations.of(context).eventDetailStartDealing,
              style: AppTypography.ibm(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
          border: Border.all(
            color: AppColors.buttonPrimary.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.leaderboard,
              color: AppColors.buttonPrimary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              AppLocalizations.of(context).eventDetailViewLiveRankings,
              style: AppTypography.ibm(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.buttonPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToMySeat() async {
    final userId = AuthService.userId;
    if (userId == null) return;

    try {
      // Get all seats where user is currently seated
      final seats = await SeatService.getCurrentUserAllSeats();

      if (seats.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).eventDetailNotSeatedAtTable),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Find seat in this event's tables
      final eventTableIds = _event.tableIds.toSet();
      final seatInEvent = seats.where((s) => eventTableIds.contains(s.tableId)).firstOrNull;

      if (seatInEvent == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).eventDetailNotSeatedInEvent),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Navigate to PlayerSessionScreen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerSessionScreen(
              clubId: seatInEvent.clubId,
              tableId: seatInEvent.tableId,
              seatNumber: seatInEvent.seatNumber,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).eventDetailErrorFindingSeat(UserFacingError.message(e))),
            backgroundColor: AppColors.lossRed,
          ),
        );
      }
    }
  }

  Widget _buildReturnToSeatButton() {
    return GestureDetector(
      onTap: _navigateToMySeat,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
          border: Border.all(
            color: AppColors.buttonPrimary.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.event_seat,
              color: AppColors.buttonPrimary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              AppLocalizations.of(context).eventDetailReturnToSeat,
              style: AppTypography.ibm(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.buttonPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewFinalStandingsButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FinalStandingsScreen(
              club: widget.club,
              event: _event,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
          border: Border.all(
            color: Colors.amber.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.emoji_events,
              color: Colors.amber,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              AppLocalizations.of(context).eventDetailViewFinalStandings,
              style: AppTypography.ibm(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.amber,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManageTablesButton() {
    return GestureDetector(
      onTap: () => _navigateToTableView(isAdmin: true),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.buttonPrimary,
          borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.table_restaurant,
              color: Colors.black,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              _event.tableIds.length > 1 ? AppLocalizations.of(context).eventDetailManageTables : AppLocalizations.of(context).eventDetailManageTable,
              style: AppTypography.ibm(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeeAvailabilityButton() {
    return GestureDetector(
      onTap: () => _navigateToTableView(isAdmin: false),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
          border: Border.all(
            color: AppColors.buttonPrimary.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.event_seat,
              color: AppColors.buttonPrimary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              AppLocalizations.of(context).eventDetailSeeAvailability,
              style: AppTypography.ibm(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.buttonPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Unclickable indicator shown when player is seated in a cash game
  Widget _buildYouAreSeatedIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.buttonPrimary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
        border: Border.all(
          color: AppColors.buttonPrimary.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle,
            color: AppColors.buttonPrimary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            AppLocalizations.of(context).eventDetailYoureSeated,
            style: AppTypography.ibm(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.buttonPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToTableView({required bool isAdmin}) async {
    if (_event.tableIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).eventDetailNoTablesAssigned),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;

    if (isAdmin) {
      if (_event.tableIds.length > 1) {
        // Multiple tables - show multi-table overview screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdminEventTablesScreen(
              club: widget.club,
              event: _event,
            ),
          ),
        );
      } else {
        // Single table - go directly to table management
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdminTableManagementScreen(
              club: widget.club,
              event: _event,
              tableId: _event.tableIds.first,
            ),
          ),
        );
      }
    } else {
      // Player view
      if (_event.tableIds.length > 1) {
        // Multiple tables - show multi-table overview screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MemberEventTablesScreen(
              club: widget.club,
              event: _event,
            ),
          ),
        );
      } else {
        // Single table - go directly to table view
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MemberTableViewScreen(
              club: widget.club,
              event: _event,
              tableId: _event.tableIds.first,
            ),
          ),
        );
      }
    }
  }

  Widget _buildAdminActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).eventDetailAdminActions,
          style: AppTypography.ibm(
            fontSize: 12,
            color: AppColors.limeGreen,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
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
                  label: AppLocalizations.of(context).eventDetailStartEvent,
                  color: AppColors.buttonPrimary,
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
                      ? AppLocalizations.of(context).eventDetailFinish
                      : AppLocalizations.of(context).commonCancel,
                  color: (_event.status == EventStatus.active ||
                          _event.status == EventStatus.paused)
                      ? AppColors.buttonPrimary
                      : AppColors.lossRed,
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
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppDecorations.radius14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.ibm(
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
