#!/usr/bin/env node
// Batch-generate persona-driven Daily Challenge coach feedback via the
// Anthropic Message Batches API + prompt caching (target: < ~$1/day).
//
// For a given day, for each authored spot × each reachable hero-decision node ×
// each available action × each coach, generate 2 variants of in-character
// feedback, grounded ONLY in solver frequencies/sizes + the structured
// fact block (sheet column M JSON). NEVER invents EV / range-advantage numbers.
// Then warms the neural voice cache so every line plays instantly in-app.
// Writes daily_challenge_lines/{dayKey}; the app reads it via
// DailyCoachLinesService.lineForAction.
//
// Usage:
//   node generate_feedback.mjs --day 2026-10-28                  # generate + upload + warm voice
//   node generate_feedback.mjs --day 2026-10-28 --dry            # build requests only, no submit/write
//   node generate_feedback.mjs --day 2026-10-28 --model opus     # sonnet|opus (default sonnet)
//   node generate_feedback.mjs --day 2026-10-28 --csv out.csv    # dump a review CSV
//   node generate_feedback.mjs --day 2026-10-28 --no-voice       # skip voice pre-render
//   node generate_feedback.mjs --day 2026-10-28 --yes            # skip the cost confirmation prompt
//
// A COST ESTIMATE is printed and CONFIRMATION is required before the batch is
// submitted (unless --yes / --dry / --sample). Full-day regenerations are not
// free — regenerate ONLY the day whose fact blocks changed, and use --dry /
// --sample (cheap/free) to validate first.
//
// Env:  ANTHROPIC_API_KEY (required; never logged)
// Creds: ./service-account.json (gitignored)
//
// The Firestore shape, fact-block schema, completeness gate, anti-repetition,
// validation, voice pre-render and per-user variant pick are all specified in
// FEEDBACK-SCHEMA.md — keep this file in sync with it.
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { createRequire } from 'module';
import { checkPunctuation, buildFallbackPair, stripNumbers } from './text_rules.mjs';

const require = createRequire(import.meta.url);
const admin = require('firebase-admin');
const Anthropic = require('@anthropic-ai/sdk');

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..', '..');
const COACHES_DIR = path.join(ROOT, 'coaches');

// ── args ──────────────────────────────────────────────────────────────────
function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`);
  if (i === -1) return fallback;
  const next = process.argv[i + 1];
  return next && !next.startsWith('--') ? next : true;
}
const DAY = arg('day');
const DRY = process.argv.includes('--dry');
const NO_VOICE = process.argv.includes('--no-voice');
// Skip the interactive cost confirmation (for scripted/automated runs).
const YES = process.argv.includes('--yes') || process.argv.includes('-y');
const CSV = arg('csv', null);
// check 10: --sample [N] generates feedback for N random hero nodes (default
// 10) and writes a CSV for review — does NOT submit the full day, write
// Firestore, or warm voice. Run this first, eyeball the CSV, then run for real.
const SAMPLE_RAW = arg('sample', false);
const SAMPLE = SAMPLE_RAW ? (Number(SAMPLE_RAW) > 0 ? Number(SAMPLE_RAW) : 10) : 0;
const MODEL = arg('model', 'sonnet') === 'opus' ? 'claude-opus-4-8' : 'claude-sonnet-5';
// Batch pricing is per-token; sized small (2 short variants) → cheap.
const POLL_MS = 15000;

if (!DAY || !/^\d{4}-\d{2}-\d{2}$/.test(DAY)) {
  console.error('Pass --day YYYY-MM-DD');
  process.exit(1);
}
const apiKey = process.env.ANTHROPIC_API_KEY;
if (!apiKey) {
  console.error('ANTHROPIC_API_KEY env var is required.');
  process.exit(1);
}
const keyFile = path.join(__dirname, 'service-account.json');
if (!fs.existsSync(keyFile)) {
  console.error('Missing service-account.json in tool/gto_export/.');
  process.exit(1);
}
const serviceAccount = require(keyFile);
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();
// Warm the Auth service at init (its first-touch builds token verifiers; doing
// that lazily mid-fetch intermittently threw "invalid public client cert URL").
const auth = admin.auth();
const anthropic = new Anthropic({ apiKey });

const ACTION_WORDS = { fold: 'fold', check: 'check', call: 'call', raise: 'raise', allin: 'all-in' };
const LEVELS = ['beginner', 'intermediate', 'advanced'];
// check 9: only generate for nodes on lines where every prior hero action is
// played at least this often.
const MIN_LINE_FREQ = 0.2;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ── personas ────────────────────────────────────────────────────────────────
function loadCoaches() {
  return ['duke.json', 'vega.json', 'nova.json'].map((f) =>
    JSON.parse(fs.readFileSync(path.join(COACHES_DIR, f), 'utf8'))
  );
}

// ── solver bands (mirror AuthoredSpotGrader) ────────────────────────────────
function verdictFor(freq) {
  if (freq >= 0.65) return 'correct';
  if (freq >= 0.15) return 'mixed';
  return 'incorrect';
}
function reactionKey(v) {
  return v === 'correct' ? 'correct' : v === 'mixed' ? 'mixed_spot' : 'incorrect';
}

// ── load the day's authored spots ───────────────────────────────────────────
async function loadDaySpots(dayKey) {
  const dayDoc = await db.collection('authored_days').doc(dayKey).get();
  if (!dayDoc.exists) {
    console.error(`authored_days/${dayKey} not found — nothing to generate.`);
    process.exit(1);
  }
  const ids = (dayDoc.data().hands || []).filter(Boolean);
  const spots = [];
  for (const id of ids) {
    const d = await db.collection('authored_spots').doc(id).get();
    if (!d.exists) {
      console.warn(`authored_spots/${id} missing — skipped.`);
      continue;
    }
    spots.push({ id, tree: JSON.parse(d.data().treeJson) });
  }
  return spots;
}

// Villain deterministic response (mirrors AuthoredTreeWalker).
function villainNext(tree, node) {
  const withChildren = (node.actions || []).filter((a) => node.children?.[a]);
  const pool = withChildren.length ? withChildren : node.actions || [];
  let best = pool[0];
  let bestSum = -1;
  for (const a of pool) {
    let sum = 0;
    for (const v of Object.values(node.freq?.[a] || {})) sum += v;
    if (sum > bestSum) { bestSum = sum; best = a; }
  }
  return best;
}

// Hero-decision nodes the player can actually reach (walked like the app).
// SCOPE (check 9): only descend a hero branch whose action the hero hand plays
// at least [MIN_LINE_FREQ]. So every node returned sits on a line where EVERY
// prior hero action was >= 20% — keeps generation volume sane and skips
// near-impossible lines. (The node's OWN available actions are unfiltered —
// the player can still pick a 0% action there; we just don't walk DEEPER past
// a rare choice.)
function heroDecisions(tree) {
  const hand = tree.heroHandClass;
  const seen = new Set();
  const out = [];
  const stack = [tree.rootId];
  let guard = 0;
  while (stack.length && guard++ < 500) {
    const id = stack.pop();
    const node = tree.nodes[id];
    if (!node) continue;
    if (node.actor === 'hero') {
      const reachable = (node.actions || []).some((a) => (node.freq?.[a]?.[hand] ?? null) != null);
      if (!reachable) continue;
      if (!seen.has(id)) {
        seen.add(id);
        const actions = (node.actions || []).filter((a) => (node.freq?.[a]?.[hand] ?? null) != null);
        out.push({ id, node, actions });
        for (const a of actions) {
          // Only walk deeper when the hero plays this action >= 20% (check 9).
          if ((node.freq?.[a]?.[hand] ?? 0) < MIN_LINE_FREQ) continue;
          const child = node.children?.[a];
          if (child) stack.push(child);
        }
      }
    } else {
      const child = node.children?.[villainNext(tree, node)];
      if (child) stack.push(child);
    }
  }
  return out;
}

// ── fact-block completeness gate (update 1) ─────────────────────────────────
// Validate ONE node's authored fact block (column M JSON). The browser agent
// authors these; the generator ingests + validates + rejects the day on any
// failure. Structural requirements + the 6 content checks (v2 brief).
const _REASON_WORDS = ['because', 'so ', 'so,', 'which means'];
const _HAND_TOKEN = /\b([AKQJT2-9]{2}[so]?|[AKQJT2-9][shdc][AKQJT2-9][shdc])\b/;
function factHasReason(fact) {
  const f = ` ${String(fact).toLowerCase()} `;
  return _REASON_WORDS.some((w) => f.includes(w));
}
// A fact "only lists hands" if, with the hand tokens + connectors removed,
// almost no prose remains.
function factOnlyListsHands(fact) {
  const stripped = String(fact)
    .replace(/\b([AKQJT2-9]{2}[so]?|[AKQJT2-9][shdc][AKQJT2-9][shdc])\b/g, '')
    .replace(/\b(and|or|such as|like|hands|include[s]?|the|a|an|,|\.)\b/gi, '')
    .replace(/[^a-z]/gi, '')
    .trim();
  return stripped.length < 8;
}
// "solver" object in the fact block is {action: freq}. The actions the solver
// plays under 10% need a wrong_action_note.
function solverActions(fb) {
  const s = fb.solver && typeof fb.solver === 'object' ? fb.solver : {};
  return Object.entries(s).map(([a, f]) => [a, Number(f) || 0]);
}
function factBlockIssues(node) {
  const fb = node.facts;
  if (!fb || typeof fb !== 'object') return ['no JSON fact block (prose/empty column M)'];
  const issues = [];

  // ── structural ──────────────────────────────────────────────────────────
  if (!fb.hero_hand) issues.push('missing hero_hand');
  if (!fb.hand_class) issues.push('missing hand_class');
  if (fb.solver == null || typeof fb.solver !== 'object') issues.push('missing solver object');
  if (!Array.isArray(fb.facts) || fb.facts.length < 3) issues.push('needs >=3 facts');
  if (!fb.key_concept) issues.push('missing key_concept');

  // ── check 4: level_hints keys + teaching content (not instructions) ──────
  const lh = fb.level_hints || {};
  for (const lv of LEVELS) {
    if (!lh[lv]) issues.push(`level_hints.${lv} missing (keys must be beginner/intermediate/advanced)`);
  }
  if (lh.pro && !lh.advanced) issues.push('level_hints uses "pro" — must be "advanced"');
  for (const lv of LEVELS) {
    const h = String(lh[lv] || '');
    // Instruction-style ("Explain…", "Focus on…", "Discuss…") is not teaching.
    if (/^(explain|focus on|discuss|describe|mention|talk about)\b/i.test(h.trim())) {
      issues.push(`level_hints.${lv} is an instruction, not teaching content`);
    }
  }

  // ── check 1: every fact has a reason; none merely lists hands ────────────
  if (Array.isArray(fb.facts)) {
    fb.facts.forEach((fact, i) => {
      if (!factHasReason(fact)) issues.push(`facts[${i}] has no reason (because/so/which means)`);
      else if (factOnlyListsHands(fact)) issues.push(`facts[${i}] only lists hands`);
    });
  }

  // ── check 2: exact hero combo with suits; no "depending on suits" ────────
  const blob = JSON.stringify(fb).toLowerCase();
  if (blob.includes('depending on suits') || blob.includes('depending on the suits')) {
    issues.push('contains "depending on suits" — needs the exact combo');
  }
  // hero_hand should be a concrete combo (e.g. "AJs" class is ok, but the facts
  // should reference exact cards). Require hero_hand to be present & specific.
  if (fb.hero_hand && /depend|either|some suit/i.test(String(fb.hero_hand))) {
    issues.push('hero_hand is not a specific combo');
  }

  // ── check 5: wrong_action_notes for every action the solver plays <10% ───
  const wan = fb.wrong_action_notes || {};
  for (const [a, f] of solverActions(fb)) {
    if (f < 0.1 && !wan[a]) issues.push(`wrong_action_notes.${a} missing (solver plays it ${Math.round(f * 100)}% < 10%)`);
  }

  // ── check 3: solver/strength consistency ─────────────────────────────────
  // If the facts claim the hand "beats most/is ahead" yet the solver folds it
  // >=80%, the facts must explain the contradiction (polarization / sizing /
  // blockers), else it reads as self-contradictory.
  const foldF = (fb.solver && Number(fb.solver.fold)) || 0;
  const claimsAhead = /beats most|ahead of most|is ahead|beats about half|crush/i.test(blob);
  if (foldF >= 0.8 && claimsAhead) {
    const explains = /polari|sizing|size|block|range|value and bluff|too much of/i.test(blob);
    if (!explains) issues.push('facts claim "ahead" but solver folds >=80% with no polarization/sizing/blocker explanation');
  }

  return issues;
}

// Build the model context for one (node, action). Numbers only from data.
function buildContext(tree, node, action) {
  const hand = tree.heroHandClass;
  const freq = node.freq?.[action]?.[hand] ?? 0;
  const actionFreqs = {};
  for (const a of node.actions || []) {
    const f = node.freq?.[a]?.[hand];
    if (f != null) actionFreqs[a] = { frequencyPct: Math.round(f * 100), sizeBB: node.sizingBB?.[a] ?? null };
  }
  const fb = node.facts || {};
  return {
    heroHand: hand,
    heroCards: tree.heroCards || [],
    heroPosition: tree.heroPosition,
    villainPosition: tree.villainPosition,
    stackDepthBB: tree.stackBB,
    format: tree.formatLabel,
    street: node.street,
    board: node.board || [],
    potBB: node.potBB ?? 0,
    toCallBB: node.toCallBB ?? 0,
    availableActions: actionFreqs,
    chosenAction: action,
    chosenActionFrequencyPct: Math.round(freq * 100),
    verdict: verdictFor(freq),
    // Fact block (the ground truth). For a wrong action, surface its note.
    facts: fb.facts || [],
    keyConcept: fb.key_concept || '',
    villainView: fb.villain_view || '',
    threats: fb.threats || '',
    conceptTags: fb.concept_tags || [],
    wrongActionNote: (fb.wrong_action_notes || {})[action] || '',
    levelHints: fb.level_hints || {},
    // mags_note (column N): a maintainer override. When present it is the
    // AUTHORITATIVE angle — the coach must honour it over its own read.
    magsNote: node.magsNote || '',
    // The ONLY numbers allowed in output: the frequencyPct + sizeBB values above.
  };
}

// ── anti-repetition (rolling 7-day, per coach) ──────────────────────────────
async function loadHistory(coachKey) {
  const doc = await db.collection('coach_feedback_history').doc(coachKey).get();
  const data = doc.exists ? doc.data() : {};
  const cutoff = daysAgoKey(DAY, 7);
  return {
    openings: (data.openings || []).filter((o) => o.day >= cutoff),
    concepts: (data.concepts || []).filter((c) => c.day >= cutoff),
  };
}
async function saveHistory(coachKey, history, newOpenings, newConcepts) {
  if (DRY) return;
  await db.collection('coach_feedback_history').doc(coachKey).set(
    {
      openings: [...history.openings, ...newOpenings.map((text) => ({ day: DAY, text }))],
      concepts: [...history.concepts, ...newConcepts.map((concept) => ({ day: DAY, concept }))],
    },
    { merge: true }
  );
}
function opening(text) {
  return text.trim().split(/\s+/).slice(0, 3).join(' ').toLowerCase();
}
function daysAgoKey(dayKey, n) {
  const [y, m, d] = dayKey.split('-').map(Number);
  const dt = new Date(Date.UTC(y, m - 1, d));
  dt.setUTCDate(dt.getUTCDate() - n);
  return dt.toISOString().slice(0, 10);
}

// ── prompt assembly (2 variants per request, cached system) ─────────────────
function systemBlocks(coach, recentOpenings) {
  const v = coach.voice;
  const text = [
    `You are ${coach.name}. ${coach.tagline}`,
    `BACKGROUND: ${coach.background}`,
    `COACHING LENS: ${coach.lens}`,
    `VOICE: ${v.sentence_style} Address the player as ${v.address_user_as.join(' or ')}.`,
    `Prefer: ${v.vocabulary_prefer.join(', ')}. Avoid: ${v.vocabulary_avoid.join(', ')}.`,
    `Hard limit per variant: ${v.max_words} words. One short paragraph each.`,
    ``,
    `GLOBAL RULES (never break):`,
    `- Speak ONLY as ${coach.name}. No preamble, no meta, no surrounding quotes.`,
    `- You may ONLY state numbers that appear in the context JSON: action`,
    `  frequencies (as %) and bet/raise sizes (in BB). You have NO EV figures`,
    `  and NO range/nut-advantage percentages — never state such a number. You`,
    `  may discuss those ideas qualitatively only.`,
    `- React in the style given for the decision's verdict.`,
    `- Refer to the hero's hand in CLASS notation: e.g. ATs, 98o, 45s`,
    `  (s = suited, o = offsuit; pairs like 99). NEVER write the exact-suit`,
    `  combo ("As-Ts", "A♠T♠") — the context's hero_hand is data, not text to`,
    `  quote.`,
    `- PUNCTUATION: write grammatical sentences. End EVERY sentence with a`,
    `  period (or ! / ?), including the last one. Never run two sentences`,
    `  together without punctuation between them (e.g. "...value raise. The HJ`,
    `  ...", never "...value raise The HJ..."). Use commas within sentences.`,
    `- Material rule: ${coach.material_rules}`,
    `- NEVER use any of these phrases: ${coach.never_say.join('; ')}.`,
    recentOpenings.length
      ? `- Do NOT open with any of these recently-used phrases: ${recentOpenings.map((o) => `"${o}"`).join(', ')}.`
      : ``,
    `- Ground the reason in the fact block (facts / keyConcept / villainView /`,
    `  threats / wrongActionNote). Translate it into your own voice; don't quote.`,
    `- If the context has a non-empty "magsNote", it is a maintainer override —`,
    `  honour its angle/emphasis over your own read, still in your voice.`,
    ``,
    `Few-shot examples of your voice:`,
    coach.example_answers.map((e) => `Situation: ${e.situation}\n${coach.name}: ${e.answer}`).join('\n\n'),
    ``,
    `OUTPUT CONTRACT: return ONLY a JSON array of exactly TWO strings — two`,
    `feedback variants that OPEN WITH DIFFERENT first words and take different`,
    `angles on the same correct teaching. No keys, no prose around the array.`,
  ].filter(Boolean).join('\n');
  // The whole system block is cacheable — identical across all of this coach's
  // requests in the run, so prompt caching pays off (update 3).
  return [{ type: 'text', text, cache_control: { type: 'ephemeral' } }];
}
const LEVEL_DEPTH = {
  beginner:
    'Audience: a BEGINNER. Keep it simple and concrete, plain words, one clear ' +
    'takeaway. Avoid jargon; explain any term you use.',
  intermediate:
    'Audience: an INTERMEDIATE player. Assume they know the basics; focus on ' +
    'the single key idea and why it holds.',
  advanced:
    'Audience: an ADVANCED player. Be precise and technical; you may reference ' +
    'range composition and the finer reasons, concisely.',
};
function userMessage(coach, ctx, level) {
  const reaction = coach.reactions[reactionKey(ctx.verdict)];
  const hint = (ctx.levelHints && ctx.levelHints[level]) || '';
  return [
    `Write feedback for THIS decision.`,
    `Reaction mode (${ctx.verdict}): ${reaction}`,
    LEVEL_DEPTH[level] || '',
    hint ? `Teaching point for this level: ${hint}` : '',
    `Context (all facts + the only numbers you may cite):`,
    JSON.stringify(ctx, null, 2),
    ``,
    `Return a JSON array of exactly two in-character variants.`,
  ].filter(Boolean).join('\n');
}

// Parse the model's "two variants" output into exactly two strings.
function parseVariants(text) {
  const t = (text || '').trim();
  try {
    const arr = JSON.parse(t);
    if (Array.isArray(arr)) {
      const v = arr.map((s) => String(s).trim()).filter(Boolean);
      if (v.length >= 2) return v.slice(0, 2);
      if (v.length === 1) return [v[0], v[0]];
    }
  } catch { /* fall through */ }
  // Fallback: a JSON array embedded in prose.
  const m = t.match(/\[[\s\S]*\]/);
  if (m) {
    try {
      const arr = JSON.parse(m[0]);
      if (Array.isArray(arr) && arr.length) {
        const v = arr.map((s) => String(s).trim()).filter(Boolean);
        return v.length >= 2 ? v.slice(0, 2) : [v[0], v[0]];
      }
    } catch { /* ignore */ }
  }
  // Last resort: the whole thing as one variant, duplicated.
  const clean = t.replace(/^["'[]+|["'\]]+$/g, '').trim();
  return [clean, clean];
}

// ── validation ──────────────────────────────────────────────────────────────
// Every number the coach is ALLOWED to cite: the hero's action frequencies +
// sizes at this node, the pot/toCall, AND every % and BB figure that appears
// in the authored fact-block text (villain sizings, pot %, equity-ish counts).
// Those fact-block numbers are ground truth the coach SHOULD be able to use —
// e.g. Vega naturally cites "the HJ's 100% pot bet" / "UTG bets 6.2bb", which
// come from villain_view / facts, not from the hero's own availableActions.
// Without this the technical coach fell back ~40% of the time (2026-10-28).
function allowedNumbers(ctx) {
  const pcts = new Set();
  const sizes = new Set();
  for (const info of Object.values(ctx.availableActions)) {
    pcts.add(info.frequencyPct);
    if (info.sizeBB != null) sizes.add(round1(info.sizeBB));
  }
  if (ctx.potBB) sizes.add(round1(ctx.potBB));
  if (ctx.toCallBB) sizes.add(round1(ctx.toCallBB));

  // Harvest numbers from the authored fact-block text the model is grounded on.
  const factText = [
    ...(ctx.facts || []),
    ctx.villainView || '',
    Array.isArray(ctx.threats) ? ctx.threats.join(' ') : (ctx.threats || ''),
    ctx.wrongActionNote || '',
    ctx.keyConcept || '',
    ctx.magsNote || '',
  ].join(' ');
  for (const m of factText.matchAll(/(\d+(?:\.\d+)?)\s*%/g)) {
    pcts.add(Math.round(Number(m[1])));
  }
  for (const m of factText.matchAll(/(\d+(?:\.\d+)?)\s*bb/gi)) {
    sizes.add(round1(m[1]));
  }
  return { pcts, sizes };
}
const round1 = (n) => Math.round(Number(n) * 10) / 10;
function checkNumbers(text, ctx) {
  const { pcts, sizes } = allowedNumbers(ctx);
  const bad = [];
  for (const m of text.matchAll(/(\d+(?:\.\d+)?)\s*%/g)) {
    const n = Math.round(Number(m[1]));
    if (![...pcts].some((p) => Math.abs(p - n) <= 1)) bad.push(`${m[1]}%`);
  }
  for (const m of text.matchAll(/(\d+(?:\.\d+)?)\s*(?:bb|big blinds?)/gi)) {
    const n = round1(m[1]);
    if (![...sizes].some((s) => Math.abs(s - n) <= 0.1)) bad.push(`${m[1]}BB`);
  }
  return bad;
}
function checkNeverSay(text, coach) {
  const low = text.toLowerCase();
  return coach.never_say.filter((p) => {
    const pl = p.toLowerCase();
    if (pl === 'emoji') return /[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}]/u.test(text);
    if (pl === 'exclamation marks') return text.includes('!');
    return low.includes(pl);
  });
}
function validate(text, ctx, coach, recentOpenings, siblingOpening) {
  const failed = [];
  const numBad = checkNumbers(text, ctx);
  const nsBad = checkNeverSay(text, coach);
  const op = opening(text);
  if (numBad.length) failed.push(`numbers:${numBad.join(',')}`);
  if (nsBad.length) failed.push(`never_say:${nsBad.join(',')}`);
  if (recentOpenings.includes(op) || (siblingOpening && op === siblingOpening)) failed.push(`opening:${op}`);
  const punct = checkPunctuation(text);
  if (punct.length) failed.push(`punctuation:${punct.join(',')}`);
  return failed;
}
// Complete-sentence, ACTION-AWARE fallback pair (never a bare key_concept fragment). The two
// variants use different frames. See text_rules.buildFallbackPair.
function fallbackPair(coach, ctx) {
  const max = (coach.voice.max_words || 70) - 4;
  const top = Object.entries(ctx.availableActions || {}).sort((x, y) => y[1].frequencyPct - x[1].frequencyPct)[0];
  return buildFallbackPair({
    action: ctx.chosenAction,
    top: top ? top[0] : null,
    topPct: top ? top[1].frequencyPct : 0,
    chosenPct: ctx.chosenActionFrequencyPct,
    concept: stripNumbers(ctx.keyConcept || ''),
    wrongNote: ctx.wrongActionNote || '',
    street: ctx.street,
    toCallBB: ctx.toCallBB,
    max,
  });
}

// Count validation failures by reason (prefix before ':' plus punctuation
// sub-reasons) so the fallback rate can be diagnosed at the end of a run.
const reasonCounts = { first: {}, retry: {}, fallbackCause: {} };
function tally(bucket, failed) {
  for (const f of failed) {
    const [kind, rest] = f.split(/:(.*)/s);
    const keys = kind === 'punctuation' ? rest.split(',').map((r) => `punctuation.${r}`)
      : kind === 'opening' ? ['opening'] : [kind];
    for (const k of new Set(keys)) reasonCounts[bucket][k] = (reasonCounts[bucket][k] || 0) + 1;
  }
}
function printReasons() {
  console.log('\nValidation failures by reason (per variant check):');
  for (const [bucket, label] of [['first', 'first pass'], ['retry', 'after retry'], ['fallbackCause', 'cause of fallback']]) {
    const e = Object.entries(reasonCounts[bucket]).sort((x, y) => y[1] - x[1]);
    console.log(`  ${label}: ${e.length ? e.map(([k, n]) => `${k}=${n}`).join(', ') : 'none'}`);
  }
}

// ── Batch API ─────────────────────────────────────────────────────────────
// One request per (coach, spot, NODE, action, LEVEL); the model returns 2
// variants. Keyed by node id so that a hero action repeated across streets
// (preflop call, flop call, river call …) never collides, and by experience
// level (beginner/intermediate/advanced) so the coach adapts its depth.
function buildRequests(coaches, spots, histories) {
  const requests = [];
  const index = {};
  for (const coach of coaches) {
    const key = coach.coachKey;
    const recentOpenings = histories[key].openings.map((o) => o.text);
    for (const spot of spots) {
      for (const { id: nodeId, node, actions } of heroDecisions(spot.tree)) {
        for (const action of actions) {
          const ctx = buildContext(spot.tree, node, action);
          for (const level of LEVELS) {
            const customId = `${key}__${spot.id}__${nodeId}__${action}__${level}`;
            index[customId] = {
              coachKey: key, spotKey: spot.id, nodeId, action, level, ctx, recentOpenings, coach,
            };
            requests.push({
              custom_id: customId,
              params: {
                model: MODEL,
                max_tokens: 600,
                system: systemBlocks(coach, recentOpenings),
                messages: [{ role: 'user', content: userMessage(coach, ctx, level) }],
              },
            });
          }
        }
      }
    }
  }
  return { requests, index };
}

// Rough per-token prices (USD / 1M tokens), Batch API (~50% of standard).
// Update if Anthropic pricing changes — these are only for the estimate print.
const BATCH_PRICE = {
  'claude-sonnet-5': { in: 1.5, cachedIn: 0.15, out: 7.5 },
  'claude-opus-4-8': { in: 7.5, cachedIn: 0.75, out: 37.5 },
};

// Print a cost estimate for a run of [n] main requests and require the operator
// to confirm (unless --yes). The system prompt is prompt-cached per coach, so
// most of its ~700 tokens bill at the cheap cached rate; each request also
// carries ~700 context tokens + ~2 short variants (~400 output tokens). A
// retry batch (~30% of n on average) roughly adds ~0.3×. Deliberately a rough
// UPPER-ish estimate so the number is a ceiling, not a surprise.
async function confirmCost(n) {
  const p = BATCH_PRICE[MODEL] || BATCH_PRICE['claude-sonnet-5'];
  const withRetry = Math.round(n * 1.3); // main + typical retry batch
  const perReq =
    (700 * p.cachedIn + 700 * p.in) / 1e6 + // cached system + context in
    (400 * p.out) / 1e6; // 2 variants out
  const est = withRetry * perReq;
  console.log(
    `\nCost estimate: ~${withRetry} requests (incl. retry) on ${MODEL}, ` +
      `≈ $${est.toFixed(2)} (rough ceiling, Batch pricing).`
  );
  if (YES) {
    console.log('(--yes) proceeding without confirmation.\n');
    return;
  }
  const readline = await import('node:readline/promises');
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  const answer = (await rl.question('Submit this batch? [y/N] ')).trim().toLowerCase();
  rl.close();
  if (answer !== 'y' && answer !== 'yes') {
    console.log('Aborted — nothing submitted, nothing charged.');
    process.exit(0);
  }
  console.log('');
}

async function runBatch(requests) {
  const batch = await anthropic.messages.batches.create({ requests });
  process.stdout.write(`  batch ${batch.id} submitted (${requests.length} requests)\n`);
  let status = batch;
  while (status.processing_status !== 'ended') {
    await sleep(POLL_MS);
    status = await anthropic.messages.batches.retrieve(batch.id);
    const c = status.request_counts || {};
    process.stdout.write(`    …${status.processing_status} (done ${c.succeeded ?? 0}/${requests.length})\n`);
  }
  const results = {};
  for await (const r of await anthropic.messages.batches.results(batch.id)) {
    if (r.result?.type === 'succeeded') {
      const blocks = r.result.message?.content || [];
      results[r.custom_id] = blocks.filter((b) => b.type === 'text').map((b) => b.text).join('').trim();
    } else {
      results[r.custom_id] = null; // errored/expired → fallback later
    }
  }
  return results;
}

// ── voice pre-render via coachSpeech CF (update 4) ──────────────────────────
// Mint a Firebase ID token from the service account (custom token → exchange)
// and POST each final line to the deployed coachSpeech CF so its MP3 caches in
// Storage under the same key the app fetches. ElevenLabs key stays in the CF.
// Public Firebase client key used only to exchange a custom token for an ID
// token (Identity Toolkit). The iOS/web key is API-restricted and rejects this
// call; the Android key is not — so default to it. Override with
// FIREBASE_WEB_API_KEY if the project's keys change.
const WEB_API_KEY =
  process.env.FIREBASE_WEB_API_KEY || 'AIzaSyAFVCGvv94GSHRdwbTwBJ5IRYj81Cj12PA';
const COACH_SPEECH_URL =
  'https://us-central1-poker-tracker-52df8.cloudfunctions.net/coachSpeech';
async function mintIdToken() {
  // A stable tooling uid; the CF only needs a VALID token, not a specific uid.
  const customToken = await auth.createCustomToken('feedback-voice-warmer');
  const resp = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${WEB_API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: customToken, returnSecureToken: true }),
    }
  );
  const data = await resp.json();
  if (!data.idToken) throw new Error(`token exchange failed: ${JSON.stringify(data).slice(0, 200)}`);
  return data.idToken;
}
async function warmVoice(lines) {
  if (NO_VOICE || DRY) {
    console.log(NO_VOICE ? '\nVoice pre-render skipped (--no-voice).' : '\nDry run — voice not warmed.');
    return;
  }
  let idToken;
  try {
    idToken = await mintIdToken();
  } catch (e) {
    console.warn(`\nVoice pre-render skipped — could not mint token: ${e.message}`);
    return;
  }
  console.log(`\nWarming voice cache: ${lines.length} unique lines…`);
  let ok = 0, fail = 0;
  for (const { coachKey, text } of lines) {
    try {
      const resp = await fetch(COACH_SPEECH_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${idToken}` },
        body: JSON.stringify({ text, coach: coachKey }),
      });
      if (resp.ok) ok++;
      else { fail++; if (fail <= 3) console.warn(`  voice ${resp.status} for ${coachKey}`); }
    } catch (e) {
      fail++;
      if (fail <= 3) console.warn(`  voice error: ${e.message}`);
    }
  }
  console.log(`Voice warmed: ${ok} ok, ${fail} failed.`);
}

// ── main ────────────────────────────────────────────────────────────────────
async function main() {
  const coaches = loadCoaches();
  const spots = await loadDaySpots(DAY);
  console.log(`Day ${DAY}: ${spots.length} spot(s), ${coaches.length} coaches, model=${MODEL}${DRY ? ' (dry)' : ''}`);

  // ── Completeness gate: every PRESENTED hero node needs a valid fact block.
  //    Scope (check 9): only nodes on lines where every PRIOR hero action is
  //    played >= 20% (keeps volume sane + skips near-impossible lines).
  //    Reject the whole day on any failure.
  const problems = [];
  for (const spot of spots) {
    const decisions = heroDecisions(spot.tree); // already 20%-line-scoped
    const keyConcepts = [];
    for (const { id: nodeId, node } of decisions) {
      const issues = factBlockIssues(node);
      if (issues.length) problems.push(`  ${spot.id}/${nodeId}: ${issues.join('; ')}`);
      const kc = node.facts?.key_concept;
      if (kc) keyConcepts.push(String(kc).trim().toLowerCase());
    }
    // ── check 6: flag if any one key_concept covers > 30% of a spot's nodes.
    if (keyConcepts.length >= 4) {
      const counts = {};
      for (const kc of keyConcepts) counts[kc] = (counts[kc] || 0) + 1;
      for (const [kc, n] of Object.entries(counts)) {
        if (n / keyConcepts.length > 0.3) {
          problems.push(
            `  ${spot.id}: key_concept "${kc}" repeats on ${n}/${keyConcepts.length} ` +
              `nodes (>30%) — make concepts node-specific`
          );
        }
      }
    }
  }
  if (problems.length) {
    console.error(
      `\nREJECTED ${DAY}: ${problems.length} fact-block issue(s).\n` +
        problems.join('\n') +
        `\n\nEvery presented hero node needs a valid column-M fact block ` +
        `(hero_hand w/ suits, hand_class, solver, >=3 reasoned facts, ` +
        `key_concept, level_hints beginner/intermediate/advanced as teaching, ` +
        `wrong_action_notes for every sub-10% action). Nothing written.`
    );
    process.exit(2);
  }

  const histories = {};
  for (const c of coaches) histories[c.coachKey] = await loadHistory(c.coachKey);

  // ── Build + submit the main batch ──────────────────────────────────────
  let { requests, index } = buildRequests(coaches, spots, histories);
  console.log(`Built ${requests.length} requests (each → 2 variants).`);
  if (DRY) {
    console.log('Dry run — not submitting the batch. Sample request:');
    console.log(JSON.stringify(requests[0], null, 2).slice(0, 1200));
    process.exit(0);
  }

  // ── check 10: --sample → generate a random subset for review, no write ──
  if (SAMPLE) {
    const shuffled = [...requests];
    for (let i = shuffled.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }
    const sample = shuffled.slice(0, Math.min(SAMPLE, shuffled.length));
    console.log(`SAMPLE mode: generating ${sample.length} random node(s) for review (no Firestore, no voice).`);
    const sampleRaw = await runBatch(sample);
    const out = CSV || `/tmp/feedback-sample-${DAY}.csv`;
    const rows = [['coachKey', 'spotKey', 'nodeId', 'action', 'level', 'verdict', 'variant', 'text']];
    for (const req of sample) {
      const { coachKey, spotKey, nodeId, action, level, ctx } = index[req.custom_id];
      const variants = sampleRaw[req.custom_id] ? parseVariants(sampleRaw[req.custom_id]) : ['(no output)', ''];
      variants.forEach((t, i) => rows.push([coachKey, spotKey, nodeId, action, level, ctx.verdict, String(i + 1), t]));
    }
    fs.writeFileSync(out, rows.map((r) => r.map((c) => `"${String(c).replace(/"/g, '""')}"`).join(',')).join('\n'));
    console.log(`\nWrote sample CSV: ${out}\nReview it, then re-run WITHOUT --sample to generate + upload the full day.`);
    process.exit(0);
  }

  // ── Cost estimate + confirmation (skipped with --yes / -y) ─────────────
  await confirmCost(requests.length);

  const raw = await runBatch(requests);

  // ── Validate each request's two variants; collect retries ──────────────
  const hands = {};
  const perCoachNewOpenings = {};
  const perCoachNewConcepts = {};
  const logs = [];
  const retryRequests = [];
  const finalByCustomId = {};

  // Storage shape (v2 brief): hands[spotKey][nodeId][action][coachId][level].
  // Keyed by NODE so a repeated action across streets never overwrites, and by
  // LEVEL for tier-adapted depth. A COLLISION (same full key written twice) is
  // a generator bug — fail the run loudly rather than silently clobber.
  function placeVariants(customId, variants) {
    const { coachKey, spotKey, nodeId, action, level } = index[customId];
    hands[spotKey] ||= {};
    hands[spotKey][nodeId] ||= {};
    hands[spotKey][nodeId][action] ||= {};
    hands[spotKey][nodeId][action][coachKey] ||= {};
    if (hands[spotKey][nodeId][action][coachKey][level] !== undefined) {
      console.error(
        `COLLISION: ${spotKey}/${nodeId}/${action}/${coachKey}/${level} written twice. ` +
          `Nothing saved.`
      );
      process.exit(3);
    }
    hands[spotKey][nodeId][action][coachKey][level] = variants;
    finalByCustomId[customId] = variants;
    (perCoachNewOpenings[coachKey] ||= []).push(opening(variants[0]), opening(variants[1]));
    const tags = index[customId].ctx.conceptTags || [];
    (perCoachNewConcepts[coachKey] ||= []).push(...tags);
  }

  for (const [customId, meta] of Object.entries(index)) {
    const { coach, ctx, recentOpenings } = meta;
    const text = raw[customId];
    const variants = text ? parseVariants(text) : null;
    if (!variants) {
      reasonCounts.first.unparseable = (reasonCounts.first.unparseable || 0) + 1;
      retryRequests.push(buildSingleRequest(customId, meta));
      continue;
    }
    const f0 = validate(variants[0], ctx, coach, recentOpenings, null);
    const f1 = validate(variants[1], ctx, coach, recentOpenings, opening(variants[0]));
    if (f0.length || f1.length) {
      retryRequests.push(buildSingleRequest(customId, meta, { f0, f1 }));
      tally('first', [...f0, ...f1]);
      logs.push({ customId, failed: [...f0, ...f1], stage: 'first' });
    } else {
      placeVariants(customId, variants);
      logs.push({ customId, failed: [], stage: 'first' });
    }
  }

  // ── One retry batch for failures ───────────────────────────────────────
  if (retryRequests.length) {
    console.log(`\nRetry batch: ${retryRequests.length} request(s) failed validation.`);
    const retryRaw = await runBatch(retryRequests.map((r) => r.request));
    for (const { customId, meta } of retryRequests) {
      const { coach, ctx, recentOpenings } = meta;
      const text = retryRaw[customId];
      const variants = text ? parseVariants(text) : null;
      let fellBack = false;
      let final = variants;
      if (!variants) {
        final = fallbackPair(coach, ctx);
        fellBack = true;
        tally('fallbackCause', ['unparseable']);
        tally('retry', ['unparseable']);
      } else {
        const f0 = validate(variants[0], ctx, coach, recentOpenings, null);
        const f1 = validate(variants[1], ctx, coach, recentOpenings, opening(variants[0]));
        if (f0.length || f1.length) {
          final = fallbackPair(coach, ctx);
          fellBack = true;
          tally('retry', [...f0, ...f1]);
          tally('fallbackCause', [...f0, ...f1]);
          console.log(`  fallback ${customId}: ${[...f0, ...f1].join(' | ')}`);
        }
      }
      placeVariants(customId, final);
      logs.push({ customId, failed: fellBack ? ['fallback'] : [], stage: 'retry', fellBack });
    }
  }

  // ── Write Firestore (update 2 storage shape) ───────────────────────────
  await db.collection('daily_challenge_lines').doc(DAY).set(
    { generatedAt: admin.firestore.FieldValue.serverTimestamp(), mode: 'authored', hands },
    { merge: true }
  );
  console.log(`\nWrote daily_challenge_lines/${DAY}`);

  // Anti-repetition history
  for (const c of coaches) {
    await saveHistory(c.coachKey, histories[c.coachKey], perCoachNewOpenings[c.coachKey] || [], perCoachNewConcepts[c.coachKey] || []);
  }

  // ── CSV ────────────────────────────────────────────────────────────────
  if (CSV) {
    const rows = [['coachKey', 'spotKey', 'nodeId', 'action', 'level', 'verdict', 'variant', 'text']];
    for (const [customId, variants] of Object.entries(finalByCustomId)) {
      const { coachKey, spotKey, nodeId, action, level, ctx } = index[customId];
      variants.forEach((t, i) => rows.push([coachKey, spotKey, nodeId, action, level, ctx.verdict, String(i + 1), t]));
    }
    fs.writeFileSync(CSV, rows.map((r) => r.map((c) => `"${String(c).replace(/"/g, '""')}"`).join(',')).join('\n'));
    console.log(`Wrote review CSV: ${CSV}`);
  }

  // ── Voice pre-render (update 4) ────────────────────────────────────────
  const uniqueLines = [];
  const seenLine = new Set();
  for (const [customId, variants] of Object.entries(finalByCustomId)) {
    const { coachKey } = index[customId];
    for (const t of variants) {
      const k = `${coachKey}|${t}`;
      if (!seenLine.has(k)) { seenLine.add(k); uniqueLines.push({ coachKey, text: t }); }
    }
  }
  await warmVoice(uniqueLines);

  // ── Summary ──────────────────────────────────────────────────────────────
  const fell = logs.filter((l) => l.fellBack).length;
  console.log(`\nSummary: ${Object.keys(finalByCustomId).length} decisions × 2 variants; ${fell} fell back.`);
  printReasons();
  process.exit(0);
}

function punctuationNudge(failed) {
  const all = [...(failed.f0 || []), ...(failed.f1 || [])].filter((f) => f.startsWith('punctuation:'));
  if (!all.length) return '';
  return ` PUNCTUATION problem (${all.join('; ')}): write complete sentences, capitalise each sentence, ` +
    `end every sentence (including the last) with a period, and use single spaces.`;
}

// Single-request rebuild for the retry batch (adds a nudge about what failed).
function buildSingleRequest(customId, meta, failed) {
  const { coach, ctx, recentOpenings } = meta;
  const nudge = failed
    ? `\n\nYour previous attempt failed these checks — fix them: ${JSON.stringify(failed)}. ` +
      `Remember: only cite numbers from the context; never use forbidden phrases; open differently.` +
      punctuationNudge(failed)
    : '';
  return {
    customId,
    meta,
    request: {
      custom_id: customId,
      params: {
        model: MODEL,
        max_tokens: 600,
        system: systemBlocks(coach, recentOpenings),
        messages: [{ role: 'user', content: userMessage(coach, ctx, meta.level) + nudge }],
      },
    },
  };
}

main().catch((e) => {
  console.error('generate_feedback failed:', e);
  process.exit(1);
});
