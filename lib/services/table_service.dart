import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/poker_table.dart';
import '../models/qr_seat_data.dart';
import '../models/qr_table_data.dart';
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

    // Generate table-level QR code for dealers
    final tableQrData = QRTableData(
      clubId: clubId,
      tableId: tableRef.id,
    );
    final tableQRCode = tableQrData.encode();

    // Update the table with QR codes
    await tableRef.update({
      'qrCodes': actualQrCodes,
      'tableQRCode': tableQRCode,
    });

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
      tableQRCode: tableQRCode,
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

  /// Find a table by name pattern (e.g., "table_1" -> "Table 1")
  /// or by table number extracted from the pattern
  static Future<PokerTable?> findTableByNamePattern(
    String clubId,
    String namePattern,
  ) async {
    try {
      // First try direct ID lookup
      final directTable = await getTable(clubId, namePattern);
      if (directTable != null) return directTable;

      // Try to extract table number from pattern like "table_1" or "1"
      int? tableNumber;
      final match = RegExp(r'(?:table_)?(\d+)$', caseSensitive: false)
          .firstMatch(namePattern);
      if (match != null) {
        tableNumber = int.tryParse(match.group(1)!);
      }

      // Get all tables and find matching one
      final tables = await getTables(clubId);

      // Try to match by table number
      if (tableNumber != null) {
        final byNumber = tables.where((t) => t.tableNumber == tableNumber);
        if (byNumber.isNotEmpty) return byNumber.first;
      }

      // Try to match by name (case-insensitive)
      final searchName = namePattern.replaceAll('_', ' ').toLowerCase();
      final byName = tables.where(
        (t) => t.name.toLowerCase() == searchName ||
            t.name.toLowerCase() == 'table $searchName' ||
            t.name.toLowerCase().contains(searchName),
      );
      if (byName.isNotEmpty) return byName.first;

      return null;
    } catch (e) {
      print('Error finding table by name pattern: $e');
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

  /// Get or generate the table QR code for a table
  /// This ensures existing tables have a QR code (migration)
  static Future<String?> getOrGenerateTableQRCode(
    String clubId,
    String tableId,
  ) async {
    try {
      final table = await getTable(clubId, tableId);
      if (table == null) return null;

      // If table already has a QR code, return it
      if (table.tableQRCode != null && table.tableQRCode!.isNotEmpty) {
        return table.tableQRCode;
      }

      // Generate new table QR code
      final tableQrData = QRTableData(
        clubId: clubId,
        tableId: tableId,
      );
      final tableQRCode = tableQrData.encode();

      // Save to Firestore
      await _firestore
          .collection(_clubsCollection)
          .doc(clubId)
          .collection(_tablesSubcollection)
          .doc(tableId)
          .update({'tableQRCode': tableQRCode});

      return tableQRCode;
    } catch (e) {
      print('Error getting/generating table QR code: $e');
      return null;
    }
  }

  /// Get table with ensured QR code (generates if missing)
  static Future<PokerTable?> getTableWithQRCode(
    String clubId,
    String tableId,
  ) async {
    try {
      var table = await getTable(clubId, tableId);
      if (table == null) return null;

      // If table doesn't have a QR code, generate one
      if (table.tableQRCode == null || table.tableQRCode!.isEmpty) {
        final qrCode = await getOrGenerateTableQRCode(clubId, tableId);
        if (qrCode != null) {
          table = table.copyWith(tableQRCode: qrCode);
        }
      }

      return table;
    } catch (e) {
      print('Error getting table with QR code: $e');
      return null;
    }
  }
}
