import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Data encoded in a QR code for a poker table (for dealers)
///
/// URL Format: pkr://club_{clubId}/table_{tableId}?v=1&c={checksum}
class QRTableData {
  static const String urlScheme = 'pkr://';
  static const int currentVersion = 1;

  final String clubId;
  final String tableId;
  final int version;
  final String checksum;

  QRTableData({
    required this.clubId,
    required this.tableId,
    this.version = currentVersion,
    String? checksum,
  }) : checksum = checksum ?? _generateChecksum(clubId, tableId, currentVersion);

  /// Generate a checksum for the QR data
  static String _generateChecksum(String clubId, String tableId, int version) {
    final data = '$clubId:$tableId:table:$version';
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 8);
  }

  /// Encode to URL string for QR code
  String encode() {
    return '${urlScheme}club_$clubId/table_$tableId?v=$version&c=$checksum';
  }

  /// Decode from URL string
  /// Returns null if the URL is invalid
  static QRTableData? decode(String url) {
    try {
      if (!url.startsWith(urlScheme)) {
        return null;
      }

      final path = url.substring(urlScheme.length);
      final parts = path.split('?');
      if (parts.isEmpty) return null;

      final pathParts = parts[0].split('/');

      // Expected: club_{clubId}/table_{tableId} (no seat)
      // Must have exactly 2 path parts for table QR
      if (pathParts.length != 2) return null;

      // Extract clubId
      if (!pathParts[0].startsWith('club_')) return null;
      final clubId = pathParts[0].substring(5);

      // Extract tableId
      if (!pathParts[1].startsWith('table_')) return null;
      final tableId = pathParts[1].substring(6);

      // Parse query parameters
      int version = currentVersion;
      String? checksum;

      if (parts.length > 1) {
        final queryParams = Uri.splitQueryString(parts[1]);
        version = int.tryParse(queryParams['v'] ?? '') ?? currentVersion;
        checksum = queryParams['c'];
      }

      return QRTableData(
        clubId: clubId,
        tableId: tableId,
        version: version,
        checksum: checksum ?? _generateChecksum(clubId, tableId, version),
      );
    } catch (e) {
      return null;
    }
  }

  /// Validate the checksum
  bool validateChecksum() {
    final expectedChecksum = _generateChecksum(clubId, tableId, version);
    return checksum == expectedChecksum;
  }

  /// Convert to map for storage
  Map<String, dynamic> toMap() {
    return {
      'type': 'poker_table',
      'version': version,
      'clubId': clubId,
      'tableId': tableId,
      'checksum': checksum,
    };
  }

  /// Create from map
  factory QRTableData.fromMap(Map<String, dynamic> map) {
    return QRTableData(
      clubId: map['clubId'] ?? '',
      tableId: map['tableId'] ?? '',
      version: map['version'] ?? currentVersion,
      checksum: map['checksum'],
    );
  }

  @override
  String toString() {
    return 'QRTableData(club: $clubId, table: $tableId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QRTableData &&
        other.clubId == clubId &&
        other.tableId == tableId;
  }

  @override
  int get hashCode => Object.hash(clubId, tableId);
}
