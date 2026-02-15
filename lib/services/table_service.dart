import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/poker_table.dart';
import '../models/qr_seat_data.dart';
import 'auth_service.dart';

/// Service for managing poker tables within clubs
class TableService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _clubsCollection = 'clubs';
  static const String _tablesSubcollection = 'tables';

  /// Create a new table in a club
  static Future<PokerTable> createTable({
    required String clubId,
    required int tableNumber,
    String? name,
    int maxSeats = 9,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) throw 'User not authenticated';

    final now = DateTime.now();
    final tableName = name ?? 'Table $tableNumber';

    // Generate QR codes for each seat
    final qrCodes = <int, String>{};
    for (var seat = 1; seat <= maxSeats; seat++) {
      // We'll generate the actual QR data - the tableId placeholder will be updated
      qrCodes[seat] = ''; // Will be updated after we have the table ID
    }

    final tableData = PokerTable(
      id: '',
      clubId: clubId,
      tableNumber: tableNumber,
      name: tableName,
      status: TableStatus.inactive,
      dealerId: null,
      currentSessionId: null,
      qrCodes: {},
      createdAt: now,
    );

    // Create table document
    final tableRef = await _firestore
        .collection(_clubsCollection)
        .doc(clubId)
        .collection(_tablesSubcollection)
        .add(tableData.toFirestore());

    // Now generate QR codes with the actual table ID
    final actualQrCodes = <String, String>{};
    for (var seat = 1; seat <= maxSeats; seat++) {
      final qrData = QRSeatData(
        clubId: clubId,
        tableId: tableRef.id,
        seatNumber: seat,
      );
      actualQrCodes[seat.toString()] = qrData.encode();
    }

    // Update the table with QR codes
    await tableRef.update({'qrCodes': actualQrCodes});

    // Parse QR codes back to Map<int, String>
    final parsedQrCodes = actualQrCodes.map(
      (key, value) => MapEntry(int.parse(key), value),
    );

    return PokerTable(
      id: tableRef.id,
      clubId: clubId,
      tableNumber: tableNumber,
      name: tableName,
      status: TableStatus.inactive,
      dealerId: null,
      currentSessionId: null,
      qrCodes: parsedQrCodes,
      createdAt: now,
    );
  }

  /// Get all tables for a club
  static Future<List<PokerTable>> getTables(String clubId) async {
    try {
      final snapshot = await _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_tablesSubcollection)
          .orderBy('tableNumber')
          .get();

      return snapshot.docs
          .map((doc) => PokerTable.fromFirestore(doc, clubId: clubId))
          .toList();
    } catch (e) {
      print('Error getting tables: $e');
      return [];
    }
  }

  /// Get a single table by ID
  static Future<PokerTable?> getTable(String clubId, String tableId) async {
    try {
      final doc = await _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_tablesSubcollection)
          .doc(tableId)
          .get();

      if (doc.exists) {
        return PokerTable.fromFirestore(doc, clubId: clubId);
      }
      return null;
    } catch (e) {
      print('Error getting table: $e');
      return null;
    }
  }

  /// Update table properties
  static Future<void> updateTable(
    String clubId,
    String tableId, {
    String? name,
    TableStatus? status,
    String? dealerId,
    String? currentSessionId,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (status != null) updates['status'] = status.value;
    if (dealerId != null) updates['dealerId'] = dealerId;
    if (currentSessionId != null) updates['currentSessionId'] = currentSessionId;

    if (updates.isNotEmpty) {
      await _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_tablesSubcollection)
          .doc(tableId)
          .update(updates);
    }
  }

  /// Clear table session (when session ends)
  static Future<void> clearTableSession(String clubId, String tableId) async {
    await _firestore
        .collection(_clubsCollection)
        .doc(clubId)
        .collection(_tablesSubcollection)
        .doc(tableId)
        .update({
          'status': TableStatus.inactive.value,
          'dealerId': null,
          'currentSessionId': null,
        });
  }

  /// Delete a table
  static Future<void> deleteTable(String clubId, String tableId) async {
    await _firestore
        .collection(_clubsCollection)
        .doc(clubId)
        .collection(_tablesSubcollection)
        .doc(tableId)
        .delete();
  }

  /// Get QR code URL for a specific seat
  static Future<String?> getSeatQRCode(
    String clubId,
    String tableId,
    int seatNumber,
  ) async {
    final table = await getTable(clubId, tableId);
    return table?.getSeatQRCode(seatNumber);
  }

  /// Regenerate QR codes for a table (e.g., if compromised)
  static Future<PokerTable?> regenerateQRCodes(
    String clubId,
    String tableId, {
    int maxSeats = 9,
  }) async {
    try {
      final newQrCodes = <String, String>{};
      for (var seat = 1; seat <= maxSeats; seat++) {
        final qrData = QRSeatData(
          clubId: clubId,
          tableId: tableId,
          seatNumber: seat,
        );
        newQrCodes[seat.toString()] = qrData.encode();
      }

      await _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_tablesSubcollection)
          .doc(tableId)
          .update({'qrCodes': newQrCodes});

      return await getTable(clubId, tableId);
    } catch (e) {
      print('Error regenerating QR codes: $e');
      return null;
    }
  }

  /// Watch a specific table for real-time updates
  static Stream<PokerTable?> watchTable(String clubId, String tableId) {
    return _firestore
        .collection(_clubsCollection)
        .doc(clubId)
        .collection(_tablesSubcollection)
        .doc(tableId)
        .snapshots()
        .map((doc) => doc.exists ? PokerTable.fromFirestore(doc, clubId: clubId) : null);
  }

  /// Watch all tables in a club for real-time updates
  static Stream<List<PokerTable>> watchTables(String clubId) {
    return _firestore
        .collection(_clubsCollection)
        .doc(clubId)
        .collection(_tablesSubcollection)
        .orderBy('tableNumber')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PokerTable.fromFirestore(doc, clubId: clubId))
            .toList());
  }
}
