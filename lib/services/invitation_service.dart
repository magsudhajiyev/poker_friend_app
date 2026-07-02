import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/club_invitation.dart';
import '../models/club_member.dart';
import 'auth_service.dart';
import 'club_service.dart';
import 'email_service.dart';

/// Service for managing club invitations
class InvitationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _clubsCollection = 'clubs';
  static const String _invitationsSubcollection = 'invitations';
  static const String _membersSubcollection = 'members';
  static const String _dealersCollection = 'dealers';

  /// Create a new invitation to join a club
  static Future<ClubInvitation> createInvitation({
    required String clubId,
    required String email,
    required ClubRole role,
    int expirationDays = 7,
  }) async {
    final inviterId = AuthService.userId;
    if (inviterId == null) throw 'User not authenticated';

    // Get club name for the invitation
    final club = await ClubService.getClub(clubId);
    final clubName = club?.name ?? 'Unknown Club';

    final now = DateTime.now();
    final expiresAt = now.add(Duration(days: expirationDays));

    final invitation = ClubInvitation(
      id: '',
      clubId: clubId,
      clubName: clubName,
      email: email.toLowerCase().trim(),
      role: role,
      status: InvitationStatus.pending,
      invitedBy: inviterId,
      invitedByName: AuthService.userDisplayName,
      createdAt: now,
      expiresAt: expiresAt,
    );

    final ref = await _firestore
        .collection(_clubsCollection)
        .doc(clubId)
        .collection(_invitationsSubcollection)
        .add(invitation.toFirestore());

    // Send invitation email
    final emailSent = await EmailService.sendInvitationEmail(
      toEmail: email.toLowerCase().trim(),
      clubName: clubName,
      clubId: clubId,
      invitationId: ref.id,
      inviterName: AuthService.userDisplayName ?? 'A club admin',
    );

    if (!emailSent) {
      debugPrint('Warning: Invitation created but email failed to send');
    }

    return ClubInvitation(
      id: ref.id,
      clubId: clubId,
      clubName: clubName,
      email: email.toLowerCase().trim(),
      role: role,
      status: InvitationStatus.pending,
      invitedBy: inviterId,
      invitedByName: AuthService.userDisplayName,
      createdAt: now,
      expiresAt: expiresAt,
    );
  }

  /// Get pending invitations for the current user (by email)
  static Future<List<ClubInvitation>> getPendingInvitations() async {
    final email = AuthService.currentUser?.email?.toLowerCase().trim();
    if (email == null) return [];

    try {
      // collectionGroup query requires a Firestore index on (email, status)
      // but doesn't require reading all clubs — avoids permission errors.
      final snapshot = await _firestore
          .collectionGroup(_invitationsSubcollection)
          .where('email', isEqualTo: email)
          .where('status', isEqualTo: 'pending')
          .get();

      final invitations = <ClubInvitation>[];
      for (final doc in snapshot.docs) {
        // Extract clubId from path: clubs/{clubId}/invitations/{invId}
        final clubId = doc.reference.parent.parent?.id;
        if (clubId == null) continue;
        final invitation = ClubInvitation.fromFirestore(doc, clubId: clubId);
        if (!invitation.isExpired) {
          invitations.add(invitation);
        }
      }
      return invitations;
    } catch (e) {
      // Silently return empty list — user may not be invited to any club.
      return [];
    }
  }

  /// Get invitations for a specific club (for club owners/admins)
  static Future<List<ClubInvitation>> getClubInvitations(String clubId, {
    InvitationStatus? status,
  }) async {
    try {
      var query = _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_invitationsSubcollection)
          .orderBy('createdAt', descending: true);

      if (status != null) {
        query = query.where('status', isEqualTo: status.value);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => ClubInvitation.fromFirestore(doc, clubId: clubId))
          .toList();
    } catch (e) {
      debugPrint('Error getting club invitations: $e');
      return [];
    }
  }

  /// Accept an invitation
  static Future<void> acceptInvitation({
    required String clubId,
    required String invitationId,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) throw 'User not authenticated';

    // Get the invitation first
    final invRef = _firestore
        .collection(_clubsCollection)
        .doc(clubId)
        .collection(_invitationsSubcollection)
        .doc(invitationId);

    final invDoc = await invRef.get();
    if (!invDoc.exists) throw 'Invitation not found';

    final invitation = ClubInvitation.fromFirestore(invDoc, clubId: clubId);

    // Validate invitation
    if (!invitation.canAccept) {
      if (invitation.isExpired) {
        throw 'Invitation has expired';
      }
      throw 'Invitation cannot be accepted';
    }

    // Verify email matches
    final userEmail = AuthService.currentUser?.email?.toLowerCase().trim();
    if (userEmail != invitation.email) {
      throw 'Invitation is for a different email address';
    }

    final batch = _firestore.batch();

    // Update invitation status
    batch.update(invRef, {
      'status': InvitationStatus.accepted.value,
      'acceptedAt': FieldValue.serverTimestamp(),
    });

    // Add user as member
    final memberRef = _firestore
        .collection(_clubsCollection)
        .doc(clubId)
        .collection(_membersSubcollection)
        .doc();

    batch.set(memberRef, ClubMember(
      id: memberRef.id,
      userId: userId,
      displayName: AuthService.userDisplayName,
      email: userEmail,
      role: invitation.role,
      joinedAt: DateTime.now(),
    ).toFirestore());

    await batch.commit();

    // Update the user's dealers document if they're a dealer
    if (invitation.role == ClubRole.dealer ||
        invitation.role == ClubRole.admin ||
        invitation.role == ClubRole.owner) {
      await _addClubToDealer(userId, clubId);
    }
  }

  /// Decline an invitation
  static Future<void> declineInvitation({
    required String clubId,
    required String invitationId,
  }) async {
    await _firestore
        .collection(_clubsCollection)
        .doc(clubId)
        .collection(_invitationsSubcollection)
        .doc(invitationId)
        .update({
          'status': InvitationStatus.declined.value,
          'declinedAt': FieldValue.serverTimestamp(),
        });
  }

  /// Cancel an invitation (by the inviter)
  static Future<void> cancelInvitation({
    required String clubId,
    required String invitationId,
  }) async {
    await _firestore
        .collection(_clubsCollection)
        .doc(clubId)
        .collection(_invitationsSubcollection)
        .doc(invitationId)
        .delete();
  }

  /// Resend an invitation (creates a new one with fresh expiration)
  static Future<ClubInvitation> resendInvitation({
    required String clubId,
    required String invitationId,
  }) async {
    // Get the original invitation
    final invDoc = await _firestore
        .collection(_clubsCollection)
        .doc(clubId)
        .collection(_invitationsSubcollection)
        .doc(invitationId)
        .get();

    if (!invDoc.exists) throw 'Invitation not found';

    final oldInvitation = ClubInvitation.fromFirestore(invDoc, clubId: clubId);

    // Delete the old invitation
    await cancelInvitation(clubId: clubId, invitationId: invitationId);

    // Create a new invitation
    return await createInvitation(
      clubId: clubId,
      email: oldInvitation.email,
      role: oldInvitation.role,
    );
  }

  /// Add a club ID to a user's dealers document
  static Future<void> _addClubToDealer(String userId, String clubId) async {
    final dealerRef = _firestore.collection(_dealersCollection).doc(userId);
    final doc = await dealerRef.get();

    if (doc.exists) {
      await dealerRef.update({
        'clubIds': FieldValue.arrayUnion([clubId]),
      });
    } else {
      await dealerRef.set({
        'accountType': 'dealer',
        'clubIds': [clubId],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // Clear auth cache so new account type is fetched
    AuthService.clearAccountTypeCache();
  }

  /// Get an invitation by its shareable token code (searches all clubs)
  /// Returns null if no matching valid invitation is found
  static Future<ClubInvitation?> getInvitationByToken(String token) async {
    try {
      final clubsSnapshot = await _firestore.collection(_clubsCollection).get();

      for (final clubDoc in clubsSnapshot.docs) {
        final query = await clubDoc.reference
            .collection(_invitationsSubcollection)
            .where('token', isEqualTo: token)
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .get();

        for (final invDoc in query.docs) {
          final invitation = ClubInvitation.fromFirestore(invDoc, clubId: clubDoc.id);
          if (!invitation.isExpired) return invitation;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting invitation by token: $e');
      return null;
    }
  }

  /// Accept an invitation identified by its shareable token code
  static Future<void> acceptInvitationByToken(String token) async {
    final invitation = await getInvitationByToken(token);
    if (invitation == null) throw 'Invitation not found or expired';
    await acceptInvitation(clubId: invitation.clubId, invitationId: invitation.id);
  }

  /// Watch pending invitations for the current user
  static Stream<List<ClubInvitation>> watchPendingInvitations() async* {
    final email = AuthService.currentUser?.email?.toLowerCase().trim();
    if (email == null) {
      yield [];
      return;
    }

    // This is a simplified version - in production you'd want to use a more
    // efficient approach like Cloud Functions to aggregate invitations
    while (true) {
      yield await getPendingInvitations();
      await Future.delayed(const Duration(seconds: 30));
    }
  }
}
