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

if (!SHEET_ID) {
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
  // Discover tab if not given.
  let range = TAB ? `${TAB}!A:J` : 'A:J';
  if (!TAB) {
    const meta = await sheets.spreadsheets.get({ spreadsheetId: SHEET_ID });
    const first = meta.data.sheets[0].properties.title;
    range = `${first}!A:J`;
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
function historyPath(spot) {
  if (!spot) return '';
  const pre = spot.split(/→|->/)[0];
  if (!/\b(Flop|Turn|River):/.test(pre)) return '';
  const toks = [];
  for (const seg of pre.split('|')) {
    const sm = seg.match(/\b(Flop|Turn|River):/);
    if (!sm) continue;
    const st = sm[1][0]; // F / T / R
    const body = seg.slice(sm.index + sm[0].length);
    // Order matters: AI and multi-char tokens before single letters.
    const re = /\b(LJ|BTN)\s+(AI(?:\s*\d+%?)?|b\d*%?|r\d*%?|x|c|f)\b/g;
    let m;
    while ((m = re.exec(body))) {
      let a = m[2].toLowerCase();
      if (a.startsWith('ai')) a = 'ai';
      else if (a.startsWith('b')) a = 'b';
      else if (a.startsWith('r')) a = 'r';
      else if (a.startsWith('x')) a = 'x';
      toks.push(`${st}:${m[1]}:${a}`);
    }
  }
  return toks.join('|');
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
  };

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
    nodes.push({
      step: parseInt(row[ci.step], 10),
      street: STREET[row[ci.street]] || 'preflop',
      board: boardCards(row[ci.board]),
      actor: row[ci.actor] === 'LJ' ? 'hero' : 'villain',
      actions,
      rawActions,
      sizing,
      pot: potFromSizing,
      prompt: (row[ci.spot] || '').split(/→|->/).slice(-1)[0].trim(),
      path: historyPath(row[ci.spot]),
      freq: parseRange(row[ci.range]),
      title: row[ci.hand] || '',
    });
  }

  for (const n of nodes) n.id = `n${n.step}`;
  const whoFor = (actor) => (actor === 'hero' ? 'LJ' : 'BTN');

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

  // Preflop spine (no history grammar for preflop actions):
  //   n1 LJ open --raise--> n2 BTN vs open --raise--> n3 LJ vs 3-bet
  //   n3 --call--> n4 (flop entry). Other preflop actions are terminal.
  const spine = { 1: { raise: 2 }, 2: { raise: 3 }, 3: { call: 4 } };

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

  const root = nodes.find((n) => n.step === 1) || nodes[0];
  // Big blinds always read 'BB' in the app (sheet titles say '70bb').
  const title = (root.title || SPOT_ID).replace(/(\d)bb\b/g, '$1BB');

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
      actions: n.actions,
      sizingBB: n.sizing,
      freq: n.freq,
      children: n.children,
    };
  }

  const tree = {
    id: SPOT_ID,
    title,
    formatLabel: 'MTT · 70BB · 9-max',
    stackBB: 70,
    anteMode: true,
    heroPosition: 'LJ',
    villainPosition: 'BTN',
    heroCards: HERO ? heroCardsFor(HERO) : [],
    heroHandClass: HERO || '',
    rootId: root.id,
    nodes: treeNodes,
  };

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
    await admin.firestore().collection('authored_spots').doc(SPOT_ID).set(tree);
    console.log(`Uploaded to authored_spots/${SPOT_ID}`);
  }
}

// Hero hand → concrete off-board cards (board = T♠9♣4♦J♦2♥). Mirrors the app.
function heroCardsFor(hc) {
  const MAP = {
    '99': ['9♠', '9♥'],
    TT: ['10♥', '10♦'],
    KQs: ['K♠', 'Q♠'],
    JTs: ['J♥', '10♥'], // hearts — J♦ is the turn card
  };
  return MAP[hc] || [];
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
