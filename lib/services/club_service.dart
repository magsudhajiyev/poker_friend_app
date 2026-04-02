import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/club.dart';
import '../models/club_member.dart';
import 'auth_service.dart';
import 'fcm_service.dart';

/// Service for managing poker clubs
class ClubService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _clubsCollection = 'clubs';
  static const String _membersSubcollection = 'members';
  static const String _dealersCollection = 'dealers';

  /// Create a new club (admin only)
  /// The creator becomes the owner, or a different owner can be specified
  static Future<Club> createClub({
    required String name,
    ClubSettings? settings,
    String? ownerUserId,  // Can specify different owner (for admin creating clubs)
    String? ownerDisplayName,  // Display name for the owner (if different from current user)
    String? ownerEmail,  // Email for the owner (if different from current user)
  }) async {
    final adminId = AuthService.userId;
    if (adminId == null) throw 'User not authenticated';

    final ownerId = ownerUserId ?? adminId;
    // Use provided owner info, or fall back to current user's info if owner is current user
    final displayName = ownerDisplayName ??
        (ownerId == adminId ? AuthService.userDisplayName : 'Club Owner');
    final email = ownerEmail ??
        (ownerId == adminId ? AuthService.currentUser?.email : null);
    final now = DateTime.now();

    final clubData = Club(
      id: '',  // Will be assigned by Firestore
      name: name,
      ownerId: ownerId,
      createdBy: adminId,
      createdAt: now,
      settings: settings ?? ClubSettings(),
    );

    // Create club document
    final clubRef = await _firestore.collection(_clubsCollection).add(
      clubData.toFirestore(),
    );

    // Add owner as a member
    await clubRef.collection(_membersSubcollection).add(
      ClubMember(
        id: '',
        userId: ownerId,
        displayName: displayName,
        email: email,
        role: ClubRole.owner,
        joinedAt: now,
      ).toFirestore(),
    );

    // Update owner's dealers document to include this club
    await _addClubToDealer(ownerId, clubRef.id);

    return Club(
      id: clubRef.id,
      name: name,
      ownerId: ownerId,
      createdBy: adminId,
      createdAt: now,
      settings: settings ?? ClubSettings(),
    );
  }

  /// Get clubs where the current user is a member
  static Future<List<Club>> getClubs() async {
    final userId = AuthService.userId;
    if (userId == null) return [];

    try {
      // First try to get club IDs from the dealers document (faster)
      final dealerClubIds = await AuthService.getDealerClubIds();

      if (dealerClubIds.isNotEmpty) {
        // Fetch all clubs the user belongs to
        final clubs = <Club>[];
        for (final clubId in dealerClubIds) {
          final club = await getClub(clubId);
          if (club != null) {
            clubs.add(club);
          }
        }
        if (clubs.isNotEmpty) {
          return clubs;
        }
      }

      // Fallback: Query clubs collection directly for membership
      // This is more reliable but slower
      return await _getClubsByMembership(userId);
    } catch (e) {
      print('Error getting clubs: $e');
      // Ultimate fallback
      return await _getClubsByMembership(userId);
    }
  }

  /// Get clubs by querying membership (slower but comprehensive)
  static Future<List<Club>> _getClubsByMembership(String userId) async {
    try {
      // Get all clubs
      final clubsSnapshot = await _firestore.collection(_clubsCollection).get();

      final clubs = <Club>[];
      for (final clubDoc in clubsSnapshot.docs) {
        // Check if user is a member
        final memberQuery = await clubDoc.reference
            .collection(_membersSubcollection)
            .where('userId', isEqualTo: userId)
            .limit(1)
            .get();

        if (memberQuery.docs.isNotEmpty) {
          clubs.add(Club.fromFirestore(clubDoc));
        }
      }

      return clubs;
    } catch (e) {
      print('Error getting clubs by membership: $e');
      return [];
    }
  }

  /// Get a single club by ID
  static Future<Club?> getClub(String clubId) async {
    try {
      final doc = await _firestore.collection(_clubsCollection).doc(clubId).get();
      if (doc.exists) {
        return Club.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting club: $e');
      return null;
    }
  }

  /// Update club settings and info
  static Future<void> updateClub(String clubId, {
    String? name,
    ClubSettings? settings,
    String? address,
    String? phone,
    String? description,
    String? appStoreQRUrl,
    String? playStoreQRUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (settings != null) updates['settings'] = settings.toMap();
    if (address != null) updates['address'] = address;
    if (phone != null) updates['phone'] = phone;
    if (description != null) updates['description'] = description;
    if (appStoreQRUrl != null) updates['appStoreQRUrl'] = appStoreQRUrl;
    if (playStoreQRUrl != null) updates['playStoreQRUrl'] = playStoreQRUrl;

    if (updates.isNotEmpty) {
      await _firestore.collection(_clubsCollection).doc(clubId).update(updates);
    }
  }

  /// Get members of a club
  static Future<List<ClubMember>> getMembers(String clubId) async {
    try {
      final snapshot = await _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_membersSubcollection)
          .get();

      return snapshot.docs.map((doc) => ClubMember.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting club members: $e');
      return [];
    }
  }

  /// Get a member's role in a club
  static Future<ClubRole?> getMemberRole(String clubId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_membersSubcollection)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return ClubMember.fromFirestore(snapshot.docs.first).role;
      }
      return null;
    } catch (e) {
      print('Error getting member role: $e');
      return null;
    }
  }

  /// Check if user can manage dealers in this club
  static Future<bool> canManageDealers(String clubId) async {
    final userId = AuthService.userId;
    if (userId == null) return false;

    final role = await getMemberRole(clubId, userId);
    return role?.canManageDealers ?? false;
  }

  /// Check if user can manage events in this club
  static Future<bool> canManageEvents(String clubId) async {
    final userId = AuthService.userId;
    if (userId == null) return false;

    final role = await getMemberRole(clubId, userId);
    // Owners and admins can manage events
    return role == ClubRole.owner || role == ClubRole.admin;
  }

  /// Get all member user IDs for a club (for notifications)
  static Future<List<String>> getMemberUserIds(String clubId) async {
    try {
      final snapshot = await _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_membersSubcollection)
          .get();

      return snapshot.docs
          .map((doc) => doc.data()['userId'] as String?)
          .where((userId) => userId != null)
          .cast<String>()
          .toList();
    } catch (e) {
      print('Error getting member user IDs: $e');
      return [];
    }
  }

  /// Get member count for a club
  static Future<int> getMemberCount(String clubId) async {
    try {
      final snapshot = await _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_membersSubcollection)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      print('Error getting member count: $e');
      return 0;
    }
  }

  /// Watch members of a club in real-time
  static Stream<List<ClubMember>> watchMembers(String clubId) {
    return _firestore
        .collection(_clubsCollection)
        .doc(clubId)
        .collection(_membersSubcollection)
        .orderBy('joinedAt', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ClubMember.fromFirestore(doc)).toList());
  }

  /// Add a user as a member of a club
  static Future<void> addMemberToClub({
    required String clubId,
    required String userId,
    required String displayName,
    String? email,
    ClubRole role = ClubRole.player,
  }) async {
    final now = DateTime.now();

    // Add to club's members subcollection
    await _firestore
        .collection(_clubsCollection)
        .doc(clubId)
        .collection(_membersSubcollection)
        .add(
          ClubMember(
            id: '',
            userId: userId,
            displayName: displayName,
            email: email,
            role: role,
            joinedAt: now,
          ).toFirestore(),
        );

    // Add club to user's dealers document
    await _addClubToDealer(userId, clubId);

    // Subscribe current user to club FCM topic for push notifications
    if (userId == AuthService.userId) {
      try {
        await FCMService.subscribeToClub(clubId);
      } catch (e) {
        print('Failed to subscribe to club FCM topic: $e');
        // Don't fail membership if FCM subscription fails
      }
    }
  }

  /// Add a club ID to a dealer's document
  static Future<void> _addClubToDealer(String userId, String clubId) async {
    final dealerRef = _firestore.collection(_dealersCollection).doc(userId);
    final doc = await dealerRef.get();

    if (doc.exists) {
      // Add to existing clubIds array
      await dealerRef.update({
        'clubIds': FieldValue.arrayUnion([clubId]),
      });
    } else {
      // Create new dealer document
      await dealerRef.set({
        'accountType': 'dealer',
        'clubIds': [clubId],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Remove a club ID from a dealer's document
  static Future<void> removeClubFromDealer(String odUserIdToRemove, String clubId) async {
    final dealerRef = _firestore.collection(_dealersCollection).doc(odUserIdToRemove);
    await dealerRef.update({
      'clubIds': FieldValue.arrayRemove([clubId]),
    });
  }

  /// Update a member's role in a club
  static Future<void> updateMemberRole({
    required String clubId,
    required String userId,
    required ClubRole newRole,
  }) async {
    try {
      // Find the member document
      final snapshot = await _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_membersSubcollection)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        throw 'Member not found in club';
      }

      // Update the role
      await snapshot.docs.first.reference.update({
        'role': newRole.value,
      });
    } catch (e) {
      print('Error updating member role: $e');
      rethrow;
    }
  }

  /// Get a member by userId
  static Future<ClubMember?> getMember(String clubId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_membersSubcollection)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return ClubMember.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      print('Error getting member: $e');
      return null;
    }
  }

  /// Find club by name
  static Future<Club?> findClubByName(String name) async {
    try {
      final snapshot = await _firestore
          .collection(_clubsCollection)
          .where('name', isEqualTo: name)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return Club.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      print('Error finding club by name: $e');
      return null;
    }
  }

  /// Find member by display name in a club
  static Future<ClubMember?> findMemberByName(String clubId, String displayName) async {
    try {
      final snapshot = await _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_membersSubcollection)
          .where('displayName', isEqualTo: displayName)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return ClubMember.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      print('Error finding member by name: $e');
      return null;
    }
  }

  /// Listen to club updates in real-time
  static Stream<Club?> watchClub(String clubId) {
    return _firestore
        .collection(_clubsCollection)
        .doc(clubId)
        .snapshots()
        .map((doc) => doc.exists ? Club.fromFirestore(doc) : null);
  }

  /// Remove a member from a club
  static Future<void> removeMember(String clubId, String userId) async {
    try {
      // Find the member document
      final snapshot = await _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_membersSubcollection)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return; // Member not found, nothing to remove
      }

      // Delete the member document
      await snapshot.docs.first.reference.delete();

      // Remove club from user's dealers document
      await removeClubFromDealer(userId, clubId);

      // Unsubscribe current user from club FCM topic
      if (userId == AuthService.userId) {
        try {
          await FCMService.unsubscribeFromClub(clubId);
        } catch (e) {
          print('Failed to unsubscribe from club FCM topic: $e');
          // Don't fail removal if FCM unsubscription fails
        }
      }
    } catch (e) {
      print('Error removing member: $e');
      rethrow;
    }
  }

  /// Ensure a user is a member of a club (add if not exists)
  /// Used for auto-membership when players are seated via QR or dealer
  static Future<void> ensureMembership({
    required String clubId,
    required String userId,
    required String displayName,
    ClubRole role = ClubRole.player,
  }) async {
    try {
      final existingMember = await getMember(clubId, userId);
      if (existingMember == null) {
        await addMemberToClub(
          clubId: clubId,
          userId: userId,
          displayName: displayName,
          role: role,
        );
      }
    } catch (e) {
      print('Error ensuring membership: $e');
    }
  }
}
