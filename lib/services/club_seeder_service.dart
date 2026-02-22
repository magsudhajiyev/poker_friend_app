import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/club.dart';
import '../models/club_member.dart';
import 'club_service.dart';
import 'auth_service.dart';

/// Service for seeding club data (one-time use)
class ClubSeederService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Seed the database with initial clubs and members
  /// This should only be run once
  static Future<void> seedClubs() async {
    print('Starting club seeding...');

    // Club names to create
    final clubNames = ['Poczekalia', 'House of Cards', 'Gringster Room'];

    // Users to associate with clubs
    final usersToAdd = ['test', 'gringo'];

    // Look up users by displayNameLower
    final users = <Map<String, String>>[];
    for (final username in usersToAdd) {
      final user = await _findUserByDisplayName(username);
      if (user != null) {
        users.add(user);
        print('Found user: ${user['displayName']} (${user['uid']})');
      } else {
        print('User not found: $username');
      }
    }

    // Also add current logged-in user
    final currentUserId = AuthService.userId;
    final currentUserName = AuthService.userDisplayName;
    final currentUserEmail = AuthService.currentUser?.email;
    if (currentUserId != null) {
      // Check if already in list
      final alreadyAdded = users.any((u) => u['uid'] == currentUserId);
      if (!alreadyAdded) {
        users.add({
          'uid': currentUserId,
          'displayName': currentUserName,
          'email': currentUserEmail ?? '',
        });
        print('Added current user: $currentUserName ($currentUserId)');
      }
    }

    if (users.isEmpty) {
      print('No users found to associate with clubs. Aborting.');
      return;
    }

    // Create clubs and add members
    for (final clubName in clubNames) {
      // Check if club already exists
      final existingClub = await _findClubByName(clubName);
      if (existingClub != null) {
        print('Club "$clubName" already exists (${existingClub.id}), skipping creation.');

        // Still add members if not already added
        for (final user in users) {
          await _addMemberIfNotExists(existingClub.id, user);
        }
        continue;
      }

      // Create the club
      final club = await _createClub(clubName);
      print('Created club: ${club.name} (${club.id})');

      // Add users as members
      for (final user in users) {
        await ClubService.addMemberToClub(
          clubId: club.id,
          userId: user['uid']!,
          displayName: user['displayName']!,
          email: user['email'],
          role: ClubRole.player,
        );
        print('  Added ${user['displayName']} as player to ${club.name}');
      }
    }

    print('Club seeding complete!');
  }

  /// Find a user by display name (case-insensitive, tries multiple approaches)
  static Future<Map<String, String>?> _findUserByDisplayName(String displayName) async {
    try {
      // Try exact match on displayNameLower
      var snapshot = await _firestore
          .collection('users')
          .where('displayNameLower', isEqualTo: displayName.toLowerCase())
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        return {
          'uid': data['uid'] ?? snapshot.docs.first.id,
          'displayName': data['displayName'] ?? displayName,
          'email': data['email'] ?? '',
        };
      }

      // Try prefix search on displayNameLower
      final queryLower = displayName.toLowerCase();
      final queryEnd = queryLower.substring(0, queryLower.length - 1) +
          String.fromCharCode(queryLower.codeUnitAt(queryLower.length - 1) + 1);

      snapshot = await _firestore
          .collection('users')
          .where('displayNameLower', isGreaterThanOrEqualTo: queryLower)
          .where('displayNameLower', isLessThan: queryEnd)
          .limit(5)
          .get();

      if (snapshot.docs.isNotEmpty) {
        // Find best match
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final name = (data['displayName'] as String?)?.toLowerCase() ?? '';
          if (name.contains(displayName.toLowerCase())) {
            print('  Found user by prefix: ${data['displayName']}');
            return {
              'uid': data['uid'] ?? doc.id,
              'displayName': data['displayName'] ?? displayName,
              'email': data['email'] ?? '',
            };
          }
        }
      }

      // Try searching by email prefix
      snapshot = await _firestore
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: '${displayName.toLowerCase()}@')
          .where('email', isLessThan: '${displayName.toLowerCase()}@\uf8ff')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        print('  Found user by email: ${data['email']}');
        return {
          'uid': data['uid'] ?? snapshot.docs.first.id,
          'displayName': data['displayName'] ?? displayName,
          'email': data['email'] ?? '',
        };
      }

      return null;
    } catch (e) {
      print('Error finding user: $e');
      return null;
    }
  }

  /// Find a club by name
  static Future<Club?> _findClubByName(String name) async {
    try {
      final snapshot = await _firestore
          .collection('clubs')
          .where('name', isEqualTo: name)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return Club.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      print('Error finding club: $e');
      return null;
    }
  }

  /// Create a club without an owner (system-created)
  static Future<Club> _createClub(String name) async {
    final now = DateTime.now();

    final clubData = Club(
      id: '',
      name: name,
      ownerId: 'system', // System-created club
      createdBy: 'system',
      createdAt: now,
      settings: ClubSettings(),
    );

    final clubRef = await _firestore.collection('clubs').add(
      clubData.toFirestore(),
    );

    return Club(
      id: clubRef.id,
      name: name,
      ownerId: 'system',
      createdBy: 'system',
      createdAt: now,
      settings: ClubSettings(),
    );
  }

  /// Add member to club if not already a member
  static Future<void> _addMemberIfNotExists(String clubId, Map<String, String> user) async {
    try {
      final snapshot = await _firestore
          .collection('clubs')
          .doc(clubId)
          .collection('members')
          .where('userId', isEqualTo: user['uid'])
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        await ClubService.addMemberToClub(
          clubId: clubId,
          userId: user['uid']!,
          displayName: user['displayName']!,
          email: user['email'],
          role: ClubRole.player,
        );
        print('  Added ${user['displayName']} as player');
      } else {
        // Member exists in club, but make sure dealers document has this club
        await _ensureDealerHasClub(user['uid']!, clubId);
        print('  ${user['displayName']} already a member, ensured dealers doc updated');
      }
    } catch (e) {
      print('Error adding member: $e');
    }
  }

  /// Ensure the dealers document has this club ID
  static Future<void> _ensureDealerHasClub(String userId, String clubId) async {
    try {
      final dealerRef = _firestore.collection('dealers').doc(userId);
      final doc = await dealerRef.get();

      if (doc.exists) {
        // Add to existing clubIds array (arrayUnion won't duplicate)
        await dealerRef.update({
          'clubIds': FieldValue.arrayUnion([clubId]),
        });
      } else {
        // Create new dealer document
        await dealerRef.set({
          'accountType': 'player',
          'clubIds': [clubId],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error ensuring dealer has club: $e');
    }
  }

  /// Promote current user to admin for a specific club
  /// Returns true if successful, false otherwise
  static Future<bool> promoteCurrentUserToAdmin(String clubName) async {
    try {
      final userId = AuthService.userId;
      if (userId == null) {
        print('User not authenticated');
        return false;
      }

      // Find the club by name
      final club = await _findClubByName(clubName);
      if (club == null) {
        print('Club "$clubName" not found');
        return false;
      }

      // Find the user's member document
      final snapshot = await _firestore
          .collection('clubs')
          .doc(club.id)
          .collection('members')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        print('User is not a member of "$clubName"');
        return false;
      }

      // Update the role to admin
      await snapshot.docs.first.reference.update({
        'role': ClubRole.admin.value,
      });

      print('Successfully promoted user to admin of "$clubName"');
      return true;
    } catch (e) {
      print('Error promoting user to admin: $e');
      return false;
    }
  }

  /// Make current user owner of a specific club (for testing only)
  /// This also updates the club's ownerId field
  static Future<bool> makeCurrentUserOwner(String clubName) async {
    try {
      final userId = AuthService.userId;
      if (userId == null) {
        print('User not authenticated');
        return false;
      }

      // Find the club by name
      final club = await _findClubByName(clubName);
      if (club == null) {
        print('Club "$clubName" not found');
        return false;
      }

      // Find the user's member document
      final snapshot = await _firestore
          .collection('clubs')
          .doc(club.id)
          .collection('members')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        print('User is not a member of "$clubName"');
        return false;
      }

      // Update the role to owner
      await snapshot.docs.first.reference.update({
        'role': ClubRole.owner.value,
      });

      // Update the club's ownerId
      await _firestore.collection('clubs').doc(club.id).update({
        'ownerId': userId,
      });

      print('Successfully made user owner of "$clubName"');
      return true;
    } catch (e) {
      print('Error making user owner: $e');
      return false;
    }
  }
}
