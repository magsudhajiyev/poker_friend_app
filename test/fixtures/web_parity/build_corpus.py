#!/usr/bin/env python3
"""Authoring script for the web-parity hand corpus.

Run from the repo root:  python3 test/fixtures/web_parity/build_corpus.py

It (re)writes hands/*.json and sessions/*.json. The JSON files are the
contract; this script only exists so the corpus is reproducible and so
stacks / pots stay internally consistent. All data is synthetic.

Action script syntax (space separated): <seat><code><n>
  codes: f fold, x check, c call, b bet, r raise, a all-in
  n is in HALF big blinds (r6 = raise to 3bb). Preflop raise = TOTAL,
  postflop raise = ADDITIONAL on top of the current bet (CLAUDE.md rules).
"""
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
SUITS = {'s': '♠', 'h': '♥', 'd': '♦', 'c': '♣'}
NAMES = {1: 'Alice', 2: 'Bob', 3: 'Carol', 4: 'Dave', 5: 'Erin', 6: 'Frank',
         7: 'Grace', 8: 'Heidi', 9: 'Ivan'}
# Mirrors lib/utils/poker_positions.dart (active-player naming).
POS = {
    3: ['BTN', 'SB', 'BB'],
    4: ['BTN', 'SB', 'BB', 'UTG'],
    5: ['BTN', 'SB', 'BB', 'UTG', 'CO'],
    6: ['BTN', 'SB', 'BB', 'UTG', 'HJ', 'CO'],
    7: ['BTN', 'SB', 'BB', 'UTG', 'UTG+1', 'HJ', 'CO'],
    8: ['BTN', 'SB', 'BB', 'UTG', 'UTG+1', 'UTG+2', 'HJ', 'CO'],
    9: ['BTN', 'SB', 'BB', 'UTG', 'UTG+1', 'UTG+2', 'LJ', 'HJ', 'CO'],
}


def card(s):
    """'As' -> 'A♠'. Strings that already carry a symbol pass through."""
    return s if s[-1] in SUITS.values() else s[:-1] + SUITS[s[-1]]


def cards(s):
    return [card(x) for x in s.split()]


def num(x):
    """Whole floats become ints so the JSON has no spurious '.0'."""
    x = round(x, 6)
    return int(x) if x == int(x) else x


SESSIONS = {}


def session(sid, name, game, sb, bb, players, ante=False, buyin=None):
    SESSIONS[sid] = {
        'sessionId': sid, 'sessionName': name, 'gameType': game,
        'smallBlind': sb, 'bigBlind': bb, 'hasBBante': ante,
        'playerCount': players,
        'startTime': '2025-03-01T18:00:00.000Z',
        'endTime': '2025-03-01T23:00:00.000Z',
        'totalHands': 0,
    }
    if buyin is not None:
        SESSIONS[sid]['buyInAmount'] = buyin


session('cash_6max', 'Friday Cash 6-max', 'cash', 1, 2, 6)
session('cash_decimal', 'Low Stakes Decimal', 'cash', 0.25, 0.5, 6)
session('cash_9max', 'Casino 9-max', 'cash', 2, 5, 9)
session('cash_hu', 'Heads-up Duel', 'cash', 5, 10, 2)
session('cash_gaps', 'Short Table Gaps', 'cash', 1, 2, 5)
session('tourn_8max', 'Sunday Tournament', 'tournament', 300, 600, 8, buyin=10)
session('tourn_bbante', 'Turbo BB Ante', 'tournament', 100, 200, 6, ante=True,
        buyin=25)
session('cash_bbante', 'Cash BB Ante', 'cash', 1, 2, 6, ante=True)

HANDS = []


def build(hid, sid, seats, btn, hero, hole, streets, *, board=None, win=None,
          chop=None, shares=None, sd=None, stacks=None, stack=100, names=None,
          tags=(), completeness=None, blind_actions=True, scouted=False,
          extra=None, ids=False):
    """Simulate a hand and append the Firestore-shaped map to HANDS."""
    sess = SESSIONS[sid]
    sb_amt, bb_amt = sess['smallBlind'], sess['bigBlind']
    ante = sess['hasBBante']
    seats = sorted(seats)
    n = len(seats)
    bi = seats.index(btn)
    rel = {s: (seats.index(s) - bi) % n for s in seats}
    if n == 2:
        posname = {s: ('BTN/SB' if rel[s] == 0 else 'BB') for s in seats}
        sb_seat = btn
        bb_seat = [s for s in seats if s != btn][0]
    else:
        posname = {s: POS[n][rel[s]] for s in seats}
        sb_seat = [s for s in seats if rel[s] == 1][0]
        bb_seat = [s for s in seats if rel[s] == 2][0]
    stk = {s: float((stacks or {}).get(s, stack)) * bb_amt for s in seats}
    pname = dict(NAMES)
    pname.update(names or {})
    hand_no = len(HANDS) + 1
    t = [0]

    def ts():
        t[0] += 7
        return '2025-03-01T20:%02d:%02dZ' % (t[0] // 60, t[0] % 60)

    actions = []
    contrib = {s: 0.0 for s in seats}
    street_pot = {}

    def rec(seat, act, street, amount, before):
        actions.append({
            'player': seat, 'action': act, 'street': street,
            'timestamp': ts(), 'buttonPosition': btn,
            'playerName': pname[seat], 'playerId': None,
            'isCurrentUser': seat == hero, 'playerPosition': posname[seat],
            'playerStack': num(before),
            'amount': None if amount is None else num(amount)})

    committed = {s: 0.0 for s in seats}
    cur = 0.0
    if ante:
        stk[bb_seat] -= bb_amt
        contrib[bb_seat] += bb_amt
    for seat, amt, label in ((sb_seat, sb_amt, 'small blind'),
                             (bb_seat, bb_amt, 'big blind')):
        stk[seat] -= amt
        committed[seat] += amt
        contrib[seat] += amt
        cur = max(cur, amt)
        if blind_actions:
            rec(seat, label, 'preflop', amt, stk[seat])

    for street in ('preflop', 'flop', 'turn', 'river'):
        toks = streets.get(street, '')
        if street != 'preflop':
            if not toks:
                continue
            committed = {s: 0.0 for s in seats}
            cur = 0.0
        for m in re.finditer(r'(\d)([fxcbra])([\d.]*)', toks):
            seat, code, arg = int(m.group(1)), m.group(2), m.group(3)
            arg = float(arg) * bb_amt / 2 if arg else None
            before = stk[seat]
            if code == 'f':
                rec(seat, 'fold', street, None, before)
                continue
            if code == 'x':
                rec(seat, 'check', street, None, before)
                continue
            if code == 'c':
                put = min(cur - committed[seat], before)
                rec(seat, 'call', street, put, before)
                new_total = committed[seat] + put
            elif code == 'b':
                cur = arg
                rec(seat, 'bet', street, arg, before)
                new_total = arg
            elif code == 'r':
                rec(seat, 'raise', street, arg, before)
                new_total = arg if street == 'preflop' else cur + arg
                cur = new_total
            else:  # all-in
                total = committed[seat] + before
                if street == 'preflop':
                    if total > cur:
                        rec(seat, 'all-in', street, total, before)
                        cur = total
                    else:
                        rec(seat, 'all-in', street, before, before)
                elif cur == 0:
                    rec(seat, 'all-in', street, before, before)
                    cur = total
                elif total > cur:
                    rec(seat, 'all-in', street, total - cur, before)
                    cur = total
                else:
                    rec(seat, 'all-in', street, before, before)
                new_total = total
            delta = new_total - committed[seat]
            stk[seat] -= delta
            contrib[seat] += delta
            committed[seat] = new_total
        street_pot[street] = sum(contrib.values())

    pot = sum(contrib.values())
    if callable(shares):
        shares = shares(pot)
    shown = {str(s): {'card1': card(c[0]), 'card2': card(c[1])}
             for s, c in (sd or {}).items()}
    h = {
        'id': hid, 'sessionId': sid, 'handNumber': hand_no,
        'buttonPosition': btn, 'playerCount': n, 'actions': actions,
        'startTime': '2025-03-01T20:00:00.000Z',
        'endTime': '2025-03-01T20:%02d:%02dZ' % ((t[0] + 20) // 60,
                                                  (t[0] + 20) % 60),
        'state': 'completed',
        'boardCards': ({'flop': cards(board['flop']),
                        'turn': card(board['turn']) if 'turn' in board else None,
                        'river': card(board['river']) if 'river' in board else None}
                       if board else None),
        'ourHoleCards': ({'card1': card(hole[0]), 'card2': card(hole[1])}
                         if hole else None),
        'showdownData': ({'playerCards': shown, 'winner': win,
                          'handDescription': None} if sd else None),
        'reachedShowdown': bool(sd),
        'potAmount': num(pot),
        'preflopPot': num(street_pot.get('preflop', pot)),
        'flopPot': num(street_pot.get('flop', 0)),
        'turnPot': num(street_pot.get('turn', 0)),
        'riverPot': num(street_pot.get('river', 0)),
        'winnerId': None if chop else win,
        'heroPositionName': posname[hero],
        'heroSeatNumber': hero,
        'isChoppedPot': bool(chop), 'isSplitPot': bool(chop),
        'choppedWinners': chop,
        'individualShares': ({str(k): num(v) for k, v in shares.items()}
                             if shares else None),
        'sharePerWinner': num(pot / len(chop)) if chop and not shares else None,
        'isStarred': False, 'isScouted': scouted, 'tags': [], 'notes': '',
        'gameType': sess['gameType'],
        'smallBlind': sb_amt, 'bigBlind': bb_amt,
        'playerNames': {str(s): pname[s] for s in seats},
        'playerIds': {str(s): None for s in seats},
        '_tags': list(tags),
    }
    if ids:
        h['playerIds'] = {str(s): 'opp_%d' % s for s in seats}
        h['playerIds'][str(hero)] = 'uid_parity_hero'
    if completeness:
        h['completeness'] = completeness
    if extra:
        h.update(extra)
    HANDS.append(h)
    sess['totalHands'] += 1


# 6-max, btn=6: 1=SB 2=BB 3=UTG 4=HJ 5=CO 6=BTN
B6 = dict(sid='cash_6max', seats=[1, 2, 3, 4, 5, 6])

# ---------------------------------------------------------------- walks / folds
build('cash_walk_hero_bb', btn=6, hero=2, hole=('Ks', 'Jd'), win=2,
      streets={'preflop': '3f 4f 5f 6f 1f'}, tags=['cash', 'walk'], **B6)
build('cash_walk_hero_utg_fold', btn=6, hero=3, hole=('7c', '2d'), win=2,
      streets={'preflop': '3f 4f 5f 6f 1f'}, tags=['cash', 'walk'], **B6)
build('cash_hero_fold_utg', btn=6, hero=3, hole=('9s', '4h'), win=5,
      streets={'preflop': '3f 4f 5r6 6f 1f 2f'}, tags=['cash', 'fold'], **B6)

# ---------------------------------------------------------------- steal / cbet / 3bet
build('cash_btn_steal_uncontested', btn=6, hero=6, hole=('Qh', 'Jh'), win=6,
      streets={'preflop': '3f 4f 5f 6r6 1f 2f'}, tags=['cash', 'steal'], **B6)
build('cash_co_open_cbet_fold', btn=6, hero=5, hole=('As', 'Qd'), win=5,
      streets={'preflop': '3f 4f 5r6 6f 1f 2c', 'flop': '2x 5b5 2f'},
      board={'flop': 'Kc 8d 3s'}, tags=['cash', 'cbet', 'steal'], **B6)
build('cash_co_open_cbet_called_river_fold', btn=6, hero=5, hole=('Ah', 'Jc'),
      win=2, streets={'preflop': '3f 4f 5r6 6f 1f 2c',
                      'flop': '2x 5b5 2c', 'turn': '2x 5x',
                      'river': '2b15 5f'},
      board={'flop': 'Qs 9s 4d', 'turn': '2h', 'river': 'Kd'},
      tags=['cash', 'cbet', 'river-fold'], **B6)
build('cash_hero_3bet_btn_win', btn=6, hero=6, hole=('Ac', 'Kc'), win=6,
      streets={'preflop': '3f 4f 5r6 6r20 1f 2f 5f'},
      tags=['cash', '3bet'], **B6)
build('cash_hero_open_folds_to_3bet', btn=6, hero=4, hole=('Td', 'Tc'), win=6,
      streets={'preflop': '3f 4r6 5f 6r20 1f 2f 4f'},
      tags=['cash', 'facing-3bet', 'fold-to-3bet'], **B6)
build('cash_hero_open_calls_3bet_showdown_win', btn=6, hero=4,
      hole=('Qs', 'Qh'), win=4, sd={4: ('Qs', 'Qh'), 6: ('Ad', 'Kd')},
      streets={'preflop': '3f 4r6 5f 6r20 1f 2f 4c',
               'flop': '4x 6b15 4c', 'turn': '4x 6x', 'river': '4x 6b30 4c'},
      board={'flop': 'Qd 7c 2h', 'turn': '9s', 'river': '3d'},
      tags=['cash', 'facing-3bet', 'call-3bet', 'showdown'], **B6)
build('cash_hero_4bet_allin_runout_win', btn=6, hero=5, hole=('As', 'Ad'),
      win=5, sd={5: ('As', 'Ad'), 6: ('Kh', 'Kd')},
      streets={'preflop': '3f 4f 5r6 6r20 1f 2f 5r50 6a 5c'},
      board={'flop': 'Jc 7d 2s', 'turn': '4h', 'river': '9c'},
      tags=['cash', 'all-in', 'runout', '4bet', 'showdown'], **B6)
build('cash_cr_flop_hero_wins', btn=6, hero=2, hole=('8h', '7h'), win=2,
      streets={'preflop': '3f 4f 5f 6r6 1f 2c',
               'flop': '2x 6b6 2r16 6f'},
      board={'flop': '9h 6h 2c'}, tags=['cash', 'check-raise', 'bb-defend'],
      **B6)
build('cash_villain_cr_hero_folds', btn=6, hero=5, hole=('Ac', 'Js'), win=2,
      streets={'preflop': '3f 4f 5r6 6f 1f 2c',
               'flop': '2x 5b5 2r12 5f'},
      board={'flop': 'Ad 7s 5c'}, tags=['cash', 'check-raise-faced', 'cbet'],
      **B6)

# ---------------------------------------------------------------- blinds
build('cash_bb_folds_to_steal', btn=6, hero=2, hole=('9d', '3c'), win=6,
      streets={'preflop': '3f 4f 5f 6r5 1f 2f'},
      tags=['cash', 'bb-steal', 'fold'], **B6)
build('cash_bb_defends_steal_showdown_lose', btn=6, hero=2,
      hole=('Kd', 'Td'), win=6, sd={2: ('Kd', 'Td'), 6: ('As', '7s')},
      streets={'preflop': '3f 4f 5f 6r5 1f 2c',
               'flop': '2x 6x', 'turn': '2x 6b6 2c', 'river': '2x 6x'},
      board={'flop': 'Kc 7d 2d', 'turn': 'Ah', 'river': '9s'},
      tags=['cash', 'bb-steal', 'defend', 'showdown'], **B6)
build('cash_sb_defends_vs_btn', btn=6, hero=1, hole=('Js', 'Ts'), win=1,
      streets={'preflop': '3f 4f 5f 6r5 1c 2f',
               'flop': '1x 6b4 1r10 6f'},
      board={'flop': 'Qs 9d 8s'}, tags=['cash', 'sb', 'check-raise'], **B6)
build('cash_limp_then_fold_to_raise', btn=6, hero=4, hole=('6d', '5d'), win=6,
      streets={'preflop': '3f 4c 5f 6r8 1f 2f 4f'},
      tags=['cash', 'limp', 'limp-fold'], **B6)
build('cash_limp_option_bb_checks_folds_flop', btn=6, hero=2,
      hole=('Qd', '8h'), win=3,
      streets={'preflop': '3c 4f 5f 6f 1c 2x',
               'flop': '1x 2x 3b2 1f 2f'},
      board={'flop': 'Ac 5h 2s'}, tags=['cash', 'limp', 'bb-option'], **B6)
build('cash_sb_completes_limp', btn=6, hero=1, hole=('Ts', '9s'), win=1,
      streets={'preflop': '3f 4f 5f 6f 1c 2x', 'flop': '1b2 2f'},
      board={'flop': 'Tc 6d 3h'}, tags=['cash', 'limp', 'sb'], **B6)

# ---------------------------------------------------------------- postflop responses
build('cash_river_call_showdown_win', btn=6, hero=6, hole=('Ah', 'Qh'),
      win=6, sd={6: ('Ah', 'Qh'), 2: ('Kc', 'Qc')},
      streets={'preflop': '3f 4f 5f 6r5 1f 2c',
               'flop': '2x 6x', 'turn': '2b4 6c', 'river': '2b12 6c'},
      board={'flop': 'Qd 7c 3h', 'turn': '2s', 'river': 'Ac'},
      tags=['cash', 'river-call', 'showdown'], **B6)
build('cash_turn_raise_hero_folds', btn=6, hero=6, hole=('Jd', 'Jc'), win=2,
      streets={'preflop': '3f 4f 5f 6r5 1f 2c',
               'flop': '2x 6b3 2c', 'turn': '2b8 6r20 2r40 6f'},
      board={'flop': 'Ts 6c 2d', 'turn': 'Qh'},
      tags=['cash', 'turn-fold', 'facing-raise'], **B6)
build('cash_hero_raises_flop_bet', btn=6, hero=2, hole=('7s', '7d'), win=2,
      streets={'preflop': '3f 4f 5f 6r5 1f 2c',
               'flop': '2x 6b3 2r10 6f'},
      board={'flop': '7h 4c Kd'}, tags=['cash', 'flop-raise', 'set'], **B6)
build('cash_flush_draw_semi_bluff_allin', btn=6, hero=6, hole=('Ah', '5h'),
      win=2, sd={6: ('Ah', '5h'), 2: ('Ks', 'Kd')},
      streets={'preflop': '3f 4f 5f 6r5 1f 2r16 6c',
               'flop': '2b12 6a 2c'},
      board={'flop': 'Kh 9h 2c', 'turn': '3s', 'river': '8d'},
      stacks={6: 60, 2: 90}, tags=['cash', 'all-in', 'draw', 'showdown'], **B6)
build('cash_postflop_allin_raise_over_bet', btn=6, hero=5, hole=('Ts', 'Js'),
      win=5, sd={5: ('Ts', 'Js'), 2: ('Ac', 'Qd')},
      streets={'preflop': '3f 4f 5r6 6f 1f 2c', 'flop': '2b6 5a 2c'},
      board={'flop': '9d 8c 2s', 'turn': 'Qs', 'river': '7h'},
      stacks={5: 40, 2: 80}, tags=['cash', 'all-in', 'raise-all-in'], **B6)
build('cash_open_shove_preflop', btn=6, hero=4, hole=('Ad', '9d'), win=4,
      streets={'preflop': '3f 4a 5f 6f 1f 2f'}, stacks={4: 14},
      tags=['cash', 'all-in', 'shove'], **B6)
build('cash_call_allin_for_less', btn=6, hero=2, hole=('Kh', 'Qs'), win=6,
      sd={2: ('Kh', 'Qs'), 6: ('Ac', 'Ad')},
      streets={'preflop': '3f 4f 5f 6r10 1f 2a'}, stacks={2: 4},
      board={'flop': 'Jc 3d 8s', 'turn': '2c', 'river': '4h'},
      tags=['cash', 'all-in', 'call-for-less', 'showdown'], **B6)
build('cash_no_hole_cards', btn=6, hero=3, hole=None, win=5,
      streets={'preflop': '3f 4f 5r6 6f 1f 2f'},
      tags=['cash', 'no-hole-cards'], **B6)
build('cash_no_blind_actions_legacy', btn=6, hero=5, hole=('Ac', '2c'),
      win=5, blind_actions=False,
      streets={'preflop': '3f 4f 5r6 6f 1f 2c', 'flop': '2x 5b5 2f'},
      board={'flop': 'Kd 8h 8s'}, tags=['cash', 'legacy', 'no-blind-actions'],
      **B6)
build('cash_dealer_ids_names_sanitize', btn=6, hero=6, hole=('Qc', 'Qd'),
      win=6, ids=True,
      names={2: 'Bob: The Rock', 3: 'Smith, J', 4: '', 5: 'O"Neil\nTwo'},
      streets={'preflop': '3f 4f 5f 6r5 1f 2c', 'flop': '2x 6b3 2f'},
      board={'flop': '4s 4d 9c'}, tags=['cash', 'names', 'dealer'], **B6)

# ---------------------------------------------------------------- chops and side pots
build('cash_chop_two_way_board_plays', btn=6, hero=6, hole=('Ah', '5c'),
      chop=[2, 6], sd={6: ('Ah', '5c'), 2: ('Ad', '4h')},
      streets={'preflop': '3f 4f 5f 6r5 1f 2c',
               'flop': '2x 6x', 'turn': '2x 6x', 'river': '2x 6x'},
      board={'flop': 'As 9c 3d', 'turn': 'Kd', 'river': 'Qc'},
      tags=['cash', 'chop', 'showdown'], **B6)
build('cash_chop_three_way_side_pot', btn=6, hero=3, hole=('Ks', 'Qs'),
      chop=[3, 5], shares=lambda pot: {3: 61.5, 5: pot - 61.5},
      sd={3: ('Ks', 'Qs'), 5: ('Kh', 'Qh'), 4: ('2c', '2d')},
      streets={'preflop': '3a 4a 5a 6f 1f 2f'}, stacks={3: 40, 4: 20, 5: 40},
      board={'flop': 'Ac 8d 3h', 'turn': 'Jc', 'river': 'Tc'},
      tags=['cash', 'chop', 'side-pot', 'all-in', 'multiway'], **B6)
build('cash_side_pot_short_stack_wins_main', btn=6, hero=4, hole=('Ac', 'Ah'),
      win=4, sd={4: ('Ac', 'Ah'), 5: ('Kd', 'Kc'), 6: ('9s', '9h')},
      streets={'preflop': '3f 4r6 5r18 6a 1f 2f 4a 5c'},
      stacks={4: 30, 5: 90, 6: 50},
      board={'flop': '2c 7d 4s', 'turn': '8h', 'river': 'Jd'},
      tags=['cash', 'side-pot', 'all-in', 'multiway', 'showdown'], **B6)

# ---------------------------------------------------------------- flop texture / strength sweep
SWEEP = [
    ('paired_top', ('Ks', 'Qh'), 'Kc Kd 5s'),
    ('monotone_flushdraw', ('Ah', 'Th'), 'Kh 8h 3h'),
    ('dry_air', ('Qc', 'Jd'), 'Ks 7d 2c'),
    ('wet_oesd', ('9s', '8s'), 'Td 7h 2c'),
    ('wet_gutshot', ('Qd', 'Jc'), 'Ts 8h 2c'),
    ('overcards', ('Ac', 'Kd'), 'Jd 7h 3c'),
    ('weak_pair', ('8c', '7c'), 'Ks 8d 2h'),
    ('underpair', ('5d', '5c'), 'Qs 9d 2h'),
    ('overpair', ('Jd', 'Jc'), '8s 7d 2h'),
    ('wheel_draw', ('4c', '3d'), 'As 2h 9c'),
    ('two_tone_air', ('Kc', 'Td'), '9s 4s 2d'),
    ('ten_notation', ('10h', 'Jh'), '10s 5d 2c'),
]
for name, hole, flop in SWEEP:
    build('sweep_' + name, btn=6, hero=5, hole=hole, win=5,
          streets={'preflop': '3f 4f 5r6 6f 1f 2c', 'flop': '2x 5b4 2f'},
          board={'flop': flop}, tags=['cash', 'texture-strength'], **B6)

# ---------------------------------------------------------------- decimal blinds
D6 = dict(sid='cash_decimal', seats=[1, 2, 3, 4, 5, 6])
build('dec_walk', btn=6, hero=2, hole=('Th', '7h'), win=2,
      streets={'preflop': '3f 4f 5f 6f 1f'}, tags=['cash', 'decimal', 'walk'],
      **D6)
build('dec_open_cbet_win', btn=6, hero=6, hole=('Ad', 'Td'), win=6,
      streets={'preflop': '3f 4f 5f 6r5 1f 2c', 'flop': '2x 6b3 2f'},
      board={'flop': 'Tc 6s 2h'}, tags=['cash', 'decimal', 'cbet', 'steal'],
      **D6)
build('dec_3bet_pot_fold', btn=6, hero=4, hole=('Kh', 'Kd'), win=6,
      streets={'preflop': '3f 4r5 5f 6r17 1f 2f 4f'},
      tags=['cash', 'decimal', '3bet', 'fold-to-3bet'], **D6)
build('dec_odd_amounts_showdown', btn=6, hero=5, hole=('Jc', 'Td'), win=2,
      sd={5: ('Jc', 'Td'), 2: ('Jh', 'Ad')},
      streets={'preflop': '3f 4f 5r5 6f 1f 2c',
               'flop': '2x 5b2.2 2c', 'turn': '2x 5x', 'river': '2b6.7 5c'},
      board={'flop': 'Js 6d 2c', 'turn': '4h', 'river': '9s'},
      tags=['cash', 'decimal', 'showdown'], **D6)

# ---------------------------------------------------------------- 9-max, empty seats
# btn=9: 1=SB 2=BB 3=UTG 4=UTG+1 5=UTG+2 6=LJ 7=HJ 8=CO 9=BTN
N9 = dict(sid='cash_9max', seats=list(range(1, 10)))
build('nine_utg2_open_fold_to_3bet', btn=9, hero=5, hole=('Ad', 'Js'), win=1,
      streets={'preflop': '3f 4f 5r15 6f 7f 8f 9f 1r50 2f 5f'},
      tags=['cash', '9max', 'fold-to-3bet'], **N9)
build('nine_lj_multiway_call_showdown', btn=9, hero=6, hole=('7s', '6s'),
      win=6, sd={6: ('7s', '6s'), 5: ('Ac', 'Kc')},
      streets={'preflop': '3f 4f 5r15 6c 7f 8f 9c 1f 2f',
               'flop': '5b15 6c 9f', 'turn': '5x 6b30 5c',
               'river': '5x 6b60 5c'},
      board={'flop': '8s 5d 2c', 'turn': '4h', 'river': '3s'},
      tags=['cash', '9max', 'multiway', 'showdown'], **N9)
build('nine_utg_open_win', btn=9, hero=3, hole=('Ks', 'Kd'), win=3,
      streets={'preflop': '3r15 4f 5f 6f 7f 8f 9f 1f 2f'},
      tags=['cash', '9max', 'ep'], **N9)
build('nine_empty_seats_6_of_9', sid='cash_9max', seats=[2, 3, 5, 6, 8, 9],
      btn=6, hero=5, hole=('Ah', 'Jh'), win=5,
      streets={'preflop': '2f 3f 5r15 6f 8f 9c', 'flop': '9x 5b12 9f'},
      board={'flop': 'Jd 7c 3s'}, tags=['cash', '9max', 'empty-seats'])

# ---------------------------------------------------------------- short-handed / heads-up
build('hu_btn_open_cbet_win', sid='cash_hu', seats=[2, 5], btn=2, hero=2,
      hole=('Kd', '9d'), win=2,
      streets={'preflop': '2r6 5c', 'flop': '5x 2b6 5f'},
      board={'flop': 'Kc 6s 2d'}, tags=['cash', 'heads-up', 'cbet'])
build('hu_sb_folds_bb_wins', sid='cash_hu', seats=[2, 5], btn=2, hero=5,
      hole=('Qc', '3d'), win=5, streets={'preflop': '2f'},
      tags=['cash', 'heads-up', 'walk'])
build('hu_bb_defends_showdown_lose', sid='cash_hu', seats=[2, 5], btn=5,
      hero=2, hole=('Ts', 'Td'), win=5, sd={2: ('Ts', 'Td'), 5: ('Ah', 'Kh')},
      streets={'preflop': '5r6 2c', 'flop': '2x 5x', 'turn': '2x 5b8 2c',
               'river': '2x 5x'},
      board={'flop': 'Kd 7c 2s', 'turn': '9h', 'river': 'Kc'},
      tags=['cash', 'heads-up', 'showdown'])
# sorted seats 1,3,4,7,9 btn=4: 7=SB 9=BB 1=UTG 3=CO 4=BTN
build('gaps_5handed_co_open', sid='cash_gaps', seats=[1, 3, 4, 7, 9], btn=4,
      hero=3, hole=('Ac', 'Qc'), win=3,
      streets={'preflop': '1f 3r6 4f 7f 9f'},
      tags=['cash', 'empty-seats', 'steal'])
# sorted 3,4,7,9 btn=7: 9=SB 3=BB 4=UTG 7=BTN
build('gaps_4handed_3bet_pot', sid='cash_gaps', seats=[3, 4, 7, 9], btn=7,
      hero=7, hole=('Jh', 'Js'), win=7,
      streets={'preflop': '4r6 7r20 9f 3f 4c', 'flop': '4x 7b14 4f'},
      board={'flop': '6d 3c 2h'}, tags=['cash', 'empty-seats', '3bet'])

# ---------------------------------------------------------------- tournaments
# btn=8: 1=SB 2=BB 3=UTG 4=UTG+1 5=UTG+2 6=HJ 7=CO 8=BTN
T8 = dict(sid='tourn_8max', seats=list(range(1, 9)))
build('tourn_open_shove_bb_calls_win', btn=8, hero=8, hole=('Ac', '8c'),
      win=8, sd={8: ('Ac', '8c'), 2: ('Kd', 'Jd')}, stacks={8: 11, 2: 14},
      streets={'preflop': '3f 4f 5f 6f 7f 8a 1f 2c'},
      board={'flop': '8h 5s 2c', 'turn': 'Jc', 'river': '3d'},
      tags=['tournament', 'all-in', 'shove', 'showdown'], **T8)
build('tourn_3bet_shove_opener_folds', btn=8, hero=7, hole=('Ah', 'Qd'),
      win=7, stacks={7: 25, 4: 40},
      streets={'preflop': '3f 4r5 5f 6f 7a 8f 1f 2f 4f'},
      tags=['tournament', '3bet', 'shove'], **T8)
build('tourn_hero_open_folds_to_shove', btn=8, hero=6, hole=('Ts', '9s'),
      win=2, stacks={6: 30, 2: 22},
      streets={'preflop': '3f 4f 5f 6r5 7f 8f 1f 2a 6f'},
      tags=['tournament', 'facing-3bet', 'fold-to-3bet'], **T8)
build('tourn_cbet_barrel_showdown_win', btn=8, hero=7, hole=('Ad', 'Kh'),
      win=7, sd={7: ('Ad', 'Kh'), 8: ('Qc', 'Qd')}, stacks={7: 60, 8: 70},
      streets={'preflop': '3f 4f 5f 6f 7r5 8c 1f 2f',
               'flop': '7b4 8c', 'turn': '7b10 8c', 'river': '7b24 8c'},
      board={'flop': 'Ac 9d 4s', 'turn': '2h', 'river': 'Ks'},
      tags=['tournament', 'cbet', 'barrel', 'showdown'], **T8)
build('tourn_chop_all_in', btn=8, hero=1, hole=('Ah', 'Kd'),
      chop=[1, 8], sd={1: ('Ah', 'Kd'), 8: ('Ac', 'Ks')}, stacks={1: 20, 8: 20},
      streets={'preflop': '3f 4f 5f 6f 7f 8a 1c 2f'},
      board={'flop': '9c 6d 2h', 'turn': '3s', 'river': 'Jd'},
      tags=['tournament', 'chop', 'all-in', 'showdown'], **T8)
build('tourn_bb_defend_3bet_pot', btn=8, hero=2, hole=('Qs', 'Qc'), win=2,
      stacks={2: 45, 7: 45},
      streets={'preflop': '3f 4f 5f 6f 7r5 8f 1f 2r16 7c', 'flop': '2b8 7f'},
      board={'flop': 'Jh 6s 3d'}, tags=['tournament', '3bet', 'bb-defend'],
      **T8)

# btn=6: 1=SB 2=BB 3=UTG 4=HJ 5=CO 6=BTN
TB = dict(sid='tourn_bbante', seats=[1, 2, 3, 4, 5, 6])
build('bbante_walk', btn=6, hero=2, hole=('7d', '7s'), win=2,
      streets={'preflop': '3f 4f 5f 6f 1f'},
      tags=['tournament', 'bb-ante', 'walk'], **TB)
build('bbante_open_cbet', btn=6, hero=5, hole=('Ac', 'Th'), win=5, stack=40,
      streets={'preflop': '3f 4f 5r5 6f 1f 2c', 'flop': '2x 5b3 2f'},
      board={'flop': 'Th 6c 2s'},
      tags=['tournament', 'bb-ante', 'cbet', 'steal'], **TB)
build('bbante_river_showdown_lose', btn=6, hero=2, hole=('9h', '8h'), win=6,
      sd={2: ('9h', '8h'), 6: ('Ad', 'Ac')}, stack=60,
      streets={'preflop': '3f 4f 5f 6r5 1f 2c',
               'flop': '2x 6b4 2c', 'turn': '2x 6x', 'river': '2b8 6r24 2c'},
      board={'flop': '9d 4h 2c', 'turn': '6s', 'river': 'Jh'},
      tags=['tournament', 'bb-ante', 'showdown'], **TB)
build('bbante_chop', btn=6, hero=3, hole=('Qh', 'Jd'), chop=[3, 4], stack=50,
      sd={3: ('Qh', 'Jd'), 4: ('Qs', 'Jc')},
      streets={'preflop': '3r5 4c 5f 6f 1f 2f',
               'flop': '3x 4x', 'turn': '3x 4x', 'river': '3x 4x'},
      board={'flop': 'As 8d 3c', 'turn': 'Kh', 'river': 'Td'},
      tags=['tournament', 'bb-ante', 'chop', 'showdown'], **TB)
build('cash_bbante_3bet_pot', sid='cash_bbante', seats=[1, 2, 3, 4, 5, 6],
      btn=6, hero=6, hole=('Kc', 'Qc'), win=6,
      streets={'preflop': '3f 4r6 5f 6r20 1f 2f 4f'},
      tags=['cash', 'bb-ante', '3bet'])

# ---------------------------------------------------------------- completeness levels
build('level_fold_tick', completeness='fold_tick', btn=6, hero=3,
      hole=('8d', '3s'), win=None, streets={'preflop': '3f'},
      blind_actions=False, tags=['cash', 'completeness-fold_tick'], **B6)
build('level_preflop', completeness='preflop', btn=6, hero=5, hole=('Ah', '9h'),
      win=5, streets={'preflop': '3f 4f 5r6 6f 1f 2f'},
      tags=['cash', 'completeness-preflop'], **B6)
build('level_flagged_stub', completeness='flagged', btn=6, hero=4, hole=None,
      win=None, streets={}, blind_actions=False,
      extra={'flag': {'tags': ['bluff', 'review'], 'note': 'ran into a set'}},
      tags=['cash', 'completeness-flagged'], **B6)
build('level_reconstructed', completeness='reconstructed', btn=6, hero=5,
      hole=('Js', 'Jd'), win=5,
      streets={'preflop': '3f 4f 5r6 6f 1f 2c', 'flop': '2x 5b5 2f'},
      board={'flop': '7s 4d 2c'}, extra={'flag': {'tags': ['recalled']}},
      tags=['cash', 'completeness-reconstructed'], **B6)
build('level_full_explicit', completeness='full', btn=6, hero=5,
      hole=('Js', 'Jd'), win=5,
      streets={'preflop': '3f 4f 5r6 6f 1f 2c', 'flop': '2x 5b5 2f'},
      board={'flop': '7s 4d 2c'}, tags=['cash', 'completeness-full'], **B6)

# ---------------------------------------------------------------- scouted
build('scouted_hero_folds_opps_logged', scouted=True, btn=6, hero=3,
      hole=('7h', '2c'), win=6,
      streets={'preflop': '3f 4r6 5c 6r20 1f 2f 4f 5f'},
      tags=['cash', 'scouted'], **B6)
build('scouted_preflop_completeness', scouted=True, completeness='preflop',
      btn=6, hero=4, hole=('Td', '4c'), win=5,
      streets={'preflop': '3f 4f 5r6 6f 1f 2f'},
      tags=['cash', 'scouted', 'completeness-preflop'], **B6)


def dead_blind_hands():
    """Hands as the app saves them since dead button / dead SB support: NO
    blind-post actions, plus the real blinds (bbSeat / sbSeat / smallBlindDead).
    Hand-written (not simulated) so the stored fields are exactly what the app
    writes. Seat 3 is empty in both."""
    names = {'1': 'Alice', '2': 'Bob', '4': 'Dave', '5': 'Erin', '6': 'Frank'}
    base = next(h for h in HANDS if h['id'] == 'cash_walk_hero_bb')

    def act(i, seat, a, pos, btn, stack, amount=None):
        return {'player': seat, 'action': a, 'street': 'preflop',
                'timestamp': '2025-03-01T20:00:%02dZ' % (7 * (i + 1)),
                'buttonPosition': btn, 'playerName': names[str(seat)],
                'playerId': None, 'isCurrentUser': seat == 1,
                'playerPosition': pos, 'playerStack': stack, 'amount': amount}

    def make(hid, number, btn, hero_pos, acts, extra, win, pot, tags):
        d = dict(base)
        d.update({
            'id': hid, 'handNumber': number, 'buttonPosition': btn,
            'heroPositionName': hero_pos, 'heroSeatNumber': 1,
            'ourHoleCards': {'card1': '9' + SUITS['s'], 'card2': '9' + SUITS['h']},
            'winnerId': win, 'potAmount': pot, 'preflopPot': pot,
            'playerNames': names, 'playerIds': {k: None for k in names},
            'actions': acts, '_tags': tags,
            'endTime': '2025-03-01T20:01:09Z'})
        d.update(extra)
        return d

    # Dead SB walk: BTN2 live, SB seat 3 empty, BB4 never acts.
    walk = [act(0, 5, 'fold', 'UTG', 2, 200), act(1, 6, 'fold', 'HJ', 2, 200),
            act(2, 1, 'fold', 'CO', 2, 200), act(3, 2, 'fold', 'BTN', 2, 200)]
    # Dead button: seat 3 empty holds the button; SB4, BB5; CO2 steals.
    steal = [act(0, 6, 'fold', 'UTG', 3, 200), act(1, 1, 'fold', 'HJ', 3, 200),
             act(2, 2, 'raise', 'CO', 3, 200, 6),
             act(3, 4, 'fold', 'SB', 3, 199), act(4, 5, 'fold', 'BB', 3, 198)]
    HANDS.append(make('cash_dead_sb_walk', 21, 2, 'CO', walk,
                      {'bbSeat': 4, 'smallBlindDead': True}, 4, 2,
                      ['cash', 'walk', 'dead-sb']))
    HANDS.append(make('cash_dead_button_steal', 22, 3, 'HJ', steal,
                      {'bbSeat': 5, 'sbSeat': 4}, 2, 9,
                      ['cash', 'steal', 'dead-button']))


dead_blind_hands()


def main():
    hands_dir = os.path.join(HERE, 'hands')
    os.makedirs(hands_dir, exist_ok=True)
    os.makedirs(os.path.join(HERE, 'sessions'), exist_ok=True)
    for f in os.listdir(hands_dir):
        os.remove(os.path.join(hands_dir, f))
    ids = set()
    for h in HANDS:
        assert h['id'] not in ids, h['id']
        ids.add(h['id'])
        with open(os.path.join(hands_dir, h['id'] + '.json'), 'w') as fh:
            json.dump(h, fh, indent=1, ensure_ascii=False)
            fh.write('\n')
    for sid, s in SESSIONS.items():
        with open(os.path.join(HERE, 'sessions', sid + '.json'), 'w') as fh:
            json.dump(s, fh, indent=1, ensure_ascii=False)
            fh.write('\n')
    print('hands:', len(HANDS), 'sessions:', len(SESSIONS))


if __name__ == '__main__':
    main()
