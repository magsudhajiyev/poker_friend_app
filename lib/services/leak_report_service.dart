import 'package:cloud_firestore/cloud_firestore.dart';

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

      for (final session in sessions.docs) {
        final data = session.data();
        if (data['isTutorial'] == true) continue;
        if (data['isIndividualSession'] == true) continue;
        if ((data['totalHands'] as num? ?? 0) == 0) continue;

        final hands = await firestore
            .collection('poker_sessions')
            .doc(session.id)
            .collection('poker_hands')
            .get();
        for (final hand in hands.docs) {
          final data = hand.data();
          // Same key shape as the range grid uses for hand lookups.
          final ref = '${session.id}:${data['handNumber'] ?? hand.id}';
          final extracted = LeakExtractor.extract(data, ref: ref);
          if (extracted != null) {
            facts.add(extracted);
            handsByRef[ref] = data;
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
