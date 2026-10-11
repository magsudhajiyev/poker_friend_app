# 2026-07-20 — Preflop 3-Bet Detection Off-by-One Fix + Consolidation

**Status**: Fixed & verified (110/110 tests pass)
**Branch**: main

---

## The bug

A preflop **3-bet is the 2nd voluntary raise**. Blind posts are forced bets
(not an open), so counting *voluntary* raises: the 1st voluntary raise is the
open ("2-bet"), and the next raise (the first re-raise) is the **3-bet**.

The canonical `StatsCalculator.didPlayerThreeBet` counted a 3-bet as the **3rd**
voluntary raise — which is actually a **4-bet**. This under-counted 3-bets and
mislabeled real 3-bets (a re-raise over an open) as "just a raise." The sibling
detectors shared the same off-by-one:
- `hadThreeBetOpportunity` waited for 2 prior raises (should be 1 — the open)
- `facedThreeBet` / `didFoldTo3Bet` used `raiseCount >= 3` (should be `>= 2`)

The app's own help text was already correct ("re-raise an opponent's open raise
preflop"), and CLAUDE.md codified the wrong rule ("3rd raise preflop").

## Divergence found (3 implementations, 2 disagreeing)

| Location | Rule | Correct? | all-in? | Fed |
|---|---|---|---|---|
| `StatsCalculator.didPlayerThreeBet` | 3rd raise | ❌ | ✅ | opponent stats + hero (firebase_service) |
| `user_stats_service._didPlayerThreeBetInHand` | raise-after-opp-raise | ✅ | ❌ | hero user_stats |
| `stats_verification_service._didPlayerThreeBet` | raise-after-opp-raise | ✅ | ❌ | audit |

So hero 3-bet was computed two contradictory ways; opponent 3-bet used only the
wrong one.

## The fix

Correct definition: **3-bet = 2nd voluntary raise**. The open = first voluntary
raise (blinds and limps/calls before it are not the open).

1. **`lib/services/stats_calculator.dart`** — rewrote the 4 detectors:
   - `didPlayerThreeBet`: true when the player makes the **2nd** voluntary raise
     (`raiseCount == 2`).
   - `hadThreeBetOpportunity`: fires when the player acts with exactly **1**
     prior voluntary raise (the open). Does not count 4-bet spots.
   - `facedThreeBet` / `didFoldTo3Bet`: opener faces the **2nd** voluntary raise
     (`raiseCount >= 2`).
   - Blinds stay excluded via `isRaiseAction`; all-in still counts as a raise.
2. **Consolidation** — deleted the two private copies
   (`user_stats_service._didPlayerThreeBetInHand`,
   `stats_verification_service._didPlayerThreeBet`) and pointed both at the
   canonical `StatsCalculator.didPlayerThreeBet` (added imports; cast the
   verification service's `List<dynamic>` actions). `firebase_service` already
   used the canonical methods, so no change there.
3. **Tests** — `test/services/stats_calculator_test.dart`: rewrote the whole
   3-Bet Detection + Fold-to-3-Bet groups and fixed 4 stale edge-case tests to
   the correct definition (re-raise over open = 3-bet; 3rd raise = 4-bet;
   opportunity exists after the open; all-in-as-3-bet; limp→open→3-bet). 110/110
   pass.
4. **Docs** — corrected CLAUDE.md in 4 places (metric table, 3-Bet Detection
   section pseudocode, Known Bug Patterns).

## Decisions

- **Fix forward** — no migration; the DB will be cleared. Existing
  `threeBetCount` / `facing3BetCount` / `fold3betCount` counters stay as-is
  until the clear.
- **Postflop 3-bet (re-raise) tracking** = deferred to a separate follow-up.
  Postflop a 3-bet has a different structure (bet=1st, raise=2nd, re-raise=3-bet,
  no blind shift) and would be a new stat + counters + UI, not a bug fix.

## Gotcha during implementation

Mid-work the entire working tree got reverted to the last commit — likely a
stray `git restore`/`checkout` from a background test agent's environment. It was
caught (old tests were passing against reverted production code) and all 5 files
were re-applied from scratch. Lesson: commit stat-logic fixes promptly; don't run
long-lived background agents that may touch git while uncommitted work sits in the
tree.

## Files

- `lib/services/stats_calculator.dart` — 4 detectors (canonical fix)
- `lib/services/user_stats_service.dart` — deleted private copy, call canonical
- `lib/services/stats_verification_service.dart` — deleted private copy, call canonical
- `test/services/stats_calculator_test.dart` — rewrote 3-bet groups + edge cases
- `CLAUDE.md` — corrected the documented definition
