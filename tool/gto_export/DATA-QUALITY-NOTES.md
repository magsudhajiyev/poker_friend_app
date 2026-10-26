# Daily Challenge authored-spot data-quality notes (for the extraction agent)

These are concerns found while building the 2026-10-26 spot set (5 sheets,
MTT 50bb, hero BTN vs each position). They describe how the sheets should be
exported so the app grades every hero decision correctly. The build pipeline
(`build_tree.js` → `authored_spots/{id}`) works; the gaps below are in the
**sheet data**, not the tool.

## How the app uses the data (so the "why" is clear)

Each hero decision node carries a `freq` map:

```
freq = { <action> : { <handClass> : <probability 0..1>, ... }, ... }
```

The grader (`authored_spot_grader.dart`) looks up the **hero's exact hand class**
(e.g. `TT`, `A5s`, `KQs`) across the node's actions and grades the player's
chosen action against that hand's solver frequency (BEST ≥0.65 / GOOD ≥0.15 /
LEAK <0.15, with a range-share softening). **If the hero hand is missing from a
node's `freq` map, there is no solver baseline for that decision** — the grade
degrades (no signal), the "Show range" chart for that node is incomplete, and
the coach line has nothing hand-specific to say.

So the single most important rule: **every street the hero can reach must
export per-hand frequencies that INCLUDE the specific hero hand.**

## Concern 1 — MISSING hero-hand frequencies on turn/river (HIGH)

Measured coverage of "hero nodes that contain the hero hand in their `freq`"
for the 2026-10-26 set:

| Spot (board, matchup, hero) | hero nodes with freq for the hand | missing mostly on |
|---|---|---|
| 9s8s5d BTN vs BB, A9s  | 24/32 (75%) | river |
| Qs9h8c BTN vs UTG, TT  | 52/65 (80%) | turn + river |
| 9h8c3c BTN vs HJ, A5s  | 15/18 (83%) | river |
| 9h7s2d BTN vs SB, KQs  | 26/34 (76%) | turn + river |
| 5s3c2s BTN vs CO, A4s  | 31/46 (67%) | river (heavy) |

The missing nodes cluster on **turn and river**. It looks like the later-street
range exports drop down to aggregated / top-hands-only frequencies instead of a
full per-combo range. **Fix:** on EVERY street (flop, turn, AND river), export
the full hand-level range for each action at each hero node — the same density
as the flop/preflop rows already have. If the solver only shows a subset by
default, expand it so the specific hero combos reach the river.

Minimum bar per spot: the **hero hand must appear in the `freq` map at 100% of
the hero decision nodes along the lines the hero can actually take** (not just
preflop/flop).

## Concern 2 — Hero hand is chosen by us, not in the sheet (MEDIUM)

The solver tree is hand-agnostic; we stamp a single hero hand on it at build
time (`--hero`). For the hero hand to be gradeable, it MUST be a hand the
solver range actually contains (a hand BTN would have in that spot). The
sheets don't name a hero hand, so the picker has to guess. **Fix (either):**
- (a) Name the intended hero hand in the sheet title or a header cell (e.g.
  `Hero: TT`), so the pick is authoritative and known-present; OR
- (b) Guarantee that whatever reasonable hand we pick is fully present across
  all streets (follows from Concern 1).

Current picks (confirm they're the intended teaching hands):
`9s8s5d → A9s`, `Qs9h8c → TT`, `9h8c3c → A5s`, `9h7s2d → KQs`,
`5s3c2s → A4s` (A4s was my pick for the CO spot — the original never specified
a hero hand).

## Concern 3 — Street completeness (RESOLVED, keep it this way)

Earlier exports stopped at the TURN (no river rows), so some lines ended
mid-hand. The 2026-10-26 sheets are now **river-complete** (5-card boards, a
River street present). Keep exporting the full tree to showdown. A quick
self-check before sharing: the sheet should contain at least one `River` row
and the board should reach 5 cards on lines that get there.

## Concern 4 — Column/format consistency (LOW)

`build_tree.js` expects columns:
`Date | Hand | Street | Board | Step | Spot | Actor | Actions available | Sizing | Range | Explanation`
- `Actor` must be `hero`/`villain` (or resolvable to H/V via the matchup).
- `Range` cells are `hand:share` pairs; `bet` is normalized to `raise`.
- Keep ONE consistent sheet layout. The folder currently mixes a
  "full tree" style and a newer style — same columns is fine, but verify the
  header row matches the expected names above or the tool mis-maps columns.

## What "good" looks like (acceptance checklist per sheet)
- [ ] River rows present; boards reach 5 cards on showdown lines.
- [ ] Every hero decision row (every street) has a full per-combo Range cell.
- [ ] The intended hero hand appears in the Range at EVERY hero node on its line.
- [ ] Actor column uses hero/villain consistently.
- [ ] Explanation column filled (used verbatim in the coach feedback).

---

## UPDATE — reviewer ↔ exporter reconciliation (2026-10-26)

Thanks for the detailed pass. Reconciled view:

- **Concern 1 is mostly NOT a data problem** — agreed. 47 of 55 "missing"
  nodes are lines the hero hand never takes (≤1% earlier in the line), so GTO
  Wizard correctly omits the hand. ✅ **FIXED app-side (2026-10-26):** the
  walker (`authored_tree_walker.dart`) now ENDS the hand when the hero lands on
  a node where the hero hand has no solver frequency (`TreeNode.hasHeroFreq`),
  instead of presenting an impossible decision that always graded freq=0 →
  LEAK. (This was the cause of the "Leak — you should've folded" message when
  the player DID fold at a KQs river node.) So a hero-hand-absent node is now
  treated as unreachable and simply doesn't appear as a decision. The 8 GENUINE
  export gaps below are still worth fixing (they cut the hand a touch short on
  those rare lines), but no longer misgrade.
- **Concern 2 (hero-hand columns K/L/M)** — great, already fixed from the 25bb
  set on. The 50bb sheets (2026-10-25 / 2026-10-26 folders) predate them.
- **Concern 3 (river)** — resolved, no change.
- **Concern 4 (column layout)** — real. **Please lock the fixed header** you
  proposed and we'll map by header NAME (robust to column moves):
  `Date | Hand | Street | Board | Step | Spot | Actor | Actions available | Sizing | Range | Hero hand | Hero hand strategy | Explanation`

### ACTION NEEDED from the exporter — one replacement spot for 2026-10-26

**Hard rule: every scheduled day must have EXACTLY 5 spots.**

For **2026-10-26** (MTT 50bb, hero BTN), we had 5 but DROPPED the CO spot
because it has GENUINE export gaps on reachable lines:
- **`5s3c2s · BTN vs CO · A4s`** — 7 river nodes where A4s is reached ~5% of the
  time but is absent from the Range (your note: maybe the 4♣ river blocks the
  combos). DROPPED.

The day is currently scheduled with the **4 clean spots** (A9s, TT, A5s, KQs)
so it's testable, but it is **one short of the required 5**.

**Please produce ONE new MTT-50bb BTN-vs-X spot to replace it** (any villain
position / board is fine — ideally a *different* board texture from the other
four for variety), meeting the acceptance checklist above, and crucially:
- name the hero hand (column K) so the pick is authoritative, and
- ensure that hero hand appears in the Range at every node it can reach
  (no reachable-line gaps like the A4s river).

Drop the new sheet into the `2026-10-26` Drive folder. The reviewer will build
+ upload it and re-schedule the day back to 5. (If you prefer, re-check the
A4s · 5s3c2s spot on GTO Wizard once the limit resets and fix its river range —
either a fixed A4s sheet or a brand-new spot works; we just need the 5th.)

### Also pending (optional, your call)
- You offered to back-fill Hero-hand (K) + Hero-hand-strategy (L) columns onto
  the ten older 50bb sheets using their own Range data (no GTO Wizard needed).
  That would let us re-upload the 50bb set with authoritative hero hands. Nice
  to have, not blocking — the current hero picks are all confirmed in range.
