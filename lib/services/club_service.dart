import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/club.dart';
import '../models/club_member.dart';
import 'auth_service.dart';

/// Service for managing poker clubs
class ClubService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _clubsCollection = 'clubs';
  static const String _membersSubcollection = 'members';
  static const String _dealersCollection = 'dealers';

  /// Create a new club (admin only)
  /// The creator becomes the owner
  static Future<Club> createClub({
    required String name,
    ClubSettings? settings,
    String? ownerUserId,  // Can specify different owner (for admin creating clubs)
  }) async {
    final adminId = AuthService.userId;
    if (adminId == null) throw 'User not authenticated';

    final ownerId = ownerUserId ?? adminId;
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
        displayName: AuthService.userDisplayName,
        email: AuthService.currentUser?.email,
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
      // First get club IDs from the dealers document
      final dealerClubIds = await AuthService.getDealerClubIds();

      if (dealerClubIds.isEmpty) {
        // Fallback: Query clubs collection directly for membership
        // This is less efficient but works as backup
        return await _getClubsByMembership(userId);
      }

      // Fetch all clubs the user belongs to
      final clubs = <Club>[];
      for (final clubId in dealerClubIds) {
        final club = await getClub(clubId);
        if (club != null) {
          clubs.add(club);
        }
      }

      return clubs;
    } catch (e) {
      print('Error getting clubs: $e');
      return [];
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

  /// Update club settings
  static Future<void> updateClub(String clubId, {
    String? name,
    ClubSettings? settings,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (settings != null) updates['settings'] = settings.toMap();

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

  /// Listen to club updates in real-time
  static Stream<Club?> watchClub(String clubId) {
    return _firestore
        .collection(_clubsCollection)
        .doc(clubId)
        .snapshots()
        .map((doc) => doc.exists ? Club.fromFirestore(doc) : null);
  }
}
