# Hand Logging — Core Spec & Regression Contract

**Purpose:** the canonical list of hand-logging core behaviors (invariants), how the
pieces fit together, what tests protect them, and where the gaps are. Any change
touching hand logging must keep every invariant here green. Companion to the
`/diary` entries (which document individual past fixes).

**Created:** 2026-07-21 (full audit: engine + UI flow + test coverage).

---

## 1. Architecture — how the app comes together on top of hand logging

Three layers own state; the seams between them are where bugs live:

| Layer | Class / file | Owns |
|---|---|---|
| **Live table engine** | `PokerGameState` (`lib/models/poker_game_state.dart`) | pot, stacks, betThisRound/totalContribution, currentBet, turn order, side pots, street snapshots |
| **Recorder** | `PokerSessionManager` + `HandRecord`/`ActionRecord` (`lib/models/hand_state_machine.dart`) | action log, per-street pots, stack history, save/stats orchestration |
| **Glue (widget!)** | `poker_hand_screen.dart` (~7900 lines) | gesture handling, dialogs, **pot-award logic**, **undo engine**, dual-writes to both engines |

**Fixed call order per hand (driver convention, not enforced):**
`gameState.startNewHand()` → `gameState.initializePot()` → `sessionManager.startHand(...)`
(first hand additionally requires `finalizeInitialization()` before `initializePot`).

**Save pipeline (single path):** every completion funnels through
`_saveHandToFirebase` (hand_state_machine.dart:915):
Local SQLite → RangeGrid index (fire-and-forget) → Firestore → stats.
Hero stats: ONLY in `FirebaseService._updateUserStatsFromHand`.
`_updateOptimizedStats` (hsm:1031) is opponents-only (double-count scar, hsm:1144-1156).

### Duplicated state (drift sources — audit found 9)
1. Pot ×3: `gameState.currentPot` + `streetPots` map + `HandRecord.potAmount`/per-street pots
2. Button ×3: gameState, sessionManager, per-ActionRecord
3. Blind seats ×2: `_effectiveSB/BBPosition` (gameState) vs `actualSB/BBSeat` (sessionManager)
4. Hero seat ×2: `sessionManager.ourSeatNumber` vs `HandRecord.heroSeatNumber` (snapshot)
5. Stacks ×3: `players[i].currentStack`, `playerStacks[seat]`, `stackHistory`
6. Hero position: frozen at startHand vs recomputed per action
7. `betThisRound` vs `totalContribution` (rolled over once per street)
8. `hasCalledCurrentBet`: 3 writers (reset-except, street reset, undo recalc)
9. `isAllIn`: derived + directly set (3 writers)

UI dual-write points (must update BOTH engines): dealer-button move
(`_onDealerButtonMoved` :2288), blinds edit (:820-823), seat edits (`_onSeatTapped`
:2380-2430).

---

## 2. Core invariants (the regression contract)

Status: ✅ tested · ⚠️ enforced but untested · ❌ nothing protects it

### Chip conservation & pot math
| # | Invariant | Enforced at | Test |
|---|---|---|---|
| I1 | Pot == Σ contributions at every step; Σ side pots == total committed | SidePotCalculator; debug-only assert poker_hand_screen:5095 | ✅ engine level (`hand_logging_edge_cases_test.dart` asserts every step) / ❌ at award time (assert stripped in release) |
| I2 | Uncalled bet returned to unique highest bettor before award | `processUncalledBetReturns` pgs:1653 | ✅ C-series tests |
| I3 | Pot award: winner stack += pot exactly once, then pot=0 | widget layer only (:5206, :6061) | ❌ no test (lives in widget) |
| I4 | Scouted hand: pot NEVER awarded, stacks frozen at fold | hsm:773-804 | ⚠️ (isScouted serialization tested; award-skip not) |
| I5 | `_applyStreetPots` reconciles per-street pots incl. current street fallback | hsm:698-723 | ❌ |

### Blinds, button, positions
| # | Invariant | Enforced at | Test |
|---|---|---|---|
| I6 | Blinds/button rotate by TDA Rule 34 from the previous hand's BB/SB SEATS (cash + tournament): BB = next live after last BB, SB = last BB seat, BTN = last SB seat. Empty SB seat = dead SB (nobody posts); empty BTN seat = dead button. 2 live: BTN = SB | `lib/utils/blind_rotation.dart`, pgs `rotateBlindsForNextHand` | ✅ `dead_button_*_test.dart` |
| I6a | Rotation advances exactly once per new hand (startNewHand, Skip, fold tick). `initializePot` / `recalculateActionOrder` re-derive from the memory and never advance it; BB removed pre-action == left before the hand | pgs `_refreshAssignment` | ✅ |
| I6b | Manual button move (pre-action only, I12) restarts the memory from that button; later hands continue from it. Undo/fold-tick restore puts the memory back (`restoreBlinds`) | pgs `buttonPosition=`, `TableSnapshot` | ✅ |
| I6c | Dead hands: position names are real (no BTN on dead button, no SB on dead SB; empty seats are ring slots), stored once at hand start (I11) | `PokerPositions.getPositionNameForActivePlayers(deadSeats:)`, hsm `deadSeats` | ✅ |
| I6d | Known gaps (shipped 2.1.9): a reopened dealer table loses a pending dead SB (only the button is persisted; `seedDeadSmallBlind` is not fed on reopen). AI analyzer `_calculatePosition` fallback can mislabel a player with no recorded action in a dead hand | `ai_analyzer_service`, dealer table reopen | ⚠️ open |
| I7 | Blinds posted from CURRENT active players (HU special case: BTN=SB) | pgs:1378-1418 | ✅ A-series |
| I8 | `initializePot` idempotent (double-call refunds prior blinds) | pgs:1381-1387 | ⚠️ |
| I9 | `initializePot` never called inside `startNewHand` (late seat changes) | convention, pgs:1141-1144 | ❌ |
| I10 | UTG first preflop, SB first postflop; HU: button first preflop | pgs:253, :1050 | ✅ |
| I11 | Hero position computed ONCE at hand start, never recalculated | hsm:579, comments :806/:884 | ❌ |
| I12 | Button locked while hand has actions (`isDealerButtonDraggable`) | poker_hand_screen:1915 | ❌ (diary 2025-10-27) |

### Action recording semantics
| # | Invariant | Enforced at | Test |
|---|---|---|---|
| I13 | Amount semantics: **call = delta paid; bet/raise = total bet-to** (split by action type, NOT by street) | screen :4654-4657 / pgs:724,759 | ❌ — and undo's `_getPreviousBetThisRound` (:5880) violates it for call-then-raise |
| I14 | All-in counts as bet/raise for stats (via enum; `'all-in'` string branches are DEAD code — nothing records it) | stats_calculator:19-27 | ✅ detection / ⚠️ dead branches misleading |
| I15 | Blind posts are never ActionRecords (undo reconstructs from effective positions) | by omission; :5888 | ❌ |
| I16 | Duplicate action suppression (same player+action+street within 2s dropped) | hsm:243-257 | ❌ (heuristic, can drop legit repeats) |

### Streets & undo
| # | Invariant | Enforced at | Test |
|---|---|---|---|
| I17 | Street advance snapshot/restore is exact (cancel board dialog = full rollback) | pgs:945/969; rollback :5657 | ✅ D-series (engine) / ❌ dialog-cancel path |
| I18 | Undo restores stacks/pot/flags exactly; only current-street, non-blind actions | `_undoLastAction` :5721, `_canUndoLastAction` :5689 | ❌ (diary 2025-11-02) |
| I19 | `betThisRound` → `totalContribution` rollover exactly once per street | pgs:78 | ✅ D1 |

### Completion & save
| # | Invariant | Enforced at | Test |
|---|---|---|---|
| I20 | Single save path; stats updated exactly once per hand (hero stats ONLY in FirebaseService) | hsm:915, scar comment :1144-1156 | ❌ nothing prevents regression |
| I21 | Save retry must not duplicate: **currently NOT idempotent** (doc id `hand_{n}_{ms}` time-based; totalHands re-incremented) | firebase_service:296,306 | ❌ known defect |
| I22 | Walk: BB with no opportunity → walksCount++, NOT vpip; denominator = totalHands − walks | stats_calculator:346; fs:1485 | ✅ detection / ❌ save-side gating |
| I23 | Scout hand: opponent stats always, hero stats only if voluntarily entered (`skipHeroStats`) | hsm:769,819; fs:313 | ❌ |
| I24 | Tutorial/guided hands: never counted (skipStats), guided replay never persisted | hsm:918-922 | ❌ |
| I25 | Empty hands (no actions) discarded, never saved | hsm:548-554, 1249-1256 | ❌ |
| I26 | `completedHands` holds only hero-counted hands (session summary basis) | hsm:810 | ❌ |
| I27 | Skip hand: no record, no save, `skippedHands++` only (honest denominators) | hsm:435 | ❌ |
| I28 | Busted players deactivated only at hand boundary, never mid-hand | pgs:96-97, 1102, 1108 | ⚠️ |
| I29 | Chop vs split: `isSplitPot` distinguishes side-pot wins from chopped single pot; `winnerId` = largest-pot winner | hsm:203-205, 873-875 | ✅ partial (multi_pot_winner_aggregation) |

**Easy hand logging — completeness levels (flag `easy_hand_logging`; see `docs/hand-logging-completeness.md`)**

| # | Invariant | Where | Tested |
|---|---|---|---|
| I30 | A flagged stub's stats apply EXACTLY ONCE, at promotion, guarded by `statsApplied` (flipped in a Firestore transaction BEFORE the stats call; a failure under-counts, never double-counts) | hand_promotion_service `promote`, firebase_service `claimStubPromotion` | ✅ hand_promotion_test |
| I31 | Stubs (`flagged`) never reach `updateStatsAtomic`; the only hand-stat callers are the allow-listed sites | firebase_service `_applyStatsForSavedHand` | ✅ completeness_gating_test (allow-list) |
| I32 | A fold tick adds `totalHands + 1` and `skippedHands + 1` (position stays null), exactly like the legacy Skip hand | `HeroHandDelta.foldTick`, `_updateSessionCounters` | ✅ hand_stats_plan_test |
| I33 | Session `totalHands` and `walksCount` change at promotion only for a stub (a BB-walk stub adds `walksCount` when promoted) | hand_promotion_service, `computeHeroDelta` | ✅ |
| I34 | Ticks and stubs take REAL incremented hand numbers (range-grid dedupe key `{sessionId}:{handNumber}`) | `PokerSessionManager._buildBaseRecord` | ✅ hand_promotion_test |
| I35 | Non-full hands are excluded from analysis consumers per the gating matrix (leaks, AI, exports, summary best/worst, history) | leak_extractor, exports, hand_actions_screen, history screens | ✅ completeness_gating_test |
| I36 | Empty-actions stubs are allowed ONLY through `PokerSessionManager.recordFlag` (bypasses the "empty hand is never saved" rule on purpose) | hand_state_machine `recordFlag` | ✅ |

### UI flow invariants
| # | Invariant | Enforced at | Test |
|---|---|---|---|
| U1 | Winner/MultiPot dialogs are DISMISSIBLE; on null result → `bettingRoundComplete=false` + setState (unfreeze). Removing these guards re-introduces the frozen-hand bug | :6402, :4970 | ❌ no widget test |
| U2 | Board-cards dialog cancel → full street rollback (snapshot restore) | :5285, :5657 | ❌ |
| U3 | All-in board dialog cancel → betting reopened (undo available) | :4882 | ❌ |
| U4 | PopScope: never pop with unsaved data without save/discard/cancel dialog; empty session deleted on exit | :1226, :994 | ❌ (diary 2026-03-25) |
| U5 | Free-tier gate: paywall dismissed → session saved + exited; premium re-checked after paywall | :6195-6211 | ❌ (diary 2026-04-12) |
| U6 | Winner shown with identical name+position in both winner paths (all-in vs river) | diary 2025-10-07 | ❌ |
| U7 | Mid-hand blinds edit: applies next hand (already-posted blinds NOT re-posted) | :713-823 | ❌ |
| U8 | `_BustedPlayerDialog` dismiss = no-op (busted player unresolved) — **known hole** | :6798 | ❌ |
| U9 | Side-pot pill appears the moment a bet/raise exceeds an all-in (pending live players are pot-eligible); pill model recalculated after every action and survives street advance; single-eligible in-flight overage pots never shown as pills; winner-dialog pots computed AFTER uncalled-bet returns | SidePotCalculator eligibility clause (HL-7 fix); recalc at pgs:631/781/994/1088/1271 | ✅ `side_pot_display_test.dart` (incl. exact user scenario replay) |
| U10 | Seating boundary (HL-1/HL-3): seat change while `currentHand.actions.isEmpty` joins the current hand — blinds re-posted, action order recomputed (new seat after BB becomes UTG), blind seats + frozen hero position re-synced. Seat change after any action is DEFERRED (`pendingSeats`/`deferHeroReseat`): engine untouched mid-hand, seat renders dimmed, `flushPendingSeats()` runs before every `startNewHand()` | `_onSeatTapped` onSave; `recalculateActionOrder()`; hsm pending-seat block | ✅ `seating_boundary_test.dart` |

---

## 3. Hand completion paths (12 — all must be covered eventually)

1. Everyone folds → auto-award sole survivor (:6039) — no winner dialog
2. Showdown multi-live → winner selection (:6114)
3. River betting complete → `_handleHandComplete` (:7089)
4. Single winner selected (:5185)
5. Chopped single pot (:5155) — `completeCurrentHandWithChop`
6. Multi side-pot, same/chopped main (:5128)
7. Multi side-pot, distinct winners (:5117) — `isSplitPot=true`
8. All-in runout (:4842) → paths 4-7
9. Scouted hand (:4060) — preflop-only, no pot award, conditional hero stats
10. Skip hand — no record at all, `skippedHands++`
11. Dealer mode (dealer_table_screen:1112/1187) — + playerIds multi-player stats
12. Dealer chop (dealer_table_screen:1044)

---

## 4. Latent defects found during audit (not yet user-reported)

| ID | Defect | Where | Severity |
|---|---|---|---|
| D1 | `UserStats.toFirestore()` writes raw `DateTime` for `lastUpdated`; `fromFirestore` expects `Timestamp` → round-trip crash (root cause of "17 failing tests"; real failures: 2) | user_stats.dart:224/:192 | **Real prod bug** |
| D2 | Save retry can duplicate hand doc + re-increment totalHands (non-deterministic id) | firebase_service:296,306; hsm:1316 | High |
| D3 | Undo mis-reconstructs when player calls then raises same street (treats call.amount as total) | poker_hand_screen:5880 | High |
| D4 | Opponent stats possibly written by TWO paths (`_updateOptimizedStats` name-based + `updateOpponentStatsFromHand`) — confirm they don't double-count | hsm:1129 vs fs:342 | Needs confirmation |
| D5 | `_BustedPlayerDialog` dismissed → busted player never resolved | :6798 | Medium |
| D6 | Pot-conservation assert is debug-only; release builds silently tolerate distribution mismatch | :5095 | Medium |
| D7 | No app-lifecycle handling: backgrounding + OS kill loses in-progress hand (memory-only) | whole screen | Medium/known |
| D8 | `heroPositionName`/`heroSeatNumber` not persisted to local SQLite (TODO hsm:943) — offline hands lose position | hsm:943 | Low |
| D9 | CSV export tests drifted from exporter output (8 failures: `small-blind` vs `small blind`, pot column, headers) — decide which is right | csv_export_service_test | Test debt |

---

## 5. Test coverage snapshot (2026-07-21)

**Well covered:** PokerGameState engine (35 scenarios w/ chip-conservation assert each
step), side pots, all-in, StatsCalculator detection (110), UserStats math, exports.

**Zero coverage:** PokerSessionManager lifecycle (startHand/recordAction/complete/
undo — never instantiated except one getter test), save-pipeline gating
(skipStats/skipHeroStats/walk/dealer), `utils/poker_positions.dart`, hand-level
undo, ALL widget tests (only one testWidgets exists and it's `skip: true`), no
`integration_test/`, HandRecord general round-trip (only isScouted covered).

**Infra gap:** `pubspec.yaml` has **no dev_dependencies block** — no
fake_cloud_firestore, no mocktail. This blocks save-pipeline + widget tests.

**Currently red:** 10 real failures (2 user_stats_position via D1, 8 CSV drift via
D9); the rest of the "-27" full-run tally is async-error contamination between tests.

---

## 6. Test build-out plan (phased)

**Phase 0 — unbreak & unblock**
- Fix D1 (`Timestamp.fromDate` in toFirestore) → user_stats_position green
- Resolve D9 (align CSV tests or exporter — decide intended format)
- Add `dev_dependencies`: flutter_test (explicit), mocktail, fake_cloud_firestore
- Kill async contamination (await the offending futures in tests)

**Phase 1 — recorder lifecycle unit tests** (highest-value gap)
- PokerSessionManager: startHand → recordAction* → completeCurrentHand /
  WithChop: potAmount, per-street pots (I5), winnerId, heroPositionName frozen
  (I11), empty-hand discard (I25), completedHands membership (I26),
  skippedHands (I27), isScouted behavior (I4/I23 flags), chop/split fields (I29)
- HandRecord full serialization round-trip (actions, board, hole, showdown,
  chopped, shares)
- Shared **HandBuilder** test fixture that drives BOTH engines in lockstep the
  way the screen does (startNewHand → initializePot → startHand → actions) so
  every test exercises the real integration seam

**Phase 2 — invariant hardening tests**
- I13 amount-semantics contract test (call=delta, bet/raise=total) + the D3
  call-then-raise undo case (will fail → fix)
- Undo round-trip property test: apply N actions, undo N, assert exact
  gameState equality (I18)
- Pot conservation at award time for all completion paths 1-8 (I1/I3)
- initializePot idempotency (I8), button-rotation w/ busted seats (I6)

**Phase 3 — save pipeline tests (fake_cloud_firestore)**
- I20 exactly-once stats; I21 retry idempotency (fix D2 with deterministic id
  `hand_{n}` or session-scoped counter → then test)
- I22 walk gating, I23 scout gating, I24 tutorial gating, dealer-mode
  multi-player stats (path 11)
- D4 confirmation test (opponent stats single-write)

**Phase 4 — widget tests (UI flow contract)**
- U1: winner dialog dismissed → hand not frozen (tap next action succeeds)
- U2: board dialog cancel → state identical to pre-advance snapshot
- U4: PopScope guard (unsaved → dialog; empty → session deleted)
- Numpad/raise-snap commit paths produce correct engine mutations
- U8: busted-dialog dismiss (fix first, then lock)

**Phase 5 — integration_test/ happy paths** (device/simulator)
- Full session: setup → 3 hands (fold-out, showdown, all-in) → end session →
  summary; assert Firestore + SQLite contents match

---

*Update this file whenever an invariant is added/changed or a phase lands.*
