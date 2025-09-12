import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../services/auth_service.dart';
import '../models/game_types.dart';

class LocalStorageService {
  static Database? _database;
  
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  static Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'poker_logger.db');
    
    return await openDatabase(
      path,
      version: 7,
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
            gameType TEXT DEFAULT 'cash'
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
            winnerId INTEGER,
            heroPosition INTEGER,
            playerNames TEXT,
            handSmallBlind INTEGER,
            handBigBlind INTEGER,
            handGameType TEXT,
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
  }) async {
    try {
      final db = await database;
      final userId = AuthService.userId ?? 'anonymous';
      
      await db.insert(
        'sessions',
        {
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
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      print('Session saved locally: $sessionId');
    } catch (e) {
      print('Error saving session locally: $e');
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
    int? winnerId,
    int? heroPosition,
    Map<int, String>? playerNames,
    int? smallBlind,
    int? bigBlind,
    String? gameType,
  }) async {
    try {
      final db = await database;
      final handId = '${sessionId}_hand_$handNumber';
      
      print('🔥 DEBUG: saveHand called with:');
      print('  potAmount: $potAmount');
      print('  winnerId: $winnerId'); 
      print('  smallBlind: $smallBlind');
      print('  bigBlind: $bigBlind');
      print('  gameType: $gameType');
      
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
          'actions': jsonEncode(actions),
          'boardCards': boardCards != null ? jsonEncode(boardCards) : null,
          'ourHoleCards': ourHoleCards != null ? jsonEncode(ourHoleCards) : null,
          'showdownData': showdownData != null ? jsonEncode(showdownData) : null,
          'reachedShowdown': reachedShowdown == true ? 1 : 0,
          'potAmount': potAmount ?? 0,
          'winnerId': winnerId,
          'heroPosition': heroPosition,
          'playerNames': playerNames != null ? jsonEncode(playerNames) : null,
          'handSmallBlind': smallBlind,
          'handBigBlind': bigBlind,
          'handGameType': gameType,
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
      
      final sessions = await db.query(
        'sessions',
        where: 'userId = ?',
        whereArgs: [userId],
        orderBy: 'startTime DESC',
      );
      
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
      
      print('🔥 DEBUG: getSessionHands called for sessionId: $sessionId');
      print('🔥 DEBUG: Found ${hands.length} hands in local database');
      
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
        result['winnerId'] = result['winnerId'];
        result['heroPosition'] = result['heroPosition'];
        
        // Use hand-level session data (preferred) or fall back to session-level data
        result['smallBlind'] = result['handSmallBlind'] ?? sessionDefaults['smallBlind'];
        result['bigBlind'] = result['handBigBlind'] ?? sessionDefaults['bigBlind'];
        result['gameType'] = result['handGameType'] ?? sessionDefaults['gameType'];
        
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
    int? totalHands,
  }) async {
    try {
      final db = await database;
      
      Map<String, dynamic> updateData = {
        'updatedAt': DateTime.now().toIso8601String(),
      };
      
      if (totalHands != null) {
        updateData['totalHands'] = totalHands;
      }
      
      await db.update(
        'sessions',
        updateData,
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      
      print('Session updated locally: $sessionId (totalHands: $totalHands)');
    } catch (e) {
      print('Error updating session locally: $e');
      rethrow;
    }
  }
}