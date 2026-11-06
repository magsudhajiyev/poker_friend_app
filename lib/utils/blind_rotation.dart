/// Pure blind / button rotation with dead button and dead small blind
/// (TDA Rule 34). No Flutter, no state: callers keep the memory
/// (last BB seat, last SB seat) and pass it in. See POKER_SEATING_RULES.md.
///
/// "Live" = a seat with a player who has chips. Seat numbers are 1..tableSize
/// and wrap. A seat stays remembered after its player leaves.
class BlindAssignment {
  final int buttonSeat;

  /// SB seat number. When [sbDead] the seat is empty and nobody posts.
  final int sbSeat;
  final int bbSeat;
  final bool buttonDead;
  final bool sbDead;

  const BlindAssignment({
    required this.buttonSeat,
    required this.sbSeat,
    required this.bbSeat,
    required this.buttonDead,
    required this.sbDead,
  });

  @override
  String toString() =>
      'BlindAssignment(btn=$buttonSeat${buttonDead ? ' dead' : ''}, '
      'sb=$sbSeat${sbDead ? ' dead' : ''}, bb=$bbSeat)';
}

class BlindRotation {
  /// Blinds for the next hand from the previous hand's BB and SB seats.
  /// Returns null when fewer than 2 seats are live.
  static BlindAssignment? next({
    required List<int> live,
    required int tableSize,
    required int lastBB,
    required int lastSB,
  }) {
    if (live.length < 2) return null;
    final bb = _after(live, tableSize, lastBB);
    if (live.length == 2) return _headsUp(live, bb);
    final button = _noCollision(live, tableSize, lastSB, lastBB, bb);
    return BlindAssignment(
      buttonSeat: button,
      sbSeat: lastBB,
      bbSeat: bb,
      buttonDead: !live.contains(button),
      sbDead: !live.contains(lastBB),
    );
  }

  /// Baseline from a button seat: first hand, or after a manual button move.
  /// SB is the first live seat after the button, BB the next. An empty
  /// button seat stays where it is (dead button). With 2 live, the button
  /// is the SB and snaps to the next live seat if it was empty.
  static BlindAssignment? fromButton({
    required List<int> live,
    required int tableSize,
    required int button,
  }) {
    if (live.length < 2) return null;
    if (live.length == 2) {
      final sb = live.contains(button) ? button : _after(live, tableSize, button);
      final bb = live.firstWhere((s) => s != sb);
      return _headsUp(live, bb);
    }
    final sb = _after(live, tableSize, button);
    final bb = _after(live, tableSize, sb);
    return BlindAssignment(
      buttonSeat: button,
      sbSeat: sb,
      bbSeat: bb,
      buttonDead: !live.contains(button),
      sbDead: false,
    );
  }

  static BlindAssignment _headsUp(List<int> live, int bb) {
    final other = live.firstWhere((s) => s != bb);
    return BlindAssignment(
      buttonSeat: other,
      sbSeat: other,
      bbSeat: bb,
      buttonDead: false,
      sbDead: false,
    );
  }

  /// Going from heads-up back to 3+ can make the remembered SB seat equal the
  /// new BB. Nobody is both: the button goes to the last live seat before
  /// the SB seat (the entrant, who joins behind the button).
  static int _noCollision(
      List<int> live, int tableSize, int button, int sbSeat, int bb) {
    if (button != bb) return button;
    return _before(live, tableSize, sbSeat);
  }

  /// First live seat strictly after [seat], clockwise, wrapping.
  static int _after(List<int> live, int tableSize, int seat) {
    for (var i = 1; i <= tableSize; i++) {
      final s = ((seat - 1 + i) % tableSize) + 1;
      if (live.contains(s)) return s;
    }
    return seat;
  }

  /// First live seat strictly before [seat], counter-clockwise, wrapping.
  static int _before(List<int> live, int tableSize, int seat) {
    for (var i = 1; i <= tableSize; i++) {
      final s = ((seat - 1 - i) % tableSize + tableSize) % tableSize + 1;
      if (live.contains(s)) return s;
    }
    return seat;
  }
}
