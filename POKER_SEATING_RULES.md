# Poker Seating Rules — deferred correctness work

Cases the app should eventually enforce around players joining/leaving the table.
**Not implemented yet** — captured here so the initial seating fix (2026-07-21)
stays simple. See `test/HAND_LOGGING_SPEC.md` for the implemented boundary rule.

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
- **Dead button rule:** when the SB busts/leaves, next hand the button points at
  an empty seat ("dead button") rather than skipping ahead — nobody gets to be
  BTN twice / skip blinds.
- **Dead small blind:** BB busts → who posts what next hand.
- **Missed blinds:** player sits out through their blinds and returns — post
  both / wait for BB (house-rule choice).
- **Heads-up transitions:** 3-handed → heads-up blind assignment when a player
  leaves mid-orbit.

## Where this will live when implemented

Entry-eligibility belongs at the **hand boundary** (the pending-seat flush in
the screen + position recompute), NOT inside `PokerGameState` mid-hand logic.
Each rule above becomes an invariant + test in `test/HAND_LOGGING_SPEC.md`
before implementation.
