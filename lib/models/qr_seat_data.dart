import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Data encoded in a QR code for a poker table seat
///
/// URL Format: pkr://club_{clubId}/table_{tableId}/seat/{seatNumber}?v=1&c={checksum}
class QRSeatData {
  static const String urlScheme = 'pkr://';
  static const int currentVersion = 1;

  final String clubId;
  final String tableId;
  final int seatNumber;
  final int version;
  final String checksum;

  QRSeatData({
    required this.clubId,
    required this.tableId,
    required this.seatNumber,
    this.version = currentVersion,
    String? checksum,
  }) : checksum = checksum ?? _generateChecksum(clubId, tableId, seatNumber, currentVersion);

  /// Generate a checksum for the QR data
  static String _generateChecksum(String clubId, String tableId, int seatNumber, int version) {
    final data = '$clubId:$tableId:$seatNumber:$version';
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    // Return first 8 characters of hex string
    return digest.toString().substring(0, 8);
  }

  /// Encode to URL string for QR code
  String encode() {
    return '${urlScheme}club_$clubId/table_$tableId/seat/$seatNumber?v=$version&c=$checksum';
  }

  /// Decode from URL string
  /// Returns null if the URL is invalid
  static QRSeatData? decode(String url) {
    try {
      // Check URL scheme
      if (!url.startsWith(urlScheme)) {
        return null;
      }

      // Remove scheme
      final path = url.substring(urlScheme.length);

      // Split path and query
      final parts = path.split('?');
      if (parts.isEmpty) return null;

      final pathParts = parts[0].split('/');

      // Expected: club_{clubId}/table_{tableId}/seat/{seatNumber}
      if (pathParts.length < 4) return null;

      // Extract clubId
      if (!pathParts[0].startsWith('club_')) return null;
      final clubId = pathParts[0].substring(5);

      // Extract tableId
      if (!pathParts[1].startsWith('table_')) return null;
      final tableId = pathParts[1].substring(6);

      // Extract seat number
      if (pathParts[2] != 'seat') return null;
      final seatNumber = int.tryParse(pathParts[3]);
      if (seatNumber == null) return null;

      // Parse query parameters
      int version = currentVersion;
      String? checksum;

      if (parts.length > 1) {
        final queryParams = Uri.splitQueryString(parts[1]);
        version = int.tryParse(queryParams['v'] ?? '') ?? currentVersion;
        checksum = queryParams['c'];
      }

      return QRSeatData(
        clubId: clubId,
        tableId: tableId,
        seatNumber: seatNumber,
        version: version,
        checksum: checksum ?? _generateChecksum(clubId, tableId, seatNumber, version),
      );
    } catch (e) {
      return null;
    }
  }

  /// Validate the checksum
  bool validateChecksum() {
    final expectedChecksum = _generateChecksum(clubId, tableId, seatNumber, version);
    return checksum == expectedChecksum;
  }

  /// Convert to map for storage
  Map<String, dynamic> toMap() {
    return {
      'type': 'poker_seat',
      'version': version,
      'clubId': clubId,
      'tableId': tableId,
      'seatNumber': seatNumber,
      'checksum': checksum,
    };
  }

  /// Create from map
  factory QRSeatData.fromMap(Map<String, dynamic> map) {
    return QRSeatData(
      clubId: map['clubId'] ?? '',
      tableId: map['tableId'] ?? '',
      seatNumber: map['seatNumber'] ?? 0,
      version: map['version'] ?? currentVersion,
      checksum: map['checksum'],
    );
  }

  @override
  String toString() {
    return 'QRSeatData(club: $clubId, table: $tableId, seat: $seatNumber)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QRSeatData &&
        other.clubId == clubId &&
        other.tableId == tableId &&
        other.seatNumber == seatNumber;
  }

  @override
  int get hashCode => Object.hash(clubId, tableId, seatNumber);
}
