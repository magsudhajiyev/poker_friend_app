import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a club registration request
enum ClubRequestStatus {
  pending,
  approved,
  rejected,
}

extension ClubRequestStatusExtension on ClubRequestStatus {
  String get displayName {
    switch (this) {
      case ClubRequestStatus.pending:
        return 'Pending';
      case ClubRequestStatus.approved:
        return 'Approved';
      case ClubRequestStatus.rejected:
        return 'Rejected';
    }
  }

  String get value {
    switch (this) {
      case ClubRequestStatus.pending:
        return 'pending';
      case ClubRequestStatus.approved:
        return 'approved';
      case ClubRequestStatus.rejected:
        return 'rejected';
    }
  }

  static ClubRequestStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'approved':
        return ClubRequestStatus.approved;
      case 'rejected':
        return ClubRequestStatus.rejected;
      case 'pending':
      default:
        return ClubRequestStatus.pending;
    }
  }
}

/// Represents a club registration request
class ClubRequest {
  final String id;
  final String clubName;
  final String address;
  final String phone;
  final String adminEmail;  // Proposed club admin email
  final String requestedBy;  // userId of requester
  final String requestedByEmail;
  final String requestedByName;
  final DateTime requestedAt;
  final ClubRequestStatus status;
  final String? reviewedBy;  // App admin userId who reviewed
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final String? createdClubId;  // If approved, the created club ID

  ClubRequest({
    required this.id,
    required this.clubName,
    required this.address,
    required this.phone,
    required this.adminEmail,
    required this.requestedBy,
    required this.requestedByEmail,
    required this.requestedByName,
    required this.requestedAt,
    this.status = ClubRequestStatus.pending,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
    this.createdClubId,
  });

  /// Check if request is pending
  bool get isPending => status == ClubRequestStatus.pending;

  /// Check if request is approved
  bool get isApproved => status == ClubRequestStatus.approved;

  /// Check if request is rejected
  bool get isRejected => status == ClubRequestStatus.rejected;

  /// Factory constructor from Firestore document
  factory ClubRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClubRequest(
      id: doc.id,
      clubName: data['clubName'] ?? '',
      address: data['address'] ?? '',
      phone: data['phone'] ?? '',
      adminEmail: data['adminEmail'] ?? '',
      requestedBy: data['requestedBy'] ?? '',
      requestedByEmail: data['requestedByEmail'] ?? '',
      requestedByName: data['requestedByName'] ?? '',
      requestedAt: (data['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: ClubRequestStatusExtension.fromString(data['status']),
      reviewedBy: data['reviewedBy'],
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      rejectionReason: data['rejectionReason'],
      createdClubId: data['createdClubId'],
    );
  }

  /// Factory constructor from map
  factory ClubRequest.fromMap(Map<String, dynamic> map) {
    return ClubRequest(
      id: map['id'] ?? '',
      clubName: map['clubName'] ?? '',
      address: map['address'] ?? '',
      phone: map['phone'] ?? '',
      adminEmail: map['adminEmail'] ?? '',
      requestedBy: map['requestedBy'] ?? '',
      requestedByEmail: map['requestedByEmail'] ?? '',
      requestedByName: map['requestedByName'] ?? '',
      requestedAt: DateTime.tryParse(map['requestedAt'] ?? '') ?? DateTime.now(),
      status: ClubRequestStatusExtension.fromString(map['status']),
      reviewedBy: map['reviewedBy'],
      reviewedAt: map['reviewedAt'] != null
          ? DateTime.tryParse(map['reviewedAt'])
          : null,
      rejectionReason: map['rejectionReason'],
      createdClubId: map['createdClubId'],
    );
  }

  /// Convert to map for Firestore storage
  Map<String, dynamic> toFirestore() {
    return {
      'clubName': clubName,
      'address': address,
      'phone': phone,
      'adminEmail': adminEmail,
      'requestedBy': requestedBy,
      'requestedByEmail': requestedByEmail,
      'requestedByName': requestedByName,
      'requestedAt': Timestamp.fromDate(requestedAt),
      'status': status.value,
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (createdClubId != null) 'createdClubId': createdClubId,
    };
  }

  /// Convert to map for local storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clubName': clubName,
      'address': address,
      'phone': phone,
      'adminEmail': adminEmail,
      'requestedBy': requestedBy,
      'requestedByEmail': requestedByEmail,
      'requestedByName': requestedByName,
      'requestedAt': requestedAt.toIso8601String(),
      'status': status.value,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt?.toIso8601String(),
      'rejectionReason': rejectionReason,
      'createdClubId': createdClubId,
    };
  }

  /// Create a copy with updated values
  ClubRequest copyWith({
    ClubRequestStatus? status,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? rejectionReason,
    String? createdClubId,
  }) {
    return ClubRequest(
      id: id,
      clubName: clubName,
      address: address,
      phone: phone,
      adminEmail: adminEmail,
      requestedBy: requestedBy,
      requestedByEmail: requestedByEmail,
      requestedByName: requestedByName,
      requestedAt: requestedAt,
      status: status ?? this.status,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdClubId: createdClubId ?? this.createdClubId,
    );
  }
}
