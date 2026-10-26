/// Data models for the opponent-based training drill mode.
///
/// Training drills are fully isolated from real data: nothing here touches
/// poker_sessions, user/opponent stats, or the range grid index.
library;

/// Blended behavioural profile a drill bot plays by.
///
/// Observed opponent stats are shrunk toward a generic-regular prior so an
/// opponent with 12 logged hands doesn't produce absurd frequencies. All
/// rates are percentages (0–100).
class DrillVillainProfile {
  final String? opponentId; // null for a generic filler bot
  final String name;
  final int handsObserved;
  final double threeBet;
  final double fold3bet;
  final double aggression; // aggression frequency %
  final double steal;
  final double cbet;
  final double blindDefend;
  final double showdown;
  final double checkRaiseFlop;
  final String archetype; // PlayStyleDetector style, or 'Regular' for bots

  const DrillVillainProfile({
    required this.opponentId,
    required this.name,
    required this.handsObserved,
    required this.threeBet,
    required this.fold3bet,
    required this.aggression,
    required this.steal,
    required this.cbet,
    required this.blindDefend,
    required this.showdown,
    required this.checkRaiseFlop,
    required this.archetype,
  });

  /// Limp/passive-entry rate, approximated from aggression and showdown %.
  double get limpRate {
    final passivity = (100 - aggression).clamp(0.0, 100.0);
    final showdownExcess = (showdown - 28).clamp(0.0, 50.0);
    return (passivity * 0.10 + showdownExcess * 0.5).clamp(0.0, 30.0);
  }

  /// Passive continue rate facing a single raise (cold-call/defend for
  /// non-blind positions).
  double get defendRate {
    final passivity = (100 - aggression).clamp(0.0, 100.0);
    final showdownExcess = (showdown - 28).clamp(0.0, 50.0);
    return (passivity * 0.08 + showdownExcess * 0.4).clamp(0.0, 25.0);
  }

  bool get isGenericBot => opponentId == null;

  String get confidenceLabel {
    if (isGenericBot) return 'generic bot';
    if (handsObserved < 30) return 'early read — $handsObserved hands';
    if (handsObserved < 100) return 'developing — $handsObserved hands';
    return 'based on $handsObserved hands';
  }

  /// Cash game prior (8-9 max, 100BB deep)
  static const cashPrior = DrillVillainProfile(
    opponentId: null,
    name: 'Bot',
    handsObserved: 0,
    threeBet: 6,
    fold3bet: 58,
    aggression: 45,
    steal: 28,
    cbet: 65,
    blindDefend: 35,
    showdown: 28,
    checkRaiseFlop: 8,
    archetype: 'Regular',
  );

  /// Tournament prior (8-9 max, antes in play)
  static const mttPrior = DrillVillainProfile(
    opponentId: null,
    name: 'Bot',
    handsObserved: 0,
    threeBet: 8,
    fold3bet: 52,
    aggression: 52,
    steal: 38,
    cbet: 62,
    blindDefend: 45,
    showdown: 26,
    checkRaiseFlop: 9,
    archetype: 'Regular',
  );

  /// Convenience accessor — kept for backward compat / tests.
  static DrillVillainProfile prior({bool anteMode = false}) =>
      anteMode ? mttPrior : cashPrior;
}

/// One seat at the drill table.
class DrillSeat {
  final int seatNumber;
  final bool isHero;
  final DrillVillainProfile? profile; // null only for the hero seat

  const DrillSeat({
    required this.seatNumber,
    required this.isHero,
    this.profile,
  });

  String get displayName => isHero ? 'You' : (profile?.name ?? 'Bot');
}

/// Saved table lineup (persisted to SharedPreferences as JSON).
class DrillLineup {
  final String id;
  final String name;
  final int playerCount;
  final int heroSeat;
  final double stackBB;

  /// BB-ante (MTT) format; false = cash. Old saved lineups default to cash.
  final bool hasAnte;

  /// seat number -> opponentId ('' means generic bot). Hero seat excluded.
  final Map<int, String> seatOpponentIds;

  /// seat number -> display name snapshot (so the lineup renders even if an
  /// opponent was deleted later).
  final Map<int, String> seatNames;

  const DrillLineup({
    required this.id,
    required this.name,
    required this.playerCount,
    required this.heroSeat,
    required this.stackBB,
    this.hasAnte = false,
    required this.seatOpponentIds,
    required this.seatNames,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'playerCount': playerCount,
        'heroSeat': heroSeat,
        'stackBB': stackBB,
        'hasAnte': hasAnte,
        'seatOpponentIds':
            seatOpponentIds.map((k, v) => MapEntry(k.toString(), v)),
        'seatNames': seatNames.map((k, v) => MapEntry(k.toString(), v)),
      };

  factory DrillLineup.fromJson(Map<String, dynamic> json) {
    Map<int, String> parseSeatMap(dynamic raw) {
      final result = <int, String>{};
      if (raw is Map) {
        raw.forEach((k, v) {
          final seat = int.tryParse(k.toString());
          if (seat != null && v != null) result[seat] = v.toString();
        });
      }
      return result;
    }

    return DrillLineup(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Lineup',
      playerCount: (json['playerCount'] as num?)?.toInt() ?? 6,
      heroSeat: (json['heroSeat'] as num?)?.toInt() ?? 1,
      stackBB: (json['stackBB'] as num?)?.toDouble() ?? 100,
      hasAnte: json['hasAnte'] == true,
      seatOpponentIds: parseSeatMap(json['seatOpponentIds']),
      seatNames: parseSeatMap(json['seatNames']),
    );
  }
}

/// A single simulated table event shown in the drill action feed.
class DrillEvent {
  final int seat;
  final String name;
  final String position;
  final String action; // 'posts SB', 'posts BB', 'folds', 'limps', 'calls',
  // 'raises', '3-bets', '4-bets', 'checks', 'jams'
  final double? toAmountBB; // total to-amount in BB for raises/calls

  const DrillEvent({
    required this.seat,
    required this.name,
    required this.position,
    required this.action,
    this.toAmountBB,
  });
}

/// Scenario the hero faces at a decision point.
enum DrillScenario {
  unopened, // no raise, no limpers
  vsLimpers, // no raise, 1+ limpers
  vsRaise, // facing exactly one raise
  vs3betAsAggressor, // hero raised earlier, now facing a re-raise
  vs3betCold, // facing 2+ raises without having raised
}

/// A still-live opponent yet to act after the hero, tagged with their seat
/// position so the grader can reason about WHERE they sit (e.g. an aggressive
/// 3-bettor on the direct left, or a passive player in the blinds behind a
/// steal attempt).
class DrillSeatRef {
  final DrillVillainProfile profile;
  final String positionGroup; // EP/MP/CO/BTN/SB/BB
  final bool isBlind; // SB or BB
  final bool isDirectLeft; // acts immediately after the hero

  const DrillSeatRef({
    required this.profile,
    required this.positionGroup,
    required this.isBlind,
    required this.isDirectLeft,
  });
}

/// Everything the grader needs about one hero decision point.
class DrillDecisionContext {
  final String handClass;
  final String positionGroup; // EP/MP/CO/BTN/SB/BB
  final double stackBB;
  final DrillScenario scenario;
  final DrillVillainProfile? opener; // last aggressor before hero, if any
  final String openerPosGroup; // position group of the opener ('' if none)
  final bool heroLimped; // hero limped earlier this hand (limp-then-face-raise)
  final List<DrillVillainProfile> limpers;
  final List<DrillVillainProfile> playersBehind; // not folded, act after hero
  final List<DrillSeatRef> behindDetail; // same players, position-tagged
  final double toCallBB;
  final double currentBetBB; // total to-amount of the live bet (1 = blinds)
  final double potBB;
  final int raisesBeforeHero;

  /// Profile of the player in the BB seat (null when hero is BB).
  final DrillVillainProfile? bbProfile;

  /// Profile of the player in the SB seat (null when hero is SB).
  final DrillVillainProfile? sbProfile;

  /// Whether hero acts after the last aggressor (positional advantage).
  final bool isInPosition;

  /// BB-ante format (MTT): extra dead money widens opens and turns the SB
  /// into a complete-or-raise (almost never fold) spot.
  final bool anteMode;

  const DrillDecisionContext({
    required this.handClass,
    required this.positionGroup,
    required this.stackBB,
    required this.scenario,
    required this.opener,
    this.openerPosGroup = '',
    this.heroLimped = false,
    required this.limpers,
    required this.playersBehind,
    this.behindDetail = const [],
    required this.toCallBB,
    required this.currentBetBB,
    required this.potBB,
    required this.raisesBeforeHero,
    this.bbProfile,
    this.sbProfile,
    this.isInPosition = false,
    this.anteMode = false,
  });

  /// Live opponents in the blinds who still get to act after the hero —
  /// the steal targets when the hero opens from a late seat.
  List<DrillSeatRef> get blindsBehind =>
      behindDetail.where((r) => r.isBlind).toList();
}

enum DrillGrade { correct, ok, mistake }

/// Grader verdict for one hero decision, evaluated two ways:
/// a baseline **GTO** line (opponent-agnostic, driven only by position and
/// stack depth) and an **exploit** line (the GTO baseline adjusted for the
/// actual opponents at the table and their tendencies). The hero's action is
/// graded against the exploit line — that's the point of the trainer — but
/// both are shown so the divergence is the teaching moment.
class DrillGradeResult {
  final DrillGrade grade;
  final String heroAction; // 'fold' | 'check' | 'call' | 'raise'
  final String recommendedAction; // = exploitAction (primary target)

  /// Street-aware display word for the recommended action ('bet' vs 'raise'
  /// depending on whether there was a bet to raise over). Set by the authored
  /// grader; null elsewhere → [recommendedWord] falls back to
  /// [recommendedAction]. Coach-persona lead templates substitute `{action}`
  /// with [recommendedWord], not the raw wire string (which always reads
  /// 'raise').
  final String? recommendedWordRaw;

  /// Display word for the recommended action (street-aware when provided).
  String get recommendedWord => recommendedWordRaw ?? recommendedAction;

  final String explanation; // verdict lead + exploit reason (for summaries)

  /// The reason half of [explanation] WITHOUT the rotated lead — coach
  /// personas prepend their own character leads to this ('' on legacy
  /// construction; fall back to [explanation]).
  final String headlineReason;

  /// Where the dealt hand ranks among all 169 combos (0 = AA, 100 = worst).
  final double handTopPercent;

  // ── Dual evaluation ──
  final String gtoAction;
  final double gtoRangePercent;
  final String gtoReason;
  final String exploitAction;
  final double exploitRangePercent;
  final String exploitReason;

  const DrillGradeResult({
    required this.grade,
    required this.heroAction,
    required this.recommendedAction,
    this.recommendedWordRaw,
    required this.explanation,
    this.headlineReason = '',
    this.handTopPercent = 0,
    this.gtoAction = 'fold',
    this.gtoRangePercent = 0,
    this.gtoReason = '',
    this.exploitAction = 'fold',
    this.exploitRangePercent = 0,
    this.exploitReason = '',
    this.trace = const [],
  });

  /// Step-by-step decision trace for debugging: which chart/table produced
  /// the baseline, every exploit adjustment applied, membership checks, and
  /// the final verdict math. Logged via debugPrint in debug builds.
  final List<String> trace;

  /// True when the exploitative line matches the GTO baseline.
  bool get linesAgree => gtoAction == exploitAction;

  DrillGradeResult copyWith({
    DrillGrade? grade,
    String? explanation,
    String? headlineReason,
    String? exploitReason,
  }) {
    return DrillGradeResult(
      grade: grade ?? this.grade,
      heroAction: heroAction,
      recommendedAction: recommendedAction,
      explanation: explanation ?? this.explanation,
      headlineReason: headlineReason ?? this.headlineReason,
      handTopPercent: handTopPercent,
      gtoAction: gtoAction,
      gtoRangePercent: gtoRangePercent,
      gtoReason: gtoReason,
      exploitAction: exploitAction,
      exploitRangePercent: exploitRangePercent,
      exploitReason: exploitReason ?? this.exploitReason,
      trace: trace,
    );
  }
}

/// One graded hero decision, kept for the session summary.
class DrillDecisionRecord {
  final int handNumber;
  final String handClass;
  final String position;
  final DrillScenario scenario;
  final DrillGradeResult result;

  const DrillDecisionRecord({
    required this.handNumber,
    required this.handClass,
    required this.position,
    required this.scenario,
    required this.result,
  });
}
