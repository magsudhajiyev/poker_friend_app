// Web-parity golden generator + staleness check. See README.md here.
//
//   UPDATE_GOLDENS=1 flutter test test/web_parity/generate_goldens_test.dart
//
// regenerates test/fixtures/web_parity/expected/*.json. Without the env var
// the same computation runs and the test FAILS if any golden differs from
// what the current Dart code produces (or if a golden is orphaned).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/hand_completeness.dart';
import 'package:poker_logger/models/hand_state_machine.dart';
import 'package:poker_logger/services/board_texture.dart';
import 'package:poker_logger/services/csv_export_service.dart';
import 'package:poker_logger/services/drill_gto_charts.dart';
import 'package:poker_logger/services/drill_hand_strength.dart';
import 'package:poker_logger/services/flop_strength.dart';
import 'package:poker_logger/services/leak_engine.dart';
import 'package:poker_logger/services/leak_extractor.dart';
import 'package:poker_logger/services/pokerstars_export_service.dart';
import 'package:poker_logger/services/range_grid_service.dart';
import 'package:poker_logger/services/range_shape_service.dart';
import 'package:poker_logger/services/stats_calculator.dart';

typedef Json = Map<String, dynamic>;

const _root = 'test/fixtures/web_parity';
const _userId = 'parity-user';

/// Leak engine multiplicities: the corpus is replayed N times (refs get a
/// `#k` suffix) so verdict branches that need large samples are exercised.
const _multiplicities = [1, 6, 20];

// ── Deterministic JSON ────────────────────────────────────────────────

Object? _canon(Object? v) {
  if (v is Map) {
    final keys = v.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in keys) k: _canon(v[k])};
  }
  if (v is List) return v.map(_canon).toList();
  if (v is double && !v.isFinite) return v.toString();
  return v;
}

String _encode(Object? v) =>
    '${const JsonEncoder.withIndent('  ').convert(_canon(v))}\n';

// ── Loading ───────────────────────────────────────────────────────────

List<File> _jsonFiles(String dir) => Directory('$_root/$dir')
    .listSync()
    .whereType<File>()
    .where((f) => f.path.endsWith('.json'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

String _id(File f) => f.uri.pathSegments.last.replaceAll('.json', '');

Json _read(File f) => jsonDecode(f.readAsStringSync()) as Json;

// ── Stats ─────────────────────────────────────────────────────────────

List<Json> _actions(Json hand) => (hand['actions'] as List)
    .map((a) => Map<String, dynamic>.from(a as Map))
    .toList();

Json _seatFlags(List<Json> a, int seat) => {
      'foldedPreflop': StatsCalculator.playerFoldedPreflop(a, seat),
      'threeBet': StatsCalculator.didPlayerThreeBet(a, seat),
      'threeBetOpportunity': StatsCalculator.hadThreeBetOpportunity(a, seat),
      'facedThreeBet': StatsCalculator.facedThreeBet(a, seat),
      'foldToThreeBet': StatsCalculator.didFoldTo3Bet(a, seat),
      'cbetOpportunity': StatsCalculator.hadCbetOpportunity(a, seat),
      'cbet': StatsCalculator.didCbet(a, seat),
      'stealOpportunity': StatsCalculator.hadStealOpportunity(a, seat),
      'steal': StatsCalculator.didSteal(a, seat),
      'checkRaiseOpportunity':
          StatsCalculator.hadCheckRaiseFlopOpportunity(a, seat),
      'checkRaise': StatsCalculator.didCheckRaiseFlop(a, seat),
      'isBigBlind': StatsCalculator.isBigBlind(a, seat),
      'isSmallBlind': StatsCalculator.isSmallBlind(a, seat),
      'blindDefendOpportunity':
          StatsCalculator.hadBlindDefendOpportunity(a, seat),
      'blindDefend': StatsCalculator.didBlindDefend(a, seat),
    };

Json _stats(Json hand) {
  final a = _actions(hand);
  final seats = <int>{
    ...(hand['playerNames'] as Map).keys.map((k) => int.parse(k as String)),
    ...a.map((x) => x['player'] as int),
  }.toList()
    ..sort();
  final heroSeat = hand['heroSeatNumber'] as int?;
  return {
    'heroSeat': heroSeat,
    'isWalk': StatsCalculator.isWalkHand(a),
    'bigBlindSeat': StatsCalculator.findBigBlindSeat(a),
    'smallBlindSeat': StatsCalculator.findSmallBlindSeat(a),
    'hero': heroSeat == null ? null : _seatFlags(a, heroSeat),
    'seats': {for (final s in seats) '$s': _seatFlags(a, s)},
    'actionFlags': [
      for (final x in a)
        {
          'isBlind': StatsCalculator.isBlindAction(x),
          'isRaise': StatsCalculator.isRaiseAction(x['action'] as String),
          'isBet': StatsCalculator.isBetAction(x['action'] as String),
          'isAggressive':
              StatsCalculator.isAggressiveAction(x['action'] as String),
        }
    ],
  };
}

// ── Leak facts / report ───────────────────────────────────────────────

String? _texLabel(BoardTexture? t) => t?.name;

Json? _facts(LeakHandFacts? f) {
  if (f == null) return null;
  return {
    'ref': f.ref,
    'isWalk': f.isWalk,
    'flopTexture': _texLabel(f.flopTexture),
    'posGroup': f.posGroup,
    'holeCards': f.holeCards,
    'flopStrength': f.flopStrength?.name,
    'netBB': f.netBB,
    'stackBB': f.stackBB,
    'openerPosGroup': f.openerPosGroup,
    'heroVpip': f.heroVpip,
    'openedPot': f.openedPot,
    'facedThreeBetAfterOpen': f.facedThreeBetAfterOpen,
    'foldedToThreeBet': f.foldedToThreeBet,
    'limped': f.limped,
    'limpFacedRaise': f.limpFacedRaise,
    'limpFolded': f.limpFolded,
    'bbFacedSteal': f.bbFacedSteal,
    'bbFoldedToSteal': f.bbFoldedToSteal,
    'flopFacingResponse': f.flopFacingResponse,
    'turnFacingResponse': f.turnFacingResponse,
    'riverFacingResponse': f.riverFacingResponse,
    'sawFlop': f.sawFlop,
    'wentToShowdown': f.wentToShowdown,
    'wonAtShowdown': f.wonAtShowdown,
    'wonWithoutShowdown': f.wonWithoutShowdown,
  };
}

Json _finding(LeakFinding f) => {
      'id': f.id,
      'title': f.title,
      'value': f.value,
      'bandLow': f.bandLow,
      'bandHigh': f.bandHigh,
      'sampleCount': f.sampleCount,
      'minSample': f.minSample,
      'verdict': f.verdict.name,
      'aboveBand': f.aboveBand,
      'isLeak': f.isLeak,
      'severity': f.severity,
      'meaning': f.meaning,
      'cost': f.cost,
      'fix': f.fix,
      'practiceHint': f.practiceHint,
      'examples': [
        for (final e in f.examples)
          {
            'ref': e.ref,
            'handNumber': e.handNumber,
            'posGroup': e.posGroup,
            'textureLabel': e.textureLabel,
            'holeCards': e.holeCards,
            'strengthLabel': e.strengthLabel,
          }
      ],
      'slices': [
        for (final s in f.slices)
          {
            'label': s.label,
            'value': s.value,
            'sampleCount': s.sampleCount,
            'flagged': s.flagged,
          }
      ],
    };

Json _report(LeakReport r) => {
      'handsAnalyzed': r.handsAnalyzed,
      'coachSummary': r.coachSummary,
      'findings': r.findings.map(_finding).toList(),
      'leakIds': r.leaks.map((f) => f.id).toList(),
      'healthyIds': r.healthy.map((f) => f.id).toList(),
      'insufficientIds': r.insufficient.map((f) => f.id).toList(),
      'positionNets': [
        for (final p in r.positionNets)
          {
            'pos': p.pos,
            'netBBTotal': p.netBBTotal,
            'hands': p.hands,
            'netBBPerHand': p.netBBPerHand,
          }
      ],
      'worstSpots': [
        for (final s in r.worstSpots)
          {
            'label': s.label,
            'netBBTotal': s.netBBTotal,
            'hands': s.hands,
            'presetStackBB': s.presetStackBB,
          }
      ],
    };

// ── Range grid ────────────────────────────────────────────────────────

/// Mirrors RangeGridCloudBackfill._entryFromCloudHand (private there) so the
/// golden reflects exactly what a cloud hand would index as.
RangeGridEntry? _rangeEntry(Json hand, Json session) {
  final a = _actions(hand);
  Json? heroAction;
  for (final x in a) {
    if (x['isCurrentUser'] == true) {
      heroAction = x;
      break;
    }
  }
  final heroSeat =
      hand['heroSeatNumber'] as int? ?? heroAction?['player'] as int?;
  final heroPos = hand['heroPositionName'] as String? ??
      heroAction?['playerPosition'] as String?;
  final holeRaw = hand['ourHoleCards'];
  final hole = holeRaw is Map
      ? HoleCards.fromMap(Map<String, dynamic>.from(holeRaw))
      : null;
  final choppedRaw = hand['choppedWinners'];
  final chopped = choppedRaw is List
      ? choppedRaw.whereType<num>().map((n) => n.toInt()).toList()
      : null;
  final ts = DateTime.tryParse(
          (hand['endTime'] ?? hand['startTime'] ?? '') as String? ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);
  return RangeGridService.buildEntry(
    handKey: '${hand['sessionId']}:${hand['handNumber']}',
    cloudHandId: hand['id'] as String?,
    sessionId: hand['sessionId'] as String,
    userId: _userId,
    timestamp: ts,
    gameType: hand['gameType'] as String? ?? 'cash',
    holeCards: hole,
    heroPositionName: heroPos,
    heroSeat: heroSeat,
    actions: a,
    bigBlind: (hand['bigBlind'] as num?)?.toDouble() ??
        (session['bigBlind'] as num?)?.toDouble() ??
        0.0,
    potAmount: (hand['potAmount'] as num?)?.toDouble() ?? 0.0,
    winnerId: (hand['winnerId'] as num?)?.toInt(),
    choppedWinners: chopped,
    completeness: HandCompletenessX.fromHandMap(hand),
  );
}

Json? _entryJson(RangeGridEntry? e) {
  if (e == null) return null;
  return {
    'handKey': e.handKey,
    'cloudHandId': e.cloudHandId,
    'sessionId': e.sessionId,
    'userId': e.userId,
    'timestamp': e.timestamp,
    'gameType': e.gameType,
    'handClass': e.handClass,
    'position': e.position,
    'posGroup': e.posGroup,
    'stackBB': e.stackBB,
    'stackBucket': e.stackBucket,
    'primaryAction': e.primaryAction,
    'scenario': e.scenario,
    'preflopLine': e.preflopLine,
    'potBB': e.potBB,
    'won': e.won,
  };
}

/// Pure replica of LocalStorageService.aggregateRangeByHandClass (SQL
/// `GROUP BY handClass, primaryAction`) folded through the real
/// RangeCellAggregate.addingAction.
Json _aggregate(List<RangeGridEntry> entries, String gameType,
    {String? posGroup, String? stackBucket, String? scenario}) {
  final out = <String, RangeCellAggregate>{};
  for (final e in entries) {
    if (e.gameType != gameType) continue;
    if (posGroup != null && e.posGroup != posGroup) continue;
    if (stackBucket != null && e.stackBucket != stackBucket) continue;
    if (scenario != null && e.scenario != scenario) continue;
    out[e.handClass] = (out[e.handClass] ??
            RangeCellAggregate(handClass: e.handClass))
        .addingAction(e.primaryAction, 1);
  }
  return {
    for (final e in out.entries)
      e.key: {
        'allIn': e.value.allInCount,
        'raise': e.value.raiseCount,
        'call': e.value.callCount,
        'fold': e.value.foldCount,
        'check': e.value.checkCount,
        'total': e.value.total,
      }
  };
}

// ── Pure function tables ──────────────────────────────────────────────

Json _functionCases(List<Json> hands) {
  const pairs = <List<String?>>[
    ['A♠', 'K♠'], ['A♠', 'K♦'], ['K♦', 'A♠'], ['7♥', '7♣'], ['10♥', 'J♥'],
    ['2♣', '7♦'], ['T♠', '9♠'], ['A', 'K'], ['', 'K♠'], [null, 'K♠'],
    ['K♠', null], ['Z♠', 'K♠'], [' A♠ ', 'K♦'], ['a♠', 'k♠'], ['1♠', 'K♠'],
    ['AA♠', 'K♠'],
  ];
  const positions = [
    'BB', 'bb', 'SB', 'BTN', 'BU', 'BTN/SB', 'CO', 'UTG', 'UTG+1', 'UTG+2',
    'LJ', 'HJ', 'MP', 'P5', '', 'utg', 'co'
  ];
  const flops = <List<Object?>?>[
    ['K♣', 'K♦', '5♠'], ['K♥', '8♥', '3♥'], ['K♠', '7♦', '2♣'],
    ['T♦', '7♥', '2♣'], ['9♠', '8♦', '7♣'], ['A♠', '2♥', '3♣'],
    ['A♠', '2♥', '9♣'], ['A♠', '5♥', '4♣'], ['Q♠', 'K♥', 'A♣'],
    ['2♠', '3♥', '4♦'], ['K♠', '9♠', '2♦'], ['10♠', '5♦', '2♣'],
    ['K♠', '7♦'], ['K♠', '7♦', '2♣', '3♦'], ['K', '7♦', '2♣'], [1, 2, 3],
    null, <Object?>[],
  ];
  const strengthCases = <List<Object?>>[
    ['K♠Q♥', ['K♣', 'K♦', '5♠']], ['A♥T♥', ['K♥', '8♥', '3♥']],
    ['Q♣J♦', ['K♠', '7♦', '2♣']], ['9♠8♠', ['T♦', '7♥', '2♣']],
    ['Q♦J♣', ['T♠', '8♥', '2♣']], ['A♣K♦', ['J♦', '7♥', '3♣']],
    ['8♣7♣', ['K♠', '8♦', '2♥']], ['5♦5♣', ['Q♠', '9♦', '2♥']],
    ['J♦J♣', ['8♠', '7♦', '2♥']], ['4♣3♦', ['A♠', '2♥', '9♣']],
    ['A♣5♦', ['4♠', '3♥', '9♣']], ['7♣7♦', ['7♥', '4♣', 'K♦']],
    ['A♠K♠', ['Q♠', 'J♠', '2♦']], ['K♣Q♦', ['A♦', 'J♠', '2♦']],
    ['10♥J♥', ['10♠', '5♦', '2♣']], ['K♠Q♥', ['K♣', 'K♦']],
    ['K♠', ['K♣', 'K♦', '5♠']], [null, ['K♣', 'K♦', '5♠']],
    ['K♠Q♥', null], ['K♠Q♥', [1, 2, 3]], ['K♠Q♥', ['K♣', 'Z♦', '5♠']],
  ];

  String? hc(List<String?> p) => RangeGridService.canonicalHandClass(
      HoleCards(card1: p[0], card2: p[1]));

  return {
    'canonicalHandClass': [
      for (final p in pairs) {'card1': p[0], 'card2': p[1], 'result': hc(p)}
    ],
    'positionGroup': [
      for (final p in positions)
        {'position': p, 'result': RangeGridService.positionGroup(p)}
    ],
    'classifyFlop': [
      for (final f in flops)
        {
          'flop': f,
          'result': BoardTextureClassifier.classifyFlop(f)?.name,
          'label': (() {
            final t = BoardTextureClassifier.classifyFlop(f);
            return t == null ? null : BoardTextureClassifier.label(t);
          })(),
        }
    ],
    'flopStrength': [
      for (final c in strengthCases)
        {
          'holeCards': c[0],
          'flop': c[1],
          'result': FlopStrengthClassifier.classify(
                  c[0] as String?, c[1] as List<dynamic>?)
              ?.name,
          'label': (() {
            final s = FlopStrengthClassifier.classify(
                c[0] as String?, c[1] as List<dynamic>?);
            return s == null ? null : FlopStrengthClassifier.label(s);
          })(),
        }
    ],
    'heroStackBB': [
      for (final c in <List<Object?>>[
        [<Json>[], 1, 2.0],
        [
          [
            {'player': 1, 'street': 'preflop', 'playerStack': 100}
          ],
          1,
          0.0
        ],
        [
          [
            {'player': 1, 'street': 'flop', 'playerStack': 150},
            {'player': 1, 'street': 'preflop', 'playerStack': 100}
          ],
          1,
          2.0
        ],
        [
          [
            {'player': 1, 'street': 'flop', 'playerStack': 150}
          ],
          1,
          3.0
        ],
        [
          [
            {'player': 1, 'street': 'preflop', 'playerStack': 0},
            {'player': 1, 'street': 'turn', 'playerStack': 60}
          ],
          1,
          2.0
        ],
        [
          [
            {'player': 2, 'street': 'preflop', 'playerStack': 100}
          ],
          1,
          2.0
        ],
      ])
        {
          'actions': c[0],
          'heroSeat': c[1],
          'bigBlind': c[2],
          'result': RangeGridService.heroStackBB(
              (c[0] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
              c[1] as int,
              c[2] as double),
        }
    ],
    'derivePreflopLine': [
      // Hand-shaped edge cases not in the corpus: all-in call, hero acts
      // twice, walk with no hero action.
      for (final c in <List<Object?>>[
        [
          [
            {'player': 3, 'action': 'raise', 'street': 'preflop'},
            {
              'player': 1,
              'action': 'call',
              'street': 'preflop',
              'amount': 40,
              'playerStack': 40
            },
          ],
          1
        ],
        [
          [
            {'player': 1, 'action': 'raise', 'street': 'preflop'},
            {'player': 2, 'action': 'raise', 'street': 'preflop'},
            {'player': 1, 'action': 'fold', 'street': 'preflop'},
          ],
          1
        ],
        [
          [
            {'player': 2, 'action': 'raise', 'street': 'preflop'},
            {'player': 3, 'action': 'raise', 'street': 'preflop'},
            {'player': 1, 'action': 'all-in', 'street': 'preflop'},
          ],
          1
        ],
        [
          [
            {'player': 2, 'action': 'bet', 'street': 'preflop'},
            {'player': 1, 'action': 'check', 'street': 'preflop'},
          ],
          1
        ],
        [
          [
            {'player': 2, 'action': 'none', 'street': 'preflop'},
            {'player': 3, 'action': 'fold', 'street': 'preflop'},
          ],
          1
        ],
      ])
        (() {
          final acts = (c[0] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final r = RangeGridService.derivePreflopLine(acts, c[1] as int);
          return {
            'actions': c[0],
            'heroSeat': c[1],
            'primaryAction': r.$1,
            'line': r.$2,
            'scenario': r.$3,
          };
        })(),
    ],
  };
}


// ── Range shape ───────────────────────────────────────────────────────

Json _aggJson(RangeCellAggregate a) => {
      'allIn': a.allInCount,
      'raise': a.raiseCount,
      'call': a.callCount,
      'fold': a.foldCount,
      'check': a.checkCount,
      'total': a.total,
    };

Json _positionShapeJson(PositionShape p) {
  final chart = DrillGtoCharts.openRange(p.posGroup);
  return {
    'posGroup': p.posGroup,
    'sampledSpots': p.sampledSpots,
    'playerOpenFreq': p.playerOpenFreq,
    'chartOpenPct': p.chartOpenPct,
    'sufficient': p.sufficient,
    'hasDeviations': p.hasDeviations,
    'missedOpens': [
      for (final d in p.missedOpens)
        {'handClass': d.handClass, 'spots': d.spots, 'offActions': d.offActions}
    ],
    'looseOpens': [
      for (final d in p.looseOpens)
        {'handClass': d.handClass, 'spots': d.spots, 'offActions': d.offActions}
    ],
    'aggregates': {
      for (final e in p.aggregates.entries) e.key: _aggJson(e.value)
    },
    // Mini-grid paint class for all 169 cells (what the Ranges tab draws).
    'cellKinds': {
      for (final hc in _allClasses())
        hc: RangeShapeService.classifyCell(
            inChart: chart.contains(hc), agg: p.aggregates[hc])
    },
  };
}

List<String> _allClasses() =>
    ([...DrillHandStrength.allHandClasses]..sort());

/// Mirrors RangeShapeService.generate(): per position, RFI aggregates of
/// cash + tournament merged, then analyzePosition. The corpus is replayed
/// [m] times (same as the leak analyses).
Json _rangeShapeGolden(List<RangeGridEntry> entries) {
  final reports = <String, Object?>{};
  for (final m in _multiplicities) {
    final positions = <Json>[];
    for (final pos in RangeShapeService.positions) {
      final merged = <String, RangeCellAggregate>{};
      for (final e in entries) {
        if (e.scenario != 'rfi' || e.posGroup != pos) continue;
        if (e.gameType != 'cash' && e.gameType != 'tournament') continue;
        merged[e.handClass] =
            (merged[e.handClass] ?? RangeCellAggregate(handClass: e.handClass))
                .addingAction(e.primaryAction, m);
      }
      positions.add(_positionShapeJson(
          RangeShapeService.analyzePosition(posGroup: pos, aggregates: merged)));
    }
    reports['x$m'] = {
      'positions': positions,
      'sufficientPositions': [
        for (final p in positions)
          if (p['sufficient'] == true) p['posGroup']
      ],
      'insufficientPositions': [
        for (final p in positions)
          if (p['sufficient'] != true) p['posGroup']
      ],
    };
  }
  return {
    'leakMultiplicities': _multiplicities,
    'reports': reports,
    'functionCases': _rangeShapeFunctionCases(),
  };
}

RangeCellAggregate _agg(String hc,
        {int allIn = 0, int raise = 0, int call = 0, int fold = 0, int check = 0}) =>
    RangeCellAggregate(
        handClass: hc,
        allInCount: allIn,
        raiseCount: raise,
        callCount: call,
        foldCount: fold,
        checkCount: check);

Json _rangeShapeFunctionCases() {
  final classifyAggs = <String, RangeCellAggregate?>{
    'null': null,
    'one_spot': _agg('AKs', raise: 1),
    'all_fold': _agg('AKs', fold: 4),
    'fold_2_of_3': _agg('AKs', fold: 2, raise: 1),
    'fold_1_of_2': _agg('AKs', fold: 1, raise: 1),
    'open_half': _agg('AKs', raise: 2, fold: 2),
    'open_all_in_mix': _agg('AKs', raise: 1, allIn: 1, call: 1, fold: 1),
    'open_2_of_3': _agg('AKs', raise: 2, fold: 1),
    'all_open': _agg('AKs', raise: 5),
    'calls_only': _agg('AKs', call: 4),
    'checks_only': _agg('AKs', check: 3),
  };
  final classify = <Json>[
    for (final inChart in [true, false])
      for (final e in classifyAggs.entries)
        {
          'inChart': inChart,
          'case': e.key,
          'agg': e.value == null ? null : _aggJson(e.value!),
          'result': RangeShapeService.classifyCell(
              inChart: inChart, agg: e.value),
        }
  ];

  Json analyze(String name, String pos, List<RangeCellAggregate> aggs) => {
        'name': name,
        'posGroup': pos,
        'input': {for (final a in aggs) a.handClass: _aggJson(a)},
        'result': _positionShapeJson(RangeShapeService.analyzePosition(
            posGroup: pos, aggregates: {for (final a in aggs) a.handClass: a})),
      };

  // 11 BTN-chart hands the player always folds, with distinct counts and
  // one tie, to hit maxCells truncation, sort order and tie handling.
  final manyMissed = [
    for (final e in {
      'AA': 12, 'KK': 11, 'QQ': 10, 'JJ': 9, 'TT': 9, '99': 8, '88': 7,
      '77': 6, '66': 5, '55': 4, '44': 3
    }.entries)
      _agg(e.key, fold: e.value)
  ];
  final manyLoose = [
    for (final e in {
      '72o': 9, '83o': 8, '92o': 8, '73o': 7, '82o': 6, '62o': 5,
      '52o': 4, '42o': 3, '32o': 3, '93o': 2
    }.entries)
      _agg(e.key, raise: e.value)
  ];

  final analyses = [
    analyze('empty', 'BTN', []),
    analyze('insufficient_one_cell', 'EP', [_agg('AA', raise: 3)]),
    analyze('sufficient_aligned', 'EP', [
      _agg('AA', raise: 10), _agg('KK', raise: 10), _agg('72o', fold: 10),
    ]),
    analyze('missed_and_loose_btn', 'BTN', [
      _agg('A5s', fold: 4, raise: 1), _agg('K9s', fold: 2, raise: 1),
      _agg('J6s', fold: 1, raise: 1), _agg('Q2o', raise: 3, fold: 1),
      _agg('72o', allIn: 1, raise: 2), _agg('AKs', raise: 9),
      _agg('T9s', fold: 2), _agg('32o', raise: 1),
    ]),
    analyze('threshold_exactly_067', 'MP', [
      _agg('A5s', fold: 2, raise: 1), // 0.666 < 0.67 -> not missed
      _agg('A4s', fold: 67, raise: 33), // 0.67 -> missed
      _agg('72o', raise: 2, fold: 1), // 0.666 -> not loose
      _agg('83o', raise: 67, fold: 33), // 0.67 -> loose
    ]),
    analyze('max_cells_truncation', 'BTN', [...manyMissed, ...manyLoose]),
    analyze('ties_small_list', 'CO', [
      _agg('AA', fold: 5), _agg('KK', fold: 5), _agg('QQ', fold: 5),
    ]),
    analyze('unknown_pos_falls_back_to_mp', 'BB', [
      _agg('K7s', fold: 4), _agg('K6s', raise: 4),
    ]),
    analyze('calls_dont_count_as_opens', 'SB', [
      _agg('AA', call: 8), _agg('72o', call: 8),
    ]),
  ];

  return {
    'constants': {
      'positions': RangeShapeService.positions,
      'minPositionSpots': RangeShapeService.minPositionSpots,
      'minCellSpots': RangeShapeService.minCellSpots,
      'cellDeviationFreq': RangeShapeService.cellDeviationFreq,
      'maxCells': RangeShapeService.maxCells,
    },
    'classifyCell': classify,
    'analyzePosition': analyses,
    'combosOf': [
      for (final hc in ['AA', '22', 'AKs', 'AKo', '72o', '65s'])
        {'handClass': hc, 'result': DrillGtoCharts.combosOf(hc)}
    ],
    'openRange': [
      for (final pos in ['EP', 'MP', 'CO', 'BTN', 'SB', 'BB', 'UTG', ''])
        {
          'posGroup': pos,
          'size': DrillGtoCharts.openRange(pos).length,
          'sameAsMp': identical(DrillGtoCharts.openRange(pos),
              DrillGtoCharts.rfi['MP']),
        }
    ],
  };
}

/// The RFI baseline the shape cards compare against, mirrored from
/// DrillGtoCharts so the web loads the same charts (never hand-copied).
Json _baselineCharts() => {
      'description':
          'DrillGtoCharts.rfi (~100BB open charts). openRange(pos) falls back to MP for unknown groups; BB has no chart.',
      'allHandClasses': _allClasses(),
      'combosPerClass': {
        for (final hc in _allClasses()) hc: DrillGtoCharts.combosOf(hc)
      },
      'rfi': {
        for (final e in DrillGtoCharts.rfi.entries)
          e.key: (e.value.toList()..sort())
      },
      'rfiCoveragePct': {
        for (final e in DrillGtoCharts.rfi.entries)
          e.key: DrillGtoCharts.coverageOf(e.value)
      },
      'rfiChartOpenPct': {
        for (final e in DrillGtoCharts.rfi.entries)
          e.key:
              e.value.fold<int>(0, (n, hc) => n + DrillGtoCharts.combosOf(hc)) /
                  1326
      },
      'shapeConstants': {
        'positions': RangeShapeService.positions,
        'minPositionSpots': RangeShapeService.minPositionSpots,
        'minCellSpots': RangeShapeService.minCellSpots,
        'cellDeviationFreq': RangeShapeService.cellDeviationFreq,
        'maxCells': RangeShapeService.maxCells,
      },
    };

// ── Assemble every golden ─────────────────────────────────────────────

Map<String, String> _buildAll() {
  final sessions = {
    for (final f in _jsonFiles('sessions')) _id(f): _read(f),
  };
  final hands = [for (final f in _jsonFiles('hands')) _read(f)];
  final out = <String, String>{};
  final entries = <RangeGridEntry>[];
  final csv = CSVExportService();

  for (final hand in hands) {
    final id = hand['id'] as String;
    final session = sessions[hand['sessionId']]!;
    final entry = _rangeEntry(hand, session);
    if (entry != null) entries.add(entry);
    final ref = '${hand['sessionId']}:${hand['handNumber']}';
    out['expected/$id.json'] = _encode({
      'id': id,
      'completeness': HandCompletenessX.fromHandMap(hand).wire,
      'pokerstars': PokerStarsExportService.exportHand(hand, session),
      'csv': csv.exportHandToCsv(hand),
      'stats': _stats(hand),
      'leakFacts': _facts(LeakExtractor.extract(hand, ref: ref)),
      'rangeEntry': _entryJson(entry),
      'rangeLine': (() {
        final a = _actions(hand);
        final seat = hand['heroSeatNumber'] as int?;
        if (seat == null) return null;
        final r = RangeGridService.derivePreflopLine(a, seat);
        return {
          'primaryAction': r.$1,
          'line': r.$2,
          'scenario': r.$3,
          'heroStackBB': RangeGridService.heroStackBB(
              a, seat, (hand['bigBlind'] as num?)?.toDouble() ?? 0.0),
        };
      })(),
    });
  }

  final analyses = <String, Object?>{};
  for (final m in _multiplicities) {
    final facts = <LeakHandFacts>[];
    for (var k = 0; k < m; k++) {
      for (final hand in hands) {
        final ref = '${hand['sessionId']}:${hand['handNumber']}#$k';
        final f = LeakExtractor.extract(hand, ref: ref);
        if (f != null) facts.add(f);
      }
    }
    analyses['x$m'] = _report(LeakEngine.analyze(facts));
  }

  final bySession = <String, List<Json>>{};
  for (final h in hands) {
    (bySession[h['sessionId'] as String] ??= []).add(h);
  }
  final sessionExports = <String, Object?>{};
  for (final e in bySession.entries) {
    final list = [...e.value]
      ..sort((a, b) =>
          (a['handNumber'] as int).compareTo(b['handNumber'] as int));
    sessionExports[e.key] = {
      'handIds': list.map((h) => h['id']).toList(),
      'pokerstars': PokerStarsExportService.exportSession(sessions[e.key]!, list),
      'csv': csv.exportSessionToCsv(sessions[e.key]!, list),
    };
  }

  out['expected/_corpus.json'] = _encode({
    'handIds': hands.map((h) => h['id']).toList(),
    'leakMultiplicities': _multiplicities,
    'leakAnalyses': analyses,
    'sessionExports': sessionExports,
    'rangeGrid': {
      'entriesIndexed': entries.length,
      'cash': _aggregate(entries, 'cash'),
      'tournament': _aggregate(entries, 'tournament'),
      'cashRfi': _aggregate(entries, 'cash', scenario: 'rfi'),
      'cashVsRaise': _aggregate(entries, 'cash', scenario: 'vs_raise'),
      'cashBtn': _aggregate(entries, 'cash', posGroup: 'BTN'),
      'cashBb': _aggregate(entries, 'cash', posGroup: 'BB'),
      'cashDeep': _aggregate(entries, 'cash', stackBucket: 'veryDeep'),
      'tournamentShort': _aggregate(entries, 'tournament', stackBucket: 'short'),
    },
    'functionCases': _functionCases(hands),
  });
  out['expected/_rangeShape.json'] = _encode(_rangeShapeGolden(entries));
  out['baseline_charts.json'] = _encode(_baselineCharts());
  return out;
}

void main() {
  test('web-parity goldens', () {
    final expected = _buildAll();
    final dir = Directory('$_root/expected');

    if (Platform.environment['UPDATE_GOLDENS'] == '1') {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      dir.createSync(recursive: true);
      expected.forEach(
          (name, body) => File('$_root/$name').writeAsStringSync(body));
      // ignore: avoid_print
      print('Wrote ${expected.length} goldens under $_root');
      return;
    }

    final problems = <String>[];
    expected.forEach((name, body) {
      final f = File('$_root/$name');
      if (!f.existsSync()) {
        problems.add('missing: $name');
      } else if (f.readAsStringSync() != body) {
        problems.add('stale: $name');
      }
    });
    final onDisk = dir.existsSync()
        ? dir
            .listSync()
            .whereType<File>()
            .map((f) => 'expected/${f.uri.pathSegments.last}')
            .toSet()
        : <String>{};
    for (final extra in onDisk.difference(expected.keys.toSet())) {
      problems.add('orphaned: $extra');
    }
    expect(problems, isEmpty,
        reason: 'Goldens out of date. Run: UPDATE_GOLDENS=1 flutter test '
            'test/web_parity/generate_goldens_test.dart '
            '(and sync to final-table-web).');
  });
}
