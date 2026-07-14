import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/introduction_screen.dart';
import '../screens/logging_mode_selection_screen.dart';
import '../screens/session_history_screen.dart';
import '../screens/session_analytics_screen.dart';
import '../screens/statistics_screen.dart';
import '../screens/my_opponents_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/admin/club_requests_screen.dart';
import '../screens/admin/support_requests_screen.dart';
import '../services/support_request_service.dart';
import '../models/support_request.dart';
import '../screens/calendar_screen.dart';
import '../screens/earnings_chart_screen.dart';
import '../services/auth_service.dart';
import '../services/bankroll_service.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
import '../services/session_result_service.dart';
import '../services/play_style_detector.dart';
import '../services/currency_service.dart';
import '../screens/auth_screen.dart';
import '../widgets/looping_splash_logo.dart';
import '../services/calendar_event_service.dart';
import '../widgets/main_shell.dart';
import '../onboarding/onboarding_tour.dart';
import '../onboarding/onboarding_prefs.dart';
import 'paywall_screen.dart';
import '../onboarding/onboarding_state.dart';
import '../onboarding/onboarding_progress_bar.dart';
import '../design_system/design_system.dart';
import '../design_system/poker_friend_theme.dart';
import '../design_system/components/buttons/close_circle_button.dart';
import '../design_system/components/cards/swipe_to_delete_cell.dart';
import '../design_system/components/dialogs/app_dialog.dart';
import '../design_system/components/dialogs/dialog_action_bar.dart';
import '../design_system/components/modals/confirm_dialog.dart';
import '../design_system/components/drawer_dots.dart';
import '../design_system/components/cards/error_state_card.dart';
import '../services/seat_service.dart';
import '../services/table_service.dart';
import '../services/club_notification_service.dart';
import '../services/club_service.dart';
import '../services/event_service.dart';
import '../models/seat_assignment.dart';
import '../models/club_notification.dart';
import '../models/club.dart';
import '../design_system/components/overlays/sliding_notification.dart';
import '../widgets/navigation_drawer.dart';
import 'player/qr_scan_screen.dart';
import 'club/event_detail_screen.dart';
import 'event_detail_screen.dart' as personal_detail;
import 'club/club_dashboard_screen.dart';
import 'invitations_screen.dart';
import 'notifications_screen.dart';
import '../models/club_member.dart';
import '../services/invitation_service.dart';
import '../services/event_attendance_service.dart';
import '../models/event_attendance.dart';
import '../services/app_data_cache.dart';
import '../services/display_identity_service.dart';
import '../services/logger_service.dart';
import '../l10n/app_localizations.dart';
import '../utils/user_facing_error.dart';

/// Home screen
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _fabKey = GlobalKey(debugLabel: 'fab');
  final GlobalKey _sessionsNavKey = GlobalKey(debugLabel: 'sessionsNav');
  final GlobalKey _bankrollCardKey = GlobalKey(debugLabel: 'bankrollCard');
  int _currentIndex = 2;
  List<Map<String, dynamic>> upcomingEvents = [];
  Map<String, int> _eventGoingCounts = {};  // eventId -> going count

  // Seat assignment listener for dealer notifications
  StreamSubscription<List<SeatAssignment>>? _seatSubscription;
  Set<String> _notifiedSeatIds = {};
  bool _hasActiveSession = false;
  List<SeatAssignment> _activeSeats = [];

  // Club notification listener for event notifications
  StreamSubscription<List<ClubNotification>>? _clubNotificationSubscription;
  Set<String> _notifiedClubNotificationIds = {};
  List<ClubNotification> _allNotifications = [];  // All notifications to display
  int _unreadNotificationCount = 0;  // For badge only

  // Data variables
  double currentBankroll = 0.0;
  double bankrollGoal = 0.0;
  double bankrollProgress = 0.0;
  String userName = 'User';

  // Animation variables
  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;
  Map<String, dynamic> playerStats = {};
  List<Map<String, dynamic>> recentSessions = [];
  List<Map<String, dynamic>> earningsChartData = [];
  double avgEarnings = 0.0;
  bool isLoadingData = true;
  String? _loadError;
  bool _isBankrollHidden = false;

  // Play style tooltip overlay
  OverlayEntry? _playStyleTooltipEntry;
  final GlobalKey _playStyleInfoKey = GlobalKey(debugLabel: 'playStyleInfo');

  // Bankroll card inline edit (press-and-hold)
  final _editGoalController = TextEditingController();
  final _editBankrollController = TextEditingController();
  bool _isBankrollEditing = false;

  // Context menu state
  String? _selectedEventId;
  Offset? _popupPosition;


  @override
  void initState() {
    super.initState();
    LoggerService.logScreenView('home');

    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _loadBankrollVisibility();
    _loadData();
    _setupSeatListener();
    _scheduleOnboardingTour();
  }

  void _scheduleOnboardingTour() async {
    // Phase 5 — session result tour (user returned from a completed session)
    if (OnboardingState.isOnboardingActive && OnboardingState.currentPhase == 5) {
      // Wait for the Sessions nav key to attach
      final sessionsKey =
          MainShell.globalKey.currentState?.sessionsNavKey ?? _sessionsNavKey;
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        if (sessionsKey.currentContext != null) break;
      }
      if (!mounted || sessionsKey.currentContext == null) return;
      SessionResultTour(
        sessionsNavKey: sessionsKey,
        onComplete: () { if (mounted) setState(() {}); },
      ).show(context);
      return;
    }

    final seen = await OnboardingPrefs.hasSeenOnboarding();
    if (!mounted) return;
    if (seen) {
      // Tour skipped mid-way earlier — show the deferred post-tour paywall
      // once, then never again
      if (await OnboardingPrefs.isPostTourPaywallPending()) {
        await OnboardingPrefs.clearPostTourPaywallPending();
        final shown = await OnboardingPrefs.wasPostTourPaywallShown();
        if (!shown && mounted) {
          await OnboardingPrefs.markPostTourPaywallShown();
          if (mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => const PaywallScreen(showSkip: true),
              ),
            );
          }
        }
      }

      // Post-tour bankroll card tip — shown once after completing the tour
      if (await OnboardingPrefs.isBankrollTourPending()) {
        if (!mounted) return;
        // Wait for bankroll card to render
        for (int i = 0; i < 20; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          if (!mounted) return;
          if (_bankrollCardKey.currentContext != null) break;
        }
        if (mounted && _bankrollCardKey.currentContext != null) {
          BankrollCardTour(bankrollCardKey: _bankrollCardKey).show(context);
        }
      }
      return;
    }

    // Wait for the FAB key to be attached (nav bar may take a few frames)
    final fabKey = MainShell.globalKey.currentState?.fabKey ?? _fabKey;
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      if (fabKey.currentContext != null) break;
    }

    if (!mounted || fabKey.currentContext == null) return;
    OnboardingState.start();
    setState(() {}); // refresh to show progress bar
    HomeTour(fabKey: fabKey).show(context);
  }

  void _loadBankrollVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isBankrollHidden = prefs.getBool('bankroll_hidden') ?? false;
    });
  }

  /// Listen for seat assignments where the current user has been seated by a dealer
  void _setupSeatListener() {
    final userId = AuthService.userId;
    if (userId == null) return;

    // First pre-populate existing seats to avoid duplicate notifications
    SeatService.getCurrentUserAllSeats().then((existingSeats) {
      for (final seat in existingSeats) {
        _notifiedSeatIds.add(seat.id);
      }
    }).catchError((e) {
      debugPrint('Error pre-populating seats: $e');
    });

    // Set up real-time listener
    _seatSubscription = SeatService.watchCurrentUserSeats().listen((seats) {
      // Update active session state
      final hasActive = seats.isNotEmpty;
      if (_hasActiveSession != hasActive || _activeSeats.length != seats.length) {
        setState(() {
          _hasActiveSession = hasActive;
          _activeSeats = seats;
        });
      }

      for (final seat in seats) {
        if (!_notifiedSeatIds.contains(seat.id)) {
          _notifiedSeatIds.add(seat.id);
          _showSeatedNotification(seat);
        }
      }
    }, onError: (error) {
      debugPrint('Seat listener error: $error');
    });

    // Set up club notification listener for event notifications
    _setupClubNotificationListener();
  }

  /// Set up listener for club event notifications
  void _setupClubNotificationListener() {
    // Pre-populate existing notifications to avoid duplicate sliding alerts
    ClubNotificationService.getUserNotifications(limit: 50).then((existing) {
      for (final notification in existing) {
        _notifiedClubNotificationIds.add(notification.id);
      }
      // Also update unread notifications list
      _updateUnreadNotifications(existing);
    }).catchError((e) {
      debugPrint('Error pre-populating club notifications: $e');
    });

    // Set up real-time listener
    _clubNotificationSubscription = ClubNotificationService.watchUserNotifications(limit: 20).listen((notifications) {
      // Update unread notifications for badge
      _updateUnreadNotifications(notifications);

      // Show sliding notification for new ones
      for (final notification in notifications) {
        if (!_notifiedClubNotificationIds.contains(notification.id)) {
          _notifiedClubNotificationIds.add(notification.id);
          // Only show sliding notification if it's recent (within last 5 minutes)
          final age = DateTime.now().difference(notification.createdAt);
          if (age.inMinutes < 5) {
            _showClubEventNotification(notification);
          }
        }
      }
    }, onError: (error) {
      debugPrint('Club notification listener error: $error');
    });
  }

  /// Update notifications list and unread count
  void _updateUnreadNotifications(List<ClubNotification> notifications) {
    final unreadCount = notifications.where((n) => !n.isRead).length;
    // Always update - notifications content may have changed (e.g., isRead status)
    setState(() {
      _allNotifications = notifications;
      _unreadNotificationCount = unreadCount;
    });
  }

  /// Show a sliding notification for club events
  void _showClubEventNotification(ClubNotification notification) {
    if (!mounted) return;

    // Choose icon and color based on notification type
    IconData icon;
    Color iconColor;
    switch (notification.type) {
      case NotificationType.eventCreated:
        icon = Icons.event_available;
        iconColor = AppColors.profitGreen;
        break;
      case NotificationType.eventStarted:
        icon = Icons.play_circle_filled;
        iconColor = const Color(0xFF4CAF50);
        break;
      case NotificationType.eventStarting:
        icon = Icons.schedule;
        iconColor = const Color(0xFFFFA726);
        break;
      case NotificationType.eventUpdated:
        icon = Icons.update;
        iconColor = const Color(0xFF42A5F5);
        break;
      case NotificationType.eventCancelled:
        icon = Icons.event_busy;
        iconColor = const Color(0xFFEF5350);
        break;
      case NotificationType.memberRSVP:
        icon = Icons.how_to_reg;
        iconColor = const Color(0xFF9C27B0);
        break;
      case NotificationType.clubApproved:
        icon = Icons.check_circle;
        iconColor = const Color(0xFF4CAF50);
        break;
      case NotificationType.clubRejected:
        icon = Icons.cancel;
        iconColor = const Color(0xFFEF5350);
        break;
      case NotificationType.memberInvited:
        icon = Icons.mail;
        iconColor = const Color(0xFFA855F7);
        break;
      case NotificationType.invitationAccepted:
        icon = Icons.person_add;
        iconColor = const Color(0xFF4CAF50);
        break;
      case NotificationType.invitationDeclined:
        icon = Icons.person_off;
        iconColor = const Color(0xFFEF5350);
        break;
      case NotificationType.newClubRequest:
        icon = Icons.business;
        iconColor = const Color(0xFFF59E0B);
        break;
      case NotificationType.seatAvailable:
        icon = Icons.event_seat;
        iconColor = const Color(0xFF4CAF50);
        break;
      case NotificationType.newSupportRequest:
        icon = Icons.support_agent;
        iconColor = AppColors.accentPrimary;
        break;
      case NotificationType.supportRequestUpdated:
        icon = Icons.check_circle;
        iconColor = AppColors.accentPrimary;
        break;
      case NotificationType.partnerGranted:
        icon = Icons.card_giftcard;
        iconColor = AppColors.accentPrimary;
        break;
    }

    SlidingNotificationOverlay.show(
      context: context,
      title: notification.title,
      subtitle: notification.clubName,
      detail: notification.body,
      icon: icon,
      iconColor: iconColor,
      displayDuration: const Duration(seconds: 6),
      onTap: () {
        ClubNotificationService.markAsRead(notification.id);
        _handleNotificationTap(notification);
      },
    );
  }

  /// Show a sliding notification when user is seated by a dealer
  void _showSeatedNotification(SeatAssignment seat) async {
    if (!mounted) return;

    // Get event and table info for display and navigation
    final event = await EventService.getActiveEventForTable(seat.clubId, seat.tableId);
    final table = await TableService.getTable(seat.clubId, seat.tableId);
    final tableNumber = table?.tableNumber ?? 1;

    if (!mounted) return;

    SlidingNotificationOverlay.show(
      context: context,
      title: AppLocalizations.of(context).eventDetailYoureSeatedGoodLuck,
      subtitle: AppLocalizations.of(context).homeTableSeatInfo(tableNumber.toString(), seat.seatNumber.toString()),
      icon: Icons.event_seat,
      iconColor: AppColors.profitGreen,
      displayDuration: const Duration(seconds: 6),
      onTap: () async {
        if (event != null) {
          // Navigate to event details page
          final club = await ClubService.getClub(seat.clubId);
          if (club == null || !mounted) return;
          final isAdmin = await ClubService.canManageEvents(seat.clubId);
          if (!mounted) return;

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EventDetailScreen(
                club: club,
                event: event,
                isAdmin: isAdmin,
              ),
            ),
          );
        }
      },
    );
  }

  /// Navigate to the player session screen for the given seat
  void _navigateToPlayerSession(SeatAssignment seat) {
    Navigator.pushNamed(
      context,
      '/player_session',
      arguments: {
        'clubId': seat.clubId,
        'tableId': seat.tableId,
        'seatNumber': seat.seatNumber,
      },
    );
  }

  /// Build icon supporting both SVG and PNG formats
  Widget _buildIcon(String path, double size, Color color) {
    if (path.endsWith('.svg')) {
      return SvgPicture.asset(
        path,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    } else {
      return Image.asset(
        path,
        width: size,
        height: size,
        color: color,
      );
    }
  }

  /// Show active sessions dropdown
  void _showActiveSessionsDropdown(BuildContext context) {
    if (_activeSeats.isEmpty) {
      // No active sessions - show a message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).homeNoActiveSessions),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Get the button position for positioning the dropdown
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          // Dismiss on tap outside
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.transparent),
            ),
          ),
          // Dropdown positioned below the bell icon
          Positioned(
            top: buttonPosition.dy + 50,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: _buildSessionsDropdown(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsDropdown(BuildContext context) {
    return Container(
      width: 280,
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant4,
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.profitGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  AppLocalizations.of(context).homeLiveSessions,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_activeSeats.length}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Session list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _activeSeats.length,
              itemBuilder: (context, index) {
                final seat = _activeSeats[index];
                return _buildActiveSessionItem(context, seat);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSessionItem(BuildContext context, SeatAssignment seat) {
    final chipStackStr = seat.chipStack != null
        ? CurrencyService.formatCash(seat.chipStack!)
        : AppLocalizations.of(context).profileNotSet;

    return InkWell(
      onTap: () {
        Navigator.pop(context); // Close dropdown
        _navigateToPlayerSession(seat);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Table icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.profitGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
              ),
              child: const Icon(
                Icons.casino,
                color: AppColors.profitGreen,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            // Session details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    seat.tableId,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context).homeSeatInfoStr(seat.seatNumber, chipStackStr),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // Arrow
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// Navigate to the dedicated notifications screen
  void _showNotificationsDropdown(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationsScreen(),
      ),
    );
  }

  /// Handle notification tap based on type
  void _handleNotificationTap(ClubNotification notification) {
    switch (notification.type) {
      case NotificationType.memberInvited:
        _handleMemberInvitationTap(notification);
        break;
      case NotificationType.clubApproved:
        _navigateToClub(notification.clubId);
        break;
      case NotificationType.clubRejected:
        // Just show a message, nothing to navigate to
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(notification.body)),
        );
        break;
      case NotificationType.invitationAccepted:
      case NotificationType.invitationDeclined:
        // Navigate to club to see the member
        _navigateToClub(notification.clubId);
        break;
      case NotificationType.eventCreated:
      case NotificationType.eventUpdated:
      case NotificationType.eventCancelled:
      case NotificationType.eventStarting:
      case NotificationType.eventStarted:
      case NotificationType.memberRSVP:
        _navigateToEventFromNotification(notification);
        break;
      case NotificationType.newClubRequest:
        // Navigate to club requests screen for app admins
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ClubRequestsScreen(),
          ),
        );
        break;
      case NotificationType.seatAvailable:
        // Navigate to the event to claim the seat
        _navigateToEventFromNotification(notification);
        break;
      case NotificationType.newSupportRequest:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SupportRequestsScreen(),
          ),
        );
        break;
      case NotificationType.supportRequestUpdated:
        _showSupportResponseDialog(notification);
        break;
      case NotificationType.partnerGranted:
        // No navigation needed — the grant is already active
        break;
    }
  }

  void _showSupportResponseDialog(ClubNotification notification) async {
    final requestId = notification.data['requestId'] as String?;
    if (requestId == null) return;

    final request = await SupportRequestService.getRequest(requestId);
    if (!mounted || request == null) return;

    final isResolved = request.isResolved;

    AppDialog.show<void>(
      context,
      title: isResolved
          ? AppLocalizations.of(context).homeRequestResolved
          : AppLocalizations.of(context).homeRequestClosed,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isResolved ? Icons.check_circle : Icons.cancel,
                color: isResolved ? AppColors.accentPrimary : AppColors.errorRed,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  request.subject,
                  style: AppTypography.ibm(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            request.category,
            style: AppTypography.ibm(
              color: AppColors.textDisabled,
              fontSize: 13,
            ),
          ),
          if (request.adminResponse != null && request.adminResponse!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).homeResponse,
              style: AppTypography.ibm(
                color: AppColors.textDisabled,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isResolved
                    ? AppColors.accentPrimary.withValues(alpha: 0.1)
                    : AppColors.errorRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDecorations.radius10),
              ),
              child: Text(
                request.adminResponse!,
                style: AppTypography.ibm(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: const DialogActionBar.single(cancelLabel: 'OK'),
    );
  }

  /// Handle member invitation notification tap - show accept/decline dialog
  Future<void> _handleMemberInvitationTap(ClubNotification notification) async {
    if (notification.clubId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).homeClubNotFound)),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch club data
      final club = await ClubService.getClub(notification.clubId);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (club == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).homeClubNotFound)),
          );
        }
        return;
      }

      // Show accept/decline dialog
      if (mounted) {
        _showInvitationResponseDialog(notification, club);
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).commonErrorGeneric(UserFacingError.message(e)))),
        );
      }
    }
  }

  /// Show dialog to accept or decline invitation
  void _showInvitationResponseDialog(ClubNotification notification, Club club) {
    AppDialog.show<void>(
      context,
      title: AppLocalizations.of(context).homeClubInvitation,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.accentPurple.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mail,
              color: AppColors.accentPurple,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).homeYouveBeenInvitedToJoin,
            style: AppTypography.ibm(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            club.name,
            style: AppTypography.ibm(
              color: AppColors.accentPurple,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            notification.body,
            style: AppTypography.ibm(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: DialogActionBar(
        cancelLabel: AppLocalizations.of(context).homeDecline,
        confirmLabel: AppLocalizations.of(context).homeAccept,
        confirmColor: AppColors.accentPrimary,
        onCancel: () => _respondToInvitation(notification, club, false),
        onConfirm: () => _respondToInvitation(notification, club, true),
      ),
    );
  }

  /// Respond to invitation (accept or decline)
  Future<void> _respondToInvitation(ClubNotification notification, Club club, bool accept) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final userId = AuthService.userId;
      final l10n = AppLocalizations.of(context);
      final userName = AuthService.userDisplayName ?? l10n.homeUserFallback;

      if (userId == null) {
        throw 'Not authenticated';
      }

      if (accept) {
        // User is already a member (was added when invitation was sent)
        // Just notify admins and navigate to club

        // Notify club admins
        await _notifyClubAdmins(
          club: club,
          type: NotificationType.invitationAccepted,
          title: AppLocalizations.of(context).homeInvitationAccepted,
          body: '$userName has accepted the invitation to join ${club.name}.',
        );

        // Close loading dialog
        if (mounted) Navigator.pop(context);

        // Navigate to club
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClubDashboardScreen(club: club),
            ),
          );
        }
      } else {
        // User declined - remove them from club membership
        await ClubService.removeMember(club.id, userId);

        // Notify club admins
        await _notifyClubAdmins(
          club: club,
          type: NotificationType.invitationDeclined,
          title: AppLocalizations.of(context).homeInvitationDeclined,
          body: '$userName has declined the invitation to join ${club.name}.',
        );

        // Close loading dialog
        if (mounted) Navigator.pop(context);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).homeInvitationDeclined)),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).commonErrorGeneric(UserFacingError.message(e)))),
        );
      }
    }
  }

  /// Notify club admins about invitation response
  Future<void> _notifyClubAdmins({
    required Club club,
    required NotificationType type,
    required String title,
    required String body,
  }) async {
    try {
      // Get all club members who are owners or admins
      final members = await ClubService.getMembers(club.id);
      final adminUserIds = members
          .where((m) => m.role == ClubRole.owner || m.role == ClubRole.admin)
          .map((m) => m.userId)
          .whereType<String>()
          .toList();

      // Don't notify current user if they're an admin
      final currentUserId = AuthService.userId;
      adminUserIds.removeWhere((id) => id == currentUserId);

      // Send notification to each admin
      for (final adminId in adminUserIds) {
        await ClubNotificationService.notifyUser(
          userId: adminId,
          type: type,
          title: title,
          body: body,
          clubId: club.id,
          clubName: club.name,
          data: {
            'action': 'view_club',
            'clubId': club.id,
          },
        );
      }
    } catch (e) {
      // Don't fail the whole operation if notification fails
    }
  }

  /// Navigate to club dashboard
  Future<void> _navigateToClub(String clubId) async {
    if (clubId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).homeClubNotFound)),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final club = await ClubService.getClub(clubId);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (club == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).homeClubNotFound)),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClubDashboardScreen(club: club),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).commonErrorGeneric(UserFacingError.message(e)))),
        );
      }
    }
  }

  /// Navigate to event detail screen from notification
  Future<void> _navigateToEventFromNotification(ClubNotification notification) async {
    if (notification.eventId == null || notification.clubId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).homeEventNotFound)),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch club and event data AND check admin status BEFORE closing dialog
      // This ensures catch block can safely pop the dialog if any of these throw
      final club = await ClubService.getClub(notification.clubId);
      final event = await EventService.getEvent(notification.clubId, notification.eventId!);
      final isAdmin = await ClubService.canManageEvents(notification.clubId);

      // Close loading dialog AFTER all async operations complete
      if (mounted) Navigator.pop(context);

      if (club == null || event == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).homeEventNotFound)),
          );
        }
        return;
      }

      // Navigate to event detail
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventDetailScreen(
              club: club,
              event: event,
              isAdmin: isAdmin,
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog (safe because all async ops are before pop)
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).homeErrorLoadingEvent(UserFacingError.message(e)))),
        );
      }
    }
  }

  @override
  void dispose() {
    _seatSubscription?.cancel();
    _clubNotificationSubscription?.cancel();
    _playStyleTooltipEntry?.remove();
    _progressAnimationController.dispose();
    _editGoalController.dispose();
    _editBankrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Serve from cache if data hasn't changed since last fetch
      if (!AppDataCache.isHomeDirty && AppDataCache.hasHomeCacheData) {
        if (mounted) {
          setState(() {
            currentBankroll = AppDataCache.cachedBankroll!;
            bankrollGoal = AppDataCache.cachedBankrollGoal!;
            bankrollProgress = AppDataCache.cachedBankrollProgress!;
            playerStats = AppDataCache.cachedPlayerStats!;
            recentSessions = AppDataCache.cachedRecentSessions?.cast<Map<String, dynamic>>() ?? [];
            earningsChartData = AppDataCache.cachedEarningsData?['chartData'];
            avgEarnings = AppDataCache.cachedEarningsData?['avgEarnings'] ?? 0.0;
            upcomingEvents = AppDataCache.cachedUpcomingEvents?.cast<Map<String, dynamic>>() ?? [];
            userName = AppDataCache.cachedUserName ?? AppLocalizations.of(context).homeUserFallback;
            isLoadingData = false;
          });
          _progressAnimationController.reset();
          _progressAnimationController.forward();
          _loadEventAttendanceCounts();
          _checkPendingInvitations();
        }
        return;
      }

      setState(() {
        isLoadingData = true;
        _loadError = null;
      });

      // Pull bankroll from Firestore into SharedPreferences (handles reinstall)
      await BankrollService.syncFromFirestore();

      // All remaining reads are independent — fetch them in parallel
      // instead of serially awaiting each one (was the bulk of the
      // cold-start time alongside the removed stats verification dump)
      final results = await Future.wait<dynamic>([
        BankrollService.getCurrentBankroll()
            .timeout(const Duration(seconds: 10), onTimeout: () => 0.0),
        BankrollService.getBankrollGoal()
            .timeout(const Duration(seconds: 10), onTimeout: () => 0.0),
        BankrollService.getBankrollProgress()
            .timeout(const Duration(seconds: 10), onTimeout: () => 0.0),
        BankrollService.getPlayerStatistics()
            .timeout(const Duration(seconds: 10), onTimeout: () => {}),
        _getRecentSessions()
            .timeout(const Duration(seconds: 10), onTimeout: () => []),
        _getEarningsData().timeout(const Duration(seconds: 10),
            onTimeout: () => {'chartData': null, 'avgEarnings': 0.0}),
        _loadCalendarEvents()
            .timeout(const Duration(seconds: 10), onTimeout: () => []),
        // Pre-load display identity cache (respects useNicknameInGame toggle)
        DisplayIdentityService.getDisplayIdentity(),
      ]);

      final bankroll = results[0] as double;
      final goal = results[1] as double;
      final progress = results[2] as double;
      final stats = Map<String, dynamic>.from(results[3] as Map);
      final sessions = List<Map<String, dynamic>>.from(
          (results[4] as List).whereType<Map<String, dynamic>>());
      final earningsData = Map<String, dynamic>.from(results[5] as Map);
      final events = List<Map<String, dynamic>>.from(
          (results[6] as List).whereType<Map<String, dynamic>>());
      final displayName = DisplayIdentityService.cachedDisplayIdentity;

      if (mounted) {
        setState(() {
          currentBankroll = bankroll;
          bankrollGoal = goal;
          bankrollProgress = progress;
          playerStats = stats;
          recentSessions = sessions;
          earningsChartData = earningsData['chartData'];
          avgEarnings = earningsData['avgEarnings'];
          upcomingEvents = events;
          userName = displayName;
          isLoadingData = false;
        });

        // Store in cache
        AppDataCache.cachedBankroll = bankroll;
        AppDataCache.cachedBankrollGoal = goal;
        AppDataCache.cachedBankrollProgress = progress;
        AppDataCache.cachedPlayerStats = stats;
        AppDataCache.cachedRecentSessions = sessions;
        AppDataCache.cachedEarningsData = earningsData;
        AppDataCache.cachedUpcomingEvents = events;
        AppDataCache.cachedUserName = displayName;
        AppDataCache.clearHomeDirty();

        _progressAnimationController.reset();
        _progressAnimationController.forward();

        // Load attendance counts for events
        _loadEventAttendanceCounts();

        // Check for pending club invitations
        _checkPendingInvitations();
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        setState(() {
          isLoadingData = false;
          _loadError = e.toString();
        });
      }
    }
  }

  /// Check for pending club invitations and show dialog if any exist
  Future<void> _checkPendingInvitations() async {
    try {
      final invitations = await InvitationService.getPendingInvitations();
      if (invitations.isNotEmpty && mounted) {
        // Show a dialog prompting user to view their invitations
        AppDialog.show<void>(
          context,
          title: AppLocalizations.of(context).homeClubInvitations,
          body: Text(
            AppLocalizations.of(context).homePendingInvitationsMsg(invitations.length),
            style: AppTypography.ibm(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 22 / 15,
            ),
          ),
          actions: DialogActionBar(
            cancelLabel: AppLocalizations.of(context).homeLater,
            confirmLabel: AppLocalizations.of(context).homeViewInvitations,
            onConfirm: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const InvitationsScreen(),
                ),
              );
            },
          ),
        );
      }
    } catch (e) {
      // Silently fail - invitations are not critical
      debugPrint('Error checking invitations: $e');
    }
  }

  /// Load attendance counts for all upcoming events
  Future<void> _loadEventAttendanceCounts() async {
    for (final event in upcomingEvents) {
      final clubId = event['clubId'] as String?;
      final eventId = event['clubEventId'] as String?;

      if (clubId != null && eventId != null) {
        try {
          final counts = await EventAttendanceService.getAttendanceCounts(
            clubId,
            eventId,
          );
          final goingCount = counts[AttendanceStatus.going] ?? 0;

          if (mounted && goingCount > 0) {
            setState(() {
              _eventGoingCounts[eventId] = goingCount;
            });
          }
        } catch (e) {
          // Ignore errors for individual events
        }
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getRecentSessions() async {
    try {
      List<Map<String, dynamic>> sessions;
      try {
        sessions = await FirebaseService.getAllSessions();
      } catch (e) {
        sessions = await LocalStorageService.getUserSessions();
      }

      sessions.sort((a, b) {
        try {
          DateTime dateA = _parseSessionDate(a);
          DateTime dateB = _parseSessionDate(b);
          return dateB.compareTo(dateA);
        } catch (e) {
          return 0;
        }
      });

      return sessions.take(3).toList();
    } catch (e) {
      debugPrint('Error loading recent sessions: $e');
      return [];
    }
  }

  DateTime _parseSessionDate(Map<String, dynamic> session) {
    try {
      var createdAt = session['createdAt'];
      var timestamp = session['timestamp'];

      if (createdAt != null) {
        if (createdAt.runtimeType.toString().contains('Timestamp')) {
          return (createdAt as dynamic).toDate();
        }
        if (createdAt is DateTime) {
          return createdAt;
        }
        if (createdAt is String) {
          return DateTime.tryParse(createdAt) ?? DateTime(2000);
        }
      }

      if (timestamp != null) {
        if (timestamp.runtimeType.toString().contains('Timestamp')) {
          return (timestamp as dynamic).toDate();
        }
        if (timestamp is DateTime) {
          return timestamp;
        }
        if (timestamp is String) {
          return DateTime.tryParse(timestamp) ?? DateTime(2000);
        }
      }

      return DateTime(2000);
    } catch (e) {
      return DateTime(2000);
    }
  }

  Future<Map<String, dynamic>> _getEarningsData() async {
    try {
      final sessionResults = await SessionResultService.getAllSessionResults();

      final now = DateTime.now();
      final currentWeekday = now.weekday;
      final monday = now.subtract(Duration(days: currentWeekday - 1));
      final sunday = monday.add(Duration(days: 6));

      Map<String, Map<String, double>> dailyData = {};
      for (int i = 0; i < 7; i++) {
        final date = monday.add(Duration(days: i));
        final dateKey = DateFormat('MMM d').format(date);
        dailyData[dateKey] = {'tournament': 0.0, 'cash': 0.0, 'dateObj': date.millisecondsSinceEpoch.toDouble()};
      }

      for (var result in sessionResults) {
        DateTime date;
        if (result['timestamp'] != null) {
          date = (result['timestamp'] as Timestamp).toDate();
        } else if (result['createdAt'] != null) {
          date = DateTime.parse(result['createdAt']);
        } else {
          continue;
        }

        if (date.isBefore(monday) || date.isAfter(sunday.add(Duration(days: 1)))) continue;

        final dateKey = DateFormat('MMM d').format(date);
        final gameType = result['gameType'] as String? ?? 'cash';
        final amount = (result['amount'] as num?)?.toDouble() ?? 0.0;

        if (dailyData.containsKey(dateKey)) {
          dailyData[dateKey]![gameType] = (dailyData[dateKey]![gameType] ?? 0.0) + amount;
        }
      }

      List<Map<String, dynamic>> chartData = dailyData.entries.map((entry) {
        return {
          'date': entry.key,
          'tournament': entry.value['tournament']!,
          'cash': entry.value['cash']!,
          'dateObj': entry.value['dateObj']!,
        };
      }).toList();

      chartData.sort((a, b) => (a['dateObj'] as double).compareTo(b['dateObj'] as double));

      for (var item in chartData) {
        item.remove('dateObj');
      }

      double totalEarnings = sessionResults.fold(0.0, (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0.0));
      double avgEarnings = sessionResults.isNotEmpty ? totalEarnings / sessionResults.length : 0.0;

      return {
        'chartData': chartData,
        'avgEarnings': avgEarnings,
      };
    } catch (e) {
      debugPrint('Error getting earnings data: $e');
      return {
        'chartData': <Map<String, dynamic>>[],
        'avgEarnings': 0.0,
      };
    }
  }

  Future<List<Map<String, dynamic>>> _loadCalendarEvents() async {
    try {
      final events = await CalendarEventService.getUpcomingEvents();
      return events;
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingData && currentBankroll == 0.0 && recentSessions.isEmpty) {
      // Keep the logo animation looping through the whole loading course
      // instead of cutting to a static loader after the splash.
      return Scaffold(
        backgroundColor: AppColors.paper,
        body: Column(
          children: [
            const Expanded(child: LoopingSplashLogo()),
            Padding(
              padding: const EdgeInsets.only(bottom: 64),
              child: Text(
                AppLocalizations.of(context).homeLoadingPokerData,
                style: AppTypography.ibm(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_loadError != null && currentBankroll == 0.0 && recentSessions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.paper,
        body: ErrorStateCard(onRetry: _loadData),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.bgPrimary,
      extendBody: true,
      extendBodyBehindAppBar: true,
      drawer: AppNavigationDrawer(
        username: userName,
        email: AuthService.currentUser?.email,
      ),
      body: Builder(
        builder: (context) {
          final topPadding = MediaQuery.of(context).padding.top;
          final isAndroid = Theme.of(context).platform == TargetPlatform.android;
          final extraTopPadding = isAndroid ? 12.0 : 0.0;
          final headerHeight = topPadding + extraTopPadding + 62;

          return Stack(
            children: [
              // Full-screen scrollable content (behind header)
              RefreshIndicator(
                onRefresh: () {
                  AppDataCache.markHomeDirty();
                  return _loadData();
                },
                color: AppColors.accentPrimary,
                backgroundColor: const Color(0xFF1C2926),
                edgeOffset: headerHeight,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Space for header so content starts below it
                      SizedBox(height: headerHeight + 8),

                        // Bankroll Card (standalone)
                        _buildBankrollCard(),

                        const SizedBox(height: 8),

                        // Recent Activity (Stats Grid)
                        _buildStatsGrid(),

                        const SizedBox(height: 32),

                        // Earnings Chart
                        _buildEarningsCard(),

                        const SizedBox(height: 8),

                        // Recent Sessions
                        _buildRecentSessionsCard(),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),

              // Header overlay
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OnboardingProgressBar(),
                    _buildNewHeader(context, topPadding, extraTopPadding),
                  ],
                ),
              ),

              // Blur overlay when popup is visible
          if (_selectedEventId != null)
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedEventId = null;
                  _popupPosition = null;
                });
              },
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: Container(
                  color: Colors.black.withOpacity(0.0),
                ),
              ),
            ),

          // Positioned popup menu
          if (_selectedEventId != null && _popupPosition != null)
            Positioned(
              left: _popupPosition!.dx,
              top: _popupPosition!.dy,
              child: _buildEventContextMenu(),
            ),
          ],
        );
        },
      ),
    );
  }

  // ── Figma v2 Header ──────────────────────────────────────────────
  Widget _buildNewHeader(BuildContext context, double topPadding, double extraTopPadding) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          color: AppColors.bgPrimary.withValues(alpha: 0.6),
          padding: EdgeInsets.fromLTRB(16, topPadding + extraTopPadding + 6, 16, 12),
          child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo
          Image.asset('assets/icons/Logo horizontal-text.png', height: 38, fit: BoxFit.contain),

          // Right: bell + menu (Figma spec — 38×38 bgElevated circles, 8px gap)
          Row(
            children: [
              _TopNavCircleButton(
                onTap: () => _showNotificationsDropdown(context),
                svgAsset: 'icons/figma_icons/notification.svg',
                showBadge: _unreadNotificationCount > 0,
              ),
              const SizedBox(width: 8),
              _TopNavCircleButton(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
                svgAsset: 'assets/icons/card icons/List.svg',
              ),
            ],
          ),
        ],
      ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(35),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Home Icon
          IconButton(
            icon: Icon(Icons.home, color: Colors.white, size: 28),
            onPressed: () {
              // Already on home screen
            },
          ),
          // Opponents Icon
          IconButton(
            icon: Icon(Icons.group, color: Colors.white, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MyOpponentsScreen()),
              );
            },
          ),
          // Center Plus Button
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFA5EC44),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.add, color: Colors.black, size: 32),
              onPressed: () {
                Navigator.push(
                  context,
                  LoggingModeSelectionScreen.route(),
                );
              },
            ),
          ),
          // Game/Cards Icon
          IconButton(
            icon: Icon(Icons.style, color: Colors.white, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SessionHistoryScreen()),
              );
            },
          ),
          // Profile Icon
          IconButton(
            icon: Icon(Icons.person, color: Colors.white, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Profile Picture (frame)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              );
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ),

          // Right side icons
          Row(
            children: [
              // Statistics Icon
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => StatisticsScreen()),
                  );
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: _buildIcon(
                      'icons/flat_icons/stats.png',
                      26,
                      Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Notification Bell Icon with badge
              GestureDetector(
                onTap: () {
                  _showNotificationsDropdown(context);
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: _buildIcon(
                          'icons/flat_icons/bell.png',
                          26,
                          Colors.white,
                        ),
                      ),
                    ),
                    // Badge for unread notifications
                    if (_unreadNotificationCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF5350),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _unreadNotificationCount > 9 ? '9+' : '$_unreadNotificationCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
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
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final l10n = AppLocalizations.of(context);
    final playStyleName = _getPlayStyleName();
    final isUnknown = playStyleName.contains('/50');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            l10n.homeRecentActivity,
            style: AppTypography.ibm(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStatCell(
                      label: l10n.homePlayStyle,
                      value: playStyleName,
                      iconBg: AppColors.cardIconBlue,
                      icon: SvgPicture.asset(
                        'assets/icons/GameController.svg',
                        width: 18,
                        height: 18,
                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                      ),
                      onInfoTap: isUnknown ? _showPlayStyleTooltip : null,
                      infoKey: isUnknown ? _playStyleInfoKey : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildStatCell(
                      label: l10n.statsSessions,
                      value: '${playerStats['totalSessions'] ?? 0}',
                      iconBg: AppColors.cardIconPurple,
                      icon: SvgPicture.asset(
                        'assets/icons/DiceFour.svg',
                        width: 18,
                        height: 18,
                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCell(
                      label: l10n.homeWinRate,
                      value: '${(playerStats['winRate'] ?? 0.0).toStringAsFixed(0)}%',
                      iconBg: AppColors.cardIconOrange,
                      icon: SvgPicture.asset(
                        'assets/icons/Trophy.svg',
                        width: 18,
                        height: 18,
                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildStatCell(
                      label: l10n.homeHours,
                      value: '${(playerStats['totalHours'] ?? 0.0).toStringAsFixed(0)}',
                      iconBg: AppColors.cardIconRed,
                      icon: SvgPicture.asset(
                        'assets/icons/ClockUser.svg',
                        width: 18,
                        height: 18,
                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCell({
    required String label,
    required String value,
    required Color iconBg,
    required Widget icon,
    VoidCallback? onInfoTap,
    GlobalKey? infoKey,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderDefault, width: 1),
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(AppDecorations.radius10),
                ),
                child: Center(child: icon),
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.ibm(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: AppTypography.ibm(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (onInfoTap != null)
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                key: infoKey,
                onTap: onInfoTap,
                behavior: HitTestBehavior.opaque,
                child: SvgPicture.asset(
                  'assets/icons/Info.svg',
                  width: 16,
                  height: 16,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF9A9B9E), BlendMode.srcIn),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showPlayStyleTooltip() {
    if (_playStyleTooltipEntry != null) {
      _dismissPlayStyleTooltip();
      return;
    }

    final box = _playStyleInfoKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    // Top-center of the info icon in global coordinates
    final iconCenter = box.localToGlobal(Offset(box.size.width / 2, 0));
    final screenHeight = MediaQuery.of(context).size.height;
    final l10n = AppLocalizations.of(context)!;

    _playStyleTooltipEntry = OverlayEntry(
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _dismissPlayStyleTooltip,
        child: Stack(
          children: [
            Positioned(
              left: 16,
              right: 16,
              // Position the tooltip pill above the icon, leaving 6px gap for the arrow
              bottom: screenHeight - iconCenter.dy + 6,
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tooltip pill
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.bgElevated,
                        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                      ),
                      child: Row(
                        children: [
                          SvgPicture.asset(
                            'assets/icons/Info.svg',
                            width: 12,
                            height: 12,
                            colorFilter: const ColorFilter.mode(
                              AppColors.contentInactive, BlendMode.srcIn),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              l10n.homePlayStyleTooltip,
                              style: AppTypography.ibm(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                                height: 16 / 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Downward caret arrow aligned under the info icon
                    Padding(
                      padding: EdgeInsets.only(
                        left: (iconCenter.dx - 16 - 6).clamp(0.0, double.infinity),
                      ),
                      child: CustomPaint(
                        size: const Size(12, 6),
                        painter: _DownArrowPainter(),
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

    Overlay.of(context).insert(_playStyleTooltipEntry!);
  }

  void _dismissPlayStyleTooltip() {
    _playStyleTooltipEntry?.remove();
    _playStyleTooltipEntry = null;
  }

  Widget _buildBankrollCard() => _buildBankrollFront();

  void _startBankrollEdit() {
    _editBankrollController.text = currentBankroll > 0 ? currentBankroll.toStringAsFixed(0) : '';
    _editGoalController.text = bankrollGoal > 0 ? bankrollGoal.toStringAsFixed(0) : '';
    setState(() => _isBankrollEditing = true);
  }

  void _cancelBankrollEdit() {
    setState(() => _isBankrollEditing = false);
  }

  Future<void> _saveBankrollEdit() async {
    final newBankroll = double.tryParse(_editBankrollController.text);
    final newGoal = double.tryParse(_editGoalController.text);

    if (newBankroll != null) {
      await BankrollService.setCurrentBankroll(newBankroll);
    }
    if (newGoal != null) {
      await BankrollService.setBankrollGoal(newGoal);
    }

    AppDataCache.markHomeDirty();
    _loadData();
    setState(() => _isBankrollEditing = false);

    if (mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.bankrollSheetBankrollUpdated),
          backgroundColor: AppColors.accentPrimary,
        ),
      );
    }
  }

  Widget _buildBankrollFront() {
    final remaining = bankrollGoal - currentBankroll;
    final progress = bankrollGoal > 0
        ? (currentBankroll / bankrollGoal).clamp(0.0, 1.0)
        : 0.0;
    final progressPct = (progress * 100).toStringAsFixed(0);
    final blurFilter = _isBankrollHidden
        ? ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7)
        : ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0);

    final l10n = AppLocalizations.of(context);

    return GestureDetector(
      key: _bankrollCardKey,
      onLongPress: _isBankrollHidden ? null : _startBankrollEdit,
      // Opaque so press-and-hold works anywhere on the card, not only on
      // the text glyphs (deferToChild made the gesture feel broken).
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // "Total Bankroll" label
            Text(
              'Total Bankroll',
              style: AppTypography.ibm(
                fontSize: 10, fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 12),

            // Amount row + eye icon
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: ImageFiltered(
                    imageFilter: blurFilter,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: CurrencyService.formatBankroll(currentBankroll),
                              style: AppTypography.grotesk(
                                fontSize: 64, fontWeight: FontWeight.w600,
                                color: Colors.white, height: 1.0,
                              ),
                            ),
                            TextSpan(
                              text: '  of ${CurrencyService.formatBankroll(bankrollGoal)}',
                              style: AppTypography.grotesk(
                                fontSize: 24, fontWeight: FontWeight.w400,
                                color: AppColors.textSecondary, height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    setState(() {
                      _isBankrollHidden = !_isBankrollHidden;
                      if (_isBankrollHidden) _isBankrollEditing = false;
                    });
                    await prefs.setBool('bankroll_hidden', _isBankrollHidden);
                  },
                  child: _buildIcon('icons/figma_icons/eye.svg', 24, Colors.white),
                ),
              ],
            ),

            // Inline edit fields (shown on long-press)
            if (_isBankrollEditing) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildBankrollEditField(
                      label: l10n.bankrollSheetCurrentLabel,
                      controller: _editBankrollController,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildBankrollEditField(
                      label: l10n.bankrollSheetGoalLabel,
                      controller: _editGoalController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: l10n.commonCancel,
                      variant: AppButtonVariant.secondarySmall,
                      onTap: _cancelBankrollEdit,
                      fullWidth: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: l10n.commonSave,
                      variant: AppButtonVariant.primarySmall,
                      onTap: _saveBankrollEdit,
                      fullWidth: true,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 8),

            // "$X left" | "Y%" + progress bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ImageFiltered(
                    imageFilter: blurFilter,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${CurrencyService.formatBankroll(remaining)} left',
                          style: AppTypography.ibm(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '$progressPct%',
                          style: AppTypography.ibm(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ImageFiltered(
                    imageFilter: blurFilter,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppDecorations.navBarRadius),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: AppColors.borderStrong,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentPrimary),
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

  Widget _buildBankrollEditField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.ibm(
            fontSize: 11, fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
            border: Border.all(color: AppColors.borderStrong),
            color: AppColors.bgSurface,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.left,
            style: AppTypography.mono(
              fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white,
            ),
            decoration: InputDecoration(
              prefixText: CurrencyService.prefixText,
              suffixText: CurrencyService.suffixText,
              prefixStyle: AppTypography.mono(
                fontSize: 15, color: AppColors.contentInactive,
              ),
              suffixStyle: AppTypography.mono(
                fontSize: 15, color: AppColors.contentInactive,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onSubmitted: (_) => _saveBankrollEdit(),
          ),
        ),
      ],
    );
  }


  Widget _buildEarningsCard() {
    final l10n = AppLocalizations.of(context);
    final netProfit = earningsChartData.fold<double>(
      0.0,
      (sum, p) =>
          sum +
          ((p['tournament'] as num?)?.toDouble() ?? 0.0) +
          ((p['cash'] as num?)?.toDouble() ?? 0.0),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: "Earnings" left · net profit + label right
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.homeEarnings,
                    style: AppTypography.ibm(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      height: 20 / 17,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyService.formatCash(netProfit),
                      style: AppTypography.ibm(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentPrimary,
                        height: 1.44,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Net Profit',
                      style: AppTypography.ibm(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                        height: 16 / 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 19),
          // Legend + chart
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildLegendItem(l10n.homeTournament, AppColors.accentInfo),
                    const SizedBox(width: 17),
                    _buildLegendItem(l10n.homeCashGame, AppColors.accentPrimary),
                  ],
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => _showNoEarningsDataModal(),
                  child: SizedBox(
                    height: 167,
                    child: earningsChartData.isEmpty
                        ? Center(
                            child: Text(
                              l10n.homeNoEarningsDataYet,
                              style: AppTypography.listRowText(
                                color: Colors.white.withValues(alpha: 0.40),
                              ),
                            ),
                          )
                        : _buildEarningsLineChart(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNoEarningsDataModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(AppDecorations.radiusXl),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Close button
              Align(
                alignment: Alignment.centerRight,
                child: CloseCircleButton(onTap: () => Navigator.of(ctx).pop()),
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon container — Flutter color, no SVG asset caching
                  Center(
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                      ),
                      child: Center(
                        child: SvgPicture.string(
                          '''<svg width="24" height="24" viewBox="0 0 38 38" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M28 26.5H10V11.5" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M25.75 13.75L19 20.5L16 17.5L10 23.5" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M25.75 17.5V13.75H22" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''',
                          width: 24,
                          height: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No earning data yet',
                    textAlign: TextAlign.center,
                    style: AppTypography.ibm(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                      height: 1.44,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add some session results first to view your earnings chart. You can add results from the Profile page.',
                    textAlign: TextAlign.center,
                    style: AppTypography.ibm(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                      height: 22 / 15,
                    ),
                  ),
                  const SizedBox(height: 32),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.bgInverse,
                        borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
                      ),
                      child: Text(
                        'Ok',
                        textAlign: TextAlign.center,
                        style: AppTypography.ibm(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textInverse,
                          height: 20 / 15,
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
    );
  }

  Widget _buildEarningsLineChart() {
    // Build cumulative data
    final tournamentSpots = <FlSpot>[];
    final cashSpots = <FlSpot>[];
    double tournamentTotal = 0;
    double cashTotal = 0;

    for (int i = 0; i < earningsChartData.length; i++) {
      final point = earningsChartData[i];
      tournamentTotal += (point['tournament'] as num?)?.toDouble() ?? 0.0;
      cashTotal += (point['cash'] as num?)?.toDouble() ?? 0.0;
      tournamentSpots.add(FlSpot(i.toDouble(), tournamentTotal));
      cashSpots.add(FlSpot(i.toDouble(), cashTotal));
    }

    // Y bounds
    double rawMinY = 0, rawMaxY = 0;
    for (final s in [...tournamentSpots, ...cashSpots]) {
      if (s.y < rawMinY) rawMinY = s.y;
      if (s.y > rawMaxY) rawMaxY = s.y;
    }
    if (rawMaxY <= 0) rawMaxY = 50;
    if (rawMinY >= 0) rawMinY = -50;
    final yPad = (rawMaxY - rawMinY) * 0.1;
    final minY = rawMinY - yPad;
    final maxY = rawMaxY + yPad;
    final yRange = maxY - minY;
    final yInterval = yRange / 4;

    // X-axis date labels: first, middle, last — deduplicated
    final candidateIndices = earningsChartData.length <= 3
        ? List.generate(earningsChartData.length, (i) => i)
        : [0, earningsChartData.length ~/ 2, earningsChartData.length - 1];
    final shownDates = <String>{};
    final labelSet = <int>{};
    for (final i in candidateIndices) {
      final date = earningsChartData[i]['date'] ?? '';
      if (!shownDates.contains(date)) {
        shownDates.add(date);
        labelSet.add(i);
      }
    }

    return LineChart(
      LineChartData(
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withValues(alpha: 0.06),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: yInterval,
              reservedSize: 45,
              getTitlesWidget: (value, meta) {
                if (meta.axisPosition == 0 || meta.axisPosition == meta.parentAxisSize) {
                  return const SizedBox.shrink();
                }
                return Text(
                  CurrencyService.formatCash(value),
                  style: AppTypography.mono(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value != value.roundToDouble()) return const SizedBox.shrink();
                final idx = value.toInt();
                if (!labelSet.contains(idx)) return const SizedBox.shrink();
                if (idx < 0 || idx >= earningsChartData.length) return const SizedBox.shrink();
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 4,
                  child: Text(
                    earningsChartData[idx]['date'] ?? '',
                    style: AppTypography.mono(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: -0.5,
        maxX: (earningsChartData.length - 1).toDouble() + 0.5,
        minY: minY,
        maxY: maxY,
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          // Tournament line
          LineChartBarData(
            spots: tournamentSpots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.tournamentBlue,
            barWidth: 1.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 3,
                color: AppColors.tournamentBlue,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(show: false),
          ),
          // Cash line
          LineChartBarData(
            spots: cashSpots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.cashGameGreen,
            barWidth: 1.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 3,
                color: AppColors.cashGameGreen,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSessionsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row — "Recent Sessions" + "View all"
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context).homeRecentSessions,
                  style: AppTypography.ibm(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 20 / 17,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SessionHistoryScreen()),
                    );
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      AppLocalizations.of(context).homeViewAll,
                      style: AppTypography.ibm(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          if (recentSessions.isEmpty)
            _buildEmptyInfoCard(
              title: AppLocalizations.of(context).homeNoRecentSessions,
              subtitle: AppLocalizations.of(context).homeStartFirstSession,
              onAddTap: () {
                Navigator.push(
                  context,
                  LoggingModeSelectionScreen.route(),
                );
              },
            )
          else
            Column(
              children: recentSessions.take(3).map((session) {
                return SwipeToDeleteCell(
                  key: ValueKey('session-${session['id']}'),
                  onDelete: () => _confirmDeleteSession(session),
                  child: _buildSessionRow(session),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  /// Empty-state card matching Figma 1241:7989 (sessions) / 1241:8014 (events).
  /// Title + subtitle on the left, cyan-tinted "Add New +" pill on the right.
  Widget _buildEmptyInfoCard({
    required String title,
    required String subtitle,
    required VoidCallback onAddTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        border: Border.all(color: Colors.black, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.ibm(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    height: 1.44,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.ibm(
                    color: const Color(0xFFB3B4B6),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.44,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: onAddTap,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(AppDecorations.radius10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.of(context).homeAddNew,
                    style: AppTypography.ibm(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.add,
                    size: 18,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingEventsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with title and view all
        SectionHeadline(
          title: AppLocalizations.of(context).homeUpcomingEvents,
          actionText: AppLocalizations.of(context).homeViewAll,
          onActionPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CalendarScreen()),
            );
            _loadData();
          },
        ),
        const SizedBox(height: 8),
        // Content
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: upcomingEvents.isEmpty
              ? _buildEmptyInfoCard(
                  title: AppLocalizations.of(context).homeNoRecentEvents,
                  subtitle: AppLocalizations.of(context).homeAddFirstEvent,
                  onAddTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CalendarScreen()),
                    );
                    _loadData();
                  },
                )
              : Column(
                  children: upcomingEvents.take(3).map((event) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildEventCard(event),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  /// Confirms + deletes a session (invoked from the swipe-to-delete cell
  /// on Recent Sessions rows). Both Firebase and local mirror stores are
  /// removed, then the visible list is refreshed.
  Future<void> _confirmDeleteSession(Map<String, dynamic> session) async {
    final l10n = AppLocalizations.of(context);
    final sessionId = session['id'] as String?;
    if (sessionId == null) return;

    ConfirmDialog.show(
      context,
      title: l10n.sessionAnalyticsDeleteTitle,
      message: l10n.sessionAnalyticsDeleteMessage,
      confirmLabel: l10n.commonDelete,
      onConfirm: () async {
        try {
          await FirebaseService.deleteSession(sessionId);
          await LocalStorageService.deleteSession(sessionId);
        } catch (_) {}
        if (!mounted) return;
        setState(() {
          recentSessions.removeWhere((s) => s['id'] == sessionId);
        });
        AppDataCache.markSessionsDirty();
      },
    );
  }

  Widget _buildSessionRow(Map<String, dynamic> session) {
    String sessionName = session['sessionName'] ?? '';
    if (sessionName.isEmpty) {
      final createdAt = _parseSessionDate(session);
      final gameType = session['gameType'] ?? AppLocalizations.of(context).homePokerFallback;
      final dateStr = DateFormat('MMM d').format(createdAt);
      sessionName = '$gameType Session - $dateStr';
    }

    final createdAt = _parseSessionDate(session);
    final formattedDate = DateFormat('MMM d').format(createdAt);
    final isTournament = (session['gameType'] ?? 'cash').toLowerCase() == 'tournament';

    // Calculate duration
    String durationText = '';
    try {
      final start = _parseSessionDate(session);
      final endRaw = session['endTime'];
      if (endRaw != null) {
        DateTime end;
        if (endRaw is Timestamp) {
          end = endRaw.toDate();
        } else if (endRaw is String) {
          end = DateTime.parse(endRaw);
        } else {
          end = start;
        }
        final diff = end.difference(start);
        if (diff.inHours > 0) {
          durationText = '${diff.inHours}h ${diff.inMinutes % 60}m';
        } else {
          durationText = '${diff.inMinutes}m';
        }
      }
    } catch (_) {}

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SessionAnalyticsScreen(
            sessionData: session,
            sessionId: session['id'],
          ),
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.borderDefault, width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            // Session type icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
              ),
              child: Center(
                child: SvgPicture.asset(
                  isTournament ? 'assets/icons/Trophy.svg' : 'assets/icons/Coin.svg',
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(AppColors.textSecondary, BlendMode.srcIn),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name + profit + chips
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sessionName,
                    style: AppTypography.ibm(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 20 / 17,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (durationText.isNotEmpty)
                        _buildInfoChip(durationText),
                      if (durationText.isNotEmpty)
                        const SizedBox(width: 4),
                      _buildInfoChip(formattedDate),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Caret right
            const Icon(Icons.chevron_right, color: Color(0xFF808285), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
      ),
      child: Text(
        text,
        style: AppTypography.ibm(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
          height: 16 / 11,
        ),
      ),
    );
  }

  List<Widget> _buildEventsList() {
    List<Widget> widgets = [];
    final events = upcomingEvents.take(3).toList();

    for (int i = 0; i < events.length; i++) {
      widgets.add(_buildEventItem(events[i]));

      // Add divider between events (not after the last one)
      if (i < events.length - 1) {
        widgets.add(
          Container(
            height: 1,
            margin: EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.3),
                  Colors.white.withOpacity(0.1),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildEventItem(Map<String, dynamic> event) {
    final GlobalKey eventKey = GlobalKey();

    String formattedDate = '';
    try {
      final dateTime = DateTime.parse(event['date']);
      formattedDate = DateFormat('MMM dd, h:mma').format(dateTime).toLowerCase();
    } catch (e) {
      formattedDate = event['date'] ?? '';
    }

    // Get buy-in amount from event
    String buyIn = '';
    if (event['buyIn'] != null) {
      final buyInValue = event['buyIn'];
      if (buyInValue is num) {
        buyIn = CurrencyService.formatCash(buyInValue.toDouble());
      } else {
        buyIn = buyInValue.toString();
      }
    }

    // Get going count for this event
    final eventId = event['clubEventId'] as String?;
    final goingCount = eventId != null ? (_eventGoingCounts[eventId] ?? 0) : 0;

    return GestureDetector(
      key: eventKey,
      behavior: HitTestBehavior.opaque,
      onTap: () => _navigateToCalendarEventDetail(event),
      onLongPress: () {
        // Get the position of the card
        final RenderBox renderBox = eventKey.currentContext!.findRenderObject() as RenderBox;
        final cardPosition = renderBox.localToGlobal(Offset.zero);
        final cardSize = renderBox.size;

        // Position popup at top-right of the card
        final popupX = cardPosition.dx + cardSize.width - 184 - 16; // 184px menu width, 16px margin
        final popupY = cardPosition.dy;

        setState(() {
          _selectedEventId = event['id'];
          _popupPosition = Offset(popupX, popupY);
        });
      },
      child: Container(
        width: double.infinity,
        color: Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side: Event info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event['title'] ?? AppLocalizations.of(context).homeEventFallback,
                    style: AppTypography.ibm(
                      fontSize: 20,
                      color: Color(0xFFF8FFF7),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        formattedDate,
                        style: AppTypography.ibm(
                          fontSize: 12,
                          color: Color(0xFFF8FFF7),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                          height: 1.2,
                        ),
                      ),
                      if (goingCount > 0) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: PokerFriendColors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(AppDecorations.radius10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people,
                                size: 12,
                                color: PokerFriendColors.green,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                AppLocalizations.of(context).homeGoingCount(goingCount),
                                style: AppTypography.ibm(
                                  fontSize: 11,
                                  color: PokerFriendColors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Right side: Buy-in price
            if (buyIn.isNotEmpty)
              Text(
                buyIn,
                style: AppTypography.mono(
                  fontSize: 22,
                  color: AppColors.accentPrimary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                  height: 1.0,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    String formattedDate = '';
    try {
      final dateTime = DateTime.parse(event['date']);
      formattedDate = DateFormat('MMM dd, h:mm a').format(dateTime);
    } catch (e) {
      formattedDate = event['date'] ?? '';
    }

    String buyIn = '';
    if (event['buyIn'] != null) {
      final buyInValue = event['buyIn'];
      if (buyInValue is num) {
        buyIn = CurrencyService.formatCash(buyInValue.toDouble());
      } else {
        buyIn = buyInValue.toString();
      }
    }

    // User-created events store display string in 'type' (e.g. 'Tournament', 'Cash Game')
    // Club events store lowercase in 'gameType' (e.g. 'cash', 'tournament')
    final eventType = event['type'] as String?;
    final clubGameType = event['gameType'] as String?;
    final l10n = AppLocalizations.of(context);
    final gameType = eventType ?? switch (clubGameType) {
      'tournament' => l10n.homeTournament,
      'private' => l10n.homePrivateGame,
      _ => l10n.homeCashGame,
    };

    return GestureDetector(
      onTap: () => _navigateToCalendarEventDetail(event),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
          border: Border.all(color: Colors.black),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Game type pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(120),
              ),
              child: Text(
                gameType,
                style: AppTypography.infoCardPill(color: AppColors.accentPrimary),
              ),
            ),
            const SizedBox(height: 8),
            // Row 2: Event name + buy-in pill
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      event['title'] ?? AppLocalizations.of(context).homeEventFallback,
                      style: AppTypography.infoCardText(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (buyIn.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      buyIn,
                      style: AppTypography.ibm(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.eventBuyInText,
                        height: 1.44,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            // Row 3: Date
            Text(
              formattedDate,
              style: AppTypography.infoCardDate(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToCalendarEventDetail(Map<String, dynamic> event) async {
    final clubId = event['clubId'];
    final clubEventId = event['clubEventId'];

    // Personal event -> navigate to personal event detail
    if (clubId == null || clubEventId == null) {
      final date = DateTime.tryParse(event['date'] ?? '') ?? DateTime.now();
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => personal_detail.EventDetailScreen(
            title: event['title'] ?? AppLocalizations.of(context).homeEventFallback,
            type: event['type'] ?? '',
            location: event['location'] ?? '',
            date: date,
            buyIn: (event['buyIn'] as num?)?.toDouble() ?? 0,
          ),
        ),
      );
      _loadData();
      return;
    }

    try {
      // Fetch the club and event data
      final club = await ClubService.getClub(clubId);
      if (club == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).homeClubNotFound)),
          );
        }
        return;
      }

      final clubEvent = await EventService.getEvent(clubId, clubEventId);
      if (clubEvent == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).homeEventNotFound)),
          );
        }
        return;
      }

      // Check if user is admin
      final isAdmin = await ClubService.canManageEvents(clubId);

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EventDetailScreen(
            club: club,
            event: clubEvent,
            isAdmin: isAdmin,
          ),
        ),
      );

      // Refresh data after returning
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).homeFailedLoadEvent(UserFacingError.message(e)))),
        );
      }
    }
  }

  Widget _buildEventContextMenu() {
    if (_selectedEventId == null) return SizedBox.shrink();

    // Find the event data
    final event = upcomingEvents.firstWhere(
      (e) => e['id'] == _selectedEventId,
      orElse: () => {},
    );

    if (event.isEmpty) return SizedBox.shrink();

    final eventTitle = event['title'] ?? AppLocalizations.of(context).homeEventFallback;

    return AnimatedScale(
      scale: _selectedEventId != null ? 1.0 : 0.0,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _selectedEventId != null ? 1.0 : 0.0,
        duration: Duration(milliseconds: 300),
        child: Container(
          width: 184,
          decoration: BoxDecoration(
            color: Color(0xFF131613),
            borderRadius: BorderRadius.circular(AppDecorations.radius18),
          ),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Event title
              Text(
                eventTitle,
                style: AppTypography.ibm(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 14),

              // Menu items
              Column(
                children: [
                  // Edit Event
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedEventId = null;
                        _popupPosition = null;
                      });
                      _showEditEventDialog(event);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocalizations.of(context).homeEditEvent,
                            style: AppTypography.ibm(
                              fontSize: 14,
                              color: Color(0xFFEBFFEF),
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0,
                              height: 1.2,
                            ),
                          ),
                          Icon(
                            Icons.edit,
                            color: Color(0xFFEBFFEF),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Divider
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.3),
                          Colors.white.withOpacity(0.1),
                        ],
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),

                  // Delete Event
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedEventId = null;
                        _popupPosition = null;
                      });
                      _handleDeleteEvent(event['id'], event['title'] ?? AppLocalizations.of(context).homeEventFallback);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocalizations.of(context).homeDeleteEvent,
                            style: AppTypography.ibm(
                              fontSize: 14,
                              color: Color(0xFFEBFFEF),
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0,
                              height: 1.2,
                            ),
                          ),
                          Icon(
                            Icons.delete,
                            color: Color(0xFFEBFFEF),
                            size: 18,
                          ),
                        ],
                      ),
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

  void _showEditEventDialog(Map<String, dynamic> event) async {
    final titleController = TextEditingController(text: event['title'] ?? '');
    final locationController = TextEditingController(text: event['location'] ?? '');
    final buyInController = TextEditingController(text: event['buyIn']?.toString() ?? '');

    final eventDate = DateTime.parse(event['date']);
    DateTime dialogSelectedDate = eventDate;
    TimeOfDay selectedTime = TimeOfDay(hour: eventDate.hour, minute: eventDate.minute);
    String selectedType = event['type'] ?? 'Tournament';

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
                      borderRadius: BorderRadius.circular(AppDecorations.radius18),
                    ),
                    padding: EdgeInsets.fromLTRB(24, 32, 24, 32),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title and Close button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                AppLocalizations.of(context).homeEditEvent,
                                style: AppTypography.ibm(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ],
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
                                style: AppTypography.ibm(
                                  color: Color(0x99EBFFEF),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  height: 1.2,
                                ),
                                items: [
                                  AppLocalizations.of(context).homeEventTypeTournament,
                                  AppLocalizations.of(context).homeEventTypeCashGame,
                                  AppLocalizations.of(context).homeEventTypeHomeGame,
                                  AppLocalizations.of(context).homeEventTypeOnline,
                                ].map((type) => DropdownMenuItem(
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
                            style: AppTypography.ibm(
                              color: Color(0x99EBFFEF),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context).homeEventName,
                              hintStyle: AppTypography.ibm(
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
                            style: AppTypography.ibm(
                              color: Color(0x99EBFFEF),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context).homeLocationVenue,
                              hintStyle: AppTypography.ibm(
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
                            style: AppTypography.ibm(
                              color: Color(0x99EBFFEF),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context).homeBuyInAmount,
                              hintStyle: AppTypography.ibm(
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
                                    style: AppTypography.ibm(
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
                                    style: AppTypography.ibm(
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

                          // Save Changes Button
                          GestureDetector(
                            onTap: () async {
                              final title = titleController.text.trim();
                              if (title.isEmpty) return;

                              final eventDateTime = DateTime(
                                dialogSelectedDate.year,
                                dialogSelectedDate.month,
                                dialogSelectedDate.day,
                                selectedTime.hour,
                                selectedTime.minute,
                              );

                              try {
                                await CalendarEventService.updateEvent(
                                  eventId: event['id'],
                                  title: title,
                                  type: selectedType,
                                  location: locationController.text.trim(),
                                  date: eventDateTime,
                                  buyIn: double.tryParse(buyInController.text) ?? 0.0,
                                );

                                Navigator.pop(context);
                                _loadData();
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(AppLocalizations.of(context).homeFailedUpdateEvent(UserFacingError.message(e)))),
                                );
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Color(0xFFBAFF9A),
                                borderRadius: BorderRadius.circular(AppDecorations.radius10),
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                              child: Center(
                                child: Text(
                                  AppLocalizations.of(context).homeSaveChanges,
                                  style: AppTypography.ibm(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
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
                        borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
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
                                  AppLocalizations.of(context).homeSelectDate,
                                  style: AppTypography.ibm(
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
                                        Icon(Icons.close, color: AppColors.errorRed, size: 12),
                                        SizedBox(width: 4),
                                        Text(
                                          AppLocalizations.of(context).commonClear,
                                          style: AppTypography.ibm(
                                            color: AppColors.errorRed,
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
                                      borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.today, color: Color(0xFFFAFAFA), size: 12),
                                        SizedBox(width: 4),
                                        Text(
                                          AppLocalizations.of(context).commonToday,
                                          style: AppTypography.ibm(
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
                              borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
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
                                            style: AppTypography.ibm(
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
                                          style: AppTypography.ibm(
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
                                  borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Color(0xFF191F1B),
                                      borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
                                    ),
                                    child: Row(
                                      children: [AppLocalizations.of(context).weekdaySun, AppLocalizations.of(context).weekdayMon, AppLocalizations.of(context).weekdayTue, AppLocalizations.of(context).weekdayWed, AppLocalizations.of(context).weekdayThu, AppLocalizations.of(context).weekdayFri, AppLocalizations.of(context).weekdaySat]
                                          .map((day) => Expanded(
                                                child: Container(
                                                  height: 24,
                                                  decoration: BoxDecoration(
                                                    color: Color(0x0DFFFFFF),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      day,
                                                      style: AppTypography.ibm(
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
                                            style: AppTypography.ibm(
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
                                              ? AppColors.profitGreen
                                              : (isToday ? AppColors.surfaceVariant3 : Colors.transparent),
                                          borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
                                          border: isToday && !isSelected
                                              ? Border.all(color: AppColors.profitGreen, width: 1)
                                              : null,
                                        ),
                                        child: Center(
                                          child: Text(
                                            dayNumber.toString(),
                                            style: AppTypography.ibm(
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
                                      borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
                                    ),
                                    child: Center(
                                      child: Text(
                                        AppLocalizations.of(context).commonCancel,
                                        style: AppTypography.ibm(
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
                                        borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
                                      ),
                                      child: Center(
                                        child: Text(
                                          AppLocalizations.of(context).commonDone,
                                          style: AppTypography.ibm(
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

  void _handleDeleteEvent(String eventId, String eventName) {
    _showDeleteConfirmationDialog(eventId, eventName);
  }

  void _showDeleteConfirmationDialog(String eventId, String eventName) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.transparent,
      transitionDuration: Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          )),
          child: child,
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
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
              // Main dialog container
              Container(
                decoration: BoxDecoration(
                  color: Color(0xFF131613),
                  borderRadius: BorderRadius.circular(AppDecorations.radius18),
                ),
                padding: EdgeInsets.only(top: 24),
                child: Column(
                  children: [
                    // Title section
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        AppLocalizations.of(context).homeDeleteEventConfirm(eventName),
                        style: AppTypography.ibm(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                          height: 1.2,
                          decoration: TextDecoration.none,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    SizedBox(height: 24),

                    // Description section
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        AppLocalizations.of(context).homeDeleteEventDescription(eventName),
                        style: AppTypography.ibm(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.24,
                          height: 1.7,
                          decoration: TextDecoration.none,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    SizedBox(height: 16),

                    // Divider
                    Container(
                      height: 1,
                      color: Colors.white.withOpacity(0.1),
                    ),

                    SizedBox(height: 4),

                    // Delete button
                    GestureDetector(
                      onTap: () async {
                        Navigator.pop(context); // Close dialog
                        await _performDeleteEvent(eventId);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                        child: Text(
                          AppLocalizations.of(context).commonDelete,
                          style: AppTypography.ibm(
                            fontSize: 16,
                            color: AppColors.errorRed, // Red color
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                            height: 1.2,
                            decoration: TextDecoration.none,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 8),

              // Cancel button (separate container)
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF131613),
                    borderRadius: BorderRadius.circular(AppDecorations.radius18),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  width: double.infinity,
                  child: Text(
                    AppLocalizations.of(context).commonCancel,
                    style: AppTypography.ibm(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      height: 1.2,
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              SizedBox(height: 16), // Bottom safe area padding
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _navigateToEarningsChart() async {
    // Check if there are any session results
    try {
      final results = await SessionResultService.getAllSessionResults();
      if (results.isEmpty) {
        if (mounted) {
          _showNoEarningsDataDialog();
        }
      } else {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EarningsChartScreen(),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showNoEarningsDataDialog();
      }
    }
  }

  void _showNoEarningsDataDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          )),
          child: child,
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
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Main dialog container
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF131613),
                        borderRadius: BorderRadius.circular(AppDecorations.radius18),
                      ),
                      padding: const EdgeInsets.only(top: 24),
                      child: Column(
                        children: [
                          // Icon
                          Icon(
                            Icons.show_chart_rounded,
                            color: AppColors.accentPrimary,
                            size: 48,
                          ),

                          const SizedBox(height: 16),

                          // Title section
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              AppLocalizations.of(context).homeNoEarningsDataTitle,
                              style: AppTypography.ibm(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0,
                                height: 1.2,
                                decoration: TextDecoration.none,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Description section
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              AppLocalizations.of(context).homeNoEarningsDataDescription,
                              style: AppTypography.ibm(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.6),
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.24,
                                height: 1.5,
                                decoration: TextDecoration.none,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Divider
                          Container(
                            height: 1,
                            color: Colors.white.withOpacity(0.1),
                          ),

                          // OK button
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                              child: Text(
                                'OK',
                                style: AppTypography.ibm(
                                  fontSize: 16,
                                  color: AppColors.accentPrimary,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                  height: 1.2,
                                  decoration: TextDecoration.none,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16), // Bottom safe area padding
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performDeleteEvent(String eventId) async {
    try {
      // Delete the event
      await CalendarEventService.deleteEvent(eventId);

      // Reload data to show updated list
      await _loadData();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).homeEventDeletedSuccessfully),
          backgroundColor: AppColors.profitGreen,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).homeErrorDeletingEvent(UserFacingError.message(e))),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.ibm(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.26,
          ),
        ),
      ],
    );
  }

  String _getPlayStyleName() {
    final vpip = (playerStats['vpip'] as num?)?.toDouble() ?? 0.0;
    final pfr = (playerStats['pfr'] as num?)?.toDouble() ?? 0.0;
    final threeBet = (playerStats['threeBet'] as num?)?.toDouble() ?? 0.0;
    final aggressionFactor = (playerStats['aggressionFactor'] as num?)?.toDouble() ?? 0.0;
    final wtsd = (playerStats['wtsd'] as num?)?.toDouble();
    final wsd = (playerStats['wsd'] as num?)?.toDouble();
    final handsPlayed = (playerStats['totalHands'] as num?)?.toInt() ??
        (playerStats['handsPlayed'] as num?)?.toInt();

    final result = PlayStyleDetector.detectPlayStyle(
      vpip: vpip,
      pfr: pfr,
      threeBet: threeBet,
      aggressionFactor: aggressionFactor,
      wtsd: wtsd,
      wsd: wsd,
      handsPlayed: handsPlayed,
    );

    final style = result['style'] ?? 'Balanced';
    if (style == 'Unknown') {
      final count = handsPlayed ?? 0;
      return '$count/50';
    }
    return PlayStyleDetector.getStyleAbbreviation(style);
  }

  String _getPlayStyleIcon() {
    final styleName = _getPlayStyleName().toLowerCase();

    // Map play style abbreviations to icon filenames
    switch (styleName) {
      case 'tag':
        return 'assets/play_style/tag.png';
      case 'lag':
        return 'assets/play_style/lag.png';
      case 'nit':
        return 'assets/play_style/nit.png';
      case 'maniac':
        return 'assets/play_style/maniac.png';
      case 'calling station':
        return 'assets/play_style/calling_station.png';
      case 'balanced':
        return 'assets/play_style/balanced.png';
      default:
        return 'assets/play_style/balanced.png'; // Default fallback
    }
  }
}

class _DownArrowPainter extends CustomPainter {
  const _DownArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = AppColors.bgElevated,
    );
  }

  @override
  bool shouldRepaint(_DownArrowPainter old) => false;
}

/// Home top-nav circular action button (bell / list).
/// 38×38 bgElevated circle with a centered 21.375×21.375 icon. Optional
/// unread-count dot in the top-right.
class _TopNavCircleButton extends StatelessWidget {
  final VoidCallback onTap;
  final String svgAsset;
  final bool showBadge;

  const _TopNavCircleButton({
    required this.onTap,
    required this.svgAsset,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.bgElevated,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SvgPicture.asset(
                svgAsset,
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          if (showBadge)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF5350),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderDefault, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

