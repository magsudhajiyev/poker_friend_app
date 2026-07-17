# Firestore Transaction FieldPath Crash Fix

**Date**: 2026-07-17
**Severity**: Critical (SIGABRT crash — app terminates)
**Affected builds**: 1.0.3 (builds 11, 13, 14) — 139 crash events

## Symptom

App crashes with `EXC_CRASH (SIGABRT)` during hand saving. The native Firestore SDK throws `InvalidArgument` from `FieldPath::FromDotSeparatedStringView` inside a `transaction.update()` call. The crash happens on a background dispatch thread (Thread 29), not the main thread.

## Root Cause

`UserStatsService.updateStatsAtomic()` passes dynamic map keys (position-based Firestore dot-paths like `positionHandsPlayed.BTN`) to `transaction.update()`. If a position value somehow contains an invalid character (empty segment, leading/trailing dot, consecutive dots), the native Firestore C++ layer crashes before any Dart exception can be caught.

The previous guard (`pos.contains('.')`) only protected against dots but not other edge cases that could produce invalid Firestore field paths.

## Fix

**File**: `lib/services/user_stats_service.dart`

1. **Replaced dot-check with a strict whitelist** of known safe position names:
   ```dart
   static const _safePositionNames = {
     'BTN', 'SB', 'BB', 'UTG', 'UTG+1', 'UTG+2',
     'LJ', 'HJ', 'CO', 'BTN/SB', 'Empty',
     'P1', 'P2', 'P3', 'P4', 'P5', 'P6', 'P7', 'P8', 'P9',
   };
   ```
   Any position not in the whitelist is silently skipped (no crash, stats just skip position breakdown for that hand).

2. **Added defensive key sanitization** before `transaction.update()`:
   ```dart
   updates.removeWhere((key, _) =>
       key.isEmpty || key.startsWith('.') || key.endsWith('.') || key.contains('..'));
   ```
   This is a belt-and-suspenders guard — even if a bad key somehow gets into the map, it's stripped before reaching native Firestore.

## Key Stack Trace

```
FieldPath::FromDotSeparatedStringView (field_path.cc:99)
  → ThrowInvalidArgument (exception.h:94)
  → [FSTUserDataReader parsedUpdateData:] (FSTUserDataReader.mm:223)
  → [FIRTransaction updateData:forDocument:] (FIRTransaction.mm:108)
  → FLTTransactionStreamHandler (FLTTransactionStreamHandler.m:98)
```

## All transaction.update() call sites reviewed

| Service | File | Dynamic keys? | Safe? |
|---------|------|--------------|-------|
| UserStatsService | user_stats_service.dart:120 | Yes (position paths) | **Fixed** |
| OpponentStatsService | opponent_stats_service.dart:171 | No (all hardcoded) | Safe |
| SeatService | seat_service.dart:125, 276 | No (all hardcoded) | Safe |
| UsernameService | username_service.dart:87, 158 | No (all hardcoded) | Safe |

## Notes

- dSYMs still need uploading to Firebase Crashlytics (builds 11, 13, 14) to see symbolicated crash reports and breadcrumbs
- The exact rogue field path value that triggered the crash is unknown without symbolicated logs
- Position names come from `PokerPositions` in `lib/utils/poker_positions.dart` — all hardcoded, but the whitelist adds defense-in-depth
