import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/club_notification.dart';
import '../models/support_request.dart';
import 'auth_service.dart';
import 'club_notification_service.dart';

class SupportRequestService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'support_requests';
  static const String _adminsCollection = 'app_admins';

  static Future<bool> isAppAdmin() async {
    final userId = AuthService.userId;
    if (userId == null) return false;
    try {
      final doc = await _firestore.collection(_adminsCollection).doc(userId).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  static Future<SupportRequest> submitRequest({
    required String category,
    required String subject,
    required String description,
  }) async {
    final userId = AuthService.userId;
    final userEmail = AuthService.currentUser?.email ?? '';
    final userName = AuthService.userDisplayName;

    if (userId == null) throw 'User not authenticated';

    final now = DateTime.now();

    final request = SupportRequest(
      id: '',
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      category: category,
      subject: subject,
      description: description,
      submittedAt: now,
    );

    final docRef = await _firestore.collection(_collection).add(request.toFirestore());

    // Notify app admins via push notification
    _notifyAppAdmins(
      userName: userName,
      category: category,
      subject: subject,
      requestId: docRef.id,
    );

    return SupportRequest(
      id: docRef.id,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      category: category,
      subject: subject,
      description: description,
      submittedAt: now,
    );
  }

  static Future<void> _notifyAppAdmins({
    required String userName,
    required String category,
    required String subject,
    required String requestId,
  }) async {
    try {
      final snapshot = await _firestore.collection(_adminsCollection).get();
      for (final doc in snapshot.docs) {
        await ClubNotificationService.notifyUser(
          userId: doc.id,
          type: NotificationType.newSupportRequest,
          title: 'New Support Request',
          body: '$userName: [$category] $subject',
          data: {
            'action': 'view_support_requests',
            'requestId': requestId,
          },
        );
      }
    } catch (e) {
      // Don't throw — request was still created successfully
    }
  }

  static Future<List<SupportRequest>> getAllRequests({
    SupportRequestStatus? filterStatus,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(_collection)
          .orderBy('submittedAt', descending: true);

      if (filterStatus != null) {
        query = query.where('status', isEqualTo: filterStatus.value);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => SupportRequest.fromFirestore(doc)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<int> getPendingCount() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: SupportRequestStatus.pending.value)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<void> resolveRequest(String requestId, {String? response}) async {
    final adminId = AuthService.userId;
    if (adminId == null) throw 'User not authenticated';
    if (!await isAppAdmin()) throw 'Not authorized';

    final doc = await _firestore.collection(_collection).doc(requestId).get();
    final request = SupportRequest.fromFirestore(doc);

    await _firestore.collection(_collection).doc(requestId).update({
      'status': SupportRequestStatus.resolved.value,
      'reviewedBy': adminId,
      'reviewedAt': FieldValue.serverTimestamp(),
      if (response != null) 'adminResponse': response,
    });

    // Notify the user
    ClubNotificationService.notifyUser(
      userId: request.userId,
      type: NotificationType.supportRequestUpdated,
      title: 'Support Request Resolved',
      body: 'Your request "${request.subject}" has been resolved.',
      data: {'action': 'support_resolved', 'requestId': requestId},
    );
  }

  static Future<void> rejectRequest(String requestId, String reason) async {
    final adminId = AuthService.userId;
    if (adminId == null) throw 'User not authenticated';
    if (!await isAppAdmin()) throw 'Not authorized';

    final doc = await _firestore.collection(_collection).doc(requestId).get();
    final request = SupportRequest.fromFirestore(doc);

    await _firestore.collection(_collection).doc(requestId).update({
      'status': SupportRequestStatus.rejected.value,
      'reviewedBy': adminId,
      'reviewedAt': FieldValue.serverTimestamp(),
      'adminResponse': reason,
    });

    // Notify the user
    ClubNotificationService.notifyUser(
      userId: request.userId,
      type: NotificationType.supportRequestUpdated,
      title: 'Support Request Update',
      body: 'Your request "${request.subject}" has been closed. Reason: $reason',
      data: {'action': 'support_rejected', 'requestId': requestId},
    );
  }

  static Future<SupportRequest?> getRequest(String requestId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(requestId).get();
      if (doc.exists) return SupportRequest.fromFirestore(doc);
      return null;
    } catch (e) {
      return null;
    }
  }
}
