import '../models/authored_tree.dart';
import 'authored_tree_walker.dart';
import 'daily_coach_lines_service.dart' show DailyCoachLinesService;
import 'paid_nudge_logic.dart';

/// A notification button of the one-tap spot quiz. Distinct ids for "bet" and
/// "raise" (both are [AuthoredAction.raise] in the tree) because the button
/// title is fixed per id on iOS (categories are registered once at startup).
enum SpotQuizAction {
  fold('fold', 'Fold', AuthoredAction.fold),
  check('check', 'Check', AuthoredAction.check),
  call('call', 'Call', AuthoredAction.call),
  bet('bet', 'Bet', AuthoredAction.raise),
  raise('raise', 'Raise', AuthoredAction.raise),
  allIn('allin', 'All-in', AuthoredAction.allin);

  final String id;

  /// Poker terms stay English in every locale (project rule).
  final String label;
  final AuthoredAction action;
  const SpotQuizAction(this.id, this.label, this.action);

  static SpotQuizAction? fromId(String? id) {
    for (final a in values) {
      if (a.id == id) return a;
    }
    return null;
  }
}

/// What the villain did before the hero's first decision.
enum SpotQuizVillainMove { opened, raised, bet, called, checked, allIn }

/// The truthful facts of a quiz question, read from a real tree. No copy.
class SpotQuizSpot {
  final String treeId;
  final String heroCards; // 'J♠ 9♠'
  final String heroPosition;
  final String villainPosition;

  /// Null when the hero acts first.
  final SpotQuizVillainMove? villainMove;

  /// 2–3 buttons, canonical order, highest solver frequency kept.
  final List<SpotQuizAction> buttons;

  const SpotQuizSpot({
    required this.treeId,
    required this.heroCards,
    required this.heroPosition,
    required this.villainPosition,
    required this.villainMove,
    required this.buttons,
  });
}

/// Pure decisions for the spot-quiz push: which past day and hand to show,
/// what the question facts are, and the payload/category contract. No IO.
class SpotQuizLogic {
  SpotQuizLogic._();

  static const int maxButtons = 3;
  static const int minButtons = 2;

  /// Past days a quiz may draw from: 1..3 days before the fire day.
  static const int maxAgeDays = 3;

  /// Android caps visible actions at 3; iOS categories are registered for
  /// every 2–3 subset of [SpotQuizAction] (see [allCategories]).
  static const String categoryPrefix = 'spot_quiz_';

  /// Candidate days (date-only) for a push firing on [fireDay]: yesterday
  /// first. Always ≥ 1 day old, never today, so today's challenge and the
  /// leaderboard are not spoiled and a 15-day Pro window includes them.
  static List<DateTime> candidateDays(DateTime fireDay) => [
        for (var i = 1; i <= maxAgeDays; i++)
          DateTime(fireDay.year, fireDay.month, fireDay.day - i),
      ];

  /// First local `[hour]` slot from TOMORROW on (never the current day: a
  /// server push already sent today is invisible here) that clears every cap
  /// against [others] (the other queued offers + the streak reminder),
  /// looking at the next [maxAgeDays] + 1 days. Null = none.
  static DateTime? fireTime(DateTime now, int hour, List<DateTime> others) {
    for (var i = 1; i <= maxAgeDays + 1; i++) {
      final at = DateTime(now.year, now.month, now.day + i, hour);
      if (!at.isAfter(now.add(PaidNudgeLogic.minLead))) continue;
      if (PaidNudgeLogic.tooInactive(now, at)) return null;
      if (PaidNudgeLogic.withinOfferCap([
            for (final o in others)
              if (o != at) o
          ], at) &&
          PaidNudgeLogic.dayIsFree(others, at)) {
        return at;
      }
    }
    return null;
  }

  /// Deterministic start offset for [uid] on [fireDayKey] among [count]
  /// options; the caller rotates from it, so a day that cannot serve a quiz
  /// falls through to the next one reproducibly.
  static int pickStart(
          String uid, String fireDayKey, String scope, int count) =>
      count <= 1
          ? 0
          : DailyCoachLinesService.stableHash('$uid|$fireDayKey|$scope') %
              count;

  /// The question facts for [tree]'s first hero decision, or null when
  /// nothing honest can be asked (no hole cards, hero never acts, hand not
  /// in the solver data, fewer than [minButtons] real actions).
  static SpotQuizSpot? spotFor(AuthoredTree tree) {
    if (tree.heroCards.length < 2) return null;
    final walker = AuthoredTreeWalker(tree);
    if (!walker.isHeroTurn && !walker.isOver) walker.advanceVillains();
    final node = walker.current;
    if (node == null || !node.isHero || !node.hasHeroFreq(tree.heroHandClass)) {
      return null;
    }
    final buttons = _buttons(node, tree.heroHandClass);
    if (buttons.length < minButtons) return null;
    return SpotQuizSpot(
      treeId: tree.id,
      heroCards: tree.heroCards.take(2).join(' '),
      heroPosition: tree.heroPosition,
      villainPosition: tree.villainPosition,
      villainMove: _move(walker.lastVillainMoves),
      buttons: buttons,
    );
  }

  /// The legal actions of [node] as buttons; with more than [maxButtons],
  /// the ones the solver plays most with [hand] (ties keep tree order).
  static List<SpotQuizAction> _buttons(TreeNode node, String hand) {
    final all = <(SpotQuizAction, double)>[];
    for (final a in node.actions) {
      final b = _button(a, node);
      if (b != null) all.add((b, node.freqOf(a, hand)));
    }
    if (all.length > maxButtons) {
      final ranked = [...all]..sort((x, y) => y.$2.compareTo(x.$2));
      final keep = ranked.take(maxButtons).map((e) => e.$1).toSet();
      all.removeWhere((e) => !keep.contains(e.$1));
    }
    return canonicalButtons([for (final e in all) e.$1]);
  }

  /// [buttons] de-duplicated, in enum order, capped at [maxButtons]. The iOS
  /// category id and the shown buttons both derive from this, so tree action
  /// order can never change which category a push uses.
  static List<SpotQuizAction> canonicalButtons(
      Iterable<SpotQuizAction> buttons) {
    final set = buttons.toSet();
    return [
      for (final a in SpotQuizAction.values)
        if (set.contains(a)) a
    ].take(maxButtons).toList();
  }

  static SpotQuizAction? _button(AuthoredAction a, TreeNode node) =>
      switch (a) {
        AuthoredAction.fold => SpotQuizAction.fold,
        AuthoredAction.check => SpotQuizAction.check,
        AuthoredAction.call => SpotQuizAction.call,
        AuthoredAction.raise =>
          node.toCallBB > 0 ? SpotQuizAction.raise : SpotQuizAction.bet,
        AuthoredAction.allin => SpotQuizAction.allIn,
      };

  static SpotQuizVillainMove? _move(List<VillainMove> moves) {
    if (moves.isEmpty) return null;
    final last = moves.last;
    final preflop = last.street == TreeStreet.preflop;
    return switch (last.action) {
      AuthoredAction.raise => preflop
          ? (moves.length == 1
              ? SpotQuizVillainMove.opened
              : SpotQuizVillainMove.raised)
          : (moves.length == 1
              ? SpotQuizVillainMove.bet
              : SpotQuizVillainMove.raised),
      AuthoredAction.call => SpotQuizVillainMove.called,
      AuthoredAction.check => SpotQuizVillainMove.checked,
      AuthoredAction.allin => SpotQuizVillainMove.allIn,
      AuthoredAction.fold => null, // a folded villain ends the hand
    };
  }

  /// Whether [action] can still be played at [tree]'s first hero decision —
  /// the tree may have changed since the push was built.
  static bool isStillLegal(AuthoredTree tree, SpotQuizAction action) {
    final walker = AuthoredTreeWalker(tree);
    if (!walker.isHeroTurn && !walker.isOver) walker.advanceVillains();
    final node = walker.current;
    return node != null && node.isHero && node.actions.contains(action.action);
  }

  // ── Payload + iOS categories ────────────────────────────────────────

  /// `engagement:spot_quiz:{eventId}` + the tapped button: appends
  /// `:{actionId}` (backward compatible — see StreakSaverService.parsePayload).
  /// Unknown or empty ids leave [payload] unchanged (a body tap).
  static String payloadWithAction(String payload, String? actionId) =>
      SpotQuizAction.fromId(actionId) == null ? payload : '$payload:$actionId';

  /// iOS category id for exactly this button set (order = enum order).
  static String categoryId(List<SpotQuizAction> buttons) =>
      '$categoryPrefix${canonicalButtons(buttons).map((b) => b.id).join('-')}';

  /// Every 2–3 button subset in canonical order — registered once at plugin
  /// init because iOS action sets are fixed per category.
  static List<List<SpotQuizAction>> allCategories() {
    const v = SpotQuizAction.values;
    return [
      for (var i = 0; i < v.length; i++)
        for (var j = i + 1; j < v.length; j++) ...[
          [v[i], v[j]],
          for (var k = j + 1; k < v.length; k++) [v[i], v[j], v[k]],
        ],
    ];
  }

  /// The stored target of a quiz push: `{dayKey}|{treeId}`.
  static String encodeTarget(String dayKey, String treeId) => '$dayKey|$treeId';

  static ({String dayKey, String treeId})? decodeTarget(String? raw) {
    final p = raw?.split('|');
    if (p == null || p.length != 2 || p[0].isEmpty || p[1].isEmpty) return null;
    return (dayKey: p[0], treeId: p[1]);
  }
}
