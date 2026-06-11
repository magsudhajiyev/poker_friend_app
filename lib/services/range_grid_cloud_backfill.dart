import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/hand_state_machine.dart';
import 'auth_service.dart';
import 'firebase_service.dart';
import 'local_storage_service.dart';
import 'range_grid_service.dart';

/// Fetches every hand the hero has ever played from Firestore and indexes
/// it into the local range grid, so the preflop chart is populated with the
/// full history immediately — including hands logged before this feature
/// existed or on other devices.
///
/// Entries are keyed by '{sessionId}:{handNumber}', the same dedupe key the
/// local save path and local backfill use, so a hand present both locally
/// and in the cloud lands on a single row (the merge upsert keeps both ids).
class RangeGridCloudBackfill {
  static const _flagKeyPrefix = 'range_grid_cloud_backfilled_v3_';
  static Future<bool>? _inFlight;

  /// True while a cloud sync is currently running (for UI indicators).
  static bool get isRunning => _inFlight != null;

  /// Runs the cloud backfill once per user (flag-guarded). Returns true
  /// when a sync actually ran and indexed at least one hand, so callers
  /// know to refresh the grid. Safe to call repeatedly.
  static Future<bool> ensureCloudBackfilled({bool force = false}) {
    final existing = _inFlight;
    if (existing != null) return existing;
    final run = _run(force).whenComplete(() => _inFlight = null);
    _inFlight = run;
    return run;
  }

  static Future<bool> _run(bool force) async {
    try {
      final userId = AuthService.userId;
      if (userId == null) return false;

      final prefs = await SharedPreferences.getInstance();
      final flagKey = '$_flagKeyPrefix$userId';
      if (!force && (prefs.getBool(flagKey) ?? false)) return false;

      final sessions = await FirebaseService.getAllSessions();
      int indexed = 0;
      bool anySaveFailed = false;

      for (final session in sessions) {
        final sessionId = session['id'] as String?;
        if (sessionId == null) continue;

        final sessionGameType = session['gameType'] as String? ?? 'cash';
        final sessionBigBlind = (session['bigBlind'] as num?)?.toDouble();
        final sessionHeroSeat = session['ourSeatNumber'] as int?;

        List<Map<String, dynamic>> hands;
        try {
          hands = await FirebaseService.getSessionHands(sessionId);
        } catch (_) {
          continue; // Skip unreadable sessions, keep syncing the rest
        }

        for (final hand in hands) {
          try {
            final entry = _entryFromCloudHand(
              hand: hand,
              sessionId: sessionId,
              userId: userId,
              sessionGameType: sessionGameType,
              sessionBigBlind: sessionBigBlind,
              sessionHeroSeat: sessionHeroSeat,
            );
            if (entry != null) {
              final saved =
                  await LocalStorageService.saveRangeEntry(entry.toDbMap());
              if (saved) {
                indexed++;
              } else {
                anySaveFailed = true;
              }
            }
          } catch (_) {
            // Skip malformed hands
          }
        }
      }

      // Only mark complete when every entry landed — otherwise retry on a
      // later call (e.g. the table wasn't available yet)
      if (!anySaveFailed) {
        await prefs.setBool(flagKey, true);
      }
      debugPrint('RangeGridCloudBackfill: indexed $indexed cloud hands'
          '${anySaveFailed ? ' (some saves failed — will retry)' : ''}');
      return indexed > 0;
    } catch (e) {
      debugPrint('RangeGridCloudBackfill error: $e');
      return false; // Retry on a later call — flag stays unset
    }
  }

  static RangeGridEntry? _entryFromCloudHand({
    required Map<String, dynamic> hand,
    required String sessionId,
    required String userId,
    required String sessionGameType,
    required double? sessionBigBlind,
    required int? sessionHeroSeat,
  }) {
    final handNumber = hand['handNumber'];
    final cloudHandId = hand['id'] as String?;
    if (handNumber == null || cloudHandId == null) return null;

    final actionsRaw = hand['actions'];
    final actions = actionsRaw is List
        ? actionsRaw
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList()
        : <Map<String, dynamic>>[];

    // Hero seat/position: stored fields first, hero-flagged action fallback
    Map<String, dynamic>? heroAction;
    for (final a in actions) {
      if (a['isCurrentUser'] == true) {
        heroAction = a;
        break;
      }
    }
    final heroSeat = hand['heroSeatNumber'] as int? ??
        sessionHeroSeat ??
        heroAction?['player'] as int?;
    final heroPosition = hand['heroPositionName'] as String? ??
        heroAction?['playerPosition'] as String?;

    final holeCardsRaw = hand['ourHoleCards'];
    final holeCards = holeCardsRaw is Map
        ? HoleCards.fromMap(Map<String, dynamic>.from(holeCardsRaw))
        : null;

    final choppedRaw = hand['choppedWinners'];
    final chopped = choppedRaw is List
        ? choppedRaw.whereType<num>().map((n) => n.toInt()).toList()
        : null;

    final timestamp = DateTime.tryParse(
            (hand['endTime'] ?? hand['startTime'] ?? '') as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);

    return RangeGridService.buildEntry(
      handKey: '$sessionId:$handNumber',
      cloudHandId: cloudHandId,
      sessionId: sessionId,
      userId: userId,
      timestamp: timestamp,
      gameType: hand['gameType'] as String? ?? sessionGameType,
      holeCards: holeCards,
      heroPositionName: heroPosition,
      heroSeat: heroSeat,
      actions: actions,
      bigBlind: (hand['bigBlind'] as num?)?.toDouble() ?? sessionBigBlind ?? 0.0,
      potAmount: (hand['potAmount'] as num?)?.toDouble() ?? 0.0,
      winnerId: (hand['winnerId'] as num?)?.toInt(),
      choppedWinners: chopped,
    );
  }

  /// Fetches a single hand document from Firestore, shaped like the maps
  /// returned by FirebaseService.getSessionHands, so HandActionsScreen can
  /// open hands that only exist in the cloud.
  static Future<Map<String, dynamic>?> fetchHand(
      String sessionId, String cloudHandId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('poker_sessions')
          .doc(sessionId)
          .collection('poker_hands')
          .doc(cloudHandId)
          .get();
      final data = doc.data();
      if (data == null) return null;

      String? parseTime(dynamic value) {
        if (value is Timestamp) return value.toDate().toIso8601String();
        if (value is String) return value;
        return null;
      }

      return {
        'id': doc.id,
        'sessionId': sessionId,
        ...data,
        'startTime':
            parseTime(data['startTime']) ?? DateTime.now().toIso8601String(),
        'endTime': parseTime(data['endTime']),
      };
    } catch (e) {
      debugPrint('RangeGridCloudBackfill.fetchHand error: $e');
      return null;
    }
  }
}
