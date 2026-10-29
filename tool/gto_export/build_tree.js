#!/usr/bin/env node
/**
 * Solver full-tree Google Sheet  ->  authored_spots tree JSON (+ optional
 * Firestore upload).
 *
 * Reads a sheet exported by the "full tree" extraction prompt (columns:
 * Date | Hand | Street | Board | Step | Spot | Actor | Actions available |
 * Sizing | Range (hand:raise/call/check/fold/allin)) and builds a navigable
 * game tree keyed by action-history, matching lib/models/authored_tree.dart.
 *
 * Villain nodes are kept in the tree too (the app walks them deterministically
 * by most-likely action). Terminal edges (fold / no child) are left null.
 *
 * Usage:
 *   node build_tree.js --sheet <SHEET_ID> --hero 99 --id lj-btn-ts9c4d-99 \
 *       [--out tree.local.json] [--upload]
 *
 * Auth: put a Google service-account key at tool/gto_export/service-account.json
 * (gitignored). The service account must have read access to the sheet and
 * write access to Firestore (same project).
 */
const fs = require('fs');
const path = require('path');

const ACTIONS = ['raise', 'call', 'check', 'fold', 'allin'];

// Max hero decisions on any root->terminal path. A day is up to 5 hands and
// firestore.rules for leaderboard_daily entries cap `verdicts` at 60 chars and
// `weights` at 50 items: 5x10 letters + 4 '|' separators = 54 <= 60; 5x10
// weights = 50 <= 50. Longer trees would silently fail the leaderboard write.
const MAX_HERO_DECISIONS_PER_HAND = 10;

// Longest chain of hero decisions along any path (follows every child).
// `nodes` = object keyed by id or array of nodes with {id, actor, children}.
function maxHeroDecisions(nodes, rootId) {
  const byId = Array.isArray(nodes)
    ? Object.fromEntries(nodes.map((n) => [n.id, n]))
    : nodes;
  const memo = {};
  const walk = (id, stack) => {
    const n = byId[id];
    if (!n) return 0;
    if (stack.has(id)) throw new Error(`cycle in tree at node ${id}`);
    if (id in memo) return memo[id];
    stack.add(id);
    let best = 0;
    for (const c of Object.values(n.children || {}))
      if (c) best = Math.max(best, walk(c, stack));
    stack.delete(id);
    return (memo[id] = best + (n.actor === 'hero' ? 1 : 0));
  };
  return walk(rootId, new Set());
}

// ── args ────────────────────────────────────────────────────────────────
function arg(name, def) {
  const i = process.argv.indexOf(`--${name}`);
  if (i === -1) return def;
  const v = process.argv[i + 1];
  return v && !v.startsWith('--') ? v : true;
}
const SHEET_ID = arg('sheet');
const HERO = arg('hero'); // optional: pick one hero hand to stamp on the tree
const SPOT_ID = arg('id', 'authored-spot');
const OUT = arg('out', 'tree.local.json');
const UPLOAD = arg('upload', false);
const TAB = arg('tab'); // optional explicit tab name
// Optional overrides — normally inferred from the sheet's "Hand" title
// (e.g. "MTT 50bb · BTN vs SB · QcTd9d"). Flags win when present.
const HERO_POS = arg('heroPos'); // e.g. 'BTN'
const VILLAIN_POS = arg('villainPos'); // e.g. 'SB'
const STACK = arg('stack'); // e.g. '50'
// Explicit hero cards in GTOW ASCII, comma-separated, e.g. 'Kd,Qd'. Needed
// when the suited combo matters vs the board; else auto-picked off-board.
const CARDS = arg('cards');

if (require.main === module && !SHEET_ID) {
  console.error('Missing --sheet <SHEET_ID>');
  process.exit(1);
}

// ── sheet read ──────────────────────────────────────────────────────────
async function readSheet() {
  const { google } = require('googleapis');
  const keyFile = path.join(__dirname, 'service-account.json');
  if (!fs.existsSync(keyFile)) {
    console.error('Missing service-account.json in tool/gto_export/.');
    process.exit(1);
  }
  const auth = new google.auth.GoogleAuth({
    keyFile,
    scopes: ['https://www.googleapis.com/auth/spreadsheets.readonly'],
  });
  const sheets = google.sheets({ version: 'v4', auth: await auth.getClient() });
  // Discover tab if not given. Range spans A:N — the newer sheet format adds
  // "Hero hand" (K), "Hero hand strategy" (L), "Explanation" (M, now a JSON
  // fact block on new sheets / plain-English narrative on old ones) and
  // "mags_note" (N, a maintainer free-text note). A:K (the original range)
  // silently dropped L–N, so authored spots uploaded with it carried NO coach
  // explanation.
  let range = TAB ? `${TAB}!A:N` : 'A:N';
  if (!TAB) {
    const meta = await sheets.spreadsheets.get({ spreadsheetId: SHEET_ID });
    const first = meta.data.sheets[0].properties.title;
    range = `${first}!A:N`;
  }
  const res = await sheets.spreadsheets.values.get({
    spreadsheetId: SHEET_ID,
    range,
  });
  return res.data.values || [];
}

// ── parsing ─────────────────────────────────────────────────────────────
function parseRange(cell) {
  const out = {}; // action -> {hand: freq}
  for (const a of ACTIONS) out[a] = {};
  if (!cell) return out;
  for (const tok of cell.split(',')) {
    const t = tok.trim();
    const i = t.indexOf(':');
    if (i < 0) continue;
    const hand = t.slice(0, i).trim();
    const parts = t.slice(i + 1).split('/').map((x) => parseFloat(x));
    ACTIONS.forEach((a, k) => {
      const f = parts[k] || 0;
      if (f > 0) out[a][hand] = Math.round(f * 1000) / 1000;
    });
  }
  // drop empty action maps
  for (const a of ACTIONS) if (Object.keys(out[a]).length === 0) delete out[a];
  return out;
}

// Column M holds either a JSON fact block (new sheets) or plain prose (old).
// Returns { facts, explanation }: on a parsed object, `facts` is the structured
// block and `explanation` is a derived plain-text string (key_concept + first
// fact) for the in-app grader fallback. On prose, `facts` is null and
// `explanation` is the raw string. See FEEDBACK-SCHEMA.md.
function parseFactBlock(raw) {
  const text = (raw || '').trim();
  if (!text) return { facts: null, explanation: '' };
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch {
    return { facts: null, explanation: text }; // prose (old style)
  }
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    return { facts: null, explanation: text };
  }
  const keyConcept = (parsed.key_concept || '').toString().trim();
  const firstFact =
    Array.isArray(parsed.facts) && parsed.facts.length
      ? (parsed.facts[0] || '').toString().trim()
      : '';
  const derived = [keyConcept, firstFact].filter(Boolean).join(' ');
  return { facts: parsed, explanation: derived };
}

const STREET = { Preflop: 'preflop', Flop: 'flop', Turn: 'turn', River: 'river' };

// Normalize a Board string "Ts 9c 4d Jd 2h" -> glyph cards ['10♠','9♣',...].
const SUIT = { s: '♠', h: '♥', d: '♦', c: '♣' };
function boardCards(s) {
  if (!s) return [];
  return s
    .trim()
    .split(/\s+/)
    .map((c) => {
      let rank = c.slice(0, -1);
      const suit = c.slice(-1);
      if (rank === 'T') rank = '10';
      return `${rank}${SUIT[suit] || suit}`;
    });
}

// Parse the Spot POSTFLOP history into a canonical STREET-AWARE token path so
// nodes link up. The real sheet grammar (confirmed against the live export):
//   "Flop: LJ x, BTN b51%, LJ c | Turn: LJ x, BTN b94% → LJ to act"
// - The arrow is unicode '→' (also accept '->').
// - Segments are '|'-separated, each with a street prefix (Flop:/Turn:/River:).
// - Tokens: x=check, b51%=bet, r30%=raise, c=call, AI 88%=all-in.
// Paths are prefixed with the street letter (F/T/R) so the same action on
// different streets never collides (bug: preflop vs flop jams all mapped to
// one key before this).
// Bare preflop prompts ("LJ open", "LJ vs BTN 3-bet", "LJ to act") have no
// grammar → empty path; the preflop spine links those explicitly.
// Escape a position name for use inside a RegExp (UTG+1, UTG+2 contain '+').
function reEsc(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// [heroPos, villainPos] are the two actor labels in this sheet (e.g.
// ['BTN','SB']). Passed in so the parser isn't hardcoded to LJ/BTN.
function historyPath(spot, heroPos, villainPos) {
  if (!spot) return '';
  const pre = spot.split(/→|->/)[0];
  if (!/\b(Flop|Turn|River):/.test(pre)) return '';
  const actorAlt = `${reEsc(heroPos)}|${reEsc(villainPos)}`;
  const toks = [];
  for (const seg of pre.split('|')) {
    const sm = seg.match(/\b(Flop|Turn|River):/);
    if (!sm) continue;
    const st = sm[1][0]; // F / T / R
    const body = seg.slice(sm.index + sm[0].length);
    // Order matters: AI and multi-char tokens before single letters.
    const re = new RegExp(
      `(${actorAlt})\\s+(AI(?:\\s*\\d+%?)?|b\\d*%?|r\\d*%?|x|c|f)\\b`,
      'g'
    );
    let m;
    while ((m = re.exec(body))) {
      let a = m[2].toLowerCase();
      if (a.startsWith('ai')) a = 'ai';
      else if (a.startsWith('b')) a = 'b';
      else if (a.startsWith('r')) a = 'r';
      else if (a.startsWith('x')) a = 'x';
      // Canonicalize the actor to H (hero) / V (villain) so path keys don't
      // depend on the position names.
      const who = m[1] === heroPos ? 'H' : 'V';
      toks.push(`${st}:${who}:${a}`);
    }
  }
  return toks.join('|');
}

/// Parse the sheet "Hand" title → { heroPos, villainPos, stackBB, format }.
/// Title grammar: "MTT 50bb · BTN vs SB · QcTd9d" (or 'cash'). Falls back to
/// the legacy LJ/BTN/70 when the title can't be parsed, preserving the
/// original spot's behaviour.
// Canonical position labels the app uses. Solver titles write 'UTG1'/'UTG2'
// (and other aliases); normalize so the app matches the villain seat (else it
// renders the real villain as folded — the KK-vs-UTG1 bug).
function normalizePos(raw) {
  const p = (raw || '').trim().toUpperCase();
  const map = {
    UTG1: 'UTG+1', 'UTG+1': 'UTG+1', UTG2: 'UTG+2', 'UTG+2': 'UTG+2',
    MP: 'LJ', MP1: 'LJ', MP2: 'HJ', EP: 'UTG', LOJACK: 'LJ', HIJACK: 'HJ',
  };
  return map[p] || p;
}

function parseTitleMeta(title) {
  const t = (title || '').trim();
  const fmt = /\bMTT\b/i.test(t) ? 'mtt' : /\bcash\b/i.test(t) ? 'cash' : 'mtt';
  const stackM = t.match(/(\d+(?:\.\d+)?)\s*bb\b/i);
  const vsM = t.match(/([A-Za-z+0-9]+)\s+vs\s+([A-Za-z+0-9]+)/i);
  // RAW (as the sheet writes them) — these must match the Actor column and the
  // Spot history tokens verbatim. The app-facing labels are normalized only at
  // output (heroPosition/villainPosition) so the app's seat map matches.
  return {
    heroPos: HERO_POS || (vsM ? vsM[1].toUpperCase() : 'LJ'),
    villainPos: VILLAIN_POS || (vsM ? vsM[2].toUpperCase() : 'BTN'),
    stackBB: STACK ? parseFloat(STACK) : stackM ? parseFloat(stackM[1]) : 70,
    format: fmt,
    anteMode: fmt === 'mtt',
  };
}

// Map a node's RAW action name to its history token. 'bet' and 'raise' are
// distinct in the grammar (b vs r) even though the app folds both into
// AuthoredAction.raise.
function actionToken(rawAction) {
  switch (rawAction) {
    case 'check':
      return 'x';
    case 'bet':
      return 'b';
    case 'raise':
      return 'r';
    case 'call':
      return 'c';
    case 'fold':
      return 'f';
    case 'allin':
      return 'ai';
    default:
      return rawAction;
  }
}

async function main() {
  const rows = await readSheet();
  if (!rows.length) {
    console.error('Sheet is empty.');
    process.exit(1);
  }
  const header = rows[0];
  const col = (name) => header.findIndex((h) => (h || '').startsWith(name));
  const ci = {
    street: col('Street'),
    board: col('Board'),
    step: col('Step'),
    spot: col('Spot'),
    actor: col('Actor'),
    actions: col('Actions'),
    sizing: col('Sizing'),
    range: col('Range'),
    hand: col('Hand'),
    explanation: col('Explanation'), // JSON fact block (new) / prose (old)
    magsNote: col('mags_note'), // column N — maintainer free-text note
  };

  // Resolve hero/villain/stack from the first data row's "Hand" title
  // (overridable by --heroPos/--villainPos/--stack).
  const firstData = rows.slice(1).find((row) => row && row[ci.step]);
  const meta = parseTitleMeta(firstData ? firstData[ci.hand] : '');
  console.log(
    `Meta: hero=${meta.heroPos} villain=${meta.villainPos} ` +
      `stack=${meta.stackBB}bb format=${meta.format}`
  );

  const nodes = []; // raw parsed rows
  for (let r = 1; r < rows.length; r++) {
    const row = rows[r];
    if (!row || !row[ci.step]) continue;
    // Keep RAW names (bet vs raise) for history tokens; the app-facing
    // actions fold 'bet' into 'raise'.
    const rawActions = (row[ci.actions] || '')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    const actions = rawActions.map((a) => (a === 'bet' ? 'raise' : a));
    // Sizing formats seen in real exports (per ';'-separated part):
    //   "raise=2.1bb"              → bb directly after '='
    //   "bet=51% pot (8.8bb)"      → % of pot + absolute bb in parens
    //   "raise=30% (to 19.2bb)"    → % + 'to' bb in parens
    //   "allin=88% pot (62.65bb)"
    // We record the absolute bb amount per action (app shows real numbers)
    // and derive the pot when a "% pot" + bb pair is present: pot = bb/(pct).
    const sizing = {};
    let potFromSizing = 0;
    for (const part of (row[ci.sizing] || '').split(';')) {
      const am = part.match(/(fold|call|raise|check|allin|bet)\s*=/i);
      if (!am) continue;
      const a = am[1].toLowerCase() === 'bet' ? 'raise' : am[1].toLowerCase();
      // Absolute bb: the LAST "<num>bb" in the part (covers all formats).
      const bbs = [...part.matchAll(/([\d.]+)\s*bb/gi)];
      if (bbs.length) sizing[a] = parseFloat(bbs[bbs.length - 1][1]);
      // Pot derivation from "<pct>% pot (<bb>bb)" — BET entries only: bets
      // are always sized vs the CURRENT pot, so the division is exact. Raise
      // and all-in percentages reference other baselines (previous bet /
      // remaining stack) and give wrong pots — those nodes inherit via BFS.
      const pm =
        am[1].toLowerCase() === 'bet'
          ? part.match(/([\d.]+)%\s*pot\s*\(([\d.]+)\s*bb\)/i)
          : null;
      if (pm) {
        const pct = parseFloat(pm[1]) / 100;
        const bb = parseFloat(pm[2]);
        if (pct > 0) potFromSizing = Math.round((bb / pct) * 10) / 10;
      }
    }
    // Column M: a JSON fact block on new sheets, plain prose on old ones.
    // When it parses as an object, keep the structured block as `facts` AND
    // derive a plain-text `explanation` (key_concept + first fact) for the
    // in-app grader. When it's prose, `explanation` is the raw string and
    // `facts` is null. Column N is the maintainer `mags_note`.
    const rawExplanation =
      ci.explanation >= 0 ? (row[ci.explanation] || '').trim() : '';
    const { facts, explanation } = parseFactBlock(rawExplanation);
    const magsNote =
      ci.magsNote >= 0 ? (row[ci.magsNote] || '').trim() : '';
    nodes.push({
      step: parseInt(row[ci.step], 10),
      street: STREET[row[ci.street]] || 'preflop',
      board: boardCards(row[ci.board]),
      actor: row[ci.actor] === meta.heroPos ? 'hero' : 'villain',
      actions,
      rawActions,
      sizing,
      pot: potFromSizing,
      prompt: (row[ci.spot] || '').split(/→|->/).slice(-1)[0].trim(),
      path: historyPath(row[ci.spot], meta.heroPos, meta.villainPos),
      freq: parseRange(row[ci.range]),
      title: row[ci.hand] || '',
      explanation,
      facts,
      magsNote,
    });
  }

  for (const n of nodes) n.id = `n${n.step}`;
  // History paths canonicalize actors to H/V (see historyPath), so edge
  // keys must too — independent of the position names in this sheet.
  const whoFor = (actor) => (actor === 'hero' ? 'H' : 'V');

  // Postflop nodes link by action-history path. Preflop + the flop-entry node
  // have no history grammar, so chain the PREFLOP SPINE explicitly by step
  // order: the hero's "best" preflop action advances to the next spine node.
  //   step1 LJ open   --raise-->  step2 BTN vs open
  //   step2 BTN 3-bet --raise-->  step3 LJ vs 3-bet
  //   step3 LJ call   --call-->   step4 LJ flop first-to-act
  //   step4 LJ check  --check-->  step5 BTN flop vs check
  // (These are the spine edges; non-spine preflop actions like fold/4-bet are
  //  terminal — the tree only walks the line the solver actually solved deeper.)
  const byPath = new Map();
  for (const n of nodes) {
    if (!n.path) continue;
    if (byPath.has(n.path)) {
      console.warn(
        `WARNING: path collision — ${byPath.get(n.path).id} and ${n.id} both at "${n.path}"`
      );
    }
    byPath.set(n.path, n);
  }

  // Preflop spine (no history grammar for preflop actions) — DERIVED from the
  // sheet so it works for any preflop sequence (open→3bet→call, open→call,
  // etc.), not just LJ's open→3bet→call. Rule: walk the preflop steps in order
  // and link each to the next; the transition INTO the first postflop node is a
  // 'call' (someone closes the preflop action to see a flop), every earlier
  // preflop transition is a 'raise' (open / 3-bet / 4-bet). Non-spine preflop
  // actions (fold / the branch not solved deeper) stay terminal.
  const preSteps = nodes
    .filter((n) => n.street === 'preflop')
    .map((n) => n.step)
    .sort((x, y) => x - y);
  const firstPostStep = Math.min(
    ...nodes.filter((n) => n.street !== 'preflop').map((n) => n.step)
  );
  const spine = {};
  for (let i = 0; i < preSteps.length; i++) {
    const step = preSteps[i];
    const next = preSteps[i + 1] ?? firstPostStep; // flop entry after last pre
    if (!Number.isFinite(next)) continue;
    // Last preflop step → postflop is a call; earlier ones are raises. Only
    // add the edge if the node actually offers that action.
    const node = nodes.find((n) => n.step === step);
    const isLastPre = i === preSteps.length - 1;
    const edge = isLastPre ? 'call' : 'raise';
    if (node && node.actions.includes(edge)) spine[step] = { [edge]: next };
  }
  console.log(
    `Preflop spine: ${Object.entries(spine)
      .map(([s, e]) => `${s}-${Object.keys(e)[0]}->${Object.values(e)[0]}`)
      .join(' ')}`
  );

  const STREET_LETTER = { preflop: 'P', flop: 'F', turn: 'T', river: 'R' };

  for (const n of nodes) {
    n.children = {};
    for (let i = 0; i < n.actions.length; i++) {
      const a = n.actions[i]; // app-facing name (bet folded into raise)
      const raw = n.rawActions[i]; // grammar name (bet vs raise distinct)
      // Spine override first (preflop).
      if (spine[n.step] && spine[n.step][a] != null) {
        n.children[a] = `n${spine[n.step][a]}`;
        continue;
      }
      // Street-aware history link. The edge's street is THIS node's street.
      const childPath = [
        n.path,
        `${STREET_LETTER[n.street]}:${whoFor(n.actor)}:${actionToken(raw)}`,
      ]
        .filter(Boolean)
        .join('|');
      const child = byPath.get(childPath);
      n.children[a] = child ? child.id : null;
    }
  }

  // ── Pot / to-call fill (BFS from the root) ────────────────────────────
  // Bet-derived pots ("bet=X% pot (Ybb)") are exact; everything else is
  // accumulated: pot(child) = pot(parent) + edge amount. toCall(child) is the
  // incoming bet/raise/jam amount when the edge was aggressive.
  {
    const byId = new Map(nodes.map((n) => [n.id, n]));
    const rootN = nodes.find((n) => n.step === 1) || nodes[0];
    // Preflop seed: SB+BB+BB-ante ≈ 2.5bb.
    if (!rootN.pot) rootN.pot = 2.5;
    const seen = new Set([rootN.id]);
    const q = [rootN];
    while (q.length) {
      const n = q.shift();
      for (const [a, cid] of Object.entries(n.children)) {
        if (!cid || seen.has(cid)) continue;
        const c = byId.get(cid);
        if (!c) continue;
        const size = n.sizing[a] || 0;
        const aggressive = a === 'raise' || a === 'allin';
        const addend = aggressive
          ? size
          : a === 'call'
            ? n.toCall || n.sizing.call || 0
            : 0;
        const inherited = Math.round(((n.pot || 0) + addend) * 10) / 10;
        // Prefer the exact bet-derived pot when the child has one.
        if (!c.pot) c.pot = inherited;
        // The child faces the aggressive amount (unless sheet already set it).
        c.toCall = aggressive ? size : c.sizing.call || 0;
        seen.add(cid);
        q.push(c);
      }
    }
    // Nodes that still miss toCall from sheet sizing keep sizing.call.
    for (const n of nodes) if (n.toCall == null) n.toCall = n.sizing.call || 0;
  }

  // The exact hero combo from the fact block (column M JSON), e.g. "7s-6h".
  // When present it is the SOURCE OF TRUTH for which two cards the table deals,
  // so the dealt combo matches the reasoning in the facts (bug 2026-10-28: the
  // auto-picker chose K♠Q♠ while the facts assumed K♥Q♥). First hero node wins.
  const factHeroHand = (() => {
    for (const n of nodes) {
      const h = n.facts && n.facts.hero_hand;
      if (h && /^[AKQJT2-9][shdc]-?[AKQJT2-9][shdc]$/i.test(String(h).replace(/\s/g, ''))) {
        return String(h).replace(/\s/g, '');
      }
    }
    return null;
  })();

  const root = nodes.find((n) => n.step === 1) || nodes[0];
  // Big blinds always read 'BB' in the app (sheet titles say '50bb').
  const title = (root.title || SPOT_ID).replace(/(\d)bb\b/g, '$1BB');
  // The final board (longest board seen) — for board-aware hero-card picking.
  const finalBoard = nodes.reduce(
    (b, n) => (n.board.length > b.length ? n.board : b),
    []
  );
  const formatLabel = `${meta.format === 'mtt' ? 'MTT' : 'cash'} · ${meta.stackBB}BB`;

  const treeNodes = {};
  for (const n of nodes) {
    treeNodes[n.id] = {
      id: n.id,
      street: n.street,
      board: n.board,
      actor: n.actor,
      potBB: n.pot || 0,
      toCallBB: n.toCall || 0,
      prompt: n.prompt,
      ...(n.explanation ? { explanation: n.explanation } : {}),
      ...(n.facts ? { facts: n.facts } : {}),
      ...(n.magsNote ? { magsNote: n.magsNote } : {}),
      actions: n.actions,
      sizingBB: n.sizing,
      freq: n.freq,
      children: n.children,
    };
  }

  const tree = {
    id: SPOT_ID,
    title,
    formatLabel,
    stackBB: meta.stackBB,
    anteMode: meta.anteMode,
    heroPosition: normalizePos(meta.heroPos),
    villainPosition: normalizePos(meta.villainPos),
    heroCards: HERO ? heroCardsFor(HERO, finalBoard, factHeroHand) : [],
    heroHandClass: HERO || '',
    rootId: root.id,
    nodes: treeNodes,
  };
  if (HERO && tree.heroCards.length !== 2) {
    console.warn(
      `WARNING: could not resolve concrete cards for hero ${HERO} off board ` +
        `${finalBoard.join('')} — pass --cards 'Xy,Zw' (GTOW ascii).`
    );
  }

  const maxDecisions = maxHeroDecisions(tree.nodes, tree.rootId);
  if (maxDecisions > MAX_HERO_DECISIONS_PER_HAND) {
    throw new Error(
      `Tree has a hero line of ${maxDecisions} decisions (max ` +
        `${MAX_HERO_DECISIONS_PER_HAND}): a 5-hand day would exceed the ` +
        `leaderboard rules limits (verdicts<=60 chars, weights<=50). Prune the tree.`
    );
  }
  console.log(`Max hero decisions on any path: ${maxDecisions}`);

  const json = JSON.stringify(tree, null, 2);
  fs.writeFileSync(path.join(__dirname, OUT), json);
  console.log(`Wrote ${OUT}  (${nodes.length} nodes, root=${root.id})`);
  // Quick link sanity: report unlinked non-fold edges.
  let dangling = 0;
  for (const n of nodes)
    for (const a of n.actions)
      if (n.children[a] === null && a !== 'fold') dangling++;
  console.log(`Terminal/unlinked non-fold edges: ${dangling} (fold edges are terminal by design)`);

  if (UPLOAD) {
    const admin = require('firebase-admin');
    admin.initializeApp({
      credential: admin.credential.cert(
        require(path.join(__dirname, 'service-account.json'))
      ),
    });
    // Firestore auto-indexes every map entry; a big tree (hundreds of nodes ×
    // per-hand freqs) blows past the 20k index-entries-per-doc limit. Store the
    // tree as ONE JSON string ('treeJson') so it counts as a single index
    // entry, with a little queryable metadata alongside. The app loader parses
    // treeJson when present (and still accepts the old inline shape).
    const doc = {
      id: tree.id,
      title: tree.title,
      formatLabel: tree.formatLabel,
      heroPosition: tree.heroPosition,
      villainPosition: tree.villainPosition,
      heroHandClass: tree.heroHandClass,
      treeJson: JSON.stringify(tree),
    };
    await admin.firestore().collection('authored_spots').doc(SPOT_ID).set(doc);
    console.log(`Uploaded to authored_spots/${SPOT_ID} (treeJson blob)`);
  }
}

// Hero hand class → two concrete glyph cards that avoid [board].
// Precedence: explicit --cards (GTOW ascii, e.g. 'Kd,Qd') wins; otherwise
// auto-pick suits for the 169 class so neither card is on the board.
// Returns [] if it can't (caller warns → pass --cards).
function glyphFromAscii(c) {
  let rank = c.slice(0, -1);
  const suit = c.slice(-1).toLowerCase();
  if (rank.toUpperCase() === 'T') rank = '10';
  else rank = rank.toUpperCase();
  const SUITS = { s: '♠', h: '♥', d: '♦', c: '♣' };
  return `${rank}${SUITS[suit] || suit}`;
}
function heroCardsFor(hc, board, factHeroHand) {
  const used = new Set(board || []);
  if (CARDS) {
    const cards = CARDS.split(',').map((c) => glyphFromAscii(c.trim()));
    return cards.length === 2 ? cards : [];
  }
  // Prefer the exact combo from the fact block ("7s-6h" → ['7♠','6♥']) so the
  // dealt cards match the authored reasoning. Only use it if both cards are
  // off-board (a fact combo that clashes with the board falls through to auto).
  if (factHeroHand) {
    const parts = factHeroHand.split('-');
    if (parts.length === 2) {
      const cards = parts.map((c) => glyphFromAscii(c.trim()));
      if (cards.length === 2 && cards.every((c) => !used.has(c))) return cards;
    }
  }
  // Rank glyphs: ten is '10'.
  const rankGlyph = (r) => (r === 'T' ? '10' : r);
  const ALL_SUITS = ['♠', '♥', '♦', '♣'];
  const m = hc.match(/^([AKQJT2-9])([AKQJT2-9])?([so])?$/);
  if (!m) return [];
  const r1 = rankGlyph(m[1]);
  const r2 = m[2] ? rankGlyph(m[2]) : r1; // pair when one rank
  const kind = m[3]; // 's' | 'o' | undefined (pair)
  const freeFor = (rank) => ALL_SUITS.filter((s) => !used.has(`${rank}${s}`));
  if (!m[2]) {
    // Pair: two distinct suits of the same rank, both off-board.
    const free = freeFor(r1);
    if (free.length < 2) return [];
    const picked = [`${r1}${free[0]}`, `${r1}${free[1]}`];
    picked.forEach((c) => used.add(c));
    return picked;
  }
  if (kind === 's') {
    // Suited: one suit present for BOTH ranks, off-board.
    for (const s of ALL_SUITS) {
      const a = `${r1}${s}`;
      const b = `${r2}${s}`;
      if (!used.has(a) && !used.has(b)) return [a, b];
    }
    return [];
  }
  // Offsuit: two different suits, each off-board.
  const f1 = freeFor(r1);
  const f2 = freeFor(r2);
  for (const s1 of f1) {
    for (const s2 of f2) {
      if (s1 !== s2) return [`${r1}${s1}`, `${r2}${s2}`];
    }
  }
  return [];
}

module.exports = { maxHeroDecisions, MAX_HERO_DECISIONS_PER_HAND };

if (require.main === module) main().catch((e) => {
  console.error(e);
  process.exit(1);
});
