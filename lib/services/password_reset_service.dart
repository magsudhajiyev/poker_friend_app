import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'email_service.dart';

class PasswordResetService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static final _googleSignIn = GoogleSignIn(
    serverClientId: '311745459306-povk09gd7ll56fgng8rsac54lrbgguq6.apps.googleusercontent.com',
  );
  static const _collection = 'password_reset_codes';

  /// Generate a random 6-digit code
  static String _generateCode() {
    final random = Random.secure();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Send a 6-digit reset code to the given email
  /// Returns true if code was sent successfully
  static Future<bool> sendResetCode(String email) async {
    final normalizedEmail = email.toLowerCase().trim();

    try {
      // Delete any existing codes for this email
      final existing = await _firestore
          .collection(_collection)
          .where('email', isEqualTo: normalizedEmail)
          .get();
      for (final doc in existing.docs) {
        await doc.reference.delete();
      }

      // Generate new code
      final code = _generateCode();
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(minutes: 15));

      // Store in Firestore
      await _firestore.collection(_collection).add({
        'email': normalizedEmail,
        'code': code,
        'createdAt': Timestamp.fromDate(now),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'verified': false,
        'used': false,
      });

      // Send email via Resend
      final sent = await EmailService.sendPasswordResetCodeEmail(
        toEmail: normalizedEmail,
        code: code,
      );

      if (!sent) {
        debugPrint('PasswordResetService: Failed to send email');
        return false;
      }

      debugPrint('PasswordResetService: Reset code sent to $normalizedEmail');
      return true;
    } catch (e) {
      debugPrint('PasswordResetService: Error sending reset code: $e');
      return false;
    }
  }

  /// Verify the 6-digit code for the given email
  /// Returns true if code is valid and not expired
  static Future<bool> verifyCode(String email, String code) async {
    final normalizedEmail = email.toLowerCase().trim();

    try {
      final now = Timestamp.now();
      final snapshot = await _firestore
          .collection(_collection)
          .where('email', isEqualTo: normalizedEmail)
          .where('code', isEqualTo: code)
          .where('used', isEqualTo: false)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('PasswordResetService: No matching code found');
        return false;
      }

      final doc = snapshot.docs.first;
      final data = doc.data();
      final expiresAt = data['expiresAt'] as Timestamp;

      if (expiresAt.compareTo(now) < 0) {
        debugPrint('PasswordResetService: Code expired');
        return false;
      }

      // Mark as verified
      await doc.reference.update({'verified': true});
      debugPrint('PasswordResetService: Code verified for $normalizedEmail');
      return true;
    } catch (e) {
      debugPrint('PasswordResetService: Error verifying code: $e');
      return false;
    }
  }

  /// Reset password after code verification
  /// Signs in silently with Google (no UI), updates password, then signs out
  static Future<void> resetPassword(String email, String newPassword) async {
    final normalizedEmail = email.toLowerCase().trim();

    // Try silent Google sign-in first (no UI popup)
    GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();

    // If silent fails, fall back to interactive (user may not have signed in before)
    googleUser ??= await _googleSignIn.signIn();

    if (googleUser == null) {
      throw 'Unable to verify your identity. Please try again.';
    }

    // Verify the Google account matches the email being reset
    if (googleUser.email.toLowerCase() != normalizedEmail) {
      await _googleSignIn.signOut();
      throw 'Google account does not match $normalizedEmail.';
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    try {
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        throw 'Failed to verify identity.';
      }

      // Update the password (this adds/restores the password provider)
      await user.updatePassword(newPassword);

      // Mark code as used
      final codes = await _firestore
          .collection(_collection)
          .where('email', isEqualTo: normalizedEmail)
          .where('verified', isEqualTo: true)
          .where('used', isEqualTo: false)
          .get();
      for (final doc in codes.docs) {
        await doc.reference.update({'used': true});
      }

      // Sign out so user goes back to login screen
      await _auth.signOut();
      await _googleSignIn.signOut();

      debugPrint('PasswordResetService: Password updated for $normalizedEmail');
    } on FirebaseAuthException catch (e) {
      // Sign out on failure too
      await _auth.signOut().catchError((_) {});
      await _googleSignIn.signOut().catchError((_) => null);

      if (e.code == 'weak-password') {
        throw 'Password is too weak. Please use at least 6 characters.';
      }
      throw 'Failed to update password: ${e.message}';
    }
  }
}
