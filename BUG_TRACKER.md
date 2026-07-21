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
| HL-8b | Stack ≤ call: raise-snap drag bar still offers raises; drag-down numpad doesn't adapt | When no legal raise exists (stack ≤ toCall) or the only raise is a shove (stack < min-raise), the drag-up bar collapses to a single ALL-IN snap and the numpad locks to the all-in amount | 🟡 |

Deferred: SB-entry / dead-button rules → POKER_SEATING_RULES.md

## Device-test checklist (🟠)
- [x] HL-1: seat player left of BB pre-action → they become UTG — APPROVED
- [x] HL-3: add player mid-hand → dimmed, no action, dealt in next hand — APPROVED
- [x] HL-7: raise over an all-in → side-pot pill appears immediately — APPROVED
- [ ] HL-2: change table mid-hand → discard confirm; cancel resumes hand; confirm → fresh table, no phantom hand in history/stats
- [ ] HL-4: after table change → no drawer; tap seats to add players
- [ ] HL-8: shove with stack ≤ call amount → flash + hand review show ALL-IN

## Audit-found defects (details in test/HAND_LOGGING_SPEC.md §4)
D1 UserStats DateTime crash · D2 duplicate hand on save retry · D3 undo call-then-raise ·
D4 dual opponent-stats path? · D5 busted-dialog dismiss no-op · D9 CSV test drift — all 🔴

## Earlier fixes: duplicate opponents (2d39996) · Y-axis wrap (629b6b4) · iOS 1.0.3 train (config)
