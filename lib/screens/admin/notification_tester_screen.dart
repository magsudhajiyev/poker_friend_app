import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/components/backgrounds/gradient_background.dart';
import '../../models/club_notification.dart';
import '../../widgets/sliding_notification.dart';

/// Debug screen to preview and trigger all notification types.
/// Shows both the sliding overlay and how each notification renders
/// in the notifications list.
class NotificationTesterScreen extends StatelessWidget {
  const NotificationTesterScreen({super.key});

  /// All notification type definitions with mock data
  static final List<_NotificationMock> _mocks = [
    _NotificationMock(
      type: NotificationType.eventCreated,
      title: 'New Event Created',
      body: 'Friday Night Poker - Apr 11, 8:00 PM',
      clubName: 'Ace High Club',
      icon: Icons.event_available,
      iconColor: AppColors.profitGreen,
    ),
    _NotificationMock(
      type: NotificationType.eventUpdated,
      title: 'Event Updated',
      body: 'Friday Night Poker has been rescheduled to 9:00 PM',
      clubName: 'Ace High Club',
      icon: Icons.update,
      iconColor: const Color(0xFF42A5F5),
    ),
    _NotificationMock(
      type: NotificationType.eventCancelled,
      title: 'Event Cancelled',
      body: 'Friday Night Poker has been cancelled',
      clubName: 'Ace High Club',
      icon: Icons.event_busy,
      iconColor: const Color(0xFFEF5350),
    ),
    _NotificationMock(
      type: NotificationType.eventStarting,
      title: 'Event Starting Soon',
      body: 'Friday Night Poker starts in 1 hour!',
      clubName: 'Ace High Club',
      icon: Icons.schedule,
      iconColor: const Color(0xFFFFA726),
    ),
    _NotificationMock(
      type: NotificationType.eventStarted,
      title: 'Event Started',
      body: 'Friday Night Poker is now LIVE!',
      clubName: 'Ace High Club',
      icon: Icons.play_circle_filled,
      iconColor: const Color(0xFF4CAF50),
    ),
    _NotificationMock(
      type: NotificationType.memberRSVP,
      title: 'Member RSVP',
      body: 'John D. responded "Going" to Friday Night Poker',
      clubName: 'Ace High Club',
      icon: Icons.how_to_reg,
      iconColor: const Color(0xFF9C27B0),
    ),
    _NotificationMock(
      type: NotificationType.newClubRequest,
      title: 'New Club Request',
      body: 'Mike wants to register "Royal Flush Lounge"',
      clubName: '',
      icon: Icons.business,
      iconColor: const Color(0xFFF59E0B),
    ),
    _NotificationMock(
      type: NotificationType.clubApproved,
      title: 'Club Approved',
      body: 'Your club "Royal Flush Lounge" has been approved!',
      clubName: 'Royal Flush Lounge',
      icon: Icons.check_circle,
      iconColor: const Color(0xFF4CAF50),
    ),
    _NotificationMock(
      type: NotificationType.clubRejected,
      title: 'Club Rejected',
      body: 'Your club request has been declined. Reason: Duplicate entry.',
      clubName: '',
      icon: Icons.cancel,
      iconColor: const Color(0xFFEF5350),
    ),
    _NotificationMock(
      type: NotificationType.memberInvited,
      title: 'Club Invitation',
      body: 'You\'ve been invited to join Ace High Club by Sarah M.',
      clubName: 'Ace High Club',
      icon: Icons.mail,
      iconColor: const Color(0xFFA855F7),
    ),
    _NotificationMock(
      type: NotificationType.invitationAccepted,
      title: 'Invitation Accepted',
      body: 'Alex K. has accepted the invitation to join Ace High Club.',
      clubName: 'Ace High Club',
      icon: Icons.person_add,
      iconColor: const Color(0xFF4CAF50),
    ),
    _NotificationMock(
      type: NotificationType.invitationDeclined,
      title: 'Invitation Declined',
      body: 'Chris P. has declined the invitation to join Ace High Club.',
      clubName: 'Ace High Club',
      icon: Icons.person_off,
      iconColor: const Color(0xFFEF5350),
    ),
    _NotificationMock(
      type: NotificationType.seatAvailable,
      title: 'Seat Available',
      body: 'A seat is now available at Table 1 for Friday Night Poker',
      clubName: 'Ace High Club',
      icon: Icons.event_seat,
      iconColor: const Color(0xFF4CAF50),
    ),
    _NotificationMock(
      type: NotificationType.newSupportRequest,
      title: 'New Support Request',
      body: 'John D.: [Bug Report] App crashes on hand save',
      clubName: '',
      icon: Icons.support_agent,
      iconColor: AppColors.buttonPrimary,
    ),
    _NotificationMock(
      type: NotificationType.supportRequestUpdated,
      title: 'Support Request Resolved',
      body: 'Your request "App crashes on hand save" has been resolved.',
      clubName: '',
      icon: Icons.check_circle,
      iconColor: AppColors.limeGreen,
    ),
  ];

  void _triggerSliding(BuildContext context, _NotificationMock mock) {
    SlidingNotificationOverlay.show(
      context: context,
      title: mock.title,
      subtitle: mock.clubName.isNotEmpty ? mock.clubName : mock.body,
      detail: mock.clubName.isNotEmpty ? mock.body : null,
      icon: mock.icon,
      iconColor: mock.iconColor,
      displayDuration: const Duration(seconds: 8),
      autoDismiss: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        children: [
          const GradientBackground(),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
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
                      const SizedBox(width: 12),
                      Text(
                        'Notification Tester',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Info pill
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.buttonPrimary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.buttonPrimary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      'Tap any notification to trigger the sliding overlay. '
                      'Tap the list icon to preview it as a notification list item.',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 13,
                        color: AppColors.buttonPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // List of all notification types
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: _mocks.length,
                    separatorBuilder: (_, __) => const Divider(
                      color: AppColors.separatorDark,
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final mock = _mocks[index];
                      return _buildMockRow(context, mock);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockRow(BuildContext context, _NotificationMock mock) {
    return GestureDetector(
      onTap: () => _triggerSliding(context, mock),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: mock.iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                mock.icon,
                color: mock.iconColor,
                size: 22,
              ),
            ),

            const SizedBox(width: 12),

            // Type name + title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mock.type.displayName,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mock.title,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      color: AppColors.textDisabled,
                    ),
                  ),
                ],
              ),
            ),

            // Preview as list item button
            GestureDetector(
              onTap: () => _showListPreview(context, mock),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.list_alt,
                  color: AppColors.textDisabled,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Preview how the notification looks as a list item (like in NotificationsScreen)
  void _showListPreview(BuildContext context, _NotificationMock mock) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textDisabled,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'List Item Preview',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                mock.type.displayName,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  color: AppColors.textDisabled,
                ),
              ),
              const SizedBox(height: 20),

              // Unread version
              Text(
                'UNREAD',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.limeGreen,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              _buildListItemPreview(mock, isRead: false),

              const SizedBox(height: 20),

              // Read version
              Text(
                'READ',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDisabled,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              _buildListItemPreview(mock, isRead: true),
            ],
          ),
        );
      },
    );
  }

  /// Renders a notification exactly like NotificationsScreen._buildNotificationItem
  Widget _buildListItemPreview(_NotificationMock mock, {required bool isRead}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Green checkmark circle
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.accentGreenBright,
            borderRadius: BorderRadius.circular(52.5),
          ),
          child: const Center(
            child: Icon(Icons.check, color: Colors.black, size: 12),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mock.title,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  height: 1.44,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                mock.body,
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
        if (!isRead)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.buttonPrimary,
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
          )
        else
          const SizedBox(width: 100),
      ],
    );
  }
}

class _NotificationMock {
  final NotificationType type;
  final String title;
  final String body;
  final String clubName;
  final IconData icon;
  final Color iconColor;

  const _NotificationMock({
    required this.type,
    required this.title,
    required this.body,
    required this.clubName,
    required this.icon,
    required this.iconColor,
  });
}
