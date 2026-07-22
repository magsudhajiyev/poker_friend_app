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
| HL-5 | Record opponent's shown cards | "Record shown cards" pill on settling overlay → standard AppSheet player drawer → single-card dialog → persisted (Firestore+SQLite). PLUS history rule: hands where hero folded PREFLOP (incl. open→fold-to-3bet, scouted) hidden from hero's hand history — still saved, hero preflop stats + range grid + opponent stats unaffected. Post-hand patch sites migrated completedHands.last → lastFinishedHand (kills the HL-6 wrong-hand hazard). Tests: shown_cards_test (14) | 🟠 |
| HL-6 | Hole cards sometimes missing in session details | Deferred — diagnosis in test/HAND_LOGGING_SPEC.md | 🔵 |
| HL-7 | Side pots broken | Eligibility fix: pill now appears when a bet exceeds an all-in; math was correct | 🟢 |
| HL-8 | All-in ≤ call amount shown as limp/call | ALL-IN labels approved & committed (flash, range-grid line, hand details, PS export; record stays `call`) | 🟢 |
| HL-8b | Stack ≤ call: raise-snap drag bar still offers raises; drag-down numpad doesn't adapt | 4 layers: engine `isValidAction(raise)` now false when stack can't exceed the bet; snap ladder drops unaffordable "Min" + collapses to single All-In when shove-only; drag-up with stack ≤ call becomes an all-in CALL gesture (confirm calls, never raises); numpad locks to the all-in amount (shove-only) / never opens (no raise exists). Tests: `raise_gesture_mode_test.dart` | 🟢 |

Deferred: SB-entry / dead-button rules → POKER_SEATING_RULES.md
Agreed follow-up (HL-5t): shown-cards step must join the IN-APP TOUR — after the guided hand finishes and ONLY when it was not a showdown hand (respect diary/2026-07-15 tour reference). 🟡

Next session: HL-5 (press-hold shown cards + tour step) → audit defects D1-D5, D9 → spec Phase 0-4 test build-out (test/HAND_LOGGING_SPEC.md §6).

## Device-test checklist (🟠)
- [x] HL-1: seat player left of BB pre-action → they become UTG — APPROVED
- [x] HL-3: add player mid-hand → dimmed, no action, dealt in next hand — APPROVED
- [x] HL-7: raise over an all-in → side-pot pill appears immediately — APPROVED
- [x] HL-2: change table mid-hand → discard confirm; cancel resumes hand — APPROVED
- [x] HL-4: after table change → no drawer — APPROVED
- [x] HL-8/8b: shove with stack ≤ call → ALL-IN labels + collapsed gesture — APPROVED
- [ ] HL-5: after a hand → "Record shown cards" pill → standard drawer picker → 1-2 cards → saved; stack ring normal mid-hand
- [ ] HL-5 history rule: open then fold to a 3-bet preflop → hand NOT in hand list; fold on flop → hand IS in list; VPIP/PFR still count the open-fold

All device-approved 2026-07-22. Commits: 8739b82 (HL-1..4,7,8), 47c8007 (HL-8b). Local only — not pushed.

## Features in flight
- GS-1 Sign-up-first get-started flow 🟢 (573aabd, device-approved) — guest mode removed for new users: intro "Get Started" → register screen; AuthWrapper routes ALL anonymous sessions to the hard gate (stray guests upgraded in place). Order (v2 per owner): signup → onboarding (username+survey via startup gate — username guaranteed: fresh docs carry hasSetUsername:false) → tour auto-starts on Home → tour ends → bankroll step (BankrollCardTour) → "you're done" dialog → once-ever paywall (new postTourWrapUpPending flag, kill-resume safe). Guest machinery kept dormant

- GS-2 Stack-ring tour step 🟢 (573aabd, device-approved) — discovered the existing stack-ring coach mark NEVER fired (targeted a StackRangeCircle widget that never renders during the guided hand; also absent from the tour reference step list). Moved to a deterministic slot: post-hand-1 coach marks now run Stack ring (hold opponent seat, circle spotlight) → Blinds pill → Next Hand → Undo. Copy rewritten to teach the press-and-hold entry (8 locales). Diary reference updated

- GS-3 AI analysis in selected language 🟢 — backend 4e213ce (prompt suffix, 9 locales, poker terms stay English; optional field, old clients unaffected) + client 5832d28 (analysisLanguage resolver, stored on saved analysis; cached analyses keep their language — no silent quota burn). Device-tested

## Audit-found defects (details in test/HAND_LOGGING_SPEC.md §4)
- D1 UserStats DateTime crash 🟠 DONE — tolerant lastUpdated parse (Timestamp/DateTime/missing); BONUS: 'EP'/'MP' added to position whitelist (their position stats were silently dropped). user_stats suites 42/42 green
- D2 duplicate hand on save retry 🟠 — save is now retry-idempotent: local skipped when localHandId set (re-insert minted a new row id), cloud skipped when cloudHandId set (re-save minted a new doc + re-incremented totalHands)
- D3 undo call-then-raise 🔴 — deferred (fragile undo surgery, own session)
- D4 dual opponent-stats path 🟠 — CONFIRMED orphan writes: _updateOptimizedStats wrote opponent_stats keyed by player NAME with per-ACTION vpip deltas; nothing reads name-keyed docs (all consumers load by opponent.id). Dead method removed; opponent stats update exactly once via saveHand path. Zero read-behavior change
- D5 busted-dialog dismiss no-op 🟠 — dialog re-shows until an explicit rebuy/leave choice (system back could pop it to null)
- D9 CSV test drift 🟠 DONE — all 3 CSV test files green (49 tests): stale expectations aligned to shipped format (hyphen blind names, blind-excluded pot column, boards only on rows of their street, metadata totalHands, size threshold, always-failing preflop-substring assert). Exporter hardened: never throws on corrupt actions/boards/hole cards, junk amounts degrade to 0, player names CSV-sanitized (RFC 4180 quoting — commas/quotes/newlines can no longer corrupt rows)

## Earlier fixes: duplicate opponents (2d39996) · Y-axis wrap (629b6b4) · iOS 1.0.3 train (config)
