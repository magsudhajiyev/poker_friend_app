#!/usr/bin/env node
// Repair EXISTING daily_challenge_lines/{day} fallback pairs (free: no LLM).
//   node repair_fallback_lines.mjs --day 2026-10-25            # READ-ONLY report
//   node repair_fallback_lines.mjs --day 2026-10-25 --apply    # writes changed leaves
//
// A "fallback pair" = both variants identical AND failing checkPunctuation
// (the old fallbackLine() stored the bare key_concept twice). The stored text
// IS the node-level key_concept, which describes the solver's PREFERRED action,
// so the repair is ACTION-AWARE: it reads authored_spots/{spot} (read-only) for
// the node's solver frequencies + wrong_action_notes and uses the same builder
// as the generator (text_rules.buildFallbackPair). If the spot/node is not
// readable, the fragment is only normalizeLine'd (complete sentence, but NOT
// action-verified) and counted as "unverified".
// Writes use a field-path update per changed leaf (never overwrite the doc).
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import { createRequire } from 'module';
import { checkPunctuation, buildFallbackPair, normalizeLine, stripNumbers } from './text_rules.mjs';

const require = createRequire(import.meta.url);
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const i = process.argv.indexOf('--day');
const DAY = i > -1 ? process.argv[i + 1] : null;
const APPLY = process.argv.includes('--apply');
if (!DAY || !/^\d{4}-\d{2}-\d{2}$/.test(DAY)) {
  console.error('Pass --day YYYY-MM-DD [--apply]');
  process.exit(1);
}
const keyFile = path.join(__dirname, 'service-account.json');
if (!fs.existsSync(keyFile)) {
  console.error('Missing service-account.json in tool/gto_export/.');
  process.exit(1);
}
const admin = require('firebase-admin');
admin.initializeApp({ credential: admin.credential.cert(require(keyFile)) });
const db = admin.firestore();

// Walk hands[spot][node][action][coach][level] = [v0, v1]; skip legacy shapes.
function* leaves(hands) {
  for (const [spot, nodes] of Object.entries(hands || {}))
    for (const [node, acts] of Object.entries(nodes || {}))
      for (const [act, coaches] of Object.entries(acts || {}))
        for (const [coach, levels] of Object.entries(coaches || {})) {
          if (Array.isArray(levels)) continue; // legacy spot/coach/action shape
          for (const [level, v] of Object.entries(levels || {}))
            if (Array.isArray(v) && v.length === 2) yield { p: [spot, node, act, coach, level], v };
        }
}

const treeCache = {};
async function nodeOf(spot, nodeId) {
  if (!(spot in treeCache)) {
    const d = await db.collection('authored_spots').doc(spot).get();
    treeCache[spot] = d.exists ? JSON.parse(d.data().treeJson) : null;
  }
  const tree = treeCache[spot];
  return tree && tree.nodes[nodeId] ? { tree, node: tree.nodes[nodeId] } : null;
}
async function repairPair(p, text) {
  const [spot, nodeId, action] = p;
  const hit = await nodeOf(spot, nodeId);
  if (!hit) return { after: [normalizeLine(text), normalizeLine(text)], verified: false };
  const { tree, node } = hit;
  const hand = tree.heroHandClass;
  const freqs = Object.fromEntries((node.actions || []).map((a) => [a, node.freq?.[a]?.[hand]]).filter(([, f]) => f != null));
  const top = Object.entries(freqs).sort((x, y) => y[1] - x[1])[0];
  const fb = node.facts || {};
  const after = buildFallbackPair({
    action, top: top ? top[0] : null, topPct: top ? Math.round(top[1] * 100) : 0,
    chosenPct: Math.round((freqs[action] ?? 0) * 100),
    street: node.street, toCallBB: node.toCallBB ?? 0,
    concept: stripNumbers(fb.key_concept || text), wrongNote: (fb.wrong_action_notes || {})[action] || '',
  });
  return { after, verified: true };
}

async function main() {
  const ref = db.collection('daily_challenge_lines').doc(DAY);
  const snap = await ref.get(); // read only
  if (!snap.exists) { console.error(`daily_challenge_lines/${DAY} not found.`); process.exit(1); }
  const changes = [];
  let total = 0;
  for (const { p, v } of leaves(snap.data().hands)) {
    total++;
    if (v[0] !== v[1] || checkPunctuation(v[0]).length === 0) continue;
    const r = await repairPair(p, v[0]);
    changes.push({ path: p.join('/'), before: v[0], after: r.after, verified: r.verified });
  }
  console.log(`${DAY}: ${total} variant pairs, ${changes.length} fallback pair(s) to repair; ${changes.filter((c) => !c.verified).length} unverified (no fact block: normalised only).`);
  for (const c of changes.slice(0, 10)) console.log(`\n${c.path}${c.verified ? '' : ' [unverified]'}\n  before: ${c.before}\n  after:  ${c.after[0]}\n          ${c.after[1]}`);
  if (!APPLY) { console.log('\nREAD-ONLY. Re-run with --apply to write.'); return; }
  for (let k = 0; k < changes.length; k += 400) {
    const batch = db.batch();
    for (const c of changes.slice(k, k + 400)) batch.update(ref, new admin.firestore.FieldPath(...c.path.split('/').flatMap((x, n) => (n === 0 ? ['hands', x] : [x]))), c.after);
    await batch.commit();
  }
  console.log(`\nApplied ${changes.length} leaf update(s).`);
}
main().catch((e) => { console.error('repair failed:', e.message); process.exit(1); });
