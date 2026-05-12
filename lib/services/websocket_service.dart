import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;

/// Connection state for the WebSocket
enum WebSocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// Service for WebSocket communication with the backend
class WebSocketService {
  static WebSocketService? _instance;
  static WebSocketService get instance {
    _instance ??= WebSocketService._();
    return _instance!;
  }

  WebSocketService._();

  IO.Socket? _socket;
  String? _currentTableId;
  String? _serverUrl;

  // Connection state
  final _connectionStateController = StreamController<WebSocketConnectionState>.broadcast();
  Stream<WebSocketConnectionState> get connectionState => _connectionStateController.stream;
  WebSocketConnectionState _currentState = WebSocketConnectionState.disconnected;

  // Event streams
  final _playerJoinedController = StreamController<Map<String, dynamic>>.broadcast();
  final _playerLeftController = StreamController<Map<String, dynamic>>.broadcast();
  final _handStartedController = StreamController<Map<String, dynamic>>.broadcast();
  final _actionLoggedController = StreamController<Map<String, dynamic>>.broadcast();
  final _boardDealtController = StreamController<Map<String, dynamic>>.broadcast();
  final _handCompletedController = StreamController<Map<String, dynamic>>.broadcast();
  final _sessionEndedController = StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<Map<String, dynamic>>.broadcast();

  // Event ranking streams (for live dashboard)
  final _rankingUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  String? _currentEventId;

  // Event stream getters
  Stream<Map<String, dynamic>> get onPlayerJoined => _playerJoinedController.stream;
  Stream<Map<String, dynamic>> get onPlayerLeft => _playerLeftController.stream;
  Stream<Map<String, dynamic>> get onHandStarted => _handStartedController.stream;
  Stream<Map<String, dynamic>> get onActionLogged => _actionLoggedController.stream;
  Stream<Map<String, dynamic>> get onBoardDealt => _boardDealtController.stream;
  Stream<Map<String, dynamic>> get onHandCompleted => _handCompletedController.stream;
  Stream<Map<String, dynamic>> get onSessionEnded => _sessionEndedController.stream;
  Stream<Map<String, dynamic>> get onError => _errorController.stream;

  /// Stream for live ranking updates (for event dashboard)
  Stream<Map<String, dynamic>> get onRankingUpdate => _rankingUpdateController.stream;

  String? _userId;

  /// Connect to the WebSocket server
  ///
  /// [serverUrl] should be the base URL, e.g. "http://localhost:8000"
  /// Socket.IO is now at the default /socket.io path
  void connect(String serverUrl, {String? userId}) {
    if (_socket != null && _socket!.connected) {
      // debugPrint('WebSocket already connected');
      return;
    }

    // Remove /ws suffix if present (old convention)
    final cleanUrl = serverUrl.endsWith('/ws')
        ? serverUrl.substring(0, serverUrl.length - 3)
        : serverUrl;
    _serverUrl = cleanUrl;
    _userId = userId;
    _updateState(WebSocketConnectionState.connecting);

    _socket = IO.io(
      cleanUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .setAuth({'user_id': userId})
          .build(),
    );

    _setupListeners();
  }

  void _setupListeners() {
    if (_socket == null) return;

    _socket!.onConnect((_) {
      // debugPrint('WebSocket connected');
      _updateState(WebSocketConnectionState.connected);

      // Rejoin table if we were in one
      if (_currentTableId != null) {
        joinTable(_currentTableId!);
      }
    });

    _socket!.onDisconnect((_) {
      // debugPrint('WebSocket disconnected');
      _updateState(WebSocketConnectionState.disconnected);
    });

_socket!.onReconnect((_) {
      // debugPrint('WebSocket reconnected');
      _updateState(WebSocketConnectionState.connected);
    });

    _socket!.onConnectError((error) {
      // debugPrint('WebSocket connection error: $error');
      _errorController.add({'type': 'connection_error', 'error': error.toString()});
    });

    _socket!.onError((error) {
      // debugPrint('WebSocket error: $error');
      _errorController.add({'type': 'error', 'error': error.toString()});
    });

    // Server events
    _socket!.on('player_joined', (data) {
      _playerJoinedController.add(_parseData(data));
    });

    _socket!.on('player_left', (data) {
      _playerLeftController.add(_parseData(data));
    });

    _socket!.on('hand_started', (data) {
      _handStartedController.add(_parseData(data));
    });

    _socket!.on('action_logged', (data) {
      _actionLoggedController.add(_parseData(data));
    });

    _socket!.on('board_dealt', (data) {
      _boardDealtController.add(_parseData(data));
    });

    _socket!.on('hand_completed', (data) {
      _handCompletedController.add(_parseData(data));
    });

    _socket!.on('session_ended', (data) {
      _sessionEndedController.add(_parseData(data));
    });

    _socket!.on('error', (data) {
      _errorController.add(_parseData(data));
    });

    // Event ranking updates (for live dashboard)
    _socket!.on('ranking_update', (data) {
      _rankingUpdateController.add(_parseData(data));
    });
  }

  Map<String, dynamic> _parseData(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'data': data};
  }

  void _updateState(WebSocketConnectionState state) {
    _currentState = state;
    _connectionStateController.add(state);
  }

  /// Disconnect from the WebSocket server
  void disconnect() {
    _currentTableId = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _updateState(WebSocketConnectionState.disconnected);
  }

  /// Check if connected
  bool get isConnected => _socket?.connected ?? false;

  /// Get current connection state
  WebSocketConnectionState get currentState => _currentState;

  /// Join a table room
  void joinTable(String tableId, {int? seatNumber, String? playerName}) {
    _currentTableId = tableId;
    if (isConnected) {
      _socket!.emit('join_table', {
        'table_id': tableId,
        'seat_number': seatNumber,
        'player_name': playerName ?? 'Unknown',
      });
      // debugPrint('Joining table: $tableId');
    }
  }

  /// Leave a table room
  void leaveTable(String tableId) {
    if (isConnected) {
      _socket!.emit('leave_table', {'table_id': tableId});
      // debugPrint('Leaving table: $tableId');
    }
    if (_currentTableId == tableId) {
      _currentTableId = null;
    }
  }

  /// Emit a dealer action (for dealers)
  void emitDealerAction({
    required String tableId,
    required String sessionId,
    required String handId,
    required int seatNumber,
    required String action,
    double? amount,
    double? potAfter,
  }) {
    if (!isConnected) {
      // debugPrint('Cannot emit action: not connected');
      return;
    }

    _socket!.emit('dealer_action', {
      'session_id': sessionId,
      'hand_id': handId,
      'seat_number': seatNumber,
      'action': action,
      'amount': amount,
      'pot_after': potAfter ?? 0,
    });
  }

  /// Emit hand started event (for dealers)
  void emitHandStarted({
    required String tableId,
    required String sessionId,
    required String handId,
    required int handNumber,
    required int buttonPosition,
    required Map<int, String> players,  // seat -> player name
  }) {
    if (!isConnected) return;

    _socket!.emit('start_hand', {
      'session_id': sessionId,
      'hand_id': handId,
      'hand_number': handNumber,
      'button_position': buttonPosition,
      'players': players.map((k, v) => MapEntry(k.toString(), v)),
    });
  }

  /// Emit board cards dealt (for dealers)
  void emitBoardDealt({
    required String tableId,
    required String sessionId,
    required String handId,
    required String street,  // 'flop', 'turn', 'river'
    required List<String> cards,
  }) {
    if (!isConnected) return;

    _socket!.emit('board_dealt', {
      'session_id': sessionId,
      'hand_id': handId,
      'street': street,
      'cards': cards,
    });
  }

  /// Emit hand completed event (for dealers)
  void emitHandCompleted({
    required String tableId,
    required String sessionId,
    required String handId,
    required int winnerSeat,
    required double potAmount,
    String? summary,
  }) {
    if (!isConnected) return;

    _socket!.emit('complete_hand', {
      'session_id': sessionId,
      'hand_id': handId,
      'winner_seat': winnerSeat,
      'pot_amount': potAmount,
      'summary': summary ?? '',
    });
  }

  /// Emit session ended event (for dealers)
  void emitSessionEnded({
    required String tableId,
    required String sessionId,
    int? totalHands,
  }) {
    if (!isConnected) return;

    _socket!.emit('end_session', {
      'session_id': sessionId,
      'total_hands': totalHands ?? 0,
    });
  }

  // ============ Event Dashboard Methods ============

  /// Join an event room to receive live ranking updates
  ///
  /// If the event doesn't exist on the backend yet, you can pass optional
  /// event data to create it on-the-fly.
  Future<Map<String, dynamic>?> joinEvent(
    String eventId, {
    String? clubId,
    String? name,
    List<String>? tableIds,
    bool? isPublic,
    String? accessCode,
    String? createdBy,
  }) async {
    if (!isConnected) return null;

    _currentEventId = eventId;
    final completer = Completer<Map<String, dynamic>?>();

    final payload = <String, dynamic>{
      'event_id': eventId,
    };

    // Add optional event data for on-the-fly creation
    if (clubId != null) payload['club_id'] = clubId;
    if (name != null) payload['name'] = name;
    if (tableIds != null) payload['table_ids'] = tableIds;
    if (isPublic != null) payload['is_public'] = isPublic;
    if (accessCode != null) payload['access_code'] = accessCode;
    if (createdBy != null) payload['created_by'] = createdBy;

    _socket!.emitWithAck('join_event', payload, ack: (data) {
      if (data != null) {
        completer.complete(_parseData(data));
      } else {
        completer.complete(null);
      }
    });

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => null,
    );
  }

  /// Leave an event room
  void leaveEvent(String eventId) {
    if (!isConnected) return;

    _socket!.emit('leave_event', {'event_id': eventId});

    if (_currentEventId == eventId) {
      _currentEventId = null;
    }
  }

  /// Update a player's stack (triggers ranking broadcast if in event)
  Future<Map<String, dynamic>?> emitPlayerStackUpdate({
    required String tableId,
    required String playerId,
    required int newStack,
    String? playerName,
    int? seatNumber,
    String? status, // 'active', 'busted', 'onBreak'
    int? finishPosition, // For busted players (e.g., 14 = finished 14th)
  }) async {
    if (!isConnected) return null;

    final completer = Completer<Map<String, dynamic>?>();

    final payload = <String, dynamic>{
      'table_id': tableId,
      'player_id': playerId,
      'new_stack': newStack,
    };
    if (playerName != null) payload['player_name'] = playerName;
    if (seatNumber != null) payload['seat_number'] = seatNumber;
    if (status != null) payload['status'] = status;
    if (finishPosition != null) payload['finish_position'] = finishPosition;

    _socket!.emitWithAck('update_player_stack', payload, ack: (data) {
      if (data != null) {
        completer.complete(_parseData(data));
      } else {
        completer.complete(null);
      }
    });

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => null,
    );
  }

  /// Sync all players for an event (call when dashboard opens)
  ///
  /// If the event doesn't exist on the backend yet, you can pass optional
  /// event data to create it on-the-fly.
  Future<Map<String, dynamic>?> syncEventPlayers({
    required String eventId,
    required Map<String, List<Map<String, dynamic>>> tablePlayers,
    String? clubId,
    String? name,
    List<String>? tableIds,
    bool? isPublic,
    String? createdBy,
  }) async {
    if (!isConnected) return null;

    final completer = Completer<Map<String, dynamic>?>();

    final payload = <String, dynamic>{
      'event_id': eventId,
      'table_players': tablePlayers,
    };

    // Add optional event data for on-the-fly creation
    if (clubId != null) payload['club_id'] = clubId;
    if (name != null) payload['name'] = name;
    if (tableIds != null) payload['table_ids'] = tableIds;
    if (isPublic != null) payload['is_public'] = isPublic;
    if (createdBy != null) payload['created_by'] = createdBy;

    _socket!.emitWithAck('sync_event_players', payload, ack: (data) {
      if (data != null) {
        completer.complete(_parseData(data));
      } else {
        completer.complete(null);
      }
    });

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => null,
    );
  }

  /// Get current event ID (if in an event room)
  String? get currentEventId => _currentEventId;

  /// Dispose all resources
  void dispose() {
    disconnect();
    _connectionStateController.close();
    _playerJoinedController.close();
    _playerLeftController.close();
    _handStartedController.close();
    _actionLoggedController.close();
    _boardDealtController.close();
    _handCompletedController.close();
    _sessionEndedController.close();
    _errorController.close();
    _rankingUpdateController.close();
    _instance = null;
  }
}
