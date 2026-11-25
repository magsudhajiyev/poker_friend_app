import 'game_types.dart';
import 'single_hand_group.dart';

/// Session `sessionType` of a tracked session ("Track a session"): a real
/// session for money, time and bankroll that only holds single hands. Absent
/// on every normal session.
const String kTrackedSessionType = 'tracked';

/// True when a session map (Firestore or SQLite) is a tracked session.
bool isTrackedSession(Map<String, dynamic> session) =>
    session['sessionType'] == kTrackedSessionType;

/// True for sessions whose hands must never reach HAND stats (VPIP/PFR,
/// opponent stats, range grid, Leak Detector, recalculation): hand groups and
/// tracked sessions. Money and session aggregates still include tracked ones.
bool skipsHandStats(Map<String, dynamic> session) =>
    isHandGroupSession(session) || isTrackedSession(session);

/// Where a "Log a hand" hand is saved when a tracked session is the target:
/// INSIDE that session (D17). Only its name and game type shape the setup.
///
/// [isFull]: the running session is a FULL logging session. Single hands are
/// never mixed into it (they would bias its stats); choosing it on the setup
/// screen resumes its logging table instead.
class SingleHandSessionTarget {
  final String id;
  final String name;
  final GameType gameType;
  final bool isFull;
  const SingleHandSessionTarget(this.id, this.name, this.gameType,
      {this.isFull = false});
}
