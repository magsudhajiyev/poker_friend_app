import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:poker_logger/models/game_types.dart';

/// Service for exporting poker hand and session data to CSV format
class CSVExportService {
  static const String _csvHeader = 'Hand#,Street,Seat,Player,Action,Amount,Pot,Board,HoleCards';

  /// Export a single hand to CSV format
  String exportHandToCsv(Map<String, dynamic> handData) {
    final csv = StringBuffer();

    // Add CSV header
    csv.writeln(_csvHeader);

    // Add hand metadata as comment if needed
    if (handData['isChoppedPot'] == true) {
      csv.writeln('# CHOPPED POT - Hand ${handData['handNumber'] ?? 'N/A'}');
      final winners = handData['choppedWinners'] as List<dynamic>?;
      final playerNames = handData['playerNames'] as Map<String, dynamic>? ?? {};

      if (winners != null && winners.isNotEmpty) {
        final winnerNames = winners
            .map((seat) => playerNames[seat.toString()] ?? 'Seat $seat')
            .join(',');
        csv.writeln('# Winners: $winnerNames');
      }

      final sharePerWinner = handData['sharePerWinner'] as double?;
      if (sharePerWinner != null) {
        csv.writeln('# Share per winner: \$${sharePerWinner.toStringAsFixed(2)}');
      }
    }

    // Process actions
    final actions = handData['actions'] as List<dynamic>? ?? [];
    final playerNames = handData['playerNames'] as Map<String, dynamic>? ?? {};
    final heroSeat = handData['heroSeatNumber'] as int?;
    final ourHoleCards = handData['ourHoleCards'] as Map<String, dynamic>?;
    final boardCards = handData['boardCards'] as Map<String, dynamic>? ?? {};

    double runningPot = 0.0;

    for (final actionData in actions) {
      if (actionData == null) continue;

      final action = actionData as Map<String, dynamic>;
      final handNumber = handData['handNumber'] ?? '';
      final street = action['street'] ?? '';
      final seat = action['player'] ?? '';
      final playerName = action['playerName'] ??
                        playerNames[seat.toString()] ??
                        'Seat $seat';
      final actionType = action['action'] ?? '';
      final amount = (action['amount'] as num?)?.toDouble() ?? 0.0;

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
        final card1 = ourHoleCards['card1']?.toString() ?? '';
        final card2 = ourHoleCards['card2']?.toString() ?? '';
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

  /// Format board cards for a specific street
  String _formatBoardForStreet(Map<String, dynamic> boardCards, String street) {
    final flop = boardCards['flop'] as List<dynamic>?;
    final turn = boardCards['turn']?.toString();
    final river = boardCards['river']?.toString();

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