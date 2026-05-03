# Tournament Data Persistence + Session Statistics Redesign — 2026-05-03

## Summary
Persist tournament data (finishing position, field size, prize) and session duration to Firestore `session_results` documents. Redesign Statistics → Session Statistics into three sections: General, Cash, Tournament — with financial stats, tournament-specific metrics, and hourly rates.

## Problem
The app collected tournament data (finishing position, field size, prize amount) in `SessionEndBankrollSheet` but discarded it — only net profit was saved to `session_results`. This valuable data was never surfaced to users.

## Solution

### Phase 1: Data Persistence
Added 5 new optional fields to `SessionResultService.addSessionResult()`:
- `buyInAmount` — total buy-in for the session (cash + tournament)
- `prizeWon` — tournament prize amount
- `finishedPlace` — tournament finishing position
- `fieldSize` — tournament field size
- `durationMinutes` — session duration in minutes

Updated 3 callers to pass these fields:
- `SessionEndBankrollSheet` — passes all fields from its form inputs
- `individual_session_tracking_screen.dart` (2 call sites) — passes `durationMinutes`
- `poker_hand_screen.dart` — passes `durationMinutes`

### Phase 2: Statistics Screen Redesign
Replaced single session stats section with 3 sections:

**GENERAL** (all session types)
- 3-column row: Sessions | Total Time | Avg Session (from `user_stats`)
- Total Buy-In, Total Cash-Out, Net Profit, Hourly Rate (from `session_results`)

**CASH** (gameType == 'cash' only)
- Sessions, Total Buy-In, Total Cash-Out, Net Profit, Hourly Rate

**TOURNAMENT** (gameType == 'tournament' only)
- Sessions, Total Buy-In, Total Cash-Out, Net Profit, Hourly Rate
- ITM%, Avg Finish, Best Finish, ROI%, Final Tables, Avg Buy-In, Avg Field Size

### Phase 3: Hourly Rate
- Formula: `netProfit / (totalMinutes / 60)`
- Color-coded: green (+) / red (-), with `/h` suffix
- Currency-aware: respects prefix/suffix position (e.g., `+$45/h` or `+45zł/h`)
- Shows N/A when no duration data available

## Key Design Decisions
- **On-the-fly computation**: Stats computed from fetched `session_results`, not incremental counters
- **No migration**: Old records without `buyInAmount` are skipped (continue excluded from financial stats)
- **Best Finish**: Plain number, no ordinal suffixes
- **Final Tables**: Position ≤ 9
- **Cash-Out calculation**: Cash = buyIn + profit; Tournament = prizeWon (actual cash received)
- **General Cash-Out**: buyIn + netProfit (aggregate)
- **ROI**: `(cashOut - buyIn) / buyIn * 100`

## Cache
All new fields (financial stats, hourly rates, duration minutes) added to `AppDataCache.cachedOverallStats` save/restore cycle.

## i18n
14 new keys added to all 7 ARB files:
- `statsGeneral`, `statsCash`, `statsTournament`
- `statsTotalBuyIn`, `statsTotalCashOut`, `statsNetProfit`
- `statsItm`, `statsAvgFinish`, `statsBestFinish`, `statsRoi`
- `statsFinalTables`, `statsAvgBuyIn`, `statsAvgFieldSize`
- `statsHourlyRate`

Poker terms (ITM, ROI, Buy-In, Cash-Out) stay English in all locales.

## Files Modified (20 files)
- `lib/services/session_result_service.dart` — 5 new optional params
- `lib/widgets/session_end_bankroll_sheet.dart` — pass new fields + durationMinutes param
- `lib/screens/statistics_screen.dart` — full redesign (~400 lines added)
- `lib/screens/individual_session_tracking_screen.dart` — pass durationMinutes (2 sites)
- `lib/screens/poker_hand_screen.dart` — pass durationMinutes
- `lib/l10n/app_*.arb` (7 files) — 14 new keys each
- `lib/l10n/app_localizations*.dart` (8 files) — auto-generated

## Patterns
- Section headers: lime green 12px w600 uppercase, letterSpacing 1.0
- Stats card: `#131616` bg, radius 18, padding 20
- Profit row: green `#87ED81` for positive, red `#E85A5A` for negative, with +/- prefix
- Hourly rate: same color coding, with currency symbol + `/h` suffix
- Empty state: centered 14px white 40% opacity text
