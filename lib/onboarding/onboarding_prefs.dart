import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';

class OnboardingPrefs {
  static const _field = 'hasSeenOnboarding';
  static const _analysisField = 'tourAnalysisUsed';
  static const _paywallShownField = 'postTourPaywallShown';
  static const _paywallPendingField = 'postTourPaywallPending';
  static const _signupRequiredField = 'postTourSignupRequired';
  static const _bankrollTourField = 'bankrollTourPending';
  static const _wrapUpPendingField = 'postTourWrapUpPending';
  static const _promoCongratsField = 'promoCongratsPending';

  static String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  static Future<bool> _readFlag(String field, {required bool onError}) async {
    final uid = _userId;
    if (uid == null) return onError;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      return doc.data()?[field] == true;
    } catch (_) {
      return onError;
    }
  }

  static Future<void> _writeFlag(String field, bool value) async {
    final uid = _userId;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({field: value}, SetOptions(merge: true));
    } catch (_) {}
  }

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

  // ── One free AI analysis (tour taste of the premium feature) ──────────
  // Persisted on the user doc so it survives reinstall and account linking.
  // Fails closed (no free analysis) on read errors.

  static Future<bool> canUseTourAnalysis() async =>
      !(await _readFlag(_analysisField, onError: true));

  static Future<void> markTourAnalysisUsed() =>
      _writeFlag(_analysisField, true);

  // ── Post-tour paywall bookkeeping ─────────────────────────────────────
  // Shown at most once ever: the normal completion path shows it directly
  // and sets "shown"; skip paths set "pending" so the next Home visit
  // shows it once.

  static Future<bool> wasPostTourPaywallShown() =>
      _readFlag(_paywallShownField, onError: true);

  static Future<void> markPostTourPaywallShown() =>
      _writeFlag(_paywallShownField, true);

  static Future<bool> isPostTourPaywallPending() =>
      _readFlag(_paywallPendingField, onError: false);

  static Future<void> setPostTourPaywallPending() =>
      _writeFlag(_paywallPendingField, true);

  static Future<void> clearPostTourPaywallPending() =>
      _writeFlag(_paywallPendingField, false);

  // ── Post-tour sign-up gate (guests) ───────────────────────────────────
  // Set when an anonymous guest finishes the tour, so that if they kill the
  // app before linking an account, the next launch forces them back into the
  // required sign-up instead of letting them keep using the app as a guest.
  // Cleared once they successfully link. Persisted on the user doc (survives
  // app kill / reinstall). Fails open on read error to avoid bricking an
  // offline user; the flag is written while online at tour completion and
  // served from Firestore's local cache thereafter.

  static Future<bool> isPostTourSignupRequired() =>
      _readFlag(_signupRequiredField, onError: false);

  static Future<void> setPostTourSignupRequired() =>
      _writeFlag(_signupRequiredField, true);

  static Future<void> clearPostTourSignupRequired() =>
      _writeFlag(_signupRequiredField, false);

  // ── Post-tour bankroll card tip ─────────────────────────────────────
  // Set at tour completion so the next Home visit shows the bankroll
  // card press-and-hold coach mark once.

  static Future<bool> isBankrollTourPending() =>
      _readFlag(_bankrollTourField, onError: false);

  static Future<void> setBankrollTourPending() =>
      _writeFlag(_bankrollTourField, true);

  static Future<void> clearBankrollTourPending() =>
      _writeFlag(_bankrollTourField, false);

  // ── Post-tour wrap-up (completion dialog + paywall) ────────────────
  // The tour ends away from Home, but its final beats — bankroll step →
  // "you're done" dialog → paywall — run ON Home. Persisted so an app
  // kill between tour end and the wrap-up can't lose them.

  static Future<bool> isPostTourWrapUpPending() =>
      _readFlag(_wrapUpPendingField, onError: false);

  static Future<void> setPostTourWrapUpPending() =>
      _writeFlag(_wrapUpPendingField, true);

  static Future<void> clearPostTourWrapUpPending() =>
      _writeFlag(_wrapUpPendingField, false);

  // ── Launch-promo congratulations ─────────────────────────────────────
  // Set when the user taps "Got it" on the free-month gift dialog; the
  // paywall then resets to Home, where the congratulations dialog shows
  // once. Persisted so an app kill in between can't lose it.

  static Future<bool> isPromoCongratsPending() =>
      _readFlag(_promoCongratsField, onError: false);

  static Future<void> setPromoCongratsPending() =>
      _writeFlag(_promoCongratsField, true);

  static Future<void> clearPromoCongratsPending() =>
      _writeFlag(_promoCongratsField, false);
}
