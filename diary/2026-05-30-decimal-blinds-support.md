# Decimal Blinds Support for Cash Games

**Date**: 2026-05-30
**Branch**: design_v2

## Summary

Changed `smallBlind`/`bigBlind` from `int` to `double` across the entire data pipeline so small-stakes cash games can use fractional blinds like $0.25/$0.50. Tournament blinds remain whole numbers but use `double` for type consistency.

## What Changed

### Type: `int` → `double` (20 files)

**Core Models**
- `poker_game_state.dart` — fields, constructor; removed 16 `.toDouble()` calls; added top-level `formatBlindValue()` helper
- `hand_state_machine.dart` — fields; `biggestPotBB` also `int` → `double`
- `dealer_session.dart` — fields, constructor defaults, `fromFirestore`/`fromMap` with `(num?)?.toDouble()`
- `club.dart` — `ClubSettings.defaultSmallBlind`/`defaultBigBlind`, `fromMap`, `copyWith`
- `stack_bucket.dart` — `displayForPlayer()` and `bbLabel()` params

**Screens**
- `poker_hand_screen.dart` — widget params, blinds dialog (`Map<String, int>` → `Map<String, double>`), decimal keyboard + `FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))`, `prefs.setInt` → `prefs.setDouble`, display pill uses `formatBlindValue()`, `ante` field `int` → `double`
- `unified_session_setup_screen.dart` — state vars, prefs, validation; `_buildBlindTextField` gains `allowDecimal` param (cash=true, tournament=false)
- `individual_session_tracking_screen.dart` — `_currentSmallBlind`/`_currentBigBlind`, dialog, display, Firestore reads with `(num?)?.toDouble()`
- `individual_session_setup_screen.dart` — state vars, dialog, display
- `individual_hand_setup_screen.dart` — state vars, display
- `introduction_screen.dart` — state vars, dialog, display
- `seat_setup_screen.dart` — widget params
- `quick_stack_update_screen.dart` — widget params
- `profile_screen.dart` — debug `biggestPotBB` literal
- `spectator/event_rankings_screen.dart` — `_bigBlind`
- `dealer/dealer_table_screen.dart` — state vars, dialog type, parsing
- `dealer/dealer_home_screen.dart` — state vars, display
- `dealer/dealer_qr_scan_screen.dart` — local vars, `_buildBlindCard` callback, `_startSession` params

**Services**
- `firebase_service.dart` — 3 function signatures (`createSession`, `saveHand`, `updateIndividualSession`)
- `local_storage_service.dart` — 2 function signatures (`saveSession`, `saveHand`)
- `dealer_service.dart` — 2 function signatures (`startSession`, `updateSessionBlinds`)

**Widgets**
- `session_summary_card.dart` — `biggestPotBB` field `int?` → `double?`
- `stack_range_circle.dart` — `bigBlind` param

### Display Helper: `formatBlindValue(double v)`
Located in `poker_game_state.dart` as a top-level function. Returns clean string:
- Whole numbers: `formatBlindValue(2.0)` → `'2'`
- Decimals: `formatBlindValue(0.25)` → `'0.25'`
- Trailing zeros stripped: `formatBlindValue(0.50)` → `'0.5'`

Used everywhere blinds appear as text: BB pill, blinds dialog initial values, session setup, individual session display.

### Cash vs Tournament Input
- **Cash games**: keyboard shows decimal point (`TextInputType.numberWithOptions(decimal: true)`), input allows `[\d.]`
- **Tournaments**: keyboard is integer-only (`TextInputType.number`), input filtered to `digitsOnly`
- Controlled via `allowDecimal` parameter in `_buildBlindTextField`

## What Did NOT Change
- Firebase/SQLite schemas — no migration needed (Firestore stores `num`, SQLite is dynamically typed)
- `RaiseSnapOverlay` — already uses `double` params
- `CurrencyService.formatCash()` — already handles decimals
- Bet calculation logic — all internal math already uses `double`
- l10n ARB files — `setupMustBeAtLeastBigBlind(int)` and `individualSetupStackValidation(int)` remain `int`; call sites pass `.toInt()`

## Verification
- `flutter analyze` — 0 new errors (all errors pre-existing in test/public_leaderboard/redeem_invitation files)
- `flutter test` — 245 pass, 19 fail (all 19 are pre-existing CSV export test failures)
- Backwards compatible with existing Firestore data (old `int` values read via `(num?)?.toDouble()`)
