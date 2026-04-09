# Dealer Voice Logging Guide

A step-by-step guide for dealers using voice-powered hand logging in Poker Friend.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Voice Command Format](#voice-command-format)
3. [Logging a Full Hand](#logging-a-full-hand)
4. [Board Cards & Street Transitions](#board-cards--street-transitions)
5. [Handling Raises & Bets](#handling-raises--bets)
6. [Undo & Rollback](#undo--rollback)
7. [Hold Mode (Pause/Resume)](#hold-mode-pauseresume)
8. [Common Situations & Tips](#common-situations--tips)
9. [Troubleshooting](#troubleshooting)

---

## Getting Started

### Before the Session

1. **Position your phone** where you can see the screen and speak naturally (6-12 inches from mic)
2. **Minimize background noise** — voice recognition works best in quieter environments
3. **Confirm players are seated** — all seats should be assigned before starting

### Starting Your First Hand

1. Tap **"Start Hand"** to begin
2. Voice mode activates automatically on the first hand
3. Blinds are posted automatically based on your session settings
4. The current player is highlighted — this is who should act next

---

## Voice Command Format

Every voice command **must include a seat number**. The system will reject any action without one.

### Three Ways to Say the Seat

| Format | Example | Speed |
|--------|---------|-------|
| Full: "seat N" | "Seat 4 call" | Clearest |
| Short: "sN" | "S4 call" | Quick |
| Bare number | "4 call" | Fastest |

### Supported Actions

| Action | What to Say | Aliases |
|--------|-------------|---------|
| Fold | "seat 3 fold" | "pass", "muck" |
| Check | "seat 3 check" | "checking" |
| Call | "seat 3 call" | "calling" |
| Bet | "seat 3 bet 500" | "betting" |
| Raise | "seat 3 raise 2000" | "re-raise", "raising" |
| All-in | "seat 3 all in" | "shove", "jam" |

### Amount Formats

| Format | Example | Parsed As |
|--------|---------|-----------|
| Plain number | "raise 2000" | 2000 |
| With comma | "raise 2,000" | 2000 |
| K suffix | "bet 2.5k" | 2500 |
| Word form | "raise two thousand" | 2000 |

---

## Logging a Full Hand

### Step 1: Preflop Action

The system knows who posts blinds. Action starts from UTG (under the gun).

```
You say:          What happens:
"3 fold"       →  Seat 3 folds
"4 call"       →  Seat 4 calls the big blind
"5 raise 600"  →  Seat 5 raises to 600
"6 fold"       →  Seat 6 folds
"1 fold"       →  Seat 1 (SB) folds
"2 call"       →  Seat 2 (BB) calls the raise
```

### Step 2: Board Cards

When preflop action is complete, a **board cards dialog** appears automatically:
- Select the 3 flop cards
- Tap confirm

### Step 3: Flop, Turn, River

Continue calling out actions the same way. After each street completes:
- A dialog appears for the next board card (turn = 1 card, river = 1 card)

### Step 4: Winner

After river betting completes:
- **Winner dialog** appears
- Select the winning seat(s)
- For chopped pots, select multiple winners

---

## Board Cards & Street Transitions

### Cards Icon in Header

There is a **cards icon** in the top bar (next to the QR code). Use it to:
- **Reopen the board cards dialog** if you accidentally closed it
- Works when the betting round is complete but cards haven't been selected yet

### All-In Before River

If all remaining players are all-in before the river:
- The system shows an **all-in board cards dialog** to run out remaining streets at once
- Select all remaining board cards in one go
- No more betting rounds needed

---

## Handling Raises & Bets

### Say the Amount Together

Best practice — include the amount in the same command:

```
"Seat 4 raise 2000"   ← Executes immediately
"5 bet 500"            ← Executes immediately
```

### If You Forget the Amount

If you say "seat 4 raise" without an amount:
- The system **holds the action** and waits for the amount
- Say the full command again: "seat 4 raise 2000"
- The held action will resolve with the amount

The system waits **indefinitely** — there is no timeout. The held action is discarded only when:
- You say an action for a **different seat** (the system assumes you moved on)
- You use the **manual buttons** instead

### Amount Clamping

If the spoken amount exceeds a player's stack, the system automatically caps it to their maximum (all-in). No manual correction needed.

### Auto-Correction

The system auto-corrects common mistakes:

| You Said | Game State | System Does |
|----------|-----------|-------------|
| "check" | There's a bet to face | **Rejected** — you must say "call" explicitly |
| "call" | No bet to call | Converts to **check** |
| "bet" | Someone already bet | Converts to **raise** |
| "raise" | No bet to raise | Converts to **bet** |

---

## Undo & Rollback

### Undo Last Action

Tap the **undo button** (arrow icon) to reverse the last action:
- Chips return to the player's stack
- Pot is recalculated
- Current player moves back
- Player screens update automatically

You can undo multiple times in a row to roll back several actions.

### Cross-Street Rollback

If you undo all actions on the current street (e.g., undo all flop bets):
- The system **automatically rolls back to the previous street**
- Board cards for the rolled-back street are removed
- Pot reverts to what it was at the end of the previous street
- You can then redo the board cards and betting

**Example:** On the flop with 2 actions logged. Undo twice → system rolls back to preflop, flop cards are removed, pot returns to preflop total.

---

## Hold Mode (Pause/Resume)

### When to Use

- During card dealing (to avoid logging background chatter)
- When having a side conversation
- Any time you want voice recognition to stop temporarily

### How to Use

1. Tap the **pause icon** in the voice status bar
2. Voice recognition pauses — no actions will be logged from speech
3. Tap the **play icon** to resume
4. Recognition continues instantly (no recalibration needed)

The connection stays alive during pause — you won't lose your dealer lock.

---

## Common Situations & Tips

### Speaking Pace

- **Pause briefly** (~half second) between the seat number and the action
- Good: "Seat 4 ... call"
- Too fast: "Seat4call" (may not parse correctly)

### Multiple Actions Quickly

You can call actions in rapid succession. The system processes them one at a time and validates each against the current game state:

```
"3 fold"  →  [processes, advances to seat 4]
"4 call"  →  [processes, advances to seat 5]
"5 fold"  →  [processes, advances to seat 6]
```

### Wrong Seat Called

If you call the wrong seat number:
- Your phone **vibrates** (haptic feedback)
- The action is rejected
- Simply say the correct seat number

### BB Option (Big Blind Checks)

When action folds around to the BB with no raise:
- Say "seat 2 check" (BB checks their option)
- If you accidentally say "seat 2 call", the system auto-converts it to a check (since there's nothing additional to call)

### All-In Scenarios

- Say "seat 4 all in" — the system calculates the exact amount
- No need to know their stack size
- Works for both short-stack shoves and big-stack all-ins

### Manual Buttons as Backup

Manual action buttons are **always available** alongside voice:
- Use them if the environment is too noisy
- Use them if voice misunderstands repeatedly
- Use them for the amount entry on raise/bet if voice struggles with numbers

---

## Troubleshooting

### Voice Not Responding

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| No actions executing | Voice mode paused | Tap play/resume button |
| "Voice off" bar showing | Voice stopped | Tap the bar to restart |
| Actions rejected with vibration | Wrong seat number | Check highlighted current player |
| Raise held, nothing happens | Waiting for amount | Say full command with amount, or use manual buttons |

### Connection Issues

- If connection drops, the system tries to reconnect automatically (5-second grace period)
- If reconnection fails, voice mode will show as off — tap to restart
- WiFi/cellular signal strength affects voice quality

### Tips for Better Recognition

1. **Speak at conversational volume** — no need to shout
2. **Enunciate seat numbers clearly** — "seat four" is clearer than "s'four"
3. **Say amounts as complete numbers** — "two thousand" or "2000", not "two oh oh oh"
4. **Avoid filler words** — "um, seat 4, uh, call" may confuse the parser
5. **Face your phone** when speaking — directional mics pick up your voice better

---

## Quick Reference Card

```
FORMAT:    [seat number] [action] [amount if needed]

SEATS:     "seat 4" / "s4" / "4"

ACTIONS:   fold | check | call | bet [amount] | raise [amount] | all in

EXAMPLES:  "4 fold"
           "seat 3 call"
           "s5 raise 2000"
           "2 all in"
           "seat 6 bet 500"

UNDO:      Tap undo button (can undo multiple times)
PAUSE:     Tap pause icon in voice bar
RESUME:    Tap play icon in voice bar
CARDS:     Tap cards icon in header to reopen board cards dialog
```
