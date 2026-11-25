import 'dart:async';

import 'package:flutter/material.dart';

import '../design_system/constants/colors.dart';
import '../models/game_types.dart';
import '../models/tracked_session.dart';
import '../services/live_session_logic.dart';
import '../services/live_session_notification_service.dart';
import '../services/session_navigation.dart';
import '../services/tracked_session_service.dart';
import '../widgets/single_hand/single_hand_flow.dart';
import 'session_details_screen.dart';

/// Opens the Track-a-session hub (`SessionDetailsScreen` in tracked mode) and
/// plugs tracked sessions into the running-session hooks.
class TrackedSessionHub {
  TrackedSessionHub._();

  /// The hub for [session]; [doc] (the stored session doc) restores the stack
  /// and history when the session is reopened later.
  static Widget screenFor(TrackedSession session,
      {Map<String, dynamic>? doc}) {
    final history = doc?['stackHistory'];
    return SessionDetailsScreen(
      sessionName: session.name,
      buyInAmount: session.buyIn,
      startingStack: session.startingStack,
      gameType: session.gameType,
      smallBlind: 0,
      bigBlind: 0,
      hasBBante: false,
      currentStack: (doc?['currentStack'] as num?)?.toDouble(),
      sessionId: session.id,
      startTime: session.startTime,
      liveStackHistory: history is List
          ? [for (final e in history) Map<String, dynamic>.from(e as Map)]
          : null,
      tracked: session,
    );
  }

  /// Opens the hub for [sessionId] at once (the screen loads the session doc
  /// itself and shows a loading state meanwhile). Single-flight: when the hub
  /// is already on the stack it pops back to it instead of pushing another.
  /// Returns right after the push; use [openAndWait] to wait for the close.
  static Future<bool> open(NavigatorState nav, String sessionId) async {
    unawaited(openAndWait(nav, sessionId));
    return true;
  }

  /// Like [open], but completes when the hub is closed.
  static Future<void> openAndWait(NavigatorState nav, String sessionId) =>
      SessionNavigation.openOnce<void>(
          nav,
          SessionNavigation.hubKey(sessionId),
          () => MaterialPageRoute<void>(
              builder: (_) => TrackedHubLoader(sessionId: sessionId)));

  /// Replaces the setup screen with the hub of a session just started.
  static void replaceWithHub(NavigatorState nav, TrackedSession session) {
    final route = MaterialPageRoute<void>(builder: (_) => screenFor(session));
    SessionNavigation.track(SessionNavigation.hubKey(session.id), route);
    nav.pushReplacement(route);
  }

  /// Installs the tracked-session handlers into [LiveSessionHooks], chaining
  /// to whatever handler was set before (full sessions). Call once at start.
  static void registerHooks() {
    final prevOpen = LiveSessionHooks.openSession;
    final prevLog = LiveSessionHooks.logHand;
    final prevEnd = LiveSessionHooks.endSession;

    LiveSessionHooks.openSession = (nav, r) async {
      if (r.kind == LiveSessionRecord.kindTracked) {
        return open(nav, r.sessionId);
      }
      return prevOpen != null && await prevOpen(nav, r);
    };
    LiveSessionHooks.logHand = (nav, r) async {
      if (r.kind == LiveSessionRecord.kindTracked) {
        final target = SingleHandSessionTarget(r.sessionId, r.name,
            r.gameType == 'tournament' ? GameType.tournament : GameType.cash);
        if (!nav.mounted) return false;
        await SessionNavigation.runOnce(
            'log:${r.sessionId}',
            () => SingleHandFlow.run(nav.context, session: target));
        return true;
      }
      return prevLog != null && await prevLog(nav, r);
    };
    LiveSessionHooks.endSession = (r, end) async {
      if (r.kind == LiveSessionRecord.kindTracked) {
        return TrackedSessionService.endWithoutSheet(r.sessionId, end);
      }
      // Full sessions: their owner's hook, else the plain end-time stamp.
      return prevEnd != null
          ? prevEnd(r, end)
          : LiveSessionNotificationService.defaultEnd(r, end);
    };
  }
}

/// The hub route's page: shown at once, loads the session doc inside (loading
/// state), then becomes the hub. A session that is gone or already ended
/// closes the screen.
class TrackedHubLoader extends StatefulWidget {
  final String sessionId;
  const TrackedHubLoader({super.key, required this.sessionId});

  @override
  State<TrackedHubLoader> createState() => _TrackedHubLoaderState();
}

class _TrackedHubLoaderState extends State<TrackedHubLoader> {
  Widget? _hub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Map<String, dynamic>? doc;
    try {
      doc = await TrackedSessionService.loadDoc(widget.sessionId);
    } catch (_) {}
    if (!mounted) return;
    final session = (doc == null || doc['endTime'] != null)
        ? null
        : TrackedSession.fromSession(widget.sessionId, doc);
    if (session == null) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _hub = TrackedSessionHub.screenFor(session, doc: doc));
  }

  @override
  Widget build(BuildContext context) {
    return _hub ??
        const Scaffold(
          backgroundColor: AppColors.bgPrimary,
          body: Center(
              child: CircularProgressIndicator(color: AppColors.accentPrimary)),
        );
  }
}
