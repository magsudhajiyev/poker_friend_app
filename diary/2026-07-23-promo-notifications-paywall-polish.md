# 2026-07-23 (PM) — Promo expiry notifications, paywall fixes, notification branding

Continuation of the launch-promo work (see
diary/2026-07-23-launch-promo-free-pro-month.md). All device-tested on
Android (MIUI) + iOS simulator.

## 1. Free-month expiry notification: 1 day before, guaranteed

- **Warn timing moved 3d → 1d** before expiry ("Only 1 day left of your
  free Pro access.", `promoNotifWarnBody` retranslated ×10 locales). The
  "has ended" notification at expiry time stays.
- **Heal-on-open resync** — `syncPromoExpiryReminders(context)`
  (onboarding_tour.dart), called post-frame in HomeScreen.initState every
  session. Previously the reminders were scheduled exactly once (at the
  post-tour promo paywall); if that moment was missed the reminders never
  existed. The sync re-derives the schedule from the `freeMonthGranted`
  user-doc marker + the live RC entitlement.
- **Idempotent**: `schedulePromoExpiryReminders` cancels its fixed ids
  (888890/888891) before rescheduling — safe to run every open.
- **Paid-upgrade guard**: reminders are only (re)scheduled while the
  entitlement's `store == Store.promotional`; otherwise they're CANCELLED —
  a paying subscriber must never see "your free month ends tomorrow".
- Timing source is RC's own `EntitlementInfo.expirationDate` — client never
  computes expiry.

## 2. Notification tap → paywall

- Payloads `promo_expiry_warning` / `promo_expired` route to
  `PaywallScreen(showSkip: true, preselectedTier: 0)`.
- **Warm/background tap**: `onDidReceiveNotificationResponse` → push via the
  global `navigatorKey`.
- **Cold start** (app terminated): the tap callback never fires — the
  payload arrives via `getNotificationAppLaunchDetails()` in `initialize()`;
  `_openPaywallWhenReady()` waits for navigator + signed-in auth (max 15s)
  + 800ms gate-settle before pushing.
- **navigatorKey injection is hot-reload-proof**: assigned in
  `MyApp.build` (every build), not only in `main()` — startup-only
  injection left the key null after a hot reload (main() doesn't re-run),
  which was the first "tap does nothing" cause.
- Product answer recorded: users CAN purchase while the promo is active —
  the store sub starts (and bills) at purchase time, it does not queue
  after the free month; the entitlement stays active through both.

## 3. Dev tool + Android scheduling gotcha

- Profile → Dev Tools → "Test Promo Expiry Notification" fires the real
  localized warn notification IMMEDIATELY (`debugFirePromoWarnNow`,
  kReleaseMode no-op) so tap-routing is testable.
- **Gotcha**: the first version scheduled it 10s out via `zonedSchedule` —
  on Android with `AndroidScheduleMode.inexactAllowWhileIdle` the OS
  batches inexact alarms and delays seconds-away alarms by MINUTES, which
  looks broken. Fine for the real 1-day-out reminder; never use scheduling
  to demo short-delay notifications.

## 4. Paywall: Pro showed USD on non-USD storefronts (committed 59d0c27)

The Dutch report: Pro monthly/annual in USD, Elite/Club correctly in EUR.
`packageById('pro_monthly')` found nothing because the Pro packages are the
offering's STANDARD packages (`$rc_monthly`/`$rc_annual`) while Elite/Club
are custom ids; the paywall silently fell back to hardcoded "$19.99"
strings — invisible in USD sandbox where fallback == real price. Fixed with
an alias map inside `packageById` (display + purchase paths both healed).
**Pattern**: a fallback that equals the developer-storefront value is
camouflage — always test prices on a non-USD sandbox storefront.

## 5. Trial messaging removed

Real-card purchase charged immediately despite the "7-Day Free Trial"
badge — the badge was a hardcoded string, never store data; whether a trial
applies is store config (intro offer per product in ASC/Play) + one-per-
Apple-ID-per-subscription-group eligibility. No intro offers are configured
→ owner chose to remove the badge outright (only the launch-promo
"1 MONTH FREE" badge remains, which is backed by a real grant) and the
compliance disclaimer was rewritten ×10 locales without the trial sentence
("After your free trial…" → charged-unless-cancelled wording).
If intro offers are ever configured later: re-add via
`storeProduct.introductoryPrice.price == 0` (per displayed package).

## 6. Android notification branding

Notifications showed a blank rounded blob: Android renders small icons
from the ALPHA CHANNEL ONLY, and we passed the opaque launcher icon.
- Generated `res/drawable-*dpi/ic_notification.png` (5 densities, 24-96px):
  the "final table" wordmark from `assets/ios_logo.icon/Assets/Property
  1=Logo-text.svg` rendered white-on-transparent (cairosvg + PIL).
- Local notifications: per-notification `icon:` + plugin default both point
  at `@drawable/ic_notification`; `largeIcon` stays the full-colour
  launcher. Small-icon tint red → brand teal (#62E3BC).
- **FCM pushes** (Cloud Functions) take their icon from the MANIFEST:
  added `com.google.firebase.messaging.default_notification_icon` +
  `default_notification_color` meta-data (+ `notification_color` in
  colors.xml).
- Native resources/manifest changes need a FULL rebuild — a hot restart
  keeps the old APK and throws `PlatformException(invalid_icon…)` (same
  process id in logs = no rebuild happened).

## 7. Misc

- Share Hand drawer modernized (committed fca1364): legacy bottom sheet →
  standard FormDrawer + single "Show hole cards" AppToggle (checkmark
  shares, dismiss cancels); `FormDrawer.heightFraction` widened to
  `double?` so AppSheet's hug-content mode is reachable.
- AI Analyzer button icon: brain (`Icons.psychology`) → `icons/figma_icons/
  sparkle.svg` tinted to the button text colour (analysis-complete state
  keeps the check icon).
- Pro opponent cap 20 → 30 (in the launch-promo commit; single source
  `FreeTierLimits.maxOpponentProfilesPro` + `paywallProFeature3` ×10).

## Verified on device
Dev-tools notification → shade shows teal wordmark → tap → paywall opens
with Pro pre-selected (warm + cold). Pending reminders confirmed queued
(888890 warn / 888891 ended) on the promo test account.
