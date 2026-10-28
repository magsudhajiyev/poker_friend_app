#!/usr/bin/env node
// INDEPENDENT audit of a generated coach-feedback CSV.
//
// The batch generator (generate_feedback.mjs --csv out.csv) writes a review
// CSV with columns: coachKey,spotKey,action,verdict,variant,fellBack,failed,text
// This harness RE-RUNS every quality check from scratch against the live
// solver data in Firestore — it does NOT trust the generator's own `failed`
// column. Use it to review a full day's (or several days') output before the
// lines go live, and as a CI gate.
//
// Usage:
//   node test_feedback.mjs --csv out.csv                 # audit, infer spots from CSV
//   node test_feedback.mjs --csv out.csv --day 2026-10-28 # also use the day's authored_days doc
//
// Checks per row (independent of the generator):
//   - number-match : every N% within 1pp of an allowed solver frequency,
//                    every N BB matches an allowed solver size (±0.1)
//   - never_say    : no persona never_say phrase (emoji / "!" handled specially)
//   - repeated-open: first-3-words must be unique within a coachKey
//   - length       : avg words/coach + count over voice.max_words
//
// Exit code: non-zero if ANY never_say violation or number-match failure is
// found (so CI can gate on it). Repeated-opening + overflow are reported but
// do NOT fail the run (they are quality signals, not correctness bugs).
//
// Admin SDK creds: ./service-account.json (gitignored). No Anthropic API call.
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { createRequire } from 'module';

const require = createRequire(import.meta.url);
const admin = require('firebase-admin');

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..', '..');
const COACHES_DIR = path.join(ROOT, 'coaches');

// ── args ────────────────────────────────────────────────────────────────────
function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`);
  if (i === -1) return fallback;
  const next = process.argv[i + 1];
  return next && !next.startsWith('--') ? next : true;
}
const CSV = arg('csv', null);
const DAY = arg('day', null);

if (!CSV || CSV === true) {
  console.error('Usage: node test_feedback.mjs --csv <file> [--day YYYY-MM-DD]');
  console.error('Audits a generated coach-feedback CSV against live solver data.');
  process.exit(1);
}
if (!fs.existsSync(CSV)) {
  console.error(`CSV not found: ${CSV}`);
  process.exit(1);
}
if (DAY && DAY !== true && !/^\d{4}-\d{2}-\d{2}$/.test(DAY)) {
  console.error('--day must be YYYY-MM-DD');
  process.exit(1);
}

// ── init ──────────────────────────────────────────────────────────────────
const keyFile = path.join(__dirname, 'service-account.json');
if (!fs.existsSync(keyFile)) {
  console.error('Missing service-account.json in tool/gto_export/.');
  process.exit(1);
}
admin.initializeApp({ credential: admin.credential.cert(require(keyFile)) });
const db = admin.firestore();

// ── personas (for never_say + max_words) ────────────────────────────────────
function loadCoaches() {
  const byKey = {};
  for (const f of ['duke.json', 'vega.json', 'nova.json']) {
    const c = JSON.parse(fs.readFileSync(path.join(COACHES_DIR, f), 'utf8'));
    byKey[c.coachKey] = c;
  }
  return byKey;
}

// ── CSV parsing (handles the generator's quoted/escaped output) ──────────────
function parseCsv(text) {
  const rows = [];
  let row = [];
  let field = '';
  let inQuotes = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (inQuotes) {
      if (ch === '"') {
        if (text[i + 1] === '"') {
          field += '"';
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field += ch;
      }
    } else if (ch === '"') {
      inQuotes = true;
    } else if (ch === ',') {
      row.push(field);
      field = '';
    } else if (ch === '\n' || ch === '\r') {
      if (ch === '\r' && text[i + 1] === '\n') i++;
      row.push(field);
      field = '';
      if (row.length > 1 || row[0] !== '') rows.push(row);
      row = [];
    } else {
      field += ch;
    }
  }
  if (field.length || row.length) {
    row.push(field);
    rows.push(row);
  }
  return rows;
}

// ── solver-data helpers (mirror generate_feedback.mjs) ───────────────────────
function round1(n) {
  return Math.round(Number(n) * 10) / 10;
}

// Allowed numbers for a (tree, nodeId, —) : the frequency % + sizes of every
// available action at that node, plus pot/toCall. Mirrors the generator's
// buildContext + allowedNumbers, but aggregated across ALL hero nodes of the
// spot keyed by action, because the CSV only carries (spotKey, action) — not
// which specific node. We therefore accept a number that is valid at ANY hero
// node reachable for that action (a superset — a true number-invention still
// fails because it matches no node).
function allowedNumbersForSpotAction(tree, action) {
  const hand = tree.heroHandClass;
  const pcts = new Set();
  const sizes = new Set();
  for (const node of Object.values(tree.nodes)) {
    if (node.actor !== 'hero') continue;
    const f = node.freq?.[action]?.[hand];
    if (f == null) continue; // this node doesn't offer the action to the hero
    // Every available action's freq + size at this node is citable context.
    for (const a of node.actions || []) {
      const af = node.freq?.[a]?.[hand];
      if (af != null) {
        pcts.add(Math.round(af * 100));
        if (node.sizingBB?.[a] != null) sizes.add(round1(node.sizingBB[a]));
      }
    }
    if (node.potBB) sizes.add(round1(node.potBB));
    if (node.toCallBB) sizes.add(round1(node.toCallBB));
  }
  return { pcts, sizes };
}

function checkNumbers(text, allowed) {
  const bad = [];
  for (const m of text.matchAll(/(\d+(?:\.\d+)?)\s*%/g)) {
    const n = Math.round(Number(m[1]));
    if (![...allowed.pcts].some((p) => Math.abs(p - n) <= 1)) bad.push(`${m[1]}%`);
  }
  for (const m of text.matchAll(/(\d+(?:\.\d+)?)\s*(?:bb|big blinds?)/gi)) {
    const n = round1(m[1]);
    if (![...allowed.sizes].some((s) => Math.abs(s - n) <= 0.1)) bad.push(`${m[1]}BB`);
  }
  return bad;
}

function checkNeverSay(text, coach) {
  if (!coach) return [];
  const low = text.toLowerCase();
  return coach.never_say.filter((p) => {
    const pl = p.toLowerCase();
    if (pl === 'emoji') return /[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}]/u.test(text);
    if (pl === 'exclamation marks') return text.includes('!');
    return low.includes(pl);
  });
}

function opening(text) {
  return text.trim().split(/\s+/).slice(0, 3).join(' ').toLowerCase();
}
function wordCount(text) {
  return text.trim().split(/\s+/).filter(Boolean).length;
}

// ── load the authored spots referenced by the CSV ────────────────────────────
async function loadSpotTrees(spotIds) {
  const trees = {};
  for (const id of spotIds) {
    const d = await db.collection('authored_spots').doc(id).get();
    if (!d.exists) {
      console.warn(`WARN: authored_spots/${id} not found — number checks for its rows will be skipped.`);
      continue;
    }
    trees[id] = JSON.parse(d.data().treeJson);
  }
  return trees;
}

// ── main ────────────────────────────────────────────────────────────────────
async function main() {
  const coaches = loadCoaches();
  const raw = fs.readFileSync(CSV, 'utf8');
  const rows = parseCsv(raw);
  if (rows.length < 2) {
    console.error('CSV has no data rows.');
    process.exit(1);
  }
  const header = rows[0].map((h) => h.trim());
  const col = (name) => header.indexOf(name);
  const ci = {
    coachKey: col('coachKey'),
    spotKey: col('spotKey'),
    action: col('action'),
    verdict: col('verdict'),
    variant: col('variant'),
    fellBack: col('fellBack'),
    failed: col('failed'),
    text: col('text'),
  };
  for (const [k, v] of Object.entries(ci)) {
    if (v < 0) {
      console.error(`CSV missing expected column: ${k}`);
      process.exit(1);
    }
  }

  const data = rows.slice(1).map((r) => ({
    coachKey: r[ci.coachKey],
    spotKey: r[ci.spotKey],
    action: r[ci.action],
    verdict: r[ci.verdict],
    variant: r[ci.variant],
    fellBack: r[ci.fellBack] === 'true',
    failed: r[ci.failed],
    text: r[ci.text] || '',
  }));

  // Resolve spot ids: --day (authored_days) ∪ distinct CSV spotKeys.
  const spotIds = new Set(data.map((d) => d.spotKey).filter(Boolean));
  if (DAY && DAY !== true) {
    const dayDoc = await db.collection('authored_days').doc(DAY).get();
    if (dayDoc.exists) {
      for (const id of dayDoc.data().hands || []) if (id) spotIds.add(id);
    } else {
      console.warn(`WARN: authored_days/${DAY} not found; using CSV spotKeys only.`);
    }
  }
  const trees = await loadSpotTrees([...spotIds]);

  // Per-coach aggregation.
  const stats = {}; // coachKey -> {...}
  const openSeen = {}; // coachKey -> Map(opening -> count)
  const ensure = (key) => {
    if (!stats[key]) {
      stats[key] = {
        rows: 0,
        numChecked: 0,
        numPass: 0,
        neverSay: 0,
        repeatedOpen: 0,
        words: 0,
        overflow: 0,
        numberFailures: [],
        neverSayHits: [],
      };
      openSeen[key] = new Map();
    }
    return stats[key];
  };

  for (const d of data) {
    const s = ensure(d.coachKey);
    const coach = coaches[d.coachKey];
    s.rows++;
    s.words += wordCount(d.text);

    // length / overflow
    if (coach && wordCount(d.text) > coach.voice.max_words) s.overflow++;

    // never_say
    const ns = checkNeverSay(d.text, coach);
    if (ns.length) {
      s.neverSay++;
      s.neverSayHits.push({ spot: d.spotKey, action: d.action, hits: ns });
    }

    // repeated openings within coach
    const op = opening(d.text);
    const prev = openSeen[d.coachKey].get(op) || 0;
    openSeen[d.coachKey].set(op, prev + 1);

    // number-match (only when we have the tree)
    const tree = trees[d.spotKey];
    if (tree) {
      s.numChecked++;
      const allowed = allowedNumbersForSpotAction(tree, d.action);
      const bad = checkNumbers(d.text, allowed);
      if (bad.length === 0) {
        s.numPass++;
      } else {
        s.numberFailures.push({
          spot: d.spotKey,
          action: d.action,
          variant: d.variant,
          bad,
        });
      }
    }
  }

  // Finalize repeated-opening counts (an opening used N>1 times contributes N).
  for (const key of Object.keys(stats)) {
    let repeated = 0;
    for (const n of openSeen[key].values()) if (n > 1) repeated += n;
    stats[key].repeatedOpen = repeated;
  }

  // ── report ──────────────────────────────────────────────────────────────
  console.log(`\nAudit of ${CSV}${DAY && DAY !== true ? ` (day ${DAY})` : ''}`);
  console.log(`Spots loaded for number checks: ${Object.keys(trees).length}/${spotIds.size}\n`);

  const pad = (s, n) => String(s).padEnd(n);
  console.log(
    pad('coach', 11) +
      pad('rows', 6) +
      pad('num-match', 11) +
      pad('neverSay', 10) +
      pad('repOpen', 9) +
      pad('avgLen', 8) +
      pad('overflow', 9)
  );
  console.log('-'.repeat(64));

  let totalRows = 0;
  let totalNumChecked = 0;
  let totalNumPass = 0;
  let totalNeverSay = 0;
  let totalRepeated = 0;
  let totalWords = 0;
  let totalOverflow = 0;

  for (const key of Object.keys(stats).sort()) {
    const s = stats[key];
    const rate =
      s.numChecked > 0 ? `${Math.round((s.numPass / s.numChecked) * 100)}%` : 'n/a';
    const avg = s.rows > 0 ? (s.words / s.rows).toFixed(1) : '0';
    console.log(
      pad(key, 11) +
        pad(s.rows, 6) +
        pad(`${rate} (${s.numPass}/${s.numChecked})`, 11) +
        pad(s.neverSay, 10) +
        pad(s.repeatedOpen, 9) +
        pad(avg, 8) +
        pad(s.overflow, 9)
    );
    totalRows += s.rows;
    totalNumChecked += s.numChecked;
    totalNumPass += s.numPass;
    totalNeverSay += s.neverSay;
    totalRepeated += s.repeatedOpen;
    totalWords += s.words;
    totalOverflow += s.overflow;
  }

  console.log('-'.repeat(64));
  const totRate =
    totalNumChecked > 0
      ? `${Math.round((totalNumPass / totalNumChecked) * 100)}%`
      : 'n/a';
  const totAvg = totalRows > 0 ? (totalWords / totalRows).toFixed(1) : '0';
  console.log(
    pad('TOTAL', 11) +
      pad(totalRows, 6) +
      pad(`${totRate} (${totalNumPass}/${totalNumChecked})`, 11) +
      pad(totalNeverSay, 10) +
      pad(totalRepeated, 9) +
      pad(totAvg, 8) +
      pad(totalOverflow, 9)
  );

  // Detail on hard failures.
  const numberFailRows = Object.values(stats).flatMap((s) => s.numberFailures);
  const neverSayRows = Object.values(stats).flatMap((s) => s.neverSayHits);
  if (numberFailRows.length) {
    console.log(`\nNUMBER-MATCH FAILURES (${numberFailRows.length}):`);
    for (const f of numberFailRows) {
      console.log(`  ${f.spot}/${f.action} v${f.variant}: unverified ${f.bad.join(', ')}`);
    }
  }
  if (neverSayRows.length) {
    console.log(`\nNEVER_SAY VIOLATIONS (${neverSayRows.length}):`);
    for (const f of neverSayRows) {
      console.log(`  ${f.spot}/${f.action}: ${f.hits.join(', ')}`);
    }
  }

  const fail = numberFailRows.length > 0 || totalNeverSay > 0;
  console.log(
    `\n${fail ? 'FAIL' : 'PASS'}: ${numberFailRows.length} number-match failure(s), ` +
      `${totalNeverSay} never_say violation(s), ${totalRepeated} repeated opening(s).`
  );
  process.exit(fail ? 1 : 0);
}

main().catch((e) => {
  console.error('test_feedback failed:', e);
  process.exit(1);
});
