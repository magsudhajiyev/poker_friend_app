import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'display_identity_service.dart';

class UsernameService {
  static final _firestore = FirebaseFirestore.instance;

  // Cache to avoid repeated Firestore reads
  static bool? _cachedHasSetUsername;
  static String? _cachedForUserId;

  /// Validate username format (client-side, pure function).
  /// Accepts mixed case input; validation checks lowercase form.
  /// Returns null if valid, error message if invalid.
  static String? validateUsername(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Username is required';
    if (trimmed.length < 3) return 'Must be at least 3 characters';
    if (trimmed.length > 20) return 'Must be 20 characters or less';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmed)) {
      return 'Only letters, numbers, and underscores';
    }
    if (trimmed.startsWith('_') || trimmed.endsWith('_')) {
      return 'Cannot start or end with underscore';
    }
    return null;
  }

  /// Check if a username is available.
  /// Checks both `usernames` collection (live users) AND
  /// `nickname_claims` collection (web reservations).
  /// Claims belonging to [currentUserEmail] are ignored (user's own reservation).
  static Future<bool> isUsernameAvailable(String username, {String? currentUserEmail}) async {
    final normalized = username.toLowerCase().trim();

    // Check live usernames
    final doc = await _firestore.collection('usernames').doc(normalized).get();
    if (doc.exists) return false;

    // Check web reservations
    final claims = await _firestore
        .collection('nickname_claims')
        .where('nickname', isEqualTo: normalized)
        .where('status', isEqualTo: 'pending')
        .limit(5)
        .get();

    if (claims.docs.isEmpty) return true;

    // If all matching claims belong to the current user's email, it's available
    if (currentUserEmail != null) {
      final normalizedEmail = currentUserEmail.toLowerCase().trim();
      final otherClaims = claims.docs.where(
        (d) => (d.data()['email'] as String?)?.toLowerCase().trim() != normalizedEmail,
      );
      return otherClaims.isEmpty;
    }

    return false;
  }

  /// Claim a username atomically using a Firestore transaction.
  /// Stores the original casing for display; uses lowercase for uniqueness index.
  /// Returns true on success, false if taken.
  static Future<bool> claimUsername(String username) async {
    final displayName = username.trim();
    final normalized = displayName.toLowerCase();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return false;

    try {
      final success = await _firestore.runTransaction<bool>((transaction) async {
        final usernameRef = _firestore.collection('usernames').doc(normalized);
        final snapshot = await transaction.get(usernameRef);

        if (snapshot.exists) return false;

        // Write to usernames index (lowercase key)
        transaction.set(usernameRef, {
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Update user document — store original casing for display
        transaction.update(_firestore.collection('users').doc(userId), {
          'username': displayName,
          'usernameLower': normalized,
          'hasSetUsername': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });

      // Update cache and mark any matching web claim as claimed
      if (success) {
        _cachedHasSetUsername = true;
        _cachedForUserId = userId;
        markClaimAsClaimed(normalized);

        // If the account has no usable display name — typical for Apple
        // sign-in, where the name is only delivered on the very first
        // authorization and the private-relay email offers no fallback —
        // adopt the chosen username as the display name.
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null &&
              AuthService.isPlaceholderNameFor(user.displayName, user.email)) {
            await user.updateDisplayName(displayName);
            await user.reload();
            await _firestore.collection('users').doc(userId).update({
              'displayName': displayName,
              'displayNameLower': normalized,
            });
            DisplayIdentityService.clearCache();
          }
        } catch (_) {
          // Non-fatal: username claim already succeeded.
        }
      }
      return success;
    } catch (e) {
      debugPrint('Error claiming username: $e');
      return false;
    }
  }

  /// Release old username and claim a new one atomically.
  /// Returns true on success, false if new name is taken.
  static Future<bool> releaseAndClaimNew(
      String oldUsername, String newUsername) async {
    final oldNormalized = oldUsername.toLowerCase().trim();
    final newDisplayName = newUsername.trim();
    final newNormalized = newDisplayName.toLowerCase();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return false;

    try {
      return await _firestore.runTransaction<bool>((transaction) async {
        final newRef = _firestore.collection('usernames').doc(newNormalized);
        final newSnapshot = await transaction.get(newRef);

        if (newSnapshot.exists) return false;

        // Delete old username doc
        final oldRef = _firestore.collection('usernames').doc(oldNormalized);
        transaction.delete(oldRef);

        // Create new username doc
        transaction.set(newRef, {
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Update user document — store original casing for display
        transaction.update(_firestore.collection('users').doc(userId), {
          'username': newDisplayName,
          'usernameLower': newNormalized,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      debugPrint('Error changing username: $e');
      return false;
    }
  }

  /// Mark username setup as skipped (user chose not to set one now).
  static Future<void> skipUsername() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'hasSetUsername': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _cachedHasSetUsername = true;
      _cachedForUserId = userId;
    } catch (e) {
      debugPrint('Error skipping username: $e');
    }
  }

  /// Check if user has been through username setup (set or skipped).
  /// Returns true for existing users who don't have the field (grandfathered).
  static Future<bool> hasCompletedUsernameSetup() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return true;

    // Use cache if available for same user
    if (_cachedForUserId == userId && _cachedHasSetUsername != null) {
      return _cachedHasSetUsername!;
    }

    try {
      // Reuse prefetched doc from SplashScreen to avoid a separate read.
      final prefetched = AuthService.consumePrefetchedUserDoc();
      final data = prefetched ?? (await _firestore.collection('users').doc(userId).get()).data();
      // No user doc yet (brand-new sign-up) → setup is NOT done. We must ask
      // for a username during onboarding; a null doc used to short-circuit to
      // "done", which silently skipped the username step for new users.
      if (data == null) return false;

      // Ground truth: an actual username already set means done (covers both
      // users who set one and legacy/grandfathered accounts that predate the
      // `hasSetUsername` flag but already have a username).
      final username = (data['username'] as String?)?.trim() ?? '';
      if (username.isNotEmpty) {
        _cachedHasSetUsername = true;
        _cachedForUserId = userId;
        return true;
      }

      // No username value. Only treat as done if explicitly marked
      // (hasSetUsername == true — e.g. the user deliberately skipped). A
      // missing flag on a doc WITHOUT a username is a new user who must be
      // asked — NOT grandfathered (a real legacy user would have a username).
      final flag = data['hasSetUsername'] == true;
      _cachedHasSetUsername = flag;
      _cachedForUserId = userId;
      return flag;
    } catch (e) {
      debugPrint('Error checking username setup: $e');
      // On a transient read error we can't tell a new user from a returning
      // one; stay lenient (don't block an established user on flaky network).
      // The genuine "new user skipped" bug is fixed above on the SUCCESSFUL
      // read path (null doc / missing-flag-without-username → ask).
      return true;
    }
  }

  /// Look up a pending nickname claim by email (from web reservation).
  /// Returns the reserved nickname or null if none found.
  static Future<String?> getPendingClaimForEmail(String email) async {
    final normalizedEmail = email.toLowerCase().trim();
    try {
      // Query by email only (no composite index needed), filter status client-side
      final claims = await _firestore
          .collection('nickname_claims')
          .where('email', isEqualTo: normalizedEmail)
          .get();
      if (claims.docs.isEmpty) {
        debugPrint('📍 USERNAME: No nickname claims found for email: $normalizedEmail');
        return null;
      }
      // Find the first pending claim
      for (final doc in claims.docs) {
        final data = doc.data();
        if (data['status'] == 'pending') {
          final nickname = data['nickname'] as String?;
          debugPrint('📍 USERNAME: Found pending claim "$nickname" for $normalizedEmail');
          return nickname;
        }
      }
      debugPrint('📍 USERNAME: Claims found but none pending for $normalizedEmail');
      return null;
    } catch (e) {
      debugPrint('❌ USERNAME: Error looking up nickname claim: $e');
      return null;
    }
  }

  /// Mark a web nickname claim as claimed (after user claims it in-app).
  static Future<void> markClaimAsClaimed(String nickname) async {
    try {
      final normalized = nickname.toLowerCase().trim();
      final claims = await _firestore
          .collection('nickname_claims')
          .where('nickname', isEqualTo: normalized)
          .where('status', isEqualTo: 'pending')
          .get();
      for (final doc in claims.docs) {
        await doc.reference.update({'status': 'claimed'});
      }
    } catch (e) {
      debugPrint('Error marking claim as claimed: $e');
    }
  }

  /// Get current user's username from Firestore.
  static Future<String?> getUsername() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['username'] as String?;
    } catch (e) {
      debugPrint('Error getting username: $e');
      return null;
    }
  }

  /// Get user's preference for using nickname in game.
  static Future<bool> getUseNicknameInGame() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return false;

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['useNicknameInGame'] as bool? ?? false;
    } catch (e) {
      debugPrint('Error getting useNicknameInGame: $e');
      return false;
    }
  }

  /// Toggle the useNicknameInGame preference.
  static Future<void> setUseNicknameInGame(bool value) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'useNicknameInGame': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error setting useNicknameInGame: $e');
    }
  }

  /// Clear cached state (call on sign out).
  static void clearCache() {
    _cachedHasSetUsername = null;
    _cachedForUserId = null;
  }
}
