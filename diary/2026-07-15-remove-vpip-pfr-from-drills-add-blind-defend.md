# Remove VPIP/PFR from Training Drills, Add Blind Defend Stat

**Date**: 2026-07-15
**Branch**: design_v2
**Status**: Complete — all tests passing

---

## Overview

Replaced all VPIP/PFR dependencies in the training drill system with opportunity-based stats that are correctly tracked. VPIP/PFR are structurally unreliable for opponents because we only track opponents in hands where the hero is involved — unobserved folds are never counted, inflating VPIP and making PFR meaningless for opponent profiling. VPIP/PFR were already removed from the opponent display UI (see `diary/2026-04-26`) but were still used in the drill grader's exploit tips, the engine's villain simulation, and the profiler.

This change introduces a new **blind defend** stat to the stats infrastructure and replaces all drill-system VPIP/PFR logic with opportunity-based stats: steal%, aggression%, showdown%, blind defend%, c-bet%, and check-raise flop%.

---

## What Changed

### Phase 1: Blind Defend Stat — Stats Infrastructure

**Definition**: When a player is in BB or SB and faces at least one open-raise preflop, did they call/raise (defend) rather than fold?

#### `lib/services/stats_calculator.dart`
Added 4 new static methods mirroring the existing `isBigBlind`/`findBigBlindSeat` pattern:
- `isSmallBlind(actions, seatNumber)` — checks for `'small blind'` action type or `playerPosition == 'SB'`
- `findSmallBlindSeat(actions)` — returns the SB seat number from blind posts
- `hadBlindDefendOpportunity(actions, seatNumber)` — player is BB/SB, not a walk, at least one raise happened preflop
- `didBlindDefend(actions, seatNumber)` — player called/raised/all-in preflop (did not fold) when facing a raise

#### `lib/models/opponent_stats.dart` + `lib/models/user_stats.dart`
Added `blindDefendCount` (int, default 0) and `blindDefendOpportunity` (int, default 0) to both models. Updated: field declarations, constructor, `fromFirestore`, `fromMap`, `toFirestore`, `toMap`, `copyWith`, `incrementWith` (with delta params). Added `blindDefendPercentage` getter and `hasDataFor('blindDefend')` check.

#### `lib/services/opponent_stats_service.dart` + `lib/services/user_stats_service.dart`
Added `blindDefendCountDelta` and `blindDefendOpportunityDelta` parameters to `updateStatsAtomic()` (and `updateStatsIncremental()` for opponents).

#### `lib/services/firebase_service.dart`
Wired blind defend detection in both `_updateOpponentStatsFromHand()` and `_updateUserStatsFromHand()`. Detection block:
```dart
if (StatsCalculator.hadBlindDefendOpportunity(actions, seat)) {
  deltas['blindDefendOpportunityDelta'] = 1;
  if (StatsCalculator.didBlindDefend(actions, seat)) {
    deltas['blindDefendCountDelta'] = 1;
  }
}
```

**Note**: `_updateAllPlayerStatsFromHand()` (dealer mode) was NOT updated — consistent with existing pattern where dealer mode only tracks basic stats.

---

### Phase 2: DrillVillainProfile Restructure

#### `lib/models/drill_models.dart`

**Removed** fields: `vpip`, `pfr`

**Added** fields: `steal`, `cbet`, `blindDefend`, `showdown`, `checkRaiseFlop` (all `double`, 0–100%)

**Added format-aware priors** — two static constants selected by `anteMode`:

| Stat | Cash (8-9max) | MTT (8-9max + antes) | Why Different |
|---|---|---|---|
| steal | 28% | 38% | Antes add ~1BB dead money → wider steals |
| blindDefend | 35% | 45% | BB gets better price vs steal when antes swell the pot |
| threeBet | 6% | 8% | MTT 3-bet more aggressively for fold equity + antes |
| fold3bet | 58% | 52% | MTT calls 3-bets slightly wider (antes improve pot odds) |
| aggression | 45% | 52% | Shorter effective stacks → more jam/fold |
| cbet | 65% | 62% | MTT slightly less c-bet (SPR lower) |
| showdown | 28% | 26% | More preflop all-ins in MTT |
| checkRaiseFlop | 8% | 9% | MTT defenders check-raise more (lower SPR) |

```dart
static const cashPrior = DrillVillainProfile(...);
static const mttPrior = DrillVillainProfile(...);
static DrillVillainProfile prior({bool anteMode = false}) =>
    anteMode ? mttPrior : cashPrior;
```

**Rewrote derived getters** (no longer use VPIP-PFR gap):
- `limpRate`: `(passivity * 0.10 + showdownExcess * 0.5).clamp(0.0, 30.0)` — cash prior produces ~5.5%, matches old prior
- `defendRate`: `(passivity * 0.08 + showdownExcess * 0.4).clamp(0.0, 25.0)` — for non-blind cold-call only

#### `lib/services/drill_opponent_profiler.dart`
Added `anteMode` parameter to `profileFor()` and `fromStats()`. Removed vpip/pfr blending. Added blending for steal, cbet, blindDefend, showdown, checkRaiseFlop against the format-appropriate prior. Kept vpip/pfr from `OpponentStats` ONLY for `PlayStyleDetector` archetype classification (these are still stored for the hero profiling path).

#### `lib/screens/training/drill_setup_screen.dart`
Passes `anteMode: _ante` to `DrillOpponentProfiler.profileFor()` and uses `DrillVillainProfile.prior(anteMode: _ante)` for generic bots.

---

### Phase 3: Drill Grader — 10 Exploit Condition Replacements

Added `_ExploitThresholds` class with format-specific constants:

| Threshold | Cash | MTT |
|---|---|---|
| tightBlindDefend | 28% | 35% |
| wideBlindDefend | 50% | 60% |
| tightSteal | 18% | 25% |
| looseSteal | 42% | 52% |
| maniacSteal | 55% | 65% |
| nitThreeBet | 3.5% | 5% |
| passiveAggression | 30% | 30% (format-independent) |
| stationShowdown | 40% | 40% (format-independent) |
| limperShowdown | 35% | 35% (format-independent) |

Thresholds set at ~20–25% relative deviation from the format-specific GTO baseline. This prevents false positives — e.g., an MTT player defending 35% isn't exploitable (below GTO), but a cash player defending 35% is right at GTO.

All 10 replacements in `lib/services/drill_grader.dart`:

| # | Old Check | New Check | Recommendation Text |
|---|---|---|---|
| 1 | `avgVpip <= 24` (tight blinds) | `avgBlindDefend <= t.tightBlindDefend` | "{name} defends the blinds only {X}% — steal relentlessly from {pos}." |
| 2 | `avgVpip >= 34` (wide blinds) | `avgBlindDefend >= t.wideBlindDefend` | "{name} defends wide ({X}%) — drop the weakest steals." |
| 3 | `vpip >= 42 && pfr < 15` (station behind) | `aggression <= 30 && showdown >= 40` | "{name} calls down passively (aggression {X}%, showdown {Y}%) — favour hands that flop well." |
| 4 | `vpip >= 38 && pfr <= 15` (loose-passive limper) | `aggression <= 30 && showdown >= 35` | "{name} limps and calls passively (aggression {X}%) — isolate wide and take the lead." |
| 5 | `vpip <= 17` (nit jammer) | `steal <= t.tightSteal && threeBet <= t.nitThreeBet` | "{name} only jams premiums — fold the marginal calls." |
| 6 | `vpip >= 33` (loose opener) | `steal >= t.looseSteal` | "{name} opens loose (steal {X}%) — widen value." |
| 7 | `vpip <= 17` (tight opener) | `steal <= t.tightSteal+4 && threeBet <= t.nitThreeBet` | "{name} raises very tight (steal {X}%) — respect his raises." |
| 8 | `pfr >= 28` (maniac opener) | `steal >= t.maniacSteal && aggression >= 60` | "{name} raises aggressively (steal {X}%, aggression {Y}%) — play back wider." |
| 9 | `pfr >= 28 \|\| archetype == 'Maniac'` (maniac jammer) | `(steal >= t.maniacSteal && aggression >= 60) \|\| archetype == 'Maniac'` | "{name} shoves wide — call lighter." |
| 10 | `vpip >= 33` (cold 3-bet loose aggressor) | `steal >= t.looseSteal` | "Both raises came from loose players — continue slightly wider." |

---

### Phase 4: Drill Engine — Villain Simulation

#### `lib/services/drill_engine.dart`

**BB raise frequency** (was `profile.pfr * 0.5`):
→ Now `profile.aggression * 0.3` (limpers) or `* 0.15` (no limpers). Aggression is a more reliable indicator of how often the BB will squeeze/raise.

**Open-raise frequency** (was `profile.pfr * positionMultiplier`):
→ Steal positions (CO/BTN/SB): use `profile.steal` directly — this IS the open-raise rate for these positions.
→ Non-steal positions: approximate from aggression: `aggression * 0.28` (EP) or `aggression * 0.35` (MP).
→ The existing `anteMode ? 1.12 : 1.0` multiplier still applies, clamped to 92%.

**Blind defense facing a raise** (was `profile.defendRate * 1.2` for BB):
→ BB/SB seats now use `profile.blindDefend` for total continue rate, carved into 3-bet portion + cold-call remainder.
→ Non-blind seats still use the `defendRate` getter (aggression/showdown-based).
→ This fixes a bug: old prior had only ~10.5% total continue rate in BB, which was way too tight vs real poker. Cash prior now defends ~35%, MTT prior ~45%.

---

### Phase 6: Comprehensive Tests

**186 total tests across 4 test files, all passing.**

#### `test/services/stats_calculator_test.dart` — 110 tests (13 new)
New `'Blind Defend'` group with sub-groups:
- `isSmallBlind`: 4 tests (mirrors `isBigBlind` pattern)
- `findSmallBlindSeat`: 3 tests (mirrors `findBigBlindSeat` pattern)
- `hadBlindDefendOpportunity` / `didBlindDefend`: 6 tests covering BB/SB facing raise (call, fold, 3-bet), walk hand, limp-only hand, non-blind facing raise, multi-raise scenario

#### `test/services/drill_training_test.dart` — 27 tests (10 new)
- Prior values: `cashPrior` and `mttPrior` field verification
- `prior(anteMode:)` factory test
- `limpRate` / `defendRate` getter sanity and comparisons
- Profiler `anteMode` blending against MTT prior
- Profiler `blindDefend` stat blending
- Engine smoke tests: villain opens from steal positions, MTT mode defends wider

#### `test/services/drill_gto_baseline_test.dart` — 22 tests (unchanged, all pass)

#### `test/services/drill_grader_test.dart` — 27 tests (NEW file)
7 groups testing exploit boundary conditions in both cash and MTT modes:
- Blind defense exploits (cash + MTT): 8 boundary tests
- Station/limper detection: 4 tests (aggression/showdown thresholds)
- Opener steal-based exploits (cash vs MTT): 5 tests (same steal% triggers differently by format)
- Jammer exploits: 2 tests (maniac + nit)
- 3-bet exploits: 2 tests (fold-to-3bet, wide 3-bettor)
- Profile priors: 6 tests (values, factory, getters)

---

## Files Changed

| File | Change |
|---|---|
| `lib/services/stats_calculator.dart` | +4 methods: `isSmallBlind`, `findSmallBlindSeat`, `hadBlindDefendOpportunity`, `didBlindDefend` |
| `lib/models/opponent_stats.dart` | +2 fields: `blindDefendCount`, `blindDefendOpportunity` + getter + all serialization |
| `lib/models/user_stats.dart` | +2 fields: same (parity) |
| `lib/services/opponent_stats_service.dart` | +2 delta params in `updateStatsAtomic`/`updateStatsIncremental` |
| `lib/services/user_stats_service.dart` | +2 delta params in `updateStatsAtomic` |
| `lib/services/firebase_service.dart` | Wired blind defend detection in `_updateOpponentStatsFromHand` + `_updateUserStatsFromHand` |
| `lib/models/drill_models.dart` | Removed vpip/pfr; added steal/cbet/blindDefend/showdown/checkRaiseFlop; cashPrior/mttPrior; rewrote getters |
| `lib/services/drill_opponent_profiler.dart` | `anteMode` param; removed vpip/pfr blending; added new stat blending |
| `lib/screens/training/drill_setup_screen.dart` | Pass `anteMode` to profiler + prior() |
| `lib/services/drill_grader.dart` | Added `_ExploitThresholds` class; replaced all 10 VPIP/PFR exploit conditions |
| `lib/services/drill_engine.dart` | Replaced PFR-based open frequency with steal-based; blind defense uses `blindDefend` |
| `test/services/stats_calculator_test.dart` | +13 blind defend detection tests |
| `test/services/drill_training_test.dart` | +10 tests: priors, getters, profiler anteMode, engine smoke |
| `test/services/drill_grader_test.dart` | **NEW** — 27 grader exploit boundary tests |

---

## GTO Threshold Sources

All thresholds derived from **8-9 max** solver data, split by format:

**Cash (8-9 max, 100BB, no antes)**: Steal ~28% (BTN ~38%, CO ~22%, SB ~25%); BB defend ~35-40%; 3-bet ~6%; fold-to-3bet ~58%. Standard solver outputs for 100BB 9-max.

**Tournament (8-9 max, BB ante)**: Steal ~38% (BTN ~51%, CO ~27%, SB ~35%); BB defend ~45-55%; 3-bet ~8%; fold-to-3bet ~52%. Preflop Wizard 75BB 9-max MTT solver outputs.

**Exploit threshold design**: Set at ~20–25% relative deviation from the format-specific GTO baseline. This ensures the same "degree of exploitability" regardless of format.

---

## Key Design Decisions

1. **Why not just keep VPIP/PFR with a disclaimer?** VPIP/PFR are fundamentally broken for opponents because we never observe their folds in hands where the hero isn't dealt in. Every other stat in the system (steal, 3-bet, c-bet, etc.) uses opportunity-based denominators that are correctly tracked. Removing VPIP/PFR from the drill system eliminates an entire class of misleading exploit recommendations.

2. **Why format-aware priors?** A cash game at 8-max with no antes has fundamentally different equilibrium frequencies than an MTT at the same table size with antes. Using a single prior produces incorrect exploit thresholds — e.g., a 35% blind defend rate is right at GTO in cash but 10pp below GTO in MTT with antes. The dual-prior system prevents false positives where the grader would incorrectly label normal MTT behavior as exploitable.

3. **Why keep vpip/pfr in OpponentStats?** The raw VPIP/PFR values are still tracked and stored in `OpponentStats` — they're used by `PlayStyleDetector` for archetype classification (Maniac, LAG, TAG, etc.) on the hero's own stats where the denominator IS correct. The drill profiler reads them only for this archetype call, never exposing them on `DrillVillainProfile`.

4. **BB defense bug fix**: The old system derived BB defense from `(vpip - pfr) * factor`, which produced only ~10.5% total continue rate for the default villain — far too tight. Real BB defense at 8-9max cash is ~35-40%. The new `blindDefend` stat directly models this correctly.

---

## Verification Checklist

- [x] `flutter analyze` — zero new errors (620 pre-existing warnings/infos unchanged)
- [x] `flutter test test/services/stats_calculator_test.dart` — 110 pass
- [x] `flutter test test/services/drill_training_test.dart` — 27 pass
- [x] `flutter test test/services/drill_gto_baseline_test.dart` — 22 pass
- [x] `flutter test test/services/drill_grader_test.dart` — 27 pass
- [x] Zero `.vpip` / `.pfr` references in any drill file
- [x] No VPIP/PFR mentioned in any exploit tips or trace output
