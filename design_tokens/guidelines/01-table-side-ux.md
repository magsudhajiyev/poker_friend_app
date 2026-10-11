# Table-side UX rules

These rules bind every screen used during a live session. A design that breaks one needs a written exception (see Governance).

## The live-session context

| Constraint | What it means for design |
| --- | --- |
| One hand free, phone low or under the table | In-hand controls sit in the bottom of the screen; nothing important only at the top |
| 20–60 seconds between hands | A hand must be loggable in under 10 seconds |
| Dim, warm room light | Dark theme by default; contrast floors are minimums |
| Opponents can see the screen | No sound, no celebratory animation, no full-screen colour flashes; Bankroll supports a hidden (blurred) state |
| Attention is on the game | One decision per step; no reading required to proceed |
| Patchy casino Wi-Fi | Offline-first; sync status is a `footnote` line, never a blocking dialog |

## Hit targets

- Minimum target 44×44 pt (iOS). Top-bar icon buttons and tab items already meet it.
- `Button` Small (26 pt tall) is below the minimum: use it only off the table (settings, summaries) and extend its tap area to 44 pt in code. Inside the hand logger use Large (50 pt).
- The "+" in the tab bar (54 pt) starts a hand or session; keep it the only floating action.

## The three-gesture hand

The core flow is **cards → action → result**:

1. **Cards** — hero's hole cards on a rank × suit keypad. Two taps per card is the ceiling.
2. **Action** — the line taken by street, with sizing prefilled from the last similar spot.
3. **Result** — won, lost or chopped, with the amount prefilled from the stack change.

- Prefill everything predictable (position rotates, blinds and stack carry over). The player corrects, never enters.
- A hand saved with only a result is valid and marked incomplete in `text-warning`.
- Back is one gesture and never discards input.
- No confirmation dialogs inside the flow; offer undo for 5 seconds instead.

## Layout

- Screen gutter `spacing-16`; sections separated by `spacing-24` and introduced by `SectionHeader`.
- Top of every main screen: `TopBar` (wordmark + up to two `IconButton`s). Bottom: `TabBar` with Home, Opponents, Stats, Sessions and the "+" action.
- Lists of sessions use `SessionCard`, 12 pt apart.
- The live header shows three things only: stack (`large-title`), session result (`text-success`/`text-danger`, signed), elapsed time (`footnote`).

## Interruptions

- The app can be backgrounded mid-hand; restore to the exact step on return.
- A hand in progress survives app kill, phone lock and going offline.
- Notifications are off during a live session unless the player turns them on.

## After the session

Analysis screens can be denser: tables of figures in tabular numerals, graphs with `accent-success` above zero and `accent-danger` below, and the series colours from the Earnings chart (Tournament `accent-info`, Cash Game `accent-primary`).
