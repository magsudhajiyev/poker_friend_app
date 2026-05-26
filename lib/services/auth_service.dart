import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account_type.dart';
import 'app_data_cache.dart';
import 'fcm_service.dart';
import 'logger_service.dart';
import 'subscription_service.dart';
import 'username_service.dart';
import 'display_identity_service.dart';

/// Thrown when Google sign-in detects an existing email/password account.
/// The UI should catch this and show a password dialog to link accounts.
class GoogleSignInAccountLinkException implements Exception {
  final String email;
  final AuthCredential googleCredential;
  const GoogleSignInAccountLinkException({
    required this.email,
    required this.googleCredential,
  });
}

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '311745459306-povk09gd7ll56fgng8rsac54lrbgguq6.apps.googleusercontent.com',
  );

  // Cached account type
  static AccountType? _cachedAccountType;
  static String? _cachedAccountTypeUserId;  // Track which user the cache is for

  // Track if user explicitly logged out (vs unexpected session loss)
  static bool _isExplicitLogout = false;

  /// Check if user explicitly logged out
  static bool get isExplicitLogout => _isExplicitLogout;

  /// Clear the explicit logout flag (call when user successfully signs in)
  static void clearExplicitLogoutFlag() {
    _isExplicitLogout = false;
  }
  
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
      debugPrint('User signed in: ${credential.user?.email}');

      // Ensure user document exists (backfill for users registered before this feature)
      if (credential.user != null) {
        debugPrint('Calling ensureUserDocument after sign in...');
        await ensureUserDocument();
        debugPrint('ensureUserDocument completed');

        // Set user context for observability
        unawaited(LoggerService.setUserId(credential.user!.uid));
        unawaited(LoggerService.logEvent('login', parameters: {'method': 'email'}));

        // RevenueCat user association - don't block sign-in
        unawaited(SubscriptionService.loginUser(credential.user!.uid));

        // FCM setup runs in background - don't block sign-in
        unawaited(_setupFcmInBackground());
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      await LoggerService.error('Sign in error', e);

      // If sign-in fails, check if this email uses Google-only sign-in
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        try {
          final methods = await _auth.fetchSignInMethodsForEmail(email);
          if (methods.contains('google.com') && !methods.contains('password')) {
            throw 'This account uses Google Sign-In. Please sign in with Google, or use "Forgot Password" to set a password for email login.';
          }
        } catch (fetchError) {
          if (fetchError is String) rethrow;
          // If fetching methods fails, fall through to default error
        }
      }

      throw _getAuthException(e);
    } catch (e) {
      await LoggerService.error('Unexpected error during sign in', e, StackTrace.current);
      if (e is String) rethrow; // Re-throw our custom message
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

        // Set user context for observability
        unawaited(LoggerService.setUserId(credential.user!.uid));
        unawaited(LoggerService.logEvent('signup', parameters: {'method': 'email'}));

        // FCM setup runs in background - don't block registration
        unawaited(_setupFcmInBackground());
      }

      debugPrint('User registered: ${credential.user?.email}');
      return credential;
    } on FirebaseAuthException catch (e) {
      await LoggerService.error('Registration error', e);
      throw _getAuthException(e);
    } catch (e) {
      await LoggerService.error('Unexpected error during registration', e, StackTrace.current);
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  // Create or update user document in Firestore
  static Future<void> _createUserDocument(String uid, String displayName, String email) async {
    debugPrint('Creating user document: uid=$uid, displayName=$displayName, email=$email');
    try {
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'displayName': displayName,
        'displayNameLower': displayName.toLowerCase(), // For case-insensitive search
        'email': email,
        'hasSetUsername': false,
        'hasCompletedOnboarding': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('User document created successfully for $uid');
    } catch (e) {
      await LoggerService.error('Error creating user document', e, StackTrace.current);
      // Don't throw - user registration should still succeed
    }
  }

  // Ensure current user has a document (for existing users who registered before this feature)
  static Future<void> ensureUserDocument() async {
    final user = currentUser;
    debugPrint('ensureUserDocument called, user=${user?.uid}, displayName=${user?.displayName}');
    if (user == null) {
      debugPrint('ensureUserDocument: No current user, returning');
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      debugPrint('ensureUserDocument: Document exists=${doc.exists}');
      if (!doc.exists) {
        await _createUserDocument(
          user.uid,
          user.displayName ?? user.email?.split('@').first ?? 'Player',
          user.email ?? '',
        );
      } else {
        debugPrint('ensureUserDocument: Document already exists, skipping creation');
      }
    } catch (e) {
      await LoggerService.error('ensureUserDocument error', e, StackTrace.current);
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
      await LoggerService.error('Error searching users', e, StackTrace.current);
      return [];
    }
  }
  
  // Sign out
  static Future<void> signOut() async {
    try {
      debugPrint('📍 LOGOUT: signOut() called');
      debugPrint('📍 LOGOUT: Stack trace: ${StackTrace.current}');

      _isExplicitLogout = true;  // Mark as explicit logout

      // FCM cleanup runs in background - don't block sign-out
      unawaited(_cleanupFcmInBackground());

      // RevenueCat logout - don't block sign-out
      unawaited(SubscriptionService.logoutUser());

      clearAccountTypeCache();  // Clear cached account type
      UsernameService.clearCache();
      DisplayIdentityService.clearCache();
      AppDataCache.clearAll();  // Clear all in-memory cached data

      // Clear user-data SharedPreferences keys that aren't user-scoped
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('bankroll_goal');
        await prefs.remove('current_bankroll');
        await prefs.remove('bankroll_synced_from_firestore');
        await prefs.remove('bankroll_hidden');
        await prefs.remove('beta_ai_analysis_count');
      } catch (_) {}

      unawaited(LoggerService.logEvent('logout'));

      await _auth.signOut();
      // Sign out of Google so account picker appears next time
      try { await _googleSignIn.signOut(); } catch (_) {}
      debugPrint('User signed out');
    } catch (e) {
      _isExplicitLogout = false;  // Reset on error
      await LoggerService.error('Sign out error', e, StackTrace.current);
      throw 'Failed to sign out. Please try again.';
    }
  }

  // ==================== Google Sign-In ====================

  /// Sign in (or register) with Google.
  /// Returns null if user cancels the Google dialog.
  /// Throws [GoogleSignInAccountLinkException] if the email is already
  /// registered with email/password — the UI should catch this and show
  /// a password dialog to link accounts.
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential;

      try {
        userCredential = await _auth.signInWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'account-exists-with-different-credential') {
          // Email already registered with email/password — let UI handle linking
          final email = e.email ?? googleUser.email;
          throw GoogleSignInAccountLinkException(
            email: email,
            googleCredential: credential,
          );
        }
        rethrow;
      }

      if (userCredential.user != null) {
        await _syncGoogleProfileData(userCredential.user!, googleUser);
        await ensureUserDocument();
        clearExplicitLogoutFlag();
        unawaited(LoggerService.setUserId(userCredential.user!.uid));
        unawaited(LoggerService.logEvent('login', parameters: {'method': 'google'}));
        unawaited(SubscriptionService.loginUser(userCredential.user!.uid));
        unawaited(_setupFcmInBackground());
      }

      return userCredential;
    } on GoogleSignInAccountLinkException {
      rethrow; // Let UI handle this
    } on FirebaseAuthException catch (e) {
      throw _getAuthException(e);
    } catch (e) {
      if (e.toString().contains('sign_in_canceled')) {
        return null;
      }
      if (e.toString().contains('network_error') ||
          e.toString().contains('NetworkError') ||
          e.toString().contains('unable to resolve host') ||
          e.toString().contains('No address associated')) {
        throw 'No internet connection. Please check your network and try again.';
      }
      throw 'Google sign-in failed. Please try again.';
    }
  }

  /// Link a Google credential to an existing email/password account.
  /// Called from the UI after the user enters their password.
  static Future<UserCredential> linkGoogleToExistingAccount({
    required String email,
    required String password,
    required AuthCredential googleCredential,
  }) async {
    try {
      // Sign in with existing email/password
      final emailCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Link the Google credential to this account
      final linked = await emailCredential.user!
          .linkWithCredential(googleCredential);

      // Sync Google photo
      final googleAccount = await _googleSignIn.signInSilently();
      if (googleAccount != null && linked.user != null) {
        await _syncGoogleProfileData(linked.user!, googleAccount);
      }

      await ensureUserDocument();
      clearExplicitLogoutFlag();
      unawaited(LoggerService.setUserId(linked.user!.uid));
      unawaited(LoggerService.logEvent('login', parameters: {'method': 'google_link'}));
      unawaited(SubscriptionService.loginUser(linked.user!.uid));
      unawaited(_setupFcmInBackground());

      return linked;
    } on FirebaseAuthException catch (e) {
      throw _getAuthException(e);
    }
  }

  /// Sync Google profile photo to Firebase Auth and Firestore.
  static Future<void> _syncGoogleProfileData(
    User firebaseUser,
    GoogleSignInAccount googleAccount,
  ) async {
    final photoUrl = googleAccount.photoUrl;
    if (photoUrl == null) return;

    try {
      await firebaseUser.updatePhotoURL(photoUrl);
      await firebaseUser.reload();

      await _firestore.collection('users').doc(firebaseUser.uid).set({
        'photoURL': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Non-fatal: photo sync failure should not block sign-in
    }
  }

  /// Setup FCM in background (fire-and-forget)
  static Future<void> _setupFcmInBackground() async {
    try {
      final token = await FCMService.getToken();
      if (token != null) {
        await FCMService.storeToken(token);
      }
      await FCMService.subscribeToUserClubs();
    } catch (e) {
      debugPrint('FCM setup failed (background): $e');
    }
  }

  /// Cleanup FCM in background (fire-and-forget)
  static Future<void> _cleanupFcmInBackground() async {
    try {
      await FCMService.unsubscribeFromAllClubs();
      await FCMService.removeToken();
    } catch (e) {
      debugPrint('FCM cleanup failed (background): $e');
    }
  }
  
  // Send password reset email
  static Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      debugPrint('Password reset email sent to: $email');
    } on FirebaseAuthException catch (e) {
      await LoggerService.error('Password reset error', e);
      throw _getAuthException(e);
    } catch (e) {
      await LoggerService.error('Unexpected error during password reset', e, StackTrace.current);
      throw 'An unexpected error occurred. Please try again.';
    }
  }
  
  // Get user display name
  static String get userDisplayName {
    return currentUser?.displayName ?? currentUser?.email?.split('@').first ?? 'Player';
  }

  // Get user photo URL (from Google profile or manually set)
  static String? get userPhotoURL => currentUser?.photoURL;
  
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
      case 'account-exists-with-different-credential':
        return 'This email is already registered. Please sign in with your password.';
      case 'credential-already-in-use':
        return 'This Google account is already linked to another account.';
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
      // Clear all caches before deleting
      clearAccountTypeCache();
      UsernameService.clearCache();
      DisplayIdentityService.clearCache();
      AppDataCache.clearAll();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('bankroll_goal');
        await prefs.remove('current_bankroll');
        await prefs.remove('bankroll_synced_from_firestore');
        await prefs.remove('bankroll_hidden');
        await prefs.remove('beta_ai_analysis_count');
      } catch (_) {}

      await currentUser?.delete();
      debugPrint('User account deleted');
    } on FirebaseAuthException catch (e) {
      await LoggerService.error('Account deletion error', e);
      throw _getAuthException(e);
    } catch (e) {
      await LoggerService.error('Unexpected error during account deletion', e, StackTrace.current);
      throw 'Failed to delete account. Please try again.';
    }
  }
  
  // Update user profile
  static Future<void> updateProfile({String? displayName, String? photoURL}) async {
    try {
      await currentUser?.updateDisplayName(displayName);
      await currentUser?.updatePhotoURL(photoURL);
      await currentUser?.reload();
      debugPrint('Profile updated successfully');
    } catch (e) {
      await LoggerService.error('Profile update error', e, StackTrace.current);
      throw 'Failed to update profile. Please try again.';
    }
  }
  
  // Check if email is verified
  static bool get isEmailVerified => currentUser?.emailVerified ?? false;

  // Send email verification
  static Future<void> sendEmailVerification() async {
    try {
      await currentUser?.sendEmailVerification();
      debugPrint('Email verification sent');
    } catch (e) {
      await LoggerService.error('Email verification error', e, StackTrace.current);
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
      await LoggerService.error('Error getting account type', e, StackTrace.current);
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
      await LoggerService.error('Error getting dealer club IDs', e, StackTrace.current);
      return [];
    }
  }
}