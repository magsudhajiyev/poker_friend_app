import 'package:cloud_firestore/cloud_firestore.dart';

/// Type of club notification
enum NotificationType {
  eventCreated,
  eventUpdated,
  eventCancelled,
  eventStarting,    // 1 hour before
  eventStarted,     // When status -> active
  memberRSVP,       // When a member RSVPs to an event
  newClubRequest,   // When a new club registration is submitted (for app admins)
  clubApproved,     // When a club request is approved
  clubRejected,     // When a club request is rejected
  memberInvited,    // When user is invited to join a club
  invitationAccepted, // When invited user accepts the invitation
  invitationDeclined, // When invited user declines the invitation
  seatAvailable,    // When a seat becomes available for waitlist member
  newSupportRequest, // When a user submits a support request (for app admins)
  supportRequestUpdated, // When admin resolves/rejects a support request (for user)
}

extension NotificationTypeExtension on NotificationType {
  String get displayName {
    switch (this) {
      case NotificationType.eventCreated:
        return 'New Event';
      case NotificationType.eventUpdated:
        return 'Event Updated';
      case NotificationType.eventCancelled:
        return 'Event Cancelled';
      case NotificationType.eventStarting:
        return 'Event Starting Soon';
      case NotificationType.eventStarted:
        return 'Event Started';
      case NotificationType.memberRSVP:
        return 'Member RSVP';
      case NotificationType.newClubRequest:
        return 'New Club Request';
      case NotificationType.clubApproved:
        return 'Club Approved';
      case NotificationType.clubRejected:
        return 'Club Rejected';
      case NotificationType.memberInvited:
        return 'Club Invitation';
      case NotificationType.invitationAccepted:
        return 'Invitation Accepted';
      case NotificationType.invitationDeclined:
        return 'Invitation Declined';
      case NotificationType.seatAvailable:
        return 'Seat Available';
      case NotificationType.newSupportRequest:
        return 'Support Request';
      case NotificationType.supportRequestUpdated:
        return 'Support Update';
    }
  }

  String get value {
    switch (this) {
      case NotificationType.eventCreated:
        return 'event_created';
      case NotificationType.eventUpdated:
        return 'event_updated';
      case NotificationType.eventCancelled:
        return 'event_cancelled';
      case NotificationType.eventStarting:
        return 'event_starting';
      case NotificationType.eventStarted:
        return 'event_started';
      case NotificationType.memberRSVP:
        return 'member_rsvp';
      case NotificationType.newClubRequest:
        return 'new_club_request';
      case NotificationType.clubApproved:
        return 'club_approved';
      case NotificationType.clubRejected:
        return 'club_rejected';
      case NotificationType.memberInvited:
        return 'member_invited';
      case NotificationType.invitationAccepted:
        return 'invitation_accepted';
      case NotificationType.invitationDeclined:
        return 'invitation_declined';
      case NotificationType.seatAvailable:
        return 'seat_available';
      case NotificationType.newSupportRequest:
        return 'new_support_request';
      case NotificationType.supportRequestUpdated:
        return 'support_request_updated';
    }
  }

  static NotificationType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'event_created':
        return NotificationType.eventCreated;
      case 'event_updated':
        return NotificationType.eventUpdated;
      case 'event_cancelled':
        return NotificationType.eventCancelled;
      case 'event_starting':
        return NotificationType.eventStarting;
      case 'event_started':
        return NotificationType.eventStarted;
      case 'member_rsvp':
        return NotificationType.memberRSVP;
      case 'new_club_request':
        return NotificationType.newClubRequest;
      case 'club_approved':
        return NotificationType.clubApproved;
      case 'club_rejected':
        return NotificationType.clubRejected;
      case 'member_invited':
        return NotificationType.memberInvited;
      case 'invitation_accepted':
        return NotificationType.invitationAccepted;
      case 'invitation_declined':
        return NotificationType.invitationDeclined;
      case 'seat_available':
        return NotificationType.seatAvailable;
      case 'new_support_request':
        return NotificationType.newSupportRequest;
      case 'support_request_updated':
        return NotificationType.supportRequestUpdated;
      default:
        return NotificationType.eventCreated;
    }
  }
}

/// Represents a notification sent to club members
class ClubNotification {
  final String id;
  final String clubId;
  final String clubName;
  final String? eventId;
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic> data;  // Deep link payload
  final DateTime createdAt;
  final List<String> recipientUserIds;  // For targeted notifications
  final bool isRead;

  ClubNotification({
    required this.id,
    required this.clubId,
    required this.clubName,
    this.eventId,
    required this.type,
    required this.title,
    required this.body,
    this.data = const {},
    required this.createdAt,
    this.recipientUserIds = const [],
    this.isRead = false,
  });

  /// Factory constructor from Firestore document
  factory ClubNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClubNotification(
      id: doc.id,
      clubId: data['clubId'] ?? '',
      clubName: data['clubName'] ?? '',
      eventId: data['eventId'],
      type: NotificationTypeExtension.fromString(data['type']),
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      recipientUserIds: List<String>.from(data['recipientUserIds'] ?? []),
      isRead: data['isRead'] ?? false,
    );
  }

  /// Factory constructor from map
  factory ClubNotification.fromMap(Map<String, dynamic> map) {
    return ClubNotification(
      id: map['id'] ?? '',
      clubId: map['clubId'] ?? '',
      clubName: map['clubName'] ?? '',
      eventId: map['eventId'],
      type: NotificationTypeExtension.fromString(map['type']),
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      data: Map<String, dynamic>.from(map['data'] ?? {}),
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      recipientUserIds: List<String>.from(map['recipientUserIds'] ?? []),
      isRead: map['isRead'] ?? false,
    );
  }

  /// Convert to map for Firestore storage
  Map<String, dynamic> toFirestore() {
    return {
      'clubId': clubId,
      'clubName': clubName,
      'eventId': eventId,
      'type': type.value,
      'title': title,
      'body': body,
      'data': data,
      'createdAt': Timestamp.fromDate(createdAt),
      'recipientUserIds': recipientUserIds,
      'isRead': isRead,
    };
  }

  /// Convert to map for local storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clubId': clubId,
      'clubName': clubName,
      'eventId': eventId,
      'type': type.value,
      'title': title,
      'body': body,
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'recipientUserIds': recipientUserIds,
      'isRead': isRead,
    };
  }

  /// Create a copy with updated values
  ClubNotification copyWith({
    bool? isRead,
  }) {
    return ClubNotification(
      id: id,
      clubId: clubId,
      clubName: clubName,
      eventId: eventId,
      type: type,
      title: title,
      body: body,
      data: data,
      createdAt: createdAt,
      recipientUserIds: recipientUserIds,
      isRead: isRead ?? this.isRead,
    );
  }
}
