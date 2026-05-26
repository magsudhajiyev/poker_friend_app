# Pre-Submission Compliance Fixes & Club Tier Gating

**Date:** 2026-05-27
**Status:** Complete — tested on iOS device (sandbox)
**Files changed:** 13 files (+ 7 generated l10n files)

---

## Overview

Batch of fixes to pass App Store (iOS) and Google Play (Android) review, plus club tier gating enforcement.

---

## 1. Paywall Compliance (Apple 3.1.2 / Google Subscriptions Policy)

### Disclaimer text updated (7 ARB files)
**Before:** `"Subscriptions auto-renew. Cancel* anytime\nfrom your account settings."`
**After:** `"Subscriptions auto-renew. After your free trial, you'll be charged the listed price unless you cancel at least 24 hours before the period ends. Cancel anytime in your account settings."`

Covers: auto-renewal notice, free trial → paid transition, 24-hour cancellation window, how to cancel. All 7 languages updated.

### Asterisk removed from subtitle (7 ARB files)
`"Upgrade or cancel* at anytime"` → `"Upgrade or cancel at any time"`

### Fallback annual prices corrected (`paywall_screen.dart`)
Updated from `$149.99/$179.99/$439.99` to `$159.99/$189.99/$449.99` to match actual App Store Connect prices. Fallbacks only shown while RevenueCat offerings are loading.

---

## 2. Current Plan Indicator (`paywall_screen.dart`, 7 ARB files)

When a subscribed user opens the paywall:
- Their current tier shows a **"Current Plan"** cyan badge (replaces BEST VALUE on that card)
- Trial badge hidden on current plan card
- CTA button shows "Current Plan" (dimmed, disabled) when current tier selected
- Current tier pre-selected on open
- New `preselectedTier` parameter allows auto-selecting + auto-scrolling to a specific tier

New l10n key: `paywallCurrentPlan` — translated in all 7 languages.

---

## 3. Club Tier Gating (`navigation_drawer.dart`)

**Gate:** "Register Club" in the navigation drawer now requires Club tier.
- Non-Club users see the paywall pre-scrolled to the Club card
- Once a club is created, all members (dealers, players) operate freely regardless of their own subscription

**Paywall copy updated** (7 ARB files):
- `"Club management & member roles"` → `"Create & run your own club"`
- `"Live dealer voice logging"` → `"Invite dealers & manage members"`
- `"Multi-table events with rankings"` → `"Host multi-table events with live rankings"`

This clarifies that Club tier is a "club creator license" — the owner pays, members participate free.

---

## 4. Security: Debug Override Gated for Release

### `subscription_service.dart`
- `_loadDebugOverride()` and `setDebugTierOverride()` now return immediately when `kReleaseMode` is true
- Debug tier override cannot activate in production builds

### `profile_screen.dart`
- Removed hardcoded `test1@test.com` email bypass for dev tools
- Dev tools section only visible when `!kReleaseMode` (debug builds only)

---

## 5. iOS Encryption Declaration (`Info.plist`)
Added `ITSAppUsesNonExemptEncryption: false` — app uses only standard HTTPS/TLS via Firebase, qualifies for exemption.

---

## 6. Bug Fixes

### `redeem_invitation_screen.dart`
Added missing `import '../models/club_member.dart'` — fixes `ClubRole.displayName` compile error.

### `global_bottom_nav_bar.dart`
Reduced nav item text line height from 1.47 to 1.2 — fixes 2px bottom overflow in the Column (icon 31px + text 19px > 50px constraint).

---

## 7. Purchase Error Handling (`subscription_service.dart`)

User cancellations (`PlatformException` with `userCancelled: true`) now logged as info instead of error. Previously fell through to the generic `catch` block and was reported to Crashlytics as an error.

---

## Key Decisions

- **Club gating model:** Only club registration requires Club tier. All other club features (events, dealing, settings) are ungated once the club exists. The club owner pays, members participate free.
- **Trial badges:** Shown on all tiers (all 6 products have free trials in App Store Connect). Monthly = 7-day, Annual = 14-day. Hidden on the user's current plan card.
- **Pre-selected tier priority:** `preselectedTier` param > current plan > Elite > first visible.
