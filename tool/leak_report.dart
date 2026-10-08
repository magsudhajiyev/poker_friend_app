// Dev harness: run the REAL leak extractor + engine over a JSON dump of
// hand maps (list of Firestore hand documents as plain JSON).
//
//   dart run tool/leak_report.dart /path/to/hands.json
//
// Keep lib/services/leak_extractor.dart and leak_engine.dart free of
// Flutter imports so this stays runnable from the command line.
import 'dart:convert';
import 'dart:io';

import '../lib/services/leak_engine.dart';
import '../lib/services/leak_extractor.dart';

void main(List<String> args) {
  final raw = jsonDecode(File(args.first).readAsStringSync()) as List;
  final facts = <LeakHandFacts>[];
  var skipped = 0;
  for (final h in raw) {
    final map = Map<String, dynamic>.from(h as Map);
    final f = LeakExtractor.extract(map, ref: 'dump:${map['handNumber']}');
    if (f == null) {
      skipped++;
    } else {
      facts.add(f);
    }
  }

  final report = LeakEngine.analyze(facts);
  String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

  print('hands in dump: ${raw.length}  (skipped: $skipped, '
      'walks excluded by engine)');
  print('hands analyzed: ${report.handsAnalyzed}\n');

  print('── COACH SUMMARY ──');
  print('${report.coachSummary}\n');

  print('── DETECTED LEAKS ──');
  for (final f in report.leaks) {
    print('[${f.verdict.name.toUpperCase()}] ${f.title}: ${pct(f.value)} '
        '(healthy ${pct(f.bandLow)}-${pct(f.bandHigh)}, n=${f.sampleCount}, '
        'severity ${(f.severity * 100).round()})');
    print('    meaning: ${f.meaning}');
    print('    cost:    ${f.cost}');
    print('    fix:     ${f.fix}');
    if (f.slices.isNotEmpty) {
      print('    where: ${f.slices.map((sl) => '${sl.label} '
          '${pct(sl.value)} (n=${sl.sampleCount})'
          '${sl.flagged ? ' <FLAG>' : ''}').join(' | ')}');
    }
    if (f.examples.isNotEmpty) {
      print('    examples: ${f.examples.map((e) => '#${e.handNumber}'
          '${e.posGroup != null ? ' ${e.posGroup}' : ''}'
          '${e.holeCards != null ? ' ${e.holeCards}' : ''}'
          '${e.textureLabel != null ? ' ${e.textureLabel}' : ''}'
          '${e.strengthLabel != null ? ' [${e.strengthLabel}]' : ''}').join(', ')}');
    }
    print('');
  }
  if (report.leaks.isEmpty) print('(none)\n');

  print('── HEALTHY ──');
  for (final f in report.healthy) {
    print('${f.title}: ${pct(f.value)} (n=${f.sampleCount})');
    for (final s in f.slices) {
      print('    ${s.label}: ${pct(s.value)} (n=${s.sampleCount})');
    }
  }

  print('\n── MONEY VIEW (BB) ──');
  for (final p in report.positionNets) {
    print('${p.pos.padRight(4)} ${p.netBBTotal >= 0 ? '+' : ''}'
        '${p.netBBTotal.toStringAsFixed(1)}bb total '
        '(${p.netBBPerHand >= 0 ? '+' : ''}${p.netBBPerHand.toStringAsFixed(2)}'
        'bb/hand, n=${p.hands})');
  }
  print('worst spots (total bb lost, n>=6):');
  for (final sp in report.worstSpots) {
    print('  ${sp.label}: ${sp.netBBTotal.toStringAsFixed(1)}bb over '
        '${sp.hands} hands (drill @${sp.presetStackBB.toInt()}bb)');
  }

  print('\n── INSUFFICIENT DATA ──');
  for (final f in report.insufficient) {
    print('${f.title}: n=${f.sampleCount} of ${f.minSample} needed '
        '(so far ${pct(f.value)})');
  }
}
