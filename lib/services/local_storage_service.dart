import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/subscription_service.dart';
import '../models/game_types.dart';

class LocalStorageService {
  static Database? _database;
  
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  static Future<Database> _initDatabase() async {
    String dbPath = path.join(await getDatabasesPath(), 'poker_logger.db');
    
    return await openDatabase(
      dbPath,
      version: 13,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sessions(
            id TEXT PRIMARY KEY,
            userId TEXT NOT NULL,
            smallBlind INTEGER NOT NULL,
            bigBlind INTEGER NOT NULL,
            playerCount INTEGER NOT NULL,
            ourSeatNumber INTEGER,
            totalHands INTEGER DEFAULT 0,
            startTime TEXT NOT NULL,
            endTime TEXT,
            userEmail TEXT,
            userName TEXT,
            sessionName TEXT,
            updatedAt TEXT,
            gameType TEXT DEFAULT 'cash',
            stackHistory TEXT,
            buyInAmount REAL,
            totalBuyIn REAL,
            handsLogged INTEGER DEFAULT 0,
            biggestPot REAL DEFAULT 0
          )
        ''');
        
        await db.execute('''
          CREATE TABLE hands(
            id TEXT PRIMARY KEY,
            sessionId TEXT NOT NULL,
            handNumber INTEGER NOT NULL,
            buttonPosition INTEGER NOT NULL,
            playerCount INTEGER NOT NULL,
            startTime TEXT NOT NULL,
            endTime TEXT,
            actions TEXT NOT NULL,
            boardCards TEXT,
            ourHoleCards TEXT,
            showdownData TEXT,
            reachedShowdown INTEGER DEFAULT 0,
            potAmount REAL DEFAULT 0,
            preflopPot REAL DEFAULT 0,
            flopPot REAL DEFAULT 0,
            turnPot REAL DEFAULT 0,
            riverPot REAL DEFAULT 0,
            winnerId INTEGER,
            heroPosition INTEGER,
            playerNames TEXT,
            handSmallBlind INTEGER,
            handBigBlind INTEGER,
            handGameType TEXT,
            isChoppedPot INTEGER DEFAULT 0,
            choppedWinners TEXT,
            individualShares TEXT,
            sharePerWinner REAL,
            isStarred INTEGER DEFAULT 0,
            tags TEXT,
            notes TEXT,
            FOREIGN KEY (sessionId) REFERENCES sessions (id)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add sessionName and updatedAt columns to existing sessions table
          await db.execute('ALTER TABLE sessions ADD COLUMN sessionName TEXT');
          await db.execute('ALTER TABLE sessions ADD COLUMN updatedAt TEXT');
        }
        if (oldVersion < 3) {
          // Add ourSeatNumber column if missing
          await db.execute('ALTER TABLE sessions ADD COLUMN ourSeatNumber INTEGER');
        }
        if (oldVersion < 4) {
          // Add gameType column if missing
          await db.execute('ALTER TABLE sessions ADD COLUMN gameType TEXT DEFAULT \'cash\'');
        }
        if (oldVersion < 5) {
          // Add new columns for hole cards and showdown data
          await db.execute('ALTER TABLE hands ADD COLUMN ourHoleCards TEXT');
          await db.execute('ALTER TABLE hands ADD COLUMN showdownData TEXT');
          await db.execute('ALTER TABLE hands ADD COLUMN reachedShowdown INTEGER DEFAULT 0');
        }
        if (oldVersion < 6) {
          // Add new columns for pot amount, winner, hero position, and player names
          await db.execute('ALTER TABLE hands ADD COLUMN potAmount REAL DEFAULT 0');
          await db.execute('ALTER TABLE hands ADD COLUMN winnerId INTEGER');
          await db.execute('ALTER TABLE hands ADD COLUMN heroPosition INTEGER');
          await db.execute('ALTER TABLE hands ADD COLUMN playerNames TEXT');
        }
        if (oldVersion < 7) {
          // Add session-level data to hands for easier querying
          await db.execute('ALTER TABLE hands ADD COLUMN handSmallBlind INTEGER');
          await db.execute('ALTER TABLE hands ADD COLUMN handBigBlind INTEGER');
          await db.execute('ALTER TABLE hands ADD COLUMN handGameType TEXT');
        }
        if (oldVersion < 8) {
          // Add per-street pot tracking columns
          await db.execute('ALTER TABLE hands ADD COLUMN preflopPot REAL DEFAULT 0');
          await db.execute('ALTER TABLE hands ADD COLUMN flopPot REAL DEFAULT 0');
          await db.execute('ALTER TABLE hands ADD COLUMN turnPot REAL DEFAULT 0');
          await db.execute('ALTER TABLE hands ADD COLUMN riverPot REAL DEFAULT 0');
        }
        if (oldVersion < 9) {
          // Add chopped pot tracking columns
          await db.execute('ALTER TABLE hands ADD COLUMN isChoppedPot INTEGER DEFAULT 0');
          await db.execute('ALTER TABLE hands ADD COLUMN choppedWinners TEXT');
          await db.execute('ALTER TABLE hands ADD COLUMN individualShares TEXT');
          await db.execute('ALTER TABLE hands ADD COLUMN sharePerWinner REAL');
        }
        if (oldVersion < 10) {
          // Add stack history tracking column to sessions table
          await db.execute('ALTER TABLE sessions ADD COLUMN stackHistory TEXT');
        }
        if (oldVersion < 11) {
          // Add buy-in amount tracking columns to sessions table
          await db.execute('ALTER TABLE sessions ADD COLUMN buyInAmount REAL');
          await db.execute('ALTER TABLE sessions ADD COLUMN totalBuyIn REAL');
        }
        if (oldVersion < 12) {
          // Add hand annotation columns for review/tagging
          await db.execute('ALTER TABLE hands ADD COLUMN isStarred INTEGER DEFAULT 0');
          await db.execute('ALTER TABLE hands ADD COLUMN tags TEXT');
          await db.execute('ALTER TABLE hands ADD COLUMN notes TEXT');
        }
        if (oldVersion < 13) {
          // Add handsLogged and biggestPot columns to sessions table
          await db.execute('ALTER TABLE sessions ADD COLUMN handsLogged INTEGER DEFAULT 0');
          await db.execute('ALTER TABLE sessions ADD COLUMN biggestPot REAL DEFAULT 0');
        }
      },
    );
  }
  
  // Save session locally
  static Future<void> saveSession({
    required String sessionId,
    required int smallBlind,
    required int bigBlind,
    required int playerCount,
    required String startTime,
    String? endTime,
    int? ourSeatNumber,
    GameType gameType = GameType.cash,
    double? buyInAmount,
  }) async {
    try {
      final db = await database;
      final userId = AuthService.userId ?? 'anonymous';

      final sessionData = {
        'id': sessionId,
        'userId': userId,
        'smallBlind': smallBlind,
        'bigBlind': bigBlind,
        'playerCount': playerCount,
        'ourSeatNumber': ourSeatNumber,
        'totalHands': 0,
        'startTime': startTime,
        'endTime': endTime,
        'userEmail': AuthService.currentUser?.email,
        'userName': AuthService.userDisplayName,
        'gameType': gameType.value,
      };

      if (buyInAmount != null) {
        sessionData['buyInAmount'] = buyInAmount;
        sessionData['totalBuyIn'] = buyInAmount;
      }

      await db.insert('sessions', sessionData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      print('Session saved locally: $sessionId');
    } catch (e) {
      print('Error saving session locally: $e');
    }
  }

  // Delete a session (used when navigating away without logging any hands)
  static Future<void> deleteSession(String sessionId) async {
    try {
      final db = await database;

      // Delete any hands in this session
      await db.delete('hands', where: 'sessionId = ?', whereArgs: [sessionId]);

      // Delete the session
      await db.delete('sessions', where: 'id = ?', whereArgs: [sessionId]);
    } catch (e) {
      // Silently fail - not critical
    }
  }

  // Save hand locally
  static Future<void> saveHand({
    required String sessionId,
    required int handNumber,
    required int buttonPosition,
    required int playerCount,
    required List<Map<String, dynamic>> actions,
    required String startTime,
    String? endTime,
    Map<String, dynamic>? boardCards,
    Map<String, dynamic>? ourHoleCards,
    Map<String, dynamic>? showdownData,
    bool? reachedShowdown,
    double? potAmount,
    double? preflopPot,
    double? flopPot,
    double? turnPot,
    double? riverPot,
    int? winnerId,
    int? heroPosition,
    Map<int, String>? playerNames,
    int? smallBlind,
    int? bigBlind,
    String? gameType,
    // Chopped pot fields
    bool? isChoppedPot,
    List<int>? choppedWinners,
    Map<int, double>? individualShares,
    double? sharePerWinner,
    // Hand annotations
    bool? isStarred,
    List<String>? tags,
    String? notes,
  }) async {
    try {
      final db = await database;
      // Use timestamp to ensure unique handId even if sessionId changes mid-session
      final handId = '${sessionId}_hand_${handNumber}_${DateTime.now().millisecondsSinceEpoch}';

      
      
      await db.insert(
        'hands',
        {
          'id': handId,
          'sessionId': sessionId,
          'handNumber': handNumber,
          'buttonPosition': buttonPosition,
          'playerCount': playerCount,
          'startTime': startTime,
          'endTime': endTime,
          'actions': _safeJsonEncode(actions),
          'boardCards': boardCards != null ? _safeJsonEncode(boardCards) : null,
          'ourHoleCards': ourHoleCards != null ? _safeJsonEncode(ourHoleCards) : null,
          'showdownData': showdownData != null ? _safeJsonEncode(showdownData) : null,
          'reachedShowdown': reachedShowdown == true ? 1 : 0,
          'potAmount': potAmount ?? 0,
          'preflopPot': preflopPot ?? 0,
          'flopPot': flopPot ?? 0,
          'turnPot': turnPot ?? 0,
          'riverPot': riverPot ?? 0,
          'winnerId': winnerId,
          'heroPosition': heroPosition,
          'playerNames': playerNames != null ? _safeJsonEncode(playerNames) : null,
          'handSmallBlind': smallBlind,
          'handBigBlind': bigBlind,
          'handGameType': gameType,
          // Chopped pot fields
          'isChoppedPot': (isChoppedPot == true) ? 1 : 0,
          'choppedWinners': choppedWinners != null ? _safeJsonEncode(choppedWinners) : null,
          'individualShares': individualShares != null ? _safeJsonEncode(_convertKeysToStrings(individualShares)) : null,
          'sharePerWinner': sharePerWinner,
          // Hand annotations
          'isStarred': (isStarred == true) ? 1 : 0,
          'tags': tags != null && tags.isNotEmpty ? _safeJsonEncode(tags) : null,
          'notes': notes,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      // Update session hand count
      await db.rawUpdate(
        'UPDATE sessions SET totalHands = totalHands + 1 WHERE id = ?',
        [sessionId],
      );
      
      print('Hand saved locally: $handId with potAmount: ${potAmount ?? 0}');
    } catch (e) {
      print('Error saving hand locally: $e');
    }
  }
  
  // Get all sessions for current user
  static Future<List<Map<String, dynamic>>> getUserSessions() async {
    try {
      final db = await database;
      final userId = AuthService.userId ?? 'anonymous';

      var sessions = await db.query(
        'sessions',
        where: 'userId = ?',
        whereArgs: [userId],
        orderBy: 'startTime DESC',
      );

      // Apply 30-day filtering for free-tier users (matching Firebase behavior)
      if (!SubscriptionService.isPremium) {
        final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
        sessions = sessions.where((session) {
          final startTimeStr = session['startTime'] as String?;
          if (startTimeStr == null) return false;

          try {
            final startTime = DateTime.parse(startTimeStr);
            return startTime.isAfter(thirtyDaysAgo);
          } catch (e) {
            // If startTime parsing fails, exclude the session
            print('Error parsing session startTime "$startTimeStr": $e');
            return false;
          }
        }).toList();
      }

      return sessions;
    } catch (e) {
      print('Error getting user sessions: $e');
      return [];
    }
  }
  
  // Get hands for a session
  static Future<List<Map<String, dynamic>>> getSessionHands(String sessionId) async {
    try {
      final db = await database;
      
      // First get the session data as fallback for old hands
      final sessionData = await db.query(
        'sessions',
        where: 'id = ?',
        whereArgs: [sessionId],
        limit: 1,
      );
      
      Map<String, dynamic> sessionDefaults = {};
      if (sessionData.isNotEmpty) {
        final session = sessionData.first;
        sessionDefaults = {
          'smallBlind': session['smallBlind'] ?? 1,
          'bigBlind': session['bigBlind'] ?? 2,
          'gameType': session['gameType'] ?? 'cash',
        };
      } else {
        // If no session found, use sensible defaults
        sessionDefaults = {
          'smallBlind': 1,
          'bigBlind': 2,
          'gameType': 'cash',
        };
      }
      
      final hands = await db.query(
        'hands',
        where: 'sessionId = ?',
        whereArgs: [sessionId],
        orderBy: 'handNumber ASC',
      );
      
      
      return hands.map((hand) {
        final result = Map<String, dynamic>.from(hand);
        
        
        // Parse JSON fields
        if (result['actions'] != null) {
          result['actions'] = jsonDecode(result['actions']);
        }
        if (result['boardCards'] != null) {
          result['boardCards'] = jsonDecode(result['boardCards']);
        }
        if (result['ourHoleCards'] != null) {
          result['ourHoleCards'] = jsonDecode(result['ourHoleCards']);
        }
        if (result['showdownData'] != null) {
          result['showdownData'] = jsonDecode(result['showdownData']);
        }
        if (result['playerNames'] != null) {
          result['playerNames'] = jsonDecode(result['playerNames']);
        }
        
        // Convert reachedShowdown from int to bool
        result['reachedShowdown'] = (result['reachedShowdown'] as int?) == 1;
        
        // Include pot amount, winner, and hero position
        result['potAmount'] = result['potAmount'] ?? 0;
        result['preflopPot'] = result['preflopPot'] ?? 0;
        result['flopPot'] = result['flopPot'] ?? 0;
        result['turnPot'] = result['turnPot'] ?? 0;
        result['riverPot'] = result['riverPot'] ?? 0;
        result['winnerId'] = result['winnerId'];
        result['heroPosition'] = result['heroPosition'];
        
        // Use hand-level session data (preferred) or fall back to session-level data
        result['smallBlind'] = result['handSmallBlind'] ?? sessionDefaults['smallBlind'];
        result['bigBlind'] = result['handBigBlind'] ?? sessionDefaults['bigBlind'];
        result['gameType'] = result['handGameType'] ?? sessionDefaults['gameType'];

        // Parse chopped pot fields
        result['isChoppedPot'] = (result['isChoppedPot'] == 1);
        if (result['choppedWinners'] != null && result['choppedWinners'].isNotEmpty) {
          try {
            result['choppedWinners'] = jsonDecode(result['choppedWinners']);
          } catch (e) {
            result['choppedWinners'] = null;
          }
        }
        if (result['individualShares'] != null && result['individualShares'].isNotEmpty) {
          try {
            final sharesMap = jsonDecode(result['individualShares']) as Map<String, dynamic>;
            result['individualShares'] = sharesMap;
          } catch (e) {
            result['individualShares'] = null;
          }
        }

        return result;
      }).toList();
    } catch (e) {
      print('Error getting session hands: $e');
      return [];
    }
  }
  
  // Update session end time
  static Future<void> endSession(String sessionId, String endTime) async {
    try {
      final db = await database;
      
      await db.update(
        'sessions',
        {'endTime': endTime},
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      
      print('Session ended locally: $sessionId');
    } catch (e) {
      print('Error ending session locally: $e');
    }
  }
  
  // Clear all local data (for testing)
  static Future<void> clearAllData() async {
    try {
      final db = await database;
      await db.delete('hands');
      await db.delete('sessions');
      print('All local data cleared');
    } catch (e) {
      print('Error clearing local data: $e');
    }
  }

  // Clear all session data for current user
  static Future<void> clearUserSessions() async {
    try {
      final db = await database;
      final userId = AuthService.userId ?? 'anonymous';
      
      // First get all session IDs for this user
      final sessions = await db.query(
        'sessions',
        columns: ['id'],
        where: 'userId = ?',
        whereArgs: [userId],
      );
      
      // Delete all hands for these sessions
      for (final session in sessions) {
        await db.delete(
          'hands',
          where: 'sessionId = ?',
          whereArgs: [session['id']],
        );
      }
      
      // Delete all sessions for this user
      await db.delete(
        'sessions',
        where: 'userId = ?',
        whereArgs: [userId],
      );
      
      print('All user sessions cleared from local storage');
    } catch (e) {
      print('Error clearing user sessions: $e');
    }
  }

  // Update session name
  static Future<void> updateSessionName(String sessionId, String sessionName) async {
    try {
      final db = await database;
      await db.update(
        'sessions',
        {
          'sessionName': sessionName,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      
      print('Session name updated locally: $sessionId -> $sessionName');
    } catch (e) {
      print('Error updating session name locally: $e');
      rethrow;
    }
  }

  // Update session with progress data
  static Future<void> updateSession({
    required String sessionId,
    int? handsLogged,
    double? biggestPot,
    List<Map<String, dynamic>>? stackHistory,
    double? totalBuyIn,
  }) async {
    try {
      final db = await database;

      Map<String, dynamic> updateData = {
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (handsLogged != null) {
        updateData['handsLogged'] = handsLogged;
      }

      if (biggestPot != null) {
        updateData['biggestPot'] = biggestPot;
      }

      if (stackHistory != null) {
        updateData['stackHistory'] = _safeJsonEncode(stackHistory);
      }

      if (totalBuyIn != null) {
        updateData['totalBuyIn'] = totalBuyIn;
      }

      await db.update(
        'sessions',
        updateData,
        where: 'id = ?',
        whereArgs: [sessionId],
      );

    } catch (e) {
      print('Error updating session locally: $e');
      rethrow;
    }
  }

  // Helper method to safely encode JSON, handling non-serializable objects
  static String _safeJsonEncode(dynamic data) {
    try {
      return jsonEncode(data);
    } catch (e) {
      // If encoding fails, try to convert to a safe format
      try {
        return jsonEncode(_makeJsonSafe(data));
      } catch (e2) {
        print('Warning: Failed to JSON encode data, using toString: $e2');
        return jsonEncode({'error': 'Failed to encode', 'data': data.toString()});
      }
    }
  }

  // Helper method to make objects JSON-safe by converting problematic types
  static dynamic _makeJsonSafe(dynamic data) {
    if (data == null) return null;

    if (data is Map) {
      Map<String, dynamic> result = {};
      data.forEach((key, value) {
        result[key.toString()] = _makeJsonSafe(value);
      });
      return result;
    }

    if (data is List) {
      return data.map((item) => _makeJsonSafe(item)).toList();
    }

    // Convert enums to their string representation
    if (data.runtimeType.toString().contains('Enum')) {
      return data.toString();
    }

    // Handle primitive types
    if (data is String || data is num || data is bool) {
      return data;
    }

    // For other objects, try to convert to string
    return data.toString();
  }

  // Helper method to convert map keys to strings
  static Map<String, dynamic> _convertKeysToStrings(Map<int, double> map) {
    Map<String, dynamic> result = {};
    map.forEach((key, value) {
      result[key.toString()] = value;
    });
    return result;
  }

  /// Set migration completion flag
  static Future<void> setMigrationCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('stats_migration_completed', true);
  }

  /// Check if migration has been completed
  static Future<bool> isMigrationCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('stats_migration_completed') ?? false;
  }

  /// Get session details including stack history and rebuys
  static Future<Map<String, dynamic>?> getSession(String sessionId) async {
    try {
      final db = await database;
      final results = await db.query(
        'sessions',
        where: 'id = ?',
        whereArgs: [sessionId],
        limit: 1,
      );

      if (results.isEmpty) {
        return null;
      }

      final sessionData = Map<String, dynamic>.from(results.first);

      // Parse JSON fields
      if (sessionData['stackHistory'] != null) {
        try {
          sessionData['stackHistory'] = jsonDecode(sessionData['stackHistory']);
        } catch (e) {
          print('Error parsing stackHistory: $e');
          sessionData['stackHistory'] = [];
        }
      } else {
        sessionData['stackHistory'] = [];
      }

      // Add empty rebuys for compatibility (local storage doesn't track rebuys separately yet)
      sessionData['rebuys'] = sessionData['rebuys'] ?? [];

      return sessionData;
    } catch (e) {
      print('Error getting session from local storage: $e');
      return null;
    }
  }
}