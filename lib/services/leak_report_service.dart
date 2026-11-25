import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/single_hand_group.dart';
import 'auth_service.dart';
import 'leak_engine.dart';
import 'leak_extractor.dart';
import 'logger_service.dart';

/// LEAK DETECTOR (phase 1) — data loading + report assembly.
///
/// Fetches all of the signed-in user's logged hands from Firestore and runs
/// the pure extractor/engine over them. Read-time aggregation by design —
/// no incremental counters to corrupt (see the stats double-counting bug
/// history). Excludes tutorial sessions, individual (quick) sessions and
/// scouted hands.
/// Report + the raw hand maps behind it, keyed by example ref — the screen
/// uses these to open HandActionsScreen for "show me the hand".
class LeakReportBundle {
  final LeakReport report;
  final Map<String, Map<String, dynamic>> handsByRef;
  const LeakReportBundle(this.report, this.handsByRef);
}

class LeakReportService {
  LeakReportService._();

  static const int _fetchChunk = 8;

  static Future<LeakReportBundle> generate() async {
    final userId = AuthService.userId;
    if (userId == null) {
      return const LeakReportBundle(
          LeakReport(findings: [], handsAnalyzed: 0), {});
    }

    final firestore = FirebaseFirestore.instance;
    final facts = <LeakHandFacts>[];
    final handsByRef = <String, Map<String, dynamic>>{};

    try {
      final sessions = await firestore
          .collection('poker_sessions')
          .where('userId', isEqualTo: userId)
          .get();

      final eligible = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      for (final session in sessions.docs) {
        final data = session.data();
        if (data['isTutorial'] == true) continue;
        if (data['isIndividualSession'] == true) continue;
        // Single hands are hand-picked (mostly played hands): they would bias
        // every frequency band.
        if (isHandGroupSession(data)) continue;
        if ((data['totalHands'] as num? ?? 0) == 0) continue;
        eligible.add(session);
      }

      // Bounded parallel fetch; results are consumed in the original session
      // order so the output is identical to the old serial loop.
      for (var i = 0; i < eligible.length; i += _fetchChunk) {
        final chunk = eligible.skip(i).take(_fetchChunk).toList();
        final snaps = await Future.wait(chunk.map((session) => firestore
            .collection('poker_sessions')
            .doc(session.id)
            .collection('poker_hands')
            .get()));
        for (var j = 0; j < chunk.length; j++) {
          final sessionId = chunk[j].id;
          for (final hand in snaps[j].docs) {
            final data = hand.data();
            // Same key shape as the range grid uses for hand lookups.
            final ref = '$sessionId:${data['handNumber'] ?? hand.id}';
            final extracted = LeakExtractor.extract(data, ref: ref);
            if (extracted != null) {
              facts.add(extracted);
              handsByRef[ref] = data;
            }
          }
        }
      }
    } catch (e) {
      await LoggerService.error(
          'Leak report: hand fetch failed', e, StackTrace.current);
      rethrow;
    }

    return LeakReportBundle(LeakEngine.analyze(facts), handsByRef);
  }
}
