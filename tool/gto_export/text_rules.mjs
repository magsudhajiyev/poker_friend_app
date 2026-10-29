// Pure text rules for coach lines (no I/O, no SDKs) — unit-tested in
// test/text_rules.test.mjs.
//
// KEEP IN SYNC with the Flutter helper `normalizeCoachText` in
// lib/utils/coach_text.dart: same behaviour (trim, collapse whitespace,
// capitalise sentence starts, add a final '.', idempotent). If one changes,
// change the other.

const TERMINAL = /[.!?…]["'”’)\]]*$/;
// Abbreviations whose trailing '.' does not end a sentence.
const ABBREV = /(?:^|\s)(?:vs|e\.g|i\.e|etc|approx|w\/o)$/i;

// A sentence boundary: letter/digit/closer + . ! ? + whitespace + next char.
// '…' and '...' are deliberately NOT boundaries (ellipsis may continue lower).
function boundaries(s) {
  const out = [];
  const re = /([A-Za-z0-9)"'”’\]])([.!?])(\s+)(\S)/g;
  let m;
  while ((m = re.exec(s))) {
    const before = s.slice(0, m.index + 1);
    if (m[2] === '.' && ABBREV.test(before)) continue;
    // "..." ellipsis written as three dots: previous char is also '.'.
    if (s[m.index - 1] === '.') continue;
    out.push({ index: m.index, punct: m[2], gap: m[3], next: m[4], nextIndex: m.index + 1 + 1 + m[3].length });
  }
  return out;
}

export function checkPunctuation(line) {
  const reasons = [];
  const s = String(line ?? '');
  const t = s.trim();
  if (!t) return ['empty'];
  if (!TERMINAL.test(t)) reasons.push('no_terminal');
  if (boundaries(t).some((b) => /[a-z]/.test(b.next))) reasons.push('lowercase_after_period');
  if (/ {2,}/.test(s) || /[\t\n\r]/.test(s)) reasons.push('double_space');
  const words = t.split(/\s+/).length;
  const internal = /[,;:—]|\s-\s|[.!?]\s/.test(t.replace(TERMINAL, ''));
  if (reasons.includes('no_terminal') && !internal && words <= 12) reasons.push('fragment');
  if (!reasons.includes('no_terminal')) {
    const sentences = t.split(/(?<=[.!?…])\s+/);
    if (!sentences.some((x) => x.split(/\s+/).length >= 3)) reasons.push('no_full_sentence');
  }
  return reasons;
}

// Port of Dart `_normalizeLine` + `normalizeCoachText` (coach_text.dart).
const D_CLOSERS = '"\'’”)';
const D_TERMINAL = new RegExp(`[.!?…][${D_CLOSERS}]*$`);
const D_BREAK = new RegExp(`([.!?][${D_CLOSERS}]*)(\\s+)(\\p{Ll})`, 'gu');
const D_ABBREV = new Set(['vs', 'e.g', 'i.e', 'etc', 'approx', 'incl', 'eg', 'ie', 'mr', 'dr']);

function endsWithAbbrev(upToStop) {
  const m = /([A-Za-z.]+)\.$/.exec(upToStop);
  return !!m && D_ABBREV.has(m[1].toLowerCase());
}

function capitaliseStart(t) {
  let i = 0;
  while (i < t.length && '("\'“‘¿¡'.includes(t[i])) i++;
  if (i >= t.length) return t;
  const c = t[i];
  if (c.toLowerCase() === c.toUpperCase()) return t;
  return t.slice(0, i) + c.toUpperCase() + t.slice(i + 1);
}

function normalizeOne(raw) {
  let t = raw.replace(/\s+/g, ' ').trim();
  if (!t) return '';
  t = t.replace(/ +([,.;:!?])/g, '$1').replace(/(?<!\.)\.\.(?!\.)/g, '.');
  const src = t;
  t = src.replace(D_BREAK, (all, stop, gap, ch, off) => {
    const before = src.slice(0, off + 1);
    if (stop.startsWith('.') && endsWithAbbrev(before)) return all;
    return stop + gap + ch.toUpperCase();
  });
  t = capitaliseStart(t);
  t = t.replace(/[,;:—-]+$/, '').trimEnd();
  if (!t) return '';
  return D_TERMINAL.test(t) ? t : t + '.';
}

export function normalizeLine(line) {
  return String(line ?? '')
    .split(/\s*[\r\n]+\s*/)
    .map(normalizeOne)
    .filter(Boolean)
    .join(' ');
}

// lowercase the first word only when it is a plain capitalised word
// ("Shove" -> "shove"); leave BTN, A9s, 3-bet, I, "Nash" style tokens alone.
export function lowercaseFirst(s) {
  const t = String(s ?? '').trim();
  const m = t.match(/^([A-Z][a-z]+)(?=[\s,.;:!?]|$)/);
  if (!m || ['Nash', 'Duke', 'Vega', 'Nova', 'I'].includes(m[1])) return t;
  return m[1].toLowerCase() + t.slice(m[1].length);
}

export function stripNumbers(s) {
  return String(s)
    .replace(/\(\s*\d+(?:\.\d+)?\s*%\s*\)/g, '')
    .replace(/\b\d+(?:\.\d+)?\s*%(?=\s+(?:of\s+(?:the\s+)?(?:time|hands|combos)|freq))/gi, 'often')
    .replace(/\b\d+(?:\.\d+)?\s*%\s*/g, '')
    .replace(/\s{2,}/g, ' ')
    .trim();
}

export function trimWords(s, max) {
  const w = String(s).split(/\s+/);
  return w.length <= max ? String(s) : w.slice(0, max).join(' ').replace(/[,;:]?$/, '') + '.';
}

const THIRD = { fold: 'folds', check: 'checks', call: 'calls', raise: 'raises', bet: 'bets', allin: 'jams' };
const GERUND = { fold: 'folding', check: 'checking', call: 'calling', raise: 'raising', bet: 'betting', allin: 'jamming' };
// Postflop with nothing to call, the wire action 'raise' reads as a 'bet'.
const asBet = (a, bet) => (a === 'raise' && bet ? 'bet' : a);

// Frequency as words (lines must not cite raw numbers). Returns the predicate
// "<adverb/phrase> + verb" for the subject, e.g. "almost never checks".
export function freqClause(subject, verbS, pct) {
  const p = Number(pct) || 0;
  if (p < 5) return `${subject} almost never ${verbS}`;
  if (p >= 99) return `${subject} ${verbS} every time`;
  if (p >= 95) return `${subject} almost always ${verbS}`;
  if (p >= 65) return `${subject} ${verbS} most of the time`;
  if (p >= 35) return `${subject} ${verbS} about half the time`;
  return `${subject} sometimes ${verbS}`;
}

// Fallback pair used when a generated line fails validation twice (and by the
// repair tool). NEVER returns a bare fragment, the two variants differ, and it
// is ACTION-AWARE: the node-level key_concept describes the solver's preferred
// line, so it is only used when the player's action IS that line. For any
// other action the text names the preferred action + frequency (in words, no
// raw numbers — same policy as stripNumbers) or the authored
// wrong_action_notes[action] when present.
//   opts: { action, top, topPct, chosenPct, concept, wrongNote, max, street, toCallBB }
export function buildFallbackPair(opts) {
  const { action, top, topPct = 0, chosenPct = 0, concept = '', wrongNote = '', max = 66, street = 'preflop', toCallBB = 0 } = opts;
  const bet = street !== 'preflop' && !toCallBB;
  const clean = (x) => stripNumbers(String(x ?? '')).replace(/[\s.!?\u2026,;:]+$/, '').trim();
  const finish = (arr) => arr.map((f) => normalizeLine(trimWords(f, max)));
  const isTop = top != null && action === top;
  const body0 = clean(concept);
  if (isTop && body0) {
    if (/[:—]/.test(body0)) {
      return finish([`Here is the solver's plan. ${body0}.`, `${body0}. That is the idea to keep.`]);
    }
    const body = lowercaseFirst(body0);
    return finish([`The solver's plan: ${body}.`, `The one idea to keep: ${body}.`]);
  }
  if (top == null) {
    return finish(['The solver has a clear plan at this spot.', 'Check the range chart to see how the solver mixes it.']);
  }
  const topV = THIRD[asBet(top, bet)] || String(top);
  if (isTop) {
    return finish([
      `${GERUND[asBet(action, bet)] || action} is the solver's most common line here.`,
      `${freqClause('The solver', topV, topPct)} in this spot.`,
    ]);
  }
  const actV = THIRD[asBet(action, bet)] || String(action);
  const note = clean(wrongNote);
  const first = note || `${freqClause('The solver', topV, topPct)} here`;
  const link = chosenPct < 35 ? ' — ' : '; ';
  return finish([
    first,
    `${freqClause('The solver', actV, chosenPct)} here${link}${freqClause('it', topV, topPct)}.`,
  ]);
}
