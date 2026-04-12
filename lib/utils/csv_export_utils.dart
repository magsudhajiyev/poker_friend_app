import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/number_formatter.dart';
import '../models/game_types.dart';

class CsvExportUtils {
  /// Generates a CSV file from hand data and returns the file path
  static Future<String> generateHandCsv(Map<String, dynamic> hand) async {
    // Extract hand data
    final handNumber = hand['handNumber'] ?? 1;
    final actions = List<Map<String, dynamic>>.from(hand['actions'] ?? []);
    final gameTypeStr = hand['gameType'] ?? 'cash';
    final gameType = GameTypeExtension.fromString(gameTypeStr);
    final playerNamesData = hand['playerNames'] as Map<String, dynamic>?;
    final boardCardsData = hand['boardCards'] as Map<String, dynamic>?;

    // Build CSV data
    List<List<String>> csvData = [];

    // CSV Headers
    csvData.add([
      'Hand#',
      'Street',
      'Seat',
      'Player',
      'Action',
      'Amount',
      'Stack',
      'Pot',
      'Board'
    ]);

    // Track pot amounts by street for context
    final potAmounts = {
      'preflop': hand['preflopPot'],
      'flop': hand['flopPot'],
      'turn': hand['turnPot'],
      'river': hand['riverPot']
    };

    // Process board cards by street
    Map<String, String> boardByStreet = {};
    if (boardCardsData != null) {
      // Flop
      final flop = List<String>.from(boardCardsData['flop'] ?? []);
      if (flop.isNotEmpty) {
        boardByStreet['flop'] = flop.join(' ');
      }

      // Turn (flop + turn)
      final turn = boardCardsData['turn'] as String?;
      if (turn != null && turn.isNotEmpty) {
        final turnBoard = [...flop];
        turnBoard.add(turn);
        boardByStreet['turn'] = turnBoard.join(' ');
      }

      // River (flop + turn + river)
      final river = boardCardsData['river'] as String?;
      if (river != null && river.isNotEmpty) {
        final riverBoard = [...flop];
        if (turn != null && turn.isNotEmpty) riverBoard.add(turn);
        riverBoard.add(river);
        boardByStreet['river'] = riverBoard.join(' ');
      }
    }

    // Process each action
    for (final action in actions) {
      final street = action['street'] as String? ?? 'preflop';
      final playerSeat = action['player'] as int? ?? action['playerSeat'] as int? ?? 1;
      final actionType = action['action'] as String? ?? 'Unknown';
      final amount = action['amount'];
      final stack = action['playerStack'] ?? action['stack'];

      // Get player name
      String playerName = 'Player $playerSeat';
      if (playerNamesData != null) {
        playerName = playerNamesData[playerSeat.toString()] ??
                    action['playerName'] as String? ??
                    playerName;
      }

      // Format amount
      String amountFormatted = '-';
      if (amount != null) {
        final amountNum = (amount is num) ? amount.toDouble() : 0.0;
        if (amountNum > 0) {
          if (gameType == GameType.cash) {
            amountFormatted = formatCompactCurrency(amountNum);
          } else {
            amountFormatted = formatCompactNumber(amountNum);
          }
        }
      }

      // Format stack
      String stackFormatted = '-';
      if (stack != null) {
        final stackNum = (stack is num) ? stack.toDouble() : 0.0;
        if (stackNum > 0) {
          if (gameType == GameType.cash) {
            stackFormatted = formatCompactCurrency(stackNum);
          } else {
            stackFormatted = formatCompactNumber(stackNum);
          }
        }
      }

      // Format pot for this street
      String potFormatted = '-';
      final streetPot = potAmounts[street];
      if (streetPot != null) {
        final potNum = (streetPot is num) ? streetPot.toDouble() : 0.0;
        if (potNum > 0) {
          if (gameType == GameType.cash) {
            potFormatted = formatCompactCurrency(potNum);
          } else {
            potFormatted = formatCompactNumber(potNum);
          }
        }
      }

      // Get board cards for this street
      final boardFormatted = boardByStreet[street] ?? '';

      // Add row to CSV
      csvData.add([
        handNumber.toString(),
        street.toUpperCase(),
        playerSeat.toString(),
        playerName,
        actionType.toUpperCase(),
        amountFormatted,
        stackFormatted,
        potFormatted,
        boardFormatted
      ]);
    }

    // Generate CSV content
    String csvString = const ListToCsvConverter().convert(csvData);

    // Save to temporary file
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'poker_hand_${handNumber}_$timestamp.csv';
    final filePath = '${directory.path}/$fileName';

    final file = File(filePath);
    await file.writeAsString(csvString);

    return filePath;
  }

  /// Share the CSV file using the share_plus package
  static Future<void> shareHandCsv(String filePath, int handNumber) async {
    final file = File(filePath);
    if (await file.exists()) {
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Poker Hand #$handNumber Export',
        text: 'Poker hand data exported from Poker Friend',
      );
    }
  }

  /// Generate and share CSV in one call - convenience method
  static Future<void> exportAndShareHand(Map<String, dynamic> hand) async {
    final handNumber = hand['handNumber'] ?? 1;
    try {
      final filePath = await generateHandCsv(hand);
      await shareHandCsv(filePath, handNumber);

      // Clean up temporary file after a delay
      Future.delayed(const Duration(minutes: 5), () async {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      });
    } catch (e) {
      throw Exception('Failed to export hand: $e');
    }
  }
}