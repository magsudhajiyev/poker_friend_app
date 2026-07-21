# Bug Tracker

Status: 🔴 open · 🟡 agreed · 🟠 fixed, uncommitted · 🟢 committed · 🔵 deferred
Details live in `test/HAND_LOGGING_SPEC.md`; seating rules in `POKER_SEATING_RULES.md`.

## Hand-logging bugs (2026-07-21)

| # | Bug | Fix (short) | Status |
|---|---|---|---|
| HL-1 | Seat filled after BB pre-action → UTG doesn't change | Pre-action add re-posts blinds + recomputes action order/positions | 🟢 |
| HL-2 | No confirmation for mid-hand table change | ConfirmDialog (8 locales) "Discard & Change Table" / Cancel; `discardCurrentHand()` nulls hand BEFORE seats clear (kills silent corrupt-hand save); fresh hand reuses the number | 🟢 |
| HL-3 | Player seated mid-hand gets action | Deferred activation (pendingSeats), dimmed seat, joins next hand; same for hero | 🟢 |
| HL-4 | Seat drawer auto-opens after table change | Removed — widget deleted (`table_management_sheet.dart`), players added by tapping seats | 🟢 |
| HL-5 | Record opponent's shown cards | Press-and-hold seat during settling → cards to showdownData; add tour step | 🟡 |
| HL-6 | Hole cards sometimes missing in session details | Deferred — diagnosis in test/HAND_LOGGING_SPEC.md | 🔵 |
| HL-7 | Side pots broken | Eligibility fix: pill now appears when a bet exceeds an all-in; math was correct | 🟢 |
| HL-8 | All-in ≤ call amount shown as limp/call | ALL-IN labels approved & committed (flash, range-grid line, hand details, PS export; record stays `call`) | 🟢 |
| HL-8b | Stack ≤ call: raise-snap drag bar still offers raises; drag-down numpad doesn't adapt | 4 layers: engine `isValidAction(raise)` now false when stack can't exceed the bet; snap ladder drops unaffordable "Min" + collapses to single All-In when shove-only; drag-up with stack ≤ call becomes an all-in CALL gesture (confirm calls, never raises); numpad locks to the all-in amount (shove-only) / never opens (no raise exists). Tests: `raise_gesture_mode_test.dart` | 🟢 |

Deferred: SB-entry / dead-button rules → POKER_SEATING_RULES.md

Next session: HL-5 (press-hold shown cards + tour step) → audit defects D1-D5, D9 → spec Phase 0-4 test build-out (test/HAND_LOGGING_SPEC.md §6).

## Device-test checklist (🟠)
- [x] HL-1: seat player left of BB pre-action → they become UTG — APPROVED
- [x] HL-3: add player mid-hand → dimmed, no action, dealt in next hand — APPROVED
- [x] HL-7: raise over an all-in → side-pot pill appears immediately — APPROVED
- [x] HL-2: change table mid-hand → discard confirm; cancel resumes hand — APPROVED
- [x] HL-4: after table change → no drawer — APPROVED
- [x] HL-8/8b: shove with stack ≤ call → ALL-IN labels + collapsed gesture — APPROVED

All device-approved 2026-07-22. Commits: 8739b82 (HL-1..4,7,8), 47c8007 (HL-8b). Local only — not pushed.

## Audit-found defects (details in test/HAND_LOGGING_SPEC.md §4)
D1 UserStats DateTime crash · D2 duplicate hand on save retry · D3 undo call-then-raise ·
D4 dual opponent-stats path? · D5 busted-dialog dismiss no-op · D9 CSV test drift — all 🔴

## Earlier fixes: duplicate opponents (2d39996) · Y-axis wrap (629b6b4) · iOS 1.0.3 train (config)
