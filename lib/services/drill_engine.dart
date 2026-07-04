import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/drill_models.dart';
import 'drill_grader.dart';
import 'drill_gto_charts.dart';
import 'drill_hand_strength.dart';

/// Hero's available options at a decision point.
class DrillHeroTurn {
  final double toCallBB;
  final bool canCheck;
  final bool canRaise; // false when facing a bet for the full stack
  final double potBB;
  final DrillScenario scenario;
  final List<double> suggestedRaiseToBB; // total to-amounts, ascending
  final double minRaiseToBB;
  final double maxRaiseToBB; // hero stack (jam)

  const DrillHeroTurn({
    required this.toCallBB,
    required this.canCheck,
    required this.canRaise,
    required this.potBB,
    required this.scenario,
    required this.suggestedRaiseToBB,
    required this.minRaiseToBB,
    required this.maxRaiseToBB,
  });
}

/// Result of advancing the simulation (start, or after a hero action).
class DrillHandUpdate {
  final List<DrillEvent> newEvents;
  final bool awaitingHero;
  final DrillHeroTurn? heroTurn;
  final bool handComplete;
  final bool heroWalked; // everyone folded to hero's BB — no decision made
  final bool heroWonUncontested;
  final bool reachedFlop; // preflop betting closed with 2+ players in
  final double potBB;
  final DrillGradeResult? grade; // grade of the hero action just applied

  const DrillHandUpdate({
    required this.newEvents,
    required this.awaitingHero,
    this.heroTurn,
    required this.handComplete,
    this.heroWalked = false,
    this.heroWonUncontested = false,
    this.reachedFlop = false,
    required this.potBB,
    this.grade,
  });
}

class _HandPlayer {
  final int seat;
  final bool isHero;
  final DrillVillainProfile profile; // hero carries the prior, unused
  bool folded = false;
  bool hasActed = false;
  bool limped = false;
  bool raisedThisHand = false;
  double committedBB = 0;

  _HandPlayer(this.seat, this.isHero, this.profile);
}

/// Frequency-driven preflop simulator. Villains act by dice roll against
/// their blended tendency profiles — no villain hole cards exist, which is
/// all a preflop-only drill needs. Hands never persist anywhere.
class DrillEngine {
  final List<DrillSeat> seats;
  final double stackBB;
  final Random _rng;

  late final int heroSeat;
  late final List<int> _orderedSeats; // ascending seat numbers
  int handNumber = 0;
  int _buttonSeat = 0;

  // Per-hand state (empty until the first startHand so UI can build early)
  List<_HandPlayer> _players = [];
  Map<int, _HandPlayer> _bySeat = {};
  Map<int, String> _positions = {};
  double _currentBetBB = 1;
  double _lastRaiseIncrementBB = 1;
  int _raises = 0;
  int? _lastAggressorSeat;
  int _actionPointer = 0; // index into _orderedSeats of last actor
  List<String> heroCards = [];
  String heroHandClass = '';
  DrillDecisionContext? _pendingContext;

  DrillEngine({
    required this.seats,
    required this.stackBB,
    Random? rng,
  }) : _rng = rng ?? Random() {
    heroSeat = seats.firstWhere((s) => s.isHero).seatNumber;
    _orderedSeats = seats.map((s) => s.seatNumber).toList()..sort();
    _buttonSeat = _orderedSeats[_rng.nextInt(_orderedSeats.length)];
  }

  String get heroPosition => _positions[heroSeat] ?? 'UNK';
  int get buttonSeat => _buttonSeat;
  String positionOf(int seat) => _positions[seat] ?? '';
  double get potBB =>
      _players.fold(0.0, (sum, p) => sum + p.committedBB);

  /// Remaining stack (BB) for a seat in the current hand. Stacks reset to
  /// [stackBB] every hand — this is a drill, not a bankroll simulation.
  double stackOf(int seat) => stackBB - (_bySeat[seat]?.committedBB ?? 0.0);

  DrillHandUpdate startHand() {
    handNumber++;
    _buttonSeat = handNumber == 1 ? _buttonSeat : _nextSeat(_buttonSeat);
    _players = [
      for (final s in seats)
        _HandPlayer(
            s.seatNumber, s.isHero, s.profile ?? DrillVillainProfile.prior)
    ];
    _bySeat = {for (final p in _players) p.seat: p};
    _positions = _calculatePositions();
    _currentBetBB = 1;
    _lastRaiseIncrementBB = 1;
    _raises = 0;
    _lastAggressorSeat = null;
    _pendingContext = null;
    _dealHero();

    final events = <DrillEvent>[];
    final sbSeat = _smallBlindSeat();
    final bbSeat = _bigBlindSeat();
    _bySeat[sbSeat]!.committedBB = 0.5;
    _bySeat[bbSeat]!.committedBB = 1.0;
    events.add(_event(sbSeat, 'posts SB', toAmount: 0.5));
    events.add(_event(bbSeat, 'posts BB', toAmount: 1.0));

    // Preflop action starts left of the BB
    _actionPointer = _orderedSeats.indexOf(bbSeat);
    return _run(events);
  }

  /// Applies the hero's choice, grades it, and resumes the simulation.
  /// [action] is 'fold' | 'check' | 'call' | 'raise'; [raiseToBB] is the
  /// total to-amount when raising.
  DrillHandUpdate applyHeroAction(String action, {double? raiseToBB}) {
    final ctx = _pendingContext;
    _pendingContext = null;
    final grade = ctx != null
        ? DrillGrader.grade(ctx, action, raiseToBB: raiseToBB)
        : null;
    if (grade != null && grade.trace.isNotEmpty) {
      // Debug-build decision trace: exactly how this grade was computed
      debugPrint('┌─ DRILL DECISION TRACE (hand #$handNumber, '
          '${ctx!.handClass} @ $heroPosition, ${stackBB.toInt()}BB)');
      for (final line in grade.trace) {
        debugPrint('│ $line');
      }
      debugPrint('└─ verdict: ${grade.grade.name.toUpperCase()} '
          '(hero: $action, exploit: ${grade.exploitAction}, '
          'gto: ${grade.gtoAction})');
    }

    final hero = _bySeat[heroSeat]!;
    final events = <DrillEvent>[];
    switch (action) {
      case 'fold':
        hero.folded = true;
        hero.hasActed = true;
        events.add(_event(heroSeat, 'folds'));
      case 'check':
        hero.hasActed = true;
        events.add(_event(heroSeat, 'checks'));
      case 'call':
        final to = min(_currentBetBB, stackBB);
        hero.committedBB = to;
        hero.hasActed = true;
        hero.limped = _raises == 0;
        events.add(_event(heroSeat, _raises == 0 ? 'limps' : 'calls',
            toAmount: to));
      case 'raise':
        final minTo = min(_currentBetBB + _lastRaiseIncrementBB, stackBB);
        final to = (raiseToBB ?? minTo).clamp(minTo, stackBB).toDouble();
        _applyRaise(hero, to, events);
    }

    if (hero.folded) {
      // Let the remaining villains finish the hand silently — the drill is
      // over for the hero, so just close it out.
      return _finishAfterHeroFold(events, grade);
    }
    return _run(events, grade: grade);
  }

  // ── Simulation loop ─────────────────────────────────────────────────

  DrillHandUpdate _run(List<DrillEvent> events, {DrillGradeResult? grade}) {
    while (true) {
      final remaining = _players.where((p) => !p.folded).toList();
      if (remaining.length == 1) {
        final winner = remaining.first;
        final walked = winner.isHero &&
            _raises == 0 &&
            !winner.limped &&
            _positions[heroSeat] == 'BB' &&
            !winner.hasActed;
        return DrillHandUpdate(
          newEvents: events,
          awaitingHero: false,
          handComplete: true,
          heroWalked: walked,
          heroWonUncontested: winner.isHero,
          potBB: potBB,
          grade: grade,
        );
      }

      final actor = _nextActor();
      if (actor == null) {
        // Betting closed — flop would be dealt; preflop drill ends here
        return DrillHandUpdate(
          newEvents: events,
          awaitingHero: false,
          handComplete: true,
          reachedFlop: true,
          potBB: potBB,
          grade: grade,
        );
      }

      if (actor.isHero) {
        _pendingContext = _buildContext(actor);
        return DrillHandUpdate(
          newEvents: events,
          awaitingHero: true,
          heroTurn: _buildHeroTurn(actor),
          handComplete: false,
          potBB: potBB,
          grade: grade,
        );
      }

      _villainAct(actor, events);
    }
  }

  DrillHandUpdate _finishAfterHeroFold(
      List<DrillEvent> events, DrillGradeResult? grade) {
    // Resolve remaining villain actions without surfacing them — keeps the
    // feed focused on what the hero saw.
    var guard = 0;
    while (guard++ < 50) {
      final remaining = _players.where((p) => !p.folded).toList();
      if (remaining.length <= 1) break;
      final actor = _nextActor();
      if (actor == null) break;
      _villainAct(actor, []);
    }
    return DrillHandUpdate(
      newEvents: events,
      awaitingHero: false,
      handComplete: true,
      potBB: potBB,
      grade: grade,
    );
  }

  _HandPlayer? _nextActor() {
    for (int step = 1; step <= _orderedSeats.length; step++) {
      final idx = (_actionPointer + step) % _orderedSeats.length;
      final p = _bySeat[_orderedSeats[idx]]!;
      if (p.folded) continue;
      final needsAction = !p.hasActed || p.committedBB < _currentBetBB;
      final canAct = p.committedBB < stackBB; // not already all-in
      if (needsAction && canAct) {
        _actionPointer = idx;
        return p;
      }
    }
    return null;
  }

  void _villainAct(_HandPlayer p, List<DrillEvent> events) {
    final profile = p.profile;
    final roll = _rng.nextDouble() * 100;
    final isBB = p.seat == _bigBlindSeat();

    if (_raises == 0) {
      final limpersInPot = _players
          .where((q) => q.limped && !q.folded)
          .length;
      if (isBB) {
        // BB option: occasionally raise the limped pot, otherwise check
        final raiseFreq =
            limpersInPot > 0 ? profile.pfr * 0.5 : profile.pfr * 0.3;
        if (roll < raiseFreq) {
          _applyRaise(p, 2.5 + limpersInPot + 1, events);
        } else {
          p.hasActed = true;
          events.add(_event(p.seat, 'checks'));
        }
        return;
      }
      final openFreq =
          (profile.pfr * _positionOpenMultiplier(p.seat)).clamp(0.0, 92.0);
      if (roll < openFreq) {
        _applyRaise(p, 2.5 + limpersInPot, events);
      } else if (roll < openFreq + profile.limpRate) {
        p.committedBB = 1.0;
        p.hasActed = true;
        p.limped = true;
        events.add(_event(p.seat, 'limps', toAmount: 1.0));
      } else {
        p.folded = true;
        p.hasActed = true;
        events.add(_event(p.seat, 'folds'));
      }
      return;
    }

    if (_raises == 1) {
      final defend =
          isBB ? profile.defendRate * 1.2 : profile.defendRate;
      if (roll < profile.threeBet) {
        _applyRaise(p, _currentBetBB * 3, events);
      } else if (roll < profile.threeBet + defend) {
        _callCurrent(p, events);
      } else {
        p.folded = true;
        p.hasActed = true;
        events.add(_event(p.seat, 'folds'));
      }
      return;
    }

    // Facing a 3-bet or more
    if (p.raisedThisHand) {
      final continuePct = 100 - profile.fold3bet;
      if (_raises < 4 && roll < continuePct * 0.25) {
        _applyRaise(p, _currentBetBB * 2.4, events);
      } else if (roll < continuePct) {
        _callCurrent(p, events);
      } else {
        p.folded = true;
        p.hasActed = true;
        events.add(_event(p.seat, 'folds'));
      }
    } else {
      // Cold-facing multiple raises: continue rarely, driven by looseness
      if (roll < profile.threeBet * 0.5) {
        _callCurrent(p, events);
      } else {
        p.folded = true;
        p.hasActed = true;
        events.add(_event(p.seat, 'folds'));
      }
    }
  }

  void _callCurrent(_HandPlayer p, List<DrillEvent> events) {
    final to = min(_currentBetBB, stackBB);
    p.committedBB = to;
    p.hasActed = true;
    events.add(_event(p.seat, 'calls', toAmount: to));
  }

  void _applyRaise(_HandPlayer p, double toBB, List<DrillEvent> events) {
    var to = toBB;
    // Jam instead of leaving crumbs behind
    if (to >= stackBB * 0.66) to = stackBB;
    to = min(to, stackBB);
    final minTo = _currentBetBB + _lastRaiseIncrementBB;
    if (to < minTo) to = min(minTo, stackBB);
    if (to <= _currentBetBB) {
      // Stack can't exceed the live bet — this "raise" is just a call
      _callCurrent(p, events);
      return;
    }

    _lastRaiseIncrementBB = to - _currentBetBB;
    _currentBetBB = to;
    _raises++;
    _lastAggressorSeat = p.seat;
    p.committedBB = to;
    p.raisedThisHand = true;
    p.hasActed = true;
    // Everyone else gets to act again
    for (final q in _players) {
      if (q.seat != p.seat && !q.folded) q.hasActed = false;
    }

    final String label;
    if (to >= stackBB) {
      label = 'jams';
    } else if (_raises == 1) {
      label = 'raises';
    } else if (_raises == 2) {
      label = '3-bets';
    } else if (_raises == 3) {
      label = '4-bets';
    } else {
      label = 'raises';
    }
    events.add(_event(p.seat, label, toAmount: to));
  }

  // ── Hero decision context ───────────────────────────────────────────

  DrillScenario _scenarioFor(_HandPlayer hero) {
    if (_raises == 0) {
      final limpers =
          _players.where((p) => p.limped && !p.folded && !p.isHero);
      return limpers.isEmpty
          ? DrillScenario.unopened
          : DrillScenario.vsLimpers;
    }
    if (_raises == 1) return DrillScenario.vsRaise;
    return hero.raisedThisHand
        ? DrillScenario.vs3betAsAggressor
        : DrillScenario.vs3betCold;
  }

  DrillDecisionContext _buildContext(_HandPlayer hero) {
    final opener = _lastAggressorSeat != null
        ? _bySeat[_lastAggressorSeat!]!.profile
        : null;
    final limpers = _players
        .where((p) => p.limped && !p.folded && !p.isHero)
        .map((p) => p.profile)
        .toList();
    // Players still to act after the hero this round, ordered by how soon
    // they act (nearest first = direct left).
    final n = _orderedSeats.length;
    final heroIdx = _orderedSeats.indexOf(hero.seat);
    final behindPlayers = _players
        .where((p) => !p.folded && !p.isHero && !p.hasActed)
        .toList()
      ..sort((a, b) {
        final da = (_orderedSeats.indexOf(a.seat) - heroIdx + n) % n;
        final db = (_orderedSeats.indexOf(b.seat) - heroIdx + n) % n;
        return da.compareTo(db);
      });
    final sbSeat = _smallBlindSeat();
    final bbSeat = _bigBlindSeat();
    final behindDetail = <DrillSeatRef>[
      for (int k = 0; k < behindPlayers.length; k++)
        DrillSeatRef(
          profile: behindPlayers[k].profile,
          positionGroup: positionGroup(_positions[behindPlayers[k].seat] ?? ''),
          isBlind: behindPlayers[k].seat == sbSeat ||
              behindPlayers[k].seat == bbSeat,
          isDirectLeft: k == 0,
        ),
    ];
    return DrillDecisionContext(
      handClass: heroHandClass,
      positionGroup: positionGroup(heroPosition),
      stackBB: stackBB,
      scenario: _scenarioFor(hero),
      opener: _raises > 0 ? opener : null,
      openerPosGroup: _raises > 0 && _lastAggressorSeat != null
          ? positionGroup(_positions[_lastAggressorSeat!] ?? '')
          : '',
      heroLimped: hero.limped,
      limpers: limpers,
      playersBehind: behindPlayers.map((p) => p.profile).toList(),
      behindDetail: behindDetail,
      toCallBB: max(0.0, _currentBetBB - hero.committedBB),
      currentBetBB: _currentBetBB,
      potBB: potBB,
      raisesBeforeHero: _raises,
    );
  }

  DrillHeroTurn _buildHeroTurn(_HandPlayer hero) {
    final toCall = max(0.0, _currentBetBB - hero.committedBB);
    final minRaiseTo = min(_currentBetBB + _lastRaiseIncrementBB, stackBB);
    final limperCount =
        _players.where((p) => p.limped && !p.folded && !p.isHero).length;

    final sizes = <double>[];
    if (_raises == 0) {
      sizes.add(2.5 + limperCount);
      sizes.add(3.5 + limperCount);
    } else if (_raises == 1) {
      sizes.add(_round1(_currentBetBB * 3));
      sizes.add(_round1(_currentBetBB * 4));
    } else {
      sizes.add(_round1(_currentBetBB * 2.4));
    }
    sizes.add(stackBB); // jam
    final unique = <double>[];
    for (final s in sizes) {
      final capped = min(s, stackBB);
      if (capped >= minRaiseTo && !unique.contains(capped)) {
        unique.add(capped);
      }
    }
    if (unique.isEmpty) unique.add(stackBB);

    return DrillHeroTurn(
      toCallBB: toCall,
      canCheck: toCall == 0,
      canRaise: _currentBetBB < stackBB,
      potBB: potBB,
      scenario: _scenarioFor(hero),
      suggestedRaiseToBB: unique,
      minRaiseToBB: minRaiseTo,
      maxRaiseToBB: stackBB,
    );
  }

  // ── Table geometry ──────────────────────────────────────────────────

  int _nextSeat(int from) {
    final idx = _orderedSeats.indexOf(from);
    return _orderedSeats[(idx + 1) % _orderedSeats.length];
  }

  int _smallBlindSeat() =>
      _orderedSeats.length == 2 ? _buttonSeat : _nextSeat(_buttonSeat);

  int _bigBlindSeat() => _orderedSeats.length == 2
      ? _nextSeat(_buttonSeat)
      : _nextSeat(_smallBlindSeat());

  Map<int, String> _calculatePositions() {
    final n = _orderedSeats.length;
    final names = _positionNamesFor(n);
    final result = <int, String>{};
    final buttonIdx = _orderedSeats.indexOf(_buttonSeat);
    for (int i = 0; i < n; i++) {
      final seat = _orderedSeats[(buttonIdx + i) % n];
      result[seat] = names[i];
    }
    return result;
  }

  static List<String> _positionNamesFor(int n) {
    switch (n) {
      case 2:
        return ['BTN', 'BB'];
      case 3:
        return ['BTN', 'SB', 'BB'];
      case 4:
        return ['BTN', 'SB', 'BB', 'UTG'];
      case 5:
        return ['BTN', 'SB', 'BB', 'UTG', 'CO'];
      case 6:
        return ['BTN', 'SB', 'BB', 'UTG', 'HJ', 'CO'];
      case 7:
        return ['BTN', 'SB', 'BB', 'UTG', 'UTG+1', 'HJ', 'CO'];
      case 8:
        return ['BTN', 'SB', 'BB', 'UTG', 'UTG+1', 'UTG+2', 'HJ', 'CO'];
      default:
        return ['BTN', 'SB', 'BB', 'UTG', 'UTG+1', 'UTG+2', 'LJ', 'HJ', 'CO'];
    }
  }

  /// Coarse group used by the grader (mirrors RangeGridService.positionGroup).
  static String positionGroup(String position) {
    final p = position.toUpperCase();
    if (p == 'BB') return 'BB';
    if (p == 'SB') return 'SB';
    if (p == 'BTN') return 'BTN';
    if (p == 'CO') return 'CO';
    if (p.startsWith('UTG')) return 'EP';
    return 'MP';
  }

  double _positionOpenMultiplier(int seat) {
    switch (positionGroup(_positions[seat] ?? '')) {
      case 'EP':
        return 0.75;
      case 'MP':
        return 0.9;
      case 'CO':
        return 1.15;
      case 'BTN':
        return 1.35;
      case 'SB':
        return 1.1;
      default:
        return 1.0;
    }
  }

  // ── Dealing ─────────────────────────────────────────────────────────

  static const _dealRanks = [
    'A', 'K', 'Q', 'J', '10', '9', '8', '7', '6', '5', '4', '3', '2'
  ];
  static const _dealSuits = ['♠', '♥', '♦', '♣'];

  /// Deal hero cards with a bias toward playable hands.
  ///
  /// ~65% of the time we ensure the hand is "interesting" — inside the GTO
  /// opening range for the hero's position, or close to the boundary (top
  /// percentile up to range + 10%). The remaining ~35% are fully random so
  /// the user still practises folding trash.
  void _dealHero() {
    final posGroup = positionGroup(_positions[heroSeat] ?? 'MP');
    final range = DrillGtoCharts.openRange(posGroup);
    final rangeCoverage = DrillGtoCharts.coverageOf(range);
    // "Interesting" = in range OR borderline (within 10% above the range edge)
    final interestingCutoff = rangeCoverage + 10;

    // 65% chance we force an interesting hand
    final forceInteresting = _rng.nextDouble() < 0.65;

    for (int attempt = 0; attempt < 20; attempt++) {
      final first = _rng.nextInt(52);
      int second = _rng.nextInt(51);
      if (second >= first) second++;
      final c1 = _cardFromIndex(first);
      final c2 = _cardFromIndex(second);
      final hc = handClassFor(c1, c2);

      if (!forceInteresting || attempt == 19) {
        // Accept any hand on the last attempt or when not forcing
        heroCards = [c1, c2];
        heroHandClass = hc;
        return;
      }

      // Accept if the hand is in range or borderline
      if (range.contains(hc) ||
          DrillHandStrength.topPercent(hc) <= interestingCutoff) {
        heroCards = [c1, c2];
        heroHandClass = hc;
        return;
      }
    }
  }

  static String _cardFromIndex(int i) =>
      '${_dealRanks[i ~/ 4]}${_dealSuits[i % 4]}';

  /// 169-grid class for two card strings like 'A♠' + 'K♦' → 'AKo'.
  static String handClassFor(String card1, String card2) {
    String rankOf(String c) {
      final r = c.substring(0, c.length - 1);
      return r == '10' ? 'T' : r.toUpperCase();
    }

    String suitOf(String c) => c.substring(c.length - 1);

    const order = 'AKQJT98765432';
    final r1 = rankOf(card1);
    final r2 = rankOf(card2);
    if (r1 == r2) return '$r1$r2';
    final high = order.indexOf(r1) < order.indexOf(r2) ? r1 : r2;
    final low = high == r1 ? r2 : r1;
    final suffix = suitOf(card1) == suitOf(card2) ? 's' : 'o';
    return '$high$low$suffix';
  }

  DrillEvent _event(int seat, String action, {double? toAmount}) {
    final seatInfo = seats.firstWhere((s) => s.seatNumber == seat);
    return DrillEvent(
      seat: seat,
      name: seatInfo.displayName,
      position: _positions[seat] ?? '?',
      action: action,
      toAmountBB: toAmount,
    );
  }

  static double _round1(double v) => (v * 10).roundToDouble() / 10;
}
