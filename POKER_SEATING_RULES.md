# Poker Seating Rules — deferred correctness work

Cases the app should eventually enforce around players joining/leaving the table.
Dead button and dead small blind are IMPLEMENTED (below). Everything under
"NOT yet enforced" is still future work. See `test/HAND_LOGGING_SPEC.md` for the
implemented boundary rule.

## Dead button and dead small blind (IMPLEMENTED, founder decision 2026-11-06)

Cash AND tournament, no setting. Rule: TDA Rule 34. Sources:
https://www.pokertda.com/view-poker-tda-rules/ and
https://cardplayer.com/rules-of-poker/buttons-and-blinds

Code: `lib/utils/blind_rotation.dart` (pure) used by `PokerGameState`; tests
`test/dead_button_rotation_test.dart` (vectors), `dead_button_engine_test.dart`,
`dead_button_session_test.dart`.

- Memory = last hand's BB seat and SB seat (seat numbers, kept when vacated). Live = seat with a player with chips.
- Next hand: BB = first live seat after last BB. SB = last BB seat (empty = dead SB: nobody posts, no dead money). BTN = last SB seat (empty = dead button).
- Exactly 2 live: BTN = SB = the other live seat. Nobody pays BB twice in a row.
- BB posts BB + full BB ante in dead SB and dead button hands.
- Preflop first: heads-up BTN, else first live after BB. Postflop first: heads-up BB, else first live seat after the button SEAT (empty or not); last: last live seat at or before it.
- Position names are real: dead button = nobody is BTN; dead SB = nobody is SB.
- Heads-up back to 3+ can make the remembered SB equal the new BB. Then the button goes to the last live seat before the SB (the entrant joins behind the button).
- Manual button move (before any action) restarts the memory from that button. Dropping it on an empty seat is not possible in the UI (drop targets are live seats); the engine would treat it as a dead button.
- A player seated pre-action in the dead SB seat makes that seat live: they post the SB. No entry-eligibility rules (still future work, below).
- Removing the current BB before any action re-derives the blinds as if they left before the hand.

## Implemented today (baseline)

- **Boundary rule:** a player added while `currentHand.actions.isEmpty` joins the
  current hand (positions + blinds recomputed, `initializePot` re-posts). A player
  added after any action sits out (deferred activation — engine not told until
  next `startNewHand()`), shown dimmed. Same rule applies to the hero re-seating.

## NOT yet enforced (future work)

### 1. New player seating directly into the SB position
By live poker rules, a new player cannot be dealt in as the **small blind** on
their first hand. They must wait until the BB reaches them (or, house-rule
variant, post a BB from position). Currently the app deals them in as SB if
that's where the seat falls after position recompute.

**Expected future behavior:** if the newly filled seat would be the SB for the
upcoming (or recomputed) hand, the player sits out that hand automatically and
enters on the following hand.

### 2. The same player cannot take the BTN on their next hand
Continuation of case 1: after sitting out the SB hand, the entrant must not
immediately become the **button** either (they would gain the best position
without ever posting blinds). They enter behind the button / when the BB
naturally reaches them.

### 3. Related cases to specify when we pick this up
- ~~Dead button rule~~ and ~~dead small blind~~: done, see top of this file.
- **Missed blinds:** player sits out through their blinds and returns — post
  both / wait for BB (house-rule choice).
- ~~Heads-up transitions~~: done (see top). Entry-eligibility for the returning/new player is still open.

## Where this will live when implemented

Entry-eligibility belongs at the **hand boundary** (the pending-seat flush in
the screen + position recompute), NOT inside `PokerGameState` mid-hand logic.
Each rule above becomes an invariant + test in `test/HAND_LOGGING_SPEC.md`
before implementation.
