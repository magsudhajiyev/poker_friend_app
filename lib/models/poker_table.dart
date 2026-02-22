import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a poker table
enum TableStatus {
  inactive,  // No active session
  active,    // Session in progress
  paused,    // Session paused
}

extension TableStatusExtension on TableStatus {
  String get value {
    switch (this) {
      case TableStatus.inactive:
        return 'inactive';
      case TableStatus.active:
        return 'active';
      case TableStatus.paused:
        return 'paused';
    }
  }

  static TableStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'active':
        return TableStatus.active;
      case 'paused':
        return TableStatus.paused;
      case 'inactive':
      default:
        return TableStatus.inactive;
    }
  }
}

/// Represents a poker table within a club
class PokerTable {
  final String id;
  final String clubId;
  final int tableNumber;
  final String name;
  final TableStatus status;
  final String? dealerId;  // Currently assigned dealer
  final String? currentSessionId;  // Active dealer session
  final Map<int, String> qrCodes;  // seat number -> QR code data
  final String? tableQRCode;  // Table-level QR code for dealers to scan
  final DateTime createdAt;

  PokerTable({
    required this.id,
    required this.clubId,
    required this.tableNumber,
    required this.name,
    this.status = TableStatus.inactive,
    this.dealerId,
    this.currentSessionId,
    this.qrCodes = const {},
    this.tableQRCode,
    required this.createdAt,
  });

  /// Factory constructor from Firestore document
  factory PokerTable.fromFirestore(DocumentSnapshot doc, {String? clubId}) {
    final data = doc.data() as Map<String, dynamic>;
    return PokerTable(
      id: doc.id,
      clubId: clubId ?? data['clubId'] ?? '',
      tableNumber: data['tableNumber'] ?? 1,
      name: data['name'] ?? 'Table ${data['tableNumber'] ?? 1}',
      status: TableStatusExtension.fromString(data['status']),
      dealerId: data['dealerId'],
      currentSessionId: data['currentSessionId'],
      qrCodes: _parseQrCodes(data['qrCodes']),
      tableQRCode: data['tableQRCode'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Factory constructor from map
  factory PokerTable.fromMap(Map<String, dynamic> map) {
    return PokerTable(
      id: map['id'] ?? '',
      clubId: map['clubId'] ?? '',
      tableNumber: map['tableNumber'] ?? 1,
      name: map['name'] ?? 'Table ${map['tableNumber'] ?? 1}',
      status: TableStatusExtension.fromString(map['status']),
      dealerId: map['dealerId'],
      currentSessionId: map['currentSessionId'],
      qrCodes: _parseQrCodes(map['qrCodes']),
      tableQRCode: map['tableQRCode'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  static Map<int, String> _parseQrCodes(dynamic qrCodesData) {
    if (qrCodesData == null) return {};
    if (qrCodesData is Map) {
      return qrCodesData.map((key, value) =>
        MapEntry(int.tryParse(key.toString()) ?? 0, value.toString())
      );
    }
    return {};
  }

  /// Convert to map for Firestore storage
  Map<String, dynamic> toFirestore() {
    return {
      'clubId': clubId,
      'tableNumber': tableNumber,
      'name': name,
      'status': status.value,
      'dealerId': dealerId,
      'currentSessionId': currentSessionId,
      'qrCodes': qrCodes.map((key, value) => MapEntry(key.toString(), value)),
      'tableQRCode': tableQRCode,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Convert to map for local storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clubId': clubId,
      'tableNumber': tableNumber,
      'name': name,
      'status': status.value,
      'dealerId': dealerId,
      'currentSessionId': currentSessionId,
      'qrCodes': qrCodes.map((key, value) => MapEntry(key.toString(), value)),
      'tableQRCode': tableQRCode,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create a copy with updated values
  PokerTable copyWith({
    String? name,
    TableStatus? status,
    String? dealerId,
    String? currentSessionId,
    Map<int, String>? qrCodes,
    String? tableQRCode,
  }) {
    return PokerTable(
      id: id,
      clubId: clubId,
      tableNumber: tableNumber,
      name: name ?? this.name,
      status: status ?? this.status,
      dealerId: dealerId ?? this.dealerId,
      currentSessionId: currentSessionId ?? this.currentSessionId,
      qrCodes: qrCodes ?? this.qrCodes,
      tableQRCode: tableQRCode ?? this.tableQRCode,
      createdAt: createdAt,
    );
  }

  /// Check if a specific seat has a QR code
  bool hasSeatQRCode(int seatNumber) => qrCodes.containsKey(seatNumber);

  /// Get QR code for a specific seat
  String? getSeatQRCode(int seatNumber) => qrCodes[seatNumber];
}
