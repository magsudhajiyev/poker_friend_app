import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/account_type.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cached account type
  static AccountType? _cachedAccountType;
  static String? _cachedAccountTypeUserId;  // Track which user the cache is for
  
  // Get current user
  static User? get currentUser => _auth.currentUser;
  
  // Check if user is signed in
  static bool get isSignedIn => currentUser != null;
  
  // Auth state stream
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Sign in with email and password
  static Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('User signed in: ${credential.user?.email}');

      // Ensure user document exists (backfill for users registered before this feature)
      if (credential.user != null) {
        print('Calling ensureUserDocument after sign in...');
        await ensureUserDocument();
        print('ensureUserDocument completed');
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      print('Sign in error: ${e.message}');
      throw _getAuthException(e);
    } catch (e) {
      print('Unexpected error during sign in: $e');
      throw 'An unexpected error occurred. Please try again.';
    }
  }
  
  // Register with email and password
  static Future<UserCredential?> registerWithEmail(String email, String password, String displayName) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await credential.user?.updateDisplayName(displayName);
      await credential.user?.reload();

      // Create user document in Firestore for searchability
      if (credential.user != null) {
        await _createUserDocument(credential.user!.uid, displayName, email);
        // Verify document was created (safety net)
        await ensureUserDocument();
      }

      print('User registered: ${credential.user?.email}');
      return credential;
    } on FirebaseAuthException catch (e) {
      print('Registration error: ${e.message}');
      throw _getAuthException(e);
    } catch (e) {
      print('Unexpected error during registration: $e');
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  // Create or update user document in Firestore
  static Future<void> _createUserDocument(String uid, String displayName, String email) async {
    print('Creating user document: uid=$uid, displayName=$displayName, email=$email');
    try {
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'displayName': displayName,
        'displayNameLower': displayName.toLowerCase(), // For case-insensitive search
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('User document created successfully for $uid');
    } catch (e) {
      print('Error creating user document: $e');
      // Don't throw - user registration should still succeed
    }
  }

  // Ensure current user has a document (for existing users who registered before this feature)
  static Future<void> ensureUserDocument() async {
    final user = currentUser;
    print('ensureUserDocument called, user=${user?.uid}, displayName=${user?.displayName}');
    if (user == null) {
      print('ensureUserDocument: No current user, returning');
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      print('ensureUserDocument: Document exists=${doc.exists}');
      if (!doc.exists) {
        await _createUserDocument(
          user.uid,
          user.displayName ?? user.email?.split('@').first ?? 'Player',
          user.email ?? '',
        );
      } else {
        print('ensureUserDocument: Document already exists, skipping creation');
      }
    } catch (e) {
      print('ensureUserDocument error: $e');
    }
  }

  // Search users by name (case-insensitive prefix search)
  static Future<List<Map<String, dynamic>>> searchUsersByName(String query) async {
    if (query.isEmpty) return [];

    final queryLower = query.toLowerCase();
    final queryEnd = queryLower.substring(0, queryLower.length - 1) +
        String.fromCharCode(queryLower.codeUnitAt(queryLower.length - 1) + 1);

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('displayNameLower', isGreaterThanOrEqualTo: queryLower)
          .where('displayNameLower', isLessThan: queryEnd)
          .limit(10)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return <String, dynamic>{
          'uid': data['uid'] ?? doc.id,
          'displayName': data['displayName'] ?? 'Unknown',
          'email': data['email'] ?? '',
        };
      }).toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }
  
  // Sign out
  static Future<void> signOut() async {
    try {
      clearAccountTypeCache();  // Clear cached account type
      await _auth.signOut();
      print('User signed out');
    } catch (e) {
      print('Sign out error: $e');
      throw 'Failed to sign out. Please try again.';
    }
  }
  
  // Send password reset email
  static Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      print('Password reset email sent to: $email');
    } on FirebaseAuthException catch (e) {
      print('Password reset error: ${e.message}');
      throw _getAuthException(e);
    } catch (e) {
      print('Unexpected error during password reset: $e');
      throw 'An unexpected error occurred. Please try again.';
    }
  }
  
  // Get user display name
  static String get userDisplayName {
    return currentUser?.displayName ?? currentUser?.email?.split('@').first ?? 'Player';
  }
  
  // Get user ID for database operations
  static String? get userId => currentUser?.uid;
  
  // Convert Firebase Auth exceptions to user-friendly messages
  static String _getAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'internal-error':
        if (e.message?.contains('CONFIGURATION_NOT_FOUND') == true) {
          return 'Firebase Authentication is not properly configured. Please enable Email/Password authentication in Firebase Console and ensure the SHA-1 fingerprint is added.';
        }
        return 'Internal authentication error. Please try again.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
  
  // Delete current user account
  static Future<void> deleteAccount() async {
    try {
      await currentUser?.delete();
      print('User account deleted');
    } on FirebaseAuthException catch (e) {
      print('Account deletion error: ${e.message}');
      throw _getAuthException(e);
    } catch (e) {
      print('Unexpected error during account deletion: $e');
      throw 'Failed to delete account. Please try again.';
    }
  }
  
  // Update user profile
  static Future<void> updateProfile({String? displayName, String? photoURL}) async {
    try {
      await currentUser?.updateDisplayName(displayName);
      await currentUser?.updatePhotoURL(photoURL);
      await currentUser?.reload();
      print('Profile updated successfully');
    } catch (e) {
      print('Profile update error: $e');
      throw 'Failed to update profile. Please try again.';
    }
  }
  
  // Check if email is verified
  static bool get isEmailVerified => currentUser?.emailVerified ?? false;

  // Send email verification
  static Future<void> sendEmailVerification() async {
    try {
      await currentUser?.sendEmailVerification();
      print('Email verification sent');
    } catch (e) {
      print('Email verification error: $e');
      throw 'Failed to send verification email. Please try again.';
    }
  }

  // ==================== Account Type Methods ====================

  /// Get the account type for the current user
  /// Returns AccountType.player by default
  static Future<AccountType> getAccountType() async {
    final uid = userId;
    if (uid == null) return AccountType.player;

    // Return cached value if it's for the same user
    if (_cachedAccountType != null && _cachedAccountTypeUserId == uid) {
      return _cachedAccountType!;
    }

    try {
      // Check the dealers collection for this user
      final doc = await _firestore.collection('dealers').doc(uid).get();

      if (doc.exists) {
        final data = doc.data();
        final typeString = data?['accountType'] as String?;
        _cachedAccountType = AccountTypeExtension.fromString(typeString);
      } else {
        _cachedAccountType = AccountType.player;
      }
      _cachedAccountTypeUserId = uid;
      return _cachedAccountType!;
    } catch (e) {
      print('Error getting account type: $e');
      return AccountType.player;
    }
  }

  /// Clear the cached account type (call on sign out)
  static void clearAccountTypeCache() {
    _cachedAccountType = null;
    _cachedAccountTypeUserId = null;
  }

  /// Check if current user is a dealer
  static Future<bool> get isDealer async {
    final accountType = await getAccountType();
    return accountType == AccountType.dealer || accountType == AccountType.admin;
  }

  /// Check if current user is an admin
  static Future<bool> get isAdmin async {
    final accountType = await getAccountType();
    return accountType == AccountType.admin;
  }

  /// Check if current user is a regular player
  static Future<bool> get isPlayer async {
    final accountType = await getAccountType();
    return accountType == AccountType.player;
  }

  /// Get the list of club IDs the dealer belongs to
  static Future<List<String>> getDealerClubIds() async {
    final uid = userId;
    if (uid == null) return [];

    try {
      final doc = await _firestore.collection('dealers').doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        final clubIds = data?['clubIds'] as List<dynamic>?;
        return clubIds?.cast<String>() ?? [];
      }
      return [];
    } catch (e) {
      print('Error getting dealer club IDs: $e');
      return [];
    }
  }
}