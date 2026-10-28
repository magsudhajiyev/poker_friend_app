# Daily Challenge coach feedback — shared contract

This is the single source of truth for the batch coach-feedback system. The
generator, seed script, and test harness all conform to it. The Flutter client
reads it via `lib/services/daily_coach_lines_service.dart`
(`lineForAction`).

## Coaches

Three personas. Repo source of truth: `coaches/{duke,vega,nova}.json`
(project root). Each file has a `coachKey` field mapping the display id to the
STORED key used everywhere in code + Firestore:

| persona id | coachKey (stored) | voice cast (coachSpeech CF) |
|-----------|-------------------|------------------------------|
| duke      | grinder           | "Bill" (old American)        |
| vega      | professor         | "George" (British)           |
| nova      | nova              | "Laura" (energetic)          |

ALWAYS key Firestore + prompts by `coachKey`, never the persona `id`.

## Persona file schema

```
{ id, coachKey, name, tagline, background, lens,
  voice: { sentence_style, address_user_as[], vocabulary_prefer[],
           vocabulary_avoid[], max_words },
  reactions: { correct, incorrect, mixed_spot },
  material_bank: [ { concept, note } ],
  material_rules, never_say[], example_answers: [ { situation, answer } ] }
```

## Firestore: `coaches/{coachKey}`

The seed script writes each persona file to `coaches/{coachKey}` verbatim
(plus `updatedAt`). Editable in the console without an app release. The repo
JSON stays the source of truth; re-run the seed after editing.

## Firestore: `daily_challenge_lines/{dayKey}`

`dayKey` = `YYYY-MM-DD`. Shape the client reads (PER-ACTION):

```
{
  generatedAt: <server timestamp>,
  mode: "authored",
  hands: {
    "<spotKey>": {                     // authored spot id, e.g. "bb-hj-8h5h3c-33"
      "<nodeId>": {                    // tree node id, e.g. "n2" — REQUIRED key
        "<actionWire>": {              // fold | check | call | raise | allin
          "<coachKey>": {              // grinder | professor | nova
            "<level>": [               // beginner | intermediate | advanced
              "variant 1", "variant 2" // EXACTLY two variants, open differently
            ]
          }
        }
      }
    }
  }
}
```

- One entry per **spot × hero NODE × available action × coach × level**, 2 variants.
- **`nodeId` is mandatory** — a hero action repeats across streets (preflop call,
  flop call, river call …); keying by action alone silently overwrote earlier
  nodes (2026-10-28 bug: a preflop call showed flop two-pair text). The generator
  fails the run with a COLLISION error if the same full key is written twice.
- `level` adapts depth (beginner/intermediate/advanced), fed by the fact block's
  `level_hints`. The client resolves the player's tier via `CoachLevelResolver`.
- `spotKey` = the authored spot id (the Firestore doc id in `authored_spots`).
- Keyed by the action the USER TOOK (so feedback matches that action's verdict).
- The two variants for an action MUST open with different first 3 words.

## Fact block — the structured ground truth (sheet column M, JSON)

Newer solver sheets emit a JSON **fact block** in column M (and a free-text
`mags_note` in column N). This is the authoritative per-hero-node source the
coach feedback is grounded in. `build_tree.js` parses column M as JSON and
stores it on the tree node as `facts` (the structured object); it also derives
a plain-text `explanation` string from it (see "Grader fallback" below) so the
in-app grader + existing tests keep working.

Fact-block JSON shape (field names are canonical — do not rename):

```
{
  "step": <int>,                       // sheet step number
  "hero_hand": "AJs",                  // the real combo w/ suits — no "depending on suits"
  "hand_class": "suited broadway ace", // the hand-strength class on this board
  "solver": { "call": 1 },             // {action: freq} for THIS node (sums ~1)
  "facts": [ "...", "...", "..." ],    // >= 3 fact strings; EACH must give a reason
  "villain_view": "...",               // what villain's action/range means
  "threats": "..." | [ "...", ... ],   // board threats (string OR array)
  "wrong_action_notes": {              // one entry per action the solver plays < 10%
    "fold": "...", "raise": "...", ... // keyed by action wire string; {} is valid
  },
  "key_concept": "...",                // node-SPECIFIC idea (not a reused generic label)
  "concept_tags": [ "polarization", ... ],
  "level_hints": {                     // keys EXACTLY beginner/intermediate/advanced
    "beginner": "...",                 // TEACHING content, not an instruction
    "intermediate": "...",
    "advanced": "..."
  }
}
```

Column N `mags_note` is a maintainer free-text note; parsed to the node as
`magsNote` (optional, not required for completeness).

### Day completeness gate + validation checks

The browser agent authors the column-M fact block; the generator INGESTS,
VALIDATES, and REJECTS the whole day on any failure (prints every offending
spot/node + reason, writes nothing). A plain-prose M (old style) counts as
missing. **Policy:** already-published PROSE days keep their existing lines and
stay playable; only NEW days require JSON.

**Scope (check 9):** only nodes on lines where EVERY prior hero action is played
≥ 20% are validated + generated (keeps volume sane, skips near-impossible
lines). A node's own available actions are NOT frequency-filtered — the player
can still pick a rare action there.

**Structural:** `hero_hand`, `hand_class`, `solver` (object `{action:freq}`),
`facts` (≥ 3), `key_concept`, `level_hints`.

**Content checks (reject on failure):**
1. **Every fact gives a reason** — contains `because` / `so` / `which means`;
   no fact may merely list hands.
2. **Exact hero combo with suits** — reject `"depending on suits"` / a
   non-specific `hero_hand`.
3. **Solver/strength consistency** — if the facts claim the hand "beats
   most/is ahead" yet `solver.fold ≥ 0.8`, the facts MUST explain the
   contradiction (polarization / sizing / blockers), else reject.
4. **`level_hints` keys are exactly `beginner`/`intermediate`/`advanced`** (the
   solver sheet's `pro` key is rejected) AND the values are TEACHING content,
   not instructions (a hint starting "Explain…/Focus on…/Discuss…" is rejected).
5. **`wrong_action_notes` for every action the solver plays < 10%** (keyed off
   the fact block's own `solver` map — a 44/56 check/bet mix needs none).
6. **key_concept specificity** — reject if any single `key_concept` covers
   > 30% of a spot's nodes (generic-label reuse).

`mags_note` (column N) is OPTIONAL — not required for completeness. It is an
authoritative OVERRIDE passed into coach generation (see below).

### Dry-run sample (check 10)

`--sample [N]` (default 10) generates feedback for N random presented hero nodes
and writes a review CSV — it does NOT submit the full day, write Firestore, or
warm voice. Run it first, eyeball the CSV, then re-run without `--sample`.

### Grader fallback string

`build_tree.js` derives a plain `explanation` string from the fact block
(`key_concept` + the first fact, trimmed) and stores it alongside the structured
`facts`. The in-app `AuthoredSpotGrader` uses that string verbatim when no AI
line is cached (unchanged behaviour); the JSON is additive, never a breaking
replacement. Prose-era nodes keep their raw string as `explanation` with no
`facts`.

## Spot context (what the generator feeds the model)

Build ONLY from data we actually have — NEVER invent numbers. Per hero
decision node in the authored tree (`authored_spots/{id}.treeJson`, parse the
`treeJson` string → `{ heroHandClass, heroCards[], heroPosition,
villainPosition, stackBB, formatLabel, nodes{} }`; a node has
`street, board[], actor, potBB, toCallBB, actions[], sizingBB{}, freq{action:{hand:freq}}, explanation, children{}`):

Available numbers:
- `heroHandClass` (e.g. "33"), `heroCards` (["8h","5h"] style; display only).
- For each available `action`: its solver **frequency** for the hero hand
  (`freq[action][heroHandClass]`, 0..1) and its **size** (`sizingBB[action]`, in BB).
- `potBB`, `toCallBB`, board, street, positions, stack depth, format.
- The node's **fact block** (`facts` object, see above) — the richest ground
  truth: `facts[]`, `key_concept`, `villain_view`, `threats`, `concept_tags`,
  the per-action `wrong_action_notes`, and the per-tier `level_hints`. For the
  CHOSEN action's feedback, include the matching `wrong_action_notes[action]`
  when the action is a non-solver line so the coach explains the specific leak.
- Verdict band for the chosen action (reuse the app's bands):
  freq ≥ 0.65 → "correct"; ≥ 0.15 → "mixed"; else "incorrect".

NOT available — never state them: EV / EV-loss in BB, range advantage %,
nut advantage %, explicit blocker combos. The personas may speak about these
CONCEPTS qualitatively (Vega's lens mentions them) but must attach NO number
to them. The only numbers allowed in output are frequencies (as %) and sizes
(in BB) that appear in the context.

## Prompt assembly — ONE request per (spot × action × coach), 2 variants

System = persona rendered to instructions + global rules, **marked cacheable**
(`cache_control: ephemeral`) so a coach's system block is cached across all its
requests in the run (update 3 — prompt caching):
- Speak only as the coach; stay within `voice.max_words`.
- Use ONLY numbers from the context (frequencies as %, sizes in BB). No EV,
  no range/nut-advantage numbers.
- Reaction mode = the verdict (correct → reactions.correct, etc.).
- Follow `material_rules`; never use any `never_say` phrase.
- Do not open with the same first 3 words as any entry in "recently used".
Few-shot: the persona's `example_answers` (part of the cached system block).
User message = the context object as JSON + "return a JSON array of exactly 2
variant strings that OPEN DIFFERENTLY from each other". Generating both variants
in one request (a) halves request count, (b) lets the model make them diverge,
(c) removes the sequential opening dependency that blocked batching.

## Generation — Anthropic Message Batches API (update 3)

The generator builds ALL requests up front (one `custom_id` per
spot·node·action·coach), submits ONE `messages.batches.create`, polls until
`ended`, then streams results. Batch pricing (~50% off) + prompt-cached system
blocks keep a full day **under ~$1/day**. Flags: `--model sonnet|opus`
(default sonnet), `--dry` (build requests, don't submit), `--csv <file>`.
Key from env `ANTHROPIC_API_KEY` (NEVER hardcode/log). A tiny follow-up batch
handles regenerate-once for variants that fail validation; survivors fall back.

## Anti-repetition (rolling 7-day, per coach)

Firestore `coach_feedback_history/{coachKey}`: last 7 days of OPENING PHRASES
(first 3 words) + `concept_tags` used, passed into every prompt as "recently
used, avoid". After the run, append the day's openings/concepts, trim to 7 days.
The two variants of one action must open differently (enforced in-request + a
post-check).

## Validation (post-batch, per variant)

1. **Number check**: every `N%` within 1pp of a context frequency; every
   `N BB` matches a context size. Fail → regenerate once.
2. **never_say check**: reject on any `never_say` phrase (emoji / `!` handled
   specially). Fail → regenerate once.
3. **Opening check**: reject if it repeats a recently-used or sibling opening.
   Fail → regenerate once.
4. Still failing after one regenerate → FALL BACK to a safe template (the node's
   derived `explanation` string trimmed to `max_words`) and LOG it.

## Voice pre-render (update 4)

After the day's lines are finalized + written, the generator warms the neural
voice cache so every line plays instantly in-app: for each unique final line it
mints a Firebase ID token (Admin `createCustomToken` → exchange via
`signInWithCustomToken` REST with the project Web API key) and POSTs
`{text, coach}` to the deployed **`coachSpeech`** Cloud Function — exactly as the
app does, so the MP3 is cached in Storage under the SAME key
`sha256(coach|voiceId|text)` the app fetches. The ElevenLabs key stays only in
the CF. Skippable with `--no-voice`. The text sent is the FINAL stored variant,
unchanged (the app applies `speakable()` at play time — keep the warm text in
sync with what the app speaks, i.e. warm the composed line the app will send).

## Storage shape — node + action + coach + level (update 2, revised)

`daily_challenge_lines/{dayKey}`:
```
{ generatedAt, mode: "authored",
  hands: { "<spotKey>": { "<nodeId>": { "<actionWire>":
             { "<coachKey>": { "<level>": ["v1","v2"] } } } } } }
```
Keyed by the NODE + the action the user TOOK + coach + level; exactly two
variants, opening differently. See the top of this file for why `nodeId` is
mandatory (overwrite bug). The generator ABORTS with a COLLISION error if any
`spot/node/action/coach/level` key would be written twice.

## Cost estimate + confirmation

`generate_feedback.mjs` prints a rough cost ceiling and requires interactive
confirmation before submitting the main batch (skipped by `--yes`/`-y`, and not
shown for `--dry`/`--sample`). Full-day regenerations are NOT free: a 5-spot
100BB day is ~675 requests × 3 levels ≈ $3-4. Regenerate ONLY the day whose
fact blocks changed, and validate first with `--dry` (free) / `--sample`
(cheap). Prices are in `BATCH_PRICE` — update if Anthropic pricing changes.

## Per-user variant pick (update 5)

The client picks ONE of the two variants deterministically per user per day:
`variantIndex = hash(uid|dayKey|spotKey|nodeId|action|level) % 2`. Stable all
day, splits users across both variants, reshuffles tomorrow, stable on replays,
no storage/network. When an AI line is present it IS the whole coach line — the
rotating template opener is NOT prepended (that only applies to the
template-reason fallback). Implemented in `DailyCoachLinesService.lineForAction`
(takes `uid`, `nodeId`, `level`, `dayKeyOverride`) + `CoachPersona.compose(aiLine:)`.

## Dealt cards (card fix)

`build_tree.js` deals the EXACT hero combo from the fact block's `hero_hand`
(e.g. "7s-6h" → 7♠6♥), falling back to the auto-picker only if that combo
clashes with the board. Keeps the dealt cards consistent with the authored
reasoning (bug: a KQs spot dealt K♠Q♠ while the facts assumed K♥Q♥).

## Logging

Per variant: coachKey, spotKey, actionWire, verdict, output, failed checks,
fellBack. Plus a run summary: request count, cache-hit tokens, fallback rate,
voice clips warmed, est. cost.
