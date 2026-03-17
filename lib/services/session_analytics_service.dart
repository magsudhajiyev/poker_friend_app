import 'dart:convert';
import 'package:http/http.dart' as http;
import 'logger_service.dart';
import 'opponent_service.dart';
import 'opponent_stats_service.dart';

/// Service for Premium Session Analytics API
/// Connects to the Python backend for full session analysis
class SessionAnalyticsService {
  static const String baseUrl = 'https://poker-friend-engine.onrender.com/api/v1/analytics';
  static const String _apiKey = 'oCx_2Be-_wkxXGa_cacuG4Dm0--sglzSSddJD46bibI';

  /// Job status enum matching backend JobStatus
  static const String statusPending = 'pending';
  static const String statusProcessing = 'processing';
  static const String statusCompleted = 'completed';
  static const String statusFailed = 'failed';
  static const String statusCancelled = 'cancelled';

  /// Create a new session analysis and queue the job
  /// Returns session_id and job_id on success
  static Future<Map<String, dynamic>> createSession({
    required String userId,
    required String sessionName,
    required String gameType,
    required List<Map<String, dynamic>> hands,
    String? stakes,
    int? tableSize,
    DateTime? startedAt,
    DateTime? endedAt,
  }) async {
    try {
      // Build opponent play styles map from stored opponent data
      final opponentPlayStyles = await _buildOpponentPlayStylesMap(hands);

      // Prepare hands in the format expected by the backend
      final preparedHands = hands.map((hand) {
        // Use AIAnalyzerService's prepareHandDataForAnalysis if needed
        // or send raw hand data depending on backend requirements
        return _prepareHandData(hand, opponentPlayStyles);
      }).toList();

      final requestBody = {
        'session_name': sessionName,
        'game_type': gameType,
        'hands': preparedHands,
        if (stakes != null) 'stakes': stakes,
        if (tableSize != null) 'table_size': tableSize,
        if (startedAt != null) 'started_at': startedAt.toIso8601String(),
        if (endedAt != null) 'ended_at': endedAt.toIso8601String(),
      };

      await LoggerService.info('📊 ===== SESSION ANALYTICS REQUEST =====');
      await LoggerService.info('📊 Endpoint: $baseUrl/sessions');
      await LoggerService.info('📊 User ID: $userId');
      await LoggerService.info('📊 Session: $sessionName');
      await LoggerService.info('📊 Hands: ${hands.length}');

      final response = await http.post(
        Uri.parse('$baseUrl/sessions'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-ID': userId,
          'X-API-Key': _apiKey,
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      await LoggerService.info('📊 Response Status: ${response.statusCode}');

      if (response.statusCode == 201) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        await LoggerService.info('📊 Session created: ${result['id']}');
        await LoggerService.info('📊 Job status: ${result['job_status']}');
        return result;
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please try again later.');
      } else if (response.statusCode == 403) {
        throw Exception('Premium subscription required for session analytics.');
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to create session');
      }
    } catch (e) {
      await LoggerService.error('📊 Session Analytics Error: $e');
      rethrow;
    }
  }

  /// Get job progress for a session analysis
  static Future<Map<String, dynamic>> getJobProgress({
    required String userId,
    required String sessionId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sessions/$sessionId/job'),
        headers: {
          'X-User-ID': userId,
          'X-API-Key': _apiKey,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        throw Exception('Session or job not found');
      } else {
        throw Exception('Failed to get job progress');
      }
    } catch (e) {
      await LoggerService.error('📊 Get Job Progress Error: $e');
      rethrow;
    }
  }

  /// Get full session statistics after analysis completes
  static Future<Map<String, dynamic>> getSessionStatistics({
    required String userId,
    required String sessionId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sessions/$sessionId/statistics'),
        headers: {
          'X-User-ID': userId,
          'X-API-Key': _apiKey,
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        throw Exception('Session not found');
      } else {
        throw Exception('Failed to get session statistics');
      }
    } catch (e) {
      await LoggerService.error('📊 Get Statistics Error: $e');
      rethrow;
    }
  }

  /// Get paginated hand analyses for a session
  static Future<Map<String, dynamic>> getSessionHands({
    required String userId,
    required String sessionId,
    int page = 1,
    int pageSize = 20,
    String? severity,
    String? position,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'page_size': pageSize.toString(),
        if (severity != null) 'severity': severity,
        if (position != null) 'position': position,
      };

      final uri = Uri.parse('$baseUrl/sessions/$sessionId/hands')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'X-User-ID': userId,
          'X-API-Key': _apiKey,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get session hands');
      }
    } catch (e) {
      await LoggerService.error('📊 Get Session Hands Error: $e');
      rethrow;
    }
  }

  /// List all sessions for a user
  static Future<Map<String, dynamic>> listSessions({
    required String userId,
    int page = 1,
    int pageSize = 10,
    String? gameType,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'page_size': pageSize.toString(),
        if (gameType != null) 'game_type': gameType,
      };

      final uri = Uri.parse('$baseUrl/sessions')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'X-User-ID': userId,
          'X-API-Key': _apiKey,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to list sessions');
      }
    } catch (e) {
      await LoggerService.error('📊 List Sessions Error: $e');
      rethrow;
    }
  }

  /// Get dashboard configuration
  static Future<Map<String, dynamic>> getDashboardConfig({
    required String userId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard/config'),
        headers: {
          'X-User-ID': userId,
          'X-API-Key': _apiKey,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get dashboard config');
      }
    } catch (e) {
      await LoggerService.error('📊 Get Dashboard Config Error: $e');
      rethrow;
    }
  }

  /// Get available dashboard widgets
  static Future<List<Map<String, dynamic>>> getAvailableWidgets({
    required String userId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard/widgets'),
        headers: {
          'X-User-ID': userId,
          'X-API-Key': _apiKey,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(result['widgets'] ?? []);
      } else {
        throw Exception('Failed to get available widgets');
      }
    } catch (e) {
      await LoggerService.error('📊 Get Widgets Error: $e');
      rethrow;
    }
  }

  /// Build a map of opponent names to their calculated play styles
  /// This looks up each unique opponent from stored data
  static Future<Map<String, String>> _buildOpponentPlayStylesMap(
    List<Map<String, dynamic>> hands
  ) async {
    final Map<String, String> playStyles = {};
    final Set<String> processedNames = {};

    // Extract all unique opponent names from actions
    for (final hand in hands) {
      final actions = hand['actions'] as List<dynamic>? ?? [];
      for (final action in actions) {
        if (action is Map<String, dynamic>) {
          final playerName = action['playerName'] as String?;
          final isHero = action['isCurrentUser'] == true;

          // Skip hero and already processed names
          if (playerName == null || playerName == 'Hero' || isHero) continue;
          if (playerName.startsWith('Player ')) continue;
          if (processedNames.contains(playerName)) continue;

          processedNames.add(playerName);

          // Look up opponent and their stats
          try {
            final opponent = await OpponentService.findOpponentByName(playerName);
            if (opponent != null) {
              final stats = await OpponentStatsService.getOpponentStats(opponent.id);
              if (stats != null) {
                // Convert full play style to short code for Python backend
                final fullStyle = stats.playingStyle;
                playStyles[playerName] = _convertPlayStyleToCode(fullStyle);
              }
            }
          } catch (e) {
            // Ignore lookup errors, will fall back to UNKNOWN
          }
        }
      }
    }

    return playStyles;
  }

  /// Convert full play style description to short code
  /// e.g., "Tight-Aggressive (TAG)" -> "TAG"
  static String _convertPlayStyleToCode(String fullStyle) {
    if (fullStyle.contains('TAG') || fullStyle.contains('Tight-Aggressive')) {
      return 'TAG';
    } else if (fullStyle.contains('LAG') || fullStyle.contains('Loose-Aggressive')) {
      return 'LAG';
    } else if (fullStyle.contains('Fish') || fullStyle.contains('Loose-Passive')) {
      return 'FISH';
    } else if (fullStyle.contains('Rock') || fullStyle.contains('Tight-Passive') || fullStyle.contains('NIT')) {
      return 'NIT';
    } else if (fullStyle.contains('Maniac')) {
      return 'MANIAC';
    } else if (fullStyle.contains('Calling Station')) {
      return 'FISH';  // Calling stations are a type of fish
    } else if (fullStyle.contains('Regular') || fullStyle.contains('REG')) {
      return 'REG';
    }
    return 'UNKNOWN';
  }

  /// Prepare hand data for the backend
  /// Converts Flutter hand format to the format expected by the analytics API
  static Map<String, dynamic> _prepareHandData(
    Map<String, dynamic> hand,
    Map<String, String> opponentPlayStyles,
  ) {
    // Extract hero cards - check multiple field names
    Map<String, dynamic>? ourHoleCards;
    if (hand['ourHoleCards'] is Map<String, dynamic>) {
      ourHoleCards = hand['ourHoleCards'] as Map<String, dynamic>;
    }
    String? heroCards;
    if (ourHoleCards != null) {
      final card1 = ourHoleCards['card1'] as String?;
      final card2 = ourHoleCards['card2'] as String?;
      if (card1 != null && card2 != null) {
        heroCards = '${_convertCard(card1)}${_convertCard(card2)}';
      }
    }

    // Get hero seat - check multiple field names
    // Test data uses 'heroPosition' for seat number, other code uses 'heroSeatNumber'
    final heroSeat = hand['heroSeatNumber'] ?? hand['heroPosition'];

    // Get hero position name - check multiple field names
    String? heroPosition = hand['heroPositionName'] as String?;

    // Get hero action and position from actions
    // Check both seat matching AND isCurrentUser flag
    String? heroAction;
    double? heroStack;
    final actions = hand['actions'] as List<dynamic>? ?? [];

    for (final action in actions) {
      final actionMap = action as Map<String, dynamic>;
      final street = actionMap['street'] as String? ?? 'preflop';
      if (street != 'preflop') continue;

      final seat = actionMap['player'] ?? actionMap['playerSeat'];
      final isCurrentUser = actionMap['isCurrentUser'] == true;

      // Check if this is hero's action (via isCurrentUser flag OR seat match)
      if (isCurrentUser || (heroSeat != null && seat == heroSeat)) {
        heroAction = (actionMap['action'] as String?)?.toLowerCase();

        // Get position from action if not already set
        if (heroPosition == null || heroPosition == 'UNK') {
          heroPosition = actionMap['playerPosition'] as String?;
        }

        // Get stack from action if available
        if (actionMap['playerStack'] != null) {
          heroStack = (actionMap['playerStack'] as num).toDouble();
        }

        break;
      }
    }

    // Default position if still not found
    heroPosition ??= 'UNK';

    // Get big blind - check multiple field names
    final bigBlind = (hand['bigBlind'] ?? hand['handBigBlind'] ?? 200) as num;

    // Calculate hero stack in BB
    double? heroStackBB;
    if (heroStack != null && bigBlind > 0) {
      heroStackBB = heroStack / bigBlind;
    } else {
      // Try initialStacks as fallback
      final initialStacks = hand['initialStacks'] as Map<String, dynamic>?;
      if (heroSeat != null && initialStacks != null) {
        final stackValue = initialStacks[heroSeat.toString()];
        if (stackValue != null) {
          heroStackBB = (stackValue as num).toDouble() / bigBlind;
        }
      }
    }

    // Determine action facing (open, vs_open, vs_3bet, etc.)
    String actionFacing = 'open';
    int raiseCount = 0;
    bool reachedHero = false;
    for (final action in actions) {
      final actionMap = action as Map<String, dynamic>;
      final street = actionMap['street'] as String? ?? 'preflop';
      if (street != 'preflop') continue;

      final seat = actionMap['player'] ?? actionMap['playerSeat'];
      final isCurrentUser = actionMap['isCurrentUser'] == true;
      final actionType = (actionMap['action'] as String?)?.toLowerCase();

      // Stop when we reach hero's action
      if (isCurrentUser || (heroSeat != null && seat == heroSeat)) {
        reachedHero = true;
        break;
      }

      // Count raises before hero
      if (actionType == 'raise') {
        raiseCount++;
        if (raiseCount == 1) actionFacing = 'vs_open';
        if (raiseCount == 2) actionFacing = 'vs_3bet';
        if (raiseCount >= 3) actionFacing = 'vs_4bet';
      }
    }

    // Get villain position and type (the last raiser before hero)
    String? villainPosition;
    String? villainType;
    for (final action in actions.reversed) {
      final actionMap = action as Map<String, dynamic>;
      final street = actionMap['street'] as String? ?? 'preflop';
      if (street != 'preflop') continue;

      final seat = actionMap['player'] ?? actionMap['playerSeat'];
      final isCurrentUser = actionMap['isCurrentUser'] == true;
      final actionType = (actionMap['action'] as String?)?.toLowerCase();

      // Skip hero's action
      if (isCurrentUser || (heroSeat != null && seat == heroSeat)) continue;

      if (actionType == 'raise') {
        villainPosition = actionMap['playerPosition'] as String?;
        // Look up villain type from stored opponent play styles
        final playerName = actionMap['playerName'] as String?;
        if (playerName != null) {
          // Use stored play style if available, otherwise fall back to name extraction
          villainType = opponentPlayStyles[playerName] ?? _extractVillainType(playerName);
        }
        break;
      }
    }

    // Check if hand went to showdown
    bool wentToShowdown = hand['reachedShowdown'] == true ||
        hand['reachedShowdown'] == 1 ||
        (hand['showdownData'] != null);

    return {
      'hand_id': hand['id'] ?? hand['handNumber']?.toString() ?? 'unknown',
      'hero_position': heroPosition,
      'hero_cards': heroCards,
      'hero_action': heroAction,
      'hero_stack_bb': heroStackBB ?? 50.0,
      'action_facing': actionFacing,
      'villain_position': villainPosition,
      'villain_type': villainType,
      'went_to_showdown': wentToShowdown,
      'actions': hand['actions'] ?? [],
    };
  }

  /// Convert card from UI format (A♥) to simple format (Ah)
  static String _convertCard(String card) {
    if (card.length < 2) return card;

    final rank = card[0];
    final suit = card[1];

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

  /// Extract villain type from player name (e.g., "FISH Mike" -> "FISH")
  static String? _extractVillainType(String playerName) {
    final upperName = playerName.toUpperCase();
    const knownTypes = ['FISH', 'TAG', 'LAG', 'NIT', 'MANIAC', 'REG', 'REC', 'WHALE', 'SHARK'];

    for (final type in knownTypes) {
      if (upperName.startsWith(type)) {
        return type;
      }
    }

    // Also check if type is at the end (e.g., "Mike FISH")
    for (final type in knownTypes) {
      if (upperName.endsWith(type)) {
        return type;
      }
    }

    return null;
  }
}
