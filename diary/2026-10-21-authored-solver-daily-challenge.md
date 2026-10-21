# 2026-10-21 — Daily Challenge: authored solver game-tree hands

Feature reference lives in CLAUDE.md Key Feature 18c; this entry records the
decisions and the bugs hit on the way, so they are not repeated.

## Product decisions (user)
- Hands come from solver exports (browser-assisted extraction → Google Sheet →
  `tool/gto_export/build_tree.js` → Firestore `authored_spots/{id}`).
- The hero holds a REAL hand from the ranges (first spot: 9♠9♥ LJ vs BTN,
  T♠9♣4♦) — never the board cards.
- Hero may pick ANY action; grading = solver frequency (≥65% BEST, ≥15% GOOD,
  else LEAK). Villain responds deterministically (most-likely action among the
  branches the export actually solved). A trainer must offer a Bet even where
  the solver only checks (synthetic option, graded honestly, hand continues on
  the solver line).
- A day = up to 5 hands. Score = **pot-weighted hand accuracy**, day = mean of
  hands (0–100%); decision value from the verdict letter. Schedule =
  Firestore `authored_days/{yyyy-MM-dd}` (`schedule_day.js`), bundled
  `days.json` fallback, otherwise the RNG day.
- Coach talks casually BETWEEN decisions (reacts, reads the board, what you
  hit) — never recaps the hero's move, never gives away the answer.
- Never write the vendor's name anywhere — label the data "solver".

## Bugs worth remembering
- **Villain argmax over the whole range = fold** at most response nodes,
  which ended every hand instantly. Fix: argmax only over actions that HAVE a
  child node (the solved line); plain argmax only at true terminals.
- **Pot from raise/all-in percentages was wrong** in the exporter — derive the
  pot only from `bet=X% pot (Ybb)` entries, else BFS-accumulate.
- **Single-hand day encoded as `ccom`** was read as 4 one-letter hands by the
  first "no `|` = legacy per-letter" rule. Rule changed to "no `|` = ONE hand";
  legacy RNG strings score identically (equal weights).
- **Seats straddled the neon rail** (folded right-side seats are translucent,
  so the rail showed through). Seats now sit outside the measured rail
  (≈64% × 82% of the painted oval), table pinned to the top.
- **Coach voice silent**: ElevenLabs free quota exhausted (CF 502 ← 401).
  Not a code bug; upgrade the plan (quota resets 2026-11-13).
- **Hot reload vs new fields/assets**: a new `final` field on a saved model
  throws `Null is not a subtype of String` until a hot RESTART; a new asset
  file (`days.json`) needs a full `flutter run` rebuild.

## Not done / follow-ups
Rules + `validateLeaderboardEntry` deploy (together, by name); remove the
`days.json` `default` testing bridge before the flag opens; 4 more hand
exports for a full 5-hand day; server-side replay (today the CF re-scores
submitted verdicts + weights, it does not replay the tree).
