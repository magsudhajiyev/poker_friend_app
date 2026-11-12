import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_types.dart';
import '../models/hand_state_machine.dart';
import '../models/poker_game_state.dart';
import '../models/single_hand_group.dart';
import '../models/single_hand_setup.dart';
import '../utils/poker_positions.dart';
import 'app_data_cache.dart';
import 'auth_service.dart';
import 'firebase_service.dart';
import 'free_tier_limits.dart';
import 'local_storage_service.dart';
import 'logger_service.dart';

/// Result of [SingleHandService.saveHand].
class SingleHandSaveResult {
  final String sessionId;

  /// Firestore hand doc id; falls back to the SQLite id when the cloud write
  /// had not been acknowledged yet (offline: the write stays queued).
  final String handId;
  final int handNumber;
  final SingleHandGroup group;

  /// Seat -> name as saved (position labels, see [SingleHandService.seatNames]).
  final Map<int, String> playerNames;

  const SingleHandSaveResult({
    required this.sessionId,
    required this.handId,
    required this.handNumber,
    required this.group,
    this.playerNames = const {},
  });
}

/// Everything a single-hand save needs from storage. The real
/// implementation writes Firestore + SQLite; tests inject a fake. Nothing here
/// can touch stats, `session_results` or `endSession`: single hands never
/// do (docs/features/single-hand-logging.md, decisions 3 and 4).
abstract class SingleHandBackend {
  /// Hand groups of the signed-in user, any order.
  Future<List<SingleHandGroup>> loadGroups();

  /// Hands already in [groupId] (0 when unknown).
  Future<int> handCount(String groupId);

  /// Creates the group doc under the client-chosen [groupId].
  Future<void> createGroup({
    required String groupId,
    required String name,
    required SingleHandSetup setup,
  });

  /// Writes the hand WITHOUT stats and bumps the group counters.
  /// Returns `(cloudHandId, localHandId)`; either may be null.
  Future<(String?, String?)> writeHand({
    required String groupId,
    required int handNumber,
    required HandRecord hand,
    required SingleHandSetup setup,
    required Map<int, String> playerNames,
    Map<int, String>? playerIds,
  });

  /// Moves the group's `endTime` to [at].
  Future<void> touchGroup(String groupId, DateTime at);
}

class SingleHandService {
  SingleHandService._();

  /// A group older than this (last hand) is not suggested.
  static const Duration groupWindow = Duration(hours: 12);

  static const String _lastGroupKey = 'single_hand_last_group';

  @visibleForTesting
  static SingleHandBackend backend = FirebaseSingleHandBackend();

  /// Clock, id and tier cap seams for tests.
  @visibleForTesting
  static String Function() newGroupId = FirebaseService.newSessionId;
  static DateTime Function() now = DateTime.now;
  static bool Function(int handsInGroup) canAddHand =
      FreeTierLimits.canLogAnotherHand;

  // ---------------------------------------------------------------------------
  // Grouping
  // ---------------------------------------------------------------------------

  /// The group a new hand should default to, or null for "New group".
  static Future<SingleHandGroup?> suggestedGroup(SingleHandSetup setup) async {
    final groups = await _sortedGroups();
    return pickSuggested(groups, setup, now(), canAddHand);
  }

  static Future<List<SingleHandGroup>> recentGroups({int limit = 5}) async {
    final groups = await _sortedGroups();
    return groups.take(limit).toList();
  }

  /// Pure grouping rule: only the MOST RECENT group can be the default, and
  /// only when its last hand is under 12h old, the game type matches, the
  /// blinds match (cash only: tournament blinds go up) and the tier hand cap
  /// still allows one more hand. [groups] must be sorted newest first.
  static SingleHandGroup? pickSuggested(
    List<SingleHandGroup> groups,
    SingleHandSetup setup,
    DateTime at,
    bool Function(int handsInGroup) canAdd,
  ) {
    if (groups.isEmpty) return null;
    final g = groups.first;
    if (at.difference(g.lastHandAt) >= groupWindow) return null;
    if (g.gameType != setup.gameType) return null;
    if (setup.gameType == GameType.cash &&
        (g.smallBlind != setup.smallBlind || g.bigBlind != setup.bigBlind)) {
      return null;
    }
    if (!canAdd(g.handCount)) return null;
    return g;
  }

  /// Seat -> saved name: the hero's nickname (when the setup has one),
  /// every other seat by position (BTN, CO…).
  static Map<int, String> seatNames(SingleHandSetup setup) {
    final snapshot = {
      for (final seat in setup.toSnapshot().seats) seat.seat: seat.name,
    };
    return {
      for (var s = 1; s <= setup.playerCount; s++)
        s: (snapshot[s] ?? '').isNotEmpty ? snapshot[s]! : 'Player $s',
    };
  }

  /// Names to save: a live table name (a real opponent picked on a seat, or
  /// the hero nickname) wins over the default from [seatNames], unless it is
  /// empty, "Player N" or a bare position label. [live] is the table's
  /// `sessionManager.playerNames`.
  static Map<int, String> mergeNames(
      SingleHandSetup setup, Map<int, String>? live) {
    final defaults = seatNames(setup);
    if (live == null) return defaults;
    bool placeholder(String n) =>
        n.trim().isEmpty ||
        RegExp(r'^Player \d+$').hasMatch(n.trim()) ||
        PokerPositions.isPositionName(n.trim());
    return {
      for (final e in defaults.entries)
        e.key: (live[e.key] != null && !placeholder(live[e.key]!))
            ? live[e.key]!.trim()
            : e.value,
    };
  }

  /// `{date} · {blinds} {Cash|Tournament}`. English unless the caller passes
  /// the localized [kind] label and [locale]; pass the result as `groupName`.
  static String defaultGroupName(SingleHandSetup setup, DateTime at,
      {String? kind, String? locale}) {
    kind ??= setup.gameType == GameType.cash ? 'Cash' : 'Tournament';
    final blinds =
        '${formatBlindValue(setup.smallBlind)}/${formatBlindValue(setup.bigBlind)}';
    return '${DateFormat.MMMd(locale).format(at)} · $blinds $kind';
  }

  static Future<List<SingleHandGroup>> _sortedGroups() async {
    List<SingleHandGroup> groups;
    try {
      groups = await backend.loadGroups();
    } catch (e) {
      await LoggerService.warning('Single hand: loading groups failed: $e');
      groups = const [];
    }
    if (groups.isEmpty) {
      final cached = await _cachedLastGroup();
      if (cached != null) groups = [cached];
    }
    return [...groups]..sort((a, b) => b.lastHandAt.compareTo(a.lastHandAt));
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  /// Saves one hand into [groupId], or into a NEW group when [groupId] is null
  /// (or the group is already at the tier cap). Never updates stats, never
  /// writes `session_results`, never ends a session.
  static Future<SingleHandSaveResult> saveHand({
    required HandRecord hand,
    required SingleHandSetup setup,
    String? groupId,
    String? groupName,
    Map<int, String>? playerNames,
    Map<int, String>? playerIds,
  }) async {
    final at = now();
    final names = mergeNames(setup, playerNames);
    final ids = {
      for (final e in (playerIds ?? const <int, String>{}).entries)
        if (e.key <= setup.playerCount && e.value.isNotEmpty) e.key: e.value
    };
    var existingHands = 0;
    if (groupId != null) {
      existingHands = await _safeCount(groupId);
      if (!canAddHand(existingHands)) {
        groupId = null;
        existingHands = 0;
      }
    }

    final String id;
    final String name;
    if (groupId == null) {
      id = newGroupId();
      name = groupName ?? defaultGroupName(setup, at);
      await backend.createGroup(groupId: id, name: name, setup: setup);
    } else {
      id = groupId;
      name = await _nameOf(id);
    }

    final handNumber = existingHands + 1;
    final (cloudId, localId) = await backend.writeHand(
        groupId: id,
        handNumber: handNumber,
        hand: hand,
        setup: setup,
        playerNames: names,
        playerIds: ids.isEmpty ? null : ids);
    await backend.touchGroup(id, at);

    final group = SingleHandGroup(
      sessionId: id,
      name: name,
      gameType: setup.gameType,
      smallBlind: setup.smallBlind,
      bigBlind: setup.bigBlind,
      handCount: handNumber,
      lastHandAt: at,
    );
    await _cacheLastGroup(group);
    AppDataCache.markSessionsDirty();
    AppDataCache.markHomeDirty();
    return SingleHandSaveResult(
      sessionId: id,
      handId: cloudId ?? localId ?? '',
      handNumber: handNumber,
      group: group,
      playerNames: names,
    );
  }

  static Future<int> _safeCount(String groupId) async {
    try {
      return await backend.handCount(groupId);
    } catch (e) {
      await LoggerService.warning('Single hand: hand count failed: $e');
      return 0;
    }
  }

  static Future<String> _nameOf(String groupId) async {
    final cached = await _cachedLastGroup();
    return cached?.sessionId == groupId ? cached!.name : '';
  }

  // ---------------------------------------------------------------------------
  // Last-group cache (offline fallback + name lookup)
  // ---------------------------------------------------------------------------

  static Future<void> _cacheLastGroup(SingleHandGroup g) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _lastGroupKey,
          jsonEncode({
            'id': g.sessionId,
            'sessionType': kHandGroupSessionType,
            'sessionName': g.name,
            'gameType': g.gameType.value,
            'smallBlind': g.smallBlind,
            'bigBlind': g.bigBlind,
            'totalHands': g.handCount,
            'endTime': g.lastHandAt.toIso8601String(),
          }));
    } catch (_) {
      // Convenience cache only.
    }
  }

  static Future<SingleHandGroup?> _cachedLastGroup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_lastGroupKey);
      if (raw == null) return null;
      final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return SingleHandGroup.fromSession(m['id'] as String, m);
    } catch (_) {
      return null;
    }
  }
}

/// Firestore + SQLite implementation. Offline: Firestore writes queue, so
/// every awaited cloud write gets a timeout and a timeout is not an error.
class FirebaseSingleHandBackend implements SingleHandBackend {
  static const Duration _cloudWait = Duration(seconds: 4);
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> _queued(Future<void> write, String what) async {
    try {
      await write.timeout(_cloudWait);
    } on TimeoutException {
      await LoggerService.info('Single hand: $what queued (offline?)');
    }
  }

  @override
  Future<List<SingleHandGroup>> loadGroups() async {
    final uid = AuthService.userId;
    if (uid == null) return const [];
    try {
      // Two equality filters: no composite index. Sorted by the caller.
      final snap = await _db
          .collection('poker_sessions')
          .where('userId', isEqualTo: uid)
          .where('sessionType', isEqualTo: kHandGroupSessionType)
          .get()
          .timeout(_cloudWait);
      return [
        for (final d in snap.docs)
          if (SingleHandGroup.fromSession(d.id, d.data()) case final g?) g
      ];
    } catch (_) {
      final local =
          await LocalStorageService.getUserSessions(includeHandGroups: true);
      return [
        for (final s in local)
          if (SingleHandGroup.fromSession('${s['id']}', s) case final g?) g
      ];
    }
  }

  @override
  Future<int> handCount(String groupId) async {
    try {
      final doc = await _db
          .collection('poker_sessions')
          .doc(groupId)
          .get()
          .timeout(_cloudWait);
      final n = (doc.data()?['totalHands'] as num?)?.toInt();
      if (n != null) return n;
    } catch (_) {}
    final local = await LocalStorageService.getSession(groupId);
    return (local?['totalHands'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> createGroup({
    required String groupId,
    required String name,
    required SingleHandSetup setup,
  }) async {
    final nowIso = DateTime.now().toIso8601String();
    await LocalStorageService.saveSession(
      sessionId: groupId,
      smallBlind: setup.smallBlind,
      bigBlind: setup.bigBlind,
      playerCount: setup.playerCount,
      startTime: nowIso,
      endTime: nowIso,
      ourSeatNumber: SingleHandSetup.heroSeat,
      gameType: setup.gameType,
      sessionType: kHandGroupSessionType,
      sessionName: name,
    );
    await _queued(
      FirebaseService.createSession(
        smallBlind: setup.smallBlind,
        bigBlind: setup.bigBlind,
        playerCount: setup.playerCount,
        ourSeatNumber: SingleHandSetup.heroSeat,
        gameType: setup.gameType,
        sessionName: name,
        hasBBante: setup.hasBBante,
        sessionType: kHandGroupSessionType,
        sessionId: groupId,
      ),
      'group create',
    );
  }

  @override
  Future<(String?, String?)> writeHand({
    required String groupId,
    required int handNumber,
    required HandRecord hand,
    required SingleHandSetup setup,
    required Map<int, String> playerNames,
    Map<int, String>? playerIds,
  }) async {
    final names = playerNames;
    final actions = hand.actions.map((a) => a.toMap()).toList();
    // SQLite first (it bumps the local group totalHands itself).
    final localId = await LocalStorageService.saveHand(
      sessionId: groupId,
      handNumber: handNumber,
      buttonPosition: hand.buttonPosition,
      playerCount: hand.playerCount,
      actions: actions,
      startTime: hand.startTime.toIso8601String(),
      endTime: hand.endTime?.toIso8601String(),
      boardCards: hand.boardCards?.toMap(),
      ourHoleCards: hand.ourHoleCards?.toMap(),
      showdownData: hand.showdownData?.toMap(),
      reachedShowdown: hand.reachedShowdown,
      potAmount: hand.potAmount,
      preflopPot: hand.preflopPot,
      flopPot: hand.flopPot,
      turnPot: hand.turnPot,
      riverPot: hand.riverPot,
      winnerId: hand.winnerId,
      playerNames: names,
      smallBlind: setup.smallBlind,
      bigBlind: setup.bigBlind,
      gameType: setup.gameType.name,
      isChoppedPot: hand.isChoppedPot,
      isSplitPot: hand.isSplitPot,
      choppedWinners: hand.choppedWinners,
      individualShares: hand.individualShares,
      sharePerWinner: hand.sharePerWinner,
      isStarred: hand.isStarred,
      tags: hand.tags,
      notes: hand.notes,
      bbSeat: hand.bbSeat,
      sbSeat: hand.sbSeat,
      smallBlindDead: hand.smallBlindDead,
    );
    hand.localHandId = localId;

    String? cloudId;
    try {
      // skipStats: no user stats, no opponent stats, no range grid.
      cloudId = await FirebaseService.saveHand(
        sessionId: groupId,
        handNumber: handNumber,
        buttonPosition: hand.buttonPosition,
        actions: actions,
        playerCount: hand.playerCount,
        boardCards: hand.boardCards?.toMap(),
        ourHoleCards: hand.ourHoleCards?.toMap(),
        showdownData: hand.showdownData?.toMap(),
        reachedShowdown: hand.reachedShowdown,
        potAmount: hand.potAmount,
        preflopPot: hand.preflopPot,
        flopPot: hand.flopPot,
        turnPot: hand.turnPot,
        riverPot: hand.riverPot,
        winnerId: hand.winnerId,
        heroPositionName: hand.heroPositionName,
        heroSeatNumber: hand.heroSeatNumber ?? SingleHandSetup.heroSeat,
        playerNames: names,
        smallBlind: setup.smallBlind,
        bigBlind: setup.bigBlind,
        gameType: setup.gameType.name,
        isChoppedPot: hand.isChoppedPot,
        isSplitPot: hand.isSplitPot,
        choppedWinners: hand.choppedWinners,
        individualShares: hand.individualShares,
        sharePerWinner: hand.sharePerWinner,
        isStarred: hand.isStarred,
        tags: hand.tags,
        notes: hand.notes,
        playerIds: playerIds,
        skipStats: true,
        bbSeat: hand.bbSeat,
        sbSeat: hand.sbSeat,
        smallBlindDead: hand.smallBlindDead,
        analyticsExtras: {'mode': 'single', 'group_hand_number': handNumber},
      ).timeout(_cloudWait);
      hand.cloudHandId = cloudId;
    } on TimeoutException {
      await LoggerService.info('Single hand: cloud save queued (offline?)');
    } catch (e) {
      await LoggerService.error('Single hand: cloud save failed, kept locally',
          e, StackTrace.current);
    }
    return (cloudId, localId);
  }

  @override
  Future<void> touchGroup(String groupId, DateTime at) async {
    await LocalStorageService.endSession(groupId, at.toIso8601String());
    try {
      await _queued(
        _db
            .collection('poker_sessions')
            .doc(groupId)
            .update({'endTime': FieldValue.serverTimestamp()}),
        'group touch',
      );
    } catch (e) {
      await LoggerService.warning('Single hand: group touch failed: $e');
    }
  }
}
