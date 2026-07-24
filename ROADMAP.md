# ROADMAP — post-launch work queue

Living document (created 2026-07-23, launch night). Ordered by urgency.
Sources: `SECURITY_AUDIT_2026-07-23.md` (full findings + context),
`BUG_TRACKER.md` (hand-logging backlog), `todo/` items.

## STATUS — 2026-07-24

**v2.1.0+14 SUBMITTED to Google Play** (launch night). Shipped with it:
launch promo (free Pro month, admin-toggled), 11 locales, experience-level
+ language-aware AI analysis, active-player-aware analysis, audit fixes
(rules hardening deployed, backend rate-limited, API keys rotated), store
listing rewritten (`release-plan/store-listing.md` — trial claim removed).
iOS submission: pending (build + upload via Xcode).

Launch-window operational notes:
- Promo toggle (User Management) is ON — flip OFF after the club window;
  granted months keep running on their own (RC-enforced).
- Play advertising-ID warning: declaration purpose = Analytics; clears when
  build 14 supersedes the old artifact. Optional privacy-clean route
  (declare none + tools:node="remove" AD_ID) is an Update-1 candidate.
- Club features were NOT smoke-tested against the new Firestore rules
  scoping — do this FIRST in Update 1 (see item 3).

## Update 1 — "compliance + club" (target: well before Aug 31, 2026)

**HARD DEADLINE Aug 31, 2026** — Google Play rejects app UPDATES on Billing
Library < 8.0.0 after this date.

1. **Google Play Billing Library 8 migration** ⏰ — bump `purchases_flutter`
   8.11.0 → 9.15.1 (bundles Billing 8; verified compatible with pinned
   Flutter 3.38.10). Work = RevenueCat Dart API 8→9 breaking changes,
   contained to `SubscriptionService` + paywall; full sandbox re-test of all
   6 packages + promo entitlement flow.
2. **Forgot-password is BROKEN in production** (audit B9) — the live screen
   uses the custom `password_reset_codes` flow which Firestore rules deny.
   Users cannot reset passwords today. Cheapest: switch
   `forgot_password_screen.dart` to Firebase's built-in
   `sendPasswordResetEmail` (wrapped at `auth_service.dart:877`), then style
   the Firebase email template (todo/21). Proper: server-side custom-code
   flow via Cloud Function.
3. **Club rules hardening** (audit B5, deferred): members can still write
   `role: 'owner'` on their own member doc. Rules-only fix breaks admin/
   owner invitation redemption (`invitation_service.dart:191`) — needs
   server-validated invitations (Cloud Function or rules `get()` against the
   invitation doc). Ship together with a full club-feature smoke test
   (invite, roles, dealer session, live spectate, event rankings — untested
   against the new hands/opponent-stats rule scoping from launch night).
4. **user_notifications server-side sends** (audit B6 full fix): move
   notification creation into a Cloud Function so create-for-other-users can
   be locked down in rules (currently only size/type-capped — push-spam to
   arbitrary users is still possible by an authenticated attacker).

## Update 2 — security hardening round 2

5. **Rotate remaining keys** (audit B1/B2): backend `API_KEYS` and
   `RESEND_API_KEY` were ROTATED on launch night (2026-07-24, old key
   verified dead). Still to rotate: `SONIOX_API_KEY` (ships in the binary
   via the bundled `.env` asset).
6. **Move email + AI calls behind the backend** and remove `.env` from the
   Flutter asset bundle (use `--dart-define` for the few truly-client keys,
   e.g. RevenueCat public SDK keys which are safe to ship).
7. **Enable Firebase App Check** — with rules as the only real boundary,
   App Check blocks non-app clients wholesale.
8. **Backend**: swap in-memory rate limiter for Redis-backed if Render
   scales past one instance; constant-time API-key compare; remove default
   `secret_key` footgun (`config.py:16`).

## Update 3 — product backlog

**PostHog product analytics (minimal viable setup)** — the Data Warehouse
is already connected (RevenueCat + Resend sources synced; EU cloud, project
222008 — see `posthog-warehouse-report.md`), but NO app behavior events are
sent yet, so funnels/retention can't be built and the report's example
`revenuecat JOIN events` query has no `events` side. To close the gap:
- Add the PostHog Flutter SDK; `identify()` with the **Firebase uid** on
  every sign-in (so it matches RevenueCat's customer_id — the join key).
- Fire ~8 events that matter: `signup`, `hand_logged`, `session_ended`,
  `paywall_opened`, `subscribed`, `ai_analysis_used`, `promo_redeemed`,
  `tour_completed`.
- Build ONE funnel (signup → hand_logged → paywall_opened → subscribed)
  and ONE 7-day retention chart. That's ~90% of the value.
- Keep it lean: skip session replay + PostHog feature flags (we have our
  own Firestore flag system). ~half a day of work.
- Note: use the PostHog SDK's public/project API key (safe to ship), NOT
  the warehouse's read-scoped Resend/RevenueCat keys.

9. Club FCM pushes (club notifications are in-app only — TODO at
   `club_notification_service.dart:123`).
10. Referral system (double-sided free time via partner_grants + Cloud
    Function — designed 2026-07-22, not built).
11. Hand-logging deferred fixes (see BUG_TRACKER): D3 undo call-then-raise;
    HL-5t shown-cards tour step (post-hand, non-showdown only); HL-6
    hole-cards persistence (cheap now via cloudHandId); POKER_SEATING_RULES
    SB-entry/dead-button items.
12. Guest-mode machinery cleanup (dormant since sign-up-first funnel).
13. Session analytics backend endpoint (`/api/v1/analytics/sessions` never
    deployed).
14. Offline UX for post-tour chains (audit M5 — awaited Firestore writes
    dead-end silently offline; relaunch recovery exists).
15. Test-suite build-out phases 0-4 from `test/HAND_LOGGING_SPEC.md`
    (mocking deps, SessionManager lifecycle, widget tests).

## Standing constraints (do not regress)

- `session_results` amounts are client-written — never build cross-user
  features (leaderboards, club standings) on them without server-side
  validation (audit M6).
- Flutter pinned 3.38.10 until the 3.41 Firestore write regression is fixed
  upstream (`diary/2026-03-29`). Any Flutter bump = all Firebase plugins
  bump together.
- The l10n locale set is 11 and growing — enumerate `lib/l10n/app_*.arb`,
  never hardcode locale lists.
- Poker terms stay English in every locale; tier names (Free/Pro/Elite/
  Club) are product names in every language.
