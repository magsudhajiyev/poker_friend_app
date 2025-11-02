import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'logger_service.dart';

class AIAnalyzerService {
  static const String baseUrl = 'http://localhost:8080/api/v1';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Analyze a poker hand using the backend AI service
  /// IMPORTANT: Only sends PREFLOP data for GTO analysis
  static Future<Map<String, dynamic>> analyzeHand({
    required String handId,
    required Map<String, dynamic> handData,
  }) async {
    try {
      final requestBody = {
        'handId': handId,
        'handData': handData,
      };

      // DEBUG: Log the request body being sent to poker engine
      await LoggerService.info('🎲 ===== AI ANALYZER REQUEST (PREFLOP ONLY) =====');
      await LoggerService.info('🎲 Endpoint: $baseUrl/analyze-hand');
      await LoggerService.info('🎲 Request Body:');

      // Pretty-print JSON for readability
      const encoder = JsonEncoder.withIndent('  ');
      final prettyJson = encoder.convert(requestBody);

      // Split into lines and log each one (to avoid truncation)
      for (final line in prettyJson.split('\n')) {
        await LoggerService.debug('  $line');
      }

      await LoggerService.info('🎲 ================================');

      final response = await http.post(
        Uri.parse('$baseUrl/analyze-hand'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(Duration(seconds: 30));

      // DEBUG: Log the response
      await LoggerService.info('🎲 ===== AI ANALYZER RESPONSE =====');
      await LoggerService.info('🎲 Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        await LoggerService.info('🎲 Response Body:');

        // Pretty-print response JSON
        const encoder = JsonEncoder.withIndent('  ');
        final responseJson = jsonDecode(response.body);
        final prettyResponse = encoder.convert(responseJson);

        // Split into lines and log each one
        for (final line in prettyResponse.split('\n')) {
          await LoggerService.debug('  $line');
        }

        await LoggerService.info('🎲 ==================================');
        return responseJson as Map<String, dynamic>;
      } else {
        await LoggerService.error('🎲 Error Response: ${response.body}');
        await LoggerService.info('🎲 ==================================');
        throw Exception('Failed to analyze hand: ${response.statusCode}');
      }
    } catch (e) {
      await LoggerService.error('🎲 AI Analyzer Exception: $e');
      throw Exception('Failed to analyze hand: $e');
    }
  }

  /// Save AI analysis to Firebase
  static Future<void> saveAnalysis({
    required String sessionId,
    required String handId,
    required Map<String, dynamic> analysis,
  }) async {
    try {
      final userId = AuthService.userId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _firestore
          .collection('poker_sessions')
          .doc(sessionId)
          .collection('poker_hands')
          .doc(handId)
          .update({
        'aiAnalysis': {
          'analysisId': analysis['analysisId'],
          'correct': analysis['correct'],
          'severity': analysis['severity'],
          'gtoAnalysis': analysis['gtoAnalysis'],
          'aiAnalysis': analysis['aiAnalysis'],
          'processingTimeMs': analysis['processingTimeMs'],
          'analyzedAt': FieldValue.serverTimestamp(),
        },
      });
    } catch (e) {
      throw Exception('Failed to save analysis: $e');
    }
  }

  /// Get saved AI analysis from Firebase
  static Future<Map<String, dynamic>?> getAnalysis({
    required String sessionId,
    required String handId,
  }) async {
    try {
      final doc = await _firestore
          .collection('poker_sessions')
          .doc(sessionId)
          .collection('poker_hands')
          .doc(handId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey('aiAnalysis')) {
          return data['aiAnalysis'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Convert hand data to the PREFLOP-ONLY format expected by the backend
  ///
  /// New Request Structure:
  /// {
  ///   "handId": "hand_123",
  ///   "gameType": "tournament",  // or "cash"
  ///   "hero": {
  ///     "seat": 7,
  ///     "position": "BB",
  ///     "cards": ["Kc", "4s"],
  ///     "stackBB": 248.75
  ///   },
  ///   "activePlayers": [
  ///     {"seat": 8, "position": "UTG", "stackBB": 247.6},
  ///     {"seat": 9, "position": "CO", "stackBB": 248.5},
  ///     ...
  ///   ],
  ///   "preflopActions": [
  ///     {"seat": 8, "position": "UTG", "action": "fold"},
  ///     {"seat": 9, "position": "CO", "action": "fold"},
  ///     ...
  ///   ]
  /// }
  static Map<String, dynamic> prepareHandDataForAnalysis(
    Map<String, dynamic> hand,
  ) {
    // Extract hero cards
    final ourHoleCards = hand['ourHoleCards'] as Map<String, dynamic>?;
    List<String> heroCards = [];
    if (ourHoleCards != null) {
      final card1 = ourHoleCards['card1'] as String?;
      final card2 = ourHoleCards['card2'] as String?;
      if (card1 != null) heroCards.add(_convertCardFormat(card1));
      if (card2 != null) heroCards.add(_convertCardFormat(card2));
    }

    // Get blinds
    final smallBlind = (hand['smallBlind'] ?? 1) as int;
    final bigBlind = (hand['bigBlind'] ?? 2) as int;

    // Get hero seat number and position
    final heroSeatNumber = hand['heroSeatNumber'] as int?;
    final heroPosition = hand['heroPositionName'] as String? ?? 'UNK';

    // Get button position and player count for position calculation
    final buttonPosition = hand['buttonPosition'] ?? 1;
    final playerCount = hand['playerCount'] as int? ?? 6;

    // Get all actions
    final actions = hand['actions'] as List<dynamic>? ?? [];

    // CRITICAL: Get initial stacks (at start of hand, preflop)
    Map<int, double> playerStacks = {};
    final initialStacks = hand['initialStacks'] as Map<String, dynamic>?;
    if (initialStacks != null) {
      initialStacks.forEach((key, value) {
        final seat = int.tryParse(key);
        if (seat != null && value != null) {
          playerStacks[seat] = (value as num).toDouble();
        }
      });
    } else {
      // Fallback: get stacks from first action of each player
      Map<int, bool> stackFound = {};
      for (final action in actions) {
        final actionMap = action as Map<String, dynamic>;
        final seat = actionMap['player'] ?? actionMap['playerSeat'];
        final stack = actionMap['playerStack'] ?? actionMap['stack'];

        if (seat != null && stack != null && !(stackFound[seat as int] ?? false)) {
          playerStacks[seat] = (stack as num).toDouble();
          stackFound[seat] = true;
        }
      }
    }

    // Get hero stack
    final heroStack = heroSeatNumber != null
        ? playerStacks[heroSeatNumber] ?? 200.0
        : 200.0;

    // Calculate hero stack in BB
    final heroStackBB = heroStack / bigBlind;

    // Get active player names and positions
    final playerNames = hand['playerNames'] as Map<String, dynamic>? ?? {};

    // Build activePlayers list with positions and stacks in BB
    List<Map<String, dynamic>> activePlayers = [];

    // Get list of active seats from actions or playerNames
    Set<int> activeSeats = {};
    for (final action in actions) {
      final actionMap = action as Map<String, dynamic>;
      final seat = actionMap['player'] ?? actionMap['playerSeat'];
      if (seat != null) {
        activeSeats.add(seat as int);
      }
    }

    // If no actions yet, use playerNames
    if (activeSeats.isEmpty) {
      playerNames.forEach((key, value) {
        final seat = int.tryParse(key);
        if (seat != null && value != null && value.toString().isNotEmpty) {
          activeSeats.add(seat);
        }
      });
    }

    // Build active players list with positions
    for (final seat in activeSeats) {
      // Get position for this seat - use stored position from action if available
      String? position;
      for (final action in actions) {
        final actionMap = action as Map<String, dynamic>;
        final actionSeat = actionMap['player'] ?? actionMap['playerSeat'];
        if (actionSeat == seat) {
          position = actionMap['playerPosition'] as String?;
          if (position != null) break;
        }
      }

      // If position not found in actions, calculate it
      if (position == null) {
        position = _calculatePosition(seat, buttonPosition, activeSeats.toList());
      }

      final stackSize = playerStacks[seat] ?? 200.0;
      final stackBB = stackSize / bigBlind;

      activePlayers.add({
        'seat': seat,
        'position': position,
        'stackBB': double.parse(stackBB.toStringAsFixed(2)),
      });
    }

    // Sort active players by seat number for consistency
    activePlayers.sort((a, b) => (a['seat'] as int).compareTo(b['seat'] as int));

    // Build PREFLOP actions only
    List<Map<String, dynamic>> preflopActions = [];
    for (final action in actions) {
      final actionMap = action as Map<String, dynamic>;
      final street = actionMap['street'] as String? ?? 'preflop';

      // ONLY include preflop actions
      if (street != 'preflop') continue;

      final seat = actionMap['player'] ?? actionMap['playerSeat'];
      final position = actionMap['playerPosition'];
      final actionType = _convertActionFormat(actionMap['action'] as String? ?? '');

      // Skip post_sb and post_bb actions (they're automatic)
      if (actionType == 'post_sb' || actionType == 'post_bb') continue;

      final actionData = {
        'seat': seat,
        'position': position,
        'action': actionType,
      };

      // Add amount for raises (in BB)
      if (actionType == 'raise' && actionMap['amount'] != null) {
        final amountChips = (actionMap['amount'] as num).toDouble();
        final amountBB = amountChips / bigBlind;
        actionData['sizeBB'] = double.parse(amountBB.toStringAsFixed(2));
      }

      preflopActions.add(actionData);
    }

    // Determine game type
    final isCashGame = hand['isCashGame'] as bool? ?? true;
    final gameType = isCashGame ? 'cash' : 'tournament';

    // Build the simplified request body
    final result = {
      'handId': hand['id'] ?? hand['handNumber']?.toString() ?? 'unknown',
      'gameType': gameType,
      'hero': {
        'seat': heroSeatNumber,
        'position': heroPosition,
        'cards': heroCards,
        'stackBB': double.parse(heroStackBB.toStringAsFixed(2)),
      },
      'activePlayers': activePlayers,
      'preflopActions': preflopActions,
    };

    return result;
  }

  /// Calculate position for a seat based on button and active seats
  static String _calculatePosition(int seat, int buttonPosition, List<int> activeSeats) {
    final sortedSeats = List<int>.from(activeSeats)..sort();
    final playerCount = sortedSeats.length;

    // Find button index in sorted seats
    int buttonIndex = sortedSeats.indexOf(buttonPosition);
    if (buttonIndex == -1) {
      buttonIndex = 0;
    }

    // Find seat index
    int seatIndex = sortedSeats.indexOf(seat);
    if (seatIndex == -1) {
      return 'UNK';
    }

    // Calculate relative position
    int relativePosition = (seatIndex - buttonIndex + playerCount) % playerCount;

    // Map to position names based on player count
    switch (playerCount) {
      case 2:
        return relativePosition == 0 ? 'BTN' : 'BB';
      case 3:
        return ['BTN', 'SB', 'BB'][relativePosition];
      case 4:
        return ['BTN', 'SB', 'BB', 'UTG'][relativePosition];
      case 5:
        return ['BTN', 'SB', 'BB', 'UTG', 'CO'][relativePosition];
      case 6:
        return ['BTN', 'SB', 'BB', 'UTG', 'HJ', 'CO'][relativePosition];
      case 7:
        return ['BTN', 'SB', 'BB', 'UTG', 'UTG+1', 'HJ', 'CO'][relativePosition];
      case 8:
        return ['BTN', 'SB', 'BB', 'UTG', 'UTG+1', 'UTG+2', 'HJ', 'CO'][relativePosition];
      case 9:
        return ['BTN', 'SB', 'BB', 'UTG', 'UTG+1', 'UTG+2', 'LJ', 'HJ', 'CO'][relativePosition];
      default:
        return 'P${relativePosition + 1}';
    }
  }

  /// Convert card format from UI format (e.g., "A♥") to backend format (e.g., "Ah")
  static String _convertCardFormat(String card) {
    if (card.length < 2) return card;

    final rank = card[0];
    final suit = card[1];

    // Convert suit symbol to letter
    String suitLetter;
    switch (suit) {
      case '♥':
        suitLetter = 'h';
        break;
      case '♦':
        suitLetter = 'd';
        break;
      case '♣':
        suitLetter = 'c';
        break;
      case '♠':
        suitLetter = 's';
        break;
      default:
        suitLetter = suit.toLowerCase();
    }

    return '$rank$suitLetter';
  }

  /// Convert action format from UI format to backend format
  static String _convertActionFormat(String action) {
    switch (action.toLowerCase()) {
      case 'raise':
        return 'raise';
      case 'call':
        return 'call';
      case 'fold':
        return 'fold';
      case 'check':
        return 'check';
      case 'bet':
        return 'bet';
      case 'all in':
      case 'allin':
        return 'raise'; // Backend treats all-in as raise
      case 'post_sb':
      case 'post_bb':
        return action.toLowerCase();
      default:
        return action.toLowerCase();
    }
  }
}
