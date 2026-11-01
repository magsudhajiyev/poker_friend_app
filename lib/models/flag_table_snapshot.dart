import '../utils/poker_positions.dart';
import 'game_types.dart';
import 'hand_state_machine.dart';
import 'poker_game_state.dart';

/// One seat of a flagged table.
class FlagSeat {
  final int seat;
  final bool active;
  final String? position;
  final String? name;
  final String? playerId;

  /// Stack at the START of the hand (chips already in the pot are added back).
  final double stack;

  const FlagSeat({
    required this.seat,
    required this.active,
    this.position,
    this.name,
    this.playerId,
    this.stack = 0,
  });

  Map<String, dynamic> toMap() => {
        'seat': seat,
        'active': active,
        if (position != null) 'position': position,
        if (name != null) 'name': name,
        if (playerId != null) 'playerId': playerId,
        'stack': stack,
      };

  factory FlagSeat.fromMap(Map m) => FlagSeat(
        seat: (m['seat'] as num).toInt(),
        active: m['active'] == true,
        position: m['position'] as String?,
        name: m['name'] as String?,
        playerId: m['playerId'] as String?,
        stack: (m['stack'] as num?)?.toDouble() ?? 0,
      );
}

/// The table at the moment a hand was flagged: enough to rebuild it in
/// recall mode. Stored under `flagMeta['table']`; plain JSON types only, so it
/// survives Firestore and SQLite unchanged.
class FlagTableSnapshot {
  final int buttonPosition;
  final int? heroSeat;
  final double smallBlind;
  final double bigBlind;
  final bool hasBBante;
  final String gameType;
  final List<FlagSeat> seats;

  const FlagTableSnapshot({
    required this.buttonPosition,
    required this.heroSeat,
    required this.smallBlind,
    required this.bigBlind,
    required this.hasBBante,
    required this.gameType,
    required this.seats,
  });

  Map<String, dynamic> toMap() => {
        'buttonPosition': buttonPosition,
        if (heroSeat != null) 'heroSeat': heroSeat,
        'smallBlind': smallBlind,
        'bigBlind': bigBlind,
        'hasBBante': hasBBante,
        'gameType': gameType,
        'seats': [for (final s in seats) s.toMap()],
      };

  static FlagTableSnapshot? fromMap(Object? raw) {
    if (raw is! Map) return null;
    try {
      return FlagTableSnapshot(
        buttonPosition: (raw['buttonPosition'] as num).toInt(),
        heroSeat: (raw['heroSeat'] as num?)?.toInt(),
        smallBlind: (raw['smallBlind'] as num).toDouble(),
        bigBlind: (raw['bigBlind'] as num).toDouble(),
        hasBBante: raw['hasBBante'] == true,
        gameType: raw['gameType']?.toString() ?? 'cash',
        seats: [
          for (final s in (raw['seats'] as List)) FlagSeat.fromMap(s as Map),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  /// Best-effort table for stubs saved before snapshots existed: seats and
  /// stacks come from the stub's `stacks` map, the button defaults to seat 1
  /// and hero to the first seat. The user can edit all of it in recall mode.
  static FlagTableSnapshot fromLegacyMeta(Map<String, dynamic> meta) {
    final stacks = <int, double>{};
    final raw = meta['stacks'];
    if (raw is Map) {
      raw.forEach((k, v) {
        final seat = int.tryParse(k.toString());
        if (seat != null && v is num) stacks[seat] = v.toDouble();
      });
    }
    if (stacks.isEmpty) {
      final bb = (meta['bigBlind'] as num?)?.toDouble() ?? 2;
      stacks
        ..[1] = bb * 100
        ..[2] = bb * 100;
    }
    final order = stacks.keys.toList()..sort();
    return FlagTableSnapshot(
      buttonPosition: order.first,
      heroSeat: order.first,
      smallBlind: (meta['smallBlind'] as num?)?.toDouble() ?? 1,
      bigBlind: (meta['bigBlind'] as num?)?.toDouble() ?? 2,
      hasBBante: false,
      gameType: meta['gameType']?.toString() ?? 'cash',
      seats: [
        for (var i = 1; i <= 9; i++)
          FlagSeat(
              seat: i, active: stacks.containsKey(i), stack: stacks[i] ?? 0),
      ],
    );
  }

  GameType get gameTypeEnum =>
      gameType == 'tournament' ? GameType.tournament : GameType.cash;

  /// Builds the snapshot from the live table. Stacks are start-of-hand.
  static FlagTableSnapshot capture(
      PokerSessionManager sm, PokerGameState g) {
    final active = [
      for (final p in g.players)
        if (p.isActive) p.playerId
    ];
    final seats = <FlagSeat>[];
    for (var i = 1; i <= g.numberOfPlayers; i++) {
      final p = g.players[i - 1];
      final isActive = p.isActive;
      seats.add(FlagSeat(
        seat: i,
        active: isActive,
        position: isActive
            ? PokerPositions.getPositionNameForActivePlayers(
                i, g.buttonPosition, active)
            : null,
        name: sm.playerNames[i],
        playerId: sm.playerIds[i],
        stack: isActive
            ? p.currentStack + p.betThisRound + p.totalContribution
            : 0,
      ));
    }
    return FlagTableSnapshot(
      buttonPosition: g.buttonPosition,
      heroSeat: sm.ourSeatNumber,
      smallBlind: g.smallBlind,
      bigBlind: g.bigBlind,
      hasBBante: g.hasBBante,
      gameType: sm.gameType.name,
      seats: seats,
    );
  }
}
