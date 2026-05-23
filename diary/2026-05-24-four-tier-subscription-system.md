# 4-Tier Subscription System (Free / Pro / Elite / Club)

**Date:** 2026-05-24
**Status:** Complete — tested on Android sandbox
**Files changed:** 32 files, ~3000 lines net

---

## Overview

Replaced the binary free/premium system with a full 4-tier subscription model:

| Tier | Price (monthly) | Price (annual) | Key limits |
|------|----------------|----------------|------------|
| Free | — | — | 10 hands/session, 5 opponents, 30-day history |
| Pro | $19.99/mo | $159.99/yr | 50 hands/session, 15 opponents, 90-day history, 10 AI/mo, 30 exports/mo |
| Elite | $24.99/mo | $189.99/yr | Unlimited hands/opponents/history, 30 AI/mo, unlimited exports |
| Club | $59.99/mo | $449.99/yr | Everything Elite + club features |

Annual toggle shows "Save ~40%" label.

---

## Architecture Decisions

### Single Default RevenueCat Offering
All 6 packages live in the **default offering**, accessed by identifier via `packageById()`. Custom packages (`elite_monthly`, `elite_annual`, `club_monthly`, `club_annual`) are NOT exposed by RevenueCat's `.monthly`/`.annual` convenience getters — must use `availablePackages.firstWhere()`.

Package identifier constants in `SubscriptionService`:
- `pkgProMonthly` = `$rc_monthly`
- `pkgProAnnual` = `$rc_annual`
- `pkgEliteMonthly` = `elite_monthly`
- `pkgEliteAnnual` = `elite_annual`
- `pkgClubMonthly` = `club_monthly`
- `pkgClubAnnual` = `club_annual`

### Tier Hierarchy (entitlement cascade)
RevenueCat dashboard: Elite products grant both `pro` + `elite` entitlements. Club products grant `pro` + `elite` + `club`. This means all existing `isPremium` callsites (15+) continue working unchanged.

### Prices from RevenueCat at Runtime
No prices are hardcoded in ARB files. `storeProduct.priceString` is used with raw-string Dart fallbacks (`r'$19.99'` etc.) only as display placeholders while offerings load.

---

## Key Files Changed

### `lib/services/subscription_service.dart`
- Added `eliteEntitlement`/`clubEntitlement` constants
- Added `_isElite`, `_isClub` boolean state fields
- Added `currentTier` string getter (`'free'`/`'pro'`/`'elite'`/`'club'`)
- Added `_effectiveTier` (applies debug override first)
- Added `isPro`, `isElite`, `isClub` computed getters
- `isPremium` now computed from `_effectiveTier != 'free'` — fully backwards-compatible
- Replaced `_debugPremiumOverride` (bool) with `_debugTierOverride` (String?) — migrates old key on first load
- Added `setDebugTierOverride(String?)`, kept `setDebugPremiumOverride(bool?)` as wrapper
- Added `defaultOffering` getter (returns `_offerings?.current`)
- Added `packageById(String identifier)` — searches `availablePackages`, returns null if absent
- Added `pkgPro*/pkgElite*/pkgClub*` identifier constants
- `_updatePremiumStatus` now sets all 3 booleans; stream fires on any tier change (not just free↔paid)
- Added `refreshOnResume()` — invalidates cache + force-fetches; called by `WidgetsBindingObserver` in main.dart
- Added `_purchasedTierOverride` — set immediately on purchase to the bought tier, cleared when entitlements catch up; prevents sandbox lag from showing wrong tier (e.g. cancelled Elite still active when buying Pro)
- `fetchOfferings()` logs all available packages with identifier/type/price/productId

### `lib/services/free_tier_limits.dart`
Full rewrite to be tier-aware:
- `maxHandsPerSessionFree=10`, `maxHandsPerSessionPro=50`, `maxHandsPerTour=5`
- `maxOpponentProfilesFree=5`, `maxOpponentProfilesPro=15`
- `maxHandsPerSession` / `maxOpponentProfiles` computed getters based on current tier
- `sessionHistoryCutoff()` returns null (all-time) for Elite, 90d for Pro, 30d for Free
- `canLogAnotherHand()` uses `OnboardingState.isOnboardingActive` to cap tour at 5 hands with no upgrade dialog
- `canCreateAnotherOpponent()` tier-aware
- All dialogs (`showHandsLimitDialog`, `showOpponentLimitDialog`) use l10n and show tier-appropriate upgrade message

### `lib/models/hand_state_machine.dart`
- Added `OnboardingState.isGuidedHandActive` guard at top of `_saveHandToFirebase()` — tour hands are never persisted (no Firestore write, no stats update, no opponent stats)

### `lib/screens/paywall_screen.dart`
Full overhaul:
- Removed 3-offering approach (`_proOffering`/`_eliteOffering`/`_clubOffering`)
- Added `_visibleTierIndices` — dynamically filtered; tiers without packages on current platform are hidden
- `_selectedVisibleIndex` — index within visible tiers, auto-selects Elite (tier 1) when available
- `_packageForTier(tierIndex, annual)` uses `SubscriptionService.packageById()`
- `_resolvePackage()` async helper — tries preferred billing period, falls back to other, retries fetch if needed
- Purchase flow uses resolved `Package` object directly
- Elite pre-selected with "BEST VALUE" lime badge
- Button label varies: "Start with Pro" / "Get Elite" / "Get Club"
- Button width `screenWidth * 0.85` (responsive)
- All prices from RevenueCat `storeProduct.priceString` with fallbacks

### `lib/screens/statistics_screen.dart`
- Added `_buildLockedSection()` helper: blur overlay (`ImageFilter.blur(sigmaX:6, sigmaY:6)`) + dark overlay + lock icon + Upgrade button for free users
- Wrapped `_buildGeneralSessionStats()`, `_buildCashSessionStats()`, `_buildTournamentSessionStats()` — `_buildOverallStats()` (VPIP/PFR etc.) remains visible to all

### `lib/screens/hand_actions_screen.dart`
AI quota system:
- Free → paywall gate (no analysis at all)
- Pro → 10/month (`monthly_ai_analysis_count_pro` key)
- Elite → 30/month (`monthly_ai_analysis_count_elite` key)
- Club/admin → unlimited
- Both keys reset simultaneously on month boundary
- `_showAnalysisQuotaDialog()` with tier-aware CTA (Pro shows "Upgrade to Elite", Elite shows "OK" only)

Export quota system:
- Free → paywall gate
- Elite/Club → unlimited
- Pro → 30/month (`monthly_export_count` key)
- Quota dialog with "Upgrade to Elite" button

### `lib/screens/session_analytics_screen.dart`
- Session export quota: same pattern as hand export, keys `monthly_session_export_count`/`monthly_session_export_month`

### `lib/screens/session_history_screen.dart` / `firebase_service.dart` / `local_storage_service.dart`
- All 3 session history date filters replaced with `FreeTierLimits.sessionHistoryCutoff()` null-check pattern

### `lib/screens/my_opponents_screen.dart`
- Counter subtitle: Elite = clean count, Pro = N/15, Free = N/5
- Added `premiumStatusStream` subscription in `initState` → `setState` on tier change → limits enforced immediately after purchase without restart

### `lib/screens/profile_screen.dart`
- Debug tier picker: `DropdownButton<String?>` with null/pro/elite/club options
- `_subscriptionPillLabel()` helper: shows plan name (Pro/Elite/Club) when subscribed, "Upgrade" when free
- Added `premiumStatusStream` subscription for live UI updates

### `lib/widgets/navigation_drawer.dart`
- Subscription pill label: shows tier name when subscribed, "Upgrade" when free
- Added `premiumStatusStream` subscription for live UI updates
- Added `_subscriptionPillLabel()` helper using `profileTier*` l10n keys

### `lib/main.dart`
- `PokerTrackerApp` converted from `StatelessWidget` to `StatefulWidget`
- Added `WidgetsBindingObserver` → `didChangeAppLifecycleState` → calls `SubscriptionService.refreshOnResume()` on `AppLifecycleState.resumed`

### `lib/l10n/app_en.arb` + all 6 language files (de/es/fr/pl/pt/ru)
57 new keys added and translated:
- `freeTierHandLimit*`, `freeTierOpponentLimit*`, `freeTierUpgrade`, `freeTierNotNow`
- `quotaMonthlyLimitTitle`, `quotaAiLimit*`, `quotaExportLimit*`, `quotaUpgradeToElite`, `quotaOk`
- `statsLockedTitle/Subtitle/Upgrade`
- `paywallBestValue`, `paywallWelcomeElite/Club`, `paywallStartWithPro`, `paywallGetElite/ClubAction`
- `paywallProFeature1-5`, `paywallEliteFeature4-8`, `paywallClubFeature1-4`
- `profileTierOverride`, `profileTierOverride*Subtitle`, `profileTierFree/Pro/Elite/Club`
- `paywallAnnualSave` updated to "Save ~40%" in all 7 languages

### `ios/Products.storekit`
- Updated `pro_monthly` $29.99 → $19.99, `pro_annual` $249.99 → $159.99
- Added `elite_monthly` ($24.99), `elite_annual` ($189.99), `club_monthly` ($59.99), `club_annual` ($449.99) in subscription group `ECD86BD7`

---

## Bugs Fixed During Implementation

### 1. RevenueCat `CONFIGURATION_ERROR` on offerings fetch
**Cause:** RevenueCat dashboard not yet configured with Elite/Club products.
**Fix:** Added fallback prices in Dart (raw strings `r'$19.99'`) so UI displays placeholder while offerings load. Removed hardcoded price keys from ARB files (would have been stale when prices change).

### 2. `AppColors.accentTertiary` not found
**Cause:** Constant doesn't exist — correct name is `AppColors.limeGreen`.
**Fix:** Changed all references.

### 3. Dollar signs in string literals (`'$19.99'` → interpolation error)
**Cause:** Single-quoted Dart strings treat `$` as interpolation start.
**Fix:** Raw strings `r'$19.99'`.

### 4. ARB FormatException on price keys with escaped dollar signs
**Cause:** `\$19.99` is invalid in ARB format.
**Fix:** Removed all price keys from ARB entirely — prices come from RevenueCat at runtime.

### 5. Limits not enforced after purchase (no UI rebuild)
**Cause:** `SubscriptionService` updates static fields after purchase but screens never rebuild — they read static getters only at build time.
**Fix:** Added `premiumStatusStream` subscriptions to `MyOpponentsScreen`, `ProfileScreen`, and `AppNavigationDrawer`. Stream now fires on any tier change (was only free↔paid before).

### 6. "Upgrade" button stays after subscribing
**Cause:** Nav drawer and profile screen header pill hardcoded `l10n.navDrawerUpgrade`/`l10n.profileUpgrade`.
**Fix:** Both now call `_subscriptionPillLabel()` which returns tier name (Pro/Elite/Club) or "Upgrade" for free tier.

### 7. App doesn't detect external cancellation (from OS Settings)
**Cause:** `CustomerInfoUpdateListener` only fires for in-app RevenueCat events — not for cancellations made in iOS/Android Settings.
**Fix:** `PokerTrackerApp` now implements `WidgetsBindingObserver`. On `AppLifecycleState.resumed`, calls `SubscriptionService.refreshOnResume()` which invalidates cache and force-fetches from Apple/Google.

### 8. Tier shows wrong after cancel+repurchase (sandbox lag)
**Cause:** In sandbox, a cancelled subscription's entitlement can remain active for several minutes. After cancelling Elite and buying Pro, RevenueCat returned both `elite=active` and `pro=active` — `currentTier` resolved to `'elite'`.
**Fix:** Added `_purchasedTierOverride` — set to the just-purchased tier immediately on successful purchase (determined from package identifier), takes precedence over entitlement-derived tier. Cleared automatically when `_updatePremiumStatus` sees entitlements that match or exceed it (using rank comparison), or on app resume.

---

## RevenueCat Dashboard Requirements

The following must be configured in the RevenueCat dashboard (out of band):

| Entity | Details |
|--------|---------|
| Entitlements | `pro`, `elite`, `club` |
| Products | `pro_monthly`, `pro_annual`, `elite_monthly`, `elite_annual`, `club_monthly`, `club_annual` |
| Default offering | All 6 packages attached with identifiers matching constants above |
| Entitlement attachment | pro products → `pro`; elite products → `pro`+`elite`; club products → `pro`+`elite`+`club` |

---

## Testing Checklist

| Scenario | Expected |
|----------|----------|
| Free: tap Add Opponent at limit (5) | Upgrade dialog shown |
| Pro: tap Add Opponent at limit (15) | Upgrade dialog shown |
| Elite: no opponent limit | Can add unlimited opponents |
| Free: Statistics screen | General/Cash/Tournament sections blurred |
| Pro/Elite: Statistics screen | All sections visible |
| Free: tap AI Analyze | Paywall shown |
| Pro: 10th analysis used | Quota dialog with "Upgrade to Elite" |
| Elite: 30th analysis used | Quota dialog with "OK" only |
| Free: tap export | Paywall shown |
| Pro: 30th export used | Quota dialog with "Upgrade to Elite" |
| Elite: export | Always works, no dialog |
| During guided tour | Max 5 hands, no upgrade dialog, hands NOT saved to Firestore |
| Purchase Pro | Pill shows "Pro", limits change immediately |
| Cancel in Settings, return to app | Tier reverts to free on resume |
| Cancel Elite, buy Pro in same session | Shows Pro (not Elite) |
| Debug picker: set Elite | All Elite features unlocked |
| Paywall: Elite pre-selected | "BEST VALUE" badge visible |
| Paywall: annual toggle | Shows "Save ~40%" |
