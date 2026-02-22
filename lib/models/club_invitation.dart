import 'package:cloud_firestore/cloud_firestore.dart';
import 'club_member.dart';

/// Status of an invitation
enum InvitationStatus {
  pending,
  accepted,
  declined,
  expired,
}

extension InvitationStatusExtension on InvitationStatus {
  String get displayName {
    switch (this) {
      case InvitationStatus.pending:
        return 'Pending';
      case InvitationStatus.accepted:
        return 'Accepted';
      case InvitationStatus.declined:
        return 'Declined';
      case InvitationStatus.expired:
        return 'Expired';
    }
  }

  String get value {
    switch (this) {
      case InvitationStatus.pending:
        return 'pending';
      case InvitationStatus.accepted:
        return 'accepted';
      case InvitationStatus.declined:
        return 'declined';
      case InvitationStatus.expired:
        return 'expired';
    }
  }

  static InvitationStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'accepted':
        return InvitationStatus.accepted;
      case 'declined':
        return InvitationStatus.declined;
      case 'expired':
        return InvitationStatus.expired;
      case 'pending':
      default:
        return InvitationStatus.pending;
    }
  }
}

/// Represents an invitation to join a club
class ClubInvitation {
  final String id;
  final String clubId;
  final String? clubName;  // Denormalized for display
  final String email;
  final String? token;  // Unique token for shareable link (one-time use)
  final ClubRole role;
  final InvitationStatus status;
  final String invitedBy;  // userId of person who sent invitation
  final String? invitedByName;  // Denormalized for display
  final DateTime createdAt;
  final DateTime expiresAt;

  ClubInvitation({
    required this.id,
    required this.clubId,
    this.clubName,
    required this.email,
    this.token,
    required this.role,
    this.status = InvitationStatus.pending,
    required this.invitedBy,
    this.invitedByName,
    required this.createdAt,
    required this.expiresAt,
  });

  /// Get shareable invitation code (last 8 chars of token for readability)
  String? get inviteCode => token;

  /// Check if invitation is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Check if invitation can be accepted
  bool get canAccept =>
      status == InvitationStatus.pending && !isExpired;

  /// Factory constructor from Firestore document
  factory ClubInvitation.fromFirestore(DocumentSnapshot doc, {String? clubId}) {
    final data = doc.data() as Map<String, dynamic>;
    return ClubInvitation(
      id: doc.id,
      clubId: clubId ?? data['clubId'] ?? '',
      clubName: data['clubName'],
      email: data['email'] ?? '',
      role: ClubRoleExtension.fromString(data['role']),
      status: InvitationStatusExtension.fromString(data['status']),
      invitedBy: data['invitedBy'] ?? '',
      invitedByName: data['invitedByName'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(days: 7)),
    );
  }

  /// Factory constructor from map
  factory ClubInvitation.fromMap(Map<String, dynamic> map) {
    return ClubInvitation(
      id: map['id'] ?? '',
      clubId: map['clubId'] ?? '',
      clubName: map['clubName'],
      email: map['email'] ?? '',
      role: ClubRoleExtension.fromString(map['role']),
      status: InvitationStatusExtension.fromString(map['status']),
      invitedBy: map['invitedBy'] ?? '',
      invitedByName: map['invitedByName'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(map['expiresAt'] ?? '') ??
          DateTime.now().add(const Duration(days: 7)),
    );
  }

  /// Convert to map for Firestore storage
  Map<String, dynamic> toFirestore() {
    return {
      'clubId': clubId,
      'clubName': clubName,
      'email': email,
      'role': role.value,
      'status': status.value,
      'invitedBy': invitedBy,
      'invitedByName': invitedByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  /// Convert to map for local storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clubId': clubId,
      'clubName': clubName,
      'email': email,
      'role': role.value,
      'status': status.value,
      'invitedBy': invitedBy,
      'invitedByName': invitedByName,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  /// Create a copy with updated values
  ClubInvitation copyWith({
    InvitationStatus? status,
  }) {
    return ClubInvitation(
      id: id,
      clubId: clubId,
      clubName: clubName,
      email: email,
      role: role,
      status: status ?? this.status,
      invitedBy: invitedBy,
      invitedByName: invitedByName,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }
}
