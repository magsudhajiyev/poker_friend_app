import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:google_fonts/google_fonts.dart';
import '../design_system/constants/colors.dart';
import '../models/club_notification.dart';
import '../models/club.dart';
import '../models/club_member.dart';
import '../services/club_notification_service.dart';
import '../services/club_service.dart';
import '../services/event_service.dart';
import '../services/auth_service.dart';
import '../widgets/global_bottom_nav_bar.dart';
import 'club/event_detail_screen.dart';
import 'club/club_dashboard_screen.dart';
import 'admin/club_requests_screen.dart';

/// Dedicated notifications screen matching Figma design (node 324:4769)
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<ClubNotification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final notifications = await ClubNotificationService.getUserNotifications();
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(ClubNotification notification) async {
    await ClubNotificationService.markAsRead(notification.id);
    setState(() {
      final index = _notifications.indexWhere((n) => n.id == notification.id);
      if (index != -1) {
        _notifications[index] = notification.copyWith(isRead: true);
      }
    });
  }

  Future<void> _markAllAsRead() async {
    await ClubNotificationService.markAllAsRead();
    setState(() {
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    });
  }

  /// Group notifications by time period
  Map<String, List<ClubNotification>> _groupNotifications() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final groups = <String, List<ClubNotification>>{
      'Today': [],
      'Yesterday': [],
      'This Week': [],
      'Earlier': [],
    };

    for (final notification in _notifications) {
      final notifDate = DateTime(
        notification.createdAt.year,
        notification.createdAt.month,
        notification.createdAt.day,
      );

      if (notifDate.isAtSameMomentAs(today) || notifDate.isAfter(today)) {
        groups['Today']!.add(notification);
      } else if (notifDate.isAtSameMomentAs(yesterday)) {
        groups['Yesterday']!.add(notification);
      } else if (notifDate.isAfter(weekAgo)) {
        groups['This Week']!.add(notification);
      } else {
        groups['Earlier']!.add(notification);
      }
    }

    groups.removeWhere((key, value) => value.isEmpty);
    return groups;
  }

  /// Get category label for notification type
  String _getCategoryLabel(NotificationType type) {
    switch (type) {
      case NotificationType.eventCreated:
      case NotificationType.eventUpdated:
      case NotificationType.eventCancelled:
      case NotificationType.eventStarting:
      case NotificationType.eventStarted:
        return 'Events';
      case NotificationType.memberRSVP:
        return 'RSVP';
      case NotificationType.newClubRequest:
      case NotificationType.clubApproved:
      case NotificationType.clubRejected:
        return 'Clubs';
      case NotificationType.memberInvited:
      case NotificationType.invitationAccepted:
      case NotificationType.invitationDeclined:
        return 'Invitations';
      case NotificationType.seatAvailable:
        return 'Seats';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _notifications.any((n) => !n.isRead);
    final groupedNotifications = _groupNotifications();
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.backgroundPaper, // #02050B
      body: Stack(
        children: [
          // Cyan ellipse glow at top (Figma node 343:4912)
          // Position adjusted lower for better visual appearance
          Positioned(
            top: -50,
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

          // Main content column
          Positioned.fill(
            child: Column(
              children: [
                // Status bar spacing
                SizedBox(height: statusBarHeight),

                // Header (Figma node 343:4869): h:84px, backdrop-blur 20px, p:16
                _buildHeader(hasUnread),

                // "Today" section (Figma node 350:4968): gap 4px, then separator
                _buildTodaySection(hasUnread),

                // Notifications list (Figma node 350:4967): top spacing, gap 24px
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.buttonPrimary,
                          ),
                        )
                      : _notifications.isEmpty
                          ? _buildEmptyState()
                          : _buildNotificationsList(groupedNotifications),
                ),
              ],
            ),
          ),

          // Bottom navigation bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: const GlobalBottomNavBar(currentScreen: 'notifications'),
          ),
        ],
      ),
    );
  }

  /// Header with back button, title, and bell icon
  /// Figma node 343:4869: backdrop-blur 20px, h:84px (auto), p:16, gap:12
  Widget _buildHeader(bool hasUnread) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 84,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Back button (Figma node 13:926): 44x44, bg #101115, rounded 88.733px, p:9.68
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(9.68),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSurface, // #101115
                    borderRadius: BorderRadius.circular(88.733),
                  ),
                  child: Center(
                    child: Image.asset(
                      'icons/flat_icons/back.png',
                      width: 24,
                      height: 24,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Title container (Figma node 343:4875): flex-1, items-start, justify-center
              // Inner container (Figma node 350:4927): pl-12
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        'Notifications',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 27,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bell icon with pink dot (Figma node 350:4969): 44x44, rounded 100px
              // Icon (node 350:4970): 28x28, centered
              // Dot (node 350:4971): left:25, top:12, 5x5
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Bell icon container (rounded 100px = full circle)
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Center(
                        child: Image.asset(
                          'icons/flat_icons/bell.png',
                          width: 28,
                          height: 28,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // Pink notification dot (Figma node 350:4971)
                    if (hasUnread)
                      Positioned(
                        left: 25,
                        top: 12,
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE91E63), // Magenta/pink
                            shape: BoxShape.circle,
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
    );
  }

  /// "Today" row with "Mark all as read" and separator
  /// Figma node 350:4968: flex-col, gap:4, items-start
  Widget _buildTodaySection(bool hasUnread) {
    return Column(
      children: [
        const SizedBox(height: 8),

        // Row (Figma node 350:4959): px-16, justify-between
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // "Today" (Figma node 343:4915): Medium 17px, white, line-height 1.44
              Text(
                'Today',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  height: 1.44,
                ),
              ),
              // "Mark all as read" (Figma node 350:4957): SemiBold 14px, #89F1EC, line-height 1.47
              if (hasUnread)
                GestureDetector(
                  onTap: _markAllAsRead,
                  child: Text(
                    'Mark all as read',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF89F1EC), // mint/300
                      height: 1.47,
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 4),

        // Separator (Figma node 13:1765): px-16, h:1px, bg #1C1F21
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 1,
            color: AppColors.separatorDark, // #1C1F21
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'icons/flat_icons/bell.png',
            width: 64,
            height: 64,
            color: AppColors.textDisabled,
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: AppColors.textDisabled,
              height: 1.44,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(Map<String, List<ClubNotification>> groupedNotifications) {
    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: AppColors.buttonPrimary,
      child: ListView.builder(
        // Figma: notifications list starts at y:218 (60px below separator)
        padding: const EdgeInsets.only(top: 24, bottom: 100),
        itemCount: groupedNotifications.length,
        itemBuilder: (context, index) {
          final entry = groupedNotifications.entries.elementAt(index);
          final notifications = entry.value;

          return _buildNotificationGroup(notifications);
        },
      ),
    );
  }

  Widget _buildNotificationGroup(List<ClubNotification> notifications) {
    // Group by category
    final categorizedNotifications = <String, List<ClubNotification>>{};
    for (final notification in notifications) {
      final category = _getCategoryLabel(notification.type);
      categorizedNotifications.putIfAbsent(category, () => []).add(notification);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Figma node 350:4967: flex-col, gap:24
        ...categorizedNotifications.entries.map((categoryEntry) {
          final category = categoryEntry.key;
          final categoryNotifications = categoryEntry.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category label (Figma node 350:4955): px-16
              // Text (node 350:4928): Regular 17px, #D3FFFD, line-height 1.44
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  category,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary, // #D3FFFD
                    height: 1.44,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Notification items (gap 16px between items)
              ...categoryNotifications.asMap().entries.map((entry) {
                final index = entry.key;
                final notification = entry.value;
                final isLast = index == categoryNotifications.length - 1;

                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 24 : 16),
                  child: _buildNotificationItem(notification),
                );
              }),
            ],
          );
        }),
      ],
    );
  }

  /// Handle notification tap - navigate to appropriate screen
  Future<void> _onNotificationTap(ClubNotification notification) async {
    // Mark as read first
    if (!notification.isRead) {
      await _markAsRead(notification);
    }

    if (!mounted) return;

    switch (notification.type) {
      // Event-related notifications -> EventDetailScreen
      case NotificationType.eventCreated:
      case NotificationType.eventUpdated:
      case NotificationType.eventCancelled:
      case NotificationType.eventStarting:
      case NotificationType.eventStarted:
      case NotificationType.memberRSVP:
      case NotificationType.seatAvailable:
        await _navigateToEventFromNotification(notification);
        break;

      // Club invitation -> Show accept/decline dialog
      case NotificationType.memberInvited:
        await _handleMemberInvitationTap(notification);
        break;

      // Club request (for admins) -> ClubRequestsScreen
      case NotificationType.newClubRequest:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ClubRequestsScreen(),
          ),
        );
        break;

      // Club approved -> Navigate to club
      case NotificationType.clubApproved:
        if (notification.clubId.isNotEmpty) {
          await _navigateToClub(notification.clubId);
        }
        break;

      // Club rejected -> Just show a message
      case NotificationType.clubRejected:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(notification.body)),
        );
        break;

      // Invitation responses -> Navigate to club
      case NotificationType.invitationAccepted:
      case NotificationType.invitationDeclined:
        if (notification.clubId.isNotEmpty) {
          await _navigateToClub(notification.clubId);
        }
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
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.buttonPrimary),
      ),
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
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.buttonPrimary),
      ),
    );

    try {
      final userId = AuthService.userId;
      final userName = AuthService.userDisplayName;

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

  /// Navigate to event from notification (fetches club and event data)
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
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.buttonPrimary),
      ),
    );

    try {
      // Fetch club and event data AND check admin status BEFORE closing dialog
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
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading event: $e')),
        );
      }
    }
  }

  /// Navigate to club dashboard (fetches club data)
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
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.buttonPrimary),
      ),
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
          SnackBar(content: Text('Failed to load club: $e')),
        );
      }
    }
  }

  /// Single notification item
  /// Figma node 350:4954: px-16, justify-between
  Widget _buildNotificationItem(ClubNotification notification) {
    return GestureDetector(
      onTap: () => _onNotificationTap(notification),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side (Figma node 350:4953): flex, gap:8
          // Green checkmark circle (Figma node 350:4948): 24x24, #54E98A, rounded 52.5px
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.accentGreenBright, // #54E98A
              borderRadius: BorderRadius.circular(52.5),
            ),
            child: const Center(
              child: Icon(
                Icons.check,
                color: Colors.black,
                size: 12,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Text container (Figma node 350:4952): flex-1, flex-col, gap:3
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title (Figma node 350:4946): Medium 17px, white, line-height 1.44
                Text(
                  notification.title,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 1.44,
                  ),
                ),
                const SizedBox(height: 3),
                // Body (Figma node 350:4947): Regular 13px, #B3B4B6, line-height 1.44
                Text(
                  notification.body,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFFB3B4B6),
                    height: 1.44,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // "Mark as read" button (Figma node 350:4930):
          // bg #89F1EC, rounded 86px, px:16, py:8
          // Text (node 350:4934): SemiBold 13px, black, line-height 1.47
          // Show for unread notifications, hide for already read
          if (!notification.isRead)
            GestureDetector(
              onTap: () => _markAsRead(notification),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.buttonPrimary, // #89F1EC
                  borderRadius: BorderRadius.circular(86),
                ),
                child: Text(
                  'Mark as read',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    height: 1.47,
                  ),
                ),
              ),
            )
          else
            // Placeholder for read notifications to maintain alignment
            const SizedBox(width: 100),
        ],
      ),
      ),
    );
  }
}
