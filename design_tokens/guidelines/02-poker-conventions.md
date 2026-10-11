# Poker conventions

How the app writes and draws poker, so hand histories and session lists read at a glance.

## Sessions

- A session title is **stakes · venue** for cash (`NL200 · Bellagio`) and the event name for tournaments (`Sunday Million`).
- The meta line is **duration • date**: `4h 32m • Jul 25`, in `footnote`, `label-tertiary`.
- The type chip shows cash (banknote glyph) or tournament (trophy glyph) on `fill-primary`.

## Money and results

- Always sign results: **+400**, **−450** (true minus U+2212, never a hyphen), `0` for break-even.
- Currency: `$ 340` for the big bankroll figure (symbol, thin space, number), `$50`, `−$50` on axes and inline (minus before the symbol).
- Thousands: `$ 39.5K`, `$55K left`; never `$55000`.
- Result colour follows the sign: `text-success` for +, `text-danger` for −, `label-primary` for 0.
- Stakes: `NL200`, `PLO500`, or `1/2` when the blind structure matters.

## Cards

- Ranks `A K Q J T 9 8 7 6 5 4 3 2` — **T** for ten. A card is rank + suit: **A♠ K♦**; compact form `AsKd`. Hand classes **AKs**, **QJo**, **77**.
- Suits use the four-colour deck, mapped to existing tokens: ♠ `label-primary`, ♥ `accent-danger`, ♦ `accent-info`, ♣ `accent-primary`.
- Unknown board cards are empty `fill-primary` slots.

## Positions, actions, streets

- Positions in caps: **UTG, UTG+1, MP, LJ, HJ, CO, BTN, SB, BB**, plus **STR** for a straddle. The hero seat is the only green badge on screen.
- Verbs: **fold, check, call, bet, raise, all-in**. Buttons show the amount, not the multiple: **Raise 60**.
- Streets: **Preflop, Flop, Turn, River, Showdown**.

## Stats

The home stats rows use the file's labels: **Play Style**, **Sessions**, **Win Rate**, **Hours**, with `—` before there is data. Play style values are single words (`Aggressive`, `Tight`, `Loose`, `Passive`).

## Dates

Short month + day (`Jul 25`) in lists; on chart axes add a space (`Oct 13`).
