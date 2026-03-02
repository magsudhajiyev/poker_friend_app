import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/introduction_screen.dart';
import '../screens/logging_mode_selection_screen.dart';
import '../screens/session_history_screen.dart';
import '../screens/statistics_screen.dart';
import '../screens/my_opponents_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/admin/club_requests_screen.dart';
import '../screens/calendar_screen.dart';
import '../services/auth_service.dart';
import '../services/bankroll_service.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
import '../services/session_result_service.dart';
import '../services/play_style_detector.dart';
import '../services/stats_verification_service.dart';
import '../screens/auth_screen.dart';
import '../widgets/loading_screen.dart';
import '../services/calendar_event_service.dart';
import '../widgets/global_bottom_nav_bar.dart';
import '../design_system/design_system.dart';
import '../design_system/poker_friend_theme.dart';
import '../design_system/components.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../services/seat_service.dart';
import '../services/club_notification_service.dart';
import '../services/club_service.dart';
import '../services/event_service.dart';
import '../models/seat_assignment.dart';
import '../models/club_notification.dart';
import '../models/club.dart';
import '../widgets/sliding_notification.dart';
import '../widgets/navigation_drawer.dart';
import 'player/qr_scan_screen.dart';
import 'club/event_detail_screen.dart';
import 'club/club_dashboard_screen.dart';
import 'invitations_screen.dart';
import '../models/club_member.dart';
import '../services/invitation_service.dart';
import '../services/event_attendance_service.dart';
import '../models/event_attendance.dart';

/// Home screen
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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

  // Context menu state
  String? _selectedEventId;
  Offset? _popupPosition;

  @override
  void initState() {
    super.initState();

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

    _loadData();
    _setupSeatListener();
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
      print('Error pre-populating seats: $e');
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
      print('Seat listener error: $error');
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
      print('Error pre-populating club notifications: $e');
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
      print('Club notification listener error: $error');
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
        iconColor = const Color(0xFF5AC95A);
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
        // TODO: Navigate to event detail screen when implemented
        // For now, mark as read
        ClubNotificationService.markAsRead(notification.id);
      },
    );
  }

  /// Show a sliding notification when user is seated by a dealer
  void _showSeatedNotification(SeatAssignment seat) {
    if (!mounted) return;

    final chipStackStr = seat.chipStack != null
        ? '\$${seat.chipStack!.toStringAsFixed(0)}'
        : 'Not set';

    SlidingNotificationOverlay.show(
      context: context,
      title: "You've Been Seated!",
      subtitle: 'Table: ${seat.tableId}',
      detail: 'Seat #${seat.seatNumber}  •  Stack: $chipStackStr',
      icon: Icons.event_seat,
      iconColor: const Color(0xFF5AC95A),
      displayDuration: const Duration(seconds: 6),
      onTap: () {
        // Navigate to player session screen
        _navigateToPlayerSession(seat);
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

  /// Show active sessions dropdown
  void _showActiveSessionsDropdown(BuildContext context) {
    if (_activeSeats.isEmpty) {
      // No active sessions - show a message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active sessions'),
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
        color: const Color(0xFF1A1A1E),
        borderRadius: BorderRadius.circular(16),
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
                    color: Color(0xFF5AC95A),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Live Sessions',
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
        ? '\$${seat.chipStack!.toStringAsFixed(0)}'
        : 'Not set';

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
                color: const Color(0xFF5AC95A).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.casino,
                color: Color(0xFF5AC95A),
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
                    'Seat #${seat.seatNumber}  •  $chipStackStr',
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

  /// Show combined notifications dropdown (active sessions + club notifications)
  void _showNotificationsDropdown(BuildContext context) {
    final hasItems = _activeSeats.isNotEmpty || _allNotifications.isNotEmpty;

    if (!hasItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No notifications'),
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
      builder: (dialogContext) => Stack(
        children: [
          // Dismiss on tap outside
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(dialogContext),
              child: Container(color: Colors.transparent),
            ),
          ),
          // Dropdown positioned below the bell icon
          Positioned(
            top: buttonPosition.dy + 50,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: _buildNotificationsDropdown(dialogContext),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsDropdown(BuildContext dialogContext) {
    return Container(
      width: 300,
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1E),
        borderRadius: BorderRadius.circular(16),
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
      child: SingleChildScrollView(
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
                  const Icon(
                    Icons.notifications,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (_unreadNotificationCount > 0)
                    GestureDetector(
                      onTap: () async {
                        await ClubNotificationService.markAllAsRead();
                        Navigator.pop(dialogContext);
                      },
                      child: Text(
                        'Mark all read',
                        style: TextStyle(
                          color: const Color(0xFF5AC95A),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Active Sessions Section
            if (_activeSeats.isNotEmpty) ...[
              _buildSectionHeader('Live Sessions', _activeSeats.length, const Color(0xFF5AC95A)),
              ...(_activeSeats.map((seat) => _buildActiveSessionItem(dialogContext, seat))),
            ],

            // Club Notifications Section
            if (_allNotifications.isNotEmpty) ...[
              if (_activeSeats.isNotEmpty)
                Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
              _buildSectionHeader('Events', _allNotifications.length, const Color(0xFF42A5F5)),
              ...(_allNotifications.map((notification) => _buildNotificationItem(dialogContext, notification))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color dotColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '$count',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(BuildContext dialogContext, ClubNotification notification) {
    // Choose icon and color based on notification type
    IconData icon;
    Color iconColor;
    switch (notification.type) {
      case NotificationType.eventCreated:
        icon = Icons.event_available;
        iconColor = const Color(0xFF5AC95A);
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
    }

    // Format time ago
    final age = DateTime.now().difference(notification.createdAt);
    String timeAgo;
    if (age.inMinutes < 1) {
      timeAgo = 'Just now';
    } else if (age.inMinutes < 60) {
      timeAgo = '${age.inMinutes}m ago';
    } else if (age.inHours < 24) {
      timeAgo = '${age.inHours}h ago';
    } else {
      timeAgo = '${age.inDays}d ago';
    }

    return InkWell(
      onTap: () async {
        Navigator.pop(dialogContext);
        // Mark as read
        await ClubNotificationService.markAsRead(notification.id);
        // Handle based on notification type
        _handleNotificationTap(notification);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${notification.clubName}  •  $timeAgo',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Unread indicator
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 8, top: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFF5AC95A),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
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
    }
  }

  /// Handle member invitation notification tap - show accept/decline dialog
  Future<void> _handleMemberInvitationTap(ClubNotification notification) async {
    if (notification.clubId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Club not found')),
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
            const SnackBar(content: Text('Club not found')),
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
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  /// Show dialog to accept or decline invitation
  void _showInvitationResponseDialog(ClubNotification notification, Club club) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Club Invitation',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFA855F7).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mail,
                color: Color(0xFFA855F7),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You\'ve been invited to join',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              club.name,
              style: const TextStyle(
                color: Color(0xFFA855F7),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              notification.body,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _respondToInvitation(notification, club, false);
            },
            child: const Text(
              'Decline',
              style: TextStyle(color: Color(0xFFEF5350)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _respondToInvitation(notification, club, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Accept'),
          ),
        ],
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
      final userName = AuthService.userDisplayName ?? 'User';

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
          title: 'Invitation Accepted',
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
          title: 'Invitation Declined',
          body: '$userName has declined the invitation to join ${club.name}.',
        );

        // Close loading dialog
        if (mounted) Navigator.pop(context);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invitation declined')),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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
        const SnackBar(content: Text('Club not found')),
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
            const SnackBar(content: Text('Club not found')),
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
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  /// Navigate to event detail screen from notification
  Future<void> _navigateToEventFromNotification(ClubNotification notification) async {
    if (notification.eventId == null || notification.clubId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event not found')),
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
            const SnackBar(content: Text('Event not found')),
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
          SnackBar(content: Text('Error loading event: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _seatSubscription?.cancel();
    _clubNotificationSubscription?.cancel();
    _progressAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        isLoadingData = true;
      });

      StatsVerificationService.verifyAllStats();

      final bankroll = await BankrollService.getCurrentBankroll();
      final goal = await BankrollService.getBankrollGoal();
      final progress = await BankrollService.getBankrollProgress();
      final stats = await BankrollService.getPlayerStatistics();
      final sessions = await _getRecentSessions();
      final earningsData = await _getEarningsData();
      final events = await _loadCalendarEvents();

      final user = AuthService.currentUser;
      String displayName = 'User';
      if (user != null) {
        displayName = user.displayName ?? user.email?.split('@')[0] ?? 'User';
      }

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

        _progressAnimationController.reset();
        _progressAnimationController.forward();

        // Load attendance counts for events
        _loadEventAttendanceCounts();

        // Check for pending club invitations
        _checkPendingInvitations();
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() {
          isLoadingData = false;
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
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: PokerFriendColors.dark2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.mail_outline,
                  color: PokerFriendColors.purple,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Club Invitations',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(
              'You have ${invitations.length} pending club invitation${invitations.length > 1 ? 's' : ''}.',
              style: TextStyle(
                color: PokerFriendColors.dark11,
                fontSize: 14,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Later',
                  style: TextStyle(
                    color: PokerFriendColors.dark9,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const InvitationsScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: PokerFriendColors.purple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'View Invitations',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Silently fail - invitations are not critical
      print('Error checking invitations: $e');
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
      print('Error loading recent sessions: $e');
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
      print('Error getting earnings data: $e');
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
      return LoadingScreen(message: 'Loading your poker data...');
    }

    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF0B0A0A),
      extendBody: true,
      drawer: AppNavigationDrawer(
        username: userName,
        email: AuthService.currentUser?.email,
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadData,
            color: AppColors.tealAccent,
            backgroundColor: const Color(0xFF1C2926),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Gradient Header with greeting and bankroll
                  HomeHeader(
                    userName: userName,
                    subtitle: 'Welcome back',
                    currentBankroll: currentBankroll,
                    bankrollGoal: bankrollGoal,
                    filterLabel: 'Label',
                    onMenuPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const QRScanScreen()),
                      );
                    },
                    onNotificationPressed: () {
                      _showNotificationsDropdown(context);
                    },
                    onSettingsPressed: () {
                      _scaffoldKey.currentState?.openDrawer();
                    },
                    showNotificationBadge: _unreadNotificationCount > 0,
                    notificationCount: _unreadNotificationCount,
                  ),

                  // Recent Activity (Stats)
                  _buildStatsGrid(),

                  const SizedBox(height: 32),

                  // Earnings Chart
                  _buildEarningsCard(),

                  const SizedBox(height: 32),

                  // Recent Sessions
                  _buildRecentSessionsCard(),

                  const SizedBox(height: 32),

                  // Upcoming Events
                  _buildUpcomingEventsCard(),

                  const SizedBox(height: 100),
                ],
              ),
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
      ),
      bottomNavigationBar: GlobalBottomNavBar(currentScreen: 'home'),
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
                  MaterialPageRoute(builder: (context) => LoggingModeSelectionScreen()),
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
                    child: Image.asset(
                      'icons/flat_icons/stats.png',
                      color: Colors.white,
                      width: 26,
                      height: 26,
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
                        child: Image.asset(
                          'icons/flat_icons/bell.png',
                          color: Colors.white,
                          width: 26,
                          height: 26,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recent Activity headline
        SectionHeadline(title: 'Recent Activity'),

        // Stats rows with separators
        StatListRow(
          label: 'Sessions',
          value: '${playerStats['totalSessions'] ?? 0}',
        ),
        const ListSeparator(),
        StatListRow(
          label: 'Win Rate',
          value: '${(playerStats['winRate'] ?? 0.0).toStringAsFixed(0)}%',
        ),
        const ListSeparator(),
        StatListRow(
          label: 'Hours',
          value: '${(playerStats['totalHours'] ?? 0.0).toStringAsFixed(1)}',
        ),
        const ListSeparator(),
        StatListRow(
          label: 'Play Style',
          value: _getPlayStyleName(),
        ),
      ],
    );
  }

  Widget _buildEarningsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with title and avg badge
          SectionHeadline(
            title: 'Earnings',
            badgeText: 'Avg \$${avgEarnings.toStringAsFixed(0)}',
          ),
          const SizedBox(height: 16),
          // Legend
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildLegendItem('Tournament', AppColors.tournamentBlue),
                const SizedBox(width: 17),
                _buildLegendItem('Cash Game', AppColors.cashGameGreen),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Chart
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 167,
              child: earningsChartData.isEmpty
                  ? Center(
                      child: Text(
                        'No earnings data yet',
                        style: AppTypography.listRowText(
                          color: Colors.white.withOpacity(0.40),
                        ),
                      ),
                    )
                  : CustomPaint(
                      painter: EarningsChartPainter(earningsChartData),
                      size: Size.infinite,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSessionsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with title and view all
        SectionHeadline(
          title: 'Recent Sessions',
          actionText: 'View All',
          onActionPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SessionHistoryScreen()),
            );
          },
        ),
        const SizedBox(height: 8),
        // Content
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: recentSessions.isEmpty
              ? InfoCard(
                  isEmpty: true,
                  emptyTitle: 'No recent sessions',
                  emptySubtitle: 'Start your first poker session!',
                  onEmptyTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LoggingModeSelectionScreen()),
                    );
                  },
                )
              : Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.infoCardBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Three dots menu at top-right
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: () {
                              // TODO: Show sessions menu
                            },
                            child: const Icon(
                              Icons.more_horiz,
                              color: Color(0xFF7DCAB4),
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Sessions list
                      ..._buildSessionsList(),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildUpcomingEventsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with title and view all
        SectionHeadline(
          title: 'Upcoming Events',
          actionText: 'View All',
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
              ? InfoCard(
                  isEmpty: true,
                  emptyTitle: 'No recent sessions',
                  emptySubtitle: 'Start your first poker session!',
                  onEmptyTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CalendarScreen()),
                    );
                    _loadData();
                  },
                )
              : Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.infoCardBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: _buildEventsList(),
                  ),
                ),
        ),
      ],
    );
  }

  List<Widget> _buildSessionsList() {
    List<Widget> widgets = [];
    final sessions = recentSessions.take(3).toList();

    for (int i = 0; i < sessions.length; i++) {
      widgets.add(_buildSessionItem(sessions[i]));

      // Add divider between sessions (not after the last one)
      if (i < sessions.length - 1) {
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

  Widget _buildSessionItem(Map<String, dynamic> session) {
    String sessionName = session['sessionName'] ?? '';

    if (sessionName.isEmpty) {
      final createdAt = _parseSessionDate(session);
      final gameType = session['gameType'] ?? 'Poker';
      final dateStr = DateFormat('MMM d').format(createdAt);
      sessionName = '$gameType Session - $dateStr';
    }

    final createdAt = _parseSessionDate(session);
    final formattedDate = DateFormat('MMM dd, h:mma').format(createdAt).toLowerCase();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SessionHistoryScreen(targetSessionId: session['id']),
          ),
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side: Session info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sessionName,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    color: Color(0xFFF8FFF7),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Color(0xFFF8FFF7),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          // Right side: Arrow icon
          Icon(
            Icons.arrow_forward_ios,
            color: Color(0xFF87ED81),
            size: 18,
          ),
        ],
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
        buyIn = '\$${buyInValue.toStringAsFixed(0)}';
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
                    event['title'] ?? 'Event',
                    style: TextStyle(
                      fontFamily: 'Inter',
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
                        style: TextStyle(
                          fontFamily: 'Inter',
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
                            borderRadius: BorderRadius.circular(10),
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
                                '$goingCount going',
                                style: TextStyle(
                                  fontFamily: 'Inter',
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
                style: GoogleFonts.robotoMono(
                  fontSize: 22,
                  color: Color(0xFF87ED81),
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

  Future<void> _navigateToCalendarEventDetail(Map<String, dynamic> event) async {
    final clubId = event['clubId'];
    final clubEventId = event['clubEventId'];

    // Only navigate if this is a club event
    if (clubId == null || clubEventId == null) {
      return;
    }

    try {
      // Fetch the club and event data
      final club = await ClubService.getClub(clubId);
      if (club == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Club not found')),
          );
        }
        return;
      }

      final clubEvent = await EventService.getEvent(clubId, clubEventId);
      if (clubEvent == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event not found')),
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
          SnackBar(content: Text('Failed to load event: $e')),
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

    final eventTitle = event['title'] ?? 'Event';

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
            borderRadius: BorderRadius.circular(18),
          ),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Event title
              Text(
                eventTitle,
                style: TextStyle(
                  fontFamily: 'Inter',
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
                            'Edit Event',
                            style: TextStyle(
                              fontFamily: 'Inter',
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
                      _handleDeleteEvent(event['id'], event['title'] ?? 'Event');
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Delete Event',
                            style: TextStyle(
                              fontFamily: 'Inter',
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
                      borderRadius: BorderRadius.circular(18),
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
                                'Edit Event',
                                style: TextStyle(
                                  fontFamily: 'Inter',
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
                              hintText: 'Event Name',
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
                                  SnackBar(content: Text('Failed to update event: $e')),
                                );
                              }
                            },
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
                                  'Save Changes',
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
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: EdgeInsets.only(top: 24),
                child: Column(
                  children: [
                    // Title section
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Delete $eventName?',
                        style: TextStyle(
                          fontFamily: 'Inter',
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
                        'Are you sure you want to delete "$eventName"?',
                        style: TextStyle(
                          fontFamily: 'Inter',
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
                          'Delete',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            color: Color(0xFFD55A41), // Red color
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
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  width: double.infinity,
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: 'Inter',
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

  Future<void> _performDeleteEvent(String eventId) async {
    try {
      // Delete the event
      await CalendarEventService.deleteEvent(eventId);

      // Reload data to show updated list
      await _loadData();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Event deleted successfully'),
          backgroundColor: Color(0xFF5AC95A),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting event: $e'),
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
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            letterSpacing: -0.24,
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
    final handsPlayed = (playerStats['handsPlayed'] as num?)?.toInt();

    final result = PlayStyleDetector.detectPlayStyle(
      vpip: vpip,
      pfr: pfr,
      threeBet: threeBet,
      aggressionFactor: aggressionFactor,
      wtsd: wtsd,
      wsd: wsd,
      handsPlayed: handsPlayed,
    );

    return PlayStyleDetector.getStyleAbbreviation(result['style'] ?? 'Balanced');
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

// Custom painter for earnings chart (bar chart)
class EarningsChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;

  EarningsChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()..style = PaintingStyle.fill;

    final chartArea = Rect.fromLTWH(50, 20, size.width - 70, size.height - 50);

    double maxValue = 0;
    double minValue = 0;
    for (var point in data) {
      final tournament = (point['tournament'] as num?)?.toDouble() ?? 0.0;
      final cash = (point['cash'] as num?)?.toDouble() ?? 0.0;
      maxValue = math.max(maxValue, math.max(tournament, cash));
      minValue = math.min(minValue, math.min(tournament, cash));
    }

    if (maxValue == 0 && minValue == 0) {
      maxValue = 100;
      minValue = -100;
    }

    maxValue = ((maxValue / 100).ceil() * 100).toDouble();
    minValue = ((minValue / 100).floor() * 100).toDouble();

    final valueRange = maxValue - minValue;

    final zeroY = chartArea.bottom - ((0 - minValue) / valueRange) * chartArea.height;

    final axisPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(chartArea.left, chartArea.top),
      Offset(chartArea.left, chartArea.bottom),
      axisPaint,
    );

    canvas.drawLine(
      Offset(chartArea.left, zeroY),
      Offset(chartArea.right, zeroY),
      axisPaint,
    );

    final textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
    );

    for (int i = 0; i <= 4; i++) {
      final value = minValue + (i * valueRange / 4);
      textPainter.text = TextSpan(
        text: '\$${value.toInt()}',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w300,
        ),
      );
      textPainter.layout();

      final y = chartArea.bottom - (i / 4) * chartArea.height;
      textPainter.paint(canvas, Offset(5, y - textPainter.height / 2));
    }

    final barGroupWidth = chartArea.width / data.length;
    final barWidth = (barGroupWidth - 16) / 2;
    final spacing = 4.0;

    for (int i = 0; i < data.length; i++) {
      final tournamentValue = (data[i]['tournament'] as num?)?.toDouble() ?? 0.0;
      final cashValue = (data[i]['cash'] as num?)?.toDouble() ?? 0.0;

      final groupX = chartArea.left + (i * barGroupWidth) + 8;

      final tournamentBarX = groupX;
      final tournamentHeight = ((tournamentValue - 0) / valueRange) * chartArea.height;
      final tournamentTop = tournamentValue >= 0
          ? zeroY - tournamentHeight.abs()
          : zeroY;
      final tournamentBarHeight = tournamentHeight.abs();

      if (tournamentBarHeight > 0) {
        paint.color = const Color(0xFF006AFF);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              tournamentBarX,
              tournamentTop,
              barWidth,
              tournamentBarHeight,
            ),
            Radius.circular(4),
          ),
          paint,
        );
      }

      final cashBarX = groupX + barWidth + spacing;
      final cashHeight = ((cashValue - 0) / valueRange) * chartArea.height;
      final cashTop = cashValue >= 0
          ? zeroY - cashHeight.abs()
          : zeroY;
      final cashBarHeight = cashHeight.abs();

      if (cashBarHeight > 0) {
        paint.color = const Color(0xFFA5EC44);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              cashBarX,
              cashTop,
              barWidth,
              cashBarHeight,
            ),
            Radius.circular(4),
          ),
          paint,
        );
      }

      textPainter.text = TextSpan(
        text: data[i]['date'],
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w300,
        ),
      );
      textPainter.layout();

      final labelX = groupX + (barGroupWidth - 16) / 2 - textPainter.width / 2;
      textPainter.paint(canvas, Offset(labelX, chartArea.bottom + 5));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
