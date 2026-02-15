import '../models/qr_seat_data.dart';

/// Service for QR code generation and parsing
class QRService {
  /// Generate QR data for a seat
  static QRSeatData generateQRData({
    required String clubId,
    required String tableId,
    required int seatNumber,
  }) {
    return QRSeatData(
      clubId: clubId,
      tableId: tableId,
      seatNumber: seatNumber,
    );
  }

  /// Generate QR URL string for a seat
  static String generateQRUrl({
    required String clubId,
    required String tableId,
    required int seatNumber,
  }) {
    final data = generateQRData(
      clubId: clubId,
      tableId: tableId,
      seatNumber: seatNumber,
    );
    return data.encode();
  }

  /// Parse a QR URL string
  /// Returns null if the URL is invalid
  static QRSeatData? parseQRUrl(String url) {
    return QRSeatData.decode(url);
  }

  /// Validate a QR data object
  /// Checks checksum and basic validity
  static bool validateQRData(QRSeatData data) {
    // Validate checksum
    if (!data.validateChecksum()) {
      return false;
    }

    // Validate seat number (1-9)
    if (data.seatNumber < 1 || data.seatNumber > 9) {
      return false;
    }

    // Validate IDs are not empty
    if (data.clubId.isEmpty || data.tableId.isEmpty) {
      return false;
    }

    return true;
  }

  /// Parse and validate a QR URL in one step
  /// Returns null if invalid
  static QRSeatData? parseAndValidate(String url) {
    final data = parseQRUrl(url);
    if (data == null) return null;
    if (!validateQRData(data)) return null;
    return data;
  }

  /// Extract club ID from a QR URL (without full parsing)
  static String? extractClubId(String url) {
    final data = parseQRUrl(url);
    return data?.clubId;
  }

  /// Extract table ID from a QR URL (without full parsing)
  static String? extractTableId(String url) {
    final data = parseQRUrl(url);
    return data?.tableId;
  }

  /// Extract seat number from a QR URL (without full parsing)
  static int? extractSeatNumber(String url) {
    final data = parseQRUrl(url);
    return data?.seatNumber;
  }
}
