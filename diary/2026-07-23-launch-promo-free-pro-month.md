# 2026-07-23 — Launch promo: free Pro month for new sign-ups (+ skip-path paywall, Pro cap 30, onboarding-replay fix)

## 1. Free Pro month launch promo (admin-toggled, RevenueCat-enforced)

**Product**: printed QR visit cards for the owner's local club. While a
super-admin toggle is ON, every new sign-up automatically receives 1 month of
free Pro. The owner turns the toggle off after the launch window; newcomers
after that get nothing, already-granted months run to their expiry. (This
replaced an earlier promo-code design — no code entry, no landing page.)

### Architecture — why RevenueCat promotional entitlements

The owner's two hard requirements:
1. Users must be tied to RevenueCat so the expiry lifecycle is real.
2. Expiry must be bulletproof — no client-side clock/flag that could bug
   into indefinite free Pro.

Both are satisfied by **RC promotional entitlements** granted server-side:
- The grant lands on `app_user_id = Firebase uid` (`Purchases.logIn(uid)`
  runs on every sign-in path), making the user a real RC subscriber visible
  in the dashboard with a server-computed `expires_date`.
- Expiry is enforced by **RC's servers** — the same machinery that lapses
  paid subscriptions. The client has ZERO new expiry code: when the month
  lapses RC flips `isActive=false` and the existing
  `_updatePremiumStatus` / `refreshOnResume` paths revert the tier.
  Device-clock manipulation is irrelevant.
- Partner grants (client-side Firestore expiry check) were deliberately NOT
  used for this reason.

### Server: `grantFreeMonthOnSignup` (functions/src/index.ts)

`onDocumentCreated("users/{userId}")` — fires exactly once per new user
(`users/{uid}` is only created by `AuthService._createUserDocument`, guarded
by `!doc.exists` in `ensureUserDocument`). Steps, all fail-closed:
1. Toggle gate: `app_config/promotions.freeMonthOnSignup !== true` → return.
2. Strict-new guard: `admin.auth().getUser(uid).metadata.creationTime` older
   than 1 hour → return (protects against doc backfills for old accounts).
3. **Ensure the RC customer exists**: `GET /v1/subscribers/{uid}` —
   returns-or-creates. ⚠️ CRITICAL: the promotional POST does NOT
   auto-create subscribers; without this GET the grant 404s
   (`code 7259 "The subscriber was not found"`) because the trigger fires
   ~2s after doc creation — before the client's `Purchases.logIn(uid)`
   round-trip registers the uid with RC. Found via `firebase functions:log`
   on the first live test.
4. Grant: `POST /v1/subscribers/{uid}/entitlements/pro/promotional` with
   `{"duration":"monthly"}`, `Authorization: Bearer <secret>`.
5. Marker on success: `users/{uid}.freeMonthGranted = true` (+`GrantedAt`).
   An update cannot re-fire an onCreate trigger.
6. Any RC failure: log + return, no marker — user just sees the normal
   paywall (owner can hand-grant via partner grants).

Secret: `REVENUECAT_SECRET_API_KEY` via `defineSecret` (first secret in this
functions codebase). Must be an RC **V1** secret key — V2 keys (permission-
scoped) are rejected by the v1 REST API. Deployed to us-central1 (default,
matches existing functions and the Dart callable default).

### Admin toggle

- Firestore: `app_config/promotions { freeMonthOnSignup: bool }` — covered
  by the existing `app_config/{docId}` rules (read: authenticated, write:
  super-admin). No rules change was needed.
- UI: switch card at the top of `PartnerGrantsScreen` ("User Management"
  under super-admin profile section) — optimistic write with revert+snackbar
  on failure. Toggle OFF blocks new grants instantly, no deploy.

### Client: promo paywall variant

- `PaywallScreen(launchPromo: true)`: Pro pre-selected, `_isAnnual = false`
  (monthly display), the Pro card's trial pill shows **"1 MONTH FREE"**
  (`promoFreeMonthBadge`) instead of "7-Day Free Trial", and a post-frame
  celebration dialog ("A gift from us 🎁 / Enjoy your 1 month of Pro
  experience, on us!") in the AppDialog + DialogActionBar.single style.
- Detection (`_detectLaunchPromo` in onboarding_tour.dart): requires BOTH
  `users/{uid}.freeMonthGranted == true` AND a live RC `pro` entitlement
  after `refreshOnResume()`. Any failure → normal paywall, never broken.
- Expiry courtesy reminders (`NotificationService.schedulePromoExpiryReminders`,
  ids 888890/888891): local notifications at `expiresAt − 3d` and `expiresAt`,
  scheduled from **RC's own** `EntitlementInfo.expirationDate`
  (purchases_flutter 8.11.0). Cosmetic only — entitlement truth never
  depends on them. Strings passed in from the call site (l10n).
- l10n: 7 new keys (`promoFreeMonthBadge`, `promoWelcomeTitle/Body`,
  `promoNotifWarn/EndedTitle/Body`) in **all ten** arbs (it included).

### Ops runbook

- Kill switch: User Management toggle (instant) — granted months keep
  running, which is intended.
- Verify a grant: RC dashboard → customer by uid → `pro` entitlement, store
  "promotional", expiry visible ~30 days out.
- Debug: `firebase functions:log --only grantFreeMonthOnSignup` — success
  logs "Free Pro month granted to new user <uid>".
- Key hygiene: rotate the RC secret post-launch
  (`firebase functions:secrets:set REVENUECAT_SECRET_API_KEY` + redeploy).

## 2. Post-tour paywall shown immediately on skip (all paths unified)

Previously, skipping the tour only set `postTourPaywallPending` and the
paywall appeared on the NEXT Home visit — users who skipped saw nothing.
Now `maybeShowPostTourPaywall(context)` (onboarding_tour.dart) is the single
once-ever implementation: guard `wasPostTourPaywallShown` → mark shown →
clear pending → `_detectLaunchPromo` → push `PaywallScreen(showSkip: true,
launchPromo: …)`. Callers:
- coach-mark skip (`createOnboardingCoachMark.onSkip`) — pending flag set
  first for kill-safety, then immediate show after a 350ms overlay-dismiss
  delay;
- mid-hand skip (`guided_hand_overlay._finishOnboarding`) — same;
- tour completion (`showPostTourWrapUp`) and guest chain
  (`completeGuestSignup`);
- Home's pending-flag branch — now purely kill-recovery (and gained the
  promo variant it previously lacked).

## 3. Pro tier opponent cap: 20 → 30

Single source `FreeTierLimits.maxOpponentProfilesPro = 30`
(free_tier_limits.dart) — cap check and both limit dialogs use it via
placeholders, so no dialog string changes. Paywall display:
`paywallProFeature3` = "30 opponent profiles" in all ten arbs.

## 4. Bug fix: onboarding sometimes replayed after completion

**Symptom**: finish the onboarding questions → splash replays → onboarding
starts over (intermittent).

**Root cause — stale startup prefetch**: registration resets to '/'
(SplashScreen), which prefetches `users/{uid}` into a static
(`AuthService._prefetchedUserDoc`) — captured with
`hasCompletedOnboarding:false`. `consumePrefetchedUserDoc()` intentionally
does NOT clear (multiple consumers per startup), and the only clear site was
Home's first render — which a brand-new user doesn't reach before
OnboardingFlow. After completing onboarding, the '/' reset starts a NEW
prefetch that RACES the AuthWrapper gate; on slow networks the gate's
`OnboardingService.hasCompletedOnboarding()` consumed the STALE pre-
onboarding snapshot → `'onboarding_skip'` → OnboardingFlow replayed.
(Username check usually survived via UsernameService's in-process cache,
which is why the replay typically showed the survey.)

**Fix**: `prefetchUserDocument()` now clears the static SYNCHRONOUSLY before
starting the network read — every '/' reset invalidates the old snapshot, so
a consumer that loses the race falls back to a fresh Firestore read instead
of stale data. Belt-and-braces: `OnboardingFlow._completeOnboarding()` also
clears right before its '/' reset (covers the splash 10s-safety-net path
where the prefetch never runs).

**Pattern for the future**: any cached user-doc snapshot must be invalidated
at every navigation reset that re-runs the startup gate, or gate flags
written since the snapshot will be lost. See "Cache staleness" in
CLAUDE.md's UI bug patterns.

## Files touched

- functions/src/index.ts (grantFreeMonthOnSignup)
- lib/screens/admin/partner_grants_screen.dart (toggle card)
- lib/screens/paywall_screen.dart (launchPromo variant + dialog)
- lib/onboarding/onboarding_tour.dart (_detectLaunchPromo,
  maybeShowPostTourPaywall, skip-path immediate paywall)
- lib/onboarding/guided_hand_overlay.dart (mid-hand skip → paywall)
- lib/screens/home_screen.dart (pending branch → shared helper)
- lib/services/notification_service.dart (promo expiry reminders)
- lib/services/free_tier_limits.dart (Pro cap 30)
- lib/services/auth_service.dart (prefetch invalidation)
- lib/screens/onboarding/onboarding_flow.dart (prefetch clear on complete)
- lib/l10n/app_*.arb ×9 tracked (+ app_it.arb, committed with the Italian
  language work)
