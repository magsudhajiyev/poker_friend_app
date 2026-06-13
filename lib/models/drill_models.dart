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
  final double vpip;
  final double pfr;
  final double threeBet;
  final double fold3bet;
  final double aggression; // aggression frequency %
  final String archetype; // PlayStyleDetector style, or 'Regular' for bots

  const DrillVillainProfile({
    required this.opponentId,
    required this.name,
    required this.handsObserved,
    required this.vpip,
    required this.pfr,
    required this.threeBet,
    required this.fold3bet,
    required this.aggression,
    required this.archetype,
  });

  /// Limp/passive-entry rate, approximated from the VPIP–PFR gap.
  /// (Limp frequency isn't tracked directly yet; most of the gap in live
  /// home games is open-limping.)
  double get limpRate {
    final gap = vpip - pfr;
    return gap > 0 ? gap * 0.7 : 0.0;
  }

  /// Passive continue rate facing a single raise (cold-call/defend).
  double get defendRate {
    final gap = vpip - pfr;
    return gap > 0 ? gap * 0.5 : 0.0;
  }

  bool get isGenericBot => opponentId == null;

  String get confidenceLabel {
    if (isGenericBot) return 'generic bot';
    if (handsObserved < 30) return 'early read — $handsObserved hands';
    if (handsObserved < 100) return 'developing — $handsObserved hands';
    return 'based on $handsObserved hands';
  }

  /// Generic balanced-regular profile used for unassigned seats and as the
  /// shrinkage prior for low-sample opponents.
  static const prior = DrillVillainProfile(
    opponentId: null,
    name: 'Bot',
    handsObserved: 0,
    vpip: 24,
    pfr: 17,
    threeBet: 7,
    fold3bet: 55,
    aggression: 50,
    archetype: 'Regular',
  );
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
    required this.seatOpponentIds,
    required this.seatNames,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'playerCount': playerCount,
        'heroSeat': heroSeat,
        'stackBB': stackBB,
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

  const DrillDecisionContext({
    required this.handClass,
    required this.positionGroup,
    required this.stackBB,
    required this.scenario,
    required this.opener,
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
  });

  /// Live opponents in the blinds who still get to act after the hero —
  /// the steal targets when the hero opens from a late seat.
  List<DrillSeatRef> get blindsBehind =>
      behindDetail.where((r) => r.isBlind).toList();
}

enum DrillGrade { correct, ok, mistake }

/// Grader verdict for one hero decision.
class DrillGradeResult {
  final DrillGrade grade;
  final String heroAction; // 'fold' | 'check' | 'call' | 'raise'
  final String recommendedAction;
  final String explanation;

  /// Transparency: where the dealt hand ranks among all 169 combos
  /// (0 = AA, 100 = worst) and the top-% range boundary the decision was
  /// graded against, after opponent/position adjustments. Lets the UI show
  /// the actual math behind a verdict.
  final double handTopPercent;
  final double rangePercent;

  const DrillGradeResult({
    required this.grade,
    required this.heroAction,
    required this.recommendedAction,
    required this.explanation,
    this.handTopPercent = 0,
    this.rangePercent = 0,
  });
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
