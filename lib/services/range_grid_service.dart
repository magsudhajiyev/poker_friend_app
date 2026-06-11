import 'package:shared_preferences/shared_preferences.dart';

import '../models/hand_state_machine.dart';
import '../models/stack_bucket.dart';
import 'auth_service.dart';
import 'local_storage_service.dart';

/// One indexed hero hand in the range grid data.
class RangeGridEntry {
  final String handId;
  final String sessionId;
  final String userId;
  final int timestamp; // millisecondsSinceEpoch
  final String gameType; // 'cash' | 'tournament'
  final String handClass; // 169-grid class: 'AKs', 'AKo', '77'
  final String position; // exact position name: 'BTN', 'UTG+1', ...
  final String posGroup; // 'EP' | 'MP' | 'CO' | 'BTN' | 'SB' | 'BB'
  final double? stackBB; // hero stack depth at first action, in BB
  final String? stackBucket; // StackRange.name, null when stack unknown
  final String primaryAction; // 'raise' | 'call' | 'fold' | 'check'
  final String preflopLine; // human-readable summary
  final double potBB; // final pot in BB
  final bool won;

  const RangeGridEntry({
    required this.handId,
    required this.sessionId,
    required this.userId,
    required this.timestamp,
    required this.gameType,
    required this.handClass,
    required this.position,
    required this.posGroup,
    required this.stackBB,
    required this.stackBucket,
    required this.primaryAction,
    required this.preflopLine,
    required this.potBB,
    required this.won,
  });

  Map<String, dynamic> toDbMap() => {
        'handId': handId,
        'sessionId': sessionId,
        'userId': userId,
        'timestamp': timestamp,
        'gameType': gameType,
        'handClass': handClass,
        'position': position,
        'posGroup': posGroup,
        'stackBB': stackBB,
        'stackBucket': stackBucket,
        'primaryAction': primaryAction,
        'preflopLine': preflopLine,
        'potBB': potBB,
        'won': won ? 1 : 0,
      };

  factory RangeGridEntry.fromDbMap(Map<String, dynamic> map) => RangeGridEntry(
        handId: map['handId'] as String,
        sessionId: map['sessionId'] as String? ?? '',
        userId: map['userId'] as String? ?? '',
        timestamp: map['timestamp'] as int? ?? 0,
        gameType: map['gameType'] as String? ?? 'cash',
        handClass: map['handClass'] as String? ?? '',
        position: map['position'] as String? ?? '',
        posGroup: map['posGroup'] as String? ?? '',
        stackBB: (map['stackBB'] as num?)?.toDouble(),
        stackBucket: map['stackBucket'] as String?,
        primaryAction: map['primaryAction'] as String? ?? 'fold',
        preflopLine: map['preflopLine'] as String? ?? '',
        potBB: (map['potBB'] as num?)?.toDouble() ?? 0.0,
        won: (map['won'] as int? ?? 0) == 1,
      );
}

/// Aggregated action frequencies for one 169-grid hand class (one grid cell).
class RangeCellAggregate {
  final String handClass;
  final int raiseCount;
  final int callCount;
  final int foldCount;
  final int checkCount;

  const RangeCellAggregate({
    required this.handClass,
    this.raiseCount = 0,
    this.callCount = 0,
    this.foldCount = 0,
    this.checkCount = 0,
  });

  int get total => raiseCount + callCount + foldCount + checkCount;

  RangeCellAggregate addingAction(String action, int count) {
    return RangeCellAggregate(
      handClass: handClass,
      raiseCount: raiseCount + (action == 'raise' ? count : 0),
      callCount: callCount + (action == 'call' ? count : 0),
      foldCount: foldCount + (action == 'fold' ? count : 0),
      checkCount: checkCount + (action == 'check' ? count : 0),
    );
  }
}

/// Range Grid — indexes the hero's hole-card hands by (hand class, position,
/// stack depth) so the 13×13 range chart fills itself from real play.
///
/// Pure canonicalization/derivation logic lives in static functions (tested
/// without a database); persistence goes through LocalStorageService.
class RangeGridService {
  static const _backfillFlagKey = 'range_grid_backfilled_v1';
  static Future<void>? _backfillFuture;

  // ── Canonicalization ────────────────────────────────────────────────

  static const _rankOrder = 'AKQJT98765432';

  /// Splits a card string like 'A♠' or '10♥' into (rank, suit).
  /// Returns null for malformed input.
  static (String, String)? _parseCard(String card) {
    final trimmed = card.trim();
    if (trimmed.length < 2) return null;
    final suit = trimmed.substring(trimmed.length - 1);
    var rank = trimmed.substring(0, trimmed.length - 1).toUpperCase();
    if (rank == '10') rank = 'T';
    if (!_rankOrder.contains(rank) || rank.length != 1) return null;
    return (rank, suit);
  }

  /// 169-grid canonical class for a pair of hole cards: 'AKs', 'AKo', '77'.
  /// Returns null when cards are missing or malformed.
  static String? canonicalHandClass(HoleCards? cards) {
    if (cards == null || !cards.isComplete) return null;
    final c1 = _parseCard(cards.card1!);
    final c2 = _parseCard(cards.card2!);
    if (c1 == null || c2 == null) return null;

    final (rank1, suit1) = c1;
    final (rank2, suit2) = c2;
    if (rank1 == rank2) return '$rank1$rank2'; // pair

    // Higher rank first
    final high =
        _rankOrder.indexOf(rank1) < _rankOrder.indexOf(rank2) ? rank1 : rank2;
    final low = high == rank1 ? rank2 : rank1;
    final suffix = suit1 == suit2 ? 's' : 'o';
    return '$high$low$suffix';
  }

  /// Coarse position group used for the grid's position filter.
  static String positionGroup(String position) {
    final p = position.toUpperCase();
    if (p == 'BB') return 'BB';
    if (p == 'SB') return 'SB';
    if (p == 'BTN' || p == 'BU' || p == 'BTN/SB') return 'BTN';
    if (p == 'CO') return 'CO';
    if (p.startsWith('UTG')) return 'EP';
    // LJ, HJ, generic P# middles
    return 'MP';
  }

  // ── Preflop line derivation ─────────────────────────────────────────

  /// Classifies the hero's preflop play from raw action maps (same format
  /// as ActionRecord.toMap / the stored hand JSON).
  ///
  /// Returns (primaryAction, line):
  /// - primaryAction: hero's first VOLUNTARY preflop action —
  ///   'raise' | 'call' | 'fold' | 'check' — used for cell frequencies.
  /// - line: short human-readable summary, e.g. "3-bet",
  ///   "Open-raised → folded".
  static (String, String) derivePreflopLine(
      List<Map<String, dynamic>> actions, int heroSeat) {
    int raisesBeforeHero = 0;
    String? primary;
    String firstLabel = '';
    String? heroLastAction;
    int heroActionCount = 0;

    bool isRaise(String? a) => a == 'raise' || a == 'all-in';

    for (final action in actions) {
      if (action['street'] != 'preflop') continue;
      final type = action['action'] as String?;
      if (type == null || type == 'none') continue;

      final isHero = action['player'] == heroSeat;
      if (!isHero) {
        if (isRaise(type) || type == 'bet') {
          if (primary == null) raisesBeforeHero++;
        }
        continue;
      }

      heroActionCount++;
      heroLastAction = type;

      if (primary != null) continue; // only first voluntary action classifies

      if (isRaise(type) || type == 'bet') {
        primary = 'raise';
        final raiseNumber = raisesBeforeHero + 1;
        firstLabel = switch (raiseNumber) {
          1 => 'Open-raised',
          2 => 'Re-raised',
          3 => '3-bet',
          _ => '4-bet+',
        };
      } else if (type == 'call') {
        primary = 'call';
        firstLabel = raisesBeforeHero == 0 ? 'Limped' : 'Called raise';
      } else if (type == 'check') {
        primary = 'check';
        firstLabel = 'Checked';
      } else if (type == 'fold') {
        primary = 'fold';
        firstLabel = raisesBeforeHero == 0 ? 'Folded' : 'Folded to raise';
      }
    }

    if (primary == null) return ('check', 'No action (walk)');

    // Hero acted again and ended up folding (e.g., raised then folded to 3-bet)
    var line = firstLabel;
    if (heroActionCount > 1 && heroLastAction == 'fold' && primary != 'fold') {
      line = '$firstLabel → folded';
    }
    return (primary, line);
  }

  /// Hero's stack in BB at their first recorded preflop action, if known.
  static double? heroStackBB(
      List<Map<String, dynamic>> actions, int heroSeat, double bigBlind) {
    if (bigBlind <= 0) return null;
    for (final action in actions) {
      if (action['player'] != heroSeat) continue;
      final stack = (action['playerStack'] as num?)?.toDouble();
      if (stack != null && stack > 0) return stack / bigBlind;
    }
    return null;
  }

  // ── Entry building ──────────────────────────────────────────────────

  /// Builds the index entry for a completed hand, or null when the hand
  /// can't be indexed (no hero hole cards / unknown position or seat).
  static RangeGridEntry? buildEntry({
    required String handId,
    required String sessionId,
    required String userId,
    required DateTime timestamp,
    required String gameType,
    required HoleCards? holeCards,
    required String? heroPositionName,
    required int? heroSeat,
    required List<Map<String, dynamic>> actions,
    required double bigBlind,
    required double potAmount,
    required int? winnerId,
    required List<int>? choppedWinners,
  }) {
    final handClass = canonicalHandClass(holeCards);
    if (handClass == null) return null;
    if (heroSeat == null) return null;
    final position = heroPositionName;
    if (position == null || position.isEmpty) return null;

    final stackBB = heroStackBB(actions, heroSeat, bigBlind);
    final (primaryAction, line) = derivePreflopLine(actions, heroSeat);
    final won =
        winnerId == heroSeat || (choppedWinners?.contains(heroSeat) ?? false);

    return RangeGridEntry(
      handId: handId,
      sessionId: sessionId,
      userId: userId,
      timestamp: timestamp.millisecondsSinceEpoch,
      gameType: gameType,
      handClass: handClass,
      position: position,
      posGroup: positionGroup(position),
      stackBB: stackBB,
      stackBucket: stackBB != null
          ? StackBucketHelper.getRangeForBB(stackBB).name
          : null,
      primaryAction: primaryAction,
      preflopLine: line,
      potBB: bigBlind > 0 ? potAmount / bigBlind : 0.0,
      won: won,
    );
  }

  /// Index a freshly completed hand. Fire-and-forget from the save path.
  static Future<void> indexHand({
    required HandRecord hand,
    required String handId,
    required String sessionId,
    required int? heroSeat,
    required double bigBlind,
    required String gameType,
  }) async {
    try {
      final userId = AuthService.userId;
      if (userId == null) return;
      final entry = buildEntry(
        handId: handId,
        sessionId: sessionId,
        userId: userId,
        timestamp: hand.endTime ?? hand.startTime,
        gameType: gameType,
        holeCards: hand.ourHoleCards,
        heroPositionName: hand.heroPositionName,
        heroSeat: heroSeat,
        actions: hand.actions.map((a) => a.toMap()).toList(),
        bigBlind: bigBlind,
        potAmount: hand.potAmount,
        winnerId: hand.winnerId,
        choppedWinners: hand.choppedWinners,
      );
      if (entry == null) return;
      await LocalStorageService.saveRangeEntry(entry.toDbMap());
    } catch (_) {
      // Index is derived data — never let it break the save path
    }
  }

  // ── Queries ─────────────────────────────────────────────────────────

  /// Aggregated action counts per 169-grid hand class for the grid,
  /// under the given filters (null = all).
  static Future<Map<String, RangeCellAggregate>> aggregateByHandClass({
    required String gameType,
    String? posGroup,
    String? stackBucket,
  }) async {
    await ensureBackfilled();
    final userId = AuthService.userId;
    if (userId == null) return {};

    final rows = await LocalStorageService.aggregateRangeByHandClass(
      userId: userId,
      gameType: gameType,
      posGroup: posGroup,
      stackBucket: stackBucket,
    );

    final result = <String, RangeCellAggregate>{};
    for (final row in rows) {
      final handClass = row['handClass'] as String? ?? '';
      final action = row['primaryAction'] as String? ?? 'fold';
      final count = (row['n'] as int?) ?? 0;
      final current =
          result[handClass] ?? RangeCellAggregate(handClass: handClass);
      result[handClass] = current.addingAction(action, count);
    }
    return result;
  }

  /// Recent hands for one hand class under the current filters (cell detail).
  static Future<List<RangeGridEntry>> queryHandClass({
    required String gameType,
    required String handClass,
    String? posGroup,
    String? stackBucket,
    int limit = 20,
  }) async {
    await ensureBackfilled();
    final userId = AuthService.userId;
    if (userId == null) return [];
    final rows = await LocalStorageService.queryRangeEntries(
      userId: userId,
      gameType: gameType,
      handClass: handClass,
      posGroup: posGroup,
      stackBucket: stackBucket,
      limit: limit,
    );
    return rows.map(RangeGridEntry.fromDbMap).toList();
  }

  /// Loads the full decoded hand map for an entry (for opening that hand's
  /// details from a cell's recent-hands list).
  static Future<Map<String, dynamic>?> loadHand(String handId) {
    return LocalStorageService.getHandById(handId);
  }

  // ── Backfill ────────────────────────────────────────────────────────

  /// Index all locally stored historical hands once. Idempotent (PK on
  /// handId); guarded by a SharedPreferences flag and an in-flight future.
  static Future<void> ensureBackfilled() {
    return _backfillFuture ??= _runBackfill();
  }

  static Future<void> _runBackfill() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_backfillFlagKey) ?? false) return;

      final rows = await LocalStorageService.getHandsForRangeBackfill();
      for (final row in rows) {
        try {
          // Rows without an owning user can never be queried — skip them
          final rowUserId = row['userId'] as String?;
          if (rowUserId == null || rowUserId.isEmpty) continue;

          final actionsRaw = row['actions'];
          if (actionsRaw is! List) continue;
          final actions = actionsRaw
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();

          // Hero is identified by the isCurrentUser flag on their actions
          Map<String, dynamic>? heroAction;
          for (final a in actions) {
            if (a['isCurrentUser'] == true) {
              heroAction = a;
              break;
            }
          }
          if (heroAction == null) continue;
          final heroSeat = heroAction['player'] as int?;
          final heroPosition = heroAction['playerPosition'] as String?;

          final holeCardsRaw = row['ourHoleCards'];
          final holeCards = holeCardsRaw is Map
              ? HoleCards.fromMap(Map<String, dynamic>.from(holeCardsRaw))
              : null;

          final choppedRaw = row['choppedWinners'];
          final chopped =
              choppedRaw is List ? choppedRaw.whereType<int>().toList() : null;

          final entry = buildEntry(
            handId: row['id'] as String,
            sessionId: row['sessionId'] as String? ?? '',
            userId: rowUserId,
            timestamp: DateTime.tryParse(
                    (row['endTime'] ?? row['startTime'] ?? '') as String) ??
                DateTime.fromMillisecondsSinceEpoch(0),
            gameType: row['handGameType'] as String? ??
                row['gameType'] as String? ??
                'cash',
            holeCards: holeCards,
            heroPositionName: heroPosition,
            heroSeat: heroSeat,
            actions: actions,
            bigBlind:
                ((row['handBigBlind'] ?? row['bigBlind']) as num?)?.toDouble() ??
                    0.0,
            potAmount: (row['potAmount'] as num?)?.toDouble() ?? 0.0,
            winnerId: row['winnerId'] as int?,
            choppedWinners: chopped,
          );
          if (entry != null) {
            await LocalStorageService.saveRangeEntry(entry.toDbMap());
          }
        } catch (_) {
          // Skip malformed historical hands
        }
      }

      await prefs.setBool(_backfillFlagKey, true);
    } catch (_) {
      // Retry on next ensureBackfilled() call in a future app session
      _backfillFuture = null;
    }
  }
}
