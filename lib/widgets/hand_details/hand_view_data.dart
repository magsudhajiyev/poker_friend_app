import 'dart:math' as math;

import '../../models/game_types.dart';
import 'hand_amount_formatter.dart';

enum StreetKind { preflop, flop, turn, river, runout }

/// One street (or all-in run-out strip) of the hand.
class StreetBlock {
  final StreetKind kind;
  final List<String> cards;
  final List<Map<String, dynamic>> actions;
  final double? pot;

  const StreetBlock({
    required this.kind,
    required this.cards,
    required this.actions,
    this.pot,
  });
}

/// An opponent's shown hole cards.
class ShownHand {
  final int seat;
  final String? name;
  final String card1;
  final String card2;

  const ShownHand(this.seat, this.name, this.card1, this.card2);
}

/// Pure, display-ready view of a stored hand map. Parsing lives here so the
/// widgets stay declarative and the logic is unit-testable.
class HandViewData {
  final Map<String, dynamic> hand;
  final int? heroSeat;
  final HandAmountFormatter formatter;
  final Map<String, String> playerNames;
  final int buttonPosition;
  final int playerCount;
  final GameType gameType;
  final String? heroCard1;
  final String? heroCard2;
  final List<String> flop;
  final String? turn;
  final String? river;
  final List<ShownHand> shownHands;
  final List<StreetBlock> streets;

  HandViewData._({
    required this.hand,
    required this.heroSeat,
    required this.formatter,
    required this.playerNames,
    required this.buttonPosition,
    required this.playerCount,
    required this.gameType,
    required this.heroCard1,
    required this.heroCard2,
    required this.flop,
    required this.turn,
    required this.river,
    required this.shownHands,
    required this.streets,
  });

  bool get hasHeroCards => heroCard1 != null || heroCard2 != null;

  /// Full board in deal order.
  List<String> get board => [
        ...flop,
        if (turn != null && turn!.isNotEmpty) turn!,
        if (river != null && river!.isNotEmpty) river!,
      ];

  static int? _asInt(dynamic v) => v is num ? v.toInt() : null;

  static String? _cardOrNull(dynamic v) =>
      v is String && v.isNotEmpty ? v : null;

  factory HandViewData.from(
    Map<String, dynamic> hand, {
    int? ourSeat,
    required bool showBB,
  }) {
    final gameType =
        GameTypeExtension.fromString(hand['gameType'] ?? 'cash');
    final formatter = HandAmountFormatter(
      showBB: showBB,
      bigBlind: (hand['bigBlind'] as num?)?.toDouble() ?? 2.0,
      isCash: gameType == GameType.cash,
    );

    final names = <String, String>{};
    final rawNames = hand['playerNames'];
    if (rawNames is Map) {
      rawNames.forEach((k, v) => names[k.toString()] = v.toString());
    }

    final hole = hand['ourHoleCards'];
    final board = hand['boardCards'];
    final flop = <String>[];
    String? turn;
    String? river;
    if (board is Map) {
      flop.addAll(List<String>.from(board['flop'] ?? const []));
      turn = board['turn'] as String?;
      river = board['river'] as String?;
    }

    final actions = (hand['actions'] as List<dynamic>? ?? const [])
        .map((a) => Map<String, dynamic>.from(a as Map))
        .toList();

    return HandViewData._(
      hand: hand,
      heroSeat: ourSeat ?? _asInt(hand['heroPosition']),
      formatter: formatter,
      playerNames: names,
      buttonPosition: _asInt(hand['buttonPosition']) ?? 1,
      playerCount: math.max(2, _asInt(hand['playerCount']) ?? 6),
      gameType: gameType,
      heroCard1: hole is Map ? _cardOrNull(hole['card1']) : null,
      heroCard2: hole is Map ? _cardOrNull(hole['card2']) : null,
      flop: flop,
      turn: turn,
      river: river,
      shownHands: _shownHands(hand['showdownData'], names),
      streets: _buildStreets(hand, actions, flop, turn, river),
    );
  }

  static List<ShownHand> _shownHands(dynamic showdown, Map<String, String> names) {
    final result = <ShownHand>[];
    if (showdown is! Map || showdown['playerCards'] is! Map) return result;
    (showdown['playerCards'] as Map).forEach((key, value) {
      final seat = int.tryParse(key.toString());
      if (seat == null || value is! Map) return;
      final c1 = _cardOrNull(value['card1']);
      final c2 = _cardOrNull(value['card2']);
      if (c1 != null && c2 != null) {
        result.add(ShownHand(seat, names[seat.toString()], c1, c2));
      }
    });
    return result;
  }

  // ---- All-in helpers (behaviour preserved from the original screen) ----

  /// HL-8: a CALL that consumes the whole stack is an all-in for less and
  /// must read ALL-IN too, not just bets/raises.
  static bool isAllInAction(Map<String, dynamic> action) {
    final type = (action['action'] as String?)?.toLowerCase();
    if (type != 'raise' && type != 'bet' && type != 'call') return false;
    final amount = action['amount'];
    final stack = action['playerStack'] ?? action['stack'];
    if (amount is! num || stack is! num) return false;
    if (stack <= 0) return false; // no stack recorded: can't infer all-in
    return amount.toDouble() >= (stack.toDouble() - 0.01);
  }

  static bool _hasPostflopActions(List<Map<String, dynamic>> actions) =>
      actions.any((a) =>
          a['street'] != null &&
          a['street'].toString().toLowerCase() != 'preflop');

  static List<StreetBlock> _buildStreets(
    Map<String, dynamic> hand,
    List<Map<String, dynamic>> actions,
    List<String> flop,
    String? turn,
    String? river,
  ) {
    final by = <String, List<Map<String, dynamic>>>{
      'preflop': [], 'flop': [], 'turn': [], 'river': [],
    };
    for (final a in actions) {
      by[a['street'] as String? ?? 'preflop']?.add(a);
    }
    final hasTurn = turn != null && turn.isNotEmpty;
    final hasRiver = river != null && river.isNotEmpty;
    double? pot(String k) => HandAmountFormatter.toDouble(hand[k]);

    final blocks = <StreetBlock>[
      if (by['preflop']!.isNotEmpty)
        StreetBlock(
            kind: StreetKind.preflop,
            cards: const [],
            actions: by['preflop']!,
            pot: pot('preflopPot')),
    ];

    final allIn = actions.any(isAllInAction);
    if (allIn && !_hasPostflopActions(actions)) {
      final all = [...flop, if (hasTurn) turn, if (hasRiver) river];
      if (all.isNotEmpty) {
        blocks.add(StreetBlock(
            kind: _runoutKind(flop, hasTurn, hasRiver),
            cards: all,
            actions: const []));
      }
      return blocks;
    }

    // A street DEALT but with no recorded actions is an all-in run-out: those
    // streets collapse into one board strip at the end.
    final flopRun = flop.isNotEmpty && by['flop']!.isEmpty;
    final turnRun = hasTurn && by['turn']!.isEmpty;
    final riverRun = hasRiver && by['river']!.isEmpty;

    if (flop.isNotEmpty && !flopRun) {
      blocks.add(StreetBlock(
          kind: StreetKind.flop,
          cards: flop,
          actions: by['flop']!,
          pot: pot('flopPot')));
    }
    if (hasTurn && !turnRun) {
      blocks.add(StreetBlock(
          kind: StreetKind.turn,
          cards: [turn],
          actions: by['turn']!,
          pot: pot('turnPot')));
    }
    if (hasRiver && !riverRun) {
      blocks.add(StreetBlock(
          kind: StreetKind.river,
          cards: [river],
          actions: by['river']!,
          pot: pot('riverPot')));
    }
    if (flopRun || turnRun || riverRun) {
      final runFlop = flopRun ? flop : const <String>[];
      final cards = [
        ...runFlop,
        if (turnRun) turn,
        if (riverRun) river,
      ];
      blocks.add(StreetBlock(
          kind: _runoutKind(runFlop, turnRun, riverRun),
          cards: cards,
          actions: const []));
    }
    return blocks;
  }

  /// Single-street run-out keeps its street name; multi-street is "run-out".
  static StreetKind _runoutKind(List<String> flop, bool hasTurn, bool hasRiver) {
    if (flop.isEmpty && !hasTurn && hasRiver) return StreetKind.river;
    if (flop.isEmpty && hasTurn && !hasRiver) return StreetKind.turn;
    return StreetKind.runout;
  }
}
