import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/seat_assignment.dart';
import '../models/qr_seat_data.dart';
import 'auth_service.dart';

/// Service for managing seat assignments at poker tables
class SeatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _seatAssignmentsCollection = 'seat_assignments';

  /// Generate a unique ID for a seat assignment
  static String _getSeatId(String clubId, String tableId, int seatNumber) {
    return '${clubId}_${tableId}_$seatNumber';
  }

  /// Request to join a seat (sets status to pending, awaiting dealer approval)
  /// Returns the seat assignment, or throws if seat is occupied
  static Future<SeatAssignment> requestJoinSeat({
    required String clubId,
    required String tableId,
    required int seatNumber,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) throw 'User not authenticated';

    final seatId = _getSeatId(clubId, tableId, seatNumber);
    final seatRef = _firestore.collection(_seatAssignmentsCollection).doc(seatId);

    // Use a transaction to prevent race conditions
    return await _firestore.runTransaction<SeatAssignment>((transaction) async {
      final seatDoc = await transaction.get(seatRef);

      if (seatDoc.exists) {
        final existing = SeatAssignment.fromFirestore(seatDoc);
        // Allow if seat is empty, left status, or player is already in this seat
        if (existing.isOccupied && existing.playerId != userId) {
          throw 'Seat is already occupied by another player';
        }
        // If same player is already pending or joined, return existing
        if (existing.playerId == userId && existing.status != SeatStatus.left) {
          return existing;
        }
      }

      final now = DateTime.now();
      final assignment = SeatAssignment(
        id: seatId,
        clubId: clubId,
        tableId: tableId,
        seatNumber: seatNumber,
        playerId: userId,
        playerName: AuthService.userDisplayName,
        status: SeatStatus.pending,  // Wait for dealer approval
        chipStack: null,  // Will be set by dealer
        assignedAt: now,
        updatedAt: now,
      );

      transaction.set(seatRef, assignment.toFirestore());

      return assignment;
    });
  }

  /// Join a seat at a table (legacy method - for backwards compatibility)
  /// Use requestJoinSeat for new dealer-assisted flow
  static Future<SeatAssignment> joinSeat({
    required String clubId,
    required String tableId,
    required int seatNumber,
    double? initialStack,
  }) async {
    // For backwards compatibility, use the request flow
    return requestJoinSeat(
      clubId: clubId,
      tableId: tableId,
      seatNumber: seatNumber,
    );
  }

  /// Approve a pending join request (for dealers)
  /// Sets the player's chip stack and changes status to 'joined'
  static Future<SeatAssignment> approveJoin({
    required String clubId,
    required String tableId,
    required int seatNumber,
    required double chipStack,
  }) async {
    final seatId = _getSeatId(clubId, tableId, seatNumber);
    final seatRef = _firestore.collection(_seatAssignmentsCollection).doc(seatId);

    return await _firestore.runTransaction<SeatAssignment>((transaction) async {
      final seatDoc = await transaction.get(seatRef);

      if (!seatDoc.exists) {
        throw 'Seat assignment not found';
      }

      final existing = SeatAssignment.fromFirestore(seatDoc);

      if (existing.status != SeatStatus.pending) {
        throw 'No pending join request for this seat';
      }

      final updated = existing.copyWith(
        status: SeatStatus.joined,
        chipStack: chipStack,
        updatedAt: DateTime.now(),
      );

      transaction.update(seatRef, {
        'status': 'joined',
        'chipStack': chipStack,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return updated;
    });
  }

  /// Reject a pending join request (for dealers)
  static Future<void> rejectJoin({
    required String clubId,
    required String tableId,
    required int seatNumber,
  }) async {
    final seatId = _getSeatId(clubId, tableId, seatNumber);
    await _firestore.collection(_seatAssignmentsCollection).doc(seatId).update({
      'playerId': null,
      'playerName': null,
      'status': 'left',
      'chipStack': null,
      'assignedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Watch for pending join requests at a table (for dealers)
  static Stream<List<SeatAssignment>> watchPendingJoins({
    required String clubId,
    required String tableId,
  }) {
    return _firestore
        .collection(_seatAssignmentsCollection)
        .where('clubId', isEqualTo: clubId)
        .where('tableId', isEqualTo: tableId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => SeatAssignment.fromFirestore(doc))
              .toList();
        });
  }

  /// Join a seat using QR data
  static Future<SeatAssignment> joinSeatFromQR(QRSeatData qrData) async {
    return joinSeat(
      clubId: qrData.clubId,
      tableId: qrData.tableId,
      seatNumber: qrData.seatNumber,
    );
  }

  /// Leave a seat at a table
  static Future<void> leaveSeat({
    required String clubId,
    required String tableId,
    required int seatNumber,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) throw 'User not authenticated';

    final seatId = _getSeatId(clubId, tableId, seatNumber);
    final seatRef = _firestore.collection(_seatAssignmentsCollection).doc(seatId);

    await _firestore.runTransaction((transaction) async {
      final seatDoc = await transaction.get(seatRef);

      if (!seatDoc.exists) return;

      final existing = SeatAssignment.fromFirestore(seatDoc);

      // Only allow leaving if the user owns this seat
      if (existing.playerId != userId) {
        throw 'You are not seated in this seat';
      }

      transaction.update(seatRef, {
        'playerId': null,
        'playerName': null,
        'status': 'left',
        'chipStack': null,
        'assignedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Force remove a player from a seat (for dealers/admins)
  static Future<void> removeSeatOccupant({
    required String clubId,
    required String tableId,
    required int seatNumber,
  }) async {
    final seatId = _getSeatId(clubId, tableId, seatNumber);
    await _firestore.collection(_seatAssignmentsCollection).doc(seatId).update({
      'playerId': null,
      'playerName': null,
      'status': 'left',
      'chipStack': null,
      'assignedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get the seat assignment for a specific seat
  static Future<SeatAssignment?> getSeatAssignment({
    required String clubId,
    required String tableId,
    required int seatNumber,
  }) async {
    final seatId = _getSeatId(clubId, tableId, seatNumber);
    final doc = await _firestore
        .collection(_seatAssignmentsCollection)
        .doc(seatId)
        .get();

    if (doc.exists) {
      return SeatAssignment.fromFirestore(doc);
    }
    return null;
  }

  /// Get all seat assignments for a table
  static Future<Map<int, SeatAssignment>> getTableSeats({
    required String clubId,
    required String tableId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_seatAssignmentsCollection)
          .where('clubId', isEqualTo: clubId)
          .where('tableId', isEqualTo: tableId)
          .get();

      final seats = <int, SeatAssignment>{};
      for (final doc in snapshot.docs) {
        final assignment = SeatAssignment.fromFirestore(doc);
        seats[assignment.seatNumber] = assignment;
      }

      return seats;
    } catch (e) {
      print('Error getting table seats: $e');
      return {};
    }
  }

  /// Get the seat where the current user is sitting
  static Future<SeatAssignment?> getCurrentUserSeat({
    required String clubId,
    required String tableId,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) return null;

    try {
      final snapshot = await _firestore
          .collection(_seatAssignmentsCollection)
          .where('clubId', isEqualTo: clubId)
          .where('tableId', isEqualTo: tableId)
          .where('playerId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return SeatAssignment.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      print('Error getting current user seat: $e');
      return null;
    }
  }

  /// Check if the current user is seated at a table
  static Future<bool> isSeated({
    required String clubId,
    required String tableId,
  }) async {
    final seat = await getCurrentUserSeat(clubId: clubId, tableId: tableId);
    return seat != null;
  }

  /// Watch seat assignments for a table in real-time
  static Stream<Map<int, SeatAssignment>> watchTableSeats({
    required String clubId,
    required String tableId,
  }) {
    return _firestore
        .collection(_seatAssignmentsCollection)
        .where('clubId', isEqualTo: clubId)
        .where('tableId', isEqualTo: tableId)
        .snapshots()
        .map((snapshot) {
          final seats = <int, SeatAssignment>{};
          for (final doc in snapshot.docs) {
            final assignment = SeatAssignment.fromFirestore(doc);
            seats[assignment.seatNumber] = assignment;
          }
          return seats;
        });
  }

  /// Watch a specific seat for real-time updates
  static Stream<SeatAssignment?> watchSeat({
    required String clubId,
    required String tableId,
    required int seatNumber,
  }) {
    final seatId = _getSeatId(clubId, tableId, seatNumber);
    return _firestore
        .collection(_seatAssignmentsCollection)
        .doc(seatId)
        .snapshots()
        .map((doc) => doc.exists ? SeatAssignment.fromFirestore(doc) : null);
  }

  /// Clear all seats at a table (when session ends)
  static Future<void> clearAllSeats({
    required String clubId,
    required String tableId,
  }) async {
    final batch = _firestore.batch();
    final seats = await getTableSeats(clubId: clubId, tableId: tableId);

    for (final entry in seats.entries) {
      final seatId = _getSeatId(clubId, tableId, entry.key);
      final ref = _firestore.collection(_seatAssignmentsCollection).doc(seatId);
      batch.update(ref, {
        'playerId': null,
        'playerName': null,
        'status': 'left',
        'chipStack': null,
        'assignedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Update a player's chip stack (for dealers)
  static Future<void> updateChipStack({
    required String clubId,
    required String tableId,
    required int seatNumber,
    required double chipStack,
  }) async {
    final seatId = _getSeatId(clubId, tableId, seatNumber);
    await _firestore.collection(_seatAssignmentsCollection).doc(seatId).update({
      'chipStack': chipStack,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Manually add a player to a seat (for dealers to add walk-up players)
  static Future<SeatAssignment> addManualPlayer({
    required String clubId,
    required String tableId,
    required int seatNumber,
    required String playerName,
    required double chipStack,
  }) async {
    final seatId = _getSeatId(clubId, tableId, seatNumber);
    final seatRef = _firestore.collection(_seatAssignmentsCollection).doc(seatId);

    final now = DateTime.now();
    final assignment = SeatAssignment(
      id: seatId,
      clubId: clubId,
      tableId: tableId,
      seatNumber: seatNumber,
      playerId: 'manual_${DateTime.now().millisecondsSinceEpoch}', // Generate a pseudo-ID for manual players
      playerName: playerName,
      status: SeatStatus.joined,  // Directly joined since dealer is adding
      chipStack: chipStack,
      assignedAt: now,
      updatedAt: now,
    );

    await seatRef.set(assignment.toFirestore());
    return assignment;
  }
}
