import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/club_notification.dart';
import 'auth_service.dart';
import 'club_notification_service.dart';
import 'email_service.dart';
import 'subscription_service.dart';

/// Manages partner grants — free tier overrides granted by the super admin.
///
/// Each user can have at most one active grant stored in
/// `partner_grants/{userId}`. The service keeps a real-time listener on the
/// current user's document so tier changes propagate immediately.
class PartnerGrantService {
  PartnerGrantService._();

  static final _firestore = FirebaseFirestore.instance;
  static const _collection = 'partner_grants';

  // ── Cached grant for the current user ────────────────────────────────────

  static Map<String, dynamic>? _cachedGrant;
  static StreamSubscription<DocumentSnapshot>? _listener;

  /// Bumped on every grant change — attach via ValueListenableBuilder to
  /// rebuild UI when partner status changes.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Guard to prevent concurrent auto-expire writes.
  static bool _isAutoExpiring = false;

  /// The current user's granted tier, or null if no active grant.
  static String? get partnerTier {
    final g = _cachedGrant;
    if (g == null || g['status'] != 'active') return null;
    final expiresAt = g['expiresAt'] as Timestamp?;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt.toDate())) {
      _autoExpire(g['userId'] as String?);
      return null;
    }
    return g['tier'] as String?;
  }

  /// Custom AI analysis quota, or null if no override.
  /// -1 = unlimited, 0 = use tier default (treated as null).
  static int? get partnerAiQuota {
    final g = _cachedGrant;
    if (g == null || g['status'] != 'active') return null;
    final expiresAt = g['expiresAt'] as Timestamp?;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt.toDate())) {
      _autoExpire(g['userId'] as String?);
      return null;
    }
    final q = g['aiQuota'];
    if (q is int && q != 0) return q;
    return null;
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Start listening to the current user's partner grant.
  /// Awaits the first Firestore snapshot so the tier is available immediately
  /// after this call completes. Times out after 3s to avoid blocking login.
  static Future<void> init(String userId) async {
    _cancelListener();
    final firstSnapshot = Completer<void>();
    _listener = _firestore
        .collection(_collection)
        .doc(userId)
        .snapshots()
        .listen((snap) {
      _cachedGrant = snap.exists ? snap.data() : null;
      revision.value++;
      SubscriptionService.notifyPartnerGrantChanged();
      if (!firstSnapshot.isCompleted) firstSnapshot.complete();
    }, onError: (_) {
      // Non-fatal — user stays at their RevenueCat tier
      if (!firstSnapshot.isCompleted) firstSnapshot.complete();
    });
    await firstSnapshot.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () {},
    );
  }

  /// Clear cache on logout.
  static void reset() {
    _cancelListener();
    _cachedGrant = null;
  }

  static void _cancelListener() {
    _listener?.cancel();
    _listener = null;
  }

  // ── Auto-expire ────────────────────────────────────────────────────────

  /// Fire-and-forget: set status to 'expired' when grant has passed its
  /// expiresAt timestamp. Prevents concurrent writes via [_isAutoExpiring].
  static void _autoExpire(String? userId) {
    if (userId == null || _isAutoExpiring) return;
    _isAutoExpiring = true;
    _firestore.collection(_collection).doc(userId).update({
      'status': 'expired',
      'updatedAt': FieldValue.serverTimestamp(),
    }).catchError((_) {
      // Non-fatal — next access will retry
    }).whenComplete(() => _isAutoExpiring = false);
  }

  // ── Admin methods (super-admin only) ─────────────────────────────────────

  /// Fetch all partner grants (active first, then revoked).
  static Future<List<Map<String, dynamic>>> getAllGrants() async {
    final snap = await _firestore
        .collection(_collection)
        .orderBy('grantedAt', descending: true)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  /// Create a new partner grant. Document ID = userId.
  /// [duration] sets when the grant expires. null = indefinite.
  static Future<void> createGrant({
    required String userId,
    required String email,
    required String displayName,
    required String tier,
    required int aiQuota,
    String notes = '',
    Duration? duration,
  }) async {
    final data = <String, dynamic>{
      'userId': userId,
      'email': email,
      'displayName': displayName,
      'tier': tier,
      'aiQuota': aiQuota,
      'status': 'active',
      'grantedAt': FieldValue.serverTimestamp(),
      'grantedBy': AuthService.userId ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
      'notes': notes,
    };
    if (duration != null) {
      data['expiresAt'] = Timestamp.fromDate(DateTime.now().add(duration));
    }
    await _firestore.collection(_collection).doc(userId).set(data);

    // Notify the partner about their new plan
    final tierLabel = tier[0].toUpperCase() + tier.substring(1);
    final durLabel = durationLabel(duration);
    try {
      await ClubNotificationService.notifyUser(
        userId: userId,
        type: NotificationType.partnerGranted,
        title: 'You\'ve been upgraded to $tierLabel!',
        body: 'A $tierLabel plan has been activated on your account for $durLabel. Enjoy your new features!',
        data: {'action': 'partner_granted', 'tier': tier},
      );
    } catch (e) {
      debugPrint('PartnerGrantService: Failed to send notification: $e');
    }

    // Fire-and-forget email
    unawaited(EmailService.sendPartnerGrantEmail(
      toEmail: email,
      displayName: displayName,
      tier: tier,
      duration: durLabel,
    ).catchError((_) => false));
  }

  /// Update an existing grant's tier, quota, notes, or duration.
  /// When [duration] is provided, a new expiresAt is computed from now.
  static Future<void> updateGrant(
    String userId, {
    String? tier,
    int? aiQuota,
    String? notes,
    Duration? duration,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (tier != null) updates['tier'] = tier;
    if (aiQuota != null) updates['aiQuota'] = aiQuota;
    if (notes != null) updates['notes'] = notes;
    if (duration != null) {
      updates['expiresAt'] =
          Timestamp.fromDate(DateTime.now().add(duration));
    }
    await _firestore.collection(_collection).doc(userId).update(updates);
  }

  /// Revoke a partner grant (keeps the document for history).
  static Future<void> revokeGrant(String userId) async {
    await _firestore.collection(_collection).doc(userId).update({
      'status': 'revoked',
      'revokedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Re-activate a previously revoked or expired grant.
  /// [duration] sets the new expiry. null = remove expiresAt (indefinite).
  static Future<void> reactivateGrant(String userId, {Duration? duration}) async {
    final updates = <String, dynamic>{
      'status': 'active',
      'revokedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (duration != null) {
      updates['expiresAt'] =
          Timestamp.fromDate(DateTime.now().add(duration));
    } else {
      updates['expiresAt'] = FieldValue.delete();
    }
    await _firestore.collection(_collection).doc(userId).update(updates);
  }

  /// Search users by name, email, or username for the user management flow.
  /// Runs parallel queries on `email`, `displayNameLower`, and `username`
  /// then deduplicates by userId.
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().length < 2) return [];
    final lower = query.trim().toLowerCase();

    // Run email, displayName, and username prefix queries in parallel
    final results = await Future.wait([
      _firestore
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: lower)
          .where('email', isLessThan: '$lower\uf8ff')
          .limit(10)
          .get(),
      _firestore
          .collection('users')
          .where('displayNameLower', isGreaterThanOrEqualTo: lower)
          .where('displayNameLower', isLessThan: '$lower\uf8ff')
          .limit(10)
          .get(),
      _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: lower)
          .where('username', isLessThan: '$lower\uf8ff')
          .limit(10)
          .get(),
    ]);

    // Merge and deduplicate by userId
    final seen = <String>{};
    final merged = <Map<String, dynamic>>[];
    for (final snap in results) {
      for (final doc in snap.docs) {
        if (seen.add(doc.id)) {
          merged.add({
            'userId': doc.id,
            'email': doc.data()['email'] ?? '',
            'displayName': doc.data()['displayName'] ?? '',
            'username': doc.data()['username'] ?? '',
          });
        }
      }
    }
    return merged;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Human-readable remaining time from an [expiresAt] timestamp.
  /// Returns "Expired" if past, "5 days left" / "2 months left" etc.
  static String formatRemainingTime(Timestamp? expiresAt) {
    if (expiresAt == null) return 'No expiry';
    final now = DateTime.now();
    final expiry = expiresAt.toDate();
    final diff = expiry.difference(now);
    if (diff.isNegative) return 'Expired';
    if (diff.inDays >= 30) {
      final months = (diff.inDays / 30).round();
      return '$months month${months == 1 ? '' : 's'} left';
    }
    if (diff.inDays >= 1) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} left';
    }
    if (diff.inHours >= 1) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} left';
    }
    return 'Less than an hour left';
  }

  /// Human-readable label for a duration option.
  static String durationLabel(Duration? duration) {
    if (duration == null) return 'indefinitely';
    if (duration.inDays == 7) return '1 week';
    if (duration.inDays == 30) return '1 month';
    if (duration.inDays == 90) return '3 months';
    if (duration.inDays < 30) return '${duration.inDays} days';
    final months = (duration.inDays / 30).round();
    return '$months month${months == 1 ? '' : 's'}';
  }
}
