import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/waitlist_entry.dart';
import 'auth_service.dart';
import 'club_notification_service.dart';

/// Normalizes a stakes string (e.g. "1/2", " 1 / 2 ") to a Firestore-safe key ("1_2").
/// Used for stakes-scoped waitlists where multiple live cash events sharing the
/// same stakes share a single waitlist.
String stakesKeyFor(String stakes) {
  final normalized = stakes.trim().toLowerCase();
  return normalized
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

/// Service for managing cash game event waitlists
class WaitlistService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _clubsCollection = 'clubs';
  static const String _eventsSubcollection = 'events';
  static const String _waitlistSubcollection = 'waitlist';
  static const String _stakesWaitlistsSubcollection = 'stakes_waitlists';
  static const String _entriesSubcollection = 'entries';

  /// Get the waitlist collection reference for an event
  static CollectionReference<Map<String, dynamic>> _getWaitlistRef(
    String clubId,
    String eventId,
  ) {
    return _firestore
        .collection(_clubsCollection)
        .doc(clubId)
        .collection(_eventsSubcollection)
        .doc(eventId)
        .collection(_waitlistSubcollection);
  }

  /// Join the waitlist for an event
  /// Returns the new waitlist entry
  static Future<WaitlistEntry> joinWaitlist({
    required String clubId,
    required String eventId,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) throw 'User not authenticated';

    final displayName = AuthService.userDisplayName;
    final waitlistRef = _getWaitlistRef(clubId, eventId);

    // Check if user is already in waitlist
    final existing = await waitlistRef
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['waiting', 'notified'])
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      // User already in waitlist, return existing entry
      return WaitlistEntry.fromFirestore(existing.docs.first);
    }

    // Create new entry with current timestamp for FIFO ordering
    final now = DateTime.now();
    final entry = WaitlistEntry(
      id: '',
      eventId: eventId,
      clubId: clubId,
      userId: userId,
      userDisplayName: displayName,
      joinedAt: now,
      status: WaitlistStatus.waiting,
    );

    final docRef = await waitlistRef.add(entry.toFirestore());
    return entry.copyWith(id: docRef.id);
  }

  /// Add a specific player to the waitlist (for admin use, e.g., when closing a table)
  static Future<WaitlistEntry> addPlayerToWaitlist({
    required String clubId,
    required String eventId,
    required String userId,
    required String displayName,
  }) async {
    final waitlistRef = _getWaitlistRef(clubId, eventId);

    // Check if user is already in waitlist
    final existing = await waitlistRef
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['waiting', 'notified'])
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      // User already in waitlist, return existing entry
      return WaitlistEntry.fromFirestore(existing.docs.first);
    }

    // Create new entry with current timestamp for FIFO ordering
    final now = DateTime.now();
    final entry = WaitlistEntry(
      id: '',
      eventId: eventId,
      clubId: clubId,
      userId: userId,
      userDisplayName: displayName,
      joinedAt: now,
      status: WaitlistStatus.waiting,
    );

    final docRef = await waitlistRef.add(entry.toFirestore());
    return entry.copyWith(id: docRef.id);
  }

  /// Leave the waitlist voluntarily
  static Future<void> leaveWaitlist({
    required String clubId,
    required String eventId,
    required String entryId,
  }) async {
    final waitlistRef = _getWaitlistRef(clubId, eventId);
    await waitlistRef.doc(entryId).update({
      'status': 'removed',
    });
  }

  /// Leave the waitlist by user ID (for current user)
  static Future<void> leaveWaitlistByUser({
    required String clubId,
    required String eventId,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) throw 'User not authenticated';

    final waitlistRef = _getWaitlistRef(clubId, eventId);
    final snapshot = await waitlistRef
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['waiting', 'notified'])
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'status': 'removed'});
    }
    await batch.commit();
  }

  /// Get current user's position in the waitlist (1-indexed)
  /// Returns null if user is not in waitlist
  static Future<int?> getPosition({
    required String clubId,
    required String eventId,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) return null;

    final waitlistRef = _getWaitlistRef(clubId, eventId);

    // Get all waiting entries and sort client-side to avoid composite index
    final snapshot = await waitlistRef
        .where('status', isEqualTo: 'waiting')
        .get();

    // Sort by joinedAt client-side
    final docs = snapshot.docs.toList();
    docs.sort((a, b) {
      final aTime = (a.data()['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      final bTime = (b.data()['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      return aTime.compareTo(bTime);
    });

    for (int i = 0; i < docs.length; i++) {
      final data = docs[i].data();
      if (data['userId'] == userId) {
        return i + 1; // 1-indexed
      }
    }

    return null;
  }

  /// Check if current user is in the waitlist
  static Future<bool> isUserInWaitlist({
    required String clubId,
    required String eventId,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) return false;

    final waitlistRef = _getWaitlistRef(clubId, eventId);
    final snapshot = await waitlistRef
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['waiting', 'notified'])
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  /// Get current user's waitlist entry
  static Future<WaitlistEntry?> getUserEntry({
    required String clubId,
    required String eventId,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) return null;

    final waitlistRef = _getWaitlistRef(clubId, eventId);
    final snapshot = await waitlistRef
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['waiting', 'notified'])
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return WaitlistEntry.fromFirestore(snapshot.docs.first);
  }

  /// Watch current user's waitlist entry in real-time
  static Stream<WaitlistEntry?> watchUserEntry({
    required String clubId,
    required String eventId,
  }) {
    final userId = AuthService.userId;
    if (userId == null) return Stream.value(null);

    final waitlistRef = _getWaitlistRef(clubId, eventId);
    return waitlistRef
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          // Filter for active entries client-side to avoid composite index
          final activeEntries = snapshot.docs.where((doc) {
            final status = doc.data()['status'];
            return status == 'waiting' || status == 'notified';
          });
          if (activeEntries.isEmpty) return null;
          return WaitlistEntry.fromFirestore(activeEntries.first);
        });
  }

  /// Get all waiting and notified entries ordered by joinedAt (FIFO)
  static Future<List<WaitlistEntry>> getWaitlist({
    required String clubId,
    required String eventId,
  }) async {
    final waitlistRef = _getWaitlistRef(clubId, eventId);
    final snapshot = await waitlistRef
        .where('status', whereIn: ['waiting', 'notified'])
        .get();

    // Sort client-side to avoid composite index requirement
    final entries = snapshot.docs
        .map((doc) => WaitlistEntry.fromFirestore(doc))
        .toList();
    entries.sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
    return entries;
  }

  /// Watch full waitlist in real-time (includes waiting and notified)
  static Stream<List<WaitlistEntry>> watchWaitlist({
    required String clubId,
    required String eventId,
  }) {
    final waitlistRef = _getWaitlistRef(clubId, eventId);
    return waitlistRef
        .where('status', whereIn: ['waiting', 'notified'])
        .snapshots()
        .map((snapshot) {
          // Sort client-side to avoid composite index requirement
          final entries = snapshot.docs
              .map((doc) => WaitlistEntry.fromFirestore(doc))
              .toList();
          entries.sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
          return entries;
        });
  }

  /// Get the next person in line (first waiting entry)
  static Future<WaitlistEntry?> getNextInLine({
    required String clubId,
    required String eventId,
  }) async {
    final waitlistRef = _getWaitlistRef(clubId, eventId);
    final snapshot = await waitlistRef
        .where('status', isEqualTo: 'waiting')
        .get();

    if (snapshot.docs.isEmpty) return null;

    // Sort client-side and get first
    final entries = snapshot.docs
        .map((doc) => WaitlistEntry.fromFirestore(doc))
        .toList();
    entries.sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
    return entries.first;
  }

  /// Notify the first waiting member that a seat is available
  /// Returns the entry that was notified, or null if waitlist is empty
  static Future<WaitlistEntry?> notifyNextInLine({
    required String clubId,
    required String eventId,
    required String eventName,
  }) async {
    final waitlistRef = _getWaitlistRef(clubId, eventId);

    // Get all waiting entries and sort client-side
    final snapshot = await waitlistRef
        .where('status', isEqualTo: 'waiting')
        .get();

    if (snapshot.docs.isEmpty) return null;

    // Sort by joinedAt and get first
    final docs = snapshot.docs.toList();
    docs.sort((a, b) {
      final aTime = (a.data()['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      final bTime = (b.data()['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      return aTime.compareTo(bTime);
    });

    final doc = docs.first;
    final entry = WaitlistEntry.fromFirestore(doc);
    final now = DateTime.now();

    // Update status to notified
    await doc.reference.update({
      'status': 'notified',
      'notifiedAt': Timestamp.fromDate(now),
    });

    // Send notification
    await ClubNotificationService.notifySeatAvailable(
      clubId: clubId,
      userId: entry.userId,
      eventId: eventId,
      eventName: eventName,
    );

    return entry.copyWith(
      status: WaitlistStatus.notified,
      notifiedAt: now,
    );
  }

  /// Mark a waitlist entry as seated
  static Future<void> markSeated({
    required String clubId,
    required String eventId,
    required String entryId,
    required String tableId,
    required int seatNumber,
  }) async {
    final waitlistRef = _getWaitlistRef(clubId, eventId);
    await waitlistRef.doc(entryId).update({
      'status': 'seated',
      'seatedTableId': tableId,
      'seatedSeatNumber': seatNumber,
    });
  }

  /// Get waitlist entry by ID
  static Future<WaitlistEntry?> getEntry({
    required String clubId,
    required String eventId,
    required String entryId,
  }) async {
    final waitlistRef = _getWaitlistRef(clubId, eventId);
    final doc = await waitlistRef.doc(entryId).get();
    if (!doc.exists) return null;
    return WaitlistEntry.fromFirestore(doc);
  }

  /// Get total count of people waiting
  static Future<int> getWaitlistCount({
    required String clubId,
    required String eventId,
  }) async {
    final waitlistRef = _getWaitlistRef(clubId, eventId);
    final snapshot = await waitlistRef
        .where('status', isEqualTo: 'waiting')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  /// Clear waitlist when event ends (mark all as removed)
  static Future<void> clearWaitlist({
    required String clubId,
    required String eventId,
  }) async {
    final waitlistRef = _getWaitlistRef(clubId, eventId);
    final snapshot = await waitlistRef
        .where('status', whereIn: ['waiting', 'notified'])
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'status': 'removed'});
    }
    await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // Stakes-scoped waitlists
  //
  // Used by the Grouped Cash Game screen, where multiple live cash events
  // sharing the same stakes (e.g., "1/2") share a single waitlist. Entries
  // live at clubs/{clubId}/stakes_waitlists/{stakesKey}/entries/{entryId}.
  //
  // The existing WaitlistEntry model is reused; the `eventId` field stores
  // the stakesKey for stakes-scoped entries.
  // ---------------------------------------------------------------------------

  /// Get the waitlist collection reference for a stakes group
  static CollectionReference<Map<String, dynamic>> _getStakesWaitlistRef(
    String clubId,
    String stakesKey,
  ) {
    return _firestore
        .collection(_clubsCollection)
        .doc(clubId)
        .collection(_stakesWaitlistsSubcollection)
        .doc(stakesKey)
        .collection(_entriesSubcollection);
  }

  /// Join the stakes-scoped waitlist
  static Future<WaitlistEntry> joinStakesWaitlist({
    required String clubId,
    required String stakesKey,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) throw 'User not authenticated';

    final displayName = AuthService.userDisplayName;
    final waitlistRef = _getStakesWaitlistRef(clubId, stakesKey);

    // Check if user is already in waitlist
    final existing = await waitlistRef
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['waiting', 'notified'])
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return WaitlistEntry.fromFirestore(existing.docs.first);
    }

    final now = DateTime.now();
    final entry = WaitlistEntry(
      id: '',
      eventId: stakesKey, // stakesKey stored in eventId field
      clubId: clubId,
      userId: userId,
      userDisplayName: displayName,
      joinedAt: now,
      status: WaitlistStatus.waiting,
    );

    final docRef = await waitlistRef.add(entry.toFirestore());
    return entry.copyWith(id: docRef.id);
  }

  /// Leave the stakes-scoped waitlist (current user)
  static Future<void> leaveStakesWaitlist({
    required String clubId,
    required String stakesKey,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) throw 'User not authenticated';

    final waitlistRef = _getStakesWaitlistRef(clubId, stakesKey);
    final snapshot = await waitlistRef
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['waiting', 'notified'])
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'status': 'removed'});
    }
    await batch.commit();
  }

  /// Get current user's position in the stakes waitlist (1-indexed)
  static Future<int?> getStakesWaitlistPosition({
    required String clubId,
    required String stakesKey,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) return null;

    final waitlistRef = _getStakesWaitlistRef(clubId, stakesKey);
    final snapshot = await waitlistRef
        .where('status', isEqualTo: 'waiting')
        .get();

    final docs = snapshot.docs.toList();
    docs.sort((a, b) {
      final aTime = (a.data()['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      final bTime = (b.data()['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      return aTime.compareTo(bTime);
    });

    for (int i = 0; i < docs.length; i++) {
      if (docs[i].data()['userId'] == userId) {
        return i + 1;
      }
    }

    return null;
  }

  /// Total count of people waiting in the stakes group
  static Future<int> getStakesWaitlistCount({
    required String clubId,
    required String stakesKey,
  }) async {
    final waitlistRef = _getStakesWaitlistRef(clubId, stakesKey);
    final snapshot = await waitlistRef
        .where('status', isEqualTo: 'waiting')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  /// Get current user's stakes-scoped waitlist entry
  static Future<WaitlistEntry?> getUserStakesEntry({
    required String clubId,
    required String stakesKey,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) return null;

    final waitlistRef = _getStakesWaitlistRef(clubId, stakesKey);
    final snapshot = await waitlistRef
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['waiting', 'notified'])
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return WaitlistEntry.fromFirestore(snapshot.docs.first);
  }

  /// Watch current user's stakes-scoped waitlist entry in real-time
  static Stream<WaitlistEntry?> watchUserStakesEntry({
    required String clubId,
    required String stakesKey,
  }) {
    final userId = AuthService.userId;
    if (userId == null) return Stream.value(null);

    final waitlistRef = _getStakesWaitlistRef(clubId, stakesKey);
    return waitlistRef
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final activeEntries = snapshot.docs.where((doc) {
            final status = doc.data()['status'];
            return status == 'waiting' || status == 'notified';
          });
          if (activeEntries.isEmpty) return null;
          return WaitlistEntry.fromFirestore(activeEntries.first);
        });
  }

  /// Watch the full stakes-scoped waitlist in real-time, ordered FIFO by
  /// joinedAt (first to join at the top). Used by the admin waitlist drawer.
  static Stream<List<WaitlistEntry>> watchStakesWaitlist({
    required String clubId,
    required String stakesKey,
  }) {
    final waitlistRef = _getStakesWaitlistRef(clubId, stakesKey);
    return waitlistRef
        .where('status', whereIn: ['waiting', 'notified'])
        .snapshots()
        .map((snapshot) {
          final entries = snapshot.docs
              .map((doc) => WaitlistEntry.fromFirestore(doc))
              .toList();
          entries.sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
          return entries;
        });
  }

  /// Remove a specific user from a stakes-scoped waitlist (any active
  /// waiting/notified entries). Called automatically when an admin seats a
  /// player at a table in the matching stakes group — whether that player
  /// came from the waitlist or not.
  static Future<void> removeUserFromStakesWaitlist({
    required String clubId,
    required String stakesKey,
    required String userId,
  }) async {
    final waitlistRef = _getStakesWaitlistRef(clubId, stakesKey);
    final snapshot = await waitlistRef
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['waiting', 'notified'])
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'status': 'seated'});
    }
    await batch.commit();
  }

  /// Admin action: notify a specific waitlist entry that a seat is available.
  /// Updates status to "notified" and sends a push notification to the user.
  /// Returns the updated entry.
  static Future<WaitlistEntry> notifyStakesWaitlistEntry({
    required String clubId,
    required String stakesKey,
    required WaitlistEntry entry,
    required String stakesDisplay,
  }) async {
    final waitlistRef = _getStakesWaitlistRef(clubId, stakesKey);
    final now = DateTime.now();

    await waitlistRef.doc(entry.id).update({
      'status': 'notified',
      'notifiedAt': Timestamp.fromDate(now),
    });

    await ClubNotificationService.notifySeatAvailable(
      clubId: clubId,
      userId: entry.userId,
      eventId: stakesKey,
      eventName: 'Cash Game $stakesDisplay',
    );

    return entry.copyWith(
      status: WaitlistStatus.notified,
      notifiedAt: now,
    );
  }
}
