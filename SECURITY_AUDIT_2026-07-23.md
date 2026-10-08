# Production Audit — 2026-07-23 (pre-launch)

Three-lens audit (security / fragility / release-readiness), all findings
verified against code. Status legend: 🔴 blocker · 🟠 high · 🟡 medium ·
✅ fixed · ⏳ needs owner action · 📋 accepted/deferred.

## 🔴 Launch blockers

| # | Finding | Where | Status |
|---|---------|-------|--------|
| B1 | Backend `X-API-Key` hardcoded in committed source; same key is the only auth on paid endpoints | `session_export_service.dart:15` | ✅ moved to EnvConfig; ⏳ ROTATE the key (it is in git history forever) |
| B2 | `.env` (Resend/AI/Soniox keys) ships inside the app bundle as a Flutter asset — extractable from any IPA/APK | `pubspec.yaml` assets | ⏳ rotate keys post-launch; long-term: move email/AI calls server-side, use --dart-define. Accepted for launch window with rotation plan |
| B3 | Claude endpoints: no rate limit, no max-token cap → unbounded Opus spend with extracted key | engine `analyze.py`, `claude_client.py` | ✅ rate limiting + spend caps added |
| B4 | `/export/session-email` = open email relay from trusted domain | engine `export.py` | ✅ rate limited + content/subject sanitized + size caps |
| B5 | Club member can self-escalate to owner/admin (member doc update unrestricted) | `firestore.rules` members | 📋 DEFERRED to the club update: invitation redemption legitimately self-creates admin/owner member docs (invitation_service.dart:191), so a rules-only fix breaks admin invites and clubs can't be smoke-tested tonight. Proper fix: server-validated invitations |
| B6 | Any user can create `user_notifications` targeting anyone → FCM push spam via our own function | `firestore.rules` | 🟠 PARTIAL: cross-user create is load-bearing (club invitations) — content size/type caps added; full fix = server-side sends (owner action list) |
| B7 | `poker_hands` + `opponent_stats` read/writable by ANY authenticated user (others' hole cards, stat tampering) | `firestore.rules` | ✅ scoped (see rules comments for the dealer/participant carve-outs) |
| B8 | `users/{uid}` world-readable incl. emails (unauthenticated scraping) | `firestore.rules:41` | ✅ authenticated-only |
| B9 | `password_reset_codes` has NO rules block | `password_reset_service.dart` | ⏳ VERIFIED BROKEN: the live forgot-password screen uses this flow and the rules deny it — reset cannot work in production. Decide: switch screen to Firebase's built-in sendPasswordResetEmail (already wrapped at auth_service.dart:877, 1-hour change) or build the server-side custom flow |
| B10 | Super-admin = unverified email string; no email-verification gate anywhere | rules `isSuperAdmin()`, `feature_flag_service.dart:46` | ✅ `email_verified` required in rules (owner account verified first) |

## 🟠 High (fix in launch window)

| # | Finding | Where | Status |
|---|---------|-------|--------|
| H1 | Promo reminder heal-on-open CANCELS reminders when it races RC init (null customerInfo treated as "inactive") | `onboarding_tour.dart` sync | ✅ null = unknown → no-op; tests added |
| H2 | `maybeShowPostTourPaywall` burns once-ever flag BEFORE showing; untimed RC work in between → paywall lost forever on hang+kill | `onboarding_tour.dart` | ✅ mark after show + timeout on detection |
| H3 | Notification tap → paywall: no dedup/reentrancy → stacked paywalls from tray | `notification_service.dart` | ✅ routing guard added |
| H4 | `_detectLaunchPromo` single-shot read races the grant function → promo silently downgraded for fast users | `onboarding_tour.dart` | ✅ short retry added |
| H5 | Backend: wildcard CORS with credentials; raw exception strings to clients | engine `main.py`, `analyze.py` | ✅ origins restricted, errors generic |

## 🟡 Medium

| # | Finding | Status |
|---|---------|--------|
| M1 | ~750 debugPrints active in release, some log emails/uids | ✅ release no-op override in main() |
| M2 | Logger file unbounded growth | ✅ size-capped |
| M3 | Stale prefetch on logout→re-login (same-session) can replay onboarding | ✅ cleared in signOut |
| M4 | `$e` shown raw in admin SnackBars (5 spots) | ✅ UserFacingError |
| M5 | Offline: post-tour chains await server-acked writes → silent dead-ends (relaunch recovers) | 📋 accepted (recovery exists) |
| M6 | `session_results` client-forgeable — fine until any cross-user feature trusts them | 📋 documented constraint |
| M7 | Club FCM pushes are TODO (in-app only) | 📋 product decision |
| M8 | INTERNET permission only in debug manifest (merged by Firebase in practice) | ✅ declared explicitly |
| M9 | Prompt injection via player/opponent names into Claude prompt (cost/steering, bounded by tool schema) | ✅ length caps + sanitization |
| M10 | Paywall `_onContinue` retry recursion without mounted check | ✅ guarded |
| M11 | Cold-start notification paywall can show fallback prices until RC init | 📋 accepted (Continue retries) |

## ⏳ Owner actions (cannot be done from code)

1. **Rotate the backend API key** (Render env `API_KEYS` + app `.env` AI_API_KEY + the export key) — the old one is in git history.
2. **Rotate RESEND_API_KEY and SONIOX_API_KEY** after launch window (they ship in the binary; rotation limits the blast radius of B2 until the server-side move).
3. Verify **forgot-password** works on production (B9) — if broken, prioritize the server-side reset flow.
4. Confirm the super-admin Google account shows `emailVerified: true` (checked during B10 fix).
5. Post-launch: enable **Firebase App Check**; move email + AI calls AND user-notification sends behind the backend; delete `.env` from the asset bundle.
6. Deploy checklist for these fixes: `firebase deploy --only firestore:rules` (rules validated, NOT yet deployed) · push poker_friend_engine (rate limit/CORS/sanitization, NOT yet pushed) · commit+push app changes · then smoke-test: club invite, dealer session, live session spectate, opponent stats update, admin screens, promo signup.

## ✅ Verified clean (no action)

Dev tools/debug overrides release-gated · no test-account bypasses · global
error handling → Crashlytics · EnvConfig graceful degradation · iOS usage
descriptions + encryption declaration · fresh-install empty states · all 11
locales ICU-valid · `.env` not in git · `grantFreeMonthOnSignup` hardening
(fail-closed toggle, new-account guard, RC-server-enforced entitlement) ·
client tier gates only affect attacker's own data.
