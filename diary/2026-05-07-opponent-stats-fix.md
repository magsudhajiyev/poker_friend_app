# Stats Calculation Fix (User + Opponent) — 2026-05-07

## Bugs Found & Fixed

### Bug 1: 3-Bet Detection Wrong (StatsCalculator)
**Problem**: All 4 methods (`didPlayerThreeBet`, `hadThreeBetOpportunity`, `facedThreeBet`, `didFoldTo3Bet`) treated the 2nd raise preflop as a 3-bet. In poker, a 3-bet is the **3rd raise** (open=1st, re-raise=2nd, 3-bet=3rd). Blinds don't count as raises.

**Fix**: Changed from boolean flags (`sawOpponentRaise`) to counting total `raiseCount`. A 3-bet requires `raiseCount == 3`. Similarly, 3-bet opportunity requires exactly 2 total raises already happened.

**Files**: `lib/services/stats_calculator.dart` (lines 36-154)

### Bug 2: 3-Bet Opportunity Undercounted (StatsCalculator)
**Problem**: `hadThreeBetOpportunity` only counted raises by **other** players. This missed the common scenario where a player opens (1st raise), gets re-raised (2nd raise), and now has a 3-bet opportunity. The code required 2 raises by others, but the player's own open counts as one of the 2 raises.

**Fix**: Changed to count **total** raises (by anyone). Player has 3-bet opportunity when `totalRaiseCount == 2` at the time they act. Uses `== 2` not `>= 2` to exclude 4-bet opportunities.

**Files**: `lib/services/stats_calculator.dart` (`hadThreeBetOpportunity`)

### Bug 3: Opponent VPIP Overcounted (FirebaseService)
**Problem**: `_updateOpponentStatsFromHand` incremented `vpipDelta` for every `call`/`bet`/`raise` on **every street**, not just preflop. An opponent who called preflop and bet flop got vpipDelta=2. VPIP should be 0 or 1 per hand (preflop only).

**Fix**: Replaced per-action VPIP/PFR increment with per-hand boolean flags (`opponentDidVpip`, `opponentDidPfr`), applied after the action loop. Matches how user stats already worked.

**Files**: `lib/services/firebase_service.dart` (lines 1090-1200)

### Bug 4: `all-in` Action Ignored (FirebaseService)
**Problem**: The per-action switch statement had no `case 'all-in':` branch. When an opponent went all-in, nothing was counted — no raise, aggression, VPIP, or PFR.

**Fix**: Added `case 'all-in':` that mirrors `raise` behavior. Also fixed in `_updateUserStatsFromHand` where `all-in` was missing from VPIP/PFR/didPlay conditions.

**Files**: `lib/services/firebase_service.dart` (both opponent and user stat methods)

### Bug 5: Walk Detection for Opponents (FirebaseService + StatsCalculator)
**Problem**: In walk hands, the BB never acts (hand ends before them), so BB has no action in the action list. This caused:
- `isBigBlind()` returned false (no matching action found)
- BB opponent not added to `handParticipants` (missed handsPlayed increment)
- Walk count not incremented for BB opponent

**Fix**: Added `findBigBlindSeat()` method to StatsCalculator that finds BB from blind posting actions. Updated walk detection in `_updateOpponentStatsFromHand` to use it, initializing deltas and adding BB to handParticipants even when they have no actions.

**Files**: `lib/services/stats_calculator.dart`, `lib/services/firebase_service.dart`

## Scope
All fixes apply to **both user and opponent stats** — both code paths use the same `StatsCalculator` methods.

## Label Change
- Renamed "Aggression Freq" → "Aggression %" across all 7 locales (EN/DE/ES/FR/PL/PT/RU)

## Verification (12 hands across 3 sessions)
Hand-by-hand audit against Firestore data for "New Opp2":

| Stat | Expected | Stored | Match |
|------|----------|--------|-------|
| handsPlayed | 12 | 12 | YES |
| vpipCount | 9 | 9 | YES |
| pfrCount | 6 | 6 | YES |
| threeBetCount | 1 | 1 | YES |
| threeBetOpportunity | 3 | 3 | YES |
| facing3BetCount | 2 | 2 | YES |
| fold3betCount | 1 | 1 | YES |
| stealCount | 1 | 1 | YES |
| stealOpportunity | 3 | 3 | YES |
| cbetCount | 1 | 1 | YES |
| cbetOpportunity | 1 | 1 | YES |
| checkRaiseFlopCount | 1 | 1 | YES |
| checkRaiseFlopOpportunity | 1 | 1 | YES |
| foldCount | 5 | 5 | YES |
| showdownCount | 1 | 1 | YES |

## Key Definitions (for future reference)
- **3-bet** = the 3rd raise preflop. Open=1st, re-raise=2nd, 3-bet=3rd. Blinds don't count.
- **3-bet opportunity** = exactly 2 raises already happened (total, by anyone) when player acts. Does NOT include 4-bet opportunities (3+ raises).
- **Facing 3-bet** = player raised earlier, then the 3rd raise happened by someone else.
- **Fold to 3-bet** = facing a 3-bet and folded. Can happen to opener OR 2nd raiser.
- **VPIP** = per-hand boolean (0 or 1), preflop voluntary actions only. Blinds excluded.

## Tests Updated
- `test/services/stats_calculator_test.dart` — rewritten 3-bet tests to use correct definition (3rd raise)
- `test/fixtures/mock_hand_actions.dart` — updated `threeBetPot`, `heroFaces3Bet`, `heroFoldsTo3Bet`, `heroCallsTo3Bet` fixtures to include 3 raises
- Added `findBigBlindSeat` tests
- All tests pass
