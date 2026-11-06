import '../models/hand_state_machine.dart';
import '../models/poker_game_state.dart';

/// Pure helpers for the Easy Hand Logging live screen. No I/O, no widgets:
/// everything here is unit-tested without a Flutter binding.

/// The one player left in the hand, or null when 0 or 2+ remain.
int? soleSurvivor(PokerGameState g) {
  final live = g.getActivePlayers();
  return live.length == 1 ? live.first : null;
}

/// True when hero has put chips in voluntarily (call, bet, raise) so the
/// hand is no longer a pure fold.
bool heroEnteredPot(List<ActionRecord> actions, int? heroSeat) {
  if (heroSeat == null) return false;
  return actions.any((a) =>
      a.player == heroSeat &&
      (a.action == PlayerAction.call ||
          a.action == PlayerAction.bet ||
          a.action == PlayerAction.raise));
}

bool _isLive(PlayerState p) => p.isActive && !p.hasFolded && !p.isAllIn;

/// Table state captured just before a fold tick advances to the next hand,
/// so Undo can put the table back exactly as it was.
///
/// Uses the engine's own street snapshot slot for the fields it keeps private
/// (last raise size, per-player bets), so the slot must not be reused until
/// the tick is committed or undone: the screen retires the undo as soon as
/// the new hand takes an action.
class TableSnapshot {
  final int handNumber;
  final int buttonPosition;
  final int? sbSeat;
  final int? bbSeat;
  final List<bool> folded;
  final List<bool> active;

  /// Dead button / dead SB rotation memory, so Undo restores it too.
  final (int, int)? blindMemory;

  TableSnapshot._({
    required this.handNumber,
    required this.buttonPosition,
    required this.sbSeat,
    required this.bbSeat,
    required this.folded,
    required this.active,
    required this.blindMemory,
  });

  static TableSnapshot capture(PokerGameState g) {
    g.snapshotBeforeStreetAdvance();
    return TableSnapshot._(
      handNumber: g.handNumber,
      buttonPosition: g.buttonPosition,
      sbSeat: g.effectiveSBPosition,
      bbSeat: g.effectiveBBPosition,
      folded: [for (final p in g.players) p.hasFolded],
      active: [for (final p in g.players) p.isActive],
      blindMemory: g.blindMemory,
    );
  }

  void restore(PokerGameState g) {
    g.handNumber = handNumber;
    for (var i = 0; i < g.players.length && i < folded.length; i++) {
      g.players[i].hasFolded = folded[i];
      g.players[i].isActive = active[i];
    }
    // Stacks first: the blind derivation counts a seat as live by its chips.
    g.restoreFromStreetSnapshot();
    g.restoreBlinds(buttonPosition, blindMemory);
  }
}
