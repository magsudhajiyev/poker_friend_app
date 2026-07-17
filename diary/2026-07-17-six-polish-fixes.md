# 2026-07-17 — Six Polish Fixes

1. **Tour skip button hidden** on "Every Hand, Saved" step to avoid overlapping the View Logged Hands button.
2. **Hand Tools spotlight fixed** — reduced radius from 40→16 and increased padding so all 4 buttons are covered.
3. **Tour Complete Done button centered** — wrapped `DialogActionBar.single` pill in full-width SizedBox.
4. **Opponent no-hands icon removed** — removed the 72×72 icon container from `_buildEmptyState()` in `opponent_hands_screen.dart`.
5. **Splash background box eliminated** — changed video from 50%-width aspect-ratio box to full-screen `FittedBox.cover` so the video background fills the scaffold.
6. **Subscription tier limits updated** — Pro opponents 15→20, AI quotas Pro 10→20 / Elite 30→50, paywall feature lists show specific limits.
