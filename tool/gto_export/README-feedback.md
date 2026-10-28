# Daily Challenge coach feedback — batch system

Persona-driven, solver-grounded coach feedback for the Daily Challenge. Three
coaches (Duke, Professor Vega, Nova) each explain the player's move in their own
voice. Feedback is **pre-generated in batch per day** (not live) — every user
of a day shares the same per-action variants, so there is zero latency before
the verdict voice and the Anthropic cost is paid once per day, not per player.

> **The authoritative contract is [`FEEDBACK-SCHEMA.md`](./FEEDBACK-SCHEMA.md).**
> This README is the operating guide; the schema file is the spec the three
> scripts conform to. Read it before changing anything.

## The three scripts

| Script | What it does |
|--------|--------------|
| `seed_coaches.js` | Pushes the repo persona files `coaches/{duke,vega,nova}.json` to Firestore `coaches/{coachKey}` so they can be hot-edited in the console. Repo JSON stays the source of truth. |
| `generate_feedback.mjs` | The batch generator (Anthropic **Message Batches API** + prompt-cached per-coach system blocks). Validates the day's authored fact blocks (rejects on any failure); then for each presented hero node × available action × coach generates **2 variants** grounded only in solver frequencies/sizes + the authored fact block. Writes `daily_challenge_lines/{dayKey}` and warms the neural voice cache. `--sample`/`--dry`/`--csv`/`--no-voice`/`--model`. |
| `test_feedback.mjs` | **Independent** audit of a generated CSV — re-runs every quality check against live solver data (does not trust the generator's own `failed` column). CI-gateable. |

## Coaches & IDs

Persona `id` (display) maps to the STORED `coachKey` used everywhere in code,
Firestore and prompts. **Always key by `coachKey`.**

| persona id | coachKey | voice (coachSpeech CF) |
|-----------|----------|-------------------------|
| duke      | grinder   | "Bill" (old American)  |
| vega      | professor | "George" (British)     |
| nova      | nova      | "Laura" (energetic)    |

## Firestore collections written

- **`coaches/{coachKey}`** — the persona file verbatim (+ `updatedAt`). Written by `seed_coaches.js`. Console-editable.
- **`daily_challenge_lines/{dayKey}`** — the generated feedback:
  ```
  { generatedAt, mode: "authored",
    hands: { "<spotKey>": { "<nodeId>": { "<actionWire>":
               { "<coachKey>": { "<level>": [v1, v2] } } } } } }
  ```
  `spotKey` = the `authored_spots` doc id; `nodeId` = the tree node (REQUIRED —
  a repeated action across streets would otherwise overwrite); `actionWire` =
  fold|check|call|raise|allin; `level` = beginner|intermediate|advanced. Keyed
  by the node + action the user **took**, so the line matches that exact decision.
- **`coach_feedback_history/{coachKey}`** — the rolling anti-repetition store (see below).

## How the app reads it

`lib/services/daily_coach_lines_service.dart` → `lineForAction({ spotKey,
nodeId, coachKey, action, level, uid, spotNumber, dayKeyOverride })`. It fetches
the day's `daily_challenge_lines` doc and navigates
`hands[spotKey][nodeId][action][coachKey][level.id]`, then picks ONE of the two
variants **deterministically per user per day** —
`FNV-1a hash(uid|dayKey|spotKey|nodeId|action|level) % 2` — so a user sees the
same variant all day, two users split across both, and it reshuffles tomorrow
(stable on a replayed past day via `dayKeyOverride`). The authored screen passes
the current tree `nodeId` + the player's `CoachLevel` (resolved via
`CoachLevelResolver`). For Nova it prepends a short client-side session opener.
On a miss it returns null and the caller falls back to the built-in persona
template — so the feature never *depends* on generation being present. When an
AI line IS present it is the whole coach line; the template opener is only used
on the fallback.

## The hard rule: frequencies and sizes only, never invent numbers

The solver export carries **frequencies and bet/raise sizes only** — no EV, no
range-advantage %, no nut-advantage %. The prompt forbids stating any number
that is not an action frequency (as %) or a size (in BB) from the context.
Personas may discuss those concepts *qualitatively* (Vega's lens does) but may
attach **no number** to them. Validation enforces this.

## Fact-block validation (the day is rejected on any failure)

The browser agent authors a JSON **fact block** in sheet column M (+ an optional
`mags_note` in column N); `build_tree.js` parses it onto each tree node. Before
generating, `generate_feedback.mjs` validates EVERY presented hero node and
**rejects the whole day** (writes nothing) if any node fails. Scope: only nodes
on lines where every prior hero action is played ≥ 20% (`MIN_LINE_FREQ`). Checks:

1. **Every fact gives a reason** (`because`/`so`/`which means`); no fact may just list hands.
2. **Exact hero combo with suits** — no `"depending on suits"`.
3. **Solver/strength consistency** — "beats most" + `solver.fold ≥ 0.8` must be explained (polarization/sizing/blockers).
4. **`level_hints` keys are `beginner`/`intermediate`/`advanced`** (not `pro`) and are TEACHING content, not instructions.
5. **`wrong_action_notes` for every action the solver plays < 10%** (keyed off the block's own `solver` map).
6. **key_concept specificity** — reject if one `key_concept` covers > 30% of a spot's nodes.

`mags_note` (column N) is optional and is passed to coach generation as an
**authoritative override** — the coach honours its angle over its own read.

Preview before committing a day: `--sample [N]` (default 10) generates N random
nodes to a CSV and writes nothing else — eyeball it, then run for real.

## Anti-repetition (rolling 7 days, per coach)

`coach_feedback_history/{coachKey}` keeps the last 7 days of **opening phrases**
(first 3 words) and `material_bank` concepts used. The generator passes them
into every prompt as "recently used, avoid", then appends the day's new openings
and trims to the window. Within a day, an action's 2 variants must open with
different first-3-words.

## Validate → regenerate once → fallback

Every generated variant is checked: (1) **number-match** — each `N%` within 1pp
of a context frequency, each `N BB` matching a context size; (2) **never_say** —
no forbidden phrase (emoji / "!" handled specially); (3) **opening** — not a
recently-used or sibling-variant opening. On any failure the variant is
regenerated **once** (a small follow-up batch); if it still fails it falls back
to a safe, number-free template derived from the fact block's `key_concept`, and
the failure is logged. An invalid line is never written.

## Running it

```bash
cd tool/gto_export
export ANTHROPIC_API_KEY=...            # required; never logged. Creds: ./service-account.json

node seed_coaches.js                    # push personas to Firestore (once / after edits)
node seed_coaches.js --show             # inspect what's stored

node generate_feedback.mjs --day 2026-10-28 --dry            # validate only, no submit (FREE — do this first)
node generate_feedback.mjs --day 2026-10-28 --sample         # 10 random nodes → CSV (cheap preview)
node generate_feedback.mjs --day 2026-10-28                 # generate + upload + warm voice (prints COST, asks to confirm)
node generate_feedback.mjs --day 2026-10-28 --yes           # ...skip the cost confirmation (scripted runs)
node generate_feedback.mjs --day 2026-10-28 --csv day.csv   # + review CSV
node generate_feedback.mjs --day 2026-10-28 --no-voice      # skip voice pre-render
node generate_feedback.mjs --day 2026-10-28 --model opus    # sonnet (default) | opus

node test_feedback.mjs --csv day.csv --day 2026-10-28       # independent audit
```

💲 **Cost**: a full run prints a rough estimate and asks before submitting. A
5-spot 100BB day ≈ 675 requests × 3 levels ≈ **$3-4**. Regenerate ONLY the day
whose fact blocks changed — not all days — and `--dry` first (free).

`generate_feedback.mjs` submits ONE Message Batch and polls until it ends
(validation retries go in a second small batch). Batch turnaround is typically a
few minutes even for a small day — run it in the background, not a foreground
shell with a short timeout. Voice pre-render then POSTs each final line to the
`coachSpeech` CF so the MP3 caches before any player hears it.

## Review target (the "180 outputs" acceptance check)

The original spec asks to review 3 coaches × 20 fixed spots × correct/mixed/
incorrect verdicts ≈ 180 outputs. Satisfy it by generating **several authored
days** (each day contributes all its spots × actions × coaches × 2 variants,
which naturally spans correct/mixed/incorrect verdicts because every available
action at every hero node is covered), concatenating their `--csv` outputs, and
auditing the combined file:

```bash
for d in 2026-10-25 2026-10-26 2026-10-28; do
  node generate_feedback.mjs --day "$d" --csv "fb-$d.csv"
done
# concatenate (keep one header), then audit — pass --day for the richest day
head -1 fb-2026-10-25.csv > fb-all.csv
tail -n +2 -q fb-*.csv >> fb-all.csv
node test_feedback.mjs --csv fb-all.csv
```

The audit reports a per-coach table (number-match rate, never_say violations,
repeated openings, average length, max_words overflow) plus a totals line, and
exits non-zero if any never_say violation or number-match failure survives —
so it doubles as a CI gate.
