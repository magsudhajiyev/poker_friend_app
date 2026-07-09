# Partner Grants System — Email, Duration Expiry, Race Condition Fix

**Date**: 2026-07-08
**Branch**: design_v2

## What Was Built

Admin-managed partner grants: super-admin can grant users free tier access (Pro/Elite/Club) with a set duration, email notification, and in-app notification.

### Features Added
1. **Email notification** — when admin grants a tier, user receives a styled email (teal/mint theme, tier-specific feature list, duration info) via Resend API
2. **Duration with expiry** — grants expire after 1 week, 1 month, or 3 months. Client-side `partnerTier` getter returns `null` for expired grants immediately (no wait for Firestore cleanup). Auto-expire writes `status: 'expired'` to Firestore fire-and-forget.
3. **Admin UI** — duration pill selector in Add/Edit sheets, expiry countdown on grant cards (teal for normal, amber when <7 days), three-state status badge (Active/Expired/Revoked), reactivation with new duration

### Bug Fix: Race Condition on Login
**Problem**: `PartnerGrantService.init()` was called with `unawaited()` in all 5 sign-in paths in `auth_service.dart`. The Firestore snapshot listener started but returned immediately — by the time the UI rendered, `_cachedGrant` was still `null`, so the user appeared as free tier.

**Fix**:
- `init()` now uses a `Completer` to await the first Firestore snapshot before returning, with a 3-second timeout
- All 5 auth_service call sites changed from `unawaited(PartnerGrantService.init(...))` to `await PartnerGrantService.init(...)`
- `auth_wrapper.dart` (app resume path) left as fire-and-forget — `notifyPartnerGrantChanged()` handles the reactive update there

## Files Modified
- `lib/services/partner_grant_service.dart` — expiration logic, duration params, email call, Completer-based init
- `lib/services/email_service.dart` — `sendPartnerGrantEmail()` + HTML template
- `lib/screens/admin/partner_grants_screen.dart` — duration pills, expiry display, expired status handling
- `lib/services/auth_service.dart` — removed `unawaited()` from 5 `PartnerGrantService.init()` call sites

## Key Details
- `expiresAt` stored as Firestore `Timestamp`
- `_autoExpire()` uses `_isAutoExpiring` bool guard to prevent concurrent writes
- `formatRemainingTime(Timestamp?)` — "5 days left", "2 months left", "Expired", "No expiry"
- `durationLabel(Duration?)` — "1 week", "1 month", "3 months", "indefinitely"
- Email from: `admin@finaltable.io`, subject: "You've been upgraded to {Tier}!"
- Duration pills snap to nearest predefined option when editing existing grants

## Important Note
Partner grants require the new app version — production users on the shipped version don't have `PartnerGrantService` code and won't see the upgrade until the next release.
