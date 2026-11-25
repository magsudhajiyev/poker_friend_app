import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/poker_positions.dart';
import 'flag_table_snapshot.dart';
import 'game_types.dart';

/// Unit the player types the stack in: [amount] = chips (tournament) or money
/// (cash), [bb] = big blinds. `stackBB` stays the stored truth.
enum StackUnit { amount, bb }

/// Table set-up for one single-hand log ("Log a hand"): pure data + derivation,
/// no Flutter, no Firebase. The hero always sits in seat 1; the button seat is
/// derived so the hero holds [heroPosition]. Every seat is active with the
/// same [stackBB] stack. See docs/features/single-hand-logging.md.
class SingleHandSetup {
  GameType gameType;
  double smallBlind;
  double bigBlind;
  bool hasBBante;
  int playerCount; // 2..9
  String heroPosition; // valid for playerCount, see [positionsFor]
  double stackBB; // same for all seats
  String? card1;
  String? card2;

  /// Hero's display name (nickname). Set by the screen when the hand starts;
  /// never stored with the last-used values. Villains are named by position.
  String? heroName;

  /// Last-used input unit per game type (tournament players think in chips,
  /// cash players in BB by default).
  StackUnit cashStackUnit;
  StackUnit tournamentStackUnit;

  StackUnit get stackUnit =>
      gameType == GameType.cash ? cashStackUnit : tournamentStackUnit;

  set stackUnit(StackUnit u) {
    if (gameType == GameType.cash) {
      cashStackUnit = u;
    } else {
      tournamentStackUnit = u;
    }
  }

  /// Typed [input] in [unit] -> BB at [bigBlind]; null for non-positive input.
  static double? stackToBB(double? input, StackUnit unit, double bigBlind) {
    if (input == null || input <= 0 || bigBlind <= 0) return null;
    return unit == StackUnit.bb ? input : input / bigBlind;
  }

  /// BB -> chips / money at [bigBlind].
  static double bbToAmount(double bb, double bigBlind) => bb * bigBlind;

  /// Snap steps (in BB) for the one-drag hero stack, by game type. Cash steps
  /// are BB multiples (the screen shows them as money = step * bigBlind).
  static List<double> stackStepsBB(GameType t) => t == GameType.cash
      ? const [20, 30, 40, 50, 60, 75, 100, 125, 150, 200, 250, 300, 400, 500]
      : const [
          5, 8, 10, 12, 15, 20, 25, 30, 40, 50, 60, 80, 100, 125, 150, 200,
          250, 300
        ];

  /// Index of the step closest to [value]; the lower step wins a tie.
  /// [steps] must not be empty.
  static int nearestStepIndex(List<double> steps, double value) {
    var best = 0;
    for (var i = 1; i < steps.length; i++) {
      if ((steps[i] - value).abs() < (steps[best] - value).abs()) best = i;
    }
    return best;
  }

  /// Villain stack overlay scale: multiples of the hero stack.
  static const List<double> relativeStackSteps = [
    0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0
  ];

  SingleHandSetup({
    this.gameType = GameType.cash,
    this.smallBlind = 1,
    this.bigBlind = 2,
    this.hasBBante = false,
    this.playerCount = 6,
    this.heroPosition = 'BTN',
    this.stackBB = 100,
    this.cashStackUnit = StackUnit.bb,
    this.tournamentStackUnit = StackUnit.amount,
    this.card1,
    this.card2,
  });

  static const String _prefsKey = 'single_hand_last_setup';
  static const int heroSeat = 1;

  /// Position names selectable for [playerCount], early to late, blinds last
  /// (UTG ... CO, BTN, SB, BB). Names match what the hand logger shows;
  /// heads-up is BTN (the button posts the small blind) and BB.
  static List<String> positionsFor(int playerCount) {
    final n = playerCount.clamp(2, 9);
    if (n == 2) return const ['BTN', 'BB'];
    // With the button on seat 1, relative position r sits on seat r + 1.
    String at(int r) => PokerPositions.getPositionName(r + 1, 1, n);
    return [
      for (var r = 3; r < n; r++) at(r),
      at(0),
      at(1),
      at(2),
    ];
  }

  /// Clockwise distance from the button to the hero (0 = BTN, 1 = SB, ...).
  int get _heroOffset {
    final n = playerCount;
    if (n == 2) return heroPosition == 'BB' ? 1 : 0;
    final i = positionsFor(n).indexOf(heroPosition);
    if (i < 0) return 0;
    final early = n - 3; // seats UTG .. CO come first in the list
    return i < early ? i + 3 : i - early;
  }

  /// Seat that holds the button so the hero (seat 1) gets [heroPosition].
  int get buttonSeat => ((playerCount - _heroOffset) % playerCount) + 1;

  /// Throw-away table for the logger (same shape recall mode uses).
  FlagTableSnapshot toSnapshot() {
    final button = buttonSeat;
    final active = [for (var s = 1; s <= playerCount; s++) s];
    return FlagTableSnapshot(
      buttonPosition: button,
      heroSeat: heroSeat,
      smallBlind: smallBlind,
      bigBlind: bigBlind,
      hasBBante: hasBBante,
      gameType: gameType.name,
      seats: [
        for (final s in active)
          FlagSeat(
            seat: s,
            active: true,
            position: PokerPositions.getPositionNameForActivePlayers(
                s, button, active),
            name: _seatName(s, button, active),
            stack: stackBB * bigBlind,
          ),
      ],
    );
  }

  /// Hero = nickname (when known), villains = their position label.
  String _seatName(int seat, int button, List<int> active) {
    final hero = heroName?.trim() ?? '';
    if (seat == heroSeat && hero.isNotEmpty) return hero;
    return PokerPositions.getPositionNameForActivePlayers(seat, button, active);
  }

  SingleHandSetup copyWith({
    GameType? gameType,
    double? smallBlind,
    double? bigBlind,
    bool? hasBBante,
    int? playerCount,
    String? heroPosition,
    double? stackBB,
    String? card1,
    String? card2,
  }) =>
      SingleHandSetup(
        gameType: gameType ?? this.gameType,
        smallBlind: smallBlind ?? this.smallBlind,
        bigBlind: bigBlind ?? this.bigBlind,
        hasBBante: hasBBante ?? this.hasBBante,
        playerCount: playerCount ?? this.playerCount,
        heroPosition: heroPosition ?? this.heroPosition,
        stackBB: stackBB ?? this.stackBB,
        cashStackUnit: cashStackUnit,
        tournamentStackUnit: tournamentStackUnit,
        card1: card1 ?? this.card1,
        card2: card2 ?? this.card2,
      )..heroName = heroName;

  /// Last-used values only: cards belong to one hand and are never stored.
  Map<String, dynamic> toMap() => {
        'gameType': gameType.name,
        'smallBlind': smallBlind,
        'bigBlind': bigBlind,
        'hasBBante': hasBBante,
        'playerCount': playerCount,
        'heroPosition': heroPosition,
        'stackBB': stackBB,
        'cashStackUnit': cashStackUnit.name,
        'tournamentStackUnit': tournamentStackUnit.name,
      };

  /// Tolerant: bad or missing fields fall back to the first-run defaults, and
  /// a position that is invalid for the player count falls back to the button.
  factory SingleHandSetup.fromMap(Map<String, dynamic> m) {
    final d = SingleHandSetup();
    final players =
        ((m['playerCount'] as num?)?.toInt() ?? d.playerCount).clamp(2, 9);
    final pos = m['heroPosition']?.toString();
    final sb = (m['smallBlind'] as num?)?.toDouble() ?? d.smallBlind;
    final bb = (m['bigBlind'] as num?)?.toDouble() ?? d.bigBlind;
    final stack = (m['stackBB'] as num?)?.toDouble() ?? d.stackBB;
    return SingleHandSetup(
      gameType:
          m['gameType'] == 'tournament' ? GameType.tournament : GameType.cash,
      smallBlind: sb > 0 ? sb : d.smallBlind,
      bigBlind: bb > 0 ? bb : d.bigBlind,
      hasBBante: m['hasBBante'] == true,
      playerCount: players,
      heroPosition:
          pos != null && positionsFor(players).contains(pos) ? pos : 'BTN',
      stackBB: stack > 0 ? stack : d.stackBB,
      cashStackUnit: StackUnit.values.firstWhere(
          (v) => v.name == m['cashStackUnit'],
          orElse: () => StackUnit.bb),
      tournamentStackUnit: StackUnit.values.firstWhere(
          (v) => v.name == m['tournamentStackUnit'],
          orElse: () => StackUnit.amount),
    );
  }

  static Future<SingleHandSetup> loadLastUsed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return SingleHandSetup();
      final map = jsonDecode(raw);
      if (map is! Map) return SingleHandSetup();
      return SingleHandSetup.fromMap(Map<String, dynamic>.from(map));
    } catch (_) {
      return SingleHandSetup();
    }
  }

  Future<void> saveAsLastUsed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(toMap()));
    } catch (_) {
      // Remembering the last set-up is a convenience only.
    }
  }
}
