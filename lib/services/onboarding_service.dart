import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

/// Service for persisting onboarding survey data to Firestore.
class OnboardingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Save onboarding data to Firestore users/{userId}.
  static Future<void> saveOnboardingData({
    required String gameType,
    required String pokerJourney,
    required int monthlySessions,
    required List<String> purposes,
  }) async {
    final user = AuthService.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'hasCompletedOnboarding': true,
        'onboardingData': {
          'gameType': gameType,
          'pokerJourney': pokerJourney,
          'monthlySessions': monthlySessions,
          'purposes': purposes,
          'completedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('OnboardingService.saveOnboardingData error: $e');
    }
  }

  /// Check if the current user has completed onboarding.
  static Future<bool> hasCompletedOnboarding() async {
    final user = AuthService.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return false;
      return doc.data()?['hasCompletedOnboarding'] == true;
    } catch (e) {
      debugPrint('OnboardingService.hasCompletedOnboarding error: $e');
      return false;
    }
  }

  /// Mark onboarding as complete without saving survey data (skip scenario).
  static Future<void> markOnboardingComplete() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'hasCompletedOnboarding': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('OnboardingService.markOnboardingComplete error: $e');
    }
  }
}
