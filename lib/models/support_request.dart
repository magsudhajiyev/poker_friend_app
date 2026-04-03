import 'package:cloud_firestore/cloud_firestore.dart';

enum SupportRequestStatus {
  pending,
  resolved,
  rejected,
}

extension SupportRequestStatusExtension on SupportRequestStatus {
  String get displayName {
    switch (this) {
      case SupportRequestStatus.pending:
        return 'Pending';
      case SupportRequestStatus.resolved:
        return 'Resolved';
      case SupportRequestStatus.rejected:
        return 'Rejected';
    }
  }

  String get value {
    switch (this) {
      case SupportRequestStatus.pending:
        return 'pending';
      case SupportRequestStatus.resolved:
        return 'resolved';
      case SupportRequestStatus.rejected:
        return 'rejected';
    }
  }

  static SupportRequestStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'resolved':
        return SupportRequestStatus.resolved;
      case 'rejected':
        return SupportRequestStatus.rejected;
      case 'pending':
      default:
        return SupportRequestStatus.pending;
    }
  }
}

class SupportRequest {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String category;
  final String subject;
  final String description;
  final SupportRequestStatus status;
  final DateTime submittedAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? adminResponse;

  SupportRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.category,
    required this.subject,
    required this.description,
    this.status = SupportRequestStatus.pending,
    required this.submittedAt,
    this.reviewedBy,
    this.reviewedAt,
    this.adminResponse,
  });

  bool get isPending => status == SupportRequestStatus.pending;
  bool get isResolved => status == SupportRequestStatus.resolved;
  bool get isRejected => status == SupportRequestStatus.rejected;

  factory SupportRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SupportRequest(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      category: data['category'] ?? '',
      subject: data['subject'] ?? '',
      description: data['description'] ?? '',
      status: SupportRequestStatusExtension.fromString(data['status']),
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedBy: data['reviewedBy'],
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      adminResponse: data['adminResponse'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'category': category,
      'subject': subject,
      'description': description,
      'status': status.value,
      'submittedAt': Timestamp.fromDate(submittedAt),
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      if (adminResponse != null) 'adminResponse': adminResponse,
    };
  }
}
