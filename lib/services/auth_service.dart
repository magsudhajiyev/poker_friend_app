import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
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
  
  // Sign out
  static Future<void> signOut() async {
    try {
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
}