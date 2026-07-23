import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account_type.dart';
import 'app_data_cache.dart';
import 'currency_service.dart';
import 'fcm_service.dart';
import 'logger_service.dart';
import 'partner_grant_service.dart';
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

/// Thrown when Apple sign-in detects an existing email/password account.
/// The UI should catch this and show a password dialog to link accounts.
class AppleSignInAccountLinkException implements Exception {
  final String email;
  final AuthCredential appleCredential;
  const AppleSignInAccountLinkException({
    required this.email,
    required this.appleCredential,
  });
}

/// Thrown when linking a guest (anonymous) account to a credential that
/// already belongs to an existing account. The UI should warn the user that
/// guest data won't be transferred and offer to sign in to the existing
/// account instead.
class AnonymousLinkConflictException implements Exception {
  const AnonymousLinkConflictException();
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

  // ── Pre-fetched user document ──────────────────────────────────────
  // Avoids 3-4 sequential reads of the same doc during startup.
  static Map<String, dynamic>? _prefetchedUserDoc;
  static String? _prefetchedUserId;

  /// Pre-fetch the user document so AuthWrapper and HomeScreen can read
  /// cached data instead of hitting Firestore sequentially. Call this from
  /// SplashScreen while the logo loop is playing.
  static Future<void> prefetchUserDocument() async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    // Invalidate any previous snapshot SYNCHRONOUSLY, before the network
    // read. The static survives '/' resets (splash → gate), so a consumer
    // racing this fetch must fall back to a fresh Firestore read rather
    // than see data captured before the latest flag writes — a stale
    // hasCompletedOnboarding:false here made onboarding repeat.
    clearPrefetchedUserDoc();
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _prefetchedUserDoc = doc.data();
        _prefetchedUserId = uid;
      }
    } catch (e) {
      unawaited(LoggerService.error('prefetchUserDocument error', e));
    }
  }

  /// Consume the prefetched user document (returns it once, then clears).
  /// Returns null if no prefetch is available or the uid doesn't match.
  static Map<String, dynamic>? consumePrefetchedUserDoc() {
    final uid = currentUser?.uid;
    if (uid == null || uid != _prefetchedUserId) return null;
    final doc = _prefetchedUserDoc;
    // Keep it available — multiple consumers read it during the same startup.
    return doc;
  }

  /// Clear the prefetch cache (call after startup is done).
  static void clearPrefetchedUserDoc() {
    _prefetchedUserDoc = null;
    _prefetchedUserId = null;
  }

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

  /// True for guest (anonymous) accounts — no email/Google/Apple linked yet.
  static bool get isAnonymous => currentUser?.isAnonymous ?? false;

  // Auth state stream
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ==================== Anonymous (guest) auth ====================

  /// Start using the app as a guest — no account required. All data is
  /// keyed by the anonymous uid, and linking a real credential later keeps
  /// the same uid, so nothing needs migrating.
  static Future<UserCredential?> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();

      if (credential.user != null) {
        await ensureUserDocument();
        clearExplicitLogoutFlag();
        unawaited(LoggerService.setUserId(credential.user!.uid));
        unawaited(LoggerService.logEvent('signup', parameters: {'method': 'anonymous'}));
        unawaited(SubscriptionService.loginUser(credential.user!.uid));
        unawaited(_setupFcmInBackground());
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      await LoggerService.error('Anonymous sign in error', e);
      // Firebase returns admin-restricted-operation when the Anonymous
      // provider is disabled in the console, operation-not-allowed on some
      // SDK versions — both mean guest access is unavailable.
      if (e.code == 'operation-not-allowed' ||
          e.code == 'admin-restricted-operation') {
        throw 'Guest access is not available right now. Please create an account.';
      }
      throw _getAuthException(e);
    } catch (e) {
      await LoggerService.error('Unexpected error during anonymous sign in', e, StackTrace.current);
      throw 'Could not start a guest session. Please check your connection and try again.';
    }
  }

  /// Common post-linking bookkeeping: merge the real identity into the user
  /// doc (created with an empty email for guests) and refresh services.
  static Future<void> _finalizeAnonymousLink(User user, String method) async {
    try {
      final displayName = user.displayName?.trim() ?? '';
      await _firestore.collection('users').doc(user.uid).set({
        'email': user.email ?? '',
        if (displayName.isNotEmpty) 'displayName': displayName,
        if (displayName.isNotEmpty) 'displayNameLower': displayName.toLowerCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    DisplayIdentityService.clearCache();
    unawaited(LoggerService.logEvent('account_linked', parameters: {'method': method}));
    unawaited(SubscriptionService.loginUser(user.uid));
    unawaited(_setupFcmInBackground());
  }

  static bool _isLinkConflict(FirebaseAuthException e) =>
      e.code == 'credential-already-in-use' ||
      e.code == 'email-already-in-use' ||
      e.code == 'account-exists-with-different-credential' ||
      e.code == 'provider-already-linked';

  /// Link the guest account to an email/password credential.
  /// Throws [AnonymousLinkConflictException] when the email already belongs
  /// to another account.
  static Future<UserCredential> linkAnonymousWithEmail(
      String email, String password, String displayName) async {
    final user = currentUser;
    if (user == null || !user.isAnonymous) {
      throw 'No guest session to upgrade. Please sign in normally.';
    }
    try {
      final linked = await user.linkWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      await linked.user?.updateDisplayName(displayName);
      await linked.user?.reload();
      await _finalizeAnonymousLink(currentUser!, 'email');
      return linked;
    } on FirebaseAuthException catch (e) {
      if (_isLinkConflict(e)) throw const AnonymousLinkConflictException();
      throw _getAuthException(e);
    }
  }

  /// Link the guest account to a Google credential.
  /// Returns null if the user cancels the Google dialog.
  /// Throws [AnonymousLinkConflictException] when the Google account already
  /// belongs to another account.
  static Future<UserCredential?> linkAnonymousWithGoogle() async {
    final user = currentUser;
    if (user == null || !user.isAnonymous) {
      throw 'No guest session to upgrade. Please sign in normally.';
    }
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final linked = await user.linkWithCredential(credential);
      if (linked.user != null) {
        await _syncGoogleProfileData(linked.user!, googleUser);
        // Adopt Google's name when the guest has none
        final googleName = googleUser.displayName?.trim() ?? '';
        if (googleName.isNotEmpty &&
            (linked.user!.displayName == null ||
                linked.user!.displayName!.trim().isEmpty)) {
          await linked.user!.updateDisplayName(googleName);
          await linked.user!.reload();
        }
        await _finalizeAnonymousLink(currentUser!, 'google');
      }
      return linked;
    } on FirebaseAuthException catch (e) {
      if (_isLinkConflict(e)) throw const AnonymousLinkConflictException();
      throw _getAuthException(e);
    } catch (e) {
      if (e is AnonymousLinkConflictException) rethrow;
      if (e.toString().contains('sign_in_canceled')) return null;
      throw 'Google sign-in failed. Please try again.';
    }
  }

  /// Link the guest account to an Apple credential.
  /// Returns null if the user cancels the Apple dialog.
  /// Throws [AnonymousLinkConflictException] when the Apple ID already
  /// belongs to another account.
  static Future<UserCredential?> linkAnonymousWithApple() async {
    final user = currentUser;
    if (user == null || !user.isAnonymous) {
      throw 'No guest session to upgrade. Please sign in normally.';
    }
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final linked = await user.linkWithCredential(oauthCredential);
      if (linked.user != null) {
        await _syncAppleProfileData(linked.user!, appleCredential);
        await _repairAppleDisplayName(linked.user!);
        await _finalizeAnonymousLink(currentUser!, 'apple');
      }
      return linked;
    } on FirebaseAuthException catch (e) {
      if (_isLinkConflict(e)) throw const AnonymousLinkConflictException();
      throw _getAuthException(e);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      throw 'Apple sign-in failed. Please try again.';
    } catch (e) {
      if (e is AnonymousLinkConflictException) rethrow;
      if (e.toString().contains('AuthorizationErrorCode.canceled')) return null;
      throw 'Apple sign-in failed. Please try again.';
    }
  }
  
  // Sign in with email and password
  static Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      unawaited(LoggerService.debug('User signed in: ${credential.user?.email}'));

      // Ensure user document exists (backfill for users registered before this feature)
      if (credential.user != null) {
        unawaited(LoggerService.debug('Calling ensureUserDocument after sign in...'));
        await ensureUserDocument();
        unawaited(LoggerService.debug('ensureUserDocument completed'));

        // Set user context for observability
        unawaited(LoggerService.setUserId(credential.user!.uid));
        unawaited(LoggerService.logEvent('login', parameters: {'method': 'email'}));

        // RevenueCat user association - don't block sign-in
        unawaited(SubscriptionService.loginUser(credential.user!.uid));
        await PartnerGrantService.init(credential.user!.uid);

        // FCM setup runs in background - don't block sign-in
        unawaited(_setupFcmInBackground());
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      await LoggerService.error('Sign in error', e);

      // If sign-in fails, check if this email uses Google-only or Apple-only sign-in
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        try {
          final methods = await _auth.fetchSignInMethodsForEmail(email);
          if (methods.contains('google.com') && !methods.contains('password')) {
            throw 'This account uses Google Sign-In. Please sign in with Google, or use "Forgot Password" to set a password for email login.';
          }
          if (methods.contains('apple.com') && !methods.contains('password')) {
            throw 'This account uses Apple Sign-In. Please sign in with Apple, or use "Forgot Password" to set a password for email login.';
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

      unawaited(LoggerService.debug('User registered: ${credential.user?.email}'));
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
    unawaited(LoggerService.debug('Creating user document: uid=$uid, displayName=$displayName, email=$email'));
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
      unawaited(LoggerService.debug('User document created successfully for $uid'));
    } catch (e) {
      await LoggerService.error('Error creating user document', e, StackTrace.current);
      // Don't throw - user registration should still succeed
    }
  }

  // Ensure current user has a document (for existing users who registered before this feature)
  static Future<void> ensureUserDocument() async {
    final user = currentUser;
    unawaited(LoggerService.debug('ensureUserDocument called, user=${user?.uid}, displayName=${user?.displayName}'));
    if (user == null) {
      unawaited(LoggerService.debug('ensureUserDocument: No current user, returning'));
      return;
    }

    try {
      // Reuse prefetched doc if available (avoids a redundant Firestore read
      // during startup — the same doc was already fetched in SplashScreen).
      final prefetched = consumePrefetchedUserDoc();
      if (prefetched != null) {
        unawaited(LoggerService.debug('ensureUserDocument: Using prefetched doc, skipping read'));
        return; // Doc exists (prefetch only stores non-null data)
      }

      final doc = await _firestore.collection('users').doc(user.uid).get();
      unawaited(LoggerService.debug('ensureUserDocument: Document exists=${doc.exists}'));
      if (!doc.exists) {
        await _createUserDocument(
          user.uid,
          fallbackDisplayNameFor(user.displayName, user.email),
          user.email ?? '',
        );
      } else {
        unawaited(LoggerService.debug('ensureUserDocument: Document already exists, skipping creation'));
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
      unawaited(LoggerService.debug('📍 LOGOUT: signOut() called'));
      unawaited(LoggerService.debug('📍 LOGOUT: Stack trace: ${StackTrace.current}'));

      _isExplicitLogout = true;  // Mark as explicit logout

      // FCM cleanup runs in background - don't block sign-out
      unawaited(_cleanupFcmInBackground());

      // RevenueCat logout - don't block sign-out
      unawaited(SubscriptionService.logoutUser());
      PartnerGrantService.reset();

      clearAccountTypeCache();  // Clear cached account type
      UsernameService.clearCache();
      DisplayIdentityService.clearCache();
      AppDataCache.clearAll();  // Clear all in-memory cached data
      // Audit M3: the splash-era user-doc snapshot must not survive into a
      // same-session re-login — a stale hasSetUsername:false replays
      // onboarding for the re-logged-in user.
      clearPrefetchedUserDoc();

      // Clear user-data SharedPreferences keys that aren't user-scoped
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('bankroll_goal');
        await prefs.remove('current_bankroll');
        await prefs.remove('bankroll_synced_from_firestore');
        await prefs.remove('bankroll_hidden');
        await prefs.remove('beta_ai_analysis_count');
      } catch (_) {}

      // Reset currency to default so the next user doesn't inherit it
      try {
        await CurrencyService.reset();
      } catch (_) {}

      unawaited(LoggerService.logEvent('logout'));

      await _auth.signOut();
      // Sign out of Google so account picker appears next time
      try { await _googleSignIn.signOut(); } catch (_) {}
      unawaited(LoggerService.debug('User signed out'));
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
        await PartnerGrantService.init(userCredential.user!.uid);
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
      await PartnerGrantService.init(linked.user!.uid);
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

  // ==================== Apple Sign-In ====================

  /// Generate a cryptographically secure random nonce for Apple Sign-In.
  static String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// SHA-256 hash of input string, returned as hex.
  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Sign in (or register) with Apple.
  /// Returns null if user cancels the Apple dialog.
  /// Throws [AppleSignInAccountLinkException] if the email is already
  /// registered with email/password — the UI should catch this and show
  /// a password dialog to link accounts.
  static Future<UserCredential?> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      UserCredential userCredential;

      try {
        userCredential = await _auth.signInWithCredential(oauthCredential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'account-exists-with-different-credential') {
          final email = e.email ?? appleCredential.email ?? '';
          throw AppleSignInAccountLinkException(
            email: email,
            appleCredential: oauthCredential,
          );
        }
        rethrow;
      }

      if (userCredential.user != null) {
        await _syncAppleProfileData(userCredential.user!, appleCredential);
        await ensureUserDocument();
        await _repairAppleDisplayName(userCredential.user!);
        clearExplicitLogoutFlag();
        unawaited(LoggerService.setUserId(userCredential.user!.uid));
        unawaited(LoggerService.logEvent('login', parameters: {'method': 'apple'}));
        unawaited(SubscriptionService.loginUser(userCredential.user!.uid));
        await PartnerGrantService.init(userCredential.user!.uid);
        unawaited(_setupFcmInBackground());
      }

      return userCredential;
    } on AppleSignInAccountLinkException {
      rethrow; // Let UI handle this
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return null; // User cancelled
      }
      throw 'Apple sign-in failed. Please try again.';
    } on FirebaseAuthException catch (e) {
      throw _getAuthException(e);
    } catch (e) {
      if (e.toString().contains('AuthorizationErrorCode.canceled')) {
        return null;
      }
      throw 'Apple sign-in failed. Please try again.';
    }
  }

  /// Sync Apple profile data to Firebase Auth and Firestore.
  /// CRITICAL: Apple only returns the user's name on the FIRST sign-in.
  /// On subsequent sign-ins, givenName/familyName will be null.
  static Future<void> _syncAppleProfileData(
    User firebaseUser,
    AuthorizationCredentialAppleID appleCredential,
  ) async {
    try {
      final givenName = appleCredential.givenName;
      final familyName = appleCredential.familyName;

      // Only update name if Apple provided it (first sign-in only)
      if (givenName != null || familyName != null) {
        final displayName = [givenName, familyName]
            .where((n) => n != null && n.isNotEmpty)
            .join(' ');

        if (displayName.isNotEmpty) {
          await firebaseUser.updateDisplayName(displayName);
          await firebaseUser.reload();

          await _firestore.collection('users').doc(firebaseUser.uid).set({
            'displayName': displayName,
            'displayNameLower': displayName.toLowerCase(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      // Store Apple's relay email if provided
      final email = appleCredential.email;
      if (email != null && email.isNotEmpty) {
        await _firestore.collection('users').doc(firebaseUser.uid).set({
          'email': email,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      // Non-fatal: profile sync failure should not block sign-in
    }
  }

  /// Apple only delivers the user's name on the FIRST authorization ever.
  /// On later sign-ins (reinstall, account re-creation) the name is null and
  /// old fallbacks stored the private-relay token as the display name.
  /// If the account's name is missing or such a placeholder, recover it from
  /// the user document: chosen username first, then a previously stored real
  /// display name.
  static Future<void> _repairAppleDisplayName(User user) async {
    try {
      if (!isPlaceholderNameFor(user.displayName, user.email)) return;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data == null) return;

      final username = (data['username'] as String?)?.trim() ?? '';
      final storedName = (data['displayName'] as String?)?.trim() ?? '';

      String? candidate;
      if (username.isNotEmpty) {
        candidate = username;
      } else if (!isPlaceholderNameFor(storedName, user.email)) {
        candidate = storedName;
      }
      if (candidate == null) return;

      await user.updateDisplayName(candidate);
      await user.reload();
      await _firestore.collection('users').doc(user.uid).set({
        'displayName': candidate,
        'displayNameLower': candidate.toLowerCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      DisplayIdentityService.clearCache();
    } catch (e) {
      // Non-fatal: a cosmetic repair must never block sign-in.
      unawaited(LoggerService.warning('Apple display-name repair skipped: $e'));
    }
  }

  /// Link an Apple credential to an existing email/password account.
  /// Called from the UI after the user enters their password.
  static Future<UserCredential> linkAppleToExistingAccount({
    required String email,
    required String password,
    required AuthCredential appleCredential,
  }) async {
    try {
      // Sign in with existing email/password
      final emailCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Link the Apple credential to this account
      final linked = await emailCredential.user!
          .linkWithCredential(appleCredential);

      await ensureUserDocument();
      clearExplicitLogoutFlag();
      unawaited(LoggerService.setUserId(linked.user!.uid));
      unawaited(LoggerService.logEvent('login', parameters: {'method': 'apple_link'}));
      unawaited(SubscriptionService.loginUser(linked.user!.uid));
      await PartnerGrantService.init(linked.user!.uid);
      unawaited(_setupFcmInBackground());

      return linked;
    } on FirebaseAuthException catch (e) {
      throw _getAuthException(e);
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
      unawaited(LoggerService.warning('FCM setup failed (background): $e'));
    }
  }

  /// Cleanup FCM in background (fire-and-forget)
  static Future<void> _cleanupFcmInBackground() async {
    try {
      await FCMService.unsubscribeFromAllClubs();
      await FCMService.removeToken();
    } catch (e) {
      unawaited(LoggerService.warning('FCM cleanup failed (background): $e'));
    }
  }
  
  // Send password reset email
  static Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      unawaited(LoggerService.debug('Password reset email sent to: $email'));
    } on FirebaseAuthException catch (e) {
      await LoggerService.error('Password reset error', e);
      throw _getAuthException(e);
    } catch (e) {
      await LoggerService.error('Unexpected error during password reset', e, StackTrace.current);
      throw 'An unexpected error occurred. Please try again.';
    }
  }
  
  /// True when [email] is an Apple private-relay address. Its local part is
  /// a random token (e.g. `x7kq2mfd9a@privaterelay.appleid.com`) and must
  /// never be shown as a name.
  static bool isPrivateRelayEmail(String? email) =>
      email != null &&
      email.toLowerCase().endsWith('@privaterelay.appleid.com');

  /// Pure check: is [name] unusable as a display name for an account with
  /// [email]? Unusable = empty, or equal to the random local part of a
  /// private-relay email (how the "weird id" usernames were born).
  static bool isPlaceholderNameFor(String? name, String? email) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return true;
    if (isPrivateRelayEmail(email)) {
      final localPart = email!.split('@').first.toLowerCase();
      if (trimmed.toLowerCase() == localPart) return true;
    }
    return false;
  }

  /// Convenience: placeholder check against the signed-in user's email.
  static bool isPlaceholderDisplayName(String? name) =>
      isPlaceholderNameFor(name, currentUser?.email);

  /// Display-name fallback that never leaks a private-relay token:
  /// real display name → email local part (non-relay only) → 'Player'.
  static String fallbackDisplayNameFor(String? name, String? email) {
    final trimmed = name?.trim() ?? '';
    if (!isPlaceholderNameFor(trimmed, email)) return trimmed;
    if (email != null && email.isNotEmpty && !isPrivateRelayEmail(email)) {
      return email.split('@').first;
    }
    return 'Player';
  }

  // Get user display name
  static String get userDisplayName =>
      fallbackDisplayNameFor(currentUser?.displayName, currentUser?.email);

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
      unawaited(LoggerService.debug('User account deleted'));
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
      unawaited(LoggerService.debug('Profile updated successfully'));
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
      unawaited(LoggerService.debug('Email verification sent'));
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