import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/club.dart';
import '../models/club_member.dart';
import '../models/club_notification.dart';
import '../models/club_request.dart';
import 'auth_service.dart';
import 'club_service.dart';
import 'club_notification_service.dart';
import 'email_service.dart';

/// Service for managing club registration requests
class ClubRequestService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _requestsCollection = 'club_requests';
  static const String _adminsCollection = 'app_admins';

  /// Check if current user is a global app admin
  static Future<bool> isAppAdmin() async {
    final userId = AuthService.userId;
    if (userId == null) return false;

    try {
      final doc = await _firestore.collection(_adminsCollection).doc(userId).get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking app admin status: $e');
      return false;
    }
  }

  /// Get all app admins with their user details
  static Future<List<Map<String, dynamic>>> _getAppAdmins() async {
    try {
      final snapshot = await _firestore.collection(_adminsCollection).get();
      List<Map<String, dynamic>> admins = [];

      for (final doc in snapshot.docs) {
        final userDoc = await _firestore.collection('users').doc(doc.id).get();
        if (userDoc.exists) {
          admins.add({
            'userId': doc.id,
            'email': userDoc.data()?['email'] ?? '',
            'displayName': userDoc.data()?['displayName'] ?? '',
          });
        }
      }
      return admins;
    } catch (e) {
      debugPrint('Error getting app admins: $e');
      return [];
    }
  }

  /// Notify app admins about a new club registration request
  static Future<void> _notifyAppAdmins({
    required String clubName,
    required String requesterName,
    required String requesterEmail,
    required String requestId,
    String? address,
    String? phone,
  }) async {
    try {
      final admins = await _getAppAdmins();
      debugPrint('Notifying ${admins.length} app admins about new club request');

      for (final admin in admins) {
        // Send in-app notification (which triggers FCM via Cloud Function)
        await ClubNotificationService.notifyUser(
          userId: admin['userId'] as String,
          type: NotificationType.newClubRequest,
          title: 'New Club Request',
          body: '$requesterName wants to register "$clubName"',
          data: {
            'action': 'view_club_requests',
            'requestId': requestId,
          },
        );

        // Send email notification
        final email = admin['email'] as String;
        if (email.isNotEmpty) {
          await EmailService.sendNewClubRequestEmail(
            toEmail: email,
            clubName: clubName,
            requesterName: requesterName,
            requesterEmail: requesterEmail,
            address: address,
            phone: phone,
          );
        }
      }
    } catch (e) {
      debugPrint('Error notifying app admins: $e');
      // Don't throw - request was still created successfully
    }
  }

  /// Submit a new club registration request
  static Future<ClubRequest> submitRequest({
    required String clubName,
    required String address,
    required String phone,
    required String adminEmail,
  }) async {
    final userId = AuthService.userId;
    final userEmail = AuthService.currentUser?.email;
    final userName = AuthService.userDisplayName;

    if (userId == null) throw 'User not authenticated';

    final now = DateTime.now();

    final requestData = ClubRequest(
      id: '',
      clubName: clubName,
      address: address,
      phone: phone,
      adminEmail: adminEmail,
      requestedBy: userId,
      requestedByEmail: userEmail ?? '',
      requestedByName: userName ?? 'Unknown',
      requestedAt: now,
      status: ClubRequestStatus.pending,
    );

    final docRef = await _firestore
        .collection(_requestsCollection)
        .add(requestData.toFirestore());

    // Notify app admins about the new request
    await _notifyAppAdmins(
      clubName: clubName,
      requesterName: userName ?? 'Unknown',
      requesterEmail: userEmail ?? '',
      requestId: docRef.id,
      address: address,
      phone: phone,
    );

    return ClubRequest(
      id: docRef.id,
      clubName: clubName,
      address: address,
      phone: phone,
      adminEmail: adminEmail,
      requestedBy: userId,
      requestedByEmail: userEmail ?? '',
      requestedByName: userName ?? 'Unknown',
      requestedAt: now,
      status: ClubRequestStatus.pending,
    );
  }

  /// Get all club requests (for app admins)
  static Future<List<ClubRequest>> getAllRequests({
    ClubRequestStatus? filterStatus,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(_requestsCollection)
          .orderBy('requestedAt', descending: true);

      if (filterStatus != null) {
        query = query.where('status', isEqualTo: filterStatus.value);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => ClubRequest.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting club requests: $e');
      return [];
    }
  }

  /// Watch requests in real-time (for app admins)
  static Stream<List<ClubRequest>> watchRequests({
    ClubRequestStatus? filterStatus,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(_requestsCollection)
        .orderBy('requestedAt', descending: true);

    if (filterStatus != null) {
      query = query.where('status', isEqualTo: filterStatus.value);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => ClubRequest.fromFirestore(doc)).toList());
  }

  /// Get count of pending requests (for badge)
  static Future<int> getPendingCount() async {
    try {
      final snapshot = await _firestore
          .collection(_requestsCollection)
          .where('status', isEqualTo: ClubRequestStatus.pending.value)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error getting pending count: $e');
      return 0;
    }
  }

  /// Look up a user by email
  static Future<Map<String, dynamic>?> _findUserByEmail(String email) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return {
          'userId': doc.id,
          'displayName': doc.data()['displayName'] ?? doc.data()['name'] ?? 'Club Admin',
          'email': doc.data()['email'] ?? email,
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error finding user by email: $e');
      return null;
    }
  }

  /// Approve a club request (for app admins)
  static Future<Club> approveRequest(String requestId) async {
    final adminId = AuthService.userId;
    if (adminId == null) throw 'User not authenticated';

    // Verify caller is an app admin
    if (!await isAppAdmin()) {
      throw 'Not authorized to approve requests';
    }

    // Get the request
    final requestDoc = await _firestore
        .collection(_requestsCollection)
        .doc(requestId)
        .get();

    if (!requestDoc.exists) {
      throw 'Request not found';
    }

    final request = ClubRequest.fromFirestore(requestDoc);

    if (request.status != ClubRequestStatus.pending) {
      throw 'Request has already been reviewed';
    }

    // Try to find the user by adminEmail to make them the owner
    final adminUser = await _findUserByEmail(request.adminEmail);
    String ownerUserId;
    String ownerDisplayName;
    String ownerEmail;

    if (adminUser != null) {
      // adminEmail user exists - make them the owner
      ownerUserId = adminUser['userId'] as String;
      ownerDisplayName = adminUser['displayName'] as String;
      ownerEmail = adminUser['email'] as String;
    } else {
      // If adminEmail user not found, use the requester as owner
      ownerUserId = request.requestedBy;
      ownerDisplayName = request.requestedByName;
      ownerEmail = request.requestedByEmail;
    }

    // Create the club with the correct owner (NOT the app admin)
    final club = await ClubService.createClub(
      name: request.clubName,
      ownerUserId: ownerUserId,
      ownerDisplayName: ownerDisplayName,
      ownerEmail: ownerEmail,
    );

    // Update club with address, phone, and app download QR URLs
    await ClubService.updateClub(
      club.id,
      address: request.address,
      phone: request.phone,
      appStoreQRUrl: 'https://apps.apple.com/us/app/final-table/id6760188970',
      playStoreQRUrl: 'https://play.google.com/store/apps/details?id=com.finaltable.app',
    );

    // If adminEmail user is different from requester and was found,
    // make sure they're added as owner
    if (adminUser != null && adminUser['userId'] != request.requestedBy) {
      // Also add the requester as a member (admin role) if different from owner
      await ClubService.addMemberToClub(
        clubId: club.id,
        userId: request.requestedBy,
        displayName: request.requestedByName,
        email: request.requestedByEmail,
        role: ClubRole.admin,
      );
    }

    // Update request status
    await _firestore.collection(_requestsCollection).doc(requestId).update({
      'status': ClubRequestStatus.approved.value,
      'reviewedBy': adminId,
      'reviewedAt': FieldValue.serverTimestamp(),
      'createdClubId': club.id,
    });

    // Send in-app notification to the requester
    await ClubNotificationService.notifyUser(
      userId: request.requestedBy,
      type: NotificationType.clubApproved,
      title: 'Club Approved!',
      body: 'Your club "${request.clubName}" has been approved and is now active.',
      clubId: club.id,
      clubName: request.clubName,
      data: {
        'action': 'view_club',
        'clubId': club.id,
      },
    );

    // If adminEmail is different from requester and the user exists, notify them too
    if (adminUser != null && adminUser['userId'] != request.requestedBy) {
      await ClubNotificationService.notifyUser(
        userId: adminUser['userId'] as String,
        type: NotificationType.clubApproved,
        title: 'You\'re a Club Owner!',
        body: 'You\'ve been assigned as owner of "${request.clubName}".',
        clubId: club.id,
        clubName: request.clubName,
        data: {
          'action': 'view_club',
          'clubId': club.id,
        },
      );
    }

    // Send notification email to the club admin
    await EmailService.sendClubApprovalEmail(
      toEmail: request.adminEmail,
      clubName: request.clubName,
    );

    return club;
  }

  /// Reject a club request (for app admins)
  static Future<void> rejectRequest(String requestId, String reason) async {
    final adminId = AuthService.userId;
    if (adminId == null) throw 'User not authenticated';

    // Verify caller is an app admin
    if (!await isAppAdmin()) {
      throw 'Not authorized to reject requests';
    }

    // Get the request
    final requestDoc = await _firestore
        .collection(_requestsCollection)
        .doc(requestId)
        .get();

    if (!requestDoc.exists) {
      throw 'Request not found';
    }

    final request = ClubRequest.fromFirestore(requestDoc);

    if (request.status != ClubRequestStatus.pending) {
      throw 'Request has already been reviewed';
    }

    // Update request status
    await _firestore.collection(_requestsCollection).doc(requestId).update({
      'status': ClubRequestStatus.rejected.value,
      'reviewedBy': adminId,
      'reviewedAt': FieldValue.serverTimestamp(),
      'rejectionReason': reason,
    });

    // Send in-app notification to the requester
    await ClubNotificationService.notifyUser(
      userId: request.requestedBy,
      type: NotificationType.clubRejected,
      title: 'Club Request Declined',
      body: 'Your request for "${request.clubName}" was declined. Reason: $reason',
      data: {
        'action': 'view_requests',
      },
    );
  }

  /// Get requests submitted by current user
  static Future<List<ClubRequest>> getMyRequests() async {
    final userId = AuthService.userId;
    if (userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection(_requestsCollection)
          .where('requestedBy', isEqualTo: userId)
          .orderBy('requestedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => ClubRequest.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting my requests: $e');
      return [];
    }
  }

  /// Get a specific request by ID
  static Future<ClubRequest?> getRequest(String requestId) async {
    try {
      final doc = await _firestore
          .collection(_requestsCollection)
          .doc(requestId)
          .get();

      if (doc.exists) {
        return ClubRequest.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting request: $e');
      return null;
    }
  }
}
