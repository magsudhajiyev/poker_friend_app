# 2026-10-28 — Daily Challenge: AI coach feedback (batch-generated, per-node/level)

Built the persona-driven AI coach-feedback system for the authored (solver
game-tree) Daily Challenge, plus a batch of on-device fixes found while playing
it. All on `main`, committed (not pushed). Feature stays behind the admin-only
`daily_challenge` flag.

## What it is

Three coaches (Duke/`grinder`, Prof. Vega/`professor`, Nova/`nova`) explain each
graded decision in their own voice, grounded ONLY in the solver's frequencies +
the authored fact block — **pre-generated in batch, never per-decision**. At
play time the app does a local grade + one cached Firestore read; zero LLM calls.

## Pipeline (all out of band)

```
authored sheet col M (JSON fact block, by the browser agent)
  → build_tree.js      (parse → authored_spots/{id}, deals the exact fact combo)
  → generate_feedback.mjs (Anthropic Message Batches API, prompt-cached system)
       validate fact blocks → reject day on any failure (6 content checks)
       one request per spot × NODE × action × coach × LEVEL → 2 variants
       validate (numbers / never_say / openings) → retry once → fallback
       write daily_challenge_lines/{dayKey}  +  warm voice via coachSpeech CF
  → app reads DailyCoachLinesService.lineForAction(...)
```

Files: `coaches/{duke,vega,nova}.json` (persona source of truth),
`tool/gto_export/{generate_feedback.mjs,seed_coaches.js,test_feedback.mjs,
FEEDBACK-SCHEMA.md,README-feedback.md}`. Contract: `FEEDBACK-SCHEMA.md`.

## Storage shape — keyed by NODE and LEVEL (the big fix)

```
hands[spotKey][nodeId][action][coachId][level] = [variantA, variantB]
```

- **`nodeId` is mandatory.** A hero action repeats across streets (preflop call,
  flop call, river call …). The first shape keyed by action alone, so later
  nodes silently OVERWROTE earlier ones — a preflop BB-defense call showed a
  flop two-pair line ("76o made two pair, calling 21.8bb" before any flop). Now
  one entry per node; the generator ABORTS with a COLLISION error if a full key
  is written twice.
- **`level`** (beginner/intermediate/advanced) adapts depth, fed by the fact
  block's `level_hints`. The authored screen resolves the tier via
  `CoachLevelResolver` (like the RNG screen) and passes it + the current node id
  to `lineForAction`. Per-user variant pick:
  `FNV-1a hash(uid|dayKey|spotKey|nodeId|action|level) % 2`.

## Other fixes this session

- **Validator too strict for Vega** — the number check only allowed the hero's
  own action numbers, so Vega (who cites the villain's sizing, e.g. "the HJ's
  100% pot bet / 6.2bb") failed ~40% → fell back. `allowedNumbers` now also
  harvests every % / BB figure from the fact-block text (ground truth).
- **Dealt cards must match the fact block** (`build_tree.js`): the auto-picker
  chose suits that could differ from `hero_hand` (one spot dealt K♠Q♠ vs
  Kh-Qh). Now deals the exact fact combo, auto-pick only if it clashes with the
  board. Scanned all 24 spots — only `btn-sb-9h7s2d-kqs` was wrong; fixed.
- **Hero not first to act** (`authored_situation.dart` + screen): a BB-defense
  spot read "folds to you on the BB" and `describe()` crashed (`history[-1]`).
  Now the opener's action is recorded before the first hero decision and a
  dedicated `openIntro` branch narrates it ("the button raises you to 2BB,
  action on you"). Test added (BB-defense group).
- **Hand notation + punctuation** (screen): collapse the hero's exact combo in
  AI lines to class notation (`98o`/`45s`); ensure a terminal period; prompt
  now requires class notation + proper sentence punctuation.
- **Villain action timing** (screen): the villain's response (their bet after
  you check) no longer pops instantly on your click. It's hidden through the
  feedback card and fades/scales in on "Next" with a light haptic, overlapping
  the coach's between-decision setup line. Terminal hands still show the final
  move on the feedback card.
- **PostHog person name** (`analytics_service.dart`): `identify()` now sends
  `name`/`email` person properties so the dashboard shows names, not uids;
  `refreshIdentity()` on username set.
- **Cost guard** (`generate_feedback.mjs`): prints a rough cost estimate and
  requires confirmation before submitting a batch (`--yes`/`-y` to skip; not
  shown for `--dry`/`--sample`). A full-day regen is ~$3-4 — regenerate only
  the changed day.

## Data state

All five days (2026-10-24 … 2026-10-28) imported, validated, and published with
the node+level shape. 24 = 4 spots (its 5th sheet has no fact block yet); the
rest are 5. Voice clips NOT warmed — ElevenLabs quota exhausted (resets
~2026-11-13); the coach types every line and stays silent until credits return.

## Verification

- `flutter analyze`: 0 errors (628 pre-existing warnings, baseline unchanged).
- `flutter test` (authored + daily-challenge suites): all pass, incl. the new
  BB-defense situation test and `daily_coach_lines_test`.
- Generator: node-keyed output verified (preflop vs flop call differ); collision
  check never fired; cost gate aborts cleanly on "n".
