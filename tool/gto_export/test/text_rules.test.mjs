import test from 'node:test';
import assert from 'node:assert/strict';
import { checkPunctuation, normalizeLine, buildFallbackPair, freqClause } from '../text_rules.mjs';

const FRAGMENTS = [
  'Small range c-bet with top set',
  'Shove river into capped full houses',
  'Defend medium pair versus small lead',
];

test('fragments fail checkPunctuation', () => {
  for (const f of FRAGMENTS) {
    const r = checkPunctuation(f);
    assert.ok(r.includes('no_terminal'), f);
    assert.ok(r.includes('fragment'), f);
  }
});

test('well-formed lines pass', () => {
  for (const ok of [
    'Nice. The BTN 3-bet range is wide, so A9s can call.',
    'You jammed the river… and the solver agrees!',
    'Why call? Because the pot odds are fine.',
    'Compare it vs. a tight range, then call.',
  ]) assert.deepEqual(checkPunctuation(ok), [], ok);
});

test('detects lowercase after period and double space', () => {
  assert.ok(checkPunctuation('Good call. the BTN folds.').includes('lowercase_after_period'));
  assert.ok(checkPunctuation('Good  call.').includes('double_space'));
  assert.ok(checkPunctuation('Fold.').includes('no_full_sentence'));
  assert.ok(checkPunctuation('').length > 0);
});

test('normalizeLine fixes fragments and is idempotent', () => {
  for (const f of FRAGMENTS) {
    const n = normalizeLine(f);
    assert.ok(n.endsWith('.'));
    assert.equal(normalizeLine(n), n);
  }
  const messy = '  good call.  the BTN folds  a lot ';
  const n = normalizeLine(messy);
  assert.equal(n, 'Good call. The BTN folds a lot.');
  assert.equal(normalizeLine(n), n);
});

test('poker tokens, dashes and ellipsis untouched', () => {
  const s = 'A9s is a BTN 3-bet call — c-bet small…';
  assert.equal(normalizeLine(s), s);
  assert.equal(normalizeLine('c-bet small with A9s'), 'C-bet small with A9s.');
  assert.equal(normalizeLine('3-bet light vs. BTN'), '3-bet light vs. BTN.');
});

const sets = [
  { action: 'raise', top: 'raise', topPct: 90, chosenPct: 90, concept: 'Small range c-bet with top set' },
  { action: 'check', top: 'raise', topPct: 90, chosenPct: 10, concept: 'Small range c-bet with top set' },
  { action: 'check', top: 'raise', topPct: 90, chosenPct: 0, concept: 'x', wrongNote: 'Checking gives up value against weaker aces' },
  { action: 'call', top: null, concept: 'BTN opens wide' },
];

test('fallback builder never returns a fragment, variants differ', () => {
  for (const o of sets) {
    const pair = buildFallbackPair(o);
    assert.equal(pair.length, 2);
    assert.notEqual(pair[0], pair[1]);
    for (const p of pair) assert.deepEqual(checkPunctuation(p), [], p);
  }
  assert.equal(buildFallbackPair(sets[0])[0], "The solver's plan: small range c-bet with top set.");
});

test('device bug: FLOP BET (top action) uses the concept', () => {
  const [a] = buildFallbackPair({ action: 'bet', top: 'bet', topPct: 100, chosenPct: 100,
    concept: 'C-betting top pair for value and protection' });
  assert.equal(a, "The solver's plan: C-betting top pair for value and protection.");
});

test('device bug: TURN CHECK never describes betting; names preferred action', () => {
  const pair = buildFallbackPair({ action: 'check', top: 'raise', topPct: 85, chosenPct: 15, street: 'turn', toCallBB: 0,
    concept: 'Turn value barrel against weaker aces' });
  for (const p of pair) {
    assert.ok(!/barrel/i.test(p), p);
    assert.deepEqual(checkPunctuation(p), [], p);
  }
  assert.equal(pair[0], 'The solver bets most of the time here.');
  assert.equal(pair[1], 'The solver sometimes checks here — it bets most of the time.');
});

test('wrong_action_note is preferred for non-top actions', () => {
  assert.equal(buildFallbackPair(sets[2])[0], 'Checking gives up value against weaker aces.');
});

test('Dart parity: quote closer, spacing before punctuation, double dots', () => {
  assert.equal(normalizeLine('he said "go." then left'), 'He said "go." Then left.');
  assert.equal(normalizeLine('a  ,  b'), 'A, b.');
  assert.equal(normalizeLine('Done.. ok'), 'Done. Ok.');
  assert.equal(normalizeLine('wait... what'), 'Wait... What.');
  assert.equal(normalizeLine('see vs. the field'), 'See vs. the field.');
  for (const x of ['he said "go." then left', 'a  ,  b', 'Done.. ok', 'x\ny z']) {
    const n = normalizeLine(x);
    assert.equal(normalizeLine(n), n, x);
  }
});

test('frequency bands in words', () => {
  const c = (p) => freqClause('it', 'bets', p);
  assert.equal(c(100), 'it bets every time');
  assert.equal(c(96), 'it almost always bets');
  assert.equal(c(80), 'it bets most of the time');
  assert.equal(c(50), 'it bets about half the time');
  assert.equal(c(20), 'it sometimes bets');
  assert.equal(c(2), 'it almost never bets');
  assert.equal(c(0), 'it almost never bets');
});

test('device wording: grammar of check vs bet', () => {
  const [a, b] = buildFallbackPair({ action: 'check', top: 'raise', topPct: 100, chosenPct: 0, street: 'flop', toCallBB: 0, concept: 'x' });
  assert.equal(a, 'The solver bets every time here.');
  assert.equal(b, 'The solver almost never checks here — it bets every time.');
});

test('every action verb, numbers never appear', () => {
  const verbs = { fold: 'folds', check: 'checks', call: 'calls', allin: 'jams', bet: 'bets' };
  for (const [act, v] of Object.entries(verbs)) {
    const [, b] = buildFallbackPair({ action: act, top: 'zzz', topPct: 70, chosenPct: 10, concept: 'c' });
    assert.ok(b.includes(`sometimes ${v}`), b);
    assert.ok(!/\d/.test(b), b);
  }
  const [, pre] = buildFallbackPair({ action: 'call', top: 'raise', topPct: 70, chosenPct: 10, street: 'preflop' });
  assert.ok(pre.includes('raises'), pre);
  const [, post] = buildFallbackPair({ action: 'call', top: 'raise', topPct: 70, chosenPct: 10, street: 'flop', toCallBB: 3 });
  assert.ok(post.includes('raises'), post);
  const [g] = buildFallbackPair({ action: 'allin', top: 'allin', topPct: 90, chosenPct: 90 });
  assert.equal(g, "Jamming is the solver's most common line here.");
});

test('wrong note strips numbers; colon concept uses non-colon frames', () => {
  assert.equal(buildFallbackPair({ action: 'check', top: 'bet', topPct: 90, chosenPct: 5, wrongNote: 'Checking loses 40% of value' })[0], 'Checking loses of value.');
  const pair = buildFallbackPair({ action: 'raise', top: 'raise', topPct: 95, chosenPct: 95, concept: 'Overbet shove: smaller full houses still call' });
  assert.equal(pair[0], "Here is the solver's plan. Overbet shove: smaller full houses still call.");
  assert.equal(pair[1], 'Overbet shove: smaller full houses still call. That is the idea to keep.');
  assert.ok(!/plan[^.]*:/.test(pair[0]));
  assert.equal(normalizeLine(pair[1]), pair[1]);
});

test('stripNumbers: sizing percentages dropped, frequency becomes often', async () => {
  const { stripNumbers } = await import('../text_rules.mjs');
  assert.equal(stripNumbers('call a 30% pot bet'), 'call a pot bet');
  assert.equal(stripNumbers('it calls 40% of the time'), 'it calls often of the time');
});
