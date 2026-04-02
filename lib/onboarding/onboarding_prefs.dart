import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';

class OnboardingPrefs {
  static const _field = 'hasSeenOnboarding';

  static String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  static Future<bool> hasSeenOnboarding() async {
    final uid = _userId;
    if (uid == null) return true; // No user logged in, skip tour
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      return doc.data()?[_field] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markOnboardingSeen() async {
    final uid = _userId;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({_field: true}, SetOptions(merge: true));
      // Cancel the delayed onboarding notification since user completed it
      NotificationService.cancelOnboardingReminder();
    } catch (_) {}
  }

  static Future<void> resetOnboarding() async {
    final uid = _userId;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({_field: FieldValue.delete()});
    } catch (_) {}
  }
}
