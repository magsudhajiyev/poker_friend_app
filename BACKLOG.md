# Product Backlog

Triaged from founder notes + note-app checkmarks (2026-07-06). Stable IDs:
B# bug, U# UX, F# feature, M# monetization/social, G# growth.
Status: ✅ done (checked in notes), 🔎 marked done — verify in code,
⬜ open, ❓ open but needs codebase check (founder may have fixed and
forgotten to tick).

## P0 — Open correctness bugs (attack order)

| ID | Item | Status |
|----|------|--------|
| B14 | Positional stats: FIXED 2026-07-06 — position maps added to UserStats model + atomic delta writes (positionUpdatePaths) + hero call site; unit tests in user_stats_position_test.dart. Note: counters start from this fix — historical hands need the migration path to backfill | 🔎 verify on device |
| B11 | Side pots: FIXED 2026-07-06 — multi-pot save now persists EVERY pot's winner (was: only first pot's winner → side-pot winner lost from details). New isSplitPot flag (model+firebase+local DB v16) labels separate-pot winners; details view lists all. Heads-up 'no spurious side pot' confirmed already-correct (display filters single-eligible overage). Tests: multi_pot_winner_aggregation_test.dart + side_pot HU regression | 🔎 verify on device |
| B10 | Bust after all-in: implemented for DEALER mode (dealer_table_screen.dart:1332). Own-logging bust handling unverified | ❓ verify own logging |
| B3 | Manage players → blinds: code-verified CLEAN — no blind writes anywhere in seat management/remove flows. Likely already fixed | 🔎 confirm on device |
| B7 | Replay duplicate "You": fix present — session_analytics_screen.dart:1175 uses per-hand heroSeatNumber (ourSeat: null). Likely already fixed | 🔎 confirm on device |
| B8 | Vacated UTG: first-to-act recomputed from ACTIVE players each hand (poker_game_state.dart:280,327). Likely already fixed | 🔎 confirm on device |
| B13 | Skip-hand stacks: implemented — blind deducted, contributions restored (poker_hand_screen.dart:4266) | 🔎 confirm on device |

## Done per notes — spot-check before closing (blinds cluster was "Main Bugs")

| ID | Item | Status |
|----|------|--------|
| B1 | Blinds not keeping up after updating them | 🔎 |
| B2 | Session details blinds out of sync | 🔎 |
| B4 | "Blinds are not stable — TEST LIVE" umbrella | 🔎 |
| B5 | Blind level-up logic | 🔎 |
| B6 | Return blinds after wrong/voided hand | 🔎 |
| B9 | All-in player no longer gets action turns | 🔎 |
| B15 | Action take-back restores stacks/pot/street | 🔎 |
| U2 | Ask winner cards first; showdown card entry for everyone | 🔎 |
| U3 | Re-seat flow after table move | 🔎 |
| U6 | Stack updates with +/- deltas | 🔎 |
| U7 | Next-hand animation | 🔎 |
| — | Side pot logic implemented (own logging) | 🔎 |
| F9 | Separate backend for AI engine | 🔎 |

## P1 — Open UX friction

| ID | Item | Status |
|----|------|--------|
| U1 | Leave-confirmation skip: DONE in code — isIndividualSession branch (poker_hand_screen.dart:1252) | ✅ code-verified |
| U5 | Chop logic: DONE incl. dealer mode (dealer_table_screen.dart:1187) | ✅ code-verified |
| U4 | Dealer voice grammar: commands start with seat name; strict speech→action grammar | ⬜ |
| U8 | Lazy load: DONE 2026-07-06 — session history renders a growing window (LazyPagination helper, 15/page, per-tab); scroll-to-bottom reveals next page. Fixed latent two-tabs-one-ScrollController fragility (now per-tab controllers). Tests: lazy_pagination_test.dart. TODO: apply same to session_hands + opponents lists | 🔎 verify on device |

## P2 — Open product features

| ID | Item |
|----|------|
| F1 | Drill score: decision-making score over time (extends drill grades) |
| F2 | Stack analytics: table-avg chip input, stack/avg ratio, BB-per-hour growth |
| F3 | After-session notes |
| F4 | Hand of the session |
| F5 | Hand notes & starring: star UI exists (hand_actions_screen.dart:65); notes editing only in player_session — add notes editor to hand details |
| F6 | Session highlight-hands analyzer shared with participants |
| F7 | Decision-tree generation from action patterns, position-adjusted |
| F8 | Opponent simulator: tree × style → "how would they play here" |
| F10 | AI jokes in hand analysis |
| F11 | Spotify-Wrapped-style throwbacks |
| F12 | Train with "hungry horse data" (meaning TBC with founder) |

## P3 — Social & monetization

| ID | Item |
|----|------|
| M1 | Pay to see own data (consider: free recent + paid deep history, not hostage UX) |
| M2 | Voice-memo hand feed; pros analyze + revenue share |
| M3 | Journey feed (hands + session photos) |
| M4 | PF Points internal ranking |

## P4 — Marketing

| ID | Item |
|----|------|
| G1 | YouTube channel (founder-flagged !!) |
| G2 | Storytelling video on website |

## Open questions for founder
1. B8 wording: "UTG seat opens" = seat becomes vacant, correct?
2. U5 chop logic: what's missing beyond own-logging chopped pots — dealer mode?
3. F12 "hungry horse data": what is it?
4. M1: confirm the free/paid split appetite before design.
