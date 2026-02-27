import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/club_notification.dart';
import '../models/club_event.dart';
import 'auth_service.dart';
import 'club_service.dart';

/// Service for managing club notifications
class ClubNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _clubsCollection = 'clubs';
  static const String _notificationsSubcollection = 'notifications';
  static const String _userNotificationsCollection = 'user_notifications';

  /// Send notification to a single user
  static Future<void> notifyUser({
    required String userId,
    required NotificationType type,
    required String title,
    required String body,
    String? clubId,
    String? clubName,
    Map<String, dynamic>? data,
  }) async {
    try {
      final notification = ClubNotification(
        id: '',
        clubId: clubId ?? '',
        clubName: clubName ?? '',
        type: type,
        title: title,
        body: body,
        data: data ?? {},
        createdAt: DateTime.now(),
        recipientUserIds: [userId],
      );

      // Create user notification document
      await _firestore
          .collection(_userNotificationsCollection)
          .add({
        ...notification.toFirestore(),
        'userId': userId,
        'isRead': false,
      });
    } catch (e) {
      print('Error sending notification to user: $e');
    }
  }

  /// Send notification to all club members
  static Future<void> notifyClubMembers({
    required String clubId,
    required NotificationType type,
    required String title,
    required String body,
    String? eventId,
    Map<String, dynamic>? data,
    String? excludeUserId,  // Exclude this user (e.g., the creator)
  }) async {
    print('notifyClubMembers called for clubId: $clubId');
    try {
      // Get club info
      final club = await ClubService.getClub(clubId);
      if (club == null) {
        print('Club not found: $clubId');
        return;
      }
      print('Club found: ${club.name}');

      // Get all member user IDs
      var memberIds = await ClubService.getMemberUserIds(clubId);
      print('Found ${memberIds.length} members: $memberIds');

      // Exclude the specified user (e.g., admin who created the event)
      if (excludeUserId != null) {
        memberIds = memberIds.where((id) => id != excludeUserId).toList();
        print('After excluding $excludeUserId: ${memberIds.length} members');
      }

      if (memberIds.isEmpty) {
        print('No members to notify for club: $clubId');
        return;
      }

      final notification = ClubNotification(
        id: '',
        clubId: clubId,
        clubName: club.name,
        eventId: eventId,
        type: type,
        title: title,
        body: body,
        data: data ?? {},
        createdAt: DateTime.now(),
        recipientUserIds: memberIds,
      );

      // Store in club's notifications subcollection
      final notificationRef = await _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_notificationsSubcollection)
          .add(notification.toFirestore());

      // Also create individual user notification documents for easy querying
      // These are for in-app notification list - FCM is already sent via club topic
      final batch = _firestore.batch();
      for (final userId in memberIds) {
        final userNotificationRef = _firestore
            .collection(_userNotificationsCollection)
            .doc();
        batch.set(userNotificationRef, {
          ...notification.toFirestore(),
          'notificationId': notificationRef.id,
          'userId': userId,
          'isRead': false,
          'skipFcm': true,  // FCM already sent via club topic, don't send again
        });
      }
      await batch.commit();

      // TODO: In production, also send FCM push notifications here
      // await _sendPushNotifications(memberIds, title, body, data);

    } catch (e) {
      print('Error notifying club members: $e');
    }
  }

  /// Send notification for a new event
  static Future<void> notifyEventCreated({
    required String clubId,
    required ClubEvent event,
  }) async {
    print('notifyEventCreated called for event: ${event.name}, notifyMembers: ${event.notifyMembers}');
    if (!event.notifyMembers) {
      print('Skipping notification - notifyMembers is false');
      return;
    }

    final club = await ClubService.getClub(clubId);
    final clubName = club?.name ?? 'Club';
    print('Club found: $clubName');

    await notifyClubMembers(
      clubId: clubId,
      type: NotificationType.eventCreated,
      title: 'New Event: ${event.name}',
      body: '$clubName has a new event on ${_formatDate(event.startTime)}',
      eventId: event.id,
      data: {
        'action': 'view_event',
        'clubId': clubId,
        'eventId': event.id,
      },
      excludeUserId: event.createdBy,  // Don't notify the admin who created it
    );
  }

  /// Send notification when event is updated
  static Future<void> notifyEventUpdated({
    required String clubId,
    required ClubEvent event,
    String? changeDescription,
  }) async {
    final club = await ClubService.getClub(clubId);
    final clubName = club?.name ?? 'Club';

    await notifyClubMembers(
      clubId: clubId,
      type: NotificationType.eventUpdated,
      title: 'Event Updated: ${event.name}',
      body: changeDescription ?? '$clubName updated the event details',
      eventId: event.id,
      data: {
        'action': 'view_event',
        'clubId': clubId,
        'eventId': event.id,
      },
    );
  }

  /// Send notification when event is cancelled
  static Future<void> notifyEventCancelled({
    required String clubId,
    required ClubEvent event,
  }) async {
    final club = await ClubService.getClub(clubId);
    final clubName = club?.name ?? 'Club';

    await notifyClubMembers(
      clubId: clubId,
      type: NotificationType.eventCancelled,
      title: 'Event Cancelled: ${event.name}',
      body: '$clubName has cancelled the event scheduled for ${_formatDate(event.startTime)}',
      eventId: event.id,
      data: {
        'action': 'view_club',
        'clubId': clubId,
      },
    );
  }

  /// Send notification when event is starting (call this 1 hour before)
  static Future<void> notifyEventStarting({
    required String clubId,
    required ClubEvent event,
  }) async {
    final club = await ClubService.getClub(clubId);
    final clubName = club?.name ?? 'Club';

    await notifyClubMembers(
      clubId: clubId,
      type: NotificationType.eventStarting,
      title: '${event.name} starts in 1 hour!',
      body: '$clubName event is about to begin',
      eventId: event.id,
      data: {
        'action': 'view_event',
        'clubId': clubId,
        'eventId': event.id,
      },
    );
  }

  /// Send notification when event has started (status → active)
  static Future<void> notifyEventStarted({
    required String clubId,
    required ClubEvent event,
  }) async {
    final club = await ClubService.getClub(clubId);
    final clubName = club?.name ?? 'Club';

    await notifyClubMembers(
      clubId: clubId,
      type: NotificationType.eventStarted,
      title: '${event.name} is now LIVE!',
      body: '$clubName event has started - join now to spectate',
      eventId: event.id,
      data: {
        'action': 'spectate_event',
        'clubId': clubId,
        'eventId': event.id,
      },
    );
  }

  /// Send notification when a seat becomes available for a waitlist member
  static Future<void> notifySeatAvailable({
    required String clubId,
    required String userId,
    required String eventId,
    required String eventName,
  }) async {
    try {
      final club = await ClubService.getClub(clubId);
      final clubName = club?.name ?? 'Club';

      await notifyUser(
        userId: userId,
        type: NotificationType.seatAvailable,
        title: 'Seat is open: $eventName',
        body: 'A seat is now available at $clubName! Open the app to take your spot.',
        clubId: clubId,
        clubName: clubName,
        data: {
          'action': 'view_event',
          'clubId': clubId,
          'eventId': eventId,
        },
      );
    } catch (e) {
      print('Error sending seat available notification: $e');
    }
  }

  /// Send notification to admin when a member RSVPs
  static Future<void> notifyAdminRSVP({
    required String clubId,
    required ClubEvent event,
    required String memberName,
    required String rsvpStatus,  // 'Going', 'Maybe', 'Can't go'
  }) async {
    try {
      final club = await ClubService.getClub(clubId);
      if (club == null) return;

      // Get admin user IDs (owner is the admin)
      final adminIds = <String>[club.ownerId];
      // Also include createdBy if different from owner
      if (club.createdBy.isNotEmpty && club.createdBy != club.ownerId) {
        adminIds.add(club.createdBy);
      }
      if (adminIds.isEmpty) return;

      // Don't notify if the RSVP is from an admin themselves
      final currentUserId = AuthService.userId;
      final nonCurrentAdminIds = adminIds.where((id) => id != currentUserId).toList();
      if (nonCurrentAdminIds.isEmpty) return;

      final notification = ClubNotification(
        id: '',
        clubId: clubId,
        clubName: club.name,
        eventId: event.id,
        type: NotificationType.memberRSVP,
        title: 'RSVP: $memberName',
        body: '$memberName responded "$rsvpStatus" to ${event.name}',
        data: {
          'action': 'view_event',
          'clubId': clubId,
          'eventId': event.id,
        },
        createdAt: DateTime.now(),
        recipientUserIds: nonCurrentAdminIds,
      );

      // Store in club's notifications subcollection
      final notificationRef = await _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_notificationsSubcollection)
          .add(notification.toFirestore());

      // Create individual user notification documents for admins
      final batch = _firestore.batch();
      for (final adminId in nonCurrentAdminIds) {
        final userNotificationRef = _firestore
            .collection(_userNotificationsCollection)
            .doc();
        batch.set(userNotificationRef, {
          ...notification.toFirestore(),
          'notificationId': notificationRef.id,
          'userId': adminId,
          'isRead': false,
        });
      }
      await batch.commit();
    } catch (e) {
      print('Error notifying admin about RSVP: $e');
    }
  }

  /// Get current user's notifications
  static Future<List<ClubNotification>> getUserNotifications({
    int limit = 50,
  }) async {
    final userId = AuthService.userId;
    print('📬 getUserNotifications: userId=$userId');
    if (userId == null) return [];

    try {
      // Avoid composite index by not using orderBy - sort locally instead
      final snapshot = await _firestore
          .collection(_userNotificationsCollection)
          .where('userId', isEqualTo: userId)
          .get();

      print('📬 getUserNotifications: Received ${snapshot.docs.length} documents');
      final notifications = snapshot.docs
          .map((doc) => ClubNotification.fromFirestore(doc))
          .toList();
      // Sort locally by createdAt descending
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      // Apply limit
      return notifications.take(limit).toList();
    } catch (e) {
      print('Error getting user notifications: $e');
      return [];
    }
  }

  /// Get unread notification count for current user
  static Future<int> getUnreadCount() async {
    final userId = AuthService.userId;
    if (userId == null) return 0;

    try {
      final snapshot = await _firestore
          .collection(_userNotificationsCollection)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  /// Watch unread notification count in real-time
  static Stream<int> watchUnreadCount() {
    final userId = AuthService.userId;
    if (userId == null) return Stream.value(0);

    return _firestore
        .collection(_userNotificationsCollection)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark a notification as read
  static Future<void> markAsRead(String notificationDocId) async {
    final userId = AuthService.userId;
    print('📬 markAsRead: notificationDocId=$notificationDocId, userId=$userId');
    if (userId == null) return;

    try {
      // Update directly by document ID
      await _firestore
          .collection(_userNotificationsCollection)
          .doc(notificationDocId)
          .update({'isRead': true});
      print('📬 markAsRead: Success');
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  static Future<void> markAllAsRead() async {
    final userId = AuthService.userId;
    if (userId == null) return;

    try {
      final snapshot = await _firestore
          .collection(_userNotificationsCollection)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  /// Delete old notifications (cleanup)
  static Future<void> cleanupOldNotifications({
    int daysToKeep = 30,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) return;

    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      final snapshot = await _firestore
          .collection(_userNotificationsCollection)
          .where('userId', isEqualTo: userId)
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Error cleaning up old notifications: $e');
    }
  }

  /// Watch user notifications in real-time
  static Stream<List<ClubNotification>> watchUserNotifications({
    int limit = 50,
  }) {
    final userId = AuthService.userId;
    print('📬 watchUserNotifications: userId=$userId');
    if (userId == null) {
      print('📬 watchUserNotifications: No user ID, returning empty stream');
      return Stream.value([]);
    }

    // Avoid composite index by not using orderBy - sort locally instead
    print('📬 watchUserNotifications: Setting up Firestore listener for userId=$userId');
    return _firestore
        .collection(_userNotificationsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          print('📬 watchUserNotifications: Received ${snapshot.docs.length} documents');
          final notifications = snapshot.docs
              .map((doc) => ClubNotification.fromFirestore(doc))
              .toList();
          // Sort locally by createdAt descending
          notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          // Apply limit
          return notifications.take(limit).toList();
        });
  }

  /// Format date for notification display
  static String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '${months[date.month - 1]} ${date.day} at $hour:${date.minute.toString().padLeft(2, '0')} $amPm';
  }

  // TODO: Implement FCM push notifications for production
  // static Future<void> _sendPushNotifications(
  //   List<String> userIds,
  //   String title,
  //   String body,
  //   Map<String, dynamic>? data,
  // ) async {
  //   // This would call Firebase Cloud Functions or Admin SDK
  //   // to send push notifications to the users
  // }
}
