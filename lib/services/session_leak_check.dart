import 'firebase_service.dart';
import 'leak_engine.dart';
import 'leak_extractor.dart';
import 'leak_focus_store.dart';
import 'leak_snapshot_store.dart';

/// Session-end leak check — the per-session hook of the Leak Detector
/// retention loop (see docs/features/leak-detector-retention.md).
///
/// Produces at most ONE line for the session summary: either "how this
/// session compared to your usual" on the most notable detector, or "how
/// much closer this session got you to your next unlock". Everything is
/// FACTUAL COUNTING ("you folded 5 of 6 river spots") compared against the
/// stored overall value — never a verdict on a session-sized sample, per
/// the Leak Detector's sample-honesty principle.
enum SessionLeakChipKind {
  /// Session rate meaningfully above the player's overall rate.
  aboveUsual,

  /// Session rate meaningfully below the player's overall rate.
  belowUsual,

  /// Session in line with the player's overall rate.
  nearUsual,

  /// No baseline to compare against (player hasn't opened the report yet,
  /// or the detector has no verdict) — plain session fact, doubles as the
  /// feature's introduction hook.
  factOnly,

  /// This session added spots toward an un-unlocked detector.
  unlockProgress,

  /// The session pushed a detector past its minimum sample — the next
  /// report will carry a verdict.
  unlockReady,

  /// Floor for short sessions: nothing comparable or unlockable, but the
  /// session still banked hands/spots. A session must never end in
  /// silence — silence reads as "broken".
  sessionBanked,
}

class SessionLeakChipData {
  final SessionLeakChipKind kind;
  final String findingId;
  final String title;

  /// Session-level tally (highlight kinds).
  final int hits;
  final int spots;
  final double sessionRate;

  /// The player's overall rate from the last report snapshot, when known.
  final double? usualRate;

  /// The detector is currently flagged as a leak in the snapshot — the
  /// chip relates to the thing the player should be working on.
  final bool relatesToCurrentLeak;

  /// Spots still missing after this session (unlock kinds; 0 = ready).
  final int remainingToUnlock;

  /// Hands this session fed into the detectors (sessionBanked kind).
  final int handsAnalyzed;

  const SessionLeakChipData({
    required this.kind,
    required this.findingId,
    required this.title,
    this.hits = 0,
    this.spots = 0,
    this.sessionRate = 0,
    this.usualRate,
    this.relatesToCurrentLeak = false,
    this.remainingToUnlock = 0,
    this.handsAnalyzed = 0,
  });

  bool get isUnlockKind =>
      kind == SessionLeakChipKind.unlockProgress ||
      kind == SessionLeakChipKind.unlockReady;
}

class SessionLeakCheck {
  SessionLeakCheck._();

  /// A session tally below this many spots is too thin to even mention.
  static const int minSpots = 3;

  /// |session − usual| below this reads as "in line with your usual".
  static const double nearThreshold = 0.10;

  /// Loads the session's saved hands + the last report snapshot and
  /// evaluates. Returns null when there is nothing worth a chip.
  static Future<SessionLeakChipData?> evaluateSession(
      String sessionId) async {
    final hands = await FirebaseService.getSessionHands(sessionId);
    final snapshot = await LeakSnapshotStore.load();
    final focus = await LeakFocusStore.loadFocus();
    return evaluate(
        hands: hands, snapshot: snapshot, focusFindingId: focus?.findingId);
  }

  /// Pure core — unit-tested. [hands] are Firestore-format hand maps of
  /// ONE session; [snapshot] is the player's last leak-report snapshot
  /// (null when they have never opened the report); [focusFindingId] is
  /// the player's active focus goal — it outranks everything else, so the
  /// chip reports progress on the thing they committed to.
  static SessionLeakChipData? evaluate({
    required List<Map<String, dynamic>> hands,
    required LeakSnapshot? snapshot,
    String? focusFindingId,
  }) {
    if (hands.isEmpty) return null;

    // Same pipeline as the report, scoped to this session's hands. The
    // extractor already drops scouted hands; the engine drops walks.
    final facts = <LeakHandFacts>[];
    for (final hand in hands) {
      final f = LeakExtractor.extract(hand);
      if (f != null) facts.add(f);
    }
    if (facts.isEmpty) return null;
    final session = LeakEngine.analyze(facts);

    // ── Candidate highlights: detectors with a real session tally ──
    SessionLeakChipData? best;
    var bestScore = double.negativeInfinity;
    for (final f in session.findings) {
      if (f.id.contains('@')) continue; // top-level detectors only
      if (f.sampleCount < minSpots) continue;

      final prev = snapshot?.entries[f.id];
      final usual =
          (prev != null && prev.verdict != LeakVerdict.insufficientData)
              ? prev.value
              : null;
      final relatesToLeak = prev?.isLeak ?? false;
      final delta = usual != null ? (f.value - usual).abs() : 0.0;

      // The chip exists to connect the session to the player's story:
      // their FOCUS goal outranks everything, then their current leak,
      // then the biggest deviation from usual, then raw sample size.
      final score = (f.id == focusFindingId ? 5000.0 : 0.0) +
          (relatesToLeak ? 1000.0 : 0.0) +
          delta * 100 +
          f.sampleCount.toDouble();
      if (score <= bestScore) continue;
      bestScore = score;

      final kind = usual == null
          ? SessionLeakChipKind.factOnly
          : (f.value - usual) >= nearThreshold
              ? SessionLeakChipKind.aboveUsual
              : (usual - f.value) >= nearThreshold
                  ? SessionLeakChipKind.belowUsual
                  : SessionLeakChipKind.nearUsual;

      best = SessionLeakChipData(
        kind: kind,
        findingId: f.id,
        title: f.title,
        hits: (f.value * f.sampleCount).round(),
        spots: f.sampleCount,
        sessionRate: f.value,
        usualRate: usual,
        relatesToCurrentLeak: relatesToLeak,
      );
    }

    // ── Unlock progress: this session's spots against locked detectors ──
    SessionLeakChipData? unlock;
    if (snapshot != null) {
      var bestRemaining = 1 << 30;
      for (final f in session.findings) {
        if (f.id.contains('@') || f.sampleCount == 0) continue;
        final prev = snapshot.entries[f.id];
        if (prev == null ||
            prev.verdict != LeakVerdict.insufficientData) {
          continue;
        }
        final remaining =
            (f.minSample - (prev.sampleCount + f.sampleCount))
                .clamp(0, f.minSample);
        if (remaining < bestRemaining) {
          bestRemaining = remaining;
          unlock = SessionLeakChipData(
            kind: remaining == 0
                ? SessionLeakChipKind.unlockReady
                : SessionLeakChipKind.unlockProgress,
            findingId: f.id,
            title: f.title,
            spots: f.sampleCount,
            remainingToUnlock: remaining,
          );
        }
      }
    }

    // ── Pick one line ──
    // A comparison against the player's own baseline (especially on their
    // current leak) beats everything; a just-unlocked detector beats a
    // bare fact; progress is the fallback that still gives the session
    // a meaning.
    if (best != null &&
        (best.relatesToCurrentLeak || best.usualRate != null)) {
      return best;
    }
    if (unlock != null && unlock.kind == SessionLeakChipKind.unlockReady) {
      return unlock;
    }
    if (best != null || unlock != null) return best ?? unlock;

    // Floor: short sessions still get an acknowledgement — hands and
    // spots banked toward future verdicts. Pure counting, zero claims.
    var bankedSpots = 0;
    for (final f in session.findings) {
      if (!f.id.contains('@')) bankedSpots += f.sampleCount;
    }
    return SessionLeakChipData(
      kind: SessionLeakChipKind.sessionBanked,
      findingId: 'session',
      title: 'Session banked',
      spots: bankedSpots,
      handsAnalyzed: session.handsAnalyzed,
    );
  }
}
