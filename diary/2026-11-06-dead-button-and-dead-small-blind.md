# 2026-11-06 — Dead button and dead small blind (TDA Rule 34)

Shipped in 2.1.9+26. Founder approved the result on 2026-11-06.

## Symptom (reported by the founder)

When the big blind busts, the next hand has no small blind. Only the BB posts
(plus the ante). In the hand after that, the button must land on the now-empty
seat. The old code skipped the empty seat and gave the button to the next
player, so blinds and positions did not match a real table.

## Root cause

The button and blinds were derived in four separate places, each with its own
logic: `PokerGameState.startNewHand`, the Skip path and the fold-tick reset
`_rotatedButton` in `poker_hand_screen.dart`, and the bust handler
`_adjustButtonForRemovedPlayer`. All of them worked from the CURRENT button
and the list of ACTIVE players only. An empty seat was removed from the ring,
so a dead button or a dead small blind could not exist. The bust handler also
moved the button once itself, and `startNewHand` moved it again, so the button
could advance twice for one hand. Re-posting blinds in the same hand (a seat
filled or removed before the first action) could also advance the rotation.

## Fix

- `lib/utils/blind_rotation.dart`: ONE pure function (`BlindRotation.next` /
  `fromButton`) replaces the four copies. BB = next live seat after last BB,
  SB = last BB seat, BTN = last SB seat. An empty SB seat = dead small blind
  (nobody posts, no dead money). An empty BTN seat = dead button. Heads-up:
  BTN = SB.
- Seat memory in `PokerGameState`: the previous hand's BB and SB SEAT numbers
  are kept even after the seats empty. The hand's assignment is always derived
  from the memory, so re-posting blinds never advances it.
- Rotate once: only `rotateBlindsForNextHand()` advances the memory (new hand,
  Skip, fold tick). A manual button move restarts the memory from that button.
  Undo restores the memory (`restoreBlinds`).
- Position names in dead hands come from `getPositionNameForActivePlayers(...,
  deadSeats:)`: nobody is BTN on a dead button, nobody is SB on a dead SB.
- `HandRecord` stores `bbSeat`, `sbSeat`, `smallBlindDead`. SQLite schema v21
  (idempotent ADD COLUMN). Hands saved before this release have no `bbSeat`;
  readers fall back to labels and button.
- PokerStars export uses the persisted seats and writes no "posts small blind"
  line on a dead SB. The web export has the same rule (parity goldens
  `cash_dead_button_steal`, `cash_dead_sb_walk`).

## Rule sources

TDA Rule 34 (button and blinds) and Rule 36-C, Robert's Rules text via Card
Player, and the TDA forum. The founder decided on 2026-11-06 that cash games
use the dead button too (no setting). Two points are inferences, not verified
rules: the ante on a dead-SB hand, and real cash room practice.

## Known gaps

- A reopened dealer table loses a pending dead SB. Only the button is stored.
- The AI analyzer `_calculatePosition` fallback can mislabel a player with no
  recorded action in a dead hand.

Both are in ROADMAP.md (item 16).

## Testing

Founder approved the result on 2026-11-06. Automated tests passed. Claude ran
nothing on a device.

Tests: `flutter test` 1552 passed, 1 skipped; web parity goldens passed; final-table-web `vitest` 1560 passed.
