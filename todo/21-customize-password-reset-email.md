# Customize Firebase password-reset email

**Status:** TODO

## Problem
The default Firebase Auth password-reset email is ugly/untrustworthy:
- Subject: "Reset your password for project-311745459306" (uses raw Firebase
  project number instead of app name)
- From: `noreply@poker-tracker-52df8.firebaseapp.com` (default Firebase domain)
- Link: `poker-tracker-52df8.firebaseapp.com/__/auth/action?...`
- Signature: "Your project-311745459306 team"

None of this comes from app code — it's Firebase Console configuration +
uncustomized templates.

## Fix levels

### 1. Console quick-fix (5 min, no code) — DO FIRST
- Firebase Console → Authentication → Settings → **Public-facing name** →
  set to "Final Table" (fixes subject + signature).
- Set support email / sender name on same page.
- Authentication → Templates → Password reset → edit subject/body.

### 2. Custom sender domain (removes firebaseapp.com)
- Templates → Customize domain → verify own domain (SPF/DKIM DNS).
- Email then sends from e.g. `noreply@finaltable.io`.

### 3. Fully custom email via Resend (total control) — optional
- App already has `RESEND_API_KEY` + `EmailService` + backend.
- Backend generates reset link (Admin SDK `generatePasswordResetLink()`),
  sends branded HTML via Resend (match partner-grant emails).
- `sendPasswordReset` hits backend instead of Firebase directly.
- Real work: backend endpoint + template + wiring.

## Recommendation
Do #1 now (Console-only). Consider #2 before marketing push. Reserve #3 for
full brand-match. #1/#2 are Console tasks (user); #3 needs code (Claude can help).
