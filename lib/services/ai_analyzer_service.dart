import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

class AIAnalyzerService {
  static const String baseUrl = 'http://localhost:8080/api/v1';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Analyze a poker hand using the backend AI service
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
      print('🎲 ===== AI ANALYZER REQUEST =====');
      print('🎲 Endpoint: $baseUrl/analyze-hand');
      print('🎲 Request Body:');
      print(jsonEncode(requestBody));
      print('🎲 ================================');

      final response = await http.post(
        Uri.parse('$baseUrl/analyze-hand'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(Duration(seconds: 30));

      // DEBUG: Log the response
      print('🎲 ===== AI ANALYZER RESPONSE =====');
      print('🎲 Status Code: ${response.statusCode}');
      if (response.statusCode == 200) {
        print('🎲 Response Body:');
        print(response.body);
        print('🎲 ==================================');
        final analysis = jsonDecode(response.body) as Map<String, dynamic>;
        return analysis;
      } else {
        print('🎲 Error Response: ${response.body}');
        print('🎲 ==================================');
        throw Exception('Failed to analyze hand: ${response.statusCode}');
      }
    } catch (e) {
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

  /// Convert hand data to the format expected by the backend
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

    // Determine the street (get the latest street from actions)
    String street = 'preflop';
    final actions = hand['actions'] as List<dynamic>? ?? [];
    if (actions.isNotEmpty) {
      final lastAction = actions.last as Map<String, dynamic>;
      street = lastAction['street'] as String? ?? 'preflop';
    }

    // Build actions list
    List<Map<String, dynamic>> formattedActions = [];
    for (final action in actions) {
      final actionMap = action as Map<String, dynamic>;
      formattedActions.add({
        'seat': actionMap['player'] ?? actionMap['playerSeat'],
        'action': _convertActionFormat(actionMap['action'] as String? ?? ''),
        if (actionMap['amount'] != null) 'amount': actionMap['amount'],
        if (actionMap['playerPosition'] != null) 'position': actionMap['playerPosition'],  // Include pre-calculated position
      });
    }

    // Build opponents list
    List<Map<String, dynamic>> opponents = [];
    final playerNames = hand['playerNames'] as Map<String, dynamic>? ?? {};
    final playerCount = hand['playerCount'] as int? ?? 6;
    final heroPosition = hand['heroPosition'] as int? ?? 1;

    // CRITICAL: Always get stack from the START OF THE HAND (preflop), not current street
    // The AI analyzer needs to know the initial stack to properly analyze the hand
    Map<int, double> playerStacks = {};
    Map<int, bool> stackFound = {}; // Track if we've found the initial stack for each player

    // First, try to use initialStacks if available (most reliable)
    final initialStacks = hand['initialStacks'] as Map<String, dynamic>?;
    if (initialStacks != null) {
      initialStacks.forEach((key, value) {
        final seat = int.tryParse(key);
        if (seat != null && value != null) {
          playerStacks[seat] = (value as num).toDouble();
          stackFound[seat] = true;
        }
      });
    }

    // If initialStacks not available, get stacks from the FIRST action of each player (preflop)
    if (playerStacks.isEmpty) {
      for (final action in actions) {
        final actionMap = action as Map<String, dynamic>;
        final seat = actionMap['player'] ?? actionMap['playerSeat'];
        final stack = actionMap['playerStack'] ?? actionMap['stack'];

        // Only get the first occurrence of each player's stack (initial stack)
        if (seat != null && stack != null && !(stackFound[seat as int] ?? false)) {
          playerStacks[seat] = (stack as num).toDouble();
          stackFound[seat] = true;
        }
      }
    }

    // For each seat except hero
    for (int seat = 1; seat <= playerCount; seat++) {
      if (seat == heroPosition) continue;

      final playerName = playerNames[seat.toString()] ?? 'Player $seat';
      final stackSize = playerStacks[seat] ?? 200.0; // Default to 200 if not found

      opponents.add({
        'seat': seat,
        'name': playerName,
        'stack': stackSize,
        'stats': {
          'vpip': 25.0, // Default stats
          'pfr': 18.0,
          'three_bet': 7.0,
          'aggression': 1.5,
          'playing_style': 'TAG',
        },
      });
    }

    // Get hero stack (initial stack at start of hand)
    final heroStack = playerStacks[heroPosition] ?? 200.0;

    // DEBUG: Log hero stack calculation
    print('🎲 DEBUG: Initial Stack Calculation (Start of Hand)');
    print('🎲   Current Street Being Analyzed: $street');
    print('🎲   Hero Position: $heroPosition');
    print('🎲   Hero INITIAL Stack: $heroStack');
    print('🎲   All Player INITIAL Stacks: $playerStacks');

    // Get hero's position name from the first action of hero (most reliable)
    String? heroPositionName;
    for (final action in actions) {
      final actionMap = action as Map<String, dynamic>;
      final seat = actionMap['player'] ?? actionMap['playerSeat'];
      if (seat == heroPosition) {
        heroPositionName = actionMap['playerPosition'] as String?;
        if (heroPositionName != null) break;
      }
    }

    // Extract and convert board cards
    List<String> boardCards = [];
    final boardCardsData = hand['boardCards'] as Map<String, dynamic>?;
    if (boardCardsData != null) {
      // Add flop cards
      final flop = boardCardsData['flop'] as List<dynamic>?;
      if (flop != null) {
        for (final card in flop) {
          if (card != null && card is String) {
            boardCards.add(_convertCardFormat(card));
          }
        }
      }

      // Add turn card
      final turn = boardCardsData['turn'] as String?;
      if (turn != null && turn.isNotEmpty) {
        boardCards.add(_convertCardFormat(turn));
      }

      // Add river card
      final river = boardCardsData['river'] as String?;
      if (river != null && river.isNotEmpty) {
        boardCards.add(_convertCardFormat(river));
      }
    }

    final result = {
      'handId': hand['id'] ?? hand['handNumber']?.toString() ?? 'unknown',
      'street': street,
      'heroSeat': heroPosition,
      'heroPosition': heroPositionName,  // Send hero's position name directly
      'heroCards': heroCards,
      'heroStack': heroStack,
      'buttonPosition': hand['buttonPosition'] ?? 1,
      'playerCount': playerCount,  // CRITICAL: Backend needs this to calculate position correctly
      'blinds': {
        'sb': hand['smallBlind'] ?? 1,
        'bb': hand['bigBlind'] ?? 2,
      },
      'pot': (hand['potAmount'] ?? hand['pot'] ?? 0).toDouble(),
      if (boardCards.isNotEmpty) 'board': boardCards,  // Only include if there are board cards
      'actions': formattedActions,
      'opponents': opponents,
    };

    return result;
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
