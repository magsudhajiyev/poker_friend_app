import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:poker_logger/models/game_types.dart';
import 'package:poker_logger/models/hand_completeness.dart';

/// Service for exporting poker hand and session data to CSV format
class CSVExportService {
  static const String _csvHeader = 'Hand#,Street,Seat,Player,Action,Amount,Pot,Board,HoleCards';

  /// Export a single hand to CSV format
  String exportHandToCsv(Map<String, dynamic> handData) {
    final csv = StringBuffer();

    // Add CSV header
    csv.writeln(_csvHeader);

    // Ticks, stubs and reconstructed hands are never exported.
    if (!HandCompletenessX.fromHandMap(handData).isAnalyzable) {
      return csv.toString();
    }

    // Add hand metadata as comment if needed
    if (handData['isChoppedPot'] == true) {
      csv.writeln('# CHOPPED POT - Hand ${handData['handNumber'] ?? 'N/A'}');
      final winnersRaw = handData['choppedWinners'];
      final winners = winnersRaw is List ? winnersRaw : null;
      final namesRaw = handData['playerNames'];
      final Map playerNames = namesRaw is Map ? namesRaw : const {};

      if (winners != null && winners.isNotEmpty) {
        final winnerNames = winners
            .map((seat) => playerNames[seat.toString()] ?? 'Seat $seat')
            .join(',');
        csv.writeln('# Winners: $winnerNames');
      }

      final shareRaw = handData['sharePerWinner'];
      final sharePerWinner = shareRaw is num ? shareRaw.toDouble() : null;
      if (sharePerWinner != null) {
        csv.writeln('# Share per winner: \$${sharePerWinner.toStringAsFixed(2)}');
      }
    }

    // Process actions. All reads are type-guarded: an export must never
    // throw on corrupt data (D9) — malformed values degrade gracefully.
    final actionsRaw = handData['actions'];
    final actions = actionsRaw is List ? actionsRaw : const [];
    final playerNamesRaw = handData['playerNames'];
    final Map playerNames = playerNamesRaw is Map ? playerNamesRaw : const {};
    final heroSeat =
        handData['heroSeatNumber'] is int ? handData['heroSeatNumber'] as int : null;
    final holeRaw = handData['ourHoleCards'];
    final Map? ourHoleCards = holeRaw is Map ? holeRaw : null;
    final boardRaw = handData['boardCards'];
    final Map boardCards = boardRaw is Map ? boardRaw : const {};

    double runningPot = 0.0;

    for (final actionData in actions) {
      if (actionData is! Map) continue;

      final action = actionData;
      final handNumber = handData['handNumber'] ?? '';
      final street = action['street'] ?? '';
      final seat = action['player'] ?? '';
      final playerName = _sanitizeCsvField((action['playerName'] ??
              playerNames[seat.toString()] ??
              'Seat $seat')
          .toString());
      final actionType = action['action'] ?? '';
      // Junk amounts (strings, negatives, NaN, Infinity) degrade to 0.
      final rawAmount = action['amount'];
      double amount = rawAmount is num ? rawAmount.toDouble() : 0.0;
      if (!amount.isFinite || amount < 0) amount = 0.0;

      // Update running pot
      if (actionType == 'small-blind' || actionType == 'big-blind' ||
          actionType == 'bet' || actionType == 'raise' ||
          actionType == 'call' || actionType == 'all-in') {
        runningPot += amount;
      }

      // Format board cards for this street
      final boardForStreet = _formatBoardForStreet(boardCards, street);

      // Format hole cards (only show for hero)
      String holeCardsStr = '';
      if (heroSeat != null && seat == heroSeat && ourHoleCards != null) {
        final c1Raw = ourHoleCards['card1'];
        final c2Raw = ourHoleCards['card2'];
        final card1 = c1Raw is String ? c1Raw : '';
        final card2 = c2Raw is String ? c2Raw : '';
        if (card1.isNotEmpty && card2.isNotEmpty) {
          holeCardsStr = '$card1$card2';
        }
      }

      // Add action row
      csv.writeln('$handNumber,$street,$seat,$playerName,$actionType,$amount,$runningPot,$boardForStreet,$holeCardsStr');
    }

    return csv.toString();
  }

  /// Export multiple hands from a session to CSV format
  String exportSessionToCsv(Map<String, dynamic> sessionData, List<Map<String, dynamic>> hands) {
    final csv = StringBuffer();

    // Add session metadata header
    final sessionName = sessionData['sessionName'] ?? 'Poker Session';
    final gameType = sessionData['gameType'];
    final gameTypeName = gameType is GameType ? gameType.displayName :
                        (gameType?.toString().contains('cash') == true ? 'Cash Game' :
                         gameType?.toString().contains('tournament') == true ? 'Tournament' : 'Unknown');

    csv.writeln('# Session: $sessionName');
    csv.writeln('# Game Type: $gameTypeName');

    final smallBlind = sessionData['smallBlind'];
    final bigBlind = sessionData['bigBlind'];
    if (smallBlind != null && bigBlind != null) {
      csv.writeln('# Blinds: \$$smallBlind/\$$bigBlind');
    }

    final startTime = sessionData['startTime']?.toString();
    final endTime = sessionData['endTime']?.toString();
    if (startTime != null) {
      csv.writeln('# Start: $startTime');
    }
    if (endTime != null) {
      csv.writeln('# End: $endTime');
    }

    final totalHands = sessionData['totalHands'] ?? hands.length;
    csv.writeln('# Total: $totalHands hands');
    csv.writeln('#');

    // Add CSV header
    csv.writeln(_csvHeader);

    // Export each hand
    for (final handData in hands) {
      if (!HandCompletenessX.fromHandMap(handData).isAnalyzable) continue;
      final handCsv = exportHandToCsv(handData);
      final handLines = handCsv.split('\n');

      // Skip the header line from individual hand export
      for (int i = 1; i < handLines.length; i++) {
        final line = handLines[i].trim();
        if (line.isNotEmpty && !line.startsWith('#')) {
          csv.writeln(line);
        } else if (line.startsWith('#')) {
          // Include hand-specific metadata
          csv.writeln(line);
        }
      }
    }

    return csv.toString();
  }

  /// CSV field sanitizer: newlines/tabs become spaces; fields containing
  /// commas or quotes are quoted (RFC 4180) so player names can never
  /// corrupt the row structure.
  String _sanitizeCsvField(String value) {
    var v = value.replaceAll(RegExp(r'[\n\r\t]+'), ' ');
    if (v.contains(',') || v.contains('"')) {
      v = '"' + v.replaceAll('"', '""') + '"';
    }
    return v;
  }

  /// Format board cards for a specific street
  String _formatBoardForStreet(Map boardCards, String street) {
    // Malformed board data (wrong types) degrades to an empty board column
    final flopRaw = boardCards['flop'];
    final flop = flopRaw is List ? flopRaw : null;
    final turnRaw = boardCards['turn'];
    final turn = turnRaw is String ? turnRaw : null;
    final riverRaw = boardCards['river'];
    final river = riverRaw is String ? riverRaw : null;

    switch (street.toLowerCase()) {
      case 'preflop':
        return '';
      case 'flop':
        if (flop != null && flop.isNotEmpty) {
          return flop.join('');
        }
        return '';
      case 'turn':
        final flopStr = flop?.join('') ?? '';
        final turnStr = turn ?? '';
        return '$flopStr$turnStr';
      case 'river':
        final flopStr = flop?.join('') ?? '';
        final turnStr = turn ?? '';
        final riverStr = river ?? '';
        return '$flopStr$turnStr$riverStr';
      default:
        return '';
    }
  }

  /// Generate filename for CSV export
  String generateFilename(Map<String, dynamic> sessionData) {
    final sessionName = sessionData['sessionName']?.toString() ?? 'PokerSession';
    final date = DateTime.now().toIso8601String().split('T')[0];
    final cleanName = sessionName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    return '${cleanName}_$date.csv';
  }

  /// Convert CSV string to bytes for sharing
  List<int> csvToBytes(String csvContent) {
    return utf8.encode(csvContent);
  }
}